//
//  CloudSyncEngineTests.swift
//  YalaTests / CloudSync
//
//  Motor de captura (write→drain) del Modo Nube (I3). Container ON-DISK temp con los 3 stores
//  (personal `.none` + grupos `.none` + sync-meta `.none`), un solo `ModelContext` que los abarca
//  (espejo del mainContext de producción) — el History es por-CONTAINER y el motor lee de él.
//
//  `.serialized` + containers on-disk propios por test (patrón de los spikes / I2). El ruido sqlite
//  `vnode unlinked while in use` en teardown es benigno y conocido.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSyncEngine · write→drain / outbox", .serialized)
@MainActor
struct CloudSyncEngineTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudSyncEngine-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CSE-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "CSE-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "CSE-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    private func makeTx(amount: Double, currency: String = "USD", context: ModelContext) -> TransactionItem {
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: amount, currencyCode: currency)
        tx.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(tx)
        return tx
    }

    private func outboxRows(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>())
    }

    private func cursorTokenData(_ context: ModelContext) throws -> Data? {
        try context.fetch(FetchDescriptor<SyncCursor>()).first?.historyTokenData
    }

    private func dedupKeys(_ rows: [SyncOutbox]) -> [String] {
        rows.map { "\($0.syncID.uuidString)|\($0.hlc)|\($0.opRaw)" }
    }

    // MARK: - Idempotencia + token estable

    @Test func drain_isIdempotent_noNewRows_tokenStable() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 10, context: context)
        try context.save()

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)
        let afterFirst = try outboxRows(context).count
        #expect(afterFirst == 1)  // el insert produjo exactamente una fila upsert

        // Segunda vuelta: sin writes externos nuevos → 0 filas nuevas.
        engine.drainOnce(context: context)
        #expect(try outboxRows(context).count == afterFirst)
        let tokenAfterSecond = try cursorTokenData(context)

        // Tercera vuelta: convergencia — token estable y sin filas nuevas.
        engine.drainOnce(context: context)
        #expect(try outboxRows(context).count == afterFirst)
        #expect(try cursorTokenData(context) == tokenAfterSecond)
    }

    // MARK: - Kill entre outbox y token → sin duplicados

    @Test func drain_killBetweenOutboxAndToken_replayHasNoDuplicates() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 42, context: context)
        try context.save()

        // Mismo nodeID en ambas instancias = mismo dispositivo (el nodeID se persiste en I8). Con
        // reloj fresco + mismo nodeID + misma history/orden → HLCs IDÉNTICOS → el dedup los absorbe.
        let node = NodeID.generate()

        // Drain 1: guarda las filas del outbox PERO no avanza el token (kill simulado).
        let engine1 = CloudSyncEngine(nodeID: node)
        engine1._testSuppressTokenAdvance = true
        engine1.drainOnce(context: context)
        let afterKill = try outboxRows(context)
        #expect(afterKill.count == 1)
        #expect(try cursorTokenData(context) == nil)  // token NO avanzó

        // Drain 2: instancia fresca (reloj fresco, mismo nodeID), token viejo → re-procesa el mismo
        // history y NO duplica.
        let engine2 = CloudSyncEngine(nodeID: node)
        engine2.drainOnce(context: context)
        let afterReplay = try outboxRows(context)
        #expect(afterReplay.count == 1)
        #expect(Set(dedupKeys(afterReplay)).count == 1)  // sin duplicados (syncID,hlc,op)
    }

    // MARK: - Kill entre outbox y token, transacción MULTI-FILA → HLCs byte-idénticos, sin duplicados

    @Test func drain_killReplay_multiRowTransaction_reproducesIdenticalHLCs() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // TRES entidades en el MISMO save() → UNA transacción de history con 3 changes que comparten
        // `tx.timestamp` (mismo ms) → `clock.send` ejercita counters en SECUENCIA (0,1,2). El replay
        // con reloj fresco debe reproducir el lockstep EXACTO o los dedup keys divergen (residual #1
        // del review adversarial de I3: orden estable de `tx.changes` entre fetches).
        _ = makeTx(amount: 11, context: context)
        _ = makeTx(amount: 22, context: context)
        let category = Category(name: "Travel", colorHex: "#222222", isIncome: false, isDefaultSeed: false)
        context.insert(category)
        try context.save()

        // Mismo nodeID en ambas instancias = mismo dispositivo (el nodeID se persiste en I8).
        let node = NodeID.generate()

        // Drain 1: persiste las filas PERO no avanza el token (kill simulado).
        let engine1 = CloudSyncEngine(nodeID: node)
        engine1._testSuppressTokenAdvance = true
        engine1.drainOnce(context: context)
        let afterKill = try outboxRows(context)
        #expect(afterKill.count == 3)
        #expect(try cursorTokenData(context) == nil)  // token NO avanzó
        let hlcsAfterKill = Set(afterKill.map(\.hlc))
        #expect(hlcsAfterKill.count == 3)  // 3 HLCs distintos (counters en secuencia dentro del ms)

        // Drain 2: instancia fresca (reloj fresco, mismo nodeID) re-procesa la MISMA transacción
        // multi-fila → HLCs BYTE-idénticos → el dedup absorbe las 3.
        let engine2 = CloudSyncEngine(nodeID: node)
        engine2.drainOnce(context: context)
        let afterReplay = try outboxRows(context)
        #expect(afterReplay.count == 3)  // cero filas nuevas
        #expect(Set(dedupKeys(afterReplay)).count == 3)  // sin duplicados (syncID,hlc,op)
        #expect(Set(afterReplay.map(\.hlc)) == hlcsAfterKill)  // HLCs byte-idénticos entre drains
    }

    // MARK: - No auto-captura

    @Test func drain_doesNotCapture_ownAuthorWrites() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Escribir entidades personales BAJO el autor del motor (modela el apply de cambios remotos).
        let previous = context.author
        context.author = CloudSyncEngine.outboxSaveAuthor
        _ = makeTx(amount: 99, context: context)
        try context.save()
        context.author = previous

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)
        #expect(try outboxRows(context).isEmpty)  // 0 filas: las escribió el propio motor
    }

    // MARK: - Barrido defensivo (asigna syncID; syncID-only excluido; delete → tombstone con syncID)

    @Test func drain_barrido_assignsSyncID_excludesSyncIDOnly_tombstoneCarriesSyncID() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Entidad creada SIN syncID (flag born-cloud OFF).
        let tx = makeTx(amount: 7, context: context)
        #expect(tx.syncID == nil)
        try context.save()

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)
        // El barrido le asignó syncID y el insert produjo una fila upsert.
        let syncID = try #require(tx.syncID)
        let afterFirst = try outboxRows(context)
        #expect(afterFirst.count == 1)
        #expect(afterFirst.first?.opRaw == SyncOutboxOp.upsert.rawValue)
        #expect(afterFirst.first?.syncID == syncID)

        // Segundo drain: sin cambios de dominio → 0 filas nuevas (el cambio de syncID se excluye).
        engine.drainOnce(context: context)
        #expect(try outboxRows(context).count == 1)

        // Borrar → drain → tombstone CON el syncID preservado.
        context.delete(tx)
        try context.save()
        engine.drainOnce(context: context)
        let rows = try outboxRows(context)
        let tombstones = rows.filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue }
        #expect(tombstones.count == 1)
        #expect(tombstones.first?.syncID == syncID)
    }

    // MARK: - Tombstone sin syncID preservado → gap (contador interno)

    @Test func drain_deleteWithoutSyncID_recordsIdentityGap_noRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Create+save y delete+save en saves SEPARADOS, SIN drain intermedio → el syncID nunca se
        // asigna (el barrido no ve la fila ya borrada) → el tombstone lo lleva nil.
        let tx = makeTx(amount: 5, context: context)
        try context.save()
        context.delete(tx)
        try context.save()

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        // Gap registrado (contador interno) y NINGUNA fila de outbox (no hay identidad que tombstonear).
        #expect(engine.identityGapCount == 1)
        #expect(try outboxRows(context).isEmpty)
    }

    // MARK: - Golden M3: writes ANTES de instanciar el motor

    @Test func drain_capturesWritesMadeBeforeEngineExisted() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 1, context: context)
        _ = makeTx(amount: 2, context: context)
        let category = Category(name: "Food", colorHex: "#111111", isIncome: false, isDefaultSeed: false)
        context.insert(category)
        try context.save()

        // El motor se instancia DESPUÉS de los writes.
        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        let rows = try outboxRows(context)
        #expect(rows.count == 3)  // 2 TX + 1 Category, todos capturados
        #expect(rows.allSatisfy { $0.opRaw == SyncOutboxOp.upsert.rawValue })
        let types = Set(rows.map(\.entityType))
        #expect(types == [SyncEntityType.transactionItem, SyncEntityType.category])
    }

    // MARK: - Anti-fuga de Grupos

    @Test func drain_ignoresGroupStoreEntities() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Escribir un tipo del store de GRUPOS (nunca debe filtrarse al outbox personal).
        let group = SplitGroup(name: "Trip", isOwner: true)
        context.insert(group)
        // Y un tipo personal legítimo, para confirmar que el drain SÍ funciona en la misma vuelta.
        _ = makeTx(amount: 3, context: context)
        try context.save()

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        let rows = try outboxRows(context)
        #expect(rows.count == 1)  // solo el TX personal
        #expect(rows.first?.entityType == SyncEntityType.transactionItem)
        #expect(!rows.contains { $0.entityType == "SplitGroup" })
    }

    // MARK: - HALLAZGO 2 — guard del token de History no-comparable cross-mount (corrida device reversa 2026-07-11)

    private func allHistory(_ context: ModelContext) throws -> [DefaultHistoryTransaction] {
        try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
    }

    private func makeFX(_ context: ModelContext, dateKey: String = "2026-07-11") throws -> ExchangeRate {
        let fx = try ExchangeRate(dateKey: dateKey, base: "USD", ratesDictionary: ["EUR": 0.9, "PEN": 3.7])
        context.insert(fx)
        return fx
    }

    /// Sella el cursor con el token de HIGH-WATER (excluye `> hw` las txs presentes, incl. una fila que ya
    /// existe en History) + un `lastDrainedTxAt` dado → reproduce el SÍNTOMA del token no-comparable
    /// cross-mount de forma DETERMINISTA (el token no surfacea una tx que el timestamp SÍ ve), agnóstico al
    /// mecanismo real (remount `.icloud`→`.cloud` o cross-store — ambos INTERMITENTES, no aptos para un test
    /// determinista; el guard es agnóstico al mecanismo). `nil` = simula un cursor pre-schema (guard skip).
    private func sealStaleToken(_ context: ModelContext, lastDrainedTxAt: Date?) throws {
        let hist = try allHistory(context)
        let hw = try #require(hist.last?.token)
        let cursor = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        let prev = context.author
        context.author = CloudSyncEngine.outboxSaveAuthor
        cursor.historyTokenData = try JSONEncoder().encode(hw)
        cursor.lastDrainedTxAt = lastDrainedTxAt
        try context.save()
        context.author = prev
    }

    private func setLastDrainedTxAt(_ context: ModelContext, _ date: Date) throws {
        let cursor = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        let prev = context.author
        context.author = CloudSyncEngine.outboxSaveAuthor
        cursor.lastDrainedTxAt = date
        try context.save()
        context.author = prev
    }

    private func fxRows(_ context: ModelContext) throws -> [SyncOutbox] {
        try outboxRows(context).filter { $0.entityType == SyncEntityType.exchangeRate }
    }

    /// Borra las filas de outbox de un tipo (autor del motor → el delete de `SyncOutbox` no se re-captura).
    /// Modela "la fila jamás llegó al outbox" partiendo de una entidad YA drenada (con syncID) — así no hay
    /// tx de asignación de syncID del barrido que avance el token por outcome (b).
    private func deleteOutboxRows(_ context: ModelContext, entityType: String) throws {
        let prev = context.author
        context.author = CloudSyncEngine.outboxSaveAuthor
        for row in try outboxRows(context) where row.entityType == entityType { context.delete(row) }
        try context.save()
        context.author = prev
    }

    /// PASO 0a (viabilidad): un `#Predicate` sobre `DefaultHistoryTransaction.timestamp` EJECUTA contra un
    /// store real (no solo compila) — familia del gotcha `#Predicate`; tipo CONCRETO, debe ser seguro.
    @Test func t0_smoke_historyTimestampPredicate_executesAgainstRealStore() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = makeTx(amount: 5, context: context)
        try context.save()

        let cutoff = Date(timeIntervalSince1970: 0)
        let txns = try context.fetchHistory(
            HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.timestamp > cutoff }))
        #expect(!txns.isEmpty)  // ejecutó sin SIGTRAP / NSInvalidArgument y devolvió txs > epoch
    }

    /// T1 (regresión principal): una fila FX que el token stale NO surfacea (el bug de la corrida device)
    /// es RECUPERADA por el guard y viaja al outbox con columnas correctas.
    @Test func t1_guardRecoversFXRowInvisibleToStaleToken() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // 1) Corpus base drenado (crea el cursor con token + lastDrainedTxAt válidos).
        _ = makeTx(amount: 10, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        #expect(try outboxRows(context).count == 1)
        let baseTxAt = try #require(allHistory(context).last?.timestamp)

        // 2) Fila FX del boot post-cutover: existe en History pero aún sin drenar.
        let fx = try makeFX(context)
        try context.save()

        // 3) Sellar el token stale (high-water excluye la FX; lastDrainedTxAt ANTES de la FX).
        try sealStaleToken(context, lastDrainedTxAt: baseTxAt)
        #expect(try fxRows(context).isEmpty)  // pre-fix: la FX no llegó al outbox (pending=0 perpetuo)

        // 4) Drain con instancia FRESCA → el guard detecta el token roto y RECUPERA la FX.
        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        #expect(engine.historyTokenIncomparableCount == 1)
        #expect(engine.historyTokenRecoveredCount == 1)
        let recovered = try fxRows(context)
        #expect(recovered.count == 1)                                // la FX viajó al outbox
        let row = try #require(recovered.first)
        #expect(row.syncID == fx.syncID)                             // identidad correcta (asignada por el barrido)
        #expect(row.opRaw == SyncOutboxOp.upsert.rawValue)           // upsert full-row
        #expect(row.fieldsJSON != "{}")                              // con columnas de dominio

        // El token se re-ancló al mount actual → un 2º drain (ya validado) es no-op para la FX.
        let fxCountAfterFirst = try fxRows(context).count
        engine.drainOnce(context: context)
        #expect(engine.historyTokenValidated)
        #expect(try fxRows(context).count == fxCountAfterFirst)      // sin re-emisión de la FX
    }

    /// T2 (steady-state): token VÁLIDO comparable en el mismo mount → el guard valida por comparación
    /// (`validatedByCompare`), NO recupera, NO emite `historyTokenIncomparable`, el token avanza normal.
    @Test func t2_steadyStateValidToken_validatesWithoutRecovery() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Drenar un corpus con engineA → cursor con token + lastDrainedTxAt VÁLIDOS del mount actual.
        _ = makeTx(amount: 1, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        let afterFirst = try outboxRows(context).count
        #expect(afterFirst == 1)

        // Un write nuevo del MISMO mount, drenado por una instancia FRESCA → el guard corre y valida.
        _ = makeTx(amount: 2, context: context)
        try context.save()
        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        #expect(engine.historyTokenIncomparableCount == 0)   // token comparable → sin falso positivo
        #expect(engine.historyTokenRecoveredCount == 0)
        #expect(engine.historyTokenValidated)                // validado por comparación
        let rows = try outboxRows(context)
        #expect(rows.count == 2)                             // TX1 + TX2, sin duplicados
        #expect(Set(dedupKeys(rows)).count == 2)
    }

    /// T3 (frontera/dedup): al recuperar, la tx de la frontera del slack YA drenada se re-lee y se re-emite
    /// con HLC FRESCO (el reloj de la instancia ya avanzó) — duplicado de outbox HLC-idempotente que el
    /// backend colapsa por LWW. Documenta cuál de los dos comportamientos del plan aplica: RE-EMISIÓN.
    @Test func t3_recoveryReReadsSlackBoundary_reEmitsWithFreshHLC() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Base drenada (la frontera del slack). Capturamos su syncID + HLC original.
        _ = makeTx(amount: 7, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        let baseTxAt = try #require(allHistory(context).last?.timestamp)
        let baseRow = try #require(try outboxRows(context).first)
        let baseSyncID = baseRow.syncID
        let baseHLC = baseRow.hlc

        // FX nueva + token stale → fuerza recovery (la unión re-incluye la base de la frontera).
        _ = try makeFX(context)
        try context.save()
        try sealStaleToken(context, lastDrainedTxAt: baseTxAt)

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)
        #expect(engine.historyTokenRecoveredCount == 1)

        // La base de la frontera aparece DOS veces: original + re-emisión con HLC distinto (mismo syncID/op).
        let baseRows = try outboxRows(context).filter { $0.syncID == baseSyncID }
        #expect(baseRows.count == 2)
        let hlcs = Set(baseRows.map(\.hlc))
        #expect(hlcs.count == 2)                       // HLC fresco ≠ original (no dedup — reloj avanzó)
        #expect(hlcs.contains(baseHLC))                // el original sigue presente
        #expect(baseRows.allSatisfy { $0.opRaw == SyncOutboxOp.upsert.rawValue })  // mismo op → LWW converge
    }

    /// T4 (atomicidad): `lastDrainedTxAt` se persiste JUNTO al token. Con el kill simulado (`_testSuppress…`)
    /// NINGUNO de los dos avanza; el replay (mismo nodeID) re-crea sin duplicados y ahora persiste AMBOS.
    @Test func t4_lastDrainedTxAtPersistsAtomicallyWithToken() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 42, context: context)
        try context.save()
        let node = NodeID.generate()

        // Drain 1: persiste el outbox PERO no avanza (kill entre outbox y token).
        let engine1 = CloudSyncEngine(nodeID: node)
        engine1._testSuppressTokenAdvance = true
        engine1.drainOnce(context: context)
        #expect(try outboxRows(context).count == 1)
        let cursorAfterKill = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        #expect(cursorAfterKill.historyTokenData == nil)   // token NO avanzó
        #expect(cursorAfterKill.lastDrainedTxAt == nil)    // lastDrainedTxAt TAMPOCO (atómico con el token)

        // Drain 2: instancia fresca (mismo nodeID) → replay HLC-idéntico, sin duplicados; ambos persisten.
        let engine2 = CloudSyncEngine(nodeID: node)
        engine2.drainOnce(context: context)
        let rows = try outboxRows(context)
        #expect(rows.count == 1)                           // sin duplicado (dedup HLC-idéntico)
        let cursorAfter = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        #expect(cursorAfter.historyTokenData != nil)       // token persistido
        #expect(cursorAfter.lastDrainedTxAt != nil)        // lastDrainedTxAt persistido en el MISMO save
    }

    /// T5 (revalidación continua): un primer drain SIN nada que comparar (ventana vacía) NO marca validado;
    /// un drain POSTERIOR de la MISMA instancia, ya con señal, recupera la FX (cierra el agujero de la
    /// validación única). El ajuste de `lastDrainedTxAt` entre drains modela la llegada de nueva señal.
    @Test func t5_continuousRevalidation_secondDrainRecovers() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 3, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        let baseTxAt = try #require(allHistory(context).last?.timestamp)

        // FX DRENADA (obtiene syncID + outbox) y luego BORRADA del outbox → modela "jamás capturada" SIN una
        // tx de barrido pendiente que avance el token (el confound que invalidaba la premisa de este test).
        _ = try makeFX(context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        #expect(try fxRows(context).count == 1)
        try deleteOutboxRows(context, entityType: SyncEntityType.exchangeRate)
        #expect(try fxRows(context).isEmpty)

        // Token stale + lastDrainedTxAt en el FUTURO (ventana de timestamp vacía → primer drain no valida).
        try sealStaleToken(context, lastDrainedTxAt: baseTxAt.addingTimeInterval(600))

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)
        #expect(engine.historyTokenIncomparableCount == 0)   // nada contra qué validar
        #expect(!engine.historyTokenValidated)               // NO se marcó validado (no es one-shot)
        #expect(try fxRows(context).isEmpty)                 // FX aún invisible

        // Llega señal (lastDrainedTxAt real) → el SEGUNDO drain de la MISMA instancia recupera.
        try setLastDrainedTxAt(context, baseTxAt)
        engine.drainOnce(context: context)
        #expect(engine.historyTokenIncomparableCount == 1)
        #expect(engine.historyTokenValidated)
        #expect(try fxRows(context).count == 1)
    }

    /// T6 (breadcrumb 1:1): la recuperación emite EXACTAMENTE un `historyTokenIncomparable` + un
    /// `historyTokenRecovered` (contadores pareados); un drain steady-state no emite ninguno.
    @Test func t6_breadcrumbCountersPairOnRecovery_zeroInSteadyState() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 9, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        let baseTxAt = try #require(allHistory(context).last?.timestamp)
        _ = try makeFX(context)
        try context.save()
        try sealStaleToken(context, lastDrainedTxAt: baseTxAt)

        let recovering = CloudSyncEngine()
        recovering.drainOnce(context: context)
        #expect(recovering.historyTokenIncomparableCount == recovering.historyTokenRecoveredCount)
        #expect(recovering.historyTokenIncomparableCount == 1)

        // Steady-state fresco sobre el estado ya recuperado (token válido) → cero canarios.
        _ = makeTx(amount: 11, context: context)
        try context.save()
        let steady = CloudSyncEngine()
        steady.drainOnce(context: context)
        #expect(steady.historyTokenIncomparableCount == 0)
        #expect(steady.historyTokenRecoveredCount == 0)
    }

    /// T7 (nil-skip): un cursor con token pero `lastDrainedTxAt == nil` (pre-schema) → el guard hace SKIP;
    /// comportamiento IDÉNTICO al pre-fix (la FX invisible NO se auto-cura — residual documentado).
    @Test func t7_nilLastDrainedTxAt_guardSkips() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 4, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)

        _ = try makeFX(context)
        try context.save()
        // Token stale PERO lastDrainedTxAt nil (cursor pre-schema).
        try sealStaleToken(context, lastDrainedTxAt: nil)

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        #expect(engine.historyTokenIncomparableCount == 0)   // guard skip (sin ancla comparable)
        #expect(try fxRows(context).isEmpty)                 // FX sigue invisible (idéntico al pre-fix)
    }

    /// T8 (S1 del review adversarial): `fastForwardHistoryBaseline` estampa `lastDrainedTxAt` JUNTO al
    /// token (mismo save). Sin el estampado, el primer drain post-fast-forward (re-migración sobre la MISMA
    /// instalación, ancla vieja de la época `.cloud` previa) vería como "faltantes" todas las txs que el
    /// baseline salta A PROPÓSITO (el snapshot full-row las cubre) → recovery masiva del corpus + canario
    /// `historyTokenIncomparable` FALSO en el propio camino gateado de I14.
    @Test func t8_fastForwardBaselineStampsAnchor_guardDoesNotFalselyRecover() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Cursor con ancla VIEJA (el device drenó semanas atrás, antes de la reversa).
        _ = makeTx(amount: 1, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        let outboxBefore = try outboxRows(context).count
        let oldAnchor = Date(timeIntervalSince1970: 1_600_000_000)
        try setLastDrainedTxAt(context, oldAnchor)

        // "Corpus re-importado" posterior al ancla que el baseline salta a propósito.
        _ = makeTx(amount: 2, context: context)
        _ = makeTx(amount: 3, context: context)
        try context.save()

        CloudSyncEngine().fastForwardHistoryBaseline(context: context)

        // El fast-forward estampó el ancla junto al token (mismo save).
        let cursor = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        let anchoredAt = try #require(cursor.lastDrainedTxAt)
        #expect(anchoredAt > oldAnchor)

        // Primer drain de una instancia fresca: token y ancla CONSISTENTES → sin recovery, sin canario
        // falso, sin re-emisión del corpus saltado (las txs pre-baseline siguen suprimidas).
        let fresh = CloudSyncEngine()
        fresh.drainOnce(context: context)
        #expect(fresh.historyTokenIncomparableCount == 0)
        #expect(fresh.historyTokenRecoveredCount == 0)
        #expect(try outboxRows(context).count == outboxBefore)
    }

    // MARK: - DIFERIDOS #33 — fallback ACOTADO ante token IN-DECODIFICABLE (T9-T13)

    /// Sella el cursor con Data BASURA como token (in-decodificable — la clase del hazard #33) + un
    /// `lastDrainedTxAt` dado. Autor del motor → el write del cursor no se re-captura.
    private func sealCorruptToken(_ context: ModelContext, lastDrainedTxAt: Date?) throws {
        let cursor = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        let prev = context.author
        context.author = CloudSyncEngine.outboxSaveAuthor
        cursor.historyTokenData = Data("garbage-token".utf8)
        cursor.lastDrainedTxAt = lastDrainedTxAt
        try context.save()
        context.author = prev
    }

    /// Purga la History ENTERA (espeja `purgeHistoryOnce` con corte en distantFuture) — modela la
    /// purga por debajo del ancla, el escenario real de la ventana vacía de T10.
    private func purgeAllHistory(_ context: ModelContext) throws {
        let cut = Date.distantFuture
        try context.deleteHistory(
            HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.timestamp < cut }))
    }

    /// T9 (regresión principal #33): token CORRUPTO + ancla válida → la rama ACOTADA recupera la fila
    /// FX pendiente (columnas reales), re-ancla el token y NO corre el guard del Hallazgo 2. La
    /// frontera del slack (la base ya drenada) se re-emite con HLC fresco — mismo residual que T3.
    @Test func t9_corruptToken_boundedRescanRecoversAndReanchors() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Base drenada (crea cursor con token + ancla + reloj persistidos).
        _ = makeTx(amount: 10, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        let baseRow = try #require(try outboxRows(context).first)
        let baseSyncID = baseRow.syncID
        let baseHLC = baseRow.hlc
        let baseTxAt = try #require(allHistory(context).last?.timestamp)

        // FX sin drenar + token CORRUPTO con ancla real.
        let fx = try makeFX(context)
        try context.save()
        try sealCorruptToken(context, lastDrainedTxAt: baseTxAt)

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        #expect(engine.historyTokenBrokenBoundedCount == 1)      // rama acotada
        #expect(engine.historyTokenBrokenReanchoredCount == 1)   // re-anclado
        #expect(engine.historyTokenBrokenFullRescanCount == 0)   // SIN full-rescan (el hazard acotado)
        #expect(engine.historyTokenIncomparableCount == 0)       // el guard del Hallazgo 2 NO corrió
        #expect(engine.historyTokenValidated)

        // La FX viajó al outbox con columnas reales.
        let fxOutbox = try fxRows(context)
        #expect(fxOutbox.count == 1)
        #expect(fxOutbox.first?.syncID == fx.syncID)
        #expect(fxOutbox.first?.opRaw == SyncOutboxOp.upsert.rawValue)
        #expect(fxOutbox.first?.fieldsJSON != "{}")

        // Frontera del slack: la base se re-emite con HLC FRESCO (reloj persistido avanzó) — LWW converge.
        let baseRowsAfter = try outboxRows(context).filter { $0.syncID == baseSyncID }
        #expect(baseRowsAfter.count == 2)
        #expect(Set(baseRowsAfter.map(\.hlc)).count == 2)
        #expect(baseRowsAfter.contains { $0.hlc == baseHLC })

        // Token sanado: el 2º drain de la misma instancia es no-op (sin filas nuevas, sin canarios nuevos).
        let countAfterFirst = try outboxRows(context).count
        engine.drainOnce(context: context)
        #expect(try outboxRows(context).count == countAfterFirst)
        #expect(engine.historyTokenBrokenBoundedCount == 1)
    }

    /// T10 (ventana vacía → cura): History PURGADA por debajo del ancla + token corrupto → window 0:
    /// sin emisión, sin reanchor, el token roto persiste (drain ocioso barato); el primer write nuevo
    /// entra en la ventana → el siguiente drain lo emite y re-ancla (auto-cura).
    @Test func t10_corruptToken_emptyWindow_healsOnNextWrite() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 5, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        let baseTxAt = try #require(allHistory(context).last?.timestamp)
        let outboxBefore = try outboxRows(context).count

        // Sellar ANTES de purgar: el save del cursor del seal también es una tx de History (motor) —
        // si quedara viva, caería en la ventana y el drain re-anclaría a ella de inmediato (correcto
        // en producción, pero rompería la premisa "ventana vacía" de este test).
        try sealCorruptToken(context, lastDrainedTxAt: baseTxAt)
        try purgeAllHistory(context)

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)
        #expect(engine.historyTokenBrokenBoundedCount == 1)      // rama acotada corrió (window 0)
        #expect(engine.historyTokenBrokenReanchoredCount == 0)   // nada a lo que re-anclar
        #expect(!engine.historyTokenValidated)                   // token sigue roto
        #expect(try outboxRows(context).count == outboxBefore)   // sin emisión
        let cursorMid = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        #expect(cursorMid.historyTokenData == Data("garbage-token".utf8))  // intacto

        // Write nuevo (timestamp wall-clock > cutoff) → el siguiente drain emite + re-ancla.
        _ = makeTx(amount: 6, context: context)
        try context.save()
        engine.drainOnce(context: context)
        #expect(engine.historyTokenBrokenBoundedCount == 2)
        #expect(engine.historyTokenBrokenReanchoredCount == 1)
        #expect(engine.historyTokenValidated)
        #expect(try outboxRows(context).count == outboxBefore + 1)
        let cursorAfter = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        #expect(cursorAfter.historyTokenData != Data("garbage-token".utf8))  // re-anclado (decodable)
    }

    /// T11 (semántica a): token corrupto SIN ancla (cursor pre-schema) → full-rescan CONSERVADO con
    /// breadcrumb propio: el corpus ya drenado se RE-emite con HLC fresco (el hazard, acotado solo al
    /// caso sin ancla) y el avance normal del paso 7 sana el token.
    @Test func t11_corruptTokenWithoutAnchor_fullRescanConserved() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 7, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        let baseRow = try #require(try outboxRows(context).first)
        let baseSyncID = baseRow.syncID

        _ = try makeFX(context)
        try context.save()
        try sealCorruptToken(context, lastDrainedTxAt: nil)

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        #expect(engine.historyTokenBrokenFullRescanCount == 1)   // full-rescan (reason no-anchor)
        #expect(engine.historyTokenBrokenBoundedCount == 0)
        #expect(engine.historyTokenIncomparableCount == 0)       // guard saltado (token roto)
        // El corpus se re-emitió (base ×2 con HLC fresco) + la FX ×1 — documenta el hazard conservado.
        #expect(try outboxRows(context).filter { $0.syncID == baseSyncID }.count == 2)
        #expect(try fxRows(context).count == 1)
        // El avance NORMAL del paso 7 (txs externas consumidas) sanó el token.
        let cursor = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        #expect(cursor.historyTokenData != nil)
        #expect(cursor.historyTokenData != Data("garbage-token".utf8))
        #expect(cursor.lastDrainedTxAt != nil)                   // el ancla se pobló (pre-schema curado)
    }

    /// T12 (semántica b): token corrupto + ancla + el fetch ACOTADO también lanza (seam) → DEGRADA al
    /// full-rescan medido en vez de abortar el drain (la FX se recupera igual).
    @Test func t12_corruptToken_boundedFetchThrows_degradesToFullRescan() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 8, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        let baseTxAt = try #require(allHistory(context).last?.timestamp)

        _ = try makeFX(context)
        try context.save()
        try sealCorruptToken(context, lastDrainedTxAt: baseTxAt)

        let engine = CloudSyncEngine()
        engine._testThrowOnBoundedHistoryFetch = true
        engine.drainOnce(context: context)

        #expect(engine.historyTokenBrokenFullRescanCount == 1)   // degradado (reason bounded-fetch-failed)
        #expect(engine.historyTokenBrokenBoundedCount == 0)      // la acotada no llegó a contar
        #expect(engine.historyTokenBrokenReanchoredCount == 0)
        #expect(try fxRows(context).count == 1)                  // el drain NO abortó: la FX se recuperó

        // El avance NORMAL sanó el token en el MISMO drain (sin heal, cada drain repetiría el
        // full-rescan re-emisor — el hazard en loop).
        let cursor = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        #expect(cursor.historyTokenData != nil)
        #expect(cursor.historyTokenData != Data("garbage-token".utf8))
    }

    /// T13 (fetch por token que LANZA con token VÁLIDO — el 2º punto del hazard #33): mismo camino
    /// acotado que T9 (re-decide como roto → bounded + reanchor).
    @Test func t13_validTokenFetchThrows_takesBoundedFallback() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 9, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)  // cursor con token VÁLIDO + ancla

        let fx = try makeFX(context)
        try context.save()

        let engine = CloudSyncEngine()
        engine._testThrowOnTokenHistoryFetch = true
        engine.drainOnce(context: context)

        #expect(engine.historyTokenBrokenBoundedCount == 1)      // rama acotada (no full-rescan)
        #expect(engine.historyTokenBrokenReanchoredCount == 1)
        #expect(engine.historyTokenBrokenFullRescanCount == 0)
        #expect(try fxRows(context).count == 1)
        #expect(try fxRows(context).first?.syncID == fx.syncID)

        // Seam OFF → el token re-anclado vuelve al camino normal sin filas nuevas.
        engine._testThrowOnTokenHistoryFetch = false
        let countAfterFirst = try outboxRows(context).count
        engine.drainOnce(context: context)
        #expect(try outboxRows(context).count == countAfterFirst)
        #expect(engine.historyTokenBrokenBoundedCount == 1)
    }

    /// T14 (SERIO 1 del review adversarial #33): si la traducción ABORTA a mitad de ventana
    /// (`clock.send` lanza por drift — reloj persistido adelantado > 5 min), el re-anclaje del token
    /// roto se SUPRIME (re-anclar saltaría txs externas jamás emitidas = pérdida silenciosa). El token
    /// queda roto y, saneado el reloj, el siguiente drain recupera TODO (nada se perdió).
    @Test func t14_translationAborted_suppressesBrokenReanchor_noWriteLoss() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(amount: 12, context: context)
        try context.save()
        CloudSyncEngine().drainOnce(context: context)
        let baseTxAt = try #require(allHistory(context).last?.timestamp)
        let outboxBefore = try outboxRows(context).count

        // FX sin drenar + token corrupto + RELOJ PERSISTIDO adelantado 1h → drift > 5 min: el primer
        // `clock.send` de la traducción lanza → abort en la frontera, sin filas ni avance.
        let fx = try makeFX(context)
        try context.save()
        try sealCorruptToken(context, lastDrainedTxAt: baseTxAt)
        var futureClock = HLCClock(nodeID: NodeID.generate())
        let futureHLC = try futureClock.send(now: baseTxAt.addingTimeInterval(3600))
        let cursorPre = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        let prevAuthor = context.author
        context.author = CloudSyncEngine.outboxSaveAuthor
        cursorPre.clockLatestHLC = futureHLC.description
        try context.save()
        context.author = prevAuthor

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        #expect(engine.historyTokenBrokenBoundedCount == 1)      // la rama acotada corrió…
        #expect(engine.historyTokenBrokenReanchoredCount == 0)   // …pero el reanchor se SUPRIMIÓ
        #expect(try fxRows(context).isEmpty)                     // nada emitido (abort en la frontera)
        let cursorMid = try #require(try context.fetch(FetchDescriptor<SyncCursor>()).first)
        #expect(cursorMid.historyTokenData == Data("garbage-token".utf8))  // token intacto (retry)

        // Reloj saneado → instancia fresca (el reloj en memoria de `engine` quedó contaminado por
        // loadClock) recupera la FX completa: el abort NO perdió el write.
        let prevAuthor2 = context.author
        context.author = CloudSyncEngine.outboxSaveAuthor
        cursorMid.clockLatestHLC = nil
        try context.save()
        context.author = prevAuthor2

        let healed = CloudSyncEngine()
        healed.drainOnce(context: context)
        #expect(healed.historyTokenBrokenReanchoredCount == 1)   // ahora sí re-ancla
        #expect(try fxRows(context).count == 1)                  // la FX se recuperó — sin pérdida
        #expect(try fxRows(context).first?.syncID == fx.syncID)
        #expect(try outboxRows(context).count > outboxBefore)
    }
}
