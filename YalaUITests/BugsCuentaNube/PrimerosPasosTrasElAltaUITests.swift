//
//  PrimerosPasosTrasElAltaUITests.swift
//  YalaUITests / BugsCuentaNube
//
//  Bug C (Jürgen, 25-nov-2026): una cuenta nueva no veía Primeros pasos, ni en «Solo gastos» ni en «Gastos e ingresos».
//  El mazo exige la marca de instalación nueva de 2.3, que solo se decidía en el primer arranque con ese código: en un
//  teléfono que ya tenía Yala, nunca. Las pruebas no lo veían porque las que miran el mazo lanzan con
//  `-uitest-fresh-install`, que pone la marca a mano, y las que recorren el alta no miran el mazo.
//
//  Aquí el teléfono es uno de ANTES de 2.3 (`-uitest-reset` sin `-uitest-fresh-install`, la barra de siempre) y la
//  persona hace el alta entera por la conversación. `-uitest-show-setup-deck` solo deja salir el mazo, que bajo `-uitest`
//  se calla: no pone la marca (`AppBootstrapper` solo escribe `setup.isNewInstall`). Sin el arreglo, los dos casos caen
//  en la espera del mazo.
//

import XCTest

final class PrimerosPasosTrasElAltaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func signUpWithICloud(_ app: XCUIApplication, tracking: String) {
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil,
                            extraArguments: ["-uitest-show-setup-deck"])
        XCTAssertTrue(app.waitForWelcomeShowcase(), "No salió la bienvenida.")
        app.buttons["welcome_access_icloud"].tap()

        let field = app.textFields["welcome_chat_name_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 20), "No llegó la conversación.")
        field.tap()
        field.typeText("Ana")
        app.buttons["welcome_chat_name_send"].tap()
        let currency = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "welcome_chat_currency_"))
            .firstMatch
        XCTAssertTrue(currency.waitForExistence(timeout: 10), "No llegó la pregunta de la moneda.")
        currency.tap()
        let option = app.buttons[tracking]
        XCTAssertTrue(option.waitForExistence(timeout: 10), "No llegó la pregunta de qué llevar.")
        option.tap()
        let enter = app.buttons["welcome_chat_enter"]
        XCTAssertTrue(enter.waitForExistence(timeout: 10), "La conversación no terminó.")
        enter.tap()
        XCTAssertTrue(app.waitForRootNavigation(timeout: 30), "No se llegó a la app.")
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// «Gastos e ingresos»: el Panel llega con el mazo en el paso 1, no con «Crea tu primera cuenta» suelto.
    func test_gastosEIngresos_enUnTelefonoDeAntes_saleElMazo() throws {
        let app = XCUIApplication()
        signUpWithICloud(app, tracking: "welcome_chat_tracking_both")
        let deck = app.buttons["setup_deck_current"]
        XCTAssertTrue(deck.waitForExistence(timeout: 15), "Tras el alta con «Gastos e ingresos» no salió Primeros pasos.")
        XCTAssertTrue(deck.label.contains("1 de 7"), "El mazo empieza en el paso 1: «\(deck.label)».")
        attach(app, "gastos-e-ingresos-mazo")
    }

    /// «Solo gastos»: la cuenta de gastos ya existe, así que el mazo empieza más adelante, pero sale.
    func test_soloGastos_enUnTelefonoDeAntes_saleElMazo() throws {
        let app = XCUIApplication()
        signUpWithICloud(app, tracking: "welcome_chat_tracking_expenses")
        let deck = app.buttons["setup_deck_current"]
        XCTAssertTrue(deck.waitForExistence(timeout: 15), "Tras el alta con «Solo gastos» no salió Primeros pasos.")
        XCTAssertTrue(deck.label.contains("de 7"), "El mazo de siete pasos: «\(deck.label)».")
        attach(app, "solo-gastos-mazo")
    }
}
