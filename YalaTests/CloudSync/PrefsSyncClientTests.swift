//
//  PrefsSyncClientTests.swift
//  YalaTests / CloudSync
//
//  Transporte de prefs (I13), sin red (URLSession stub). Cubre: clasificación de outcomes (200/401/403/
//  5xx), decode de push (applied/noop + reason), decode de pull (envelope + cursor), y el body del push.
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

@Suite("PrefsSyncClient · I13", .serialized)
@MainActor
struct PrefsSyncClientTests {

    private let baseURL = URL(string: "https://x.test")!

    private func client(_ stub: PrefsStubSession, token: String? = "jwt") -> PrefsSyncClient {
        PrefsSyncClient(baseURL: baseURL, tokenProvider: { token }, urlSession: stub)
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
        let outcome = await client(stub, token: nil).push([WirePref(key: "a", value: "1", hlc: "h")])
        #expect(outcome == .sessionExpired)
        #expect(stub.lastRequest == nil)
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
