//
//  PushTokenSignOutSeamTests.swift
//  YalaTests / CloudSync
//
//  Seam de desregistro del push token en el sign-out (G8-2). `.serialized` porque muta seams estáticos del
//  enum + el flag global (restaurados con defer). Cubre: flag OFF / sin sesión → no-op (cero red); con
//  sesión + token → unregister invocado (path correcto); error del cliente NO propaga.
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

@Suite("PushTokenSignOutSeam · G8-2", .serialized)
@MainActor
struct PushTokenSignOutSeamTests {

    /// Ejecuta `body` con los seams del enum sustituidos y los restaura después (incluye el flag global).
    private func withSeam(
        session: Bool, token: String?, flag: Bool, stub: StubHTTPSession,
        _ body: () async -> Void
    ) async {
        let savedClient = PushTokenSignOutSeam.client
        let savedHasSession = PushTokenSignOutSeam.hasSession
        let savedToken = PushTokenSignOutSeam.storedToken
        defer {
            PushTokenSignOutSeam.client = savedClient
            PushTokenSignOutSeam.hasSession = savedHasSession
            PushTokenSignOutSeam.storedToken = savedToken
            // RESET del override, no restauración por valor: leer el getter y re-asignarlo deja override
            // no-nil (y propaga el que hubiera dejado otro test). Ver CloudSyncFlags._testReset*.
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        CloudSyncFlags.groupsBackendEnabled = flag
        PushTokenSignOutSeam.client = PushTokenRegistrationClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { "jwt" }, attestProvider: { nil }, urlSession: stub)
        PushTokenSignOutSeam.hasSession = { session }
        PushTokenSignOutSeam.storedToken = { token }
        await body()
    }

    @Test func noSession_noOp() async {
        let stub = StubHTTPSession()
        await withSeam(session: false, token: "tok", flag: true, stub: stub) {
            await PushTokenSignOutSeam.clearForSignOut()
        }
        #expect(stub.callCount == 0)
    }

    @Test func flagOff_noOp() async {
        let stub = StubHTTPSession()
        await withSeam(session: true, token: "tok", flag: false, stub: stub) {
            await PushTokenSignOutSeam.clearForSignOut()
        }
        #expect(stub.callCount == 0)
    }

    @Test func sessionAndToken_invokesUnregister() async {
        let stub = StubHTTPSession(status: 200)
        await withSeam(session: true, token: "tok", flag: true, stub: stub) {
            await PushTokenSignOutSeam.clearForSignOut()
        }
        #expect(stub.callCount == 1)
        #expect(stub.lastRequest?.url?.absoluteString.hasSuffix("/push/unregister") == true)
    }

    @Test func clientError_doesNotPropagate() async {
        struct Boom: Error {}
        let stub = StubHTTPSession(error: Boom())
        // Si propagara, `clearForSignOut` lanzaría y el test no compilaría (no es `throws`) — la ausencia
        // de throw + el conteo es la aserción.
        await withSeam(session: true, token: "tok", flag: true, stub: stub) {
            await PushTokenSignOutSeam.clearForSignOut()
        }
        #expect(stub.callCount == 1)
    }
}
