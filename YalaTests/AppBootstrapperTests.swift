//
//  AppBootstrapperTests.swift
//  YalaTests
//
//  Unit tests for AppBootstrapper retry logic and invite link handling.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct AppBootstrapperTests {

    // MARK: - handleInviteLink invalid URL
    //
    // Note: end-to-end tests of `retryPendingBridges` crash the Swift Testing runner —
    // the bridge invokes globals (WidgetDataCache, BudgetAlertService, SessionState)
    // that assume a fully-configured app environment. The retry flow is exercised
    // manually via the smoke checklist instead.

    @Test func handleInviteLink_invalidURL_enqueuesShowInviteError() {
        #if DEBUG
        AppRouter.shared._testReset()
        AppRouter.shared.markReady(.contentView)
        #endif

        let bad = URL(string: "https://yala-app.pe/invite?broken")!
        AppBootstrapper.shared.handleInviteLink(bad)

        let peeked = AppRouter.shared.peekNext(for: .contentView)
        if case .showInviteError = peeked {
            #expect(true)
        } else {
            Issue.record("Expected .showInviteError to be enqueued, got: \(String(describing: peeked))")
        }
    }

    // MARK: - showGroupSyncError intent

    @Test func showGroupSyncError_routesToContentViewWithHighPriority() {
        let intent = RouterIntent.showGroupSyncError("boom")
        #expect(intent.handler == .contentView)
        #expect(intent.priority == .high)
        #expect(intent.id.contains("groupSyncError"))
    }

    @Test func showGroupSyncError_dedupesByMessage() {
        // Same message → same id (queue collapses to last-write-wins).
        let a = RouterIntent.showGroupSyncError("X")
        let b = RouterIntent.showGroupSyncError("X")
        #expect(a.id == b.id)
        // Different message → different id.
        let c = RouterIntent.showGroupSyncError("Y")
        #expect(a.id != c.id)
    }

    // MARK: - A12: Invite routing decision (pure function)
    //
    // `acceptShareFromURL` itself depends on CloudKit (`InviteLinkService.fetchShareMetadata`)
    // and isn't testable end-to-end. The pure decision function `inviteRouteDecision(...)`
    // captures the routing logic — these tests verify it stays symmetric with the
    // CKShare native path in YalaAppDelegate.

    @Test func inviteRouteDecision_newUser_acceptsAndShowsInviteOnboarding() {
        // !hasCompletedOnboarding && onboardingMode != .groupInvite → invite onboarding.
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .full
        )
        #expect(decision == .acceptAndShowInviteOnboarding)
    }

    @Test func inviteRouteDecision_onboardedActiveUser_showsReconnect() {
        // hasCompletedOnboarding=true → reconnect (regardless of segment, including .active).
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full
        )
        #expect(decision == .showReconnect)
    }

    @Test func inviteRouteDecision_dormantOnboardedUser_showsReconnect() {
        // Regression: dormant users (segment-based) used to have a special branch.
        // Now they go via the shared "onboarded → reconnect" path.
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full
        )
        #expect(decision == .showReconnect)
    }

    @Test func inviteRouteDecision_midGroupInviteOnboarding_showsReconnect() {
        // User mid-invite-onboarding receives another link → reconnect (the in-progress
        // onboarding view IS the confirmation; reconnect on top is acceptable for the rare
        // edge case of two simultaneous invitations).
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .groupInvite
        )
        #expect(decision == .showReconnect)
    }
}
