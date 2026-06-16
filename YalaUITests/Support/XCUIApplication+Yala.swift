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
        seed: String? = "minimal",
        deeplink: String? = nil,
        onboarding: Bool = false,
        inboxAlert: Bool = false,
        forceUpdate: Bool = false,
        aiConsent: Bool = false,
        groupInvite: Bool = false
    ) -> XCUIApplication {
        var args = ["-uitest"]
        if reset { args.append("-uitest-reset") }
        if skipOnboarding { args.append("-uitest-skip-onboarding") }
        if pro { args.append("-uitest-pro") }
        if let seed {
            args.append("-uitest-seed")
            args.append(seed)
        }
        if let deeplink {
            args.append("-uitest-deeplink")
            args.append(deeplink)
        }
        if onboarding { args.append("-uitest-onboarding") }
        if inboxAlert { args.append("-uitest-inbox-alert") }
        if forceUpdate { args.append("-uitest-force-update") }
        if aiConsent { args.append("-uitest-ai-consent") }
        if groupInvite { args.append("-uitest-group-invite") }
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

    // MARK: - Menú (···) de Registros

    /// El menú (···) de la toolbar de Registros (tab Registros de Estadísticas /
    /// RecordsStandaloneView). Visible solo en modo normal (no en modo selección).
    /// Señal canónica de "estamos en la lista de Registros en modo normal".
    var recordsOverflowMenu: XCUIElement { buttons["records_overflow_menu"] }

    /// Abre el menú (···) de Registros y toca "Filtrar". El botón `filters_toolbar_button`
    /// vive ahora DENTRO del menú (antes era un botón directo del toolbar).
    func openRecordsFilters(timeout: TimeInterval = 10) {
        let menu = recordsOverflowMenu
        XCTAssertTrue(menu.waitForExistence(timeout: timeout), "No apareció el menú (···) de Registros.")
        menu.tap()
        let filters = buttons["filters_toolbar_button"]
        XCTAssertTrue(filters.waitForExistence(timeout: timeout), "El menú (···) no ofreció 'Filtrar'.")
        filters.tap()
    }

    /// Abre el menú (···) de Registros y toca "Seleccionar" → entra en modo selección.
    /// El botón `records_select_button` vive ahora DENTRO del menú.
    func openRecordsSelectMode(timeout: TimeInterval = 10) {
        let menu = recordsOverflowMenu
        XCTAssertTrue(menu.waitForExistence(timeout: timeout), "No apareció el menú (···) de Registros.")
        menu.tap()
        let select = buttons["records_select_button"]
        XCTAssertTrue(select.waitForExistence(timeout: timeout), "El menú (···) no ofreció 'Seleccionar'.")
        select.tap()
    }
}
