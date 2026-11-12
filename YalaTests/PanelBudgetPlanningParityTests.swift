//
//  PanelBudgetPlanningParityTests.swift
//  YalaTests
//
//  Ticket `panel-budget-spent-diverges-from-planning` (card 7ld8): la tarjeta de Presupuestos del Panel filtraba por su
//  cuenta y podía decir distinto lo que queda de un presupuesto que Planificación. Desde el 2026-10-23 el Panel calcula
//  lo gastado con `BudgetsViewModel.calculateSpending`, la de Planificación.
//
//  El fixture es DISCRIMINANTE: con el cálculo viejo del Panel el ajuste de saldo (500) y el gasto de grupo con
//  «Contar mi parte de los gastos de grupo» apagado (300) contaban, y el gasto sin categoría (40) no: 1.000 en vez de 240.
//
//  Sin ModelContext: `@Model` en memoria, como `AccountSpendingParityTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Presupuestos · Panel y Planificación dicen lo mismo")
struct PanelBudgetPlanningParityTests {

    private func scenario() -> (budget: Budget, txs: [TransactionItem]) {
        let account = Account(name: "Main", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let food = Yala.Category(name: "Comida", colorHex: "#000", isIncome: false)
        let others = Yala.Category(name: "Otros", colorHex: "#000", isIncome: false)
        let salaryCat = Yala.Category(name: "Sueldo", colorHex: "#000", isIncome: true)
        let date = aMomentAgoToday()
        func tx(_ amount: Double, _ category: Yala.Category?) -> TransactionItem {
            TransactionItem(
                date: date, amount: amount, currencyCode: "PEN", category: category, account: account,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            )
        }
        let spend = tx(-200, food)
        let adjustment = tx(-500, others)
        adjustment.balanceAdjustmentType = "initial_balance"
        let shared = tx(-300, food)
        shared.splitExpenseID = "split-1"
        let uncategorized = tx(-40, nil)
        let salary = tx(1_000, salaryCat)
        let budget = Budget(
            currencyCode: "PEN", limitAmount: 1_000, name: "Mes", periodType: "monthly",
            isFavorite: true, includeSharedExpenses: false
        )
        return (budget, [spend, adjustment, shared, uncategorized, salary])
    }

    @Test("Lo gastado en la tarjeta del Panel es lo de Planificación (ajustes, gastos de grupo, sin categoría)")
    func panelSpentEqualsPlanning() {
        let (budget, txs) = scenario()

        let panel = PanelViewModel()
        panel.calculateBudgetsWidget(budgets: [budget], transactions: txs, defaultCurrencyCode: "PEN")
        let panelSummary = panel.budgetsWidget.topBudgetSummaries.first

        let planning = BudgetsViewModel()
        planning.calculateBudgetData(budgets: [budget], transactions: txs, accounts: [], defaultCurrencyCode: "PEN")
        let planningSummary = planning.groupedBudgets.flatMap(\.budgets).first

        let alerts = BudgetsViewModel.calculateSpending(
            budget: budget, transactions: txs, interval: panel.getBudgetDateInterval(budget: budget)
        )

        #expect(panelSummary?.spent == 240, "Panel: \(String(describing: panelSummary?.spent))")
        #expect(planningSummary?.spent == 240, "Planificación: \(String(describing: planningSummary?.spent))")
        #expect(alerts == 240)
        #expect(panelSummary?.spent == planningSummary?.spent)
        #expect(panelSummary?.percentage == planningSummary?.percentage)
        #expect(panelSummary?.status == planningSummary?.status)
    }

    /// Source-scan del cableado: el Panel no vuelve a filtrar los movimientos de un presupuesto por su cuenta.
    @Test("El Panel no tiene filtro propio de presupuestos")
    func panelHasNoOwnBudgetFilter() throws {
        let source = try String(contentsOfFile: sourcePath("Yala/App/ViewModels/PanelViewModel.swift"), encoding: .utf8)
        let start = try #require(source.range(of: "private func calculateBudgetSummary("))
        let end = try #require(source.range(of: "return BudgetSummary(", range: start.upperBound..<source.endIndex))
        let body = String(source[start.upperBound..<end.lowerBound])
        #expect(body.contains("BudgetsViewModel.calculateSpending("))
        #expect(body.contains("adjustment: statsAdjustment"))
        #expect(!body.contains(".filter"))
    }

    private func sourcePath(_ relative: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relative)
            .path
    }
}
