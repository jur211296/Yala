//
//  GroupBackendAcceptErrorLogic.swift
//  Yala
//
//  Pure decision logic para el fallo del join backend (`GroupBackendMembershipService.join`). Clasifica un
//  `GroupsRPCError` en QUÉ mostrarle al usuario y, crucialmente, si el fallo es PERMANENTE (limpia intent +
//  canario) o reintenta el reconciler (transient/sessionRequired conservan el intent).
//
//  Nació como molde de `GroupAcceptShareErrorLogic`, su gemelo del canal CloudKit, **borrado en el chip M3
//  (2026-08-12)**: la superficie que clasificaba —`CKShareEntryHandler` y el `container.accept`— murió con
//  la Fase 3, y con ella sus tres copys (`groups.sync.errorAcceptShare*`). Este tipo se quedó SIN gemelo,
//  no sin razón de ser: es el único vivo, y por eso ya no tiene caso de sesión secundaria —un join en
//  secundaria hoy es una FEATURE (la invitada se une a SU grupo con SU identidad), no un bug.
//
//  Contrato C4 (G4-invites). Sin SwiftData ni UI — tabla completa en
//  GroupBackendAcceptErrorLogicTests. DARK: nadie lo invoca con `groupsBackendEnabled` OFF.
//

import Foundation

nonisolated enum GroupBackendAcceptErrorLogic {

    enum ErrorKind: Equatable {
        /// Token inválido/expirado/revocado/agotado → copy `groups.invite.linkInvalid*`.
        case invalidInvite
        /// Sesión expirada / ausente → re-presentar sign-in; el reconciler reintenta al volver.
        case sessionRequired
        /// El backend rechazó por permisos (`yala_not_authorized`).
        case notAuthorized
        /// Offline / 5xx / transporte → NO alerta permanente; el reconciler reintenta.
        case transient
        /// El KILL-SWITCH server-side apagó el canal (403 `yala_groups_disabled`). NO es permanente: el
        /// enlace es bueno y el canal se levantará sin que el usuario haga nada, así que el intent se
        /// CONSERVA y el reconciler reintenta — pero, al revés que `.transient`, sí se le dice al usuario
        /// (con `groups.invite.channelUnavailable`, el mismo copy y el mismo canario que el camino en que
        /// el flag local ya está OFF: es el MISMO estado del mundo visto por el otro lado).
        case channelDisabled
        /// El token era válido pero el grupo ya no existe (`yala_group_deleted`, g13_03). Permanente,
        /// como `.invalidInvite`, pero con su propio mensaje: aquí el consejo de «pide otro enlace» no
        /// solo es inútil, es imposible de seguir.
        case groupDeleted
        /// Cualquier otro (badInput, permanentRejected, decoding, invalidGroupID, …).
        case generic
    }

    static func classify(_ error: GroupsRPCError) -> ErrorKind {
        switch error {
        case .invalidInvite:    return .invalidInvite
        case .groupDeleted:     return .groupDeleted
        case .sessionExpired:   return .sessionRequired
        case .notAuthorized:    return .notAuthorized
        case .transient:        return .transient
        case .channelDisabled:  return .channelDisabled
        case .badInput, .groupExists, .invalidGroupID, .memberNotFound,
             .cannotRemoveOwner, .ownerCannotLeave, .permanentRejected, .decoding:
            return .generic
        }
    }

    /// `true` para fallos PERMANENTES (limpian el intent + emiten el canario `groupJoinFailed`).
    /// `sessionRequired`/`transient` NO son permanentes: el reconciler reintenta y conserva el intent.
    static func isPermanent(_ kind: ErrorKind) -> Bool {
        switch kind {
        case .invalidInvite, .groupDeleted, .notAuthorized, .generic:
            return true
        case .sessionRequired, .transient, .channelDisabled:
            // `channelDisabled` NO es permanente A PROPÓSITO: limpiar el intent aquí quemaría la
            // invitación del usuario por una decisión de configuración que se revierte con un deploy, y
            // le obligaría a pedir un enlace nuevo que tampoco haría falta. Conservarlo es lo que hace
            // que el join se complete solo cuando el canal vuelva.
            return false
        }
    }

    /// Slug estable (sin PII) para el canario `groupJoinFailed`: el kind + el código `yala_*` cuando el
    /// error es un `permanentRejected` (el resto de casos no portan código libre).
    static func slug(for error: GroupsRPCError) -> String {
        switch classify(error) {
        case .invalidInvite:    return "invalidInvite"
        // Slug propio y no `invalidInvite`: en el dashboard, «el grupo ya no existe» y «el enlace no
        // sirve» son incidencias distintas, y colapsarlas escondería cuánta gente llega por un grupo
        // borrado — que es justo lo que este cambio existe para hacer visible.
        case .groupDeleted:     return "groupDeleted"
        case .sessionRequired:  return "sessionRequired"
        case .notAuthorized:    return "notAuthorized"
        case .transient:        return "transient"
        case .channelDisabled:  return "channelDisabled"
        case .generic:
            if case .permanentRejected(let code) = error { return "generic:\(code)" }
            return "generic"
        }
    }
}
