//
//  PresentationKinds.swift
//  Yala
//
//  Enum-based model of every modal the shell can present. The
//  PresentationCoordinator holds one `ShellPresentation` + one
//  `PanelPresentation` at a time; the shell binds .sheet/.fullScreenCover
//  modifiers to derived bindings from the coordinator.
//
//  Only includes presentations driven by RouterIntent. Local-only modals
//  (splash, onboarding flow chain, biometric lock) remain shell @State.
//

import Foundation

/// Modal presentations at the ContentView level (shell-wide). One active at a time.
enum ShellPresentation: Equatable {
    case none

    // Inbox + monetization (high priority)
    case inboxAlert(PendingInboxNotification)
    case trialOffer
    case trialExpired
    case milestoneUpgrade(Int)
    case whatsNew(features: [WhatsNewFeature], version: String)
    case downgradeResolution

    // Groups & invites
    case groupInviteOnboarding(InviteMetadata)
    case groupReconnect(InviteMetadata)
    case offerRestoreBeforeInvite(InviteMetadata)
    case inviteError(String)
    case groupSyncError(String)

    // Activation & system
    case fullModeActivation
    case iCloudMismatch
    case remoteWipe(skipOnboarding: Bool)
    case remoteOnboardingCompleted

    /// Stable identifier for the active presentation. Useful for telemetry/logs
    /// and for binding derivation in the coordinator.
    var kindID: String {
        switch self {
        case .none: return "none"
        case .inboxAlert: return "inboxAlert"
        case .trialOffer: return "trialOffer"
        case .trialExpired: return "trialExpired"
        case .milestoneUpgrade: return "milestoneUpgrade"
        case .whatsNew: return "whatsNew"
        case .downgradeResolution: return "downgradeResolution"
        case .groupInviteOnboarding: return "groupInviteOnboarding"
        case .groupReconnect: return "groupReconnect"
        case .offerRestoreBeforeInvite: return "offerRestoreBeforeInvite"
        case .inviteError: return "inviteError"
        case .groupSyncError: return "groupSyncError"
        case .fullModeActivation: return "fullModeActivation"
        case .iCloudMismatch: return "iCloudMismatch"
        case .remoteWipe: return "remoteWipe"
        case .remoteOnboardingCompleted: return "remoteOnboardingCompleted"
        }
    }
}

/// Modal presentations at the Panel tab level. Independent of the shell.
enum PanelPresentation: Equatable {
    case none

    case inboxSheet
    case sharedImage(URL)
    case newTransaction
    case newTransactionFromChatDraft(ChatDraftPrefill)
    case voiceEntry
    case imageEntry
    case upgradeSheet(UpgradeFeature)
    case aiConsent(PendingAIInput)

    var kindID: String {
        switch self {
        case .none: return "none"
        case .inboxSheet: return "inboxSheet"
        case .sharedImage: return "sharedImage"
        case .newTransaction: return "newTransaction"
        case .newTransactionFromChatDraft: return "newTransactionFromChatDraft"
        case .voiceEntry: return "voiceEntry"
        case .imageEntry: return "imageEntry"
        case .upgradeSheet(let f): return "upgradeSheet:\(f.rawValue)"
        case .aiConsent: return "aiConsent"
        }
    }
}
