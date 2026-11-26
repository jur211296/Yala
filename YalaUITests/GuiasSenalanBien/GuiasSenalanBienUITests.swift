//
//  GuiasSenalanBienUITests.swift
//  YalaUITests
//
//  Lote 2 de la observación en vivo del iPhone 14 (25-nov-2026): las guías señalan donde deben.
//  · Paso 6 con Más desplazado: la guía lleva Estadísticas a la vista antes de enmarcar y, al terminar, vuelve al Panel.
//  · Aviso «Tus presupuestos viven en Más» con la barra encogida: la despliega y tocar «Más» sigue la guía.
//  La lógica y el cableado los fijan los tests de `YalaTests/GuiasSenalanBien/`. Las historias que responden en toda la
//  zona no tienen caso aquí: medido el 2026-11-25, el toque sintético de XCUITest justo encima del botón no llega a la
//  zona (con `axe` sí, a 450, 600 y 738 pt); lo fija el cableado de `GuiasHistoriasZonaTests` y el guion de iPhone.
//

import XCTest

final class GuiasSenalanBienUITests: XCTestCase {

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

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func tapWhenSettled(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10,
                                file: StaticString = #filePath, line: UInt = #line) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "No apareció «\(id)».", file: file, line: line)
        _ = app.waitForSettledLayout(of: target)
        target.tap()
    }

    /// Paso 6 con Más desplazado hasta abajo: la guía sube Estadísticas a la vista y «Entendido» vuelve al Panel.
    func test_paso6_conMasDesplazado_enfocaEstadisticas_yVuelveAlPanel() {
        let app = XCUIApplication()
        app.launchForUITest(
            seed: "cuenta-con-movimientos",
            extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck", "-uitest-setup-deck-at", "6"])
        XCTAssertTrue(app.waitForUITestReady())

        // Más, desplazado hasta abajo: Estadísticas queda fuera de la vista.
        app.selectTab(.more)
        let insights = app.buttons["more_card_insights"].firstMatch
        XCTAssertTrue(insights.waitForExistence(timeout: 10))
        for _ in 0..<4 { app.swipeUp() }
        let window = app.frame
        let navBottom = app.navigationBars.firstMatch.frame.maxY
        XCTAssertFalse(insights.exists && insights.frame.minY >= navBottom && insights.frame.maxY <= window.maxY,
                       "El escenario necesita Más desplazado, con Estadísticas fuera de la vista.")
        attach(app, "mas-desplazado")

        // De vuelta al Panel, el paso 6.
        app.selectTabExpandingCompactBar(.panel)
        tapWhenSettled(app, "setup_deck_current")
        let card = element(app, "place_guide_card")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        // Lo enmarcado a la vista: las tres de Estadísticas entre la barra de arriba y el borde de abajo.
        let deadline = Date().addingTimeInterval(5)
        func statsVisible() -> Bool {
            ["more_card_insights", "more_card_trends", "more_card_categories"].allSatisfy { id in
                let card = app.buttons[id].firstMatch
                return card.exists && card.frame.minY >= navBottom - 1 && card.frame.maxY <= window.maxY
            }
        }
        while !statsVisible() && Date() < deadline { _ = card.waitForExistence(timeout: 0.3) }
        XCTAssertTrue(statsVisible(), "La guía lleva Estadísticas a la vista antes de enmarcarla.")
        sleep(1)
        attach(app, "paso6-foco")

        // «Entendido»: el paso queda hecho y vuelve al Panel, con el mazo en el paso 7.
        tapWhenSettled(app, "place_guide_advance")
        let panelTab = app.tabEntry(.panel)
        let onPanel = NSPredicate(format: "isSelected == true")
        expectation(for: onPanel, evaluatedWith: panelTab)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(element(app, "setup_deck_current").waitForExistence(timeout: 5))
        sleep(1)
        attach(app, "paso6-vuelve-al-panel")
    }

    /// Paso 3 terminado con la barra de pestañas ENCOGIDA: el aviso «Tus presupuestos viven en Más» la despliega, y
    /// tocar «Más» sigue la guía hasta Presupuestos.
    func test_avisoVivenEnMas_despliegaLaBarra_yTocarMasSigue() {
        let app = XCUIApplication()
        app.launchForUITest(
            seed: "cuenta-con-movimientos",
            extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck", "-uitest-setup-deck-at", "3"])
        XCTAssertTrue(app.waitForUITestReady())
        let deck = element(app, "setup_deck_current")
        XCTAssertTrue(deck.waitForExistence(timeout: 10))

        // Un arrastre corto encoge la barra sin perder el mazo de vista.
        let more = app.tabEntry(.more)
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        for _ in 0..<3 where more.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)))
        }
        XCTAssertFalse(more.exists, "El escenario necesita la barra encogida, sin «Más» a la vista.")
        if !deck.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.33)))
        }

        // Paso 3, de punta a punta.
        tapWhenSettled(app, "setup_deck_current")
        tapWhenSettled(app, "first_budget_start")
        tapWhenSettled(app, "first_budget_scope_all")
        tapWhenSettled(app, "first_budget_period_monthly")
        tapWhenSettled(app, "first_budget_limit")
        element(app, "first_budget_limit").typeText("600")
        tapWhenSettled(app, "first_budget_limit_send")
        tapWhenSettled(app, "first_budget_name_yes")
        tapWhenSettled(app, "first_budget_alert_none")
        tapWhenSettled(app, "first_budget_panel_yes")
        tapWhenSettled(app, "first_budget_done")

        // El aviso: la barra desplegada, con «Más» a la vista.
        XCTAssertTrue(element(app, "place_guide_card").waitForExistence(timeout: 10))
        XCTAssertTrue(more.waitForExistence(timeout: 3), "Con el aviso a la vista, la barra va desplegada.")
        sleep(1)
        attach(app, "aviso-viven-en-mas")

        // Tocar «Más» sigue la guía: ya dentro, Presupuestos enmarcado y «Entendido».
        more.tap()
        XCTAssertTrue(element(app, "place_guide_advance").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["more_card_budgets"].firstMatch.waitForExistence(timeout: 3))
        sleep(1)
        attach(app, "aviso-dentro-de-mas")
        tapWhenSettled(app, "place_guide_advance")
    }
}
