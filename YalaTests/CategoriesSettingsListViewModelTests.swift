//
//  CategoriesSettingsListViewModelTests.swift
//  YalaTests
//
//  Tests for CategoriesSettingsListViewModel UI state management.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct CategoriesSettingsListViewModelTests {

    // MARK: - Initial State

    @MainActor @Test func initialState_categoriesEmpty() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.categories.isEmpty)
    }

    @MainActor @Test func initialState_isEmptyTrue() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.isEmpty == true)
    }

    @MainActor @Test func initialState_isEditingFalse() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.isEditing == false)
    }

    @MainActor @Test func initialState_isNavigatingToNewCategoryFalse() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.isNavigatingToNewCategory == false)
    }

    @MainActor @Test func initialState_newCategoryNil() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.newCategory == nil)
    }

    @MainActor @Test func initialState_showCannotDeleteAlertFalse() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.showCannotDeleteAlert == false)
    }

    @MainActor @Test func initialState_categoryToDeleteNameEmpty() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.categoryToDeleteName == "")
    }

    @MainActor @Test func initialState_transactionCountForAlertZero() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.transactionCountForAlert == 0)
    }

    // MARK: - Computed Properties with Empty Data

    @MainActor @Test func orderedCategories_emptyData_returnsEmpty() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.orderedCategories.isEmpty)
    }

    @MainActor @Test func activeCategories_emptyData_returnsEmpty() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.activeCategories.isEmpty)
    }

    @MainActor @Test func hiddenCategories_emptyData_returnsEmpty() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.hiddenCategories.isEmpty)
    }

    // MARK: - Alert State Management

    @MainActor @Test func alertState_canBeSetManually() {
        let vm = CategoriesSettingsListViewModel()

        vm.showCannotDeleteAlert = true
        vm.categoryToDeleteName = "Food"
        vm.transactionCountForAlert = 5

        #expect(vm.showCannotDeleteAlert == true)
        #expect(vm.categoryToDeleteName == "Food")
        #expect(vm.transactionCountForAlert == 5)
    }

    @MainActor @Test func alertState_resetAfterDismissal() {
        let vm = CategoriesSettingsListViewModel()

        // Simulate alert shown
        vm.showCannotDeleteAlert = true
        vm.categoryToDeleteName = "Transport"
        vm.transactionCountForAlert = 10

        // Simulate dismissal
        vm.showCannotDeleteAlert = false
        vm.categoryToDeleteName = ""
        vm.transactionCountForAlert = 0

        #expect(vm.showCannotDeleteAlert == false)
        #expect(vm.categoryToDeleteName == "")
        #expect(vm.transactionCountForAlert == 0)
    }

    // MARK: - Edit Mode

    @MainActor @Test func editMode_toggle() {
        let vm = CategoriesSettingsListViewModel()
        #expect(vm.isEditing == false)

        vm.isEditing = true
        #expect(vm.isEditing == true)

        vm.isEditing = false
        #expect(vm.isEditing == false)
    }
}

/*
Tests generated:
1. initialState_categoriesEmpty - Categories start empty
2. initialState_isEmptyTrue - isEmpty true initially
3. initialState_isEditingFalse - Not editing initially
4. initialState_isNavigatingToNewCategoryFalse - Not navigating initially
5. initialState_newCategoryNil - No new category initially
6. initialState_showCannotDeleteAlertFalse - Alert not shown initially
7. initialState_categoryToDeleteNameEmpty - Delete name empty
8. initialState_transactionCountForAlertZero - Transaction count zero
9. orderedCategories_emptyData_returnsEmpty - Empty ordered list
10. activeCategories_emptyData_returnsEmpty - Empty active list
11. hiddenCategories_emptyData_returnsEmpty - Empty hidden list
12. alertState_canBeSetManually - Set alert state
13. alertState_resetAfterDismissal - Reset alert state
14. editMode_toggle - Toggle edit mode

Cases NOT covered (require ModelContext):
- orderedCategories sorting (categories is private(set))
- activeCategories / hiddenCategories filtering (categories is private(set))
- createAndOpenNewCategory (requires context.insert)
- handleCategoryDelete (requires context + transaction counting)
- loadCategories (requires ModelContext)
*/
