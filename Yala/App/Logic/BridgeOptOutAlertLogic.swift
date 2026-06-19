//
//  BridgeOptOutAlertLogic.swift
//  Yala
//
//  Pure-logic: decide si tras save de un expense/settlement el form debe mostrar
//  el alert "¿También registrar en tu Yala personal?" (opt-in que crea draft Inbox).
//
//  Solo aplica a Caso A (yo pago) y Caso C (yo liquido) cuando bridge effective
//  está OFF. Caso B (otro pagó) y Caso D (yo recibo) NO requieren alert: el primero
//  no involucra TX personal real; el segundo ya recibe su draft auto en Inbox desde
//  el bridge (creación local o sync), por lo que el alert lo duplicaría.
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

    /// Caso del bridge para un settlement desde la perspectiva del current user.
    /// - Returns: `.caseC` si soy quien paga (`from`), `.caseD` si soy quien recibe
    ///   (`to`), `nil` si no participo (settlement entre otros — no debería ocurrir
    ///   desde el form de liquidación; defensivo).
    static func settlementCase(
        currentUserMemberID: String?,
        fromMemberID: String,
        toMemberID: String
    ) -> BridgeCase? {
        guard let currentUserMemberID else { return nil }
        if currentUserMemberID == fromMemberID { return .caseC }
        if currentUserMemberID == toMemberID { return .caseD }
        return nil
    }
}
