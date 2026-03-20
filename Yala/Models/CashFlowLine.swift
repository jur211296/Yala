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

    var displayName: String {
        switch self {
        case .average3m: L10n.CashFlowPlan.average3m
        case .average6m: L10n.CashFlowPlan.average6m
        case .average12m: L10n.CashFlowPlan.average12m
        case .lastMonth: L10n.CashFlowPlan.lastMonth
        case .manual: L10n.CashFlowPlan.manual
        case .scheduled: L10n.CashFlowPlan.scheduled
        case .trend: L10n.CashFlowPlan.trend
        case .custom: L10n.CashFlowPlan.custom
        }
    }

    var descriptionText: String {
        switch self {
        case .average3m: L10n.CashFlowPlan.average3mDesc
        case .average6m: L10n.CashFlowPlan.average6mDesc
        case .average12m: L10n.CashFlowPlan.average12mDesc
        case .lastMonth: L10n.CashFlowPlan.lastMonthDesc
        case .manual: L10n.CashFlowPlan.manualDesc
        case .scheduled: L10n.CashFlowPlan.scheduledDesc
        case .trend: L10n.CashFlowPlan.trendDesc
        case .custom: L10n.CashFlowPlan.customDesc
        }
    }
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

    @Relationship(deleteRule: .nullify, inverse: \Subcategory.cashFlowLines)
    var subcategory: Subcategory?

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
        subcategory: Subcategory? = nil,
        scheduledPayment: ScheduledPayment? = nil
    ) {
        self.name = name
        self.isIncome = isIncome
        self.sortOrder = sortOrder
        self.estimationMethod = estimationMethod.rawValue
        self.manualAmount = manualAmount
        self.category = category
        self.subcategory = subcategory
        self.scheduledPayment = scheduledPayment
    }
}
