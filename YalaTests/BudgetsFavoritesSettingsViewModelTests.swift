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

    // MARK: - CRUD State (Initial)

    @MainActor @Test func initialState_showEditorFalse() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.showEditor == false)
    }

    @MainActor @Test func initialState_budgetToEditNil() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.budgetToEdit == nil)
    }

    @MainActor @Test func initialState_showDeleteErrorFalse() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.showDeleteError == false)
    }

    @MainActor @Test func initialState_showDeleteConfirmationFalse() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.showDeleteConfirmation == false)
    }

    @MainActor @Test func initialState_showUpgradeSheetFalse() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.showUpgradeSheet == false)
    }

    @MainActor @Test func initialState_budgetToDeleteNil() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.budgetToDelete == nil)
    }

    // MARK: - CRUD Operations

    @MainActor @Test func openEditor_forNil_setsShowEditorTrue() {
        let vm = BudgetsFavoritesSettingsViewModel()
        vm.openEditor(for: nil)
        #expect(vm.showEditor == true)
        #expect(vm.budgetToEdit == nil)
    }

    @MainActor @Test func closeEditor_resetsEditorState() {
        let vm = BudgetsFavoritesSettingsViewModel()
        vm.openEditor(for: nil)
        vm.closeEditor()
        #expect(vm.showEditor == false)
        #expect(vm.budgetToEdit == nil)
    }

    @MainActor @Test func deleteBudget_withoutBudgetToDelete_isNoOp() {
        let vm = BudgetsFavoritesSettingsViewModel()
        vm.deleteBudget()
        #expect(vm.showDeleteError == false)
    }

    @MainActor @Test func activeBudgetsCount_emptyData_returnsZero() {
        let vm = BudgetsFavoritesSettingsViewModel()
        #expect(vm.activeBudgetsCount == 0)
    }
}
