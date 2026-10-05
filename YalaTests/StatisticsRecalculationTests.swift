//
//  StatisticsRecalculationTests.swift
//  YalaTests
//
//  El hero de Tendencias sigue al período venga el cambio de donde venga.
//  Ticket `trends-hero-keeps-the-previous-period-after-changing-it-on-trends`.
//
//  El hero de Tendencias lee `InsightsViewModel.insightData` (el resumen del período de Resumen). Hasta el
//  2026-10-05 ese cálculo solo corría con Resumen o Distribución a la vista: cambiar el período desde Tendencias
//  movía las gráficas y dejaba el hero con el período anterior. Estos tests van por la pasada real que ejecuta la
//  pantalla (`StatisticsRecalculation.run`), con los tres view models de verdad.
//
//  **El fixture discrimina en las tres cifras del hero:** «Todo el tiempo» da ingresos 800, gastos 1100 y neto −300;
//  «Mes pasado», 300, 100 y +200. Un hero que se queda con el período anterior no acierta ninguna por casualidad (la
//  primera versión tenía los ingresos iguales en los dos períodos y esa aserción pasaba con el bug puesto).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Estadísticas · el hero sigue al período en cualquier pestaña", .serialized)
struct StatisticsRecalculationTests {

    private let calendar = Calendar.current

    /// `period` vive en `SessionState.shared` (es lo que escribe el menú de período de las cuatro pestañas). Se
    /// restaura al salir: es estado global.
    private func conPeriodo(_ periodo: DetailPeriod, _ cuerpo: () throws -> Void) rethrows {
        let anterior = SessionState.shared.selectedPeriod
        SessionState.shared.selectedPeriod = periodo
        defer { SessionState.shared.selectedPeriod = anterior }
        try cuerpo()
    }

    /// Día 10 del mes `mesesAtras` antes del actual, a mediodía: lejos de las medianoches de los bordes.
    private func dia10(mesesAtras: Int) -> Date {
        let inicioMes = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        let mes = calendar.date(byAdding: .month, value: -mesesAtras, to: inicioMes) ?? inicioMes
        return calendar.date(byAdding: DateComponents(day: 9, hour: 12), to: mes) ?? mes
    }

    private struct Fixture {
        let account: Account
        let categories: [YalaCategory]
        let transactions: [TransactionItem]
    }

    /// Mes pasado: +300 de ingreso y −100 de gasto (neto +200). Hace dos meses: +500 de ingreso y −1000 de gasto.
    /// «Todo el tiempo»: ingreso 800, gasto 1100, neto −300.
    private func fixture(_ context: ModelContext) -> Fixture {
        let account = Account(name: "Main", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let food = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        let salary = YalaCategory(name: "Salary", colorHex: "#00FF00", isIncome: true)
        context.insert(account)
        context.insert(food)
        context.insert(salary)
        func tx(_ amount: Double, _ date: Date, _ category: YalaCategory) -> TransactionItem {
            let tx = TransactionItem(
                date: date, amount: amount, currencyCode: "PEN", note: "",
                category: category, account: account, tags: [],
                amountInPreferredCurrency: amount
            )
            tx.preferredCurrencyCode = "PEN"
            context.insert(tx)
            return tx
        }
        let txs = [
            tx(300, dia10(mesesAtras: 1), salary),
            tx(-100, dia10(mesesAtras: 1), food),
            tx(500, dia10(mesesAtras: 2), salary),
            tx(-1000, dia10(mesesAtras: 2), food),
        ]
        return Fixture(account: account, categories: [food, salary], transactions: txs)
    }

    private func inputs(_ f: Fixture) -> StatisticsRecalculation.Inputs {
        StatisticsRecalculation.Inputs(
            transactions: f.transactions,
            accounts: [f.account],
            categories: f.categories,
            tags: [],
            budgets: [],
            scheduledPayments: [],
            period: SessionState.shared.selectedPeriod,
            customRange: nil,
            comparisonMode: .month,
            currencyCode: "PEN",
            dataVersion: SessionState.shared.dataVersion,
            includeGroupTransactionsInStats: true
        )
    }

    @MainActor private struct Pantalla {
        let pass = StatisticsRecalculation()
        let records = RecordsViewModel()
        let trends = StatisticsViewModel(context: StatisticsContext(initialMetric: .balance, period: .allTime))
        let insights = InsightsViewModel()

        func run(_ inputs: StatisticsRecalculation.Inputs, _ context: ModelContext) {
            pass.run(inputs, records: records, trends: trends, insights: insights, context: context)
        }
    }

    /// El caso del ticket, en su orden: Estadísticas abierta en Resumen con «Todo el tiempo», el usuario pasa a
    /// Tendencias y elige «Mes pasado» ahí. La pasada que sigue tiene que llevar el hero a septiembre (o al mes
    /// que toque), no dejarlo en el total de siempre.
    @Test("Cambiar el período desde Tendencias mueve el resumen que pinta el hero")
    func periodChangedOnTrendsMovesTheHeroSummary() throws {
        let context = try makeTestContext()
        let f = fixture(context)
        let pantalla = Pantalla()

        try conPeriodo(.allTime) {
            pantalla.run(inputs(f), context)
            let todo = try #require(pantalla.insights.insightData?.periodSummary)
            #expect(todo.netBalance == -300, "Control: con «Todo el tiempo» el neto es −300.")

            SessionState.shared.selectedPeriod = .lastMonth
            pantalla.run(inputs(f), context)
            let mes = try #require(pantalla.insights.insightData?.periodSummary)
            #expect(mes.netBalance == 200, """
                El hero de Tendencias se quedó con el período anterior (neto \(mes.netBalance)): con «Mes pasado» \
                el neto es +200.
                """)
            #expect(mes.totalIncome == 300)
            #expect(mes.totalExpense == 100)
            #expect(mes.transactionCount == 2)
        }
    }

    /// Hero y gráficas leen dos view models distintos. Tras la misma pasada tienen que hablar del mismo período:
    /// es lo que el usuario vio desalineado (gráficas en septiembre, hero en «Todo el tiempo»).
    @Test("Tras cambiar el período, el hero y las gráficas cuentan lo mismo")
    func heroAndChartsAgreeAfterAPeriodChange() throws {
        let context = try makeTestContext()
        let f = fixture(context)
        let pantalla = Pantalla()

        try conPeriodo(.allTime) {
            pantalla.run(inputs(f), context)
            SessionState.shared.selectedPeriod = .lastMonth
            pantalla.run(inputs(f), context)

            let hero = try #require(pantalla.insights.insightData?.periodSummary)
            #expect(pantalla.trends.totalIncome == 300, "Control: las gráficas ya seguían al período.")
            #expect(hero.totalIncome == pantalla.trends.totalIncome)
            #expect(hero.totalExpense == abs(pantalla.trends.totalExpense))
        }
    }

    /// Abrir Estadísticas directamente en Tendencias (la última pestaña usada) no pasaba nunca por Resumen: el
    /// hero salía vacío. La primera pasada ya tiene que dejarlo calculado.
    @Test("La primera pasada ya deja calculado el resumen del hero")
    func firstPassAlreadyComputesTheHeroSummary() throws {
        let context = try makeTestContext()
        let f = fixture(context)
        let pantalla = Pantalla()

        try conPeriodo(.lastMonth) {
            pantalla.run(inputs(f), context)
            let mes = try #require(pantalla.insights.insightData?.periodSummary, "El hero salió sin datos.")
            #expect(mes.netBalance == 200)
        }
    }
}
