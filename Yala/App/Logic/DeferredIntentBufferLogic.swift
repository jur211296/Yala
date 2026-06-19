//
//  DeferredIntentBufferLogic.swift
//  Yala
//
//  Pure-logic: codable layer for the DeferredIntentBuffer.
//
//  Some RouterIntents arrive when the app cannot present yet (pre-bootstrap,
//  biometric lock, mid-onboarding). Instead of dropping them, the gate
//  persists a serializable proxy in UserDefaults. On the next ready window
//  the buffer drains via the gate.
//
//  Not every intent is serializable (`.presentGroupInviteOnboarding(CKShare.Metadata)`
//  is not — CKShare.Metadata is opaque). For those, we persist only what
//  identifies the path (the share URL string) and re-resolve at drain time.
//

import Foundation

/// Persisted envelope. `version` enables schema evolution; unknown versions
/// are dropped silently in decode.
struct DeferredEntry: Codable, Equatable {
    let version: Int
    let createdAt: Date
    let payload: SerializableIntent

    static let currentVersion = 1

    init(payload: SerializableIntent, createdAt: Date = Date()) {
        self.version = Self.currentVersion
        self.createdAt = createdAt
        self.payload = payload
    }
}

/// Codable proxy for the subset of RouterIntents safe to persist across
/// app launches. Excludes intents whose payload contains live framework
/// objects (CKShare.Metadata, fetched accounts/budgets, runtime callbacks).
enum SerializableIntent: Codable, Equatable {
    case navigate(routerKey: String)
    case showInboxAlert(scheduledPayments: Int, subscriptions: Int, automations: Int)
}

enum DeferredIntentBufferLogic {

    /// `true` if the intent has a faithful proxy in `SerializableIntent`.
    /// Returns false for intents carrying non-codable payloads.
    static func canSerialize(_ intent: RouterIntent) -> Bool {
        return serialize(intent) != nil
    }

    /// Lossy projection from RouterIntent to SerializableIntent. Returns nil
    /// for intents without a stable persistent representation, including
    /// intents whose deserialization cannot recover the original payload:
    /// - `.navigate(.groupDetail(groupID:))` — groupID is NOT in `routerKey`,
    ///   so a round-trip would silently lose it. Better refuse to serialize.
    /// - `.presentSharedImage(url)` — the full URL cannot be reconstructed
    ///   from `filename` alone. `AppBootstrapper.checkForPendingSharedImage`
    ///   re-emits this intent on each cold launch from `SharedContainerService`,
    ///   so deferral via buffer is redundant + lossy.
    static func serialize(_ intent: RouterIntent) -> SerializableIntent? {
        switch intent {
        case .navigate(let dest):
            // Reject groupDetail: payload would be silently lost on drain.
            if case .groupDetail = dest { return nil }
            return .navigate(routerKey: dest.routerKey)
        case .showInboxAlert(let n):
            return .showInboxAlert(
                scheduledPayments: n.scheduledPayments,
                subscriptions: n.subscriptions,
                automations: n.automations
            )
        case .presentSharedImage:
            // Re-emitted from SharedContainerService at every cold launch —
            // persistence would create stale entries pointing at a filename
            // we can't re-resolve. Skip.
            return nil
        default:
            return nil
        }
    }

    /// Inverse of `serialize`. `serialize` rejects unrecoverable cases
    /// up-front, so this function only needs the recoverable subset.
    static func deserialize(_ s: SerializableIntent) -> RouterIntent? {
        switch s {
        case .navigate(let key):
            guard let dest = deepLinkDestination(from: key) else { return nil }
            return .navigate(dest)
        case .showInboxAlert(let sched, let subs, let autos):
            return .showInboxAlert(PendingInboxNotification(
                scheduledPayments: sched,
                subscriptions: subs,
                automations: autos
            ))
        }
    }

    /// Encode a list of entries to JSON. Returns nil on failure.
    static func encode(_ entries: [DeferredEntry]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(entries)
    }

    /// Decode entries from JSON with per-element tolerance. A single corrupt
    /// or unknown-schema entry does NOT sink the whole array. Used so that:
    /// - A future build serializes a new SerializableIntent case → older
    ///   builds that downgrade still recover the v1 entries they understand.
    /// - A storage corruption on one entry doesn't lose the rest.
    /// Returns `[]` only on totally-malformed input.
    static func decode(_ data: Data?) -> [DeferredEntry] {
        guard let data, !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Step 1: parse as opaque array of JSON objects (always succeeds for
        // well-formed JSON, regardless of entry shape).
        guard let rawArray = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return []
        }
        // Step 2: decode each element independently; drop on per-element failure.
        var entries: [DeferredEntry] = []
        for element in rawArray {
            guard let elementData = try? JSONSerialization.data(withJSONObject: element) else {
                continue
            }
            guard let entry = try? decoder.decode(DeferredEntry.self, from: elementData) else {
                continue
            }
            guard entry.version == DeferredEntry.currentVersion else { continue }
            entries.append(entry)
        }
        return entries
    }

    /// Drops entries older than `ttl`. Default TTL = 24h.
    static func purgeExpired(
        _ entries: [DeferredEntry],
        now: Date,
        ttl: TimeInterval = 24 * 60 * 60
    ) -> [DeferredEntry] {
        entries.filter { now.timeIntervalSince($0.createdAt) < ttl }
    }

    // MARK: - Internals

    /// Reverse-lookup of `DeepLinkDestination.routerKey`. Returns nil if the
    /// key is unknown (forward compatibility — older builds may have
    /// persisted a destination the current build no longer recognises).
    /// Note: `groupDetail` is excluded — its `groupID` payload is not in `routerKey`.
    static func deepLinkDestination(from key: String) -> DeepLinkDestination? {
        switch key {
        case "panel": return .panel
        case "statistics": return .statistics
        case "records": return .records
        case "categories": return .categories
        case "planning": return .planning
        case "budgets": return .budgets
        case "inbox": return .inbox
        case "scheduledPayments": return .scheduledPayments
        case "recordsStandalone": return .recordsStandalone
        case "groups": return .groups
        default: return nil
        }
    }
}
