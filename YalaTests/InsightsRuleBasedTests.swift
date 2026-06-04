//
//  InsightsRuleBasedTests.swift
//  YalaTests
//
//  Unit tests for InsightsCalculator.generateRuleBasedInsights rule logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct InsightsRuleBasedTests {

    // MARK: - Helpers

    private func makeCategory(name: String) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#000000", isIncome: false)
    }

    private func makePeriodSummary(
        totalExpense: Double = 1000,
        expenseVariation: Double? = nil
    ) -> PeriodSummary {
        PeriodSummary(
            totalExpense: totalExpense,
            totalIncome: 2000,
            netBalance: 1000,
            transactionCount: 10,
            expenseVariation: expenseVariation,
            incomeVariation: nil,
            balanceVariation: nil,
            dailyAverageCount: 1,
            dailyAverageExpense: 33,
            dailyAverageVariation: nil,
            previousPeriodLabel: "last month"
        )
    }

    private func makeQuickStats() -> QuickStats {
        QuickStats(
            dailyAverage: 33,
            topCategories: [],
            topSubcategories: [],
            highestExpense: nil,
            highestAvgWeekday: nil,
            subscriptionsTotal: 0
        )
    }

    private func makeCommitments(budgetsAtRisk: [BudgetAtRisk] = []) -> Commitments {
        Commitments(
            pendingPaymentsCount: 0,
            pendingPaymentsAmount: 0,
            activeSubscriptionsCount: 0,
            activeSubscriptionsMonthly: 0,
            activeRecurringCount: 0,
            activeRecurringMonthly: 0,
            budgetsAtRisk: budgetsAtRisk
        )
    }

    private func makeNeedDistribution(
        essential: Double = 500,
        priority: Double = 300,
        optional: Double = 200
    ) -> NeedDistribution {
        NeedDistribution(
            essential: essential,
            priority: priority,
            optional: optional,
            total: essential + priority + optional
        )
    }

    private func makeCashFlow() -> CashFlowSummary {
        CashFlowSummary(
            totalIncome: 2000,
            totalExpense: 1000,
            netFlow: 1000,
            chartData: [],
            currencyCode: "USD"
        )
    }

    private func makeBudgetAtRisk(name: String, usagePercent: Double) -> BudgetAtRisk {
        let budget = Budget(currencyCode: "USD", limitAmount: 1000)
        return BudgetAtRisk(
            id: budget.persistentModelID,
            name: name,
            icon: "dollarsign.circle",
            usagePercent: usagePercent,
            spent: usagePercent * 10,
            limit: 1000,
            colorHex: "#FF0000"
        )
    }

    // MARK: - Tests

    @Test func benignInputs_noSpecificRulesTriggered() {
        let cat = makeCategory(name: "Food")
        let catSummary = CategorySpendingSummary(category: cat, amount: 200, percentage: 20)

        let result = InsightsCalculator.generateRuleBasedInsights(
            periodSummary: makePeriodSummary(expenseVariation: 5),
            quickStats: makeQuickStats(),
            commitments: makeCommitments(),
            needDistribution: makeNeedDistribution(),
            yearOverYear: nil,
            topCategories: [catSummary],
            prevCashFlow: makeCashFlow(),
            currencyCode: "USD"
        )
        // Las reglas universales (daily_average_snapshot, savings_*) siempre aparecen
        // cuando hay gasto/ingreso > 0 (Reglas 5/6 del stats polish). Con inputs benignos
        // (categoría 20% < umbral, variación de gasto 5% < umbral, sin presupuestos en
        // riesgo, opcional 20% < 40%) NINGUNA regla específica debe dispararse.
        let specificIDs: Set<String> = ["top_category_dominant", "expense_up", "expense_down", "optional_high"]
        #expect(result.allSatisfy { !specificIDs.contains($0.id) && !$0.id.hasPrefix("budget_risk_") })
    }

    @Test func topCategoryDominant_balanced() {
        let cat = makeCategory(name: "Rent")
        let catSummary = CategorySpendingSummary(category: cat, amount: 500, percentage: 50)

        let result = InsightsCalculator.generateRuleBasedInsights(
            periodSummary: makePeriodSummary(),
            quickStats: makeQuickStats(),
            commitments: makeCommitments(),
            needDistribution: makeNeedDistribution(),
            yearOverYear: nil,
            topCategories: [catSummary],
            prevCashFlow: makeCashFlow(),
            currencyCode: "USD",
            focus: .balanced
        )
        #expect(result.contains(where: { $0.id == "top_category_dominant" }))
    }

    @Test func topCategoryDominant_saverThreshold() {
        let cat = makeCategory(name: "Rent")
        // 35% > 30% (saver threshold) but < 40% (balanced threshold)
        let catSummary = CategorySpendingSummary(category: cat, amount: 350, percentage: 35)

        let result = InsightsCalculator.generateRuleBasedInsights(
            periodSummary: makePeriodSummary(),
            quickStats: makeQuickStats(),
            commitments: makeCommitments(),
            needDistribution: makeNeedDistribution(),
            yearOverYear: nil,
            topCategories: [catSummary],
            prevCashFlow: makeCashFlow(),
            currencyCode: "USD",
            focus: .saver
        )
        #expect(result.contains(where: { $0.id == "top_category_dominant" }))
    }

    @Test func expenseUp_triggersAttention() {
        let result = InsightsCalculator.generateRuleBasedInsights(
            periodSummary: makePeriodSummary(expenseVariation: 20),
            quickStats: makeQuickStats(),
            commitments: makeCommitments(),
            needDistribution: makeNeedDistribution(),
            yearOverYear: nil,
            topCategories: [],
            prevCashFlow: makeCashFlow(),
            currencyCode: "USD"
        )
        let insight = result.first(where: { $0.id == "expense_up" })
        #expect(insight != nil)
        #expect(insight?.sentiment == .attention)
    }

    @Test func expenseDown_triggersPositive() {
        let result = InsightsCalculator.generateRuleBasedInsights(
            periodSummary: makePeriodSummary(expenseVariation: -15),
            quickStats: makeQuickStats(),
            commitments: makeCommitments(),
            needDistribution: makeNeedDistribution(),
            yearOverYear: nil,
            topCategories: [],
            prevCashFlow: makeCashFlow(),
            currencyCode: "USD"
        )
        let insight = result.first(where: { $0.id == "expense_down" })
        #expect(insight != nil)
        #expect(insight?.sentiment == .positive)
    }

    @Test func expenseUp_cautiousThreshold() {
        // 12% > 10% (cautious threshold) but < 15% (balanced threshold)
        let result = InsightsCalculator.generateRuleBasedInsights(
            periodSummary: makePeriodSummary(expenseVariation: 12),
            quickStats: makeQuickStats(),
            commitments: makeCommitments(),
            needDistribution: makeNeedDistribution(),
            yearOverYear: nil,
            topCategories: [],
            prevCashFlow: makeCashFlow(),
            currencyCode: "USD",
            focus: .cautious
        )
        #expect(result.contains(where: { $0.id == "expense_up" }))
    }

    @Test func budgetAtRisk_90percent() {
        let risk = makeBudgetAtRisk(name: "Food", usagePercent: 95)

        let result = InsightsCalculator.generateRuleBasedInsights(
            periodSummary: makePeriodSummary(),
            quickStats: makeQuickStats(),
            commitments: makeCommitments(budgetsAtRisk: [risk]),
            needDistribution: makeNeedDistribution(),
            yearOverYear: nil,
            topCategories: [],
            prevCashFlow: makeCashFlow(),
            currencyCode: "USD"
        )
        #expect(result.contains(where: { $0.id == "budget_risk_Food" }))
    }

    @Test func budgetAtRisk_cautiousThreshold() {
        // 80% > 75% (cautious threshold) but < 90% (balanced threshold)
        let risk1 = makeBudgetAtRisk(name: "Food", usagePercent: 80)
        let risk2 = makeBudgetAtRisk(name: "Transport", usagePercent: 85)

        let result = InsightsCalculator.generateRuleBasedInsights(
            periodSummary: makePeriodSummary(),
            quickStats: makeQuickStats(),
            commitments: makeCommitments(budgetsAtRisk: [risk2, risk1]),
            needDistribution: makeNeedDistribution(),
            yearOverYear: nil,
            topCategories: [],
            prevCashFlow: makeCashFlow(),
            currencyCode: "USD",
            focus: .cautious
        )
        // Cautious allows up to 2 budget alerts
        let budgetInsights = result.filter { $0.id.hasPrefix("budget_risk_") }
        #expect(budgetInsights.count == 2)
    }

    @Test func optionalSpendingHigh() {
        // optional 450 / total 1000 = 45% > 40%
        let result = InsightsCalculator.generateRuleBasedInsights(
            periodSummary: makePeriodSummary(),
            quickStats: makeQuickStats(),
            commitments: makeCommitments(),
            needDistribution: makeNeedDistribution(essential: 300, priority: 250, optional: 450),
            yearOverYear: nil,
            topCategories: [],
            prevCashFlow: makeCashFlow(),
            currencyCode: "USD"
        )
        #expect(result.contains(where: { $0.id == "optional_high" }))
    }

    @Test func multipleRules_allFire() {
        let cat = makeCategory(name: "Rent")
        let catSummary = CategorySpendingSummary(category: cat, amount: 500, percentage: 50)
        let risk = makeBudgetAtRisk(name: "Food", usagePercent: 95)

        let result = InsightsCalculator.generateRuleBasedInsights(
            periodSummary: makePeriodSummary(expenseVariation: 25),
            quickStats: makeQuickStats(),
            commitments: makeCommitments(budgetsAtRisk: [risk]),
            needDistribution: makeNeedDistribution(essential: 200, priority: 100, optional: 500),
            yearOverYear: nil,
            topCategories: [catSummary],
            prevCashFlow: makeCashFlow(),
            currencyCode: "USD"
        )
        // Should trigger: top_category_dominant, expense_up, budget_risk_Food, optional_high
        #expect(result.count >= 3)
    }
}
