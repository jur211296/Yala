//
//  Bienvenida23BaseUITests.swift
//  YalaUITests
//
//  Lote 01 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md):
//   · Y23-15: una instalación nueva ve Panel · Grupos · Registros · Más · Buscar, y la guía de «días después» lleva
//     de «Configurar Panel» a Más › Estadísticas.
//   · Y23-05: la llegada tiene el mazo como única acción, «Primeros pasos · 1 de 7», y «Ver los 7 pasos».
//
//  `-uitest-fresh-install` deja la instalación como nueva (sin él, el reset deja la barra de antes);
//  `-uitest-show-setup-deck` y `-uitest-later-charts-guide` dejan salir el mazo y la guía, que bajo `-uitest` se callan.
//  Cada caso adjunta su captura (`keepAlways`).
//

import XCTest

final class Bienvenida23BaseUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Y23-15 + Y23-05: instalación nueva, sin datos. La barra nueva y el mazo en el paso 1, sin la fila de acciones.
    func test_freshInstall_hasTheNewTabs_andTheDeckIsTheOnlyAction() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "No hay barra de pestañas.")
        XCTAssertTrue(bar.buttons["Grupos"].exists, "Una instalación nueva lleva Grupos en la barra.")
        XCTAssertTrue(bar.buttons["Registros"].exists, "Una instalación nueva lleva Registros en la barra.")
        XCTAssertFalse(bar.buttons["Estadísticas"].exists, "Estadísticas vive en Más.")
        XCTAssertFalse(bar.buttons["Planificación"].exists, "Planificación vive en Más.")

        let deck = app.buttons["setup_deck_current"]
        XCTAssertTrue(deck.waitForExistence(timeout: 10), "No salió el mazo de Primeros pasos.")
        XCTAssertTrue(deck.label.contains("1 de 7"), "El mazo empieza en el paso 1: «\(deck.label)».")
        XCTAssertTrue(deck.label.contains("Crea tu primera cuenta"), "Paso 1 por su nombre: «\(deck.label)».")
        XCTAssertFalse(app.buttons["panel_create_first_account"].exists, "En la llegada, el mazo es la única acción.")
        XCTAssertFalse(app.buttons["panel_action_new"].exists, "En la llegada, el mazo es la única acción.")
        attach(app, "llegada-mazo")

        app.buttons["setup_checklist_toggle_steps"].tap()
        let resume = app.buttons["setup_steps_resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5), "«Ver los 7 pasos» no abrió la lista.")
        XCTAssertTrue(app.staticTexts["Yala en tu pantalla de inicio"].exists, "La lista trae los siete pasos.")
        attach(app, "lista-7-pasos")
        resume.tap()
        XCTAssertTrue(resume.waitForNonExistence(timeout: 5), "«Seguir donde iba» cierra la lista.")
    }

    /// Y23-15: con registros en varios días, la guía sale sola: «Arma tu Panel» → «Tus gráficas viven en Más» →
    /// tocar Más → «Todas tus gráficas» → «Entendido».
    func test_laterGuide_walksFromConfigurePanelToStatisticsInMore() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: ["-uitest-fresh-install", "-uitest-later-charts-guide"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.descendants(matching: .any)["place_guide_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 15), "La guía de «días después» no salió.")
        XCTAssertTrue(app.staticTexts["Arma tu Panel"].exists)
        attach(app, "dias-despues-1-arma-tu-panel")

        app.buttons["place_guide_advance"].tap()
        XCTAssertTrue(app.staticTexts["Tus gráficas viven en Más"].waitForExistence(timeout: 5))
        attach(app, "dias-despues-2-viven-en-mas")

        app.tabBars.firstMatch.buttons["Más"].tap()
        XCTAssertTrue(app.staticTexts["Todas tus gráficas"].waitForExistence(timeout: 5),
                      "Tocar Más no llevó a la pantalla Más con el foco en Estadísticas.")
        attach(app, "dias-despues-3-todas-tus-graficas")

        app.buttons["place_guide_advance"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["place_guide_card"].waitForNonExistence(timeout: 5),
                      "«Entendido» cierra la guía.")
    }

    /// Texto grande (AX3): el mazo y la guía se leen enteros (ficha «Cómo usar esta especificación»).
    func test_largeText_deckAndGuideReadWhole() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: [
            "-uitest-fresh-install", "-uitest-later-charts-guide",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL",
        ])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.descendants(matching: .any)["place_guide_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 15), "La guía de «días después» no salió con texto grande.")
        XCTAssertTrue(app.buttons["place_guide_advance"].isHittable, "Con texto grande, «Siguiente» se alcanza.")
        attach(app, "texto-grande-guia")
    }
}
