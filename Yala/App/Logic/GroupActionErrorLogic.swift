//
//  GroupActionErrorLogic.swift
//  Yala
//
//  Qué texto ve el usuario cuando falla CREAR un grupo o una acción de admin sobre un miembro
//  (aprobar, rechazar, expulsar, cambiar de rol).
//
//  POR QUÉ EXISTE. Esas cinco superficies pintaban `error.localizedDescription` directo en su alerta.
//  `GroupsRPCError` no conforma `LocalizedError`, así que Foundation fabricaba «No se ha podido completar
//  la operación. (Error de Yala.GroupsRPCError 1.)» en el uso normal sin conexión, y `GroupServiceError`
//  devuelve textos de desarrollo en inglés («GroupService: …»). Ticket
//  `groups-create-approve-remove-show-a-raw-rpc-error`, opción A: se reutilizan textos que ya existen.
//
//  Molde: `GroupLeaveErrorLogic`, su gemelo de salir de un grupo. Este tipo NO devuelve copy, solo el
//  `Kind`; el texto lo elige la extensión de abajo, que es `@MainActor` por `L10n`.
//

import Foundation

nonisolated enum GroupActionErrorLogic {

    enum Kind: Equatable {
        /// La sesión no sirve (`GroupsRPCError.sessionExpired`). Copy `groups.errors.sessionExpired`.
        case sessionExpired
        /// El canal de grupos está apagado de nuestro lado (`channelDisabled`, el kill-switch). Pasajero y sin
        /// escrituras: el RPC se rechazó entero. Copy `welcome.groups.channelOffBody`, el mismo que ya enseña
        /// el formulario cuando el flag local dice OFF.
        case channelOff
        /// Este teléfono lleva más de un día sin conseguir App Attest y el 401 `yala_attest_required` llega con la
        /// racha terminal (`GroupsAttestStreakStore.isTerminal`). «Vuelve a intentarlo» dejaría de ser verdad.
        /// Copy `groups.errors.attestUnavailable`.
        case deviceCannotSyncGroups
        /// La cuenta del usuario sigue pendiente de aprobación en ese grupo (`GroupServiceError
        /// .currentUserPendingApproval`). Copy `groups.errors.pendingApproval`.
        case pendingApproval
        /// Cualquier otro, incluido lo pasajero (red, 5xx). Copy `groups.errors.actionFailed`, que pide
        /// volver a intentarlo.
        case generic
    }

    /// - Parameter attestUnavailable: `GroupsAttestStreakStore.isTerminal()`. Sin valor por defecto, para que
    ///   cada llamada se pronuncie. Solo cambia algo con `.transient(status: 401)`.
    static func classify(_ error: Error, attestUnavailable: Bool) -> Kind {
        if let rpc = error as? GroupsRPCError {
            switch rpc {
            case .sessionExpired:
                return .sessionExpired
            case .channelDisabled:
                return .channelOff
            case .transient(let status):
                return status == 401 && attestUnavailable ? .deviceCannotSyncGroups : .generic
            case .notAuthorized, .invalidInvite, .groupDeleted, .groupArchived, .badInput, .groupExists,
                 .invalidGroupID, .memberNotFound, .cannotRemoveOwner, .ownerCannotLeave, .permanentRejected,
                 .decoding:
                return .generic
            }
        }
        if let service = error as? GroupServiceError {
            switch service {
            case .currentUserPendingApproval:
                return .pendingApproval
            case .noContext, .emptyName, .emptyMemberName, .invalidRole, .notOwner, .adminRequired,
                 .ownerCannotLeave, .lastAdmin, .inactiveMember, .memberNotInGroup, .cannotRemoveSelf,
                 .ownerMemberImmutable, .currentUserMemberNotFound, .notPendingApproval, .outstandingBalance,
                 .missingMemberKey, .backendActionUnavailable, .movedToBackend, .saveFailed:
                return .generic
            }
        }
        return .generic
    }

    // MARK: - Crear el enlace de invitación

    /// Por qué no salió el enlace de invitación. Ticket `invite-link-creation-blames-the-connection-for-any-rpc-failure`:
    /// las dos superficies que lo acuñan (`GroupMembersView`, `GroupDetailViewModel`) decían «revisa tu conexión» para
    /// CUALQUIER fallo del RPC, también con la conexión buena y la sesión caducada.
    enum InviteKind: Equatable {
        /// La sesión no sirve. Copy `groups.errors.sessionExpired`.
        case sessionExpired
        /// Racha de App Attest terminal. Copy `groups.errors.attestUnavailable`.
        case deviceCannotSyncGroups
        /// La petición no salió del teléfono (`transient(status: -1)`: transporte, o el token que no se renovó sin
        /// red). Es el único caso en que «revisa tu conexión» es verdad. Copy `groups.errors.inviteFailed`.
        case noConnection
        /// Salió y el servidor no la atendió: 5xx, el canal apagado, una respuesta que no se entiende o un rechazo.
        /// Copy `groups.errors.inviteChannelOff` («en este momento… en un rato»), que no culpa a nadie.
        case unavailable
    }

    static func classifyInviteFailure(_ error: Error, attestUnavailable: Bool) -> InviteKind {
        guard let rpc = error as? GroupsRPCError else { return .unavailable }
        switch rpc {
        case .sessionExpired:
            return .sessionExpired
        case .transient(let status):
            if status == -1 { return .noConnection }
            return status == 401 && attestUnavailable ? .deviceCannotSyncGroups : .unavailable
        case .channelDisabled, .notAuthorized, .invalidInvite, .groupDeleted, .groupArchived, .badInput,
             .groupExists, .invalidGroupID, .memberNotFound, .cannotRemoveOwner, .ownerCannotLeave,
             .permanentRejected, .decoding:
            return .unavailable
        }
    }
}

// MARK: - Presentación

extension GroupActionErrorLogic.Kind {
    var localizedMessage: String {
        switch self {
        case .sessionExpired:         return L10n.Groups.Errors.sessionExpired
        case .channelOff:             return L10n.Welcome.Groups.channelOffBody
        case .deviceCannotSyncGroups: return L10n.Groups.Errors.attestUnavailable
        case .pendingApproval:        return L10n.Groups.Errors.pendingApproval
        case .generic:                return L10n.Groups.Errors.actionFailed
        }
    }
}

extension GroupActionErrorLogic.InviteKind {
    var localizedMessage: String {
        switch self {
        case .sessionExpired:         return L10n.Groups.Errors.sessionExpired
        case .deviceCannotSyncGroups: return L10n.Groups.Errors.attestUnavailable
        case .noConnection:           return L10n.Groups.Errors.inviteFailed
        case .unavailable:            return L10n.Groups.Errors.inviteChannelOff
        }
    }
}

extension GroupActionErrorLogic {
    /// El texto de la alerta para `error`, leyendo la racha de App Attest en el momento.
    @MainActor
    static func message(for error: Error) -> String {
        classify(error, attestUnavailable: GroupsAttestStreakStore.isTerminal()).localizedMessage
    }

    /// El texto de la alerta cuando falla crear el enlace de invitación.
    @MainActor
    static func inviteMessage(for error: Error) -> String {
        classifyInviteFailure(error, attestUnavailable: GroupsAttestStreakStore.isTerminal()).localizedMessage
    }
}
