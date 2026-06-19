//
//  AppRouterTests.swift
//  YalaTests
//
//  Unit tests for AppRouter (F1 of router refactor). Covers enqueue dedup,
//  priority/FIFO ordering, drain semantics, readiness gating, transient vs
//  non-transient reset, and the critical single-intent drain (re-entrance
//  protection).
//

import CloudKit
import Foundation
import Testing

@testable import Yala

struct AppRouterTests {

    // MARK: - Helpers

    @MainActor
    private func freshRouter() -> AppRouter {
        let router = AppRouter.shared
        router._testReset()
        return router
    }

    // MARK: - enqueue

    @MainActor @Test func enqueue_empty_addsToQueue() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)
        #expect(router._testQueue.count == 1)
        #expect(router._testQueue.first?.id == "inboxSheet")
    }

    @MainActor @Test func enqueue_duplicateID_isDropped() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)
        router.enqueue(.presentInboxSheet)
        #expect(router._testQueue.count == 1)
    }

    @MainActor @Test func enqueue_priorityOrder_criticalBeforeHigh() {
        let router = freshRouter()
        router.enqueue(.presentMilestoneUpgrade(10))  // normal, .mainTab
        router.enqueue(.iCloudMismatch)               // critical, .contentView
        router.enqueue(.presentSharedImage(URL(fileURLWithPath: "/tmp/a.jpg")))  // high, .panel

        #expect(router._testQueue[0].id == "iCloudMismatch")     // critical first
        #expect(router._testQueue[1].id == "sharedImage:a.jpg")  // high second
        #expect(router._testQueue[2].id == "milestone:10")       // normal last
    }

    @MainActor @Test func enqueue_samePriority_fifoOrder() {
        let router = freshRouter()
        router.enqueue(.presentNewTransaction)  // normal
        router.enqueue(.presentVoiceEntry)      // normal
        router.enqueue(.presentImageEntry)      // normal

        #expect(router._testQueue[0].id == "newTransaction")
        #expect(router._testQueue[1].id == "voiceEntry")
        #expect(router._testQueue[2].id == "imageEntry")
    }

    @MainActor @Test func enqueue_bumpsRevision() {
        let router = freshRouter()
        let before = router.revision
        router.enqueue(.presentInboxSheet)
        #expect(router.revision > before)
    }

    // MARK: - drainNext

    @MainActor @Test func drainNext_emptyQueue_returnsNil() {
        let router = freshRouter()
        router.markReady(.panel)
        #expect(router.drainNext(for: .panel) == nil)
    }

    @MainActor @Test func drainNext_readyConsumer_returnsMatchingIntent() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)
        router.markReady(.panel)

        let intent = router.drainNext(for: .panel)
        #expect(intent == .presentInboxSheet)
        #expect(router._testQueue.isEmpty)
    }

    @MainActor @Test func drainNext_unreadyConsumer_returnsNil_leavesIntentQueued() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)

        // Consumer not ready
        #expect(router.drainNext(for: .panel) == nil)
        #expect(router._testQueue.count == 1)
    }

    @MainActor @Test func drainNext_skipsIntentsForOtherConsumers() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)       // .panel
        router.enqueue(.presentTrialExpired)     // .mainTab
        router.markReady(.mainTab)

        let intent = router.drainNext(for: .mainTab)
        #expect(intent == .presentTrialExpired)
        #expect(router._testQueue.count == 1)
        #expect(router._testQueue.first?.id == "inboxSheet")
    }

    @MainActor @Test func drainNext_removesReturnedIntent() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)
        router.markReady(.panel)

        _ = router.drainNext(for: .panel)
        #expect(router._testQueue.isEmpty)
    }

    // MARK: - readiness

    @MainActor @Test func markReady_bumpsRevision() {
        let router = freshRouter()
        let before = router.revision
        router.markReady(.panel)
        #expect(router.revision > before)
    }

    @MainActor @Test func markUnready_doesNotDropQueuedIntents() {
        let router = freshRouter()
        router.markReady(.panel)
        router.enqueue(.presentInboxSheet)
        router.markUnready(.panel)

        // Intent still queued, consumer just unable to drain
        #expect(router._testQueue.count == 1)
    }

    /// Simula el gating del ChatSheet en PanelShell: mientras chat abierto,
    /// `.panel` está unready y los intents (incluido el del Edit del draft)
    /// permanecen en queue. Al cerrar el chat, markReady drena.
    @MainActor @Test func chatSheetUnreadyBlocksDrain_thenDrainsOnReady() {
        let router = freshRouter()
        router.markReady(.panel)

        // Chat abre → unready
        router.markUnready(.panel)

        // User tap Edit → enqueue
        let prefill = ChatDraftPrefill(
            originMessageID: UUID(),
            originDraftID: UUID(),
            accountID: nil,
            subcategoryID: nil,
            amount: 50,
            currencyCode: "PEN",
            note: "almuerzo",
            date: Date.now,
            isExpense: true,
            tagIDs: []
        )
        router.enqueue(.presentNewTransactionFromChatDraft(prefill))

        // Intent queueado, drain bloqueado
        #expect(router.drainNext(for: .panel) == nil)
        #expect(router._testQueue.count == 1)

        // Chat cierra → ready → intent drenable
        router.markReady(.panel)
        let drained = router.drainNext(for: .panel)
        #expect(drained != nil)
        if case .presentNewTransactionFromChatDraft = drained {
            // success
        } else {
            Issue.record("Expected presentNewTransactionFromChatDraft, got \(String(describing: drained))")
        }
        #expect(router._testQueue.isEmpty)
    }

    // MARK: - reset

    @MainActor @Test func resetTransients_removesTransientIntents_keepsPersistenceBacked() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)        // transient
        router.enqueue(.iCloudMismatch)           // non-transient
        router.enqueue(.remoteWipe(skipOnboarding: false))  // non-transient

        router.resetTransients()

        #expect(router._testQueue.count == 2)
        #expect(router._testQueue.contains { $0.id == "iCloudMismatch" })
        #expect(router._testQueue.contains { $0.id == "remoteWipe" })
    }

    @MainActor @Test func resetAll_wipesEverything_resetsRevision() {
        let router = freshRouter()
        router.enqueue(.iCloudMismatch)
        router.markReady(.panel)

        router.resetAll()

        #expect(router._testQueue.isEmpty)
        #expect(router.readyConsumers.isEmpty)
        #expect(router.revision == 0)
    }

    // MARK: - dedup by id

    @MainActor @Test func navigateGroupDetail_deduplicatesByRouterKey_lastWriteWins() {
        let router = freshRouter()
        router.enqueue(.navigate(.groupDetail(groupID: "A")))
        router.enqueue(.navigate(.groupDetail(groupID: "B")))

        #expect(router._testQueue.count == 1)
        // Last payload wins (same id "navigate:groupDetail" for both)
        if case .navigate(.groupDetail(let id)) = router._testQueue.first {
            #expect(id == "B")
        } else {
            Issue.record("Expected navigate(groupDetail) intent")
        }
    }

    @MainActor @Test func inboxAlert_dedupesBySignature() {
        let router = freshRouter()
        let notif1 = PendingInboxNotification(scheduledPayments: 2, subscriptions: 1, automations: 0)
        let notif2 = PendingInboxNotification(scheduledPayments: 2, subscriptions: 1, automations: 0)
        let notif3 = PendingInboxNotification(scheduledPayments: 3, subscriptions: 1, automations: 0)

        router.enqueue(.showInboxAlert(notif1))
        router.enqueue(.showInboxAlert(notif2))  // same signature → dedup
        router.enqueue(.showInboxAlert(notif3))  // different signature → new entry

        #expect(router._testQueue.count == 2)
    }

    @MainActor @Test func sharedImage_dedupesByFilename() {
        let router = freshRouter()
        router.enqueue(.presentSharedImage(URL(fileURLWithPath: "/tmp/a.jpg")))
        router.enqueue(.presentSharedImage(URL(fileURLWithPath: "/other/a.jpg")))  // same filename → dedup
        router.enqueue(.presentSharedImage(URL(fileURLWithPath: "/tmp/b.jpg")))    // different filename

        #expect(router._testQueue.count == 2)
    }

    // MARK: - drop(where:) and contains(where:) — F2 extensions

    @MainActor @Test func drop_byPredicate_removesMatchingIntents_bumpsRevision() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)
        router.enqueue(.presentTrialOffer)
        router.enqueue(.presentNewTransaction)
        let beforeRev = router.revision

        let dropped = router.drop { intent in
            if case .presentInboxSheet = intent { return true }
            return false
        }

        #expect(dropped == ["inboxSheet"])
        #expect(router._testQueue.count == 2)
        #expect(router.revision == beforeRev + 1)
    }

    @MainActor @Test func drop_emptyMatch_doesNotBumpRevision() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)
        let beforeRev = router.revision

        let dropped = router.drop { intent in
            if case .presentTrialOffer = intent { return true }
            return false
        }

        #expect(dropped.isEmpty)
        #expect(router._testQueue.count == 1)
        #expect(router.revision == beforeRev)
    }

    @MainActor @Test func contains_matchingPredicate_returnsTrue() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)

        #expect(router.contains { if case .presentInboxSheet = $0 { return true }; return false })
        #expect(!router.contains { if case .presentTrialOffer = $0 { return true }; return false })
    }

    @MainActor @Test func contains_doesNotMutateOrBumpRevision() {
        let router = freshRouter()
        router.enqueue(.presentInboxSheet)
        let beforeRev = router.revision
        let beforeCount = router._testQueue.count

        _ = router.contains { _ in true }

        #expect(router._testQueue.count == beforeCount)
        #expect(router.revision == beforeRev)
    }

    @MainActor @Test func _testReset_clearsStateBetweenTests() {
        let router = AppRouter.shared
        router.enqueue(.presentInboxSheet)
        router.markReady(.panel)
        router._testReset()

        #expect(router._testQueue.isEmpty)
        #expect(router.readyConsumers.isEmpty)
        #expect(router.revision == 0)
    }

    // MARK: - Re-entrance (CRITICAL regression test)

    /// If a drain handler enqueues a new intent, the single-intent drain
    /// pattern guarantees the new intent is NOT processed in the same
    /// `onChange` tick. It waits for the next revision observer fire.
    /// This is the contract that kills the original bug pattern where
    /// an `InboxAlertModal.onViewInbox` callback enqueues the Inbox sheet
    /// mid-dismissal.
    @MainActor @Test func drain_handlerEnqueuesNewIntent_doesNotProcessInSameTick() {
        let router = freshRouter()
        router.markReady(.panel)
        router.enqueue(.presentInboxSheet)

        // Simulate the consumer's `.onChange(revision)` running:
        // Pull ONE intent, handler enqueues another, but we don't loop.
        let firstIntent = router.drainNext(for: .panel)
        #expect(firstIntent == .presentInboxSheet)

        // Handler enqueues a follow-up (as if InboxAlertModal.onViewInbox)
        router.enqueue(.presentNewTransaction)

        // The new intent MUST be queued, not already drained.
        // It drains on the NEXT tick — caller's responsibility not to loop.
        #expect(router._testQueue.count == 1)
        #expect(router._testQueue.first?.id == "newTransaction")

        // Next tick drains it cleanly.
        let secondIntent = router.drainNext(for: .panel)
        #expect(secondIntent == .presentNewTransaction)
        #expect(router._testQueue.isEmpty)
    }

    // MARK: - supersedesWelcomeChain (B4-04)

    /// Intents comunes NO deben gatillar el teardown de la cadena welcome.
    /// (El true-path — group invite/reconnect — requiere `CKShare.Metadata`, no
    /// construible en test sin CloudKit; se cubre vía ContentViewReadinessLogic
    /// + device QA.)
    @Test func supersedesWelcomeChain_falseForCommonIntents() {
        #expect(RouterIntent.presentTrialOffer.supersedesWelcomeChain == false)
        #expect(RouterIntent.presentFullModeActivation.supersedesWelcomeChain == false)
        #expect(RouterIntent.iCloudMismatch.supersedesWelcomeChain == false)
        #expect(RouterIntent.remoteWipe(skipOnboarding: false).supersedesWelcomeChain == false)
        #expect(RouterIntent.remoteOnboardingCompleted.supersedesWelcomeChain == false)
        #expect(RouterIntent.presentInboxSheet.supersedesWelcomeChain == false)
        #expect(RouterIntent.presentWhatsNew(features: [], version: "1.0").supersedesWelcomeChain == false)
        #expect(RouterIntent.navigate(.panel).supersedesWelcomeChain == false)
    }
}
