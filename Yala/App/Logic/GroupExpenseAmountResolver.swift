//
//  GroupExpenseAmountResolver.swift
//  Yala
//
//  Pure-logic resolver para perspectiva personal del current user en un gasto compartido.
//

import Foundation

enum PersonalShareStatus: Equatable {
    /// Yo pagué (el grupo me debe `amount` = totalExpense - miParte).
    case youAreOwed(amount: Double)
    /// Otro pagó y yo participo (yo debo `amount` = miParte del split).
    case youOwe(amount: Double)
    /// No participo en este gasto.
    case notIncluded
}

enum GroupExpenseAmountResolver {

    /// Resuelve la perspectiva personal del current user en un expense.
    ///
    /// - Parameters:
    ///   - expense: el gasto compartido.
    ///   - share: el share del current user. `nil` cuando no tiene parte asignada — para un
    ///     NO-pagador significa que no participa; para el pagador significa que prestó el total.
    ///   - currentMemberID: id del current member (uuidString).
    static func resolve(
        expense: SplitExpense,
        share: SplitShare?,
        currentMemberID: String
    ) -> PersonalShareStatus {
        // El pagador SIEMPRE participa (modelo Splitwise), tenga o no `SplitShare` propio:
        // pagar algo cuya parte propia es 0 (otro lo devuelve todo) = prestar el total. Por eso
        // se evalúa el pagador ANTES del guard de `share`.
        if expense.paidByMemberID == currentMemberID {
            return .youAreOwed(amount: expense.amount - (share?.amount ?? 0))
        }
        // No-pagador sin share: no participa en el gasto.
        guard let share else { return .notIncluded }
        return .youOwe(amount: share.amount)
    }
}
