//
//  PanelInicioDeMesParidadTests.swift
//  YalaTests
//
//  El Panel parte del saldo al empezar el día 1, igual que el flujo de caja (decisión de Jürgen del 19-nov-2026, 14:04).
//  Antes, la fila del gráfico de saldo («1 nov S/ 72,979 → hoy · −2.8 %») tomaba el primer punto de la curva, que es el
//  CIERRE del día 1 y contaba el sueldo de ese día, mientras el flujo de caja decía «Empezaste con S/ 64,345».
//
//  El fixture trae lo que separa las dos lecturas: el sueldo cobrado el día 1, un ajuste de saldo, un movimiento sin
//  categoría y una cuenta archivada que no suma.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Panel · el inicio de mes es el «Empezaste con» del flujo de caja", .serialized)
struct PanelInicioDeMesParidadTests {

    private static let calendar = Calendar.current

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private static var now: Date { date(2026, 11, 19) }
    private static var monthStart: Date { calendar.dateInterval(of: .month, for: now)?.start ?? now }

    private struct IdentityConverter: CurrencyConverting {
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
    }

    private struct Escenario {
        let context: ModelContext
        let accounts: [Account]
        let transactions: [TransactionItem]
    }

    /// Octubre deja S/ 5,000 en el banco (saldo inicial 4,000 + sueldo 3,000 − 1,900 de gastos − 100 sin categoría). El
    /// 1 de noviembre a las 9:00 entra el sueldo de 3,000; el 5, 200 de comida. La cuenta archivada tiene 900 y no suma.
    private static func escenario() throws -> Escenario {
        let context = try makeTestContext()
        let bank = Account(name: "Banco", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        let archived = Account(name: "Vieja", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        archived.isArchived = true
        [bank, archived].forEach { context.insert($0) }
        let food = YalaCategory(name: "Comida", colorHex: "#000", isIncome: false)
        let salary = YalaCategory(name: "Sueldo", colorHex: "#000", isIncome: true)
        [food, salary].forEach { context.insert($0) }

        var transactions: [TransactionItem] = []
        func tx(_ amount: Double, _ day: Date, _ category: YalaCategory? = nil, account: Account? = nil) -> TransactionItem {
            let item = TransactionItem(date: day, amount: amount, currencyCode: "PEN", category: category)
            item.account = account ?? bank
            context.insert(item)
            transactions.append(item)
            return item
        }
        let initial = tx(4_000, date(2026, 9, 30))
        initial.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        _ = tx(3_000, date(2026, 10, 1), salary)
        _ = tx(-1_900, date(2026, 10, 10), food)
        _ = tx(-100, date(2026, 10, 20))
        _ = tx(900, date(2026, 10, 2), account: archived)
        _ = tx(3_000, date(2026, 11, 1, hour: 9), salary)
        _ = tx(-200, date(2026, 11, 5), food)
        try context.save()
        return Escenario(context: context, accounts: [bank, archived], transactions: transactions)
    }

    /// Lo que pinta el flujo de caja en «Empezaste con» del mes en curso, armado como `CashFlowPlanViewModel`.
    private static func empezasteCon(_ e: Escenario) throws -> Double {
        let scope = try #require(FlujoMotorMesEntrada.alcanceDelSaldo(
            accounts: e.accounts, transactions: e.transactions, includeGroups: true))
        let balance = FlujoMotorMesEntrada.FuenteSaldo(
            accounts: scope.accounts, transactions: scope.transactions, currencyCode: "PEN", converter: IdentityConverter())
        let plan = CashFlowPlan(name: "Plan")
        e.context.insert(plan)
        let projection = CashFlowProjectionCalculator.calculate(
            plan: plan, lines: [], transactions: e.transactions, allExpenseCategories: [],
            scheduledPayments: [], monthsBack: 0, monthsAhead: 0, currencyCode: "PEN",
            adjustment: .none, converter: IdentityConverter(), balance: balance,
            historyTransactions: e.transactions, excludedFutureFixed: [], now: now, calendar: calendar
        )
        let current = try #require(projection.months.first { $0.isCurrent })
        return try #require(current.openingBalance)
    }

    /// Lo que pinta el Panel: sus cuentas del saldo (sin filtro de cuentas) y la función que llama su ViewModel.
    private static func inicioDelPanel(_ e: Escenario) throws -> Double {
        let accounts = PanelBalanceScopeLogic.accounts(eligible: e.accounts, includeGroups: true, selectedAccountIDs: [])
        let transactions = PanelBalanceScopeLogic.transactions(
            e.transactions, accountIDs: Set(accounts.map(\.persistentModelID)))
        return try #require(PanelTrendSummaryLogic.periodStartBalance(
            accounts: accounts, transactions: transactions, currencyCode: "PEN", converter: IdentityConverter(),
            periodStart: monthStart, now: now, calendar: calendar
        ))
    }

    @Test func elPanelYElFlujoDeCaja_empiezanElMesConLaMismaCifra() throws {
        let e = try Self.escenario()
        let flujo = try Self.empezasteCon(e)
        let panel = try Self.inicioDelPanel(e)
        #expect(abs(flujo - 5_000) < 0.005, "«Empezaste con» = lo que dejó octubre: \(flujo)")
        #expect(abs(panel - flujo) < 0.005, "Panel \(panel) ≠ flujo de caja \(flujo)")
    }

    /// El control: el primer punto de la curva del mes es el cierre del día 1 y trae el sueldo. Si un día la curva
    /// empezara antes del día 1, este caso dejaría de discriminar y lo diría.
    @Test func elPrimerPuntoDeLaCurva_noEsElInicio_ylaFilaUsaElInicio() throws {
        let e = try Self.escenario()
        let accounts = PanelBalanceScopeLogic.accounts(eligible: e.accounts, includeGroups: true, selectedAccountIDs: [])
        let transactions = PanelBalanceScopeLogic.transactions(
            e.transactions, accountIDs: Set(accounts.map(\.persistentModelID)))
        let interval = try #require(Self.calendar.dateInterval(of: .month, for: Self.now))
        let curve = TrendDataProcessor.processTrendData(
            transactions: transactions, accounts: accounts, metric: .balance, period: .thisMonth, grouping: .day,
            interval: interval, currencyCode: "PEN", asOf: Self.now, converter: IdentityConverter()
        )
        let first = try #require(curve.rawPoints.first)
        #expect(abs(first.value - 8_000) < 0.005, "el cierre del 1 de noviembre lleva el sueldo: \(first.value)")

        let inicio = try Self.inicioDelPanel(e)
        let hoy = BarPoint(date: Self.now, value: 7_800)
        let fila = try #require(PanelTrendSummaryLogic.startEnd(
            rawPoints: curve.rawPoints, liveAnchor: hoy, periodStartBalance: inicio, today: Self.now, calendar: Self.calendar))
        #expect(abs(fila.startValue - 5_000) < 0.005, "la fila parte del saldo al empezar el día 1")
        #expect(Self.calendar.isDate(fila.startDate, inSameDayAs: Self.monthStart), "y la fecha sigue siendo el día 1")
        let variacion = try #require(fila.variation)
        #expect(abs(variacion - 56) < 0.05, "+56 % contra 5,000, no −2.5 % contra 8,000: \(variacion)")

        let sinInicio = try #require(PanelTrendSummaryLogic.startEnd(
            rawPoints: curve.rawPoints, liveAnchor: hoy, today: Self.now, calendar: Self.calendar))
        #expect(abs(sinInicio.startValue - first.value) < 0.005, "sin el inicio, el primer punto (lo de antes)")
    }

    private func codigo(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: "\(#filePath)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appending(path: path), encoding: .utf8)
        return text.split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }

    /// El ViewModel guarda el inicio con las cuentas de su saldo y el inicio del período, y la fila lo recibe.
    @Test func elPanel_pasaElInicioAlaFila() throws {
        let vm = try codigo("Yala/App/ViewModels/PanelViewModel.swift")
        #expect(vm.contains("""
            newTrendPeriodStartBalance = PanelTrendSummaryLogic.periodStartBalance( \
            accounts: calcContext.balanceAccounts, transactions: calcContext.balanceTransactions, \
            currencyCode: calcContext.defaultCurrencyCode, converter: calcContext.converter, \
            periodStart: calcContext.effectiveInterval.start,
            """))
        #expect(vm.contains("trendPeriodStartBalance: newTrendPeriodStartBalance"))
        let widget = try codigo("Yala/App/Views/Panel/TrendsCarouselWidget.swift")
        #expect(widget.contains("periodStartBalance: viewModel.trendPeriodStartBalance,"))
        let logica = try codigo("Yala/App/Logic/PanelTrendSummaryLogic.swift")
        #expect(logica.contains("FlujoMotorMesEntrada.FuenteSaldo("), "la misma pieza que «Empezaste con», no una copia")
    }
}
