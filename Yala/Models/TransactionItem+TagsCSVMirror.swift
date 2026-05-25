//
//  TransactionItem+TagsCSVMirror.swift
//  Yala
//
//  CSV mirror helpers for TransactionItem.tags. Same pattern as Budget+CSVMirror:
//  - `tagIDs` is the SSOT for reads.
//  - `setTags(from:)` is the single dual-write helper.
//  - `resolvedTagIDs(scheduleBackfill:)` falls back to M2M when CSV is nil and
//    schedules an async write to populate the CSV (auto-cura).
//

import Foundation
import SwiftData

extension TransactionItem {

    // MARK: - Decoder

    var tagIDsSet: Set<UUID>? { CSVMirrorCodec.decode(tagIDs) }

    // MARK: - Dual-Write Helper

    /// Single writer for transaction tags. Keeps M2M + CSV in sync.
    /// All `transaction.tags = ...` mutations MUST go through this helper.
    func setTags(from tags: [Tag]) {
        self.tags = tags
        self.tagIDs = CSVMirrorCodec.encode(tags.map(\.id))
    }

    // MARK: - Resolved Read with Auto-Heal Lazy Fallback

    /// Returns the resolved Set<UUID> of tags for this transaction.
    /// Preference order: CSV mirror > M2M relation.
    /// If `scheduleBackfill=true` and the value comes from M2M, schedules an
    /// async write to populate the CSV (auto-cura).
    ///
    /// Race-safety: el Task verifica que el M2M actual aún coincida con el
    /// snapshot antes de escribir — protege contra resurrección de tags borrados
    /// por un writer concurrente entre el snapshot y la ejecución del Task.
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
                // Verify M2M actual aún matchea snapshot — si un writer concurrente
                // modificó la relación, NO restauramos (evita resurrección).
                let currentM2M = Set((self.tags ?? []).map(\.id))
                guard currentM2M == snapshotIDs else { return }
                self.setTags(from: self.tags ?? [])
                do {
                    try self.modelContext?.save()
                } catch {
                    #if DEBUG
                    print("TransactionItem+TagsCSVMirror: scheduleBackfill save error: \(error)")
                    #endif
                }
            }
        }
        return ids
    }
}
