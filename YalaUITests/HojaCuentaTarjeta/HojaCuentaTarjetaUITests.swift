//
//  HojaCuentaTarjetaUITests.swift
//  YalaUITests
//
//  La hoja de una cuenta del Panel con la tarjeta personalizada arriba (pedido de Jürgen del 17-nov-2026).
//  - Tarjeta de crédito con corte (`tarjeta-corte`, «Visa QA»): la tarjeta, el monto y el estado de cuenta con fechas.
//  - Débito («Ahorros QA»): la tarjeta y el monto, sin bloque de tarjeta de crédito.
//  - Tarjeta sin día de corte (`tarjeta-dos-lineas`): pide las fechas, y el botón abre el formulario de la cuenta.
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los nombres sembrados).
//

import XCTest

final class HojaCuentaTarjetaUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openAccount(_ name: String, seed: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: seed, extraArguments: ["-defaultPeriod", "last30Days"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "La app no llegó al Panel.")
        let first = app.buttons["panel_account_card_0"]
        if !first.waitForExistence(timeout: 3) {
            app.buttons["panel_panorama_header"].tap()
        }
        XCTAssertTrue(first.waitForExistence(timeout: 5), "No apareció la primera tarjeta.")
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name).")).firstMatch
        var swipes = 0
        while !card.exists && swipes < 6 {
            first.swipeLeft()
            swipes += 1
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "No hay tarjeta de «\(name)».")
        card.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["account_detail_sheet"].firstMatch.waitForExistence(timeout: 8),
            "No abrió la ficha."
        )
        return app
    }

    /// Crédito con corte: arriba la tarjeta (con su nombre), debajo el monto y el estado de cuenta con sus fechas.
    func test_tarjetaDeCredito_enseñaTarjeta_monto_yEstadoDeCuenta() {
        let app = openAccount("Visa QA", seed: "tarjeta-corte")
        let tarjeta = app.descendants(matching: .any)["hoja_cuenta_tarjeta"].firstMatch
        XCTAssertTrue(tarjeta.waitForExistence(timeout: 5), "La hoja no trae la tarjeta arriba.")
        XCTAssertTrue(tarjeta.label.hasPrefix("Visa QA."), "La tarjeta no dice el nombre de la cuenta: \(tarjeta.label)")
        let monto = app.descendants(matching: .any)["hoja_cuenta_monto"].firstMatch
        XCTAssertTrue(monto.exists, "Falta el monto bajo la tarjeta.")
        XCTAssertLessThan(tarjeta.frame.minY, monto.frame.minY, "La tarjeta tiene que ir encima del monto.")
        XCTAssertTrue(app.descendants(matching: .any)["hoja_cuenta_estado"].firstMatch.exists,
                      "Falta el estado de cuenta de la tarjeta.")
        XCTAssertTrue(app.descendants(matching: .any)["hoja_cuenta_fechas"].firstMatch.exists,
                      "Faltan la fecha de pago y el próximo corte.")
        XCTAssertFalse(app.descendants(matching: .any)["hoja_cuenta_sin_fechas"].firstMatch.exists,
                       "Con día de corte no se piden las fechas.")
        // Lo que ya tenía la hoja sigue: el selector de divisas, Editar y la X.
        XCTAssertTrue(app.descendants(matching: .any)["account_detail_line_picker"].firstMatch.exists)
        XCTAssertTrue(app.buttons["account_detail_edit"].exists)
        XCTAssertTrue(app.buttons["account_detail_close"].exists)
    }

    /// Débito: la tarjeta y el monto, sin bloque de tarjeta de crédito.
    func test_debito_sinBloqueDeTarjetaDeCredito() {
        let app = openAccount("Ahorros QA", seed: "tarjeta-corte")
        XCTAssertTrue(app.descendants(matching: .any)["hoja_cuenta_tarjeta"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["hoja_cuenta_monto"].firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)["hoja_cuenta_estado"].firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)["hoja_cuenta_sin_fechas"].firstMatch.exists)
    }

    /// Tarjeta sin día de corte: lo dice y «Añadir fechas» abre el formulario de la cuenta.
    func test_tarjetaSinFechas_lasPide_yAbreElFormulario() {
        let app = openAccount("Visa QA", seed: "tarjeta-dos-lineas")
        let aviso = app.descendants(matching: .any)["hoja_cuenta_sin_fechas"].firstMatch
        XCTAssertTrue(aviso.waitForExistence(timeout: 5), "La tarjeta sin corte no pide las fechas.")
        XCTAssertFalse(app.descendants(matching: .any)["hoja_cuenta_estado"].firstMatch.exists)
        app.buttons["hoja_cuenta_anadir_fechas"].tap()
        XCTAssertTrue(app.textFields["account_name_field"].waitForExistence(timeout: 8),
                      "«Añadir fechas» no abrió el formulario de la cuenta.")
    }
}
