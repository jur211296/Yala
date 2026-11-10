//
//  WeekdayPriciestDayParityTests.swift
//  YalaTests
//
//  «Día de más gasto» (Estadísticas › Resumen) y «tu día más caro» (Estadísticas › Tendencias) salen de UNA entrada,
//  `WeekdaySpendingCalculator.forStatistics` (lote 02 de mejoras necesarias de 2.3, 2026-11-10). Antes cada pantalla lo
//  calculaba con sus filtros y su intervalo, y podían nombrar días distintos:
//  - con «Todo», Tendencias contaba hasta el último movimiento fechado (también los de mañana) y Resumen hasta hoy;
//  - con el chip «Ingresos», Resumen escondía el dato (filtraba los gastos) y Tendencias lo enseñaba.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct WeekdayPriciestDayParityTests {

    private let calendar = Calendar.current
    private let food = Category(name: "Comida", colorHex: "#111111", isIncome: false)
    private let account = Account(name: "Cuenta", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "cash")

    /// 2 de noviembre de 2026 es lunes; 13 de noviembre, viernes. Mediodía: el día de la semana no depende de la zona.
    private func noon(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12)) ?? .distantPast
    }

    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 15)) ?? .distantPast }

    private func expense(_ amount: Double, on date: Date) -> TransactionItem {
        TransactionItem(date: date, amount: -amount, currencyCode: "PEN", category: food, account: account,
                        amountInPreferredCurrency: -amount)
    }

    private func priciest(_ spending: [WeekdaySpending]) -> Int? {
        spending.filter { $0.average > 0 }.max(by: { $0.average < $1.average })?.weekday
    }

    private func allTime(criteria: FilterCriteria? = nil, transactions: [TransactionItem]) -> [WeekdaySpending] {
        WeekdaySpendingCalculator.forStatistics(
            transactions: transactions,
            accounts: [account],
            criteria: criteria ?? FilterCriteria(),
            period: .allTime,
            interval: DetailPeriod.allTime.dateInterval(now: now, calendar: calendar),
            currencyCode: "PEN",
            includeBridgedGroupTx: true,
            converter: IdentityConverter(),
            calendar: calendar
        )
    }

    /// Con «Todo», un gasto fechado por delante no cuenta: el día más caro es el de lo que ya pasó. Tendencias contaba el
    /// viernes de 500 y decía «viernes» con Resumen diciendo «lunes».
    @Test func allTime_aFutureDatedExpense_doesNotDecideTheDay() {
        let transactions = [expense(100, on: noon(2)), expense(500, on: noon(13))]
        let spending = allTime(transactions: transactions)
        #expect(calendar.component(.weekday, from: noon(2)) == 2, "Control: el 2-nov es lunes")
        #expect(priciest(spending) == 2)
        #expect(spending.first { $0.weekday == 6 }?.total == 0)
    }

    /// El chip Ingresos / Gastos no cambia este dato, que siempre es de gasto.
    @Test func theIncomeChip_doesNotHideTheDay() {
        var criteria = FilterCriteria()
        criteria.selectedTransactionNatures = [.income]
        let spending = allTime(criteria: criteria, transactions: [expense(100, on: noon(2))])
        #expect(priciest(spending) == 2)
    }

    /// Las dos pantallas llaman a la misma entrada, y ninguna calcula por su cuenta.
    @Test func resumenAndTendencias_readTheSameEntry() throws {
        let trends = try Self.readSource(of: "Yala/App/Views/Statistics/TrendsTabView.swift")
        let insights = try Self.readSource(of: "Yala/App/Logic/Calculators/InsightsCalculator.swift")
        for source in [trends, insights] {
            let code = Self.codeOnly(source)
            #expect(code.contains("WeekdaySpendingCalculator.forStatistics("))
            #expect(!code.contains("WeekdaySpendingCalculator.calculate("))
        }
    }

    // MARK: - Helpers

    private struct IdentityConverter: CurrencyConverting {
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
    }

    private static func readSource(of relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
    }

    /// Sin comentarios: documentar el invariante no lo pone en rojo.
    private static func codeOnly(_ source: String) -> String {
        source.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }
}
