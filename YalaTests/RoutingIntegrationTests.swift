//
//  RoutingIntegrationTests.swift
//  YalaTests
//
//  End-to-end tests for the routing refactor (F1-F10). Uses `@Suite(.serialized)`
//  because AppRouter and DeferredIntentBuffer are singletons — parallel tests
//  would race on shared state.
//
//  Covers:
//   - The owner's bug: notif tap to inbox supersedes a pending inbox alert.
//   - Monetization dedup: trial expired supersedes trial offer.
//   - Critical priority: remote wipe drops queued non-critical intents.
//   - DeferredIntentBuffer round-trip in production-shaped flow.
//

import Foundation
import Testing
@testable import Yala

@Suite("Routing Integration", .serialized)
struct RoutingIntegrationTests {

    @MainActor
    private func freshRouter() -> AppRouter {
        let router = AppRouter.shared
        router._testReset()
        return router
    }

    // MARK: - Bug del owner: alert tardío "automatizaciones"

    @MainActor @Test
    func navigateInbox_supersedesPendingInboxAlert_bugOwnerDead() {
        let router = freshRouter()
        // Simulate cold launch state where AppBootstrapper.checkForPendingInboxDrafts
        // enqueued an inbox alert before the notif tap was processed.
        let notif = PendingInboxNotification(scheduledPayments: 0, subscriptions: 0, automations: 1)
        router.enqueue(.showInboxAlert(notif))
        #expect(router.contains { if case .showInboxAlert = $0 { return true }; return false })

        // Simulate notif tap: NotificationService submits .navigate(.inbox) via the gate.
        // The gate calls IntentSupersessionLogic, drops the queued alert, then enqueues navigate.
        let (drops, accept) = IntentSupersessionLogic.decisions(
            queued: router.queueSnapshot,
            incoming: .navigate(.inbox)
        )
        router.drop { drops.contains($0.id) }
        #expect(accept)
        router.enqueue(.navigate(.inbox))

        // Final state: only the navigate is in the queue.
        #expect(!router.contains { if case .showInboxAlert = $0 { return true }; return false })
        #expect(router.contains { if case .navigate(.inbox) = $0 { return true }; return false })
    }

    @MainActor @Test
    func presentInboxSheet_supersedesPendingInboxAlert() {
        let router = freshRouter()
        let notif = PendingInboxNotification(automations: 2)
        router.enqueue(.showInboxAlert(notif))

        let (drops, _) = IntentSupersessionLogic.decisions(
            queued: router.queueSnapshot,
            incoming: .presentInboxSheet
        )
        router.drop { drops.contains($0.id) }
        router.enqueue(.presentInboxSheet)

        #expect(!router.contains { if case .showInboxAlert = $0 { return true }; return false })
        #expect(router.contains { if case .presentInboxSheet = $0 { return true }; return false })
    }

    // MARK: - Alerts de grupos serializados por readiness (matriz completa)

    /// Dos alerts async del mismo nodo (inviteError + groupSyncError): con ambos
    /// en la matriz de readiness, el primero presentado bloquea el drain y el
    /// segundo ESPERA en cola en vez de setearse tapado y tragarse en silencio.
    @MainActor @Test
    func twoContentViewAlertIntents_serializeAcrossReadiness() {
        let router = freshRouter()
        router.enqueue(.showInviteError("invite falló"))
        router.enqueue(.showGroupSyncError("sync falló"))

        // Consumer listo → drena el primero (inviteError, prioridad más alta).
        router.markReady(.contentView)
        let first = router.drainNext(for: .contentView)
        guard case .showInviteError = first else {
            Issue.record("Esperaba showInviteError primero, drenó \(String(describing: first))")
            return
        }

        // El alert está visible → la matriz (hasActiveInviteError) marca unready.
        router.markUnready(.contentView)
        #expect(router.drainNext(for: .contentView) == nil)
        #expect(router.contains { if case .showGroupSyncError = $0 { return true }; return false })

        // OK del primer alert → flag a nil → recompute → markReady → drena el segundo.
        router.markReady(.contentView)
        let second = router.drainNext(for: .contentView)
        guard case .showGroupSyncError = second else {
            Issue.record("Esperaba showGroupSyncError segundo, drenó \(String(describing: second))")
            return
        }
    }

    // MARK: - Dueling monetization

    @MainActor @Test
    func trialExpired_supersedesPendingTrialOffer() {
        let router = freshRouter()
        router.enqueue(.presentTrialOffer)

        // Supersession lives in IntentSupersessionLogic (single owner).
        let (drops, _) = IntentSupersessionLogic.decisions(
            queued: router.queueSnapshot,
            incoming: .presentTrialExpired
        )
        router.drop { drops.contains($0.id) }
        router.enqueue(.presentTrialExpired)

        #expect(!router.contains { if case .presentTrialOffer = $0 { return true }; return false })
        #expect(router.contains { if case .presentTrialExpired = $0 { return true }; return false })
    }

    @MainActor @Test
    func trialOffer_blockedByPendingTrialExpired() {
        let router = freshRouter()
        router.enqueue(.presentTrialExpired)

        let canEnqueue = MonetizationDedupLogic.canEnqueue(.presentTrialOffer, given: router.queueSnapshot)
        #expect(!canEnqueue)
    }

    // MARK: - Remote wipe priority

    @MainActor @Test
    func remoteWipe_dropsAllNonCriticalQueuedIntents() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)           // normal
        router.enqueue(.showInboxAlert(.init(automations: 1)))  // high
        router.enqueue(.presentTrialOffer)           // normal

        let (drops, _) = IntentSupersessionLogic.decisions(
            queued: router.queueSnapshot,
            incoming: .remoteWipe(skipOnboarding: false)
        )
        router.drop { drops.contains($0.id) }
        router.enqueue(.remoteWipe(skipOnboarding: false))

        // Only remoteWipe survives.
        #expect(router.queueSnapshot.count == 1)
        if case .remoteWipe = router.queueSnapshot.first { } else {
            Issue.record("Expected only remoteWipe to remain")
        }
    }

    // MARK: - DeferredIntentBuffer round-trip

    @MainActor @Test
    func deferredBuffer_persistsAndDrainsNavigateIntent() {
        // Use isolated UserDefaults to avoid colliding with the real buffer.
        let isolatedDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let buffer = DeferredIntentBuffer(defaults: isolatedDefaults)
        buffer.clear()

        buffer.deferIntent(.navigate(.inbox))
        buffer.deferIntent(.navigate(.statistics))

        let drained = buffer.drainAll()
        #expect(drained.count == 2)
        #expect(drained.contains { if case .navigate(.inbox) = $0 { return true }; return false })
        #expect(drained.contains { if case .navigate(.statistics) = $0 { return true }; return false })

        // Second drain yields empty (buffer cleared atomically).
        let secondDrain = buffer.drainAll()
        #expect(secondDrain.isEmpty)
    }

    @MainActor @Test
    func deferredBuffer_silentlyDropsNonSerializableIntents() {
        let isolatedDefaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let buffer = DeferredIntentBuffer(defaults: isolatedDefaults)
        buffer.clear()

        // .presentNewTransaction is fire-and-forget — not serializable.
        buffer.deferIntent(.presentNewTransaction)
        #expect(buffer.isEmpty)
    }

    // MARK: - Single-intent drain protection (regression guard)

    @MainActor @Test
    func singleIntentDrain_pattern_stillIntact_afterRefactor() {
        let router = freshRouter()
        router.markReady(.panel)
        router.enqueue(.presentInboxSheet)

        let first = router.drainNext(for: .panel)
        #expect(first == .presentInboxSheet)

        // Handler enqueues another — drain pattern guarantees it queues for next tick.
        router.enqueue(.presentNewTransaction)
        #expect(router.queueSnapshot.count == 1)

        let second = router.drainNext(for: .panel)
        #expect(second == .presentNewTransaction)
        #expect(router.queueSnapshot.isEmpty)
    }
}
