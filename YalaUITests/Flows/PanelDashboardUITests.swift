//
//  PanelDashboardUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `panel-dashboard-logic` (escenarios 9.x): el Panel
//  es el tab default (boundBy:0), visible al arrancar. Verifica (a) que el Panel
//  monta con su FAB y el botón de configuración de secciones, y (b) la lógica de
//  configurabilidad: ocultar una sección desde PanelSectionsConfigView la quita del
//  dashboard y la preferencia persiste al reabrir el sheet. El toggle escribe
//  directo a `panelSectionsHidden`; el YalaSaveButton solo cierra el sheet.
//  Seed `minimal` (la sección Tendencias se renderiza con sus datos por default).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class PanelDashboardUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Localiza un elemento por identifier sin acoplar al tipo: las secciones del
    /// Panel (`panel_section_<kind>`) viven en el ScrollView vertical y se resuelven
    /// vía `descendants` (mismo patrón que los TabView de Estadísticas).
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Espera (sin sleeps) a que un switch alcance el `value` esperado ("0"/"1").
    /// Necesario tras un tap: leer `.value` de inmediato captura el snapshot de
    /// accesibilidad antes de que SwiftUI propague el binding `panelSectionsHidden`
    /// (`@Observable` → re-render). El predicate re-consulta hasta que se cumple.
    private func waitForSwitchValue(_ element: XCUIElement, equals expected: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "value == %@", expected)
        let exp = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [exp], timeout: timeout) == .completed
    }

    /// Smoke + navegación: el Panel monta con su FAB y el botón de configuración de
    /// secciones; al tocarlo se presenta PanelSectionsConfigView con sus toggles.
    func test_opensPanelAndSectionsConfig() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        XCTAssertTrue(
            app.buttons["fab_new_transaction"].waitForExistence(timeout: 10),
            "No apareció el FAB del Panel — la app no llegó al dashboard."
        )

        let configButton = app.buttons["panel_sections_config"]
        XCTAssertTrue(configButton.waitForExistence(timeout: 5), "No apareció el botón de configuración de secciones.")
        configButton.tap()

        XCTAssertTrue(
            app.switches["panel_section_toggle_tendencias"].waitForExistence(timeout: 5),
            "No se montó PanelSectionsConfigView (toggle de la sección Tendencias)."
        )
    }

    /// Config logic + persistencia: ocultar la sección Tendencias la quita del Panel
    /// y la preferencia sobrevive al reabrir el sheet de configuración.
    func test_hidingSectionRemovesItFromPanelAndPersists() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // La sección Tendencias se renderiza por default (seed minimal tiene datos).
        XCTAssertTrue(
            element(app, "panel_section_tendencias").waitForExistence(timeout: 10),
            "La sección Tendencias no apareció en el Panel."
        )

        // Abrir el config y ocultar Tendencias (el toggle persiste al instante).
        app.buttons["panel_sections_config"].tap()
        let trendsToggle = app.switches["panel_section_toggle_tendencias"]
        XCTAssertTrue(trendsToggle.waitForExistence(timeout: 5), "No apareció el toggle de Tendencias.")
        XCTAssertTrue(waitForSwitchValue(trendsToggle, equals: "1"), "Tendencias debería estar visible (ON) por default.")

        // El identifier vive en el `Toggle` contenedor (row ancho); su control físico
        // es un sub-switch al extremo derecho. Tocar el centro del contenedor cae en
        // el label y NO togglea — hay que tocar el sub-switch real.
        trendsToggle.switches.firstMatch.tap()
        XCTAssertTrue(waitForSwitchValue(trendsToggle, equals: "0"), "El toggle de Tendencias no pasó a OFF tras el tap.")

        // Cerrar el sheet (YalaSaveButton solo hace dismiss).
        app.buttons["toolbar_save_button"].tap()

        // La sección desaparece del Panel (espera al cierre del sheet + re-render).
        XCTAssertTrue(
            element(app, "panel_section_tendencias").waitForNonExistence(timeout: 5),
            "La sección Tendencias sigue en el Panel tras ocultarla."
        )

        // Persistencia: al reabrir el config, el toggle sigue OFF.
        let configButton = app.buttons["panel_sections_config"]
        XCTAssertTrue(configButton.waitForExistence(timeout: 5), "No reapareció el botón de configuración.")
        configButton.tap()
        let toggleAgain = app.switches["panel_section_toggle_tendencias"]
        XCTAssertTrue(toggleAgain.waitForExistence(timeout: 5), "No reapareció el toggle de Tendencias al reabrir.")
        XCTAssertTrue(waitForSwitchValue(toggleAgain, equals: "0"), "La preferencia de ocultar Tendencias no persistió.")
    }
}
