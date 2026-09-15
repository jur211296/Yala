//
//  GroupLeaveErrorLogic.swift
//  Yala
//
//  Pure decision logic para el fallo de SALIR DE UN GRUPO. Clasifica el error en QUÉ se le enseña al
//  usuario y si la respuesta del servidor revela algo que el device tenía mal.
//
//  POR QUÉ EXISTE. Las dos superficies de salida (`GroupSettingsView`, `GroupsContainerView`) pintaban
//  `error.localizedDescription` directo en el alert. `GroupsRPCError` no conforma `LocalizedError`, así
//  que Foundation fabricaba «No se ha podido completar la operación. (Error de Yala.GroupsRPCError 10.)»
//  — un número de discriminante. Y por el otro camino, `GroupServiceError` sí conforma pero devuelve
//  dev-strings en inglés («GroupService: Owner cannot leave their own group»): el usuario acababa viendo
//  texto técnico en los dos casos.
//
//  Molde: `GroupBackendAcceptErrorLogic`, su gemelo del join. Mismo contrato — este tipo NO devuelve
//  copy, solo el `Kind`; el string lo elige la vista. Sin SwiftData ni UI; tabla completa en
//  `GroupLeaveErrorLogicTests`.
//

import Foundation

nonisolated enum GroupLeaveErrorLogic {

    enum Kind: Equatable {
        /// El grupo es del usuario a ojos del SERVIDOR (`yala_owner_cannot_leave`) o del guard local.
        /// Salir es imposible por diseño y reintentar no sirve: la salida que le queda es eliminar el
        /// grupo. Copy `groups.errors.ownerCannotLeave`.
        case ownedByCurrentUser
        /// Sesión expirada o ausente. El usuario SÍ tiene algo que hacer —volver a iniciar sesión—, y
        /// por eso no se mezcla con `.retryLater`. Copy `groups.errors.sessionExpired`.
        case sessionExpired
        /// Transitorio: red, 5xx, el KILL-SWITCH del canal o, desde el 2026-09-15, App Attest ausente (401
        /// `yala_attest_required`). No es culpa del usuario y el estado suele arreglarse solo, así que el copy
        /// pide volver a intentarlo en un momento — el mismo criterio que ya se tomó para `channelDisabled` en el
        /// enlace de invitación (`groups.invite.channelUnavailable`). Un teléfono que no recupera nunca el attest
        /// no se arregla solo: `groups-phone-that-never-attests-is-told-to-retry-forever`.
        /// Copy `groups.errors.leaveUnavailable`.
        case retryLater
        /// Cualquier otro. Copy `groups.errors.actionFailed`.
        case generic
    }

    static func classify(_ error: Error) -> Kind {
        if let rpc = error as? GroupsRPCError {
            switch rpc {
            case .ownerCannotLeave:
                return .ownedByCurrentUser
            case .sessionExpired:
                return .sessionExpired
            case .transient, .channelDisabled:
                return .retryLater
            // `.groupArchived` cae aquí a propósito: `leave_group` no lo devuelve (el gate de g13_05 vive
            // solo en `join_group`), así que es inalcanzable por este camino. Está en la lista por
            // exhaustividad del switch, no porque tenga un mensaje propio que dar al salir de un grupo.
            case .notAuthorized, .invalidInvite, .groupDeleted, .groupArchived, .badInput, .groupExists,
                 .invalidGroupID, .memberNotFound, .cannotRemoveOwner, .permanentRejected, .decoding:
                return .generic
            }
        }
        if let service = error as? GroupServiceError {
            switch service {
            case .ownerCannotLeave:
                // El guard local de `GroupService.leaveGroup` (`isOwner == true`). El usuario ve lo
                // MISMO que si lo hubiera dicho el servidor, que es lo correcto: para él es el mismo
                // hecho, y de dónde salió la afirmación es cosa nuestra.
                return .ownedByCurrentUser
            case .noContext, .emptyName, .emptyMemberName, .invalidRole, .notOwner, .adminRequired,
                 .lastAdmin, .inactiveMember, .memberNotInGroup, .cannotRemoveSelf,
                 .ownerMemberImmutable, .currentUserMemberNotFound, .notPendingApproval,
                 .currentUserPendingApproval, .outstandingBalance, .missingMemberKey,
                 .backendActionUnavailable, .movedToBackend, .saveFailed:
                return .generic
            }
        }
        return .generic
    }
}

// MARK: - Presentación

/// El copy vive aquí y no en cada vista porque las DOS superficies de salida —`GroupSettingsView`
/// (ajustes del grupo) y `GroupsContainerView` (salir de un grupo rechazado desde la lista)— enseñan
/// el mismo alert por el mismo error. Con un switch en cada una, la próxima persona que añada un caso
/// lo añade en una y no en la otra, que es justo como una de ellas se quedó pintando el error crudo.
///
/// Deliberadamente FUERA del `nonisolated enum` de arriba: `L10n` resuelve el bundle del idioma en
/// curso y es `@MainActor`, mientras que `classify` debe seguir siendo pura y testeable sin actor.
extension GroupLeaveErrorLogic.Kind {
    var localizedMessage: String {
        switch self {
        case .ownedByCurrentUser: return L10n.Groups.Errors.ownerCannotLeave
        case .sessionExpired:     return L10n.Groups.Errors.sessionExpired
        case .retryLater:         return L10n.Groups.Errors.leaveUnavailable
        case .generic:            return L10n.Groups.Errors.actionFailed
        }
    }
}
