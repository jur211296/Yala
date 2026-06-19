//
//  InsightsRuleBasedGroupTests.swift
//  YalaTests
//
//  Tests for the 6 group insight rules in InsightsCalculator.
//

import Foundation
import Testing

@testable import Yala

struct InsightsRuleBasedGroupTests {

    // MARK: - Helpers

    private func makeContext(
        totalShared: Double = 0,
        totalPersonal: Double = 0,
        sharedCount: Int = 0,
        groupExpenses: [(groupName: String, total: Double)] = [],
        categoryBreakdown: [(category: String, amount: Double)] = [],
        previousShared: Double? = nil,
        pendingDebt: Double = 0,
        groupCount: Int = 1
    ) -> GroupInsightsContext {
        GroupInsightsContext(
            totalSharedExpense: totalShared,
            totalPersonalExpense: totalPersonal,
            sharedExpenseCount: sharedCount,
            groupExpensesByGroup: groupExpenses,
            sharedCategoryBreakdown: categoryBreakdown,
            previousPeriodSharedExpense: previousShared,
            pendingDebtTotal: pendingDebt,
            groupCount: groupCount,
            currencyCode: "PEN"
        )
    }

    private func generate(
        context: GroupInsightsContext,
        dailyAverage: Double = 100,
        focus: InsightFocus = .balanced
    ) -> [InsightResult] {
        InsightsCalculator.generateGroupInsights(
            groupContext: context,
            dailyAverage: dailyAverage,
            currencyCode: "PEN",
            focus: focus
        )
    }

    // MARK: - R1: Shared Ratio

    @Test func sharedRatio_triggersAboveThreshold() {
        let ctx = makeContext(totalShared: 300, totalPersonal: 700)
        let results = generate(context: ctx)
        #expect(results.contains { $0.id == "shared_ratio" })
    }

    @Test func sharedRatio_doesNotTriggerBelowThreshold() {
        let ctx = makeContext(totalShared: 100, totalPersonal: 900)
        let results = generate(context: ctx)
        #expect(!results.contains { $0.id == "shared_ratio" })
    }

    // MARK: - R2: Most Expensive Group

    @Test func mostExpensiveGroup_triggersWhenDominant() {
        let ctx = makeContext(
            totalShared: 500,
            groupExpenses: [("Depa", 400), ("Viaje", 100)],
            groupCount: 2
        )
        let results = generate(context: ctx)
        #expect(results.contains { $0.id == "most_expensive_group" })
    }

    @Test func mostExpensiveGroup_doesNotTriggerWithOneGroup() {
        let ctx = makeContext(
            totalShared: 500,
            groupExpenses: [("Depa", 500)],
            groupCount: 1
        )
        let results = generate(context: ctx)
        #expect(!results.contains { $0.id == "most_expensive_group" })
    }

    // MARK: - R3: Shared Frequency

    @Test func sharedFrequency_triggersForHighCount() {
        let ctx = makeContext(sharedCount: 12)
        let results = generate(context: ctx)
        #expect(results.contains { $0.id == "shared_frequency" })
    }

    @Test func sharedFrequency_doesNotTriggerForLowCount() {
        let ctx = makeContext(sharedCount: 5)
        let results = generate(context: ctx)
        #expect(!results.contains { $0.id == "shared_frequency" })
    }

    // R4 (High Pending Debt) eliminada del producto en `7c7153dd` (insights #12 —
    // remove ruleHighDebt insight). Los tests del id "high_pending_debt" se borraron
    // con la regla; no hay cobertura que reabrir (feature removida intencionalmente).

    // MARK: - R5: Dominant Shared Category

    @Test func dominantSharedCategory_triggersAbove50Pct() {
        let ctx = makeContext(
            totalShared: 1000,
            categoryBreakdown: [("Comida", 600), ("Transporte", 400)]
        )
        let results = generate(context: ctx)
        #expect(results.contains { $0.id == "dominant_shared_category" })
    }

    // MARK: - R6: Shared MoM Variation

    @Test func sharedMoM_triggersFor30PctIncrease() {
        let ctx = makeContext(totalShared: 1400, previousShared: 1000)
        let results = generate(context: ctx)
        #expect(results.contains { $0.id == "shared_mom_variation" })
    }

    @Test func sharedMoM_doesNotTriggerForSmallIncrease() {
        let ctx = makeContext(totalShared: 1100, previousShared: 1000)
        let results = generate(context: ctx)
        #expect(!results.contains { $0.id == "shared_mom_variation" })
    }

    // MARK: - Edge Cases

    @Test func noSharedExpenses_noGroupInsights() {
        let ctx = makeContext()
        let results = generate(context: ctx)
        #expect(results.isEmpty)
    }
}
