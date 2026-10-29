//
//  InsightsBudgetPlanningParityTests.swift
//  YalaTests
//
//  Ticket `insights-budgets-at-risk-compute-spent-on-their-own` (card d98t): «Presupuestos en riesgo» de Observaciones
//  calculaba lo gastado por su cuenta. Solo veía los presupuestos con la categoría legada, filtraba por ella, ignoraba
//  «Contar mi parte de los gastos de grupo» y dejaba fuera los gastos sin categoría. Desde el 2026-10-29 usa
//  `BudgetsViewModel.calculateSpending`, la de Planificación.
//
//  El fixture es DISCRIMINANTE, presupuesto por presupuesto:
//  - «Mes» (sin filtros, sin grupo): con el cálculo viejo no salía. Ahora 240, como Planificación.
//  - «Legado» (categoría Comida, sin grupo): con el cálculo viejo 500 (Comida, con el gasto de grupo). Ahora 240.
//  - «Restaurantes» (por subcategoría, con grupo): con el cálculo viejo no salía. Ahora 500.
//
//  Sin ModelContext: `@Model` en memoria, como `PanelBudgetPlanningParityTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Presupuestos · Observaciones y Planificación dicen lo mismo")
struct InsightsBudgetPlanningParityTests {

    private struct Scenario {
        let budgets: [Budget]
        let txs: [TransactionItem]
        let account: Account
        let food: Yala.Category
        let others: Yala.Category
        let categories: [Yala.Category]
    }

    private func scenario() -> Scenario {
        let account = Account(name: "Main", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let food = Yala.Category(name: "Comida", colorHex: "#000", isIncome: false)
        let others = Yala.Category(name: "Otros", colorHex: "#000", isIncome: false)
        let salaryCat = Yala.Category(name: "Sueldo", colorHex: "#000", isIncome: true)
        let restaurants = Subcategory(name: "Restaurantes", category: food)
        let date = Date.now.addingTimeInterval(-60)
        func tx(_ amount: Double, _ category: Yala.Category?, _ subcategory: Subcategory? = nil) -> TransactionItem {
            TransactionItem(
                date: date, amount: amount, currencyCode: "PEN", category: category, subcategory: subcategory,
                account: account, amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            )
        }
        let spend = tx(-200, food, restaurants)
        let adjustment = tx(-500, others)
        adjustment.balanceAdjustmentType = "initial_balance"
        let shared = tx(-300, food, restaurants)
        shared.splitExpenseID = "split-1"
        let uncategorized = tx(-40, nil)
        let salary = tx(1_000, salaryCat)

        let month = Budget(
            currencyCode: "PEN", limitAmount: 1_000, name: "Mes", periodType: "monthly",
            includeSharedExpenses: false
        )
        let legacy = Budget(
            currencyCode: "PEN", limitAmount: 1_000, category: food, name: "Legado", periodType: "monthly",
            includeSharedExpenses: false
        )
        let bySubcategory = Budget(
            currencyCode: "PEN", limitAmount: 800, name: "Restaurantes", periodType: "monthly",
            subcategories: [restaurants], includeSharedExpenses: true
        )
        return Scenario(
            budgets: [month, legacy, bySubcategory],
            txs: [spend, adjustment, shared, uncategorized, salary],
            account: account,
            food: food,
            others: others,
            categories: [food, others, salaryCat]
        )
    }

    private func insights(_ s: Scenario, criteria: FilterCriteria = FilterCriteria()) -> Commitments {
        InsightsCalculator.calculate(
            transactions: s.txs, accounts: [s.account], categories: s.categories, budgets: s.budgets,
            scheduledPayments: [], period: .thisMonth, criteria: criteria, currencyCode: "PEN", customRange: nil
        ).commitments
    }

    @Test("Mismo presupuesto, mismo gastado y mismo porcentaje en Observaciones y en Planificación")
    func insightsEqualsPlanning() throws {
        let s = scenario()
        let rows = insights(s).budgets

        let planning = BudgetsViewModel()
        planning.calculateBudgetData(budgets: s.budgets, transactions: s.txs, accounts: [], defaultCurrencyCode: "PEN")
        let planningSummaries = planning.groupedBudgets.flatMap(\.budgets)

        let expected: [String: Double] = ["Mes": 240, "Legado": 240, "Restaurantes": 500]
        #expect(rows.count == 3, "con el cálculo viejo solo salía «Legado»: \(rows.map(\.name))")
        for budget in s.budgets {
            let row = try #require(rows.first { $0.id == budget.persistentModelID }, "\(budget.name) no sale")
            let summary = try #require(
                planningSummaries.first { $0.budget.persistentModelID == budget.persistentModelID }
            )
            #expect(row.spent == expected[budget.name], "\(budget.name): \(row.spent)")
            #expect(row.spent == summary.spent, "\(budget.name): Observaciones \(row.spent) · Planificación \(summary.spent)")
            #expect(row.usagePercent == summary.percentage, "\(budget.name)")
        }
    }

    @Test("En riesgo (≥ 50 %) sale el presupuesto por subcategoría, que antes no aparecía")
    func atRiskIncludesSubcategoryBudget() {
        #expect(insights(scenario()).budgetsAtRisk.map(\.name) == ["Restaurantes"])
    }

    @Test("El filtro de Estadísticas no mueve lo gastado de un presupuesto")
    func sessionFilterDoesNotMoveSpent() {
        let s = scenario()
        var criteria = FilterCriteria()
        criteria.selectedCategories = [s.others.persistentModelID]
        #expect(insights(s, criteria: criteria).budgets.map(\.spent) == insights(s).budgets.map(\.spent))
    }

    /// Source-scan del cableado: Observaciones no vuelve a filtrar los movimientos de un presupuesto por su cuenta.
    @Test("Observaciones no tiene filtro propio de presupuestos")
    func insightsHasNoOwnBudgetFilter() throws {
        let source = try String(
            contentsOfFile: sourcePath("Yala/App/Logic/Calculators/InsightsCalculator.swift"), encoding: .utf8
        )
        let start = try #require(source.range(of: "var budgetsAtRisk: [BudgetAtRisk] = []"))
        let end = try #require(source.range(of: "let row = BudgetAtRisk(", range: start.upperBound..<source.endIndex))
        let body = String(source[start.upperBound..<end.lowerBound])
        #expect(body.contains("BudgetsViewModel.calculateSpending("))
        #expect(body.contains("transactions: allTransactions"))
        #expect(!body.contains(".filter"))
        #expect(!body.contains("budget.category"))
    }

    private func sourcePath(_ relative: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relative)
            .path
    }
}
