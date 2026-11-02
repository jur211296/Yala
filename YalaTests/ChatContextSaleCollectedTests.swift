//
//  ChatContextSaleCollectedTests.swift
//  YalaTests
//
//  Grupos B · card 11: lo por cobrar de una venta de grupo no cuenta como ingreso y lo cobrado sí, el mes del pago, en
//  Estadísticas (el hero: filtro de tendencias + `CashFlowCalculator`), en Yala IA (`FullFinancialContextBuilder`) y en
//  el ajuste del puente (`GroupBridgeStatsAdjustment`). El conector `mcp/` lleva los mismos casos en vitest
//  (`logic.test.ts`, «ventas por cobrar»).
//
//  Escena (USD, tasa 1, a mitad de octubre). Le vendiste algo a Ana por 120 el 20 de septiembre; te pagó 50 el 8 de
//  octubre. Quedan 70 por cobrar (pata con tipo, fechada en la venta) y 50 cobrados (pata de ingreso en «Grupos» con la
//  marca de cobrada, fechada en el pago). Sueldo de 1.000 el 1 de octubre.
//  - Octubre: ingreso 1.050 (sueldo + lo cobrado). Septiembre: 0 (la venta no era ingreso todavía).
//  - Control: con la pata cobrada marcada como por cobrar, octubre se queda en 1.000.
//
//  Archivo propio: `makeTestContext()` reusa el store por `#fileID` (ver `testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Grupos B · lo cobrado de una venta es ingreso del mes del pago", .serialized)
struct ChatContextSaleCollectedTests {

    private let calendar = Calendar.current

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)) ?? .distantPast
    }

    private func date(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? .distantPast
    }

    private func cerca(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    private struct Escena {
        let accounts: [Account]
        let txs: [TransactionItem]
        let collected: TransactionItem
        let mixedRealLeg: TransactionItem?
    }

    /// - Parameter withRealLeg: añade una pata real del mismo gasto (un aparato que aún no repasó una venta que dejó de
    ///   serlo): lo cobrado no puede netearse contra ella.
    private func escena(_ context: ModelContext, withRealLeg: Bool = false) throws -> Escena {
        let principal = makeTestAccount(context: context, name: "Principal", currencyCode: "USD")
        let grupos = makeTestAccount(context: context, name: "Grupos", currencyCode: "USD")
        grupos.isSystemAccount = true
        let sueldo = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        let ingresos = makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        let ventas = makeTestSubcategory(context: context, name: "Ventas", category: ingresos)
        let compras = makeTestCategory(context: context, name: "Compras")

        func fila(_ amount: Double, _ when: Date, _ category: YalaCategory, _ account: Account) -> TransactionItem {
            let t = TransactionItem(
                date: when, amount: amount, currencyCode: "USD", note: "Venta de zapatillas",
                category: category, account: account,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "USD")
            context.insert(t)
            return t
        }

        let porCobrar = fila(70, date(9, 20), ingresos, grupos)
        porCobrar.subcategory = ventas
        porCobrar.balanceAdjustmentType = TransactionItem.adjustmentTypeReceivable
        porCobrar.splitExpenseID = "venta-1"
        let cobrada = fila(50, date(10, 8), ingresos, grupos)
        cobrada.subcategory = ventas
        cobrada.splitExpenseID = "venta-1"
        cobrada.splitLinesRaw = GroupSplitLinesRecipe.encodeCollectedMarker(eventID: UUID())
        var txs = [fila(1_000, date(10, 1), sueldo, principal), porCobrar, cobrada]
        var real: TransactionItem?
        if withRealLeg {
            let leg = fila(-120, date(10, 3), compras, principal)
            leg.splitExpenseID = "venta-1"
            txs.append(leg)
            real = leg
        }
        try context.save()
        return Escena(accounts: [principal, grupos], txs: txs, collected: cobrada, mixedRealLeg: real)
    }

    private func contexto(_ e: Escena) -> FullFinancialContext {
        FullFinancialContextBuilder().buildFromArrays(
            transactions: e.txs,
            budgets: [],
            accounts: e.accounts,
            tags: [],
            scheduledPayments: [],
            currencyCode: "USD",
            currencyDisplay: "$",
            converter: MockCurrencyConverter(fixedRate: 1.0),
            language: "es",
            country: "US",
            includeAnomalies: false,
            adjustment: GroupBridgeStatsAdjustment.build(from: e.txs),
            now: now)
    }

    /// El hero de Estadísticas para un mes: el filtro de tendencias y `CashFlowCalculator`, con el ajuste del conjunto crudo.
    private func estadisticas(_ e: Escena, month: Int) -> CashFlowSummary {
        let filtered = FilterService.filterForTrends(
            transactions: e.txs, accounts: e.accounts, criteria: FilterCriteria(), includeBridgedGroupTx: true)
        let start = date(month, 1)
        let interval = calendar.dateInterval(of: .month, for: start) ?? DateInterval(start: start, end: start)
        let closed = DateInterval(start: interval.start, end: interval.end.addingTimeInterval(-1))
        return CashFlowCalculator.calculateCashFlow(
            transactions: filtered.filter { closed.contains($0.date) },
            interval: closed, grouping: .day, currencyCode: "USD",
            adjustment: GroupBridgeStatsAdjustment.build(from: e.txs),
            converter: MockCurrencyConverter(fixedRate: 1.0))
    }

    @Test("El ingreso del mes es lo cobrado en el mes: en Estadísticas y en Yala IA")
    func incomeOfTheMonth_isWhatWasCollectedInIt() throws {
        let e = try escena(try makeTestContext())

        let octubre = estadisticas(e, month: 10)
        let septiembre = estadisticas(e, month: 9)
        #expect(cerca(octubre.totalIncome, 1_050), "octubre: \(octubre.totalIncome)")
        #expect(cerca(septiembre.totalIncome, 0), "septiembre: \(septiembre.totalIncome)")

        let ctx = contexto(e)
        #expect(cerca(ctx.periods.currentMonth.income, 1_050), "IA, este mes: \(ctx.periods.currentMonth.income)")
        #expect(cerca(ctx.periods.lastMonth.income, 0), "IA, mes pasado: \(ctx.periods.lastMonth.income)")
        let ingresos = try #require(ctx.incomeCategories.first { $0.name == "Ingresos" })
        #expect(cerca(ingresos.totalCurrentMonth, 50), "Ingresos (Ventas) este mes: \(ingresos.totalCurrentMonth)")
        #expect(cerca(ingresos.totalLastMonth, 0), "Ingresos (Ventas) el mes pasado: \(ingresos.totalLastMonth)")
    }

    /// Discriminante: la misma pata cobrada con el tipo de lo por cobrar no cuenta. Si el ingreso de octubre no cambia,
    /// el test no estaría mirando lo cobrado.
    @Test("Control: marcada como por cobrar, la parte cobrada no cuenta")
    func control_withTheReceivableType_nothingCounts() throws {
        let e = try escena(try makeTestContext())
        e.collected.balanceAdjustmentType = TransactionItem.adjustmentTypeReceivable
        #expect(cerca(estadisticas(e, month: 10).totalIncome, 1_000))
        #expect(cerca(contexto(e).periods.currentMonth.income, 1_000))
    }

    /// Observaciones: lo cobrado lleva el puntero de la venta pero es un ingreso, no un gasto compartido. Sumado ahí con
    /// `abs`, el «gasto de grupos» del mes salía en 50 y el personal bajaba otros 50.
    @Test("Observaciones no cuenta lo cobrado como gasto compartido")
    func insights_doNotCountCollectedAsSharedExpense() throws {
        let e = try escena(try makeTestContext())
        let data = InsightsCalculator.calculate(
            transactions: e.txs, accounts: e.accounts, categories: [], budgets: [], scheduledPayments: [],
            period: .thisMonth, criteria: FilterCriteria(), currencyCode: "USD", customRange: nil,
            converter: MockCurrencyConverter(fixedRate: 1.0),
            adjustment: GroupBridgeStatsAdjustment.build(from: e.txs), now: now)
        #expect(data.groupInsightsContext == nil,
                "gasto compartido: \(String(describing: data.groupInsightsContext?.totalSharedExpense))")
    }

    /// Lo cobrado no se netea contra una pata real del mismo gasto: sin la exclusión del ajuste, se tomaría por un
    /// préstamo, se suprimiría y la pata real saldría por 70.
    @Test("Lo cobrado no es un préstamo: no se netea contra una pata real del mismo gasto")
    func collectedIsNotALoan() throws {
        let e = try escena(try makeTestContext(), withRealLeg: true)
        let adjustment = GroupBridgeStatsAdjustment.build(from: e.txs)
        #expect(!adjustment.isSuppressed(e.collected))
        let real = try #require(e.mixedRealLeg)
        // Ajustada sí (es la pata real del gasto), pero sin préstamo que restarle: sigue en −120.
        #expect(cerca(adjustment.amount(real), -120), "pata real: \(adjustment.amount(real))")
        let octubre = estadisticas(e, month: 10)
        #expect(cerca(octubre.totalIncome, 1_050), "ingreso: \(octubre.totalIncome)")
        #expect(cerca(octubre.totalExpense, 120), "gasto: \(octubre.totalExpense)")
    }
}
