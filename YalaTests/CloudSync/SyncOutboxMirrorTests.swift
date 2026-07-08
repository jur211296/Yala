//
//  SyncOutboxMirrorTests.swift
//  YalaTests / CloudSync
//
//  Golden tests del CIERRE FINAL A1 (§d.5): durabilidad del `SyncOutbox` ante una lightweight migration
//  que recree la tabla. Store ON-DISK temp (3 stores personal/grupos/sync-meta, como `CloudSyncEngineTests`)
//  + directorio App Group del espejo INYECTADO (temp). La migración destructiva se SIMULA por su EFECTO
//  (borrar filas del outbox) — que SwiftData REALMENTE recree la tabla vacía es spike I0 en device; aquí
//  se prueba que la re-hidratación por DIFF recupera el estado byte-idéntico.
//
//  `.serialized` + containers on-disk propios por test (patrón de los spikes / I2).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("SyncOutboxMirror · A1 durabilidad del outbox (§d.5)", .serialized)
@MainActor
struct SyncOutboxMirrorTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncOutboxMirror-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "SOM-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "SOM-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "SOM-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    /// Motor con espejo inyectado apuntando a `mirrorDir` y sellando entries con `userID`.
    private func makeEngine(mirrorDir: URL, userID: String, nodeID: NodeID = NodeID.generate()) -> CloudSyncEngine {
        let engine = CloudSyncEngine(nodeID: nodeID)
        engine.outboxMirror = SyncOutboxMirror(directoryURL: mirrorDir)
        engine.currentUserID = userID
        return engine
    }

    private func makeTx(amount: Double, context: ModelContext) -> TransactionItem {
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: amount, currencyCode: "USD")
        tx.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        context.insert(tx)
        return tx
    }

    private func outboxRows(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>())
    }

    /// Snapshot de los campos de identidad de una fila (para comparar byte-identidad).
    private struct RowSnapshot: Equatable {
        let syncID: UUID
        let entityType: String
        let opRaw: String
        let hlc: String
        let clientMutationID: UUID
        let fieldsJSON: String
        let fieldHlcsJSON: String?
        let tombstoneReason: String?
    }

    private func snapshot(_ row: SyncOutbox) -> RowSnapshot {
        RowSnapshot(
            syncID: row.syncID, entityType: row.entityType, opRaw: row.opRaw, hlc: row.hlc,
            clientMutationID: row.clientMutationID, fieldsJSON: row.fieldsJSON,
            fieldHlcsJSON: row.fieldHlcsJSON, tombstoneReason: row.tombstoneReason
        )
    }

    /// Borra TODAS las filas de `SyncOutbox` bajo un autor NEUTRO (default) — simula la recreación
    /// destructiva de la tabla por una lightweight migration (el EFECTO: filas perdidas). El delete de
    /// `SyncOutbox` NO se captura (no está en `personalEntityNames`, anti-fuga).
    private func wipeOutbox(_ context: ModelContext) throws {
        for row in try outboxRows(context) { context.delete(row) }
        try context.save()
    }

    // MARK: - Paridad del autor (anti-drift del literal)

    @Test func mirrorAuthor_matchesEngineOutboxAuthor() {
        #expect(SyncOutboxMirror.author == CloudSyncEngine.outboxSaveAuthor)
    }

    // MARK: - (1) Migración destructiva → re-hidratación byte-idéntica

    @Test func rehydrate_afterDestructiveWipe_reinsertsByteIdentical() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = dir.appendingPathComponent("Mirror", isDirectory: true)
        let context = try makeContext(dir)
        let engine = makeEngine(mirrorDir: mirrorDir, userID: "userA")

        _ = makeTx(amount: 12.34, context: context)
        try context.save()
        engine.drainOnce(context: context)

        let original = try outboxRows(context)
        #expect(original.count == 1)
        let before = snapshot(original[0])
        let createdBefore = original[0].createdAt

        // Simula la migración destructiva: la tabla del outbox queda vacía (el espejo SOBREVIVE).
        try wipeOutbox(context)
        #expect(try outboxRows(context).isEmpty)

        // Re-hidratación por DIFF incondicional.
        engine.rehydrateOutboxFromMirror(userID: "userA", context: context)

        let after = try outboxRows(context)
        #expect(after.count == 1)
        #expect(snapshot(after[0]) == before)  // syncID/hlc/clientMutationID/fieldsJSON/op/fieldHlcs idénticos
        #expect(abs(after[0].createdAt.timeIntervalSince(createdBefore)) < 0.001)  // createdAt preservado
        #expect(after[0].author == SyncOutboxMirror.author)  // re-insertado bajo el autor de recovery
    }

    // MARK: - (2) Vaciado PARCIAL → DIFF re-inserta solo lo faltante

    @Test func rehydrate_afterPartialWipe_reinsertsOnlyMissing_noDuplicates() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = dir.appendingPathComponent("Mirror", isDirectory: true)
        let context = try makeContext(dir)
        let engine = makeEngine(mirrorDir: mirrorDir, userID: "userA")

        // 3 writes → 3 filas de outbox (3 TX distintas).
        for amt in [10.0, 20.0, 30.0] {
            _ = makeTx(amount: amt, context: context)
            try context.save()
            engine.drainOnce(context: context)
        }
        let all = try outboxRows(context)
        #expect(all.count == 3)
        let survivorKey = snapshot(all[0])   // esta la dejamos viva

        // Borra la MITAD (2 de 3) — vaciado parcial (NO count==0).
        for row in all.dropFirst() { context.delete(row) }
        try context.save()
        #expect(try outboxRows(context).count == 1)

        engine.rehydrateOutboxFromMirror(userID: "userA", context: context)

        let after = try outboxRows(context)
        #expect(after.count == 3)  // re-insertó las 2 faltantes
        // El superviviente NO se duplicó: exactamente una fila con su clientMutationID.
        #expect(after.filter { $0.clientMutationID == survivorKey.clientMutationID }.count == 1)
        // Sin duplicados en el conjunto (syncID,hlc,op).
        let keys = after.map { "\($0.syncID)|\($0.hlc)|\($0.opRaw)" }
        #expect(Set(keys).count == 3)
    }

    // MARK: - (3) No-destructiva → re-hidratación NO duplica

    @Test func rehydrate_whenOutboxIntact_doesNotDuplicate() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = dir.appendingPathComponent("Mirror", isDirectory: true)
        let context = try makeContext(dir)
        let engine = makeEngine(mirrorDir: mirrorDir, userID: "userA")

        _ = makeTx(amount: 55.0, context: context)
        try context.save()
        engine.drainOnce(context: context)
        #expect(try outboxRows(context).count == 1)

        engine.rehydrateOutboxFromMirror(userID: "userA", context: context)
        #expect(try outboxRows(context).count == 1)  // idempotente: la fila viva ya está presente
    }

    // MARK: - (4) Fila re-hidratada NO la re-captura el drain (self-echo)

    @Test func rehydratedRow_isNotRecapturedByDrain() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = dir.appendingPathComponent("Mirror", isDirectory: true)
        let context = try makeContext(dir)
        let engine = makeEngine(mirrorDir: mirrorDir, userID: "userA")

        _ = makeTx(amount: 77.0, context: context)
        try context.save()
        engine.drainOnce(context: context)

        try wipeOutbox(context)
        engine.rehydrateOutboxFromMirror(userID: "userA", context: context)
        let afterRehydrate = try outboxRows(context)
        #expect(afterRehydrate.count == 1)
        #expect(afterRehydrate[0].author == SyncOutboxMirror.author)

        // Un drain posterior NO re-captura la fila re-hidratada (echo-suppression por autor).
        engine.drainOnce(context: context)
        #expect(try outboxRows(context).count == 1)  // sin duplicado
    }

    // MARK: - (5) Archivo huérfano (crash entre purga y remove) → re-inserta, dedup por clientMutationID

    @Test func orphanMirrorFile_isReinserted_dedupByClientMutationID() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = dir.appendingPathComponent("Mirror", isDirectory: true)
        let context = try makeContext(dir)
        let engine = makeEngine(mirrorDir: mirrorDir, userID: "userA")
        let mirror = SyncOutboxMirror(directoryURL: mirrorDir)

        // Un archivo espejo SIN fila viva en el store (crash entre purgar la fila y borrar el archivo).
        let cmid = UUID()
        let orphan = OutboxMirrorEntry(
            userID: "userA", syncID: UUID(), entityType: SyncEntityType.transactionItem,
            op: SyncOutboxOp.upsert.rawValue, hlc: "2021-01-01T00:00:00.000Z-0000-00000000000000aa",
            clientMutationID: cmid, fieldsJSON: #"{"amount":"1.0000"}"#, fieldHlcsJSON: #"{"money":"h"}"#,
            tombstoneReason: nil, author: SyncOutboxMirror.author, createdAt: .now
        )
        try mirror.write(orphan)
        #expect(try outboxRows(context).isEmpty)

        engine.rehydrateOutboxFromMirror(userID: "userA", context: context)

        let after = try outboxRows(context)
        #expect(after.count == 1)
        // Re-insertado con el clientMutationID ORIGINAL → el backend deduplica al re-subir (misma fila lógica).
        #expect(after[0].clientMutationID == cmid)
        #expect(after[0].fieldsJSON == #"{"amount":"1.0000"}"#)
    }

    // MARK: - (6) Owner-scoping M1: rehydrate solo re-inserta las del userID actual; purgeAll borra todo

    @Test func ownerScoping_rehydrateIgnoresOtherUser_purgeAllClears() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = dir.appendingPathComponent("Mirror", isDirectory: true)
        let context = try makeContext(dir)
        let engine = makeEngine(mirrorDir: mirrorDir, userID: "userA")
        let mirror = SyncOutboxMirror(directoryURL: mirrorDir)

        func entry(user: String, amount: String) -> OutboxMirrorEntry {
            OutboxMirrorEntry(
                userID: user, syncID: UUID(), entityType: SyncEntityType.transactionItem,
                op: SyncOutboxOp.upsert.rawValue, hlc: "2021-01-01T00:00:00.000Z-0000-00000000000000a\(amount.first!)",
                clientMutationID: UUID(), fieldsJSON: #"{"amount":"\#(amount)"}"#, fieldHlcsJSON: #"{"money":"h"}"#,
                tombstoneReason: nil, author: SyncOutboxMirror.author, createdAt: .now
            )
        }
        try mirror.write(entry(user: "userA", amount: "1"))
        try mirror.write(entry(user: "userB", amount: "2"))
        try mirror.write(entry(user: "userB", amount: "3"))

        // Owner-scoping: solo las de userA se ven / se re-insertan.
        #expect(mirror.entriesForUser("userA").count == 1)
        #expect(mirror.entriesForUser("userB").count == 2)

        engine.rehydrateOutboxFromMirror(userID: "userA", context: context)
        let after = try outboxRows(context)
        #expect(after.count == 1)  // SOLO la de userA — las de userB NO se re-insertan

        // Las de userB siguen en disco (rehydrate NO las borra — eso lo hace el teardown de sesión).
        #expect(mirror.entriesForUser("userB").count == 2)

        // purgeAll (red M1(a), teardown de sesión invitada) borra TODO.
        mirror.purgeAll()
        #expect(mirror.entriesForUser("userA").isEmpty)
        #expect(mirror.entriesForUser("userB").isEmpty)
    }

    // MARK: - (7) Invariante deleteHistory: confirmUploaded remueve el espejo y solo entonces el corte avanza

    @Test func deleteHistoryCut_doesNotAdvancePastUnconfirmedRow_untilConfirmUploaded() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = dir.appendingPathComponent("Mirror", isDirectory: true)
        let context = try makeContext(dir)
        let engine = makeEngine(mirrorDir: mirrorDir, userID: "userA")
        let mirror = SyncOutboxMirror(directoryURL: mirrorDir)

        // Dos filas: R1 (más vieja) y R2 (más nueva), ambas con archivo espejo.
        let d1 = Date(timeIntervalSince1970: 1_000)
        let d2 = Date(timeIntervalSince1970: 2_000)
        let r1SyncID = UUID(); let r1HLC = "2021-01-01T00:00:00.000Z-0000-00000000000000a1"
        let r2SyncID = UUID(); let r2HLC = "2021-01-01T00:00:01.000Z-0000-00000000000000a2"

        func seed(syncID: UUID, hlc: String, createdAt: Date) throws {
            context.insert(SyncOutbox(
                syncID: syncID, entityType: SyncEntityType.transactionItem, op: .upsert, hlc: hlc,
                fieldsJSON: #"{"amount":"1.0000"}"#, author: SyncOutboxMirror.author, createdAt: createdAt
            ))
            try context.save()
            try mirror.write(OutboxMirrorEntry(
                userID: "userA", syncID: syncID, entityType: SyncEntityType.transactionItem,
                op: SyncOutboxOp.upsert.rawValue, hlc: hlc, clientMutationID: UUID(),
                fieldsJSON: #"{"amount":"1.0000"}"#, fieldHlcsJSON: nil, tombstoneReason: nil,
                author: SyncOutboxMirror.author, createdAt: createdAt
            ))
        }
        try seed(syncID: r1SyncID, hlc: r1HLC, createdAt: d1)
        try seed(syncID: r2SyncID, hlc: r2HLC, createdAt: d2)

        // Con boundary "sin límite" (fecha lejana), el corte lo fija la fila sin-2xx más vieja = R1.
        let farFuture = Date(timeIntervalSince1970: 9_999_999)
        #expect(try engine.deleteHistorySafeCut(drainedBoundary: farFuture, context: context) == d1)

        // Sin confirmar R1, el corte NO avanza sobre ella (sigue en d1).
        #expect(try engine.deleteHistorySafeCut(drainedBoundary: farFuture, context: context) == d1)

        // 2xx de R1: purga la fila + borra su archivo espejo.
        engine.confirmUploaded(syncID: r1SyncID, hlc: r1HLC, context: context)
        #expect(mirror.entriesForUser("userA").count == 1)  // solo queda R2 en el espejo
        #expect(try outboxRows(context).count == 1)          // solo queda R2 en el store

        // Ahora el corte AVANZA a R2 (d2) — solo tras el 2xx de R1.
        #expect(try engine.deleteHistorySafeCut(drainedBoundary: farFuture, context: context) == d2)
    }

    // MARK: - (8) Rehydrate de un TOMBSTONE → sigue siendo tombstone (no muta a upsert), reason preservado

    @Test func rehydrate_tombstone_staysTombstone_reasonPreserved_byteIdentical() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = dir.appendingPathComponent("Mirror", isDirectory: true)
        let context = try makeContext(dir)
        let engine = makeEngine(mirrorDir: mirrorDir, userID: "userA")

        // Crear → drain (upsert, asigna syncID) → borrar → drain (tombstone con syncID preservado).
        let tx = makeTx(amount: 42.0, context: context)
        try context.save()
        engine.drainOnce(context: context)
        context.delete(tx)
        try context.save()
        engine.drainOnce(context: context)

        // Aislar la fila tombstone (convive con la upsert previa).
        let tombstoneBefore = try #require(
            try outboxRows(context).first { $0.opRaw == SyncOutboxOp.tombstone.rawValue }
        )
        let before = snapshot(tombstoneBefore)
        #expect(before.opRaw == SyncOutboxOp.tombstone.rawValue)
        #expect(before.fieldsJSON == "{}")            // el borrado no lleva payload de campos
        let reasonBefore = try #require(before.tombstoneReason)  // reason presente (default .user)

        // Migración destructiva: la tabla del outbox queda vacía (el espejo SOBREVIVE).
        try wipeOutbox(context)
        #expect(try outboxRows(context).isEmpty)

        // Re-hidratación por DIFF incondicional.
        engine.rehydrateOutboxFromMirror(userID: "userA", context: context)

        // La fila tombstone re-hidratada NO se convirtió en upsert.
        let tombstoneAfter = try #require(
            try outboxRows(context).first { $0.opRaw == SyncOutboxOp.tombstone.rawValue }
        )
        #expect(snapshot(tombstoneAfter) == before)   // syncID/hlc/clientMutationID/op/fieldsJSON/reason idénticos
        #expect(tombstoneAfter.opRaw == SyncOutboxOp.tombstone.rawValue)  // sigue tombstone, no upsert
        #expect(tombstoneAfter.tombstoneReason == reasonBefore)          // reason preservado
        #expect(tombstoneAfter.author == SyncOutboxMirror.author)        // re-insertado bajo el autor de recovery
    }
}
