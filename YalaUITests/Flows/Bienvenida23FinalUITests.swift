//
//  Bienvenida23FinalUITests.swift
//  YalaUITests
//
//  Lote 05 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md): el paso 6 (Y23-14), el paso 7 (Y23-16) y el final con la
//  oferta de Pro (Y23-18), recorridos de punta a punta. El mazo arranca en el paso que toca con `-uitest-setup-deck-at`
//  (los anteriores omitidos) y los precios son los de mentira de `-uitest-fake-prices` (StoreKit no contesta en XCUITest).
//

import XCTest

final class Bienvenida23FinalUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(atStep step: Int, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            seed: "cuenta-con-movimientos",
            extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck", "-uitest-setup-deck-at", "\(step)",
                             "-uitest-fake-prices", "eligible"] + extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        return app
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

    /// Y23-14: «Omitir» en «Tus gráficas viven en Más» pasa el mazo al paso 7 (antes se quedaba en el 6).
    func test_step6_skippingTheGuide_movesTheDeckToStep7() {
        let app = launch(atStep: 6)
        let deck = app.buttons["setup_deck_current"]
        XCTAssertTrue(deck.waitForExistence(timeout: 10))
        XCTAssertTrue(deck.label.contains("6 de 7"), "El mazo empieza en el paso 6: «\(deck.label)».")
        tapWhenSettled(app, "setup_deck_current")
        tapWhenSettled(app, "place_guide_skip")
        expectation(for: NSPredicate(format: "label CONTAINS %@", "7 de 7"), evaluatedWith: deck)
        waitForExpectations(timeout: 10)
    }

    /// Y23-16: cuatro maneras (sin el correo), cada una omitible, con la pantalla de entre medias; al terminar con alguna
    /// vista, el mazo se completa y queda «¡Primeros pasos completos!» (Y23-18).
    func test_step7_fourWays_doneAndSkipped_thenTheDeckCompletes() {
        let app = launch(atStep: 7)
        tapWhenSettled(app, "setup_deck_current")
        XCTAssertTrue(element(app, "home_tutorial_skip_step").waitForExistence(timeout: 10))
        attach(app, "paso7-pagina-corta")
        tapWhenSettled(app, "home_tutorial_start")

        // 1 de 4 · Widget: hecho.
        XCTAssertTrue(element(app, "home_tutorial_step_4").waitForExistence(timeout: 10), "El widget va en 4 pasos.")
        tapWhenSettled(app, "home_tutorial_method_done")
        // Entre medias: «¡Van 1 de 4!» y la que sigue.
        let between = element(app, "home_tutorial_between_title")
        XCTAssertTrue(between.waitForExistence(timeout: 10))
        XCTAssertTrue(between.label.contains("1") && between.label.contains("4"), "«\(between.label)»")
        // 2 de 4 · Apple Pay: omitida desde su mini tutorial.
        tapWhenSettled(app, "home_tutorial_next")
        tapWhenSettled(app, "home_tutorial_method_skip")
        // 3 de 4 · Compartir: omitida desde la pantalla de entre medias.
        tapWhenSettled(app, "home_tutorial_next_skip")
        // 4 de 4 · Siri: hecho. Es la última: no hay pantalla de entre medias y se cierra el paso.
        tapWhenSettled(app, "home_tutorial_next")
        XCTAssertTrue(element(app, "home_tutorial_method_title").waitForExistence(timeout: 10))
        tapWhenSettled(app, "home_tutorial_method_done")

        XCTAssertTrue(element(app, "setup_deck_done_title").waitForExistence(timeout: 10),
                      "Con el paso 7 resuelto, el mazo desaparece y queda «¡Primeros pasos completos!».")
        attach(app, "final-tarjeta")
    }

    /// Y23-18: la oferta sube sola tras el final con el anual preseleccionado y la línea de tiempo; «Seguir con la versión
    /// gratis» la cierra sin dar Pro.
    func test_final_offer_keepFree_closesWithoutPro() {
        let app = launch(atStep: 8)
        let title = element(app, "setup_offer_title")
        XCTAssertTrue(title.waitForExistence(timeout: 15), "La oferta del final sube sola.")
        XCTAssertTrue(title.label.contains("1"), "La prueba de un mes se anuncia como «1 mes»: «\(title.label)».")
        XCTAssertTrue(element(app, "setup_offer_plans").exists)
        attach(app, "oferta")
        app.swipeUp()
        XCTAssertTrue(element(app, "setup_offer_timeline").waitForExistence(timeout: 5))
        tapWhenSettled(app, "setup_offer_keep_free")
        XCTAssertTrue(title.waitForNonExistence(timeout: 10), "«Seguir con la versión gratis» cierra la oferta.")
        XCTAssertFalse(element(app, "setup_offer_success_title").exists, "Sin confirmar en la hoja de pago no hay Pro.")
        XCTAssertTrue(element(app, "setup_deck_done_title").waitForExistence(timeout: 5))
    }

    /// Y23-18: con la compra confirmada (fingida), «¡Listo! Tienes Pro» con la fecha real del fin de la prueba.
    func test_final_offer_confirmedPurchase_showsProIsOn() {
        // La compra fingida deja Pro con la prueba de un mes en curso, como la confirma Apple.
        let app = launch(atStep: 8, extra: ["-uitest-fake-purchase", "-uitest-pro-trial-days", "30"])
        XCTAssertTrue(element(app, "setup_offer_title").waitForExistence(timeout: 15))
        app.swipeUp()
        tapWhenSettled(app, "setup_offer_cta")
        XCTAssertTrue(element(app, "setup_offer_success_title").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "setup_offer_success_line").exists, "Dice hasta cuándo va la prueba y cuándo avisamos.")
        attach(app, "listo-tienes-pro")
        tapWhenSettled(app, "setup_offer_start_using")
        XCTAssertTrue(element(app, "setup_offer_success_title").waitForNonExistence(timeout: 10))
    }
}
