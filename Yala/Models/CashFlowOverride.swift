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
    // I12: identidad de sync del Modo Nube (`sync_id_source = CashFlowOverride.id`).
    // `.preserveValueOnDeletion` para que el history tombstone conserve el `id` (metadata de History;
    // sin deploy .ckdb).
    @Attribute(.preserveValueOnDeletion) var id: UUID = UUID()
    var monthKey: String = ""        // "2026-04"
    var amount: Double = 0
    var note: String = ""

    @Relationship(deleteRule: .nullify)
    var line: CashFlowLine?          // Explicit for CloudKit REFERENCE mapping

    init(monthKey: String, amount: Double, note: String = "") {
        self.monthKey = monthKey
        self.amount = amount
        self.note = note
    }
}
