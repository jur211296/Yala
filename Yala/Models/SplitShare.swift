//
//  SplitShare.swift
//  Yala
//
//  Porción de cada miembro en un gasto compartido.
//  Vinculado a SplitExpense via expenseID y a SplitMember via memberID.
//

import Foundation
import SwiftData

@Model
final class SplitShare {
    var id: UUID = UUID()
    var expenseID: UUID = UUID()
    var memberID: String = ""
    var amount: Double = 0
    var isPaid: Bool = false

    init(
        expenseID: UUID = UUID(),
        memberID: String = "",
        amount: Double = 0,
        isPaid: Bool = false
    ) {
        self.id = UUID()
        self.expenseID = expenseID
        self.memberID = memberID
        self.amount = amount
        self.isPaid = isPaid
    }
}
