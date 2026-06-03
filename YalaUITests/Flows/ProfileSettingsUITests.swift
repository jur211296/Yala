//
//  ProfileSettingsUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `settings-profile-general` (escenarios 13.1, 13.5,
//  13.6): overview del Perfil (secciones visibles) y flujo de configuración de la
//  barra de pestañas (quitar un tab + guardar) desde el editor del tab "Más".
//  Verificación de FLUJO (la config se guarda y el sheet cierra), sin tocar el
//  reset destructivo de datos. Reusa openProfile. Seed `minimal`.
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

    /// Flujo — desde el editor del dashboard "Más" (icono del toolbar), abrir la
    /// configuración de la barra de pestañas, quitar un tab y guardar; verificar
    /// que la configuración se guarda y se vuelve al editor.
    func test_tabBarConfigRemoveTabCompletes() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Tab "Más" (4º del tab bar) → editor (icono del toolbar).
        let moreTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "No apareció el tab Más.")
        moreTab.tap()

        let editorButton = app.buttons["more_editor_button"]
        XCTAssertTrue(editorButton.waitForExistence(timeout: 5), "No apareció el botón del editor en Más.")
        editorButton.tap()

        let tabBarButton = app.buttons["more_editor_tabbar_button"]
        XCTAssertTrue(tabBarButton.waitForExistence(timeout: 5), "No apareció el acceso a la barra de pestañas en el editor.")
        tabBarButton.tap()

        // Quitar el tab Planificación (activo por defecto en el config base) y guardar.
        let removePlanning = app.buttons["tabconfig_remove_planning"]
        XCTAssertTrue(removePlanning.waitForExistence(timeout: 5), "No se montó TabBarConfigView (tabconfig_remove_planning).")
        removePlanning.tap()

        let save = app.buttons["tabconfig_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No apareció tabconfig_save.")
        save.tap()

        // El sheet de configuración cierra y volvemos al editor de "Más".
        XCTAssertTrue(
            app.buttons["more_editor_tabbar_button"].waitForExistence(timeout: 5),
            "Tras guardar la configuración no se volvió al editor de Más."
        )
    }
}
