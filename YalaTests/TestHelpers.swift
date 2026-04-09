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
typealias YalaTag = Yala.Tag

// MARK: - In-Memory SwiftData Context

/// Creates an in-memory ModelContext for testing with dual config (mirrors production).
/// Each test should call this to get a fresh, isolated context.
@MainActor
func makeTestContext() throws -> ModelContext {
    let container = try ModelContainer(
        for: SwiftDataConfiguration.schema,
        configurations: SwiftDataConfiguration.personalConfiguration,
                       SwiftDataConfiguration.groupsConfiguration
    )
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
    need: SubcategoryNeed = .essential
) -> Subcategory {
    let subcategory = Subcategory(
        name: name,
        colorHex: nil,
        natureRawValue: need.rawValue,
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

// MARK: - Context-Free Factories (no ModelContext needed)

func makeBudget(
    periodType: String = "monthly",
    startDate: Date? = nil,
    endDate: Date? = nil,
    limitAmount: Double = 1000
) -> Budget {
    Budget(
        currencyCode: "USD",
        limitAmount: limitAmount,
        periodType: periodType,
        startDate: startDate,
        endDate: endDate
    )
}

// MARK: - InboxDraft Factory

@MainActor
func makeTestInboxDraft(
    context: ModelContext,
    amount: Double? = 50.0,
    date: Date? = nil,
    note: String = "Test draft"
) -> InboxDraft {
    let draft = InboxDraft(
        note: note,
        amount: amount,
        date: date ?? Date(),
        sourceType: .voice
    )
    context.insert(draft)
    return draft
}

// MARK: - ExchangeRate Factory

@MainActor
func makeTestExchangeRate(
    context: ModelContext,
    dateKey: String = "2026-01-15",
    rates: [String: Double] = ["PEN": 3.75, "EUR": 0.92, "USD": 1.0]
) throws -> ExchangeRate {
    let rate = try ExchangeRate(
        dateKey: dateKey,
        base: "USD",
        ratesDictionary: rates
    )
    context.insert(rate)
    return rate
}
