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

    // MARK: - Default Account Name

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

    // MARK: - Cleanup

    /// Remove all preferences for a group (call when leaving/deleting).
    static func removeAll(for zoneID: String) {
        let autoKey = "\(prefix)\(zoneID)_autoCreate"
        let accountKey = "\(prefix)\(zoneID)_accountName"
        defaults.removeObject(forKey: autoKey)
        defaults.removeObject(forKey: accountKey)
    }
}
