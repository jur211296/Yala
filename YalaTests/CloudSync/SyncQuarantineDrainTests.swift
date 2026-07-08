//
//  SyncQuarantineDrainTests.swift
//  YalaTests / CloudSync
//
//  I9 a nivel de motor: drenaje del upgrade path de la cuarentena (§F), testigo lockstep
//  `quarantinePendingCount` (§d.5 A1), guard de recreación de la tabla, y gate de quiescencia de los
//  reconcilers post-pull (§G). Container ON-DISK temp con los 3 stores (patrón SyncApplyEngineTests).
//  `.serialized` (≥2 containers por proceso).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("SyncQuarantineDrain · upgrade path + testigo + gate I9", .serialized)
@MainActor
struct SyncQuarantineDrainTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncQDrain-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "QD-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "QD-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "QD-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private let node = "0123456789abcdef"
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }
    private let epochTS = "2023-11-14T22:13:20.000Z"
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)

    /// Página JSON con UN upsert full-row de `entity` (cableada o no).
    private func page(entity: String, sid: UUID, serverSeq: Int, h: String) -> String {
        #"""
        {"deltas":[{"entity_type":"\#(entity)","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"date":"\#(epochTS)","amount":"10.5000","currency_code":"USD","note":"q",
        "amount_in_preferred_currency":"38.0000","preferred_currency_code":"PEN","exchange_rate":"3.62000000",
        "is_exchange_rate_provisional":false,"created_at":"\#(epochTS)","tag_refs":[]},
        "field_hlcs":{"money":"\#(h)","date":"\#(h)","note":"\#(h)","currency_code":"\#(h)","tag_refs":"\#(h)","created_at":"\#(h)"},
        "hlc":"\#(h)","server_seq":\#(serverSeq),"schema_version":1}],"max_server_seq":\#(serverSeq)}
        """#
    }

    /// `rawDelta` determinista de UN delta de `entity` (mismo formato que `SyncPullClient.reserialize`).
    private func rawDelta(entity: String, sid: UUID, serverSeq: Int, h: String) -> String {
        let p = try! SyncPullClient.decodePage(Data(page(entity: entity, sid: sid, serverSeq: serverSeq, h: h).utf8))
        return p.deltas[0].rawDelta
    }

    private func cursor(_ c: ModelContext) -> SyncCursor? {
        try? c.fetch(FetchDescriptor<SyncCursor>()).first
    }
    private func quarantine(_ c: ModelContext) -> [SyncQuarantine] {
        (try? c.fetch(FetchDescriptor<SyncQuarantine>())) ?? []
    }
    private func txItems(_ c: ModelContext) -> [TransactionItem] {
        (try? c.fetch(FetchDescriptor<TransactionItem>())) ?? []
    }

    // MARK: - Testigo lockstep en el INSERT (apply de entidad no cableada)

    @Test func applyPage_unwiredEntity_bumpsWitnessLockstep() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        // `budgets` no está cableada al apply → se cuarentena.
        let sid = UUID()
        let p = try SyncPullClient.decodePage(Data(page(entity: "budgets", sid: sid, serverSeq: 7, h: hlc(1)).utf8))
        #expect(engine.applyPage(p, context: context, now: applyNow))

        #expect(quarantine(context).count == 1)
        #expect(cursor(context)?.quarantinePendingCount == 1)  // testigo bumpeado en el MISMO save

        // Re-aplicar la MISMA página (dedup por serverSeq) → NO re-cuenta.
        #expect(engine.applyPage(p, context: context, now: applyNow))
        #expect(quarantine(context).count == 1)
        #expect(cursor(context)?.quarantinePendingCount == 1)
    }

    // MARK: - Drenaje re-aplica una entidad cableada + borra fila + decrementa testigo + NO avanza cursor

    @Test func drainQuarantine_reappliesWiredRow_deletesRow_decrementsWitness_keepsCursor() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        // Sembrar a mano una fila de cuarentena de `tx_items` (cableada) + testigo coherente + cursor
        // en un serverSeq alto (el drenaje NO debe tocarlo — esos seq ya pasaron).
        let sid = UUID()
        let raw = rawDelta(entity: "tx_items", sid: sid, serverSeq: 42, h: hlc(1))
        let q = SyncQuarantine(serverSeq: 42, entityType: "tx_items", syncID: sid, rawDelta: raw, hlc: hlc(1))
        context.insert(q)
        let cur = try engine.loadOrCreateCursor(context)
        cur.serverSeqCursor = 99
        cur.quarantinePendingCount = 1
        try context.save()

        // F-8: drain síncrono inmediatamente antes (aunque no haya nada que capturar).
        engine.drainOnce(context: context)
        engine.drainQuarantineOnce(context: context, now: applyNow)

        // La TX se materializó con la identidad remota; la fila de cuarentena se borró.
        let tx = txItems(context).first { $0.syncID == sid }
        #expect(tx != nil)
        #expect(quarantine(context).isEmpty)
        // Testigo decrementado en lockstep; cursor INTACTO (no se avanzó/retrocedió).
        #expect(cursor(context)?.quarantinePendingCount == 0)
        #expect(cursor(context)?.serverSeqCursor == 99)
    }

    @Test func drainQuarantine_unwiredEntity_isNoOp() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let sid = UUID()
        let raw = rawDelta(entity: "budgets", sid: sid, serverSeq: 5, h: hlc(1))
        context.insert(SyncQuarantine(serverSeq: 5, entityType: "budgets", syncID: sid, rawDelta: raw, hlc: hlc(1)))
        let cur = try engine.loadOrCreateCursor(context)
        cur.quarantinePendingCount = 1
        try context.save()

        engine.drainOnce(context: context)
        engine.drainQuarantineOnce(context: context, now: applyNow)

        // `budgets` sigue sin cablear → la fila permanece cuarentenada, testigo intacto.
        #expect(quarantine(context).count == 1)
        #expect(cursor(context)?.quarantinePendingCount == 1)
    }

    // MARK: - Guard de recreación (testigo>0 + tabla vacía → serverSeq=0 + testigo=0)

    @Test func recoverIfRecreated_witnessPositive_tableEmpty_forcesFullRepull() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let cur = try engine.loadOrCreateCursor(context)
        cur.serverSeqCursor = 500
        cur.quarantinePendingCount = 3   // decía que HABÍA filas...
        try context.save()
        // ...pero la tabla está vacía (recreada por lightweight migration).
        #expect(quarantine(context).isEmpty)

        engine.recoverIfQuarantineRecreated(context: context)

        #expect(cursor(context)?.serverSeqCursor == 0)          // re-pull completo forzado
        #expect(cursor(context)?.quarantinePendingCount == 0)   // testigo reseteado
    }

    @Test func recoverIfRecreated_coherent_isNoOp() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        // Testigo coherente con una fila viva → NO recuperar.
        let sid = UUID()
        context.insert(SyncQuarantine(serverSeq: 5, entityType: "budgets", syncID: sid,
                                      rawDelta: rawDelta(entity: "budgets", sid: sid, serverSeq: 5, h: hlc(1)), hlc: hlc(1)))
        let cur = try engine.loadOrCreateCursor(context)
        cur.serverSeqCursor = 500
        cur.quarantinePendingCount = 1
        try context.save()

        engine.recoverIfQuarantineRecreated(context: context)

        #expect(cursor(context)?.serverSeqCursor == 500)  // intacto
        #expect(cursor(context)?.quarantinePendingCount == 1)
    }

    // MARK: - Gate de quiescencia de reconcilers (§G): difiere y reintenta

    @Test func reconcilerGate_closed_defers_thenReruns_whenOpen() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        // Gate CERRADO: un pull que aplica ≥1 página DEBE diferir los reconcilers.
        engine.reconcilerQuiescenceGate = { false }
        let sid = UUID()
        let stub1 = StubPullSession(body: Data(page(entity: "tx_items", sid: sid, serverSeq: 7, h: hlc(1)).utf8))
        let client1 = SyncPullClient(baseURL: URL(string: "https://x.test")!,
                                     tokenProvider: { "jwt" }, urlSession: stub1)
        let outcome1 = await engine.pullAndApplyOnce(using: client1, context: context, now: applyNow)
        guard case .completed(let n) = outcome1, n == 1 else {
            Issue.record("primer pull no aplicó 1 página: \(outcome1)"); return
        }
        #expect(engine.pendingReconcile == true)  // diferido

        // Gate ABIERTO: un ciclo posterior (pull vacío, 0 páginas) reintenta el repair diferido.
        engine.reconcilerQuiescenceGate = { true }
        let stub2 = StubPullSession(body: Data(#"{"deltas":[],"max_server_seq":7}"#.utf8))
        let client2 = SyncPullClient(baseURL: URL(string: "https://x.test")!,
                                     tokenProvider: { "jwt" }, urlSession: stub2)
        _ = await engine.pullAndApplyOnce(using: client2, context: context, now: applyNow)
        #expect(engine.pendingReconcile == false)  // reintentado y limpiado
    }

    @Test func reconcilerGate_nil_runsImmediately_noPending() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        // Sin gate (comportamiento actual): reconcilers corren siempre, pendingReconcile queda false.
        let sid = UUID()
        let stub = StubPullSession(body: Data(page(entity: "tx_items", sid: sid, serverSeq: 7, h: hlc(1)).utf8))
        let client = SyncPullClient(baseURL: URL(string: "https://x.test")!,
                                    tokenProvider: { "jwt" }, urlSession: stub)
        _ = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow)
        #expect(engine.pendingReconcile == false)
    }
}

// MARK: - Stub HTTP session (respuesta fija)

private final class StubPullSession: SyncHTTPSession, @unchecked Sendable {
    let body: Data
    init(body: Data) { self.body = body }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}
