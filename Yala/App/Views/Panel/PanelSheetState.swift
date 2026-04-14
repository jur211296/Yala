//
//  PanelSheetState.swift
//  Yala
//
//  Sheet presentation state extracted from PanelView.
//  Owned by PanelShell as @State — keeps ObservationCenter out of the sheet lifecycle.
//

import SwiftData
import SwiftUI
import UIKit

/// Wrapper to enable `.sheet(item:)` pattern for both new and edit account forms.
struct AccountFormSheet: Identifiable {
    let id = UUID()
    let account: Account?
}

/// Bundles all sheet-related state for PanelView.
/// Owned as `@State` in PanelShell — SwiftUI tracks mutations internally,
/// NOT through ObservationCenter, preventing the infinite render loop.
struct PanelSheetState {
    // Sheet presentations
    var isPresentingSettings = false
    var accountFormSheet: AccountFormSheet? = nil
    var showWidgetPreferences = false
    var showNewTransaction = false
    var showVoiceRecording = false
    var showImageSelection = false
    var showCustomPeriodPicker = false
    var showBudgetFavoritesSettings = false
    var showInbox = false
    var showUpgradeForVoice = false
    var showUpgradeForImage = false
    var showUpgradeForAccounts = false
    var showSubscriptionFromBanner = false
    var subscriptionBannerSource = "direct"

    // Chat assistant
    var showChatSheet = false
    var showUpgradeForChat = false
    var showChatConsentAlert = false

    // AI consent
    var showAIConsentAlert = false
    var pendingAIInput: PendingAIInput = .voice

    // Navigation flags (post-dismiss)
    var navigateToInboxAfterVoice = false
    var switchToImageAfterVoice = false
    var navigateToInboxAfterImage = false

    // Setup trial
    var isVoiceSetupTrial = false
    var isImageSetupTrial = false
    var setupTrialExampleImages: [UIImage]? = nil
    var practiceCleanupItem: PracticeCleanupItem? = nil
}
