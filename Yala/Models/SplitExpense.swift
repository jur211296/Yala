//
//  SplitExpense.swift
//  Yala
//
//  Cache local de un gasto compartido.
//  Vinculado a SplitGroup via groupZoneID (no @Relationship).
//

import Foundation
import SwiftData

@Model
final class SplitExpense {
    var id: UUID = UUID()
    var groupZoneID: String = ""
    var amount: Double = 0
    var currencyCode: String = "USD"
    var expenseDescription: String = ""    // "description" colisiona con CustomStringConvertible
    var note: String?
    var date: Date = Date.now
    var paidByMemberID: String = ""
    var splitType: String = "equal"        // "equal" | "exact" | "percentage" | "shares"
    var isSettled: Bool = false
    var subcategoryName: String?           // Nombre subcategoría del creador (para matching)
    var createdAt: Date = Date.now

    init(
        groupZoneID: String = "",
        amount: Double = 0,
        currencyCode: String = "USD",
        expenseDescription: String = "",
        note: String? = nil,
        date: Date = Date.now,
        paidByMemberID: String = "",
        splitType: String = "equal",
        subcategoryName: String? = nil
    ) {
        self.id = UUID()
        self.groupZoneID = groupZoneID
        self.amount = amount
        self.currencyCode = currencyCode
        self.expenseDescription = expenseDescription
        self.note = note
        self.date = date
        self.paidByMemberID = paidByMemberID
        self.splitType = splitType
        self.subcategoryName = subcategoryName
        self.createdAt = Date.now
    }
}
