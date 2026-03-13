//
//  AccountsSettingsListViewModelTests.swift
//  YalaTests
//
//  Tests for AccountsSettingsListViewModel UI state and initial state.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct AccountsSettingsListViewModelTests {

    // MARK: - Initial State

    @MainActor @Test func initialState_accountsEmpty() {
        let vm = AccountsSettingsListViewModel()
        #expect(vm.accounts.isEmpty)
    }

    @MainActor @Test func initialState_transactionsEmpty() {
        let vm = AccountsSettingsListViewModel()
        #expect(vm.transactions.isEmpty)
    }

    @MainActor @Test func initialState_isEmptyTrue() {
        let vm = AccountsSettingsListViewModel()
        #expect(vm.isEmpty == true)
    }

    @MainActor @Test func initialState_isPresentingCreateAccountFalse() {
        let vm = AccountsSettingsListViewModel()
        #expect(vm.isPresentingCreateAccount == false)
    }

    @MainActor @Test func initialState_accountToEditNil() {
        let vm = AccountsSettingsListViewModel()
        #expect(vm.accountToEdit == nil)
    }

    @MainActor @Test func initialState_isEditModeFalse() {
        let vm = AccountsSettingsListViewModel()
        #expect(vm.isEditMode == false)
    }

    // MARK: - Sort Order Raw Parsing

    @MainActor @Test func sortOrderNamesRaw_emptySplitsToEmpty() {
        let vm = AccountsSettingsListViewModel()
        vm.accountsSortOrderNamesRaw = ""
        // orderedActiveAccounts with empty accounts should be empty
        #expect(vm.orderedActiveAccounts.isEmpty)
    }

    @MainActor @Test func sortOrderNamesRaw_invalidatesOnChange() {
        let vm = AccountsSettingsListViewModel()
        vm.accountsSortOrderNamesRaw = "A|B|C"
        // Access to build cache
        _ = vm.orderedActiveAccounts
        // Change invalidates
        vm.accountsSortOrderNamesRaw = "C|B|A"
        // No crash, still works
        #expect(vm.orderedActiveAccounts.isEmpty) // Empty because accounts is empty
    }

    // MARK: - UI State Management

    @MainActor @Test func uiState_toggleEditMode() {
        let vm = AccountsSettingsListViewModel()
        vm.isEditMode = true
        #expect(vm.isEditMode == true)
        vm.isEditMode = false
        #expect(vm.isEditMode == false)
    }

    @MainActor @Test func uiState_setPresentingCreateAccount() {
        let vm = AccountsSettingsListViewModel()
        vm.isPresentingCreateAccount = true
        #expect(vm.isPresentingCreateAccount == true)
    }

    @MainActor @Test func uiState_setAccountToEdit() {
        let vm = AccountsSettingsListViewModel()
        let account = Account(
            name: "Test",
            currencyCode: "PEN",
            colorHex: "#6366F1",
            iconName: "creditcard.fill",
            type: "bank"
        )
        vm.accountToEdit = account
        #expect(vm.accountToEdit != nil)
        #expect(vm.accountToEdit?.name == "Test")
    }
}

/*
Tests generated:
1. initialState_accountsEmpty - Accounts start empty
2. initialState_transactionsEmpty - Transactions start empty
3. initialState_isEmptyTrue - isEmpty is true initially
4. initialState_isPresentingCreateAccountFalse - Create sheet not shown
5. initialState_accountToEditNil - No account selected for edit
6. initialState_isEditModeFalse - Edit mode off by default
7. sortOrderNamesRaw_emptySplitsToEmpty - Empty sort order works
8. sortOrderNamesRaw_invalidatesOnChange - Cache invalidation on change
9. uiState_toggleEditMode - Edit mode toggle
10. uiState_setPresentingCreateAccount - Create account sheet state
11. uiState_setAccountToEdit - Account edit selection

Cases NOT covered (require ModelContext or private(set) data):
- activeAccounts / archivedAccounts filtering (accounts is private(set))
- orderedActiveAccounts sorting with data (accounts is private(set))
- moveAccount reorder (reads from orderedActiveAccounts which needs accounts)
- formattedBalance (needs AccountBalanceCalculator + transactions)
- existingNames / existingNamesExcluding (needs accounts)
- loadData (requires ModelContext)

RECOMMENDATION: Extract sort logic into a standalone function (like PanelViewModel.orderedActiveAccounts(from:sortOrderNames:))
to enable comprehensive testing of the ordering algorithm.
*/
