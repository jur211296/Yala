//
//  BudgetSharedExpenseTests.swift
//  YalaTests
//
//  Tests for Budget.includeSharedExpenses filtering in BudgetsViewModel.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct BudgetSharedExpenseTests {

    // MARK: - Helpers

    private func makeBudget(includeSharedExpenses: Bool = true) -> Budget {
        Budget(
            currencyCode: "PEN",
            limitAmount: 1000,
            name: "Test Budget",
            includeSharedExpenses: includeSharedExpenses
        )
    }

    private let expenseCategory = Category(name: "Test", colorHex: "#000", isIncome: false)

    private func makeTransaction(
        amount: Double,
        splitExpenseID: String? = nil,
        date: Date = Date.now
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "PEN",
            category: expenseCategory,
            amountInPreferredCurrency: amount
        )
        tx.splitExpenseID = splitExpenseID
        return tx
    }

    // MARK: - Tests

    @Test func includeSharedTrue_includesAllTransactions() {
        let budget = makeBudget(includeSharedExpenses: true)
        let personal = makeTransaction(amount: 100)
        let shared = makeTransaction(amount: 200, splitExpenseID: "some-expense-id")

        let interval = DateInterval(start: Date.distantPast, end: Date.distantFuture)
        let filtered = BudgetsViewModel.filterTransactions([personal, shared], forBudget: budget, in: interval)

        #expect(filtered.count == 2)
    }

    @Test func includeSharedFalse_excludesSharedTransactions() {
        let budget = makeBudget(includeSharedExpenses: false)
        let personal = makeTransaction(amount: 100)
        let shared = makeTransaction(amount: 200, splitExpenseID: "some-expense-id")

        let interval = DateInterval(start: Date.distantPast, end: Date.distantFuture)
        let filtered = BudgetsViewModel.filterTransactions([personal, shared], forBudget: budget, in: interval)

        #expect(filtered.count == 1)
        #expect(filtered.first?.splitExpenseID == nil)
    }

    @Test func defaultValue_isTrue() {
        let budget = Budget(currencyCode: "PEN", limitAmount: 500)
        #expect(budget.includeSharedExpenses == true)
    }
}
