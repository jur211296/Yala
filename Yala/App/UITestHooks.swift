//
//  UITestHooks.swift
//  Yala
//
//  Hooks de UI testing controlados por launch arguments (`-uitest*`).
//  En release `isActive` es siempre false y todo es no-op — no afecta producción.
//  El seeding y la activación Pro (APIs `#if DEBUG`) se aplican desde
//  AppBootstrapper dentro de bloques `#if DEBUG`; aquí solo viven los flags
//  (lectura de ProcessInfo) y la señal observable de readiness para los XCUITests.
//

import Foundation
import Observation

@MainActor
@Observable
final class UITestHooks {
    static let shared = UITestHooks()
    private init() {}

    // MARK: - Flags (false en release)

    /// True solo cuando la app se lanza con `-uitest` (y solo en builds DEBUG).
    nonisolated static var isActive: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-uitest")
        #else
        return false
        #endif
    }

    /// `-uitest-reset`: wipe de datos locales al arranque (estado limpio / vacío).
    nonisolated static var shouldReset: Bool { hasArg("-uitest-reset") }

    /// `-uitest-pro`: fuerza Pro (devForceProTier) al arranque.
    nonisolated static var forcePro: Bool { hasArg("-uitest-pro") }

    /// `-uitest-skip-onboarding`: marca onboarding/chooser completados.
    nonisolated static var skipOnboarding: Bool { hasArg("-uitest-skip-onboarding") }

    /// `-uitest-onboarding`: presenta el OnboardingView directo (salta Welcome Hero/Chooser),
    /// SIN marcar onboarding completado. Para testear el flujo de onboarding aislado.
    nonisolated static var startAtOnboarding: Bool { hasArg("-uitest-onboarding") }

    /// `-uitest-inbox-alert`: tras el seed, encola `.showInboxAlert` con un payload de
    /// muestra para presentar el InboxAlertModal sin depender del sync de CloudKit.
    nonisolated static var showInboxAlert: Bool { hasArg("-uitest-inbox-alert") }

    /// Valor de `-uitest-seed <perfil>` (ej. "realista", "pesado"). Nil si ausente.
    nonisolated static var seedProfile: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseSeedProfile(from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Pure-logic: extrae el valor que sigue a `-uitest-seed`. Nil si ausente, si es el
    /// último token, o si el siguiente token es otro flag (`-...`). Separado para test.
    nonisolated static func parseSeedProfile(from args: [String]) -> String? {
        parseValue(after: "-uitest-seed", from: args)
    }

    /// `-uitest-deeplink <target>`: simula un deeplink externo a un tab al arranque
    /// (panel/statistics/records/planning/budgets/groups/inbox/scheduledPayments/categories).
    /// Ejercita el wiring de routing a tabs ocultos (bug review-deeplinks).
    nonisolated static var deeplinkTarget: String? {
        #if DEBUG
        guard isActive else { return nil }
        return parseValue(after: "-uitest-deeplink", from: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    /// Pure-logic: extrae el valor que sigue a `flag`. Nil si ausente, si es el último
    /// token, o si el siguiente token es otro flag (`-...`). Separado para test.
    nonisolated static func parseValue(after flag: String, from args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        let value = args[i + 1]
        return value.hasPrefix("-") ? nil : value
    }

    nonisolated private static func hasArg(_ flag: String) -> Bool {
        #if DEBUG
        return isActive && ProcessInfo.processInfo.arguments.contains(flag)
        #else
        return false
        #endif
    }

    // MARK: - Readiness (observado por ContentView)

    /// Flip a true cuando bootstrap + seed terminan. Los XCUITests esperan a que
    /// el root exponga `uitest_ready` antes de interactuar (evita sleeps frágiles).
    private(set) var isReady = false

    func markReady() { isReady = true }

    /// accessibilityIdentifier del root: "" en release / sin uitest, "uitest_loading"
    /// mientras arranca, "uitest_ready" cuando todo está listo.
    var rootIdentifier: String {
        guard Self.isActive else { return "" }
        return isReady ? "uitest_ready" : "uitest_loading"
    }
}
