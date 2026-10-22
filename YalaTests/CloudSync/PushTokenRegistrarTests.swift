//
//  PushTokenRegistrarTests.swift
//  YalaTests / CloudSync
//
//  Coordinador del registro del device token (G8-2). Instancia FRESCA (`makeIsolatedDefaults()` + stub),
//  jamás muta `.shared`. `.serialized` porque el gate lee `CloudSyncFlags.groupsBackendEnabled` (flag
//  global, restaurado con `_testResetGroupsBackendEnabledOverride()` — nunca `= false`, que dejaría un
//  override pegajoso divergente del default). Cubre: capture persiste + dispara; attemptUpload gateado
//  por canal apagado y por sesión ausente (cero red); platform correcto por build.
//

import Foundation
import Testing

@testable import Yala

private final class StubHTTPSession: SyncHTTPSession, @unchecked Sendable {
    let status: Int
    private(set) var lastRequest: URLRequest?
    var callCount = 0
    init(status: Int = 200) { self.status = status }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        callCount += 1
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
    }
}

@Suite("PushTokenRegistrar · G8-2", .serialized)
@MainActor
struct PushTokenRegistrarTests {

    private func makeRegistrarClient(_ stub: StubHTTPSession) -> PushTokenRegistrationClient {
        PushTokenRegistrationClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { "jwt" }, attestProvider: { nil }, urlSession: stub)
    }

    @Test func capture_persistsToken() {
        let defaults = makeIsolatedDefaults()
        let stub = StubHTTPSession()
        let sut = PushTokenRegistrar(defaults: defaults, client: makeRegistrarClient(stub), hasSession: { false })

        sut.capture(token: "deadbeef")
        #expect(defaults.string(forKey: PushTokenRegistrar.tokenKey) == "deadbeef")
    }

    @Test func attemptUpload_flagOff_noNetwork() async {
        // Antes leía el default («flag OFF, default de la fase»). Tras el flip de D-R1 paso 2 ese default
        // es `true` bajo `Yala Dev` y este test quedaba ROJO ahí, o —peor— verde por un override pegajoso
        // que otro test hubiera dejado. El caso que quiere probar sigue vivo (canal apagado por kill
        // remoto), así que se ancla con override explícito.
        CloudSyncFlags.groupsBackendEnabled = false
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        let defaults = makeIsolatedDefaults()
        defaults.set("tok", forKey: PushTokenRegistrar.tokenKey)
        let stub = StubHTTPSession()
        let sut = PushTokenRegistrar(defaults: defaults, client: makeRegistrarClient(stub), hasSession: { true })

        sut.attemptUpload()
        await sut._testUploadTask?.value   // nil (guard cortó antes del Task) → no-op
        #expect(stub.callCount == 0)
    }

    @Test func attemptUpload_noSession_noNetwork() async {
        CloudSyncFlags.groupsBackendEnabled = true
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        let defaults = makeIsolatedDefaults()
        defaults.set("tok", forKey: PushTokenRegistrar.tokenKey)
        let stub = StubHTTPSession()
        let sut = PushTokenRegistrar(defaults: defaults, client: makeRegistrarClient(stub), hasSession: { false })

        sut.attemptUpload()
        await sut._testUploadTask?.value
        #expect(stub.callCount == 0)
    }

    @Test func attemptUpload_flagOnSession_uploads_correctBodyAndPlatform() async throws {
        CloudSyncFlags.groupsBackendEnabled = true
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        let defaults = makeIsolatedDefaults()
        let stub = StubHTTPSession(status: 200)
        let sut = PushTokenRegistrar(defaults: defaults, client: makeRegistrarClient(stub), hasSession: { true })

        sut.capture(token: "cafe")   // persiste + dispara
        await sut._testUploadTask?.value

        #expect(stub.callCount == 1)
        let req = try #require(stub.lastRequest)
        #expect(req.url?.absoluteString.hasSuffix("/push/register") == true)
        let body = try #require(req.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(json["device_token"] == "cafe")
        #expect(json["platform"] == PushTokenRegistrar.currentPlatform)
    }
}
