//
//  WhatsNewLaunchLogic.swift
//  Yala
//
//  Cuándo sale la hoja de Novedades: SOLO al actualizar (decisión de Jürgen, 16-oct-2026).
//
//  Dos reglas, y las dos se leen de `lastSeenAppVersion` (por dispositivo, no se sincroniza):
//
//  1. **Un dispositivo que arranca sin el onboarding hecho estrena Yala en ESTA versión.** Su versión
//     se da por vista en ese mismo arranque, antes de enseñar nada. Así una instalación nueva no ve
//     Novedades al terminar el onboarding ni en el arranque siguiente. El criterio es el onboarding
//     y no «`lastSeenAppVersion` vacío»: quien usó la 2.0 y nunca llegó a ver su hoja (cerró la app
//     tras el alta, o la oferta de prueba se llevó el turno) también lo tiene vacío, y ése SÍ
//     actualiza y tiene que verla.
//  2. **Se compara major.minor, no la versión entera.** Un hotfix (2.1.1 sobre 2.1) no trae
//     novedades nuevas: la entrada de `WhatsNewConfig` es la misma, y comparando la versión entera
//     la hoja volvía a salir en cada hotfix.
//

import Foundation

nonisolated enum WhatsNewLaunchLogic {

    /// La versión que este arranque debe dar por vista ANTES de decidir nada, o `nil` si no toca.
    /// Toca cuando el dispositivo aún no completó el onboarding: va a estrenar Yala en esta versión.
    static func versionToMarkSeenAtLaunch(hasCompletedOnboarding: Bool, currentVersion: String) -> String? {
        guard !hasCompletedOnboarding, !currentVersion.isEmpty else { return nil }
        return currentVersion
    }

    /// Si la versión actual trae novedades que este dispositivo no ha visto todavía.
    /// `hasFeatures` es si `WhatsNewConfig` tiene entrada para la versión actual.
    static func shouldPresent(currentVersion: String, lastSeenVersion: String, hasFeatures: Bool) -> Bool {
        guard hasFeatures, !currentVersion.isEmpty else { return false }
        return majorMinor(currentVersion) != majorMinor(lastSeenVersion)
    }

    /// "2.1.1" → "2.1". Una versión sin punto se devuelve tal cual; la vacía sigue vacía.
    static func majorMinor(_ version: String) -> String {
        let parts = version.split(separator: ".")
        guard parts.count >= 2 else { return version }
        return "\(parts[0]).\(parts[1])"
    }
}
