//
//  CashFlowPlanViewModelTests.swift
//  YalaTests
//
//  Unit tests for CashFlowPlanViewModel suggestion logic.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct CashFlowPlanViewModelTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#000000", isIncome: isIncome)
    }

    private func makeSubcategory(name: String, category: YalaCategory) -> Subcategory {
        Subcategory(name: name, colorHex: "#FF0000", category: category)
    }

    private func makeTransaction(
        amount: Double,
        date: Date,
        category: YalaCategory? = nil,
        subcategory: Subcategory? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "USD",
            note: "",
            category: category,
            tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        tx.subcategory = subcategory
        return tx
    }

    private var currentMonthStart: Date {
        let components = calendar.dateComponents([.year, .month], from: Date.now)
        return calendar.date(from: components)!
    }

    private func txDate(monthsAgo: Int, day: Int = 10) -> Date {
        let monthStart = calendar.date(byAdding: .month, value: -monthsAgo, to: currentMonthStart)!
        return calendar.date(byAdding: .day, value: day, to: monthStart)!
    }

    // MARK: - 1. Categories with 4+ months → selected

    @Test func generateSuggestions_4PlusMonths_isSelected() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Food")

        var transactions: [TransactionItem] = []
        for i in 1...5 {
            transactions.append(makeTransaction(amount: -100, date: txDate(monthsAgo: i), category: cat))
        }

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let suggestion = viewModel.suggestedLines.first { $0.name == "Food" }
        #expect(suggestion != nil)
        #expect(suggestion!.isSelected == true)
        #expect(suggestion!.monthsWithActivity == 5)
    }

    // MARK: - 2. Categories with 1 month → not included

    @Test func generateSuggestions_1Month_notIncluded() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Gym")

        let transactions = [makeTransaction(amount: -50, date: txDate(monthsAgo: 1), category: cat)]

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let suggestion = viewModel.suggestedLines.first { $0.name == "Gym" }
        #expect(suggestion == nil)
    }

    // MARK: - 3. Categories with 2-3 months → included but not selected

    @Test func generateSuggestions_2To3Months_notSelected() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Entertainment")

        var transactions: [TransactionItem] = []
        for i in 1...3 {
            transactions.append(makeTransaction(amount: -80, date: txDate(monthsAgo: i), category: cat))
        }

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let suggestion = viewModel.suggestedLines.first { $0.name == "Entertainment" }
        #expect(suggestion != nil)
        #expect(suggestion!.isSelected == false)
    }

    // MARK: - 4. Income categories → isIncome true

    @Test func generateSuggestions_incomeCategory_isIncomeTrue() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Salary", isIncome: true)

        var transactions: [TransactionItem] = []
        for i in 1...5 {
            transactions.append(makeTransaction(amount: 5000, date: txDate(monthsAgo: i), category: cat))
        }

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let suggestion = viewModel.suggestedLines.first { $0.name == "Salary" }
        #expect(suggestion != nil)
        #expect(suggestion!.isIncome == true)
    }

    // MARK: - 5. No transactions → empty suggestions

    @Test func generateSuggestions_noTransactions_emptyList() {
        let viewModel = CashFlowPlanViewModel()

        viewModel.generateSuggestions(transactions: [], scheduledPayments: [], categories: [])

        #expect(viewModel.suggestedLines.isEmpty)
    }

    // MARK: - 6. Suggested amount calculates average correctly

    @Test func generateSuggestions_averageAmountCorrect() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Food")

        let amounts: [Double] = [100, 200, 300, 400]
        var transactions: [TransactionItem] = []
        for (i, amount) in amounts.enumerated() {
            transactions.append(makeTransaction(amount: -amount, date: txDate(monthsAgo: i + 1), category: cat))
        }

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let suggestion = viewModel.suggestedLines.first { $0.name == "Food" }
        #expect(suggestion != nil)
        // Average of 100, 200, 300, 400 = 250
        #expect(abs(suggestion!.suggestedAmount - 250) < 0.01)
    }

    // MARK: - 7. Months with activity counts distinct months

    @Test func generateSuggestions_multipleTransactionsSameMonth_countedOnce() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Food")

        var transactions: [TransactionItem] = []
        // 3 transactions in same month, 1 in another
        for day in [5, 10, 15] {
            transactions.append(makeTransaction(amount: -50, date: txDate(monthsAgo: 1, day: day), category: cat))
        }
        transactions.append(makeTransaction(amount: -50, date: txDate(monthsAgo: 2), category: cat))

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let suggestion = viewModel.suggestedLines.first { $0.name == "Food" }
        #expect(suggestion != nil)
        #expect(suggestion!.monthsWithActivity == 2) // Only 2 distinct months
    }

    // MARK: - 8. Balance adjustments excluded

    @Test func generateSuggestions_balanceAdjustments_excluded() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Adjustment")

        var transactions: [TransactionItem] = []
        for i in 1...5 {
            let tx = makeTransaction(amount: -100, date: txDate(monthsAgo: i), category: cat)
            tx.balanceAdjustmentType = "adjustment"
            transactions.append(tx)
        }

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let suggestion = viewModel.suggestedLines.first { $0.name == "Adjustment" }
        #expect(suggestion == nil) // All excluded
    }

    // MARK: - 9. Subcategories grouped separately

    @Test func generateSuggestions_withSubcategories_groupsBySubcategory() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Food")
        let sub1 = makeSubcategory(name: "Groceries", category: cat)
        let sub2 = makeSubcategory(name: "Restaurants", category: cat)

        var transactions: [TransactionItem] = []
        for i in 1...4 {
            transactions.append(makeTransaction(amount: -100, date: txDate(monthsAgo: i), category: cat, subcategory: sub1))
            transactions.append(makeTransaction(amount: -50, date: txDate(monthsAgo: i), category: cat, subcategory: sub2))
        }

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let groceries = viewModel.suggestedLines.first { $0.name == "Groceries" }
        let restaurants = viewModel.suggestedLines.first { $0.name == "Restaurants" }
        #expect(groceries != nil)
        #expect(restaurants != nil)
        #expect(groceries!.subcategory?.name == "Groceries")
        #expect(restaurants!.subcategory?.name == "Restaurants")
        // No line named "Food" — subcategories take over
        let food = viewModel.suggestedLines.first { $0.name == "Food" }
        #expect(food == nil)
    }

    // MARK: - 10. Without subcategory falls back to category

    @Test func generateSuggestions_withoutSubcategory_fallsToCategory() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Transport")

        var transactions: [TransactionItem] = []
        for i in 1...4 {
            transactions.append(makeTransaction(amount: -60, date: txDate(monthsAgo: i), category: cat))
        }

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let suggestion = viewModel.suggestedLines.first { $0.name == "Transport" }
        #expect(suggestion != nil)
        #expect(suggestion!.subcategory == nil)
        #expect(suggestion!.category?.name == "Transport")
    }

    // MARK: - 11. Mixed subcategories produce separate lines

    @Test func generateSuggestions_mixedSubcategories_separateLines() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Home")
        let sub = makeSubcategory(name: "Electricity", category: cat)

        var transactions: [TransactionItem] = []
        // Some transactions with subcategory, some without
        for i in 1...3 {
            transactions.append(makeTransaction(amount: -80, date: txDate(monthsAgo: i), category: cat, subcategory: sub))
            transactions.append(makeTransaction(amount: -40, date: txDate(monthsAgo: i), category: cat))
        }

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let electricity = viewModel.suggestedLines.first { $0.name == "Electricity" }
        let home = viewModel.suggestedLines.first { $0.name == "Home" }
        #expect(electricity != nil)
        #expect(home != nil)
        // Both should have 3 months
        #expect(electricity!.monthsWithActivity == 3)
        #expect(home!.monthsWithActivity == 3)
    }

    // MARK: - 12. Update estimation method recalculates amount

    @Test func updateEstimationMethod_recalculatesAmount() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Food")

        var transactions: [TransactionItem] = []
        for i in 1...5 {
            transactions.append(makeTransaction(amount: -100, date: txDate(monthsAgo: i), category: cat))
        }

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat], currencyCode: "USD")

        guard let line = viewModel.suggestedLines.first(where: { $0.name == "Food" }) else {
            #expect(Bool(false), "Should have Food suggestion")
            return
        }
        let originalAmount = line.suggestedAmount

        // Switch to manual
        viewModel.updateEstimationMethod(for: line.id, to: .manual, manualAmount: 999)

        let updated = viewModel.suggestedLines.first { $0.id == line.id }
        #expect(updated != nil)
        #expect(updated!.estimationMethod == .manual)
        #expect(abs(updated!.suggestedAmount - 999) < 0.01)

        // Switch back to average6m — should restore original
        viewModel.updateEstimationMethod(for: line.id, to: .average6m)
        let restored = viewModel.suggestedLines.first { $0.id == line.id }
        #expect(restored != nil)
        #expect(abs(restored!.suggestedAmount - originalAmount) < 0.01)
    }
}
