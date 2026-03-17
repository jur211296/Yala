//
//  CashFlowLine.swift
//  Yala
//
//  SwiftData model for a single line (income/expense) in a cash flow plan.
//

import Foundation
import SwiftData

// MARK: - EstimationMethod

/// Estimation method enum (not persisted — for type safety in code)
enum EstimationMethod: String, CaseIterable {
    case average3m, average6m, average12m
    case lastMonth, manual, trend, custom, scheduled
}

// MARK: - CashFlowLine

@Model
final class CashFlowLine {
    var id: UUID = UUID()
    var name: String = ""
    var isIncome: Bool = false
    var sortOrder: Int = 0
    var isEnabled: Bool = true
    var isExpanded: Bool = false
    var estimationMethod: String = "average6m"
    var manualAmount: Double?
    var customMonthsRaw: String?

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify, inverse: \Category.cashFlowLines)
    var category: Category?

    @Relationship(deleteRule: .nullify, inverse: \ScheduledPayment.cashFlowLines)
    var scheduledPayment: ScheduledPayment?

    var plan: CashFlowPlan?

    @Relationship(deleteRule: .nullify, inverse: \CashFlowOverride.line)
    var overrides: [CashFlowOverride]?

    // MARK: - Computed

    var method: EstimationMethod {
        EstimationMethod(rawValue: estimationMethod) ?? .average6m
    }

    var customMonths: [String] {
        guard let raw = customMonthsRaw, !raw.isEmpty else { return [] }
        return raw.split(separator: ",").map(String.init)
    }

    // MARK: - Init

    init(
        name: String,
        isIncome: Bool = false,
        sortOrder: Int = 0,
        estimationMethod: EstimationMethod = .average6m,
        manualAmount: Double? = nil,
        category: Category? = nil,
        scheduledPayment: ScheduledPayment? = nil
    ) {
        self.name = name
        self.isIncome = isIncome
        self.sortOrder = sortOrder
        self.estimationMethod = estimationMethod.rawValue
        self.manualAmount = manualAmount
        self.category = category
        self.scheduledPayment = scheduledPayment
    }
}
