//
//  GroupsNoTirarLoEscritoUITests.swift
//  YalaUITests
//
//  Decisión 39 de la revisión 2.3 (F1 + F3, 2026-11-09). (1) La X y deslizar la hoja preguntan antes de tirar lo
//  escrito en «Nuevo gasto», «Saldar» y «Saldo inicial»; sin nada escrito cierran como siempre. (2) Cambiar de grupo en
//  «Nuevo gasto» conserva lo escrito y lo dice. (3) «Nuevo gasto» abre en el último grupo donde se apuntó un gasto.
//
//  Seed `grupos`: «Viaje a Cusco» (primero de la lista, dueño, 3 personas) y «Viaje a Lima» (Tú y Caro, una moneda).
//  Convenciones: scheme Yala Dev, sin sleeps, por identifier.
//

import XCTest

final class GroupsNoTirarLoEscritoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    // MARK: - Ayudas

    private func openNewExpenseFromList(_ app: XCUIApplication) {
        let newExpense = app.buttons["groups_action_new_expense"]
        XCTAssertTrue(newExpense.waitForExistence(timeout: 15), "No apareció «Nuevo gasto» arriba en Grupos.")
        newExpense.tap()
        XCTAssertTrue(app.textFields["group_expense_description"].waitForExistence(timeout: 10),
                      "«Nuevo gasto» no abrió el formulario.")
    }

    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No apareció \(field.identifier).")
        field.tap()
        field.typeText(text)
    }

    /// El teclado se queda encima de lo de abajo (`testing.md`, barra con el teclado abierto): se baja antes de tocar,
    /// con un toque en un hueco que no es un control (los tres formularios llevan `dismissKeyboardOnTap`). Arrastrar la
    /// barra hacia abajo NO vale: es intentar cerrar la hoja, y con algo escrito sale justo la pregunta que se prueba.
    private func hideKeyboard(_ app: XCUIApplication, tapping point: XCUICoordinate? = nil) {
        guard app.keyboards.count > 0 else { return }
        (point ?? app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))).tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 0"), object: app.keyboards)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "No se pudo bajar el teclado.")
    }

    private var discardConfirm: (XCUIApplication) -> XCUIElement {
        { $0.buttons["group_form_discard_confirm"].firstMatch }
    }

    private var discardKeep: (XCUIApplication) -> XCUIElement {
        { $0.buttons["group_form_discard_keep"].firstMatch }
    }

    private func openBalances(_ app: XCUIApplication, group: String) {
        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH %@", group)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No apareció la tarjeta de «\(group)».")
        card.tap()
        let tab = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "No apareció la pestaña de saldos.")
        tab.tap()
    }

    @discardableResult
    private func scrollTo(_ app: XCUIApplication, _ target: XCUIElement, swipes: Int = 12) -> Bool {
        for _ in 0..<swipes {
            if target.exists, target.isHittable { return true }
            app.swipeUp()
        }
        return target.exists
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - (1) La X pregunta

    /// Con el gasto a medias, la X pregunta; «Seguir editando» lo conserva y «Descartar» cierra.
    func test_newExpense_closeWithSomethingWritten_asksFirst() {
        let app = launch()
        openNewExpenseFromList(app)
        type("Cena de despedida", into: app.textFields["group_expense_description"])

        // La X está en la barra, a la vista con el teclado puesto: no hace falta bajarlo.
        app.buttons["group_expense_close"].tap()
        XCTAssertTrue(discardKeep(app).waitForExistence(timeout: 5),
                      "La X cerró «Nuevo gasto» con la descripción escrita, sin preguntar.")
        attachScreenshot("nuevo-gasto-pregunta")
        discardKeep(app).tap()

        let description = app.textFields["group_expense_description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), "«Seguir editando» cerró el formulario.")
        XCTAssertEqual(description.value as? String, "Cena de despedida", "«Seguir editando» no conservó lo escrito.")

        app.buttons["group_expense_close"].tap()
        XCTAssertTrue(discardConfirm(app).waitForExistence(timeout: 5), "La segunda X no preguntó.")
        discardConfirm(app).tap()
        XCTAssertTrue(description.waitForNonExistence(timeout: 5), "«Descartar» no cerró el formulario.")
    }

    /// Sin nada escrito, la X cierra como siempre: no hay nada que perder.
    func test_newExpense_closeEmpty_closesWithoutAsking() {
        let app = launch()
        openNewExpenseFromList(app)
        app.buttons["group_expense_close"].tap()
        XCTAssertTrue(app.textFields["group_expense_description"].waitForNonExistence(timeout: 5),
                      "La X no cerró «Nuevo gasto» vacío.")
        XCTAssertFalse(discardKeep(app).exists, "«Nuevo gasto» vacío preguntó antes de cerrarse.")
    }

    /// Deslizar la hoja hacia abajo con algo escrito tampoco la tira: pregunta.
    func test_newExpense_swipeDownWithSomethingWritten_asksFirst() {
        let app = launch()
        openNewExpenseFromList(app)
        type("120", into: app.textFields["group_expense_amount"])

        let bar = app.navigationBars.firstMatch
        bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        XCTAssertTrue(discardKeep(app).waitForExistence(timeout: 5),
                      "Deslizar la hoja hacia abajo tiró el gasto a medias sin preguntar.")
        discardKeep(app).tap()
        XCTAssertTrue(app.textFields["group_expense_amount"].waitForExistence(timeout: 5),
                      "«Seguir editando» cerró el formulario.")
    }

    /// «Saldar»: cambiar el importe y tocar la X pregunta.
    func test_settle_closeAfterChangingTheAmount_asksFirst() {
        let app = launch()
        openBalances(app, group: "Viaje a Lima")
        let settle = app.descendants(matching: .any).matching(identifier: "group_debt_settle").firstMatch
        XCTAssertTrue(settle.waitForExistence(timeout: 10), "No hay «Saldar» en las deudas de Lima.")
        settle.tap()

        let amount = app.textFields["settlement_form_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "No abrió el formulario de pago.")
        // El importe va centrado: en el borde derecho el cursor queda al final. Se borran los decimales y se escribe otra
        // cifra, para que el importe cambie de verdad (añadir un tercer decimal no lo cambia).
        amount.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "5")

        app.buttons["settlement_form_close"].tap()
        XCTAssertTrue(discardKeep(app).waitForExistence(timeout: 5),
                      "La X de «Saldar» cerró con el importe cambiado, sin preguntar.")
        attachScreenshot("saldar-pregunta")
        discardConfirm(app).tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "«Descartar» no cerró «Saldar».")
    }

    /// «Saldar» sin tocar nada cierra como siempre: el importe precargado no cuenta como escrito.
    func test_settle_closeUntouched_closesWithoutAsking() {
        let app = launch()
        openBalances(app, group: "Viaje a Lima")
        let settle = app.descendants(matching: .any).matching(identifier: "group_debt_settle").firstMatch
        XCTAssertTrue(settle.waitForExistence(timeout: 10), "No hay «Saldar» en las deudas de Lima.")
        settle.tap()
        let amount = app.textFields["settlement_form_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "No abrió el formulario de pago.")
        app.buttons["settlement_form_close"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "La X no cerró «Saldar» sin cambios.")
        XCTAssertFalse(discardKeep(app).exists, "«Saldar» sin cambios preguntó antes de cerrarse.")
    }

    /// «Saldo inicial»: con el importe escrito, la X pregunta.
    func test_openingBalance_closeWithAnAmount_asksFirst() {
        let app = launch()
        openBalances(app, group: "Viaje a Cusco")
        let add = app.descendants(matching: .any)["balances_opening_balance_add"]
        XCTAssertTrue(scrollTo(app, add), "Saldos no ofrece «Añadir saldo inicial».")
        add.tap()

        type("50", into: app.textFields["opening_balance_amount"])
        hideKeyboard(app, tapping: app.descendants(matching: .any)["opening_balance_help"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        app.buttons["opening_balance_close"].tap()
        XCTAssertTrue(discardKeep(app).waitForExistence(timeout: 5),
                      "La X de «Saldo inicial» cerró con el importe escrito, sin preguntar.")
        attachScreenshot("saldo-inicial-pregunta")
        discardConfirm(app).tap()
        XCTAssertTrue(app.buttons["opening_balance_debtor"].waitForNonExistence(timeout: 5),
                      "«Descartar» no cerró «Saldo inicial».")
    }

    // MARK: - (2) Cambiar de grupo conserva lo escrito

    func test_changingGroup_keepsWhatYouWrote_andSaysSo() {
        let app = launch()
        openNewExpenseFromList(app)
        type("Cena de despedida", into: app.textFields["group_expense_description"])
        type("400", into: app.textFields["group_expense_amount"])

        // El chip baja el teclado él mismo al tocarlo; se espera a que deje de moverse (`testing.md`, tocar tras typeText).
        let chip = app.descendants(matching: .any).matching(identifier: "group_expense_group_chip").firstMatch
        XCTAssertTrue(chip.label.contains("Viaje a Cusco"), "El composer no abrió en Cusco. label=\(chip.label)")
        XCTAssertTrue(app.waitForSettledLayout(of: chip), "El chip de grupo no dejó de moverse.")
        chip.tap()
        let limaRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'group_picker_row_' AND label CONTAINS[c] 'Viaje a Lima'")
        ).firstMatch
        XCTAssertTrue(limaRow.waitForExistence(timeout: 5), "El selector de grupo no listó «Viaje a Lima».")
        limaRow.tap()

        let switched = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS[c] 'Viaje a Lima'"),
                                                 object: chip)
        XCTAssertEqual(XCTWaiter().wait(for: [switched], timeout: 8), .completed, "El chip no pasó a «Viaje a Lima».")
        XCTAssertEqual(app.textFields["group_expense_description"].value as? String, "Cena de despedida",
                       "Cambiar de grupo borró la descripción.")
        let amountValue = (app.textFields["group_expense_amount"].value as? String) ?? ""
        XCTAssertTrue(amountValue.contains("400"), "Cambiar de grupo borró el importe. value=\(amountValue)")
        XCTAssertTrue(app.descendants(matching: .any)["group_expense_group_changed_notice"].waitForExistence(timeout: 5),
                      "Cambiar de grupo no dijo que el reparto vuelve a empezar.")
        attachScreenshot("cambio-de-grupo-conserva")
    }

    // MARK: - (3) Abre en el último grupo usado

    func test_newExpense_opensInTheLastGroupWhereYouSavedOne() {
        let app = launch()
        openNewExpenseFromList(app)
        let chip = app.descendants(matching: .any).matching(identifier: "group_expense_group_chip").firstMatch
        chip.tap()
        let limaRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'group_picker_row_' AND label CONTAINS[c] 'Viaje a Lima'")
        ).firstMatch
        XCTAssertTrue(limaRow.waitForExistence(timeout: 5), "El selector de grupo no listó «Viaje a Lima».")
        limaRow.tap()
        let switched = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS[c] 'Viaje a Lima'"),
                                                 object: chip)
        XCTAssertEqual(XCTWaiter().wait(for: [switched], timeout: 8), .completed, "El chip no pasó a «Viaje a Lima».")

        // Pagas tú (lo de siempre): «Guardar» pide la cuenta. Se elige antes de abrir el teclado, que taparía su chip;
        // «Guardar» va en la barra de abajo, encima del teclado.
        app.chooseFirstSelectorRow(chip: "group_expense_account_row", rowPrefix: "account_selector_row_")
        type("Taxi al aeropuerto", into: app.textFields["group_expense_description"])
        type("30", into: app.textFields["group_expense_amount"])

        let save = app.buttons["group_expense_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No apareció «Guardar».")
        save.tap()
        let accept = app.buttons["group_expense_success_accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "El gasto no se guardó (sin pantalla de éxito).")
        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 10), "La pantalla de éxito no se cerró.")

        openNewExpenseFromList(app)
        let again = app.descendants(matching: .any).matching(identifier: "group_expense_group_chip").firstMatch
        XCTAssertTrue(again.waitForExistence(timeout: 5), "No apareció el chip de grupo.")
        XCTAssertTrue(again.label.contains("Viaje a Lima"),
                      "«Nuevo gasto» no abrió en el último grupo donde se apuntó un gasto. label=\(again.label)")
    }
}
