//
//  GroupsSyncClient.swift
//  Yala
//
//  Cliente del canal de sync de GRUPOS → backend (incremento G2). CLASE NUEVA, DARK detrás de
//  `CloudSyncFlags.groupsBackendEnabled` (SIEMPRE `false` esta fase): captura los cambios del store de
//  Grupos del SwiftData History (drain), los sube al gateway (`POST /groups/push`), baja los deltas
//  remotos (`GET /groups/pull`) y los aplica a los `@Model` `Split*` locales — todo con anclas/token/
//  reloj PROPIOS del canal, sin tocar el motor personal (`CloudSyncEngine`) ni su `personalEntityNames`.
//
//  El muro anti-fuga es BIDIRECCIONAL: el drain de Grupos filtra por `GroupEntityEmissionMap.
//  groupEntityNames` (disjunto de `personalEntityNames`) → NUNCA emite entidades personales, y el drain
//  personal NUNCA emite `Split*`. El History es por-CONTAINER, así que ambos canales lo leen con cursores
//  independientes (`GroupSyncCursor` vs `SyncCursor`).
//
//  Echo-suppression: el drain DESCARTA las transacciones cuyo author sea `Self.outboxSaveAuthor` — el
//  MISMO autor con el que persiste su outbox Y aplica los deltas remotos (así el apply no se re-drena).
//  El bridge a modelos personales (`GroupTransactionBridge`) escribe bajo autor por DEFECTO (que el drain
//  PERSONAL sí captura → las TX puenteadas se sincronizan por el canal personal) — nunca bajo este autor.
//
//  DUPLICACIÓN CONSCIENTE (G2, decisión de la sesión): el patrón de drain (token + `lastDrainedTxAt` +
//  `recoverIfHistoryTokenIncomparable` + dedup `(syncID,hlc,op)` + HLC monótono persistido) se DUPLICA
//  del motor personal en vez de factorizarse, para NO tocar `CloudSyncEngine` esta noche. La refactor a
//  un core compartido queda diferida.
//
//  SIMPLIFICACIONES DARK (documentadas): el apply es full-row last-pulled-wins (el server ya hace el
//  merge por-unidad; el LWW por-campo client-side de Grupos se difiere), sin cuarentena / unit-clock /
//  espejo App Group / clasificación de reason (audit-only del personal). El ciclo de vida (cadencia,
//  backoff, observadores de remote-change) se cablea cuando el canal encienda (G4+).
//

import Foundation
import OSLog
import SwiftData

@MainActor
final class GroupsSyncClient {

    // MARK: Singleton (DARK)

    static let shared = GroupsSyncClient()

    // MARK: Constantes

    /// Autor del CONTEXTO con el que el canal de Grupos persiste su outbox Y aplica deltas remotos. El
    /// drain DESCARTA las transacciones con este autor (anti-auto-captura / echo suppression).
    static let outboxSaveAuthor = "GroupsSyncOutbox"

    /// Los 5 nombres de clase del store de Grupos (muro anti-fuga). Delegado al mapa de emisión (SSOT).
    static var groupEntityNames: Set<String> { GroupEntityEmissionMap.groupEntityNames }

    private let logger = Logger(subsystem: "com.yala.app", category: "GroupsSync")

    // MARK: Dependencias inyectables

    private let baseURL: URL
    // Providers `@MainActor`: leen singletons main-actor-isolados (`CloudAuthService`). El cliente es
    // `@MainActor` → invocarlos no cruza actor.
    private let tokenProvider: @MainActor () async -> String?
    private let attestProvider: @MainActor () async -> String?
    private let urlSession: SyncHTTPSession
    private let sessionCheck: @MainActor () -> Bool
    private let now: () -> Date

    // MARK: Estado

    private var clock: HLCClock
    private var isDraining = false
    private var pendingDrain = false
    private var bridgeRetryTask: Task<Void, Never>?

    // MARK: Guard del token de History (molde HALLAZGO 2)

    private(set) var historyTokenValidated = false
    private static let historyTokenSlack: TimeInterval = 60
    private(set) var historyTokenIncomparableCount = 0
    private(set) var historyTokenRecoveredCount = 0

    // MARK: Seams de test

    /// Cuando `true`, `drainOnce` NO avanza el token del cursor tras persistir el outbox (simula un kill
    /// entre el save del outbox y el avance del token). SOLO tests.
    var _testSuppressTokenAdvance = false

    // MARK: Init

    init(
        baseURL: URL = ProxyConfig.baseURL,
        tokenProvider: @escaping @MainActor () async -> String? = { await CloudAuthService.shared.accessToken() },
        attestProvider: @escaping @MainActor () async -> String? = { nil },
        urlSession: SyncHTTPSession = URLSession.shared,
        sessionCheck: @escaping @MainActor () -> Bool = { CloudAuthService.shared.hasSession },
        now: @escaping () -> Date = { .now },
        nodeID: NodeID = NodeID.generate()
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.attestProvider = attestProvider
        self.urlSession = urlSession
        self.sessionCheck = sessionCheck
        self.now = now
        self.clock = HLCClock(nodeID: nodeID)
    }

    // MARK: - Arranque (DARK)

    /// Arranca el canal de Grupos SOLO si `groupsBackendEnabled && hasSession` (SESIÓN VIVA, no
    /// storageMode — la persona solo-grupos). Con el flag `false` (SIEMPRE esta fase) es un NO-OP TOTAL:
    /// retorna ANTES de tocar la red o crear modelos. Call-site DARK en `AppBootstrapper`.
    func startIfEligible(context: ModelContext) {
        guard CloudSyncFlags.groupsBackendEnabled, sessionCheck() else { return }
        // Ciclo de vida real (cadencia/backoff/observadores) diferido a G4+: por ahora una vuelta única.
        Task { @MainActor in await self.syncCycleOnce(context: context) }
    }

    /// UNA vuelta del ciclo: captura local → push → pull → apply. DARK (solo corre con el flag ON).
    func syncCycleOnce(context: ModelContext) async {
        drainOnce(context: context)
        _ = await pushPending(context: context)
        _ = await pullAndApplyOnce(context: context)
    }

    // MARK: - Drain (captura del History → GroupSyncOutbox)

    /// Ejecuta UNA vuelta de captura. Re-entrante (coalescing one-in-flight/one-queued, molde personal).
    func drainOnce(context: ModelContext) {
        guard !isDraining else {
            pendingDrain = true
            return
        }
        isDraining = true
        defer { isDraining = false }
        repeat {
            pendingDrain = false
            performDrain(context: context)
        } while pendingDrain
    }

    private func performDrain(context: ModelContext) {
        do {
            let cursor = try loadOrCreateCursor(context)
            loadClock(from: cursor)
            let token = decodeToken(cursor.historyTokenData)

            let lookups = try buildLookups(context)
            let tokenTxns = try fetchHistory(after: token, context: context)

            let tokenGuard = recoverIfHistoryTokenIncomparable(
                cursor: cursor, tokenTxns: tokenTxns, context: context)
            if tokenGuard.validatedByCompare { historyTokenValidated = true }
            let txns = tokenGuard.txns

            var seen = try existingOutboxKeys(context)

            var rows: [PendingGroupRow] = []
            var advancedToken: DefaultHistoryToken?
            var advancedTxAt: Date?
            for tx in txns {
                // Anti-auto-captura (echo suppression): descartar los writes del propio canal SIN avanzar
                // el high-water (si avanzaran, cada avance escribiría el cursor → loop).
                if tx.author == Self.outboxSaveAuthor { continue }
                do {
                    for change in tx.changes {
                        let entityName = change.changedPersistentIdentifier.entityName
                        // Muro anti-fuga: solo entidades del store de Grupos (personal lo captura el otro canal).
                        guard Self.groupEntityNames.contains(entityName) else { continue }
                        try translate(change, entityName: entityName, tx: tx, lookups: lookups,
                                      rows: &rows, seen: &seen)
                    }
                } catch {
                    // `clock.send` lanzó (drift/overflow): abortar en la FRONTERA de esta transacción.
                    #if DEBUG
                    logger.error("GroupsSync: clock drift/overflow al traducir tx: \(error)")
                    #endif
                    break
                }
                advancedToken = tx.token
                advancedTxAt = tx.timestamp
            }

            if !rows.isEmpty {
                try saveWithAuthor(context) {
                    for row in rows { context.insert(row.makeModel()) }
                }
            }

            if !_testSuppressTokenAdvance {
                if let reanchor = tokenGuard.reanchor {
                    try saveWithAuthor(context) {
                        cursor.historyTokenData = try encodeToken(reanchor.token)
                        cursor.lastDrainedTxAt = reanchor.txAt
                        cursor.clockLatestHLC = clock.latest?.description
                    }
                    historyTokenValidated = true
                    historyTokenRecoveredCount += 1
                } else if let advancedToken {
                    try saveWithAuthor(context) {
                        cursor.historyTokenData = try encodeToken(advancedToken)
                        cursor.lastDrainedTxAt = advancedTxAt
                        cursor.clockLatestHLC = clock.latest?.description
                    }
                    historyTokenValidated = true
                }
            }
        } catch {
            #if DEBUG
            logger.error("GroupsSync: drain error: \(error)")
            #endif
        }
    }

    // MARK: - Traducción de un cambio (dispatch por tipo concreto)

    private struct Lookups {
        var splitGroup: [PersistentIdentifier: SplitGroup] = [:]
        var splitExpense: [PersistentIdentifier: SplitExpense] = [:]
        var splitShare: [PersistentIdentifier: SplitShare] = [:]
        var splitSettlement: [PersistentIdentifier: SplitSettlement] = [:]
    }

    private func translate(
        _ change: HistoryChange,
        entityName: String,
        tx: DefaultHistoryTransaction,
        lookups: Lookups,
        rows: inout [PendingGroupRow],
        seen: inout Set<String>
    ) throws {
        switch entityName {
        case GroupSyncEntityType.splitExpense:
            try translateChange(change, type: SplitExpense.self, entityType: entityName,
                                emission: GroupEntityEmissionMap.splitExpense,
                                liveSyncID: { $0.id }, liveGroupID: { $0.groupZoneID },
                                tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                tombstoneGroupID: { $0.tombstone[\.groupZoneID] as? String },
                                updateOnly: false, lookup: lookups.splitExpense, tx: tx,
                                rows: &rows, seen: &seen)
        case GroupSyncEntityType.splitShare:
            try translateChange(change, type: SplitShare.self, entityType: entityName,
                                emission: GroupEntityEmissionMap.splitShare,
                                liveSyncID: { $0.id }, liveGroupID: { $0.groupZoneID },
                                tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                tombstoneGroupID: { $0.tombstone[\.groupZoneID] as? String },
                                updateOnly: false, lookup: lookups.splitShare, tx: tx,
                                rows: &rows, seen: &seen)
        case GroupSyncEntityType.splitSettlement:
            try translateChange(change, type: SplitSettlement.self, entityType: entityName,
                                emission: GroupEntityEmissionMap.splitSettlement,
                                liveSyncID: { $0.id }, liveGroupID: { $0.groupZoneID },
                                tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                tombstoneGroupID: { $0.tombstone[\.groupZoneID] as? String },
                                updateOnly: false, lookup: lookups.splitSettlement, tx: tx,
                                rows: &rows, seen: &seen)
        case GroupSyncEntityType.splitGroup:
            // UPDATE-only: el grupo nace vía RPC create_group (G3+) → NO se emite su INSERT. `group_id` del
            // wire = `cloudKitZoneID` (la identidad server-side); `syncID` local = `id` (dedup).
            try translateChange(change, type: SplitGroup.self, entityType: entityName,
                                emission: GroupEntityEmissionMap.splitGroup,
                                liveSyncID: { $0.id }, liveGroupID: { $0.cloudKitZoneID },
                                tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                tombstoneGroupID: { $0.tombstone[\.cloudKitZoneID] as? String },
                                updateOnly: true, lookup: lookups.splitGroup, tx: tx,
                                rows: &rows, seen: &seen)
        default:
            // SplitMember (pull-only) y cualquier otro: sin emisión.
            return
        }
    }

    private func translateChange<T: PersistentModel>(
        _ change: HistoryChange,
        type: T.Type,
        entityType: String,
        emission: EntityEmission<T>,
        liveSyncID: (T) -> UUID,
        liveGroupID: (T) -> String,
        tombstoneSyncID: (DefaultHistoryDelete<T>) -> UUID?,
        tombstoneGroupID: (DefaultHistoryDelete<T>) -> String?,
        updateOnly: Bool,
        lookup: [PersistentIdentifier: T],
        tx: DefaultHistoryTransaction,
        rows: inout [PendingGroupRow],
        seen: inout Set<String>
    ) throws {
        switch change {
        case .insert(let insert):
            guard !updateOnly else { return }  // split_groups: el INSERT nace vía RPC → no emitir
            guard insert is DefaultHistoryInsert<T> else { return }
            guard let model = lookup[insert.changedPersistentIdentifier] else { return }
            try appendUpsert(model: model, emission: emission, syncID: liveSyncID(model),
                             groupID: liveGroupID(model), entityType: entityType,
                             changedColumns: emission.columns, tx: tx, rows: &rows, seen: &seen)

        case .update(let update):
            guard let typed = update as? DefaultHistoryUpdate<T> else { return }
            guard let model = lookup[typed.changedPersistentIdentifier] else { return }
            var changedColumns: Set<String> = []
            for keyPath in typed.updatedAttributes {
                if let columns = emission.columnKeyPaths[keyPath as PartialKeyPath<T>] {
                    changedColumns.formUnion(columns)
                }
            }
            guard !changedColumns.isEmpty else { return }
            try appendUpsert(model: model, emission: emission, syncID: liveSyncID(model),
                             groupID: liveGroupID(model), entityType: entityType,
                             changedColumns: changedColumns, tx: tx, rows: &rows, seen: &seen)

        case .delete(let delete):
            guard let typed = delete as? DefaultHistoryDelete<T> else { return }
            guard let syncID = tombstoneSyncID(typed), let groupID = tombstoneGroupID(typed) else {
                #if DEBUG
                logger.error("GroupsSync: tombstone sin identidad preservada para \(entityType, privacy: .public)")
                #endif
                return
            }
            try appendRow(op: .tombstone, syncID: syncID, groupID: groupID, entityType: entityType,
                          tx: tx, rows: &rows, seen: &seen) { _ in ("{}", nil) }

        @unknown default:
            return
        }
    }

    private func appendUpsert<T: AnyObject>(
        model: T,
        emission: EntityEmission<T>,
        syncID: UUID,
        groupID: String,
        entityType: String,
        changedColumns: Set<String>,
        tx: DefaultHistoryTransaction,
        rows: inout [PendingGroupRow],
        seen: inout Set<String>
    ) throws {
        try appendRow(op: .upsert, syncID: syncID, groupID: groupID, entityType: entityType,
                      tx: tx, rows: &rows, seen: &seen) { hlc in
            let result = DeltaEmitter.emit(model: model, emission: emission,
                                           changedColumns: changedColumns, hlc: hlc)
            let fieldsJSON: String
            do {
                fieldsJSON = try Canonc1Codec.encode(result.fields,
                                                     groupedColumns: Set(emission.groupByColumn.keys))
            } catch {
                #if DEBUG
                logger.error("GroupsSync: codec c1 rechazó \(entityType, privacy: .public): \(error)")
                #endif
                return nil
            }
            return (fieldsJSON, encodeFieldHlcs(result.fieldHlcs))
        }
    }

    private func appendRow(
        op: SyncOutboxOp,
        syncID: UUID,
        groupID: String,
        entityType: String,
        tx: DefaultHistoryTransaction,
        rows: inout [PendingGroupRow],
        seen: inout Set<String>,
        makePayload: (String) -> (fieldsJSON: String, fieldHlcsJSON: String?)?
    ) throws {
        let hlc = try clock.send(now: tx.timestamp).description
        let key = dedupKey(syncID: syncID, hlc: hlc, op: op)
        guard !seen.contains(key) else { return }
        seen.insert(key)
        guard let payload = makePayload(hlc) else { return }
        rows.append(PendingGroupRow(
            syncID: syncID,
            groupID: groupID,
            entityType: entityType,
            op: op,
            hlc: hlc,
            clientMutationID: UUID(),
            fieldsJSON: payload.fieldsJSON,
            fieldHlcsJSON: payload.fieldHlcsJSON,
            author: tx.author ?? "",
            createdAt: now()
        ))
    }

    // MARK: - Lookups

    private func buildLookups(_ context: ModelContext) throws -> Lookups {
        var lookups = Lookups()
        lookups.splitGroup = try index(SplitGroup.self, context: context)
        lookups.splitExpense = try index(SplitExpense.self, context: context)
        lookups.splitShare = try index(SplitShare.self, context: context)
        lookups.splitSettlement = try index(SplitSettlement.self, context: context)
        return lookups
    }

    private func index<T: PersistentModel>(
        _ type: T.Type, context: ModelContext
    ) throws -> [PersistentIdentifier: T] {
        let models = try context.fetch(FetchDescriptor<T>())
        var map: [PersistentIdentifier: T] = [:]
        for model in models { map[model.persistentModelID] = model }
        return map
    }

    // MARK: - Cursor / token / reloj

    func loadOrCreateCursor(_ context: ModelContext) throws -> GroupSyncCursor {
        var descriptor = FetchDescriptor<GroupSyncCursor>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }
        let cursor = GroupSyncCursor()
        context.insert(cursor)
        try saveWithAuthor(context) { }
        return cursor
    }

    private func loadClock(from cursor: GroupSyncCursor) {
        guard let raw = cursor.clockLatestHLC else { return }
        do {
            let hlc = try HLC.parse(raw)
            clock = HLCClock(nodeID: clock.nodeID, latest: hlc)
        } catch {
            #if DEBUG
            logger.error("GroupsSync: loadClock parse falló para \(raw, privacy: .public): \(error)")
            #endif
        }
    }

    /// Ejecuta `body` y hace `context.save()` bajo `Self.outboxSaveAuthor`, restaurando el autor previo.
    private func saveWithAuthor(_ context: ModelContext, _ body: () throws -> Void) throws {
        let previous = context.author
        context.author = Self.outboxSaveAuthor
        defer { context.author = previous }
        try body()
        try context.save()
    }

    private func decodeToken(_ data: Data?) -> DefaultHistoryToken? {
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(DefaultHistoryToken.self, from: data)
        } catch {
            return nil
        }
    }

    private func encodeToken(_ token: DefaultHistoryToken) throws -> Data {
        try JSONEncoder().encode(token)
    }

    private func fetchHistory(
        after token: DefaultHistoryToken?, context: ModelContext
    ) throws -> [DefaultHistoryTransaction] {
        guard let token else {
            return try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        }
        do {
            return try context.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token > token }))
        } catch {
            return try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        }
    }

    private func existingOutboxKeys(_ context: ModelContext) throws -> Set<String> {
        let existing = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        var keys: Set<String> = []
        for row in existing {
            guard let op = SyncOutboxOp(rawValue: row.opRaw) else { continue }
            keys.insert(dedupKey(syncID: row.syncID, hlc: row.hlc, op: op))
        }
        return keys
    }

    private func dedupKey(syncID: UUID, hlc: String, op: SyncOutboxOp) -> String {
        "\(syncID.uuidString)\u{1}\(hlc)\u{1}\(op.rawValue)"
    }

    private func encodeFieldHlcs(_ fieldHlcs: [String: String]) -> String {
        guard !fieldHlcs.isEmpty else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return String(decoding: try encoder.encode(fieldHlcs), as: UTF8.self)
        } catch {
            return "{}"
        }
    }

    // MARK: - Guard del token de History (molde HALLAZGO 2)

    private struct TokenGuardResult {
        var txns: [DefaultHistoryTransaction]
        var validatedByCompare = false
        var reanchor: (token: DefaultHistoryToken, txAt: Date)?
    }

    /// Detecta y recupera un token que dejó de surfacear transacciones nuevas del mount ACTUAL usando los
    /// TIMESTAMPS de History (comparables cross-mount). Molde byte-a-byte de
    /// `CloudSyncEngine.recoverIfHistoryTokenIncomparable`, acotado a las entidades de Grupos.
    private func recoverIfHistoryTokenIncomparable(
        cursor: GroupSyncCursor,
        tokenTxns: [DefaultHistoryTransaction],
        context: ModelContext
    ) -> TokenGuardResult {
        guard !historyTokenValidated,
              cursor.historyTokenData != nil,
              let lastDrainedTxAt = cursor.lastDrainedTxAt else {
            return TokenGuardResult(txns: tokenTxns)
        }
        let cutoff = lastDrainedTxAt.addingTimeInterval(-Self.historyTokenSlack)
        let timestampTxns: [DefaultHistoryTransaction]
        do {
            timestampTxns = try context.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.timestamp > cutoff }))
        } catch {
            return TokenGuardResult(txns: tokenTxns)
        }
        guard !timestampTxns.isEmpty else { return TokenGuardResult(txns: tokenTxns) }

        let tokenTokens = tokenTxns.map(\.token)
        func tokenPresent(_ tx: DefaultHistoryTransaction) -> Bool {
            tokenTokens.contains { $0 == tx.token }
        }
        let missing = timestampTxns.filter { tx in
            guard tx.timestamp > lastDrainedTxAt else { return false }
            guard tx.author != Self.outboxSaveAuthor else { return false }
            guard tx.changes.contains(where: {
                Self.groupEntityNames.contains($0.changedPersistentIdentifier.entityName)
            }) else { return false }
            return !tokenPresent(tx)
        }
        guard !missing.isEmpty else {
            return TokenGuardResult(txns: tokenTxns, validatedByCompare: true)
        }

        historyTokenIncomparableCount += 1
        var union = tokenTxns
        for tx in timestampTxns where !tokenPresent(tx) { union.append(tx) }
        let orderedUnion = union.enumerated()
            .sorted { a, b in
                a.element.timestamp != b.element.timestamp
                    ? a.element.timestamp < b.element.timestamp
                    : a.offset < b.offset
            }
            .map(\.element)
        guard let last = orderedUnion.last else {
            return TokenGuardResult(txns: orderedUnion)
        }
        return TokenGuardResult(txns: orderedUnion, reanchor: (token: last.token, txAt: last.timestamp))
    }

    // MARK: - Push (POST /groups/push)

    /// Sube el outbox pendiente (filas sin dead-letter) al gateway y purga/marca según los resultados.
    /// Devuelve el `PushOutcome` (molde del canal personal). NO purga si la sesión está caída.
    func pushPending(context: ModelContext) async -> PushOutcome {
        let rows: [GroupSyncOutbox]
        do {
            var descriptor = FetchDescriptor<GroupSyncOutbox>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)])
            descriptor.predicate = #Predicate { $0.rejectedReason == nil }
            rows = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            logger.error("GroupsSync: fetch outbox para push falló: \(error)")
            #endif
            return .transient
        }
        guard !rows.isEmpty else { return .completed([]) }

        guard let token = await tokenProvider(), !token.isEmpty else {
            return .sessionExpired(pending: rows.count)
        }
        let attest = await attestProvider()

        let deltas: [GroupSyncDelta]
        do {
            deltas = try rows.map { try buildDelta(from: $0) }
        } catch {
            #if DEBUG
            logger.error("GroupsSync: buildDelta falló: \(error)")
            #endif
            return .transient
        }

        let body = wireBody(deltas)
        var request = URLRequest(url: baseURL.appendingPathComponent("groups/push"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let attest, !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient
        }
        guard let http = response as? HTTPURLResponse else { return .transient }

        switch http.statusCode {
        case 200:
            do {
                let decoded = try JSONDecoder().decode(GroupPushResponse.self, from: data)
                applyResults(decoded.results, rows: rows, context: context)
                return .completed(decoded.results)
            } catch {
                return .transient
            }
        case 401:
            return .sessionExpired(pending: rows.count)
        case 403:
            return .accountUnavailable
        case 409:
            return GatewayErrorEnvelope.isAccountReverting(data) ? .accountUnavailable : .transient
        default:
            return .transient
        }
    }

    /// Traduce UNA fila de outbox de Grupos a su `GroupSyncDelta` de wire. `entity_type` = tabla Postgres.
    func buildDelta(from row: GroupSyncOutbox) throws -> GroupSyncDelta {
        guard let table = GroupEntityEmissionMap.table(forClass: row.entityType) else {
            throw SyncPushError.unknownEntity(row.entityType)
        }
        let op = SyncOutboxOp(rawValue: row.opRaw) ?? .upsert
        let isTombstone = (op == .tombstone)
        // split_groups: el wire lleva `sync_id = null` (la identidad es `group_id`, §A.2 rama especial).
        let isSplitGroup = (row.entityType == GroupSyncEntityType.splitGroup)
        return GroupSyncDelta(
            entityType: table,
            groupID: row.groupID,
            syncID: isSplitGroup ? nil : row.syncID,
            op: op,
            fieldsRawJSON: isTombstone ? nil : row.fieldsJSON,
            fieldHlcsRawJSON: isTombstone ? nil : row.fieldHlcsJSON,
            hlc: row.hlc,
            clientMutationID: row.clientMutationID,
            schemaVersion: row.schemaVersion
        )
    }

    /// Aplica los resultados del push: `applied`/`noop` → purga la fila; `rejected` → dead-letter (salvo
    /// `upstream_*`, transitorio). Correlación por `client_mutation_id` (unívoco por mutación).
    private func applyResults(_ results: [SyncDeltaResult], rows: [GroupSyncOutbox], context: ModelContext) {
        guard !results.isEmpty else { return }
        var byMutation: [String: GroupSyncOutbox] = [:]
        for row in rows { byMutation[row.clientMutationID.uuidString.lowercased()] = row }

        do {
            try saveWithAuthor(context) {
                for result in results {
                    guard let mutationID = result.clientMutationID,
                          let row = byMutation[mutationID.lowercased()] else { continue }
                    switch result.status {
                    case .applied, .noop:
                        context.delete(row)
                    case .rejected:
                        let reason = result.reason ?? "rejected"
                        if reason.hasPrefix("upstream_") { continue }
                        row.rejectedReason = reason
                        row.rejectedAt = now()
                    }
                }
            }
        } catch {
            #if DEBUG
            logger.error("GroupsSync: applyResults save falló: \(error)")
            #endif
        }
    }

    // MARK: - Wire body (RawJSON crudo, molde SyncPushClient)

    private func wireBody(_ deltas: [GroupSyncDelta]) -> Data {
        let joined = deltas.map(Self.encodeDelta).joined(separator: ",")
        return Data("{\"deltas\":[\(joined)]}".utf8)
    }

    static func encodeDelta(_ d: GroupSyncDelta) -> String {
        var parts: [String] = [
            "\"entity_type\":\(SyncPushClient.jsonString(d.entityType))",
            "\"group_id\":\(SyncPushClient.jsonString(d.groupID))",
        ]
        // split_groups → sync_id null; el resto → uuid lowercased.
        if let syncID = d.syncID {
            parts.append("\"sync_id\":\(SyncPushClient.jsonString(syncID.uuidString.lowercased()))")
        } else {
            parts.append("\"sync_id\":null")
        }
        parts.append("\"op\":\(SyncPushClient.jsonString(d.op.rawValue))")
        if let fields = d.fieldsRawJSON { parts.append("\"fields\":\(fields)") }
        if let fieldHlcs = d.fieldHlcsRawJSON { parts.append("\"field_hlcs\":\(fieldHlcs)") }
        parts.append("\"hlc\":\(SyncPushClient.jsonString(d.hlc))")
        parts.append("\"client_mutation_id\":\(SyncPushClient.jsonString(d.clientMutationID.uuidString.lowercased()))")
        parts.append("\"schema_version\":\(d.schemaVersion)")
        return "{\(parts.joined(separator: ","))}"
    }

    // MARK: - Pull (GET /groups/pull) + apply

    /// Baja UNA página de deltas remotos y la aplica. Devuelve el `PullOutcome`.
    func pullAndApplyOnce(context: ModelContext, limit: Int = 500) async -> PullOutcome {
        let cursor: GroupSyncCursor
        do { cursor = try loadOrCreateCursor(context) } catch { return .transient }

        guard let token = await tokenProvider(), !token.isEmpty else { return .sessionExpired }

        guard let url = buildPullURL(cursorsJSON: cursor.groupCursorsJSON, limit: limit) else {
            return .transient
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let attest = await attestProvider(), !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient
        }
        guard let http = response as? HTTPURLResponse else { return .transient }

        switch http.statusCode {
        case 200:
            do {
                let page = try Self.decodePage(data)
                applyPulledPage(page, cursor: cursor, context: context)
                return .page(PulledPage(deltas: [], maxServerSeq: 0))
            } catch {
                return .transient
            }
        case 401: return .sessionExpired
        case 403: return .accountUnavailable
        default: return .transient
        }
    }

    /// Construye la URL del pull con `cursors` (JSON URL-encoded) + `limit`. `internal` para test #4.
    func buildPullURL(cursorsJSON: String, limit: Int) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent("groups/pull"),
                                       resolvingAgainstBaseURL: false)
        let clampedLimit = min(max(limit, 1), 1000)
        components?.queryItems = [
            URLQueryItem(name: "cursors", value: cursorsJSON),
            URLQueryItem(name: "limit", value: String(clampedLimit)),
        ]
        return components?.url
    }

    // MARK: - Apply de una página → Split*

    /// Aplica una `GroupPulledPage` a los `@Model` `Split*` bajo `Self.outboxSaveAuthor`, avanza los
    /// cursores por grupo, y al cierre dispara `markRemoteChangePending` + el gate 5/5 del bridge remoto.
    /// `internal` para tests (cursores).
    func applyPulledPage(_ page: GroupPulledPage, cursor: GroupSyncCursor, context: ModelContext) {
        var bridgeExpenseIDs: [UUID] = []
        var bridgeSettlementIDs: [UUID] = []
        var maxSeqByGroup = decodeCursors(cursor.groupCursorsJSON)

        do {
            try saveWithAuthor(context) {
                for delta in page.deltas {
                    try applyDelta(delta, context: context,
                                   bridgeExpenseIDs: &bridgeExpenseIDs,
                                   bridgeSettlementIDs: &bridgeSettlementIDs)
                    // Avanzar el cursor del grupo al server_seq máximo aplicado.
                    let prev = maxSeqByGroup[delta.groupID] ?? 0
                    if delta.serverSeq > prev { maxSeqByGroup[delta.groupID] = delta.serverSeq }
                }
                // Cursores autoritativos del server (por si vienen por delante del delta máximo aplicado).
                for (gid, seq) in page.cursors {
                    let prev = maxSeqByGroup[gid] ?? 0
                    if seq > prev { maxSeqByGroup[gid] = seq }
                }
                cursor.groupCursorsJSON = encodeCursors(maxSeqByGroup)
                cursor.clockLatestHLC = clock.latest?.description
            }
        } catch {
            #if DEBUG
            logger.error("GroupsSync: applyPulledPage save falló: \(error)")
            #endif
            return
        }

        SessionState.shared.markRemoteChangePending()
        scheduleBridge(expenseIDs: bridgeExpenseIDs, settlementIDs: bridgeSettlementIDs)
    }

    private func applyDelta(
        _ delta: GroupPulledDelta,
        context: ModelContext,
        bridgeExpenseIDs: inout [UUID],
        bridgeSettlementIDs: inout [UUID]
    ) throws {
        switch delta.entityType {
        case GroupEntityEmissionMap.splitExpense.table:
            guard let id = delta.syncID else { return }
            try applyExpense(delta, id: id, context: context, bridgeExpenseIDs: &bridgeExpenseIDs)
        case GroupEntityEmissionMap.splitShare.table:
            guard let id = delta.syncID else { return }
            try applyShare(delta, id: id, context: context)
        case GroupEntityEmissionMap.splitSettlement.table:
            guard let id = delta.syncID else { return }
            try applySettlement(delta, id: id, context: context, bridgeSettlementIDs: &bridgeSettlementIDs)
        case GroupEntityEmissionMap.splitGroup.table:
            try applyGroupMeta(delta, context: context)
        case "group_members":
            try applyMember(delta, context: context)
        default:
            return  // entidad no cableada al apply
        }
    }

    private func applyExpense(
        _ delta: GroupPulledDelta, id: UUID, context: ModelContext, bridgeExpenseIDs: inout [UUID]
    ) throws {
        let existing = try fetchSplitExpense(id: id, context: context)
        if delta.op == .tombstone {
            if let existing { context.delete(existing) }
            return
        }
        let model = existing ?? SplitExpense()
        model.id = id
        model.groupZoneID = delta.groupID
        let f = delta.fields
        if let v = wireString(f["expense_description"]) { model.expenseDescription = v }
        if let v = wireDouble(f["amount"]) { model.amount = v }
        if let v = wireString(f["currency_code"]) { model.currencyCode = v }
        if let v = f["note"] { model.note = wireString(v) }
        if let v = wireDate(f["date"]) { model.date = v }
        if let v = wireDate(f["created_at"]) { model.createdAt = v }
        if let v = wireString(f["paid_by_member_key"]) { model.paidByMemberID = v }
        if let v = wireString(f["split_type"]) { model.splitType = v }
        if let v = wireBool(f["is_settled"]) { model.isSettled = v }
        if let v = wireBool(f["is_opening_balance"]) { model.isOpeningBalance = v }
        if let v = f["subcategory_name"] { model.subcategoryName = wireString(v) }
        if existing == nil { context.insert(model) }
        bridgeExpenseIDs.append(id)
    }

    private func applyShare(_ delta: GroupPulledDelta, id: UUID, context: ModelContext) throws {
        let existing = try fetchSplitShare(id: id, context: context)
        if delta.op == .tombstone {
            if let existing { context.delete(existing) }
            return
        }
        let model = existing ?? SplitShare()
        model.id = id
        model.groupZoneID = delta.groupID
        let f = delta.fields
        if let v = wireUUID(f["expense_id"]) { model.expenseID = v }
        if let v = wireString(f["member_key"]) { model.memberID = v }
        if let v = wireDouble(f["amount"]) { model.amount = v }
        if let v = wireBool(f["is_paid"]) { model.isPaid = v }
        if existing == nil { context.insert(model) }
    }

    private func applySettlement(
        _ delta: GroupPulledDelta, id: UUID, context: ModelContext, bridgeSettlementIDs: inout [UUID]
    ) throws {
        let existing = try fetchSplitSettlement(id: id, context: context)
        if delta.op == .tombstone {
            if let existing { context.delete(existing) }
            return
        }
        let model = existing ?? SplitSettlement()
        model.id = id
        model.groupZoneID = delta.groupID
        let f = delta.fields
        if let v = wireString(f["from_member_key"]) { model.fromMemberID = v }
        if let v = wireString(f["to_member_key"]) { model.toMemberID = v }
        if let v = wireDouble(f["amount"]) { model.amount = v }
        if let v = wireString(f["currency_code"]) { model.currencyCode = v }
        if let v = f["note"] { model.note = wireString(v) }
        if let v = wireDate(f["date"]) { model.date = v }
        if let v = wireBool(f["is_confirmed"]) { model.isConfirmed = v }
        if existing == nil { context.insert(model) }
        bridgeSettlementIDs.append(id)
    }

    private func applyGroupMeta(_ delta: GroupPulledDelta, context: ModelContext) throws {
        // Identidad = group_id (cloudKitZoneID). UPDATE-only en push; en apply se crea si falta (el grupo
        // nace vía RPC/CKSyncEngine, pero el pull es autoritativo para un member — idempotente).
        let existing = try fetchSplitGroup(zoneID: delta.groupID, context: context)
        if delta.op == .tombstone {
            if let existing { context.delete(existing) }
            return
        }
        let model = existing ?? SplitGroup()
        model.cloudKitZoneID = delta.groupID
        let f = delta.fields
        if let v = wireString(f["name"]) { model.name = v }
        if let v = wireString(f["icon_name"]) { model.iconName = v }
        if let v = wireString(f["color_hex"]) { model.colorHex = v }
        if let v = wireString(f["currency_code"]) { model.currencyCode = v }
        if let v = wireBool(f["simplify_debts"]) { model.simplifyDebts = v }
        if let v = wireBool(f["show_debts_in_single_currency"]) { model.showDebtsInSingleCurrency = v }
        if let v = wireBool(f["members_can_invite"]) { model.membersCanInvite = v }
        if let v = wireString(f["default_split_type"]) { model.defaultSplitType = v }
        if let v = wireBool(f["is_archived"]) { model.isArchived = v }
        if let v = wireBool(f["is_hidden_for_all"]) { model.isHiddenForAll = v }
        if let v = wireDate(f["created_at"]) { model.createdAt = v }
        if existing == nil { context.insert(model) }
    }

    private func applyMember(_ delta: GroupPulledDelta, context: ModelContext) throws {
        // PULL-ONLY: identidad = member_key (= `cloudKitUserRecordID`, string, en el `sync_id` del wire).
        // El sentinel '__deleted_user__' NO se traduce aquí (l10n de UI, G4+).
        guard let memberKey = delta.rawSyncID else { return }
        let existing = try fetchSplitMember(zoneID: delta.groupID, memberKey: memberKey, context: context)
        if delta.op == .tombstone {
            if let existing { context.delete(existing) }
            return
        }
        let model = existing ?? SplitMember()
        if existing == nil {
            // Born-remote: id LOCAL determinista del namespace BACKEND (paralelo al CloudKit) → dedup
            // estable cross-device sin depender del path CloudKit (G3).
            model.id = GroupBackendIdentityLogic.deterministicMemberID(
                groupID: delta.groupID, memberKey: memberKey)
        }
        model.groupZoneID = delta.groupID
        model.cloudKitUserRecordID = memberKey
        let f = delta.fields
        if let v = wireString(f["display_name"]) { model.displayName = v }
        if let v = wireString(f["role"]) { model.role = v }
        if let v = wireString(f["status"]) { model.status = v }
        if let v = wireDate(f["joined_at"]) { model.joinedAt = v }
        // `user_id` = auth uid del wire → `SplitMember.userID` (LOCAL-only del canal backend; nunca CKRecord).
        // Presente-y-null (anonimización del server) NULLea el campo (`wireString(.null) == nil`), igual que
        // `note`; ausente = no tocar (PATCH parcial). Cierra el residual documentado del commit G2.
        if let v = f["user_id"] { model.userID = wireString(v) }
        if existing == nil { context.insert(model) }
    }

    // MARK: fetch por identidad (concreto por tipo — regla `#Predicate`)

    private func fetchSplitExpense(id: UUID, context: ModelContext) throws -> SplitExpense? {
        var d = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
        return try context.fetch(d).first
    }
    private func fetchSplitShare(id: UUID, context: ModelContext) throws -> SplitShare? {
        var d = FetchDescriptor<SplitShare>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
        return try context.fetch(d).first
    }
    private func fetchSplitSettlement(id: UUID, context: ModelContext) throws -> SplitSettlement? {
        var d = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
        return try context.fetch(d).first
    }
    private func fetchSplitGroup(zoneID: String, context: ModelContext) throws -> SplitGroup? {
        var d = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneID }); d.fetchLimit = 1
        return try context.fetch(d).first
    }
    private func fetchSplitMember(zoneID: String, memberKey: String, context: ModelContext) throws -> SplitMember? {
        var d = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.cloudKitUserRecordID == memberKey })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    // MARK: - Gate 5/5 del bridge remoto (molde SplitSyncManager.processPendingRemoteChanges)

    private func scheduleBridge(expenseIDs: [UUID], settlementIDs: [UUID]) {
        guard !expenseIDs.isEmpty || !settlementIDs.isEmpty, GroupTransactionBridge.shared.isReady else { return }

        // Autoridad de quiescencia enrutada por storageMode (byte-idéntico al gate del canal CKSyncEngine).
        switch StorageModeSignalRouter.quiescenceSource(mode: CloudSyncFlags.storageMode) {
        case .cloudEngine:
            guard SyncQuiescenceCoordinator.shared.isQuiescentForEngineSaves else {
                scheduleBridgeRetry(expenseIDs: expenseIDs, settlementIDs: settlementIDs, after: 8)
                return
            }
        case .icloudImport:
            let decision = SubcategoryDedupGate.decide(
                now: now(),
                lastImportDate: iCloudSyncService.shared.lastSuccessfulImportDate,
                isSyncing: iCloudSyncService.shared.status.isImporting,
                lastDedupRunAt: nil
            )
            guard decision == .run else {
                let retryAfter: TimeInterval
                if case .waitQuiescence(let t) = decision { retryAfter = max(t, 1) } else { retryAfter = 8 }
                scheduleBridgeRetry(expenseIDs: expenseIDs, settlementIDs: settlementIDs, after: retryAfter)
                return
            }
        }

        runBridge(expenseIDs: expenseIDs, settlementIDs: settlementIDs)
    }

    private func runBridge(expenseIDs: [UUID], settlementIDs: [UUID]) {
        if !expenseIDs.isEmpty {
            do { try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: expenseIDs) }
            catch {
                #if DEBUG
                logger.error("GroupsSync: bridgeRemoteExpenses falló: \(error)")
                #endif
            }
        }
        if !settlementIDs.isEmpty {
            do { try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: settlementIDs) }
            catch {
                #if DEBUG
                logger.error("GroupsSync: bridgeRemoteSettlements falló: \(error)")
                #endif
            }
        }
    }

    private func scheduleBridgeRetry(expenseIDs: [UUID], settlementIDs: [UUID], after seconds: TimeInterval) {
        bridgeRetryTask?.cancel()
        bridgeRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            self.scheduleBridge(expenseIDs: expenseIDs, settlementIDs: settlementIDs)
        }
    }

    // MARK: - Decode del pull (envelope de wire)

    /// Decodifica el envelope `{ deltas, cursors, memberships }` de `GET /groups/pull` a `GroupPulledPage`.
    static func decodePage(_ data: Data) throws -> GroupPulledPage {
        let decoded = try JSONDecoder().decode(RawGroupPullResponse.self, from: data)
        let deltas: [GroupPulledDelta] = decoded.deltas.map { raw in
            GroupPulledDelta(
                entityType: raw.entityType,
                groupID: raw.groupID,
                rawSyncID: raw.syncID,
                syncID: raw.syncID.flatMap { UUID(uuidString: $0) },
                op: SyncOutboxOp(rawValue: raw.op) ?? .upsert,
                fields: raw.fields ?? [:],
                fieldHlcs: raw.fieldHlcs ?? [:],
                hlc: raw.hlc,
                serverSeq: raw.serverSeq,
                schemaVersion: raw.schemaVersion ?? 1
            )
        }
        return GroupPulledPage(
            deltas: deltas,
            cursors: decoded.cursors ?? [:],
            memberships: decoded.memberships ?? []
        )
    }

    // MARK: - cursors JSON

    private func decodeCursors(_ json: String) -> [String: Int64] {
        guard let data = json.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: Int64].self, from: data) else { return [:] }
        return map
    }

    private func encodeCursors(_ map: [String: Int64]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(map) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Decodificadores de valor de wire (reusan WireValueDecoder)

    private func wireString(_ v: WireValue?) -> String? {
        guard let v else { return nil }
        if case .string(let s) = v { return s }
        return nil
    }
    private func wireDouble(_ v: WireValue?) -> Double? { v.flatMap(WireValueDecoder.double) }
    private func wireBool(_ v: WireValue?) -> Bool? {
        guard let v else { return nil }
        if case .bool(let b) = v { return b }
        return nil
    }
    private func wireUUID(_ v: WireValue?) -> UUID? {
        guard let s = wireString(v) else { return nil }
        return UUID(uuidString: s)
    }
    private func wireDate(_ v: WireValue?) -> Date? {
        guard let s = wireString(v) else { return nil }
        return WireValueDecoder.date(.string(s))
    }
}

// MARK: - PendingGroupRow

/// Fila de outbox de Grupos acumulada en memoria durante un drain, materializada a `@Model` al persistir.
private struct PendingGroupRow {
    let syncID: UUID
    let groupID: String
    let entityType: String
    let op: SyncOutboxOp
    let hlc: String
    let clientMutationID: UUID
    let fieldsJSON: String
    let fieldHlcsJSON: String?
    let author: String
    let createdAt: Date

    @MainActor
    func makeModel() -> GroupSyncOutbox {
        GroupSyncOutbox(
            syncID: syncID, groupID: groupID, entityType: entityType, op: op, hlc: hlc,
            clientMutationID: clientMutationID, fieldsJSON: fieldsJSON, fieldHlcsJSON: fieldHlcsJSON,
            author: author, tombstoneReason: op == .tombstone ? SyncTombstoneReason.user.rawValue : nil,
            createdAt: createdAt
        )
    }
}

// MARK: - Wire types (Grupos)

/// Delta de wire de Grupos (espeja `SyncDelta` + `group_id`; `sync_id` nullable para `split_groups`).
struct GroupSyncDelta: Equatable {
    let entityType: String          // TABLA Postgres (split_expenses, …)
    let groupID: String
    let syncID: UUID?               // nil ⇒ split_groups (wire emite sync_id=null)
    let op: SyncOutboxOp
    let fieldsRawJSON: String?
    let fieldHlcsRawJSON: String?
    let hlc: String
    let clientMutationID: UUID
    let schemaVersion: Int
}

/// Respuesta de `POST /groups/push`.
private struct GroupPushResponse: Decodable {
    let results: [SyncDeltaResult]
}

/// Delta bajado del pull de Grupos (ya decodificado). `rawSyncID` = el `sync_id` crudo del wire (member_key
/// para group_members; UUID-string para las entidades de contenido; `null` para split_groups).
struct GroupPulledDelta: Equatable {
    let entityType: String          // TABLA Postgres
    let groupID: String
    let rawSyncID: String?
    let syncID: UUID?
    let op: SyncOutboxOp
    let fields: [String: WireValue]
    let fieldHlcs: [String: String]
    let hlc: String
    let serverSeq: Int64
    let schemaVersion: Int
}

/// Página del pull de Grupos: deltas + cursores autoritativos por grupo + memberships descubiertas.
struct GroupPulledPage: Equatable {
    let deltas: [GroupPulledDelta]
    let cursors: [String: Int64]
    let memberships: [String]
}

private struct RawGroupPullResponse: Decodable {
    let deltas: [RawGroupPulledDelta]
    let cursors: [String: Int64]?
    let memberships: [String]?
}

private struct RawGroupPulledDelta: Decodable {
    let entityType: String
    let groupID: String
    let syncID: String?
    let op: String
    let fields: [String: WireValue]?
    let fieldHlcs: [String: String]?
    let hlc: String
    let serverSeq: Int64
    let schemaVersion: Int?

    enum CodingKeys: String, CodingKey {
        case entityType = "entity_type"
        case groupID = "group_id"
        case syncID = "sync_id"
        case op
        case fields
        case fieldHlcs = "field_hlcs"
        case hlc
        case serverSeq = "server_seq"
        case schemaVersion = "schema_version"
    }
}
