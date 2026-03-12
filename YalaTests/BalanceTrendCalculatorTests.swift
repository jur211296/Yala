//
//  BalanceTrendCalculatorTests.swift
//  YalaTests
//
//  Unit tests for BalanceTrendCalculator.calculateTrend pure logic.
//

import Foundation
import Testing

@testable import Yala

struct BalanceTrendCalculatorTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#FF0000", isIncome: isIncome)
    }

    private func makeTransaction(
        amount: Double,
        date: Date,
        currencyCode: String = "USD",
        category: YalaCategory? = nil
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
        return tx
    }

    /// Creates a DateInterval spanning the given number of days starting from the base date.
    private func makeInterval(from base: Date, days: Int) -> DateInterval {
        let start = calendar.startOfDay(for: base)
        let end = calendar.date(byAdding: .day, value: days, to: start)!
        return DateInterval(start: start, end: end)
    }

    /// Creates a fixed date for deterministic testing.
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return calendar.date(from: components)!
    }

    // MARK: - 1. Empty transactions

    @Test func calculateTrend_emptyTransactions_returnsEmptyResult() {
        let interval = makeInterval(from: date(2026, 1, 1), days: 7)

        let result = BalanceTrendCalculator.calculateTrend(
            transactions: [],
            grouping: .day,
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        // With gap-filling, empty transactions still produce date entries
        // but all values should be zero
        for point in result {
            #expect(point.income == 0)
            #expect(point.expense == 0)
            #expect(point.balance == 0)
        }
    }

    // MARK: - 2. Single expense

    @Test func calculateTrend_singleExpense_runningBalanceIsNegative() {
        let expenseDate = date(2026, 1, 3)
        let category = makeCategory(name: "Food")
        let tx = makeTransaction(amount: -100, date: expenseDate, category: category)

        let interval = makeInterval(from: date(2026, 1, 1), days: 5)

        let result = BalanceTrendCalculator.calculateTrend(
            transactions: [tx],
            grouping: .day,
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        // Find the point for Jan 3
        let jan3Start = calendar.startOfDay(for: expenseDate)
        let pointOnDate = result.first { $0.date == jan3Start }

        #expect(pointOnDate != nil)
        #expect(pointOnDate!.expense == 100)
        #expect(pointOnDate!.income == 0)
        #expect(pointOnDate!.balance == -100)
    }

    // MARK: - 3. Single income

    @Test func calculateTrend_singleIncome_runningBalanceIsPositive() {
        let incomeDate = date(2026, 1, 2)
        let category = makeCategory(name: "Salary", isIncome: true)
        let tx = makeTransaction(amount: 500, date: incomeDate, category: category)

        let interval = makeInterval(from: date(2026, 1, 1), days: 4)

        let result = BalanceTrendCalculator.calculateTrend(
            transactions: [tx],
            grouping: .day,
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        let jan2Start = calendar.startOfDay(for: incomeDate)
        let pointOnDate = result.first { $0.date == jan2Start }

        #expect(pointOnDate != nil)
        #expect(pointOnDate!.income == 500)
        #expect(pointOnDate!.expense == 0)
        #expect(pointOnDate!.balance == 500)
    }

    // MARK: - 4. Mixed transactions cumulative balance

    @Test func calculateTrend_mixedTransactions_cumulativeRunningBalance() {
        let category = makeCategory(name: "Food")
        let incomeCategory = makeCategory(name: "Salary", isIncome: true)

        // Day 1: +1000 income
        let tx1 = makeTransaction(amount: 1000, date: date(2026, 2, 1), category: incomeCategory)
        // Day 2: -300 expense
        let tx2 = makeTransaction(amount: -300, date: date(2026, 2, 2), category: category)
        // Day 3: -200 expense
        let tx3 = makeTransaction(amount: -200, date: date(2026, 2, 3), category: category)

        let interval = makeInterval(from: date(2026, 2, 1), days: 4)

        let result = BalanceTrendCalculator.calculateTrend(
            transactions: [tx1, tx2, tx3],
            grouping: .day,
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        let sorted = result.sorted { $0.date < $1.date }

        // Day 1: balance = +1000
        #expect(sorted[0].balance == 1000)
        // Day 2: balance = 1000 - 300 = 700
        #expect(sorted[1].balance == 700)
        // Day 3: balance = 700 - 200 = 500
        #expect(sorted[2].balance == 500)
    }

    // MARK: - 5. Multi-currency conversion

    @Test func calculateTrend_multiCurrency_usesConverterWithFixedRate() {
        let category = makeCategory(name: "Food")
        // Transaction in EUR, target currency is USD
        // preferredCurrencyCode is EUR (different from target "USD"), so converter is used
        let tx = TransactionItem(
            date: date(2026, 3, 1),
            amount: -50,
            currencyCode: "EUR",
            note: "",
            category: category,
            tags: [],
            amountInPreferredCurrency: -50
        )
        tx.preferredCurrencyCode = "EUR"  // Differs from target "USD" -> converter path

        var converter = MockCurrencyConverter()
        converter.fixedRate = 2.0  // 1 EUR = 2 USD

        let interval = makeInterval(from: date(2026, 3, 1), days: 2)

        let result = BalanceTrendCalculator.calculateTrend(
            transactions: [tx],
            grouping: .day,
            interval: interval,
            currencyCode: "USD",
            converter: converter
        )

        let point = result.first { $0.date == calendar.startOfDay(for: date(2026, 3, 1)) }
        #expect(point != nil)
        // abs(-50) * 2.0 = 100, then negated because original amount < 0 -> expense = 100
        #expect(point!.expense == 100)
        #expect(point!.balance == -100)
    }

    // MARK: - 6. Transactions without category are excluded

    @Test func calculateTrend_transactionWithoutCategory_isExcluded() {
        // Transaction with no category
        let tx = makeTransaction(amount: -100, date: date(2026, 1, 1), category: nil)

        let interval = makeInterval(from: date(2026, 1, 1), days: 2)

        let result = BalanceTrendCalculator.calculateTrend(
            transactions: [tx],
            grouping: .day,
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        // All points should have zero values since the only transaction was excluded
        for point in result {
            #expect(point.income == 0)
            #expect(point.expense == 0)
            #expect(point.balance == 0)
        }
    }

    // MARK: - 7. Date gap filling

    @Test func calculateTrend_dateGapFilling_gapDaysCarryRunningBalance() {
        let category = makeCategory(name: "Food")
        // Day 1 (Jan 1): -100
        let tx1 = makeTransaction(amount: -100, date: date(2026, 1, 1), category: category)
        // Day 4 (Jan 4): -50 (gap on Jan 2 and Jan 3)
        let tx2 = makeTransaction(amount: -50, date: date(2026, 1, 4), category: category)

        let interval = makeInterval(from: date(2026, 1, 1), days: 5)

        let result = BalanceTrendCalculator.calculateTrend(
            transactions: [tx1, tx2],
            grouping: .day,
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        let sorted = result.sorted { $0.date < $1.date }

        // Should have 5 days of data points
        #expect(sorted.count == 5)

        // Jan 1: balance = -100
        #expect(sorted[0].balance == -100)
        // Jan 2: gap, no new transactions, balance stays at -100
        #expect(sorted[1].balance == -100)
        #expect(sorted[1].income == 0)
        #expect(sorted[1].expense == 0)
        // Jan 3: gap, balance stays at -100
        #expect(sorted[2].balance == -100)
        // Jan 4: -50 more, balance = -150
        #expect(sorted[3].balance == -150)
    }

    // MARK: - 8. Monthly grouping aggregation

    @Test func calculateTrend_monthlyGrouping_aggregatesWithinMonth() {
        let category = makeCategory(name: "Food")
        let incomeCategory = makeCategory(name: "Salary", isIncome: true)

        // Multiple transactions in January
        let tx1 = makeTransaction(amount: -100, date: date(2026, 1, 5), category: category)
        let tx2 = makeTransaction(amount: -200, date: date(2026, 1, 20), category: category)
        let tx3 = makeTransaction(amount: 500, date: date(2026, 1, 15), category: incomeCategory)

        // One transaction in February
        let tx4 = makeTransaction(amount: -50, date: date(2026, 2, 10), category: category)

        // Interval spanning Jan 1 to Mar 1 (2 months)
        let start = date(2026, 1, 1)
        let end = date(2026, 3, 1)
        let interval = DateInterval(start: calendar.startOfDay(for: start), end: calendar.startOfDay(for: end))

        let result = BalanceTrendCalculator.calculateTrend(
            transactions: [tx1, tx2, tx3, tx4],
            grouping: .month,
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        let sorted = result.sorted { $0.date < $1.date }

        // Should have 2 monthly buckets (Jan and Feb)
        #expect(sorted.count == 2)

        // January: income=500, expense=300, balance = 500-300 = 200
        #expect(sorted[0].income == 500)
        #expect(sorted[0].expense == 300)
        #expect(sorted[0].balance == 200)

        // February: income=0, expense=50, running balance = 200 + (0-50) = 150
        #expect(sorted[1].income == 0)
        #expect(sorted[1].expense == 50)
        #expect(sorted[1].balance == 150)
    }
}

/*
Tests generated:
1. calculateTrend_emptyTransactions_returnsEmptyResult - Empty input produces zero-valued points
2. calculateTrend_singleExpense_runningBalanceIsNegative - Single expense yields negative balance
3. calculateTrend_singleIncome_runningBalanceIsPositive - Single income yields positive balance
4. calculateTrend_mixedTransactions_cumulativeRunningBalance - Income + expenses accumulate correctly
5. calculateTrend_multiCurrency_usesConverterWithFixedRate - Currency conversion via MockCurrencyConverter
6. calculateTrend_transactionWithoutCategory_isExcluded - nil category skipped (guard let)
7. calculateTrend_dateGapFilling_gapDaysCarryRunningBalance - Gap days preserve running balance
8. calculateTrend_monthlyGrouping_aggregatesWithinMonth - Monthly buckets aggregate correctly

Cases NOT covered (require more context):
- Weekly grouping (similar to monthly, omitted for brevity)
- Transactions exactly on interval boundaries (start/end edge)
- Very large datasets (performance, not unit logic)
*/
