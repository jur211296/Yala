//
//  RestoreDestination.swift
//  Yala
//
//  Decide a dónde llevar al usuario tras restaurar datos de iCloud, según lo que
//  traiga el resumen restaurado. Pure-logic: el callsite aplica los side-effects
//  de cada destino (flag `hasCompletedOnboarding`).
//

import Foundation

enum RestoreDestination: Equatable {
    /// Datos personales completos (nombre + cuentas + categorías) → MainTabView.
    /// El callsite invoca `completeOnboardingAsRestoreSkip()`.
    case directToApp
    /// Faltan datos personales (p.ej. sin cuentas) → OnboardingView rama B
    /// (con los pasos prefilled saltados). El flag se setea al completar.
    case onboarding
}

enum RestoreRouter {

    /// - Parameters:
    ///   - isFullyPrefilled: `summary.isFullyPrefilled` (nombre + cuentas + categorías).
    static func decide(isFullyPrefilled: Bool) -> RestoreDestination {
        // Con el resumen completo no se fuerza un onboarding personal que no aporta nada.
        return isFullyPrefilled ? .directToApp : .onboarding
    }
}
