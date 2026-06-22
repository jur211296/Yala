//
//  GroupBridgePreferenceDeduplicationService.swift
//  Yala
//
//  Removes duplicate `GroupBridgePreference` records sharing the same `groupZoneID`.
//  Same shape as `SplitGroupDeduplicationService` / `CategoryDeduplicationService`.
//
//  Why duplicates appear: SwiftData + CloudKit private DB sync race entre devices
//  cuando dos devices crean el override para el mismo grupo simultáneamente
//  (poco probable pero posible). Keeper = oldest by `createdAt`.
//

import Foundation
import SwiftData

@MainActor
enum GroupBridgePreferenceDeduplicationService {

    /// Pure-logic plan — testable without `ModelContext` (R8).
    struct DedupPlan: Equatable {
        let toKeepIDs: [UUID]
        let toDeleteIDs: [UUID]
        let duplicateZoneCounts: [DuplicateZone]

        struct DuplicateZone: Equatable {
            let zoneID: String
            let count: Int
        }
    }

    /// Computes which records to keep / delete given an array. Pure function.
    static func computeDedupPlan(records: [GroupBridgePreference]) -> DedupPlan {
        let byZone = Dictionary(grouping: records, by: \.groupZoneID)
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
    /// - Returns: number of duplicate records removed.
    @discardableResult
    static func deduplicate(in context: ModelContext) -> Int {
        // Gate de quiescencia: `GroupBridgePreference` vive en el store personal (CloudKit private) →
        // su `save()` durante el import del restore dispara el `_assertionFailure`. Diferir (idempotente).
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("GroupBridgePrefDedup.deduplicate", "import not quiescent")
            return 0
        }
        let records: [GroupBridgePreference]
        do {
            records = try context.fetch(FetchDescriptor<GroupBridgePreference>())
        } catch {
            #if DEBUG
            print("GroupBridgePrefDedup: fetch failed: \(error)")
            #endif
            return 0
        }

        let plan = computeDedupPlan(records: records)
        guard !plan.toDeleteIDs.isEmpty else { return 0 }

        let toDeleteSet = Set(plan.toDeleteIDs)
        for record in records where toDeleteSet.contains(record.id) {
            context.delete(record)
        }

        do {
            SaveBreadcrumb.willSave("GroupBridgePrefDedup.deduplicate")
            try context.save()
            SaveBreadcrumb.didSave("GroupBridgePrefDedup.deduplicate")
            #if DEBUG
            print("GroupBridgePrefDedup: removed \(plan.toDeleteIDs.count) duplicates across \(plan.duplicateZoneCounts.count) zones")
            #endif
            for dup in plan.duplicateZoneCounts {
                TelemetryService.cloudkitDuplicateDetected(
                    model: "GroupBridgePreference",
                    count: dup.count,
                    context: .bootCleanup,
                    keySuffix: dup.zoneID
                )
            }
        } catch {
            #if DEBUG
            print("GroupBridgePrefDedup: save failed: \(error)")
            #endif
        }
        return plan.toDeleteIDs.count
    }
}
