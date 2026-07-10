//
//  SyncIdentityServiceTests.swift
//  YalaTests / CloudSync
//
//  Backfill + rebind + born-cloud capture de identidades de sync (Modo Nube, I2).
//
//  Container ON-DISK temp propio con el schema completo (3 stores, patrón de los spikes) — el
//  backfill fetchea/inserta sobre un `ModelContext` real. `.serialized` (mutamos el flag DARK con
//  `defer { restore }` y creamos containers on-disk propios).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("SyncIdentityService · backfill/rebind/capture", .serialized)
@MainActor
struct SyncIdentityServiceTests {

    /// Fecha fija → anclas deterministas (createdAt forma parte de varias anclas).
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Infra (container on-disk con los 3 stores, espejo de producción)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncIdentity-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "SI-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "SI-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "SI-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    /// TransactionItem con contenido controlado (createdAt fijo para ancla estable).
    private func makeTx(amount: Double, currency: String = "USD", context: ModelContext) -> TransactionItem {
        let tx = TransactionItem(date: fixedDate, amount: amount, currencyCode: currency)
        tx.createdAt = fixedDate
        context.insert(tx)
        return tx
    }

    private func identityCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<SyncIdentity>())
    }

    // MARK: - Idempotencia

    @Test func backfill_isIdempotent_acrossTwoRuns() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let a = makeTx(amount: 10, context: context)
        let b = makeTx(amount: 20, context: context)
        let c = makeTx(amount: 30, context: context)
        try context.save()

        SyncIdentityService.backfillIdentities(context: context, now: now)
        let id1 = a.syncID, id2 = b.syncID, id3 = c.syncID
        #expect(id1 != nil && id2 != nil && id3 != nil)
        #expect(try identityCount(context) == 3)

        // Segunda corrida: sin cambios, mismos syncIDs, sin filas nuevas.
        SyncIdentityService.backfillIdentities(context: context, now: now)
        #expect(a.syncID == id1)
        #expect(b.syncID == id2)
        #expect(c.syncID == id3)
        #expect(try identityCount(context) == 3)
    }

    // MARK: - No-colapso

    @Test func backfill_distinctContent_getsDistinctSyncIDs() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let a = makeTx(amount: 10, context: context)
        let b = makeTx(amount: 999, currency: "EUR", context: context)
        try context.save()

        SyncIdentityService.backfillIdentities(context: context, now: now)
        #expect(a.syncID != nil)
        #expect(b.syncID != nil)
        #expect(a.syncID != b.syncID)
        #expect(try identityCount(context) == 2)
    }

    // MARK: - Rebind por ancla de contenido

    // MARK: - Colisión de anclas entre filas VIVAS (bug device 2026-07-10, residual A3 materializado)

    @Test func backfill_twoLiveRowsIdenticalContent_getDistinctSyncIDs() throws {
        // Dos filas COEXISTENTES con contenido idéntico (2 pares de InboxDraft reales del owner: misma
        // createdAt+source+rawText) — el rebind viejo les daba el MISMO syncID → el upsert server-side
        // las colapsaba (8 local vs 6 server) → divergencia Merkle PERMANENTE → failedRollback.
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let a = makeTx(amount: 42, context: context)
        let b = makeTx(amount: 42, context: context)   // ancla IDÉNTICA (misma fecha fija + monto + cuenta)
        try context.save()

        SyncIdentityService.backfillIdentities(context: context, now: now)

        let idA = try #require(a.syncID)
        let idB = try #require(b.syncID)
        #expect(idA != idB, "dos filas VIVAS jamás comparten syncID, aunque el contenido sea idéntico")
        #expect(try identityCount(context) == 2, "cada una con su testigo")
    }

    @Test func backfill_healsPreexistingLiveCollision_remintsOne() throws {
        // Auto-cura: un store que YA tiene dos filas vivas compartiendo syncID (el estado en que quedó
        // el device del owner tras la corrida con el bug) → el próximo backfill re-acuña una de las dos.
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let shared = UUID()
        let a = makeTx(amount: 42, context: context)
        let b = makeTx(amount: 42, context: context)
        a.syncID = shared
        b.syncID = shared
        try context.save()

        SyncIdentityService.backfillIdentities(context: context, now: now)

        let idA = try #require(a.syncID)
        let idB = try #require(b.syncID)
        #expect(idA != idB, "la colisión preexistente se cura re-acuñando")
        #expect(idA == shared || idB == shared, "solo UNA se re-acuña; la otra conserva el id original")
    }

    @Test func backfill_rebindsDeletedRecreated_byContentAnchor() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let original = makeTx(amount: 42, context: context)
        try context.save()
        SyncIdentityService.backfillIdentities(context: context, now: now)
        let originalID = try #require(original.syncID)
        #expect(try identityCount(context) == 1)

        // Borrar el modelo (la fila SyncIdentity sobrevive).
        context.delete(original)
        try context.save()

        // Recrear con el MISMO contenido, syncID nil.
        let recreated = makeTx(amount: 42, context: context)
        #expect(recreated.syncID == nil)
        try context.save()

        let rebindTime = Date(timeIntervalSince1970: 1_900_000_000)
        SyncIdentityService.backfillIdentities(context: context, now: rebindTime)

        // Rebind: reusa el syncID original, sin fila nueva, marca lastReboundAt.
        #expect(recreated.syncID == originalID)
        #expect(try identityCount(context) == 1)
        let row = try #require(try context.fetch(FetchDescriptor<SyncIdentity>()).first)
        #expect(row.lastReboundAt == rebindTime)
    }

    // MARK: - Modelo con syncID pero sin fila testigo (crash a mitad)

    @Test func backfill_modelWithIDButNoRow_createsRow_withoutRegenerating() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let tx = makeTx(amount: 7, context: context)
        let preassigned = UUID()
        tx.syncID = preassigned
        try context.save()
        #expect(try identityCount(context) == 0)

        SyncIdentityService.backfillIdentities(context: context, now: now)

        #expect(tx.syncID == preassigned)  // NO se regenera
        #expect(try identityCount(context) == 1)
        let row = try #require(try context.fetch(FetchDescriptor<SyncIdentity>()).first)
        #expect(row.syncID == preassigned)
        #expect(row.entityType == SyncEntityType.transactionItem)
    }

    // MARK: - ensureSyncID / captureIfEnabled

    @Test func ensureSyncID_assignsOnce_thenStable() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let tx = makeTx(amount: 1, context: context)

        #expect(tx.syncID == nil)
        SyncIdentityService.ensureSyncID(tx)
        let first = try #require(tx.syncID)
        SyncIdentityService.ensureSyncID(tx)
        #expect(tx.syncID == first)  // segunda llamada no cambia el valor
    }

    @Test func captureIfEnabled_respectsDarkFlag() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let original = CloudSyncFlags.identityCaptureEnabled
        defer { CloudSyncFlags.identityCaptureEnabled = original }

        // Flag OFF (default): no-op.
        CloudSyncFlags.identityCaptureEnabled = false
        let txOff = makeTx(amount: 2, context: context)
        SyncIdentityService.captureIfEnabled(txOff)
        #expect(txOff.syncID == nil)

        // Flag ON: captura.
        CloudSyncFlags.identityCaptureEnabled = true
        let txOn = makeTx(amount: 3, context: context)
        SyncIdentityService.captureIfEnabled(txOn)
        #expect(txOn.syncID != nil)
    }

    // MARK: - Multi-entidad (una fila testigo por tipo)

    @Test func backfill_coversMultipleEntityTypes() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let tx = makeTx(amount: 5, context: context)
        let category = Category(name: "Food", colorHex: "#111111", isIncome: false, isDefaultSeed: false)
        context.insert(category)
        let merchant = MerchantMemory(merchantCanonical: "starbucks")
        context.insert(merchant)
        try context.save()

        SyncIdentityService.backfillIdentities(context: context, now: now)

        #expect(tx.syncID != nil)
        #expect(category.syncID != nil)
        #expect(merchant.syncID != nil)
        #expect(try identityCount(context) == 3)

        let rows = try context.fetch(FetchDescriptor<SyncIdentity>())
        let types = Set(rows.map(\.entityType))
        #expect(types == [
            SyncEntityType.transactionItem,
            SyncEntityType.category,
            SyncEntityType.merchantMemory,
        ])
    }
}
