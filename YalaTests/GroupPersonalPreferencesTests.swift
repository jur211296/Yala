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

    // MARK: - Per-Currency Account Name

    @Test func perCurrencyAccount_nilByDefault() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        #expect(GroupPersonalPreferences.accountName(for: zoneID, currencyCode: "USD") == nil)
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func perCurrencyAccount_setAndRead() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        GroupPersonalPreferences.setAccountName("Checking USD", for: zoneID, currencyCode: "USD")
        #expect(GroupPersonalPreferences.accountName(for: zoneID, currencyCode: "USD") == "Checking USD")
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func perCurrencyAccount_independentPerCurrency() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        GroupPersonalPreferences.setAccountName("Cuenta USD", for: zoneID, currencyCode: "USD")
        GroupPersonalPreferences.setAccountName("Cuenta PEN", for: zoneID, currencyCode: "PEN")

        #expect(GroupPersonalPreferences.accountName(for: zoneID, currencyCode: "USD") == "Cuenta USD")
        #expect(GroupPersonalPreferences.accountName(for: zoneID, currencyCode: "PEN") == "Cuenta PEN")
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func perCurrencyAccount_fallsBackToLegacy() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        // Set legacy preference only
        GroupPersonalPreferences.setDefaultAccountName("Legacy Account", for: zoneID)

        // Per-currency lookup should fall back to legacy
        #expect(GroupPersonalPreferences.accountName(for: zoneID, currencyCode: "USD") == "Legacy Account")
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func perCurrencyAccount_perCurrencyOverridesLegacy() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        GroupPersonalPreferences.setDefaultAccountName("Legacy Account", for: zoneID)
        GroupPersonalPreferences.setAccountName("USD Account", for: zoneID, currencyCode: "USD")

        // Per-currency takes priority over legacy
        #expect(GroupPersonalPreferences.accountName(for: zoneID, currencyCode: "USD") == "USD Account")
        // Other currencies still fall back to legacy
        #expect(GroupPersonalPreferences.accountName(for: zoneID, currencyCode: "PEN") == "Legacy Account")
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func allAccountPreferences_returnsOnlySet() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        GroupPersonalPreferences.setAccountName("USD Acc", for: zoneID, currencyCode: "USD")

        let prefs = GroupPersonalPreferences.allAccountPreferences(for: zoneID, currencies: ["USD", "PEN", "EUR"])
        // USD has explicit pref, PEN/EUR will get nil from per-currency but fall back to legacy (which is nil too)
        #expect(prefs["USD"] == "USD Acc")
        #expect(prefs["PEN"] == nil)
        #expect(prefs["EUR"] == nil)
        GroupPersonalPreferences.removeAll(for: zoneID)
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

    @Test func removeAll_clearsPerCurrencyKeys() {
        let zoneID = "test-zone-\(UUID().uuidString)"

        GroupPersonalPreferences.setAccountName("USD Acc", for: zoneID, currencyCode: "USD")
        GroupPersonalPreferences.setAccountName("PEN Acc", for: zoneID, currencyCode: "PEN")

        GroupPersonalPreferences.removeAll(for: zoneID)

        // Per-currency keys should be cleaned
        let key1 = "groupPrefs_\(zoneID)_account_USD"
        let key2 = "groupPrefs_\(zoneID)_account_PEN"
        #expect(UserDefaults.standard.string(forKey: key1) == nil)
        #expect(UserDefaults.standard.string(forKey: key2) == nil)
    }
}
