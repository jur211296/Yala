//
//  CloudSyncTombstoneTests.swift
//  YalaTests / CloudSync
//
//  Goldens de TOMBSTONE del Modo Nube (I4). Ejercitan la clasificación del `reason` (§c.1) 100%
//  DRAIN-SIDE del `CloudSyncEngine` end-to-end (write→drain), sin tocar ningún call-site de delete de
//  producción. Cubre los escenarios S4 del spike (§c.2): cascada manual real, latencia larga,
//  create+delete sin drain intermedio (gap), coalescing mismo-save, y el delete directo simple.
//
//  Infra ESPEJO de `CloudSyncEngineTests`: `.serialized` + container ON-DISK temp propio por test con
//  los 3 stores (personal + grupos + sync-meta, todos `.none`) sobre UN solo `ModelContext` (el
//  History es por-CONTAINER y el motor lee de él). El ruido sqlite `vnode unlinked while in use` en
//  teardown es benigno y conocido.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · tombstone reason (I4)", .serialized)
@MainActor
struct CloudSyncTombstoneTests {

    // MARK: - Infra (espejo de CloudSyncEngineTests)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudSyncTombstone-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CST-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "CST-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "CST-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    private func makeTx(amount: Double, context: ModelContext) -> TransactionItem {
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: amount, currencyCode: "USD")
        tx.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(tx)
        return tx
    }

    private func makeDraft(note: String, context: ModelContext) -> InboxDraft {
        let draft = InboxDraft(note: note, amount: 1, sourceType: .voice, rawText: note)
        context.insert(draft)
        return draft
    }

    private func makeScheduledPayment(context: ModelContext) -> ScheduledPayment {
        let payment = ScheduledPayment(
            name: "Rent", amount: 100, currencyCode: "USD",
            nextDueDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        context.insert(payment)
        return payment
    }

    private func outboxRows(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>())
    }

    private func tombstones(_ context: ModelContext) throws -> [SyncOutbox] {
        try outboxRows(context).filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue }
    }

    // MARK: - Cascada MANUAL real (réplica de la forma `deleteScheduledPayment`)

    @Test func cascadeDelete_scheduledPaymentShape_tombstonesCarryCascadeReason_preservedSyncIDs() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Padre (ScheduledPayment — YA syncable en I12; identidad = `id`) + hijos syncables (2 TX + 1 draft).
        let payment = makeScheduledPayment(context: context)
        let paymentID = payment.id
        let tx1 = makeTx(amount: 10, context: context)
        let tx2 = makeTx(amount: 20, context: context)
        let draft = makeDraft(note: "future occurrence", context: context)
        try context.save()

        // Drain 1: el barrido asigna syncID a los hijos + captura los upserts (padre e hijos).
        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)
        let syncTx1 = try #require(tx1.syncID)
        let syncTx2 = try #require(tx2.syncID)
        let syncDraft = try #require(draft.syncID)

        // Cascada: borrar los 2 TX + el draft + el PADRE en UN solo save (forma de `deleteScheduledPayment`).
        context.delete(tx1)
        context.delete(tx2)
        context.delete(draft)
        context.delete(payment)
        try context.save()

        engine.drainOnce(context: context)

        // 4 tombstones: los 3 hijos + el PADRE (ahora syncable). §c.1 clasifica por TRANSACCIÓN: como la
        // tx contiene el delete de un cascade-parent (`ScheduledPayment`), TODOS los tombstones —incluido
        // el del propio padre— llevan `cascade` (metadata de auditoría conservadora, no compromete
        // correctness: el backend mantiene `deleted=true` igual). El `id` del padre se preserva vía
        // `.preserveValueOnDeletion` (I12) → su tombstone lo conserva.
        let stones = try tombstones(context)
        #expect(stones.count == 4)
        #expect(stones.allSatisfy { $0.tombstoneReason == SyncTombstoneReason.cascade.rawValue })
        #expect(Set(stones.map(\.syncID)) == [syncTx1, syncTx2, syncDraft, paymentID])
        // El padre AHORA sí produce su propia fila (tombstone) con la identidad preservada.
        let parentStone = stones.first { $0.entityType == "ScheduledPayment" }
        #expect(parentStone?.syncID == paymentID)
    }

    // MARK: - S4-i · latencia larga: create sin syncID → drain (barrido) → delete → tombstone con syncID

    @Test func longLatency_createWithoutSyncID_thenDeleteAfterDrain_tombstoneCarriesSyncID_userReason() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Entidad creada SIN syncID (born-cloud OFF), como un App Intent out-of-band.
        let tx = makeTx(amount: 7, context: context)
        #expect(tx.syncID == nil)
        try context.save()

        // Drain: el barrido le asigna syncID ANTES de cualquier delete (cierra la ventana S4-i).
        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)
        let syncID = try #require(tx.syncID)

        // Delete directo (sin padre en la misma transacción) → reason `user`.
        context.delete(tx)
        try context.save()
        engine.drainOnce(context: context)

        let stones = try tombstones(context)
        #expect(stones.count == 1)
        #expect(stones.first?.syncID == syncID)
        #expect(stones.first?.tombstoneReason == SyncTombstoneReason.user.rawValue)
        #expect(engine.identityGapCount == 0)  // el barrido cerró la ventana → sin gap
    }

    // MARK: - S4-ii · create+delete en saves SEPARADOS sin drain intermedio → sin fila + gap

    @Test func createThenDelete_separateSaves_noDrainBetween_noRow_recordsGap() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Create y delete en saves SEPARADOS, sin drain intermedio → el barrido nunca ve la fila viva →
        // el tombstone llega con syncID nil. Comportamiento I3 pineado: NO se emite fila (nunca tuvo
        // identidad → nada que borrar en el backend) + gap registrado (breadcrumb + canario).
        let tx = makeTx(amount: 5, context: context)
        try context.save()
        context.delete(tx)
        try context.save()

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        #expect(engine.identityGapCount == 1)
        #expect(try outboxRows(context).isEmpty)
    }

    // MARK: - Coalescing mismo-save · create+delete en el MISMO save → cero history, cero fila (spike S4)

    @Test func createAndDelete_sameSave_coalesced_noHistory_noRow_noGap() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Create + delete en el MISMO save → SwiftData coalescea a NADA (0 cambios de history) → el drain
        // no ve delete → ni tombstone espurio ni gap.
        let tx = makeTx(amount: 3, context: context)
        context.delete(tx)
        try context.save()

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        #expect(try outboxRows(context).isEmpty)  // ni upsert ni tombstone
        #expect(engine.identityGapCount == 0)      // sin delete visible → sin gap
    }

    // MARK: - Delete directo simple → reason `user`

    @Test func simpleDirectDelete_tombstoneCarriesUserReason() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let tx = makeTx(amount: 42, context: context)
        try context.save()

        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)  // barrido + upsert
        let syncID = try #require(tx.syncID)

        context.delete(tx)
        try context.save()
        engine.drainOnce(context: context)

        let stones = try tombstones(context)
        #expect(stones.count == 1)
        #expect(stones.first?.syncID == syncID)
        #expect(stones.first?.tombstoneReason == SyncTombstoneReason.user.rawValue)
    }
}
