//
//  PanelProgresivoUITests.swift
//  YalaUITests
//
//  «Solo gastos» con Primeros pasos y Panel progresivo (Jürgen, 19-nov-2026): con el mazo a medias el Panel enseña solo
//  lo que la persona completó. `-uitest-fresh-install` deja la instalación como nueva y `-uitest-show-setup-deck` deja
//  salir el mazo (y con él la puerta del Panel), que bajo `-uitest` se calla.
//

import XCTest

final class PanelProgresivoUITests: XCTestCase {

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

    /// «Solo gastos» llega con el mazo, no con un botón suelto «Anotar el primer gasto», y sin «Tus finanzas» ni
    /// widgets. Sin el arreglo salía `setup_first_expense` y no había mazo.
    func test_expensesOnly_arrivesWithTheDeckAndNothingElse() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, extraArguments: [
            "-uitest-fresh-install", "-uitest-show-setup-deck", "-uitest-expenses-only",
        ])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let deck = app.buttons["setup_deck_current"]
        XCTAssertTrue(deck.waitForExistence(timeout: 10), "«Solo gastos» no enseñó el mazo de Primeros pasos.")
        XCTAssertTrue(deck.label.contains("de 7"), "El mazo de «Solo gastos» tiene los siete pasos: «\(deck.label)».")
        XCTAssertFalse(app.buttons["setup_first_expense"].exists, "Volvió el botón suelto en vez del mazo.")
        XCTAssertFalse(app.buttons["panel_panorama_header"].exists, "Al entrar no hay «Tus finanzas».")
        XCTAssertFalse(app.descendants(matching: .any)["panel_section_latestRecords"].exists,
                       "Al entrar no hay widgets.")
        attach(app, "solo-gastos-llegada")
    }

    /// Con la cuenta y los registros ya hechos (la semilla los marca) y el mazo a medias: la cuenta y «Últimos
    /// registros», y nada de Tendencias ni Planificación. Sin el arreglo, la lista de fábrica enseñaba Tendencias.
    func test_withAccountAndRecords_onlyThoseShow() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        XCTAssertTrue(app.buttons["setup_deck_current"].waitForExistence(timeout: 10), "No salió el mazo.")
        XCTAssertTrue(app.buttons["panel_panorama_header"].waitForExistence(timeout: 10),
                      "Con la cuenta hecha, «Tus finanzas» sale.")
        let latest = app.descendants(matching: .any)["panel_section_latestRecords"]
        for _ in 0..<4 where !latest.exists { app.swipeUp() }
        XCTAssertTrue(latest.exists, "Con los registros hechos, «Últimos registros» sale.")
        XCTAssertFalse(app.descendants(matching: .any)["panel_section_tendencias"].exists,
                       "Tendencias espera a que termine Primeros pasos.")
        XCTAssertFalse(app.descendants(matching: .any)["panel_section_planificacion"].exists,
                       "Sin un «Sí» en el paso 3 o el 4, no hay Planificación.")
        attach(app, "cuenta-y-registros")
    }
}
