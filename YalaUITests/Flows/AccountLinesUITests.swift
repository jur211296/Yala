//
//  AccountLinesUITests.swift
//  YalaUITests
//
//  Tarjeta con varias divisas, entrega 2 (`multi-currency-accounts-2-card-view`). Seed `tarjeta-dos-lineas`: «Visa QA»
//  (crédito, PEN) con su línea «Visa QA · USD», «Ahorros QA» (PEN) y «Dólares QA» (USD). La tarjeta sale UNA vez en el
//  Panel con sus dos saldos y el total «≈», y en Ajustes con la línea anidada debajo; «Otras divisas» está a la vista
//  en el formulario de la tarjeta de crédito y explica por qué no se puede vincular cada cuenta.
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los nombres sembrados, que no se traducen).
//

import XCTest

final class AccountLinesUITests: XCTestCase {

    private let card = "Visa QA"
    private let line = "Visa QA · USD"
    private let savings = "Ahorros QA"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "tarjeta-dos-lineas")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "La app no llegó al Panel.")
        return app
    }

    // MARK: - Panel

    /// Plegada, «Tus finanzas» enseña un chip por tarjeta: tres, no cuatro. La línea no sale como cuenta propia.
    func test_panel_theCardWithTwoLines_showsOnce() {
        let app = launch()
        if app.buttons["panel_account_card_0"].waitForExistence(timeout: 3) {
            app.buttons["panel_panorama_header"].tap()
        }
        XCTAssertTrue(app.buttons["panel_account_chip_0"].waitForExistence(timeout: 5), "No salieron los chips.")
        XCTAssertTrue(app.buttons["panel_account_chip_2"].exists)
        XCTAssertFalse(app.buttons["panel_account_chip_3"].exists,
                       "Hay un cuarto chip: la línea en dólares sale como cuenta suelta.")
        let visaChip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(card).")).firstMatch
        XCTAssertTrue(visaChip.exists, "No hay chip de «\(card)».")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(line)")).firstMatch.exists)
        XCTAssertTrue(visaChip.label.contains("≈"), "El chip de la tarjeta no da su total convertido: «\(visaChip.label)».")
    }

    /// Desplegada, la tarjeta de «Visa QA» trae los dos saldos y el total «≈».
    func test_panel_theCardShowsBothBalancesAndAnApproximateTotal() {
        let app = launch()
        let first = app.buttons["panel_account_card_0"]
        if !first.waitForExistence(timeout: 3) {
            app.buttons["panel_panorama_header"].tap()
        }
        XCTAssertTrue(first.waitForExistence(timeout: 5), "No apareció la primera tarjeta.")
        let visa = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(card).")).firstMatch
        var swipes = 0
        while !visa.exists && swipes < 5 {
            first.swipeLeft()
            swipes += 1
        }
        XCTAssertTrue(visa.waitForExistence(timeout: 5), "No hay tarjeta de «\(card)».")
        let label = visa.label
        XCTAssertTrue(label.contains("1,250") || label.contains("1.250"), "Falta el saldo en soles: «\(label)».")
        XCTAssertTrue(label.contains("80"), "Falta el saldo en dólares: «\(label)».")
        XCTAssertTrue(label.contains("≈"), "Falta el total convertido: «\(label)».")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(line).")).firstMatch.exists,
                       "La línea sale como tarjeta propia.")
    }

    // MARK: - Ajustes y formulario

    /// Ajustes enseña la tarjeta una vez y su línea anidada; antes la línea no salía en ningún sitio.
    func test_settings_nestsTheLineUnderItsCard() {
        let app = launch()
        app.openProfile()
        app.openSettingsSection("profile_accounts")
        XCTAssertTrue(app.buttons["accounts_row_\(card)"].waitForExistence(timeout: 5), "No sale la tarjeta.")
        XCTAssertTrue(app.buttons["accounts_line_row_\(line)"].waitForExistence(timeout: 5),
                      "La línea en dólares no sale anidada bajo su tarjeta.")
        XCTAssertFalse(app.buttons["accounts_row_\(line)"].exists, "La línea sale como fila propia.")
    }

    /// En la tarjeta de crédito, «Añadir línea» y «Vincular» están a la vista, sin menús; vincular explica por qué no
    /// se puede cada cuenta.
    func test_creditCardForm_offersLinesUpFront_andExplainsEachRejection() {
        let app = launch()
        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let row = app.buttons["accounts_row_\(card)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let add = app.buttons["account_lines_add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "El formulario de la tarjeta no ofrece añadir una línea.")
        let link = app.buttons["account_lines_link"]
        XCTAssertTrue(link.exists, "El formulario de la tarjeta no ofrece vincular una cuenta.")
        var swipes = 0
        while !app.windows.firstMatch.frame.contains(link.frame) && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(link.waitForHittable(timeout: 3))
        link.tap()

        let savingsRow = app.buttons["account_link_candidate_\(savings)"]
        XCTAssertTrue(savingsRow.waitForExistence(timeout: 5), "No aparece «\(savings)» para vincular.")
        XCTAssertFalse(savingsRow.isEnabled, "Se puede vincular una cuenta de la misma divisa.")
        XCTAssertTrue(savingsRow.label.count > savings.count + 4, "No dice por qué: «\(savingsRow.label)».")
    }

    /// Una cuenta de ahorro también puede tener líneas: la sección está, al final del formulario.
    func test_savingsForm_offersLines() {
        let app = launch()
        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let row = app.buttons["accounts_row_\(savings)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.textFields["account_name_field"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["account_lines_add"].waitForExistence(timeout: 5),
                      "Una cuenta de ahorro no ofrece añadir una línea en otra divisa.")
    }
}
