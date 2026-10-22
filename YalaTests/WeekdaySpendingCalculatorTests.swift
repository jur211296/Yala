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

    // MARK: - axisLabel + weekdayLongName (PP2-06c)

    @Test("axisLabel is 2 letters capitalised")
    func axisLabelIsTwoLetters() {
        for weekday in 1...7 {
            let entry = WeekdaySpending(weekday: weekday, total: 0, count: 0, dayOccurrences: 0)
            let label = entry.axisLabel
            #expect(label.count == 2)
            #expect(label.first?.isUppercase == true)
        }
    }

    @Test("weekdayLongName returns a non-empty capitalised string")
    func weekdayLongNameCapitalised() {
        for weekday in 1...7 {
            let entry = WeekdaySpending(weekday: weekday, total: 0, count: 0, dayOccurrences: 0)
            let name = entry.weekdayLongName
            #expect(!name.isEmpty)
            #expect(name.first?.isUppercase == true)
        }
    }

    @Test("Weekday order rotates according to firstWeekday (sunday-first)")
    func weekdayOrderSundayFirst() {
        #expect(WeekdayBarChart.weekdayOrder(firstWeekday: 1) == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test("Weekday order rotates according to firstWeekday (monday-first)")
    func weekdayOrderMondayFirst() {
        #expect(WeekdayBarChart.weekdayOrder(firstWeekday: 2) == [2, 3, 4, 5, 6, 7, 1])
    }

    @Test("Weekday order clamps out-of-range firstWeekday")
    func weekdayOrderClampsInvalidInput() {
        #expect(WeekdayBarChart.weekdayOrder(firstWeekday: 0).count == 7)
        #expect(WeekdayBarChart.weekdayOrder(firstWeekday: 8).count == 7)
    }

    // MARK: - Helpers

    private let calendar = Calendar.current

    /// A 7-day interval starting on Sunday March 1, 2026
    private let weekInterval = DateInterval(
        start: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!,
        end: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 8))!
    )

    /// A 28-day interval (4 full weeks) starting March 1, 2026
    private let monthInterval = DateInterval(
        start: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!,
        end: Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 29))!
    )

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

    /// Creates a date for a specific weekday (1=Sun..7=Sat) in the first week of March 2026.
    private func dateForWeekday(_ weekday: Int) -> Date {
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
            interval: weekInterval,
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
            interval: weekInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        let mondayEntry = result.first { $0.weekday == 2 }!
        #expect(mondayEntry.total == 50)
        #expect(mondayEntry.count == 1)
        // 1 Monday in a 7-day interval → average = 50/1 = 50
        #expect(mondayEntry.average == 50)

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
            interval: weekInterval,
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
            interval: weekInterval,
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
            interval: weekInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        for entry in result {
            #expect(entry.total == 0)
        }
    }

    @Test func multipleExpenses_sameWeekday_averagePerDay() {
        let cat = makeCategory(name: "Food")
        let wednesday = dateForWeekday(4) // Wednesday
        let tx1 = makeTransaction(amount: -30, date: wednesday, category: cat)
        let tx2 = makeTransaction(amount: -70, date: wednesday, category: cat)

        let result = WeekdaySpendingCalculator.calculate(
            transactions: [tx1, tx2],
            interval: weekInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        let wedEntry = result.first { $0.weekday == 4 }!
        #expect(wedEntry.total == 100)
        #expect(wedEntry.count == 2)
        // 1 Wednesday in 7-day interval → average = 100/1 = 100
        #expect(wedEntry.average == 100)
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
            interval: weekInterval,
            currencyCode: "USD",
            converter: converter
        )

        let mondayEntry = result.first { $0.weekday == 2 }!
        #expect(mondayEntry.total == 100) // 50 * 2.0
    }

    @Test func allSevenDays_haveCorrectWeekdayNumbers() {
        let result = WeekdaySpendingCalculator.calculate(
            transactions: [],
            interval: weekInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        let weekdays = result.map { $0.weekday }
        #expect(weekdays == [1, 2, 3, 4, 5, 6, 7])
    }

    // MARK: - Day Occurrences Tests

    @Test func weekdayOccurrences_7days_eachDayAppearsOnce() {
        let occurrences = WeekdaySpendingCalculator.weekdayOccurrences(in: weekInterval)
        for day in 1...7 {
            #expect(occurrences[day] == 1, "Day \(day) should appear once in 7-day interval")
        }
    }

    @Test func weekdayOccurrences_28days_eachDayAppears4Times() {
        let occurrences = WeekdaySpendingCalculator.weekdayOccurrences(in: monthInterval)
        for day in 1...7 {
            #expect(occurrences[day] == 4, "Day \(day) should appear 4 times in 28-day interval")
        }
    }

    @Test func averagePerDay_multipleWeeks() {
        let cat = makeCategory(name: "Food")
        // Two Mondays in the 28-day interval: March 2 and March 9
        let monday1 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))! // Monday
        let monday2 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))! // Monday
        let tx1 = makeTransaction(amount: -40, date: monday1, category: cat)
        let tx2 = makeTransaction(amount: -60, date: monday2, category: cat)

        let result = WeekdaySpendingCalculator.calculate(
            transactions: [tx1, tx2],
            interval: monthInterval,
            currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        let mondayEntry = result.first { $0.weekday == 2 }!
        #expect(mondayEntry.total == 100)
        #expect(mondayEntry.count == 2)
        // 4 Mondays in 28-day interval → average = 100/4 = 25
        #expect(mondayEntry.average == 25)
    }

    // MARK: - Períodos cerrados en 23:59:59 (`undercount-dias-intervalos-cerrados`)

    /// **El caso que ninguna de las 5999 pruebas del repo cazaba.** Un período cerrado —«mes pasado»,
    /// «año pasado», un rango personalizado— llega con el `-1 s` que evita el doble conteo del borde de
    /// medianoche, y `dateComponents` a pelo devolvía un día menos. Aquí eso no infla una media: hace
    /// que el ÚLTIMO día del período **no sume su día de la semana**.
    ///
    /// Enero de 2026 empieza en jueves y tiene 31 días, así que jueves, viernes y **sábado** salen 5
    /// veces. Contando 30, el sábado 31 se pierde y quedan 4 — con lo que su media (`total /
    /// ocurrencias`) se infla un 25 % y el KPI «día más caro» puede señalar el día equivocado.
    @Test func closedPeriod_countsTheWeekdayOfItsLastDay() {
        var lima = Calendar(identifier: .gregorian)
        lima.timeZone = TimeZone(identifier: "America/Lima")!
        let enero = DateInterval(
            start: lima.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            end: lima.date(from: DateComponents(
                year: 2026, month: 1, day: 31, hour: 23, minute: 59, second: 59))!
        )

        let ocurrencias = WeekdaySpendingCalculator.weekdayOccurrences(in: enero)

        // Enero 2026: del jueves 1 al sábado 31.
        #expect(ocurrencias.values.reduce(0, +) == 31, """
            Las ocurrencias tienen que sumar los días reales del período. Si suman 30, el último día se
            perdió y algún día de la semana está contado de menos.
            """)
        #expect(ocurrencias[7] == 5, "Sábado: días 3, 10, 17, 24 y 31.")
        #expect(ocurrencias[5] == 5, "Jueves: 1, 8, 15, 22 y 29.")
        #expect(ocurrencias[2] == 4, "Lunes: 5, 12, 19 y 26.")
    }

    /// Control positivo: el mismo mes con el intervalo ABIERTO (end = 1 de febrero a medianoche, como
    /// lo devuelve `Calendar.dateInterval(of:)`) ya era correcto y tiene que seguir siéndolo. Sin esto,
    /// una normalización mal hecha que sumara un día a todo pasaría el test de arriba.
    @Test func openPeriod_isUnchangedByTheFix() {
        var lima = Calendar(identifier: .gregorian)
        lima.timeZone = TimeZone(identifier: "America/Lima")!
        let enero = DateInterval(
            start: lima.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            end: lima.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        )

        let ocurrencias = WeekdaySpendingCalculator.weekdayOccurrences(in: enero)
        #expect(ocurrencias.values.reduce(0, +) == 31)
        #expect(ocurrencias[7] == 5)
    }
}
