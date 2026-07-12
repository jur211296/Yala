//
//  AppRouter.swift
//  Yala
//
//  Centralized coordinator for UI presentation intents (deeplinks, notifications,
//  Share Extension, Control Center, monetization triggers). Replaces ad-hoc
//  `SessionState.shouldShow*` flags + `Task.sleep` synchronization. Consumers
//  declare readiness and drain via `onChange(of: revision)`; single-intent drain
//  prevents re-entrance.
//
//  See $VAULT/planning/APPROUTER-AUDIT.md for rollout plan.
//

import Foundation

@Observable @MainActor
final class AppRouter {

    static let shared = AppRouter()

    // MARK: - Consumer registry

    enum ConsumerID: Hashable {
        case panel        // PanelShell — sheets (inbox, voice, image, newTx, upgrade)
        case mainTab      // MainTabView — tab nav, monetization modals, full-mode
        case contentView  // ContentView — inbox alert, group invite, system alerts
        case planning     // Budgets/ScheduledPayments — auto-open editor (peek-first)
    }

    // MARK: - Observable state

    /// Pending intents, priority-then-FIFO ordered on enqueue.
    /// Consumers observe `revision` (not `queue`) to avoid spurious
    /// renders on mutations they don't care about. Read with
    /// `peekNext(for:)` / `drainNext(for:)`.
    private var queue: [RouterIntent] = []

    /// Monotonic counter bumped on every state mutation. Consumers observe
    /// this via `.onChange(of: AppRouter.shared.revision)` — cheaper than
    /// observing the queue array (which would trigger on any mutation).
    private(set) var revision: Int = 0

    /// Consumers currently mounted and accepting intents. A consumer not in
    /// this set leaves its intents queued until it signals ready.
    private(set) var readyConsumers: Set<ConsumerID> = []

    // MARK: - API

    private init() {}

    /// Enqueues an intent. If an intent with the same `id` already exists,
    /// the existing entry is replaced in-place (last-write-wins on payload)
    /// and its queue position is preserved.
    func enqueue(_ intent: RouterIntent) {
        if let existingIndex = queue.firstIndex(where: { $0.id == intent.id }) {
            queue[existingIndex] = intent
        } else {
            let insertIndex = queue.firstIndex(where: { $0.priority < intent.priority }) ?? queue.endIndex
            queue.insert(intent, at: insertIndex)
        }
        bumpRevision()
    }

    /// Returns the next intent for `consumer` and removes it from the queue.
    /// Returns `nil` if the consumer is not ready or has no queued intents.
    /// Consumers are expected to call this from `.onChange(of: revision)`
    /// with a single-shot `if let` (not a `while` loop — that would consume
    /// intents enqueued by the handler in the same tick).
    func drainNext(for consumer: ConsumerID) -> RouterIntent? {
        guard readyConsumers.contains(consumer) else { return nil }
        guard let index = queue.firstIndex(where: { $0.handler == consumer }) else { return nil }
        let intent = queue.remove(at: index)
        bumpRevision()
        return intent
    }

    /// Returns the next intent for `consumer` without removing it. Useful for
    /// consumers that need to branch on the intent type before committing to
    /// drain (e.g., views that only handle a subset of their consumer's
    /// intents). Readiness is NOT required for peeking.
    func peekNext(for consumer: ConsumerID) -> RouterIntent? {
        queue.first(where: { $0.handler == consumer })
    }

    /// Marks a consumer ready. Idempotent.
    func markReady(_ consumer: ConsumerID) {
        guard !readyConsumers.contains(consumer) else { return }
        readyConsumers.insert(consumer)
        bumpRevision()
    }

    /// Marks a consumer unready. Queued intents for this consumer remain in
    /// the queue — they will drain when the consumer becomes ready again
    /// (or are dropped by `resetTransients` / `resetAll`).
    func markUnready(_ consumer: ConsumerID) {
        guard readyConsumers.contains(consumer) else { return }
        readyConsumers.remove(consumer)
        // No revision bump — nothing changes for observers.
    }

    /// Drops all transient intents. Called on scene phase `.background`.
    /// Intents marked `isTransient == false` (remote wipe, iCloud mismatch)
    /// are preserved. Los intents respaldados por un store persistente se re-emiten
    /// desde su fuente en la próxima ventana ready: invites desde `PendingInviteStore`
    /// (`reEmitPendingInviteIfNeeded`) y shared-image desde el App Group `PendingImages/`
    /// (`checkForPendingSharedImage`, en bootstrap post-init Y `handleBecameActive`).
    func resetTransients() {
        let before = queue.count
        queue = queue.filter { !$0.isTransient }
        if queue.count != before { bumpRevision() }
    }

    /// Drops queued intents matching `predicate`. Returns the dropped IDs (in
    /// queue order). Bumps revision iff at least one intent was dropped.
    ///
    /// Used by `RouterEntryGate` to apply supersession rules: when a new
    /// intent supersedes pending ones (e.g. `.navigate(.inbox)` supersedes
    /// `.showInboxAlert`), the gate drops the superseded entries before
    /// enqueueing the incoming one. Safe to call from any consumer.
    @discardableResult
    func drop(where predicate: (RouterIntent) -> Bool) -> [String] {
        var dropped: [String] = []
        queue.removeAll { intent in
            if predicate(intent) {
                dropped.append(intent.id)
                return true
            }
            return false
        }
        if !dropped.isEmpty { bumpRevision() }
        return dropped
    }

    /// Read-only query: does any queued intent match `predicate`?
    /// Does NOT bump revision and does NOT remove anything.
    func contains(where predicate: (RouterIntent) -> Bool) -> Bool {
        queue.contains(where: predicate)
    }

    /// Read-only snapshot of the current queue. Used by `RouterEntryGate` to
    /// run supersession decisions against the queued state. NOT exposed for
    /// direct mutation — callers use `drop`/`enqueue`/`drainNext`.
    var queueSnapshot: [RouterIntent] {
        queue
    }

    /// Nukes everything: queue, readiness, revision, AND the persistent
    /// DeferredIntentBuffer. Called from `DataWipeService` on user-initiated
    /// and remote wipes — without clearing the buffer, stale intents
    /// persisted to UserDefaults would re-emerge after reseed.
    func resetAll() {
        queue.removeAll()
        readyConsumers.removeAll()
        revision = 0
        DeferredIntentBuffer.shared.clear()
        PendingInviteStore.clear()
        PendingJoinStore.clearAll()
        GroupJoinIntentTracker.shared.clear()
    }

    // MARK: - Internals

    private func bumpRevision() {
        revision &+= 1
    }

    // MARK: - Testing

    #if DEBUG
    /// Resets router to pristine state for unit tests. Not exposed in release.
    func _testReset() {
        queue.removeAll()
        readyConsumers.removeAll()
        revision = 0
    }

    /// Test-only queue snapshot for assertions. Production code should use
    /// `peekNext(for:)` / `drainNext(for:)`.
    var _testQueue: [RouterIntent] { queue }
    #endif
}
