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

    /// Limpia las prefs residuales tanto en el dominio local de ESTA sesión como en
    /// `NSUbiquitousKeyValueStore.default`. Llamar SOLO desde el callback
    /// del Welcome Chooser cuando el user elige rama A ("Soy nuevo") —
    /// señal explícita de "empezar de cero".
    static func clearResidualPreferencesForFreshStart() {
        // **Hasta el 2026-09-12 esto iba al CAJÓN de la sesión, no al dominio del dueño** (2026-09-07);
        // hoy hay un solo dominio. La mitad iKV de abajo ya
        // estaba protegida y su comentario nombra el motivo; ésta se quedó en `.standard` crudo, así que
        // el barrido era mitad guardado y mitad abierto. En sesión secundaria la visita que elige
        // «empezar de cero» entra SIEMPRE por aquí —`hasExistingData` mide el store de la INVITADA, que
        // nace vacío, y esa es justo la rama que borra— y le dejaba al dueño su nombre y su divisa en
        // blanco. Y sin cura: la reposición del arranque siguiente sale de `readRemoteIKV`, que devuelve
        // `nil` cuando la key no está en el iKV, o sea para un dueño SIN iCloud — que es exactamente el
        // público de la rama «privacidad total».
        //
        // El dominio local es `.standard` para todo el mundo desde el 2026-09-12, cuando se retiró la
        // puerta por sesión. Antes resolvía a `.standard` salvo con una visita dentro, así que para el
        // usuario de siempre esto nunca cambió nada.
        let local = UserDefaults.standard
        // La PUERTA, no el store crudo: en sesión secundaria el iCloud KV es el del DUEÑO, y este
        // barrido le dejaría su nombre y su divisa en blanco en todos sus dispositivos.
        let iKV = OwnerKeyValueStore.shared

        for key in safeKeysToClear {
            local.removeObject(forKey: key)
            // Escribir "" al KV-Store en lugar de removeObject: el guard
            // `!remote.isEmpty` de applyRemoteValues filtra valores vacíos,
            // así que otros devices del Apple ID NO pierden sus prefs.
            iKV.setString("", forKey: key)
        }
        iKV.synchronize()
    }
}
