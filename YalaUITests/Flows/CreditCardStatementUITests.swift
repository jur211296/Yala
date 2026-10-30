//
//  CreditCardStatementUITests.swift
//  YalaUITests
//
//  Tarjeta de crédito con día de corte (card nmtk). Seed `tarjeta-corte`: «Visa QA» (PEN) con su línea en dólares, corte
//  hace ~10 días, S/ 1,240 y $ 80 facturados antes del corte y S/ 386.50 gastados después; aviso 3 días antes.
//  - Formulario (D1-A): día de corte y día de pago a la vista, y el aviso en su sección con «Cuándo».
//  - Ficha (D2-A): «Estado de cuenta» bajo el saldo, con lo facturado (las dos divisas) y lo por facturar.
//  - Flujo de caja (D4-A): la fila del pago, que no suma.
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los nombres sembrados).
//

import XCTest

final class CreditCardStatementUITests: XCTestCase {

    private let card = "Visa QA"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "tarjeta-corte")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "La app no llegó al Panel.")
        return app
    }

    private func scrollUntilVisible(_ app: XCUIApplication, _ element: XCUIElement, swipes: Int = 8) {
        var count = 0
        while count < swipes && !(element.exists && app.windows.firstMatch.frame.contains(element.frame)) {
            app.swipeUp(velocity: .slow)
            count += 1
        }
    }

    /// El formulario enseña el día de corte y el de pago sin depender del aviso, y el aviso con «Cuándo».
    func test_form_showsStatementAndPaymentDays_andTheReminderLead() {
        let app = launch()
        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let row = app.buttons["accounts_row_\(card)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No sale la tarjeta en Ajustes › Cuentas.")
        row.tap()

        let statement = app.buttons["account_cc_statement_day"]
        XCTAssertTrue(statement.waitForExistence(timeout: 8), "No hay selector de día de corte.")
        scrollUntilVisible(app, app.descendants(matching: .any)["account_cc_reminder_footer"])
        XCTAssertTrue(app.buttons["account_cc_payment_day"].exists, "No hay selector de día de pago.")
        XCTAssertTrue(app.buttons["account_cc_reminder_when"].exists, "Con día de corte falta «Cuándo».")
        XCTAssertTrue(app.staticTexts["account_cc_cycle_footer"].exists, "Falta el pie que explica el ciclo.")
        XCTAssertTrue(app.staticTexts["account_cc_reminder_footer"].exists, "Falta el pie con la fecha del aviso.")

        // Sin el aviso, el día de corte y el de pago siguen a la vista (antes el de pago se escondía).
        let toggle = app.switches["account_cc_reminder_toggle"]
        XCTAssertTrue(toggle.exists)
        toggle.switches.firstMatch.tap()
        XCTAssertFalse(app.buttons["account_cc_reminder_when"].waitForExistence(timeout: 2),
                       "Con el aviso apagado sigue «Cuándo».")
        XCTAssertTrue(app.buttons["account_cc_payment_day"].exists, "Apagar el aviso esconde el día de pago.")
        XCTAssertTrue(statement.exists, "Apagar el aviso esconde el día de corte.")
    }

    /// La ficha trae el estado de cuenta: lo facturado en soles y en dólares, y lo por facturar.
    func test_detail_showsBilledAndUnbilled() {
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
        visa.tap()

        let billed = app.descendants(matching: .any)["cc_statement_billed"]
        XCTAssertTrue(billed.waitForExistence(timeout: 8), "La ficha no trae «Facturado».")
        let billedLabel = billed.label
        XCTAssertTrue(billedLabel.contains("1,240") || billedLabel.contains("1.240"),
                      "Lo facturado en soles no es S/ 1,240: «\(billedLabel)».")
        XCTAssertTrue(billedLabel.contains("80"), "Falta lo facturado en dólares: «\(billedLabel)».")
        let unbilled = app.descendants(matching: .any)["cc_statement_unbilled"]
        XCTAssertTrue(unbilled.exists, "La ficha no trae «Por facturar».")
        XCTAssertTrue(unbilled.label.contains("386"), "Lo por facturar no es S/ 386.50: «\(unbilled.label)».")
    }

    /// En el mes del pago, el flujo de caja enseña la fila del pago de la tarjeta con lo facturado y la nota de que no
    /// se resta otra vez (D4-A).
    func test_cashFlow_showsTheCardPaymentInItsMonth() {
        let app = launch()
        Self.openCashFlowPlan(app)
        let row = Self.findCardPaymentRow(app)
        XCTAssertTrue(row.exists, "Ni este mes ni el siguiente traen el pago de la tarjeta.")
        XCTAssertTrue(row.label.contains(card), "La fila no nombra la tarjeta: «\(row.label)».")
        XCTAssertTrue(row.label.contains("1,240") || row.label.contains("1.240"), "Falta lo facturado: «\(row.label)».")
    }

    /// Abre Flujo de caja (por la tarjeta de Más), salta la guía y crea el plan si hace falta.
    static func openCashFlowPlan(_ app: XCUIApplication) {
        let moreTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "No apareció el tab Más.")
        moreTab.tap()
        let card = app.buttons["more_card_flujoDeCaja"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "No apareció la card Flujo de Caja en Más.")
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_setup_view"].firstMatch.waitForExistence(timeout: 15))
        if app.buttons["coach_mark_skip"].waitForExistence(timeout: 4) { app.buttons["coach_mark_skip"].tap() }
        let create = app.buttons["primary_button"]
        if create.waitForExistence(timeout: 10) { create.tap() }
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15), "El plan no se creó.")
        if app.buttons["coach_mark_skip"].waitForExistence(timeout: 4) { app.buttons["coach_mark_skip"].tap() }
    }

    /// El pago cae este mes o el siguiente (el seed pone el corte hace ~10 días y el pago ~21 días después): busca la fila
    /// en los dos, bajando hasta ella.
    static func findCardPaymentRow(_ app: XCUIApplication) -> XCUIElement {
        let row = app.descendants(matching: .any)["cashflow_card_payment_row"]
        let calendar = Calendar.current
        for offset in 0...1 {
            if offset > 0, let month = calendar.date(byAdding: .month, value: offset, to: .now) {
                let parts = calendar.dateComponents([.year, .month], from: month)
                let key = String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
                let capsule = app.buttons["cashflow_month_capsule_\(key)"]
                if capsule.waitForExistence(timeout: 3) { capsule.tap() }
            }
            var swipes = 0
            while swipes < 6 && !(row.exists && app.windows.firstMatch.frame.contains(row.frame)) {
                app.swipeUp(velocity: .slow)
                swipes += 1
            }
            if row.exists { return row }
            var back = 0
            let title = app.staticTexts["cashflow_month_title"]
            while back < 6 && !(title.exists && app.windows.firstMatch.frame.contains(title.frame)) {
                app.swipeDown(velocity: .slow)
                back += 1
            }
        }
        return row
    }
}
