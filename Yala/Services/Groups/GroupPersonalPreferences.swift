//
//  GroupPersonalPreferences.swift
//  Yala
//
//  Per-group personal preferences stored locally (not synced via CloudKit).
//
//  M6: regla "NO defaults universales" — eliminadas las funciones de default account
//  para settlements (form/draft sheets ahora siempre piden cuenta al user).
//
//  `removeAll(for:)` se mantiene para limpiar prefs legacy heredadas de versiones
//  pre-M6 al hacer leaveGroup/deleteGroup. Idempotente.
//

import Foundation

enum GroupPersonalPreferences {

    private static let defaults = UserDefaults.standard
    private static let prefix = "groupPrefs_"

    // MARK: - Cleanup (legacy keys + futuras prefs)

    /// Elimina todas las preferencias asociadas a un grupo (call al leave/delete).
    /// Idempotente: si no hay keys (M6+ runtime), no hace nada.
    static func removeAll(for zoneID: String) {
        // Limpia tracking legacy de currencies (pre-M6).
        let currenciesKey = "\(prefix)\(zoneID)_currencies"
        if let currencies = defaults.stringArray(forKey: currenciesKey) {
            for code in currencies {
                defaults.removeObject(forKey: "\(prefix)\(zoneID)_settlementAccount_\(code)")
            }
            defaults.removeObject(forKey: currenciesKey)
        }
    }
}
