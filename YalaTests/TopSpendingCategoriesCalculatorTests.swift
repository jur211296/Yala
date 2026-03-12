//
//  TopSpendingCategoriesCalculatorTests.swift
//  YalaTests
//
//  Unit tests for TopSpendingCategoriesCalculator pure logic.
//

import Foundation
import Testing

@testable import Yala

struct TopSpendingCategoriesCalculatorTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#FF0000", isIncome: isIncome)
    }

    private func makeTransaction(
        amount: Double,
        date: Date = Date(),
        currencyCode: String = "USD",
        category: YalaCategory? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: currencyCode,
            note: "",
            category: category,
            tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    private var defaultInterval: DateInterval {
        let now = Date()
        let start = calendar.date(byAdding: .day, value: -30, to: now)!
        return DateInterval(start: start, end: now.addingTimeInterval(1))
    }

    // MARK: - Tests

    @Test func empty_returnsEmptyResult() {
        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }

    @Test func singleCategory_100Percent() {
        let cat = makeCategory(name: "Food")
        let tx = makeTransaction(amount: -100, category: cat)

        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.count == 1)
        #expect(result[0].category.name == "Food")
        #expect(result[0].amount == 100)
        #expect(result[0].percentage == 100)
    }

    @Test func twoCategories_correctPercentages() {
        let catA = makeCategory(name: "Food")
        let catB = makeCategory(name: "Transport")
        let tx1 = makeTransaction(amount: -300, category: catA)
        let tx2 = makeTransaction(amount: -200, category: catB)

        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [tx1, tx2],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.count == 2)
        // Total = 500, Food = 300 (60%), Transport = 200 (40%)
        #expect(result[0].percentage == 60)
        #expect(result[1].percentage == 40)
    }

    @Test func sortedByAmountDescending() {
        let catSmall = makeCategory(name: "Small")
        let catBig = makeCategory(name: "Big")
        let tx1 = makeTransaction(amount: -100, category: catSmall)
        let tx2 = makeTransaction(amount: -500, category: catBig)

        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [tx1, tx2],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result[0].category.name == "Big")
        #expect(result[1].category.name == "Small")
    }

    @Test func balanceAdjustments_excluded() {
        let cat = makeCategory(name: "Food")
        let tx = makeTransaction(
            amount: -100,
            category: cat,
            balanceAdjustmentType: "adjustment"
        )

        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }

    @Test func incomeExcludedByDefault() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let tx = makeTransaction(amount: 5000, category: incomeCat)

        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }

    @Test func transactionNaturesIncome_onlyIncomeCategories() {
        let expCat = makeCategory(name: "Food")
        let incCat = makeCategory(name: "Salary", isIncome: true)
        let tx1 = makeTransaction(amount: -100, category: expCat)
        let tx2 = makeTransaction(amount: 5000, category: incCat)

        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [tx1, tx2],
            interval: defaultInterval,
            currencyCode: "USD",
            transactionNatures: [.income],
            converter: MockCurrencyConverter()
        )

        #expect(result.count == 1)
        #expect(result[0].category.name == "Salary")
    }

    @Test func transactionsOutsideInterval_excluded() {
        let cat = makeCategory(name: "Food")
        let oldDate = calendar.date(byAdding: .year, value: -1, to: Date())!
        let tx = makeTransaction(amount: -100, date: oldDate, category: cat)

        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }

    @Test func multiCurrency_conversionApplied() {
        let cat = makeCategory(name: "Food")
        let tx = makeTransaction(amount: -50, currencyCode: "EUR", category: cat)
        tx.preferredCurrencyCode = "EUR" // Different from target "USD"

        var converter = MockCurrencyConverter()
        converter.fixedRate = 2.0

        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: converter
        )

        #expect(result.count == 1)
        #expect(result[0].amount == 100) // 50 * 2.0
    }

    @Test func noCategoryTransactions_excluded() {
        let tx = makeTransaction(amount: -100)

        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [tx],
            interval: defaultInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }
}

/*
Tests generated:
1. empty_returnsEmptyResult - Empty input returns empty array
2. singleCategory_100Percent - Single category gets 100% of spending
3. twoCategories_correctPercentages - Two categories get correct proportional percentages
4. sortedByAmountDescending - Results are sorted by amount descending
5. balanceAdjustments_excluded - Balance adjustments are filtered out
6. incomeExcludedByDefault - Income categories excluded when no transactionNatures specified
7. transactionNaturesIncome_onlyIncomeCategories - Income filter returns only income categories
8. transactionsOutsideInterval_excluded - Transactions outside date interval are excluded
9. multiCurrency_conversionApplied - Currency conversion uses MockCurrencyConverter rate
10. noCategoryTransactions_excluded - Transactions without category are excluded

Cases NOT covered (require more context):
- Categories with subcategories rolled up to parent (all belong to same parent category in this model)
*/
