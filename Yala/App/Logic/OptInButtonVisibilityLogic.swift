//
//  OptInButtonVisibilityLogic.swift
//  Yala
//
//  Pure-logic: decide si mostrar el botón "Crear movimiento personal" en la vista
//  de detalle/edición de un expense de grupo (D1 recovery del opt-out).
//
//  Caso de uso: user dijo "No" al alert opt-in (F2c) y luego cambia de idea, o
//  bridge effective OFF persistente y user quiere recuperar TX real bajo demanda.
//

import Foundation

enum OptInButtonVisibilityLogic {

    /// Devuelve `true` si el botón "Crear movimiento personal" debe ser visible.
    /// - Parameters:
    ///   - isCurrentUserPayer: `true` si el current user es el `paidByMemberID` del expense.
    ///   - hasRealBridgedTransaction: `true` si ya existe una `TransactionItem` en cuenta
    ///     personal real (no sistema) con `splitExpenseID` ligado a este expense.
    static func shouldShow(isCurrentUserPayer: Bool, hasRealBridgedTransaction: Bool) -> Bool {
        // Solo aparece para el payer (Caso A). Y solo si NO existe ya la TX real.
        isCurrentUserPayer && !hasRealBridgedTransaction
    }
}
