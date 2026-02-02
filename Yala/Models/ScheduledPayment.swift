//
//  ScheduledPayment.swift
//  Yala
//
//  SwiftData model for scheduled/recurring payments (reminders).
//

import Foundation
import SwiftData

// MARK: - ScheduledPayment

/// Scheduled payment that serves as a reminder for recurring expenses or income
@Model
final class ScheduledPayment {
    // MARK: - Identification

    /// Unique identifier (stable across sessions)
    var id: UUID = UUID()

    /// Display name for the scheduled payment (required) - CloudKit: default required
    var name: String = ""

    /// Optional description/note
    var note: String?

    // MARK: - Amount & Currency (CloudKit: defaults required)

    /// Payment amount (required)
    var amount: Double = 0

    /// Currency code (ISO 4217)
    var currencyCode: String = "USD"

    // MARK: - Type (income/expense) (CloudKit: default required)

    /// Transaction type: "income" or "expense"
    var transactionType: String = "expense"

    // MARK: - Classification

    /// Linked account (required for context)
    @Relationship(inverse: \Account.scheduledPayments)
    var account: Account?

    /// Linked subcategory for categorization
    @Relationship(inverse: \Subcategory.scheduledPayments)
    var subcategory: Subcategory?

    /// Linked tags (many-to-many) - CloudKit: must be optional
    @Relationship(inverse: \Tag.scheduledPayments)
    var tags: [Tag]?

    /// Optional nature override (nil = use subcategory's nature)
    var natureOverride: String?

    // MARK: - Recurrence (CloudKit: defaults required)

    /// Whether this is a recurring payment (false = one-time)
    var isRecurring: Bool = true

    /// Recurrence type: "daily", "weekly", "monthly", "yearly" (only if isRecurring)
    var recurrenceType: String = "monthly"

    /// Recurrence interval: "every X days/weeks/months/years" (default 1)
    var recurrenceInterval: Int = 1

    /// Payment date (for one-time) or next due date (for recurring)
    var nextDueDate: Date = Date()

    /// Day of month for monthly recurrence (1-31)
    var dayOfMonth: Int?

    /// Selected weekdays for weekly recurrence (comma-separated: "1,3,5" = Sun,Tue,Thu)
    var selectedWeekdays: String?

    /// Yearly payment date (month and day)
    var yearlyMonth: Int?
    var yearlyDay: Int?

    /// Optional end date for recurring payments
    var endDate: Date?

    // MARK: - Payment Category (CloudKit: default required)

    /// Category: "recurring" or "subscription"
    var paymentCategory: String = "recurring"

    // MARK: - Notifications (CloudKit: defaults required)

    /// Whether to notify on due date
    var notifyOnDueDate: Bool = true

    /// Days before due date to notify (0 = disabled, 1-30 = days before)
    var notifyDaysBefore: Int = 0

    // MARK: - Metadata (CloudKit: defaults required)

    /// Whether this payment is active
    var isActive: Bool = true

    /// Creation timestamp
    var createdAt: Date = Date()

    /// Last date a notification was sent (to avoid duplicates)
    var lastNotifiedDate: Date?

    /// Last date this payment was marked as paid (from inbox approval)
    var lastPaidDate: Date?

    // MARK: - Init

    init(
        name: String,
        note: String? = nil,
        amount: Double,
        currencyCode: String,
        transactionType: String = "expense",
        account: Account? = nil,
        subcategory: Subcategory? = nil,
        tags: [Tag] = [],
        natureOverride: String? = nil,
        isRecurring: Bool = true,
        recurrenceType: String = "monthly",
        recurrenceInterval: Int = 1,
        nextDueDate: Date,
        dayOfMonth: Int? = nil,
        selectedWeekdays: String? = nil,
        yearlyMonth: Int? = nil,
        yearlyDay: Int? = nil,
        endDate: Date? = nil,
        paymentCategory: String = "recurring",
        notifyOnDueDate: Bool = true,
        notifyDaysBefore: Int = 3,
        isActive: Bool = true
    ) {
        self.name = name
        self.note = note
        self.amount = amount
        self.currencyCode = currencyCode
        self.transactionType = transactionType
        self.account = account
        self.subcategory = subcategory
        self.tags = tags
        self.natureOverride = natureOverride
        self.isRecurring = isRecurring
        self.recurrenceType = recurrenceType
        self.recurrenceInterval = recurrenceInterval
        self.nextDueDate = nextDueDate
        self.dayOfMonth = dayOfMonth
        self.selectedWeekdays = selectedWeekdays
        self.yearlyMonth = yearlyMonth
        self.yearlyDay = yearlyDay
        self.endDate = endDate
        self.paymentCategory = paymentCategory
        self.notifyOnDueDate = notifyOnDueDate
        self.notifyDaysBefore = notifyDaysBefore
        self.isActive = isActive
        self.createdAt = Date()
        self.lastNotifiedDate = nil
    }

    // MARK: - Computed Properties

    /// Transaction type as enum
    var type: TransactionType {
        TransactionType(rawValue: transactionType) ?? .expense
    }

    /// Effective nature (override or subcategory's nature)
    var effectiveNature: SubcategoryNature? {
        if let override = natureOverride {
            return SubcategoryNature(rawValue: override)
        }
        return subcategory?.nature
    }

    /// Whether this payment has been paid for the current billing cycle
    /// Returns true if lastPaidDate is within the current period (since last due date)
    var isPaidForCurrentCycle: Bool {
        guard let paidDate = lastPaidDate else { return false }

        let calendar = Calendar.current

        // Calculate the previous due date based on recurrence
        guard let recurrence = RecurrenceType(rawValue: recurrenceType) else { return false }

        let previousDueDate: Date?
        switch recurrence {
        case .daily:
            previousDueDate = calendar.date(byAdding: .day, value: -recurrenceInterval, to: nextDueDate)
        case .weekly:
            previousDueDate = calendar.date(byAdding: .weekOfYear, value: -recurrenceInterval, to: nextDueDate)
        case .monthly:
            previousDueDate = calendar.date(byAdding: .month, value: -recurrenceInterval, to: nextDueDate)
        case .yearly:
            previousDueDate = calendar.date(byAdding: .year, value: -recurrenceInterval, to: nextDueDate)
        }

        guard let prevDate = previousDueDate else { return false }

        // Payment is considered paid if lastPaidDate >= previousDueDate
        return paidDate >= calendar.startOfDay(for: prevDate)
    }
}
