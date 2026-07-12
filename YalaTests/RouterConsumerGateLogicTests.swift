//
//  RouterConsumerGateLogicTests.swift
//  YalaTests
//
//  Guard de drain de .mainTab/.panel (Clase D): un intent que presenta un
//  sheet propio se retiene mientras un nodo superior tape — nunca se consume
//  tapado. Pure-logic, sin contexto ni singletons.
//

import Testing
@testable import Yala

@Suite("RouterConsumerGateLogic")
struct RouterConsumerGateLogicTests {

    // MARK: - presentsModal (exhaustivo sobre los 5 intents de .mainTab)

    @Test func presentsModal_modalIntents() {
        #expect(RouterConsumerGateLogic.presentsModal(.presentDowngradeResolution))
        #expect(RouterConsumerGateLogic.presentsModal(.presentTrialExpired))
        #expect(RouterConsumerGateLogic.presentsModal(.presentMilestoneUpgrade(10)))
    }

    @Test func presentsModal_nonModalIntents() {
        // navigate = tab-switch (válido bajo cualquier cover, comportamiento de
        // siempre); requestAppStoreReview = overlay de sistema sin anchor.
        #expect(!RouterConsumerGateLogic.presentsModal(.navigate(.inbox)))
        #expect(!RouterConsumerGateLogic.presentsModal(.navigate(.statistics)))
        #expect(!RouterConsumerGateLogic.presentsModal(.requestAppStoreReview))
    }

    // MARK: - mainTabDecision

    @Test func mainTab_nonModal_drainsUnderAnyBlocker() {
        #expect(RouterConsumerGateLogic.mainTabDecision(
            intent: .navigate(.inbox), shellBlocker: "proTrialOffer", ownModalVisible: true
        ) == .drain)
        #expect(RouterConsumerGateLogic.mainTabDecision(
            intent: .requestAppStoreReview, shellBlocker: "whatsNew", ownModalVisible: false
        ) == .drain)
    }

    @Test func mainTab_modal_holdsWhileShellBlocked() {
        #expect(RouterConsumerGateLogic.mainTabDecision(
            intent: .presentTrialExpired, shellBlocker: "proTrialOffer", ownModalVisible: false
        ) == .hold)
    }

    @Test func mainTab_modal_holdsWhileOwnModalVisible() {
        #expect(RouterConsumerGateLogic.mainTabDecision(
            intent: .presentMilestoneUpgrade(50), shellBlocker: nil, ownModalVisible: true
        ) == .hold)
    }

    @Test func mainTab_modal_drainsWhenClear() {
        #expect(RouterConsumerGateLogic.mainTabDecision(
            intent: .presentDowngradeResolution, shellBlocker: nil, ownModalVisible: false
        ) == .drain)
    }

    // MARK: - panelCanDrain (tabla por dimensión)

    private func canDrain(
        tab: AppTab = .panel,
        chat: Bool = false,
        shell: String? = nil,
        mainTabModal: Bool = false,
        panelModal: Bool = false
    ) -> Bool {
        RouterConsumerGateLogic.panelCanDrain(
            selectedTab: tab,
            chatSheetOpen: chat,
            shellBlocker: shell,
            mainTabModalVisible: mainTabModal,
            panelModalVisible: panelModal
        )
    }

    @Test func panel_allClear_drains() {
        #expect(canDrain())
    }

    @Test func panel_wrongTab_holds() {
        #expect(!canDrain(tab: .statistics))
    }

    @Test func panel_chatSheetOpen_holds() {
        #expect(!canDrain(chat: true))
    }

    @Test func panel_shellBlocked_holds() {
        // El caso exacto del bug TestFlight: paywall del shell arriba →
        // .presentInboxSheet debe esperar, no consumirse tapado.
        #expect(!canDrain(shell: "proTrialOffer"))
    }

    @Test func panel_mainTabModalVisible_holds() {
        #expect(!canDrain(mainTabModal: true))
    }

    @Test func panel_ownModalVisible_holds() {
        #expect(!canDrain(panelModal: true))
    }
}

// MARK: - PanelSheetState.hasActivePresentation (contrato contra olvidos)

@Suite("PanelSheetState.hasActivePresentation")
struct PanelSheetStateActivePresentationTests {

    @Test func defaultState_noActivePresentation() {
        #expect(!PanelSheetState().hasActivePresentation)
    }

    // Cada flag de PRESENTACIÓN en solitario ⇒ true.
    @Test func eachPresentationFlag_activates() {
        var s = PanelSheetState(); s.isPresentingSettings = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.accountFormSheet = AccountFormSheet(account: nil)
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.sectionPrefsPresentation = .accounts
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showSectionsConfig = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showNewTransaction = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showVoiceRecording = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showImageSelection = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showCustomPeriodPicker = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showBudgetFavoritesSettings = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showInbox = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showUpgradeForVoice = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showUpgradeForImage = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showUpgradeForAccounts = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showSubscriptionFromBanner = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showChatSheet = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showUpgradeForChat = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showChatConsentAlert = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showYalaAIOnboarding = true
        #expect(s.hasActivePresentation)
        s = PanelSheetState(); s.showAIConsentAlert = true
        #expect(s.hasActivePresentation)
    }

    // Flags de COORDINACIÓN post-dismiss / setup trial ⇒ false (no presentan).
    @Test func coordinationFlags_doNotActivate() {
        var s = PanelSheetState()
        s.navigateToInboxAfterVoice = true
        s.switchToImageAfterVoice = true
        s.navigateToInboxAfterImage = true
        s.pendingOpenChatAfterOnboarding = true
        s.isVoiceSetupTrial = true
        s.isImageSetupTrial = true
        #expect(!s.hasActivePresentation)
    }
}
