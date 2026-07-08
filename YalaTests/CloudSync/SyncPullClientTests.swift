//
//  SyncPullClientTests.swift
//  YalaTests / CloudSync
//
//  Transporte + decoder del pull (I8f-1), sin red (URLSession stub). Cubre:
//    - Clasificación de PullOutcome: 200→page, 401→sessionExpired, 403→accountUnavailable, 5xx→transient,
//      sin token→sessionExpired, cuerpo 200 ilegible→transient.
//    - Request: método GET, query `since`/`limit`, headers Authorization Bearer + X-Yala-Capability-Set v1.
//    - decodePage: full-row (fields como WireValue, bool preservado), tombstone (fields vacío), rawDelta.
//

import Foundation
import Testing

@testable import Yala

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
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

@Suite("SyncPullClient · transporte + decoder I8f-1", .serialized)
@MainActor
struct SyncPullClientTests {

    private func client(_ session: StubHTTPSession, token: String? = "test-jwt") -> SyncPullClient {
        SyncPullClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { token },
            attestProvider: { nil },
            urlSession: session
        )
    }

    private let node = "0123456789abcdef"
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }

    // MARK: - Outcomes

    @Test func pull_200_returnsPage() async {
        let sid = UUID().uuidString.lowercased()
        let json = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid)","op":"upsert",
        "fields":{"amount":"10.5000","is_exchange_rate_provisional":false},
        "field_hlcs":{"money":"\#(hlc(1))"},"hlc":"\#(hlc(1))","server_seq":7,"schema_version":1}],
        "max_server_seq":7}
        """#
        let session = StubHTTPSession(status: 200, body: Data(json.utf8))
        let outcome = await client(session).pull(since: 0, limit: 500)
        guard case .page(let page) = outcome else { Issue.record("no page: \(outcome)"); return }
        #expect(page.maxServerSeq == 7)
        #expect(page.deltas.count == 1)
        let d = page.deltas[0]
        #expect(d.entityType == "tx_items")
        #expect(d.op == .upsert)
        #expect(d.serverSeq == 7)
        #expect(d.fields["amount"] == .string("10.5000"))
        #expect(d.fields["is_exchange_rate_provisional"] == .bool(false))  // bool preservado, no número
        #expect(d.fieldHlcs["money"] == hlc(1))
    }

    @Test func pull_noToken_sessionExpired() async {
        let session = StubHTTPSession(status: 200)
        let outcome = await client(session, token: nil).pull(since: 0)
        #expect(outcome == .sessionExpired)
    }

    @Test func pull_401_sessionExpired() async {
        let outcome = await client(StubHTTPSession(status: 401)).pull(since: 0)
        #expect(outcome == .sessionExpired)
    }

    @Test func pull_403_accountUnavailable() async {
        let outcome = await client(StubHTTPSession(status: 403)).pull(since: 0)
        #expect(outcome == .accountUnavailable)
    }

    @Test func pull_500_transient() async {
        let outcome = await client(StubHTTPSession(status: 500)).pull(since: 0)
        #expect(outcome == .transient)
    }

    @Test func pull_200_undecodable_transient() async {
        let outcome = await client(StubHTTPSession(status: 200, body: Data("not json".utf8))).pull(since: 0)
        #expect(outcome == .transient)
    }

    @Test func pull_transportError_transient() async {
        let err = NSError(domain: "test", code: -1)
        let outcome = await client(StubHTTPSession(status: 200, error: err)).pull(since: 0)
        #expect(outcome == .transient)
    }

    // MARK: - Request shape

    @Test func pull_request_hasQueryAndHeaders() async {
        let session = StubHTTPSession(status: 200, body: Data(#"{"deltas":[],"max_server_seq":42}"#.utf8))
        _ = await client(session).pull(since: 42, limit: 100)
        let req = try! #require(session.lastRequest)
        #expect(req.httpMethod == "GET")
        let url = req.url!.absoluteString
        #expect(url.contains("since=42"))
        #expect(url.contains("limit=100"))
        #expect(url.contains("/sync/pull"))
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer test-jwt")
        #expect(req.value(forHTTPHeaderField: "X-Yala-Capability-Set") == "v1")
    }

    // MARK: - decodePage: tombstone

    @Test func decodePage_tombstone_emptyFields() throws {
        let sid = UUID().uuidString.lowercased()
        let json = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid)","op":"tombstone",
        "fields":{},"field_hlcs":{},"hlc":"\#(hlc(3))","server_seq":9,"schema_version":1}],
        "max_server_seq":9}
        """#
        let page = try SyncPullClient.decodePage(Data(json.utf8))
        #expect(page.deltas.count == 1)
        #expect(page.deltas[0].op == .tombstone)
        #expect(page.deltas[0].fields.isEmpty)
        #expect(page.deltas[0].hlc == hlc(3))
        // rawDelta round-trippea (re-decodable).
        #expect(page.deltas[0].rawDelta.contains("\"sync_id\":\"\(sid)\""))
    }

    @Test func decodePage_emptyPage() throws {
        let page = try SyncPullClient.decodePage(Data(#"{"deltas":[],"max_server_seq":0}"#.utf8))
        #expect(page.deltas.isEmpty)
        #expect(page.maxServerSeq == 0)
    }
}
