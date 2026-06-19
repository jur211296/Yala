//
//  TagDisplayResolver.swift
//  Yala
//
//  Static helper that resolves display Tag objects for a record using the
//  CSV-mirror SSOT + an injected `[UUID: Tag]` catalog.
//
//  Flow per call:
//  1. `record.resolvedTagIDs(scheduleBackfill: true)` → CSV first, M2M fallback
//     with async auto-heal.
//  2. `compactMap { catalog[$0] }` resolves UUIDs to Tag objects, silently
//     dropping orphan UUIDs (Tag deleted but CSV not yet re-encoded).
//  3. Optional `prefix(limit)` for display chips (typically 3 in Rows).
//

import Foundation

enum TagDisplayResolver {

    static func tags(
        for transaction: TransactionItem,
        catalog: [UUID: Tag],
        limit: Int? = nil
    ) -> [Tag] {
        resolve(
            ids: transaction.resolvedTagIDs(scheduleBackfill: true) ?? [],
            catalog: catalog,
            limit: limit
        )
    }

    static func tags(
        for draft: InboxDraft,
        catalog: [UUID: Tag],
        limit: Int? = nil
    ) -> [Tag] {
        resolve(
            ids: draft.resolvedTagIDs(scheduleBackfill: true) ?? [],
            catalog: catalog,
            limit: limit
        )
    }

    static func tags(
        for favorite: FavoritePayment,
        catalog: [UUID: Tag],
        limit: Int? = nil
    ) -> [Tag] {
        resolve(
            ids: favorite.resolvedTagIDs(scheduleBackfill: true) ?? [],
            catalog: catalog,
            limit: limit
        )
    }

    static func tags(
        for payment: ScheduledPayment,
        catalog: [UUID: Tag],
        limit: Int? = nil
    ) -> [Tag] {
        resolve(
            ids: payment.resolvedTagIDs(scheduleBackfill: true) ?? [],
            catalog: catalog,
            limit: limit
        )
    }

    // MARK: - Pure helper (testable without SwiftData)

    /// Pure resolution: ids → Tags via catalog, drop orphans, optional limit.
    /// Order is by UUID stable iteration of the set (display order is not
    /// guaranteed — chips display in any visual order anyway).
    static func resolve(
        ids: Set<UUID>,
        catalog: [UUID: Tag],
        limit: Int? = nil
    ) -> [Tag] {
        let resolved = ids.compactMap { catalog[$0] }
        if let limit, resolved.count > limit {
            return Array(resolved.prefix(limit))
        }
        return resolved
    }
}
