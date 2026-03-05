//
//  Budget.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

// MARK: - Budget

@Model
final class Budget {
    // Stable identifier for tracking (e.g., alert notifications)
    var id: UUID = UUID()

    // Legacy properties (kept for backwards compatibility) - CloudKit: defaults required
    var currencyCode: String = "USD"
    var limitAmount: Double = 0
    @Relationship(deleteRule: .nullify, inverse: \Category.budgets)
    var category: Category?

    // New properties for enhanced budget system - CloudKit: defaults required
    var name: String = ""
    var periodType: String = "monthly"  // "weekly", "monthly", "yearly", "unique"
    var startDate: Date?    // For unique budgets
    var endDate: Date?      // For unique budgets
    var currentPeriodStart: Date?  // For tracking which week/month/year

    // Many-to-many relationships - CloudKit: must be optional
    @Relationship(deleteRule: .nullify, inverse: \Account.budgets)
    var accounts: [Account]?

    @Relationship(deleteRule: .nullify, inverse: \Subcategory.budgets)
    var subcategories: [Subcategory]?

    @Relationship(deleteRule: .nullify, inverse: \Tag.budgets)
    var tags: [Tag]?
    var natures: String?    // Comma-separated nature values (e.g., "essential,priority")
    var isActive: Bool = true
    var createdAt: Date = Date()
    var isFavorite: Bool = false
    var favoriteOrder: Int = 0

    // Alert notifications
    var alertEnabled: Bool = false
    var alertThresholds: String? = nil  // CSV: "50,75,100"

    init(
        id: UUID = UUID(),
        currencyCode: String,
        limitAmount: Double,
        category: Category? = nil,
        name: String = "",
        periodType: String = "monthly",
        startDate: Date? = nil,
        endDate: Date? = nil,
        currentPeriodStart: Date? = nil,
        accounts: [Account] = [],
        subcategories: [Subcategory] = [],
        tags: [Tag] = [],
        natures: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        isFavorite: Bool = false,
        favoriteOrder: Int = 0,
        alertEnabled: Bool = false,
        alertThresholds: String? = nil
    ) {
        self.id = id
        self.currencyCode = currencyCode
        self.limitAmount = limitAmount
        self.category = category
        self.name = name
        self.periodType = periodType
        self.startDate = startDate
        self.endDate = endDate
        self.currentPeriodStart = currentPeriodStart
        self.accounts = accounts
        self.subcategories = subcategories
        self.tags = tags
        self.natures = natures
        self.isActive = isActive
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.favoriteOrder = favoriteOrder
        self.alertEnabled = alertEnabled
        self.alertThresholds = alertThresholds
    }
}
