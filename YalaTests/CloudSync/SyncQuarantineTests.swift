//
//  SyncQuarantineTests.swift
//  YalaTests / CloudSync
//
//  Cuarentena de deltas remotos NO materializables (I8f-1, test #5): un `entity_type` NO cableado al
//  apply → fila `SyncQuarantine` con `rawDelta` verbatim + cursor avanza en el MISMO save; el re-pull de
//  la misma página NO duplica (dedup por `serverSeq`). Container ON-DISK temp con los 3 stores.
//  I12 completa: las 16 tablas de dominio están cableadas → el único ejemplo NO-cableado es un
//  `entity_type` fuera del manifest (`LegacyUnmappedEntity`, poison-row).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("SyncQuarantine · encolado + dedup I8f-1", .serialized)
@MainActor
struct SyncQuarantineTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncQuarantine-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContainer(_ dir: URL) throws -> ModelContainer {
        let personalCfg = ModelConfiguration(
            "SQ-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "SQ-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "SQ-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        return try ModelContainer(for: SwiftDataConfiguration.schema,
                                  configurations: personalCfg, groupsCfg, syncMetaCfg)
    }

    private let node = "0123456789abcdef"
    private func hlc(_ c: Int) -> String { "2023-11-14T22:13:20.000Z-\(String(format: "%04x", c))-\(node)" }
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)

    /// Página con UN delta de una tabla NO cableada (`LegacyUnmappedEntity`, fuera del manifest).
    private func unwiredPage(sid: UUID, serverSeq: Int) -> String {
        #"""
        {"deltas":[{"entity_type":"LegacyUnmappedEntity","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"name":"Cash"},
        "field_hlcs":{"name":"\#(hlc(1))"},"hlc":"\#(hlc(1))","server_seq":\#(serverSeq),"schema_version":1}],
        "max_server_seq":\#(serverSeq)}
        """#
    }

    private func quarantine(_ context: ModelContext) -> [SyncQuarantine] {
        (try? context.fetch(FetchDescriptor<SyncQuarantine>())) ?? []
    }

    @Test func unknownEntityType_isQuarantined_withRawDelta_cursorAdvances() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let page = try SyncPullClient.decodePage(Data(unwiredPage(sid: sid, serverSeq: 12).utf8))
        engine.applyPage(page, context: context, now: applyNow)

        let rows = quarantine(context)
        #expect(rows.count == 1)
        let q = try #require(rows.first)
        #expect(q.entityType == "LegacyUnmappedEntity")
        #expect(q.serverSeq == 12)
        #expect(q.syncID == sid)
        #expect(q.hlc == hlc(1))
        // rawDelta round-trippea (re-decodable a un PulledDelta con los mismos datos).
        let redecoded = try SyncPullClient.decodePage(Data(#"{"deltas":[\#(q.rawDelta)],"max_server_seq":12}"#.utf8))
        #expect(redecoded.deltas.first?.entityType == "LegacyUnmappedEntity")
        #expect(redecoded.deltas.first?.syncID == sid)
        // Cursor avanzó en el MISMO save (D-5).
        #expect((try context.fetch(FetchDescriptor<SyncCursor>()).first)?.serverSeqCursor == 12)
    }

    @Test func reapplySamePage_doesNotDuplicate_dedupByServerSeq() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let page = try SyncPullClient.decodePage(Data(unwiredPage(sid: UUID(), serverSeq: 5).utf8))
        engine.applyPage(page, context: context, now: applyNow)
        engine.applyPage(page, context: context, now: applyNow)  // re-pull idempotente
        #expect(quarantine(context).count == 1)  // dedup por serverSeq
    }

    @Test func resetServerSeqCursor_forcesZero() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        engine.applyPage(try SyncPullClient.decodePage(Data(unwiredPage(sid: UUID(), serverSeq: 30).utf8)),
                         context: context, now: applyNow)
        #expect((try context.fetch(FetchDescriptor<SyncCursor>()).first)?.serverSeqCursor == 30)
        engine.resetServerSeqCursor(context: context)  // §d.5 A1 hook (I9)
        #expect((try context.fetch(FetchDescriptor<SyncCursor>()).first)?.serverSeqCursor == 0)
    }
}
