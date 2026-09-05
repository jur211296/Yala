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

// `InviteMetadata` se BORRÓ el 2026-09-05 (medido: CERO productores en todo el árbol — nadie escribía
// `InviteMetadata(`). Exigía un `CKShare.Metadata` no-opcional, o sea del canal que la Fase 3 borró, así
// que su único consumidor —`GroupInviteOnboardingView`— lo recibía siempre `nil` y pintaba el visual
// genérico aunque el enlace trajera el nombre del grupo. Su relevo es `InviteLinkService.BrandedMetadata`,
// que es lo que de verdad viaja en el enlace y además persiste con el join intent.

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
    /// G4-invites (DARK, A2): invitado FRESCO por link backend con sesión+consent listos →
    /// presentar el `GroupInviteOnboardingView` actual (metadata nil — visual genérico) para
    /// capturar el nombre ANTES del join; su CTA dispara el join vía el reconciler. El drain
    /// re-evalúa la condición viva (onboarding aún pendiente) antes de presentar.
    case presentGroupBackendInviteOnboarding(pendingJoin: String)
    /// G3 de Grupos-first: avanzar UN paso la rama organizador del Welcome (sign-in → consent → nombre →
    /// formulario). **Sin payload a propósito**: el paso no se recuerda, se RE-DECIDE en el drain con
    /// condiciones vivas (`GroupsOrganizerFlowLogic.nextStep`), que es la regla del repo y lo que hace que
    /// un sign-in ya hecho, un consent aceptado en otra pantalla o un kill a mitad no desalineen la máquina.
    /// Los dos primeros pasos reusan los sheets de `GroupsBackendInviteModifier` —el dueño ÚNICO de ese
    /// anchor—, así que la única presentación nueva es la del nombre.
    case presentGroupsOrganizerStep

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
             .presentGroupsConsent, .presentGroupsSignIn, .presentGroupBackendInviteOnboarding,
             .presentGroupsOrganizerStep,
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
             .presentGroupsConsent, .presentGroupsSignIn, .presentGroupBackendInviteOnboarding,
             .presentGroupsOrganizerStep,
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
        case .presentGroupBackendInviteOnboarding(let pendingJoin):
            return "groupBackendInviteOnboarding:\(pendingJoin)"
        case .presentGroupsOrganizerStep:
            // Clave FIJA (sin payload): dos avances encolados a la vez son el mismo avance, y colapsarlos
            // es lo correcto — el drain re-decide el paso con condiciones vivas de todos modos.
            return "groupsOrganizerStep"
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
    /// G3 · `.presentGroupsOrganizerStep` **NO está aquí, y es deliberado**: los otros tres llegan de fuera
    /// (un link, una notificación) y se encuentran el Welcome montado por delante; este lo emite el propio
    /// Welcome al salir por su portal, que cierra `showWelcomeFlow` en la MISMA vuelta. Marcarlo como
    /// superseding le daría permiso para tumbar la cadena welcome en cualquier otro momento —por ejemplo,
    /// si el usuario relanza a mitad de la rama— en vez de esperar su turno, que es lo correcto.
    var supersedesWelcomeChain: Bool {
        switch self {
        case .presentGroupsConsent, .presentGroupsSignIn, .presentGroupBackendInviteOnboarding:
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
