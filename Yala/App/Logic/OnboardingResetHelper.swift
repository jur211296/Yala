//
//  OnboardingResetHelper.swift
//  Yala
//
//  Limpia preferencias residuales del KV-Store del Apple ID antes de iniciar
//  el onboarding rama A "Soy nuevo". Sin esto, el field userName (y otras prefs
//  visibles) aparecen pre-llenados con valores de instalaciones previas — viola
//  el modelo mental "Soy nuevo = empezar de cero".
//
//  Solo limpia keys seguras cross-device: strings que el guard `!remote.isEmpty`
//  de `PreferenceSyncService.applyRemoteValues` ignora cuando el valor remoto es
//  vacío. NO toca booleans (expensesOnlyMode, etc.) porque escribir `false` al
//  KV-Store sobrescribiría la preferencia en otros devices del mismo Apple ID.
//

import Foundation

@MainActor
enum OnboardingResetHelper {

    /// Keys a limpiar tras tap "Soy nuevo" en el Welcome Chooser. Limitado a
    /// strings que `PreferenceSyncService.applyRemoteValues` filtra cuando el
    /// remote viene vacío (línea 165: `!remote.isEmpty`). Escribir `""` al
    /// KV-Store NO afecta a otros devices.
    private static let safeKeysToClear: [String] = [
        "userName",
        "defaultCurrencyCode",
    ]

    /// Limpia las prefs residuales tanto en `UserDefaults.standard` como en
    /// `NSUbiquitousKeyValueStore.default`. Llamar SOLO desde el callback
    /// del Welcome Chooser cuando el user elige rama A ("Soy nuevo") —
    /// señal explícita de "empezar de cero".
    static func clearResidualPreferencesForFreshStart() {
        let local = UserDefaults.standard
        let iKV = NSUbiquitousKeyValueStore.default

        for key in safeKeysToClear {
            local.removeObject(forKey: key)
            // Escribir "" al KV-Store en lugar de removeObject: el guard
            // `!remote.isEmpty` de applyRemoteValues filtra valores vacíos,
            // así que otros devices del Apple ID NO pierden sus prefs.
            iKV.set("", forKey: key)
        }
        iKV.synchronize()
    }
}
