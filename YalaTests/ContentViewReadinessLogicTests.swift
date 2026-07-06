//
//  ContentViewReadinessLogicTests.swift
//  YalaTests
//
//  Pure-logic, no context, no singletons. Safe under parallel test execution.
//

import Testing
@testable import Yala

@Suite("ContentViewReadinessLogic")
struct ContentViewReadinessLogicTests {

    private func clean() -> ShellReadinessState {
        ShellReadinessState(
            isSplashDismissed: true,
            isWipingData: false,
            showOnboarding: false,
            showWelcomeFlow: false,
            showLanguageSelection: false,
            showWelcomeRestore: false,
            showInviteRecovery: false,
            showFreshStartWipeAlert: false,
            showRemoteWipeAlert: false,
            showICloudRestartAlert: false,
            hasActiveInboxAlert: false,
            showGroupInviteOnboarding: false,
            showGroupReconnect: false,
            showFullModeActivation: false
        )
    }

    @Test func allClean_isReady() {
        #expect(ContentViewReadinessLogic.isReady(state: clean()))
        #expect(ContentViewReadinessLogic.blocker(state: clean()) == nil)
    }

    @Test func splashStillUp_notReady() {
        var s = clean(); s = ShellReadinessState(
            isSplashDismissed: false, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: s.showFullModeActivation
        )
        #expect(!ContentViewReadinessLogic.isReady(state: s))
        #expect(ContentViewReadinessLogic.blocker(state: s) == "splash")
    }

    @Test func remoteWipeAlert_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: true, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: s.showFullModeActivation
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "remoteWipeAlert")
    }

    @Test func iCloudRestartAlert_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: true,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: s.showFullModeActivation
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "iCloudRestartAlert")
    }

    @Test func freshStartWipeAlert_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: true,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: s.showFullModeActivation
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "freshStartWipeAlert")
    }

    @Test func languageSelection_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: true, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: s.showFullModeActivation
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "languageSelection")
    }

    @Test func welcomeFlow_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: true,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: s.showFullModeActivation
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "welcomeFlow")
    }

    @Test func welcomeRestore_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: true,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: s.showFullModeActivation
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "welcomeRestore")
    }

    @Test func inviteRecovery_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: true, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: s.showFullModeActivation
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "inviteRecovery")
    }

    @Test func onboarding_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: true, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: s.showFullModeActivation
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "onboarding")
    }

    @Test func fullModeActivation_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: true
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "fullModeActivation")
    }

    @Test func groupInviteOnboarding_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: true,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: s.showFullModeActivation
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "groupInviteOnboarding")
    }

    @Test func groupReconnect_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: s.hasActiveInboxAlert, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: true, showFullModeActivation: s.showFullModeActivation
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "groupReconnect")
    }

    @Test func activeInboxAlert_blocks_rootCauseOfBug() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isWipingData: s.isWipingData,
            showOnboarding: s.showOnboarding, showWelcomeFlow: s.showWelcomeFlow,
            showLanguageSelection: s.showLanguageSelection, showWelcomeRestore: s.showWelcomeRestore,
            showInviteRecovery: s.showInviteRecovery, showFreshStartWipeAlert: s.showFreshStartWipeAlert,
            showRemoteWipeAlert: s.showRemoteWipeAlert, showICloudRestartAlert: s.showICloudRestartAlert,
            hasActiveInboxAlert: true, showGroupInviteOnboarding: s.showGroupInviteOnboarding,
            showGroupReconnect: s.showGroupReconnect, showFullModeActivation: s.showFullModeActivation
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "activeInboxAlert")
    }

    @Test func wipingData_priorityWinsOverEverything() {
        let s = ShellReadinessState(
            isSplashDismissed: false, isWipingData: true,
            showOnboarding: true, showWelcomeFlow: true, showLanguageSelection: true,
            showWelcomeRestore: true, showInviteRecovery: true, showFreshStartWipeAlert: true,
            showRemoteWipeAlert: true, showICloudRestartAlert: true, hasActiveInboxAlert: true,
            showGroupInviteOnboarding: true, showGroupReconnect: true, showFullModeActivation: true
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "wipingData")
    }

    // MARK: - isBlockedSolelyByWelcomeChain (B4-04)

    /// Builder con defaults limpios — varía solo las flags relevantes por test.
    private func make(
        isSplashDismissed: Bool = true,
        isWipingData: Bool = false,
        showOnboarding: Bool = false,
        showWelcomeFlow: Bool = false,
        showLanguageSelection: Bool = false,
        showWelcomeRestore: Bool = false,
        showInviteRecovery: Bool = false,
        showFreshStartWipeAlert: Bool = false,
        showRemoteWipeAlert: Bool = false,
        showICloudRestartAlert: Bool = false,
        hasActiveInboxAlert: Bool = false,
        showGroupInviteOnboarding: Bool = false,
        showGroupReconnect: Bool = false,
        showFullModeActivation: Bool = false
    ) -> ShellReadinessState {
        ShellReadinessState(
            isSplashDismissed: isSplashDismissed, isWipingData: isWipingData,
            showOnboarding: showOnboarding, showWelcomeFlow: showWelcomeFlow,
            showLanguageSelection: showLanguageSelection, showWelcomeRestore: showWelcomeRestore,
            showInviteRecovery: showInviteRecovery, showFreshStartWipeAlert: showFreshStartWipeAlert,
            showRemoteWipeAlert: showRemoteWipeAlert, showICloudRestartAlert: showICloudRestartAlert,
            hasActiveInboxAlert: hasActiveInboxAlert, showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupReconnect: showGroupReconnect, showFullModeActivation: showFullModeActivation
        )
    }

    // Cada cover de la cadena welcome, en solitario → SÍ es teardown-elegible.
    @Test func welcomeFlowOnly_isSolelyWelcome() {
        #expect(ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeFlow: true)))
    }

    @Test func welcomeRestoreOnly_isSolelyWelcome() {
        #expect(ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeRestore: true)))
    }

    @Test func inviteRecoveryOnly_isSolelyWelcome() {
        #expect(ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showInviteRecovery: true)))
    }

    @Test func languageSelectionOnly_isSolelyWelcome() {
        #expect(ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showLanguageSelection: true)))
    }

    // Estado limpio → no hay blocker → nada que cerrar.
    @Test func cleanState_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make()))
    }

    // onboarding NO es de la cadena welcome (excluido a propósito).
    @Test func onboardingOnly_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showOnboarding: true)))
    }

    // Blockers de mayor prioridad que sobreviven al clear → NO teardown
    // (preserva la protección anti-"inbox alert tardío" y los gates de sistema).
    @Test func welcomePlusSplash_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(isSplashDismissed: false, showWelcomeFlow: true)))
    }

    @Test func welcomePlusFreshStartAlert_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeFlow: true, showFreshStartWipeAlert: true)))
    }

    // welcomeFlow es el blocker de mayor prioridad, pero limpiar la cadena deja
    // el inbox alert vivo → NO teardown (el caso que motivó el readiness gate).
    @Test func welcomePlusActiveInboxAlert_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeFlow: true, hasActiveInboxAlert: true)))
    }

    // onboarding sobrevive al clear de la cadena welcome → NO teardown.
    @Test func welcomePlusOnboarding_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showOnboarding: true, showWelcomeFlow: true)))
    }
}
