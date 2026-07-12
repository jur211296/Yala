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
    /// Which section's preferences sheet is currently presented (P20-03).
    /// `nil` means no per-section prefs sheet is open. Driven via `.sheet(item:)`
    /// because `PanelSectionKind` conforms to `Identifiable`.
    var sectionPrefsPresentation: PanelSectionKind? = nil
    var showSectionsConfig = false
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
    var showYalaAIOnboarding = false
    /// Encadenamiento de sheets: cuando el onboarding completa con CTA "Empezar a chatear",
    /// se setea a true ANTES de cerrar el sheet del onboarding. El callback `onDismiss:` del
    /// `.sheet` lo lee tras la animación de cierre nativa de iOS y abre el ChatSheet sin race.
    /// Patrón canónico iOS 26 — reemplaza el frágil `Task.sleep(350ms)`.
    var pendingOpenChatAfterOnboarding = false

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

    /// True si algún sheet/alert PROPIO del panel ocupa el presentation slot.
    /// Usado por el guard de drain de `.panel` (RouterConsumerGateLogic): con
    /// uno visible, drenar otro intent que setee un sheet lo descartaría.
    /// NO incluye flags de coordinación post-dismiss (`navigateToInboxAfter*`,
    /// `switchToImageAfterVoice`, `pendingOpenChatAfterOnboarding`) ni estado
    /// de setup trial (`isVoiceSetupTrial`, `setupTrialExampleImages`,
    /// `practiceCleanupItem`) — no presentan nada por sí mismos.
    /// Al añadir un sheet nuevo a este struct, añadirlo AQUÍ (test tabla en
    /// PanelSheetStateTests lo documenta).
    var hasActivePresentation: Bool {
        isPresentingSettings
            || accountFormSheet != nil
            || sectionPrefsPresentation != nil
            || showSectionsConfig
            || showNewTransaction
            || showVoiceRecording
            || showImageSelection
            || showCustomPeriodPicker
            || showBudgetFavoritesSettings
            || showInbox
            || showUpgradeForVoice
            || showUpgradeForImage
            || showUpgradeForAccounts
            || showSubscriptionFromBanner
            || showChatSheet
            || showUpgradeForChat
            || showChatConsentAlert
            || showYalaAIOnboarding
            || showAIConsentAlert
    }
}
