//
//  Account.swift
//  Finaria
//
//  Created by Finaria Refactoring.
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
    var initialBalance: Double
    var adjustmentMode: String
    var excludeFromStatistics: Bool
    var isArchived: Bool

    init(
        name: String,
        currencyCode: String,
        colorHex: String,
        iconName: String,
        type: String,
        accountNumber: String? = nil,
        initialBalance: Double = 0,
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
        self.initialBalance = initialBalance
        self.adjustmentMode = adjustmentMode
        self.excludeFromStatistics = excludeFromStatistics
        self.isArchived = isArchived
    }
}
