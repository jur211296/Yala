//
//  RestoreDestination.swift
//  Yala
//
//  Decide a dónde llevar al usuario tras restaurar datos de iCloud, respetando
//  el `onboardingMode` restaurado (synced vía KV). Pure-logic: el callsite aplica
//  los side-effects de cada destino (flags `hasCompletedOnboarding`/`onboardingMode`).
//

import Foundation

enum RestoreDestination: Equatable {
    /// El usuario era "solo grupos" (onboardingMode == .groupInvite) → modo
    /// solo-grupos directo (tabs reducidos). El callsite setea
    /// `hasCompletedOnboarding = true` + `onboardingMode = .groupInvite`.
    case groupsOnly
    /// Datos personales completos (nombre + cuentas + categorías) → MainTabView.
    /// El callsite invoca `completeOnboardingAsRestoreSkip()`.
    case directToApp
    /// Faltan datos personales (p.ej. sin cuentas) → OnboardingView rama B
    /// (con los pasos prefilled saltados). El flag se setea al completar.
    case onboarding
}

enum RestoreRouter {

    /// - Parameters:
    ///   - onboardingMode: el modo restaurado desde iCloud (KV-store, synced).
    ///   - isFullyPrefilled: `summary.isFullyPrefilled` (nombre + cuentas + categorías).
    static func decide(onboardingMode: OnboardingMode, isFullyPrefilled: Bool) -> RestoreDestination {
        // Respetar lo que el usuario era: si "solo grupos", no forzar onboarding personal.
        if onboardingMode == .groupInvite { return .groupsOnly }
        return isFullyPrefilled ? .directToApp : .onboarding
    }
}
