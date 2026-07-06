//
//  PresentationCascadeLogicTests.swift
//  YalaTests
//

import Testing
import Foundation
@testable import Yala

@Suite("PresentationCascadeLogic")
struct PresentationCascadeLogicTests {

    private func cleanReadiness() -> ShellReadinessState {
        ShellReadinessState(
            isSplashDismissed: true, isWipingData: false,
            showOnboarding: false, showWelcomeFlow: false, showLanguageSelection: false,
            showWelcomeRestore: false, showInviteRecovery: false, showFreshStartWipeAlert: false,
            showRemoteWipeAlert: false, showICloudRestartAlert: false, hasActiveInboxAlert: false,
            showGroupInviteOnboarding: false, showGroupReconnect: false, showFullModeActivation: false
        )
    }

    private func inputs(
        shell: ShellPresentation = .none,
        panel: PanelPresentation = .none,
        tab: AppTab = .panel,
        lastDismissal: Date? = nil
    ) -> CascadeInputs {
        CascadeInputs(
            currentShell: shell, currentPanel: panel, currentTab: tab,
            readiness: cleanReadiness(), lastPanelDismissalDate: lastDismissal,
            now: Date()
        )
    }

    // MARK: - Bug original: navigate(.inbox) cascades to combined decision

    @Test func navigateInbox_returnsCombined() {
        let decision = PresentationCascadeLogic.decide(
            intent: .navigate(.inbox), inputs: inputs(tab: .statistics))
        #expect(decision == .combined(tab: .panel, panel: .inboxSheet))
    }

    @Test func navigateInbox_whileOnPanel_stillCombined() {
        // Even on .panel tab, we go combined (atomic; coordinator can dedup).
        let decision = PresentationCascadeLogic.decide(
            intent: .navigate(.inbox), inputs: inputs(tab: .panel))
        #expect(decision == .combined(tab: .panel, panel: .inboxSheet))
    }

    // MARK: - Shell presentations

    @Test func showInboxAlert_returnsShellPresent() {
        let notif = PendingInboxNotification(automations: 1)
        let decision = PresentationCascadeLogic.decide(
            intent: .showInboxAlert(notif), inputs: inputs())
        #expect(decision == .present(.inboxAlert(notif)))
    }

    @Test func presentTrialExpired_returnsShellPresent() {
        let decision = PresentationCascadeLogic.decide(
            intent: .presentTrialExpired, inputs: inputs())
        #expect(decision == .present(.trialExpired))
    }

    @Test func iCloudMismatch_returnsShellPresent() {
        let decision = PresentationCascadeLogic.decide(
            intent: .iCloudMismatch, inputs: inputs())
        #expect(decision == .present(.iCloudMismatch))
    }

    @Test func remoteWipe_returnsShellPresent() {
        let decision = PresentationCascadeLogic.decide(
            intent: .remoteWipe(skipOnboarding: true), inputs: inputs())
        #expect(decision == .present(.remoteWipe(skipOnboarding: true)))
    }

    // MARK: - Panel presentations

    @Test func presentInboxSheet_onPanelTab_returnsPanel() {
        let decision = PresentationCascadeLogic.decide(
            intent: .presentInboxSheet, inputs: inputs(tab: .panel))
        #expect(decision == .panel(.inboxSheet))
    }

    @Test func presentInboxSheet_offPanel_returnsCombined() {
        let decision = PresentationCascadeLogic.decide(
            intent: .presentInboxSheet, inputs: inputs(tab: .statistics))
        #expect(decision == .combined(tab: .panel, panel: .inboxSheet))
    }

    @Test func presentVoiceEntry_whenPanelBusy_returnsNoop() {
        let decision = PresentationCascadeLogic.decide(
            intent: .presentVoiceEntry,
            inputs: inputs(panel: .inboxSheet, tab: .panel))
        #expect(decision == .noop)
    }

    @Test func samePanelPresentation_returnsNoop() {
        let decision = PresentationCascadeLogic.decide(
            intent: .presentInboxSheet,
            inputs: inputs(panel: .inboxSheet, tab: .panel))
        #expect(decision == .noop)
    }

    @Test func panelPresentation_withinDismissCooldown_returnsNoop() {
        // User dismissed a panel sheet just now — don't re-present.
        let recentDismiss = Date(timeIntervalSinceNow: -0.1) // 100ms ago
        let decision = PresentationCascadeLogic.decide(
            intent: .presentInboxSheet,
            inputs: inputs(tab: .panel, lastDismissal: recentDismiss))
        #expect(decision == .noop)
    }

    @Test func panelPresentation_afterDismissCooldown_returnsPanel() {
        let oldDismiss = Date(timeIntervalSinceNow: -1.0) // 1s ago (>cooldown 500ms)
        let decision = PresentationCascadeLogic.decide(
            intent: .presentInboxSheet,
            inputs: inputs(tab: .panel, lastDismissal: oldDismiss))
        #expect(decision == .panel(.inboxSheet))
    }

    // MARK: - Tab navigation

    @Test func navigateStatistics_returnsSwitchTab() {
        let decision = PresentationCascadeLogic.decide(
            intent: .navigate(.statistics), inputs: inputs(tab: .panel))
        #expect(decision == .switchTab(.statistics))
    }

    @Test func navigateBudgets_mapsToPlanning() {
        let decision = PresentationCascadeLogic.decide(
            intent: .navigate(.budgets), inputs: inputs(tab: .panel))
        #expect(decision == .switchTab(.planning))
    }

    @Test func navigateRecordsStandalone_isolatedTab() {
        let decision = PresentationCascadeLogic.decide(
            intent: .navigate(.recordsStandalone), inputs: inputs(tab: .panel))
        #expect(decision == .switchTab(.records))
    }

    @Test func navigateGroups_returnsGroupsTab() {
        let decision = PresentationCascadeLogic.decide(
            intent: .navigate(.groups), inputs: inputs(tab: .panel))
        #expect(decision == .switchTab(.groups))
    }

    // MARK: - Out-of-coordinator scope

    @Test func autoOpenBudgetEditor_returnsNoop() {
        let decision = PresentationCascadeLogic.decide(
            intent: .autoOpenBudgetEditor, inputs: inputs())
        #expect(decision == .noop)
    }

    @Test func requestAppStoreReview_returnsNoop() {
        let decision = PresentationCascadeLogic.decide(
            intent: .requestAppStoreReview, inputs: inputs())
        #expect(decision == .noop)
    }

    // MARK: - Readiness gate

    @Test func splashStillUp_returnsNoop() {
        let r = ShellReadinessState(
            isSplashDismissed: false, isWipingData: false,
            showOnboarding: false, showWelcomeFlow: false, showLanguageSelection: false,
            showWelcomeRestore: false, showInviteRecovery: false, showFreshStartWipeAlert: false,
            showRemoteWipeAlert: false, showICloudRestartAlert: false, hasActiveInboxAlert: false,
            showGroupInviteOnboarding: false, showGroupReconnect: false, showFullModeActivation: false
        )
        let inp = CascadeInputs(
            currentShell: .none, currentPanel: .none, currentTab: .panel,
            readiness: r, lastPanelDismissalDate: nil, now: Date()
        )
        #expect(PresentationCascadeLogic.decide(intent: .showInboxAlert(.init(automations: 1)), inputs: inp) == .noop)
    }

    @Test func activeInboxAlert_blocks_evenForSheetIntent() {
        let r = ShellReadinessState(
            isSplashDismissed: true, isWipingData: false,
            showOnboarding: false, showWelcomeFlow: false, showLanguageSelection: false,
            showWelcomeRestore: false, showInviteRecovery: false, showFreshStartWipeAlert: false,
            showRemoteWipeAlert: false, showICloudRestartAlert: false, hasActiveInboxAlert: true,
            showGroupInviteOnboarding: false, showGroupReconnect: false, showFullModeActivation: false
        )
        let inp = CascadeInputs(
            currentShell: .inboxAlert(.init(automations: 1)), currentPanel: .none, currentTab: .panel,
            readiness: r, lastPanelDismissalDate: nil, now: Date()
        )
        // Bug del owner: el sheet del Inbox NO se debe abrir mientras el alert está visible.
        #expect(PresentationCascadeLogic.decide(intent: .presentInboxSheet, inputs: inp) == .noop)
    }

    @Test func cascadeInputs_compose() {
        // Sanity: building inputs from defaults works without crash.
        let inp = inputs()
        #expect(inp.currentShell == .none)
        #expect(inp.currentPanel == .none)
        #expect(inp.currentTab == .panel)
    }
}
