//
//  DeferredIntentBuffer.swift
//  Yala
//
//  Persists RouterIntents that arrive when the app cannot present yet
//  (pre-bootstrap, mid-onboarding). Drained by
//  RouterEntryGate on the next ready window. UserDefaults JSON storage with
//  TTL 24h.
//

import Foundation
import OSLog

@MainActor
final class DeferredIntentBuffer {
    static let shared = DeferredIntentBuffer()

    private let storageKey = "Yala.RoutingDeferredIntentBuffer.v1"
    private let logger = Logger(subsystem: "com.yala", category: "RoutingBuffer")
    private let defaults: UserDefaults

    /// TTL after which a deferred entry is silently dropped at drain time. 24h.
    private let ttl: TimeInterval = 24 * 60 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Public API

    /// Append `intent` to the persisted buffer. No-op for non-serializable intents.
    /// (Renamed from `defer` — that is a Swift keyword.)
    func deferIntent(_ intent: RouterIntent) {
        guard let proxy = DeferredIntentBufferLogic.serialize(intent) else {
            #if DEBUG
            logger.debug("DeferredIntentBuffer: skip non-serializable intent \(intent.id, privacy: .public)")
            #endif
            return
        }
        var entries = loadEntries()
        entries.append(DeferredEntry(payload: proxy))
        save(entries)
    }

    /// Returns and clears every deferred intent that can be deserialized into
    /// a live RouterIntent. Entries past TTL are purged silently. Entries
    /// that need live re-resolution (sharedImage URL, invite metadata) are
    /// returned as their `SerializableIntent` proxy so callers can re-route.
    func drainAll(now: Date = Date()) -> [RouterIntent] {
        var entries = loadEntries()
        entries = DeferredIntentBufferLogic.purgeExpired(entries, now: now, ttl: ttl)
        save([])  // clear regardless — drainers re-defer if they can't process

        var intents: [RouterIntent] = []
        for entry in entries {
            if let intent = DeferredIntentBufferLogic.deserialize(entry.payload) {
                intents.append(intent)
            } else {
                #if DEBUG
                logger.debug("DeferredIntentBuffer: drop entry without re-resolver")
                #endif
            }
        }
        return intents
    }

    /// True when there is at least one entry in the buffer (any state).
    var isEmpty: Bool {
        loadEntries().isEmpty
    }

    /// Clear without draining. Called by AppRouter.resetAll() on remote wipe.
    func clear() {
        save([])
    }

    // MARK: - Internals

    private func loadEntries() -> [DeferredEntry] {
        DeferredIntentBufferLogic.decode(defaults.data(forKey: storageKey))
    }

    private func save(_ entries: [DeferredEntry]) {
        if let data = DeferredIntentBufferLogic.encode(entries) {
            defaults.set(data, forKey: storageKey)
        } else {
            defaults.removeObject(forKey: storageKey)
        }
    }
}
