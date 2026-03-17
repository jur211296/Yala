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

    private func makeTransaction(
        amount: Double,
        date: Date,
        category: YalaCategory? = nil
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

    // MARK: - 1. Categories with 4+ months → recommended

    @Test func generateSuggestions_4PlusMonths_isRecommended() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Food")

        var transactions: [TransactionItem] = []
        for i in 1...5 {
            transactions.append(makeTransaction(amount: -100, date: txDate(monthsAgo: i), category: cat))
        }

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let suggestion = viewModel.suggestedLines.first { $0.name == "Food" }
        #expect(suggestion != nil)
        #expect(suggestion!.isRecommended == true)
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

    // MARK: - 3. Categories with 2-3 months → included but not recommended

    @Test func generateSuggestions_2To3Months_notRecommended() {
        let viewModel = CashFlowPlanViewModel()
        let cat = makeCategory(name: "Entertainment")

        var transactions: [TransactionItem] = []
        for i in 1...3 {
            transactions.append(makeTransaction(amount: -80, date: txDate(monthsAgo: i), category: cat))
        }

        viewModel.generateSuggestions(transactions: transactions, scheduledPayments: [], categories: [cat])

        let suggestion = viewModel.suggestedLines.first { $0.name == "Entertainment" }
        #expect(suggestion != nil)
        #expect(suggestion!.isRecommended == false)
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
}

/*
Tests generated:
1. generateSuggestions_4PlusMonths_isRecommended - 4+ months → recommended and selected
2. generateSuggestions_1Month_notIncluded - 1 month → not included
3. generateSuggestions_2To3Months_notRecommended - 2-3 months → included but not recommended
4. generateSuggestions_incomeCategory_isIncomeTrue - Income detection
5. generateSuggestions_noTransactions_emptyList - Empty input → empty
6. generateSuggestions_averageAmountCorrect - Average calculation
7. generateSuggestions_multipleTransactionsSameMonth_countedOnce - Distinct month counting
8. generateSuggestions_balanceAdjustments_excluded - Balance adjustments filtered
*/
