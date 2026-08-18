//
//  DistributionPreviousPeriodCalculatorTests.swift
//  YalaTests
//
//  Regresión p20-15: Distribución no debe comparar lun→hoy contra la
//  semana calendario anterior completa. Sin el recorte, 30+70 = 100.
//

import Foundation
import Testing

@testable import Yala

struct DistributionPreviousPeriodCalculatorTests {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima")!
        c.firstWeekday = 2
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func expense(amount: Double, on day: Date, category: YalaCategory) -> TransactionItem {
        let tx = TransactionItem(
            date: day,
            amount: -amount,
            currencyCode: "PEN",
            note: "",
            category: category,
            amountInPreferredCurrency: -amount
        )
        tx.preferredCurrencyCode = "PEN"
        return tx
    }

    @Test("thisWeek+month: previo lun-mié 30 + jue-dom 70 → total 30, no 100")
    func previousCategoryTotal_thisWeek_truncaAlWeekdayEquivalente() {
        let food = YalaCategory(name: "Food", colorHex: "#000000", isIncome: false)
        // Semana actual lun 6-jul → …; datos lun-mié. Previo = lun 29-jun → lun 6-jul.
        let currentInterval = DateInterval(start: date(2026, 7, 6), end: date(2026, 7, 9))
        let previousInterval = DateInterval(start: date(2026, 6, 29), end: date(2026, 7, 6))
        let currentDates = [date(2026, 7, 6), date(2026, 7, 7), date(2026, 7, 8)]

        let previous = [
            expense(amount: 10, on: date(2026, 6, 29), category: food),
            expense(amount: 10, on: date(2026, 6, 30), category: food),
            expense(amount: 10, on: date(2026, 7, 1), category: food),
            expense(amount: 20, on: date(2026, 7, 2), category: food),
            expense(amount: 20, on: date(2026, 7, 3), category: food),
            expense(amount: 20, on: date(2026, 7, 4), category: food),
            expense(amount: 10, on: date(2026, 7, 5), category: food),
        ]

        let total = DistributionPreviousPeriodCalculator.previousCategoryTotal(
            previousTransactions: previous,
            currentDates: currentDates,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: .thisWeek,
            comparisonMode: .month,
            currencyCode: "PEN"
        )

        #expect(total == 30)
        #expect(total != 100)

        // Mutación: si el gate no aplica (cerrado), se quedan los 100.
        let unaligned = DistributionPreviousPeriodCalculator.previousCategoryTotal(
            previousTransactions: previous,
            currentDates: currentDates,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: .lastMonth,
            comparisonMode: .month,
            currencyCode: "PEN"
        )
        #expect(unaligned == 100)
    }
}
