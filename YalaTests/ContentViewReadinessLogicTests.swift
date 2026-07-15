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

    /// Builder con defaults limpios — varía solo las flags relevantes por test.
    private func make(
        isSplashDismissed: Bool = true,
        isWipingData: Bool = false,
        showOnboarding: Bool = false,
        showWelcomeFlow: Bool = false,
        showLanguageSelection: Bool = false,
        showWelcomeRestore: Bool = false,
        showInviteRecovery: Bool = false,
        showWelcomeCloudSignIn: Bool = false,
        showSignOutRelaunch: Bool = false,
        secondaryEntryRelaunch: Bool = false,
        showFreshStartWipeAlert: Bool = false,
        showRemoteWipeAlert: Bool = false,
        showICloudRestartAlert: Bool = false,
        showRestoreOffer: Bool = false,
        hasActiveInviteError: Bool = false,
        hasActiveGroupSyncError: Bool = false,
        hasActiveInboxAlert: Bool = false,
        showGroupInviteOnboarding: Bool = false,
        showGroupReconnect: Bool = false,
        showGroupsConsent: Bool = false,
        showGroupsSignIn: Bool = false,
        showFullModeActivation: Bool = false,
        showProTrialOffer: Bool = false,
        showWhatsNew: Bool = false,
        showSyncSettingsSheet: Bool = false,
        isMainTabModalVisible: Bool = false
    ) -> ShellReadinessState {
        ShellReadinessState(
            isSplashDismissed: isSplashDismissed, isWipingData: isWipingData,
            showOnboarding: showOnboarding, showWelcomeFlow: showWelcomeFlow,
            showLanguageSelection: showLanguageSelection, showWelcomeRestore: showWelcomeRestore,
            showInviteRecovery: showInviteRecovery,
            showWelcomeCloudSignIn: showWelcomeCloudSignIn,
            showSignOutRelaunch: showSignOutRelaunch,
            secondaryEntryRelaunch: secondaryEntryRelaunch,
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showRemoteWipeAlert: showRemoteWipeAlert, showICloudRestartAlert: showICloudRestartAlert,
            showRestoreOffer: showRestoreOffer, hasActiveInviteError: hasActiveInviteError,
            hasActiveGroupSyncError: hasActiveGroupSyncError,
            hasActiveInboxAlert: hasActiveInboxAlert, showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupReconnect: showGroupReconnect,
            showGroupsConsent: showGroupsConsent, showGroupsSignIn: showGroupsSignIn,
            showFullModeActivation: showFullModeActivation,
            showProTrialOffer: showProTrialOffer, showWhatsNew: showWhatsNew,
            showSyncSettingsSheet: showSyncSettingsSheet,
            isMainTabModalVisible: isMainTabModalVisible
        )
    }

    @Test func allClean_isReady() {
        #expect(ContentViewReadinessLogic.isReady(state: make()))
        #expect(ContentViewReadinessLogic.blocker(state: make()) == nil)
    }

    // G4-invites (A2): los 2 sheets del flujo backend bloquean el drain mientras están arriba.

    @Test func groupsConsent_blocks() {
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showGroupsConsent: true)) == "groupsConsent")
        #expect(!ContentViewReadinessLogic.isReady(state: make(showGroupsConsent: true)))
    }

    @Test func groupsSignIn_blocks() {
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showGroupsSignIn: true)) == "groupsSignIn")
        #expect(!ContentViewReadinessLogic.isReady(state: make(showGroupsSignIn: true)))
    }

    @Test func groupsSheets_areNotTearableWelcomeChain() {
        // Un sheet del flujo backend arriba NO es cadena welcome — jamás se tumba por un
        // intent superseding (se retiene, molde welcomeCloudSignIn).
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showGroupsConsent: true)))
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showGroupsSignIn: true)))
    }

    // H4: los 2 blockers nuevos del cierre de sesión / sign-in de nube.

    @Test func welcomeCloudSignIn_blocks() {
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showWelcomeCloudSignIn: true)) == "welcomeCloudSignIn")
    }

    @Test func welcomeCloudSignIn_isNotTearableWelcomeChain() {
        // El adopt en vuelo NO se tumba por un intent superseding — se retiene.
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showWelcomeCloudSignIn: true)))
    }

    // M1: blocker de la VENTANA DE ENTRADA secundaria (descriptor armado, store del dueño montado).

    @Test func secondaryEntryRelaunch_blocks_tierTerminal() {
        #expect(ContentViewReadinessLogic.blocker(
            state: make(secondaryEntryRelaunch: true)) == "secondaryEntryRelaunch")
        // Cede solo ante wipingData y signOutRelaunch (mismo tier terminal, orden fijo).
        #expect(ContentViewReadinessLogic.blocker(
            state: make(isWipingData: true, secondaryEntryRelaunch: true)) == "wipingData")
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showSignOutRelaunch: true, secondaryEntryRelaunch: true)) == "signOutRelaunch")
        // Gana al splash y a toda la cadena welcome.
        #expect(ContentViewReadinessLogic.blocker(
            state: make(isSplashDismissed: false, secondaryEntryRelaunch: true)) == "secondaryEntryRelaunch")
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showWelcomeFlow: true, secondaryEntryRelaunch: true)) == "secondaryEntryRelaunch")
    }

    @Test func secondaryEntryRelaunch_isNotTearableWelcomeChain() {
        // La ventana armada JAMÁS se tumba por un intent superseding.
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(
            state: make(showWelcomeFlow: true, secondaryEntryRelaunch: true)))
    }

    @Test func signOutRelaunch_blocks_aboveEverythingButWipe() {
        #expect(ContentViewReadinessLogic.blocker(
            state: make(showSignOutRelaunch: true)) == "signOutRelaunch")
        // Solo wipingData lo supera en severidad.
        #expect(ContentViewReadinessLogic.blocker(
            state: make(isWipingData: true, showSignOutRelaunch: true)) == "wipingData")
        // Gana incluso al splash (terminal: nada presenta debajo).
        #expect(ContentViewReadinessLogic.blocker(
            state: make(isSplashDismissed: false, showSignOutRelaunch: true)) == "signOutRelaunch")
    }

    @Test func splashStillUp_notReady() {
        let s = make(isSplashDismissed: false)
        #expect(!ContentViewReadinessLogic.isReady(state: s))
        #expect(ContentViewReadinessLogic.blocker(state: s) == "splash")
    }

    @Test func remoteWipeAlert_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showRemoteWipeAlert: true)) == "remoteWipeAlert")
    }

    @Test func iCloudRestartAlert_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showICloudRestartAlert: true)) == "iCloudRestartAlert")
    }

    @Test func freshStartWipeAlert_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showFreshStartWipeAlert: true)) == "freshStartWipeAlert")
    }

    @Test func languageSelection_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showLanguageSelection: true)) == "languageSelection")
    }

    @Test func welcomeFlow_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showWelcomeFlow: true)) == "welcomeFlow")
    }

    @Test func welcomeRestore_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showWelcomeRestore: true)) == "welcomeRestore")
    }

    @Test func inviteRecovery_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showInviteRecovery: true)) == "inviteRecovery")
    }

    @Test func onboarding_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showOnboarding: true)) == "onboarding")
    }

    @Test func fullModeActivation_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showFullModeActivation: true)) == "fullModeActivation")
    }

    @Test func groupInviteOnboarding_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showGroupInviteOnboarding: true)) == "groupInviteOnboarding")
    }

    @Test func groupReconnect_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showGroupReconnect: true)) == "groupReconnect")
    }

    @Test func activeInboxAlert_blocks_rootCauseOfBug() {
        #expect(ContentViewReadinessLogic.blocker(state: make(hasActiveInboxAlert: true)) == "activeInboxAlert")
    }

    // MARK: - Blockers añadidos tras el bug del paywall (matriz completa)

    @Test func restoreOffer_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showRestoreOffer: true)) == "restoreOffer")
    }

    @Test func inviteError_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(hasActiveInviteError: true)) == "inviteError")
    }

    @Test func groupSyncError_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(hasActiveGroupSyncError: true)) == "groupSyncError")
    }

    @Test func proTrialOffer_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showProTrialOffer: true)) == "proTrialOffer")
    }

    @Test func whatsNew_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showWhatsNew: true)) == "whatsNew")
    }

    @Test func syncSettingsSheet_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(showSyncSettingsSheet: true)) == "syncSettingsSheet")
    }

    // Cross-node: sheet de MainTabView visible → el shell no presenta encima.
    @Test func mainTabModal_blocks() {
        #expect(ContentViewReadinessLogic.blocker(state: make(isMainTabModalVisible: true)) == "mainTabModal")
    }

    // Los dos alerts de grupos ya no pueden coexistir: el primero bloquea el
    // drain del segundo (serialización que resuelve el "alert tragado").
    @Test func inviteErrorPlusGroupSyncError_firstWins() {
        let s = make(hasActiveInviteError: true, hasActiveGroupSyncError: true)
        #expect(ContentViewReadinessLogic.blocker(state: s) == "inviteError")
        #expect(!ContentViewReadinessLogic.isReady(state: s))
    }

    // MARK: - Prioridad (orden documentado de severidad)

    @Test func wipingData_priorityWinsOverEverything() {
        let s = make(
            isSplashDismissed: false, isWipingData: true,
            showOnboarding: true, showWelcomeFlow: true, showLanguageSelection: true,
            showWelcomeRestore: true, showInviteRecovery: true, showFreshStartWipeAlert: true,
            showRemoteWipeAlert: true, showICloudRestartAlert: true,
            showRestoreOffer: true, hasActiveInviteError: true, hasActiveGroupSyncError: true,
            hasActiveInboxAlert: true, showGroupInviteOnboarding: true, showGroupReconnect: true,
            showFullModeActivation: true, showProTrialOffer: true, showWhatsNew: true,
            showSyncSettingsSheet: true
        )
        #expect(ContentViewReadinessLogic.blocker(state: s) == "wipingData")
    }

    @Test func remoteWipeAlert_winsOverInviteError() {
        let s = make(showRemoteWipeAlert: true, hasActiveInviteError: true)
        #expect(ContentViewReadinessLogic.blocker(state: s) == "remoteWipeAlert")
    }

    @Test func inviteError_winsOverProTrialOffer() {
        let s = make(hasActiveInviteError: true, showProTrialOffer: true)
        #expect(ContentViewReadinessLogic.blocker(state: s) == "inviteError")
    }

    // MARK: - isBlockedSolelyByWelcomeChain (B4-04)

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

    // Los blockers nuevos también sobreviven al clear de la cadena welcome →
    // un intent superseding NO tumba el welcome con un sheet/alert nuevo encima.
    @Test func welcomePlusProTrialOffer_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeFlow: true, showProTrialOffer: true)))
    }

    @Test func welcomePlusInviteError_notSolelyWelcome() {
        #expect(!ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: make(showWelcomeFlow: true, hasActiveInviteError: true)))
    }
}
