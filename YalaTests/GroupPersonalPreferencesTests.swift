//
//  GroupPersonalPreferencesTests.swift
//  YalaTests
//
//  Unit tests for GroupPersonalPreferences UserDefaults storage.
//

import Foundation
import Testing

@testable import Yala

struct GroupPersonalPreferencesTests {

    // Use unique zone IDs per test to avoid cross-test interference.

    // MARK: - Auto Create Transaction

    @Test func autoCreate_nilByDefault() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        let result = GroupPersonalPreferences.autoCreateTransaction(for: zoneID)
        #expect(result == nil)
        // Cleanup
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func autoCreate_setAndRead_true() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        GroupPersonalPreferences.setAutoCreateTransaction(true, for: zoneID)
        #expect(GroupPersonalPreferences.autoCreateTransaction(for: zoneID) == true)
        // Cleanup
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func autoCreate_setAndRead_false() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        GroupPersonalPreferences.setAutoCreateTransaction(false, for: zoneID)
        #expect(GroupPersonalPreferences.autoCreateTransaction(for: zoneID) == false)
        // Cleanup
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    // MARK: - Default Account Name

    @Test func accountName_nilByDefault() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        #expect(GroupPersonalPreferences.defaultAccountName(for: zoneID) == nil)
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func accountName_setAndRead() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        GroupPersonalPreferences.setDefaultAccountName("Efectivo", for: zoneID)
        #expect(GroupPersonalPreferences.defaultAccountName(for: zoneID) == "Efectivo")
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func accountName_setNil_removes() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        GroupPersonalPreferences.setDefaultAccountName("Efectivo", for: zoneID)
        GroupPersonalPreferences.setDefaultAccountName(nil, for: zoneID)
        #expect(GroupPersonalPreferences.defaultAccountName(for: zoneID) == nil)
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    // MARK: - Zone Isolation

    @Test func differentZones_independentValues() {
        let zone1 = "test-zone-\(UUID().uuidString)"
        let zone2 = "test-zone-\(UUID().uuidString)"

        GroupPersonalPreferences.setAutoCreateTransaction(true, for: zone1)
        GroupPersonalPreferences.setAutoCreateTransaction(false, for: zone2)

        #expect(GroupPersonalPreferences.autoCreateTransaction(for: zone1) == true)
        #expect(GroupPersonalPreferences.autoCreateTransaction(for: zone2) == false)

        GroupPersonalPreferences.removeAll(for: zone1)
        GroupPersonalPreferences.removeAll(for: zone2)
    }

    // MARK: - Remove All

    @Test func removeAll_clearsEverything() {
        let zoneID = "test-zone-\(UUID().uuidString)"

        GroupPersonalPreferences.setAutoCreateTransaction(false, for: zoneID)
        GroupPersonalPreferences.setDefaultAccountName("BCP", for: zoneID)

        GroupPersonalPreferences.removeAll(for: zoneID)

        #expect(GroupPersonalPreferences.autoCreateTransaction(for: zoneID) == nil)
        #expect(GroupPersonalPreferences.defaultAccountName(for: zoneID) == nil)
    }
}
