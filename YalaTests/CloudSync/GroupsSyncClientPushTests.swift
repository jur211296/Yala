//
//  GroupsSyncClientPushTests.swift
//  YalaTests / CloudSync
//
//  `GroupsSyncClient.syncNowFromPush(timeout:)` (G8-2): el disparo del ciclo desde un silent push.
//  `.serialized` (muta el flag global, restaurado con defer). Cubre: flag OFF → false SIN red; el timeout
//  dispara (stub lento ≤0.5s por la regla de sleeps) → false.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupsSyncClient · syncNowFromPush (G8-2)", .serialized)
@MainActor
struct GroupsSyncClientPushTests {

    // MARK: - Infra (molde GroupsSyncClientTests)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GSPush-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GSP-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GSP-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GSP-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    // MARK: - Stubs

    /// Cuenta llamadas; nunca debería ser invocado en el path flag-OFF.
    private final class CountingStub: SyncHTTPSession, @unchecked Sendable {
        var callCount = 0
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            callCount += 1
            let r = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("{\"deltas\":[],\"cursors\":{},\"memberships\":[]}".utf8), r)
        }
    }

    /// Duerme `delay` antes de responder (≤0.5s) — fuerza que el timeout gane la carrera.
    private final class SlowStub: SyncHTTPSession, @unchecked Sendable {
        let delay: Duration
        init(delay: Duration) { self.delay = delay }
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            try await Task.sleep(for: delay)
            let r = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("{\"deltas\":[],\"cursors\":{},\"memberships\":[]}".utf8), r)
        }
    }

    // MARK: - Tests

    @Test func flagOff_returnsFalse_noNetwork() async {
        // flag OFF (default de la fase) → guard corta antes de tocar red / context.
        let stub = CountingStub()
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: stub, sessionCheck: { true }, outboxMirror: nil)

        let result = await client.syncNowFromPush(timeout: .seconds(20))
        #expect(result == false)
        #expect(stub.callCount == 0)
    }

    @Test func timeout_returnsFalse() async throws {
        CloudSyncFlags.groupsBackendEnabled = true
        defer { CloudSyncFlags.groupsBackendEnabled = false }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // El ciclo llega a la red del pull (SlowStub, 400ms); el timeout (80ms) gana → false.
        let stub = SlowStub(delay: .milliseconds(400))
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: stub, sessionCheck: { true }, outboxMirror: nil)
        client._testSetContext(context)

        let result = await client.syncNowFromPush(timeout: .milliseconds(80))
        #expect(result == false)
    }

    /// Fase 2 · 2.5: el pull-to-refresh de la UI de Grupos entra por los MISMOS gates. Con el canal DARK
    /// (flag OFF, el estado de producción de esta fase) un tirón hacia abajo no toca la red — lo que
    /// protege este test es que nadie cablee la UI a un camino sin gatear.
    @Test func syncNowFromUI_flagOff_returnsFalse_noNetwork() async {
        let stub = CountingStub()
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: stub, sessionCheck: { true }, outboxMirror: nil)

        let result = await client.syncNowFromUI()
        #expect(result == false)
        #expect(stub.callCount == 0)
    }

    /// Con el canal ENCENDIDO el tirón sí cicla (y su tope no lo mata: el stub responde al instante).
    @Test func syncNowFromUI_flagOn_runsCycle() async throws {
        CloudSyncFlags.groupsBackendEnabled = true
        defer { CloudSyncFlags.groupsBackendEnabled = false }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let stub = CountingStub()
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: stub, sessionCheck: { true }, outboxMirror: nil)
        client._testSetContext(context)

        let result = await client.syncNowFromUI()
        #expect(result)
        #expect(stub.callCount > 0)
    }
}
