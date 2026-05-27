//
//  BridgeOptOutAlertLogic.swift
//  Yala
//
//  Pure-logic: decide si tras save de un expense/settlement el form debe mostrar
//  el alert "¿También registrar en tu Yala personal?" (opt-in que crea draft Inbox).
//
//  Solo aplica a Caso A (yo pago) y Caso C (yo liquido) cuando bridge effective
//  está OFF. Caso B (otro pagó) y Caso D (me liquidan via sync) NO requieren alert:
//  el primero no involucra TX personal real; el segundo viene de sync remoto (sin form
//  para acoplar alert in-line, manejado por draft auto en Inbox).
//

import Foundation

enum BridgeOptOutAlertLogic {

    /// Casos del bridge que pueden generar TX real en cuenta personal.
    enum BridgeCase: Equatable {
        /// Caso A: current user es payer del expense.
        case caseA
        /// Caso B: otro miembro pagó.
        case caseB
        /// Caso C: current user es el `from` del settlement.
        case caseC
        /// Caso D: current user es el `to` del settlement (entrante via sync).
        case caseD
    }

    /// Devuelve `true` si el form debe mostrar el alert opt-in tras save.
    /// - Parameters:
    ///   - case: caso del bridge para esta operación.
    ///   - bridgeEffectivelyEnabled: resultado del resolver para el grupo.
    static func shouldShowAlert(case bridgeCase: BridgeCase, bridgeEffectivelyEnabled: Bool) -> Bool {
        guard !bridgeEffectivelyEnabled else { return false }
        switch bridgeCase {
        case .caseA, .caseC: return true
        case .caseB, .caseD: return false
        }
    }
}
