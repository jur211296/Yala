//
//  ScheduledPayment+TagsCSVMirror.swift
//  Yala
//
//  CSV mirror helpers for ScheduledPayment.tags:
//  - `tagIDs` is the SSOT for reads (sobrevive CloudKit lazy hydration de M2M).
//  - `setTags(from:)` is the single dual-write helper.
//  - `resolvedTagIDs(scheduleBackfill:)` falls back to M2M when CSV is nil y
//    schedules an async write con snapshot check (anti-resurrección).
//

import Foundation
import SwiftData

extension ScheduledPayment {

    // MARK: - Decoder

    var tagIDsSet: Set<UUID>? { CSVMirrorCodec.decode(tagIDs) }

    // MARK: - Dual-Write Helper

    /// Single writer for scheduled payment tags. Keeps M2M + CSV in sync.
    /// All `payment.tags = ...` mutations MUST go through this helper.
    func setTags(from tags: [Tag]) {
        self.tags = tags
        self.tagIDs = CSVMirrorCodec.encode(tags.map(\.id))
    }

    // MARK: - Resolved Read with Auto-Heal Lazy Fallback

    /// Returns the resolved Set<UUID> of tags for this scheduled payment.
    /// Preference order: CSV mirror > M2M relation.
    /// If `scheduleBackfill=true` and the value comes from M2M, schedules an
    /// async write to populate the CSV (auto-cura).
    func resolvedTagIDs(scheduleBackfill: Bool = false) -> Set<UUID>? {
        if let set = tagIDsSet { return set }
        let m2m = tags ?? []
        guard !m2m.isEmpty else { return nil }
        let ids = Set(m2m.map(\.id))
        if scheduleBackfill {
            let snapshotIDs = ids
            let modelID = persistentModelID
            let container = modelContext?.container
            Task { @MainActor in
                guard let container else { return }
                let context = container.mainContext
                guard let model = context.model(for: modelID) as? ScheduledPayment else { return }
                guard model.tagIDsSet == nil else { return }
                let currentM2M = Set((model.tags ?? []).map(\.id))
                guard currentM2M == snapshotIDs else { return }
                // SOLO escribir CSV — NO reasignar M2M (regla CLAUDE.md sync storm).
                model.tagIDs = CSVMirrorCodec.encode(currentM2M)
                do {
                    try context.save()
                } catch {
                    #if DEBUG
                    print("ScheduledPayment+TagsCSVMirror: scheduleBackfill save error: \(error)")
                    #endif
                }
            }
        }
        return ids
    }
}
