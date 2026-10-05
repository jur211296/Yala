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

    /// Un consumidor en una ventana concreta. `scene == nil` solo lo usan los unit tests de este router, que no
    /// montan ventanas: drena como antes de la fase 4 (ver `SceneRoutingLogic.canDrain`).
    struct ScopedConsumer: Hashable {
        let consumer: ConsumerID
        let scene: UUID?
    }

    /// Un intent en cola con la ventana a la que va. **Se sella al encolar** (fase 4 del carril adaptativo): la
    /// ventana que recibió el enlace o la notificación, o la que estaba delante. Los de `.contentView` no se sellan:
    /// van siempre a la líder, que es la única que monta `ContentView`.
    private struct QueuedIntent {
        var intent: RouterIntent
        var target: UUID?
    }

    // MARK: - Observable state

    /// Pending intents, priority-then-FIFO ordered on enqueue.
    /// Consumers observe `revision` (not `queue`) to avoid spurious
    /// renders on mutations they don't care about. Read with
    /// `peekNext(for:in:)` / `drainNext(for:in:)`.
    private var queue: [QueuedIntent] = []

    /// Monotonic counter bumped on every state mutation. Consumers observe
    /// this via `.onChange(of: AppRouter.shared.revision)` — cheaper than
    /// observing the queue array (which would trigger on any mutation).
    private(set) var revision: Int = 0

    /// Consumers currently mounted and accepting intents, por ventana. A consumer not in
    /// this set leaves its intents queued until it signals ready.
    private var readyScoped: Set<ScopedConsumer> = []

    /// Consumidores listos en alguna ventana.
    var readyConsumers: Set<ConsumerID> { Set(readyScoped.map(\.consumer)) }

    // MARK: - API

    private init() {}

    /// Enqueues an intent. If an intent with the same `id` already exists,
    /// the existing entry is replaced in-place (last-write-wins on payload)
    /// and its queue position is preserved. El sello de ventana también se renueva: quien lo pide AHORA decide.
    func enqueue(_ intent: RouterIntent) {
        let queued = QueuedIntent(intent: intent, target: sealTarget(for: intent))
        // Solo los flujos del shell que pide el USUARIO (y que la líder enseña) la traen al frente; un aviso de fondo
        // —bandeja, Novedades, un sync— espera a que el usuario vuelva a la líder (review adversarial, 2026-10-02).
        if intent.bringsLeaderForward, !queue.contains(where: { $0.intent.id == intent.id }) {
            SceneRegistry.shared.bringLeaderForwardIfAnotherWindowIsFocused()
        }
        if let existingIndex = queue.firstIndex(where: { $0.intent.id == intent.id }) {
            queue[existingIndex] = queued
        } else {
            let insertIndex = queue.firstIndex(where: { $0.intent.priority < intent.priority }) ?? queue.endIndex
            queue.insert(queued, at: insertIndex)
        }
        bumpRevision()
    }

    /// Returns the next intent for `consumer` in window `scene` and removes it from the queue.
    /// Returns `nil` if the consumer is not ready or has no queued intents for that window.
    /// Consumers are expected to call this from `.onChange(of: revision)`
    /// with a single-shot `if let` (not a `while` loop — that would consume
    /// intents enqueued by the handler in the same tick).
    func drainNext(for consumer: ConsumerID, in scene: UUID?) -> RouterIntent? {
        guard readyScoped.contains(ScopedConsumer(consumer: consumer, scene: scene)) else { return nil }
        guard let index = queue.firstIndex(where: { matches($0, consumer: consumer, scene: scene) }) else { return nil }
        let intent = queue.remove(at: index).intent
        bumpRevision()
        return intent
    }

    /// Returns the next intent for `consumer` in window `scene` without removing it. Useful for
    /// consumers that need to branch on the intent type before committing to
    /// drain (e.g., views that only handle a subset of their consumer's
    /// intents). Readiness is NOT required for peeking.
    func peekNext(for consumer: ConsumerID, in scene: UUID?) -> RouterIntent? {
        queue.first(where: { matches($0, consumer: consumer, scene: scene) })?.intent
    }

    /// Marks a consumer ready in window `scene`. Idempotent.
    func markReady(_ consumer: ConsumerID, in scene: UUID?) {
        let scoped = ScopedConsumer(consumer: consumer, scene: scene)
        guard !readyScoped.contains(scoped) else { return }
        readyScoped.insert(scoped)
        bumpRevision()
    }

    /// Marks a consumer unready in window `scene`. Queued intents for this consumer remain in
    /// the queue — they will drain when the consumer becomes ready again
    /// (or are dropped by `resetTransients` / `resetAll`).
    func markUnready(_ consumer: ConsumerID, in scene: UUID?) {
        let scoped = ScopedConsumer(consumer: consumer, scene: scene)
        guard readyScoped.contains(scoped) else { return }
        readyScoped.remove(scoped)
        // No revision bump — nothing changes for observers.
    }

    /// Una ventana se abrió o se cerró: un intent sellado a la que se cerró pasa a la que está delante, y su
    /// consumidor tiene que enterarse para drenarlo. Lo llama `SceneRegistry`. Las disponibilidades de la ventana
    /// cerrada se retiran: sus vistas ya no existen para hacerlo ellas.
    func sceneTopologyDidChange() {
        let alive = Set(SceneRegistry.shared.aliveIDs)
        readyScoped = readyScoped.filter { scoped in
            guard let scene = scoped.scene else { return true }
            return alive.contains(scene)
        }
        bumpRevision()
    }

    /// Drops all transient intents. Called on scene phase `.background`.
    /// Intents marked `isTransient == false` (remote wipe, iCloud mismatch)
    /// are preserved. Los intents respaldados por un store persistente se re-emiten
    /// desde su fuente en la próxima ventana ready: invites desde su intent persistido
    /// (el reconciler de join) y shared-image desde el App Group `PendingImages/`
    /// (`checkForPendingSharedImage`, en bootstrap post-init Y `handleBecameActive`).
    func resetTransients() {
        let before = queue.count
        queue = queue.filter { !$0.intent.isTransient }
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
        queue.removeAll { queued in
            if predicate(queued.intent) {
                dropped.append(queued.intent.id)
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
        queue.contains { predicate($0.intent) }
    }

    /// Read-only snapshot of the current queue. Used by `RouterEntryGate` to
    /// run supersession decisions against the queued state. NOT exposed for
    /// direct mutation — callers use `drop`/`enqueue`/`drainNext`.
    var queueSnapshot: [RouterIntent] {
        queue.map(\.intent)
    }

    /// Nukes everything: queue, readiness, revision, AND the persistent
    /// DeferredIntentBuffer. Called from `DataWipeService` on user-initiated
    /// and remote wipes — without clearing the buffer, stale intents
    /// persisted to UserDefaults would re-emerge after reseed.
    func resetAll() {
        queue.removeAll()
        readyScoped.removeAll()
        revision = 0
        DeferredIntentBuffer.shared.clear()
        PendingJoinStore.clearAll()
        GroupJoinIntentTracker.shared.clear()
        // La señal en memoria «acabo de tapear un enlace» se va con el resto del estado de join: un arm
        // superviviente autorizaría un `join_group` después del wipe, sin tap que lo respalde.
        GroupBackendInviteEntryHandler.clearInviteTapArms()
    }

    // MARK: - Internals

    private func bumpRevision() {
        revision &+= 1
    }

    /// La ventana con la que se sella un intent al encolarlo. `.contentView` no se sella: va a la líder.
    private func sealTarget(for intent: RouterIntent) -> UUID? {
        intent.handler == .contentView ? nil : SceneRegistry.shared.routingTargetID
    }

    /// ¿Es este intent del consumidor `consumer` y de la ventana `scene`?
    private func matches(_ queued: QueuedIntent, consumer: ConsumerID, scene: UUID?) -> Bool {
        guard queued.intent.handler == consumer else { return false }
        let registry = SceneRegistry.shared
        // `.contentView` vive solo en la líder: su destino efectivo es ella, esté delante o no.
        let sealed = consumer == .contentView ? registry.leaderID : queued.target
        return SceneRoutingLogic.canDrain(
            sealed: sealed,
            consumerScene: scene,
            focused: registry.focusedID,
            alive: registry.aliveIDs)
    }

    // MARK: - Testing

    #if DEBUG
    /// Resets router to pristine state for unit tests. Not exposed in release.
    func _testReset() {
        queue.removeAll()
        readyScoped.removeAll()
        revision = 0
    }

    /// Test-only queue snapshot for assertions. Production code should use
    /// `peekNext(for:in:)` / `drainNext(for:in:)`.
    var _testQueue: [RouterIntent] { queue.map(\.intent) }

    /// Test-only: la ventana con la que quedó sellado cada intent, en orden de cola.
    var _testTargets: [UUID?] { queue.map(\.target) }
    #endif
}
