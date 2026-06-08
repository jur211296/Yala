//
//  CategoryDetailViewModelTests.swift
//  YalaTests
//
//  Unit tests for CategoryDetailViewModel validation logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct CategoryDetailViewModelTests {

    /// Create a Category without ModelContext (avoids CloudKit race condition crashes)
    private func makePlainCategory(name: String, isIncome: Bool = false, isSystem: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#EF4444", isIncome: isIncome, isSystem: isSystem)
    }

    // MARK: - hasUnsavedChanges

    @MainActor @Test func hasUnsavedChanges_noChanges_false() {
        let vm = CategoryDetailViewModel(category: makePlainCategory(name: "Comida"))
        #expect(vm.hasUnsavedChanges == false)
    }

    @MainActor @Test func hasUnsavedChanges_nameChanged_true() {
        let vm = CategoryDetailViewModel(category: makePlainCategory(name: "Comida"))
        vm.name = "Alimentación"
        #expect(vm.hasUnsavedChanges == true)
    }

    @MainActor @Test func hasUnsavedChanges_colorChanged_true() {
        let vm = CategoryDetailViewModel(category: makePlainCategory(name: "Comida"))
        vm.colorHex = "#00FF00"
        #expect(vm.hasUnsavedChanges == true)
    }

    // MARK: - canSave

    @MainActor @Test func canSave_noChanges_false() {
        let vm = CategoryDetailViewModel(category: makePlainCategory(name: "Comida"))
        #expect(vm.canSave == false)
    }

    @MainActor @Test func canSave_validChanges_true() {
        let vm = CategoryDetailViewModel(category: makePlainCategory(name: "Comida"))
        vm.name = "Alimentación"
        #expect(vm.canSave == true)
    }

    @MainActor @Test func canSave_emptyName_false() {
        let vm = CategoryDetailViewModel(category: makePlainCategory(name: "Comida"))
        vm.name = "  "
        #expect(vm.canSave == false)
    }

    // MARK: - isSystemCategory

    @MainActor @Test func isSystemCategory_income_true() {
        let vm = CategoryDetailViewModel(category: makePlainCategory(name: "Ingresos", isIncome: true))
        #expect(vm.isSystemCategory == true)
    }

    @MainActor @Test func isSystemCategory_otros_true() {
        let vm = CategoryDetailViewModel(category: makePlainCategory(name: "Otros"))
        #expect(vm.isSystemCategory == true)
    }

    @MainActor @Test func isSystemCategory_normal_false() {
        let vm = CategoryDetailViewModel(category: makePlainCategory(name: "Comida"))
        #expect(vm.isSystemCategory == false)
    }

    @MainActor @Test func isSystemCategory_systemFlagExpense_true() {
        // "Grupos" (expense, isSystem). Caso raíz del bug: el getter previo solo
        // miraba isIncome / "Otros", así que esta categoría daba false y exponía
        // los controles de edición y borrado.
        let vm = CategoryDetailViewModel(category: makePlainCategory(name: "Grupos", isSystem: true))
        #expect(vm.isSystemCategory == true)
    }

    @MainActor @Test func isSystemCategory_systemFlagIncome_true() {
        // "Cobros de grupos" (income, isSystem) — protegida por isSystem además de isIncome.
        let vm = CategoryDetailViewModel(
            category: makePlainCategory(name: "Cobros de grupos", isIncome: true, isSystem: true))
        #expect(vm.isSystemCategory == true)
    }
}
