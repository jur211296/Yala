//
//  Account.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

// MARK: - Account

@Model
final class Account {
    // CloudKit: defaults required
    var name: String = ""
    var currencyCode: String = "USD"
    var colorHex: String = "#6366F1"
    var iconName: String = "creditcard"

    var type: String = "checking"
    var accountNumber: String?
    var adjustmentMode: String = "manual"
    var excludeFromStatistics: Bool = false
    var isArchived: Bool = false

    // Credit card specific
    var creditCardPaymentReminder: Bool = false
    var creditCardPaymentDay: Int = 1

    /// Relación inversa con budgets (muchos-a-muchos) - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var budgets: [Budget]?

    /// Inverse relationship: transactions linked to this account - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var transactions: [TransactionItem]?

    /// Inverse relationship: favorite payments linked to this account - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var favoritePayments: [FavoritePayment]?

    /// Inverse relationship: scheduled payments linked to this account - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var scheduledPayments: [ScheduledPayment]?

    /// Inverse relationship: inbox drafts linked to this account - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var inboxDrafts: [InboxDraft]?

    init(
        name: String,
        currencyCode: String,
        colorHex: String,
        iconName: String,
        type: String,
        accountNumber: String? = nil,
        adjustmentMode: String = "Ajustar por registro",
        excludeFromStatistics: Bool = false,
        isArchived: Bool = false
    ) {
        self.name = name
        self.currencyCode = currencyCode
        self.colorHex = colorHex
        self.iconName = iconName
        self.type = type
        self.accountNumber = accountNumber
        self.adjustmentMode = adjustmentMode
        self.excludeFromStatistics = excludeFromStatistics
        self.isArchived = isArchived
    }
}
