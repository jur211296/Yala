//
//  OnboardingModeTests.swift
//  YalaTests
//
//  Tests for OnboardingMode enum — rank ordering and transitions.
//

import Foundation
import Testing

@testable import Yala

struct OnboardingModeTests {

    // MARK: - Rank Ordering (never-downgrade rule)

    @Test func rank_fullIsLowest() {
        #expect(OnboardingMode.full.rank == 0)
    }

    @Test func rank_groupInviteIsMiddle() {
        #expect(OnboardingMode.groupInvite.rank == 1)
    }

    @Test func rank_completedIsHighest() {
        #expect(OnboardingMode.completed.rank == 2)
    }

    @Test func rank_ordering_fullLessThanGroupInvite() {
        #expect(OnboardingMode.full.rank < OnboardingMode.groupInvite.rank)
    }

    @Test func rank_ordering_groupInviteLessThanCompleted() {
        #expect(OnboardingMode.groupInvite.rank < OnboardingMode.completed.rank)
    }

    // MARK: - Raw Value Roundtrip

    @Test func rawValue_full_roundtrips() {
        #expect(OnboardingMode(rawValue: "full") == .full)
    }

    @Test func rawValue_groupInvite_roundtrips() {
        #expect(OnboardingMode(rawValue: "groupInvite") == .groupInvite)
    }

    @Test func rawValue_completed_roundtrips() {
        #expect(OnboardingMode(rawValue: "completed") == .completed)
    }

    @Test func rawValue_invalid_returnsNil() {
        #expect(OnboardingMode(rawValue: "unknown") == nil)
    }

    // MARK: - Never-Downgrade Merge Logic

    @Test func merge_fullToGroupInvite_upgrades() {
        let local = OnboardingMode.full
        let remote = OnboardingMode.groupInvite
        let merged = remote.rank > local.rank ? remote : local
        #expect(merged == .groupInvite)
    }

    @Test func merge_groupInviteToCompleted_upgrades() {
        let local = OnboardingMode.groupInvite
        let remote = OnboardingMode.completed
        let merged = remote.rank > local.rank ? remote : local
        #expect(merged == .completed)
    }

    @Test func merge_completedToFull_doesNotDowngrade() {
        let local = OnboardingMode.completed
        let remote = OnboardingMode.full
        let merged = remote.rank > local.rank ? remote : local
        #expect(merged == .completed)
    }

    @Test func merge_completedToGroupInvite_doesNotDowngrade() {
        let local = OnboardingMode.completed
        let remote = OnboardingMode.groupInvite
        let merged = remote.rank > local.rank ? remote : local
        #expect(merged == .completed)
    }

    @Test func merge_sameMode_noChange() {
        let local = OnboardingMode.groupInvite
        let remote = OnboardingMode.groupInvite
        let merged = remote.rank > local.rank ? remote : local
        #expect(merged == .groupInvite)
    }
}
