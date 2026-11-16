//
//  BudgetBreakdownSumsSpentTests.swift
//  YalaTests
//
//  «Por categoría» de las gráficas de un presupuesto suma lo gastado (lote 02 de mejoras necesarias de 2.3, 2026-11-10).
//  El desglose saltaba todo movimiento sin subcategoría, y un presupuesto que filtra por cuenta o etiqueta (sin filtro de
//  subcategorías) los cuenta en lo gastado: la tarjeta decía «S/ 180 gastado» y el desglose sumaba 100.
//
//  Fixture de la regla de `ingreso-gasto.md`: un gasto completo, uno con categoría y sin subcategoría y uno sin
//  categoría. Sin los dos últimos, el desglose viejo y el nuevo dan lo mismo.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct BudgetBreakdownSumsSpentTests {

    private let food = Category(name: "Comida", colorHex: "#111111", isIncome: false)
    private let interval = DateInterval(start: .distantPast, end: .distantFuture)
    private let day = Date(timeIntervalSince1970: 1_700_000_000)

    private func fixture() -> (budget: Budget, transactions: [TransactionItem]) {
        let card = Account(name: "Tarjeta", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "card")
        let other = Account(name: "Ahorros", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "savings")
        let restaurants = Subcategory(name: "Restaurantes", category: food)
        let budget = Budget(
            currencyCode: "PEN", limitAmount: 500, name: "Tarjeta",
            accountIDs: CSVMirrorCodec.encode([card.shortcutID])
        )
        let transactions = [
            TransactionItem(date: day, amount: -100, currencyCode: "PEN", category: food, subcategory: restaurants,
                            account: card, amountInPreferredCurrency: -100),
            TransactionItem(date: day, amount: -50, currencyCode: "PEN", category: food, account: card,
                            amountInPreferredCurrency: -50),                                  // sin subcategoría
            TransactionItem(date: day, amount: -30, currencyCode: "PEN", account: card,
                            amountInPreferredCurrency: -30),                                  // sin categoría
            TransactionItem(date: day, amount: -999, currencyCode: "PEN", category: food, subcategory: restaurants,
                            account: other, amountInPreferredCurrency: -999),                 // otra cuenta: fuera
        ]
        return (budget, transactions)
    }

    @Test func eachListAddsUpToWhatTheBudgetSpent() {
        let f = fixture()
        let spent = BudgetsViewModel.calculateSpending(budget: f.budget, transactions: f.transactions, interval: interval)
        #expect(spent == 180, "Control del escenario: lo gastado cuenta los tres de la tarjeta")

        let breakdown = BudgetsViewModel.combinedBreakdown(budget: f.budget, transactions: f.transactions, interval: interval)
        #expect(breakdown.parentCategories.reduce(0) { $0 + $1.amount } == spent)
        #expect(breakdown.subcategories.reduce(0) { $0 + $1.amount } == spent)
    }

    @Test func whatHasNoCategoryOrSubcategoryGetsItsOwnRow() throws {
        let f = fixture()
        let breakdown = BudgetsViewModel.combinedBreakdown(budget: f.budget, transactions: f.transactions, interval: interval)

        let foodRow = try #require(breakdown.parentCategories.first { $0.name == "Comida" })
        #expect(foodRow.amount == 150, "La categoría cuenta también lo que no tiene subcategoría")
        let uncategorized = try #require(breakdown.parentCategories.first { $0.name == L10n.Report.uncategorized })
        #expect(uncategorized.amount == 30)
        #expect(uncategorized.color == AppConstants.uncategorizedColorHex)

        let noSub = try #require(breakdown.subcategories.first { $0.name == L10n.Subcategory.noSubcategory })
        #expect(noSub.amount == 50)
        #expect(noSub.parentCategoryName == "Comida", "Va bajo su categoría: al elegir Comida se ve")
        let restaurants = try #require(breakdown.subcategories.first { $0.name == "Restaurantes" })
        #expect(restaurants.amount == 100)
    }
}
