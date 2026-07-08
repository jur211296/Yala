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
}
