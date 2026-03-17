//
//  CashFlowOverride.swift
//  Yala
//
//  SwiftData model for month-specific overrides in a cash flow line.
//

import Foundation
import SwiftData

// MARK: - CashFlowOverride

@Model
final class CashFlowOverride {
    var id: UUID = UUID()
    var monthKey: String = ""        // "2026-04"
    var amount: Double = 0
    var note: String = ""

    var line: CashFlowLine?          // Inverse side

    init(monthKey: String, amount: Double, note: String = "") {
        self.monthKey = monthKey
        self.amount = amount
        self.note = note
    }
}
