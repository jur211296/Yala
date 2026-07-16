//
//  PushTokenRegistrationClientTests.swift
//  YalaTests / CloudSync
//
//  Cliente HTTP del registro/desregistro del device token APNs (G8-2). Sin red (URLSession stub):
//  body JSON EXACTO enviado (lección d49d2e47 — assertar el BODY), path/método/Authorization, y el mapeo
//  de status (200→OK, 401→sessionExpired, 400→serverRejected, 5xx→transient, token nil→sin request).
//

import Foundation
import Testing

@testable import Yala

private final class StubHTTPSession: SyncHTTPSession, @unchecked Sendable {
    let status: Int
    let error: Error?
    private(set) var lastRequest: URLRequest?
    var callCount = 0
    init(status: Int = 200, error: Error? = nil) {
        self.status = status
        self.error = error
    }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        lastRequest = request
        if let error { throw error }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }
}

@Suite("PushTokenRegistrationClient · G8-2", .serialized)
@MainActor
struct PushTokenRegistrationClientTests {

    private func makeClient(_ stub: StubHTTPSession, token: String? = "jwt") -> PushTokenRegistrationClient {
        PushTokenRegistrationClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { token }, attestProvider: { nil }, urlSession: stub)
    }

    @Test func register_postsExactBody_pathAndAuth() async throws {
        let stub = StubHTTPSession(status: 200)
        try await makeClient(stub).register(deviceToken: "abc123", platform: "ios-sandbox")

        let req = try #require(stub.lastRequest)
        #expect(req.httpMethod == "POST")
        #expect(req.url?.absoluteString.hasSuffix("/push/register") == true)
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer jwt")
        let body = try #require(req.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json == ["device_token": "abc123", "platform": "ios-sandbox"])
    }

    @Test func unregister_postsExactBody() async throws {
        let stub = StubHTTPSession(status: 204)
        try await makeClient(stub).unregister(deviceToken: "abc123")

        let req = try #require(stub.lastRequest)
        #expect(req.url?.absoluteString.hasSuffix("/push/unregister") == true)
        let body = try #require(req.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json == ["device_token": "abc123"])
    }

    @Test func register_401_sessionExpired() async {
        let stub = StubHTTPSession(status: 401)
        await #expect(throws: PushTokenRegistrationError.sessionExpired) {
            try await makeClient(stub).register(deviceToken: "abc", platform: "ios-prod")
        }
    }

    @Test func register_400_serverRejected() async {
        let stub = StubHTTPSession(status: 400)
        await #expect(throws: PushTokenRegistrationError.serverRejected(status: 400)) {
            try await makeClient(stub).register(deviceToken: "abc", platform: "ios-prod")
        }
    }

    @Test func register_500_transient() async {
        let stub = StubHTTPSession(status: 500)
        await #expect(throws: PushTokenRegistrationError.transient(status: 500)) {
            try await makeClient(stub).register(deviceToken: "abc", platform: "ios-prod")
        }
    }

    @Test func register_nilToken_sessionExpired_noRequest() async {
        let stub = StubHTTPSession(status: 200)
        await #expect(throws: PushTokenRegistrationError.sessionExpired) {
            try await makeClient(stub, token: nil).register(deviceToken: "abc", platform: "ios-prod")
        }
        #expect(stub.callCount == 0)
    }
}
