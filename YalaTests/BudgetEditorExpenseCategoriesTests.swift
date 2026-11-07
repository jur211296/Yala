//
//  BudgetEditorExpenseCategoriesTests.swift
//  YalaTests
//
//  Card dkq6 (revisión del usuario nuevo, captura 23): «Nuevo presupuesto › Elegir categorías» listaba «Ingresos». Un
//  presupuesto solo suma gastos, así que el selector ofrece solo categorías de gasto; una de ingreso que el presupuesto
//  ya guarda sigue a la vista para poder quitarla.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@MainActor
@Suite("Presupuesto · «Elegir categorías» ofrece solo las de gasto", .serialized)
struct BudgetEditorExpenseCategoriesTests {

    private struct Seed {
        let food: Yala.Category
        let restaurants: Subcategory
        let income: Yala.Category
        let salary: Subcategory
        let bonus: Subcategory
        let orphan: Subcategory
    }

    private func seed(_ context: ModelContext) throws -> Seed {
        let food = Yala.Category(name: "Comida", colorHex: "#111111", isIncome: false)
        let income = Yala.Category(name: "Ingresos", colorHex: "#222222", isIncome: true)
        context.insert(food)
        context.insert(income)
        let restaurants = Subcategory(name: "Restaurantes", category: food)
        let salary = Subcategory(name: "Sueldo", category: income)
        let bonus = Subcategory(name: "Bono", category: income)
        let orphan = Subcategory(name: "Suelta", category: nil)
        [restaurants, salary, bonus, orphan].forEach { context.insert($0) }
        try context.save()
        return Seed(food: food, restaurants: restaurants, income: income, salary: salary, bonus: bonus, orphan: orphan)
    }

    private func choices(_ seed: Seed, selected: Set<PersistentIdentifier>) -> (categories: [String], subcategories: [String]) {
        let result = BudgetEditorViewModel.budgetCategoryChoices(
            categories: [seed.food, seed.income],
            subcategories: [seed.restaurants, seed.salary, seed.bonus, seed.orphan],
            selected: selected)
        return (result.categories.map(\.name), result.subcategories.map(\.name))
    }

    @Test("sin nada elegido, ni la categoría de ingreso ni sus subcategorías: «Seleccionar todo» tampoco las marca")
    func nothingSelected_offersOnlyExpenseCategories() throws {
        let seed = try seed(try makeTestContext())
        let offered = choices(seed, selected: [])
        #expect(offered.categories == ["Comida"])
        #expect(offered.subcategories == ["Restaurantes"],
                "las subcategorías de ingreso siguen en la lista que «Seleccionar todo» marca entera")
    }

    @Test("un presupuesto que ya guarda una subcategoría de ingreso la enseña, con su categoría, para poder quitarla")
    func savedIncomeSubcategory_staysVisible() throws {
        let seed = try seed(try makeTestContext())
        let offered = choices(seed, selected: [seed.salary.persistentModelID])
        #expect(offered.categories == ["Comida", "Ingresos"])
        #expect(offered.subcategories == ["Restaurantes", "Sueldo", "Bono"])
    }

    @Test("una subcategoría suelta (sin categoría) solo sale si ya estaba elegida")
    func orphanSubcategory_onlyIfSelected() throws {
        let seed = try seed(try makeTestContext())
        #expect(!choices(seed, selected: []).subcategories.contains("Suelta"))
        #expect(choices(seed, selected: [seed.orphan.persistentModelID]).subcategories.contains("Suelta"))
    }

    @Test("MUTACIÓN: el editor pasa al selector lo que ofrece `budgetCategoryChoices`, no todas las categorías")
    func editorWiresTheExpenseOnlyChoices() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let raw = try String(contentsOf: root.appendingPathComponent("Yala/App/Views/Planning/BudgetEditorView.swift"),
                             encoding: .utf8)
        let code = raw.replacingOccurrences(of: #"(?m)//.*$"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        #expect(code.contains("let choices = viewModel.budgetCategoryChoices(selected: selectedSubcategories) "
                              + "return CategorySelectorSheet( categories: choices.categories, "
                              + "subcategories: choices.subcategories,"))
        #expect(!code.contains("categories: viewModel.categories"), "el selector vuelve a recibir todas las categorías")
    }
}
