//
//  BudgetFilterRegressionTests.swift
//  YalaTests
//
//  Regression tests for CloudKit lazy hydration de Budget filters
//  (subcategories/accounts/tags): M2M nil con CSV poblado debe filtrar OK
//  en lugar de interpretarse como "sin filtros" (que sumaría todo el periodo).
//
//  Usan `makeTestContext()` (UUID suffix isolation) para construir entidades
//  SwiftData reales. Simulan la condición de race poblando solo el CSV mirror.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Budget Filter — CloudKit lazy hydration regression", .serialized)
struct BudgetFilterRegressionTests {

    /// Caso 1: un Budget con CSV mirror poblado pero M2M `subcategories` vacía
    /// debe filtrar TX correctamente — no asumir "sin filtros" ni sumar todo.
    @Test func filterTransactions_csvPopulated_m2mEmpty_filtersCorrectly() throws {
        let context = try makeTestContext()

        let account = makeTestAccount(context: context, name: "Bank")
        let categoryExpense = makeTestCategory(context: context, name: "Food", isIncome: false)
        let subFood = makeTestSubcategory(context: context, name: "Restaurants", category: categoryExpense)
        let subOther = makeTestSubcategory(context: context, name: "Groceries", category: categoryExpense)
        try context.save()

        let now = Date()
        // TX A: subcat Restaurants — DEBE incluirse
        let txA = makeTestTransaction(
            context: context, amount: 100.0, date: now,
            account: account, category: categoryExpense, subcategory: subFood
        )
        // TX B: subcat Groceries — NO debe incluirse
        let txB = makeTestTransaction(
            context: context, amount: 200.0, date: now,
            account: account, category: categoryExpense, subcategory: subOther
        )
        try context.save()

        // Budget con CSV poblado (filtro Restaurants), M2M intencionalmente vacía
        // (simula CloudKit lazy hydration race).
        let csv = subFood.shortcutID.uuidString
        let budget = makeTestBudget(
            context: context,
            name: "Restaurants Budget",
            limitAmount: 500,
            subcategories: [],  // M2M vacía intencionalmente
            subcategoryIDs: csv
        )
        try context.save()

        let interval = DateInterval(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(3600))
        let result = BudgetsViewModel.filterTransactions([txA, txB], forBudget: budget, in: interval)

        #expect(result.count == 1, "Solo debe incluir TX A (Restaurants), no TX B (Groceries)")
        #expect(result.first?.subcategory?.persistentModelID == subFood.persistentModelID)
    }

    /// Caso 2: budget con M2M poblada y CSV nil (legacy pre-deploy) — el lazy
    /// fallback debe leer la M2M y filtrar correctamente.
    @Test func filterTransactions_csvNil_m2mPopulated_fallsBackToM2M() throws {
        let context = try makeTestContext()

        let account = makeTestAccount(context: context, name: "Bank")
        let categoryExpense = makeTestCategory(context: context, name: "Food", isIncome: false)
        let subA = makeTestSubcategory(context: context, name: "Coffee", category: categoryExpense)
        let subB = makeTestSubcategory(context: context, name: "Lunch", category: categoryExpense)
        try context.save()

        let now = Date()
        let txA = makeTestTransaction(
            context: context, amount: 50, date: now,
            account: account, category: categoryExpense, subcategory: subA
        )
        let txB = makeTestTransaction(
            context: context, amount: 150, date: now,
            account: account, category: categoryExpense, subcategory: subB
        )
        try context.save()

        // Budget legacy: M2M poblada, CSV nil.
        let budget = makeTestBudget(
            context: context,
            name: "Coffee Only",
            limitAmount: 300,
            subcategories: [subA],
            subcategoryIDs: nil  // legacy budget pre-deploy
        )
        try context.save()

        let interval = DateInterval(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(3600))
        let result = BudgetsViewModel.filterTransactions([txA, txB], forBudget: budget, in: interval)

        #expect(result.count == 1)
        #expect(result.first?.subcategory?.persistentModelID == subA.persistentModelID)
    }

    /// Caso 3: budget con CSV poblado de UUIDs huérfanos (subcategorías borradas).
    /// El filtro debe devolver `[]` (no "todos") — comportamiento defensivo benigno.
    @Test func filterTransactions_csvOrphanedUUIDs_filtersToEmpty_notAll() throws {
        let context = try makeTestContext()

        let account = makeTestAccount(context: context, name: "Bank")
        let categoryExpense = makeTestCategory(context: context, name: "Food", isIncome: false)
        let sub = makeTestSubcategory(context: context, name: "Coffee", category: categoryExpense)
        try context.save()

        let now = Date()
        let tx = makeTestTransaction(
            context: context, amount: 100, date: now,
            account: account, category: categoryExpense, subcategory: sub
        )
        try context.save()

        // Budget con CSV de UUID huérfano (no matchea ninguna Subcategory existente)
        let orphanCSV = UUID().uuidString
        let budget = makeTestBudget(
            context: context,
            name: "Orphan Budget",
            limitAmount: 500,
            subcategories: [],
            subcategoryIDs: orphanCSV
        )
        try context.save()

        let interval = DateInterval(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(3600))
        let result = BudgetsViewModel.filterTransactions([tx], forBudget: budget, in: interval)

        #expect(result.isEmpty, "UUIDs huérfanos NO deben matchear ninguna TX (comportamiento defensivo)")
    }

    /// Caso 4: budget sin filtros (CSV nil + M2M empty + natures nil) — semántica
    /// "todos los gastos" sigue funcionando.
    @Test func filterTransactions_noFilters_includesAllExpenses() throws {
        let context = try makeTestContext()

        let account = makeTestAccount(context: context, name: "Bank")
        let categoryExpense = makeTestCategory(context: context, name: "Food", isIncome: false)
        let sub = makeTestSubcategory(context: context, name: "Coffee", category: categoryExpense)
        try context.save()

        let now = Date()
        let tx = makeTestTransaction(
            context: context, amount: 100, date: now,
            account: account, category: categoryExpense, subcategory: sub
        )
        try context.save()

        let budget = makeTestBudget(
            context: context,
            name: "Global Budget",
            limitAmount: 1000,
            subcategoryIDs: nil
        )
        try context.save()

        let interval = DateInterval(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(3600))
        let result = BudgetsViewModel.filterTransactions([tx], forBudget: budget, in: interval)

        #expect(result.count == 1, "Sin filtros = todos los gastos del periodo")
    }

    /// Caso 5: budget con natures CSV (no lazy) sigue funcionando ortogonal al fix.
    @Test func filterTransactions_naturesFilter_remainsOrthogonal() throws {
        let context = try makeTestContext()

        let account = makeTestAccount(context: context, name: "Bank")
        let categoryExpense = makeTestCategory(context: context, name: "Food", isIncome: false)
        let subEssential = makeTestSubcategory(
            context: context, name: "Essential",
            category: categoryExpense, need: .essential
        )
        let subOptional = makeTestSubcategory(
            context: context, name: "Optional",
            category: categoryExpense, need: .optional
        )
        try context.save()

        let now = Date()
        let txEssential = makeTestTransaction(
            context: context, amount: 100, date: now,
            account: account, category: categoryExpense, subcategory: subEssential
        )
        let txOptional = makeTestTransaction(
            context: context, amount: 200, date: now,
            account: account, category: categoryExpense, subcategory: subOptional
        )
        try context.save()

        let budget = makeTestBudget(
            context: context,
            name: "Optional Only",
            limitAmount: 500
        )
        // `natures` almacena el rawValue del enum (español: "opcional"), igual que
        // BudgetEditorViewModel (`selectedNeeds.map { $0.rawValue }`). Usar el literal
        // inglés "optional" NO parsea a `SubcategoryNeed` → el filtro quedaba vacío.
        budget.natures = SubcategoryNeed.optional.rawValue
        try context.save()

        let interval = DateInterval(start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(3600))
        let result = BudgetsViewModel.filterTransactions([txEssential, txOptional], forBudget: budget, in: interval)

        #expect(result.count == 1)
        #expect(result.first?.subcategory?.persistentModelID == subOptional.persistentModelID)
    }
}
