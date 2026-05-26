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
            isLocked: false,
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
            isSplashDismissed: false, isLocked: s.isLocked, isWipingData: s.isWipingData,
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

    @Test func wipingData_trumpsLock() {
        let s = ShellReadinessState(
            isSplashDismissed: true, isLocked: true, isWipingData: true,
            showOnboarding: false, showWelcomeFlow: false, showLanguageSelection: false,
            showWelcomeRestore: false, showInviteRecovery: false, showFreshStartWipeAlert: false,
            showRemoteWipeAlert: false, showICloudRestartAlert: false, hasActiveInboxAlert: false,
            showGroupInviteOnboarding: false, showGroupReconnect: false, showFullModeActivation: false
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "wipingData")
    }

    @Test func locked_blocksReady() {
        let s = ShellReadinessState(
            isSplashDismissed: true, isLocked: true, isWipingData: false,
            showOnboarding: false, showWelcomeFlow: false, showLanguageSelection: false,
            showWelcomeRestore: false, showInviteRecovery: false, showFreshStartWipeAlert: false,
            showRemoteWipeAlert: false, showICloudRestartAlert: false, hasActiveInboxAlert: false,
            showGroupInviteOnboarding: false, showGroupReconnect: false, showFullModeActivation: false
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "biometricLock")
    }

    @Test func remoteWipeAlert_blocks() {
        var s = clean()
        s = ShellReadinessState(
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: s.isSplashDismissed, isLocked: s.isLocked, isWipingData: s.isWipingData,
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
            isSplashDismissed: false, isLocked: true, isWipingData: true,
            showOnboarding: true, showWelcomeFlow: true, showLanguageSelection: true,
            showWelcomeRestore: true, showInviteRecovery: true, showFreshStartWipeAlert: true,
            showRemoteWipeAlert: true, showICloudRestartAlert: true, hasActiveInboxAlert: true,
            showGroupInviteOnboarding: true, showGroupReconnect: true, showFullModeActivation: true
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "wipingData")
    }

    @Test func lockBeatsAlerts_butNotWipe() {
        let s = ShellReadinessState(
            isSplashDismissed: true, isLocked: true, isWipingData: false,
            showOnboarding: false, showWelcomeFlow: false, showLanguageSelection: false,
            showWelcomeRestore: false, showInviteRecovery: false, showFreshStartWipeAlert: true,
            showRemoteWipeAlert: true, showICloudRestartAlert: true, hasActiveInboxAlert: true,
            showGroupInviteOnboarding: false, showGroupReconnect: false, showFullModeActivation: false
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "biometricLock")
    }
}
