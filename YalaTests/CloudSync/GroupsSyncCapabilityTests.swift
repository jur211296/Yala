//
//  GroupsSyncCapabilityTests.swift
//  YalaTests / CloudSync
//
//  La versión del manifest de Grupos que declara el teléfono (`GroupsSyncCapability`) y su cableado en los dos
//  requests del canal: el pull (`GroupsSyncClient`) y el Merkle (`GroupsMerkleClient`). Ticket
//  `groups-canal-sin-capability-set` (2026-10-24). Molde: los casos de cabecera de `SyncPullClientTests` y
//  `AccountLineSyncTests` en el canal personal.
//
//  Cubre:
//   (1) la decisión pura: la menor entre cliente y Worker, nunca por debajo de 1;
//   (2) sin anuncio = 2 (no 1, como en el personal), y lo que anuncia el Worker se apunta y se olvida con `nil`;
//   (3) el pull manda `X-Yala-Capability-Set` y apunta el `manifest_version` de la respuesta;
//   (4) el Merkle manda la cabecera, apunta el anuncio y salta (`.transient`) si el Worker no sabe proyectar el nivel;
//   (5) el árbol local se computa con el nivel con el que se PIDIÓ el snapshot, no con el que quede tras el anuncio.
//
//  `GroupsSyncCapability.defaults` es ESTÁTICO: cada caso lo aísla y lo restaura en `defer`, y la suite es `.serialized`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · GroupsSyncCapability", .serialized)
@MainActor
struct GroupsSyncCapabilityTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsCapability-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("no se pudo crear el directorio temporal: \(error)")
        }
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("GroupsSyncCapabilityTests: no se pudo borrar \(dir.lastPathComponent): \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Aísla `GroupsSyncCapability.defaults` en una suite propia; el llamador restaura con el valor devuelto.
    private func isolateDefaults() throws -> UserDefaults {
        let previous = GroupsSyncCapability.defaults
        GroupsSyncCapability.defaults = try #require(UserDefaults(suiteName: "test.groupsCapability.\(UUID().uuidString)"))
        return previous
    }

    /// Stub que devuelve una SECUENCIA de respuestas y guarda cada request (la última se repite).
    final class SequenceStub: SyncHTTPSession, @unchecked Sendable {
        private var replies: [(String, Int)]
        private let fallback: (String, Int)
        var requests: [URLRequest] = []

        init(_ replies: [(String, Int)]) {
            self.replies = replies
            self.fallback = replies.last ?? ("{}", 200)
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            requests.append(request)
            let reply = replies.isEmpty ? fallback : replies.removeFirst()
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: reply.1, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badURL)
            }
            return (Data(reply.0.utf8), response)
        }
    }

    private func pullPage(manifestVersion: Int?) -> String {
        let announce = manifestVersion.map { ",\"manifest_version\":\($0)" } ?? ""
        return "{\"deltas\":[],\"cursors\":{},\"memberships\":[]\(announce)}"
    }

    private func merkleJSON(root: String, entities: [String: (Int, String)], manifestVersion: Int?) -> String {
        let ents = entities.map { "\"\($0.key)\":{\"count\":\($0.value.0),\"hash\":\"\($0.value.1)\"}" }
            .sorted().joined(separator: ",")
        let announce = manifestVersion.map { ",\"manifest_version\":\($0)" } ?? ""
        return "{\"canon_version\":\"c2\",\"group_id\":\"g\",\"root\":\"\(root)\",\"entities\":{\(ents)},\"channel2_root\":\"cc\"\(announce)}"
    }

    // MARK: - (1) La decisión pura

    @Test("(1) declara la menor entre cliente y Worker, nunca por debajo de 1")
    func declaredLevel_isTheMinimum() {
        #expect(GroupsSyncCapability.declaredLevel(client: 2, backend: 1) == 1)
        #expect(GroupsSyncCapability.declaredLevel(client: 2, backend: 2) == 2)
        #expect(GroupsSyncCapability.declaredLevel(client: 2, backend: 3) == 2)
        #expect(GroupsSyncCapability.declaredLevel(client: 3, backend: 2) == 2)
        #expect(GroupsSyncCapability.declaredLevel(client: 2, backend: 0) == 1)
        #expect(GroupsSyncCapability.header(forLevel: 2) == "v2")
    }

    // MARK: - (2) Sin anuncio = 2

    @Test("(2) sin anuncio declara v2; lo anunciado se apunta, y un Worker que no anuncia vuelve a v2")
    func unannounced_isLevelTwo_andAnnouncementsAreRecorded() throws {
        let previous = try isolateDefaults(); defer { GroupsSyncCapability.defaults = previous }

        #expect(GroupsSyncCapability.clientManifestVersion == 2)
        #expect(GroupsSyncCapability.levelWhenUnannounced == 2)
        #expect(GroupsSyncCapability.backendManifestVersion == 2)
        #expect(GroupsSyncCapability.declaredHeader == "v2")

        GroupsSyncCapability.recordBackendManifestVersion(1)
        #expect(GroupsSyncCapability.declaredLevel == 1)
        #expect(GroupsSyncCapability.declaredHeader == "v1")

        GroupsSyncCapability.recordBackendManifestVersion(nil)
        #expect(GroupsSyncCapability.declaredLevel == 2)

        GroupsSyncCapability.recordBackendManifestVersion(7)
        #expect(GroupsSyncCapability.backendManifestVersion == 7)
        #expect(GroupsSyncCapability.declaredLevel == 2)  // el cliente no entiende más que 2

        GroupsSyncCapability.recordBackendManifestVersion(0)
        #expect(GroupsSyncCapability.declaredLevel == 1)
    }

    // MARK: - (3) El pull

    @Test("(3) el pull manda X-Yala-Capability-Set y apunta el manifest_version anunciado")
    func pull_sendsTheHeader_andRecordsTheAnnouncement() async throws {
        let previous = try isolateDefaults(); defer { GroupsSyncCapability.defaults = previous }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // 1ª página: el Worker anuncia v1 (un rollback). 2ª: anuncia v2. 3ª: no anuncia (Worker anterior).
        let stub = SequenceStub([
            (pullPage(manifestVersion: 1), 200), (pullPage(manifestVersion: 2), 200), (pullPage(manifestVersion: nil), 200),
        ])
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub)

        _ = await client.pullAndApplyOnce(context: context)
        #expect(GroupsSyncCapability.backendManifestVersion == 1)
        _ = await client.pullAndApplyOnce(context: context)
        #expect(GroupsSyncCapability.backendManifestVersion == 2)
        GroupsSyncCapability.recordBackendManifestVersion(1)
        _ = await client.pullAndApplyOnce(context: context)
        #expect(GroupsSyncCapability.backendManifestVersion == 2)  // sin anuncio = 2

        let headers = stub.requests.map { $0.value(forHTTPHeaderField: "X-Yala-Capability-Set") }
        #expect(headers == ["v2", "v1", "v1"])
        #expect(stub.requests.allSatisfy { $0.url?.path.hasSuffix("/groups/pull") == true })
    }

    // MARK: - (4) El Merkle

    @Test("(4) el Merkle manda la cabecera del nivel pedido y apunta el anuncio")
    func merkle_sendsTheHeader_andRecordsTheAnnouncement() async throws {
        let previous = try isolateDefaults(); defer { GroupsSyncCapability.defaults = previous }

        let stub = SequenceStub([(merkleJSON(root: "a", entities: [:], manifestVersion: 2), 200)])
        let client = GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: stub)

        let outcome = await client.fetchMerkle(groupID: "SplitGroup-A")
        guard case .snapshot(let remote) = outcome else { Issue.record("esperaba snapshot, got \(outcome)"); return }
        #expect(remote.manifestVersion == 2)
        #expect(remote.capabilityLevel == 2)
        #expect(stub.requests.first?.value(forHTTPHeaderField: "X-Yala-Capability-Set") == "v2")

        // Nivel explícito: la cabecera es la pedida y el snapshot recuerda con cuál se pidió.
        let outcomeV1 = await client.fetchMerkle(groupID: "SplitGroup-A", capabilityLevel: 1)
        guard case .snapshot(let remoteV1) = outcomeV1 else { Issue.record("esperaba snapshot, got \(outcomeV1)"); return }
        #expect(remoteV1.capabilityLevel == 1)
        #expect(stub.requests.last?.value(forHTTPHeaderField: "X-Yala-Capability-Set") == "v1")
    }

    @Test("(4) un Worker que anuncia menos que el nivel pedido no sabe proyectarlo: transient, y se apunta")
    func merkle_workerBehindTheRequestedLevel_isTransient() async throws {
        let previous = try isolateDefaults(); defer { GroupsSyncCapability.defaults = previous }

        let stub = SequenceStub([(merkleJSON(root: "a", entities: [:], manifestVersion: 1), 200)])
        let client = GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: stub)
        #expect(await client.fetchMerkle(groupID: "g", capabilityLevel: 2) == .transient)
        #expect(GroupsSyncCapability.declaredLevel == 1)

        // Control: sin anuncio (Worker anterior a esto) vale 2 y el snapshot sí sirve.
        let stubOld = SequenceStub([(merkleJSON(root: "a", entities: [:], manifestVersion: nil), 200)])
        let old = GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: stubOld)
        guard case .snapshot = await old.fetchMerkle(groupID: "g", capabilityLevel: 2) else {
            Issue.record("un Worker que no anuncia debería valer v2"); return
        }
        #expect(GroupsSyncCapability.declaredLevel == 2)
    }

    // MARK: - (5) El árbol local

    @Test("(5) el árbol local de v1 no hashea el presupuesto: difiere del de v2 en split_groups y solo ahí")
    func localMerkle_followsTheLevel() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = SplitGroup(name: "Viaje")
        let gid = group.cloudKitZoneID
        context.insert(group)
        try context.save()

        let v1 = try GroupMerkleProjection.computeLocalMerkle(groupID: gid, context: context, capabilityLevel: 1)
        let v2 = try GroupMerkleProjection.computeLocalMerkle(groupID: gid, context: context, capabilityLevel: 2)
        #expect(v1.entities["split_groups"]?.count == 1)
        #expect(v1.entities["split_groups"]?.hashHex != v2.entities["split_groups"]?.hashHex)
        for table in GroupMerkleProjection.entityTables where table != "split_groups" {
            #expect(v1.entities[table] == v2.entities[table], "\(table) no debería cambiar con el nivel")
        }
        #expect(v1.rootHex != v2.rootHex)
    }

    @Test("(5) verifyGroupIntegrity compara con el nivel con el que PIDIÓ el snapshot, aunque el anuncio lo suba")
    func verify_usesTheRequestedLevel_notTheOneAfterTheAnnouncement() async throws {
        let previous = try isolateDefaults(); defer { GroupsSyncCapability.defaults = previous }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = SplitGroup(name: "Viaje")
        let gid = group.cloudKitZoneID
        context.insert(group)
        try context.save()

        // El teléfono habla v1 (el Worker anunció 1 la última vez); el Worker de ahora hashea v1 —lo que se le pidió—
        // y anuncia 2 en esta misma respuesta, lo que sube `declaredLevel` a 2 antes del árbol local.
        GroupsSyncCapability.recordBackendManifestVersion(1)
        let serverV1 = try GroupMerkleProjection.computeLocalMerkle(groupID: gid, context: context, capabilityLevel: 1)
        let remote = merkleJSON(
            root: serverV1.rootHex,
            entities: serverV1.entities.mapValues { ($0.count, $0.hashHex) },
            manifestVersion: 2)
        let merkleStub = SequenceStub([(remote, 200)])
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: SequenceStub([(pullPage(manifestVersion: 2), 200)]),
            merkleClient: GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: merkleStub))
        client._testMarkPullCompleted()

        let verdict = await client.verifyGroupIntegrity(groupID: gid, context: context)
        #expect(verdict == .converged)
        #expect(merkleStub.requests.first?.value(forHTTPHeaderField: "X-Yala-Capability-Set") == "v1")
        #expect(GroupsSyncCapability.declaredLevel == 2)  // el anuncio sí se apuntó, para el ciclo siguiente
    }
}
