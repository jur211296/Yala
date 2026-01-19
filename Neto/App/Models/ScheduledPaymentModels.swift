//
//  ScheduledPaymentModels.swift
//  Neto
//
//  Scheduled payment related enums and data structures
//

import Foundation
import SwiftData

// MARK: - Recurrence Type

enum RecurrenceType: String, CaseIterable, Identifiable {
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .weekly:
            return NSLocalizedString("scheduled.recurrence.weekly", comment: "Weekly recurrence")
        case .monthly:
            return NSLocalizedString("scheduled.recurrence.monthly", comment: "Monthly recurrence")
        case .yearly:
            return NSLocalizedString("scheduled.recurrence.yearly", comment: "Yearly recurrence")
        }
    }
}

// MARK: - Payment Category

enum PaymentCategory: String, CaseIterable, Identifiable {
    case recurring = "recurring"
    case subscription = "subscription"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .recurring:
            return NSLocalizedString("scheduled.category.recurring", comment: "Recurring payments")
        case .subscription:
            return NSLocalizedString("scheduled.category.subscription", comment: "Subscriptions")
        }
    }

    var iconName: String {
        switch self {
        case .recurring:
            return "arrow.trianglehead.2.clockwise.rotate.90"
        case .subscription:
            return "creditcard.and.123"
        }
    }
}

// MARK: - Due Status

enum DueStatus: String, CaseIterable, Identifiable {
    case past = "past"
    case today = "today"
    case upcoming = "upcoming"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .past:
            return NSLocalizedString("scheduled.status.past", comment: "Past due payments")
        case .today:
            return NSLocalizedString("scheduled.status.today", comment: "Due today")
        case .upcoming:
            return NSLocalizedString("scheduled.status.upcoming", comment: "Upcoming payments")
        }
    }

    var sortOrder: Int {
        switch self {
        case .past: return 0
        case .today: return 1
        case .upcoming: return 2
        }
    }
}

// MARK: - Scheduled Payment Summary

struct ScheduledPaymentSummary: Identifiable {
    let payment: ScheduledPayment
    let dueStatus: DueStatus
    let daysUntilDue: Int
    let icon: String
    let color: String

    var id: PersistentIdentifier {
        payment.persistentModelID
    }
}

// MARK: - Scheduled Payments Tab

enum ScheduledPaymentsTab: Int, CaseIterable, Identifiable {
    case recurring = 0
    case subscriptions = 1
    case all = 2

    var id: Int { rawValue }

    var localizedName: String {
        switch self {
        case .recurring:
            return NSLocalizedString("scheduled.tab.recurring", comment: "Recurring payments tab")
        case .subscriptions:
            return NSLocalizedString("scheduled.tab.subscriptions", comment: "Subscriptions tab")
        case .all:
            return NSLocalizedString("scheduled.tab.all", comment: "All payments tab")
        }
    }

    /// Filter value for paymentCategory (nil = show all)
    var categoryFilter: String? {
        switch self {
        case .recurring:
            return PaymentCategory.recurring.rawValue
        case .subscriptions:
            return PaymentCategory.subscription.rawValue
        case .all:
            return nil
        }
    }
}
