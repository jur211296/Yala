//
//  SyncPushClientTests.swift
//  YalaTests / CloudSync
//
//  Sender del outbox al Worker (POST /sync/push) — incremento I8e. Cubre (sin red, URLSession stub):
//    - buildDelta: entity_type = TABLA (no clase), fields VERBATIM del canon c1, tombstone sin fields,
//      hlc de fila (nunca regenerado), client_mutation_id.
//    - Clasificación de PushOutcome: 200→completed, 401→sessionExpired, 403→accountUnavailable,
//      409 yala_account_reverting (freeze §h.1)→accountUnavailable, 409 ajeno→transient, 500→transient.
//    - applyResults: applied/noop → confirmUploaded purga la fila; rejected → dead-letter (rejectedReason)
//      + la fila NO se purga.
//
//  `.serialized` + container on-disk propio por test (patrón de CloudSyncEngineTests: el motor lee del
//  History por-CONTAINER).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - URLSession stub

/// Stub de `SyncHTTPSession`: devuelve una respuesta fija (o lanza) y captura el último request.
private final class StubHTTPSession: SyncHTTPSession, @unchecked Sendable {
    let status: Int
    let body: Data
    let error: Error?
    private(set) var lastRequest: URLRequest?

    init(status: Int = 200, body: Data = Data(), error: Error? = nil) {
        self.status = status
        self.body = body
        self.error = error
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let error { throw error }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
        )!
        return (body, response)
    }
}

@Suite("SyncPushClient · sender I8e", .serialized)
@MainActor
struct SyncPushClientTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncPushClient-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "SPC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "SPC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "SPC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    /// Fila de outbox `upsert` con `fields`/`field_hlcs` crudos + hlc/clientMutationID fijos.
    private func makeUpsertRow(
        entityType: String = SyncEntityType.transactionItem,
        fieldsJSON: String,
        fieldHlcsJSON: String,
        hlc: String,
        syncID: UUID = UUID(),
        clientMutationID: UUID = UUID(),
        context: ModelContext
    ) -> SyncOutbox {
        let row = SyncOutbox(
            syncID: syncID, entityType: entityType, op: .upsert, hlc: hlc,
            clientMutationID: clientMutationID, fieldsJSON: fieldsJSON,
            fieldHlcsJSON: fieldHlcsJSON, author: ""
        )
        context.insert(row)
        try? context.save()
        return row
    }

    private func stubClient(_ session: StubHTTPSession, token: String? = "test-jwt") -> SyncPushClient {
        SyncPushClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { token },
            attestProvider: { nil },
            urlSession: session
        )
    }

    // MARK: - buildDelta

    @Test func buildDelta_upsert_mapsClassToTable_andEmbedsRawFields() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fields = #"{"amount":"12.5000","note":"hola"}"#
        let fieldHlcs = #"{"money":"2026-07-07T00:00:00.000Z-0001-0123456789abcdef"}"#
        let hlc = "2026-07-07T00:00:00.000Z-0001-0123456789abcdef"
        let cmid = UUID()
        let sid = UUID()
        let row = makeUpsertRow(
            fieldsJSON: fields, fieldHlcsJSON: fieldHlcs, hlc: hlc,
            syncID: sid, clientMutationID: cmid, context: context
        )
        let client = stubClient(StubHTTPSession())

        let delta = try client.buildDelta(from: row)
        // entity_type = la TABLA Postgres, no el nombre de clase.
        #expect(delta.entityType == "tx_items")
        #expect(delta.syncID == sid)
        #expect(delta.op == .upsert)
        #expect(delta.hlc == hlc)                         // HLC de FILA, no regenerado.
        #expect(delta.clientMutationID == cmid)
        // fields/field_hlcs = los strings crudos, byte-idénticos.
        #expect(delta.fieldsRawJSON == fields)
        #expect(delta.fieldHlcsRawJSON == fieldHlcs)

        // El JSON de wire embebe los fields VERBATIM (money como string, sin re-serializar).
        let wire = SyncPushClient.encodeDelta(delta)
        #expect(wire.contains(#""fields":{"amount":"12.5000","note":"hola"}"#))
        #expect(wire.contains(#""entity_type":"tx_items""#))
        #expect(wire.contains("\"hlc\":\"\(hlc)\""))
    }

    @Test func buildDelta_tombstone_hasNoFields() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let hlc = "2026-07-07T00:00:00.000Z-0001-0123456789abcdef"
        let row = SyncOutbox(
            syncID: UUID(), entityType: SyncEntityType.category, op: .tombstone, hlc: hlc,
            fieldsJSON: "{}", fieldHlcsJSON: nil, author: "", tombstoneReason: "user"
        )
        context.insert(row); try context.save()
        let client = stubClient(StubHTTPSession())

        let delta = try client.buildDelta(from: row)
        #expect(delta.entityType == "categories")
        #expect(delta.op == .tombstone)
        #expect(delta.fieldsRawJSON == nil)
        #expect(delta.fieldHlcsRawJSON == nil)
        let wire = SyncPushClient.encodeDelta(delta)
        #expect(!wire.contains("\"fields\""))
        #expect(!wire.contains("\"field_hlcs\""))
        #expect(wire.contains("\"op\":\"tombstone\""))
    }

    @Test func buildDelta_unknownEntity_throws() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = SyncOutbox(
            syncID: UUID(), entityType: "NotAWiredClass", op: .upsert, hlc: "x",
            fieldsJSON: "{}", author: ""
        )
        context.insert(row)
        let client = stubClient(StubHTTPSession())
        #expect(throws: SyncPushError.self) { try client.buildDelta(from: row) }
    }

    // MARK: - PushOutcome classification

    @Test func push_200_returnsCompletedResults() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let cmid = UUID(); let sid = UUID()
        let row = makeUpsertRow(
            fieldsJSON: #"{"note":"a"}"#, fieldHlcsJSON: #"{"note":"h"}"#, hlc: "h",
            syncID: sid, clientMutationID: cmid, context: context
        )
        let respBody = Data(#"{"results":[{"sync_id":"\#(sid.uuidString.lowercased())","client_mutation_id":"\#(cmid.uuidString.lowercased())","status":"applied"}]}"#.utf8)
        let client = stubClient(StubHTTPSession(status: 200, body: respBody))

        let outcome = await client.push([row])
        guard case .completed(let results) = outcome else {
            Issue.record("expected .completed, got \(outcome)"); return
        }
        #expect(results.count == 1)
        #expect(results.first?.status == .applied)
        #expect(results.first?.clientMutationID == cmid.uuidString.lowercased())
    }

    @Test func push_401_returnsSessionExpired() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let client = stubClient(StubHTTPSession(status: 401, body: Data()))
        let outcome = await client.push([row])
        #expect(outcome == .sessionExpired(pending: 1))
    }

    @Test func push_403_returnsAccountUnavailable() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let client = stubClient(StubHTTPSession(status: 403, body: Data()))
        let outcome = await client.push([row])
        #expect(outcome == .accountUnavailable)
    }

    @Test func push_409_reverting_returnsAccountUnavailable() async throws {
        // Freeze de la reversa (§h.1): 409 con type `yala_account_reverting` → STOP (mismo trato que
        // 403); los deltas NO se purgan ni dead-letterean.
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let body = Data(#"{"error":{"message":"reversa","type":"yala_account_reverting","param":null,"code":"yala_account_reverting"}}"#.utf8)
        let client = stubClient(StubHTTPSession(status: 409, body: body))
        let outcome = await client.push([row])
        #expect(outcome == .accountUnavailable)
    }

    @Test func push_409_unknownBody_returnsTransient() async throws {
        // Un 409 AJENO (sin el envelope del gateway, o con otro type) conserva el trato previo: transient.
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let client = stubClient(StubHTTPSession(status: 409, body: Data("conflict".utf8)))
        let outcome = await client.push([row])
        #expect(outcome == .transient)
    }

    @Test func push_500_returnsTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let client = stubClient(StubHTTPSession(status: 500, body: Data()))
        let outcome = await client.push([row])
        #expect(outcome == .transient)
    }

    @Test func push_networkError_returnsTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let client = stubClient(StubHTTPSession(error: URLError(.notConnectedToInternet)))
        let outcome = await client.push([row])
        #expect(outcome == .transient)
    }

    @Test func push_noToken_returnsSessionExpired_withoutHittingNetwork() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let session = StubHTTPSession(status: 200)
        let client = stubClient(session, token: nil)
        let outcome = await client.push([row])
        #expect(outcome == .sessionExpired(pending: 1))
        #expect(session.lastRequest == nil)               // no red sin sesión.
    }

    @Test func push_sendsAuthorizationHeader() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: #"{"note":"a"}"#, fieldHlcsJSON: #"{"note":"h"}"#, hlc: "h", context: context)
        let session = StubHTTPSession(status: 200, body: Data(#"{"results":[]}"#.utf8))
        let client = stubClient(session, token: "jwt-abc")
        _ = await client.push([row])
        #expect(session.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-abc")
        #expect(session.lastRequest?.url?.absoluteString == "https://example.test/sync/push")
    }

    // MARK: - applyResults

    @Test func applyResults_applied_purgesRow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let cmid = UUID(); let sid = UUID(); let hlc = "hlc-1"
        _ = makeUpsertRow(
            fieldsJSON: #"{"note":"a"}"#, fieldHlcsJSON: #"{"note":"h"}"#, hlc: hlc,
            syncID: sid, clientMutationID: cmid, context: context
        )
        let rows = try context.fetch(FetchDescriptor<SyncOutbox>())
        #expect(rows.count == 1)

        let result = makeResult(syncID: sid, cmid: cmid, status: "applied")
        let client = stubClient(StubHTTPSession())
        await client.applyResults([result], rows: rows, engine: engine, context: context)

        let after = try context.fetch(FetchDescriptor<SyncOutbox>())
        #expect(after.isEmpty)                             // confirmUploaded purgó la fila.
    }

    @Test func applyResults_noop_purgesRow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let cmid = UUID(); let sid = UUID()
        _ = makeUpsertRow(
            fieldsJSON: #"{"note":"a"}"#, fieldHlcsJSON: #"{"note":"h"}"#, hlc: "hlc-2",
            syncID: sid, clientMutationID: cmid, context: context
        )
        let rows = try context.fetch(FetchDescriptor<SyncOutbox>())
        let result = makeResult(syncID: sid, cmid: cmid, status: "noop")
        let client = stubClient(StubHTTPSession())
        await client.applyResults([result], rows: rows, engine: engine, context: context)
        #expect(try context.fetch(FetchDescriptor<SyncOutbox>()).isEmpty)
    }

    @Test func applyResults_rejected_setsDeadLetter_andKeepsRow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let cmid = UUID(); let sid = UUID()
        _ = makeUpsertRow(
            fieldsJSON: #"{"amount":"1.0000"}"#, fieldHlcsJSON: #"{"money":"h"}"#, hlc: "hlc-3",
            syncID: sid, clientMutationID: cmid, context: context
        )
        let rows = try context.fetch(FetchDescriptor<SyncOutbox>())
        let result = makeResult(syncID: sid, cmid: cmid, status: "rejected", reason: "coherence_group_partial:money")
        let client = stubClient(StubHTTPSession())
        await client.applyResults([result], rows: rows, engine: engine, context: context)

        let after = try context.fetch(FetchDescriptor<SyncOutbox>())
        #expect(after.count == 1)                          // NO se purga.
        #expect(after.first?.rejectedReason == "coherence_group_partial:money")
        #expect(after.first?.rejectedAt != nil)
    }

    /// Un `rejected` con reason `upstream_*` = error TRANSITORIO del Worker → NO dead-letter (la fila
    /// queda intacta sin `rejectedReason`, para reintentarse), NO purga. (Review adversarial I8e, A.)
    @Test func applyResults_upstreamError_notDeadLettered_rowKeptClean() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let cmid = UUID(); let sid = UUID()
        _ = makeUpsertRow(
            fieldsJSON: #"{"amount":"1.0000"}"#, fieldHlcsJSON: #"{"money":"h"}"#, hlc: "hlc-4",
            syncID: sid, clientMutationID: cmid, context: context
        )
        let rows = try context.fetch(FetchDescriptor<SyncOutbox>())
        let result = makeResult(syncID: sid, cmid: cmid, status: "rejected", reason: "upstream_500")
        let client = stubClient(StubHTTPSession())
        await client.applyResults([result], rows: rows, engine: engine, context: context)

        let after = try context.fetch(FetchDescriptor<SyncOutbox>())
        #expect(after.count == 1)                          // NO se purga (se reintenta).
        #expect(after.first?.rejectedReason == nil)        // NO dead-letter (no es rechazo definitivo).
        #expect(after.first?.rejectedAt == nil)
    }

    @Test func applyResults_unmatchedMutation_isNoOp() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        _ = makeUpsertRow(
            fieldsJSON: #"{"note":"a"}"#, fieldHlcsJSON: #"{"note":"h"}"#, hlc: "hlc-4",
            syncID: UUID(), clientMutationID: UUID(), context: context
        )
        let rows = try context.fetch(FetchDescriptor<SyncOutbox>())
        // Un resultado con un client_mutation_id que NO corresponde a ninguna fila.
        let result = makeResult(syncID: UUID(), cmid: UUID(), status: "applied")
        let client = stubClient(StubHTTPSession())
        await client.applyResults([result], rows: rows, engine: engine, context: context)
        #expect(try context.fetch(FetchDescriptor<SyncOutbox>()).count == 1)  // fila intacta.
    }

    // MARK: - helpers

    private func makeResult(syncID: UUID, cmid: UUID, status: String, reason: String? = nil) -> SyncDeltaResult {
        var json = #"{"sync_id":"\#(syncID.uuidString.lowercased())","client_mutation_id":"\#(cmid.uuidString.lowercased())","status":"\#(status)""#
        if let reason { json += #","reason":"\#(reason)""# }
        json += "}"
        return try! JSONDecoder().decode(SyncDeltaResult.self, from: Data(json.utf8))
    }
}
