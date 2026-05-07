//
//  NudgeTriggerEvaluatorTests.swift
//  YalaTests
//
//  Tests for NudgeTriggerEvaluator.shouldShow() — pure static logic, no SwiftData.
//

import Foundation
import Testing

@testable import Yala

struct NudgeTriggerEvaluatorTests {

    // MARK: - Helpers

    /// Creates a context with all zeros except the specified override.
    private func context(
        totalSharedAmount: Double = 0,
        sharedExpenseCount: Int = 0,
        hasConfirmedSettlement: Bool = false,
        personalTransactionCount: Int = 0,
        groupMemberCount: Int = 0,
        currentMonthSharedCount: Int = 0,
        monthOverMonthVariation: Double = 0,
        enteredViaGroupNotification: Bool = false
    ) -> NudgeTriggerContext {
        NudgeTriggerContext(
            totalSharedAmount: totalSharedAmount,
            sharedExpenseCount: sharedExpenseCount,
            hasConfirmedSettlement: hasConfirmedSettlement,
            personalTransactionCount: personalTransactionCount,
            groupMemberCount: groupMemberCount,
            currentMonthSharedCount: currentMonthSharedCount,
            monthOverMonthVariation: monthOverMonthVariation,
            enteredViaGroupNotification: enteredViaGroupNotification
        )
    }

    // MARK: - Invited Nudges

    @Test func invitedSpendingInsight_below500_returnsFalse() {
        let ctx = context(totalSharedAmount: 499)
        #expect(NudgeTriggerEvaluator.shouldShow(.invitedSpendingInsight, context: ctx) == false)
    }

    @Test func invitedSpendingInsight_above500_returnsTrue() {
        let ctx = context(totalSharedAmount: 501)
        #expect(NudgeTriggerEvaluator.shouldShow(.invitedSpendingInsight, context: ctx) == true)
    }

    @Test func invitedPostSettlement_withoutSettlement_returnsFalse() {
        let ctx = context(hasConfirmedSettlement: false)
        #expect(NudgeTriggerEvaluator.shouldShow(.invitedPostSettlement, context: ctx) == false)
    }

    @Test func invitedPostSettlement_withSettlement_returnsTrue() {
        let ctx = context(hasConfirmedSettlement: true)
        #expect(NudgeTriggerEvaluator.shouldShow(.invitedPostSettlement, context: ctx) == true)
    }

    @Test func invitedMonthTwo_at10Expenses_returnsFalse() {
        let ctx = context(sharedExpenseCount: 10)
        #expect(NudgeTriggerEvaluator.shouldShow(.invitedMonthTwo, context: ctx) == false)
    }

    @Test func invitedMonthTwo_at11Expenses_returnsTrue() {
        let ctx = context(sharedExpenseCount: 11)
        #expect(NudgeTriggerEvaluator.shouldShow(.invitedMonthTwo, context: ctx) == true)
    }

    @Test func invitedSocialProof_at2Members_returnsFalse() {
        let ctx = context(groupMemberCount: 2)
        #expect(NudgeTriggerEvaluator.shouldShow(.invitedSocialProof, context: ctx) == false)
    }

    @Test func invitedSocialProof_at3Members_returnsTrue() {
        let ctx = context(groupMemberCount: 3)
        #expect(NudgeTriggerEvaluator.shouldShow(.invitedSocialProof, context: ctx) == true)
    }

    // MARK: - Dormant Nudges

    @Test func dormantGroupsAsMain_withoutGroups_returnsFalse() {
        // Bug #2 (2026-05-07): banner "Tienes gastos compartidos pendientes" no
        // debe aparecer en users post-onboarding sin grupos.
        let ctx = context(groupMemberCount: 0)
        #expect(NudgeTriggerEvaluator.shouldShow(.dormantGroupsAsMain, context: ctx) == false)
    }

    @Test func dormantGroupsAsMain_withGroups_returnsTrue() {
        let ctx = context(groupMemberCount: 1)
        #expect(NudgeTriggerEvaluator.shouldShow(.dormantGroupsAsMain, context: ctx) == true)
    }

    @Test func dormantNewExpenses_at0Expenses_returnsFalse() {
        let ctx = context(sharedExpenseCount: 0)
        #expect(NudgeTriggerEvaluator.shouldShow(.dormantNewExpenses, context: ctx) == false)
    }

    @Test func dormantNewExpenses_at1Expense_returnsTrue() {
        let ctx = context(sharedExpenseCount: 1)
        #expect(NudgeTriggerEvaluator.shouldShow(.dormantNewExpenses, context: ctx) == true)
    }

    @Test func dormantSpendingGap_at5Expenses_returnsFalse() {
        let ctx = context(sharedExpenseCount: 5)
        #expect(NudgeTriggerEvaluator.shouldShow(.dormantSpendingGap, context: ctx) == false)
    }

    @Test func dormantSpendingGap_at6Expenses_returnsTrue() {
        let ctx = context(sharedExpenseCount: 6)
        #expect(NudgeTriggerEvaluator.shouldShow(.dormantSpendingGap, context: ctx) == true)
    }

    @Test func dormantQuickEntry_withoutNotification_returnsFalse() {
        let ctx = context(enteredViaGroupNotification: false)
        #expect(NudgeTriggerEvaluator.shouldShow(.dormantQuickEntry, context: ctx) == false)
    }

    @Test func dormantQuickEntry_withNotification_returnsTrue() {
        let ctx = context(enteredViaGroupNotification: true)
        #expect(NudgeTriggerEvaluator.shouldShow(.dormantQuickEntry, context: ctx) == true)
    }

    // MARK: - Sporadic Nudges

    @Test func sporadicImbalance_ratioAtOrBelow3_returnsFalse() {
        // sharedExpenseCount=3, personalTransactionCount=1 → 3 > 1*3 is false (3 is not > 3)
        let ctx = context(sharedExpenseCount: 3, personalTransactionCount: 1)
        #expect(NudgeTriggerEvaluator.shouldShow(.sporadicImbalance, context: ctx) == false)
    }

    @Test func sporadicImbalance_ratioAbove3_returnsTrue() {
        // sharedExpenseCount=4, personalTransactionCount=1 → 4 > 1*3 is true
        let ctx = context(sharedExpenseCount: 4, personalTransactionCount: 1)
        #expect(NudgeTriggerEvaluator.shouldShow(.sporadicImbalance, context: ctx) == true)
    }

    @Test func sporadicBudgetSuggestion_at10_returnsFalse() {
        let ctx = context(currentMonthSharedCount: 10)
        #expect(NudgeTriggerEvaluator.shouldShow(.sporadicBudgetSuggestion, context: ctx) == false)
    }

    @Test func sporadicBudgetSuggestion_at11_returnsTrue() {
        let ctx = context(currentMonthSharedCount: 11)
        #expect(NudgeTriggerEvaluator.shouldShow(.sporadicBudgetSuggestion, context: ctx) == true)
    }

    @Test func sporadicTrendAlert_at0point4_returnsFalse() {
        let ctx = context(monthOverMonthVariation: 0.4)
        #expect(NudgeTriggerEvaluator.shouldShow(.sporadicTrendAlert, context: ctx) == false)
    }

    @Test func sporadicTrendAlert_at0point41_returnsTrue() {
        let ctx = context(monthOverMonthVariation: 0.41)
        #expect(NudgeTriggerEvaluator.shouldShow(.sporadicTrendAlert, context: ctx) == true)
    }

    // MARK: - Edge Cases

    @Test func sporadicImbalance_zeroPersonalTransactions_usesMinimum1() {
        // personalTransactionCount=0 → max(0,1)=1 → sharedExpenseCount=4 > 1*3 = true
        let ctx = context(sharedExpenseCount: 4, personalTransactionCount: 0)
        #expect(NudgeTriggerEvaluator.shouldShow(.sporadicImbalance, context: ctx) == true)
    }

    @Test func invitedSpendingInsight_exactly500_returnsFalse() {
        // Boundary: > 500, not >= 500
        let ctx = context(totalSharedAmount: 500)
        #expect(NudgeTriggerEvaluator.shouldShow(.invitedSpendingInsight, context: ctx) == false)
    }
}

/*
Tests generated:
1. invitedSpendingInsight_below500_returnsFalse - Below threshold
2. invitedSpendingInsight_above500_returnsTrue - Above threshold
3. invitedPostSettlement_withoutSettlement_returnsFalse - No confirmed settlement
4. invitedPostSettlement_withSettlement_returnsTrue - Has confirmed settlement
5. invitedMonthTwo_at10Expenses_returnsFalse - Boundary below
6. invitedMonthTwo_at11Expenses_returnsTrue - Boundary above
7. invitedSocialProof_at2Members_returnsFalse - Below member threshold
8. invitedSocialProof_at3Members_returnsTrue - At member threshold (>=3)
9a. dormantGroupsAsMain_withoutGroups_returnsFalse - Bug #2 fix: gate por groupMemberCount
9b. dormantGroupsAsMain_withGroups_returnsTrue - Eligible cuando hay grupos
10. dormantNewExpenses_at0Expenses_returnsFalse - Zero expenses
11. dormantNewExpenses_at1Expense_returnsTrue - Has expenses
12. dormantSpendingGap_at5Expenses_returnsFalse - At boundary (not >5)
13. dormantSpendingGap_at6Expenses_returnsTrue - Above boundary
14. dormantQuickEntry_withoutNotification_returnsFalse - No notification entry
15. dormantQuickEntry_withNotification_returnsTrue - Entered via notification
16. sporadicImbalance_ratioAtOrBelow3_returnsFalse - Ratio exactly 3
17. sporadicImbalance_ratioAbove3_returnsTrue - Ratio above 3
18. sporadicBudgetSuggestion_at10_returnsFalse - At boundary
19. sporadicBudgetSuggestion_at11_returnsTrue - Above boundary
20. sporadicTrendAlert_at0point4_returnsFalse - At boundary (not >0.4)
21. sporadicTrendAlert_at0point41_returnsTrue - Above boundary
22. sporadicImbalance_zeroPersonalTransactions_usesMinimum1 - Edge: max(0,1) guard
23. invitedSpendingInsight_exactly500_returnsFalse - Boundary: > not >=

Cases NOT covered:
- None — all 11 nudge triggers covered with boundary tests
*/
