//
//  SplitGroupDeduplicationService.swift
//  Yala
//
//  Removes duplicate SplitGroup records sharing the same `cloudKitZoneID`.
//  Same shape as `CategoryDeduplicationService` / `NotificationService.deduplicateNotifications`.
//
//  Why duplicates appear: a SplitGroup can be created via two paths with distinct
//  `id` UUIDs but identical `cloudKitZoneID`:
//    (a) CloudKit sync via `SplitSyncManager.applyGroupMeta` (id from `record.recordID`)
//    (b) Local create / accept-share path (id is fresh `UUID()`)
//  Members/Expenses/Settlements link by `groupZoneID: String` (no @Relationship),
//  so deleting a duplicate SplitGroup does not affect them — they continue resolving
//  to the canonical group via the zoneID.
//
//  Decision: keeper = oldest by `createdAt` (most likely the original).
//  Cascade-delete CloudKit is accepted: the duplicate's record is removed from CK
//  via SwiftData CKSyncEngine; other devices observe the delete and converge.
//

import Foundation
import SwiftData

@MainActor
enum SplitGroupDeduplicationService {

    /// Pure-logic plan — testable without `ModelContext` (R8: avoid `makeTestContext()`).
    struct DedupPlan: Equatable {
        let toKeepIDs: [UUID]
        let toDeleteIDs: [UUID]
        let duplicateZoneCounts: [DuplicateZone]

        struct DuplicateZone: Equatable {
            let zoneID: String
            let count: Int
        }
    }

    /// Computes which SplitGroups to keep / delete given an array. Pure function.
    static func computeDedupPlan(groups: [SplitGroup]) -> DedupPlan {
        let byZone = Dictionary(grouping: groups, by: \.cloudKitZoneID)
        var toKeep: [UUID] = []
        var toDelete: [UUID] = []
        var dupZones: [DedupPlan.DuplicateZone] = []

        for (zoneID, dups) in byZone {
            let sorted = dups.sorted { $0.createdAt < $1.createdAt }
            guard let keeper = sorted.first else { continue }
            toKeep.append(keeper.id)
            if dups.count > 1 {
                toDelete.append(contentsOf: sorted.dropFirst().map(\.id))
                dupZones.append(.init(zoneID: zoneID, count: dups.count))
            }
        }
        return DedupPlan(toKeepIDs: toKeep, toDeleteIDs: toDelete, duplicateZoneCounts: dupZones)
    }

    /// Boot-time cleanup. Idempotent — no-op when no duplicates.
    /// - Returns: number of duplicate SplitGroup records removed.
    @discardableResult
    static func deduplicateSplitGroups(in context: ModelContext) -> Int {
        // Gate de quiescencia: aunque borra `SplitGroup` (store de grupos), comparte el MISMO
        // `NSPersistentStoreCoordinator` que el store personal → un `save()` durante el import del
        // restore dispara el `_assertionFailure`. Diferir (idempotente: re-corre en bootstrap/quiescencia).
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("SplitGroupDedup.deduplicate", "import not quiescent")
            return 0
        }
        let groups: [SplitGroup]
        do {
            groups = try context.fetch(FetchDescriptor<SplitGroup>())
        } catch {
            #if DEBUG
            print("SplitGroupDedup: fetch failed: \(error)")
            #endif
            return 0
        }

        let plan = computeDedupPlan(groups: groups)
        guard !plan.toDeleteIDs.isEmpty else { return 0 }

        let toDeleteSet = Set(plan.toDeleteIDs)
        for group in groups where toDeleteSet.contains(group.id) {
            context.delete(group)
        }

        do {
            SaveBreadcrumb.willSave("SplitGroupDedup.deduplicate")
            try context.save()
            SaveBreadcrumb.didSave("SplitGroupDedup.deduplicate")
            #if DEBUG
            print("SplitGroupDedup: removed \(plan.toDeleteIDs.count) duplicates across \(plan.duplicateZoneCounts.count) zones")
            #endif
            for dup in plan.duplicateZoneCounts {
                #if DEBUG
                print("SplitGroupDedup:   zone=\(dup.zoneID) count=\(dup.count)")
                #endif
                MetricsService.cloudkitDuplicateDetected(
                    model: "SplitGroup",
                    count: dup.count,
                    context: .bootCleanup,
                    keySuffix: dup.zoneID
                )
            }
        } catch {
            #if DEBUG
            print("SplitGroupDedup: save failed: \(error)")
            #endif
        }
        return plan.toDeleteIDs.count
    }
}
