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

    /// En una transferencia (el selector sin moneda), la tarjeta sale una vez, con su divisa en el nombre, y la línea justo
    /// debajo. Desde el 23-nov-2026 el selector de un gasto enseña solo las cuentas de la moneda del monto, así que el
    /// anidado se mira en el origen de una transferencia.
    func test_selector_nestsTheLineUnderItsCard_inATransfer() {
        let app = launch()
        app.buttons["panel_action_new"].tap()
        app.chooseNewTransactionType("transfer")

        // La primera fila sigue siendo una cabeza: los UITests que eligen la primera fila no cambian de cuenta.
        let first = app.openSelectorFirstRow(chip: "new_transaction_source_chip", rowPrefix: "account_selector_row_")
        XCTAssertFalse(first.identifier.hasSuffix("· USD"), "La primera fila es una línea: «\(first.identifier)».")

        let cardRow = app.buttons["account_selector_row_\(card)"]
        let lineRow = app.buttons["account_selector_row_\(line)"]
        XCTAssertTrue(cardRow.waitForExistence(timeout: 5), "No está la fila de la tarjeta.")
        XCTAssertTrue(lineRow.exists, "No está la fila de la línea.")
        // Cada fila, una sola divisa; la tarjeta la lleva también en el nombre («Visa QA · PEN»), como la línea de debajo
        // (Jürgen, 6-nov: antes la tarjeta decía «PEN · USD», como si fuera de las dos a la vez).
        XCTAssertTrue(cardRow.label.contains("\(card) · PEN"), "La tarjeta no lleva su divisa en el nombre: «\(cardRow.label)».")
        XCTAssertFalse(cardRow.label.contains("USD"), "La fila de la tarjeta mezcla divisas: «\(cardRow.label)».")
        XCTAssertFalse(lineRow.label.contains("PEN"), "La fila de la línea mezcla divisas: «\(lineRow.label)».")
        XCTAssertGreaterThan(lineRow.frame.minY, cardRow.frame.minY, "La línea no va debajo de su tarjeta.")
        let dollars = app.buttons["account_selector_row_Dólares QA"]
        XCTAssertFalse(dollars.label.contains("Dólares QA · "), "Una cuenta sin líneas no lleva la divisa en el nombre.")
        XCTAssertTrue(dollars.frame.maxY <= cardRow.frame.minY || dollars.frame.minY >= lineRow.frame.maxY,
                      "Otra cuenta se mete entre la tarjeta y su línea.")
    }

    /// Un gasto en soles: el selector enseña solo las cuentas en soles (la tarjeta, con su nombre «Visa QA · PEN», y no su
    /// línea ni «Dólares QA»). Tocar la tarjeta y pasar a dólares deja el registro en la línea, con el nombre de la tarjeta.
    func test_selector_inSoles_showsOnlyTheSolesAccounts_andTheCapsulePicksTheLine() {
        let app = launch()
        app.buttons["panel_action_new"].tap()
        _ = app.openSelectorFirstRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")

        let cardRow = app.buttons["account_selector_row_\(card)"]
        XCTAssertTrue(cardRow.waitForExistence(timeout: 5), "No está la fila de la tarjeta.")
        XCTAssertTrue(cardRow.label.contains("\(card) · PEN"), "La tarjeta no lleva su divisa en el nombre: «\(cardRow.label)».")
        XCTAssertTrue(app.buttons["account_selector_row_Ahorros QA"].exists, "Falta la otra cuenta en soles.")
        XCTAssertFalse(app.buttons["account_selector_row_\(line)"].exists, "Un gasto en soles enseña la línea en dólares.")
        XCTAssertFalse(app.buttons["account_selector_row_Dólares QA"].exists, "Un gasto en soles enseña una cuenta en dólares.")

        cardRow.tap()
        let accountChip = app.buttons["new_transaction_account_chip"]
        XCTAssertTrue(accountChip.waitForExistence(timeout: 5))
        XCTAssertEqual(accountChip.label, card, "La pastilla de cuenta no dice la tarjeta.")
        // Hoja B1: la cápsula de moneda del monto sustituye a las pastillas PEN · USD de la tarjeta.
        XCTAssertTrue(app.buttons["new_transaction_currency_capsule"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.newTransactionCurrency, "PEN",
                       "Con el importe en soles, elegir la tarjeta tiene que dejar la principal.")

        app.chooseNewTransactionCurrency("USD")
        XCTAssertEqual(accountChip.label, card, "Elegir la divisa no puede cambiar el nombre de la tarjeta.")
    }

    /// En dólares, el selector enseña solo las cuentas en dólares (la línea de la tarjeta y «Dólares QA»), y la cápsula
    /// vuelve a soles con la principal de la tarjeta. Sustituye al caso de la card y1z6 (tocar la tarjeta desde su línea),
    /// que ya no cabe: con el monto en dólares la tarjeta en soles no sale en el selector.
    func test_selector_inDollars_showsOnlyTheDollarAccounts_andTheCapsuleGoesBackToThePrincipal() {
        let app = launch()
        app.buttons["panel_action_new"].tap()
        _ = app.openSelectorFirstRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
        let cardRow = app.buttons["account_selector_row_\(card)"]
        XCTAssertTrue(cardRow.waitForExistence(timeout: 5), "No está la fila de la tarjeta.")
        cardRow.tap()

        app.chooseNewTransactionCurrency("USD")

        // En dólares sale la fila del tipo de cambio, que baja la pastilla de cuenta hasta debajo de la barra de «Guardar»:
        // un toque directo cae en la barra. El ayudante la desplaza a la vista antes de tocarla.
        _ = app.openSelectorFirstRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
        let lineRow = app.buttons["account_selector_row_\(line)"]
        XCTAssertTrue(lineRow.waitForExistence(timeout: 5), "En dólares falta la línea de la tarjeta.")
        XCTAssertTrue(app.buttons["account_selector_row_Dólares QA"].exists, "En dólares falta «Dólares QA».")
        XCTAssertFalse(cardRow.exists, "Un gasto en dólares enseña la tarjeta en soles.")
        XCTAssertFalse(app.buttons["account_selector_row_Ahorros QA"].exists, "Un gasto en dólares enseña una cuenta en soles.")
        lineRow.tap()
        XCTAssertTrue(lineRow.waitForNonExistence(timeout: 5), "El selector no se cerró al tocar la línea.")

        app.chooseNewTransactionCurrency("PEN")
        XCTAssertEqual(app.buttons["new_transaction_account_chip"].label, card,
                       "Volver a soles desde la línea tiene que dejar la tarjeta.")
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
        let planningTab = app.tabEntry(.planning)
        XCTAssertTrue(planningTab.waitForExistence(timeout: 10))
        planningTab.tap()
        // «Nuevo presupuesto» abre el asistente por pasos (encargo del 17-nov): este caso prueba el formulario.
        app.abrirFormularioDeNuevoPresupuesto(desde: app.buttons["budgets_create_button"])

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
