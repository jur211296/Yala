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
    ///   - share: el share del current user (nil si no participa).
    ///   - currentMemberID: id del current member (uuidString).
    static func resolve(
        expense: SplitExpense,
        share: SplitShare?,
        currentMemberID: String
    ) -> PersonalShareStatus {
        guard let share else { return .notIncluded }
        if expense.paidByMemberID == currentMemberID {
            return .youAreOwed(amount: expense.amount - share.amount)
        }
        return .youOwe(amount: share.amount)
    }
}
