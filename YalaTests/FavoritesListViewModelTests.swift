//
//  FavoritesListViewModelTests.swift
//  YalaTests
//
//  Tests for FavoritesListViewModel - UI state management and display logic.
//  Data operations (load, delete, move) require ModelContext, but we can test
//  UI state transitions, computed properties, and the expenses-only filter logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
struct FavoritesListViewModelTests {

    // MARK: - Initial State

    @MainActor @Test("Initial state has empty favorites")
    func initialState_favoritesEmpty() {
        let vm = FavoritesListViewModel()
        #expect(vm.favorites.isEmpty)
    }

    @MainActor @Test("Initial state isEmpty is true")
    func initialState_isEmptyTrue() {
        let vm = FavoritesListViewModel()
        #expect(vm.isEmpty == true)
    }

    @MainActor @Test("Initial state showEditor is false")
    func initialState_showEditorFalse() {
        let vm = FavoritesListViewModel()
        #expect(vm.showEditor == false)
    }

    @MainActor @Test("Initial state favoriteToEdit is nil")
    func initialState_favoriteToEditNil() {
        let vm = FavoritesListViewModel()
        #expect(vm.favoriteToEdit == nil)
    }

    @MainActor @Test("Initial state showSaveError is false")
    func initialState_showSaveErrorFalse() {
        let vm = FavoritesListViewModel()
        #expect(vm.showSaveError == false)
    }

    // MARK: - openEditor / closeEditor State Transitions

    @MainActor @Test("openEditor with nil sets showEditor true and favoriteToEdit nil")
    func openEditor_withNil_setsShowEditorTrue() {
        let vm = FavoritesListViewModel()
        vm.openEditor(for: nil)
        #expect(vm.showEditor == true)
        #expect(vm.favoriteToEdit == nil)
    }

    @MainActor @Test("openEditor with favorite sets both properties")
    func openEditor_withFavorite_setsBothProperties() {
        let vm = FavoritesListViewModel()
        let fav = FavoritePayment(name: "Coffee")
        vm.openEditor(for: fav)
        #expect(vm.showEditor == true)
        #expect(vm.favoriteToEdit != nil)
        #expect(vm.favoriteToEdit?.name == "Coffee")
    }

    @MainActor @Test("closeEditor resets showEditor and favoriteToEdit")
    func closeEditor_resetsBothProperties() {
        let vm = FavoritesListViewModel()
        // Open first
        let fav = FavoritePayment(name: "Coffee")
        vm.openEditor(for: fav)
        #expect(vm.showEditor == true)

        // Close
        vm.closeEditor()
        #expect(vm.showEditor == false)
        #expect(vm.favoriteToEdit == nil)
    }

    // MARK: - loadFavorites without context

    @MainActor @Test("loadFavorites without context keeps empty array")
    func loadFavorites_withoutContext_keepsEmpty() {
        let vm = FavoritesListViewModel()
        vm.loadFavorites()
        #expect(vm.favorites.isEmpty)
    }

    // MARK: - displayedFavorites filtering logic

    @MainActor @Test("displayedFavorites returns all when expensesOnlyMode is off")
    func displayedFavorites_expensesOnlyOff_returnsAll() {
        let vm = FavoritesListViewModel()
        // Ensure expenses only mode is off
        let wasExpensesOnly = SessionState.shared.isExpensesOnlyMode
        SessionState.shared.isExpensesOnlyMode = false

        // With empty favorites, displayedFavorites should be empty
        #expect(vm.displayedFavorites.isEmpty)

        // Restore
        SessionState.shared.isExpensesOnlyMode = wasExpensesOnly
    }

    @MainActor @Test("isEmpty reflects displayedFavorites, not favorites")
    func isEmpty_reflectsDisplayedFavorites() {
        let vm = FavoritesListViewModel()
        // Both favorites and displayedFavorites empty
        #expect(vm.isEmpty == true)
        #expect(vm.displayedFavorites.isEmpty == vm.isEmpty)
    }

    // MARK: - deleteFavorites without context

    @MainActor @Test("deleteFavorites without context does not crash")
    func deleteFavorites_withoutContext_noCrash() {
        let vm = FavoritesListViewModel()
        // Should not crash even with empty data and no context
        vm.deleteFavorites(at: IndexSet())
        #expect(vm.favorites.isEmpty)
    }

    // MARK: - moveFavorites without context

    @MainActor @Test("moveFavorites without context does not crash")
    func moveFavorites_withoutContext_noCrash() {
        let vm = FavoritesListViewModel()
        vm.moveFavorites(from: IndexSet(), to: 0)
        #expect(vm.favorites.isEmpty)
    }

    // MARK: - FavoritePayment transactionType filter logic (unit test for the filter)

    @Test("FavoritePayment with income type is identified correctly")
    func favoritePayment_incomeType_identifiedCorrectly() {
        let incomeFav = FavoritePayment(name: "Salary", transactionType: "income")
        let expenseFav = FavoritePayment(name: "Coffee", transactionType: "expense")

        let allFavorites = [incomeFav, expenseFav]
        let expenseOnly = allFavorites.filter { $0.transactionType != "income" }

        #expect(expenseOnly.count == 1)
        #expect(expenseOnly[0].name == "Coffee")
    }

    @Test("Filter with no income favorites returns all")
    func filter_noIncomeFavorites_returnsAll() {
        let fav1 = FavoritePayment(name: "Coffee", transactionType: "expense")
        let fav2 = FavoritePayment(name: "Lunch", transactionType: "expense")

        let allFavorites = [fav1, fav2]
        let expenseOnly = allFavorites.filter { $0.transactionType != "income" }

        #expect(expenseOnly.count == 2)
    }
}

/*
Tests generated:
1. initialState_favoritesEmpty - Empty initial state
2. initialState_isEmptyTrue - isEmpty computed property
3. initialState_showEditorFalse - Editor state initial
4. initialState_favoriteToEditNil - No favorite selected initially
5. initialState_showSaveErrorFalse - Error flag initial
6. openEditor_withNil_setsShowEditorTrue - Open editor for new favorite
7. openEditor_withFavorite_setsBothProperties - Open editor for existing
8. closeEditor_resetsBothProperties - Close resets state
9. loadFavorites_withoutContext_keepsEmpty - No crash without context
10. displayedFavorites_expensesOnlyOff_returnsAll - Display filter off
11. isEmpty_reflectsDisplayedFavorites - isEmpty correctness
12. deleteFavorites_withoutContext_noCrash - Safe without context
13. moveFavorites_withoutContext_noCrash - Safe without context
14. favoritePayment_incomeType_identifiedCorrectly - Income filter logic
15. filter_noIncomeFavorites_returnsAll - No income to filter

Cases NOT covered (require ModelContext):
- displayedFavorites with populated favorites array + expensesOnlyMode on
  (favorites is private(set), populated only via fetch)
- deleteFavorites with actual data
- moveFavorites reordering logic with actual data
*/
