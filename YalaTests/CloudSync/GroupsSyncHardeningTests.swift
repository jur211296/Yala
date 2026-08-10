//
//  GroupsSyncHardeningTests.swift
//  YalaTests / CloudSync
//
//  Endurecimiento B2 del canal Grupos → backend (DARK). Cubre los Gates B2 del brief:
//   (1) `GroupsOutboxMirror`: write en el drain (Q3) / remove al purgar Y al dead-letterizar (excluidas
//       del espejo) / re-write al revivir (re-drive) / purgeAll en teardown / rehydrate por diff
//       owner-scoped e idempotente / paridad de autor;
//   (2) push CHUNKING (tabla 0/1/50/51/120 filas → requests; fallo en chunk 2 conserva el resto;
//       [R8] applyResults POR CHUNK — lo confirmado del chunk 1 se purga aunque el 2 falle);
//   (3) stopLoop/teardownForSignOut en los 3 paths de CloudSessionSignOut (source-scan) + el teardown
//       detiene el loop y purga el espejo;
//   (4) guard de re-entrada del ciclo (2 `syncCycleOnceCoalesced` concurrentes → 1 corre + 1 coalesced);
//   (5) piggyback [R3]: personal cadenciando → startIfEligible se abstiene / performCycle 5.6 invoca
//       grupos con flag ON, NO con flag OFF, NO en secundaria; canRunDomain()==false → loop propio;
//   (6) backoff RPC [R5]: transient×2→éxito / permanente→0 retries / agotamiento→transient /
//       create_group con transporte -1 → 0 retries;
//   (8) barrido de los tombstones de `split_groups` YA ENCOLADOS antes del guard del 2026-08-02 (fila +
//       gemela del espejo + dead-letter + entry huérfana sin fila), su idempotencia sin sentinel, el
//       cinturón del rehydrate y el ORDEN del cableado (barrido → rehydrate → loop).
//  Container ON-DISK temp (3 stores `.none`), `.serialized`, sin sleeps reales (sleeper inyectado).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupsSync · endurecimiento B2 (DARK)", .serialized)
@MainActor
struct GroupsSyncHardeningTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsB2-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GB2-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GB2-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GB2-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    // MARK: Stubs HTTP

    private final class StubSession: SyncHTTPSession, @unchecked Sendable {
        let data: Data
        let status: Int
        var callCount = 0
        var bodies: [Data] = []
        init(_ json: String, status: Int = 200) { self.data = Data(json.utf8); self.status = status }
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            callCount += 1
            bodies.append(request.httpBody ?? Data())
            return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }

    private final class SequenceStubSession: SyncHTTPSession, @unchecked Sendable {
        struct Reply { let data: Data; let status: Int }
        private var replies: [Reply]
        private let fallback: Reply
        var callCount = 0
        init(_ replies: [Reply], fallback: Reply) { self.replies = replies; self.fallback = fallback }
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            callCount += 1
            let reply = replies.isEmpty ? fallback : replies.removeFirst()
            return (reply.data, HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!)
        }
    }

    /// Transporte caído: lanza SIN respuesta (el `transient(status: -1)` de la tabla de idempotencia).
    private final class ThrowingStubSession: SyncHTTPSession, @unchecked Sendable {
        var callCount = 0
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            callCount += 1
            throw URLError(.notConnectedToInternet)
        }
    }

    /// La PRIMERA respuesta se suspende hasta `release()` (para tener un ciclo EN VUELO determinista).
    private final class BlockingStubSession: SyncHTTPSession, @unchecked Sendable {
        let data: Data
        var callCount = 0
        private var blockNext = true
        private var continuation: CheckedContinuation<Void, Never>?
        init(_ json: String) { self.data = Data(json.utf8) }
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            callCount += 1
            if blockNext {
                blockNext = false
                await withCheckedContinuation { self.continuation = $0 }
            }
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        func release() {
            continuation?.resume()
            continuation = nil
        }
    }

    private final class Counter: @unchecked Sendable { var count = 0 }

    private let emptyPageJSON = "{\"deltas\":[],\"cursors\":{},\"memberships\":[]}"

    // MARK: Helpers de datos

    private func makeClient(
        session: SyncHTTPSession, mirrorDir: URL? = nil, userID: String? = "sub-a"
    ) -> GroupsSyncClient {
        GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: session, sessionCheck: { true },
            currentUserIDProvider: { userID },
            outboxMirror: mirrorDir.map { GroupsOutboxMirror(directoryURL: $0) },
            // Hermético: los tests con 401 NO deben tocar `CloudAuthService.shared` (default del retry-once
            // H-2026-07-18-4). nil = sin refresh → sessionExpired, byte-idéntico al comportamiento previo.
            forceRefreshTokenProvider: { nil })
    }

    @discardableResult
    private func seedOutboxRow(
        _ context: ModelContext, group: String = "SplitGroup-A", mid: UUID = UUID(),
        hlc: String, createdAt: Date = .now, rejectedReason: String? = nil
    ) throws -> GroupSyncOutbox {
        let row = GroupSyncOutbox(
            syncID: UUID(), groupID: group, entityType: GroupSyncEntityType.splitExpense,
            op: .upsert, hlc: hlc, clientMutationID: mid,
            fieldsJSON: "{\"amount\":\"1.0000\"}", author: "", createdAt: createdAt,
            rejectedReason: rejectedReason)
        context.insert(row)
        try context.save()
        return row
    }

    private func appliedResultsJSON(_ mids: [UUID]) -> String {
        let items = mids.map {
            "{\"sync_id\":\"s\",\"client_mutation_id\":\"\($0.uuidString.lowercased())\",\"status\":\"applied\"}"
        }.joined(separator: ",")
        return "{\"results\":[\(items)]}"
    }

    private func mirrorFiles(_ dir: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".json") }) ?? []
    }

    // MARK: - (1) Espejo del outbox

    @Test func mirrorAuthor_matchesGroupsOutboxAuthor() {
        #expect(GroupsOutboxMirror.author == GroupsSyncClient.outboxSaveAuthor)
    }

    /// El drain escribe el espejo (misma vuelta síncrona, Q3) sellado con el `sub` de la sesión, con
    /// op/fields/hlc fieles a la fila del outbox.
    @Test func drain_writesMirrorEntry_ownerSealed() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let client = makeClient(session: StubSession(emptyPageJSON), mirrorDir: mirrorDir)

        // C2-bis: la zona debe ser de un grupo BACKEND o el drain la salta (partición POR-GRUPO).
        let group = SplitGroup(name: "G")
        group.cloudKitZoneID = "SplitGroup-A"
        group.isBackendGroup = true
        context.insert(group)
        let expense = SplitExpense(groupZoneID: "SplitGroup-A", amount: 12.5, currencyCode: "USD",
                                   expenseDescription: "Dinner", paidByMemberID: "m1")
        context.insert(expense)
        try context.save()
        client.drainOnce(context: context)

        let rows = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        #expect(rows.count == 1)
        let mirror = GroupsOutboxMirror(directoryURL: mirrorDir)
        let entries = mirror.entriesForUser("sub-a")
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        let row = try #require(rows.first)
        #expect(entry.syncID == row.syncID)
        #expect(entry.groupID == "SplitGroup-A")
        #expect(entry.op == row.opRaw)
        #expect(entry.hlc == row.hlc)
        #expect(entry.clientMutationID == row.clientMutationID)
        #expect(entry.fieldsJSON == row.fieldsJSON)
        #expect(entry.author == GroupsOutboxMirror.author)
        // Owner-scoping: otro userID NO ve la entry.
        #expect(mirror.entriesForUser("sub-b").isEmpty)
    }

    /// `applied` purga la fila Y borra su archivo espejo; un dead-letter TAMBIÉN lo borra (las
    /// dead-letter se EXCLUYEN del espejo — red de durabilidad de PENDIENTES).
    @Test func push_appliedAndDeadLetter_removeMirrorFiles() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)

        let midApplied = UUID(); let midRejected = UUID()
        let rowA = try seedOutboxRow(context, mid: midApplied,
                                     hlc: "2026-07-15T00:00:00.000Z-0001-00000000000000aa")
        let rowB = try seedOutboxRow(context, mid: midRejected,
                                     hlc: "2026-07-15T00:00:00.000Z-0002-00000000000000aa")
        // Espejo pre-existente de ambas (como si el drain las hubiera escrito).
        let mirror = GroupsOutboxMirror(directoryURL: mirrorDir)
        try mirror.write(GroupsOutboxMirrorEntry(
            userID: "sub-a", syncID: rowA.syncID, groupID: rowA.groupID, entityType: rowA.entityType,
            op: rowA.opRaw, hlc: rowA.hlc, clientMutationID: rowA.clientMutationID,
            fieldsJSON: rowA.fieldsJSON, fieldHlcsJSON: nil, tombstoneReason: nil,
            author: GroupsOutboxMirror.author, createdAt: rowA.createdAt))
        try mirror.write(GroupsOutboxMirrorEntry(
            userID: "sub-a", syncID: rowB.syncID, groupID: rowB.groupID, entityType: rowB.entityType,
            op: rowB.opRaw, hlc: rowB.hlc, clientMutationID: rowB.clientMutationID,
            fieldsJSON: rowB.fieldsJSON, fieldHlcsJSON: nil, tombstoneReason: nil,
            author: GroupsOutboxMirror.author, createdAt: rowB.createdAt))
        #expect(mirrorFiles(mirrorDir).count == 2)

        let response = """
        {"results":[\
        {"sync_id":"s","client_mutation_id":"\(midApplied.uuidString.lowercased())","status":"applied"},\
        {"sync_id":"s","client_mutation_id":"\(midRejected.uuidString.lowercased())","status":"rejected","reason":"malformed_delta"}\
        ]}
        """
        let client = makeClient(session: StubSession(response), mirrorDir: mirrorDir)
        _ = await client.pushPending(context: context)

        // applied → purgada; rejected local → dead-letter viva en el store.
        let rows = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        #expect(rows.count == 1)
        #expect(rows.first?.rejectedReason == "malformed_delta")
        // AMBOS archivos espejo fuera (purga + exclusión de dead-letter).
        #expect(mirrorFiles(mirrorDir).isEmpty)
    }

    /// El RE-DRIVE (member propio aprobado) revive la dead-letter → la fila RE-ENTRA al espejo.
    @Test func redrive_revivedRow_reentersMirror() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)

        let row = try seedOutboxRow(context, group: "zone-1", mid: UUID(),
                                    hlc: "2026-07-15T00:00:00.000Z-0003-00000000000000aa",
                                    rejectedReason: "upstream_400:yala_not_authorized")
        let client = makeClient(session: StubSession(emptyPageJSON), mirrorDir: mirrorDir,
                                userID: "auth-uid-1")
        #expect(mirrorFiles(mirrorDir).isEmpty)  // dead-letter: fuera del espejo

        let delta = GroupPulledDelta(
            entityType: "group_members", groupID: "zone-1", rawSyncID: "member-rec-1", syncID: nil,
            op: .upsert,
            fields: ["display_name": .string("Alice"), "role": .string("admin"),
                     "status": .string("active"), "joined_at": .string("2026-07-15T00:00:00.000Z"),
                     "user_id": .string("auth-uid-1")],
            fieldHlcs: [:], hlc: "h", serverSeq: 3, schemaVersion: 1)
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(GroupPulledPage(deltas: [delta], cursors: [:], memberships: []),
                               cursor: cursor, context: context)

        #expect(row.rejectedReason == nil)  // revivida
        let mirror = GroupsOutboxMirror(directoryURL: mirrorDir)
        let entries = mirror.entriesForUser("auth-uid-1")
        #expect(entries.count == 1)         // re-espejada como pendiente
        #expect(entries.first?.syncID == row.syncID)
    }

    /// `teardownForSignOut` detiene el loop y purga TODO el espejo (montos — red M1).
    @Test func teardownForSignOut_stopsLoop_purgesMirror() throws {
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let mirror = GroupsOutboxMirror(directoryURL: mirrorDir)
        try mirror.write(GroupsOutboxMirrorEntry(
            userID: "sub-a", syncID: UUID(), groupID: "g", entityType: "SplitExpense",
            op: "upsert", hlc: "h1", clientMutationID: UUID(), fieldsJSON: "{}",
            fieldHlcsJSON: nil, tombstoneReason: nil, author: GroupsOutboxMirror.author, createdAt: .now))
        #expect(mirrorFiles(mirrorDir).count == 1)

        let client = makeClient(session: StubSession(emptyPageJSON), mirrorDir: mirrorDir)
        client.teardownForSignOut()

        #expect(mirrorFiles(mirrorDir).isEmpty)
        #expect(client._testLoopTask == nil)
        #expect(!client.didRemediateGroupMerkleThisSession)  // frontera de sesión re-armada (B1)
    }

    /// Los paths de `CloudSessionSignOut` llaman al teardown del canal de Grupos (source-scan — el
    /// wiring real no es ejecutable en unit test: toca CloudAuthService/controllers reales). G5-B añade
    /// el path solo-grupos, que TAMBIÉN corta el canal (pero NO el runtime personal → `teardowns` sigue 3).
    @Test func signOut_allThreePaths_wireGroupsTeardown() throws {
        let source = try String(contentsOf: Self.repoRoot
            .appendingPathComponent("Yala/Services/CloudSync/CloudSessionSignOut.swift"), encoding: .utf8)
        let teardowns = source.components(separatedBy: "CloudSyncRuntime.shared?.teardownGuestSession()").count - 1
        let groupsTeardowns = source.components(separatedBy: "GroupsSyncClient.shared.teardownForSignOut()").count - 1
        // El runtime PERSONAL se derriba en los 3 paths de sign-out que lo montan (privateReset/cloud/
        // secondary) + el cierre .cloud de ELIMINAR-CUENTA (G5-D1, belt idempotente — el service ya lo
        // derribó en su paso 2). El solo-grupos NO conoce el runtime personal.
        #expect(teardowns == 4)
        // El canal de grupos se corta en los 5 paths de sign-out (privateReset/cloud/secondary/groupsOnly
        // + exitYala del split D2 `573c3b8e`, que corta el canal ANTES de purgar cursor+outbox de grupos)
        // + los 2 cierres de eliminar-cuenta (closeLocalAfterAccountDeletion Cloud/GroupsOnly — belts).
        #expect(groupsTeardowns == 7)
    }

    /// M1 / D8 (G5-C): la purga de frontera de la sesión secundaria incluye el espejo App Group de GRUPOS
    /// (`fieldsJSON` lleva montos del dueño → no debe sobrevivir la frontera). Source-scan (la purga usa el
    /// App Group de producción, no ejecutable determinista en unit test); el mecanismo `purgeAll` lo cubre
    /// `teardownForSignOut_stopsLoop_purgesMirror`.
    @Test func boundaryPurge_wiresGroupsMirrorPurge() throws {
        let source = try String(contentsOf: Self.repoRoot
            .appendingPathComponent("Yala/Services/CloudSync/SecondarySessionBoundaryPurge.swift"),
            encoding: .utf8)
        #expect(source.contains("GroupsOutboxMirror()?.purgeAll()"))
    }

    // MARK: - (8) Barrido de tombstones de `split_groups` YA ENCOLADOS (mitad hacia atrás del 2026-08-02)
    //
    // El `guard !updateOnly` del `case .delete` de `translateChange` es hacia DELANTE: un teléfono que ya
    // tuviera la fila encolada la seguiría empujando, y server-side la identidad de `split_groups` es la
    // ZONA ⇒ borra el grupo para TODOS sus miembros. Estos tests fijan el barrido y su cinturón.

    /// Fila de outbox + su gemela en el espejo App Group (el par que hay que retirar entero).
    @discardableResult
    private func seedRowWithMirrorTwin(
        _ context: ModelContext, mirror: GroupsOutboxMirror?, userID: String = "sub-a",
        entityType: String, op: SyncOutboxOp, group: String = "SplitGroup-A", hlc: String,
        rejectedReason: String? = nil
    ) throws -> GroupSyncOutbox {
        let row = GroupSyncOutbox(
            syncID: UUID(), groupID: group, entityType: entityType, op: op, hlc: hlc,
            fieldsJSON: op == .tombstone ? "{}" : "{\"name\":\"G\"}", author: "",
            tombstoneReason: op == .tombstone ? "user" : nil, rejectedReason: rejectedReason)
        context.insert(row)
        try context.save()
        if let mirror {
            try mirror.write(GroupsOutboxMirrorEntry(
                userID: userID, syncID: row.syncID, groupID: row.groupID, entityType: row.entityType,
                op: row.opRaw, hlc: row.hlc, clientMutationID: row.clientMutationID,
                fieldsJSON: row.fieldsJSON, fieldHlcsJSON: nil, tombstoneReason: row.tombstoneReason,
                author: GroupsOutboxMirror.author, createdAt: row.createdAt))
        }
        return row
    }

    private func mirrorFileExists(_ dir: URL, syncID: UUID, hlc: String) -> Bool {
        FileManager.default.fileExists(
            atPath: dir.appendingPathComponent(GroupsOutboxMirror.fileName(syncID: syncID, hlc: hlc)).path)
    }

    /// El barrido retira la fila venenosa Y su archivo del espejo, y NO toca nada más. Las dos vecinas
    /// importan: el UPSERT de `SplitGroup` es emisión legítima (la meta del grupo SÍ se edita por el push —
    /// `update_only` es update-only, no push-nothing) y el tombstone de `SplitExpense` es el borrado de un
    /// gasto, que debe viajar. Un barrido por entidad a secas, o por `op` a secas, mataría una de las dos.
    ///
    /// MUTACIÓN: quitar la llamada a `purgeQueuedSplitGroupTombstones` (o su borrado de filas) deja las
    /// dos primeras aserciones en rojo.
    @Test func purge_removesQueuedGroupTombstone_rowAndMirrorTwin() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let mirror = GroupsOutboxMirror(directoryURL: mirrorDir)
        let client = makeClient(session: StubSession(emptyPageJSON), mirrorDir: mirrorDir)

        let poison = try seedRowWithMirrorTwin(
            context, mirror: mirror, entityType: GroupSyncEntityType.splitGroup, op: .tombstone,
            hlc: "2026-08-02T00:00:00.000Z-0001-00000000000000aa")
        let groupMetaEdit = try seedRowWithMirrorTwin(
            context, mirror: mirror, entityType: GroupSyncEntityType.splitGroup, op: .upsert,
            hlc: "2026-08-02T00:00:00.000Z-0002-00000000000000aa")
        let expenseTombstone = try seedRowWithMirrorTwin(
            context, mirror: mirror, entityType: GroupSyncEntityType.splitExpense, op: .tombstone,
            hlc: "2026-08-02T00:00:00.000Z-0003-00000000000000aa")
        let poisonSyncID = poison.syncID
        let poisonHLC = poison.hlc

        client.purgeQueuedSplitGroupTombstones(context: context)

        let rows = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        #expect(!rows.contains { $0.syncID == poisonSyncID },
                "un tombstone de split_groups encolado borra el grupo para TODOS sus miembros al empujarse")
        #expect(!mirrorFileExists(mirrorDir, syncID: poisonSyncID, hlc: poisonHLC),
                "sin la gemela del espejo, el rehydrate del próximo boot la re-inserta")
        // Lo que NO se toca.
        #expect(rows.contains { $0.syncID == groupMetaEdit.syncID })
        #expect(rows.contains { $0.syncID == expenseTombstone.syncID })
        #expect(rows.count == 2)
        #expect(mirrorFileExists(mirrorDir, syncID: groupMetaEdit.syncID, hlc: groupMetaEdit.hlc))
        #expect(mirrorFileExists(mirrorDir, syncID: expenseTombstone.syncID, hlc: expenseTombstone.hlc))
    }

    /// Las DEAD-LETTER también, sin filtro por `rejectedReason` (al revés que `pushPending`): el re-drive
    /// de `upstream_400:yala_not_authorized` revive una fila rechazada y la vuelve a hacer pendiente, así
    /// que dejarla sería dejar el veneno con un temporizador.
    ///
    /// MUTACIÓN: añadir `&& $0.rejectedReason == nil` al predicado del barrido → esta aserción en rojo.
    @Test func purge_includesDeadLetteredGroupTombstone() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let client = makeClient(session: StubSession(emptyPageJSON), mirrorDir: mirrorDir)

        // Las dead-letter se EXCLUYEN del espejo por diseño (B2) → sin gemela, solo fila.
        try seedRowWithMirrorTwin(
            context, mirror: nil, entityType: GroupSyncEntityType.splitGroup, op: .tombstone,
            hlc: "2026-08-02T00:00:00.000Z-0004-00000000000000aa",
            rejectedReason: "upstream_400:yala_not_authorized")

        client.purgeQueuedSplitGroupTombstones(context: context)

        #expect(try context.fetchCount(FetchDescriptor<GroupSyncOutbox>()) == 0,
                "una dead-letter revivible es el mismo veneno con retraso")
    }

    /// El caso que el barrido por-filas NO ve: la tabla la recreó VACÍA una lightweight migration y solo
    /// queda el archivo del espejo. Es exactamente el estado para el que existe `rehydrateOutboxFromMirror`
    /// ⇒ sin barrer el espejo, el rehydrate re-inyecta el tombstone.
    ///
    /// MUTACIÓN: quitar el bloque que escanea `mirror.entriesForUser` deja la primera aserción en rojo.
    @Test func purge_removesOrphanMirrorEntry_withNoLiveRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let mirror = GroupsOutboxMirror(directoryURL: mirrorDir)
        let client = makeClient(session: StubSession(emptyPageJSON), mirrorDir: mirrorDir)

        let orphanSyncID = UUID()
        let orphanHLC = "2026-08-02T00:00:00.000Z-0005-00000000000000aa"
        try mirror.write(GroupsOutboxMirrorEntry(
            userID: "sub-a", syncID: orphanSyncID, groupID: "SplitGroup-A",
            entityType: GroupSyncEntityType.splitGroup, op: SyncOutboxOp.tombstone.rawValue,
            hlc: orphanHLC, clientMutationID: UUID(), fieldsJSON: "{}", fieldHlcsJSON: nil,
            tombstoneReason: "user", author: GroupsOutboxMirror.author, createdAt: .now))

        client.purgeQueuedSplitGroupTombstones(context: context)

        #expect(!mirrorFileExists(mirrorDir, syncID: orphanSyncID, hlc: orphanHLC))
        // Y el rehydrate ya no tiene de dónde resucitarlo.
        client.rehydrateOutboxFromMirror(context: context)
        #expect(try context.fetchCount(FetchDescriptor<GroupSyncOutbox>()) == 0)
    }

    /// Idempotente por construcción y SIN sentinel (molde `OrphanedBridgedTxSweeper`): la segunda pasada no
    /// encuentra nada, y sobre un outbox limpio no toca ni una fila. Es lo que permite dejarlo corriendo en
    /// CADA arranque como red de cualquier camino futuro que reabra el hueco.
    @Test func purge_isIdempotent_andNoOpOnCleanOutbox() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let mirror = GroupsOutboxMirror(directoryURL: mirrorDir)
        let client = makeClient(session: StubSession(emptyPageJSON), mirrorDir: mirrorDir)

        // Outbox limpio: no-op total.
        client.purgeQueuedSplitGroupTombstones(context: context)
        #expect(try context.fetchCount(FetchDescriptor<GroupSyncOutbox>()) == 0)

        let survivor = try seedRowWithMirrorTwin(
            context, mirror: mirror, entityType: GroupSyncEntityType.splitExpense, op: .upsert,
            hlc: "2026-08-02T00:00:00.000Z-0006-00000000000000aa")
        try seedRowWithMirrorTwin(
            context, mirror: mirror, entityType: GroupSyncEntityType.splitGroup, op: .tombstone,
            hlc: "2026-08-02T00:00:00.000Z-0007-00000000000000aa")

        client.purgeQueuedSplitGroupTombstones(context: context)
        let afterFirst = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        #expect(afterFirst.count == 1)
        #expect(afterFirst.first?.syncID == survivor.syncID)

        client.purgeQueuedSplitGroupTombstones(context: context)
        let afterSecond = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        #expect(afterSecond.count == 1)
        #expect(afterSecond.first?.syncID == survivor.syncID)
        #expect(mirrorFileExists(mirrorDir, syncID: survivor.syncID, hlc: survivor.hlc))
    }

    /// CINTURÓN: aunque un archivo del espejo sobreviva al barrido (borrado de archivos a medias, o un
    /// orden futuro distinto entre los dos), el rehydrate JAMÁS devuelve un tombstone de `split_groups` al
    /// outbox — y sí sigue re-insertando lo legítimo de la misma pasada.
    ///
    /// MUTACIÓN: quitar el `continue` del filtro en `rehydrateOutboxFromMirror` deja `count == 1` en rojo.
    @Test func rehydrate_neverResurrectsGroupTombstone() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let mirror = GroupsOutboxMirror(directoryURL: mirrorDir)
        let client = makeClient(session: StubSession(emptyPageJSON), mirrorDir: mirrorDir)

        try mirror.write(GroupsOutboxMirrorEntry(
            userID: "sub-a", syncID: UUID(), groupID: "SplitGroup-A",
            entityType: GroupSyncEntityType.splitGroup, op: SyncOutboxOp.tombstone.rawValue,
            hlc: "2026-08-02T00:00:00.000Z-0008-00000000000000aa", clientMutationID: UUID(),
            fieldsJSON: "{}", fieldHlcsJSON: nil, tombstoneReason: "user",
            author: GroupsOutboxMirror.author, createdAt: .now))
        let legitSyncID = UUID()
        try mirror.write(GroupsOutboxMirrorEntry(
            userID: "sub-a", syncID: legitSyncID, groupID: "SplitGroup-A",
            entityType: GroupSyncEntityType.splitExpense, op: SyncOutboxOp.tombstone.rawValue,
            hlc: "2026-08-02T00:00:00.000Z-0009-00000000000000aa", clientMutationID: UUID(),
            fieldsJSON: "{}", fieldHlcsJSON: nil, tombstoneReason: "user",
            author: GroupsOutboxMirror.author, createdAt: .now))

        client.rehydrateOutboxFromMirror(context: context)

        let rows = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        #expect(rows.count == 1, "el tombstone de split_groups no puede volver al outbox por ninguna vía")
        #expect(rows.first?.syncID == legitSyncID)
    }

    /// Y el test que carga el peso del DÓNDE, porque ninguno de los de arriba lo prueba: el barrido tiene
    /// que correr ANTES del rehydrate y ANTES de que nazca el loop. `AppBootstrapper` llama
    /// `startIfEligible` SÍNCRONO en el paso 15, mientras que sus retomes son `Task` gateados por
    /// `awaitPersonalStoreReady()` (poll de 2 s) — mover el barrido «con los otros retomes» le haría perder
    /// la carrera contra el primer `syncCycleOnce`, que es justo el push que hay que impedir, y los tests
    /// de comportamiento seguirían todos en verde. Source-scan (molde `AttestWiringTests`).
    @Test func startIfEligible_wiresPurge_beforeRehydrateAndBeforeLoop() throws {
        let source = try String(contentsOf: Self.repoRoot
            .appendingPathComponent("Yala/Services/CloudSync/Groups/GroupsSyncClient.swift"),
            encoding: .utf8)
        let start = try #require(source.range(of: "func startIfEligible("))
        let end = try #require(source.range(of: "private func runLoop("))
        let body = String(source[start.lowerBound..<end.lowerBound])

        let purge = try #require(body.range(of: "purgeQueuedSplitGroupTombstones(context: context)"),
                                 "el barrido no está cableado en startIfEligible")
        let rehydrate = try #require(body.range(of: "rehydrateOutboxFromMirror(context: context)"))
        let loop = try #require(body.range(of: "loopTask = Task"))
        #expect(purge.lowerBound < rehydrate.lowerBound,
                "el rehydrate re-inyectaría del espejo lo que el barrido acaba de quitar")
        #expect(purge.lowerBound < loop.lowerBound,
                "el loop empuja: el barrido tiene que ser anterior a su creación")
    }

    /// El SEGUNDO call-site, y el que destapó la review adversarial: `startIfEligible` gatea por el flag
    /// COMPUESTO (`groupsBackendEnabled` = compilado && kill remoto) mientras que
    /// `CloudSessionSignOut.pushAllPendingGroupsForSignOut` gatea por el COMPILADO
    /// (`groupsBackendCompiledCapability`) y `pushPending` no consulta flag alguno. Con el kill remoto
    /// puesto —o con el snapshot de remote-config ausente, que es fail-closed— el barrido del arranque es
    /// INERTE y este push-all empuja igual: el propio comentario de `pushAllPendingGroupsForSignOut` lo
    /// dice («el transporte no consulta el flag»). Y bajar `GROUPS_BACKEND_ROLLOUT_PERCENT` es la
    /// contención natural de ESTE incidente ⇒ sin esta llamada, el barrido estaría apagado justo en la
    /// cohorte donde el veneno sobrevive.
    ///
    /// El ORDEN también importa: va antes del pre-check de pendientes, para que un outbox cuya única fila
    /// viva era la venenosa salga `.drained` sin emitir un solo request.
    ///
    /// MUTACIÓN: quitar la llamada, o moverla por debajo del pre-check, deja este test en rojo — y los
    /// otros seis de la sección en verde, que es exactamente por qué hace falta.
    @Test func signOutPushAll_wiresPurge_beforePendingPreCheck() throws {
        let source = try String(contentsOf: Self.repoRoot
            .appendingPathComponent("Yala/Services/CloudSync/CloudSessionSignOut.swift"), encoding: .utf8)
        let start = try #require(source.range(of: "private func pushAllPendingGroupsForSignOut("))
        let body = String(source[start.lowerBound...])

        let purge = try #require(
            body.range(of: "GroupsSyncClient.shared.purgeQueuedSplitGroupTombstones(context: context)"),
            "el push-all del sign-out empuja el outbox sin pasar por startIfEligible")
        let preCheck = try #require(body.range(of: "if Self.liveGroupsPendingCount(context: context) == 0"))
        let gate = try #require(body.range(of: "if CloudSyncFlags.groupsBackendCompiledCapability {"))
        #expect(gate.lowerBound < purge.lowerBound && purge.lowerBound < preCheck.lowerBound,
                "el barrido va DENTRO del gate compilado y ANTES del pre-check de pendientes")
    }

    // MARK: - (7) M1 / D8 (G5-C): aislamiento del store de grupos por sesión

    /// `GroupSyncOutbox`/`GroupSyncCursor` viven en el `syncMetaSchema` → en sesión secundaria caen en el
    /// archivo `YalaSyncMeta-Secondary` (ya aislado por `syncMetaConfiguration`), SIN scope-arlos. Fija el
    /// contrato a nivel de schema + aislamiento por-archivo: un insert en el store secundario NO es visible
    /// en el del dueño.
    @Test func groupSyncOutbox_livesInSyncMeta_isolatedPerSessionFile() throws {
        let names = Set(SwiftDataConfiguration.syncMetaSchema.entities.map(\.name))
        #expect(names.contains("GroupSyncOutbox"))
        #expect(names.contains("GroupSyncCursor"))

        let dir = freshDir(); defer { cleanup(dir) }
        let ownerCfg = ModelConfiguration(
            "SyncMeta-owner", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("owner.sqlite"), cloudKitDatabase: .none)
        let secondaryCfg = ModelConfiguration(
            "SyncMeta-secondary", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("secondary.sqlite"), cloudKitDatabase: .none)
        let ownerCtx = ModelContext(
            try ModelContainer(for: SwiftDataConfiguration.syncMetaSchema, configurations: ownerCfg))
        let secondaryCtx = ModelContext(
            try ModelContainer(for: SwiftDataConfiguration.syncMetaSchema, configurations: secondaryCfg))

        let row = GroupSyncOutbox(
            syncID: UUID(), groupID: "g", entityType: GroupSyncEntityType.splitExpense,
            op: .upsert, hlc: "h1", clientMutationID: UUID(),
            fieldsJSON: "{\"amount\":\"1.0000\"}", author: "", createdAt: .now)
        secondaryCtx.insert(row)
        try secondaryCtx.save()

        #expect(try secondaryCtx.fetchCount(FetchDescriptor<GroupSyncOutbox>()) == 1)
        #expect(try ownerCtx.fetchCount(FetchDescriptor<GroupSyncOutbox>()) == 0)  // aislado por archivo
    }

    /// Rehydrate: re-inserta por DIFF owner-scoped las entries que el outbox perdió (valores ORIGINALES),
    /// IGNORA las de otra identidad, e idempotente (segunda pasada no duplica).
    @Test func rehydrate_diffOwnerScoped_idempotent() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let mirror = GroupsOutboxMirror(directoryURL: mirrorDir)

        // 2 entries del owner (una de ellas YA viva en el outbox) + 1 de OTRA identidad.
        let liveMid = UUID(); let lostMid = UUID()
        let liveRow = try seedOutboxRow(context, mid: liveMid,
                                        hlc: "2026-07-15T00:00:00.000Z-0004-00000000000000aa")
        try mirror.write(GroupsOutboxMirrorEntry(
            userID: "sub-a", syncID: liveRow.syncID, groupID: liveRow.groupID,
            entityType: liveRow.entityType, op: liveRow.opRaw, hlc: liveRow.hlc,
            clientMutationID: liveRow.clientMutationID, fieldsJSON: liveRow.fieldsJSON,
            fieldHlcsJSON: nil, tombstoneReason: nil, author: GroupsOutboxMirror.author,
            createdAt: liveRow.createdAt))
        let lostSyncID = UUID()
        try mirror.write(GroupsOutboxMirrorEntry(
            userID: "sub-a", syncID: lostSyncID, groupID: "SplitGroup-B", entityType: "SplitExpense",
            op: "tombstone", hlc: "2026-07-15T00:00:00.000Z-0005-00000000000000aa",
            clientMutationID: lostMid, fieldsJSON: "{}", fieldHlcsJSON: nil,
            tombstoneReason: "user", author: GroupsOutboxMirror.author, createdAt: .now))
        try mirror.write(GroupsOutboxMirrorEntry(
            userID: "sub-OTHER", syncID: UUID(), groupID: "g", entityType: "SplitExpense",
            op: "upsert", hlc: "2026-07-15T00:00:00.000Z-0006-00000000000000aa",
            clientMutationID: UUID(), fieldsJSON: "{}", fieldHlcsJSON: nil, tombstoneReason: nil,
            author: GroupsOutboxMirror.author, createdAt: .now))

        let client = makeClient(session: StubSession(emptyPageJSON), mirrorDir: mirrorDir)
        client.rehydrateOutboxFromMirror(context: context)

        var rows = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        #expect(rows.count == 2)  // la viva + la perdida; la de sub-OTHER IGNORADA
        let rehydrated = try #require(rows.first(where: { $0.syncID == lostSyncID }))
        #expect(rehydrated.opRaw == "tombstone")               // op PRESERVADA (jamás upsert)
        #expect(rehydrated.clientMutationID == lostMid)        // idempotencia end-to-end intacta
        #expect(rehydrated.tombstoneReason == "user")
        #expect(rehydrated.author == GroupsOutboxMirror.author)

        // Idempotente: re-correr no duplica.
        client.rehydrateOutboxFromMirror(context: context)
        rows = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        #expect(rows.count == 2)
    }

    // MARK: - (2) Push chunking

    /// Tabla de requests por tamaño del outbox (chunk = 50): 0→0 · 1→1 · 50→1 · 51→2 · 120→3.
    @Test(arguments: [(0, 0), (1, 1), (50, 1), (51, 2), (120, 3)])
    func push_chunking_requestCountTable(rows: Int, expectedRequests: Int) async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        for i in 0..<rows {
            try seedOutboxRow(context, hlc: "2026-07-15T00:00:00.000Z-\(String(format: "%04x", i))-00000000000000aa",
                              createdAt: Date(timeIntervalSince1970: Double(1_700_000_000 + i)))
        }
        let stub = StubSession("{\"results\":[]}")
        let client = makeClient(session: stub, userID: nil)
        let outcome = await client.pushPending(context: context)
        #expect(stub.callCount == expectedRequests)
        if case .completed = outcome {} else { Issue.record("esperaba completed, got \(outcome)") }
    }

    /// [R8] + progreso incremental: 120 filas, chunk 1 (50) aplicado, chunk 2 falla 500 → applyResults
    /// corrió POR CHUNK (las 50 del chunk 1 YA purgadas), el resto (70) se conserva para el próximo
    /// ciclo, el chunk 3 NUNCA se pide, y el outcome es `.completed(parciales)`.
    @Test func push_chunk2Fails_chunk1AppliedPerChunk_restPreserved() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        var mids: [UUID] = []
        for i in 0..<120 {
            let mid = UUID()
            mids.append(mid)
            try seedOutboxRow(context, mid: mid,
                              hlc: "2026-07-15T00:00:00.000Z-\(String(format: "%04x", i))-00000000000000aa",
                              createdAt: Date(timeIntervalSince1970: Double(1_700_000_000 + i)))
        }
        // El fetch del push ordena por createdAt ASC → chunk 1 = las primeras 50 mids.
        let chunk1 = Array(mids.prefix(50))
        let stub = SequenceStubSession(
            [.init(data: Data(appliedResultsJSON(chunk1).utf8), status: 200),
             .init(data: Data("{}".utf8), status: 500)],
            fallback: .init(data: Data("{}".utf8), status: 500))
        let client = makeClient(session: stub, userID: nil)

        let outcome = await client.pushPending(context: context)

        #expect(stub.callCount == 2)  // chunk 3 jamás se pide tras el fallo del 2
        guard case .completed(let results) = outcome else {
            Issue.record("esperaba completed(parciales), got \(outcome)"); return
        }
        #expect(results.count == 50)
        let remaining = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        #expect(remaining.count == 70)  // las 50 del chunk 1 purgadas POR CHUNK [R8]
        let remainingMids = Set(remaining.map(\.clientMutationID))
        #expect(remainingMids.isDisjoint(with: Set(chunk1)))
    }

    // MARK: - (4) Guard de re-entrada del ciclo

    /// 2 `syncCycleOnceCoalesced` concurrentes → el 2º devuelve `.coalesced` inmediato Y encola una
    /// vuelta (el en-vuelo la ejecuta al terminar): total 2 pulls.
    @Test func cycle_reentry_coalescesAndQueuesOne() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = BlockingStubSession(emptyPageJSON)
        let client = makeClient(session: stub, userID: nil)

        let first = Task { @MainActor in await client.syncCycleOnceCoalesced(context: context) }
        // Dejar que el primer ciclo llegue a su pull y quede SUSPENDIDO en el stub.
        var spins = 0
        while stub.callCount == 0 && spins < 10_000 {
            await Task.yield()
            spins += 1
        }
        #expect(stub.callCount == 1)

        // Segundo caller con el primero en vuelo → coalesced inmediato (sin request propio).
        let second = await client.syncCycleOnceCoalesced(context: context)
        #expect(second == .coalesced)

        stub.release()
        let firstOutcome = await first.value
        #expect(firstOutcome == .completed)   // la última vuelta (la encolada) completó
        #expect(stub.callCount == 2)          // 1 pull del ciclo en vuelo + 1 de la vuelta encolada
    }

    /// MEDIA del review (guardia de generación): un `teardownForSignOut` con un ciclo EN VUELO
    /// (suspendido en el await del pull) + una vuelta ENCOLADA que drenaría un write nuevo → al resumir,
    /// el ciclo aborta SIN aplicar y la encolada NO corre: ni el espejo recién purgado se repuebla
    /// (garantía M1) ni el outbox recibe el drain póstumo.
    @Test func teardownDuringInFlightCycle_resumeWritesNothing() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let stub = BlockingStubSession(emptyPageJSON)
        let client = makeClient(session: stub, mirrorDir: mirrorDir, userID: "sub-a")

        // Ciclo 1 en vuelo, suspendido en su pull (outbox vacío → el push no manda request).
        let inFlight = Task { @MainActor in await client.syncCycleOnceCoalesced(context: context) }
        var spins = 0
        while stub.callCount == 0 && spins < 10_000 {
            await Task.yield()
            spins += 1
        }
        #expect(stub.callCount == 1)

        // Un write local NUEVO que la vuelta encolada drenaría (→ writeMirror + save del outbox)...
        let expense = SplitExpense(groupZoneID: "SplitGroup-A", amount: 9.99, currencyCode: "USD",
                                   expenseDescription: "Post-teardown", paidByMemberID: "m1")
        context.insert(expense)
        try context.save()
        // ...y la vuelta encolada (segundo caller con el ciclo en vuelo).
        #expect(await client.syncCycleOnceCoalesced(context: context) == .coalesced)

        // Teardown con el ciclo AÚN suspendido: generación++, espejo purgado.
        client.teardownForSignOut()
        #expect(mirrorFiles(mirrorDir).isEmpty)

        // Resume: el ciclo detecta la generación cambiada → aborta; la encolada NO corre.
        stub.release()
        let outcome = await inFlight.value
        #expect(outcome == .coalesced)  // abortado sin señal de red
        #expect(stub.callCount == 1)    // la vuelta encolada JAMÁS pidió red

        // NADA se escribió post-teardown: espejo sigue vacío (M1) y el drain póstumo no corrió.
        #expect(mirrorFiles(mirrorDir).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GroupSyncOutbox>()).isEmpty)
    }

    // MARK: - (5) Piggyback [R3]

    // MARK: (9) Kill-switch server-side del canal — la parada es inmediata pero NO se sella

    /// El envelope del 403 del kill (`gateway/src/groups/killSwitch.ts`). Un 403 SIN este código es «cuenta
    /// suspendida», que sí sella el loop.
    private static let killEnvelopeJSON =
        #"{"error":{"message":"Canal de Grupos apagado","type":"yala_groups_disabled","code":"yala_groups_disabled"}}"#

    /// LA aserción del fix: el kill para el loop en la vuelta actual y **no arma `stoppedUntilRelaunch`**.
    /// Si lo armara, apagar el canal sería inmediato pero ENCENDERLO exigiría que cada usuario matara y
    /// reabriera la app —`GroupsLoopRestartLogic.shouldStart` y `syncNowFromPush` leen ese flag— o sea la
    /// simétrica exacta del bug que el kill vino a cerrar (el 2026-07-31 un iPhone real se quedó con el
    /// canal OFF durante horas DESPUÉS de subir el percent a 100).
    @Test func killSwitch403_stopsLoop_butDoesNotSealIt() async throws {
        let prevRuntime = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.groupsBackendEnabled = true
        CloudSyncFlags.syncRuntimeEnabled = true   // storageMode `.icloud` ⇒ canRunDomain() false ⇒ loop propio
        SecondarySessionStore._testSetActiveOverride(false)
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            CloudSyncFlags.syncRuntimeEnabled = prevRuntime
            SecondarySessionStore._testSetActiveOverride(nil)
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = StubSession(Self.killEnvelopeJSON, status: 403)
        let client = makeClient(session: stub, userID: nil)
        client.sleeper = { _ in }
        client.startIfEligible(context: context)
        let task = client._testLoopTask
        #expect(task != nil)
        await task?.value

        #expect(stub.callCount >= 1)                       // llegó a hablar con el gateway
        #expect(client._testLoopTask == nil)               // el loop TERMINÓ (parada inmediata)
        #expect(client._testStoppedUntilRelaunch == false) // pero NO quedó sellado
        // Y la prueba de que la parada es re-arrancable de verdad: el próximo startIfEligible crea loop.
        client.startIfEligible(context: context, trigger: "foreground")
        let again = client._testLoopTask
        #expect(again != nil, "un kill levantado exigiría relanzar la app si el loop no re-arranca")
        await again?.value
    }

    /// Contraprueba: un 403 que NO es el kill (cuenta suspendida) SÍ sella el loop, como antes del cambio.
    /// Sin este test, «no sellar» podría haberse implementado borrando el sellado para los dos 403.
    @Test func accountUnavailable403_withoutKillCode_stillSealsLoop() async throws {
        let prevRuntime = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.groupsBackendEnabled = true
        CloudSyncFlags.syncRuntimeEnabled = true
        SecondarySessionStore._testSetActiveOverride(false)
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            CloudSyncFlags.syncRuntimeEnabled = prevRuntime
            SecondarySessionStore._testSetActiveOverride(nil)
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = StubSession(#"{"error":{"type":"yala_forbidden"}}"#, status: 403)
        let client = makeClient(session: stub, userID: nil)
        client.sleeper = { _ in }
        client.startIfEligible(context: context)
        await client._testLoopTask?.value

        #expect(client._testStoppedUntilRelaunch == true)  // veredicto sobre la CUENTA → sellado
        client.startIfEligible(context: context, trigger: "foreground")
        #expect(client._testLoopTask == nil, "un 403 de cuenta no debe re-arrancar en el mismo proceso")
    }

    /// Personal cadenciando (`syncRuntimeEnabled && canRunDomain()`) → `startIfEligible` se ABSTIENE del
    /// loop propio (el ciclo corre como paso 5.6 del runtime).
    @Test func startIfEligible_personalWillCadence_abstainsFromOwnLoop() async throws {
        let prevRuntime = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.groupsBackendEnabled = true
        CloudSyncFlags.syncRuntimeEnabled = true
        CloudSyncFlags.storageMode = .cloud
        // A3 (D-A7): el guard de mount-mismatch personal lee el testigo del mount, `.icloud` por default en
        // el host de tests. La premisa de este test es un device en modo nube YA RELANZADO (si no, el
        // personal NO cadenciaría y Grupos correría su loop propio — que es el test de al lado).
        SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.cloudMirrorOff)
        SecondarySessionStore._testSetActiveOverride(false)
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            CloudSyncFlags.syncRuntimeEnabled = prevRuntime
            CloudSyncFlags._testResetStorageModeOverride()
            SwiftDataConfiguration._testSetPersonalStoreMountedDecision(.iCloudMirror)
            SecondarySessionStore._testSetActiveOverride(nil)
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient(session: StubSession(emptyPageJSON), userID: nil)
        client.startIfEligible(context: context)
        #expect(client._testLoopTask == nil)  // abstención: piggyback 5.6 conduce
    }

    /// `canRunDomain() == false` (.icloud — solo-grupos; misma línea de guard que la fase transicional de
    /// migración, cuya matriz exhaustiva vive en CloudMigrationI14Tests) → Grupos SÍ arranca loop propio.
    @Test func startIfEligible_personalNotCadencing_startsOwnLoop() async throws {
        let prevRuntime = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.groupsBackendEnabled = true
        CloudSyncFlags.syncRuntimeEnabled = true
        // storageMode default `.icloud` → canRunDomain() == false.
        SecondarySessionStore._testSetActiveOverride(false)
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            CloudSyncFlags.syncRuntimeEnabled = prevRuntime
            SecondarySessionStore._testSetActiveOverride(nil)
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        // 401 → el loop termina solo tras la primera vuelta (sin sleeps).
        let stub = StubSession(emptyPageJSON, status: 401)
        let client = makeClient(session: stub, userID: nil)
        client.sleeper = { _ in }
        client.startIfEligible(context: context)
        let task = client._testLoopTask
        #expect(task != nil)                  // loop PROPIO arrancó
        await task?.value
        #expect(stub.callCount >= 1)          // y cicló de verdad
    }

    /// M1 / D8 (G5-C) — flag OFF: secundaria NI loop propio (guard del cliente) NI piggyback (guard del
    /// paso 5.6). Byte-idéntico al mundo M1 pre-G5-C.
    @Test func secondarySession_flagOff_neitherLoopNorPiggyback() async throws {
        CloudSyncFlags.groupsBackendEnabled = false
        SecondarySessionStore._testSetActiveOverride(true)
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            SecondarySessionStore._testSetActiveOverride(nil)
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = makeClient(session: StubSession(emptyPageJSON), userID: nil)
        client.startIfEligible(context: context)
        #expect(client._testLoopTask == nil)  // ni loop (retorna en el guard de flag)

        // Piggyback: el paso 5.6 NO invoca al runner con flag OFF.
        let counter = Counter()
        let runtime = makeRuntime(pullBody: emptyRuntimePullJSON)
        runtime.groupsSyncCycleRunner = { _ in counter.count += 1 }
        CloudSyncFlags.storageMode = .cloud
        defer { CloudSyncFlags._testResetStorageModeOverride() }
        _ = await runtime.syncCycle(context: context)
        #expect(counter.count == 0)
    }

    /// M1 / D8 (G5-C) — flag ON: la secundaria OPERATIVA (store secundario MONTADO — post-relaunch) SÍ
    /// participa. El loop propio arranca cuando el personal NO cadencia (`syncRuntimeEnabled` OFF en la
    /// porción del loop — como la fase transicional) Y el piggyback del paso 5.6 alcanza a la invitada.
    /// H-2026-07-18-4: antes este test dependía de `canRunDomain()==false` POR mount-mismatch para que el
    /// loop propio arrancara — celda que el guard D8 de `startIfEligible` ahora bloquea ANTES (correcto:
    /// la ventana de entrada jamás debe drenar; su celda vive en el test de mount-mismatch de abajo).
    @Test func secondarySession_flagOn_runsLoopAndPiggyback() async throws {
        let prevRuntime = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.groupsBackendEnabled = true
        CloudSyncFlags.syncRuntimeEnabled = false  // personal no cadencia → Grupos corre loop PROPIO
        SecondarySessionStore._testSetActiveOverride(true)
        SwiftDataConfiguration._testSetSecondaryStoreMounted(true)  // secundaria OPERATIVA (D8 no bloquea)
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            CloudSyncFlags.syncRuntimeEnabled = prevRuntime
            SecondarySessionStore._testSetActiveOverride(nil)
            SwiftDataConfiguration._testSetSecondaryStoreMounted(false)
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        // 401 → el loop termina solo tras la primera vuelta (sin sleeps reales).
        let stub = StubSession(emptyPageJSON, status: 401)
        let client = makeClient(session: stub, userID: nil)
        client.sleeper = { _ in }
        client.startIfEligible(context: context)
        let task = client._testLoopTask
        #expect(task != nil)                  // loop PROPIO arrancó bajo la invitada
        await task?.value
        #expect(stub.callCount >= 1)          // y cicló de verdad

        // Piggyback: el paso 5.6 SÍ invoca al runner en secundaria con flag ON (runtime restaurado —
        // el gate del 5.6 es solo el flag, pero se conserva el entorno del test original).
        CloudSyncFlags.syncRuntimeEnabled = prevRuntime
        let counter = Counter()
        let runtime = makeRuntime(pullBody: emptyRuntimePullJSON)
        runtime.groupsSyncCycleRunner = { _ in counter.count += 1 }
        CloudSyncFlags.storageMode = .cloud
        defer { CloudSyncFlags._testResetStorageModeOverride() }
        _ = await runtime.syncCycle(context: context)
        #expect(counter.count == 1)
    }

    /// D8 (H-2026-07-18-4): VENTANA DE ENTRADA de la secundaria (descriptor activo, store del DUEÑO aún
    /// montado — testigo secundario `false`) → el (re)arranque mid-session NO corre aunque todo lo demás
    /// esté verde (flag ON, sesión viva, personal sin cadenciar — sin D8 el loop ARRANCARÍA, como prueba
    /// el test de arriba). Pinnea el guard en el cliente real, no solo en la lógica pura.
    @Test func secondarySession_flagOn_entryWindowMountMismatch_blocksOwnLoop() async throws {
        let prevRuntime = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.groupsBackendEnabled = true
        CloudSyncFlags.syncRuntimeEnabled = false  // sin piggyback → el ÚNICO blocker posible es D8
        SecondarySessionStore._testSetActiveOverride(true)
        SwiftDataConfiguration._testSetSecondaryStoreMounted(false)  // explícito: ventana de entrada
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            CloudSyncFlags.syncRuntimeEnabled = prevRuntime
            SecondarySessionStore._testSetActiveOverride(nil)
            SwiftDataConfiguration._testSetSecondaryStoreMounted(false)
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let stub = StubSession(emptyPageJSON, status: 401)
        let client = makeClient(session: stub, userID: nil)
        client.startIfEligible(context: context, trigger: "foreground")

        #expect(client._testLoopTask == nil)  // D8 bloqueó el (re)arranque mid-session
        #expect(stub.callCount == 0)          // ni un request (el guard corta ANTES del rehydrate/ciclo)
    }

    /// Paso 5.6: con flag ON (y no-secundaria) el performCycle del runtime personal invoca el ciclo de
    /// Grupos; con flag OFF NO lo invoca (byte-idéntico).
    @Test func runtimeCycle_invokesGroupsRunner_flagOnOnly() async throws {
        let prevRuntime = CloudSyncFlags.syncRuntimeEnabled
        CloudSyncFlags.syncRuntimeEnabled = true
        CloudSyncFlags.storageMode = .cloud
        SecondarySessionStore._testSetActiveOverride(false)
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            CloudSyncFlags.syncRuntimeEnabled = prevRuntime
            CloudSyncFlags._testResetStorageModeOverride()
            SecondarySessionStore._testSetActiveOverride(nil)
        }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let counter = Counter()

        // Flag ON → el runner corre exactamente 1 vez por ciclo.
        CloudSyncFlags.groupsBackendEnabled = true
        let runtimeOn = makeRuntime(pullBody: emptyRuntimePullJSON)
        runtimeOn.groupsSyncCycleRunner = { _ in counter.count += 1 }
        let outcomeOn = await runtimeOn.syncCycle(context: context)
        #expect(counter.count == 1)
        #expect(outcomeOn == .completed)  // el ciclo personal NO se contamina por el paso 5.6

        // Flag OFF → jamás (performCycle byte-idéntico).
        CloudSyncFlags.groupsBackendEnabled = false
        let runtimeOff = makeRuntime(pullBody: emptyRuntimePullJSON)
        runtimeOff.groupsSyncCycleRunner = { _ in counter.count += 1 }
        _ = await runtimeOff.syncCycle(context: context)
        #expect(counter.count == 1)  // sin cambios
    }

    // MARK: - (6) Backoff RPC [R5]

    private func makeRPCClient(session: SyncHTTPSession) -> (GroupsMembershipClient, delays: Counter) {
        let client = GroupsMembershipClient(tokenProvider: { "jwt" }, urlSession: session)
        let delays = Counter()
        client.sleeper = { _ in delays.count += 1 }
        return (client, delays)
    }

    private let joinOKJSON =
        "{\"group_id\":\"g1\",\"member_key\":\"mk\",\"status\":\"pendingApproval\",\"rebound\":false}"

    /// transient×2 (500) → 3er intento 200 = éxito (2 sleeps 1s/3s).
    @Test func rpcRetry_transientTwice_thenSuccess() async throws {
        let stub = SequenceStubSession(
            [.init(data: Data("{}".utf8), status: 500), .init(data: Data("{}".utf8), status: 500)],
            fallback: .init(data: Data(joinOKJSON.utf8), status: 200))
        let (client, delays) = makeRPCClient(session: stub)
        let result = try await client.joinGroup(token: "t", displayName: "Bob", legacyMemberKey: nil)
        #expect(result.memberKey == "mk")
        #expect(stub.callCount == 3)
        #expect(delays.count == 2)
    }

    /// Permanente (400 yala_*) → 0 retries, 0 sleeps (reintentarlo sería loop).
    @Test func rpcRetry_permanent_noRetry() async throws {
        let stub = StubSession("{\"error\":{\"message\":\"yala_invalid_invite\",\"code\":\"yala_invalid_invite\"}}",
                               status: 400)
        let (client, delays) = makeRPCClient(session: stub)
        await #expect(throws: GroupsRPCError.invalidInvite) {
            _ = try await client.joinGroup(token: "bad", displayName: "Bob", legacyMemberKey: nil)
        }
        #expect(stub.callCount == 1)
        #expect(delays.count == 0)
    }

    /// Agotamiento: 3 intentos transitorios → sube `.transient` al call-site (2 sleeps).
    @Test func rpcRetry_exhaustion_surfacesTransient() async throws {
        let stub = StubSession("{}", status: 502)
        let (client, delays) = makeRPCClient(session: stub)
        await #expect(throws: GroupsRPCError.transient(status: 502)) {
            _ = try await client.joinGroup(token: "t", displayName: "Bob", legacyMemberKey: nil)
        }
        #expect(stub.callCount == 3)
        #expect(delays.count == 2)
    }

    /// One-shots creadores con transporte sin respuesta (-1, el request PUDO llegar) → 0 retries
    /// (create_group_invite dejaría un token huérfano válido; create_group por simetría conservadora).
    @Test func rpcRetry_createGroupTransportFailure_neverRetries() async throws {
        let stub = ThrowingStubSession()
        let (client, delays) = makeRPCClient(session: stub)
        await #expect(throws: GroupsRPCError.transient(status: -1)) {
            _ = try await client.createGroup(
                groupID: "g", name: "n", currencyCode: "PEN", iconName: "star", colorHex: "#112233",
                displayName: "A", defaultSplitType: "equal", simplifyDebts: false,
                showDebtsInSingleCurrency: false, membersCanInvite: false)
        }
        #expect(stub.callCount == 1)
        #expect(delays.count == 0)

        let stub2 = ThrowingStubSession()
        let (client2, delays2) = makeRPCClient(session: stub2)
        await #expect(throws: GroupsRPCError.transient(status: -1)) {
            _ = try await client2.createInvite(groupID: "g", ttlSeconds: 3600, maxUses: nil)
        }
        #expect(stub2.callCount == 1)
        #expect(delays2.count == 0)
    }

    /// MEDIUM-1 del review: `create_group_invite` NO reintenta NINGÚN transitorio — un 502 puede ser un
    /// ack perdido POST-COMMIT del salto gateway↔PostgREST (el RPC genera token NUEVO en cada llamada:
    /// un retry dejaría un token HUÉRFANO VÁLIDO = credencial de unión no intencionada).
    @Test func rpcRetry_createInvite502_neverRetries() async throws {
        let stub = StubSession("{}", status: 502)
        let (client, delays) = makeRPCClient(session: stub)
        await #expect(throws: GroupsRPCError.transient(status: 502)) {
            _ = try await client.createInvite(groupID: "g", ttlSeconds: 3600, maxUses: nil)
        }
        #expect(stub.callCount == 1)  // un solo intento — jamás retry de un one-shot creador
        #expect(delays.count == 0)

        // create_group ídem (simetría conservadora — el server ya lo hace seguro con yala_group_exists).
        let stub2 = StubSession("{}", status: 500)
        let (client2, delays2) = makeRPCClient(session: stub2)
        await #expect(throws: GroupsRPCError.transient(status: 500)) {
            _ = try await client2.createGroup(
                groupID: "g", name: "n", currencyCode: "PEN", iconName: "star", colorHex: "#112233",
                displayName: "A", defaultSplitType: "equal", simplifyDebts: false,
                showDebtsInSingleCurrency: false, membersCanInvite: false)
        }
        #expect(stub2.callCount == 1)
        #expect(delays2.count == 0)
    }

    /// Un RPC idempotente (approve_member) SÍ reintenta el transporte -1.
    @Test func rpcRetry_idempotentTransportFailure_retries() async throws {
        let stub = ThrowingStubSession()
        let (client, delays) = makeRPCClient(session: stub)
        await #expect(throws: GroupsRPCError.transient(status: -1)) {
            _ = try await client.approveMember(groupID: "g", memberKey: "mk")
        }
        #expect(stub.callCount == 3)  // intento + 2 retries
        #expect(delays.count == 2)
    }

    // MARK: - Runtime helper (piggyback)

    private let emptyRuntimePullJSON = "{\"deltas\":[],\"max_server_seq\":0}"

    private final class HardeningStubCloudSession: CloudSyncSessionProviding {
        var currentUserID: String? { "u1" }
        func accessToken() async -> String? { "jwt" }
        var canRenewSession: Bool { true }
        func attestToken() async throws -> String? { nil }
        var claimAction: AccountClaimDecision.AuthAction? { .routeReturningUser }
    }

    private func makeRuntime(pullBody: String) -> CloudSyncRuntime {
        CloudSyncRuntime(
            engine: CloudSyncEngine(),
            pushClient: SyncPushClient(baseURL: URL(string: "https://x.test")!,
                                       tokenProvider: { "jwt" }, urlSession: StubSession("{\"results\":[]}")),
            pullClient: SyncPullClient(baseURL: URL(string: "https://x.test")!,
                                       tokenProvider: { "jwt" }, urlSession: StubSession(pullBody)),
            merkleClient: SyncMerkleClient(baseURL: URL(string: "https://x.test")!,
                                           tokenProvider: { "jwt" }, urlSession: StubSession("{}")),
            mirror: nil,
            coordinator: SyncQuiescenceCoordinator(icloudQuiescent: { true }, modeProvider: { .icloud }),
            session: HardeningStubCloudSession(),
            onRemoteChangesApplied: nil)
    }
}
