//
//  GroupRejectMemberBackendTests.swift
//  YalaTests / CloudSync
//
//  «Rechazar» una solicitud de unión en un grupo de la nube (card 840m del QA guiado del TF19, 2026-10-20). Hasta ese
//  día `GroupService.rejectMember` lanzaba `.backendActionUnavailable` para el canal backend y el rechazo no llegaba
//  nunca al servidor. El servidor ya rechazaba con `remove_member` (pendiente → `rejected`), así que el arreglo es
//  del cliente: servidor primero, y `.rejected` en local solo si el servidor lo confirma.
//
//  Molde de `GroupChannelRoutingTests` (container ON-DISK con los 3 stores, `.serialized`: togglea
//  `CloudSyncFlags.groupsBackendEnabled` e inyecta `GroupService.shared`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Rechazar una solicitud en un grupo de la nube (840m)", .serialized)
@MainActor
struct GroupRejectMemberBackendTests {

    private let base = URL(string: "https://gw.test")!

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupReject-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("No se pudo crear el directorio del test: \(error)")
        }
        return dir
    }

    private func cleanup(_ dir: URL) {
        do { try FileManager.default.removeItem(at: dir) } catch { print("GroupRejectMemberBackendTests: cleanup: \(error)") }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GRJ-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GRJ-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GRJ-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func makeService(_ session: GroupsSyncClientTests.StubHTTPSession) -> GroupBackendMembershipService {
        let client = GroupsMembershipClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        client.sleeper = { _ in }
        return GroupBackendMembershipService(client: client, sessionCheck: { true })
    }

    private func stub(_ json: String, status: Int = 200) -> GroupsSyncClientTests.StubHTTPSession {
        GroupsSyncClientTests.StubHTTPSession(responseData: Data(json.utf8), statusCode: status)
    }

    /// Un grupo del canal backend con su admin y una solicitud de `status` dado.
    private func seed(_ context: ModelContext, status: SplitMemberStatus, memberKey: String? = "mk-bob")
        throws -> (SplitGroup, SplitMember) {
        let group = SplitGroup(name: "QA unión 19")
        group.isOwner = true
        group.isBackendGroup = true
        context.insert(group)
        let member = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Bob",
                                 cloudKitUserRecordID: "", role: "member", status: status)
        member.memberKey = memberKey
        context.insert(member)
        try context.save()
        return (group, member)
    }

    /// Prepara flag + factory y devuelve la limpieza.
    private func wire(flag: Bool, _ session: GroupsSyncClientTests.StubHTTPSession, context: ModelContext) -> () -> Void {
        GroupService.shared.setContext(context)
        let prevFactory = GroupService.shared.backendMembershipFactory
        CloudSyncFlags.groupsBackendEnabled = flag
        GroupService.shared.backendMembershipFactory = { self.makeService(session) }
        return {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
    }

    // MARK: - La decisión (pura)

    @Test func soloElRechazoDelServidorSeMarcaEnLocal() {
        #expect(GroupMemberRejectLogic.marksRejectedLocally(serverStatus: SplitMemberStatus.rejected.rawValue))
        #expect(GroupMemberRejectLogic.marksRejectedLocally(serverStatus: "rejected"))
        // Control: el mismo RPC deja `removed` a quien ya estaba dentro. Eso no es un rechazo.
        #expect(!GroupMemberRejectLogic.marksRejectedLocally(serverStatus: "removed"))
        #expect(!GroupMemberRejectLogic.marksRejectedLocally(serverStatus: "active"))
        #expect(!GroupMemberRejectLogic.marksRejectedLocally(serverStatus: ""))
    }

    // MARK: - El cableado

    /// El caso de la card: grupo de la nube, solicitud pendiente → `remove_member` con la clave del miembro, y
    /// `.rejected` en local. Antes lanzaba `.backendActionUnavailable` sin tocar la red.
    @Test func grupoDeLaNube_rechazaEnElServidor_yMarcaRechazado() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"mk-bob","status":"rejected"}"#)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let (group, member) = try seed(context, status: .pendingApproval)

        try await GroupService.shared.rejectMember(member, in: group)

        #expect(s.callCount == 1)
        #expect(s.lastRequest?.url?.absoluteString.hasSuffix("remove_member") == true)
        let body = try #require(s.lastRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["p_group_id"] as? String == group.cloudKitZoneID)
        #expect(json["p_member_key"] as? String == "mk-bob")
        #expect(member.memberStatus == .rejected)
    }

    /// Control: con el canal de CloudKit (flag apagado) el rechazo sigue siendo local y sin red, como antes.
    @Test func flagApagado_rechazaEnLocal_sinRed() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"mk-bob","status":"rejected"}"#)
        let restore = wire(flag: false, s, context: context); defer { restore() }
        let (group, member) = try seed(context, status: .pendingApproval)

        try await GroupService.shared.rejectMember(member, in: group)

        #expect(s.callCount == 0)
        #expect(member.memberStatus == .rejected)
    }

    /// La protección contra expulsar: con el estado local ya activo, `remove_member` lo dejaría `removed`. Se para antes
    /// de la red.
    @Test func miembroYaActivoEnLocal_noLlamaAlServidor() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"mk-bob","status":"removed"}"#)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let (group, member) = try seed(context, status: .active)

        var lanzo = false
        do {
            try await GroupService.shared.rejectMember(member, in: group)
        } catch GroupServiceError.notPendingApproval {
            lanzo = true
        }
        #expect(lanzo)
        #expect(s.callCount == 0)
        #expect(member.memberStatus == .active)
    }

    /// Si el servidor contesta otra cosa que `rejected` (la solicitud ya no estaba pendiente allí), no se inventa el
    /// rechazo en local: lo trae el pull.
    @Test func servidorNoConfirmaElRechazo_noSeMarcaEnLocal() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"mk-bob","status":"removed"}"#)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let (group, member) = try seed(context, status: .pendingApproval)

        try await GroupService.shared.rejectMember(member, in: group)

        #expect(s.callCount == 1)
        #expect(member.memberStatus == .pendingApproval)
    }

    /// El servidor falla → error al llamador (alerta) y la solicitud sigue pendiente en local.
    @Test func servidorFalla_lanza_yLaSolicitudSigue() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"message":"yala_not_authorized"}"#, status: 400)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let (group, member) = try seed(context, status: .pendingApproval)

        await #expect(throws: (any Error).self) {
            try await GroupService.shared.rejectMember(member, in: group)
        }
        #expect(member.memberStatus == .pendingApproval)
    }

    /// Sin `member_key` no hay a quién rechazar en el servidor: lanza antes de la red.
    @Test func sinMemberKey_lanzaAntesDeLaRed() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let s = stub(#"{"group_id":"g","member_key":"mk","status":"rejected"}"#)
        let restore = wire(flag: true, s, context: context); defer { restore() }
        let (group, member) = try seed(context, status: .pendingApproval, memberKey: nil)

        await #expect(throws: GroupServiceError.self) {
            try await GroupService.shared.rejectMember(member, in: group)
        }
        #expect(s.callCount == 0)
        #expect(member.memberStatus == .pendingApproval)
    }
}
