//
//  GroupBridgePreferenceDedupPlanTests.swift
//  YalaTests
//
//  Pure-logic tests para `GroupBridgePreferenceDeduplicationService.computeDedupPlan`.
//  Sin ModelContext (regla R8) — usa instancias directas de `@Model` con `init`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Bridge opt-out — dedup plan")
@MainActor
struct GroupBridgePreferenceDedupPlanTests {

    @Test
    func emptyInput_returnsEmptyPlan() {
        let plan = GroupBridgePreferenceDeduplicationService.computeDedupPlan(records: [])
        #expect(plan.toKeepIDs.isEmpty)
        #expect(plan.toDeleteIDs.isEmpty)
        #expect(plan.duplicateZoneCounts.isEmpty)
    }

    @Test
    func noDuplicates_keepsAll() {
        let a = GroupBridgePreference(groupZoneID: "zone-1", bridgeOverride: true)
        let b = GroupBridgePreference(groupZoneID: "zone-2", bridgeOverride: false)
        let plan = GroupBridgePreferenceDeduplicationService.computeDedupPlan(records: [a, b])
        #expect(Set(plan.toKeepIDs) == Set([a.id, b.id]))
        #expect(plan.toDeleteIDs.isEmpty)
        #expect(plan.duplicateZoneCounts.isEmpty)
    }

    @Test
    func duplicatesInSameZone_keepsOldest() {
        let earlier = GroupBridgePreference(groupZoneID: "zone-X", bridgeOverride: nil)
        earlier.createdAt = Date(timeIntervalSince1970: 1000)
        let later = GroupBridgePreference(groupZoneID: "zone-X", bridgeOverride: false)
        later.createdAt = Date(timeIntervalSince1970: 2000)
        let plan = GroupBridgePreferenceDeduplicationService.computeDedupPlan(records: [later, earlier])
        #expect(plan.toKeepIDs == [earlier.id])
        #expect(plan.toDeleteIDs == [later.id])
        #expect(plan.duplicateZoneCounts.count == 1)
        #expect(plan.duplicateZoneCounts.first?.zoneID == "zone-X")
        #expect(plan.duplicateZoneCounts.first?.count == 2)
    }

    @Test
    func multipleDuplicateZones_handledIndependently() {
        let a1 = GroupBridgePreference(groupZoneID: "zone-A", bridgeOverride: true)
        a1.createdAt = Date(timeIntervalSince1970: 100)
        let a2 = GroupBridgePreference(groupZoneID: "zone-A", bridgeOverride: false)
        a2.createdAt = Date(timeIntervalSince1970: 200)
        let b1 = GroupBridgePreference(groupZoneID: "zone-B", bridgeOverride: true)
        b1.createdAt = Date(timeIntervalSince1970: 50)
        let b2 = GroupBridgePreference(groupZoneID: "zone-B", bridgeOverride: nil)
        b2.createdAt = Date(timeIntervalSince1970: 75)
        let plan = GroupBridgePreferenceDeduplicationService.computeDedupPlan(records: [a2, a1, b2, b1])
        #expect(Set(plan.toKeepIDs) == Set([a1.id, b1.id]))
        #expect(Set(plan.toDeleteIDs) == Set([a2.id, b2.id]))
        #expect(plan.duplicateZoneCounts.count == 2)
    }
}
