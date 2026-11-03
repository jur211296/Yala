//
//  WidgetDataCacheTests.swift
//  YalaTests
//
//  Tests de regresión para WidgetDataCache: paridad con la app principal en
//  clasificación de income (category.isIncome, no signo), filtros split,
//  conversión multi-divisa y exclusión de cuentas de stats.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct WidgetDataCacheTests {

    // MARK: - Helpers

    private let expenseCategory = Yala.Category(name: "Food", colorHex: "#000", isIncome: false)
    private let incomeCategory = Yala.Category(name: "Refund", colorHex: "#0F0", isIncome: true)

    private func makeTx(
        amount: Double,
        category: Yala.Category?,
        splitExpenseID: String? = nil,
        currencyCode: String = "PEN",
        amountInPreferredCurrency: Double? = nil,
        date: Date = Date.now
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: currencyCode,
            category: category,
            amountInPreferredCurrency: amountInPreferredCurrency ?? amount
        )
        tx.splitExpenseID = splitExpenseID
        return tx
    }

    private func makeBudget(
        currencyCode: String = "PEN",
        limit: Double = 1000,
        includeSharedExpenses: Bool = true
    ) -> Budget {
        Budget(
            currencyCode: currencyCode,
            limitAmount: limit,
            name: "Test",
            includeSharedExpenses: includeSharedExpenses
        )
    }

    private var fullInterval: DateInterval {
        DateInterval(start: Date.distantPast, end: Date.distantFuture)
    }

    // MARK: - Budget spent

    @Test func budgetSpent_classifiesIncomeByCategoryNotSign() {
        // Refund: monto negativo + category.isIncome=true → NO cuenta como spent.
        let budget = makeBudget()
        let refund = makeTx(amount: -50, category: incomeCategory)
        let realExpense = makeTx(amount: -100, category: expenseCategory)

        let spent = BudgetsViewModel.calculateSpending(
            budget: budget,
            transactions: [refund, realExpense],
            interval: fullInterval
        )

        #expect(spent == 100)
    }

    @Test func budgetSpent_excludesSplitExpensesWhenIncludeSharedExpensesFalse() {
        let budget = makeBudget(includeSharedExpenses: false)
        let personal = makeTx(amount: -100, category: expenseCategory)
        let shared = makeTx(amount: -200, category: expenseCategory, splitExpenseID: "split-1")

        let spent = BudgetsViewModel.calculateSpending(
            budget: budget,
            transactions: [personal, shared],
            interval: fullInterval
        )

        #expect(spent == 100)
    }

    @Test func budgetSpent_multiCurrencyConvertsToBudgetCurrency() {
        // Budget PEN, tx USD: con converter mock rate=3.8 → 100 USD == 380 PEN.
        // Verifica que se usa budgetAmount con converter, NO amountInPreferredCurrency.
        let budget = makeBudget(currencyCode: "PEN")
        let txUSD = makeTx(
            amount: -100,
            category: expenseCategory,
            currencyCode: "USD",
            amountInPreferredCurrency: -999  // valor distraído: NO se debe usar
        )

        let converter = MockCurrencyConverter(fixedRate: Decimal(3.8))

        let spent = BudgetsViewModel.calculateSpending(
            budget: budget,
            transactions: [txUSD],
            interval: fullInterval,
            converter: converter
        )

        #expect(spent == 380)
    }

    // MARK: - Period summary

    @Test func periodSummary_classifiesIncomeByCategoryNotSign() {
        // Un importe negativo en categoría de ingreso es del lado del ingreso (lo decide la categoría) y, con signo, lo
        // RESTA: como el Flujo de caja y Registros de la app (desde el 2026-10-23; antes sumaba su magnitud).
        let refund = makeTx(amount: -50, category: incomeCategory)
        let realExpense = makeTx(amount: -200, category: expenseCategory)
        let realIncome = makeTx(amount: 1000, category: incomeCategory)

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: [refund, realExpense, realIncome],
            periodStart: Date.distantPast,
            periodEnd: Date.distantFuture,
            currencyCode: "PEN"
        )

        #expect(summary.totalIncome == 950)  // 1000 de ingreso − 50 en contra, en su mismo lado
        #expect(summary.totalExpense == 200)
    }

    /// Un movimiento sin categoría cuenta por su signo (decisión de Jürgen del 2026-09-06): hasta el 2026-10-23 el widget
    /// lo descartaba y contaba otro mes que Registros.
    @Test func periodSummary_uncategorizedCountsBySign() {
        let orphan = makeTx(amount: 500, category: nil)
        let orphanExpense = makeTx(amount: -30, category: nil)
        let realExpense = makeTx(amount: -100, category: expenseCategory)

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: [orphan, orphanExpense, realExpense],
            periodStart: Date.distantPast,
            periodEnd: Date.distantFuture,
            currencyCode: "PEN"
        )

        #expect(summary.totalIncome == 500)
        #expect(summary.totalExpense == 130)
    }

    // MARK: - Top categories

    @Test func topCategories_excludesIncomeCategories() {
        // Tx con category.isIncome=true no aparece aunque tenga monto negativo.
        let refund = makeTx(amount: -50, category: incomeCategory)
        let expense = makeTx(amount: -100, category: expenseCategory)

        let top = WidgetDataCache.buildTopCategories(
            transactions: [refund, expense],
            totalExpense: 100,
            limit: 10,
            currencyCode: "PEN"
        )

        #expect(top.count == 1)
        #expect(top.first?.name == "Food")
        #expect(top.first?.amount == 100)
    }

    // MARK: - Desglose con una devolución (card znu5)

    /// Un gasto de 100 en Comida, su devolución de 30 (positiva, en la misma categoría de gasto) y 50 de Transporte. La
    /// foto lleva Comida 70 y Transporte 50, porcentajes que suman 100 % y un total del desglose de 120: el centro de la
    /// tarta es la suma de sus filas y coincide con el gasto del período. Antes salía Comida 130 (108 %) con centro 120.
    @Test func periodSummary_aRefundLeavesPercentagesAt100AndTheCenterAtTheSumOfTheRows() {
        let food = makeTx(amount: -100, category: expenseCategory)
        let foodRefund = makeTx(amount: 30, category: expenseCategory)
        let transport = makeTx(amount: -50, category: Yala.Category(name: "Transport", colorHex: "#111", isIncome: false))

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: [food, foodRefund, transport],
            periodStart: Date.distantPast,
            periodEnd: Date.distantFuture,
            currencyCode: "PEN"
        )

        #expect(summary.totalExpense == 120)
        #expect(summary.topCategories.map(\.name) == ["Food", "Transport"])
        #expect(summary.topCategories.map(\.amount) == [70, 50])
        let rows = summary.topCategories.reduce(0) { $0 + $1.amount }
        #expect(summary.expenseBreakdownTotal == rows)
        #expect(summary.expenseBreakdownTotal == summary.totalExpense)
        let percentages = summary.topCategories.reduce(0) { $0 + $1.percentage }
        #expect(abs(percentages - 100) < 1e-9)
    }

    /// Las subcategorías también van en neto y se miden contra el total de su desglose: lo que no tiene subcategoría
    /// queda fuera de las filas y la tarta lo lleva a «Otros».
    @Test func periodSummary_subcategoriesNetTheRefundAndMeasureAgainstTheCategoryTotal() {
        let groceries = Subcategory(name: "Groceries", category: expenseCategory)
        let food = makeTx(amount: -100, category: expenseCategory)
        food.subcategory = groceries
        let refund = makeTx(amount: 30, category: expenseCategory)
        refund.subcategory = groceries
        let other = makeTx(amount: -50, category: expenseCategory)

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: [food, refund, other],
            periodStart: Date.distantPast,
            periodEnd: Date.distantFuture,
            currencyCode: "PEN"
        )

        #expect(summary.expenseBreakdownTotal == 120)
        #expect(summary.expenseSubcategoryBreakdownTotal == 120)  // sin signos mezclados, los dos totales coinciden
        #expect(summary.topSubcategories.map(\.amount) == [70])
        let percentage = summary.topSubcategories.first?.percentage ?? 0
        #expect(abs(percentage - 70.0 / 120.0 * 100) < 1e-9)
    }

    /// Una devolución en la categoría SIN subcategoría: el trozo de Comida neta 20, pero la fila de Restaurante sigue en
    /// 100. Las subcategorías se miden contra su propio desglose (Restaurante 100 + el resto de Comida 80 = 180), así que
    /// la fila no pasa del 100 % ni de su centro. Lo cazó la review de la card znu5 (salía 500 %).
    @Test func periodSummary_aRefundWithoutSubcategoryDoesNotPushTheSubcategoryRowsOverTheirTotal() {
        let restaurant = Subcategory(name: "Restaurant", category: expenseCategory)
        let dinner = makeTx(amount: -100, category: expenseCategory)
        dinner.subcategory = restaurant
        let refund = makeTx(amount: 80, category: expenseCategory)

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: [dinner, refund],
            periodStart: Date.distantPast,
            periodEnd: Date.distantFuture,
            currencyCode: "PEN"
        )

        #expect(summary.expenseBreakdownTotal == 20)
        #expect(summary.expenseSubcategoryBreakdownTotal == 180)
        #expect(summary.topSubcategories.map(\.amount) == [100])
        let percentage = summary.topSubcategories.first?.percentage ?? 0
        #expect(abs(percentage - 100.0 / 180.0 * 100) < 1e-9)
        #expect(summary.topSubcategories.reduce(0) { $0 + $1.amount } <= (summary.expenseSubcategoryBreakdownTotal ?? 0))
    }

    /// Una categoría a favor: los porcentajes siguen sumando 100 % (se miden contra la suma de los trozos) aunque el gasto
    /// con signo del período sea menor que esa suma.
    @Test func periodSummary_aCategoryInFavorStillAddsUpTo100() {
        let food = makeTx(amount: -10, category: expenseCategory)
        let bigRefund = makeTx(amount: 30, category: expenseCategory)
        let transport = makeTx(amount: -50, category: Yala.Category(name: "Transport", colorHex: "#111", isIncome: false))

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: [food, bigRefund, transport],
            periodStart: Date.distantPast,
            periodEnd: Date.distantFuture,
            currencyCode: "PEN"
        )

        #expect(summary.totalExpense == 30)
        #expect(summary.expenseBreakdownTotal == 70)
        let percentages = summary.topCategories.reduce(0) { $0 + $1.percentage }
        #expect(abs(percentages - 100) < 1e-9)
    }

    // MARK: - Cash flow by day

    @Test func cashFlowByDay_classifiesIncomeByCategoryNotSign() {
        let day = Date.now
        let refund = makeTx(amount: -50, category: incomeCategory, date: day)
        let expense = makeTx(amount: -100, category: expenseCategory, date: day)

        let points = WidgetDataCache.buildCashFlowByDay(
            transactions: [refund, expense],
            periodStart: Calendar.current.startOfDay(for: day),
            periodEnd: Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day,
            currencyCode: "PEN"
        )

        let dayPoint = points.first
        #expect(dayPoint?.income == -50)  // negativo en categoría de ingreso: su lado, con signo (como los totales)
        #expect(dayPoint?.expense == 100)
    }

    // MARK: - Account visibility

    @Test func filterVisibleAccountsForWidget_excludesArchivedAndExcludedFromStats() {
        let visible = Account(name: "Visible", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "bank")
        let archived = Account(name: "Archived", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "bank", isArchived: true)
        let excluded = Account(name: "Excluded", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "bank", excludeFromStatistics: true)

        let filtered = WidgetDataCache.filterVisibleAccountsForWidget([visible, archived, excluded])

        #expect(filtered.count == 1)
        #expect(filtered.first?.name == "Visible")
    }
}
