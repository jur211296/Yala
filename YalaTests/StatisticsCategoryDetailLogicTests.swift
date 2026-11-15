//
//  StatisticsCategoryDetailLogicTests.swift
//  YalaTests
//
//  Decisión 25 de la revisión 2.3 (B1): el detalle de una categoría en Distribución. Su cifra es la de la fila tocada,
//  sus subcategorías y registros salen de los mismos movimientos que la tarta, y suma con la regla de los calculadores
//  (gasto por categoría, sin ajustes de saldo, dentro del período).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct StatisticsCategoryDetailLogicTests {
    private let calendar = Calendar(identifier: .gregorian)
    /// Fechas fijas (`testing.md`): el período es noviembre de 2026 y el anterior, octubre.
    private var interval: DateInterval {
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 23, minute: 59, second: 59))!
        return DateInterval(start: start, end: end)
    }
    private var previousInterval: DateInterval {
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 59, second: 59))!
        return DateInterval(start: start, end: end)
    }

    private func day(_ day: Int, month: Int = 11) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 10))!
    }

    private func tx(
        _ amount: Double,
        on date: Date,
        category: YalaCategory?,
        subcategory: Subcategory? = nil,
        note: String = "",
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let item = TransactionItem(
            date: date, amount: amount, currencyCode: "USD", note: note,
            category: category, subcategory: subcategory, tags: [], amountInPreferredCurrency: amount
        )
        item.preferredCurrencyCode = "USD"
        item.balanceAdjustmentType = balanceAdjustmentType
        return item
    }

    private struct Fixture {
        let food: YalaCategory
        let groceries: Subcategory
        let delivery: Subcategory
        let current: [TransactionItem]
        let previous: [TransactionItem]
    }

    private func fixture() -> Fixture {
        let food = YalaCategory(name: "Alimentación", colorHex: "#FF0000", isIncome: false)
        let transport = YalaCategory(name: "Transporte", colorHex: "#00FF00", isIncome: false)
        let salary = YalaCategory(name: "Sueldo", colorHex: "#0000FF", isIncome: true)
        let groceries = Subcategory(name: "Supermercados", colorHex: "#FF0000", category: food)
        let delivery = Subcategory(name: "Delivery", colorHex: "#FF0000", category: food)
        let taxi = Subcategory(name: "Taxi", colorHex: "#00FF00", category: transport)
        let current = [
            tx(-88, on: day(6), category: food, subcategory: groceries, note: "Compras semana"),
            tx(-131, on: day(4), category: food, subcategory: groceries, note: "Wong"),
            tx(-29, on: day(7), category: food, subcategory: delivery, note: "Delivery app"),
            tx(-12, on: day(2), category: food, subcategory: delivery, note: "Café"),
            tx(-40, on: day(1), category: food, subcategory: groceries, note: "Mercado"),
            tx(-15, on: day(3), category: food, subcategory: groceries, note: "Pan"),
            // No suman en Alimentación: otra categoría, un ajuste de saldo y uno fuera del período.
            tx(-50, on: day(5), category: transport, subcategory: taxi, note: "Taxi"),
            tx(-999, on: day(5), category: food, subcategory: groceries, note: "Ajuste", balanceAdjustmentType: "manual"),
            tx(-77, on: day(20, month: 10), category: food, subcategory: groceries, note: "Del mes pasado"),
            tx(3000, on: day(1), category: salary, note: "Sueldo"),
        ]
        let previous = [
            tx(-200, on: day(5, month: 10), category: food, subcategory: groceries),
            tx(-10, on: day(6, month: 10), category: food, subcategory: delivery),
            tx(-60, on: day(6, month: 10), category: transport, subcategory: taxi),
        ]
        return Fixture(food: food, groceries: groceries, delivery: delivery, current: current, previous: previous)
    }

    private func build(_ f: Fixture, summary: CategorySpendingSummary? = nil) -> StatisticsCategoryDetail? {
        StatisticsCategoryDetailLogic.build(
            summary: summary ?? CategorySpendingSummary(category: f.food, amount: 315, percentage: 86.3, previousAmount: 210),
            current: f.current,
            previous: f.previous,
            interval: interval,
            previousInterval: previousInterval,
            currencyCode: "USD",
            natures: nil,
            converter: MockCurrencyConverter()
        )
    }

    @Test func cifraYComparacion_sonLasDeLaFilaTocada() throws {
        let detail = try #require(build(fixture()))
        #expect(detail.name == "Alimentación")
        #expect(detail.amount == 315)
        #expect(detail.percentage == 86.3)
        #expect(detail.previousAmount == 210)
    }

    @Test func subcategorias_soloLasDeEsaCategoria_conSuPeriodoAnterior() throws {
        let detail = try #require(build(fixture()))
        let byName = Dictionary(uniqueKeysWithValues: detail.subcategories.map { ($0.subcategoryName, $0) })
        #expect(Set(byName.keys) == ["Supermercados", "Delivery"], "Taxi es de Transporte: no va en Alimentación.")
        #expect(byName["Supermercados"]?.amount == 274)
        #expect(byName["Supermercados"]?.previousAmount == 200)
        #expect(byName["Delivery"]?.amount == 41)
        #expect(byName["Delivery"]?.previousAmount == 10)
        #expect(detail.subcategories.first?.subcategoryName == "Supermercados", "De mayor a menor.")
        // El porcentaje es sobre la categoría (315), no sobre todo el gasto del período: lo que enseñaba Distribución.
        let share = try #require(byName["Supermercados"]?.percentageOfTotal)
        #expect(abs(share - 274.0 / 315.0 * 100) < 0.01)
    }

    @Test func ultimosRegistros_losQueSuman_delMasReciente_yComoMuchoCinco() throws {
        let detail = try #require(build(fixture()))
        #expect(detail.recordCount == 6, "Fuera: el taxi, el ajuste de saldo, el del mes pasado y el sueldo.")
        #expect(detail.latestRecords.count == StatisticsCategoryDetailLogic.latestRecordsLimit)
        #expect(detail.latestRecords.map(\.note) == ["Delivery app", "Compras semana", "Wong", "Pan", "Café"])
    }

    @Test func sinComparacion_lasSubcategoriasNoLlevanAnterior() throws {
        let f = fixture()
        let detail = try #require(StatisticsCategoryDetailLogic.build(
            summary: CategorySpendingSummary(category: f.food, amount: 315, percentage: 86.3, previousAmount: nil),
            current: f.current, previous: [], interval: interval, previousInterval: nil,
            currencyCode: "USD", natures: nil, converter: MockCurrencyConverter()
        ))
        #expect(detail.previousAmount == nil)
        #expect(detail.subcategories.allSatisfy { $0.previousAmount == nil })
    }

    @Test func conIngresosElegidos_cuentaLosIngresosDeLaCategoria() throws {
        let f = fixture()
        let salary = try #require(f.current.first { $0.note == "Sueldo" }?.category)
        let detail = try #require(StatisticsCategoryDetailLogic.build(
            summary: CategorySpendingSummary(category: salary, amount: 3000, percentage: 100, previousAmount: nil),
            current: f.current, previous: [], interval: interval, previousInterval: nil,
            currencyCode: "USD", natures: [.income], converter: MockCurrencyConverter()
        ))
        #expect(detail.recordCount == 1)
        #expect(detail.latestRecords.first?.note == "Sueldo")
    }

    @Test func sinCategoria_noTieneDetalle() {
        let f = fixture()
        let uncategorized = CategorySpendingSummary(category: nil, amount: 10, percentage: 1)
        #expect(build(f, summary: uncategorized) == nil)
    }
}
