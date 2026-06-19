//
//  FullFinancialContextBudgetSpendingTests.swift
//  YalaTests
//
//  Regression tests for the chat context builder budget-spending fix.
//
//  Bug (fixed in FullFinancialContextBuilder.buildBudgets): `spent` was computed
//  by filtering transactions on the LEGACY to-one `budget.category` relation. The
//  modern budget system (BudgetEditorViewModel.save) NEVER sets `budget.category`;
//  it configures filters via the CSV mirror (subcategoryIDs/accountIDs/tagIDs) +
//  natures. So ANY budget created with the current app (category == nil) yielded
//  spent = 0 / 0% / .onTrack — the chat told users they were perfectly on track
//  even when the budget was exceeded.
//
//  The fix delegates to the canonical `BudgetsViewModel.calculateSpending(...)`,
//  which filters via `resolvedSubcategoryIDs/AccountIDs/TagIDs/natures` (CSV mirror
//  SSOT) and converts with the current rate. These tests exercise that canonical
//  path directly with in-memory @Model instances (no ModelContext — R8 pure-logic),
//  mirroring the established pattern in BudgetSharedExpenseTests.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct FullFinancialContextBudgetSpendingTests {

    // MARK: - Helpers

    private let expenseCategory = Category(name: "Gastos", colorHex: "#111111", isIncome: false)
    private let incomeCategory = Category(name: "Ingresos", colorHex: "#222222", isIncome: true)

    /// A subcategory with a known, stable `shortcutID` so the CSV mirror filter can match it.
    private func makeSubcategory(shortcutID: UUID) -> Subcategory {
        let sub = Subcategory(name: "Restaurantes", category: expenseCategory)
        sub.shortcutID = shortcutID
        return sub
    }

    /// Modern budget: NO `category` set, filtered exclusively via the CSV mirror
    /// (`subcategoryIDs`). This is exactly what BudgetEditorViewModel produces today.
    private func makeModernBudget(subcategoryShortcutIDs: [UUID], limit: Double = 500) -> Budget {
        Budget(
            currencyCode: "PEN",
            limitAmount: limit,
            category: nil,
            name: "Comidas",
            subcategoryIDs: CSVMirrorCodec.encode(subcategoryShortcutIDs)
        )
    }

    private func makeExpense(
        amount: Double,
        subcategory: Subcategory? = nil,
        income: Bool = false,
        date: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> TransactionItem {
        TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "PEN",
            category: income ? incomeCategory : expenseCategory,
            subcategory: subcategory,
            amountInPreferredCurrency: amount
        )
    }

    private let wideInterval = DateInterval(start: .distantPast, end: .distantFuture)

    // MARK: - Bug reproduction

    /// THE BUG: a modern budget (category == nil, filtered via CSV subcategoryIDs)
    /// with matching expenses must report non-zero spending. The old `byCategory`
    /// path returned 0 here because `budget.category` was nil.
    @Test func modernBudget_filteredBySubcategoryCSV_countsSpending() {
        let subID = UUID()
        let sub = makeSubcategory(shortcutID: subID)
        let budget = makeModernBudget(subcategoryShortcutIDs: [subID], limit: 500)

        let matching1 = makeExpense(amount: 300, subcategory: sub)
        let matching2 = makeExpense(amount: 250, subcategory: sub)

        let spent = BudgetsViewModel.calculateSpending(
            budget: budget,
            transactions: [matching1, matching2],
            interval: wideInterval
        )

        // Old buggy path → 0. Canonical path → 550 (matches what the app shows).
        #expect(spent == 550)

        // And the derived status the chat reports must reflect an EXCEEDED budget,
        // not the false ".onTrack" the bug produced.
        let usagePct = (spent / budget.limitAmount) * 100
        #expect(abs(usagePct - 110) < 0.0001)
        #expect(usagePct >= 100) // → FullFinancialContext.BudgetStatus.exceeded
    }

    // MARK: - Correct filtering

    /// Only transactions whose subcategory is in the budget's filter set are summed.
    @Test func modernBudget_excludesNonMatchingSubcategory() {
        let budgetSubID = UUID()
        let otherSubID = UUID()
        let budgetSub = makeSubcategory(shortcutID: budgetSubID)
        let otherSub = makeSubcategory(shortcutID: otherSubID)
        let budget = makeModernBudget(subcategoryShortcutIDs: [budgetSubID])

        let inBudget = makeExpense(amount: 100, subcategory: budgetSub)
        let outOfBudget = makeExpense(amount: 999, subcategory: otherSub)

        let spent = BudgetsViewModel.calculateSpending(
            budget: budget,
            transactions: [inBudget, outOfBudget],
            interval: wideInterval
        )

        #expect(spent == 100)
    }

    /// Income transactions must never count toward budget spending, even if their
    /// subcategory happens to match the filter.
    @Test func modernBudget_excludesIncomeTransactions() {
        let subID = UUID()
        let sub = makeSubcategory(shortcutID: subID)
        let budget = makeModernBudget(subcategoryShortcutIDs: [subID])

        let expense = makeExpense(amount: 80, subcategory: sub)
        let income = makeExpense(amount: 5000, subcategory: sub, income: true)

        let spent = BudgetsViewModel.calculateSpending(
            budget: budget,
            transactions: [expense, income],
            interval: wideInterval
        )

        #expect(spent == 80)
    }

    // MARK: - Edge cases

    /// Empty transaction set → 0 (no crash, no false positive).
    @Test func modernBudget_noTransactions_isZero() {
        let subID = UUID()
        let budget = makeModernBudget(subcategoryShortcutIDs: [subID])

        let spent = BudgetsViewModel.calculateSpending(
            budget: budget,
            transactions: [],
            interval: wideInterval
        )

        #expect(spent == 0)
    }

    /// Transactions outside the budget interval are excluded.
    @Test func modernBudget_outsideInterval_excluded() {
        let subID = UUID()
        let sub = makeSubcategory(shortcutID: subID)
        let budget = makeModernBudget(subcategoryShortcutIDs: [subID])

        let janStart = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01
        let febStart = Date(timeIntervalSince1970: 1_706_745_600) // 2024-02-01
        let marStart = Date(timeIntervalSince1970: 1_709_251_200) // 2024-03-01
        let interval = DateInterval(start: febStart, end: marStart)

        let inside = makeExpense(amount: 100, subcategory: sub, date: febStart)
        let before = makeExpense(amount: 200, subcategory: sub, date: janStart)

        let spent = BudgetsViewModel.calculateSpending(
            budget: budget,
            transactions: [inside, before],
            interval: interval
        )

        #expect(spent == 100)
    }
}
