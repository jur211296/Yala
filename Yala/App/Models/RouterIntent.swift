//
//  RouterIntent.swift
//  Yala
//
//  Intent enum consumed by AppRouter. Each case represents a UI action (sheet,
//  alert, navigation) produced by async sources (deeplinks, notifications,
//  Share Extension, Control Center, monetization triggers) and drained by a
//  specific consumer view. Named RouterIntent (not AppIntent) to avoid
//  collision with Apple's AppIntents.AppIntent protocol.
//

import CloudKit
import Foundation

/// Feature keys for upgrade prompts routed via `.presentUpgradeSheet`.
enum UpgradeFeature: String {
    case voice, image, accounts, chat
}

/// Custom keys del CKShare zone-wide (escritas/leídas por owner via `setArchived`,
/// leídas por invitados pre-accept via `metadata.share[key]`).
enum CKShareCustomKey {
    static let isArchived = "isArchived"
    static let isHiddenForAll = "isHiddenForAll"
}

/// Mode del banner de reconnect según el estado del invite + membresía actual.
/// Drives copy + CTA en GroupReconnectView.
enum ReconnectMode: String, Equatable, Sendable {
    /// Invitación normal de un user con onboarding completo (path por defecto).
    case standardReconnect
    /// Grupo archivado por el owner — no acepta nuevos miembros.
    case archived
    /// Yo ya soy miembro `.active` (mismo Apple ID en otro device, retap link).
    case alreadyMember
    /// Yo ya envié solicitud, está pendiente de aprobación admin.
    case pendingDuplicate
    /// Admin me rechazó antes — ofrecer volver a pedir.
    case rejectedRetry
    /// Yo abandoné voluntariamente — ofrecer volver a pedir.
    case leftRetry
    /// Admin me removió — ofrecer volver a pedir.
    case removedRetry
    /// FU-02: grupo eliminado por owner — invisible para todos, CTA "Entendido" sin acceptShare.
    case deletedForAll
}

/// Invite metadata carried by group invite intents. CKShare.Metadata is NOT
/// Equatable; comparison delegates to the share record ID + mode.
struct InviteMetadata: Equatable {
    let groupName: String?
    let groupIcon: String?
    let groupColor: String?
    let groupMembers: [String]?
    let shareMetadata: CKShare.Metadata
    /// Mode del reconnect — default `.standardReconnect` para call-sites pre-existentes.
    let mode: ReconnectMode

    init(
        groupName: String?,
        groupIcon: String?,
        groupColor: String?,
        groupMembers: [String]?,
        shareMetadata: CKShare.Metadata,
        mode: ReconnectMode = .standardReconnect
    ) {
        self.groupName = groupName
        self.groupIcon = groupIcon
        self.groupColor = groupColor
        self.groupMembers = groupMembers
        self.shareMetadata = shareMetadata
        self.mode = mode
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.shareMetadata.share.recordID == rhs.shareMetadata.share.recordID && lhs.mode == rhs.mode
    }
}

/// Routed app-level intent. Fully self-contained — does not leak internal
/// state into callers. Each case declares its consumer (`handler`), priority
/// ordering, stable `id` for deduplication, and whether it survives
/// scene-phase transitions (`isTransient`).
enum RouterIntent: Identifiable, Equatable {

    // A) Deep-link / Share / Notification → sheets
    case showInboxAlert(PendingInboxNotification)
    case presentInboxSheet
    case presentSharedImage(URL)
    case presentNewTransaction
    case presentNewTransactionFromChatDraft(ChatDraftPrefill)
    case presentVoiceEntry
    case presentImageEntry
    case presentUpgradeSheet(UpgradeFeature)
    case requestAIConsent(PendingAIInput)

    // B) Monetization (MainTabView consumer)
    case presentDowngradeResolution
    case presentTrialExpired
    case presentTrialOffer
    case presentMilestoneUpgrade(Int)
    case requestAppStoreReview

    // C) Groups & invites
    case presentGroupInviteOnboarding(InviteMetadata)
    case presentGroupReconnect(InviteMetadata)
    /// Returning user con datos en iCloud (sin wipe) que abre un link de invitación →
    /// ofrecer cargar sus datos antes de unirse al grupo (Parte F). El invite queda
    /// retenido en `PendingInviteStore` y se re-emite tras restaurar / empezar de cero.
    case offerRestoreBeforeInvite(InviteMetadata)
    case showInviteError(String)
    case showGroupSyncError(String)
    case presentFullModeActivation
    /// G4-invites (DARK): un link backend llegó con sesión pero sin consentimiento de
    /// grupos → presentar la pantalla de consent. Payload = keying `zoneName`
    /// (== group_id backend). La VISTA la conecta A2; A1 define+drena el intent.
    case presentGroupsConsent(pendingJoin: String)
    /// G4-invites (DARK): un link backend (g+t) llegó sin sesión Nube → presentar el
    /// sign-in solo-grupos. El intent de join ya está persistido en `PendingJoinStore`;
    /// al firmar, el reconciler/handler completa el join. Mismo payload/keying.
    case presentGroupsSignIn(pendingJoin: String)

    // D) Tab navigation
    case navigate(DeepLinkDestination)

    // E) Auto-editors
    case autoOpenBudgetEditor
    case autoOpenScheduledEditor

    // F) System alerts
    case iCloudMismatch
    case remoteWipe(skipOnboarding: Bool)
    case remoteOnboardingCompleted

    // What's new (version bump)
    case presentWhatsNew(features: [WhatsNewFeature], version: String)
}

extension RouterIntent {

    enum Priority: Int, Comparable {
        case low, normal, high, critical
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Consumer view that owns this intent's drain logic.
    var handler: AppRouter.ConsumerID {
        switch self {
        case .showInboxAlert, .presentTrialOffer, .presentWhatsNew,
             .presentGroupInviteOnboarding, .presentGroupReconnect, .offerRestoreBeforeInvite,
             .presentGroupsConsent, .presentGroupsSignIn,
             .showInviteError,
             .showGroupSyncError,
             .iCloudMismatch, .remoteWipe, .remoteOnboardingCompleted,
             .presentFullModeActivation:
            return .contentView

        case .presentInboxSheet, .presentSharedImage, .presentNewTransaction,
             .presentNewTransactionFromChatDraft,
             .presentVoiceEntry, .presentImageEntry, .presentUpgradeSheet,
             .requestAIConsent:
            return .panel

        case .presentDowngradeResolution, .presentTrialExpired,
             .presentMilestoneUpgrade, .requestAppStoreReview, .navigate:
            return .mainTab

        case .autoOpenBudgetEditor, .autoOpenScheduledEditor:
            return .planning
        }
    }

    /// Relative ordering inside a single consumer's drain queue. Higher
    /// priority intents are drained first when multiple are queued for the
    /// same consumer.
    var priority: Priority {
        switch self {
        case .iCloudMismatch, .remoteWipe, .showInviteError:
            return .critical
        case .showInboxAlert, .presentSharedImage, .presentDowngradeResolution,
             .presentTrialExpired, .requestAIConsent, .showGroupSyncError,
             .remoteOnboardingCompleted:
            return .high
        case .presentInboxSheet, .presentNewTransaction, .presentNewTransactionFromChatDraft,
             .presentVoiceEntry, .presentImageEntry, .presentUpgradeSheet,
             .presentMilestoneUpgrade,
             .presentFullModeActivation, .navigate,
             .presentGroupInviteOnboarding, .presentGroupReconnect, .offerRestoreBeforeInvite,
             .presentGroupsConsent, .presentGroupsSignIn,
             .presentTrialOffer, .autoOpenBudgetEditor, .autoOpenScheduledEditor:
            return .normal
        case .requestAppStoreReview, .presentWhatsNew:
            return .low
        }
    }

    /// Stable identifier used for deduplication. Intents with identical ids
    /// collapse inside the queue (last-write-wins for payload).
    var id: String {
        switch self {
        case .showInboxAlert(let n):
            return "inboxAlert:\(n.scheduledPayments)-\(n.subscriptions)-\(n.automations)"
        case .presentInboxSheet:
            return "inboxSheet"
        case .presentSharedImage(let url):
            return "sharedImage:\(url.lastPathComponent)"
        case .presentNewTransaction:
            return "newTransaction"
        case .presentNewTransactionFromChatDraft:
            return "newTransactionFromChatDraft"
        case .presentVoiceEntry:
            return "voiceEntry"
        case .presentImageEntry:
            return "imageEntry"
        case .presentUpgradeSheet(let feature):
            return "upgrade:\(feature.rawValue)"
        case .requestAIConsent(let input):
            return "requestAIConsent:\(input)"
        case .presentDowngradeResolution:
            return "downgrade"
        case .presentTrialExpired:
            return "trialExpired"
        case .presentTrialOffer:
            return "trialOffer"
        case .presentMilestoneUpgrade(let n):
            return "milestone:\(n)"
        case .requestAppStoreReview:
            return "appReview"
        case .presentGroupInviteOnboarding:
            return "groupInviteOnboarding"
        case .presentGroupReconnect:
            return "groupReconnect"
        case .offerRestoreBeforeInvite:
            return "offerRestoreBeforeInvite"
        case .showInviteError(let detail):
            return "inviteError:\(detail.hashValue)"
        case .showGroupSyncError(let detail):
            return "groupSyncError:\(detail.hashValue)"
        case .presentFullModeActivation:
            return "fullMode"
        case .presentGroupsConsent(let pendingJoin):
            return "groupsConsent:\(pendingJoin)"
        case .presentGroupsSignIn(let pendingJoin):
            return "groupsSignIn:\(pendingJoin)"
        case .navigate(let dest):
            return "navigate:\(dest.routerKey)"
        case .autoOpenBudgetEditor:
            return "budgetEditor"
        case .autoOpenScheduledEditor:
            return "scheduledEditor"
        case .iCloudMismatch:
            return "iCloudMismatch"
        case .remoteWipe:
            return "remoteWipe"
        case .remoteOnboardingCompleted:
            return "remoteOnboardingCompleted"
        case .presentWhatsNew(_, let version):
            return "whatsNew:\(version)"
        }
    }

    /// Transient intents are dropped on `.background` via `resetTransients()`.
    /// Persistence-backed intents re-emit on `.active` from their source
    /// services. Critical alerts survive backgrounding.
    var isTransient: Bool {
        switch self {
        case .remoteWipe, .iCloudMismatch, .remoteOnboardingCompleted:
            return false
        default:
            return true
        }
    }

    /// Intents que REEMPLAZAN la cadena welcome/onboarding en lugar de apilarse
    /// sobre ella. ContentView cierra la cadena welcome cuando uno de estos está
    /// pendiente, de modo que su drain (y presentación) pase el readiness gate
    /// — sin esto el cover del WelcomeFlow bloquea el propio intent que lo
    /// reemplazaría (deadlock B4-04).
    var supersedesWelcomeChain: Bool {
        switch self {
        case .presentGroupInviteOnboarding, .presentGroupReconnect, .offerRestoreBeforeInvite,
             .presentGroupsConsent, .presentGroupsSignIn:
            return true
        default:
            return false
        }
    }
}

extension DeepLinkDestination {
    /// Stable key for router dedup. `.groupDetail(...)` collapses to a single
    /// entry regardless of payload (last-write-wins on groupID).
    var routerKey: String {
        switch self {
        case .panel: return "panel"
        case .statistics: return "statistics"
        case .records: return "records"
        case .categories: return "categories"
        case .planning: return "planning"
        case .budgets: return "budgets"
        case .inbox: return "inbox"
        case .scheduledPayments: return "scheduledPayments"
        case .recordsStandalone: return "recordsStandalone"
        case .groups: return "groups"
        case .groupDetail: return "groupDetail"
        }
    }
}
