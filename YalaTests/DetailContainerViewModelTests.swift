//
//  DetailContainerViewModelTests.swift
//  YalaTests
//
//  Tests for DetailContainerViewModel - computed properties and date range logic.
//  Data loading requires ModelContext, but we test initial state, the
//  canUseVoiceInput logic, and computeTransactionDateRange with empty data.
//  We also test the underlying Account/Subcategory model properties that
//  drive the computed properties.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct DetailContainerViewModelTests {

    // MARK: - Initial State

    @MainActor @Test("Initial state has empty allTransactions")
    func initialState_allTransactionsEmpty() {
        let vm = DetailContainerViewModel()
        #expect(vm.allTransactions.isEmpty)
    }

    @MainActor @Test("Initial state has empty accounts")
    func initialState_accountsEmpty() {
        let vm = DetailContainerViewModel()
        #expect(vm.accounts.isEmpty)
    }

    @MainActor @Test("Initial state has empty categories")
    func initialState_categoriesEmpty() {
        let vm = DetailContainerViewModel()
        #expect(vm.categories.isEmpty)
    }

    @MainActor @Test("Initial state has empty allSubcategories")
    func initialState_allSubcategoriesEmpty() {
        let vm = DetailContainerViewModel()
        #expect(vm.allSubcategories.isEmpty)
    }

    @MainActor @Test("Initial state has empty tags")
    func initialState_tagsEmpty() {
        let vm = DetailContainerViewModel()
        #expect(vm.tags.isEmpty)
    }

    @MainActor @Test("Initial state has empty budgets")
    func initialState_budgetsEmpty() {
        let vm = DetailContainerViewModel()
        #expect(vm.budgets.isEmpty)
    }

    @MainActor @Test("Initial state has empty scheduledPayments")
    func initialState_scheduledPaymentsEmpty() {
        let vm = DetailContainerViewModel()
        #expect(vm.scheduledPayments.isEmpty)
    }

    // MARK: - loadData without context

    @MainActor @Test("loadData without context does not crash and keeps empty")
    func loadData_withoutContext_keepsEmpty() {
        let vm = DetailContainerViewModel()
        vm.loadData()
        #expect(vm.allTransactions.isEmpty)
        #expect(vm.accounts.isEmpty)
        #expect(vm.categories.isEmpty)
        #expect(vm.allSubcategories.isEmpty)
        #expect(vm.tags.isEmpty)
        #expect(vm.budgets.isEmpty)
        #expect(vm.scheduledPayments.isEmpty)
    }

    // MARK: - canUseVoiceInput

    @MainActor @Test("canUseVoiceInput returns false when no data loaded")
    func canUseVoiceInput_noData_returnsFalse() {
        let vm = DetailContainerViewModel()
        #expect(vm.canUseVoiceInput == false)
    }

    // MARK: - canUseVoiceInput underlying logic (Account + Subcategory models)

    @Test("Account isArchived defaults to false")
    func account_isArchived_defaultsFalse() {
        let account = Account(
            name: "Test",
            currencyCode: "PEN",
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "bank"
        )
        #expect(account.isArchived == false)
    }

    @Test("Account can be archived")
    func account_canBeArchived() {
        let account = Account(
            name: "Old Account",
            currencyCode: "PEN",
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "bank",
            isArchived: true
        )
        #expect(account.isArchived == true)
    }

    @Test("Subcategory isVisible defaults to true")
    func subcategory_isVisible_defaultsTrue() {
        let category = YalaCategory(name: "Expenses", colorHex: "#FF0000", isIncome: false)
        let sub = Subcategory(name: "Food", colorHex: nil, iconName: "cart", category: category)
        #expect(sub.isVisible == true)
    }

    @Test("Subcategory can be hidden")
    func subcategory_canBeHidden() {
        let category = YalaCategory(name: "Expenses", colorHex: "#FF0000", isIncome: false)
        let sub = Subcategory(name: "Hidden", colorHex: nil, iconName: "cart", category: category)
        sub.isVisible = false
        #expect(sub.isVisible == false)
    }

    @Test("canUseVoiceInput logic: needs active account AND visible subcategory")
    func canUseVoiceInput_logic_needsBothConditions() {
        let category = YalaCategory(name: "Expenses", colorHex: "#FF0000", isIncome: false)

        let activeAccount = Account(
            name: "Active",
            currencyCode: "PEN",
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "bank"
        )
        let archivedAccount = Account(
            name: "Archived",
            currencyCode: "PEN",
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "bank",
            isArchived: true
        )
        let visibleSub = Subcategory(name: "Food", colorHex: nil, iconName: "cart", category: category)
        let hiddenSub = Subcategory(name: "Hidden", colorHex: nil, iconName: "cart", category: category)
        hiddenSub.isVisible = false

        // Case 1: active account + visible subcategory = true
        let accounts1 = [activeAccount]
        let subs1 = [visibleSub]
        let result1 = accounts1.contains { !$0.isArchived } && subs1.contains { $0.isVisible }
        #expect(result1 == true)

        // Case 2: only archived accounts = false
        let accounts2 = [archivedAccount]
        let subs2 = [visibleSub]
        let result2 = accounts2.contains { !$0.isArchived } && subs2.contains { $0.isVisible }
        #expect(result2 == false)

        // Case 3: active account but only hidden subcategories = false
        let accounts3 = [activeAccount]
        let subs3 = [hiddenSub]
        let result3 = accounts3.contains { !$0.isArchived } && subs3.contains { $0.isVisible }
        #expect(result3 == false)

        // Case 4: empty arrays = false
        let result4 = [Account]().contains { !$0.isArchived } && [Subcategory]().contains { $0.isVisible }
        #expect(result4 == false)
    }

    // MARK: - computeTransactionDateRange

    @MainActor @Test("computeTransactionDateRange with empty transactions returns today for both")
    func computeTransactionDateRange_empty_returnsTodayForBoth() {
        let vm = DetailContainerViewModel()
        let before = Date()
        let range = vm.computeTransactionDateRange()
        let after = Date()

        // Both start and end should be approximately "now" (within a second)
        #expect(range.start >= before.addingTimeInterval(-1))
        #expect(range.start <= after.addingTimeInterval(1))
        #expect(range.end >= before.addingTimeInterval(-1))
        #expect(range.end <= after.addingTimeInterval(1))
    }

    // MARK: - computeTransactionDateRange underlying logic

    @Test("Date range logic with sorted dates picks first and last")
    func dateRangeLogic_sortsAndPicksFirstLast() {
        let date1 = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11
        let date2 = Date(timeIntervalSince1970: 1_710_000_000) // 2024-03
        let date3 = Date(timeIntervalSince1970: 1_720_000_000) // 2024-07

        let dates = [date3, date1, date2] // Out of order
        let sorted = dates.sorted()

        let start = sorted.first!
        let end = sorted.last!

        #expect(start == date1)
        #expect(end == date3)
    }

    @Test("Date range logic with single date returns same for start and end")
    func dateRangeLogic_singleDate_sameBoth() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let dates = [date]
        let sorted = dates.sorted()

        #expect(sorted.first == sorted.last)
    }
}

/*
Tests generated:
1. initialState_allTransactionsEmpty - All 7 arrays start empty
2-7. initialState_* - Each array verified independently
8. loadData_withoutContext_keepsEmpty - No crash without context
9. canUseVoiceInput_noData_returnsFalse - Requires data to be true
10. account_isArchived_defaultsFalse - Account model default
11. account_canBeArchived - Account archive property
12. subcategory_isVisible_defaultsTrue - Subcategory model default
13. subcategory_canBeHidden - Subcategory visibility
14. canUseVoiceInput_logic_needsBothConditions - All 4 combinations tested
15. computeTransactionDateRange_empty_returnsTodayForBoth - Empty fallback
16. dateRangeLogic_sortsAndPicksFirstLast - Sorting logic
17. dateRangeLogic_singleDate_sameBoth - Single element edge case

Cases NOT covered (require ModelContext):
- canUseVoiceInput with populated accounts/subcategories via ViewModel
  (both are private(set), populated only via fetch)
- computeTransactionDateRange with populated transactions via ViewModel
*/
