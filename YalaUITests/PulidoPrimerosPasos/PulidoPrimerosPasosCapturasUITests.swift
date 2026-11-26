//
//  PulidoPrimerosPasosCapturasUITests.swift
//  YalaUITests
//
//  El pulido de Primeros pasos y del paywall visto en el iPhone 14 (observación del 25-nov-2026), con una captura por
//  punto: la fila de pasos del mazo, «Otra moneda» al añadir una, la intro de Grupos, el final con pasos para después y
//  el confeti, y el paywall sin precios. La lógica la fijan los tests de `YalaTests/PulidoPrimerosPasos/`.
//

import XCTest

final class PulidoPrimerosPasosCapturasUITests: XCTestCase {

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

    /// La fila de pasos con «Presupuesto» y el selector de la segunda moneda con «Otra moneda».
    func test_capturas_filaDePasos_yOtraMoneda() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck"])
        XCTAssertTrue(app.waitForUITestReady())
        XCTAssertTrue(element(app, "setup_deck_progress").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "setup_deck_step_firstBudget").exists)
        attach(app, "d01-fila-de-pasos")

        tapWhenSettled(app, "setup_deck_current")
        tapWhenSettled(app, "first_account_start")
        tapWhenSettled(app, "first_account_kind_creditCard")
        tapWhenSettled(app, "first_account_add_currency")
        XCTAssertTrue(app.navigationBars["Otra moneda"].waitForExistence(timeout: 10),
                      "Al añadir una moneda, la hoja dice «Otra moneda».")
        attach(app, "d02-otra-moneda")
    }

    /// La intro de Grupos dice «Antes de empezar», sin «paso 1 de 3».
    func test_capturas_introDeGrupos() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "una-cuenta", extraArguments: [
            "-uitest-fresh-install", "-uitest-show-setup-deck", "-uitest-setup-deck-at", "5"])
        XCTAssertTrue(app.waitForUITestReady())
        tapWhenSettled(app, "setup_deck_current")
        let eyebrow = element(app, "tutorial_story_eyebrow")
        XCTAssertTrue(eyebrow.waitForExistence(timeout: 10))
        XCTAssertEqual(eyebrow.label, "Antes de empezar")
        attach(app, "d03-intro-grupos")
    }

    /// Terminar el paso 7 con los anteriores para después: «¡Listo por ahora!», el confeti sin tapar «Cerrar», y la
    /// oferta de Pro sin precios con el texto neutro.
    func test_capturas_finalConPasosParaDespues_yPaywallSinPrecios() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "una-cuenta", extraArguments: [
            "-uitest-fresh-install", "-uitest-show-setup-deck", "-uitest-setup-deck-at", "7"])
        XCTAssertTrue(app.waitForUITestReady())
        tapWhenSettled(app, "setup_deck_current")
        // Las historias del paso 7 hasta «Terminar».
        let finish = element(app, "tutorial_story_finish")
        let stage = element(app, "tutorial_story_stage")
        XCTAssertTrue(stage.waitForExistence(timeout: 10))
        for _ in 0..<12 where !finish.exists {
            stage.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        tapWhenSettled(app, "tutorial_story_finish")

        let title = element(app, "setup_deck_done_title")
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertEqual(title.label, "¡Listo por ahora!", "Con pasos para después no dice «completos».")
        attach(app, "d04-final-con-confeti")
        XCTAssertTrue(element(app, "setup_deck_done_close").isHittable)

        let pro = app.buttons["Pasarme a Pro"].firstMatch
        guard pro.waitForExistence(timeout: 5) else { return }
        _ = app.waitForSettledLayout(of: pro)
        pro.tap()
        let prices = element(app, "subscription_prices_unavailable")
        if prices.waitForExistence(timeout: 15) {
            XCTAssertEqual(prices.label, "Ahora no podemos mostrar los precios. Inténtalo en un rato.")
            attach(app, "d05-paywall-sin-precios")
        }
    }
}
