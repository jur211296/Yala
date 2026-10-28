//
//  CustomTabBarUITests.swift
//  YalaUITests
//
//  Barra de abajo personalizada EN CALIENTE (card fozu, S12i): quitar Estadísticas y Planificación, añadir
//  Grupos y Registros, guardar y tocar cada pestaña nueva SIN relanzar. Jürgen vio Registros y Grupos con la
//  pantalla negra (dock visible, pestaña activa, sin contenido) y matar la app lo curaba. Cada pestaña tiene
//  que montar su pantalla real: se comprueba con un botón propio de su barra de navegación.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class CustomTabBarUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Panel · Grupos · Registros · Más · Buscar, como la barra de Jürgen.
    func test_customizedBar_groupsAndRecords_openTheirScreens() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        customizeBar(app, remove: ["statistics", "planning"], add: ["groups", "records"])

        tapTab(app, label: "Registros")
        XCTAssertTrue(
            app.descendants(matching: .any)["records_summary_balance"].waitForExistence(timeout: 10),
            "La pestaña Registros personalizada no montó su pantalla (pantalla negra).")
        attach(app, "registros")

        tapTab(app, label: "Grupos")
        XCTAssertTrue(
            app.buttons["groups_global_settings_button"].waitForExistence(timeout: 10),
            "La pestaña Grupos personalizada no montó su pantalla (pantalla negra).")
        attach(app, "grupos")

        // Ida y vuelta: volver a Registros tras pasar por el Panel sigue enseñándola.
        tapTab(app, label: "Panel")
        XCTAssertTrue(app.buttons["panel_filters_button"].waitForExistence(timeout: 10), "El Panel no volvió.")
        tapTab(app, label: "Registros")
        XCTAssertTrue(
            app.descendants(matching: .any)["records_summary_balance"].waitForExistence(timeout: 10),
            "Registros dejó de montar al volver a ella.")
    }

    /// Variante: una sola pestaña cambiada y en otro orden (Registros delante de Planificación).
    func test_customizedBar_singleSwap_opensItsScreen() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        customizeBar(app, remove: ["statistics"], add: ["records"])

        tapTab(app, label: "Registros")
        XCTAssertTrue(
            app.descendants(matching: .any)["records_summary_balance"].waitForExistence(timeout: 10),
            "La pestaña Registros personalizada no montó su pantalla (pantalla negra).")
        attach(app, "cambio-unico-registros")
    }

    /// Variante: las dos personalizadas en el orden contrario (Registros antes que Grupos).
    func test_customizedBar_recordsThenGroups_openTheirScreens() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        customizeBar(app, remove: ["statistics", "planning"], add: ["records", "groups"])

        tapTab(app, label: "Grupos")
        XCTAssertTrue(
            app.buttons["groups_global_settings_button"].waitForExistence(timeout: 10),
            "La pestaña Grupos personalizada no montó su pantalla (pantalla negra).")
        tapTab(app, label: "Registros")
        XCTAssertTrue(
            app.descendants(matching: .any)["records_summary_balance"].waitForExistence(timeout: 10),
            "La pestaña Registros personalizada no montó su pantalla (pantalla negra).")
    }

    /// Variante: Registros ya se abrió desde Más (pestaña temporal) antes de personalizar la barra.
    func test_recordsOpenedFromMoreFirst_thenCustomized_opensTheirScreens() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.tabBars.buttons["Más"].tap()
        let recordsCard = app.buttons["more_card_records"]
        XCTAssertTrue(recordsCard.waitForExistence(timeout: 10), "Más no trae la tarjeta de Registros.")
        recordsCard.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["records_summary_balance"].waitForExistence(timeout: 10),
            "Registros desde Más no abrió.")
        tapTab(app, label: "Panel")

        customizeBar(app, remove: ["statistics", "planning"], add: ["groups", "records"])

        tapTab(app, label: "Grupos")
        XCTAssertTrue(
            app.buttons["groups_global_settings_button"].waitForExistence(timeout: 10),
            "La pestaña Grupos personalizada no montó su pantalla (pantalla negra).")
        tapTab(app, label: "Registros")
        XCTAssertTrue(
            app.descendants(matching: .any)["records_summary_balance"].waitForExistence(timeout: 10),
            "La pestaña Registros personalizada no montó su pantalla (pantalla negra).")
    }

    /// Variante: dos personalizaciones seguidas en la misma sesión (la segunda reordena la primera).
    func test_customizedTwice_opensTheirScreens() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        customizeBar(app, remove: ["statistics", "planning"], add: ["records", "groups"])
        tapTab(app, label: "Registros")
        XCTAssertTrue(
            app.descendants(matching: .any)["records_summary_balance"].waitForExistence(timeout: 10),
            "Registros no montó tras la primera personalización.")

        customizeBar(app, remove: ["records", "groups"], add: ["groups", "records"])
        tapTab(app, label: "Grupos")
        XCTAssertTrue(
            app.buttons["groups_global_settings_button"].waitForExistence(timeout: 10),
            "La pestaña Grupos no montó tras la segunda personalización (pantalla negra).")
        tapTab(app, label: "Registros")
        XCTAssertTrue(
            app.descendants(matching: .any)["records_summary_balance"].waitForExistence(timeout: 10),
            "La pestaña Registros no montó tras la segunda personalización (pantalla negra).")
    }

    /// El camino de Jürgen: Yala completo → «Solo grupos» → vuelta a Yala completo (la barra pasa de una pestaña a seis
    /// con la app abierta) → personalizar la barra con Grupos y Registros → tocarlas.
    func test_backFromGroupsOnly_thenCustomized_opensTheirScreens() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let panelMarker = app.buttons["panel_inbox_button"]
        XCTAssertTrue(panelMarker.waitForExistence(timeout: 15), "Control: el Panel no estaba montado al empezar.")

        // Ida a «Solo grupos».
        app.openProfile()
        let row = scrollTo(app, "profile_usage_mode")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está la fila «Cómo usas Yala».")
        row.tap()
        let groupsOnly = app.buttons["usage_mode_groups_only"]
        XCTAssertTrue(groupsOnly.waitForExistence(timeout: 10), "No salió «Solo grupos».")
        groupsOnly.tap()
        let confirm = app.buttons["usage_mode_leave_confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "No salió «¿Usar Yala solo para grupos?».")
        confirm.tap()
        XCTAssertTrue(panelMarker.waitForNonExistence(timeout: 15), "La shell no se redujo a solo grupos.")

        // Vuelta a Yala completo, seguir donde lo dejé.
        app.openProfile()
        let comeBack = app.buttons["profile_activate_full_yala"]
        XCTAssertTrue(comeBack.waitForExistence(timeout: 10), "En solo grupos no está «Volver a Yala completo».")
        comeBack.tap()
        let keep = app.buttons["usage_mode_return_continue"]
        XCTAssertTrue(keep.waitForExistence(timeout: 15), "La vuelta no preguntó.")
        keep.tap()
        XCTAssertTrue(panelMarker.waitForExistence(timeout: 15), "La vuelta no llevó al Panel.")

        customizeBar(app, remove: ["statistics", "planning"], add: ["groups", "records"])

        tapTab(app, label: "Registros")
        XCTAssertTrue(
            app.descendants(matching: .any)["records_summary_balance"].waitForExistence(timeout: 10),
            "Tras volver de solo grupos, la pestaña Registros personalizada no montó su pantalla (pantalla negra).")
        tapTab(app, label: "Grupos")
        XCTAssertTrue(
            app.buttons["groups_global_settings_button"].waitForExistence(timeout: 10),
            "Tras volver de solo grupos, la pestaña Grupos personalizada no montó su pantalla (pantalla negra).")
    }

    // MARK: - Helpers

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "customTabBar-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier].firstMatch
        var tries = 0
        while !(element.exists && element.isHittable) && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    private func customizeBar(_ app: XCUIApplication, remove: [String], add: [String]) {
        let moreTab = app.tabBars.buttons["Más"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "No apareció el tab Más.")
        moreTab.tap()

        let editorButton = app.buttons["more_editor_button"]
        XCTAssertTrue(editorButton.waitForExistence(timeout: 5), "No apareció el botón del editor en Más.")
        editorButton.tap()

        let tabBarButton = app.buttons["more_editor_tabbar_button"]
        XCTAssertTrue(tabBarButton.waitForExistence(timeout: 5), "No apareció el acceso a la barra de pestañas.")
        tabBarButton.tap()

        for tab in remove {
            let button = app.buttons["tabconfig_remove_\(tab)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "No apareció tabconfig_remove_\(tab).")
            button.tap()
        }
        for tab in add {
            let button = app.buttons["tabconfig_add_\(tab)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "No apareció tabconfig_add_\(tab).")
            button.tap()
        }

        let save = app.buttons["tabconfig_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No apareció tabconfig_save.")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5), "La configuración no se cerró al guardar.")

        // Cerrar el editor de Más (hoja) para volver a la barra.
        let close = app.buttons["toolbar_save_button"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "No apareció el botón de cerrar del editor de Más.")
        close.tap()
        XCTAssertTrue(
            app.buttons["more_editor_tabbar_button"].waitForNonExistence(timeout: 5),
            "El editor de Más no se cerró.")
    }

    private func tapTab(_ app: XCUIApplication, label: String) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "No apareció la pestaña \(label) en la barra.")
        tab.tap()
    }
}
