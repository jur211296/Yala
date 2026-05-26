//
//  TelemetryService.swift
//  Yala
//
//  Privacy-first analytics via TelemetryDeck.
//  No tracking IDs, no PII — only aggregate event signals.
//

import Foundation
import TelemetryDeck

// MARK: - Analytics Event

enum AnalyticsEvent: String {
    case appLaunched
    case transactionSaved
    case draftApproved
    case draftRejected
    case budgetSaved
    case budgetFiltersAppearEmpty        // params: budgetID, periodType, hadM2MNotEmpty
    case appEntityShortcutIDsRegenerated // params: accounts, subcategories, tags, budgetsNuked, txsNuked, draftsNuked
    case scheduledPaymentSaved
    case accountCreated
    case exportCompleted
    case aiInsightsGenerated
    case onboardingCompleted             // params: mode, expensesOnly, usedSeedCategories
    case onboardingStarted               // params: mode (initial|fullActivation), prefilled (true|false)
    case onboardingStepViewed            // params: step, stepIndex, totalSteps, mode
    case onboardingPurposePicked         // params: purpose (expensesOnly|dayToDay|fullControl)
    case onboardingAccountsPicked        // params: accounts (single|multiple)
    case onboardingAccountTypePicked     // params: type (checking|savings|creditCard|cash)
    case onboardingCurrencyPicked        // params: currency (rawValue)
    case onboardingCategoriesPicked      // params: loadSeed (true|false)
    case onboardingBackTapped            // params: fromStep, mode
    case onboardingCancelled             // params: atStep, mode
    case welcomeChooserBranchSelected   // A4 — params: branch (new|restore|invite)
    case purchaseAttempted
    case featureGateHit
    case reviewPromptShown
    case proUpsellShown
    case proUpsellTapped
    case proUpsellDismissed
    case paywallViewed
    case trialStarted
    case purchaseCompleted
    case trialExpiring
    case proTourStarted
    case proTourPhaseCompleted
    case proTourCompleted
    case proTourSkipped
    case chatSheetOpened
    case chatSheetDismissed
    case chatQuestionAsked
    case chatSuggestionTapped
    case chatErrorOccurred
    case chatDailyLimitReached
    case chatSuggestionsLLMSucceeded
    case chatSuggestionsLLMFailed
    case chatVoiceInputUsed
    case chatTopicsSheetOpened
    case chatPersistedSessionRehydrated
    // Yala AI Onboarding (4-step tutorial first-use post-consent)
    case yalaAIOnboardingShown          // params: launcher (panel|records|stats)
    case yalaAIOnboardingCompleted      // tap CTA Step 4 "Empezar a chatear"
    case yalaAIOnboardingSkipped        // tap "Saltar" topRight (steps 1-3)
    case yalaAIOnboardingDismissed      // tap "X" topLeft — flag NO se setea
    case yalaAIOnboardingTonePicked     // params: tone (normal|considerate|sarcastic), focus (balanced|saver|cautious)
    // Groups Onboarding (3-step informativo, primer tap del tab Grupos)
    case groupsOnboardingShown          // params: launcher (groupsTab)
    case groupsOnboardingStepViewed     // params: step (1|2|3)
    case groupsOnboardingCompleted      // tap CTA Step 3 "Ir a Grupos"
    // Chat → Registrar transacciones
    case chatIntentClassified           // params: intent, used_force_intent
    case chatDraftProposed              // params: count
    case chatDraftSaved
    case chatDraftDismissed             // tap explícito en botón Descartar
    case chatDraftEditedExternally
    case chatAmbiguousRepregunta

    // Intent lifecycle (Siri / Atajos / Lock Screen / Control Center)
    case intentInvoked
    case intentSuccess
    case intentFailed

    // Group lifecycle
    case groupCreated
    case groupJoined
    case groupArchived
    case groupDeleted
    case groupSoftDeleted
    case groupMemberAdded
    case groupExpenseAdded
    case groupSettlementCreated
    case groupSettlementConfirmed
    case groupSettlementRejected
    case groupHistoryImported
    case groupInviteSent
    case groupInviteAccepted

    // Nudges
    case nudgeShown
    case nudgeTapped
    case nudgeDismissed
    case nudgeAutoDismissed

    // Conversion
    case fullModeActivationStarted
    case fullModeActivationCompleted
    case groupInviteOnboardingCompleted

    // Panel Hero IA
    case panelHeroAIGenerated
    case panelHeroAICacheHit
    case panelHeroCTAImpression
    case panelHeroCTATap

    // CloudKit observability
    case cloudkitExportFailed
    case cloudkitExportSucceeded
    case cloudkitStalledDetected
    case cloudkitIndicatorTapped
    case cloudkitDuplicateDetected
    case cloudkitTransferOrphanRepaired
    case cloudkitTransferCollisionDetected
}

enum DuplicateDetectionContext: String {
    case bootCleanup = "boot-cleanup"
    case runtimeFetch = "runtime-fetch"
    case syncApply = "sync-apply"
    case uniquingFallback = "uniquing-fallback"
}

enum TransferReconcileContext: String {
    case bootReconcile = "boot.transferReconcile"
    case bootCollision = "boot.transferCollision"
}

// MARK: - Telemetry Service

@MainActor
enum TelemetryService {

    private static var isConfigured = false
    private static var trackedOnceKeys: Set<String> = []

    // MARK: - Configuration

    static func configure() {
        guard let appID = APIKeyService.telemetryDeckAppID else {
            #if DEBUG
            print("TelemetryService: No App ID configured — analytics disabled")
            #endif
            return
        }
        TelemetryDeck.initialize(config: .init(appID: appID))
        isConfigured = true
        #if DEBUG
        print("TelemetryService: Initialized")
        #endif
    }

    // MARK: - Tracking

    static func track(_ event: AnalyticsEvent, parameters: [String: String] = [:]) {
        guard isConfigured else { return }
        var params = parameters
        params["isProUser"] = String(FeatureGateService.shared.isProUser)
        TelemetryDeck.signal(event.rawValue, parameters: params)
        #if DEBUG
        if event.rawValue.hasPrefix("cloudkit") {
            print("TelemetryService: [CloudKit] \(event.rawValue) params=\(params)")
        }
        #endif
    }

    /// Builds common parameters for upsell/conversion tracking.
    static func upsellParameters(source: String) -> [String: String] {
        var params: [String: String] = ["source": source]
        if let firstLaunch = UserDefaults.standard.object(forKey: "reviewFirstLaunchDate") as? Date {
            let days = Calendar.current.dateComponents([.day], from: firstLaunch, to: .now).day ?? 0
            params["daysSinceInstall"] = String(days)
        }
        params["sessionNumber"] = String(UserDefaults.standard.integer(forKey: "pro.upsell.sessionCount"))
        return params
    }

    /// Tracks an event only once per session (deduplicates by composite key).
    static func trackOnce(_ event: AnalyticsEvent, key: String, parameters: [String: String] = [:]) {
        let compositeKey = "\(event.rawValue):\(key)"
        guard !trackedOnceKeys.contains(compositeKey) else { return }
        trackedOnceKeys.insert(compositeKey)
        track(event, parameters: parameters)
    }

    /// Reports a CloudKit-driven duplicate observation. The composite key includes
    /// `keySuffix` (typically a zoneID or count) so each distinct duplicate fires once
    /// instead of collapsing every dup in a session into a single event. The suffix
    /// is local-only — it never reaches the backend.
    static func cloudkitDuplicateDetected(
        model: String,
        count: Int,
        context: DuplicateDetectionContext,
        keySuffix: String
    ) {
        trackOnce(
            .cloudkitDuplicateDetected,
            key: "\(model):\(context.rawValue):\(keySuffix)",
            parameters: [
                "model": model,
                "count": String(count),
                "context": context.rawValue
            ]
        )
    }

    /// Reports orphan / malformed / pairing repair from `TransferPairReconcileService`.
    /// Privacy-first: no pairIDs ni TX identifiers, solo counts.
    static func cloudkitTransferOrphanRepaired(orphansCleared: Int, pairedCount: Int) {
        track(.cloudkitTransferOrphanRepaired, parameters: [
            "orphansCleared": String(orphansCleared),
            "pairedCount": String(pairedCount),
            "context": TransferReconcileContext.bootReconcile.rawValue
        ])
    }

    /// Reports a `transferPairID` shared by 3+ TXs (collision). NO auto-repair se aplica
    /// porque la heurística podría borrar data válida. Solo telemetry.
    static func cloudkitTransferCollisionDetected(count: Int) {
        track(.cloudkitTransferCollisionDetected, parameters: [
            "model": "TransactionItem",
            "count": String(count),
            "context": TransferReconcileContext.bootCollision.rawValue
        ])
    }
}
