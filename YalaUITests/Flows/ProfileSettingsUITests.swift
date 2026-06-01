//
//  ProfileSettingsUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `settings-profile-general` (escenarios 13.1, 13.5,
//  13.6): overview del Perfil (secciones visibles) y flujo de configuración de la
//  barra de pestañas (quitar un tab + guardar). Verificación de FLUJO (la config
//  se guarda y el sheet cierra), sin tocar el reset destructivo de datos. Reusa
//  openProfile/openSettingsSection. Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class ProfileSettingsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Overview: el sheet de Perfil muestra las secciones principales.
    func test_profileOverviewShowsSections() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()

        XCTAssertTrue(
            app.buttons["profile_accounts"].waitForExistence(timeout: 5),
            "No apareció la fila Cuentas en el Perfil."
        )
        XCTAssertTrue(
            app.buttons["profile_personalization"].waitForExistence(timeout: 5),
            "No apareció la fila Personalización en el Perfil."
        )
    }

    /// Flujo — abrir la configuración de la barra de pestañas, quitar un tab y
    /// guardar; verificar que la configuración se guarda y se vuelve a Personalización.
    func test_tabBarConfigRemoveTabCompletes() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_personalization")

        let tabBarButton = app.buttons["personalization_tabbar_button"]
        XCTAssertTrue(tabBarButton.waitForExistence(timeout: 5), "No apareció el botón de configurar barra de pestañas.")
        tabBarButton.tap()

        // Quitar el tab Planificación (activo por defecto en el config base) y guardar.
        let removePlanning = app.buttons["tabconfig_remove_planning"]
        XCTAssertTrue(removePlanning.waitForExistence(timeout: 5), "No se montó TabBarConfigView (tabconfig_remove_planning).")
        removePlanning.tap()

        let save = app.buttons["tabconfig_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No apareció tabconfig_save.")
        save.tap()

        // El sheet de configuración cierra y volvemos a Personalización.
        XCTAssertTrue(
            app.buttons["personalization_tabbar_button"].waitForExistence(timeout: 5),
            "Tras guardar la configuración no se volvió a Personalización."
        )
    }
}
