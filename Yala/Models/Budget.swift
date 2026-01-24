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
    // Legacy properties (kept for backwards compatibility)
    var month: Int
    var year: Int
    var currencyCode: String
    var limitAmount: Double
    var category: Category?

    // New properties for enhanced budget system
    var name: String
    var periodType: String  // "weekly", "monthly", "yearly", "unique"
    var startDate: Date?    // For unique budgets
    var endDate: Date?      // For unique budgets
    var currentPeriodStart: Date?  // For tracking which week/month/year

    // Many-to-many relationships (explicit inverse for proper SwiftData handling)
    @Relationship(inverse: \Account.budgets)
    var accounts: [Account]

    @Relationship(inverse: \Subcategory.budgets)
    var subcategories: [Subcategory]

    @Relationship(inverse: \Tag.budgets)
    var tags: [Tag]
    var natures: String?    // Comma-separated nature values (e.g., "essential,priority")
    var isActive: Bool
    var createdAt: Date
    var isFavorite: Bool = false
    var favoriteOrder: Int = 0

    init(
        month: Int = 0,
        year: Int = 0,
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
        favoriteOrder: Int = 0
    ) {
        self.month = month
        self.year = year
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
    }
}
