//
//  BudgetBalanceAdjustmentExclusionTests.swift
//  YalaTests
//
//  Regression tests for BudgetsViewModel.filterTransactions excluding
//  balance-adjustment transactions (initial_balance / adjustment).
//
//  Bug: balance-adjustment transactions live under the "Otros" category
//  with isIncome=false, so they passed the `category?.isIncome == false`
//  type filter and got summed as expenses via abs(amount) in calculateSpending.
//  This inflated "consumido" % and fired spurious BudgetAlertService
//  notifications (which share the same filterTransactions SSOT).
//
//  Fix: filterTransactions now drops `balanceAdjustmentType != nil`,
//  consistent with FinancialReportViewModel / CashFlowPlanViewModel.
//
//  Pure-logic: filterTransactions operates on in-memory @Model objects built
//  via their init — no ModelContext (mirrors BudgetSharedExpenseTests).
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct BudgetBalanceAdjustmentExclusionTests {

    // MARK: - Helpers

    /// Expense category (isIncome=false) — same nature as the "Otros" category
    /// under which the "Ajuste de saldo" subcategory lives.
    private let expenseCategory = Category(name: "Otros", colorHex: "#000", isIncome: false)

    /// Budget with NO filters → resolved*IDs() all return nil → "todos los gastos".
    private func makeUnfilteredBudget() -> Budget {
        Budget(currencyCode: "PEN", limitAmount: 1000, name: "Total Budget")
    }

    private func makeTransaction(
        amount: Double,
        balanceAdjustmentType: String? = nil,
        tagIDs: String? = nil,
        date: Date = Date.now
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "PEN",
            category: expenseCategory,
            amountInPreferredCurrency: amount
        )
        tx.balanceAdjustmentType = balanceAdjustmentType
        tx.tagIDs = tagIDs
        return tx
    }

    private let allTime = DateInterval(start: Date.distantPast, end: Date.distantFuture)

    // MARK: - Bug case

    @Test func initialBalanceTransaction_isExcludedFromUnfilteredBudget() {
        // The exact bug: a large initial balance under an expense-natured
        // category would inflate spending on a "todos los gastos" budget.
        let budget = makeUnfilteredBudget()
        let initialBalance = makeTransaction(amount: 5000, balanceAdjustmentType: "initial_balance")

        let filtered = BudgetsViewModel.filterTransactions([initialBalance], forBudget: budget, in: allTime)

        #expect(filtered.isEmpty)
    }

    @Test func adjustmentTransaction_isExcludedFromUnfilteredBudget() {
        let budget = makeUnfilteredBudget()
        let adjustment = makeTransaction(amount: 1200, balanceAdjustmentType: "adjustment")

        let filtered = BudgetsViewModel.filterTransactions([adjustment], forBudget: budget, in: allTime)

        #expect(filtered.isEmpty)
    }

    // MARK: - Correct case

    @Test func normalExpense_isIncludedFromUnfilteredBudget() {
        let budget = makeUnfilteredBudget()
        let expense = makeTransaction(amount: 80, balanceAdjustmentType: nil)

        let filtered = BudgetsViewModel.filterTransactions([expense], forBudget: budget, in: allTime)

        #expect(filtered.count == 1)
        #expect(filtered.first?.balanceAdjustmentType == nil)
    }

    // MARK: - Mixed list (only normal expenses survive)

    @Test func mixedList_keepsOnlyNonAdjustmentExpenses() {
        let budget = makeUnfilteredBudget()
        let expense1 = makeTransaction(amount: 30)
        let expense2 = makeTransaction(amount: 70)
        let initial = makeTransaction(amount: 5000, balanceAdjustmentType: "initial_balance")
        let adjustment = makeTransaction(amount: 200, balanceAdjustmentType: "adjustment")

        let filtered = BudgetsViewModel.filterTransactions(
            [expense1, initial, expense2, adjustment],
            forBudget: budget,
            in: allTime
        )

        #expect(filtered.count == 2)
        #expect(filtered.allSatisfy { $0.balanceAdjustmentType == nil })
    }

    // MARK: - Tag-only filtered budget (called out explicitly in the bug report)

    @Test func tagOnlyBudget_stillExcludesAdjustmentSharingTheTag() {
        // A budget filtered ONLY by tag must still drop balance adjustments that
        // happen to carry that tag — proves the exclusion is independent of filters.
        let tagID = UUID()
        let csv = tagID.uuidString

        let budget = Budget(currencyCode: "PEN", limitAmount: 500, name: "Tag Budget", tagIDs: csv)

        // Both transactions carry the budget's tag (CSV mirror = SSOT read path).
        let taggedExpense = makeTransaction(amount: 40, tagIDs: csv)
        let taggedInitial = makeTransaction(amount: 5000, balanceAdjustmentType: "initial_balance", tagIDs: csv)

        let filtered = BudgetsViewModel.filterTransactions(
            [taggedExpense, taggedInitial],
            forBudget: budget,
            in: allTime
        )

        #expect(filtered.count == 1)
        #expect(filtered.first?.balanceAdjustmentType == nil)
        #expect(filtered.first?.amount == 40)
    }

    // MARK: - Spending calculation reflects the exclusion

    @Test func calculateSpending_doesNotCountInitialBalance() {
        // End-to-end through the SSOT consumer: spending must equal only the
        // real expense, NOT the inflated total including the initial balance.
        let budget = makeUnfilteredBudget()
        let expense = makeTransaction(amount: 80)
        let initial = makeTransaction(amount: 5000, balanceAdjustmentType: "initial_balance")

        let spending = BudgetsViewModel.calculateSpending(
            budget: budget,
            transactions: [expense, initial],
            interval: allTime
        )

        #expect(spending == 80)
    }
}
