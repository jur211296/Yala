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
        // Refund (negativo + isIncome=true) suma a totalIncome, NO a totalExpense.
        let refund = makeTx(amount: -50, category: incomeCategory)
        let realExpense = makeTx(amount: -200, category: expenseCategory)
        let realIncome = makeTx(amount: 1000, category: incomeCategory)

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: [refund, realExpense, realIncome],
            periodStart: Date.distantPast,
            periodEnd: Date.distantFuture,
            currencyCode: "PEN"
        )

        #expect(summary.totalIncome == 1050)  // 50 refund + 1000 income
        #expect(summary.totalExpense == 200)
    }

    @Test func periodSummary_skipsTxWithoutCategory() {
        // Tx sin categoría no se clasifica como income ni como expense.
        let orphan = makeTx(amount: 500, category: nil)
        let realExpense = makeTx(amount: -100, category: expenseCategory)

        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: [orphan, realExpense],
            periodStart: Date.distantPast,
            periodEnd: Date.distantFuture,
            currencyCode: "PEN"
        )

        #expect(summary.totalIncome == 0)
        #expect(summary.totalExpense == 100)
    }

    // MARK: - Top categories

    @Test func topCategories_excludesIncomeCategories() {
        // Tx con category.isIncome=true no aparece aunque tenga monto negativo.
        let refund = makeTx(amount: -50, category: incomeCategory)
        let expense = makeTx(amount: -100, category: expenseCategory)

        let top = WidgetDataCache.buildTopCategories(
            transactions: [refund, expense],
            totalExpense: 100,
            limit: 10
        )

        #expect(top.count == 1)
        #expect(top.first?.name == "Food")
        #expect(top.first?.amount == 100)
    }

    // MARK: - Cash flow by day

    @Test func cashFlowByDay_classifiesIncomeByCategoryNotSign() {
        let day = Date.now
        let refund = makeTx(amount: -50, category: incomeCategory, date: day)
        let expense = makeTx(amount: -100, category: expenseCategory, date: day)

        let points = WidgetDataCache.buildCashFlowByDay(
            transactions: [refund, expense],
            periodStart: Calendar.current.startOfDay(for: day),
            periodEnd: Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
        )

        let dayPoint = points.first
        #expect(dayPoint?.income == 50)  // refund: negativo + isIncome → income (abs)
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
