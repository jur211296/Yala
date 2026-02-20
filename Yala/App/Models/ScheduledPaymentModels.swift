//
//  ScheduledPaymentModels.swift
//  Yala
//
//  Scheduled payment related enums and data structures
//

import Foundation
import SwiftData

// MARK: - Recurrence Type

enum RecurrenceType: String, CaseIterable, Identifiable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .daily:
            return NSLocalizedString("scheduled.recurrence.daily", comment: "Daily recurrence")
        case .weekly:
            return NSLocalizedString("scheduled.recurrence.weekly", comment: "Weekly recurrence")
        case .monthly:
            return NSLocalizedString("scheduled.recurrence.monthly", comment: "Monthly recurrence")
        case .yearly:
            return NSLocalizedString("scheduled.recurrence.yearly", comment: "Yearly recurrence")
        }
    }

    /// Singular form for "every 1 day/week/month/year"
    var localizedNameSingular: String {
        switch self {
        case .daily:
            return NSLocalizedString("scheduled.recurrence.day", comment: "Day")
        case .weekly:
            return NSLocalizedString("scheduled.recurrence.week", comment: "Week")
        case .monthly:
            return NSLocalizedString("scheduled.recurrence.month", comment: "Month")
        case .yearly:
            return NSLocalizedString("scheduled.recurrence.year", comment: "Year")
        }
    }

    /// Plural form for "every X days/weeks/months/years"
    var localizedNamePlural: String {
        switch self {
        case .daily:
            return NSLocalizedString("scheduled.recurrence.days", comment: "Days")
        case .weekly:
            return NSLocalizedString("scheduled.recurrence.weeks", comment: "Weeks")
        case .monthly:
            return NSLocalizedString("scheduled.recurrence.months", comment: "Months")
        case .yearly:
            return NSLocalizedString("scheduled.recurrence.years", comment: "Years")
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
    let dueDate: Date
    let dueStatus: DueStatus
    let daysUntilDue: Int
    let icon: String
    let color: String
    /// Whether this payment has been paid for the selected month
    var isPaidForMonth: Bool = false
    /// Whether this occurrence has been skipped by the user
    var isSkippedForMonth: Bool = false

    var id: String {
        "\(payment.persistentModelID)-\(dueDate.timeIntervalSince1970)"
    }
}

// MARK: - Payment Status Filter

enum PaymentStatusFilter: String, CaseIterable, Identifiable {
    case all
    case paid
    case pending

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .all:
            return NSLocalizedString("scheduled.filter.all", comment: "")
        case .paid:
            return NSLocalizedString("scheduled.filter.paid", comment: "")
        case .pending:
            return NSLocalizedString("scheduled.filter.pending", comment: "")
        }
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
