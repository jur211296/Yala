//
//  GroupsActionsOfflineTokenTests.swift
//  YalaTests / CloudSync
//
//  Ticket `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` (2026-09-17). Sin red y con el token
//  caducado, la renovación falla y el SDK CONSERVA la sesión. Hasta ese día `GroupsMembershipClient.call` lo leía
//  como sesión caducada: salir de un grupo decía «Tu sesión caducó» y aceptar una invitación abría el inicio de
//  sesión, que sin red no arregla nada.
//
//  Por qué existe además de los casos de `GroupsMembershipClientTests`: aquéllos fijan el ERROR que lanza el cliente.
//  Lo que ve la persona lo deciden la puerta del servicio, `GroupService`, el clasificador y el handler de la
//  invitación, y eso solo se mide ejecutando el camino. Cada caso va en las dos direcciones: con la sesión guardada
//  (el ticket) y con la sesión que el SDK borró (sigue pidiendo volver a entrar).
//
//  Serializado: toca `GroupService.shared` (contexto y fábrica), `CloudSyncFlags.groupsBackendEnabled`, los providers
//  estáticos del handler, `PendingJoinStore.defaults`, `AppRouter.shared` y `RouterEntryGate.readinessProvider` (todo
//  restaurado). Molde de infra: `GroupLeaveOwnershipReconcileTests` (salir) y `GroupBackendArchivedJoinTests`
//  (invitación). Que producción herede el testigo vivo lo fija `AttestWiringTests`, con el resto del cableado.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Acciones de Grupos · el token que no llega sin red no es una sesión caducada", .serialized)
@MainActor
struct GroupsActionsOfflineTokenTests {

    private let base = URL(string: "https://gw.test")!

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GAOT-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GAOT-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GAOT-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GAOT-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Un servicio real con un cliente real al que el token no le llega. `sessionCheck: { true }` es la puerta del
    /// servicio (`hasSession`), que en producción vale lo mismo que el testigo, salvo en el instante en que la
    /// renovación borra la sesión: el caso de la sesión borrada entra por ahí.
    private func membership(
        canRenewSession: Bool, session: GroupsSyncClientTests.StubHTTPSession
    ) -> GroupBackendMembershipService {
        let client = GroupsMembershipClient(
            baseURL: base, tokenProvider: { nil }, canRenewSession: { canRenewSession }, urlSession: session)
        client.sleeper = { _ in }
        return GroupBackendMembershipService(client: client, sessionCheck: { true })
    }

    // MARK: - Salir de un grupo

    private func arrangeLeave(
        _ context: ModelContext, canRenewSession: Bool, session: GroupsSyncClientTests.StubHTTPSession
    ) -> () -> Void {
        let savedFactory = GroupService.shared.backendMembershipFactory
        GroupService.shared.setContext(context)
        CloudSyncFlags.groupsBackendEnabled = true
        GroupService.shared.backendMembershipFactory = {
            self.membership(canRenewSession: canRenewSession, session: session)
        }
        return {
            GroupService.shared.backendMembershipFactory = savedFactory
            // El directorio de los `.sqlite` se borra al salir del test: sin esto el singleton se quedaría con un
            // contenedor sobre ficheros que ya no existen.
            GroupService.shared._testResetContext()
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
    }

    private func makeMemberGroup(zone: String, context: ModelContext) -> SplitGroup {
        let g = SplitGroup(name: "Viaje")
        g.cloudKitZoneID = zone
        g.isOwner = false
        g.isBackendGroup = true
        context.insert(g)
        return g
    }

    private func groupCount(_ context: ModelContext, zone: String) throws -> Int {
        try context.fetchCount(
            FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zone }))
    }

    /// Lo que devuelve `leaveGroup` cuando falla. `#expect(throws:)` no deja el error a mano, y aquí hace falta
    /// pasárselo al clasificador de las dos pantallas de salida.
    private func leaveError(_ group: SplitGroup) async -> Error? {
        do {
            try await GroupService.shared.leaveGroup(group)
            return nil
        } catch {
            return error
        }
    }

    /// **El caso del ticket, de punta a punta.** Las dos pantallas de salida (Ajustes del grupo y la tarjeta del grupo
    /// rechazado) pintan `GroupLeaveErrorLogic.classify(…).localizedMessage`: con la sesión guardada dice «No pudimos
    /// completar tu salida del grupo. Vuelve a intentarlo en un momento.», no «Tu sesión caducó». El grupo sigue
    /// local y no salió ninguna petición.
    @Test func leave_withTheSessionKept_saysTryAgainInAMoment_andKeepsTheGroup() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = GroupsSyncClientTests.StubHTTPSession(statusCode: 200)
        let restore = arrangeLeave(context, canRenewSession: true, session: session); defer { restore() }
        let group = makeMemberGroup(zone: "zone-offline", context: context)
        try context.save()

        let error = try #require(await leaveError(group))

        #expect(error as? GroupsRPCError == .transient(status: -1))
        let kind = GroupLeaveErrorLogic.classify(error, attestUnavailable: false)
        #expect(kind == .retryLater)
        #expect(kind.localizedMessage == L10n.Groups.Errors.leaveUnavailable)
        // Con la racha de App Attest terminal tampoco culpa al teléfono: el fallo es la red, no el attest. Es lo que
        // fija que el `status` sea `-1` y no el 401 que el clasificador lee como «este teléfono no puede sincronizar».
        #expect(GroupLeaveErrorLogic.classify(error, attestUnavailable: true) == .retryLater)
        #expect(session.callCount == 0)
        #expect(try groupCount(context, zone: "zone-offline") == 1)
    }

    /// La dirección contraria: el SDK borró la sesión. Ahí «Tu sesión caducó» es verdad y el aviso sigue saliendo.
    @Test func leave_afterTheSDKRemovedTheSession_stillSaysTheSessionExpired() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = GroupsSyncClientTests.StubHTTPSession(statusCode: 200)
        let restore = arrangeLeave(context, canRenewSession: false, session: session); defer { restore() }
        let group = makeMemberGroup(zone: "zone-expired", context: context)
        try context.save()

        let error = try #require(await leaveError(group))

        #expect(error as? GroupsRPCError == .sessionExpired)
        let kind = GroupLeaveErrorLogic.classify(error, attestUnavailable: false)
        #expect(kind == .sessionExpired)
        #expect(kind.localizedMessage == L10n.Groups.Errors.sessionExpired)
        #expect(session.callCount == 0)
        #expect(try groupCount(context, zone: "zone-expired") == 1)
    }

    // MARK: - Aceptar una invitación

    private func arrangeJoin(
        canRenewSession: Bool, session: GroupsSyncClientTests.StubHTTPSession
    ) -> () -> Void {
        let suite = "test.offlinejoin.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        PendingJoinStore.defaults = d
        let savedJoin = GroupBackendInviteEntryHandler.joinProvider
        let savedProfile = GroupBackendInviteEntryHandler.profileNameProvider
        let savedReadiness = RouterEntryGate.shared.readinessProvider

        CloudSyncFlags.groupsBackendEnabled = true
        GroupBackendInviteEntryHandler.profileNameProvider = { "Pia" }
        let service = membership(canRenewSession: canRenewSession, session: session)
        GroupBackendInviteEntryHandler.joinProvider = { token, displayName, legacy in
            try await service.join(token: token, displayName: displayName, legacyMemberKey: legacy)
        }
        // App lista: sin esto el gate DIFIERE el intent al buffer y la cola queda vacía por una razón que no tiene
        // nada que ver con lo que se mide (molde `GroupBackendArchivedJoinTests`).
        RouterEntryGate.shared.readinessProvider = { (hasCompletedOnboarding: true, isBootstrapInitialized: true) }
        AppRouter.shared._testReset()
        GroupBackendInviteEntryHandler.clearInviteTapArms()
        GroupJoinIntentTracker.shared.clear()

        return {
            GroupBackendInviteEntryHandler.joinProvider = savedJoin
            GroupBackendInviteEntryHandler.profileNameProvider = savedProfile
            RouterEntryGate.shared.readinessProvider = savedReadiness
            AppRouter.shared._testReset()
            PendingJoinStore.defaults = .standard
            d.removePersistentDomain(forName: suite)
            GroupBackendInviteEntryHandler.clearInviteTapArms()
            GroupJoinIntentTracker.shared.clear()
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
    }

    private func signInRequests(in queue: [RouterIntent]) -> [String] {
        queue.compactMap { if case .presentGroupsSignIn(let zone) = $0 { return zone } else { return nil } }
    }

    private func seedIntent(_ zone: String) {
        PendingJoinStore.save(PendingJoinEntry(
            zoneName: zone, zoneOwnerName: "", displayName: "Pia",
            backendGroupID: zone, inviteToken: "tok"))
    }

    /// Con la sesión guardada, la unión que falla sin red NO abre el inicio de sesión: conserva la invitación y re-arma
    /// el tap para que el reconciler la reintente al volver a la app. La pantalla de unión sigue esperando, como ya
    /// pasaba sin red con el token vigente. Es el mismo trato que el 401 de App Attest desde el 2026-09-15.
    @Test func join_withTheSessionKept_doesNotAskToSignIn_andKeepsTheInvite() async {
        let session = GroupsSyncClientTests.StubHTTPSession(statusCode: 200)
        let restore = arrangeJoin(canRenewSession: true, session: session); defer { restore() }
        seedIntent("G-OFF")

        await GroupBackendInviteEntryHandler.attemptJoin(groupID: "G-OFF", token: "tok", source: .userAction)

        #expect(signInRequests(in: AppRouter.shared.queueSnapshot).isEmpty)
        #expect(PendingJoinStore.entry(zoneName: "G-OFF") != nil)
        #expect(GroupBackendInviteEntryHandler.isInviteTapArmed(groupID: "G-OFF"))
        #expect(session.callCount == 0)
    }

    /// La dirección contraria, y la que prueba que el caso de arriba no sale verde por una cola que no se llena: con la
    /// sesión borrada, la misma unión SÍ pide volver a entrar, para esa invitación.
    @Test func join_afterTheSDKRemovedTheSession_asksToSignIn() async {
        let session = GroupsSyncClientTests.StubHTTPSession(statusCode: 200)
        let restore = arrangeJoin(canRenewSession: false, session: session); defer { restore() }
        seedIntent("G-EXP")

        await GroupBackendInviteEntryHandler.attemptJoin(groupID: "G-EXP", token: "tok", source: .userAction)

        #expect(signInRequests(in: AppRouter.shared.queueSnapshot) == ["G-EXP"])
        #expect(PendingJoinStore.entry(zoneName: "G-EXP") != nil)
        #expect(GroupBackendInviteEntryHandler.isInviteTapArmed(groupID: "G-EXP"))
        #expect(session.callCount == 0)
    }
}
