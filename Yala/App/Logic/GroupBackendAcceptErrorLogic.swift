//
//  GroupBackendAcceptErrorLogic.swift
//  Yala
//
//  Pure decision logic para el fallo del join backend (`GroupBackendMembershipService.join`),
//  molde de `GroupAcceptShareErrorLogic` (canal CloudKit). Clasifica un `GroupsRPCError` en QUÉ
//  mostrarle al usuario y, crucialmente, si el fallo es PERMANENTE (limpia intent + canario) o
//  reintenta el reconciler (transient/sessionRequired conservan el intent).
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
        /// Cualquier otro (badInput, permanentRejected, decoding, invalidGroupID, …).
        case generic
    }

    static func classify(_ error: GroupsRPCError) -> ErrorKind {
        switch error {
        case .invalidInvite:    return .invalidInvite
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
        case .invalidInvite, .notAuthorized, .generic:
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
