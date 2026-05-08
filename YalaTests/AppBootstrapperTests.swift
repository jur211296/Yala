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

    @Test func inviteRouteDecision_onboardedActiveUser_showsReconnectStandard() {
        // hasCompletedOnboarding=true sin member status → reconnect standard.
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full
        )
        #expect(decision == .showReconnect(mode: .standardReconnect))
    }

    @Test func inviteRouteDecision_midGroupInviteOnboarding_showsReconnectStandard() {
        // User mid-invite-onboarding receives another link → reconnect standard.
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .groupInvite
        )
        #expect(decision == .showReconnect(mode: .standardReconnect))
    }

    // MARK: - 5 escenarios extendidos: archived + member status

    @Test func inviteRouteDecision_archived_returnsArchived() {
        // isArchived gana sobre todo lo demás (incluso member status).
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full,
            isArchived: true,
            currentMemberStatus: .active
        )
        #expect(decision == .showReconnect(mode: .archived))
    }

    @Test func inviteRouteDecision_alreadyMember_returnsAlreadyMember() {
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full,
            isArchived: false,
            currentMemberStatus: .active
        )
        #expect(decision == .showReconnect(mode: .alreadyMember))
    }

    @Test func inviteRouteDecision_pendingApproval_returnsPendingDuplicate() {
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full,
            isArchived: false,
            currentMemberStatus: .pendingApproval
        )
        #expect(decision == .showReconnect(mode: .pendingDuplicate))
    }

    @Test func inviteRouteDecision_rejected_returnsRejectedRetry() {
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full,
            isArchived: false,
            currentMemberStatus: .rejected
        )
        #expect(decision == .showReconnect(mode: .rejectedRetry))
    }

    @Test func inviteRouteDecision_left_returnsLeftRetry() {
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full,
            isArchived: false,
            currentMemberStatus: .left
        )
        #expect(decision == .showReconnect(mode: .leftRetry))
    }

    @Test func inviteRouteDecision_removed_returnsRemovedRetry() {
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full,
            isArchived: false,
            currentMemberStatus: .removed
        )
        #expect(decision == .showReconnect(mode: .removedRetry))
    }

    @Test func inviteRouteDecision_archivedTrumpsRemoved() {
        // Even if I'm a removed member, archived takes priority.
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full,
            isArchived: true,
            currentMemberStatus: .removed
        )
        #expect(decision == .showReconnect(mode: .archived))
    }
}
