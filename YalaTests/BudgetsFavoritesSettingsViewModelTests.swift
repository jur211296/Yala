//
//  BudgetsFavoritesSettingsViewModelTests.swift
//  YalaTests
//
//  Tests for BudgetsFavoritesSettingsViewModel UI state and initial state.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct BudgetsFavoritesSettingsViewModelTests {

    // MARK: - Initial State

    @MainActor @Test func initialState_activeBudgetsEmpty() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.activeBudgets.isEmpty)
    }

    @MainActor @Test func initialState_isEmptyTrue() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.isEmpty == true)
    }

    @MainActor @Test func initialState_hasFavoritesFalse() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.hasFavorites == false)
    }

    @MainActor @Test func initialState_isEditModeFalse() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.isEditMode == false)
    }

    @MainActor @Test func initialState_showSaveErrorFalse() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.showSaveError == false)
    }

    // MARK: - Computed Properties with Empty Data

    @MainActor @Test func budgetsByPeriod_emptyData_returnsEmpty() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.budgetsByPeriod.isEmpty)
    }

    @MainActor @Test func favoriteBudgets_emptyData_returnsEmpty() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.favoriteBudgets.isEmpty)
    }

    // MARK: - UI State Management

    @MainActor @Test func uiState_toggleEditMode() {
        let vm = BudgetsFavoritesSettingsViewModel()
        vm.isEditMode = true
        #expect(vm.isEditMode == true)
        vm.isEditMode = false
        #expect(vm.isEditMode == false)
    }

    @MainActor @Test func uiState_showSaveError() {
        let vm = BudgetsFavoritesSettingsViewModel()
        vm.showSaveError = true
        #expect(vm.showSaveError == true)
    }
}

/*
Tests generated:
1. initialState_activeBudgetsEmpty - Active budgets start empty
2. initialState_isEmptyTrue - isEmpty true initially
3. initialState_hasFavoritesFalse - No favorites initially
4. initialState_isEditModeFalse - Edit mode off by default
5. initialState_showSaveErrorFalse - No save error initially
6. budgetsByPeriod_emptyData_returnsEmpty - Grouped budgets empty
7. favoriteBudgets_emptyData_returnsEmpty - Favorite budgets empty
8. uiState_toggleEditMode - Edit mode toggle
9. uiState_showSaveError - Save error state

Cases NOT covered (require ModelContext or private(set) data):
- budgetsByPeriod grouping/sorting with actual data (activeBudgets is private(set))
- favoriteBudgets sorting with actual data (activeBudgets is private(set))
- toggleFavorite (requires context.save)
- moveBudget (requires context.save)
- reindexFavorites (private method)
- loadBudgets (requires ModelContext)

RECOMMENDATION: Extract budgetsByPeriod sorting/grouping logic into a static/standalone function
that accepts [Budget] as parameter, enabling comprehensive unit tests of the
grouping, sorting-by-favorite-order, and alphabetical fallback logic.
*/
