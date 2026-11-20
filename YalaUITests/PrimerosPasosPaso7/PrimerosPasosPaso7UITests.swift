//
//  PrimerosPasosPaso7UITests.swift
//  YalaUITests
//
//  Opción B de Jürgen (20-nov-2026, tema 4 de las maquetas de Primeros pasos): la oferta del mes de Pro sale al terminar
//  «Aprender a registrar», después de «¿Borramos los de prueba?» y de la guía de la Bandeja, y no al final del paso 7.
//  Los precios son los de mentira de `-uitest-fake-prices` (StoreKit no contesta en XCUITest): sin ellos la oferta se
//  retiene para el arranque siguiente y no saldría.
//

import XCTest

final class PrimerosPasosPaso7UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
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

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// El paso 2 a mano, con las otras tres maneras omitidas: tras «¿Borramos los de prueba?» y la guía de la Bandeja sube
    /// la oferta, con el botón de empezar solo y abajo; «Ahora no» la cierra y el mazo sigue en el paso 3.
    func test_step2_finishedByItsTutorial_offersTheMonthOfPro() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "una-cuenta", extraArguments: [
            "-uitest-fresh-install", "-uitest-show-setup-deck", "-uitest-fake-prices", "eligible"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        let deck = app.buttons["setup_deck_current"]
        expectation(for: NSPredicate(format: "label CONTAINS %@", "2 de 7"), evaluatedWith: deck)
        waitForExpectations(timeout: 10)
        tapWhenSettled(app, "setup_deck_current")
        tapWhenSettled(app, "record_tutorial_start_manual")

        // El registro a mano, con la guía de foco (el mismo camino que `Bienvenida23PasosUITests`).
        XCTAssertTrue(element(app, "coach_mark_progress").waitForExistence(timeout: 10))
        tapWhenSettled(app, "new_transaction_amount")
        element(app, "new_transaction_amount").typeText("25")
        tapWhenSettled(app, "new_transaction_amount_question")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        tapWhenSettled(app, "coach_mark_primary")
        tapWhenSettled(app, "coach_mark_primary")
        tapWhenSettled(app, "new_transaction_save")
        tapWhenSettled(app, "transaction_success_accept")

        // La oferta de 2.2 (tras guardar un registro) ya no sale dentro del tutorial.
        XCTAssertTrue(element(app, "record_tutorial_headline").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "trial_offer_cta").exists, "La oferta de tras guardar salió dentro del paso 2.")
        for _ in 0..<3 { tapWhenSettled(app, "record_tutorial_skip") }
        tapWhenSettled(app, "record_tutorial_finish")

        // «¿Borramos los de prueba?» primero: la oferta no la tapa.
        XCTAssertTrue(element(app, "practice_cleanup_title").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "setup_offer_title").exists, "La oferta tapó «¿Borramos los de prueba?».")
        tapWhenSettled(app, "practice_cleanup_delete")
        let guide = element(app, "place_guide_card")
        XCTAssertTrue(guide.waitForExistence(timeout: 10), "No salió la guía de la Bandeja.")
        XCTAssertFalse(element(app, "setup_offer_title").exists, "La oferta tapó la guía de la Bandeja.")
        tapWhenSettled(app, "place_guide_advance")

        // Después, la oferta del mes de Pro.
        let title = element(app, "setup_offer_title")
        XCTAssertTrue(title.waitForExistence(timeout: 15), "Al terminar el paso 2 no subió la oferta del mes de Pro.")
        XCTAssertTrue(element(app, "setup_offer_features").exists, "Las tres funciones.")
        XCTAssertTrue(element(app, "setup_offer_cta").isHittable, "El botón de empezar se ve sin bajar.")
        attach(app, "oferta-tras-paso-2")
        tapWhenSettled(app, "setup_offer_close")
        XCTAssertTrue(title.waitForNonExistence(timeout: 10), "«Ahora no» cierra la oferta.")
        expectation(for: NSPredicate(format: "label CONTAINS %@", "3 de 7"), evaluatedWith: deck)
        waitForExpectations(timeout: 10)
    }
}
