//
//  NudgeTypeTests.swift
//  YalaTests
//
//  Tests for NudgeType enum — pure logic, no SwiftData.
//

import Foundation
import Testing

@testable import Yala

struct NudgeTypeTests {

    // MARK: - allCases

    @Test func allCases_has11Cases() {
        #expect(NudgeType.allCases.count == 11)
    }

    // MARK: - nudges(for:) Segment Filtering

    @Test func nudges_forInvited_returns4() {
        let nudges = NudgeType.nudges(for: .invited)
        #expect(nudges.count == 4)
        #expect(nudges.contains(.invitedSpendingInsight))
        #expect(nudges.contains(.invitedPostSettlement))
        #expect(nudges.contains(.invitedMonthTwo))
        #expect(nudges.contains(.invitedSocialProof))
    }

    @Test func nudges_forDormant_returns4() {
        let nudges = NudgeType.nudges(for: .dormant)
        #expect(nudges.count == 4)
        #expect(nudges.contains(.dormantGroupsAsMain))
        #expect(nudges.contains(.dormantNewExpenses))
        #expect(nudges.contains(.dormantSpendingGap))
        #expect(nudges.contains(.dormantQuickEntry))
    }

    @Test func nudges_forSporadic_returns3() {
        let nudges = NudgeType.nudges(for: .sporadic)
        #expect(nudges.count == 3)
        #expect(nudges.contains(.sporadicImbalance))
        #expect(nudges.contains(.sporadicBudgetSuggestion))
        #expect(nudges.contains(.sporadicTrendAlert))
    }

    @Test func nudges_forActive_returnsEmpty() {
        let nudges = NudgeType.nudges(for: .active)
        #expect(nudges.isEmpty)
    }

    @Test func nudges_forPowerUser_returnsEmpty() {
        let nudges = NudgeType.nudges(for: .powerUser)
        #expect(nudges.isEmpty)
    }

    // MARK: - Segment Mapping

    @Test func segment_eachNudgeMapsToCorrectSegment() {
        // Invited nudges
        #expect(NudgeType.invitedSpendingInsight.segment == .invited)
        #expect(NudgeType.invitedPostSettlement.segment == .invited)
        #expect(NudgeType.invitedMonthTwo.segment == .invited)
        #expect(NudgeType.invitedSocialProof.segment == .invited)

        // Dormant nudges
        #expect(NudgeType.dormantGroupsAsMain.segment == .dormant)
        #expect(NudgeType.dormantNewExpenses.segment == .dormant)
        #expect(NudgeType.dormantSpendingGap.segment == .dormant)
        #expect(NudgeType.dormantQuickEntry.segment == .dormant)

        // Sporadic nudges
        #expect(NudgeType.sporadicImbalance.segment == .sporadic)
        #expect(NudgeType.sporadicBudgetSuggestion.segment == .sporadic)
        #expect(NudgeType.sporadicTrendAlert.segment == .sporadic)
    }

    // MARK: - minimumWeek Values

    @Test func minimumWeek_valuesCorrectForKeyNudges() {
        #expect(NudgeType.dormantGroupsAsMain.minimumWeek == 0)
        #expect(NudgeType.dormantNewExpenses.minimumWeek == 1)
        #expect(NudgeType.sporadicImbalance.minimumWeek == 1)
        #expect(NudgeType.dormantSpendingGap.minimumWeek == 2)
        #expect(NudgeType.sporadicBudgetSuggestion.minimumWeek == 2)
        #expect(NudgeType.invitedSpendingInsight.minimumWeek == 3)
        #expect(NudgeType.dormantQuickEntry.minimumWeek == 3)
        #expect(NudgeType.invitedPostSettlement.minimumWeek == 4)
        #expect(NudgeType.invitedMonthTwo.minimumWeek == 8)
        #expect(NudgeType.invitedSocialProof.minimumWeek == 8)
        #expect(NudgeType.sporadicTrendAlert.minimumWeek == 8)
    }
}

/*
Tests generated:
1. test allCases_has11Cases - Verifies NudgeType.allCases count
2. test nudges_forInvited_returns4 - Filtering by invited segment
3. test nudges_forDormant_returns4 - Filtering by dormant segment
4. test nudges_forSporadic_returns3 - Filtering by sporadic segment
5. test nudges_forActive_returnsEmpty - Active segment has no nudges
6. test nudges_forPowerUser_returnsEmpty - Power user segment has no nudges
7. test segment_eachNudgeMapsToCorrectSegment - All 11 nudges map to correct segment
8. test minimumWeek_valuesCorrectForKeyNudges - All minimumWeek timing gates

Cases NOT covered (no need):
- icon and ctaLabel — localization strings, not logic
- actionType — simple mapping, low risk
*/
