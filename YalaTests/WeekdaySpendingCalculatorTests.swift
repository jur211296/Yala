//
//  WeekdaySpendingCalculatorTests.swift
//  YalaTests
//
//  Unit tests for WeekdaySpendingCalculator pure logic.
//

import Foundation
import Testing

@testable import Yala

struct WeekdaySpendingCalculatorTests {

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

    /// Creates a date for a specific weekday (1=Sun..7=Sat) in a recent week.
    private func dateForWeekday(_ weekday: Int) -> Date {
        // Find next occurrence of the given weekday from a fixed base date
        let base = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))! // Sunday
        var current = base
        for _ in 0..<7 {
            if calendar.component(.weekday, from: current) == weekday {
                return current
            }
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return base
    }

    // MARK: - Tests

    @Test func empty_returnsSevenEntriesAllZero() {
        let result = WeekdaySpendingCalculator.calculate(
            transactions: [],
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.count == 7)
        for entry in result {
            #expect(entry.total == 0)
            #expect(entry.count == 0)
            #expect(entry.average == 0)
        }
    }

    @Test func singleExpense_onMonday_weekday2HasTotal() {
        let cat = makeCategory(name: "Food")
        let monday = dateForWeekday(2) // Monday
        let tx = makeTransaction(amount: -50, date: monday, category: cat)

        let result = WeekdaySpendingCalculator.calculate(
            transactions: [tx],
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        let mondayEntry = result.first { $0.weekday == 2 }!
        #expect(mondayEntry.total == 50)
        #expect(mondayEntry.count == 1)

        // All other weekdays should be zero
        for entry in result where entry.weekday != 2 {
            #expect(entry.total == 0)
            #expect(entry.count == 0)
        }
    }

    @Test func incomeTransactions_excluded() {
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let monday = dateForWeekday(2)
        let tx = makeTransaction(amount: 5000, date: monday, category: incomeCat)

        let result = WeekdaySpendingCalculator.calculate(
            transactions: [tx],
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        for entry in result {
            #expect(entry.total == 0)
            #expect(entry.count == 0)
        }
    }

    @Test func balanceAdjustments_excluded() {
        let cat = makeCategory(name: "Food")
        let monday = dateForWeekday(2)
        let tx = makeTransaction(
            amount: -100,
            date: monday,
            category: cat,
            balanceAdjustmentType: "manual"
        )

        let result = WeekdaySpendingCalculator.calculate(
            transactions: [tx],
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        for entry in result {
            #expect(entry.total == 0)
        }
    }

    @Test func noCategoryTransactions_excluded() {
        let monday = dateForWeekday(2)
        let tx = makeTransaction(amount: -100, date: monday)

        let result = WeekdaySpendingCalculator.calculate(
            transactions: [tx],
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        for entry in result {
            #expect(entry.total == 0)
        }
    }

    @Test func multipleExpenses_sameWeekday_summed() {
        let cat = makeCategory(name: "Food")
        let wednesday = dateForWeekday(4) // Wednesday
        let tx1 = makeTransaction(amount: -30, date: wednesday, category: cat)
        let tx2 = makeTransaction(amount: -70, date: wednesday, category: cat)

        let result = WeekdaySpendingCalculator.calculate(
            transactions: [tx1, tx2],
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        let wedEntry = result.first { $0.weekday == 4 }!
        #expect(wedEntry.total == 100)
        #expect(wedEntry.count == 2)
        #expect(wedEntry.average == 50)
    }

    @Test func multiCurrency_conversionApplied() {
        let cat = makeCategory(name: "Food")
        let monday = dateForWeekday(2)
        let tx = makeTransaction(amount: -50, date: monday, currencyCode: "EUR", category: cat)
        tx.preferredCurrencyCode = "EUR" // Different from target "USD"

        var converter = MockCurrencyConverter()
        converter.fixedRate = 2.0

        let result = WeekdaySpendingCalculator.calculate(
            transactions: [tx],
            currencyCode: "USD",
            converter: converter
        )

        let mondayEntry = result.first { $0.weekday == 2 }!
        #expect(mondayEntry.total == 100) // 50 * 2.0
    }

    @Test func allSevenDays_haveCorrectWeekdayNumbers() {
        let result = WeekdaySpendingCalculator.calculate(
            transactions: [],
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        let weekdays = result.map { $0.weekday }
        #expect(weekdays == [1, 2, 3, 4, 5, 6, 7])
    }
}

/*
Tests generated:
1. empty_returnsSevenEntriesAllZero - Empty input returns 7 entries with zero values
2. singleExpense_onMonday_weekday2HasTotal - Single expense appears on correct weekday
3. incomeTransactions_excluded - Income categories are filtered out
4. balanceAdjustments_excluded - Balance adjustments are filtered out
5. noCategoryTransactions_excluded - Transactions without category are filtered out
6. multipleExpenses_sameWeekday_summed - Multiple expenses on same day are summed
7. multiCurrency_conversionApplied - Currency conversion uses MockCurrencyConverter rate
8. allSevenDays_haveCorrectWeekdayNumbers - Output always has weekdays 1-7

Cases NOT covered (require more context):
- Locale-specific weekday ordering (would need injecting Calendar)
*/
