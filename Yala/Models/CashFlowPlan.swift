//
//  CashFlowPlan.swift
//  Yala
//
//  SwiftData model for a cash flow projection plan.
//

import Foundation
import SwiftData

// MARK: - CashFlowPlan

@Model
final class CashFlowPlan {
    var id: UUID = UUID()
    var name: String = ""
    var startingBalance: Double = 0
    var defaultMonthsAhead: Int = 6
    var defaultMonthsBack: Int = 3
    var showOtherExpenses: Bool = true
    var showAccumulatedBalance: Bool = true
    var startingBalanceDate: Date?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \CashFlowLine.plan)
    var lines: [CashFlowLine]?

    init(name: String = "", startingBalance: Double = 0) {
        self.name = name
        self.startingBalance = startingBalance
    }
}
