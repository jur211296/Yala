//
//  AppBootstrapperTests.swift
//  YalaTests
//
//  Unit tests for AppBootstrapper retry logic and invite link handling.
//

import CloudKit
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

    // MARK: - FU-02: hiddenForAll overrides everything (soft-delete owner)

    @Test func inviteRouteDecision_hiddenForAllOverridesArchived() {
        // FU-02: isHiddenForAll gana incluso sobre isArchived (orden de evaluación).
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full,
            isHiddenForAll: true,
            isArchived: true
        )
        #expect(decision == .showReconnect(mode: .deletedForAll))
    }

    @Test func inviteRouteDecision_hiddenForAllOverridesActiveMember() {
        // FU-02: isHiddenForAll gana sobre member status `.active`.
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full,
            isHiddenForAll: true,
            currentMemberStatus: .active
        )
        #expect(decision == .showReconnect(mode: .deletedForAll))
    }

    @Test func inviteRouteDecision_hiddenForAllOverridesPendingApproval() {
        // FU-02: isHiddenForAll gana sobre member status `.pendingApproval`.
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full,
            isHiddenForAll: true,
            currentMemberStatus: .pendingApproval
        )
        #expect(decision == .showReconnect(mode: .deletedForAll))
    }

    @Test func inviteRouteDecision_hiddenForAllOverridesFreshUser() {
        // FU-02: isHiddenForAll gana incluso sobre el path acceptAndShowInviteOnboarding
        // (fresh-install retap link de grupo soft-deleted → NO entra al onboarding).
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .full,
            isHiddenForAll: true
        )
        #expect(decision == .showReconnect(mode: .deletedForAll))
    }

    // MARK: - B-18: fresh user prioriza invite onboarding sobre memberStatus

    @Test func inviteRouteDecision_freshUserWithPendingApproval_showsInviteOnboarding() {
        // B-18: fresh-install que aceptó share y quedó pending NO debe ir al Reconnect
        // (CTA "Volver al inicio" → Chooser dejaría al user fuera de la app esperando).
        // Debe entrar al invite onboarding silencioso → detectFinalStep → step 3.
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .full,
            currentMemberStatus: .pendingApproval
        )
        #expect(decision == .acceptAndShowInviteOnboarding)
    }

    @Test func inviteRouteDecision_freshUserWithActiveMember_showsInviteOnboarding() {
        // B-18 race feliz: admin aprobó en <10s antes que el routing decida.
        // Igual entra al invite onboarding (step 2 "¡Listo!" via detectFinalStep).
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .full,
            currentMemberStatus: .active
        )
        #expect(decision == .acceptAndShowInviteOnboarding)
    }

    @Test func inviteRouteDecision_freshUserWithRejected_showsInviteOnboarding() {
        // B-18 edge: user abandonó mid-flow, admin rechazó, user retapea.
        // performSilentSetup invoca ensureCurrentUserMemberExists(reactivateInactive: true)
        // → re-pone pending. Comportamiento defensivo consistente con el flow retry.
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .full,
            currentMemberStatus: .rejected
        )
        #expect(decision == .acceptAndShowInviteOnboarding)
    }

    @Test func inviteRouteDecision_freshUserMidGroupInvite_keepsReconnectStandard() {
        // B-18 regression guard: si user YA está mid-invite-onboarding (mode=.groupInvite)
        // y tapea otro link, NO re-entra al invite onboarding (evita loop / reset state).
        // Cae al default standardReconnect (que el ContentView resuelve).
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .groupInvite,
            currentMemberStatus: .pendingApproval
        )
        #expect(decision == .showReconnect(mode: .pendingDuplicate))
    }

    // MARK: - Parte F: returning user con datos → oferta cargar antes de unirse

    @Test func inviteRouteDecision_freshUserWithReturningSignal_offersRestore() {
        // Returning user con datos en iCloud (sin wipe) que abre un link → ofrecer
        // cargar antes de unirse (en vez del invite onboarding directo).
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .full,
            hasReturningSignal: true
        )
        #expect(decision == .offerRestoreThenInvite)
    }

    @Test func inviteRouteDecision_freshUserNoReturningSignal_acceptsAndShowsInviteOnboarding() {
        // Sin señal de returning (fresh real o post-wipe) → invite onboarding directo.
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .full,
            hasReturningSignal: false
        )
        #expect(decision == .acceptAndShowInviteOnboarding)
    }

    @Test func inviteRouteDecision_returningSignalIgnoredWhenOnboarded() {
        // hasCompletedOnboarding=true → la oferta no aplica; reconnect estándar
        // (la señal solo importa pre-onboarding).
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: true,
            onboardingMode: .full,
            hasReturningSignal: true
        )
        #expect(decision == .showReconnect(mode: .standardReconnect))
    }

    @Test func inviteRouteDecision_returningSignalIgnoredMidGroupInvite() {
        // mode=.groupInvite (mid invite onboarding) → no ofrecer restore aunque haya señal.
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .groupInvite,
            hasReturningSignal: true
        )
        #expect(decision == .showReconnect(mode: .standardReconnect))
    }

    @Test func inviteRouteDecision_hiddenForAllOverridesReturningSignal() {
        // isHiddenForAll gana sobre la oferta de restore (orden de evaluación).
        let decision = AppBootstrapper.inviteRouteDecision(
            hasCompletedOnboarding: false,
            onboardingMode: .full,
            isHiddenForAll: true,
            hasReturningSignal: true
        )
        #expect(decision == .showReconnect(mode: .deletedForAll))
    }

    // MARK: - shouldReEmitInvite (pure guard del re-emit de invites pendientes)

    @Test func shouldReEmitInvite_allConditionsMet_returnsTrue() {
        #expect(AppBootstrapper.shouldReEmitInvite(
            storeHasEntry: true, isProcessing: false,
            queueHasInviteIntent: false, isPresenting: false
        ))
    }

    @Test func shouldReEmitInvite_noEntry_returnsFalse() {
        #expect(!AppBootstrapper.shouldReEmitInvite(
            storeHasEntry: false, isProcessing: false,
            queueHasInviteIntent: false, isPresenting: false
        ))
    }

    @Test func shouldReEmitInvite_alreadyProcessing_returnsFalse() {
        #expect(!AppBootstrapper.shouldReEmitInvite(
            storeHasEntry: true, isProcessing: true,
            queueHasInviteIntent: false, isPresenting: false
        ))
    }

    @Test func shouldReEmitInvite_intentAlreadyQueued_returnsFalse() {
        #expect(!AppBootstrapper.shouldReEmitInvite(
            storeHasEntry: true, isProcessing: false,
            queueHasInviteIntent: true, isPresenting: false
        ))
    }

    @Test func shouldReEmitInvite_coverPresenting_returnsFalse() {
        // Cover ya abierto → NO re-emitir (evita re-presentación espuria que el
        // clear-on-complete causaría con el cover visible).
        #expect(!AppBootstrapper.shouldReEmitInvite(
            storeHasEntry: true, isProcessing: false,
            queueHasInviteIntent: false, isPresenting: true
        ))
    }

    // MARK: - isRecoverableInviteFetchError (red transitoria vs permanente)

    @Test func isRecoverableInviteFetchError_networkErrors_returnTrue() {
        #expect(AppBootstrapper.isRecoverableInviteFetchError(CKError(.networkUnavailable)))
        #expect(AppBootstrapper.isRecoverableInviteFetchError(CKError(.networkFailure)))
        #expect(AppBootstrapper.isRecoverableInviteFetchError(CKError(.serviceUnavailable)))
        #expect(AppBootstrapper.isRecoverableInviteFetchError(CKError(.requestRateLimited)))
        #expect(AppBootstrapper.isRecoverableInviteFetchError(CKError(.zoneBusy)))
    }

    @Test func isRecoverableInviteFetchError_permanentErrors_returnFalse() {
        #expect(!AppBootstrapper.isRecoverableInviteFetchError(CKError(.unknownItem)))
        #expect(!AppBootstrapper.isRecoverableInviteFetchError(CKError(.permissionFailure)))
        #expect(!AppBootstrapper.isRecoverableInviteFetchError(CKError(.invalidArguments)))
    }

    @Test func isRecoverableInviteFetchError_nonCKError_returnsFalse() {
        struct Boom: Error {}
        #expect(!AppBootstrapper.isRecoverableInviteFetchError(Boom()))
    }
}
