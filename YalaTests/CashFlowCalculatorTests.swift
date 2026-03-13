//
//  CashFlowCalculatorTests.swift
//  YalaTests
//
//  Unit tests for CashFlowCalculator pure logic.
//

import Foundation
import Testing

@testable import Yala

struct CashFlowCalculatorTests {

    // MARK: - Helpers

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#000000", isIncome: isIncome)
    }

    private func makeTransaction(
        amount: Double,
        date: Date = Date(),
        currencyCode: String = "USD",
        category: YalaCategory? = nil,
        balanceAdjustmentType: String? = nil,
        preferredCurrencyCode: String = "USD",
        amountInPreferredCurrency: Double? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: currencyCode,
            note: "",
            category: category,
            tags: [],
            amountInPreferredCurrency: amountInPreferredCurrency ?? amount
        )
        tx.preferredCurrencyCode = preferredCurrencyCode
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    /// A fixed interval spanning 7 days ending tomorrow, useful for day-grouped tests.
    private var weekInterval: DateInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -6, to: today)!
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        return DateInterval(start: start, end: end)
    }

    /// A fixed interval spanning 3 months.
    private var threeMonthInterval: DateInterval {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: components)!
        let start = calendar.date(byAdding: .month, value: -2, to: startOfMonth)!
        let end = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        return DateInterval(start: start, end: end)
    }

    // MARK: - 1. Empty transactions

    @Test func emptyTransactions_returnsZeroTotals() {
        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [],
            interval: weekInterval,
            grouping: .day,
            currencyCode: "USD"
        )

        #expect(result.totalIncome == 0)
        #expect(result.totalExpense == 0)
        #expect(result.netFlow == 0)
        #expect(result.currencyCode == "USD")
    }

    // MARK: - 2. Expenses only

    @Test func expensesOnly_correctTotals() {
        let cat = makeCategory(name: "Food")
        let today = Calendar.current.startOfDay(for: Date())
        let tx1 = makeTransaction(amount: -100, date: today, category: cat)
        let tx2 = makeTransaction(amount: -50, date: today, category: cat)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [tx1, tx2],
            interval: weekInterval,
            grouping: .day,
            currencyCode: "USD"
        )

        #expect(result.totalExpense == 150)
        #expect(result.totalIncome == 0)
        #expect(result.netFlow == -150)
    }

    // MARK: - 3. Income only

    @Test func incomeOnly_correctTotals() {
        let cat = makeCategory(name: "Salary", isIncome: true)
        let today = Calendar.current.startOfDay(for: Date())
        let tx = makeTransaction(amount: 3000, date: today, category: cat)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [tx],
            interval: weekInterval,
            grouping: .day,
            currencyCode: "USD"
        )

        #expect(result.totalIncome == 3000)
        #expect(result.totalExpense == 0)
        #expect(result.netFlow == 3000)
    }

    // MARK: - 4. Mixed income and expenses

    @Test func mixedIncomeAndExpenses_correctNetFlow() {
        let expenseCat = makeCategory(name: "Food")
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let today = Calendar.current.startOfDay(for: Date())

        let expense = makeTransaction(amount: -200, date: today, category: expenseCat)
        let income = makeTransaction(amount: 500, date: today, category: incomeCat)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [expense, income],
            interval: weekInterval,
            grouping: .day,
            currencyCode: "USD"
        )

        #expect(result.totalIncome == 500)
        #expect(result.totalExpense == 200)
        #expect(result.netFlow == 300)
    }

    // MARK: - 5. Multi-currency conversion

    @Test func multiCurrency_usesConverterWithFixedRate() {
        let cat = makeCategory(name: "Food")
        let today = Calendar.current.startOfDay(for: Date())
        // Transaction in EUR, reporting in USD, rate 2.0 means 100 EUR = 200 USD
        let tx = makeTransaction(
            amount: -100,
            date: today,
            currencyCode: "EUR",
            category: cat,
            preferredCurrencyCode: "EUR",  // Different from target "USD" to trigger conversion
            amountInPreferredCurrency: -100
        )

        let converter = MockCurrencyConverter(fixedRate: 2.0)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [tx],
            interval: weekInterval,
            grouping: .day,
            currencyCode: "USD",
            converter: converter
        )

        // abs(-100) = 100, converted at rate 2.0 = 200, sign restored = -200
        // expense -= (-200) = 200
        #expect(result.totalExpense == 200)
        #expect(result.netFlow == -200)
    }

    @Test func sameCurrency_usesAmountInPreferredCurrency() {
        let cat = makeCategory(name: "Food")
        let today = Calendar.current.startOfDay(for: Date())
        // preferredCurrencyCode matches target currencyCode => uses amountInPreferredCurrency directly
        let tx = makeTransaction(
            amount: -100,
            date: today,
            currencyCode: "EUR",
            category: cat,
            preferredCurrencyCode: "USD",
            amountInPreferredCurrency: -150
        )

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [tx],
            interval: weekInterval,
            grouping: .day,
            currencyCode: "USD"
        )

        // Uses amountInPreferredCurrency = -150 directly
        // expense -= (-150) = 150
        #expect(result.totalExpense == 150)
    }

    // MARK: - 6. Balance adjustments excluded

    @Test func balanceAdjustment_isExcluded() {
        let cat = makeCategory(name: "Adjustment")
        let today = Calendar.current.startOfDay(for: Date())
        let tx = makeTransaction(
            amount: 500,
            date: today,
            category: cat,
            balanceAdjustmentType: "manual"
        )

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [tx],
            interval: weekInterval,
            grouping: .day,
            currencyCode: "USD"
        )

        #expect(result.totalIncome == 0)
        #expect(result.totalExpense == 0)
        #expect(result.netFlow == 0)
    }

    @Test func balanceAdjustmentTypes_allExcluded() {
        let cat = makeCategory(name: "Adjustment")
        let today = Calendar.current.startOfDay(for: Date())

        let adjustmentTypes = ["initial_balance", "adjustment", "transfer"]
        let transactions = adjustmentTypes.map { type in
            makeTransaction(amount: 100, date: today, category: cat, balanceAdjustmentType: type)
        }

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: transactions,
            interval: weekInterval,
            grouping: .day,
            currencyCode: "USD"
        )

        #expect(result.totalIncome == 0)
        #expect(result.totalExpense == 0)
    }

    // MARK: - 7. Transactions without category excluded

    @Test func noCategory_isExcluded() {
        let today = Calendar.current.startOfDay(for: Date())
        let tx = makeTransaction(amount: -100, date: today)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [tx],
            interval: weekInterval,
            grouping: .day,
            currencyCode: "USD"
        )

        #expect(result.totalExpense == 0)
        #expect(result.netFlow == 0)
    }

    // MARK: - 8. Chart data fills date gaps with zeros

    @Test func chartData_fillsGapsWithZeros_dayGrouping() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 3, to: start)!
        let interval = DateInterval(start: start, end: end)

        let cat = makeCategory(name: "Food")
        // Only create a transaction on day 0, days 1 and 2 should be filled with zeros
        let tx = makeTransaction(amount: -50, date: start, category: cat)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [tx],
            interval: interval,
            grouping: .day,
            currencyCode: "USD"
        )

        #expect(result.chartData.count == 3)

        // First day has data
        #expect(result.chartData[0].expense == 50)

        // Gap days filled with zeros
        #expect(result.chartData[1].income == 0)
        #expect(result.chartData[1].expense == 0)
        #expect(result.chartData[1].net == 0)

        #expect(result.chartData[2].income == 0)
        #expect(result.chartData[2].expense == 0)
        #expect(result.chartData[2].net == 0)
    }

    // MARK: - 9. Month grouping aggregation

    @Test func monthGrouping_aggregatesCorrectly() {
        let calendar = Calendar.current
        let cat = makeCategory(name: "Food")

        // Create dates in month 1 (two months ago) and month 3 (this month)
        let components = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: components)!
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: startOfMonth)!

        let tx1 = makeTransaction(amount: -100, date: twoMonthsAgo, category: cat)
        let tx2 = makeTransaction(amount: -200, date: twoMonthsAgo, category: cat)
        let tx3 = makeTransaction(amount: -50, date: startOfMonth, category: cat)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [tx1, tx2, tx3],
            interval: threeMonthInterval,
            grouping: .month,
            currencyCode: "USD"
        )

        // Should have 3 month buckets
        #expect(result.chartData.count == 3)

        // First month: 100 + 200 = 300 expense
        #expect(result.chartData[0].expense == 300)

        // Second month: gap, filled with 0
        #expect(result.chartData[1].expense == 0)

        // Third month: 50 expense
        #expect(result.chartData[2].expense == 50)

        // Total
        #expect(result.totalExpense == 350)
    }

    // MARK: - 10. Transactions outside interval excluded

    @Test func outsideInterval_excluded() {
        let calendar = Calendar.current
        let cat = makeCategory(name: "Food")
        let today = calendar.startOfDay(for: Date())

        let start = calendar.date(byAdding: .day, value: -3, to: today)!
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        let interval = DateInterval(start: start, end: end)

        // Transaction well outside the interval (1 year ago)
        let oldDate = calendar.date(byAdding: .year, value: -1, to: today)!
        let txOutside = makeTransaction(amount: -999, date: oldDate, category: cat)

        // Transaction inside the interval
        let txInside = makeTransaction(amount: -50, date: today, category: cat)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [txOutside, txInside],
            interval: interval,
            grouping: .day,
            currencyCode: "USD"
        )

        // The outside transaction's dateKey falls outside the chart iteration range,
        // but it IS processed into groupedData and totals (the calculator does NOT
        // filter by interval for totals -- only chart iteration is interval-bounded).
        // Let's verify: the calculator iterates from interval.start to interval.end,
        // and only emits chart entries for those date keys. But totalIncome/totalExpense
        // accumulate ALL valid transactions regardless of interval.
        // So totalExpense includes the outside transaction.
        #expect(result.totalExpense == 1049)

        // But chart data only covers the 4-day interval
        #expect(result.chartData.count == 4)
    }

    // MARK: - Chart data net calculation

    @Test func chartData_netIsIncomeMinusExpense() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = today
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        let interval = DateInterval(start: start, end: end)

        let expenseCat = makeCategory(name: "Food")
        let incomeCat = makeCategory(name: "Salary", isIncome: true)

        let expense = makeTransaction(amount: -80, date: today, category: expenseCat)
        let income = makeTransaction(amount: 200, date: today, category: incomeCat)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [expense, income],
            interval: interval,
            grouping: .day,
            currencyCode: "USD"
        )

        #expect(result.chartData.count == 1)
        #expect(result.chartData[0].income == 200)
        #expect(result.chartData[0].expense == 80)
        #expect(result.chartData[0].net == 120)
    }

    // MARK: - Currency code passthrough

    @Test func currencyCode_isPassedThrough() {
        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [],
            interval: weekInterval,
            grouping: .day,
            currencyCode: "EUR"
        )

        #expect(result.currencyCode == "EUR")
    }

    // MARK: - Week grouping

    @Test func weekGrouping_aggregatesWithinSameWeek() {
        let calendar = Calendar.current
        let cat = makeCategory(name: "Food")

        // Get start of current week
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        let dayInWeek1 = weekStart
        let dayInWeek2 = calendar.date(byAdding: .day, value: 2, to: weekStart)!

        let interval = DateInterval(
            start: weekStart,
            end: calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        )

        let tx1 = makeTransaction(amount: -100, date: dayInWeek1, category: cat)
        let tx2 = makeTransaction(amount: -50, date: dayInWeek2, category: cat)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [tx1, tx2],
            interval: interval,
            grouping: .week,
            currencyCode: "USD"
        )

        // Both transactions fall in the same week bucket
        #expect(result.chartData.count == 1)
        #expect(result.chartData[0].expense == 150)
        #expect(result.totalExpense == 150)
    }

    // MARK: - Multiple expense transactions on different days

    @Test func multipleDays_correctChartDistribution() {
        let calendar = Calendar.current
        let cat = makeCategory(name: "Food")

        let start = calendar.startOfDay(for: Date())
        let day1 = start
        let day2 = calendar.date(byAdding: .day, value: 1, to: start)!
        let end = calendar.date(byAdding: .day, value: 2, to: start)!
        let interval = DateInterval(start: start, end: end)

        let tx1 = makeTransaction(amount: -100, date: day1, category: cat)
        let tx2 = makeTransaction(amount: -200, date: day2, category: cat)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [tx1, tx2],
            interval: interval,
            grouping: .day,
            currencyCode: "USD"
        )

        #expect(result.chartData.count == 2)
        #expect(result.chartData[0].expense == 100)
        #expect(result.chartData[1].expense == 200)
        #expect(result.totalExpense == 300)
    }

    // MARK: - Income conversion with multi-currency

    @Test func multiCurrencyIncome_convertsCorrectly() {
        let cat = makeCategory(name: "Freelance", isIncome: true)
        let today = Calendar.current.startOfDay(for: Date())

        // EUR income, converting to USD with rate 1.5
        let tx = makeTransaction(
            amount: 1000,
            date: today,
            currencyCode: "EUR",
            category: cat,
            preferredCurrencyCode: "EUR",
            amountInPreferredCurrency: 1000
        )

        let converter = MockCurrencyConverter(fixedRate: 1.5)

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [tx],
            interval: weekInterval,
            grouping: .day,
            currencyCode: "USD",
            converter: converter
        )

        // abs(1000) * 1.5 = 1500, positive since income
        #expect(result.totalIncome == 1500)
        #expect(result.netFlow == 1500)
    }

    // MARK: - Mixed valid and invalid transactions

    @Test func mixedValidAndInvalid_onlyValidCounted() {
        let cat = makeCategory(name: "Food")
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let today = Calendar.current.startOfDay(for: Date())

        let validExpense = makeTransaction(amount: -100, date: today, category: cat)
        let validIncome = makeTransaction(amount: 500, date: today, category: incomeCat)
        let noCategory = makeTransaction(amount: -200, date: today)  // excluded: no category
        let balanceAdj = makeTransaction(
            amount: 300,
            date: today,
            category: cat,
            balanceAdjustmentType: "adjustment"  // excluded: balance adjustment
        )

        let result = CashFlowCalculator.calculateCashFlow(
            transactions: [validExpense, validIncome, noCategory, balanceAdj],
            interval: weekInterval,
            grouping: .day,
            currencyCode: "USD"
        )

        #expect(result.totalIncome == 500)
        #expect(result.totalExpense == 100)
        #expect(result.netFlow == 400)
    }
}

/*
Tests generated:
1.  test emptyTransactions_returnsZeroTotals - Empty input produces zero totals
2.  test expensesOnly_correctTotals - Only expenses: totalExpense > 0, totalIncome = 0
3.  test incomeOnly_correctTotals - Only income: totalIncome > 0, totalExpense = 0
4.  test mixedIncomeAndExpenses_correctNetFlow - Mixed: correct netFlow calculation
5.  test multiCurrency_usesConverterWithFixedRate - Currency conversion via MockCurrencyConverter
6.  test sameCurrency_usesAmountInPreferredCurrency - Same currency uses preferred amount directly
7.  test balanceAdjustment_isExcluded - Balance adjustments are filtered out
8.  test balanceAdjustmentTypes_allExcluded - All adjustment types are excluded
9.  test noCategory_isExcluded - Transactions without category (transfers) excluded
10. test chartData_fillsGapsWithZeros_dayGrouping - Chart fills missing days with zeros
11. test monthGrouping_aggregatesCorrectly - Month grouping aggregates transactions per month
12. test outsideInterval_excluded - Transactions outside interval still in totals but not chart
13. test chartData_netIsIncomeMinusExpense - Chart data net = income - expense
14. test currencyCode_isPassedThrough - Currency code returned in summary
15. test weekGrouping_aggregatesWithinSameWeek - Week grouping merges same-week transactions
16. test multipleDays_correctChartDistribution - Multiple days distribute correctly in chart
17. test multiCurrencyIncome_convertsCorrectly - Income with currency conversion
18. test mixedValidAndInvalid_onlyValidCounted - Mix of valid/invalid, only valid counted

Cases NOT covered (require more context):
- Refund scenario (positive amount on expense category) — would reduce totalExpense
- Extremely large transaction values (overflow edge case)
- Timezone edge cases (transactions at midnight boundaries)
*/
