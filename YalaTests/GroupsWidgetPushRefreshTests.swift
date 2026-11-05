//
//  GroupsWidgetPushRefreshTests.swift
//  YalaTests
//
//  Card dvg6 (2026-11-02) · el widget de Grupos se pone al día con un gasto que llega por push silencioso, con la app en
//  segundo plano. Tres piezas, las tres medidas aquí:
//   1. el manejador del push hace la comprobación pendiente del widget ANTES de contestar a iOS (`flushPendingCheck`):
//      después, iOS suspende la app y la espera de 400 ms no llega a vencer;
//   2. un pull que se corta a medias con páginas ya guardadas sube `dataVersion` (lo guardado es real);
//   3. `ensureCurrentUserMemberExists` sube `dataVersion` cuando guarda, como ya hacía su alta.
//  La prueba de punta a punta (iPhone con dos cuentas, app en segundo plano) es del device-QA de Jürgen.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · el widget se pone al día con un push silencioso", .serialized)
@MainActor
struct GroupsWidgetPushRefreshTests {

    // MARK: - Infra

    private let group = "SplitGroup-Widget"

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsWidgetPush-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        discardTestStoreDirectory(dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "GWP-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "GWP-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "GWP-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    /// Secuencia de respuestas HTTP (la última se repite).
    final class SequenceStub: SyncHTTPSession, @unchecked Sendable {
        private var replies: [(String, Int)]
        private let fallback: (String, Int)

        init(_ replies: [(String, Int)]) {
            self.replies = replies
            self.fallback = replies.last ?? ("{}", 200)
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            let reply = replies.isEmpty ? fallback : replies.removeFirst()
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: reply.1, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badURL)
            }
            return (Data(reply.0.utf8), response)
        }
    }

    private func pageWithOneShare(seq: Int) -> String {
        """
        {"deltas":[{"entity_type":"split_shares","group_id":"\(group)","sync_id":"\(UUID().uuidString.lowercased())","op":"upsert","fields":{"expense_id":"\(UUID().uuidString.lowercased())","member_key":"m1","amount":"10.0000","is_paid":false},"field_hlcs":{},"hlc":"2026-11-02T00:00:00.000Z-0000-00000000000000aa","server_seq":\(seq),"schema_version":1}],"cursors":{"\(group)":\(seq)},"memberships":["\(group)"]}
        """
    }

    private func emptyPage() -> String { "{\"deltas\":[],\"cursors\":{},\"memberships\":[\"\(group)\"]}" }

    private func bumps(for replies: [(String, Int)]) async throws -> (Int, GroupsPullOutcome) {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        var count = 0
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: SequenceStub(replies),
            onRemoteChangesApplied: { count += 1 }, onRemoteChanges: { _ in })
        let outcome = await client.pullUntilExhausted(context: context)
        return (count, outcome)
    }

    // MARK: - (2) El pull cortado a medias

    @Test("(2) un pull que se corta tras guardar una página sube dataVersion; el que se corta sin nada, no")
    func partialPull_bumpsOnlyWhenSomethingWasSaved() async throws {
        let (cut, cutOutcome) = try await bumps(for: [(pageWithOneShare(seq: 1), 200), ("{}", 500)])
        #expect(cutOutcome == .transient)
        #expect(cut == 1, "lo guardado en la primera página no llegaba a la lista ni al widget")

        // Control: cortado en la primera página, no se guardó nada que pintar.
        let (none, noneOutcome) = try await bumps(for: [("{}", 500)])
        #expect(noneOutcome == .transient)
        #expect(none == 0)

        // Control: el pull completo sube una vez, como siempre.
        let (full, fullOutcome) = try await bumps(for: [(pageWithOneShare(seq: 1), 200), (emptyPage(), 200)])
        #expect(fullOutcome == .completed(pages: 1, deltasApplied: 1))
        #expect(full == 1)
    }

    // MARK: - (1) La comprobación pendiente, en el acto

    @Test("(1) flushPendingCheck consume la comprobación en espera; sin espera no hace nada")
    func flushConsumesThePendingCheck() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let refresh = WidgetGroupsRefresh.shared
        refresh.setContext(context)
        defer {
            refresh.setContext(nil)
            refresh.noteCleared()
        }
        #expect(!refresh.flushPendingCheck(), "sin nada pendiente no hay nada que rehacer")

        // Una foto escrita DESPUÉS de la petición ya la cubre: el flush consume la espera sin recalcular, así que el test
        // no escribe la foto real del App Group.
        refresh.requestCheck(now: Date(timeIntervalSince1970: 1))
        #expect(refresh._testHasPendingCheck)
        refresh.notePublished(nil, at: Date(timeIntervalSince1970: 2))
        #expect(!refresh.flushPendingCheck())
        #expect(!refresh._testHasPendingCheck, "la espera tiene que consumirse: iOS suspende la app antes de que venza")
    }

    @Test("(1) en segundo plano la comprobación no espera: no queda nada pendiente que iOS pueda suspender")
    func background_checksWithoutWaiting() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let refresh = WidgetGroupsRefresh.shared
        let previous = WidgetGroupsRefresh.isInBackground
        refresh.setContext(context)
        defer {
            WidgetGroupsRefresh.isInBackground = previous
            refresh.setContext(nil)
            refresh.noteCleared()
        }
        // Delante: la espera de siempre (control).
        WidgetGroupsRefresh.isInBackground = { false }
        refresh.requestCheck()
        #expect(refresh._testHasPendingCheck)
        refresh.notePublished(nil, at: .distantFuture)
        refresh.flushPendingCheck()
        // Detrás: en el acto, sin espera. Con la foto ya al día, `check()` no reescribe la del App Group.
        refresh.notePublished(WidgetGroupsSnapshotBuilder.build(context: context))
        WidgetGroupsRefresh.isInBackground = { true }
        refresh.requestCheck()
        #expect(!refresh._testHasPendingCheck, "en segundo plano la espera puede no vencer nunca")
    }

    // MARK: - Cableado

    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test("(1) el push de Grupos hace la comprobación del widget ANTES de contestar a iOS")
    func pushHandler_flushesBeforeTheCompletionHandler() throws {
        let delegate = try source("Yala/App/YalaAppDelegate.swift")
        let sync = try #require(delegate.range(of: "await GroupsSyncClient.shared.syncNowFromPush(timeout: .seconds(20))"))
        let after = delegate[sync.upperBound...]
        let flush = try #require(after.range(of: "WidgetGroupsRefresh.shared.flushPendingCheck()"))
        let reply = try #require(after.range(of: "completionHandler(result ? .newData : .noData)"))
        #expect(flush.lowerBound < reply.lowerBound, "la comprobación tiene que ir antes del completionHandler")
    }

    @Test("(3) ensureCurrentUserMemberExists sube dataVersion en sus tres guardados")
    func ensureCurrentUserMember_bumpsOnEverySave() throws {
        let service = try source("Yala/Services/Groups/GroupService.swift")
        let start = try #require(service.range(of: "func ensureCurrentUserMemberExists("))
        let end = try #require(service[start.upperBound...].range(of: "func updateCurrentUserDisplayName("))
        let body = service[start.lowerBound..<end.lowerBound]
        #expect(body.components(separatedBy: "try context.save()").count - 1 == 3)
        #expect(body.components(separatedBy: "SessionState.shared.incrementDataVersion()").count - 1 == 3)
    }
}
