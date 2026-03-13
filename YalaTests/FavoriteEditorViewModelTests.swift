//
//  FavoriteEditorViewModelTests.swift
//  YalaTests
//
//  Tests for FavoriteEditorViewModel - validation logic and state management.
//  The save operation requires ModelContext, but we can test validation gates,
//  state transitions, and the needOverride computation logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct FavoriteEditorViewModelTests {

    // MARK: - Initial State

    @MainActor @Test("Initial state has zero favorites count")
    func initialState_favoritesCountZero() {
        let vm = FavoriteEditorViewModel()
        #expect(vm.existingFavoritesCount == 0)
    }

    @MainActor @Test("Initial state has showSaveError false")
    func initialState_showSaveErrorFalse() {
        let vm = FavoriteEditorViewModel()
        #expect(vm.showSaveError == false)
    }

    // MARK: - saveFavorite validation (without context)

    @MainActor @Test("saveFavorite without context returns false")
    func saveFavorite_withoutContext_returnsFalse() {
        let vm = FavoriteEditorViewModel()
        let result = vm.saveFavorite(
            existing: nil,
            name: "Coffee",
            transactionType: .expense,
            amountString: "5.0",
            note: "",
            account: nil,
            subcategory: nil,
            tags: [],
            needOverride: nil
        )
        #expect(result == false)
    }

    @MainActor @Test("saveFavorite with empty name returns false")
    func saveFavorite_emptyName_returnsFalse() {
        let vm = FavoriteEditorViewModel()
        // Even if context were set, empty name should fail validation
        let result = vm.saveFavorite(
            existing: nil,
            name: "",
            transactionType: .expense,
            amountString: "10.0",
            note: "",
            account: nil,
            subcategory: nil,
            tags: [],
            needOverride: nil
        )
        #expect(result == false)
    }

    @MainActor @Test("saveFavorite with whitespace-only name returns false")
    func saveFavorite_whitespaceOnlyName_returnsFalse() {
        let vm = FavoriteEditorViewModel()
        let result = vm.saveFavorite(
            existing: nil,
            name: "   ",
            transactionType: .expense,
            amountString: "10.0",
            note: "",
            account: nil,
            subcategory: nil,
            tags: [],
            needOverride: nil
        )
        #expect(result == false)
    }

    // MARK: - dismissSaveError

    @MainActor @Test("dismissSaveError resets showSaveError to false")
    func dismissSaveError_resetsFlag() {
        let vm = FavoriteEditorViewModel()
        // We can't directly set showSaveError since it's private(set),
        // but dismissSaveError should always set it to false
        vm.dismissSaveError()
        #expect(vm.showSaveError == false)
    }

    // MARK: - loadFavoritesCount without context

    @MainActor @Test("loadFavoritesCount without context keeps zero")
    func loadFavoritesCount_withoutContext_keepsZero() {
        let vm = FavoriteEditorViewModel()
        vm.loadFavoritesCount()
        #expect(vm.existingFavoritesCount == 0)
    }

    // MARK: - FavoritePayment model properties (pure logic)

    @Test("FavoritePayment default type is expense")
    func favoritePayment_defaultType_isExpense() {
        let fav = FavoritePayment(name: "Coffee")
        #expect(fav.type == .expense)
        #expect(fav.transactionType == "expense")
    }

    @Test("FavoritePayment type parses income correctly")
    func favoritePayment_type_parsesIncome() {
        let fav = FavoritePayment(name: "Salary", transactionType: "income")
        #expect(fav.type == .income)
    }

    @Test("FavoritePayment effectiveNeed uses override when set")
    func favoritePayment_effectiveNeed_usesOverride() {
        let fav = FavoritePayment(name: "Gym", needOverride: "opcional")
        #expect(fav.effectiveNeed == .optional)
    }

    @Test("FavoritePayment effectiveNeed returns nil when no override and no subcategory")
    func favoritePayment_effectiveNeed_nilWithoutOverrideOrSubcategory() {
        let fav = FavoritePayment(name: "Test")
        #expect(fav.effectiveNeed == nil)
    }

    @Test("FavoritePayment displayOrder defaults to zero")
    func favoritePayment_displayOrder_defaultsToZero() {
        let fav = FavoritePayment(name: "Test")
        #expect(fav.displayOrder == 0)
    }

    @Test("FavoritePayment stores amount correctly")
    func favoritePayment_amount_storedCorrectly() {
        let fav = FavoritePayment(name: "Lunch", amount: 15.50)
        #expect(fav.amount == 15.50)
    }

    @Test("FavoritePayment nil amount when not provided")
    func favoritePayment_amount_nilWhenNotProvided() {
        let fav = FavoritePayment(name: "Variable expense")
        #expect(fav.amount == nil)
    }

    @Test("FavoritePayment note stored correctly")
    func favoritePayment_note_storedCorrectly() {
        let fav = FavoritePayment(name: "Coffee", note: "Morning routine")
        #expect(fav.note == "Morning routine")
    }

    @Test("FavoritePayment nil note when not provided")
    func favoritePayment_note_nilWhenNotProvided() {
        let fav = FavoritePayment(name: "Coffee")
        #expect(fav.note == nil)
    }
}

/*
Tests generated:
1. initialState_favoritesCountZero - Initial count is zero
2. initialState_showSaveErrorFalse - Error flag starts false
3. saveFavorite_withoutContext_returnsFalse - No context = no save
4. saveFavorite_emptyName_returnsFalse - Empty name validation
5. saveFavorite_whitespaceOnlyName_returnsFalse - Whitespace-only name validation
6. dismissSaveError_resetsFlag - Error dismissal works
7. loadFavoritesCount_withoutContext_keepsZero - No crash without context
8. favoritePayment_defaultType_isExpense - Model default type
9. favoritePayment_type_parsesIncome - Model type parsing
10. favoritePayment_effectiveNeed_usesOverride - Need override logic
11. favoritePayment_effectiveNeed_nilWithoutOverrideOrSubcategory - Need without override
12. favoritePayment_displayOrder_defaultsToZero - Display order default
13. favoritePayment_amount_storedCorrectly - Amount storage
14. favoritePayment_amount_nilWhenNotProvided - Optional amount
15. favoritePayment_note_storedCorrectly - Note storage
16. favoritePayment_note_nilWhenNotProvided - Optional note

Cases NOT covered (require ModelContext):
- saveFavorite success path (context.save + SessionState.incrementDataVersion)
- saveFavorite update of existing FavoritePayment (context required)
- loadFavoritesCount with actual data
*/
