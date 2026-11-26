//
//  OfertaProMazoCentradoUITests.swift
//  YalaUITests
//
//  Decisión de Jürgen del 25-nov-2026 («C y B»): (B) en el paso 1 el mazo va centrado con «Hola, <nombre>»; tras el paso
//  1, sin saludo y arriba. (C) con derecho al mes gratis, la tarjeta «¡Primeros pasos completos!» lleva la oferta y su
//  botón abre la hoja «Prueba Yala Pro 1 mes gratis»; sin derecho, como hoy. Cada caso deja su captura (claro y oscuro los
//  da el aspecto del simulador). Los precios se fingen con `-uitest-fake-prices`: Yala Dev no los tiene.
//

import XCTest

final class OfertaProMazoCentradoUITests: XCTestCase {

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

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck"] + extra)
        XCTAssertTrue(app.waitForUITestReady())
        return app
    }

    // MARK: - B · El mazo centrado con saludo

    /// Paso 1 con nombre: «Hola, Jürgen» y el mazo en el centro de la pantalla.
    func test_paso1_conNombre_saludaYCentra() {
        let app = launch(["-userName", "Jürgen Schmidt"])
        let title = element(app, "setup_deck_greeting_title")
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let deck = element(app, "setup_deck_current")
        XCTAssertTrue(deck.waitForExistence(timeout: 10))
        _ = app.waitForSettledLayout(of: deck)
        attach(app, "b-paso1-con-nombre")
        XCTAssertEqual(title.label, "Hola, Jürgen")
        XCTAssertTrue(element(app, "setup_deck_greeting_subtitle").exists)
        // El bloque saludo + mazo queda en el tercio central: sin centrar, el mazo estaría a ~110 pt de arriba.
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(title.frame.minY, window.height * 0.2, "El saludo bajó hacia el centro.")
        XCTAssertLessThan(deck.frame.maxY, window.height * 0.85, "El mazo no se va al fondo.")
    }

    /// Paso 1 sin nombre: solo «Hola».
    func test_paso1_sinNombre_soloHola() {
        let app = launch([])
        let title = element(app, "setup_deck_greeting_title")
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        attach(app, "b-paso1-sin-nombre")
        XCTAssertEqual(title.label, "Hola")
    }

    /// Tras el paso 1, el saludo se va y el mazo vuelve arriba.
    func test_paso2_sinSaludo() {
        let app = launch(["-userName", "Jürgen", "-uitest-setup-deck-at", "2"])
        let deck = element(app, "setup_deck_current")
        XCTAssertTrue(deck.waitForExistence(timeout: 10))
        _ = app.waitForSettledLayout(of: deck)
        attach(app, "b-paso2-arriba")
        XCTAssertFalse(element(app, "setup_deck_greeting").exists, "Sin saludo tras el paso 1.")
    }

    // MARK: - C · El mes gratis en la tarjeta final

    /// Con derecho: la oferta va dentro de la tarjeta final y su botón abre la hoja con los planes.
    func test_final_conDerecho_ofertaEnLaTarjeta() {
        let app = launch(["-uitest-setup-deck-at", "8", "-uitest-fake-prices"])
        let cta = element(app, "setup_deck_offer_cta")
        XCTAssertTrue(cta.waitForExistence(timeout: 10), "La tarjeta final lleva «Empezar mi mes gratis».")
        _ = app.waitForSettledLayout(of: cta)
        attach(app, "c-final-con-derecho")
        XCTAssertTrue(element(app, "setup_deck_offer_chip").exists)
        XCTAssertTrue(element(app, "setup_deck_offer_not_now").exists)
        XCTAssertTrue(element(app, "setup_deck_done_close").exists)
        XCTAssertTrue(cta.isHittable, "El botón cabe sin bajar.")
        XCTAssertFalse(element(app, "setup_offer_title").exists, "La hoja no sube sola encima de la tarjeta.")

        cta.tap()
        XCTAssertTrue(element(app, "setup_offer_title").waitForExistence(timeout: 10), "Abre la hoja del mes gratis.")
        XCTAssertTrue(element(app, "setup_offer_plans").exists, "Con los planes.")
        attach(app, "c-hoja-mes-gratis")
    }

    /// «Ahora no» pliega la oferta y deja la tarjeta con «Cerrar».
    func test_final_ahoraNo_plegaLaOferta() {
        let app = launch(["-uitest-setup-deck-at", "8", "-uitest-fake-prices"])
        let notNow = element(app, "setup_deck_offer_not_now")
        XCTAssertTrue(notNow.waitForExistence(timeout: 10))
        _ = app.waitForSettledLayout(of: notNow)
        notNow.tap()
        XCTAssertTrue(element(app, "setup_deck_done_close").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "setup_deck_offer_cta").exists, "La oferta se pliega.")
        attach(app, "c-final-ahora-no")
    }

    /// Sin derecho (ya usó la prueba): la tarjeta final de siempre, sin oferta.
    func test_final_sinDerecho_comoHoy() {
        let app = launch(["-uitest-setup-deck-at", "8", "-uitest-fake-prices", "trial-used"])
        let close = element(app, "setup_deck_done_close")
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        attach(app, "c-final-sin-derecho")
        XCTAssertFalse(element(app, "setup_deck_offer_cta").exists, "Sin derecho no hay oferta en la tarjeta.")
    }
}
