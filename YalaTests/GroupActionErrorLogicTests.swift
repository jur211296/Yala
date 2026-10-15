//
//  GroupActionErrorLogicTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 12 (Grupos I). Tres cosas que se veían en pantalla y no eran verdad:
//  - crear un grupo, aprobar, rechazar, expulsar o cambiar de rol enseñaban «Error de Yala.GroupsRPCError 2»;
//  - crear el enlace de invitación decía «revisa tu conexión» con la conexión buena;
//  - la tarjeta de quien espera aprobación contaba su propia solicitud como «1 solicitud pendiente».
//  El cableado de las superficies va en `GroupsLot12WiringTests`.
//

import Foundation
import Testing

@testable import Yala

struct GroupActionErrorLogicTests {

    typealias L = GroupActionErrorLogic

    // MARK: - Acciones (crear, aprobar, rechazar, expulsar, cambiar rol)

    @Test func classify_rpc_everyCase() {
        #expect(L.classify(GroupsRPCError.sessionExpired, attestUnavailable: false) == .sessionExpired)
        #expect(L.classify(GroupsRPCError.channelDisabled, attestUnavailable: false) == .channelOff)
        // Lo pasajero pide volver a intentarlo, que es lo que dice `actionFailed`.
        #expect(L.classify(GroupsRPCError.transient(status: -1), attestUnavailable: false) == .generic)
        #expect(L.classify(GroupsRPCError.transient(status: 503), attestUnavailable: false) == .generic)
        // El 401 del attest solo es «este teléfono no puede» con la racha terminal.
        #expect(L.classify(GroupsRPCError.transient(status: 401), attestUnavailable: false) == .generic)
        #expect(L.classify(GroupsRPCError.transient(status: 401), attestUnavailable: true) == .deviceCannotSyncGroups)
        #expect(L.classify(GroupsRPCError.transient(status: 503), attestUnavailable: true) == .generic)

        let resto: [GroupsRPCError] = [.notAuthorized, .invalidInvite, .groupDeleted, .groupArchived, .badInput,
                                       .groupExists, .invalidGroupID, .memberNotFound, .cannotRemoveOwner,
                                       .ownerCannotLeave, .permanentRejected(code: "yala_x"), .decoding]
        for error in resto {
            #expect(L.classify(error, attestUnavailable: false) == .generic, "\(error)")
        }
    }

    @Test func classify_service_pendingApprovalHasItsOwnText_restGeneric() {
        #expect(L.classify(GroupServiceError.currentUserPendingApproval, attestUnavailable: false) == .pendingApproval)
        #expect(L.classify(GroupServiceError.adminRequired, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupServiceError.saveFailed(GroupServiceError.noContext), attestUnavailable: false) == .generic)
    }

    @Test func classify_foreignError_isGeneric() {
        #expect(L.classify(URLError(.notConnectedToInternet), attestUnavailable: false) == .generic)
    }

    /// Ningún caso devuelve el texto crudo de Foundation: los cinco textos son claves del catálogo.
    @MainActor
    @Test func everyKind_hasACatalogMessage_neverTheEnumDiscriminant() {
        let kinds: [L.Kind] = [.sessionExpired, .channelOff, .deviceCannotSyncGroups, .pendingApproval, .generic]
        for kind in kinds {
            let text = kind.localizedMessage
            #expect(!text.isEmpty)
            #expect(!text.contains("GroupsRPCError"), "\(kind)")
            #expect(!text.contains("GroupService:"), "\(kind)")
        }
        #expect(L.message(for: GroupsRPCError.sessionExpired) == L10n.Groups.Errors.sessionExpired)
    }

    // MARK: - Enlace de invitación

    @Test func classifyInvite_onlyANetworkFailureBlamesTheConnection() {
        #expect(L.classifyInviteFailure(GroupsRPCError.transient(status: -1), attestUnavailable: false) == .noConnection)
        #expect(L.classifyInviteFailure(GroupsRPCError.transient(status: 503), attestUnavailable: false) == .unavailable)
        #expect(L.classifyInviteFailure(GroupsRPCError.transient(status: 401), attestUnavailable: false) == .unavailable)
        #expect(L.classifyInviteFailure(GroupsRPCError.transient(status: 401), attestUnavailable: true) == .deviceCannotSyncGroups)
        #expect(L.classifyInviteFailure(GroupsRPCError.sessionExpired, attestUnavailable: false) == .sessionExpired)
        #expect(L.classifyInviteFailure(GroupsRPCError.channelDisabled, attestUnavailable: false) == .unavailable)
        #expect(L.classifyInviteFailure(GroupsRPCError.decoding, attestUnavailable: false) == .unavailable)
        #expect(L.classifyInviteFailure(URLError(.timedOut), attestUnavailable: false) == .unavailable)
    }

    @MainActor
    @Test func inviteKinds_mapToTheirTexts() {
        #expect(L.InviteKind.noConnection.localizedMessage == L10n.Groups.Errors.inviteFailed)
        #expect(L.InviteKind.unavailable.localizedMessage == L10n.Groups.Errors.inviteChannelOff)
        #expect(L.InviteKind.sessionExpired.localizedMessage == L10n.Groups.Errors.sessionExpired)
        #expect(L.InviteKind.deviceCannotSyncGroups.localizedMessage == L10n.Groups.Errors.attestUnavailable)
        // La sesión caducada (lo que da hoy el simulador con sesión fingida) ya no culpa a la conexión.
        #expect(L.inviteMessage(for: GroupsRPCError.sessionExpired) != L10n.Groups.Errors.inviteFailed)
    }

    // MARK: - Tarjeta de quien espera aprobación

    @Test func visiblePendingCount_hidesOwnRequestFromPendingAndRejected() {
        #expect(GroupCardDisplayLogic.visiblePendingCount(1, displayMode: .pendingApproval) == 0)
        #expect(GroupCardDisplayLogic.visiblePendingCount(2, displayMode: .rejected) == 0)
        #expect(GroupCardDisplayLogic.visiblePendingCount(1, displayMode: .active) == 1)
        #expect(GroupCardDisplayLogic.visiblePendingCount(3, displayMode: .migratedFrozen) == 3)
        #expect(GroupCardDisplayLogic.visiblePendingCount(0, displayMode: .active) == 0)
    }

    // MARK: - La demo del educativo cuadra

    @Test func onboardingDemo_shareTimesMembersIsTheExpense() {
        #expect(GroupsOnboardingDemo.share * Double(GroupsOnboardingDemo.memberCount) == GroupsOnboardingDemo.expense)
        #expect(GroupsOnboardingDemo.share == 25)
    }
}

// MARK: - Avisos del consent

@MainActor
@Suite(.serialized)
struct GroupsConsentChangeNotificationTests {

    /// Cuenta los avisos de `didChangeNotification` que llegan mientras corre `body`.
    private func countNotifications(_ body: () -> Void) -> Int {
        var count = 0
        let token = NotificationCenter.default.addObserver(
            forName: GroupsConsentState.didChangeNotification, object: nil, queue: nil) { _ in count += 1 }
        defer { NotificationCenter.default.removeObserver(token) }
        body()
        return count
    }

    @Test func writeAndClear_announceTheChange() throws {
        let previous = GroupsConsentState.defaults
        let isolated = try #require(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        GroupsConsentState.defaults = isolated
        defer { GroupsConsentState.defaults = previous }

        let written = countNotifications {
            GroupsConsentState.write(GroupsConsentSnapshot(userID: nil, textVersion: 99, acceptedAt: .now))
        }
        #expect(written == 1)
        #expect(GroupsConsentState.readSnapshot() != nil)

        let cleared = countNotifications { GroupsConsentState.clear() }
        #expect(cleared == 1)
        #expect(GroupsConsentState.readSnapshot() == nil)
    }
}

// MARK: - Cableado

struct GroupsLot12WiringTests {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private func fuente(_ ruta: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(ruta), encoding: .utf8)
    }

    /// Las superficies de crear grupo y de las acciones de admin eligen el texto con el clasificador.
    @Test(arguments: [
        "Yala/App/Views/Groups/GroupFormView.swift",
        "Yala/App/Views/Groups/GroupMembersView.swift",
    ])
    func actionSurfaces_neverShowTheRawError(ruta: String) throws {
        let src = try fuente(ruta)
        #expect(src.contains("ErrorMessage"), "\(ruta) ya no tiene el estado del alert")
        #expect(src.contains("GroupActionErrorLogic.message(for: error)"))
        #expect(!src.contains("ErrorMessage = error.localizedDescription"), "\(ruta) volvió a pintar el error crudo")
    }

    /// Las dos superficies que acuñan el enlace clasifican el fallo en vez de culpar siempre a la conexión.
    @Test(arguments: [
        "Yala/App/Views/Groups/GroupMembersView.swift",
        "Yala/App/ViewModels/GroupDetailViewModel.swift",
    ])
    func inviteSurfaces_classifyTheFailure(ruta: String) throws {
        let src = try fuente(ruta)
        #expect(src.contains("createShareLink"), "\(ruta) ya no acuña el enlace")
        #expect(src.contains("GroupActionErrorLogic.inviteMessage(for: error)"))
    }

    /// El estado vacío de la pestaña escucha el aviso del consent y lo lee al decidirse.
    @Test func groupsTab_repaintsWhenTheConsentChanges() throws {
        let src = try fuente("Yala/App/Views/Groups/GroupsContainerView.swift")
        #expect(src.contains("GroupsConsentState.didChangeNotification"))
        #expect(src.contains("consentRevision &+= 1"))
        #expect(src.contains("let _ = consentRevision"))
    }

    /// El texto del inicio de sesión solo habla de invitación cuando la hay.
    @Test func signIn_knowsWhetherThereIsAnInvitation() throws {
        let modifier = try fuente("Yala/App/Views/Shared/GroupsBackendInviteModifier.swift")
        #expect(modifier.contains("GroupsSignInView(isForInvitation: !(pendingGroupsJoinZone ?? \"\").isEmpty)"))
        let view = try fuente("Yala/App/Views/Groups/GroupsSignInView.swift")
        #expect(view.contains("isForInvitation ? L10n.Groups.SignIn.body : L10n.Groups.SignIn.bodyNoInvite"))
    }

    /// La tarjeta de la demo cuenta los miembros de la demo, no un número suelto.
    @Test func onboardingDemoCard_usesTheDemoMemberCount() throws {
        let src = try fuente("Yala/App/Views/Groups/Onboarding/OnboardingDemoGroupCard.swift")
        #expect(src.contains("L10n.Groups.Member.activeCount(GroupsOnboardingDemo.memberCount)"))
    }
}
