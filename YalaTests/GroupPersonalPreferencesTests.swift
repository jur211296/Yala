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

    // MARK: - Default Settlement Account (per currency)

    @Test func settlementAccount_nilByDefault() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        #expect(GroupPersonalPreferences.defaultSettlementAccount(for: zoneID, currencyCode: "USD") == nil)
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func settlementAccount_setAndRead() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        GroupPersonalPreferences.setDefaultSettlementAccount("Cuenta USD", for: zoneID, currencyCode: "USD")
        #expect(GroupPersonalPreferences.defaultSettlementAccount(for: zoneID, currencyCode: "USD") == "Cuenta USD")
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func settlementAccount_setNil_removes() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        GroupPersonalPreferences.setDefaultSettlementAccount("Cuenta USD", for: zoneID, currencyCode: "USD")
        GroupPersonalPreferences.setDefaultSettlementAccount(nil, for: zoneID, currencyCode: "USD")
        #expect(GroupPersonalPreferences.defaultSettlementAccount(for: zoneID, currencyCode: "USD") == nil)
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func settlementAccount_independentPerCurrency() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        GroupPersonalPreferences.setDefaultSettlementAccount("Cuenta USD", for: zoneID, currencyCode: "USD")
        GroupPersonalPreferences.setDefaultSettlementAccount("Cuenta PEN", for: zoneID, currencyCode: "PEN")

        #expect(GroupPersonalPreferences.defaultSettlementAccount(for: zoneID, currencyCode: "USD") == "Cuenta USD")
        #expect(GroupPersonalPreferences.defaultSettlementAccount(for: zoneID, currencyCode: "PEN") == "Cuenta PEN")
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    // MARK: - Zone Isolation

    @Test func differentZones_independentValues() {
        let zone1 = "test-zone-\(UUID().uuidString)"
        let zone2 = "test-zone-\(UUID().uuidString)"

        GroupPersonalPreferences.setDefaultSettlementAccount("Acc1", for: zone1, currencyCode: "USD")
        GroupPersonalPreferences.setDefaultSettlementAccount("Acc2", for: zone2, currencyCode: "USD")

        #expect(GroupPersonalPreferences.defaultSettlementAccount(for: zone1, currencyCode: "USD") == "Acc1")
        #expect(GroupPersonalPreferences.defaultSettlementAccount(for: zone2, currencyCode: "USD") == "Acc2")

        GroupPersonalPreferences.removeAll(for: zone1)
        GroupPersonalPreferences.removeAll(for: zone2)
    }

    // MARK: - Remove All

    @Test func removeAll_clearsAllSettlementKeys() {
        let zoneID = "test-zone-\(UUID().uuidString)"

        GroupPersonalPreferences.setDefaultSettlementAccount("USD Acc", for: zoneID, currencyCode: "USD")
        GroupPersonalPreferences.setDefaultSettlementAccount("PEN Acc", for: zoneID, currencyCode: "PEN")

        GroupPersonalPreferences.removeAll(for: zoneID)

        #expect(GroupPersonalPreferences.defaultSettlementAccount(for: zoneID, currencyCode: "USD") == nil)
        #expect(GroupPersonalPreferences.defaultSettlementAccount(for: zoneID, currencyCode: "PEN") == nil)
    }
}
