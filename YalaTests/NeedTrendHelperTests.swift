//
//  NeedTrendHelperTests.swift
//  YalaTests
//
//  Unit tests for NeedTrendHelper.calculateTrend pure logic.
//

import Foundation
import Testing

@testable import Yala

struct NeedTrendHelperTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#FF0000", isIncome: isIncome)
    }

    private func makeSubcategory(
        name: String,
        category: YalaCategory,
        need: SubcategoryNeed = .unclassified
    ) -> Subcategory {
        Subcategory(
            name: name,
            colorHex: "#00FF00",
            natureRawValue: need.rawValue,
            category: category
        )
    }

    private func makeTransaction(
        amount: Double,
        date: Date = Date(),
        currencyCode: String = "USD",
        category: YalaCategory? = nil,
        subcategory: Subcategory? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: currencyCode,
            note: "",
            category: category,
            subcategory: subcategory,
            tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components)!
    }

    private var defaultInterval: DateInterval {
        let start = date(2026, 3, 1)
        let end = date(2026, 3, 31)
        return DateInterval(start: start, end: end)
    }

    // MARK: - Tests

    @Test func empty_returnsEmpty() {
        let result = NeedTrendHelper.calculateTrend(
            transactions: [],
            grouping: .day,
            interval: defaultInterval,
            preferredCurrency: .usd,
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }

    @Test func essentialNeed_onlyEssentialHasValue() {
        let cat = makeCategory(name: "Food")
        let sub = makeSubcategory(name: "Groceries", category: cat, need: .essential)
        let tx = makeTransaction(
            amount: -100,
            date: date(2026, 3, 5),
            category: cat,
            subcategory: sub
        )

        let result = NeedTrendHelper.calculateTrend(
            transactions: [tx],
            grouping: .day,
            interval: defaultInterval,
            preferredCurrency: .usd,
            converter: MockCurrencyConverter()
        )

        #expect(result.count == 1)
        #expect(result[0].essential == 100)
        #expect(result[0].priority == 0)
        #expect(result[0].optional == 0)
        #expect(result[0].unclassified == 0)
    }

    @Test func mixedNeeds_correctDistribution() {
        let cat = makeCategory(name: "Food")
        let subEssential = makeSubcategory(name: "Groceries", category: cat, need: .essential)
        let subPriority = makeSubcategory(name: "Restaurants", category: cat, need: .priority)
        let subOptional = makeSubcategory(name: "Snacks", category: cat, need: .optional)
        let txDate = date(2026, 3, 10)

        let tx1 = makeTransaction(amount: -100, date: txDate, category: cat, subcategory: subEssential)
        let tx2 = makeTransaction(amount: -200, date: txDate, category: cat, subcategory: subPriority)
        let tx3 = makeTransaction(amount: -50, date: txDate, category: cat, subcategory: subOptional)

        let result = NeedTrendHelper.calculateTrend(
            transactions: [tx1, tx2, tx3],
            grouping: .day,
            interval: defaultInterval,
            preferredCurrency: .usd,
            converter: MockCurrencyConverter()
        )

        #expect(result.count == 1)
        #expect(result[0].essential == 100)
        #expect(result[0].priority == 200)
        #expect(result[0].optional == 50)
        #expect(result[0].unclassified == 0)
        #expect(result[0].total == 350)
    }

    @Test func incomeTransactions_excluded() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let sub = makeSubcategory(name: "Wages", category: incomeCat, need: .essential)
        let tx = makeTransaction(
            amount: 5000,
            date: date(2026, 3, 5),
            category: incomeCat,
            subcategory: sub
        )

        let result = NeedTrendHelper.calculateTrend(
            transactions: [tx],
            grouping: .day,
            interval: defaultInterval,
            preferredCurrency: .usd,
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }

    @Test func balanceAdjustments_excluded() {
        let cat = makeCategory(name: "Food")
        let sub = makeSubcategory(name: "Groceries", category: cat, need: .essential)
        let tx = makeTransaction(
            amount: -100,
            date: date(2026, 3, 5),
            category: cat,
            subcategory: sub,
            balanceAdjustmentType: "adjustment"
        )

        let result = NeedTrendHelper.calculateTrend(
            transactions: [tx],
            grouping: .day,
            interval: defaultInterval,
            preferredCurrency: .usd,
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }

    @Test func noCategoryTransactions_excluded() {
        let tx = makeTransaction(
            amount: -100,
            date: date(2026, 3, 5)
        )

        let result = NeedTrendHelper.calculateTrend(
            transactions: [tx],
            grouping: .day,
            interval: defaultInterval,
            preferredCurrency: .usd,
            converter: MockCurrencyConverter()
        )

        #expect(result.isEmpty)
    }

    @Test func multiCurrency_conversionApplied() {
        let cat = makeCategory(name: "Food")
        let sub = makeSubcategory(name: "Groceries", category: cat, need: .essential)
        let tx = makeTransaction(
            amount: -50,
            date: date(2026, 3, 5),
            currencyCode: "EUR",
            category: cat,
            subcategory: sub
        )
        tx.preferredCurrencyCode = "EUR" // Different from target "USD"

        var converter = MockCurrencyConverter()
        converter.fixedRate = 2.0

        let result = NeedTrendHelper.calculateTrend(
            transactions: [tx],
            grouping: .day,
            interval: defaultInterval,
            preferredCurrency: .usd,
            converter: converter
        )

        #expect(result.count == 1)
        #expect(result[0].essential == 100) // 50 * 2.0
    }

    @Test func unclassified_whenSubcategoryHasNoNeed() {
        let cat = makeCategory(name: "Food")
        // Subcategory with default unclassified need
        let sub = makeSubcategory(name: "Misc", category: cat, need: .unclassified)
        let tx = makeTransaction(
            amount: -75,
            date: date(2026, 3, 5),
            category: cat,
            subcategory: sub
        )

        let result = NeedTrendHelper.calculateTrend(
            transactions: [tx],
            grouping: .day,
            interval: defaultInterval,
            preferredCurrency: .usd,
            converter: MockCurrencyConverter()
        )

        #expect(result.count == 1)
        #expect(result[0].unclassified == 75)
        #expect(result[0].essential == 0)
        #expect(result[0].priority == 0)
        #expect(result[0].optional == 0)
    }
}

/*
Tests generated:
1. empty_returnsEmpty - Empty input returns empty array
2. essentialNeed_onlyEssentialHasValue - Essential need mapped to essential field only
3. mixedNeeds_correctDistribution - Multiple need types distributed correctly with total check
4. incomeTransactions_excluded - Income categories are filtered out
5. balanceAdjustments_excluded - Balance adjustments are filtered out
6. noCategoryTransactions_excluded - Transactions without category are filtered out
7. multiCurrency_conversionApplied - Currency conversion uses MockCurrencyConverter rate
8. unclassified_whenSubcategoryHasNoNeed - Unclassified need goes to unclassified bucket

Cases NOT covered (require more context):
- TrendGrouping .week and .month bucketing (tested in TrendGroupingTests)
- Transaction without subcategory defaults to .unclassified via effectiveNeed
- Multiple dates producing sorted output (ordering verification)
*/
