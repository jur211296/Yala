//
//  BudgetsTransactionWindowTests.swift
//  YalaTests
//
//  Presupuestos solo cargaba los movimientos del último año: «Año pasado» de un presupuesto anual contaba desde el
//  mismo día del año anterior, y un mes de hace más de un año salía con el gasto a 0 (auditoría UX 2.2, lote 9,
//  medido en el simulador: «Setiembre 2025» a 0 y «Fijos casa» de octubre de 2025 en S/ 270 de S/ 2,470).
//  Ahora la ventana sale de lo que se enseña: el período elegido de cada tipo, los únicos y lo que pidan las gráficas.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - La ventana (lógica pura)

@MainActor
struct BudgetsTransactionWindowLogicTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private var now: Date { date(2026, 10, 14) }

    private func windowStart(
        types: Set<BudgetPeriodType>,
        uniqueStarts: [Date] = [],
        week: Date? = nil,
        month: Date? = nil,
        year: Int = 2026,
        floor: Date? = nil
    ) -> Date {
        BudgetsViewModel.transactionWindowStart(
            recurringTypes: types,
            uniqueStarts: uniqueStarts,
            selectedWeek: week ?? calendar.startOfWeek(for: now),
            selectedMonth: month ?? calendar.startOfMonth(for: now),
            selectedYear: year,
            requestedFloor: floor,
            now: now,
            calendar: calendar
        )
    }

    @Test("Sin nada más viejo, un año hacia atrás, como antes")
    func baselineIsOneYearBack() {
        #expect(windowStart(types: [.monthly]) == date(2025, 10, 14))
    }

    @Test("Un presupuesto anual en «Año pasado» carga desde el 1 de enero de ese año")
    func yearlyLastYearStartsOnJanuaryFirst() {
        #expect(windowStart(types: [.yearly], year: 2025) == date(2025, 1, 1))
    }

    @Test("El año en curso no ensancha: el 1 de enero queda dentro del último año")
    func yearlyThisYearKeepsTheBaseline() {
        #expect(windowStart(types: [.yearly], year: 2026) == date(2025, 10, 14))
    }

    @Test("Un mes de hace más de un año carga desde el día 1 de ese mes")
    func monthlyOlderThanAYearStartsOnItsFirstDay() {
        #expect(windowStart(types: [.monthly], month: date(2025, 9, 1)) == date(2025, 9, 1))
    }

    @Test("Una semana de hace más de un año carga desde su lunes")
    func weeklyOlderThanAYearStartsOnItsMonday() {
        let week = calendar.startOfWeek(for: date(2025, 3, 12))
        #expect(windowStart(types: [.weekly], week: week) == week)
    }

    @Test("El período elegido de un tipo que no existe no ensancha nada")
    func absentTypeDoesNotWiden() {
        #expect(windowStart(types: [.monthly], year: 2019) == date(2025, 10, 14))
    }

    @Test("Un único que empezó antes carga desde el inicio de su día")
    func uniqueStartsAtTheStartOfItsDay() {
        let start = calendar.date(byAdding: .hour, value: 15, to: date(2024, 6, 3)) ?? .distantPast
        #expect(windowStart(types: [], uniqueStarts: [start]) == calendar.startOfDay(for: start))
    }

    @Test("Lo que pidan las gráficas manda si es lo más viejo")
    func requestedFloorWins() {
        #expect(windowStart(types: [.monthly], floor: date(2023, 2, 1)) == date(2023, 2, 1))
    }
}

// MARK: - El gasto con el store

@MainActor
@Suite(.serialized)
struct BudgetsTransactionWindowStoreTests {

    private let calendar = userConfiguredCalendar()

    /// Un gasto del 2 de enero de hace dos años: siempre más viejo que «un año atrás», haga el día que haga.
    private var oldExpenseDate: Date {
        let year = calendar.component(.year, from: Date.now) - 2
        let day = calendar.date(from: DateComponents(year: year, month: 1, day: 2)) ?? .distantPast
        return calendar.date(byAdding: .hour, value: 12, to: day) ?? day
    }

    private func seed(_ context: ModelContext, budgetPeriod: BudgetPeriodType) throws -> Budget {
        let category = Category(name: "Viajes", colorHex: "#000000", isIncome: false)
        context.insert(category)
        let old = TransactionItem(
            date: oldExpenseDate, amount: -120, currencyCode: "PEN", category: category, amountInPreferredCurrency: -120)
        let recent = TransactionItem(
            date: Date.now, amount: -30, currencyCode: "PEN", category: category, amountInPreferredCurrency: -30)
        context.insert(old)
        context.insert(recent)
        let budget = Budget(currencyCode: "PEN", limitAmount: 1000, name: "Todo", periodType: budgetPeriod.rawValue)
        context.insert(budget)
        try context.save()
        return budget
    }

    @Test("Anual: el año de hace dos años cuenta su gasto del 2 de enero")
    func yearlyBudgetCountsAnExpenseOlderThanAYear() throws {
        let context = try makeTestContext()
        let budget = try seed(context, budgetPeriod: .yearly)
        let vm = BudgetsViewModel()
        vm.selectedPeriodType = .yearly
        vm.selectedYear = calendar.component(.year, from: oldExpenseDate)
        vm.setContext(context)

        let spent = vm.getBudgetSpending(budget: budget, transactions: vm.allTransactions, defaultCurrencyCode: "PEN")
        #expect(spent == 120, "El gasto del año elegido se quedaba fuera de lo cargado.")
        #expect(vm.transactionsLoadedFrom <= oldExpenseDate)
    }

    @Test("Mensual: llevar el período más atrás de lo cargado pide recargar, y al recargar el mes cuenta")
    func monthlyNavigationBeyondTheWindowReloads() throws {
        let context = try makeTestContext()
        let budget = try seed(context, budgetPeriod: .monthly)
        let vm = BudgetsViewModel()
        vm.setContext(context)
        #expect(vm.getBudgetSpending(budget: budget, transactions: vm.allTransactions, defaultCurrencyCode: "PEN") == 30)

        vm.selectedMonth = calendar.startOfMonth(for: oldExpenseDate)
        #expect(vm.requiredTransactionsStart() < vm.transactionsLoadedFrom, "El mes viejo no pedía recargar.")
        vm.loadData()
        #expect(vm.getBudgetSpending(budget: budget, transactions: vm.allTransactions, defaultCurrencyCode: "PEN") == 120)
    }

    @Test("Las gráficas piden su historial y la ventana se ensancha en el acto")
    func chartsRequestWidensTheWindow() throws {
        let context = try makeTestContext()
        _ = try seed(context, budgetPeriod: .monthly)
        let vm = BudgetsViewModel()
        vm.setContext(context)
        #expect(!vm.allTransactions.contains { $0.date == oldExpenseDate })

        vm.ensureTransactionsLoaded(from: calendar.startOfMonth(for: oldExpenseDate))
        #expect(vm.allTransactions.contains { $0.date == oldExpenseDate })
    }

    @Test("Al cerrar las gráficas lo pedido se suelta, y la recarga siguiente vuelve a lo justo")
    func releasingTheChartsRequestShrinksTheNextReload() throws {
        let context = try makeTestContext()
        _ = try seed(context, budgetPeriod: .monthly)
        let vm = BudgetsViewModel()
        vm.setContext(context)
        vm.ensureTransactionsLoaded(from: calendar.startOfMonth(for: oldExpenseDate))
        #expect(vm.allTransactions.contains { $0.date == oldExpenseDate })

        vm.releaseRequestedTransactions()
        vm.loadData()
        #expect(!vm.allTransactions.contains { $0.date == oldExpenseDate }, "Lo pedido por las gráficas se quedó cargado.")
    }

    @Test("Los selectores de período llegan hasta el movimiento más antiguo, no hasta lo cargado")
    func oldestTransactionDateIsTheStoresOldest() throws {
        let context = try makeTestContext()
        _ = try seed(context, budgetPeriod: .monthly)
        let vm = BudgetsViewModel()
        vm.setContext(context)
        #expect(vm.oldestTransactionDate == oldExpenseDate)
        #expect(!vm.allTransactions.contains { $0.date == oldExpenseDate }, "El control: lo cargado no llega ahí.")
    }
}
