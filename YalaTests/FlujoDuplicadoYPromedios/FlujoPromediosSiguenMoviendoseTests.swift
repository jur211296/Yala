//
//  FlujoPromediosSiguenMoviendoseTests.swift
//  YalaTests
//
//  Las líneas por promedio se mueven cada mes A PROPÓSITO. La S5 del replanteo dejó anotado «congelarlas» como pendiente,
//  y la decisión de Jürgen del 19-nov-2026 (10:21, «límites móviles», `docs/DECISIONS.md`) lo sustituyó: Promedio 6
//  meses, Promedio 3 meses y Último mes se recalculan cada mes; solo «Monto fijo» deja un número quieto. El encargo del
//  27-nov (flujo de caja duplicado y promedios) volvió a pedir congelarlas leyendo el pendiente viejo; estas pruebas
//  fijan lo vigente para que nadie lo «arregle» sin una decisión nueva:
//  - un plan creado un mes, al cruzar al siguiente, recalcula su línea por promedio con el mes que se cerró;
//  - «Monto fijo» no se mueve;
//  - «Agregar a mi plan» desde «Otros» crea la línea por promedio (que se mueve), no por monto fijo.
//  El «ahora» es fijo: el 18 de noviembre y el 18 de diciembre de 2026 en Lima.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Flujo de caja · los promedios siguen moviéndose cada mes (decisión del 19-nov)", .serialized)
struct FlujoPromediosSiguenMoviendoseTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .gmt
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }

    private static let noviembre18 = date(2026, 11, 18)
    private static let diciembre18 = date(2026, 12, 18)

    private struct Conv: CurrencyConverting {
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
    }

    private struct Escenario {
        let context: ModelContext
        let plan: CashFlowPlan
        let linea: CashFlowLine
        let transactions: [TransactionItem]
        let comida: YalaCategory
        let supermercado: Subcategory
    }

    /// Supermercado: 100 cada mes de mayo a octubre y 250 en noviembre (no llega al triple de lo normal: no es aislado; el mes que se cierra al cruzar a diciembre). El plan
    /// se creó el 18 de noviembre con la línea de Supermercado por `method`.
    private static func escenario(method: EstimationMethod, manualAmount: Double? = nil) throws -> Escenario {
        let context = try makeTestContext()
        let bank = Account(name: "Banco", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(bank)
        let comida = YalaCategory(name: "Comida", colorHex: "#000000", isIncome: false)
        context.insert(comida)
        let supermercado = Subcategory(name: "Supermercado", category: comida)
        context.insert(supermercado)
        var transactions: [TransactionItem] = []
        func tx(_ amount: Double, _ day: Date) {
            let item = TransactionItem(date: day, amount: amount, currencyCode: "PEN", category: comida)
            item.subcategory = supermercado
            item.account = bank
            context.insert(item)
            transactions.append(item)
        }
        for month in 5...10 { tx(-100, date(2026, month, 10)) }
        tx(-250, date(2026, 11, 10))

        let plan = CashFlowPlan(name: "")
        plan.createdAt = noviembre18
        context.insert(plan)
        let linea = CashFlowLine(
            name: "Supermercado", estimationMethod: method, manualAmount: manualAmount,
            category: comida, subcategory: supermercado
        )
        context.insert(linea)
        linea.plan = plan
        try context.save()
        return Escenario(
            context: context, plan: plan, linea: linea, transactions: transactions, comida: comida,
            supermercado: supermercado
        )
    }

    /// El límite de la línea en el mes en curso de `now`.
    private static func limiteDelMesEnCurso(_ e: Escenario, now: Date) throws -> Double {
        let projection = CashFlowProjectionCalculator.calculate(
            plan: e.plan, lines: [e.linea], transactions: e.transactions, allExpenseCategories: [],
            scheduledPayments: [], monthsBack: 2, monthsAhead: 1, currencyCode: "PEN", converter: Conv(),
            now: now, calendar: calendar
        )
        let key = CashFlowProjectionCalculator.monthKey(for: now, calendar: calendar)
        let month = try #require(projection.months.first { $0.monthKey == key })
        return try #require(month.expenseLines.first { $0.lineID == e.linea.id }).plannedAmount
    }

    @Test("Un plan de noviembre con Promedio 6 meses: en diciembre su límite cuenta noviembre (se mueve)")
    func promedio_alCruzarDeMes_seMueve() throws {
        let e = try Self.escenario(method: .average6m)
        let enNoviembre = try Self.limiteDelMesEnCurso(e, now: Self.noviembre18)
        let enDiciembre = try Self.limiteDelMesEnCurso(e, now: Self.diciembre18)
        // Noviembre mira mayo-octubre: 100. Diciembre mira junio-noviembre: (5 × 100 + 250) / 6 = 125.
        #expect(abs(enNoviembre - 100) < 0.01)
        #expect(abs(enDiciembre - 125) < 0.01)
        // Nada la congela por el camino: sigue siendo una línea por promedio, sin monto guardado.
        #expect(e.linea.method == .average6m)
        #expect(e.linea.manualAmount == nil)
    }

    @Test("«Monto fijo» no se mueve al cruzar de mes")
    func montoFijo_alCruzarDeMes_noSeMueve() throws {
        let e = try Self.escenario(method: .manual, manualAmount: 120)
        #expect(abs(try Self.limiteDelMesEnCurso(e, now: Self.noviembre18) - 120) < 0.01)
        #expect(abs(try Self.limiteDelMesEnCurso(e, now: Self.diciembre18) - 120) < 0.01)
    }

    @Test("«Agregar a mi plan» desde «Otros» crea la línea por Promedio 6 meses, no por monto fijo")
    func otros_creaPromedio() throws {
        let e = try Self.escenario(method: .average6m)
        let mercado = Subcategory(name: "Mercado", sortOrder: 1, category: e.comida)
        e.context.insert(mercado)
        try e.context.save()
        let viewModel = CashFlowPlanViewModel()
        viewModel.setContext(e.context)
        viewModel.promoteSubcategory(mercado, isIncome: false)
        let nueva = try #require((e.plan.lines ?? []).first { $0.subcategory?.persistentModelID == mercado.persistentModelID })
        #expect(nueva.method == .average6m)
        #expect(nueva.manualAmount == nil)
    }
}
