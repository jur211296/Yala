//
//  UsageFocus.swift
//  Yala
//
//  Flag de PRESENTACIÓN (D1 — retención «Seguir con mis grupos», estudio
//  MODO-NUBE-GESTION-DATOS-UX.md §3.3.2). Decide SOLO el foco de la shell (tab bar
//  + visibilidad de secciones personales); NO toca el ciclo de vida (`OnboardingMode`)
//  ni oculta filas de sesión/cuenta/export. Persistido en `AppPreferences.Keys.usageFocus`
//  y sincronizado LWW SIMPLE (familia `.stringGuardNonEmpty`, NUNCA never-downgrade —
//  ver PreferenceMergeLogic). Un `.groupsOnly` sigue siendo `onboardingMode == .full`.
//

import Foundation

/// Foco de uso de la app.
/// - `.full` (default): app completa.
/// - `.groupsOnly`: shell reducida a la pestaña Grupos, tras que el usuario elige
///   «Solo mis grupos» al vaciar sus datos con grupos vivos. Se revierte de un flujo
///   («Activar Yala completo»), que resetea a `.full`.
enum UsageFocus: String, CaseIterable, Sendable {
    case full
    case groupsOnly

    /// Key de UserDefaults (SSOT). `AppPreferences.Keys.usageFocus` la referencia.
    /// `nonisolated` como el `Keys` que la consume: un `String` constante no necesita actor.
    nonisolated static let userDefaultsKey = "usageFocus"

    /// Lee el valor persistido (fallback `.full` si ausente/ inválido). Point-read para
    /// call-sites IMPERATIVOS (`SessionState.effectiveShellMode`, `selectMainTab`,
    /// `resetToDefaults`). Las vistas REACTIVAS leen `AppPreferences.usageFocus` vía
    /// `@Environment` (para reaccionar a cambios locales y remotos), nunca este point-read.
    static func current(_ defaults: UserDefaults = .standard) -> UsageFocus {
        UsageFocus(rawValue: defaults.string(forKey: userDefaultsKey) ?? "") ?? .full
    }
}
