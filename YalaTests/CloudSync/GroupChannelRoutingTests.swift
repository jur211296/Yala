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

    // MARK: - C2 · Partición del INVITE (createShare)

    /// Un grupo backend nunca debe mintear un CKShare — su invite va por token RPC (C4). El guard C2 de
    /// `createShare` es lo PRIMERO (antes del check de engine) → lanza `.backendGroup`.
    @Test func createShare_backendGroup_throwsBackendGroupError() async {
        let group = SplitGroup(name: "Backend")
        group.isOwner = true
        group.isBackendGroup = true

        do {
            _ = try await SplitZoneManager(syncManager: .shared).createShare(for: group)
            Issue.record("createShare debió lanzar para un grupo backend")
        } catch let error as SplitZoneError {
            guard case .backendGroup = error else {
                Issue.record("error inesperado: \(error)")
                return
            }
            // OK — partición C2 respetada.
        } catch {
            Issue.record("tipo de error inesperado: \(error)")
        }
    }

    // MARK: - C5 · Membership routing (approve / remove / leave)

    /// Flag ON + grupo backend → `approveMember` va SERVER-FIRST por RPC y luego activa localmente.
    @Test func approveMember_backendGroup_flagOn_callsRPC_thenActivatesLocally() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupService.shared.setContext(context)

        let prevFactory = GroupService.shared.backendMembershipFactory
        let prevFlag = CloudSyncFlags.groupsBackendEnabled
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags.groupsBackendEnabled = prevFlag
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
        let prevFlag = CloudSyncFlags.groupsBackendEnabled
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags.groupsBackendEnabled = prevFlag
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
        let prevFlag = CloudSyncFlags.groupsBackendEnabled
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags.groupsBackendEnabled = prevFlag
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
        let prevFlag = CloudSyncFlags.groupsBackendEnabled
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags.groupsBackendEnabled = prevFlag
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
        let prevFlag = CloudSyncFlags.groupsBackendEnabled
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags.groupsBackendEnabled = prevFlag
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
}
