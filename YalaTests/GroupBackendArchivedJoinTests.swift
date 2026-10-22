//
//  GroupBackendArchivedJoinTests.swift
//  YalaTests
//
//  g13_05 · comportamiento del terminal cuando el servidor rechaza la entrada a un grupo ARCHIVADO.
//
//  Por qué existe además de `GroupBackendAcceptErrorLogicTests`: aquél fija la TABLA (código → kind →
//  permanencia → slug) y pasaría en verde aunque `handleJoinError` no cableara la rama, o la cableara a
//  la alerta equivocada. Lo que decide lo que ve la persona es el intent que se encola, y eso solo se
//  mide ejecutando el camino.
//
//  Serializado: toca los providers estáticos del handler + `PendingJoinStore.defaults` +
//  `AppRouter.shared` + `RouterEntryGate.readinessProvider` (todo restaurado en el cleanup).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("g13_05 · join a un grupo archivado", .serialized)
struct GroupBackendArchivedJoinTests {

    private func makeEnv(failWith error: GroupsRPCError) -> () -> Void {
        let suite = "test.archivedjoin.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        PendingJoinStore.defaults = d
        let savedJoin = GroupBackendInviteEntryHandler.joinProvider
        let savedProfile = GroupBackendInviteEntryHandler.profileNameProvider
        let savedReadiness = RouterEntryGate.shared.readinessProvider

        GroupBackendInviteEntryHandler.profileNameProvider = { "Pia" }
        GroupBackendInviteEntryHandler.joinProvider = { _, _, _ in throw error }
        // App lista: sin esto el gate DIFIERE el intent al buffer y la cola queda vacía por una razón que
        // no tiene nada que ver con lo que se mide.
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
        }
    }

    private func archivedNotice(in queue: [RouterIntent]) -> (groupID: String, groupName: String)? {
        for intent in queue {
            if case .showGroupArchivedNotice(let id, let name) = intent { return (id, name) }
        }
        return nil
    }

    private func hasInviteError(in queue: [RouterIntent]) -> Bool {
        queue.contains { if case .showInviteError = $0 { return true }; return false }
    }

    /// El enlace traía el nombre del grupo (`n=`) → el aviso lo usa en su título. Y NO se encola
    /// `.showInviteError`, cuyo título dice «Enlace no válido»: el enlace de este caso es perfecto.
    @Test func archived_enqueuesStateNotice_withGroupNameFromLink() async {
        let cleanup = makeEnv(failWith: .groupArchived); defer { cleanup() }
        PendingJoinStore.save(PendingJoinEntry(
            zoneName: "G-ARCH", zoneOwnerName: "", displayName: "Pia",
            backendGroupID: "G-ARCH", inviteToken: "tok",
            branded: InviteLinkService.BrandedMetadata(
                name: "Viaje a Cusco", icon: nil, color: nil, members: nil)))

        await GroupBackendInviteEntryHandler.attemptJoin(groupID: "G-ARCH", token: "tok", source: .userAction)

        let notice = archivedNotice(in: AppRouter.shared.queueSnapshot)
        #expect(notice?.groupID == "G-ARCH")
        #expect(notice?.groupName == "Viaje a Cusco")
        #expect(!hasInviteError(in: AppRouter.shared.queueSnapshot))
    }

    /// Sin `n=` en el enlace no hay nombre que poner. El título cae al genérico ya traducido en vez de
    /// quedarse con un hueco vacío («  fue archivado»).
    @Test func archived_fallsBackToGenericName_whenLinkCarriesNone() async {
        let cleanup = makeEnv(failWith: .groupArchived); defer { cleanup() }
        PendingJoinStore.save(PendingJoinEntry(
            zoneName: "G-ARCH", zoneOwnerName: "", displayName: "Pia",
            backendGroupID: "G-ARCH", inviteToken: "tok"))

        await GroupBackendInviteEntryHandler.attemptJoin(groupID: "G-ARCH", token: "tok", source: .userAction)

        let notice = archivedNotice(in: AppRouter.shared.queueSnapshot)
        #expect(notice?.groupName == L10n.Groups.Reconnect.fallbackGroupName)
        #expect(notice?.groupName.isEmpty == false)
    }

    /// PERMANENTE: el intent se limpia. Un grupo archivado no se desarchiva solo, así que conservarlo
    /// haría que el reconciler reintentara en cada arranque durante los siete días del TTL sin que nada
    /// cambie nunca.
    @Test func archived_clearsIntent_soTheReconcilerStopsRetrying() async {
        let cleanup = makeEnv(failWith: .groupArchived); defer { cleanup() }
        PendingJoinStore.save(PendingJoinEntry(
            zoneName: "G-ARCH", zoneOwnerName: "", displayName: "Pia",
            backendGroupID: "G-ARCH", inviteToken: "tok"))

        await GroupBackendInviteEntryHandler.attemptJoin(groupID: "G-ARCH", token: "tok", source: .userAction)

        #expect(PendingJoinStore.entry(zoneName: "G-ARCH") == nil)
    }

    /// CONTROL EN LA DIRECCIÓN CONTRARIA, y es la mitad que da la prueba: un enlace REALMENTE inválido
    /// sigue saliendo por `.showInviteError` y no por el aviso nuevo. Sin esta aserción, un cableado que
    /// mandara TODOS los fallos permanentes al aviso de archivado pasaría los tres tests de arriba.
    @Test func invalidInvite_stillUsesTheInviteErrorPath() async {
        let cleanup = makeEnv(failWith: .invalidInvite); defer { cleanup() }
        PendingJoinStore.save(PendingJoinEntry(
            zoneName: "G-X", zoneOwnerName: "", displayName: "Pia",
            backendGroupID: "G-X", inviteToken: "tok"))

        await GroupBackendInviteEntryHandler.attemptJoin(groupID: "G-X", token: "tok", source: .userAction)

        #expect(hasInviteError(in: AppRouter.shared.queueSnapshot))
        #expect(archivedNotice(in: AppRouter.shared.queueSnapshot) == nil)
    }

    /// El otro control: `.groupDeleted` conserva SU camino (el copy de «lo eliminó su creador»), que es
    /// un hecho distinto y sin vuelta atrás. Colapsar los dos estados perdería esa diferencia.
    @Test func groupDeleted_keepsItsOwnPath() async {
        let cleanup = makeEnv(failWith: .groupDeleted); defer { cleanup() }
        PendingJoinStore.save(PendingJoinEntry(
            zoneName: "G-D", zoneOwnerName: "", displayName: "Pia",
            backendGroupID: "G-D", inviteToken: "tok"))

        await GroupBackendInviteEntryHandler.attemptJoin(groupID: "G-D", token: "tok", source: .userAction)

        #expect(hasInviteError(in: AppRouter.shared.queueSnapshot))
        #expect(archivedNotice(in: AppRouter.shared.queueSnapshot) == nil)
    }
}
