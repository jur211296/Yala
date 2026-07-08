//
//  SyncUnitClockTests.swift
//  YalaTests / CloudSync
//
//  Fuente local de HLC por-unidad (I8f-2, D-A / test #1 del plan): el DRAIN puebla las unidades
//  emitidas con el HLC acuñado (mismo save que el outbox); el APPLY puebla las APLICADAS y NO las
//  saltadas por el guard D-1; el merge conserva el MAX por unidad; el tombstone (drain y apply) borra
//  la fila. Container ON-DISK temp con los 3 stores (patrón CloudSyncEngineTests). `.serialized`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("SyncUnitClock · HLC por-unidad I8f-2", .serialized)
@MainActor
struct SyncUnitClockTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncUnitClock-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "SUC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "SUC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "SUC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private let node = "0123456789abcdef"
    private func hlc(_ c: Int) -> String { "2023-11-14T22:13:20.000Z-\(String(format: "%04x", c))-\(node)" }
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)
    private let epochTS = "2023-11-14T22:13:20.000Z"
    private let epochDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func clockRow(_ syncID: UUID, _ context: ModelContext) -> SyncUnitClock? {
        SyncUnitClockStore.row(syncID: syncID, context: context)
    }

    // MARK: - Drain puebla las unidades emitidas con el HLC acuñado

    @Test func drain_populatesEmittedUnits_withMintedHLC() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        let tx = TransactionItem(date: epochDate, amount: 10, currencyCode: "USD", note: "n")
        tx.createdAt = epochDate
        context.insert(tx)
        try context.save()
        engine.drainOnce(context: context)

        let syncID = try #require(tx.syncID)
        let outboxRow = try #require(try context.fetch(FetchDescriptor<SyncOutbox>()).first)
        let row = try #require(clockRow(syncID, context))
        #expect(row.entityTable == "tx_items")  // tabla, no clase
        let map = SyncUnitClockStore.decodeMap(row.unitHlcsJSON)
        // INSERT = todas las unidades emitidas con el HLC acuñado de la fila (mismo para todas).
        #expect(map["money"] == outboxRow.hlc)
        #expect(map["note"] == outboxRow.hlc)
        #expect(map["date"] == outboxRow.hlc)
        // El mapa del clock == el field_hlcs de la fila de outbox (misma verdad).
        #expect(map == SyncUnitClockStore.decodeMap(outboxRow.fieldHlcsJSON))
    }

    // MARK: - Apply puebla las APLICADAS y NO las saltadas (guard D-1)

    @Test func apply_populatesAppliedUnits_notSkippedOnes() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        // Fila local existente + outbox pendiente money@H3 (guard D-1 activo para `money`).
        let sid = UUID()
        let tx = TransactionItem(date: epochDate, amount: 100, currencyCode: "USD")
        tx.syncID = sid
        context.insert(tx)
        let pending = SyncOutbox(syncID: sid, entityType: SyncEntityType.transactionItem, op: .upsert,
                                 hlc: hlc(3), fieldsJSON: "{}",
                                 fieldHlcsJSON: #"{"money":"\#(hlc(3))"}"#, author: "")
        context.insert(pending)
        try context.save()

        // Remoto: money@H2 (más viejo → SKIP) + note@H4 (aplica).
        let json = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"amount":"55.0000","amount_in_preferred_currency":"1.0000","preferred_currency_code":"PEN",
        "exchange_rate":"1.00000000","is_exchange_rate_provisional":false,"note":"new"},
        "field_hlcs":{"money":"\#(hlc(2))","note":"\#(hlc(4))"},"hlc":"\#(hlc(4))","server_seq":5,"schema_version":1}],
        "max_server_seq":5}
        """#
        engine.applyPage(try SyncPullClient.decodePage(Data(json.utf8)), context: context, now: applyNow)

        let row = try #require(clockRow(sid, context))
        let map = SyncUnitClockStore.decodeMap(row.unitHlcsJSON)
        #expect(map["note"] == hlc(4))   // unidad APLICADA → HLC remoto
        #expect(map["money"] == nil)     // unidad SALTADA → NO se escribe (el drain la escribiría al pushear)
    }

    // MARK: - Merge conserva el MAX por unidad

    @Test func upsert_mergeKeepsMaxPerUnit() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let sid = UUID()

        SyncUnitClockStore.upsert(syncID: sid, entityTable: "tx_items",
                                  unitHlcs: ["money": hlc(2)], context: context)
        try context.save()
        // Más viejo → NO retrocede.
        SyncUnitClockStore.upsert(syncID: sid, entityTable: "tx_items",
                                  unitHlcs: ["money": hlc(1)], context: context)
        try context.save()
        var map = SyncUnitClockStore.decodeMap(clockRow(sid, context)?.unitHlcsJSON)
        #expect(map["money"] == hlc(2))
        // Más nuevo → avanza; unidad nueva se añade sin tocar la existente.
        SyncUnitClockStore.upsert(syncID: sid, entityTable: "tx_items",
                                  unitHlcs: ["money": hlc(3), "note": hlc(1)], context: context)
        try context.save()
        map = SyncUnitClockStore.decodeMap(clockRow(sid, context)?.unitHlcsJSON)
        #expect(map["money"] == hlc(3))
        #expect(map["note"] == hlc(1))
        // Una sola fila por syncID (upsert, no insert duplicado).
        #expect(try context.fetch(FetchDescriptor<SyncUnitClock>()).count == 1)
    }

    // MARK: - Tombstone del DRAIN borra el clock

    @Test func drainTombstone_deletesClockRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        let tx = TransactionItem(date: epochDate, amount: 5, currencyCode: "USD")
        context.insert(tx)
        try context.save()
        engine.drainOnce(context: context)
        let syncID = try #require(tx.syncID)
        #expect(clockRow(syncID, context) != nil)

        context.delete(tx)
        try context.save()
        engine.drainOnce(context: context)  // emite tombstone → borra clock en el MISMO save
        #expect(clockRow(syncID, context) == nil)
    }

    // MARK: - Tombstone del APPLY borra el clock

    @Test func applyTombstone_deletesClockRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        // Born-remote → clock poblado por el apply.
        let sid = UUID()
        let upsert = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"date":"\#(epochTS)","amount":"5.0000","currency_code":"USD",
        "amount_in_preferred_currency":"5.0000","preferred_currency_code":"USD","exchange_rate":"1.00000000",
        "is_exchange_rate_provisional":false,"created_at":"\#(epochTS)"},
        "field_hlcs":{"money":"\#(hlc(1))","date":"\#(hlc(1))","currency_code":"\#(hlc(1))","created_at":"\#(hlc(1))"},
        "hlc":"\#(hlc(1))","server_seq":1,"schema_version":1}],"max_server_seq":1}
        """#
        engine.applyPage(try SyncPullClient.decodePage(Data(upsert.utf8)), context: context, now: applyNow)
        #expect(clockRow(sid, context) != nil)
        #expect(SyncUnitClockStore.decodeMap(clockRow(sid, context)?.unitHlcsJSON)["money"] == hlc(1))

        let tomb = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"tombstone",
        "fields":{},"field_hlcs":{},"hlc":"\#(hlc(5))","server_seq":2,"schema_version":1}],"max_server_seq":2}
        """#
        engine.applyPage(try SyncPullClient.decodePage(Data(tomb.utf8)), context: context, now: applyNow)
        #expect(clockRow(sid, context) == nil)
    }
}
