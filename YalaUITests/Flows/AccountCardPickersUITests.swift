//
//  AccountCardPickersUITests.swift
//  YalaUITests
//
//  Tarjeta con varias divisas, entrega 3 (`multi-currency-accounts-3-pickers-and-capture`). Seed `tarjeta-dos-lineas`:
//  «Visa QA» (crédito, PEN) con su línea «Visa QA · USD» (gasto «Hotel QA», −80 US$), «Ahorros QA» (PEN) y «Dólares QA»
//  (USD). Se elige la tarjeta y la divisa decide la línea: el selector la enseña una vez con la línea debajo, el filtro por
//  la tarjeta trae los movimientos de las dos, y un presupuesto de la tarjeta cuenta el gasto en dólares.
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los nombres sembrados, que no se traducen).
//

import XCTest

final class AccountCardPickersUITests: XCTestCase {

    private let card = "Visa QA"
    private let line = "Visa QA · USD"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "tarjeta-dos-lineas")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "La app no llegó al Panel.")
        return app
    }

    // MARK: - Selector

    /// La tarjeta sale una vez, con sus divisas, y la línea justo debajo. Tocar la tarjeta y la pastilla de dólares deja
    /// el registro en la línea.
    func test_selector_nestsTheLineUnderItsCard_andThePillPicksTheLine() {
        let app = launch()
        app.buttons["panel_action_new"].tap()

        // La primera fila sigue siendo una cabeza: los UITests que eligen la primera fila no cambian de cuenta.
        let first = app.openSelectorFirstRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
        XCTAssertFalse(first.identifier.hasSuffix("· USD"), "La primera fila es una línea: «\(first.identifier)».")

        let cardRow = app.buttons["account_selector_row_\(card)"]
        let lineRow = app.buttons["account_selector_row_\(line)"]
        XCTAssertTrue(cardRow.waitForExistence(timeout: 5), "No está la fila de la tarjeta.")
        XCTAssertTrue(lineRow.exists, "No está la fila de la línea.")
        XCTAssertTrue(cardRow.label.contains("PEN · USD"), "La tarjeta no dice sus divisas: «\(cardRow.label)».")
        XCTAssertGreaterThan(lineRow.frame.minY, cardRow.frame.minY, "La línea no va debajo de su tarjeta.")
        let dollars = app.buttons["account_selector_row_Dólares QA"]
        XCTAssertTrue(dollars.frame.maxY <= cardRow.frame.minY || dollars.frame.minY >= lineRow.frame.maxY,
                      "Otra cuenta se mete entre la tarjeta y su línea.")

        cardRow.tap()
        let accountChip = app.buttons["new_transaction_account_chip"]
        XCTAssertTrue(accountChip.waitForExistence(timeout: 5))
        XCTAssertEqual(accountChip.label, card, "La pastilla de cuenta no dice la tarjeta.")
        let usdPill = app.buttons["new_transaction_card_currency_USD"]
        let penPill = app.buttons["new_transaction_card_currency_PEN"]
        XCTAssertTrue(usdPill.waitForExistence(timeout: 5), "No salieron las pastillas de divisa de la tarjeta.")
        XCTAssertTrue(penPill.isSelected, "Con el importe en soles, elegir la tarjeta tiene que dejar la principal.")

        usdPill.tap()
        XCTAssertTrue(usdPill.waitForSelected(), "La pastilla de dólares no quedó elegida.")
        XCTAssertFalse(penPill.isSelected)
        XCTAssertEqual(accountChip.label, card, "Elegir la divisa no puede cambiar el nombre de la tarjeta.")
    }

    // MARK: - Filtro

    /// El filtro ofrece la tarjeta y no la línea, y elegir la tarjeta trae también el gasto en dólares.
    func test_filter_byTheCard_includesTheLineMovements() {
        let app = launch()
        app.buttons["panel_filters_button"].tap()

        let cardChip = app.buttons[card]
        XCTAssertTrue(cardChip.waitForExistence(timeout: 5), "El filtro no ofrece la tarjeta.")
        XCTAssertFalse(app.buttons[line].exists, "El filtro enseña la línea como otra cuenta.")
        cardChip.tap()
        XCTAssertTrue(app.staticTexts["1/3"].waitForExistence(timeout: 3),
                      "El contador no cuenta tarjetas (esperado 1/3).")
        app.buttons["filters_apply_button"].tap()

        let hotel = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Hotel QA")).firstMatch
        let supermarket = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Supermercado QA")).firstMatch
        let salary = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sueldo QA")).firstMatch
        XCTAssertTrue(app.scrollTo(supermarket), "Falta el gasto en soles de la tarjeta.")
        XCTAssertTrue(hotel.exists, "Falta el gasto en dólares de la línea: el filtro por la tarjeta no la incluye.")
        XCTAssertFalse(salary.exists, "Sale un movimiento de otra cuenta.")
    }

    // MARK: - Presupuesto

    /// Un presupuesto de la tarjeta cuenta el gasto de su línea en dólares, convertido: sin él serían S/ 1.250 de 3.000
    /// (41 %); con él pasa del 41 %.
    func test_budgetOnTheCard_countsTheLineExpense() {
        let app = launch()
        let planningTab = app.tabBars.buttons.element(boundBy: 2)
        XCTAssertTrue(planningTab.waitForExistence(timeout: 10))
        planningTab.tap()
        let fab = app.buttons["budgets_create_fab"]
        XCTAssertTrue(fab.waitForExistence(timeout: 5))
        fab.tap()

        let nameField = app.textFields["budget_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Tarjeta QA")
        let amountField = app.textFields["budget_amount_field"]
        amountField.tap()
        amountField.typeText("3000")

        let cardChip = app.buttons[card]
        XCTAssertTrue(app.scrollTo(cardChip), "El editor no ofrece la tarjeta.")
        XCTAssertFalse(app.buttons[line].exists, "El editor enseña la línea como otra cuenta.")
        cardChip.tap()

        app.buttons["toolbar_save_button"].tap()
        let keep = app.alerts.buttons.element(boundBy: 1)
        if keep.waitForExistence(timeout: 3) { keep.tap() }

        let row = app.buttons["budget_row_Tarjeta QA"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "El presupuesto no apareció en la lista.")
        let percent = row.label
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first { !$0.isEmpty }
            .flatMap(Int.init)
        XCTAssertNotNil(percent, "No se pudo leer el porcentaje de «\(row.label)».")
        XCTAssertGreaterThan(percent ?? 0, 41, "El presupuesto no cuenta el gasto de la línea: «\(row.label)».")
    }
}

private extension XCUIApplication {
    /// Baja por la pantalla hasta que `element` sea alcanzable dentro de la ventana; `false` si no aparece.
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        for _ in 0...maxSwipes {
            if element.exists, windows.firstMatch.frame.contains(element.frame) { return true }
            swipeUp()
        }
        return element.exists && windows.firstMatch.frame.contains(element.frame)
    }
}

private extension XCUIElement {
    /// Espera a que el elemento quede elegido (el rasgo `isSelected` llega una vuelta después del toque).
    func waitForSelected(timeout: TimeInterval = 3) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
