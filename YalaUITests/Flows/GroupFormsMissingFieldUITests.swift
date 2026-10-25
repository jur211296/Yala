//
//  GroupFormsMissingFieldUITests.swift
//  YalaUITests
//
//  Lote 12.3 (card rhgi): «Apuntar pago» y el «Guardar» del saldo inicial ya no se apagan sin decir por qué. Siguen
//  activos y, al tocarlos con algo pendiente, no guardan: marcan el campo y una línea dice qué falta (molde de L13-9,
//  `UXAudit22Lote13DecididoUITests.test_save_withNothingFilled_saysWhatIsMissing`).
//
//  Convenciones: scheme Yala Dev, sin sleeps, por identifier. Seed `grupos`: en «Viaje a Cusco» el usuario es dueño
//  («Añadir saldo inicial»); en «Viaje a Lima» le deben en una sola moneda («Saldar» es un botón, no un menú).
//

import XCTest

final class GroupFormsMissingFieldUITests: XCTestCase {

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

    /// «Viaje a Cusco» (dueño, deudas en soles y dólares) o «Viaje a Lima» (una sola moneda: su «Saldar» es un botón y no
    /// un menú por moneda).
    private func openBalances(_ app: XCUIApplication, group: String = "Viaje a Cusco") {
        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH %@", group)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No apareció la tarjeta de «\(group)».")
        card.tap()
        let tab = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "No apareció la pestaña de saldos.")
        tab.tap()
    }

    /// Baja hasta que el elemento existe y está en pantalla, o se rinde.
    @discardableResult
    private func scrollTo(_ app: XCUIApplication, _ target: XCUIElement, swipes: Int = 12) -> Bool {
        for _ in 0..<swipes {
            if target.exists, target.isHittable { return true }
            app.swipeUp()
        }
        return target.exists
    }

    // MARK: - Saldo inicial

    /// «Guardar» vacío no guarda: dice que falta quién debe y el formulario sigue abierto.
    func test_openingBalance_saveWithNothingChosen_saysWhoIsMissing() {
        let app = launch()
        openBalances(app)
        let add = app.descendants(matching: .any)["balances_opening_balance_add"]
        XCTAssertTrue(scrollTo(app, add), "Saldos no ofrece «Añadir saldo inicial».")
        add.tap()

        let save = app.buttons["opening_balance_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No abrió el formulario de saldo inicial.")
        XCTAssertTrue(save.isEnabled, "«Guardar» debía estar activo con el formulario vacío (card rhgi).")
        save.tap()

        let hint = app.descendants(matching: .any)["opening_balance_missing_hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 5), "Tocar «Guardar» vacío no dijo qué falta.")
        XCTAssertTrue(app.buttons["opening_balance_debtor"].exists, "«Guardar» vacío cerró el formulario.")
    }

    // MARK: - Apuntar pago

    /// Sin importe, «Apuntar pago» sigue activo; al tocarlo dice que falta el monto y no apunta nada. Al escribirlo, la
    /// línea se va.
    func test_settlement_withoutAmount_saysTheAmountIsMissing() {
        let app = launch()
        openBalances(app, group: "Viaje a Lima")
        let settle = app.descendants(matching: .any).matching(identifier: "group_debt_settle").firstMatch
        XCTAssertTrue(settle.waitForExistence(timeout: 10), "No hay «Saldar» en las deudas de Lima.")
        settle.tap()

        let amount = app.textFields["settlement_form_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "No abrió el formulario de pago.")
        // El importe va centrado: un toque en el medio deja el cursor entre cifras y el borrado no lo vacía. En el borde
        // derecho, el cursor queda al final.
        amount.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        let current = (amount.value as? String) ?? ""
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))

        let save = app.buttons["settlement_form_save"]
        XCTAssertTrue(scrollTo(app, save), "«Apuntar pago» no está a la vista.")
        XCTAssertTrue(save.isEnabled, "«Apuntar pago» debía estar activo sin importe (card rhgi).")
        save.tap()

        let hint = app.descendants(matching: .any)["settlement_form_missing_hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 5), "Tocar «Apuntar pago» sin importe no dijo qué falta.")
        XCTAssertTrue(amount.exists, "«Apuntar pago» sin importe cerró el formulario.")

        amount.tap()
        amount.typeText("10")
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: hint)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed,
                       "Con el importe escrito, la línea de lo que falta siguió ahí.")
    }
}
