//
//  ManualSubcategoryPickerLogicTests.swift
//  YalaTests
//
//  Auditoría UX 2.2, lote 2, B6: las subcategorías de sistema no se ofrecen al apuntar a mano, tampoco
//  en «Recientes» ni en el atajo «!».
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
struct ManualSubcategoryPickerLogicTests {

    // MARK: - Regla pura

    private func candidate(
        visible: Bool = true,
        system: Bool = false,
        categoryVisible: Bool = true,
        categorySystem: Bool = false,
        income: Bool = false
    ) -> ManualSubcategoryPickerLogic.Candidate {
        .init(
            isVisible: visible,
            isAnySystem: system,
            categoryIsVisible: categoryVisible,
            categoryIsSystem: categorySystem,
            categoryIsIncome: income
        )
    }

    @Test func aNormalExpenseSubcategoryIsPickableOnlyForExpenses() {
        #expect(ManualSubcategoryPickerLogic.isPickable(candidate(), for: .expense))
        #expect(!ManualSubcategoryPickerLogic.isPickable(candidate(), for: .income))
        #expect(!ManualSubcategoryPickerLogic.isPickable(candidate(), for: .transfer))
    }

    @Test func anIncomeSubcategoryIsPickableOnlyForIncome() {
        #expect(ManualSubcategoryPickerLogic.isPickable(candidate(income: true), for: .income))
        #expect(!ManualSubcategoryPickerLogic.isPickable(candidate(income: true), for: .expense))
    }

    @Test func eachExclusionAloneRemovesIt() {
        #expect(!ManualSubcategoryPickerLogic.isPickable(candidate(visible: false), for: .expense))
        #expect(!ManualSubcategoryPickerLogic.isPickable(candidate(system: true), for: .expense))
        #expect(!ManualSubcategoryPickerLogic.isPickable(candidate(categoryVisible: false), for: .expense))
        #expect(!ManualSubcategoryPickerLogic.isPickable(candidate(categorySystem: true), for: .expense))
    }

    // MARK: - Modelos

    private func makeTransaction(_ subcategory: Subcategory, daysAgo: Int) -> TransactionItem {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return TransactionItem(
            date: date,
            amount: -10,
            currencyCode: "PEN",
            note: "",
            category: subcategory.category,
            subcategory: subcategory,
            tags: [],
            amountInPreferredCurrency: -10
        )
    }

    /// El estado que deja el onboarding: el saldo inicial es el registro más reciente y su subcategoría es
    /// «Ajustes de saldo». Antes del arreglo, era la primera (y única) sugerencia de Recientes.
    @MainActor @Test func recentsSkipTheOpeningBalanceSubcategory() throws {
        let context = try makeTestContext()
        let food = YalaCategory(name: "Alimentación", colorHex: "#00AA00", isIncome: false)
        let finances = YalaCategory(name: "Finanzas", colorHex: "#0000AA", isIncome: false)
        let restaurants = Subcategory(name: "Restaurantes", colorHex: "#00AA00", category: food)
        let adjustment = Subcategory(name: "Ajustes de saldo", colorHex: "#0000AA", category: finances)
        #expect(adjustment.isAnySystem)
        context.insert(food)
        context.insert(finances)
        context.insert(restaurants)
        context.insert(adjustment)
        context.insert(makeTransaction(restaurants, daysAgo: 2))
        context.insert(makeTransaction(adjustment, daysAgo: 0))
        try context.save()

        let vm = SubcategorySelectorViewModel()
        vm.setContext(context, transactionType: .expense)

        #expect(vm.recentSubcategories.map(\.name) == ["Restaurantes"])
        #expect(!vm.groupedSubcategories.flatMap(\.subcategories).contains { $0.name == "Ajustes de saldo" })
    }

    @Test func theBangShortcutDoesNotSuggestSystemSubcategories() {
        let food = YalaCategory(name: "Alimentación", colorHex: "#00AA00", isIncome: false)
        let finances = YalaCategory(name: "Finanzas", colorHex: "#0000AA", isIncome: false)
        let restaurants = Subcategory(name: "Restaurantes", colorHex: "#00AA00", category: food)
        let adjustment = Subcategory(name: "Ajustes de saldo", colorHex: "#0000AA", category: finances)
        let transfer = Subcategory(name: "Transferencia entre cuentas", colorHex: "#0000AA", category: finances)
        #expect(transfer.isAnySystem)
        let all = [restaurants, adjustment, transfer]
        let recent = [makeTransaction(adjustment, daysAgo: 0), makeTransaction(restaurants, daysAgo: 1)]

        let byQuery = AutocompleteHelper.getSubcategorySuggestions(
            query: "a", allSubcategories: all, recentTransactions: recent, transactionType: .expense
        )
        #expect(byQuery.map(\.name) == ["Restaurantes"])

        let withoutQuery = AutocompleteHelper.getSubcategorySuggestions(
            query: "", allSubcategories: all, recentTransactions: recent, transactionType: .expense
        )
        #expect(withoutQuery.map(\.name) == ["Restaurantes"])
    }
}
