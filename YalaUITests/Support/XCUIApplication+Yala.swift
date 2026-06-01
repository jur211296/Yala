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
}
