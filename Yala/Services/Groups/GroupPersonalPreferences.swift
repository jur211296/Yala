//
//  GroupPersonalPreferences.swift
//  Yala
//
//  Per-group personal preferences stored locally (not synced via CloudKit).
//  Tracks default settlement account per (zone, currency) pair for Caso C/D.
//

import Foundation

enum GroupPersonalPreferences {

    private static let defaults = UserDefaults.standard
    private static let prefix = "groupPrefs_"

    // MARK: - Default Settlement Account (A0-Bridge, per currency)

    /// Devuelve la cuenta default para liquidaciones (caso C/D) en este grupo + moneda.
    /// Persistida tras la primera liquidación con cuenta seleccionada (form proactivo).
    /// Próxima liquidación en mismo grupo+moneda: preselect en form/draft.
    static func defaultSettlementAccount(for zoneID: String, currencyCode: String) -> String? {
        let key = "\(prefix)\(zoneID)_settlementAccount_\(currencyCode)"
        return defaults.string(forKey: key)
    }

    /// Persiste la cuenta usada en una liquidación para preselect en futuros casos.
    static func setDefaultSettlementAccount(_ value: String?, for zoneID: String, currencyCode: String) {
        let key = "\(prefix)\(zoneID)_settlementAccount_\(currencyCode)"
        if let value, !value.isEmpty {
            defaults.set(value, forKey: key)
            trackCurrency(currencyCode, for: zoneID)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Currency Tracking

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
        let currencies = trackedCurrencies(for: zoneID)
        for code in currencies {
            defaults.removeObject(forKey: "\(prefix)\(zoneID)_settlementAccount_\(code)")
        }
        defaults.removeObject(forKey: "\(prefix)\(zoneID)_currencies")
    }
}
