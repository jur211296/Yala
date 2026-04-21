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
        case .daily: return L10n.Scheduled.Recurrence.daily
        case .weekly: return L10n.Scheduled.Recurrence.weekly
        case .monthly: return L10n.Scheduled.Recurrence.monthly
        case .yearly: return L10n.Scheduled.Recurrence.yearly
        }
    }

    /// Singular form for "every 1 day/week/month/year"
    var localizedNameSingular: String {
        switch self {
        case .daily: return L10n.Scheduled.Recurrence.day
        case .weekly: return L10n.Scheduled.Recurrence.week
        case .monthly: return L10n.Scheduled.Recurrence.month
        case .yearly: return L10n.Scheduled.Recurrence.year
        }
    }

    /// Plural form for "every X days/weeks/months/years"
    var localizedNamePlural: String {
        switch self {
        case .daily: return L10n.Scheduled.Recurrence.days
        case .weekly: return L10n.Scheduled.Recurrence.weeks
        case .monthly: return L10n.Scheduled.Recurrence.months
        case .yearly: return L10n.Scheduled.Recurrence.years
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
        case .recurring: return L10n.Scheduled.Category.recurring
        case .subscription: return L10n.Scheduled.Category.subscription
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
        case .past: return L10n.Scheduled.Status.past
        case .today: return L10n.Scheduled.Status.today
        case .upcoming: return L10n.Scheduled.Status.upcoming
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
    /// Real paid amount from linked transaction (nil = use payment.amount)
    var paidAmount: Double? = nil
    /// Currency of the real paid amount (nil = use payment.currencyCode)
    var paidCurrencyCode: String? = nil

    /// Amount to display: real paid amount if available, otherwise scheduled amount
    var displayAmount: Double {
        paidAmount ?? payment.amount
    }

    /// Currency for display amount
    var displayCurrencyCode: String {
        paidCurrencyCode ?? payment.currencyCode
    }

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
        case .all: return L10n.Scheduled.Filter.all
        case .paid: return L10n.Scheduled.Filter.paid
        case .pending: return L10n.Scheduled.Filter.pending
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
        case .recurring: return L10n.Scheduled.Tab.recurring
        case .subscriptions: return L10n.Scheduled.Tab.subscriptions
        case .all: return L10n.Scheduled.Tab.all
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
