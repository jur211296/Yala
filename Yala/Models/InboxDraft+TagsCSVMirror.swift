//
//  InboxDraft+TagsCSVMirror.swift
//  Yala
//
//  CSV mirror helpers for InboxDraft.tags. Same pattern as TransactionItem+TagsCSVMirror:
//  - `tagIDs` is the SSOT for reads.
//  - `setTags(from:)` is the single dual-write helper.
//  - `resolvedTagIDs(scheduleBackfill:)` falls back to M2M when CSV is nil and
//    schedules an async write to populate the CSV (auto-cura con snapshot check).
//
//  CSV es SSOT — reads survive CloudKit M2M lazy hydration race al aprobar drafts.
//

import Foundation
import SwiftData

extension InboxDraft {

    // MARK: - Decoder

    var tagIDsSet: Set<UUID>? { CSVMirrorCodec.decode(tagIDs) }

    // MARK: - Dual-Write Helper

    /// Single writer for draft tags. Keeps M2M + CSV in sync.
    /// All `draft.tags = ...` mutations MUST go through this helper.
    func setTags(from tags: [Tag]) {
        self.tags = tags
        self.tagIDs = CSVMirrorCodec.encode(tags.map(\.id))
    }

    // MARK: - Resolved Read with Auto-Heal Lazy Fallback

    /// Returns the resolved Set<UUID> of tags for this draft.
    /// Preference order: CSV mirror > M2M relation.
    /// If `scheduleBackfill=true` and the value comes from M2M, schedules an
    /// async write to populate the CSV (auto-cura con snapshot check para
    /// evitar resurrección de tags borrados por writer concurrente).
    func resolvedTagIDs(scheduleBackfill: Bool = false) -> Set<UUID>? {
        if let set = tagIDsSet { return set }
        let m2m = tags ?? []
        guard !m2m.isEmpty else { return nil }
        let ids = Set(m2m.map(\.id))
        if scheduleBackfill {
            let snapshotIDs = ids
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.tagIDsSet == nil else { return }
                let currentM2M = Set((self.tags ?? []).map(\.id))
                guard currentM2M == snapshotIDs else { return }
                self.setTags(from: self.tags ?? [])
                do {
                    try self.modelContext?.save()
                } catch {
                    #if DEBUG
                    print("InboxDraft+TagsCSVMirror: scheduleBackfill save error: \(error)")
                    #endif
                }
            }
        }
        return ids
    }
}
