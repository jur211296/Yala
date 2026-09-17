//
//  PrefsSyncClientTests.swift
//  YalaTests / CloudSync
//
//  Transporte de prefs (I13), sin red (URLSession stub). Cubre: clasificación de outcomes (200/401/403/
//  409 yala_account_reverting (freeze §h.1)→accountUnavailable, 409 ajeno→transient/5xx), decode de push
//  (applied/noop + reason), decode de pull (envelope + cursor), y el body del push.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Stub HTTP session (captura el request + respuesta fija)

private final class PrefsStubSession: SyncHTTPSession, @unchecked Sendable {
    let status: Int
    let body: Data
    let error: Error?
    private(set) var lastRequest: URLRequest?
    private(set) var lastBody: Data?

    init(status: Int = 200, body: Data = Data(), error: Error? = nil) {
        self.status = status
        self.body = body
        self.error = error
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        lastBody = request.httpBody
        if let error { throw error }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

/// La sesión guardada del SDK, mutable desde el `tokenProvider`: la renovación terminal la borra antes de volver.
private final class SesionDelSDK: @unchecked Sendable {
    var guardada: Bool
    init(guardada: Bool) { self.guardada = guardada }
}

@Suite("PrefsSyncClient · I13", .serialized)
@MainActor
struct PrefsSyncClientTests {

    private let baseURL = URL(string: "https://x.test")!

    private func client(_ stub: PrefsStubSession, token: String? = "jwt", sessionKept: Bool = false) -> PrefsSyncClient {
        PrefsSyncClient(baseURL: baseURL, tokenProvider: { token }, urlSession: stub, canRenewSession: { sessionKept })
    }

    /// El envelope de error del gateway (`jsonError`), con el mismo valor en `type` y en `code`.
    private func gatewayError(_ type: String) -> Data {
        Data(#"{"error":{"message":"m","type":"\#(type)","param":null,"code":"\#(type)"}}"#.utf8)
    }

    // MARK: - Push

    @Test func push_empty_completesWithoutRequest() async {
        let stub = PrefsStubSession()
        let outcome = await client(stub).push([])
        #expect(outcome == .completed([]))
        #expect(stub.lastRequest == nil)  // sin red para batch vacío
    }

    @Test func push_noSession_sessionExpired() async {
        let stub = PrefsStubSession()
        // El SDK BORRÓ la sesión: esto sí es caducada.
        let outcome = await client(stub, token: nil, sessionKept: false).push([WirePref(key: "a", value: "1", hlc: "h")])
        #expect(outcome == .sessionExpired)
        #expect(stub.lastRequest == nil)
    }

    // MARK: - Sin red con el token vencido, y el 401 del attest (2026-09-16)

    // Ticket `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`. El runtime ignora el outcome de prefs, pero
    // el outcome no puede mentir: otro consumidor lo leería.

    @Test("MUTACIÓN: sin token y con la sesión GUARDADA, push y pull son pasajeros sin tocar la red")
    func noToken_withStoredSession_isTransient() async {
        let stub = PrefsStubSession()
        let sut = client(stub, token: nil, sessionKept: true)
        #expect(await sut.push([WirePref(key: "a", value: "1", hlc: "h")]) == .transient)
        #expect(await sut.pull(since: 0) == .transient)
        #expect(stub.lastRequest == nil)
        // Y en la dirección contraria el pull también es caducada (el push ya lo fija `push_noSession_sessionExpired`).
        #expect(await client(stub, token: nil, sessionKept: false).pull(since: 0) == .sessionExpired)
    }

    @Test("MUTACIÓN: push y pull leen el SDK DESPUÉS de pedir el token: si la renovación borra la sesión, es caducada")
    func noToken_readsTheStoredSessionAfterTheRequest() async {
        for camino in ["push", "pull"] {
            let sesion = SesionDelSDK(guardada: true)
            let sut = PrefsSyncClient(baseURL: baseURL, tokenProvider: { sesion.guardada = false; return nil },
                                      urlSession: PrefsStubSession(), canRenewSession: { sesion.guardada })
            if camino == "push" {
                #expect(await sut.push([WirePref(key: "a", value: "1", hlc: "h")]) == .sessionExpired)
            } else {
                #expect(await sut.pull(since: 0) == .sessionExpired)
            }
        }
    }

    @Test("MUTACIÓN: el 401 `yala_attest_required` es pasajero en push y pull, y NO toca la racha del teléfono")
    func attestRequired401_isTransient_andLeavesThePhoneStreakAlone() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        try racha.seedTerminal()
        let antes = GroupsAttestStreakStore.current()
        let defaults = makeIsolatedDefaults(prefix: "prefsSync.metrics")
        MetricsService._testReset()
        MetricsService.start(
            client: MetricsClient(baseURL: URL(string: "https://gw.test")!, urlSession: PrefsStubSession(status: 500)),
            defaults: defaults)
        defer { MetricsService._testReset() }

        let sut = client(PrefsStubSession(status: 401, body: gatewayError(GatewayErrorEnvelope.attestRequiredType)))
        #expect(await sut.push([WirePref(key: "a", value: "1", hlc: "h")]) == .transient)
        #expect(await sut.pull(since: 0) == .transient)
        #expect(GroupsAttestStreakStore.current() == antes, "la puerta del runtime ya consiguió el token: no es el teléfono")
        let canarios = MetricsSpool.pending(defaults).filter { $0.e == "canary" && $0.n == "cloudSyncAttestRequired" }
        #expect(canarios.compactMap(\.d).sorted() == ["prefs-pull", "prefs-push"], "cada ruta con su canario")
    }

    @Test("MUTACIÓN: el 401 `yala_attest_invalid` sigue siendo sesión caducada en push y pull, sin tocar la racha")
    func attestInvalid401_isStillSessionExpired() async throws {
        let racha = try IsolatedAttestStreak(); defer { racha.restore() }
        try racha.seedTerminal()
        let antes = GroupsAttestStreakStore.current()
        let invalido = client(PrefsStubSession(status: 401, body: gatewayError("yala_attest_invalid")), sessionKept: true)
        #expect(await invalido.push([WirePref(key: "a", value: "1", hlc: "h")]) == .sessionExpired)
        #expect(await invalido.pull(since: 0) == .sessionExpired)
        #expect(GroupsAttestStreakStore.current() == antes)
    }

    @Test func push_200_appliedAndNoop() async {
        let json = #"{"results":[{"key":"userName","status":"applied"},{"key":"voiceLanguage","status":"noop","reason":"stale"}]}"#
        let stub = PrefsStubSession(status: 200, body: Data(json.utf8))
        let outcome = await client(stub).push([WirePref(key: "userName", value: "Ana", hlc: "h1")])
        guard case .completed(let results) = outcome else { Issue.record("no completó: \(outcome)"); return }
        #expect(results.count == 2)
        #expect(results[0] == PrefPushResult(key: "userName", status: .applied, reason: nil))
        #expect(results[1] == PrefPushResult(key: "voiceLanguage", status: .noop, reason: "stale"))
    }

    @Test func push_body_shapeAndHeaders() async throws {
        let stub = PrefsStubSession(status: 200, body: Data(#"{"results":[]}"#.utf8))
        _ = await client(stub).push([WirePref(key: "userName", value: "Ana", hlc: "h1")])

        let req = try #require(stub.lastRequest)
        #expect(req.url?.absoluteString == "https://x.test/prefs/push")
        #expect(req.httpMethod == "POST")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer jwt")
        let body = try #require(stub.lastBody)
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let prefs = try #require(decoded?["prefs"] as? [[String: Any]])
        #expect(prefs.count == 1)
        #expect(prefs[0]["key"] as? String == "userName")
        #expect(prefs[0]["value"] as? String == "Ana")
        #expect(prefs[0]["hlc"] as? String == "h1")
    }

    @Test func push_401_sessionExpired() async {
        let stub = PrefsStubSession(status: 401)
        let outcome = await client(stub).push([WirePref(key: "a", value: "1", hlc: "h")])
        #expect(outcome == .sessionExpired)
    }

    @Test func push_403_accountUnavailable() async {
        let stub = PrefsStubSession(status: 403)
        let outcome = await client(stub).push([WirePref(key: "a", value: "1", hlc: "h")])
        #expect(outcome == .accountUnavailable)
    }

    @Test func push_409_reverting_accountUnavailable() async {
        // Freeze de la reversa (§h.1): 409 con type `yala_account_reverting` → STOP como el 403; el
        // outbox de prefs NO se purga (solo se purga en `completed`).
        let body = Data(#"{"error":{"message":"reversa","type":"yala_account_reverting","param":null,"code":"yala_account_reverting"}}"#.utf8)
        let stub = PrefsStubSession(status: 409, body: body)
        let outcome = await client(stub).push([WirePref(key: "a", value: "1", hlc: "h")])
        #expect(outcome == .accountUnavailable)
    }

    @Test func push_409_unknownBody_transient() async {
        // Un 409 AJENO (sin el envelope del gateway) conserva el trato previo: transient.
        let stub = PrefsStubSession(status: 409, body: Data("conflict".utf8))
        let outcome = await client(stub).push([WirePref(key: "a", value: "1", hlc: "h")])
        #expect(outcome == .transient)
    }

    @Test func push_500_transient() async {
        let stub = PrefsStubSession(status: 500)
        let outcome = await client(stub).push([WirePref(key: "a", value: "1", hlc: "h")])
        #expect(outcome == .transient)
    }

    @Test func push_networkError_transient() async {
        let stub = PrefsStubSession(error: URLError(.notConnectedToInternet))
        let outcome = await client(stub).push([WirePref(key: "a", value: "1", hlc: "h")])
        #expect(outcome == .transient)
    }

    // MARK: - Pull

    @Test func pull_200_decodesPageAndCursor() async throws {
        let json = #"""
        {"prefs":[{"key":"userName","value":"Ana","hlc":"h1","server_seq":7},{"key":"colorfulIcons","value":"true","hlc":"h2","server_seq":9}],"max_server_seq":9}
        """#
        let stub = PrefsStubSession(status: 200, body: Data(json.utf8))
        let outcome = await client(stub).pull(since: 0)
        guard case .page(let page) = outcome else { Issue.record("no page: \(outcome)"); return }
        #expect(page.maxServerSeq == 9)
        #expect(page.prefs.count == 2)
        #expect(page.prefs[0] == PulledPref(key: "userName", value: "Ana", hlc: "h1", serverSeq: 7))
        #expect(page.prefs[1] == PulledPref(key: "colorfulIcons", value: "true", hlc: "h2", serverSeq: 9))

        // El cursor viaja en el query `since`.
        let req = try #require(stub.lastRequest)
        #expect(req.url?.absoluteString.contains("since=0") == true)
    }

    @Test func pull_nullValue_decodesNil() async {
        let json = #"{"prefs":[{"key":"appLanguageOverride","value":null,"hlc":"h1","server_seq":3}],"max_server_seq":3}"#
        let stub = PrefsStubSession(status: 200, body: Data(json.utf8))
        let outcome = await client(stub).pull(since: 0)
        guard case .page(let page) = outcome else { Issue.record("no page"); return }
        #expect(page.prefs.first?.value == nil)
    }

    @Test func pull_emptyPage_maxSeqEchoesSince() async {
        let json = #"{"prefs":[],"max_server_seq":42}"#
        let stub = PrefsStubSession(status: 200, body: Data(json.utf8))
        let outcome = await client(stub).pull(since: 42)
        guard case .page(let page) = outcome else { Issue.record("no page"); return }
        #expect(page.prefs.isEmpty)
        #expect(page.maxServerSeq == 42)
    }

    @Test func pull_401_sessionExpired() async {
        let outcome = await client(PrefsStubSession(status: 401)).pull(since: 0)
        #expect(outcome == .sessionExpired)
    }

    @Test func pull_403_accountUnavailable() async {
        let outcome = await client(PrefsStubSession(status: 403)).pull(since: 0)
        #expect(outcome == .accountUnavailable)
    }

    @Test func pull_500_transient() async {
        let outcome = await client(PrefsStubSession(status: 500)).pull(since: 0)
        #expect(outcome == .transient)
    }
}
