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
    var name: String
    var currencyCode: String
    var colorHex: String
    var iconName: String

    var type: String
    var accountNumber: String?
    var adjustmentMode: String
    var excludeFromStatistics: Bool
    var isArchived: Bool

    /// Relación inversa con budgets (muchos-a-muchos)
    var budgets: [Budget] = []

    /// Inverse relationship: transactions linked to this account
    var transactions: [TransactionItem] = []

    /// Inverse relationship: favorite payments linked to this account
    var favoritePayments: [FavoritePayment] = []

    /// Inverse relationship: scheduled payments linked to this account
    var scheduledPayments: [ScheduledPayment] = []

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
