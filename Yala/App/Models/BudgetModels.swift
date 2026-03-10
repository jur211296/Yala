//
//  BudgetModels.swift
//  Yala
//
//  Budget-related enums and data structures
//

import Foundation
import SwiftData

// MARK: - Budget Period Type

enum BudgetPeriodType: String, CaseIterable, Identifiable {
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    case unique = "unique"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .weekly:
            return NSLocalizedString("budgets.period.weekly", comment: "Weekly budget period")
        case .monthly:
            return NSLocalizedString("budgets.period.monthly", comment: "Monthly budget period")
        case .yearly:
            return NSLocalizedString("budgets.period.yearly", comment: "Yearly budget period")
        case .unique:
            return NSLocalizedString("budgets.period.unique", comment: "One-time budget period")
        }
    }
}

// MARK: - Budget Status

enum BudgetStatus: String, Identifiable {
    case exceeded = "exceeded"
    case active = "active"
    case inactive = "inactive"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .exceeded:
            return NSLocalizedString("budgets.status.exceeded", comment: "Exceeded budgets section")
        case .active:
            return NSLocalizedString("budgets.status.active", comment: "Active budgets section")
        case .inactive:
            return NSLocalizedString("budgets.status.inactive", comment: "Inactive budgets section")
        }
    }

    var sortOrder: Int {
        switch self {
        case .exceeded: return 0
        case .active: return 1
        case .inactive: return 2
        }
    }
}

// MARK: - Budget Summary

struct BudgetSummary: Identifiable {
    let budget: Budget
    let spent: Double
    let percentage: Double
    let daysRemaining: Int
    let status: BudgetStatus
    let icon: String
    let color: String

    var id: PersistentIdentifier {
        budget.persistentModelID
    }
}

// MARK: - Budget Navigation ID

/// Wrapper for budget PersistentIdentifier to avoid conflict with ScheduledPayment's
/// `.navigationDestination(for: PersistentIdentifier.self)` in the shared PlanningView NavigationStack.
struct BudgetNavigationID: Hashable {
    let id: PersistentIdentifier
}

// MARK: - Period Option

struct PeriodOption: Identifiable {
    let date: Date
    let title: String
    let subtitle: String
    let isCurrent: Bool
    var isSelected: Bool = false

    var id: Date { date }
}
