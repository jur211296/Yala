//
//  GruposSaldar23UITests.swift
//  YalaUITests
//
//  Mejoras 2.3 · Grupos: saldar como en Splitwise (decisión 37, C1 + C2 + C3) y la moneda del grupo que no cambia sola
//  (decisión 3, opción A).
//
//  Semilla `grupos`: «Viaje a Cusco» (tú lo creaste, en S/), Beto y Ana te deben, y Beto le debe a Ana; todas las deudas
//  en soles y dólares, así que «Saldar» abre un menú por moneda.
//
//  Discriminante, punto por punto, con el código de antes:
//  C1 · la deuda de Beto con Ana no tenía «Saldar» (`group_debt_settle_others` no existía);
//  C2 · «Saldar» no tenía «Todo / Una parte» ni avisaba de pagar de más;
//  C3 · al guardar no salía ningún aviso, y no había «Deshacer»;
//  A  · apagar «Ver las deudas en una sola moneda» devolvía el grupo a S/ (el pie del presupuesto decía «en S/»).
//
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo lo sembrado y la moneda que el punto pide decir).
//

import XCTest

final class GruposSaldar23UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - C1 · Cualquiera apunta, quien recibe confirma

    func test_debtBetweenOthers_canBeSettled_andWaitsForTheReceiver() {
        let app = openBalances()
        let settleOthers = app.descendants(matching: .any)["group_debt_settle_others"]
        XCTAssertTrue(settleOthers.waitForExistence(timeout: 10), "La deuda entre Beto y Ana no tiene «Saldar».")
        openForm(app, from: settleOthers)

        XCTAssertTrue(app.staticTexts["settlement_form_third_party_hint"].exists,
                      "El formulario no dice que lo confirmará quien recibe.")
        app.buttons["settlement_form_save"].tap()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'group_settlement_pending_menu_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "El pago entre otros no quedó pendiente.")
        XCTAssertTrue(row.label.contains("Falta que Ana lo confirme"), "El pago se lee «\(row.label)».")
        XCTAssertTrue(row.label.contains("Lo apuntaste tú"), "El pago no dice quién lo apuntó: «\(row.label)».")
    }

    // MARK: - C2 · Todo o una parte, y pagar de más

    func test_partPayment_saysWhatIsLeft_andOverpayingWarnsBeforeSaving() {
        let app = openBalances()
        let settle = app.descendants(matching: .any).matching(identifier: "group_debt_settle").firstMatch
        XCTAssertTrue(settle.waitForExistence(timeout: 10), "No apareció «Saldar».")
        openForm(app, from: settle)

        let outcome = app.staticTexts["settlement_form_outcome"]
        XCTAssertTrue(outcome.waitForExistence(timeout: 5), "Con «Todo» no dice que quedan a mano.")
        let scope = app.segmentedControls["settlement_form_scope"]
        XCTAssertTrue(scope.exists, "No está «Todo / Una parte».")
        scope.buttons.element(boundBy: 1).tap()

        let amount = app.textFields["settlement_form_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("5")
        // «Una parte» vació el campo: con «5» queda deuda (sin vaciar, «110.005» o similar no lo diría).
        let leaves = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "quedará debiendo"), object: outcome)
        XCTAssertEqual(XCTWaiter().wait(for: [leaves], timeout: 5), .completed,
                       "Con una parte no dice lo que queda: «\(outcome.label)».")
        XCTAssertEqual(app.buttons["settlement_form_save"].label, "Saldar")

        amount.typeText("000")
        let anyway = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Saldar igual"), object: app.buttons["settlement_form_save"])
        XCTAssertEqual(XCTWaiter().wait(for: [anyway], timeout: 5), .completed,
                       "Pagar de más no cambia el botón a «Saldar igual».")
        XCTAssertTrue(outcome.label.hasPrefix("Es más de lo que"),
                      "No avisa de que se paga de más: «\(outcome.label)».")
    }

    // MARK: - C3 · El aviso con «Deshacer»

    func test_saving_showsANotice_andUndoRemovesThePayment() {
        let app = openBalances()
        let settle = app.descendants(matching: .any).matching(identifier: "group_debt_settle").firstMatch
        XCTAssertTrue(settle.waitForExistence(timeout: 10), "No apareció «Saldar».")
        openForm(app, from: settle)
        app.buttons["settlement_form_save"].tap()

        let undo = app.buttons["settlement_saved_undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10), "Al saldar no salió el aviso con «Deshacer».")
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'group_settlement_menu_'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "El pago no aparece en la lista.")
        let before = rows.count
        undo.tap()

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", before - 1), object: rows)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed, "«Deshacer» no quitó el pago.")
    }

    // MARK: - A · La moneda del grupo no cambia sola

    func test_turningOffSingleCurrency_keepsTheGroupCurrency() {
        let app = launch()
        openFirstGroup(app)
        app.buttons["group_settings_button"].tap()

        let toggle = app.switches["group_settings_single_currency_toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "No apareció «Ver las deudas en una sola moneda».")
        toggle.switches.firstMatch.tap()

        let currencyRow = app.buttons["group_settings_currency_row"]
        XCTAssertTrue(currencyRow.waitForExistence(timeout: 5), "Al encender no salió la moneda.")
        currencyRow.tap()
        let usd = app.buttons["currency_selector_row_USD"]
        XCTAssertTrue(usd.waitForExistence(timeout: 5), "No abrió el selector de moneda.")
        usd.tap()

        let footer = app.staticTexts["group_settings_budget_footer"]
        let inDollars = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label ENDSWITH %@", "en $."), object: footer)
        XCTAssertEqual(XCTWaiter().wait(for: [inDollars], timeout: 8), .completed,
                       "El grupo no pasó a dólares: «\(footer.label)».")

        toggle.switches.firstMatch.tap()
        XCTAssertTrue(currencyRow.waitForNonExistence(timeout: 5), "El interruptor no se apagó.")
        XCTAssertTrue(footer.label.hasSuffix("en $."),
                      "Apagar la vista en una moneda cambió la moneda del grupo: «\(footer.label)».")
    }

    // MARK: - Helpers

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups",
                            extraArguments: ["-uitest-undo-notice-seconds", "30"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func openFirstGroup(_ app: XCUIApplication) {
        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la tarjeta del grupo.")
        card.tap()
        XCTAssertTrue(app.buttons["group_settings_button"].waitForExistence(timeout: 15), "El detalle no montó.")
    }

    private func openBalances() -> XCUIApplication {
        let app = launch()
        openFirstGroup(app)
        let tab = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "No apareció la pestaña de saldos del grupo.")
        tab.tap()
        return app
    }

    /// Con dos monedas «Saldar» es un menú: se elige el pago en soles.
    private func openForm(_ app: XCUIApplication, from settle: XCUIElement) {
        settle.tap()
        let soles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "S/")).firstMatch
        if soles.waitForExistence(timeout: 3) { soles.tap() }
        XCTAssertTrue(app.textFields["settlement_form_amount"].waitForExistence(timeout: 10),
                      "No abrió el formulario de pago.")
    }
}
