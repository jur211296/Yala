//
//  TestHelpers.swift
//  YalaTests
//
//  Utilities for creating test contexts and mock data
//

import Foundation
import SwiftData

@testable import Yala

// MARK: - Type Aliases (to avoid ambiguity with Foundation types)

typealias YalaCategory = Yala.Category

// MARK: - In-Memory SwiftData Context

/// Creates an in-memory ModelContext for testing
/// Each test should call this to get a fresh, isolated context
@MainActor
func makeTestContext() throws -> ModelContext {
    // Use Schema like the main app does
    let schema = Schema([
        Yala.Category.self,
        Subcategory.self,
        Tag.self,
        Account.self,
        TransactionItem.self,
        Budget.self,
        ExchangeRate.self,
        FavoritePayment.self,
        ScheduledPayment.self,
        InboxDraft.self,
        MerchantMemory.self,
        NotificationItem.self,
    ])

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: config)
    return container.mainContext
}

// MARK: - Factory Methods

@MainActor
func makeTestAccount(
    context: ModelContext,
    name: String = "Test Account",
    currencyCode: String = "PEN"
) -> Account {
    let account = Account(
        name: name,
        currencyCode: currencyCode,
        colorHex: "#6366F1",
        iconName: "creditcard.fill",
        type: "bank"
    )
    context.insert(account)
    return account
}

@MainActor
func makeTestCategory(
    context: ModelContext,
    name: String = "Test Category",
    isIncome: Bool = false
) -> YalaCategory {
    let category = YalaCategory(
        name: name,
        colorHex: "#EF4444",
        isIncome: isIncome
    )
    context.insert(category)
    return category
}

@MainActor
func makeTestSubcategory(
    context: ModelContext,
    name: String = "Test Subcategory",
    category: YalaCategory,
    nature: SubcategoryNature = .essential
) -> Subcategory {
    let subcategory = Subcategory(
        name: name,
        colorHex: nil,
        natureRawValue: nature.rawValue,
        iconName: "cart.fill",
        category: category
    )
    context.insert(subcategory)
    return subcategory
}

@MainActor
func makeTestTag(
    context: ModelContext,
    name: String = "Test Tag"
) -> Tag {
    let tag = Tag(name: name, colorHex: "#8B5CF6", iconName: "tag.fill")
    context.insert(tag)
    return tag
}

@MainActor
func makeTestBudget(
    context: ModelContext,
    name: String = "Test Budget",
    limitAmount: Double = 1000.0,
    periodType: BudgetPeriodType = .monthly,
    isActive: Bool = true,
    accounts: [Account] = [],
    subcategories: [Subcategory] = [],
    tags: [Tag] = [],
    startDate: Date? = nil,
    endDate: Date? = nil
) -> Budget {
    let budget = Budget(
        currencyCode: "PEN",
        limitAmount: limitAmount,
        name: name,
        periodType: periodType.rawValue,
        startDate: startDate,
        endDate: endDate,
        accounts: accounts,
        subcategories: subcategories,
        tags: tags,
        isActive: isActive
    )
    context.insert(budget)
    return budget
}

@MainActor
func makeTestTransaction(
    context: ModelContext,
    amount: Double,
    date: Date = Date(),
    account: Account,
    category: YalaCategory,
    subcategory: Subcategory,
    currencyCode: String? = nil,
    tags: [Tag] = []
) -> TransactionItem {
    let transaction = TransactionItem(
        date: date,
        amount: amount,
        currencyCode: currencyCode ?? account.currencyCode,
        note: nil,
        category: category,
        subcategory: subcategory,
        account: account,
        tags: tags,
        exchangeRate: 1.0,
        amountInPreferredCurrency: amount,
        preferredCurrencyCode: "PEN"
    )
    context.insert(transaction)
    return transaction
}

// MARK: - Date Helpers

/// Get start of current month
func startOfCurrentMonth() -> Date {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month], from: Date())
    return calendar.date(from: components) ?? Date()
}

/// Get start of current week
func startOfCurrentWeek() -> Date {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
    return calendar.date(from: components) ?? Date()
}

/// Get date N days from now
func dateOffset(days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
}

/// Get date N months from now
func dateOffset(months: Int) -> Date {
    Calendar.current.date(byAdding: .month, value: months, to: Date()) ?? Date()
}
