//
//  GroupCreateLostResponseTests.swift
//  YalaTests / CloudSync
//
//  Card 5d22 (ticket `creategroup-throw-after-commit-loses-owner`): si `create_group` se guarda en el servidor y la
//  respuesta se pierde, quien lo creó tiene que acabar como dueño cuando el pull traiga el grupo. Container on-disk con
//  los tres stores (molde `GroupBackendMembershipServiceTests`); el store de intentos va en defaults aislados.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · la creación que se guardó sin respuesta (card 5d22)", .serialized)
@MainActor
struct GroupCreateLostResponseTests {

    private let base = URL(string: "https://gw.test")!

    // MARK: - Infra

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupCreateLost-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("GroupCreateLostResponseTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "GCL-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "GCL-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "GCL-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    /// El entorno: el canal encendido y el store de intentos aislado. Todo se restaura al salir.
    private func withEnvironment(_ body: () async throws -> Void) async rethrows {
        let previousDefaults = PendingGroupCreationStore.defaults
        PendingGroupCreationStore.defaults = makeIsolatedDefaults()
        CloudSyncFlags.groupsBackendEnabled = true
        defer {
            PendingGroupCreationStore.defaults = previousDefaults
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        try await body()
    }

    private func makeService(_ json: String, status: Int, sub: String? = "sub-1")
        -> (GroupBackendMembershipService, GroupsSyncClientTests.StubHTTPSession) {
        let session = GroupsSyncClientTests.StubHTTPSession(responseData: Data(json.utf8), statusCode: status)
        let client = GroupsMembershipClient(baseURL: base, tokenProvider: { "jwt-token" }, urlSession: session)
        client.sleeper = { _ in }
        return (GroupBackendMembershipService(client: client, sessionCheck: { true }, currentUserID: { sub }), session)
    }

    private func sentZone(_ session: GroupsSyncClientTests.StubHTTPSession) throws -> String {
        let body = try #require(session.lastRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        return try #require(json["p_group_id"] as? String)
    }

    /// Lo que deja el pull: la fila born-remote del grupo (sin `isOwner`, que es local) y, si llegó, el miembro dueño
    /// con su `member_key` (sin `isCurrentUser`/`isGroupOwner`, que el wire no lleva).
    @discardableResult
    private func pullBrings(_ zone: String, member: String?, _ context: ModelContext) throws -> SplitGroup {
        let group = SplitGroup(name: "Viaje", currencyCode: "USD", isOwner: false)
        group.cloudKitZoneID = zone
        group.isBackendGroup = true
        group.initialMemberImportStartedAt = .now
        context.insert(group)
        if let member { try pullBringsMember(zone, key: member, context) }
        try context.save()
        return group
    }

    private func pullBringsMember(_ zone: String, key: String, _ context: ModelContext) throws {
        let row = SplitMember(groupZoneID: zone, displayName: "Alice", cloudKitUserRecordID: "", role: "admin",
                              status: .active, isGroupOwner: false, isCurrentUser: false)
        row.memberKey = key
        row.userID = key
        context.insert(row)
        try context.save()
    }

    // MARK: - Casos

    @Test("respuesta perdida (5xx): el intento se queda y el pull deja a quien lo creó como dueño")
    func lostResponse_thenPull_makesTheCreatorTheOwner() async throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try await withEnvironment {
            let (service, session) = makeService(#"{"error":"bad gateway"}"#, status: 502)
            await #expect(throws: GroupsRPCError.transient(status: 502)) {
                _ = try await service.createGroup(name: "Viaje", currencyCode: "USD", displayName: "Alice",
                                                  context: context)
            }
            let zone = try sentZone(session)
            #expect(PendingGroupCreationStore.pending().map(\.zoneID) == [zone], "el intento ambiguo no se apuntó")
            #expect(try context.fetch(FetchDescriptor<SplitGroup>()).isEmpty, "server-first: nada local tras el error")

            let group = try pullBrings(zone, member: "sub-1", context)
            GroupBackendMembershipService.adoptPendingCreations(context: context, currentUserID: "sub-1")

            #expect(group.isOwner, "quien creó el grupo no aparece como dueño")
            #expect(group.initialMemberImportStartedAt == nil)
            let me = try #require(try context.fetch(FetchDescriptor<SplitMember>()).first)
            #expect(me.isCurrentUser && me.isGroupOwner, "el miembro propio no se reconoce")
            #expect(PendingGroupCreationStore.pending().isEmpty, "el intento ya resuelto no se retiró")
        }
    }

    /// El miembro dueño puede llegar en otra página: el grupo se marca ya y el intento espera al miembro.
    @Test("el grupo llega antes que el miembro: se marca el grupo y el intento espera")
    func groupBeforeMember_waitsForTheMember() async throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try await withEnvironment {
            PendingGroupCreationStore.record(zoneID: "SplitGroup-Z", userID: "sub-1")
            let group = try pullBrings("SplitGroup-Z", member: nil, context)
            GroupBackendMembershipService.adoptPendingCreations(context: context, currentUserID: "sub-1")
            #expect(group.isOwner)
            #expect(PendingGroupCreationStore.pending().count == 1, "se retiró sin el miembro propio")

            try pullBringsMember("SplitGroup-Z", key: "sub-1", context)
            GroupBackendMembershipService.adoptPendingCreations(context: context, currentUserID: "sub-1")
            #expect(PendingGroupCreationStore.pending().isEmpty)
        }
    }

    /// Otra cuenta en el teléfono no hereda un grupo que no creó.
    @Test("con otra sesión no se adopta nada")
    func anotherSession_adoptsNothing() async throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try await withEnvironment {
            PendingGroupCreationStore.record(zoneID: "SplitGroup-Y", userID: "sub-1")
            let group = try pullBrings("SplitGroup-Y", member: "sub-1", context)
            GroupBackendMembershipService.adoptPendingCreations(context: context, currentUserID: "sub-2")
            #expect(!group.isOwner, "otra cuenta se quedó como dueña de un grupo que no creó")
            #expect(PendingGroupCreationStore.pending().count == 1)
        }
    }

    @Test("un rechazo definitivo retira el intento: el servidor no lo guardó")
    func definitiveRejection_removesTheAttempt() async throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try await withEnvironment {
            let (service, _) = makeService(#"{"error":{"code":"yala_invalid_group_id"}}"#, status: 400)
            await #expect(throws: GroupsRPCError.invalidGroupID) {
                _ = try await service.createGroup(name: "Viaje", currencyCode: "USD", displayName: "Alice",
                                                  context: context)
            }
            #expect(PendingGroupCreationStore.pending().isEmpty)
        }
    }

    @Test("con éxito no queda ningún intento")
    func success_leavesNoAttempt() async throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try await withEnvironment {
            let (service, _) = makeService(#"{"group_id":"x","member_key":"sub-1"}"#, status: 200)
            let group = try await service.createGroup(name: "Viaje", currencyCode: "USD", displayName: "Alice",
                                                      context: context)
            #expect(group.isOwner)
            #expect(PendingGroupCreationStore.pending().isEmpty)
        }
    }

    @Test("solo los errores que no dicen nada de lo que pasó en el servidor dejan el intento")
    func ambiguityTable() {
        #expect(GroupBackendMembershipService.createMayHaveCommitted(GroupsRPCError.transient(status: -1)))
        #expect(GroupBackendMembershipService.createMayHaveCommitted(GroupsRPCError.transient(status: 503)))
        #expect(GroupBackendMembershipService.createMayHaveCommitted(GroupsRPCError.decoding))
        let definitive: [GroupsRPCError] = [.sessionExpired, .channelDisabled, .groupExists, .invalidGroupID,
                                            .badInput, .notAuthorized, .permanentRejected(code: "yala_x")]
        for error in definitive {
            #expect(!GroupBackendMembershipService.createMayHaveCommitted(error), "\(error)")
        }
        #expect(!GroupBackendMembershipService.createMayHaveCommitted(CocoaError(.fileNoSuchFile)))
    }

    @Test("los intentos caducan a los 7 días y la frontera de persona los retira")
    func store_expiresAndClearsAtTheHandover() async {
        await withEnvironment {
            let then = Date(timeIntervalSince1970: 1_000_000)
            PendingGroupCreationStore.record(zoneID: "SplitGroup-T", userID: "sub-1", now: then)
            #expect(PendingGroupCreationStore.pending(now: then.addingTimeInterval(6 * 24 * 3600)).count == 1)
            #expect(PendingGroupCreationStore.pending(now: then.addingTimeInterval(8 * 24 * 3600)).isEmpty)

            PendingGroupCreationStore.record(zoneID: "SplitGroup-H", userID: "sub-1")
            DataWipeService.removeGroupsDomainPreferenceKeys(from: PendingGroupCreationStore.defaults)
            #expect(PendingGroupCreationStore.pending().isEmpty)
        }
    }
}
