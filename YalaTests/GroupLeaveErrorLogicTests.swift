//
//  GroupLeaveErrorLogicTests.swift
//  YalaTests
//
//  Tabla completa de `GroupLeaveErrorLogic`: los 14 casos de `GroupsRPCError` + los 20 de
//  `GroupServiceError` → 4 `Kind`. El cableado de las dos superficies lo fija `GroupLeaveSurfacesWiringTests`.
//

import Foundation
import Testing

@testable import Yala

struct GroupLeaveErrorLogicTests {

    typealias L = GroupLeaveErrorLogic

    // MARK: - GroupsRPCError (los 14 casos)

    @Test func classify_rpc_allFourteenCases() {
        // El caso protagonista del device-QA 2026-08-28: el servidor rechaza la salida porque el
        // usuario es el dueño server-side. No es transitorio y reintentar no sirve nunca.
        #expect(L.classify(GroupsRPCError.ownerCannotLeave, attestUnavailable: false) == .ownedByCurrentUser)

        #expect(L.classify(GroupsRPCError.sessionExpired, attestUnavailable: false) == .sessionExpired)

        // Transitorios: red/5xx y el kill-switch del canal comparten kind porque comparten consejo
        // («vuelve en un rato») y ninguno es culpa del usuario. Mismo criterio que ya se tomó para
        // `channelDisabled` en el enlace de invitación.
        #expect(L.classify(GroupsRPCError.transient(status: 503), attestUnavailable: false) == .retryLater)
        #expect(L.classify(GroupsRPCError.transient(status: -1), attestUnavailable: false) == .retryLater)
        #expect(L.classify(GroupsRPCError.channelDisabled, attestUnavailable: false) == .retryLater)

        // Resto → generic.
        #expect(L.classify(GroupsRPCError.notAuthorized, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupsRPCError.invalidInvite, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupsRPCError.groupDeleted, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupsRPCError.badInput, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupsRPCError.groupExists, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupsRPCError.invalidGroupID, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupsRPCError.memberNotFound, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupsRPCError.cannotRemoveOwner, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupsRPCError.permanentRejected(code: "yala_desconocido"), attestUnavailable: false) == .generic)
        #expect(L.classify(GroupsRPCError.decoding, attestUnavailable: false) == .generic)
    }

    // MARK: - GroupServiceError

    /// El guard LOCAL (`isOwner == true`) tiene que contar la misma historia que el rechazo del
    /// servidor: para el usuario es el mismo hecho, y de dónde salió la afirmación es cosa nuestra.
    @Test func classify_serviceOwnerCannotLeave_matchesServerVerdict() {
        #expect(L.classify(GroupServiceError.ownerCannotLeave, attestUnavailable: false) == .ownedByCurrentUser)
        #expect(L.classify(GroupServiceError.ownerCannotLeave, attestUnavailable: false) == L.classify(GroupsRPCError.ownerCannotLeave, attestUnavailable: false))
    }

    /// Los que `leaveGroup` puede lanzar por el camino local, y una muestra del resto. Ninguno debe
    /// llegar al usuario como dev-string en inglés: todos caen a copy genérico honesto.
    @Test func classify_serviceOtherCases_areGeneric() {
        #expect(L.classify(GroupServiceError.noContext, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupServiceError.saveFailed(GroupServiceError.noContext), attestUnavailable: false) == .generic)
        #expect(L.classify(GroupServiceError.currentUserMemberNotFound, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupServiceError.outstandingBalance, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupServiceError.movedToBackend, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupServiceError.notOwner, attestUnavailable: false) == .generic)
        #expect(L.classify(GroupServiceError.backendActionUnavailable, attestUnavailable: false) == .generic)
    }

    /// Un error de fuera de las dos familias (p. ej. el `saveFailed` de SwiftData ya desenvuelto, o
    /// cualquier `NSError` de transporte) NO puede tumbar la clasificación.
    @Test func classify_unknownError_isGeneric() {
        struct Cualquiera: Error {}
        #expect(L.classify(Cualquiera(), attestUnavailable: false) == .generic)
        #expect(L.classify(NSError(domain: "test", code: 42), attestUnavailable: false) == .generic)
    }

    // MARK: - El teléfono sin App Attest (2026-09-15)

    /// **Solo el 401 del attest ausente cambia, y solo con la racha terminal.** `.transient(status: 401)` sale únicamente
    /// de `yala_attest_required` en la membresía (`GroupsMembershipClient.call`); un 503, un corte de red o el kill del
    /// canal siguen siendo «vuelve a intentarlo en un momento», haya racha o no. Ticket
    /// `groups-phone-that-never-attests-is-told-to-retry-forever`.
    @Test func classify_attestUnavailable_onlyChangesTheAttest401() {
        #expect(L.classify(GroupsRPCError.transient(status: 401), attestUnavailable: true) == .deviceCannotSyncGroups)
        #expect(L.classify(GroupsRPCError.transient(status: 401), attestUnavailable: false) == .retryLater)
        #expect(L.classify(GroupsRPCError.transient(status: 503), attestUnavailable: true) == .retryLater)
        #expect(L.classify(GroupsRPCError.transient(status: -1), attestUnavailable: true) == .retryLater)
        #expect(L.classify(GroupsRPCError.channelDisabled, attestUnavailable: true) == .retryLater)
        #expect(L.classify(GroupsRPCError.sessionExpired, attestUnavailable: true) == .sessionExpired)
        #expect(L.classify(GroupsRPCError.ownerCannotLeave, attestUnavailable: true) == .ownedByCurrentUser)
        #expect(L.classify(GroupServiceError.noContext, attestUnavailable: true) == .generic)
    }

    /// Y dice lo suyo: «vuelve a intentarlo en un momento» dejó de ser verdad para ese teléfono.
    @MainActor
    @Test func deviceCannotSyncGroups_hasItsOwnMessage() {
        #expect(L.Kind.deviceCannotSyncGroups.localizedMessage == L10n.Groups.Errors.leaveAttestUnavailable)
        #expect(L.Kind.deviceCannotSyncGroups.localizedMessage != L.Kind.retryLater.localizedMessage)
    }
}
