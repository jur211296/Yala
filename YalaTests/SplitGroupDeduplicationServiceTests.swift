//
//  SplitGroupDeduplicationServiceTests.swift
//  YalaTests
//
//  Pure-logic tests for SplitGroupDeduplicationService.computeDedupPlan.
//  Avoids `makeTestContext()` per R8 (CloudKit container race crashes the runner).
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
struct SplitGroupDeduplicationServiceTests {

    // R8: builds @Model directly without ModelContext.insert — properties and
    // persistentModelID are valid without a context, and avoids the CloudKit race
    // that crashes `makeTestContext()`.
    private func makeGroup(zoneID: String, createdAt: Date) -> SplitGroup {
        let g = SplitGroup()
        g.cloudKitZoneID = zoneID
        g.createdAt = createdAt
        return g
    }

    @MainActor @Test func computeDedupPlan_emptyArray_returnsEmptyPlan() {
        let plan = SplitGroupDeduplicationService.computeDedupPlan(groups: [])
        #expect(plan.toKeepIDs.isEmpty)
        #expect(plan.toDeleteIDs.isEmpty)
        #expect(plan.duplicateZoneCounts.isEmpty)
    }

    @MainActor @Test func computeDedupPlan_noDuplicates_keepsAll() {
        let g1 = makeGroup(zoneID: "Zone-A", createdAt: Date(timeIntervalSince1970: 100))
        let g2 = makeGroup(zoneID: "Zone-B", createdAt: Date(timeIntervalSince1970: 200))
        let g3 = makeGroup(zoneID: "Zone-C", createdAt: Date(timeIntervalSince1970: 300))

        let plan = SplitGroupDeduplicationService.computeDedupPlan(groups: [g1, g2, g3])
        #expect(plan.toKeepIDs.count == 3)
        #expect(plan.toDeleteIDs.isEmpty)
        #expect(plan.duplicateZoneCounts.isEmpty)
    }

    @MainActor @Test func computeDedupPlan_oneDuplicateZone_keepsOldestByCreatedAt() {
        let older = makeGroup(zoneID: "Zone-A", createdAt: Date(timeIntervalSince1970: 100))
        let newer = makeGroup(zoneID: "Zone-A", createdAt: Date(timeIntervalSince1970: 200))

        let plan = SplitGroupDeduplicationService.computeDedupPlan(groups: [newer, older])

        #expect(plan.toKeepIDs == [older.id])
        #expect(plan.toDeleteIDs == [newer.id])
        #expect(plan.duplicateZoneCounts.count == 1)
        #expect(plan.duplicateZoneCounts.first?.zoneID == "Zone-A")
        #expect(plan.duplicateZoneCounts.first?.count == 2)
    }

    @MainActor @Test func computeDedupPlan_threeDuplicatesSameZone_keepsOnlyOldest() {
        let oldest = makeGroup(zoneID: "Zone-A", createdAt: Date(timeIntervalSince1970: 100))
        let middle = makeGroup(zoneID: "Zone-A", createdAt: Date(timeIntervalSince1970: 200))
        let newest = makeGroup(zoneID: "Zone-A", createdAt: Date(timeIntervalSince1970: 300))

        let plan = SplitGroupDeduplicationService.computeDedupPlan(groups: [middle, newest, oldest])

        #expect(plan.toKeepIDs == [oldest.id])
        #expect(Set(plan.toDeleteIDs) == Set([middle.id, newest.id]))
        #expect(plan.duplicateZoneCounts.count == 1)
        #expect(plan.duplicateZoneCounts.first?.count == 3)
    }

    @MainActor @Test func computeDedupPlan_multipleZonesWithDuplicates_correctCounts() {
        let a1 = makeGroup(zoneID: "Zone-A", createdAt: Date(timeIntervalSince1970: 100))
        let a2 = makeGroup(zoneID: "Zone-A", createdAt: Date(timeIntervalSince1970: 200))
        let b1 = makeGroup(zoneID: "Zone-B", createdAt: Date(timeIntervalSince1970: 150))
        let b2 = makeGroup(zoneID: "Zone-B", createdAt: Date(timeIntervalSince1970: 250))
        let c1 = makeGroup(zoneID: "Zone-C", createdAt: Date(timeIntervalSince1970: 50))

        let plan = SplitGroupDeduplicationService.computeDedupPlan(groups: [a1, a2, b1, b2, c1])

        #expect(plan.toKeepIDs.count == 3)        // 1 per zone
        #expect(plan.toDeleteIDs.count == 2)      // 1 per duplicated zone
        #expect(plan.duplicateZoneCounts.count == 2)

        let keepSet = Set(plan.toKeepIDs)
        #expect(keepSet.contains(a1.id))           // oldest in A
        #expect(keepSet.contains(b1.id))           // oldest in B
        #expect(keepSet.contains(c1.id))           // only one in C

        let deleteSet = Set(plan.toDeleteIDs)
        #expect(deleteSet.contains(a2.id))
        #expect(deleteSet.contains(b2.id))
    }

    @MainActor @Test func computeDedupPlan_duplicateZoneCountsTracksZoneIDs() {
        let a1 = makeGroup(zoneID: "Zone-A", createdAt: Date(timeIntervalSince1970: 100))
        let a2 = makeGroup(zoneID: "Zone-A", createdAt: Date(timeIntervalSince1970: 200))
        let b1 = makeGroup(zoneID: "Zone-B", createdAt: Date(timeIntervalSince1970: 150))

        let plan = SplitGroupDeduplicationService.computeDedupPlan(groups: [a1, a2, b1])

        #expect(plan.duplicateZoneCounts.count == 1)
        let dup = plan.duplicateZoneCounts.first
        #expect(dup?.zoneID == "Zone-A")
        #expect(dup?.count == 2)
    }
}
