//
//  GroupChannelRoutingTests.swift
//  YalaTests / CloudSync
//
//  Routing POR-GRUPO del canal Grupos → backend (G5-A): partición del enqueue a CKSyncEngine (C2) y de las
//  ops de membership (C5). Container ON-DISK con los 3 stores (molde GroupBackendMembershipServiceTests).
//  `.serialized` (togglea `CloudSyncFlags.groupsBackendEnabled` + inyecta `GroupService.shared`).
//
//  Nota de alcance (C2): la partición del enqueue a CKSyncEngine (enqueueSave/enqueueDeletion/zoneRecovery/
//  recordRecovery) NO es unit-asertable — CKSyncEngine exige un CKContainer con iCloud (device-only, ver la
//  nota de SplitSyncManagerTests). La partición del INVITE (createShare) SÍ es observable: su guard C2 es lo
//  primero, antes de cualquier engine, y lanza `.backendGroup`. La partición del DRAIN (C2-bis) se cubre en
//  GroupsSyncClientTests contra el `GroupSyncOutbox` real.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Group channel routing · partición enqueue/membership (G5-A)", .serialized)
@MainActor
struct GroupChannelRoutingTests {

    private let base = URL(string: "https://gw.test")!

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupRouting-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Servicio backend con `sessionCheck` forzado a `true` (sin sesión real) y sin sleeps.
    private func makeService(_ session: GroupsSyncClientTests.StubHTTPSession) -> GroupBackendMembershipService {
        let client = GroupsMembershipClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        client.sleeper = { _ in }
        return GroupBackendMembershipService(client: client, sessionCheck: { true })
    }

    private func stub(_ json: String, status: Int = 200) -> GroupsSyncClientTests.StubHTTPSession {
        GroupsSyncClientTests.StubHTTPSession(responseData: Data(json.utf8), statusCode: status)
    }

    // MARK: - C2 · Partición del INVITE (createShare) — RETIRADA en la Fase 3
    //
    // `createShare_backendGroup_throwsBackendGroupError` probaba que un grupo backend jamás minteara un
    // CKShare, porque el guard C2 de `SplitZoneManager.createShare` lanzaba `.backendGroup` antes que nada.
    // El commit 1 de la Fase 3 borró `SplitZoneManager`, así que la partición ya no la sostiene un guard:
    // la sostiene que no existe ningún productor de CKShare. Un test de la ausencia de un tipo no aporta —
    // la ausencia la comprueba el compilador — y su cobertura de la ruta VIVA (invite por token RPC) la
    // llevan `GroupBackendInviteService` y los tests de C4.

    // MARK: - C5 · Membership routing (approve / remove / leave)

    /// Flag ON + grupo backend → `approveMember` va SERVER-FIRST por RPC y luego activa localmente.
    @Test func approveMember_backendGroup_flagOn_callsRPC_thenActivatesLocally() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)

        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        CloudSyncFlags.groupsBackendEnabled = true

        let s = stub(#"{"group_id":"g","member_key":"mk-bob","status":"active"}"#)
        GroupService.shared.backendMembershipFactory = { self.makeService(s) }

        let group = SplitGroup(name: "Trip")
        group.isOwner = true
        group.isBackendGroup = true
        context.insert(group)
        let member = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Bob",
                                 cloudKitUserRecordID: "", role: "member", status: .pendingApproval)
        member.memberKey = "mk-bob"
        context.insert(member)
        try context.save()

        try await GroupService.shared.approveMember(member, in: group)

        #expect(s.callCount == 1)                                  // RPC server-first golpeado
        #expect(member.memberStatus == .active)                    // mutación local optimista
        let body = try #require(s.lastRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["p_group_id"] as? String == group.cloudKitZoneID)
        #expect(json["p_member_key"] as? String == "mk-bob")       // JAMÁS member.id
    }

    /// Flag OFF → `approveMember` NO llama al RPC (camino CloudKit byte-idéntico): activa local, cero red.
    @Test func approveMember_flagOff_doesNotCallRPC() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)

        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        CloudSyncFlags.groupsBackendEnabled = false   // OFF

        let s = stub(#"{"group_id":"g","member_key":"mk","status":"active"}"#)
        GroupService.shared.backendMembershipFactory = { self.makeService(s) }

        // Grupo backend PERO flag OFF → el gate `routesMembershipToBackend` es false → sin RPC.
        let group = SplitGroup(name: "Trip")
        group.isOwner = true
        group.isBackendGroup = true
        context.insert(group)
        let member = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Bob",
                                 cloudKitUserRecordID: "", role: "member", status: .pendingApproval)
        member.memberKey = "mk-bob"
        context.insert(member)
        try context.save()

        try await GroupService.shared.approveMember(member, in: group)

        #expect(s.callCount == 0)                    // cero red — camino CloudKit
        #expect(member.memberStatus == .active)      // local aplicado igual
    }

    /// Flag ON + grupo backend → `removeMember` RPC server-first, luego `.removed` local.
    @Test func removeMember_backendGroup_flagOn_callsRPC_thenRemovesLocally() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)

        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        CloudSyncFlags.groupsBackendEnabled = true

        let s = stub(#"{"group_id":"g","member_key":"mk-carol","status":"removed"}"#)
        GroupService.shared.backendMembershipFactory = { self.makeService(s) }

        let group = SplitGroup(name: "Trip")
        group.isOwner = true
        group.isBackendGroup = true
        context.insert(group)
        let member = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Carol",
                                 cloudKitUserRecordID: "", role: "member", status: .active)
        member.memberKey = "mk-carol"
        context.insert(member)
        try context.save()

        try await GroupService.shared.removeMember(member, from: group)

        #expect(s.callCount == 1)
        #expect(member.memberStatus == .removed)
        let body = try #require(s.lastRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["p_member_key"] as? String == "mk-carol")
    }

    /// Flag ON + grupo backend → `leaveGroup` RPC + limpieza local (borra el SplitGroup), SIN CKShare.
    @Test func leaveGroup_backendGroup_flagOn_callsRPC_thenDeletesLocally() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)

        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        CloudSyncFlags.groupsBackendEnabled = true

        let s = stub(#"{"group_id":"g","member_key":"mk","status":"left"}"#)
        GroupService.shared.backendMembershipFactory = { self.makeService(s) }

        let group = SplitGroup(name: "Trip")
        group.isOwner = false            // solo un no-owner puede salir
        group.isBackendGroup = true
        context.insert(group)
        try context.save()

        try await GroupService.shared.leaveGroup(group)

        #expect(s.callCount == 1)
        let remaining = try context.fetch(FetchDescriptor<SplitGroup>())
        #expect(remaining.isEmpty)       // limpieza local borró el grupo
    }

    /// Flag ON + grupo backend + member sin `member_key` → guard defensivo lanza (C5 crítico #3), sin RPC.
    @Test func approveMember_backendGroup_missingMemberKey_throwsBeforeRPC() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)

        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        CloudSyncFlags.groupsBackendEnabled = true

        let s = stub(#"{"group_id":"g","member_key":"mk","status":"active"}"#)
        GroupService.shared.backendMembershipFactory = { self.makeService(s) }

        let group = SplitGroup(name: "Trip")
        group.isOwner = true
        group.isBackendGroup = true
        context.insert(group)
        let member = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "NoKey",
                                 cloudKitUserRecordID: "", role: "member", status: .pendingApproval)
        // member.memberKey queda nil
        context.insert(member)
        try context.save()

        await #expect(throws: GroupServiceError.self) {
            try await GroupService.shared.approveMember(member, in: group)
        }
        #expect(s.callCount == 0)                          // guard antes del RPC
        #expect(member.memberStatus == .pendingApproval)   // local INTACTO
    }

    // MARK: - Lote 19 · Rechazar va al servidor; «Cambiar rol» no se ofrece donde no existe

    /// Grupo del canal backend + flag ON → `rejectMember` va SERVER-FIRST por `remove_member` (que deja `rejected`
    /// a un pendiente) y luego marca `.rejected` en local. Hasta el lote 19 lanzaba `backendActionUnavailable`.
    @Test func rejectMember_backendGroup_flagOn_callsRemoveRPC_thenRejectsLocally() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)

        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        CloudSyncFlags.groupsBackendEnabled = true

        let s = stub(#"{"group_id":"g","member_key":"mk-dani","status":"rejected"}"#)
        GroupService.shared.backendMembershipFactory = { self.makeService(s) }

        let group = SplitGroup(name: "Trip")
        group.isOwner = true
        group.isBackendGroup = true
        context.insert(group)
        let member = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Dani",
                                 cloudKitUserRecordID: "", role: "member", status: .pendingApproval)
        member.memberKey = "mk-dani"
        context.insert(member)
        try context.save()

        try await GroupService.shared.rejectMember(member, in: group)

        #expect(s.callCount == 1)
        #expect(s.lastRequest?.url?.lastPathComponent == "remove_member")
        #expect(member.memberStatus == .rejected)
        let body = try #require(s.lastRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["p_group_id"] as? String == group.cloudKitZoneID)
        #expect(json["p_member_key"] as? String == "mk-dani")
    }

    /// Un miembro que aquí ya NO está pendiente no llega a la red: `remove_member` sobre un activo lo expulsaría.
    @Test func rejectMember_backendGroup_memberNoLongerPending_throwsBeforeRPC() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)

        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        CloudSyncFlags.groupsBackendEnabled = true

        let s = stub(#"{"group_id":"g","member_key":"mk-eva","status":"removed"}"#)
        GroupService.shared.backendMembershipFactory = { self.makeService(s) }

        let group = SplitGroup(name: "Trip")
        group.isOwner = true
        group.isBackendGroup = true
        context.insert(group)
        let member = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Eva",
                                 cloudKitUserRecordID: "", role: "member", status: .active)
        member.memberKey = "mk-eva"
        context.insert(member)
        try context.save()

        await #expect {
            try await GroupService.shared.rejectMember(member, in: group)
        } throws: { error in
            if case GroupServiceError.notPendingApproval = error { return true }
            return false
        }
        #expect(s.callCount == 0)                 // ni una petición
        #expect(member.memberStatus == .active)   // local intacto
    }

    /// El resto de comprobaciones previas también frenan ANTES de la red: un miembro de OTRO grupo (el `member_key`
    /// de un miembro nacido en el backend se repite en todos sus grupos) y quien no administra el grupo.
    @Test func rejectMember_backendGroup_otherGroupOrNotAdmin_throwBeforeRPC() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)

        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        CloudSyncFlags.groupsBackendEnabled = true

        let s = stub(#"{"group_id":"g","member_key":"mk","status":"rejected"}"#)
        GroupService.shared.backendMembershipFactory = { self.makeService(s) }

        let group = SplitGroup(name: "Trip")
        group.isOwner = true
        group.isBackendGroup = true
        context.insert(group)
        let other = SplitGroup(name: "Otro")
        other.isBackendGroup = true
        context.insert(other)
        let elsewhere = SplitMember(groupZoneID: other.cloudKitZoneID, displayName: "Gabi",
                                    cloudKitUserRecordID: "", role: "member", status: .pendingApproval)
        elsewhere.memberKey = "mk-gabi"
        context.insert(elsewhere)
        try context.save()

        await #expect {
            try await GroupService.shared.rejectMember(elsewhere, in: group)
        } throws: { error in
            if case GroupServiceError.memberNotInGroup = error { return true }
            return false
        }

        let notMine = SplitGroup(name: "Ajeno")
        notMine.isOwner = false
        notMine.isBackendGroup = true
        context.insert(notMine)
        let pending = SplitMember(groupZoneID: notMine.cloudKitZoneID, displayName: "Hugo",
                                  cloudKitUserRecordID: "", role: "member", status: .pendingApproval)
        pending.memberKey = "mk-hugo"
        context.insert(pending)
        try context.save()

        await #expect {
            try await GroupService.shared.rejectMember(pending, in: notMine)
        } throws: { error in
            if case GroupServiceError.adminRequired = error { return true }
            return false
        }

        #expect(s.callCount == 0)
        #expect(elsewhere.memberStatus == .pendingApproval)
        #expect(pending.memberStatus == .pendingApproval)
    }

    /// Si el servidor ya lo tenía como miembro (lo aprobaron en otro sitio), `remove_member` lo deja `removed`:
    /// el estado local sigue a la respuesta y no apunta un `rejected` que nunca ocurrió.
    @Test func rejectMember_backendGroup_serverSaysRemoved_localFollowsTheServer() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)

        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        CloudSyncFlags.groupsBackendEnabled = true

        let s = stub(#"{"group_id":"g","member_key":"mk-ines","status":"removed"}"#)
        GroupService.shared.backendMembershipFactory = { self.makeService(s) }

        let group = SplitGroup(name: "Trip")
        group.isOwner = true
        group.isBackendGroup = true
        context.insert(group)
        let member = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Inés",
                                 cloudKitUserRecordID: "", role: "member", status: .pendingApproval)
        member.memberKey = "mk-ines"
        context.insert(member)
        try context.save()

        try await GroupService.shared.rejectMember(member, in: group)

        #expect(s.callCount == 1)
        #expect(member.memberStatus == .removed)
    }

    @Test func localStatusAfterRejectRPC_followsTheServer() {
        #expect(GroupService.localStatusAfterRejectRPC("rejected") == .rejected)
        #expect(GroupService.localStatusAfterRejectRPC("removed") == .removed)
        #expect(GroupService.localStatusAfterRejectRPC("algo-nuevo") == .rejected)
    }

    /// Flag OFF → `rejectMember` no toca la red (camino CloudKit de siempre) y marca `.rejected` en local.
    @Test func rejectMember_flagOff_doesNotCallRPC() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)

        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        CloudSyncFlags.groupsBackendEnabled = false

        let s = stub(#"{"group_id":"g","member_key":"mk","status":"rejected"}"#)
        GroupService.shared.backendMembershipFactory = { self.makeService(s) }

        let group = SplitGroup(name: "Trip")
        group.isOwner = true
        group.isBackendGroup = true
        context.insert(group)
        let member = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Fede",
                                 cloudKitUserRecordID: "", role: "member", status: .pendingApproval)
        member.memberKey = "mk-fede"
        context.insert(member)
        try context.save()

        try await GroupService.shared.rejectMember(member, in: group)

        #expect(s.callCount == 0)
        #expect(member.memberStatus == .rejected)
    }

    /// «Cambiar rol» solo se ofrece donde `changeRole` puede funcionar: no en un grupo del canal backend.
    @Test func offersRoleChange_onlyOutsideTheBackendChannel() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }

        let backend = SplitGroup(name: "Nube")
        backend.isBackendGroup = true
        context.insert(backend)
        let legacy = SplitGroup(name: "Local")
        context.insert(legacy)
        try context.save()

        CloudSyncFlags.groupsBackendEnabled = true
        #expect(GroupService.shared.offersRoleChange(in: backend) == false)
        #expect(GroupService.shared.offersRoleChange(in: legacy) == true)
        CloudSyncFlags.groupsBackendEnabled = false
        #expect(GroupService.shared.offersRoleChange(in: backend) == true)
    }
}
