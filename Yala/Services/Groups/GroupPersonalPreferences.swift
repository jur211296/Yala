//
//  GroupPersonalPreferences.swift
//  Yala
//
//  Per-group personal preferences stored locally (not synced via CloudKit).
//  Each user decides independently whether to auto-create personal records
//  and which account to use for a given group.
//

import Foundation

enum GroupPersonalPreferences {

    private static let defaults = UserDefaults.standard
    private static let prefix = "groupPrefs_"

    // MARK: - Auto Create Transaction

    /// Returns nil if no preference has been set (caller should use fallback).
    static func autoCreateTransaction(for zoneID: String) -> Bool? {
        let key = "\(prefix)\(zoneID)_autoCreate"
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.bool(forKey: key)
    }

    static func setAutoCreateTransaction(_ value: Bool, for zoneID: String) {
        let key = "\(prefix)\(zoneID)_autoCreate"
        defaults.set(value, forKey: key)
    }

    // MARK: - Account Name (per currency)

    /// Get account name for a specific currency in a group.
    /// Falls back to legacy single-account preference for migration.
    static func accountName(for zoneID: String, currencyCode: String) -> String? {
        let key = "\(prefix)\(zoneID)_account_\(currencyCode)"
        if let value = defaults.string(forKey: key) {
            return value
        }
        // Migration fallback: try legacy single-account preference
        return defaultAccountName(for: zoneID)
    }

    /// Set account name for a specific currency in a group.
    static func setAccountName(_ value: String?, for zoneID: String, currencyCode: String) {
        let key = "\(prefix)\(zoneID)_account_\(currencyCode)"
        if let value, !value.isEmpty {
            defaults.set(value, forKey: key)
            trackCurrency(currencyCode, for: zoneID)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    /// Get all account preferences for a group as [currencyCode: accountName].
    static func allAccountPreferences(for zoneID: String, currencies: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for code in currencies {
            if let name = accountName(for: zoneID, currencyCode: code), !name.isEmpty {
                result[code] = name
            }
        }
        return result
    }

    // MARK: - Legacy Default Account Name

    /// Legacy single-account preference. Kept for migration fallback.
    static func defaultAccountName(for zoneID: String) -> String? {
        let key = "\(prefix)\(zoneID)_accountName"
        return defaults.string(forKey: key)
    }

    static func setDefaultAccountName(_ value: String?, for zoneID: String) {
        let key = "\(prefix)\(zoneID)_accountName"
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Currency Tracking

    /// Track which currencies have been configured for cleanup.
    private static func trackCurrency(_ currencyCode: String, for zoneID: String) {
        let key = "\(prefix)\(zoneID)_currencies"
        var currencies = defaults.stringArray(forKey: key) ?? []
        if !currencies.contains(currencyCode) {
            currencies.append(currencyCode)
            defaults.set(currencies, forKey: key)
        }
    }

    private static func trackedCurrencies(for zoneID: String) -> [String] {
        let key = "\(prefix)\(zoneID)_currencies"
        return defaults.stringArray(forKey: key) ?? []
    }

    // MARK: - Cleanup

    /// Remove all preferences for a group (call when leaving/deleting).
    static func removeAll(for zoneID: String) {
        defaults.removeObject(forKey: "\(prefix)\(zoneID)_autoCreate")
        defaults.removeObject(forKey: "\(prefix)\(zoneID)_accountName")

        // Clean per-currency keys
        let currencies = trackedCurrencies(for: zoneID)
        for code in currencies {
            defaults.removeObject(forKey: "\(prefix)\(zoneID)_account_\(code)")
        }
        defaults.removeObject(forKey: "\(prefix)\(zoneID)_currencies")
    }
}
