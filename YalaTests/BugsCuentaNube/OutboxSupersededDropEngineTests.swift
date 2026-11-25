//
//  OutboxSupersededDropEngineTests.swift
//  YalaTests / BugsCuentaNube
//
//  Bug A (25-nov-2026): la retirada de altas que una baja posterior deja sin efecto, sobre el motor real. Pedido por el
//  revisor con checklist: la lógica pura no prueba que se vayan la FILA y su entrada del ESPEJO, y que la baja se quede
//  en los dos. Sin el espejo, el arranque siguiente repondría el alta (`rehydrateOutboxFromMirror`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Bugs cuenta nube · A · retirada de altas sobre el motor", .serialized)
@MainActor
struct OutboxSupersededDropEngineTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OutboxSupersededDrop-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("no se pudo crear \(dir): \(error)")
        }
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "OSD-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "OSD-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "OSD-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func row(_ syncID: UUID, _ op: SyncOutboxOp, hlc: String, context: ModelContext) -> SyncOutbox {
        let row = SyncOutbox(syncID: syncID, entityType: "TransactionItem", op: op, hlc: hlc,
                             fieldsJSON: op == .upsert ? #"{"note":"x"}"# : "{}",
                             fieldHlcsJSON: op == .upsert ? #"{"note":"\#(hlc)"}"# : nil,
                             author: CloudSyncEngine.outboxSaveAuthor)
        context.insert(row)
        return row
    }

    private func mirror(_ row: SyncOutbox) -> OutboxMirrorEntry {
        OutboxMirrorEntry(userID: "u", syncID: row.syncID, entityType: row.entityType, op: row.opRaw, hlc: row.hlc,
                          clientMutationID: row.clientMutationID, fieldsJSON: row.fieldsJSON,
                          fieldHlcsJSON: row.fieldHlcsJSON, tombstoneReason: nil, author: row.author,
                          createdAt: row.createdAt)
    }

    /// Alta y baja de la misma fila, más el alta suelta de otra: se va solo la primera alta, de la cola y del espejo.
    @Test func dropsTheSupersededUpsert_fromTheOutboxAndTheMirror() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let outboxMirror = SyncOutboxMirror(directoryURL: dir.appendingPathComponent("mirror", isDirectory: true))
        engine.outboxMirror = outboxMirror

        let wiped = UUID(), kept = UUID()
        let upsert = row(wiped, .upsert, hlc: "2026-11-25T12:00:00.000Z-0000-aaaaaaaaaaaaaaaa", context: context)
        let tombstone = row(wiped, .tombstone, hlc: "2026-11-25T12:00:01.000Z-0000-aaaaaaaaaaaaaaaa", context: context)
        let other = row(kept, .upsert, hlc: "2026-11-25T12:00:02.000Z-0000-aaaaaaaaaaaaaaaa", context: context)
        try context.save()
        for r in [upsert, tombstone, other] { try outboxMirror.write(mirror(r)) }

        let dropped = engine.dropSupersededUpserts(from: [upsert, tombstone, other], context: context)
        #expect(dropped.count == 1)

        let left = try context.fetch(FetchDescriptor<SyncOutbox>())
        #expect(Set(left.map { "\($0.syncID)|\($0.opRaw)" })
                == ["\(wiped)|tombstone", "\(kept)|upsert"])
        let mirrored = outboxMirror.entriesForUser("u")
        #expect(Set(mirrored.map { "\($0.syncID)|\($0.op)" })
                == ["\(wiped)|tombstone", "\(kept)|upsert"])
    }

    /// Sin nada que retirar, no guarda ni toca el espejo.
    @Test func withoutAPair_nothingChanges() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let outboxMirror = SyncOutboxMirror(directoryURL: dir.appendingPathComponent("mirror", isDirectory: true))
        engine.outboxMirror = outboxMirror
        let only = row(UUID(), .upsert, hlc: "2026-11-25T12:00:00.000Z-0000-aaaaaaaaaaaaaaaa", context: context)
        try context.save()
        try outboxMirror.write(mirror(only))

        #expect(engine.dropSupersededUpserts(from: [only], context: context).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SyncOutbox>()).count == 1)
        #expect(outboxMirror.entriesForUser("u").count == 1)
    }
}
