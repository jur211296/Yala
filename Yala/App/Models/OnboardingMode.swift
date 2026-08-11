//
//  OnboardingMode.swift
//  Yala
//
//  Determines the onboarding experience based on how the user arrived.
//  Persisted via UserDefaults and synced via PreferenceSyncService (iCloud KV).
//

import Foundation

enum OnboardingMode: String, Codable {
    /// Default: new user without invitation, or existing user
    case full
    /// Arrived via group invitation link (reduced onboarding)
    case groupInvite
    /// Was groupInvite, activated full Yala experience
    case completed

    /// Ordering for never-downgrade merge rule.
    /// Remote sync never overwrites a higher-rank local value.
    /// `nonisolated`: valor puro consumido por `PreferenceMergeLogic` (lógica de merge nonisolated) bajo
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
    nonisolated var rank: Int {
        switch self {
        case .full: return 0
        case .groupInvite: return 1
        case .completed: return 2
        }
    }

    // MARK: - Persistence

    private static let key = "onboardingMode"

    /// Read from UserDefaults (fallback: .full)
    static func current() -> OnboardingMode {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let mode = OnboardingMode(rawValue: raw) else { return .full }
        return mode
    }

    /// Write to UserDefaults.
    ///
    /// **M1 · en sesión secundaria NO se persiste, y el valor en memoria sí cambia.** La key vive en
    /// el `UserDefaults.standard` COMPARTIDO con el dueño y su merge es NEVER-DOWNGRADE por rank
    /// (`PreferenceMergeLogic`): un `.completed` (rank 2) escrito por la invitada deja al dueño una
    /// shell escalada que su propio `.groupInvite` (rank 1) del iKV **ya no puede recuperar**, y el
    /// wipe de salida de la secundaria no repone esta key. Este es el embudo de TODAS las
    /// asignaciones a `SessionState.onboardingMode` (su `didSet` llama aquí) y de los dos
    /// `setCurrent` directos; los tres escritores que van por `PreferenceSyncService` con
    /// `OnboardingMode.userDefaultsKey` **no pasan por aquí** y llevan su propio guard.
    ///
    /// Residual consciente: la invitada ve su shell nueva durante la sesión (memoria) pero un
    /// relanzamiento se la devuelve a la del dueño. Persistirla exigiría namespacear la key por
    /// sesión, y eso toca el merge never-downgrade — fuera del alcance de este chip.
    ///
    /// `defaults` inyectable (regla del repo: nunca `.standard` directo en tests) y el descriptor se
    /// consulta sobre ESE store, para que el guard sea afirmable sin depender del simulador.
    static func setCurrent(_ mode: OnboardingMode, _ defaults: UserDefaults = .standard) {
        guard !SecondarySessionStore.isActive(defaults) else { return }
        defaults.set(mode.rawValue, forKey: key)
    }

    /// UserDefaults key (exposed for DataWipeService cleanup)
    static let userDefaultsKey = key
}
