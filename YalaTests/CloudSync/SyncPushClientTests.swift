//
//  SyncPushClientTests.swift
//  YalaTests / CloudSync
//
//  Sender del outbox al Worker (POST /sync/push) — incremento I8e. Cubre (sin red, URLSession stub):
//    - buildDelta: entity_type = TABLA (no clase), fields VERBATIM del canon c1, tombstone sin fields,
//      hlc de fila (nunca regenerado), client_mutation_id.
//    - Clasificación de PushOutcome: 200→completed, 401→sessionExpired (salvo `yala_attest_required`→transient),
//      403→accountUnavailable, 409 yala_account_reverting (freeze §h.1)→accountUnavailable, 409 ajeno→transient,
//      500→transient, sin token→sessionExpired con la sesión borrada y transient con la sesión guardada.
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

/// Stub SECUENCIAL (I14-H2): una respuesta por llamada, en orden; registra CADA request para assertar
/// el chunking (nº de requests + tamaño real de cada body). Agotadas las respuestas → 500 (falla ruidoso).
private final class SequencedHTTPSession: SyncHTTPSession, @unchecked Sendable {
    struct Step { let status: Int; let body: Data; let error: Error? }
    private var steps: [Step]
    private(set) var requests: [URLRequest] = []
    init(_ steps: [Step]) { self.steps = steps }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let step = steps.isEmpty ? Step(status: 500, body: Data(), error: nil) : steps.removeFirst()
        if let error = step.error { throw error }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: step.status, httpVersion: nil, headerFields: nil
        )!
        return (step.body, response)
    }
}

/// Contesta con una respuesta que NO es HTTP: el transporte volvió con algo que no se puede leer como la del Worker.
private final class NonHTTPSession: SyncHTTPSession, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (Data(), URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil))
    }
}

/// La sesión guardada del SDK, mutable desde el `tokenProvider`: la renovación terminal la borra antes de volver.
private final class SesionDelSDK: @unchecked Sendable {
    var guardada: Bool
    init(guardada: Bool) { self.guardada = guardada }
}

/// Stub HTTP del drenaje de métricas. 500 a propósito: el drain reintenta y el spool CONSERVA los eventos, que es lo que
/// permite contarlos (molde `BornCloudSignUpServiceTests`).
private final class MetricsStubHTTP: SyncHTTPSession, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (Data(), HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!)
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

    private func stubClient(
        _ session: StubHTTPSession, token: String? = "test-jwt", sessionKept: Bool = false
    ) -> SyncPushClient {
        SyncPushClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { token },
            attestProvider: { nil },
            urlSession: session,
            canRenewSession: { sessionKept }
        )
    }

    /// Arranca `MetricsService` contra un spool aislado para contar lo encolado, y lo desarma después.
    private func withMetrics(_ body: (UserDefaults) async throws -> Void) async rethrows {
        let defaults = makeIsolatedDefaults(prefix: "syncPush.metrics")
        MetricsService._testReset()
        MetricsService.start(
            client: MetricsClient(baseURL: URL(string: "https://gw.test")!, urlSession: MetricsStubHTTP()),
            defaults: defaults)
        defer { MetricsService._testReset() }
        try await body(defaults)
    }

    private func canaries(_ defaults: UserDefaults, _ name: String) -> [MetricsEvent] {
        MetricsSpool.pending(defaults).filter { $0.e == "canary" && $0.n == name }
    }

    /// El envelope de error del gateway (`jsonError`), con el mismo valor en `type` y en `code`.
    private func gatewayError(_ type: String) -> Data {
        Data(#"{"error":{"message":"m","type":"\#(type)","param":null,"code":"\#(type)"}}"#.utf8)
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
        // El SDK BORRÓ la sesión: esto sí es caducada.
        let client = stubClient(session, token: nil, sessionKept: false)
        let outcome = await client.push([row])
        #expect(outcome == .sessionExpired(pending: 1))
        #expect(session.lastRequest == nil)               // no red sin sesión.
    }

    // MARK: - Sin red con el token vencido, y el 401 del attest (2026-09-16)

    // Ticket `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`. Los dos casos paraban el motor personal
    // hasta volver a primer plano y Ajustes pedía iniciar sesión, cuando volver a entrar no arregla ninguno.

    @Test("MUTACIÓN: sin token y con la sesión GUARDADA es pasajero, sin tocar la red")
    func push_noToken_withStoredSession_isTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let session = StubHTTPSession(status: 200)
        let outcome = await stubClient(session, token: nil, sessionKept: true).push([row])
        #expect(outcome == .transient, "la renovación sin red no es una sesión caducada")
        #expect(session.lastRequest == nil)
    }

    @Test("MUTACIÓN: el SDK se lee DESPUÉS de pedir el token: si la renovación borra la sesión, es caducada")
    func push_noToken_readsTheStoredSessionAfterTheRequest() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        // El SDK borra la sesión ANTES de lanzar (`SupabaseSessionRenewalContractTests`): antes de pedir el token estaba.
        let sesion = SesionDelSDK(guardada: true)
        let client = SyncPushClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { sesion.guardada = false; return nil },
            urlSession: StubHTTPSession(status: 200),
            canRenewSession: { sesion.guardada })
        #expect(await client.push([row]) == .sessionExpired(pending: 1))
    }

    @Test("MUTACIÓN: el 401 `yala_attest_required` es pasajero y NO toca la racha del teléfono")
    func push_401_attestRequired_isTransient_andLeavesThePhoneStreakAlone() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        try racha.seedTerminal()
        let antes = GroupsAttestStreakStore.current()
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let client = stubClient(StubHTTPSession(status: 401, body: gatewayError(GatewayErrorEnvelope.attestRequiredType)))
        #expect(await client.push([row]) == .transient, "volver a entrar no arregla un attest: no es sesión caducada")
        // La puerta del runtime ya consiguió el token: este 401 no habla del teléfono. Ni suma un rechazo ni la borra.
        #expect(GroupsAttestStreakStore.current() == antes)
    }

    @Test("MUTACIÓN: el 401 `yala_attest_invalid` sigue siendo sesión caducada, con la sesión guardada y sin tocar la racha")
    func push_401_attestInvalid_isStillSessionExpired() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        try racha.seedTerminal()
        let antes = GroupsAttestStreakStore.current()
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let client = stubClient(StubHTTPSession(status: 401, body: gatewayError("yala_attest_invalid")), sessionKept: true)
        #expect(await client.push([row]) == .sessionExpired(pending: 1))
        #expect(GroupsAttestStreakStore.current() == antes)
    }

    @Test("MUTACIÓN: el canario de sesión caducada solo sale con la sesión borrada, y el 401 del attest tiene el suyo")
    func push_canaries_followTheCause() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        await withMetrics { defaults in
            _ = await stubClient(StubHTTPSession(status: 200), token: nil, sessionKept: true).push([row])
            #expect(canaries(defaults, "cloudSyncBlockedByExpiredSession").isEmpty,
                    "un corte de red no es una sesión caducada: inflaría el canario")

            _ = await stubClient(StubHTTPSession(status: 200), token: nil, sessionKept: false).push([row])
            #expect(canaries(defaults, "cloudSyncBlockedByExpiredSession").count == 1)

            _ = await stubClient(StubHTTPSession(status: 401, body: gatewayError(GatewayErrorEnvelope.attestRequiredType)))
                .push([row])
            #expect(canaries(defaults, "cloudSyncBlockedByExpiredSession").count == 1, "el 401 del attest no es caducada")
            #expect(canaries(defaults, "cloudSyncAttestRequired").map(\.d) == ["push"])

            // El motor reintenta con backoff: el mismo 401 en la vuelta siguiente no vuelve a contar en este proceso.
            _ = await stubClient(StubHTTPSession(status: 401, body: gatewayError(GatewayErrorEnvelope.attestRequiredType)))
                .push([row])
            #expect(canaries(defaults, "cloudSyncAttestRequired").count == 1, "una vez por proceso y ruta")
        }
    }

    // MARK: - Chunking (I14-H2, corrida device 2026-07-12)

    /// Body 200-OK con `n` results applied (cmids arbitrarios — push solo decodifica, no correlaciona).
    private func okBody(_ n: Int) -> Data {
        let items = (0..<n).map { _ in
            #"{"sync_id":"\#(UUID().uuidString.lowercased())","client_mutation_id":"\#(UUID().uuidString.lowercased())","status":"applied"}"#
        }
        return Data(#"{"results":[\#(items.joined(separator: ","))]}"#.utf8)
    }

    private func makeRows(_ n: Int, context: ModelContext) -> [SyncOutbox] {
        (0..<n).map { i in
            makeUpsertRow(fieldsJSON: #"{"note":"r\#(i)"}"#, fieldHlcsJSON: #"{"note":"h"}"#,
                          hlc: "h\(i)", context: context)
        }
    }

    @Test func push_chunks_splitsRequests_andAggregatesResults() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let rows = makeRows(5, context: context)
        let session = SequencedHTTPSession([
            .init(status: 200, body: okBody(2), error: nil),
            .init(status: 200, body: okBody(2), error: nil),
            .init(status: 200, body: okBody(1), error: nil),
        ])
        let client = SyncPushClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { "jwt" }, urlSession: session, pushChunkSize: 2)

        let outcome = await client.push(rows)
        guard case .completed(let results) = outcome else {
            Issue.record("expected .completed, got \(outcome)"); return
        }
        #expect(results.count == 5)                       // agregado de los 3 chunks
        #expect(session.requests.count == 3)              // 2+2+1
        // Cada BODY lleva exactamente su chunk (contenido REAL del wire, lección d49d2e47).
        let sizes = session.requests.map { req -> Int in
            let body = String(data: req.httpBody ?? Data(), encoding: .utf8) ?? ""
            return body.components(separatedBy: "\"client_mutation_id\"").count - 1
        }
        #expect(sizes == [2, 2, 1])
    }

    /// Chunk que falla TRAS chunks confirmados → `.completed(parciales)`: el caller purga lo confirmado
    /// y el próximo intento re-emite solo el resto (progreso incremental — el corazón del fix H2).
    @Test func push_chunkFailureAfterProgress_returnsPartialCompleted() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let rows = makeRows(4, context: context)
        let session = SequencedHTTPSession([
            .init(status: 200, body: okBody(2), error: nil),
            .init(status: 0, body: Data(), error: URLError(.timedOut)),   // el -1001 real del device
        ])
        let client = SyncPushClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { "jwt" }, urlSession: session, pushChunkSize: 2)

        let outcome = await client.push(rows)
        guard case .completed(let results) = outcome else {
            Issue.record("expected .completed(parciales), got \(outcome)"); return
        }
        #expect(results.count == 2)                       // SOLO el chunk confirmado
        #expect(session.requests.count == 2)              // no siguió empujando tras el fallo
    }

    /// `continueWhile` se pregunta ANTES de cada chunk (ticket `displaced-migration-leader-keeps-uploading-after-a-takeover`):
    /// con `false` tras el primero, el segundo no sale y lo confirmado se entrega. El control con `true` sube los tres.
    @Test func push_continueWhile_isAskedBeforeEveryChunk() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let rows = makeRows(5, context: context)
        let session = SequencedHTTPSession([
            .init(status: 200, body: okBody(2), error: nil),
            .init(status: 200, body: okBody(2), error: nil),
            .init(status: 200, body: okBody(1), error: nil),
        ])
        let client = SyncPushClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { "jwt" }, urlSession: session, pushChunkSize: 2)
        var asked = 0
        let outcome = await client.push(rows, continueWhile: { asked += 1; return asked == 1 })
        guard case .completed(let results) = outcome else {
            Issue.record("expected .completed(parciales), got \(outcome)"); return
        }
        #expect(results.count == 2, "solo el primer chunk")
        #expect(session.requests.count == 1, "el segundo chunk no sale")
        #expect(asked == 2)
    }

    /// Con `false` desde el principio no sale nada y es `.transient`, como un primer chunk fallido.
    @Test func push_continueWhileFalseFromTheStart_sendsNothing() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let rows = makeRows(3, context: context)
        let session = SequencedHTTPSession([.init(status: 200, body: okBody(2), error: nil)])
        let client = SyncPushClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { "jwt" }, urlSession: session, pushChunkSize: 2)
        #expect(await client.push(rows, continueWhile: { false }) == .transient)
        #expect(session.requests.isEmpty)
    }

    /// Primer chunk falla → el outcome del fallo sube TAL CUAL (conserva la clasificación).
    @Test func push_firstChunkFails_preservesOutcome() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let rows = makeRows(4, context: context)
        let session = SequencedHTTPSession([
            .init(status: 0, body: Data(), error: URLError(.timedOut)),
        ])
        let client = SyncPushClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { "jwt" }, urlSession: session, pushChunkSize: 2)

        let outcome = await client.push(rows)
        #expect(outcome == .transient)
        #expect(session.requests.count == 1)
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

    // MARK: - El testigo de la subida que no llegó (2026-09-25)

    // Ticket `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`. `.transient` no es «la subida falló»: también
    // trae una fila que no se deja convertir, que es de este teléfono. El testigo separa las dos para que el cierre en la nube
    // diga «no llegaron a la nube, inténtalo en un rato» solo cuando el SERVIDOR falló.

    /// Cada salida `.transient` que habló con el servidor enciende el testigo. Una fila por rama: con una sola, quitar la
    /// marca de cualquier otra dejaría esto verde (`un-arreglo-en-n-sitios-se-prueba-en-los-n`).
    @Test("MUTACIÓN: cada `.transient` que chocó con el servidor enciende el testigo")
    func witness_everyServerFailureLightsIt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let casos: [(String, StubHTTPSession)] = [
            ("sin red", StubHTTPSession(error: URLError(.notConnectedToInternet))),
            ("timeout", StubHTTPSession(error: URLError(.timedOut))),
            ("200 ilegible", StubHTTPSession(status: 200, body: Data("no es json".utf8))),
            ("401 del attest", StubHTTPSession(status: 401, body: gatewayError("yala_attest_required"))),
            ("409 que no es la reversa", StubHTTPSession(status: 409, body: Data("conflict".utf8))),
            ("500", StubHTTPSession(status: 500)),
            ("502", StubHTTPSession(status: 502)),
            ("429", StubHTTPSession(status: 429)),
            ("400 no cableado", StubHTTPSession(status: 400)),
        ]
        for (nombre, session) in casos {
            let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
            let client = stubClient(session)
            #expect(await client.push([row]) == .transient, "\(nombre)")
            #expect(client.lastPushFailedAtServer, "\(nombre): la subida no llegó al servidor")
        }
    }

    @Test("MUTACIÓN: una respuesta que no es HTTP enciende el testigo")
    func witness_nonHTTPResponseLightsIt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let client = SyncPushClient(baseURL: URL(string: "https://example.test")!, tokenProvider: { "jwt" },
                                    urlSession: NonHTTPSession())
        #expect(await client.push([row]) == .transient)
        #expect(client.lastPushFailedAtServer)
    }

    /// El token que no llega con la sesión GUARDADA es un refresh HTTP que no volvió: la subida no llegó por la red.
    @Test("MUTACIÓN: sin token con la sesión guardada enciende el testigo; con la sesión borrada es caducada y no")
    func witness_tokenRefreshThatDidNotComeBackLightsIt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let guardada = stubClient(StubHTTPSession(), token: nil, sessionKept: true)
        #expect(await guardada.push([row]) == .transient)
        #expect(guardada.lastPushFailedAtServer)

        let borrada = stubClient(StubHTTPSession(), token: nil, sessionKept: false)
        #expect(await borrada.push([row]) == .sessionExpired(pending: 1))
        #expect(!borrada.lastPushFailedAtServer, "la sesión caducada ya dice su causa")
    }

    /// Lo del teléfono no lo enciende: una fila que no se deja convertir no ha hablado con nadie, y culpar al servidor de
    /// ella sería mentir en la otra dirección.
    @Test("MUTACIÓN: una fila que no se deja convertir y el corte de `continueWhile` no encienden el testigo")
    func witness_phoneSideFailuresDoNotLightIt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let rara = SyncOutbox(syncID: UUID(), entityType: "NotAWiredClass", op: .upsert, hlc: "x",
                              fieldsJSON: "{}", author: "")
        context.insert(rara)
        let session = StubHTTPSession(status: 500)
        let client = stubClient(session)
        #expect(await client.push([rara]) == .transient)
        #expect(!client.lastPushFailedAtServer)
        #expect(session.lastRequest == nil, "control: no llegó a la red")

        let rows = makeRows(3, context: context)
        let corte = stubClient(StubHTTPSession(status: 500))
        #expect(await corte.push(rows, continueWhile: { false }) == .transient)
        #expect(!corte.lastPushFailedAtServer)
    }

    /// Un push por trozos que confirma el primero y falla en el segundo devuelve `.completed(parciales)`: la subida quedó a
    /// medias, y el testigo tiene que decirlo aunque el outcome no sea `.transient` (review adversarial, dos lentes).
    @Test("MUTACIÓN: un trozo que falla tras otro confirmado deja el testigo encendido con `.completed`")
    func witness_partialChunkedPushLightsIt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let rows = makeRows(4, context: context)
        let session = SequencedHTTPSession([
            .init(status: 200, body: okBody(2), error: nil),
            .init(status: 503, body: Data(), error: nil),
        ])
        let client = SyncPushClient(baseURL: URL(string: "https://example.test")!, tokenProvider: { "jwt" },
                                    urlSession: session, pushChunkSize: 2)
        guard case .completed(let parciales) = await client.push(rows) else {
            Issue.record("esperaba .completed(parciales)"); return
        }
        #expect(parciales.count == 2, "control: solo el primer trozo")
        #expect(client.lastPushFailedAtServer)

        // Control: los dos trozos bien ⇒ apagado.
        let bien = SyncPushClient(baseURL: URL(string: "https://example.test")!, tokenProvider: { "jwt" },
                                  urlSession: SequencedHTTPSession([.init(status: 200, body: okBody(2), error: nil),
                                                                    .init(status: 200, body: okBody(2), error: nil)]),
                                  pushChunkSize: 2)
        _ = await bien.push(rows)
        #expect(!bien.lastPushFailedAtServer)
    }

    /// Un 200 cuyo resultado es `rejected` con `upstream_*`: el Worker contestó y su Postgres no aplicó la fila. La fila sigue
    /// viva y la subida no llegó.
    @Test("MUTACIÓN: un rechazo `upstream_*` en `applyResults` enciende el testigo; uno aplicado no")
    func witness_upstreamRejectionLightsIt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let cmid = UUID(); let sid = UUID()
        _ = makeUpsertRow(fieldsJSON: #"{"amount":"1.0000"}"#, fieldHlcsJSON: #"{"money":"h"}"#, hlc: "hlc-4",
                          syncID: sid, clientMutationID: cmid, context: context)
        let rows = try context.fetch(FetchDescriptor<SyncOutbox>())
        let client = stubClient(StubHTTPSession())
        await client.applyResults([makeResult(syncID: sid, cmid: cmid, status: "rejected", reason: "upstream_500")],
                                  rows: rows, engine: engine, context: context)
        #expect(client.lastPushFailedAtServer)

        let otro = stubClient(StubHTTPSession())
        await otro.applyResults([makeResult(syncID: sid, cmid: cmid, status: "applied", reason: nil)],
                                rows: rows, engine: engine, context: context)
        #expect(!otro.lastPushFailedAtServer, "control: aplicada, la subida llegó")
    }

    /// Describe la ÚLTIMA llamada: sin el reset al entrar, un 500 de antes teñiría la fila rara de ahora.
    @Test("MUTACIÓN: el testigo se baja al entrar en cada `push`")
    func witness_isResetOnEveryPush() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeUpsertRow(fieldsJSON: "{}", fieldHlcsJSON: "{}", hlc: "h", context: context)
        let rara = SyncOutbox(syncID: UUID(), entityType: "NotAWiredClass", op: .upsert, hlc: "x",
                              fieldsJSON: "{}", author: "")
        context.insert(rara)
        let client = stubClient(StubHTTPSession(status: 500))
        #expect(await client.push([row]) == .transient)
        #expect(client.lastPushFailedAtServer, "control: el 500 lo enciende")
        #expect(await client.push([rara]) == .transient)
        #expect(!client.lastPushFailedAtServer)
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
