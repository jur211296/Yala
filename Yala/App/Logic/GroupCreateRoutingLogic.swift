//
//  GroupCreateRoutingLogic.swift
//  Yala
//
//  Pure-logic del routing de CREAR GRUPO (G5-A, contrato C3). Decide si el grupo nuevo nace en el canal
//  CloudKit (camino vigente) o BACKEND (RPC `create_group`), y si antes hay que pedir sign-in / consent.
//  Sin SwiftData/CloudKit/UI — tabla completa en GroupCreateRoutingLogicTests. Con el flag OFF SIEMPRE
//  `.cloudKit` (byte-idéntico al camino actual).
//

import Foundation

nonisolated enum GroupCreateRoutingLogic {

    enum Route: Equatable {
        /// Crear vía CKSyncEngine (camino vigente). Flag OFF SIEMPRE cae aquí.
        case cloudKit
        /// Crear vía `GroupBackendMembershipService.createGroup` (RPC server-first).
        case backend
        /// Flag ON con sesión pero sin consent → presentar el consent de grupos ANTES del form.
        case needsConsent
        /// Flag ON sin sesión → presentar el sign-in solo-grupos ANTES del form.
        case needsSignIn
    }

    /// Precedencia (flag ON): sin sesión → sign-in; con sesión sin consent → consent; listo → backend.
    /// Flag OFF → cloudKit (el gate consent/sign-in NUNCA aplica al camino CloudKit vigente).
    static func route(flagOn: Bool, hasSession: Bool, consentAccepted: Bool) -> Route {
        guard flagOn else { return .cloudKit }
        if !hasSession { return .needsSignIn }
        if !consentAccepted { return .needsConsent }
        return .backend
    }
}
