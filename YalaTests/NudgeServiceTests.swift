//
//  NudgeServiceTests.swift
//  YalaTests
//
//  Tests for NudgeService frequency capping via UserDefaults.
//  Uses resetForTesting() to clean singleton state between tests.
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
struct NudgeServiceTests {

    // MARK: - Helpers

    @MainActor
    private func freshService() -> NudgeService {
        let sut = NudgeService.shared
        sut.resetForTesting()
        return sut
    }

    // MARK: - canShowNudge

    @MainActor @Test func canShowNudge_freshState_returnsTrue() {
        let sut = freshService()
        #expect(sut.canShowNudge() == true)
    }

    @MainActor @Test func canShowNudge_weeklyCountAtMax_returnsFalse() {
        let sut = freshService()
        UserDefaults.standard.set(1, forKey: "nudge.weeklyShownCount")
        UserDefaults.standard.set(Date.now, forKey: "nudge.weeklyResetDate")
        #expect(sut.canShowNudge() == false)
    }

    @MainActor @Test func canShowNudge_monthlyCountAtMax_returnsFalse() {
        let sut = freshService()
        UserDefaults.standard.set(0, forKey: "nudge.weeklyShownCount")
        UserDefaults.standard.set(Date.now, forKey: "nudge.weeklyResetDate")
        UserDefaults.standard.set(3, forKey: "nudge.monthlyShownCount")
        UserDefaults.standard.set(Date.now, forKey: "nudge.monthlyResetDate")
        #expect(sut.canShowNudge() == false)
    }

    // MARK: - recordInteracted / recordDismissed

    @MainActor @Test func recordInteracted_marksNudgeAsInteracted() {
        let sut = freshService()
        let nudge = NudgeType.invitedSpendingInsight
        let key = "nudge.interacted.\(nudge.rawValue)"

        #expect(UserDefaults.standard.bool(forKey: key) == false)
        sut.recordInteracted(nudge)
        #expect(UserDefaults.standard.bool(forKey: key) == true)
    }

    @MainActor @Test func recordDismissed_doesNotMarkAsInteracted() {
        let sut = freshService()
        let nudge = NudgeType.dormantNewExpenses
        let key = "nudge.interacted.\(nudge.rawValue)"

        sut.recordDismissed(nudge)
        // Dismissed nudges should NOT be permanently suppressed
        #expect(UserDefaults.standard.bool(forKey: key) == false)
    }

    @MainActor @Test func recordInteracted_clearsCurrentNudge() {
        let sut = freshService()
        sut.recordInteracted(.sporadicImbalance)
        #expect(sut.currentNudge == nil)
        #expect(sut.currentNudgeMessage == nil)
    }

    // MARK: - recordGroupJoinIfNeeded

    @MainActor @Test func recordGroupJoinIfNeeded_setsDateOnFirstCall() {
        let sut = freshService()
        let key = "nudge.firstGroupJoinDate"

        #expect(UserDefaults.standard.object(forKey: key) == nil)
        sut.recordGroupJoinIfNeeded()

        let stored = UserDefaults.standard.object(forKey: key) as? Date
        #expect(stored != nil)
    }

    @MainActor @Test func recordGroupJoinIfNeeded_doesNotOverwriteExistingDate() {
        let sut = freshService()
        let key = "nudge.firstGroupJoinDate"

        let earlier = Date.now.addingTimeInterval(-86400 * 30)
        UserDefaults.standard.set(earlier, forKey: key)

        sut.recordGroupJoinIfNeeded()

        let stored = UserDefaults.standard.object(forKey: key) as? Date
        #expect(stored == earlier)
    }

    // MARK: - resetForTesting

    @MainActor @Test func resetForTesting_clearsAllState() {
        let sut = freshService()

        // Populate state
        sut.recordInteracted(.invitedSpendingInsight)
        UserDefaults.standard.set(Date.now, forKey: "nudge.firstGroupJoinDate")
        UserDefaults.standard.set(Date.now, forKey: "nudge.lastShownDate")
        UserDefaults.standard.set(2, forKey: "nudge.weeklyShownCount")
        UserDefaults.standard.set(5, forKey: "nudge.monthlyShownCount")

        sut.resetForTesting()

        #expect(sut.currentNudge == nil)
        #expect(sut.currentNudgeMessage == nil)
        #expect(sut.canShowNudge() == true)
        #expect(UserDefaults.standard.object(forKey: "nudge.lastShownDate") == nil)
        #expect(UserDefaults.standard.integer(forKey: "nudge.weeklyShownCount") == 0)
        #expect(UserDefaults.standard.integer(forKey: "nudge.monthlyShownCount") == 0)
        #expect(UserDefaults.standard.object(forKey: "nudge.firstGroupJoinDate") == nil)
        #expect(UserDefaults.standard.bool(forKey: "nudge.interacted.invitedSpendingInsight") == false)
    }
}
