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
    case scheduledPaymentSaved
    case accountCreated
    case exportCompleted
    case aiInsightsGenerated
    case onboardingCompleted
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
}
