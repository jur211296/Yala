//
//  RouterEntryGate.swift
//  Yala
//
//  Single entry point for enqueueing RouterIntents. Applies, in order:
//   1. Notification/lock gating → defer to DeferredIntentBuffer if blocked.
//   2. Cross-intent supersession (IntentSupersessionLogic) → drop superseded.
//   3. Monetization dedup (MonetizationDedupLogic) → drop incoming if blocked.
//   4. Forward to AppRouter.shared.enqueue.
//
//  All producers in the app submit via `RouterEntryGate.shared.submit(_:)`.
//  `AppRouter.shared.enqueue` stays public for tests that cover the motor,
//  but production code should not call it directly.
//

import Foundation
import OSLog

@MainActor
final class RouterEntryGate {
    static let shared = RouterEntryGate()

    private let logger = Logger(subsystem: "com.yala", category: "RoutingGate")

    /// Override hook for testing. Production reads `AppPreferences.Keys.hasCompletedOnboarding`
    /// + `AppBootstrapper.shared.isInitialized`.
    /// `@MainActor () -> ...` declares the isolation matches the caller (Swift 6 ready).
    var readinessProvider: @MainActor () -> (hasCompletedOnboarding: Bool, isBootstrapInitialized: Bool) = {
        let onboardingDone = UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
        let bootstrapped = AppBootstrapper.shared.isInitialized
        return (onboardingDone, bootstrapped)
    }

    private init() {}

    // MARK: - Public API

    /// Submit an intent. Replaces direct `AppRouter.shared.enqueue` from production.
    func submit(_ intent: RouterIntent) {
        // 1. Defer if the app cannot process notifications/deeplinks right now.
        if shouldDefer(intent) {
            // Canario (fuera de #if DEBUG, sin PII): un intent notification-like que se difiere
            // pero NO es serializable se PIERDE — `deferIntent` lo descarta en silencio. Cazó el
            // bug de cold-launch de shared-image; también delataría el mismo hueco en
            // `.navigate(.groupDetail)`. Ver Bugs/qa_cold-launch-share-image-no-registro.
            if !DeferredIntentBufferLogic.canSerialize(intent) {
                logger.notice("RouterEntryGate: DROP non-serializable deferred intent \(intent.id, privacy: .public)")
            }
            DeferredIntentBuffer.shared.deferIntent(intent)
            let r = readinessProvider()
            let reason = NotificationGateLogic.deferralReason(
                hasCompletedOnboarding: r.hasCompletedOnboarding,
                isBootstrapInitialized: r.isBootstrapInitialized
            ) ?? "unknown"
            MetricsService.routingIntentDeferred(intentID: intent.id, reason: reason)
            #if DEBUG
            logger.debug("RouterEntryGate: defer \(intent.id, privacy: .public) — \(reason, privacy: .public)")
            #endif
            return
        }

        // 1b. Inbox sheet visibility short-circuit:
        // a `.showInboxAlert` arriving while the user already has the Inbox
        // sheet open would queue a fullScreenCover behind the sheet and
        // surface tardío on dismiss. Drop silently when the sheet is visible
        // (the data is in the sheet already).
        if case .showInboxAlert = intent,
           SessionState.shared.isInboxSheetVisible {
            #if DEBUG
            logger.debug("RouterEntryGate: drop \(intent.id, privacy: .public) — inbox sheet already visible")
            #endif
            return
        }

        // 2. Monetization dedup (cross-type). If the queue already holds a
        // higher-pressure monetization intent, drop incoming silently.
        if !MonetizationDedupLogic.canEnqueue(intent, given: AppRouter.shared.queueSnapshot) {
            #if DEBUG
            logger.debug("RouterEntryGate: drop incoming \(intent.id, privacy: .public) — monetization dedup")
            #endif
            return
        }

        // 3. Apply supersession: drop queued intents superseded by this incoming.
        let queue = AppRouter.shared.queueSnapshot
        let (drops, accept) = IntentSupersessionLogic.decisions(queued: queue, incoming: intent)
        if !drops.isEmpty {
            AppRouter.shared.drop { drops.contains($0.id) }
            for dropped in drops {
                MetricsService.routingIntentSuperseded(droppedID: dropped, by: intent.id)
            }
        }
        // Monetization-driven supersession (e.g. trialExpired drops trialOffer).
        let monetizationDrops = MonetizationDedupLogic.intentsToSupersede(by: intent, in: AppRouter.shared.queueSnapshot)
        if !monetizationDrops.isEmpty {
            AppRouter.shared.drop { monetizationDrops.contains($0.id) }
            for dropped in monetizationDrops {
                MetricsService.routingIntentSuperseded(droppedID: dropped, by: intent.id)
            }
        }

        guard accept else {
            #if DEBUG
            logger.debug("RouterEntryGate: drop incoming \(intent.id, privacy: .public) — supersession self-block")
            #endif
            return
        }

        // 4. Forward to the motor.
        AppRouter.shared.enqueue(intent)
    }

    /// Drain every entry from the DeferredIntentBuffer through `submit(_:)`.
    /// Called once at cold-launch (post-bootstrap) and once per `scenePhase`
    /// transition to `.active`. NOT called from `submit` itself (would loop).
    func drainDeferredBuffer() {
        let intents = DeferredIntentBuffer.shared.drainAll()
        guard !intents.isEmpty else { return }
        #if DEBUG
        logger.debug("RouterEntryGate: drain \(intents.count, privacy: .public) deferred intent(s)")
        #endif
        for intent in intents { submit(intent) }
    }

    // MARK: - Internals

    private func shouldDefer(_ intent: RouterIntent) -> Bool {
        // Only defer the intents that originate from notification taps /
        // pre-bootstrap deep links. Producer code that hits ready paths (UI
        // taps, completion handlers) should always enqueue immediately —
        // their callsite knows readiness.
        guard isNotificationLike(intent) else { return false }
        let r = readinessProvider()
        let enqueueNow = NotificationGateLogic.shouldEnqueueNow(
            hasCompletedOnboarding: r.hasCompletedOnboarding,
            isBootstrapInitialized: r.isBootstrapInitialized
        )
        return !enqueueNow
    }

    /// Heuristic: which intents can validly arrive from background contexts
    /// (notifications, share extension, deep links) and need deferral.
    /// Synchronous user-driven intents (sheets/upgrades from taps) never defer.
    private func isNotificationLike(_ intent: RouterIntent) -> Bool {
        switch intent {
        case .navigate, .presentSharedImage:
            return true
        default:
            return false
        }
    }
}

// Snapshot is exposed by AppRouter directly (see AppRouter.queueSnapshot).
