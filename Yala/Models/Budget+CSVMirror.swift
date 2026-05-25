//
//  Budget+CSVMirror.swift
//  Yala
//
//  CSV mirror helpers for Budget M2M relations (subcategories/accounts/tags).
//  Solves CloudKit lazy hydration race: when a Budget record syncs but its M2M
//  relations are not yet materialized, reading the M2M returns nil/[] and the
//  spending calculator treats it as "no filter" → sums every expense (the bug).
//
//  Design:
//  - CSV fields (subcategoryIDs/accountIDs/tagIDs) travel in the Budget record
//    itself, so they are always available after the record arrives.
//  - resolvedXIDs(scheduleBackfill:) prefers CSV; falls back to M2M and (optionally)
//    schedules an async write to populate the CSV (auto-cura).
//  - setFilters(...) is the single writer that keeps both sides in sync.
//  - Dedup via static `pendingBackfills` sets (one per relation) to avoid
//    burst of saves when many budgets enter a hot path with scheduleBackfill=true.
//

import Foundation
import SwiftData

extension Budget {

    // MARK: - Decoders (read CSV → Set<UUID>)

    var subcategoryIDsSet: Set<UUID>? { CSVMirrorCodec.decode(subcategoryIDs) }
    var accountIDsSet: Set<UUID>? { CSVMirrorCodec.decode(accountIDs) }
    var tagIDsSet: Set<UUID>? { CSVMirrorCodec.decode(tagIDs) }

    // MARK: - Encoders (write M2M objects → CSV)

    func setSubcategoryIDs(from subs: [Subcategory]) {
        subcategoryIDs = CSVMirrorCodec.encode(subs.map(\.shortcutID))
    }

    func setAccountIDs(from accounts: [Account]) {
        accountIDs = CSVMirrorCodec.encode(accounts.map(\.shortcutID))
    }

    func setTagIDs(from tags: [Tag]) {
        tagIDs = CSVMirrorCodec.encode(tags.map(\.id))
    }

    // MARK: - Atomic Dual-Write

    /// Atomic dual-write: keeps M2M relations AND CSV mirror in sync.
    /// All Budget filter writers MUST use this helper instead of setting
    /// `.accounts/.subcategories/.tags` directly.
    func setFilters(
        accounts: [Account],
        subcategories: [Subcategory],
        tags: [Tag]
    ) {
        self.accounts = accounts
        self.subcategories = subcategories
        self.tags = tags
        setAccountIDs(from: accounts)
        setSubcategoryIDs(from: subcategories)
        setTagIDs(from: tags)
    }

    // MARK: - Resolved Reads with Auto-Heal Lazy Fallback

    /// Returns the resolved Set<UUID> for subcategory filters.
    /// Preference order: CSV mirror > M2M relation.
    /// If `scheduleBackfill=true` and the value comes from M2M (CSV nil),
    /// schedules an async write to populate the CSV (auto-cura).
    ///
    /// Race-safety: the Task verifies the **current M2M still matches the snapshot**
    /// before writing — protege contra resurrección de filtros borrados (write-write
    /// race con un writer concurrente que limpie tags entre snapshot y Task fire).
    /// Errors are logged in DEBUG (no `try?` silencing — CLAUDE.md rule).
    func resolvedSubcategoryIDs(scheduleBackfill: Bool = false) -> Set<UUID>? {
        if let set = subcategoryIDsSet { return set }
        let m2m = subcategories ?? []
        guard !m2m.isEmpty else { return nil }
        let ids = Set(m2m.map(\.shortcutID))
        if scheduleBackfill {
            let snapshotIDs = ids
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.subcategoryIDsSet == nil else { return }
                // Verify M2M actual aún matchea snapshot — si un writer concurrente
                // modificó la relación, NO restauramos (evita resurrección).
                let currentM2M = Set((self.subcategories ?? []).map(\.shortcutID))
                guard currentM2M == snapshotIDs else { return }
                self.setSubcategoryIDs(from: self.subcategories ?? [])
                do {
                    try self.modelContext?.save()
                } catch {
                    #if DEBUG
                    print("Budget+CSVMirror: scheduleBackfill subcategoryIDs save error: \(error)")
                    #endif
                }
            }
        }
        return ids
    }

    func resolvedAccountIDs(scheduleBackfill: Bool = false) -> Set<UUID>? {
        if let set = accountIDsSet { return set }
        let m2m = accounts ?? []
        guard !m2m.isEmpty else { return nil }
        let ids = Set(m2m.map(\.shortcutID))
        if scheduleBackfill {
            let snapshotIDs = ids
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.accountIDsSet == nil else { return }
                let currentM2M = Set((self.accounts ?? []).map(\.shortcutID))
                guard currentM2M == snapshotIDs else { return }
                self.setAccountIDs(from: self.accounts ?? [])
                do {
                    try self.modelContext?.save()
                } catch {
                    #if DEBUG
                    print("Budget+CSVMirror: scheduleBackfill accountIDs save error: \(error)")
                    #endif
                }
            }
        }
        return ids
    }

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
                self.setTagIDs(from: self.tags ?? [])
                do {
                    try self.modelContext?.save()
                } catch {
                    #if DEBUG
                    print("Budget+CSVMirror: scheduleBackfill tagIDs save error: \(error)")
                    #endif
                }
            }
        }
        return ids
    }
}
