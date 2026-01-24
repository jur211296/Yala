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

    /// Display name for the scheduled payment (required)
    var name: String

    /// Optional description/note
    var note: String?

    // MARK: - Amount & Currency

    /// Payment amount (required)
    var amount: Double

    /// Currency code (ISO 4217)
    var currencyCode: String

    // MARK: - Type (income/expense)

    /// Transaction type: "income" or "expense"
    var transactionType: String

    // MARK: - Classification

    /// Linked account (required for context)
    var account: Account?

    /// Linked subcategory for categorization
    var subcategory: Subcategory?

    /// Linked tags (many-to-many)
    @Relationship(inverse: \Tag.scheduledPayments)
    var tags: [Tag]

    /// Optional nature override (nil = use subcategory's nature)
    var natureOverride: String?

    // MARK: - Recurrence

    /// Whether this is a recurring payment (false = one-time)
    var isRecurring: Bool

    /// Recurrence type: "daily", "weekly", "monthly", "yearly" (only if isRecurring)
    var recurrenceType: String

    /// Recurrence interval: "every X days/weeks/months/years" (default 1)
    var recurrenceInterval: Int

    /// Payment date (for one-time) or next due date (for recurring)
    var nextDueDate: Date

    /// Day of month for monthly recurrence (1-31)
    var dayOfMonth: Int?

    /// Selected weekdays for weekly recurrence (comma-separated: "1,3,5" = Sun,Tue,Thu)
    var selectedWeekdays: String?

    /// Yearly payment date (month and day)
    var yearlyMonth: Int?
    var yearlyDay: Int?

    /// Optional end date for recurring payments
    var endDate: Date?

    // MARK: - Payment Category

    /// Category: "recurring" or "subscription"
    var paymentCategory: String

    // MARK: - Notifications

    /// Whether to notify on due date
    var notifyOnDueDate: Bool

    /// Days before due date to notify (0 = disabled, 1-30 = days before)
    var notifyDaysBefore: Int

    // MARK: - Metadata

    /// Whether this payment is active
    var isActive: Bool

    /// Creation timestamp
    var createdAt: Date

    /// Last date a notification was sent (to avoid duplicates)
    var lastNotifiedDate: Date?

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
}
