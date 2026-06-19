//
//  PanelAvailabilityLogic.swift
//  Yala
//
//  Pure-logic: when is the .panel consumer safe to drain intents?
//
//  The panel hosts ~12 sheets (inbox, voice, image, upgrade, AI consent, chat,
//  newTransaction, etc.). Draining a new .presentX intent while another sheet is
//  open silently drops the presentation. This helper centralises the predicate
//  used by PanelShell's routerConsumer(readinessSource:) binding.
//

import Foundation

/// Snapshot of the panel's sheet visibility. Built by PanelShell from its
/// PanelSheetState before calling `PanelAvailabilityLogic.isAvailable`.
struct PanelAvailabilitySnapshot: Equatable {
    let selectedTabIsPanel: Bool
    let showInbox: Bool
    let showNewTransaction: Bool
    let showVoiceRecording: Bool
    let showImageSelection: Bool
    let showChatSheet: Bool
    let showYalaAIOnboarding: Bool
    let showUpgradeForVoice: Bool
    let showUpgradeForImage: Bool
    let showUpgradeForAccounts: Bool
    let showUpgradeForChat: Bool
    let showChatConsentAlert: Bool
    let showSectionsConfig: Bool
    let showCustomPeriodPicker: Bool
    let showBudgetFavoritesSettings: Bool
    let isPresentingSettings: Bool
    let accountFormSheetActive: Bool
}

enum PanelAvailabilityLogic {

    /// `true` → safe to drain panel intents (no sheet open, panel tab active).
    static func isAvailable(_ snapshot: PanelAvailabilitySnapshot) -> Bool {
        blocker(snapshot) == nil
    }

    /// Highest-priority blocker (for diagnostics).
    static func blocker(_ s: PanelAvailabilitySnapshot) -> String? {
        if !s.selectedTabIsPanel { return "tabNotPanel" }

        // Sheets that block subsequent panel sheet presentations.
        if s.showChatSheet { return "chatSheet" }
        if s.showInbox { return "inboxSheet" }
        if s.showNewTransaction { return "newTransaction" }
        if s.showVoiceRecording { return "voiceRecording" }
        if s.showImageSelection { return "imageSelection" }
        if s.showYalaAIOnboarding { return "yalaAIOnboarding" }
        if s.showUpgradeForVoice || s.showUpgradeForImage
           || s.showUpgradeForAccounts || s.showUpgradeForChat { return "upgradeSheet" }
        if s.showChatConsentAlert { return "chatConsentAlert" }
        if s.isPresentingSettings { return "settings" }
        if s.accountFormSheetActive { return "accountForm" }
        if s.showSectionsConfig { return "sectionsConfig" }
        if s.showCustomPeriodPicker { return "customPeriodPicker" }
        if s.showBudgetFavoritesSettings { return "budgetFavorites" }
        return nil
    }
}
