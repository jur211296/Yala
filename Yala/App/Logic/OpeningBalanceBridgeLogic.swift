//
//  OpeningBalanceBridgeLogic.swift
//  Yala
//
//  Pure-logic helper que decide qué TX virtual genera el bridge para un saldo
//  inicial (deuda de apertura). Testeable sin SwiftData/ModelContext.
//
//  El bridge real (`GroupTransactionBridge.bridgeOpeningBalance`) consume este plan.
//  Un saldo inicial es SIEMPRE virtual-only (nunca toca cuenta real): refleja una
//  deuda heredada de otra app, no un movimiento de dinero de hoy.
//

import Foundation

enum OpeningBalanceBridgeLogic {

    /// Rol de la subcategoría sistema según el lado de la arista.
    enum Role: Equatable {
        /// Soy el acreedor (me deben) → income, "Saldo inicial (me deben)".
        case owed
        /// Soy el deudor (debo) → expense, "Saldo inicial (debo)".
        case debt
    }

    /// La TX virtual a crear para el current user en este saldo inicial.
    struct Plan: Equatable {
        /// Monto firmado de la TX virtual (+ acreedor / − deudor).
        let txAmount: Double
        let role: Role
    }

    private static let epsilon = 0.0001

    /// Decide la TX virtual del current user dado su rol en la arista.
    /// - Parameters:
    ///   - isCreditor: el current user es el `paidByMemberID` (acreedor) del saldo inicial.
    ///   - myShare: la cuota del current user en el saldo inicial (0 si no tiene share).
    ///   - amount: el monto total de la arista (= lo que se le debe al acreedor).
    /// - Returns: el plan de TX virtual, o `nil` si el current user no está involucrado.
    static func plan(isCreditor: Bool, myShare: Double, amount: Double) -> Plan? {
        if isCreditor {
            guard amount > epsilon else { return nil }
            return Plan(txAmount: amount, role: .owed)
        }
        guard myShare > epsilon else { return nil }
        return Plan(txAmount: -myShare, role: .debt)
    }
}
