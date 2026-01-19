//
//  ScheduledPayment.swift
//  Neto
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

    /// Recurrence type: "weekly", "monthly", "yearly"
    var recurrenceType: String

    /// Next due date for this payment
    var nextDueDate: Date

    /// Day of month for monthly recurrence (1-31)
    var dayOfMonth: Int?

    /// Day of week for weekly recurrence (1=Sunday, 7=Saturday)
    var dayOfWeek: Int?

    /// Month of year for yearly recurrence (1-12)
    var monthOfYear: Int?

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
        recurrenceType: String = "monthly",
        nextDueDate: Date,
        dayOfMonth: Int? = nil,
        dayOfWeek: Int? = nil,
        monthOfYear: Int? = nil,
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
        self.recurrenceType = recurrenceType
        self.nextDueDate = nextDueDate
        self.dayOfMonth = dayOfMonth
        self.dayOfWeek = dayOfWeek
        self.monthOfYear = monthOfYear
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
