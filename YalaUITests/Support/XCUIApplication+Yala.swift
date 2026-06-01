//
//  XCUIApplication+Yala.swift
//  YalaUITests
//
//  Harness base para XCUITests de Yala: lanzar con launch args de uitest y
//  esperar deterministamente a que bootstrap+seed terminen (señal uitest_ready).
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

extension XCUIApplication {
    /// Lanza la app en modo UI-test con los launch args indicados.
    /// Por defecto: estado limpio + onboarding saltado + seed minimal (rápido).
    @discardableResult
    func launchForUITest(
        reset: Bool = true,
        skipOnboarding: Bool = true,
        pro: Bool = false,
        seed: String? = "minimal"
    ) -> XCUIApplication {
        var args = ["-uitest"]
        if reset { args.append("-uitest-reset") }
        if skipOnboarding { args.append("-uitest-skip-onboarding") }
        if pro { args.append("-uitest-pro") }
        if let seed {
            args.append("-uitest-seed")
            args.append(seed)
        }
        launchArguments = args
        launch()
        return self
    }

    /// Espera a que el root exponga `uitest_ready` (bootstrap + seed completos).
    /// Timeout generoso por si el test usa seed realista/pesado.
    @discardableResult
    func waitForUITestReady(timeout: TimeInterval = 120) -> Bool {
        descendants(matching: .any)
            .matching(identifier: "uitest_ready")
            .firstMatch
            .waitForExistence(timeout: timeout)
    }

    // MARK: - Navegación reutilizable

    /// Abre el sheet de Perfil desde el avatar del toolbar del Panel.
    /// Falla el test si el avatar no aparece (la app no llegó al Panel).
    @discardableResult
    func openProfile(timeout: TimeInterval = 10) -> XCUIApplication {
        let avatar = buttons["profile_avatar"]
        XCTAssertTrue(avatar.waitForExistence(timeout: timeout), "No apareció el avatar de Perfil (profile_avatar) en el Panel.")
        avatar.tap()
        return self
    }

    /// Desde el Perfil abierto, navega a una sección de ajustes (push del NavigationStack).
    /// `rowID` es el accessibilityIdentifier de la fila — ej. "profile_accounts",
    /// "profile_categories", "profile_tags". Reutilizable por todas las áreas de Settings.
    func openSettingsSection(_ rowID: String, timeout: TimeInterval = 10) {
        let row = buttons[rowID]
        XCTAssertTrue(row.waitForExistence(timeout: timeout), "No apareció la fila de ajustes '\(rowID)'.")
        row.tap()
    }
}
