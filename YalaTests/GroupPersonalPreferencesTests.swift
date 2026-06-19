//
//  GroupPersonalPreferencesTests.swift
//  YalaTests
//
//  M6: regla "NO defaults universales" eliminó las funciones default account.
//  Solo queda `removeAll(for:)` para limpiar prefs legacy heredadas en leaveGroup.
//

import Foundation
import Testing

@testable import Yala

struct GroupPersonalPreferencesTests {

    @Test func removeAll_idempotentWhenNoKeys() {
        let zoneID = "test-zone-\(UUID().uuidString)"
        // No hay keys (M6+ runtime nunca las setea). Verificar que no crashea.
        GroupPersonalPreferences.removeAll(for: zoneID)
        // Doble invocación: idempotente.
        GroupPersonalPreferences.removeAll(for: zoneID)
    }

    @Test func removeAll_clearsLegacyKeys() {
        // Simula keys legacy escritas por versión pre-M6 (UserDefaults directo).
        let zoneID = "test-zone-\(UUID().uuidString)"
        let prefix = "groupPrefs_\(zoneID)"
        let defaults = UserDefaults.standard
        defaults.set(["USD", "PEN"], forKey: "\(prefix)_currencies")
        defaults.set("Cuenta USD", forKey: "\(prefix)_settlementAccount_USD")
        defaults.set("Cuenta PEN", forKey: "\(prefix)_settlementAccount_PEN")

        GroupPersonalPreferences.removeAll(for: zoneID)

        #expect(defaults.stringArray(forKey: "\(prefix)_currencies") == nil)
        #expect(defaults.string(forKey: "\(prefix)_settlementAccount_USD") == nil)
        #expect(defaults.string(forKey: "\(prefix)_settlementAccount_PEN") == nil)
    }
}
