//
//  SignOutPreferenceHold.swift
//  Yala
//
//  Card ij0i (2026-11-05), ticket `owner-preferences-return-via-ikv-after-private-sign-out`, decisión A de Jürgen del
//  2026-10-08: **tras cerrar la sesión, el iCloud-KV del Apple ID no se aplica hasta que alguien restaure o termine un
//  onboarding.**
//
//  El síntoma: cierro mi sesión para prestar el móvil, la otra persona entra y ve mi nombre y mi moneda. El borrado del
//  cierre (`SwiftDataConfiguration.performSignOutWipeIfArmed`) resetea las preferencias LOCALES, pero el arranque siguiente
//  en `.icloud` las volvía a aplicar desde el iCloud-KV, que es del Apple ID del teléfono y no de la persona.
//
//  **Se arma en los TRES cierres** (privado, solo grupos y nube: los tres pasan por ese hook y dejan el teléfono «recién
//  instalado»), decisión del bot dueño del 2026-11-05 sobre la A de Jürgen. Vive bajo `cloudSync.*` porque el barrido de
//  preferencias del mismo hook (`removeUserPreferenceKeys`) excluye ese prefijo: armada antes del barrido, sobrevive.
//
//  **Se suelta en cuatro sitios, y cada uno tiene su porqué:**
//   · al abrir Restaurar (`ContentView` y `FullModeActivationView`, quienes presentan la pantalla): quien restaura dice
//     que es el dueño del Apple ID, y el resumen del restore necesita su `userName` para ir directo a la app
//     (`ICloudAccountSummary.isFullyPrefilled`). Soltar ahí APLICA en el acto;
//   · al terminar cualquier onboarding (`PreferenceSyncService.signalOnboardingCompleted`): lo elegido ya está escrito
//     en local y, con la puerta abierta, en el KV;
//   · al nacer la sesión privada de «Activar Yala completo» desde solo grupos (`PrivateBirthKeyValueHandover` ya subió
//     lo local);
//   · en `.cloud` (`PreferenceSyncService.bootstrap`): las preferencias bajan del backend, y una retención olvidada ahí
//     bloquearía el KV para siempre si la cuenta vuelve a iCloud.
//
//   · y, como red, en cuanto el onboarding está hecho (`PreferenceSyncService.holdsAppleIDPreferences`): los caminos que
//     lo completan sin `signalOnboardingCompleted` no la dejan puesta para siempre.
//
//  Lo que NO retiene: las señales de vaciado y onboarding del Apple ID, que se siguen leyendo (`checkForRemoteWipeSignal`).
//
//  **Lo que retiene es el ANTES del onboarding, no la vida entera** (es la decisión A al pie de la letra). Terminado el
//  onboarding, lo que éste escribió (nombre, moneda, periodo, idioma) gana porque viaja al KV; lo que no escribió (tema,
//  Panel, avisos) puede llegar del Apple ID como siempre. Y abrir Restaurar suelta aunque la persona luego vuelva atrás:
//  se acepta, porque Restaurar trae por diseño los DATOS del Apple ID, no solo sus preferencias. Residual conocido: con la
//  retención puesta, la migración del Panel ve la configuración del dueño en el KV y no siembra los predeterminados, así
//  que el Panel de quien entra cae al auto-sanado (todo visible); sembrar ahí escribiría los predeterminados en el KV y
//  pisaría el Panel del dueño en sus otros dispositivos (review del lote N4, 2026-11-05).
//

import Foundation

nonisolated enum SignOutPreferenceHold {

    static let key = "cloudSync.signOutPreferenceHold"

    static func isArmed(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func arm(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    /// `true` si estaba armada: quien suelta decide con eso si tiene que aplicar algo ahora.
    @discardableResult
    static func release(_ defaults: UserDefaults = .standard) -> Bool {
        guard isArmed(defaults) else { return false }
        defaults.removeObject(forKey: key)
        return true
    }
}
