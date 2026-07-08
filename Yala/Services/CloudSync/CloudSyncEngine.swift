//
//  CloudSyncEngine.swift
//  Yala
//
//  Motor de CAPTURA del Modo Nube (incremento I3). Lee el SwiftData History del ModelContainer
//  (write→drain) y traduce cada cambio de las 6 entidades sincronizables en una fila de `SyncOutbox`
//  (upsert / tombstone) lista para reenviarse al backend (el sender llega en I8). DARK: nada de
//  producción lo instancia todavía — el wiring del ciclo de vida llega en I9/I12.
//
//  Una instancia por proceso (NO un singleton global; el owner del ciclo de vida llega en I9/I12).
//  Patrón "one in-flight, one queued" (§a.4): `drainOnce` re-entrante coalescea a lo sumo una vuelta
//  pendiente. Todo `@MainActor` (manipula `ModelContext` / `@Model`, regla inviolable del repo).
//
//  Reloj HLC EN-MEMORIA por instancia: se acuña un `NodeID` nuevo por instancia y el `HLCClock` parte
//  fresco (`latest = nil`). La persistencia del reloj y `receive()` (integrar HLCs remotos) llegan en
//  I8. Consecuencia CLAVE de resumibilidad: con reloj fresco, RE-procesar el mismo History en el
//  mismo orden produce HLCs IDÉNTICOS (los timestamps de las transacciones y el orden son estables)
//  → tras un kill (proceso reiniciado = instancia+reloj frescos), el re-drain reproduce las mismas
//  filas y la deduplicación por (syncID, hlc, op) las absorbe sin duplicar.
//
//  I4: el tombstone lleva op + syncID preservado + `reason` clasificado 100% DRAIN-SIDE
//  (`classifyTombstoneReason`, taxonomía §c.1: user | cascade | dedup | migration | wipe). La
//  clasificación NO toca los ~30 call-sites de delete de producción (cero cambios en
//  `EntityDeletionService` ni vistas). `dedup`/`wipe` se afinan en I9/I12 (comentario-guardia).
//
//  Frontera I3/I8: `fieldsJSON` es un STUB estructurado (JSON `{prop: descripción}` sin `syncID`);
//  el espejo App Group `.atomic` previo al insert; el sender; el `serverSeqCursor` del pull; y el
//  reconcile real del token expirado llegan en I8. Comentarios-guardia marcan cada punto de enganche.
//

import Foundation
import OSLog
import SwiftData

// MARK: - Errores nombrados

/// Errores del cursor de captura. Nombrados (nunca silenciados) para el path §d.6.
nonisolated enum CloudSyncCursorError: Error, Equatable {
    /// El token persistido no se pudo decodificar o el fetch por token falló (migración destructiva,
    /// incompatibilidad de versión) → reconcile: en I3 se re-escanea el History completo (dedup lo
    /// hace seguro); el reconcile real (§d.6) llega en I8.
    case historyTokenExpired
}

// MARK: - Breadcrumb (Console.app, fuera de #if DEBUG, sin PII)

/// Rastros de diagnóstico del motor de captura. Fuera de `#if DEBUG` a PROPÓSITO (espeja `SaveBreadcrumb`
/// / `SplitSync*`): el comportamiento del pipeline solo se valida del todo en device/TestFlight. Sin PII
/// (solo tipos de entidad, counts, seq — nunca valores de usuario).
@MainActor
enum CloudSyncBreadcrumb {
    private static let logger = Logger(subsystem: "com.yala", category: "CloudSync")

    /// Una vuelta de drain terminó: número de secuencia + filas de outbox pendientes tras la vuelta.
    static func drain(seq: Int, pending: Int) {
        logger.notice("CloudSync drain seq=\(seq, privacy: .public) pending=\(pending, privacy: .public)")
    }

    /// Un delete llegó sin `syncID` preservado en el tombstone → no se pudo emitir el tombstone.
    static func identityGap(entityType: String, reason: String) {
        logger.notice("CloudSyncIdentityGap \(entityType, privacy: .public) reason=\(reason, privacy: .public)")
    }

    /// El token del cursor expiró/no decodificó → reconcile (re-escaneo completo en I3).
    static func historyTokenExpired() {
        logger.notice("CloudSync historyTokenExpired — reconcile (full rescan)")
    }
}

// MARK: - CloudSyncEngine

@MainActor
final class CloudSyncEngine {

    // MARK: Constantes de captura

    /// Autor del CONTEXTO con el que el motor persiste sus propias filas de outbox. La captura DESCARTA
    /// las transacciones de History con este autor → anti-auto-captura (echo suppression): cuando el
    /// apply de cambios remotos (I8) escriba entidades personales bajo este autor, no se re-capturarán.
    static let outboxSaveAuthor = "CloudSyncOutbox"

    /// Los 16 entity names del store PERSONAL. La captura DESCARTA todo cambio cuyo entity name NO esté
    /// aquí — anti-fuga de Grupos. El History token es por-CONTAINER (personal + grupos + sync-meta en
    /// un solo ModelContainer), así que este filtro es PERMANENTE (no una optimización): sin él, los
    /// cambios de los `Split*` (store de grupos) se colarían al backend personal.
    ///
    /// De estos 16, SOLO 6 llevan `syncID` y se TRADUCEN a outbox en I3 (ver `SyncEntityType`); los
    /// otros 10 pasan el filtro anti-fuga pero aún no tienen identidad de sync → se ignoran en la
    /// traducción (incrementos posteriores los añaden). Anclado contra `personalSchema` por
    /// `CloudSyncSchemaParityTests`.
    static let personalEntityNames: Set<String> = [
        "Category",
        "Subcategory",
        "Tag",
        "Account",
        "TransactionItem",
        "Budget",
        "ExchangeRate",
        "FavoritePayment",
        "ScheduledPayment",
        "InboxDraft",
        "MerchantMemory",
        "NotificationItem",
        "CashFlowPlan",
        "CashFlowLine",
        "CashFlowOverride",
        "GroupBridgePreference",
    ]

    // MARK: Clasificación del reason de tombstone (§c.1) — 100% DRAIN-SIDE

    /// Entity names PADRE de una cascada MANUAL cuyos hijos syncables se borran en el MISMO `save()`
    /// (= misma transacción de History). Si una transacción borra uno de estos, los tombstones de las
    /// 6 entidades syncables producidos en ESA transacción se clasifican `cascade`.
    ///
    /// Inventario VERIFICADO contra `EntityDeletionService.swift` (2026-07-07):
    ///   • `ScheduledPayment` — `deleteScheduledPayment` borra `InboxDraft` (línea 253) y
    ///     `TransactionItem` (línea 274) y luego el pago (línea 285) en UN solo `save()`. Ambos hijos
    ///     SON syncables → `cascade`. ÚNICO padre verificado.
    /// EXCLUIDOS (no borran hijos syncables o no son deletes):
    ///   • `deleteTag` (Tag NO es syncable; los TX/drafts/favoritos se ACTUALIZAN, no se borran → upsert).
    ///   • `deleteCategory`/`deleteSubcategory`/`deleteAccount`/`deleteBudget` (los hijos son
    ///     Subcategory/nullify, no deletes de syncables; el propio Category borrado es el delete de nivel
    ///     superior pedido por el usuario, no una cascada).
    ///   • cascada de SCHEMA `CashFlowPlan → CashFlowLine → CashFlowOverride` (ninguna es syncable).
    ///   • `SubcategoryTransferViewModel.deleteTransactions` (borra TX sin borrar un padre en el mismo
    ///     save → bulk del usuario = `user`).
    ///   • `CategoryDeduplicationService` (I9 → `dedup`) / `DataWipeService` (I12 → `wipe`): sin señal de
    ///     call-site hoy → caen en `user`/`cascade`. Comentario-guardia: I9/I12 marcarán un author
    ///     dedicado y esta clasificación se afinará entonces (el reason es metadata de auditoría — la
    ///     clasificación conservadora NO compromete correctness: el backend mantiene `deleted=true` igual).
    static let cascadeParentEntityNames: Set<String> = [
        "ScheduledPayment",
    ]

    /// Authors cuyas transacciones se clasifican `migration`. Bucket por COMPLETITUD (§c.1): hoy solo
    /// `outboxSaveAuthor` caería aquí, pero sus transacciones ya se DESCARTAN por echo-suppression
    /// antes de clasificar → de facto inalcanzable. Reservado para el author dedicado de la migración
    /// (I10). El delete-vs-cascade se decide DESPUÉS de este gate.
    static let migrationAuthors: Set<String> = [
        outboxSaveAuthor,
    ]

    // MARK: Estado

    /// Reloj HLC en-memoria de esta instancia (fresco; persistencia + `receive()` en I8).
    private var clock: HLCClock

    /// Contador de vueltas de drain (para el breadcrumb).
    private var drainSeq = 0

    /// Número de gaps de identidad observados (delete sin syncID preservado). Expuesto para tests
    /// (el logger no es asertable). Acumula a lo largo de la vida de la instancia.
    private(set) var identityGapCount = 0

    // MARK: Coalescing "one in-flight, one queued"

    private var isDraining = false
    private var pendingDrain = false

    // MARK: Seams de test

    /// Cuando `true`, `drainOnce` NO avanza el token del cursor tras persistir el outbox — simula un
    /// kill entre el save del outbox y el avance del token. SOLO para tests.
    var _testSuppressTokenAdvance = false

    // MARK: Init

    init(nodeID: NodeID = NodeID.generate()) {
        self.clock = HLCClock(nodeID: nodeID)
    }

    // MARK: - API pública (coalescing)

    /// Ejecuta UNA vuelta de captura. Re-entrante: si ya hay una vuelta en curso, marca una pendiente
    /// (a lo sumo una) y retorna; la vuelta en curso la ejecuta al terminar (§a.4). Bajo `@MainActor`
    /// síncrono la re-entrada real no ocurre hoy, pero el patrón queda listo para el wiring de I9/I12.
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

    // MARK: - Núcleo del drain

    private func performDrain(context: ModelContext) {
        drainSeq += 1
        do {
            // 1) Cursor + token persistido.
            let cursor = try loadOrCreateCursor(context)
            let token = decodeToken(cursor.historyTokenData)

            // 2) Barrido defensivo: asigna syncID a las filas vivas de los 6 tipos que aún no lo tengan
            //    (SIN autor especial → la próxima vuelta captura ese cambio), y construye los índices
            //    persistentID→modelo que usa la traducción. Save con autor por DEFECTO (no es outbox).
            let lookups = try sweepAndBuildLookups(context)

            // 3) History posterior al token (o completo si nil / token expirado).
            let txns = try fetchHistory(after: token, context: context)

            // 4) Pre-siembra del dedup con las filas de outbox YA existentes (kill-replay: absorbe las
            //    filas persistidas en un drain previo cuyo token no llegó a avanzar).
            var seen = try existingOutboxKeys(context)

            // 5) Traducción, transacción a transacción y en orden. `advancedToken` = high-water de la
            //    history EXTERNA consumida (nil = no se consumió nada externo esta vuelta). Las
            //    transacciones que escribió el propio motor (`author == outboxSaveAuthor`: outbox +
            //    cursor) se DESCARTAN y NO avanzan el high-water → convergencia: un drain ocioso re-lee
            //    solo sus propios writes (0 filas) y no vuelve a mover/escribir el cursor. Criterio de
            //    drift: si `clock.send` lanza, NO se consume esa transacción (el high-water se queda
            //    antes de ella) → se reintenta al próximo drain.
            var rows: [PendingOutboxRow] = []
            var advancedToken: DefaultHistoryToken?
            for tx in txns {
                // Anti-auto-captura (echo suppression): descartar los writes del propio motor. NO
                // avanzan el high-water (si lo hicieran, cada avance escribiría el cursor → loop).
                if tx.author == Self.outboxSaveAuthor { continue }
                // Clasificación del reason de tombstone: UNA vez por transacción (el reason depende del
                // CONJUNTO de deletes de la transacción, no del change individual). §c.1.
                let tombstoneReason = Self.classifyTombstoneReason(tx)
                var txRows: [PendingOutboxRow] = []
                do {
                    for change in tx.changes {
                        let entityName = change.changedPersistentIdentifier.entityName
                        // Anti-fuga de Grupos: solo entidades del store personal.
                        guard Self.personalEntityNames.contains(entityName) else { continue }
                        try translate(change, entityName: entityName, tx: tx,
                                      tombstoneReason: tombstoneReason,
                                      lookups: lookups, rows: &txRows, seen: &seen)
                    }
                } catch {
                    // `clock.send` lanzó (drift/overflow): abortar en la FRONTERA de esta transacción.
                    // No consumimos `tx` (advancedToken se queda antes de ella) ni sus filas parciales.
                    #if DEBUG
                    print("CloudSyncEngine: clock drift/overflow al traducir tx \(tx.token): \(error)")
                    #endif
                    break
                }
                rows.append(contentsOf: txRows)
                // Transacción externa consumida (produzca filas o no — p.ej. anti-fuga, syncID-only,
                // o un gap): avanza el high-water para no re-procesarla (evita recontar gaps).
                advancedToken = tx.token
            }

            // 6) Persistir las filas del outbox (autor del motor → anti-auto-captura + no re-lectura).
            //    COMENTARIO-GUARDIA (hook A1, I8): el espejo App Group `.atomic` va AQUÍ, ANTES del
            //    insert+save, en el MISMO cuerpo síncrono sin `await` (regla Q3 del spike S-A1) — así
            //    autosave no puede invertir el orden fila-durable-sin-espejo.
            if !rows.isEmpty {
                try saveWithAuthor(context, Self.outboxSaveAuthor) {
                    for row in rows { context.insert(row.makeModel()) }
                }
            }

            // 7) Avanzar el token SOLO tras persistir el outbox (crash entre 6 y 7 → el re-drain re-crea
            //    idempotente por el dedup), y SOLO si se consumió history externa (advancedToken != nil).
            //    El save del cursor lleva `outboxSaveAuthor` → no se re-lee. Suprimible en tests (kill).
            if !_testSuppressTokenAdvance, let advancedToken {
                try saveWithAuthor(context, Self.outboxSaveAuthor) {
                    cursor.historyTokenData = try encodeToken(advancedToken)
                }
            }

            // Count SOLO para el breadcrumb de diagnóstico. Sin `try?` que silencie (regla inviolable):
            // do/catch con fallback a `rows.count` (nunca aborta el drain por un fallo de conteo).
            let pending: Int
            do {
                pending = try context.fetchCount(FetchDescriptor<SyncOutbox>())
            } catch {
                #if DEBUG
                print("CloudSyncEngine: fetchCount(SyncOutbox) para breadcrumb falló: \(error)")
                #endif
                pending = rows.count
            }
            CloudSyncBreadcrumb.drain(seq: drainSeq, pending: pending)
        } catch {
            #if DEBUG
            print("CloudSyncEngine: drain error: \(error)")
            #endif
        }
    }

    // MARK: - Clasificación del reason de tombstone (§c.1, drain-side)

    /// Deriva el `reason` de los tombstones de UNA transacción (§c.1). Precedencia: `migration` (author
    /// del motor/migración) → `cascade` (la transacción borra un tipo padre de cascada conocida) →
    /// `user` (default). `dedup`/`wipe` NO son clasificables hoy sin señal de call-site (I9/I12) → caen
    /// en `user`/`cascade`. Es metadata de auditoría: una clasificación conservadora no compromete la
    /// correctness (el backend mantiene `deleted=true` igual). Estático + puro → testeable en aislamiento
    /// del ciclo del drain no es trivial (requiere `DefaultHistoryTransaction`), así que los goldens lo
    /// ejercitan end-to-end vía el drain real.
    private static func classifyTombstoneReason(_ tx: DefaultHistoryTransaction) -> SyncTombstoneReason {
        // migration: author dedicado del motor/migración (bucket por completitud; ver `migrationAuthors`).
        if let author = tx.author, migrationAuthors.contains(author) {
            return .migration
        }
        // cascade: la transacción TAMBIÉN borra un tipo padre de cascada conocida.
        for change in tx.changes {
            guard case .delete = change else { continue }
            if cascadeParentEntityNames.contains(change.changedPersistentIdentifier.entityName) {
                return .cascade
            }
        }
        return .user
    }

    // MARK: - Traducción de un cambio (dispatch por tipo concreto)

    /// Índices persistentID→modelo de los 6 tipos sincronizables (construidos en el barrido).
    private struct Lookups {
        var transactionItem: [PersistentIdentifier: TransactionItem] = [:]
        var inboxDraft: [PersistentIdentifier: InboxDraft] = [:]
        var category: [PersistentIdentifier: Category] = [:]
        var favoritePayment: [PersistentIdentifier: FavoritePayment] = [:]
        var merchantMemory: [PersistentIdentifier: MerchantMemory] = [:]
        var exchangeRate: [PersistentIdentifier: ExchangeRate] = [:]
    }

    /// Despacha el cambio al handler concreto por entity name. Los tipos personales sin `syncID` (los
    /// 10 restantes) caen al `default` y se ignoran (aún sin identidad de sync — incrementos futuros).
    private func translate(
        _ change: HistoryChange,
        entityName: String,
        tx: DefaultHistoryTransaction,
        tombstoneReason: SyncTombstoneReason,
        lookups: Lookups,
        rows: inout [PendingOutboxRow],
        seen: inout Set<String>
    ) throws {
        switch entityName {
        case SyncEntityType.transactionItem:
            try translateChange(change, type: TransactionItem.self, entityType: entityName,
                                syncIDKeyPath: \.syncID, insertFields: Self.transactionItemFields,
                                lookup: lookups.transactionItem, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.inboxDraft:
            try translateChange(change, type: InboxDraft.self, entityType: entityName,
                                syncIDKeyPath: \.syncID, insertFields: Self.inboxDraftFields,
                                lookup: lookups.inboxDraft, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.category:
            try translateChange(change, type: Category.self, entityType: entityName,
                                syncIDKeyPath: \.syncID, insertFields: Self.categoryFields,
                                lookup: lookups.category, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.favoritePayment:
            try translateChange(change, type: FavoritePayment.self, entityType: entityName,
                                syncIDKeyPath: \.syncID, insertFields: Self.favoritePaymentFields,
                                lookup: lookups.favoritePayment, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.merchantMemory:
            try translateChange(change, type: MerchantMemory.self, entityType: entityName,
                                syncIDKeyPath: \.syncID, insertFields: Self.merchantMemoryFields,
                                lookup: lookups.merchantMemory, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.exchangeRate:
            try translateChange(change, type: ExchangeRate.self, entityType: entityName,
                                syncIDKeyPath: \.syncID, insertFields: Self.exchangeRateFields,
                                lookup: lookups.exchangeRate, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        default:
            // Personal-pero-aún-sin-identidad (los 10 restantes de los 16). No se traduce en I3.
            return
        }
    }

    /// Traduce UN cambio de un tipo concreto `T` a (a lo sumo) una fila de outbox.
    private func translateChange<T: PersistentModel & SyncIdentifiable>(
        _ change: HistoryChange,
        type: T.Type,
        entityType: String,
        syncIDKeyPath: KeyPath<T, UUID?>,
        insertFields: (T) -> [String: String],
        lookup: [PersistentIdentifier: T],
        tx: DefaultHistoryTransaction,
        tombstoneReason: SyncTombstoneReason,
        rows: inout [PendingOutboxRow],
        seen: inout Set<String>
    ) throws {
        switch change {
        case .insert(let insert):
            // El entityName ya coincide; el `is` confirma el tipo concreto (defensivo).
            guard insert is DefaultHistoryInsert<T> else { return }
            guard let model = lookup[insert.changedPersistentIdentifier] else { return }  // borrada → skip
            guard let syncID = model[keyPath: syncIDKeyPath] else { return }  // sin identidad → skip
            let fields = insertFields(model)  // colección estable (NUNCA incluye syncID)
            guard !fields.isEmpty else { return }
            try appendRow(op: .upsert, syncID: syncID, entityType: entityType,
                          fields: fields, tx: tx, rows: &rows, seen: &seen)

        case .update(let update):
            guard let typed = update as? DefaultHistoryUpdate<T> else { return }
            guard let model = lookup[typed.changedPersistentIdentifier] else { return }
            guard let syncID = model[keyPath: syncIDKeyPath] else { return }
            // Propiedades cambiadas EXCLUYENDO syncID (es la PK del upsert, no columna de dominio).
            let syncIDPartial = syncIDKeyPath as PartialKeyPath<T>
            let changedKeyPaths = typed.updatedAttributes.filter { ($0 as PartialKeyPath<T>) != syncIDPartial }
            // Si solo cambió syncID (p.ej. el barrido lo acuñó) → set vacío → SKIP (no crear fila).
            guard !changedKeyPaths.isEmpty else { return }
            var fields: [String: String] = [:]
            for keyPath in changedKeyPaths {
                let partial = keyPath as PartialKeyPath<T>
                // STUB (I8 → codec c1): nombre best-effort del keypath + descripción del valor actual.
                fields[String(describing: partial)] = String(describing: model[keyPath: partial])
            }
            guard !fields.isEmpty else { return }
            try appendRow(op: .upsert, syncID: syncID, entityType: entityType,
                          fields: fields, tx: tx, rows: &rows, seen: &seen)

        case .delete(let delete):
            guard let typed = delete as? DefaultHistoryDelete<T> else { return }
            // Identidad preservada vía `.preserveValueOnDeletion` (spike S1/S4).
            guard let syncID = typed.tombstone[syncIDKeyPath] as? UUID else {
                recordIdentityGap(entityType: entityType, reason: "tombstoneSyncIDNil")
                return
            }
            // Tombstone (I4): op + syncID + `reason` clasificado drain-side (§c.1), sin payload de campos.
            try appendRow(op: .tombstone, syncID: syncID, entityType: entityType,
                          fields: [:], tombstoneReason: tombstoneReason,
                          tx: tx, rows: &rows, seen: &seen)

        @unknown default:
            // `HistoryChange` puede ganar casos nuevos (Swift 6): ignorar defensivamente.
            return
        }
    }

    /// Acuña el HLC (ÚNICO punto que llama `clock.send` → advance determinista y en orden), deduplica
    /// por (syncID, hlc, op) y encola una fila pendiente. `clock.send` puede lanzar `ClockDriftError`
    /// → se propaga al llamador (criterio de drift del drain).
    private func appendRow(
        op: SyncOutboxOp,
        syncID: UUID,
        entityType: String,
        fields: [String: String],
        tombstoneReason: SyncTombstoneReason? = nil,
        tx: DefaultHistoryTransaction,
        rows: inout [PendingOutboxRow],
        seen: inout Set<String>
    ) throws {
        // Advance del reloj: SIEMPRE tras pasar los guards estructurales y ANTES del dedup, de modo que
        // dos instancias frescas procesando el mismo History avanzan el reloj en lockstep → HLCs
        // idénticos (invariante de resumibilidad). El HLC queda FIJADO en la fila (§d.5).
        let hlc = try clock.send(now: tx.timestamp).description
        let key = dedupKey(syncID: syncID, hlc: hlc, op: op)
        guard !seen.contains(key) else { return }
        seen.insert(key)
        rows.append(PendingOutboxRow(
            syncID: syncID,
            entityType: entityType,
            op: op,
            hlc: hlc,
            fieldsJSON: encodeFields(fields),
            author: tx.author ?? "",
            // Solo los tombstones llevan reason (upsert → nil). Defensivo: aunque el llamador pasara un
            // reason con op:upsert, se descarta (el reason es semántica exclusiva del tombstone).
            tombstoneReason: op == .tombstone ? tombstoneReason?.rawValue : nil
        ))
    }

    private func recordIdentityGap(entityType: String, reason: String) {
        identityGapCount += 1
        CloudSyncBreadcrumb.identityGap(entityType: entityType, reason: reason)
        // Canario TelemetryDeck (no-op en tests: `track` retorna si el servicio no está configurado).
        TelemetryService.cloudSyncIdentityGapObserved(entityType: entityType)
    }

    // MARK: - Barrido defensivo + índices

    private func sweepAndBuildLookups(_ context: ModelContext) throws -> Lookups {
        var lookups = Lookups()
        lookups.transactionItem = try sweepType(TransactionItem.self, context: context)
        lookups.inboxDraft = try sweepType(InboxDraft.self, context: context)
        lookups.category = try sweepType(Category.self, context: context)
        lookups.favoritePayment = try sweepType(FavoritePayment.self, context: context)
        lookups.merchantMemory = try sweepType(MerchantMemory.self, context: context)
        lookups.exchangeRate = try sweepType(ExchangeRate.self, context: context)
        if context.hasChanges {
            // Autor por DEFECTO (no `outboxSaveAuthor`): el cambio de syncID DEBE quedar en el History
            // para que la próxima vuelta lo procese (y lo salte por ser syncID-only), no ocultarse.
            try context.save()
        }
        return lookups
    }

    /// Fetch CONCRETO por tipo (nunca genérico sobre keypath de protocolo — regla inviolable de
    /// `#Predicate`; patrón `SyncIdentityService`). Asigna syncID a los nil y devuelve el índice.
    private func sweepType<T: PersistentModel & SyncIdentifiable>(
        _ type: T.Type, context: ModelContext
    ) throws -> [PersistentIdentifier: T] {
        let models = try context.fetch(FetchDescriptor<T>())
        var map: [PersistentIdentifier: T] = [:]
        for model in models {
            if model.syncID == nil {
                model.syncID = UUID()
            }
            map[model.persistentModelID] = model
        }
        return map
    }

    // MARK: - Cursor / token

    private func loadOrCreateCursor(_ context: ModelContext) throws -> SyncCursor {
        var descriptor = FetchDescriptor<SyncCursor>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let cursor = SyncCursor()
        context.insert(cursor)
        // Persistir de inmediato para no crear un segundo single-row si el drain no avanza el token.
        // Autor del motor → esta creación NO se re-lee como history externa.
        try saveWithAuthor(context, Self.outboxSaveAuthor) { }
        return cursor
    }

    /// Ejecuta `body` y hace `context.save()` bajo un `author` dado, restaurando el autor previo.
    /// Centraliza el manejo de `context.author` para los saves internos del motor.
    private func saveWithAuthor(
        _ context: ModelContext, _ author: String, _ body: () throws -> Void
    ) throws {
        let previous = context.author
        context.author = author
        defer { context.author = previous }
        try body()
        try context.save()
    }

    private func decodeToken(_ data: Data?) -> DefaultHistoryToken? {
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(DefaultHistoryToken.self, from: data)
        } catch {
            // Token no decodificable → path expirado (reconcile completo en I3 = escaneo total).
            CloudSyncBreadcrumb.historyTokenExpired()
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
                HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token > token })
            )
        } catch {
            // Fetch por token falló (token incompatible tras migración) → reconcile: escaneo completo.
            CloudSyncBreadcrumb.historyTokenExpired()
            return try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        }
    }

    // MARK: - Dedup / encoding

    private func existingOutboxKeys(_ context: ModelContext) throws -> Set<String> {
        let existing = try context.fetch(FetchDescriptor<SyncOutbox>())
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

    /// STUB (I8 → codec canónico c1): JSON `{prop: descripción}` con claves ordenadas (determinista).
    private func encodeFields(_ fields: [String: String]) -> String {
        guard !fields.isEmpty else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(fields)
            return String(decoding: data, as: UTF8.self)
        } catch {
            #if DEBUG
            print("CloudSyncEngine: encodeFields error: \(error)")
            #endif
            return "{}"
        }
    }

    // MARK: - Colecciones de campos por tipo (STUB de inserts)
    //
    // Colección ESTABLE de campos de dominio por entidad (equivalente al `updatedAttributes` que un
    // update sí trae). NUNCA incluye `syncID`. Garantiza ≥1 clave → un insert siempre produce una
    // fila (salvo que el modelo ya no exista o no tenga identidad). I8 lo reemplaza por el codec c1.

    private static func transactionItemFields(_ m: TransactionItem) -> [String: String] {
        [
            "amount": String(describing: m.amount),
            "currencyCode": m.currencyCode,
            "date": SyncContentAnchor.canonicalDate(m.date),
        ]
    }

    private static func inboxDraftFields(_ m: InboxDraft) -> [String: String] {
        [
            "sourceTypeRaw": m.sourceTypeRaw,
            "rawText": m.rawText ?? "",
        ]
    }

    private static func categoryFields(_ m: Category) -> [String: String] {
        ["name": m.name]
    }

    private static func favoritePaymentFields(_ m: FavoritePayment) -> [String: String] {
        [
            "name": m.name,
            "amount": String(describing: m.amount),
        ]
    }

    private static func merchantMemoryFields(_ m: MerchantMemory) -> [String: String] {
        ["merchantCanonical": m.merchantCanonical]
    }

    private static func exchangeRateFields(_ m: ExchangeRate) -> [String: String] {
        [
            "dateKey": m.dateKey,
            "base": m.base,
        ]
    }
}

// MARK: - PendingOutboxRow

/// Fila de outbox acumulada en memoria durante un drain, materializada a `@Model` al persistir.
/// Struct simple (no `@Model`) para separar la fase de traducción de la de inserción.
private struct PendingOutboxRow {
    let syncID: UUID
    let entityType: String
    let op: SyncOutboxOp
    let hlc: String
    let fieldsJSON: String
    let author: String
    let tombstoneReason: String?

    @MainActor
    func makeModel() -> SyncOutbox {
        SyncOutbox(
            syncID: syncID,
            entityType: entityType,
            op: op,
            hlc: hlc,
            fieldsJSON: fieldsJSON,
            author: author,
            tombstoneReason: tombstoneReason
        )
    }
}
