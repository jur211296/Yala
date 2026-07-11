//
//  MigrationSnapshotUploader.swift
//  Yala
//
//  Sube el SNAPSHOT completo (fila-por-fila, full-row) de las 16 entidades de dominio al backend en
//  batches idempotentes y RESUMIBLES (Modo Nube Fase 4, I10-wiring w4). Es el trabajo real de la fase
//  `uploadingSnapshot`: `MigrationWorkExecutor.uploadSnapshot(cursor:)` delega aquí.
//
//  Disciplina (plan w4):
//   - **Baseline de History ANTES de enumerar** (`engine.fastForwardHistoryBaseline`): cierra la ventana de
//     escrituras concurrentes — todo write posterior aparece en History y lo captura el drain como delta
//     INCREMENTAL (LWW converge aunque el snapshot ya lo incluyera). Se corre UNA vez al arrancar una pasada
//     (`cursor == nil`).
//   - **Enumeración determinista**: las 16 tablas en orden UTF-8 asc del nombre (mismo criterio que Merkle
//     A-4); dentro de cada entidad, filas ordenadas por identidad asc con **keyset pagination por
//     `afterSyncID`** (NUNCA offset — las filas pueden moverse). Página = `pageSize` filas.
//   - **Emisión full-row**: `DeltaEmitter.emit(changedColumns: emission.columns)` (INSERT = todas las
//     columnas) → `Canonc1Codec.encode` → fila `SyncOutbox` op `.upsert` vía el seam `enqueueSnapshotRows`
//     (HLC del reloj del motor, cmid fresco, `SyncUnitClock` + reloj en UN save — lockstep D-3).
//   - **Push por página**: `drainOnce` (captura incrementales pendientes) → push de TODAS las filas VIVAS
//     del outbox (página + incrementales juntos) → `applyResults` (confirm purga). SOLO si el outbox vivo
//     quedó VACÍO tras el push → `pageConfirmed(cursor)` (el RUNNER persiste el cursor; el uploader NO toca
//     el journal). Un dead-letter (rechazo definitivo) NO es fila viva → la página avanza y el mismatch
//     resultante en verify degradará a `failedRollback` — CORRECTO por diseño (jamás cutover con pérdida
//     silenciosa).
//   - **Convergencia con ediciones concurrentes**: una edición de fila aún-no-subida puede crear una fila
//     PARCIAL en el backend antes que su snapshot (PATCH del drain); converge porque el HLC del snapshot de
//     esa fila se acuña DESPUÉS (página posterior) → LWW por unidad hace ganar el estado local más reciente
//     en AMBAS direcciones.
//   - **Resumibilidad H5**: cursor `{table, afterSyncID}`. Kill entre enqueue y confirm → resume re-emite la
//     página con HLC nuevo → el RPC la resuelve por LWW (mismo contenido, converge). JAMÁS resumir por contador.
//

import Foundation
import SwiftData

@MainActor
final class MigrationSnapshotUploader {

    private let engine: CloudSyncEngine
    private let pushClient: SyncPushClient
    private let context: ModelContext
    private let calendar: Calendar
    private let now: () -> Date
    private let pageSize: Int

    /// Especificaciones de las 16 entidades, en orden de tabla UTF-8 asc (fijado en `init`).
    private lazy var specs: [SnapshotEntitySpec] = buildSpecs()

    init(
        engine: CloudSyncEngine,
        pushClient: SyncPushClient,
        context: ModelContext,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { .now },
        pageSize: Int = 200
    ) {
        self.engine = engine
        self.pushClient = pushClient
        self.context = context
        self.calendar = calendar
        self.now = now
        self.pageSize = max(1, pageSize)
    }

    // MARK: - Cursor

    /// Cursor opaco para el journal: tabla actual + última identidad confirmada de esa tabla.
    private struct SnapshotCursor: Codable, Equatable {
        let table: String
        let afterSyncID: String?
    }

    private func decodeCursor(_ json: String?) -> SnapshotCursor? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(SnapshotCursor.self, from: data)
        } catch {
            #if DEBUG
            print("MigrationSnapshotUploader: cursor decode falló (reinicio de pasada): \(error)")
            #endif
            return nil
        }
    }

    private func encodeCursor(_ cursor: SnapshotCursor) -> String {
        do {
            return String(decoding: try JSONEncoder().encode(cursor), as: UTF8.self)
        } catch {
            #if DEBUG
            print("MigrationSnapshotUploader: cursor encode falló: \(error)")
            #endif
            return "{}"
        }
    }

    // MARK: - API (delegada por el executor)

    /// Sube UNA página del snapshot desde `cursor` (`nil` = arranque de pasada → baseline + primera tabla).
    /// Outcomes mapeados 1:1 al seam del runner:
    ///   - `.pageConfirmed(cursor)` — la página se subió y confirmó; sigue habiendo trabajo (re-loop).
    ///   - `.completed` — no quedan páginas (residual del outbox también drenado/subido).
    ///   - `.transient` — push no-2xx / red / la página no quedó confirmada (el runner reintenta después).
    func uploadPage(cursor: String?) async -> SnapshotStepOutcome {
        let decoded = decodeCursor(cursor)
        // Baseline UNA vez al arrancar una pasada (cursor nil o no decodificable): cierra la ventana de
        // escrituras concurrentes ANTES de enumerar.
        if decoded == nil {
            engine.fastForwardHistoryBaseline(context: context)
        }

        let (startIndex, afterSyncID) = resolveStart(decoded)
        let page = nextPage(fromTableIndex: startIndex, afterSyncID: afterSyncID, limit: pageSize)

        guard let page else {
            // No quedan páginas → drenar y subir el residual (incrementales tardíos) y cerrar.
            return await finishResidual()
        }

        // Encolar la página (full-row) en el outbox vía el seam del motor. Un drift del reloj → transient
        // (el runner reintenta; la página se re-emite idempotente).
        do {
            try engine.enqueueSnapshotRows(page.inputs, context: context, now: now())
        } catch {
            #if DEBUG
            print("MigrationSnapshotUploader: enqueueSnapshotRows lanzó (drift): \(error)")
            #endif
            return .transient
        }

        // Push: capturar incrementales pendientes + subir TODO lo vivo (página + incrementales).
        let confirmed = await drainPushConfirm()
        guard confirmed else { return .transient }

        CloudSyncBreadcrumb.migrationSnapshotPageConfirmed(table: page.cursor.table, rows: page.inputs.count)
        return .pageConfirmed(cursor: encodeCursor(page.cursor))
    }

    // MARK: - Enumeración

    /// Resuelve `(tableIndex, afterSyncID)` desde el cursor. Tabla desconocida (drift de schema futuro) o
    /// cursor ausente → arranque `(0, nil)`.
    private func resolveStart(_ cursor: SnapshotCursor?) -> (Int, UUID?) {
        guard let cursor, let index = specs.firstIndex(where: { $0.table == cursor.table }) else {
            return (0, nil)
        }
        let after = cursor.afterSyncID.flatMap { UUID(uuidString: $0) }
        return (index, after)
    }

    private struct BuiltPage {
        let inputs: [SnapshotRowInput]
        let cursor: SnapshotCursor
    }

    /// Primera página NO vacía desde `fromTableIndex`/`afterSyncID`, saltando tablas agotadas. `nil` = no
    /// quedan filas en ninguna tabla (snapshot completo).
    private func nextPage(fromTableIndex: Int, afterSyncID: UUID?, limit: Int) -> BuiltPage? {
        var idx = fromTableIndex
        var after = afterSyncID
        while idx < specs.count {
            let result = specs[idx].page(after, limit)
            if result.inputs.isEmpty {
                idx += 1
                after = nil
                continue
            }
            let cursor = SnapshotCursor(table: specs[idx].table,
                                        afterSyncID: result.lastSyncID?.uuidString.lowercased())
            return BuiltPage(inputs: result.inputs, cursor: cursor)
        }
        return nil
    }

    // MARK: - Push por página

    /// Drena incrementales, sube TODAS las filas vivas del outbox y aplica resultados. `true` si el outbox
    /// vivo quedó VACÍO tras el push (página confirmada); `false` si quedan filas vivas (transient/red) o el
    /// push no fue 2xx.
    private func drainPushConfirm() async -> Bool {
        engine.drainOnce(context: context)
        let live = liveOutboxRows()
        guard !live.isEmpty else { return true }  // nada que subir (todo ya confirmado)

        // partitionBuildable (#26): aislar poison ANTES de push + DEAD-LETTEREARLO (fix del review
        // adversarial: sin dead-letter, el poison queda vivo para siempre → esta página jamás confirma →
        // migración atascada en transient perpetuo en vez de degradar honesto vía el mismatch de verify).
        let (buildable, poison) = pushClient.partitionBuildable(live)
        engine.deadLetterPoison(poison, context: context, now: now())
        guard !buildable.isEmpty else { return liveOutboxRows().isEmpty }  // solo poison → dead-lettereado → puede avanzar

        switch await pushClient.push(buildable) {
        case .completed(let results):
            await pushClient.applyResults(results, rows: buildable, engine: engine, context: context)
            // Confirmada SOLO si no quedan filas VIVAS (los dead-letters no son vivos → la página avanza y
            // el mismatch permanente lo caza verify → failedRollback tras topes, correcto por diseño).
            return liveOutboxRows().isEmpty
        case .sessionExpired, .accountUnavailable, .transient:
            return false
        }
    }

    /// Cierre de la pasada: drena y sube el residual del outbox (incrementales tardíos). `.completed` si el
    /// outbox vivo queda vacío; `.transient` si algo quedó pendiente (el runner reintenta antes de avanzar).
    private func finishResidual() async -> SnapshotStepOutcome {
        engine.drainOnce(context: context)
        let live = liveOutboxRows()
        guard !live.isEmpty else { return .completed }
        let (buildable, poison) = pushClient.partitionBuildable(live)
        engine.deadLetterPoison(poison, context: context, now: now())
        guard !buildable.isEmpty else {
            // Solo poison → dead-lettereado → si el outbox vivo quedó vacío, la pasada COMPLETA (el
            // mismatch que el poison provoca lo caza verify → degrada honesto por topes).
            return liveOutboxRows().isEmpty ? .completed : .transient
        }
        switch await pushClient.push(buildable) {
        case .completed(let results):
            await pushClient.applyResults(results, rows: buildable, engine: engine, context: context)
            return liveOutboxRows().isEmpty ? .completed : .transient
        case .sessionExpired, .accountUnavailable, .transient:
            return .transient
        }
    }

    private func liveOutboxRows() -> [SyncOutbox] {
        do {
            return try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        } catch {
            #if DEBUG
            print("MigrationSnapshotUploader: fetch(SyncOutbox) falló: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Specs

    /// Especificación de UNA entidad: tabla Postgres (orden + cursor) + el paginador que fetchea, ordena por
    /// identidad y construye los `SnapshotRowInput` de la página.
    private struct SnapshotEntitySpec {
        let table: String
        /// `(afterSyncID, limit) -> (inputs, lastSyncID de la página, hasMore)`.
        let page: (UUID?, Int) -> (inputs: [SnapshotRowInput], lastSyncID: UUID?, hasMore: Bool)
    }

    /// Las 16 especificaciones en orden de tabla UTF-8 asc (mismo criterio que Merkle A-4).
    private func buildSpecs() -> [SnapshotEntitySpec] {
        var specs: [SnapshotEntitySpec] = [
            makeSpec(TransactionItem.self, emission: EntityEmissionMap.transactionItem,
                     className: SyncEntityType.transactionItem, identity: { $0.syncID }),
            makeSpec(InboxDraft.self, emission: EntityEmissionMap.inboxDraft,
                     className: SyncEntityType.inboxDraft, identity: { $0.syncID }),
            makeSpec(Category.self, emission: EntityEmissionMap.category,
                     className: SyncEntityType.category, identity: { $0.syncID }),
            makeSpec(FavoritePayment.self, emission: EntityEmissionMap.favoritePayment,
                     className: SyncEntityType.favoritePayment, identity: { $0.syncID }),
            makeSpec(MerchantMemory.self, emission: EntityEmissionMap.merchantMemory,
                     className: SyncEntityType.merchantMemory, identity: { $0.syncID }),
            makeSpec(ExchangeRate.self, emission: EntityEmissionMap.exchangeRate,
                     className: SyncEntityType.exchangeRate, identity: { $0.syncID }),
            makeSpec(Budget.self, emission: EntityEmissionMap.budget,
                     className: SyncEntityType.budget, identity: { $0.id }),
            makeSpec(ScheduledPayment.self, emission: EntityEmissionMap.scheduledPayment,
                     className: SyncEntityType.scheduledPayment, identity: { $0.id }),
            makeSpec(Account.self, emission: EntityEmissionMap.account,
                     className: SyncEntityType.account, identity: { $0.shortcutID }),
            makeSpec(Subcategory.self, emission: EntityEmissionMap.subcategory,
                     className: SyncEntityType.subcategory, identity: { $0.shortcutID }),
            makeSpec(Tag.self, emission: EntityEmissionMap.tag,
                     className: SyncEntityType.tag, identity: { $0.id }),
            makeSpec(NotificationItem.self, emission: EntityEmissionMap.notificationItem,
                     className: SyncEntityType.notificationItem, identity: { $0.id }),
            makeSpec(CashFlowPlan.self, emission: EntityEmissionMap.cashFlowPlan,
                     className: SyncEntityType.cashFlowPlan, identity: { $0.id }),
            makeSpec(CashFlowLine.self, emission: EntityEmissionMap.cashFlowLine,
                     className: SyncEntityType.cashFlowLine, identity: { $0.id }),
            makeSpec(CashFlowOverride.self, emission: EntityEmissionMap.cashFlowOverride,
                     className: SyncEntityType.cashFlowOverride, identity: { $0.id }),
            makeSpec(GroupBridgePreference.self, emission: EntityEmissionMap.groupBridgePreference,
                     className: SyncEntityType.groupBridgePreference, identity: { $0.id }),
        ]
        specs.sort { Canonc1Codec.utf8BytesLess($0.table, $1.table) }
        return specs
    }

    /// Constructor genérico de una spec: fetch CONCRETO por tipo, orden por identidad asc, keyset por
    /// `afterSyncID`, y `SnapshotRowInput` con `makePayload` full-row (DeltaEmitter → codec c1).
    private func makeSpec<M: PersistentModel>(
        _ type: M.Type,
        emission: EntityEmission<M>,
        className: String,
        identity: @escaping (M) -> UUID?
    ) -> SnapshotEntitySpec {
        SnapshotEntitySpec(table: emission.table) { [context, calendar] afterSyncID, limit in
            let models: [M]
            do {
                models = try context.fetch(FetchDescriptor<M>())
            } catch {
                #if DEBUG
                print("MigrationSnapshotUploader: fetch(\(M.self)) falló: \(error)")
                #endif
                return ([], nil, false)
            }
            // (identidad, modelo) ordenados por identidad asc; keyset por afterSyncID. Fila sin identidad
            // (no debe ocurrir post-backfill) → se SALTA con canario.
            var pairs: [(id: String, model: M)] = []
            for model in models {
                guard let sid = identity(model) else {
                    CloudSyncBreadcrumb.identityGap(entityType: className, reason: "snapshotNoSyncID")
                    continue
                }
                pairs.append((sid.uuidString.lowercased(), model))
            }
            pairs.sort { $0.id < $1.id }
            let filtered: [(id: String, model: M)]
            if let after = afterSyncID?.uuidString.lowercased() {
                filtered = pairs.filter { $0.id > after }
            } else {
                filtered = pairs
            }
            let pageSlice = Array(filtered.prefix(limit))
            let inputs: [SnapshotRowInput] = pageSlice.map { entry in
                let syncID = UUID(uuidString: entry.id) ?? UUID()
                return Self.makeSnapshotRowInput(model: entry.model, syncID: syncID,
                                                 emission: emission, className: className, calendar: calendar)
            }
            let lastSyncID = pageSlice.last.flatMap { UUID(uuidString: $0.id) }
            return (inputs, lastSyncID, filtered.count > pageSlice.count)
        }
    }

    /// Construye el `SnapshotRowInput` full-row de UN modelo (misma emisión `DeltaEmitter`→codec c1 que la
    /// paginación del snapshot, extraída para que la reconciliación de huérfanas del adopt — DIFERIDOS #30,
    /// `MigrationWorkExecutor.runAdoptOrphanReconcile` — la REUSE verbatim en vez de duplicar el baile
    /// emisión→codec). `calendar` explícito (el llamador lo inyecta). Poison del codec c1 → canario + `nil`
    /// (el seam `enqueueSnapshotRows` salta la fila; el mismatch resultante degrada honesto por diseño).
    static func makeSnapshotRowInput<M: PersistentModel>(
        model: M, syncID: UUID, emission: EntityEmission<M>, className: String, calendar: Calendar
    ) -> SnapshotRowInput {
        SnapshotRowInput(syncID: syncID, entityType: className) { hlc in
            let result = DeltaEmitter.emit(model: model, emission: emission,
                                           changedColumns: emission.columns, hlc: hlc, calendar: calendar)
            let fieldsJSON: String
            do {
                fieldsJSON = try Canonc1Codec.encode(result.fields,
                                                     groupedColumns: Set(emission.groupByColumn.keys))
            } catch {
                // Poison: el codec c1 rechazó la fila → canario + skip (la página CONTINÚA; el
                // mismatch resultante degradará a failedRollback tras topes — correcto por diseño).
                #if DEBUG
                print("MigrationSnapshotUploader: codec c1 rechazó \(className) (fila saltada): \(error)")
                #endif
                CloudSyncBreadcrumb.encodeRejected(entity: className, reason: "snapshot:\(error)")
                return nil
            }
            return (fieldsJSON, encodeFieldHlcs(result.fieldHlcs))
        }
    }

    /// Serializa `field_hlcs` (`{unidad: hlc}`) como JSON plano con claves ordenadas (determinista, idéntico
    /// al helper privado del motor). Vacío → `"{}"` (no ocurre en upserts: siempre hay ≥1 unidad).
    private static func encodeFieldHlcs(_ fieldHlcs: [String: String]) -> String {
        guard !fieldHlcs.isEmpty else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return String(decoding: try encoder.encode(fieldHlcs), as: UTF8.self)
        } catch {
            #if DEBUG
            print("MigrationSnapshotUploader: encodeFieldHlcs error: \(error)")
            #endif
            return "{}"
        }
    }
}
