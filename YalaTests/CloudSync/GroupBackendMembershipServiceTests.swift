//
//  GroupBackendMembershipServiceTests.swift
//  YalaTests / CloudSync
//
//  Materializador de membresía server-first del canal Grupos → backend (incremento G3, DARK). Los tests que
//  ejercitan el DRAIN usan un container ON-DISK con los 3 stores (A2: el History NO es fiable in-memory —
//  lección R8/G2), no `makeTestContext`. `.serialized` (togglea `CloudSyncFlags.groupsBackendEnabled` +
//  containers propios). Reusa `GroupsSyncClientTests.StubHTTPSession`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupBackendMembershipService · create/join server-first (DARK)", .serialized)
@MainActor
struct GroupBackendMembershipServiceTests {

    private let base = URL(string: "https://gw.test")!

    // MARK: - Infra (container ON-DISK, molde GroupsSyncClientTests, A2)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupMembership-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GM-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GM-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GM-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func makeService(
        _ session: GroupsSyncClientTests.StubHTTPSession, session live: Bool = true
    ) -> GroupBackendMembershipService {
        let client = GroupsMembershipClient(baseURL: base, tokenProvider: { "jwt-token" }, urlSession: session)
        client.sleeper = { _ in }  // B2: sin sleeps reales si un stub clasificara transitorio
        return GroupBackendMembershipService(client: client, sessionCheck: { live })
    }

    private func stub(_ json: String, status: Int = 200) -> GroupsSyncClientTests.StubHTTPSession {
        GroupsSyncClientTests.StubHTTPSession(responseData: Data(json.utf8), statusCode: status)
    }

    // MARK: - createGroup happy (server-first + drain silencioso)

    @Test func createGroup_happy_materializesOwner_savesUnderOutboxAuthor() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let session = stub(#"{"group_id":"ignored-echo","member_key":"sub-99"}"#)
        let service = makeService(session)

        // Flags NO-default (true) → prueba que el SERVICIO los propaga al RPC (no solo el client).
        let group = try await service.createGroup(
            name: "Trip", currencyCode: "USD", displayName: "Alice",
            simplifyDebts: true, showDebtsInSingleCurrency: true, membersCanInvite: true,
            context: context)

        // El grupo se insertó con isOwner y su cloudKitZoneID == el p_group_id ENVIADO al RPC.
        let sentBody = try #require(session.lastRequest?.httpBody)
        let sentJSON = try #require(try JSONSerialization.jsonObject(with: sentBody) as? [String: Any])
        #expect(sentJSON["p_group_id"] as? String == group.cloudKitZoneID)
        // El servicio propaga los flags NO-default al body del RPC.
        #expect(sentJSON["p_simplify_debts"] as? Bool == true)
        #expect(sentJSON["p_show_debts_in_single_currency"] as? Bool == true)
        #expect(sentJSON["p_members_can_invite"] as? Bool == true)
        #expect(group.isOwner == true)
        #expect(group.isBackendGroup == true)   // C1 write-site (1): grupo del canal backend

        let groups = try context.fetch(FetchDescriptor<SplitGroup>())
        #expect(groups.count == 1)

        // Owner member: id determinista backend, memberKey/userID == sub, cloudKitUserRecordID VACÍO.
        let members = try context.fetch(FetchDescriptor<SplitMember>())
        #expect(members.count == 1)
        let owner = try #require(members.first)
        #expect(owner.id == GroupBackendIdentityLogic.deterministicMemberID(
            groupID: group.cloudKitZoneID, memberKey: "sub-99"))
        #expect(owner.memberKey == "sub-99")
        #expect(owner.userID == "sub-99")
        #expect(owner.cloudKitUserRecordID == "")   // separación: el sub no contamina CloudKit
        #expect(owner.isGroupOwner == true)
        #expect(owner.isCurrentUser == true)
        #expect(owner.role == "admin")
        #expect(owner.memberStatus == .active)

        // MECANISMO (assert DISCRIMINANTE): el save de la meta inicial fue bajo
        // `GroupsSyncClient.outboxSaveAuthor` (echo-suppression). Verificamos el AUTOR de la transacción de
        // History que contiene los cambios de SplitGroup/SplitMember (molde `GroupsSyncClient.fetchHistory`):
        // si el autor regresara a default, el save NO se suprimiría y este assert fallaría.
        let history = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        let metaTxns = history.filter { tx in
            tx.changes.contains { change in
                let name = change.changedPersistentIdentifier.entityName
                return name == "SplitGroup" || name == "SplitMember"
            }
        }
        #expect(!metaTxns.isEmpty)
        #expect(metaTxns.allSatisfy { $0.author == GroupsSyncClient.outboxSaveAuthor })

        // DOBLE RED (no el mecanismo): el drain no emite la meta inicial. Este assert es TAUTOLÓGICO por sí
        // solo (SplitGroup es update_only → su INSERT nunca emite; SplitMember no es emisible) → el assert de
        // autor de arriba es el que realmente prueba la echo-suppression.
        GroupsSyncClient().drainOnce(context: context)
        #expect(try context.fetch(FetchDescriptor<GroupSyncOutbox>()).isEmpty)
    }

    // MARK: - createGroup RPC error → sin inserts

    @Test func createGroup_rpcError_leavesContextUntouched() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let session = stub(#"{"error":{"code":"yala_invalid_group_id"}}"#, status: 400)
        let service = makeService(session)

        await #expect(throws: GroupsRPCError.invalidGroupID) {
            _ = try await service.createGroup(
                name: "Trip", currencyCode: "USD", displayName: "Alice", context: context)
        }

        #expect(try context.fetch(FetchDescriptor<SplitGroup>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SplitMember>()).isEmpty)
    }

    // MARK: - Gate DARK: flag OFF → no-op sin request

    @Test func createGroup_flagOff_throwsWithoutRequest() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = false

        let session = stub(#"{"group_id":"g","member_key":"m"}"#)
        let service = makeService(session)

        await #expect(throws: GroupsRPCError.sessionExpired) {
            _ = try await service.createGroup(
                name: "Trip", currencyCode: "USD", displayName: "Alice", context: context)
        }
        #expect(session.callCount == 0)   // ni red ni contexto
        #expect(try context.fetch(FetchDescriptor<SplitGroup>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SplitMember>()).isEmpty)
    }

    // MARK: - join: RPC only, no materializa localmente

    @Test func join_rpcOnly_insertsNothingLocally() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let session = stub(#"{"group_id":"g-1","member_key":"sub-3","status":"pendingApproval","rebound":false}"#)
        let service = makeService(session)

        let result = try await service.join(token: "tok-1", displayName: "Bob", legacyMemberKey: nil)
        #expect(result == JoinGroupResult(
            groupID: "g-1", memberKey: "sub-3", status: "pendingApproval", rebound: false))

        #expect(session.lastRequest?.url?.absoluteString == "https://gw.test/groups/rpc/join_group")
        // El pull reconcilia grupo+members; join NO materializa nada local.
        #expect(try context.fetch(FetchDescriptor<SplitGroup>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<SplitMember>()).isEmpty)
    }

    // MARK: - D-R1 paso 2: la asimetría del gate de `forgetUser` (teardown vs entradas)

    /// `forgetUser` es el ÚNICO método del service que NO se apaga con el kill remoto: lo invoca el
    /// borrado de cuenta para anonimizar/transferir lo que el usuario YA subió, y un kill no borra eso.
    /// El escenario se monta togglando **`CloudRemoteFlags`**, no `CloudSyncFlags`: el override de
    /// `CloudSyncFlags.groupsBackendEnabled` lo comparte `groupsBackendCompiledCapability`, así que
    /// apagarlo por ahí apagaría también la capacidad y el test dejaría de probar lo que dice.
    ///
    /// **Cae si el flip se revierte**: con `groupsBackendCompiledDefault == false` la capacidad es
    /// `false` y `ensureEligibleForTeardown` lanza `sessionExpired` sin request.
    @Test func forgetUser_survivesRemoteKill_whileEntriesStayClosed() async throws {
        CloudSyncFlags._testResetGroupsBackendEnabledOverride()   // composición REAL, sin override
        CloudRemoteFlags._testSetOverrides(groupsBackend: false)  // kill remoto activo
        defer { CloudRemoteFlags._testResetOverrides() }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // El teardown pasa: el binario es capaz y hay sesión.
        let forgetSession = stub(#"{"groups_transferred":0,"groups_tombstoned":0,"memberships_anonymized":2}"#)
        _ = try await makeService(forgetSession).forgetUser()
        #expect(forgetSession.callCount == 1)
        #expect(forgetSession.lastRequest?.url?.absoluteString
            == "https://gw.test/groups/rpc/groups_forget_user")

        // Y las ENTRADAS siguen cerradas por el mismo kill: es lo que el kill-switch existe para hacer.
        let createSession = stub(#"{"group_id":"g","member_key":"m"}"#)
        await #expect(throws: GroupsRPCError.sessionExpired) {
            _ = try await makeService(createSession).createGroup(
                name: "Trip", currencyCode: "USD", displayName: "Alice", context: context)
        }
        #expect(createSession.callCount == 0)
    }

    /// La otra mitad del gate del teardown: sin SESIÓN no hay red ni contexto, aunque el binario sea
    /// capaz. `ensureEligibleForTeardown` conserva el `sessionCheck()` justamente por esto — sin él la
    /// llamada entraría a la red para morir en el guard del `tokenProvider`.
    @Test func forgetUser_noSession_throwsWithoutRequest() async throws {
        CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        let session = stub(#"{"groups_transferred":0,"groups_tombstoned":0,"memberships_anonymized":0}"#)

        await #expect(throws: GroupsRPCError.sessionExpired) {
            _ = try await makeService(session, session: false).forgetUser()
        }
        #expect(session.callCount == 0)
    }
}
