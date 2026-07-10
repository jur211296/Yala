//
//  CloudAccountClientTests.swift
//  YalaTests / CloudSync
//
//  Decoder + clasificación de `ClaimOutcome`/`ExistsOutcome` de `CloudAccountClient` (gate de identidad
//  I7c), SIN red (URLSession stub). Los fixtures del wire copian los NOMBRES REALES de
//  `gateway/src/sync/account.ts` + `gateway/test/account.goldens.test.ts` (`{"state": …}` y el envelope
//  de error `{"error":{type,message,param,code}}`).
//

import Foundation
import Testing

@testable import Yala

// MARK: - URLSession stub

private final class AccountStubHTTP: SyncHTTPSession, @unchecked Sendable {
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

@Suite("CloudAccountClient · gate de identidad I7c")
@MainActor
struct CloudAccountClientTests {

    private let base = URL(string: "https://gw.local")!

    // MARK: - Decoder puro

    @Test func decodeState_mapsAllThreeWireValues() {
        #expect(CloudAccountClient.decodeState("created") == .created)
        #expect(CloudAccountClient.decodeState("existing_stable") == .existingStable)
        #expect(CloudAccountClient.decodeState("claiming_in_progress") == .claimingInProgress)
    }

    @Test func decodeState_unknownIsNil() {
        #expect(CloudAccountClient.decodeState("weird") == nil)
        #expect(CloudAccountClient.decodeState("") == nil)
    }

    // MARK: - claim: clasificación de outcomes

    @Test func claim_200created_success() async {
        let stub = AccountStubHTTP(status: 200, body: Data(#"{"state":"created"}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        let outcome = await client.claim(jwt: "jwt", deviceID: "dev", provider: "apple")
        #expect(outcome == .success(.created))
        // Ancla del wire: POST, Authorization Bearer, body con device_id + provider.
        #expect(stub.lastRequest?.httpMethod == "POST")
        #expect(stub.lastRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt")
        #expect(stub.lastRequest?.url?.absoluteString == "https://gw.local/account/claim")
    }

    @Test func claim_200existingStable_success() async {
        let stub = AccountStubHTTP(status: 200, body: Data(#"{"state":"existing_stable","profile":{"id":"x"}}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        #expect(await client.claim(jwt: "j", deviceID: "d", provider: "apple") == .success(.existingStable))
    }

    @Test func claim_200claimingInProgress_success() async {
        let stub = AccountStubHTTP(status: 200, body: Data(#"{"state":"claiming_in_progress"}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        #expect(await client.claim(jwt: "j", deviceID: "d", provider: "apple") == .success(.claimingInProgress))
    }

    @Test func claim_401_sessionExpired() async {
        let body = Data(#"{"error":{"message":"JWT inválido","type":"yala_attest_invalid","param":null,"code":"yala_attest_invalid"}}"#.utf8)
        let stub = AccountStubHTTP(status: 401, body: body)
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        guard case .sessionExpired(let detail) = await client.claim(jwt: "j", deviceID: "d", provider: "apple") else {
            Issue.record("esperaba sessionExpired"); return
        }
        #expect(detail.contains("401"))
    }

    @Test func claim_403_accountUnavailable() async {
        let stub = AccountStubHTTP(status: 403, body: Data(#"{"error":{"type":"forbidden"}}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        guard case .accountUnavailable = await client.claim(jwt: "j", deviceID: "d", provider: "apple") else {
            Issue.record("esperaba accountUnavailable"); return
        }
    }

    @Test func claim_500_transient() async {
        let stub = AccountStubHTTP(status: 502, body: Data(#"{"error":{"type":"yala_unavailable"}}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        guard case .transient = await client.claim(jwt: "j", deviceID: "d", provider: "apple") else {
            Issue.record("esperaba transient"); return
        }
    }

    @Test func claim_200_undecodable_isTransient() async {
        let stub = AccountStubHTTP(status: 200, body: Data(#"{"state":"martian"}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        guard case .transient = await client.claim(jwt: "j", deviceID: "d", provider: "apple") else {
            Issue.record("esperaba transient ante state desconocido"); return
        }
    }

    @Test func claim_networkError_isTransient() async {
        let stub = AccountStubHTTP(error: URLError(.notConnectedToInternet))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        guard case .transient = await client.claim(jwt: "j", deviceID: "d", provider: "apple") else {
            Issue.record("esperaba transient ante red caída"); return
        }
    }

    @Test func claim_migrationTrue_sendsMigrationInBody() async {
        let stub = AccountStubHTTP(status: 200, body: Data(#"{"state":"created"}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        _ = await client.claim(jwt: "j", deviceID: "d", provider: "apple", migration: true)
        let body = try? JSONSerialization.jsonObject(with: stub.lastRequest?.httpBody ?? Data()) as? [String: Any]
        #expect(body?["migration"] as? Bool == true)
        #expect(body?["device_id"] as? String == "d")
    }

    // MARK: - migrationProgress (cutover §g.4, I10-wiring w6)

    @Test func migrationProgress_okTrue_isOk() async {
        let stub = AccountStubHTTP(status: 200, body: Data(#"{"ok":true}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        #expect(await client.migrationProgress(jwt: "j", deviceID: "d", action: "cutover") == .ok)
        #expect(stub.lastRequest?.httpMethod == "POST")
        #expect(stub.lastRequest?.url?.absoluteString == "https://gw.local/account/migration")
        let body = try? JSONSerialization.jsonObject(with: stub.lastRequest?.httpBody ?? Data()) as? [String: Any]
        #expect(body?["action"] as? String == "cutover")
    }

    @Test func migrationProgress_otherLeader_isOtherLeader() async {
        let stub = AccountStubHTTP(status: 200, body: Data(#"{"ok":false,"reason":"other_leader"}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        #expect(await client.migrationProgress(jwt: "j", deviceID: "d", action: "cutover") == .otherLeader)
    }

    @Test func migrationProgress_otherReason_isRejected() async {
        let stub = AccountStubHTTP(status: 200, body: Data(#"{"ok":false,"reason":"not_in_progress"}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        #expect(await client.migrationProgress(jwt: "j", deviceID: "d", action: "cutover")
                == .rejected(reason: "not_in_progress"))
    }

    @Test func migrationProgress_401_sessionExpired() async {
        let stub = AccountStubHTTP(status: 401, body: Data(#"{"error":{"type":"yala_attest_invalid"}}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        guard case .sessionExpired = await client.migrationProgress(jwt: "j", deviceID: "d", action: "complete") else {
            Issue.record("esperaba sessionExpired"); return
        }
    }

    @Test func migrationProgress_502_transient() async {
        let stub = AccountStubHTTP(status: 502, body: Data(#"{"error":{"type":"yala_unavailable"}}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        guard case .transient = await client.migrationProgress(jwt: "j", deviceID: "d", action: "cutover") else {
            Issue.record("esperaba transient"); return
        }
    }

    @Test func migrationProgress_200_undecodable_isTransient() async {
        let stub = AccountStubHTTP(status: 200, body: Data(#"{"nope":1}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        guard case .transient = await client.migrationProgress(jwt: "j", deviceID: "d", action: "cutover") else {
            Issue.record("esperaba transient ante body sin ok"); return
        }
    }

    // MARK: - exists

    @Test func exists_200true() async {
        let stub = AccountStubHTTP(status: 200, body: Data(#"{"exists":true}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        #expect(await client.exists(jwt: "j") == .exists(true))
        #expect(stub.lastRequest?.httpMethod == "GET")
    }

    @Test func exists_401_sessionExpired() async {
        let stub = AccountStubHTTP(status: 401, body: Data(#"{"error":{"type":"yala_attest_required"}}"#.utf8))
        let client = CloudAccountClient(baseURL: base, urlSession: stub)
        guard case .sessionExpired = await client.exists(jwt: "j") else {
            Issue.record("esperaba sessionExpired"); return
        }
    }
}
