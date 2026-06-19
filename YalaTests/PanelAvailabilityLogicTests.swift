//
//  PanelAvailabilityLogicTests.swift
//  YalaTests
//

import Testing
@testable import Yala

@Suite("PanelAvailabilityLogic")
struct PanelAvailabilityLogicTests {

    private func clean(selectedTabIsPanel: Bool = true) -> PanelAvailabilitySnapshot {
        PanelAvailabilitySnapshot(
            selectedTabIsPanel: selectedTabIsPanel,
            showInbox: false, showNewTransaction: false,
            showVoiceRecording: false, showImageSelection: false,
            showChatSheet: false, showYalaAIOnboarding: false,
            showUpgradeForVoice: false, showUpgradeForImage: false,
            showUpgradeForAccounts: false, showUpgradeForChat: false,
            showChatConsentAlert: false, showSectionsConfig: false,
            showCustomPeriodPicker: false, showBudgetFavoritesSettings: false,
            isPresentingSettings: false, accountFormSheetActive: false
        )
    }

    @Test func allClean_isAvailable() {
        #expect(PanelAvailabilityLogic.isAvailable(clean()))
        #expect(PanelAvailabilityLogic.blocker(clean()) == nil)
    }

    @Test func tabNotPanel_blocks() {
        let s = clean(selectedTabIsPanel: false)
        #expect(PanelAvailabilityLogic.blocker(s) == "tabNotPanel")
    }

    @Test func chatSheet_blocks() {
        var s = clean()
        s = PanelAvailabilitySnapshot(
            selectedTabIsPanel: s.selectedTabIsPanel,
            showInbox: s.showInbox, showNewTransaction: s.showNewTransaction,
            showVoiceRecording: s.showVoiceRecording, showImageSelection: s.showImageSelection,
            showChatSheet: true, showYalaAIOnboarding: s.showYalaAIOnboarding,
            showUpgradeForVoice: s.showUpgradeForVoice, showUpgradeForImage: s.showUpgradeForImage,
            showUpgradeForAccounts: s.showUpgradeForAccounts, showUpgradeForChat: s.showUpgradeForChat,
            showChatConsentAlert: s.showChatConsentAlert, showSectionsConfig: s.showSectionsConfig,
            showCustomPeriodPicker: s.showCustomPeriodPicker, showBudgetFavoritesSettings: s.showBudgetFavoritesSettings,
            isPresentingSettings: s.isPresentingSettings, accountFormSheetActive: s.accountFormSheetActive
        )
        #expect(PanelAvailabilityLogic.blocker(s) == "chatSheet")
    }

    @Test func inboxSheet_blocks() {
        let s = PanelAvailabilitySnapshot(
            selectedTabIsPanel: true, showInbox: true, showNewTransaction: false,
            showVoiceRecording: false, showImageSelection: false, showChatSheet: false,
            showYalaAIOnboarding: false, showUpgradeForVoice: false, showUpgradeForImage: false,
            showUpgradeForAccounts: false, showUpgradeForChat: false, showChatConsentAlert: false,
            showSectionsConfig: false, showCustomPeriodPicker: false, showBudgetFavoritesSettings: false,
            isPresentingSettings: false, accountFormSheetActive: false
        )
        #expect(PanelAvailabilityLogic.blocker(s) == "inboxSheet")
    }

    @Test func upgradeSheet_anyVariantBlocks() {
        let s = PanelAvailabilitySnapshot(
            selectedTabIsPanel: true, showInbox: false, showNewTransaction: false,
            showVoiceRecording: false, showImageSelection: false, showChatSheet: false,
            showYalaAIOnboarding: false, showUpgradeForVoice: true, showUpgradeForImage: false,
            showUpgradeForAccounts: false, showUpgradeForChat: false, showChatConsentAlert: false,
            showSectionsConfig: false, showCustomPeriodPicker: false, showBudgetFavoritesSettings: false,
            isPresentingSettings: false, accountFormSheetActive: false
        )
        #expect(PanelAvailabilityLogic.blocker(s) == "upgradeSheet")
    }

    @Test func chatBeatsInbox_inPriority() {
        let s = PanelAvailabilitySnapshot(
            selectedTabIsPanel: true, showInbox: true, showNewTransaction: false,
            showVoiceRecording: false, showImageSelection: false, showChatSheet: true,
            showYalaAIOnboarding: false, showUpgradeForVoice: false, showUpgradeForImage: false,
            showUpgradeForAccounts: false, showUpgradeForChat: false, showChatConsentAlert: false,
            showSectionsConfig: false, showCustomPeriodPicker: false, showBudgetFavoritesSettings: false,
            isPresentingSettings: false, accountFormSheetActive: false
        )
        #expect(PanelAvailabilityLogic.blocker(s) == "chatSheet")
    }
}
