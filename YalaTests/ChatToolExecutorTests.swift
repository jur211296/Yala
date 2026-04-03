//
//  ChatToolExecutorTests.swift
//  YalaTests
//
//  Tests for ChatToolExecutor: 5 tools against SwiftData-like objects.
//

import Testing
import Foundation
import SwiftData
@testable import Yala

struct ChatToolExecutorTests {

    // MARK: - Helpers

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#000000", isIncome: isIncome)
    }

    private func makeSubcategory(name: String, category: YalaCategory? = nil) -> Subcategory {
        Subcategory(name: name, category: category)
    }

    private func makeAccount(name: String, excludeFromStatistics: Bool = false) -> Account {
        let account = Account(name: name, currencyCode: "USD", colorHex: "#000", iconName: "creditcard", type: "bank")
        account.excludeFromStatistics = excludeFromStatistics
        return account
    }

    private func makeTransaction(
        amount: Double,
        date: Date = Date.now,
        currencyCode: String = "USD",
        note: String? = nil,
        category: YalaCategory? = nil,
        subcategory: Subcategory? = nil,
        account: Account? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: currencyCode,
            note: note,
            category: category,
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        tx.subcategory = subcategory
        tx.account = account
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    @MainActor
    private func makeExecutor(transactions: [TransactionItem]) throws -> ChatToolExecutor {
        let context = try makeTestContext()
        for tx in transactions { context.insert(tx) }
        try context.save()
        return ChatToolExecutor(
            modelContext: context,
            currencyCode: "USD",
            converter: MockCurrencyConverter(fixedRate: 1.0)
        )
    }

    // MARK: - search_transactions

    @MainActor @Test func searchTransactions_byCategory_returnsMatching() throws {
        let food = makeCategory(name: "Food")
        let transport = makeCategory(name: "Transport")
        let tx1 = makeTransaction(amount: -50, note: "Lunch", category: food)
        let tx2 = makeTransaction(amount: -30, note: "Uber", category: transport)
        let executor = try makeExecutor(transactions: [tx1, tx2])

        let result = try executor.execute(
            toolName: "search_transactions",
            arguments: #"{"date_range": "this_month", "category": "Food"}"#
        )

        let summary = result["summary"] as? [String: Any]
        #expect(summary?["count"] as? Int == 1)
        #expect(summary?["total"] as? Double == 50.0)
    }

    @MainActor @Test func searchTransactions_excludesBalanceAdjustments() throws {
        let cat = makeCategory(name: "Food")
        let tx1 = makeTransaction(amount: -50, note: "Lunch", category: cat)
        let tx2 = makeTransaction(amount: 100, note: "Adjustment", category: cat, balanceAdjustmentType: "initial_balance")
        let executor = try makeExecutor(transactions: [tx1, tx2])

        let result = try executor.execute(
            toolName: "search_transactions",
            arguments: #"{"date_range": "this_month"}"#
        )

        let summary = result["summary"] as? [String: Any]
        #expect(summary?["count"] as? Int == 1)
    }

    @MainActor @Test func searchTransactions_excludesStatisticsAccounts() throws {
        let cat = makeCategory(name: "Food")
        let normalAccount = makeAccount(name: "Checking")
        let excludedAccount = makeAccount(name: "Savings", excludeFromStatistics: true)
        let tx1 = makeTransaction(amount: -50, note: "Lunch", category: cat, account: normalAccount)
        let tx2 = makeTransaction(amount: -30, note: "Other", category: cat, account: excludedAccount)
        let executor = try makeExecutor(transactions: [tx1, tx2])

        let result = try executor.execute(
            toolName: "search_transactions",
            arguments: #"{"date_range": "this_month"}"#
        )

        let summary = result["summary"] as? [String: Any]
        #expect(summary?["count"] as? Int == 1)
    }

    @MainActor @Test func searchTransactions_merchantFilter_usesCanonicalizer() throws {
        let cat = makeCategory(name: "Food")
        let tx1 = makeTransaction(amount: -15, note: "Starbucks Coffee", category: cat)
        let tx2 = makeTransaction(amount: -30, note: "McDonalds", category: cat)
        let executor = try makeExecutor(transactions: [tx1, tx2])

        let result = try executor.execute(
            toolName: "search_transactions",
            arguments: #"{"date_range": "this_month", "merchant": "starbucks"}"#
        )

        let summary = result["summary"] as? [String: Any]
        #expect(summary?["count"] as? Int == 1)
    }

    @MainActor @Test func searchTransactions_neverExposesRawNote() throws {
        let cat = makeCategory(name: "Food")
        let tx = makeTransaction(amount: -15, note: "Lunch with Juan at Starbucks", category: cat)
        let executor = try makeExecutor(transactions: [tx])

        let result = try executor.execute(
            toolName: "search_transactions",
            arguments: #"{"date_range": "this_month"}"#
        )

        let transactions = result["transactions"] as? [[String: Any]]
        let firstTx = transactions?.first
        // Merchant should be canonicalized, not raw note
        let merchant = firstTx?["merchant"] as? String ?? ""
        #expect(!merchant.contains("Juan"))
        #expect(firstTx?["note"] == nil) // note field should never be present
    }

    // MARK: - spending_summary

    @MainActor @Test func spendingSummary_byCategory_returnsGrouped() throws {
        let food = makeCategory(name: "Food")
        let transport = makeCategory(name: "Transport")
        let tx1 = makeTransaction(amount: -100, note: "Lunch", category: food)
        let tx2 = makeTransaction(amount: -50, note: "Bus", category: transport)
        let tx3 = makeTransaction(amount: -80, note: "Dinner", category: food)
        let executor = try makeExecutor(transactions: [tx1, tx2, tx3])

        let result = try executor.execute(
            toolName: "spending_summary",
            arguments: #"{"date_range": "this_month", "group_by": "category"}"#
        )

        let groups = result["groups"] as? [[String: Any]]
        #expect(groups != nil)
        #expect((groups?.count ?? 0) >= 1)
        let total = result["total"] as? Double ?? 0
        #expect(total == 230.0)
    }

    // MARK: - budget_status

    @MainActor @Test func budgetStatus_returnsActiveBudgets() throws {
        let context = try makeTestContext()
        let cat = YalaCategory(name: "Food", colorHex: "#000", isIncome: false)
        context.insert(cat)

        let budget = Budget(currencyCode: "USD", limitAmount: 500, category: cat, name: "Food Budget")
        context.insert(budget)

        let tx = TransactionItem(date: Date.now, amount: -200, currencyCode: "USD", note: "Lunch", category: cat, amountInPreferredCurrency: -200)
        tx.preferredCurrencyCode = "USD"
        context.insert(tx)
        try context.save()

        let executor = ChatToolExecutor(modelContext: context, currencyCode: "USD", converter: MockCurrencyConverter(fixedRate: 1.0))
        let result = try executor.execute(toolName: "budget_status", arguments: #"{}"#)

        let budgets = result["budgets"] as? [[String: Any]]
        #expect(budgets != nil)
        #expect((budgets?.count ?? 0) >= 1)
        let first = budgets?.first
        #expect(first?["name"] as? String == "Food Budget")
    }

    // MARK: - compare_periods

    @MainActor @Test func comparePeriods_expense_returnsChange() throws {
        let cat = makeCategory(name: "Food")
        let now = Date.now
        let lastMonth = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        let tx1 = makeTransaction(amount: -200, date: now, note: "This month", category: cat)
        let tx2 = makeTransaction(amount: -150, date: lastMonth, note: "Last month", category: cat)
        let executor = try makeExecutor(transactions: [tx1, tx2])

        let result = try executor.execute(
            toolName: "compare_periods",
            arguments: #"{"metric": "expense", "period_a": "this_month", "period_b": "last_month"}"#
        )

        let periodA = result["period_a"] as? [String: Any]
        let periodB = result["period_b"] as? [String: Any]
        #expect(periodA?["value"] as? Double == 200.0)
        #expect(periodB?["value"] as? Double == 150.0)
    }

    // MARK: - financial_overview

    @MainActor @Test func financialOverview_returnsComprehensiveData() throws {
        let food = makeCategory(name: "Food")
        let income = makeCategory(name: "Salary", isIncome: true)
        let tx1 = makeTransaction(amount: -200, note: "Food", category: food)
        let tx2 = makeTransaction(amount: 3000, note: "Salary", category: income)
        let executor = try makeExecutor(transactions: [tx1, tx2])

        let result = try executor.execute(
            toolName: "financial_overview",
            arguments: #"{"date_range": "this_month"}"#
        )

        #expect(result["income"] as? Double == 3000.0)
        #expect(result["expense"] as? Double == 200.0)
        #expect(result["balance"] as? Double == 2800.0)
        #expect(result["currency"] as? String == "USD")
    }

    // MARK: - Multi-currency

    @MainActor @Test func searchTransactions_multiCurrency_convertsToPreferred() throws {
        let cat = makeCategory(name: "Food")
        let tx1 = makeTransaction(amount: -100, currencyCode: "USD", note: "USD", category: cat)
        let tx2 = TransactionItem(date: Date.now, amount: -370, currencyCode: "PEN", note: "PEN", category: cat, amountInPreferredCurrency: -100)
        tx2.preferredCurrencyCode = "USD"

        let executor = try makeExecutor(transactions: [tx1, tx2])
        let result = try executor.execute(
            toolName: "search_transactions",
            arguments: #"{"date_range": "this_month"}"#
        )

        let summary = result["summary"] as? [String: Any]
        #expect(summary?["total"] as? Double == 200.0)
    }

    // MARK: - Error handling

    @MainActor @Test func execute_unknownTool_throws() throws {
        let executor = try makeExecutor(transactions: [])

        #expect(throws: ChatAssistantError.self) {
            _ = try executor.execute(toolName: "unknown_tool", arguments: "{}")
        }
    }

    @MainActor @Test func execute_invalidArguments_throws() throws {
        let executor = try makeExecutor(transactions: [])

        #expect(throws: (any Error).self) {
            _ = try executor.execute(toolName: "search_transactions", arguments: "not json")
        }
    }
}
