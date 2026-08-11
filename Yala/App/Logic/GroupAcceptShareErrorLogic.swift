//
//  GroupAcceptShareErrorLogic.swift
//  Yala
//
//  Pure decision logic para el error de `SplitSyncManager.acceptShare` (paquete de
//  endurecimiento Grupos-v1, decisión 2026-07-13). Clasifica el fallo para elegir
//  QUÉ mostrarle al usuario — y, crucialmente, cuándo NO mostrar nada:
//
//  - `container == nil` en sesión SECUNDARIA (M1): estado PERMANENTE — el engine de
//    Grupos jamás arranca ahí (está atado al Apple ID del OS, que es del DUEÑO) y no
//    hay retry posible. Única salida container-nil que ALERTA.
//  - `container == nil` fuera de secundaria: ventana TRANSITORIA legítima (invite en
//    cold launch antes de `initialize()`); `PendingInviteStore` + la re-emisión en
//    boot lo reintentan con éxito — alertar aquí sería un error espurio sobre algo
//    que va a funcionar. Se mantiene el silencio vigente (log + telemetría).
//  - `CKError.notAuthenticated`: el device no tiene sesión de iCloud — copy claro
//    "necesitas iCloud" en vez del genérico de sync.
//
//  Patrón GroupsDomainAdoptionLogic: sin SwiftData ni UI, tabla completa en
//  GroupAcceptShareErrorLogicTests.
//

import CloudKit
import Foundation

nonisolated enum GroupAcceptShareErrorLogic {

    enum ErrorKind: Equatable {
        /// Sesión secundaria M1: alertar con copy propio (permanente, sin retry).
        case secondarySession
        /// Container nil fuera de secundaria: NO alertar (transitorio, retry en boot).
        case containerUnavailable
        /// Sin cuenta iCloud: alertar con copy "necesitas iCloud".
        case noICloudAccount
        /// Cualquier otro fallo de `container.accept`: copy genérico vigente.
        case generic
    }

    static func classify(
        containerAvailable: Bool,
        isSecondarySession: Bool,
        ckErrorCode: CKError.Code?
    ) -> ErrorKind {
        guard containerAvailable else {
            return isSecondarySession ? .secondarySession : .containerUnavailable
        }
        if ckErrorCode == .notAuthenticated { return .noICloudAccount }
        return .generic
    }
}
