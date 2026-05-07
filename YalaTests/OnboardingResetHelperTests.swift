//
//  OnboardingResetHelperTests.swift
//  YalaTests
//
//  Tests del cleanup de prefs residuales pre-onboarding rama A.
//  No se puede inyectar mock UserDefaults porque el helper usa `.standard` y
//  `.default` directamente — los tests verifican el efecto end-to-end con
//  isolated keys (prefijos de test).
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct OnboardingResetHelperTests {

    // MARK: - Helpers

    /// Setea valores en local + KV-Store antes de ejecutar el helper para
    /// validar que el cleanup los borra correctamente.
    private func seed(local: UserDefaults, iKV: NSUbiquitousKeyValueStore) {
        local.set("Test", forKey: "userName")
        local.set("USD", forKey: "defaultCurrencyCode")
        iKV.set("Test", forKey: "userName")
        iKV.set("USD", forKey: "defaultCurrencyCode")
    }

    private func cleanup(local: UserDefaults, iKV: NSUbiquitousKeyValueStore) {
        local.removeObject(forKey: "userName")
        local.removeObject(forKey: "defaultCurrencyCode")
        iKV.removeObject(forKey: "userName")
        iKV.removeObject(forKey: "defaultCurrencyCode")
    }

    // MARK: - Cleanup behavior

    @Test func clearResidualPreferences_removesUserNameFromLocal() {
        let local = UserDefaults.standard
        let iKV = NSUbiquitousKeyValueStore.default
        seed(local: local, iKV: iKV)
        defer { cleanup(local: local, iKV: iKV) }

        OnboardingResetHelper.clearResidualPreferencesForFreshStart()

        #expect(local.string(forKey: "userName") == nil)
    }

    @Test func clearResidualPreferences_removesDefaultCurrencyCodeFromLocal() {
        let local = UserDefaults.standard
        let iKV = NSUbiquitousKeyValueStore.default
        seed(local: local, iKV: iKV)
        defer { cleanup(local: local, iKV: iKV) }

        OnboardingResetHelper.clearResidualPreferencesForFreshStart()

        #expect(local.string(forKey: "defaultCurrencyCode") == nil)
    }

    @Test func clearResidualPreferences_writesEmptyToKVStoreForCrossDeviceSafety() {
        // Escribir "" al KV-Store es la convención: applyRemoteValues filtra
        // empty strings (`!remote.isEmpty`) → otros devices no pierden sus prefs.
        let local = UserDefaults.standard
        let iKV = NSUbiquitousKeyValueStore.default
        seed(local: local, iKV: iKV)
        defer { cleanup(local: local, iKV: iKV) }

        OnboardingResetHelper.clearResidualPreferencesForFreshStart()

        #expect(iKV.string(forKey: "userName") == "")
        #expect(iKV.string(forKey: "defaultCurrencyCode") == "")
    }

    @Test func clearResidualPreferences_doesNotTouchExpensesOnlyMode() {
        // Bool prefs NO se limpian: PreferenceSyncService.applyRemoteValues
        // para Bool (`if iKV.object(...) != nil`) NO filtra `false`, por lo
        // que escribir false al KV-Store override la pref en otros devices.
        let local = UserDefaults.standard
        let iKV = NSUbiquitousKeyValueStore.default
        local.set(true, forKey: "expensesOnlyMode")
        iKV.set(true, forKey: "expensesOnlyMode")
        defer {
            local.removeObject(forKey: "expensesOnlyMode")
            iKV.removeObject(forKey: "expensesOnlyMode")
        }

        OnboardingResetHelper.clearResidualPreferencesForFreshStart()

        #expect(local.bool(forKey: "expensesOnlyMode") == true)
        #expect(iKV.bool(forKey: "expensesOnlyMode") == true)
    }
}
