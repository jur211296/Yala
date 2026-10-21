//
//  UXAudit22Lote13DecididoUITests.swift
//  YalaUITests
//
//  Lote decidido 2.2 · 11 (cards L13-4…L13-15, decisiones de Jürgen del 18-oct). Lo que se ve y se recorre en el
//  simulador con el seed `grupos`; el enlace con un movimiento (L13-15), el resumen (L13-6) y el desenlace de «Sí,
//  registrar» (L13-7) se prueban en `YalaTests` contra el bridge real.
//
//  Convenciones: scheme Yala Dev, sin sleeps, por identifier (los títulos con nombre se buscan por el nombre del gasto,
//  que es dato del seed y no texto de la app).
//

import XCTest

final class UXAudit22Lote13DecididoUITests: XCTestCase {

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

    /// Baja hasta que el elemento existe y está en pantalla, o se rinde (molde de `UXAudit22Lote11DecididasUITests`).
    @discardableResult
    private func scrollTo(_ app: XCUIApplication, _ target: XCUIElement, swipes: Int = 12) -> Bool {
        for _ in 0..<swipes {
            if target.exists, target.isHittable { return true }
            app.swipeUp()
        }
        return target.exists
    }

    /// «Viaje a Cusco»: el seed `grupos` lo crea con el usuario como dueño.
    private func openCusco(_ app: XCUIApplication) {
        let cusco = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH 'Viaje a Cusco'")).firstMatch
        XCTAssertTrue(cusco.waitForExistence(timeout: 15), "No apareció la tarjeta de «Viaje a Cusco».")
        cusco.tap()
    }

    // MARK: - L13-4

    /// El diálogo de borrar nombra el gasto («¿Eliminar «Mercado»?»): antes decía solo «Eliminar».
    func test_deleteExpense_dialogNamesTheExpense() {
        let app = launch()
        openCusco(app)

        let row = app.buttons["group_expense_row_Mercado"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No apareció «Mercado».")
        row.tap()
        let edit = app.buttons["group_expense_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "No montó el detalle del gasto.")
        edit.tap()
        let delete = app.buttons["group_expense_delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "No apareció la papelera del formulario.")
        delete.tap()

        let confirm = app.sheets.buttons["group_expense_delete_confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No salió el diálogo de borrar.")
        let named = app.sheets.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Mercado'")).firstMatch
        XCTAssertTrue(named.exists, "El diálogo de borrar no nombra el gasto (L13-4).")
    }

    // MARK: - L13-9

    /// «Guardar» con el formulario vacío no guarda: marca lo que falta y lo dice; al escribir la descripción, la línea
    /// pasa a lo siguiente (el importe).
    func test_save_withNothingFilled_saysWhatIsMissing() {
        let app = launch()
        openCusco(app)

        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció «Nuevo gasto».")
        fab.tap()
        let save = app.buttons["group_expense_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "No montó el formulario de gasto.")
        XCTAssertTrue(save.isEnabled, "«Guardar» debía estar activo con el formulario vacío (L13-9).")

        save.tap()
        let missing = app.descendants(matching: .any)["group_expense_missing_hint"]
        XCTAssertTrue(missing.waitForExistence(timeout: 5), "Tocar «Guardar» vacío no dijo qué falta.")
        let firstMessage = missing.label
        XCTAssertTrue(app.textFields["group_expense_amount"].exists, "«Guardar» vacío cerró el formulario.")

        let description = app.textFields["group_expense_description"]
        description.tap()
        description.typeText("Cena")
        let moved = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", firstMessage), object: missing)
        XCTAssertEqual(XCTWaiter().wait(for: [moved], timeout: 5), .completed,
                       "Con la descripción escrita, la línea siguió diciendo lo mismo.")
    }

    // MARK: - L13-10

    /// Quien creó el grupo tiene «Añadir saldo inicial» también en Saldos, y el formulario explica qué es.
    func test_balances_offerOpeningBalance_andTheFormExplainsIt() {
        let app = launch()
        openCusco(app)
        let tab = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "No apareció la pestaña de saldos.")
        tab.tap()

        let add = app.descendants(matching: .any)["balances_opening_balance_add"]
        XCTAssertTrue(scrollTo(app, add), "Saldos no ofrece «Añadir saldo inicial» al dueño (L13-10).")
        add.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["opening_balance_help"].waitForExistence(timeout: 5),
            "El formulario de saldo inicial no explica qué es (L13-10)."
        )
        XCTAssertTrue(app.buttons["opening_balance_debtor"].exists, "No abrió el formulario de saldo inicial.")
    }

    // MARK: - L13-7

    /// Con el puente apagado, «Sí, registrar» abre AHÍ MISMO la hoja que pide la cuenta (antes dejaba un borrador en la
    /// Bandeja sin decirlo). Cerrarla sin elegir deja el borrador en la Bandeja y la pantalla de éxito lo dice.
    func test_optIn_yesRegister_asksTheAccountRightThere() {
        let app = launch()

        // Puente apagado (Ajustes de Grupos). Con la fila de un `Toggle`, se toca su interruptor (regla de `swiftui-ds.md`).
        let settings = app.buttons["groups_global_settings_button"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "No apareció «Ajustes de Grupos».")
        settings.tap()
        let bridge = app.switches["groups_bridge_toggle"]
        XCTAssertTrue(bridge.waitForExistence(timeout: 5), "No apareció el interruptor de reflejar en tus cuentas.")
        bridge.switches.firstMatch.tap()
        let off = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0'"), object: bridge)
        XCTAssertEqual(XCTWaiter().wait(for: [off], timeout: 5), .completed, "No se apagó «reflejar en tus cuentas».")
        let close = app.buttons["xmark"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), "No apareció la X de Ajustes de Grupos.")
        close.tap()

        openCusco(app)
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció «Nuevo gasto».")
        fab.tap()
        let description = app.textFields["group_expense_description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), "No montó el formulario.")
        description.tap()
        description.typeText("Cena")
        let amount = app.textFields["group_expense_amount"]
        amount.tap()
        amount.typeText("90")
        app.buttons["group_expense_save"].tap()

        // Pagaste tú con el puente apagado: la pregunta.
        let yes = app.alerts.buttons["Sí, registrar"].firstMatch
        XCTAssertTrue(yes.waitForExistence(timeout: 8), "No salió «¿Registrar también en tu Yala personal?».")
        capture(app, "despues-L13-7-pregunta")
        yes.tap()

        let banner = app.descendants(matching: .any)["group_draft_banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 8), "«Sí, registrar» no pidió la cuenta ahí mismo (L13-7).")
        capture(app, "despues-L13-7-12-pide-cuenta")

        // Cerrar sin elegir: el borrador se queda en la Bandeja y la pantalla de éxito lo dice.
        app.buttons["xmark"].firstMatch.tap()
        XCTAssertTrue(
            app.buttons["group_expense_success_accept"].waitForExistence(timeout: 8),
            "Tras cerrar la hoja de la cuenta no llegó la pantalla de éxito."
        )
        capture(app, "despues-L13-7-exito-bandeja")
    }

    // MARK: - L13-12

    /// El borrador de un pago de grupo ya no dice «Sin descripción»: confirmas que Ana te pagó y la Bandeja lo nombra
    /// «Pago de Ana · Viaje a Cusco».
    func test_paymentDraft_isNamedInTheInbox() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", pendingSettlement: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openCusco(app)
        let tab = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "No apareció la pestaña de saldos.")
        tab.tap()
        let yes = app.buttons["group_pending_confirm_yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 10), "No apareció el pago de Ana por confirmar.")
        yes.tap()
        XCTAssertTrue(yes.waitForNonExistence(timeout: 8), "Confirmar no retiró la tarjeta.")

        // Relanzar SIN sembrar (los datos ya están en disco) y abrir la Bandeja desde el Panel.
        app.terminate()
        app.launchForUITest(reset: false, pro: true, seed: nil)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente tras relanzar.")
        let inbox = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja.")
        inbox.tap()

        let named = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Ana' AND label CONTAINS 'Viaje a Cusco'"))
            .firstMatch
        XCTAssertTrue(named.waitForExistence(timeout: 8), "El borrador del pago no lleva nombre en la Bandeja (L13-12).")
        capture(app, "despues-L13-12-bandeja-pago")
        named.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["group_draft_banner"].waitForExistence(timeout: 8),
            "No abrió la hoja del pago."
        )
        capture(app, "despues-L13-12-hoja-pago")
    }

    /// Captura para el informe de la sesión, solo si la corrida la pide (`TEST_RUNNER_YALA_CAPTURE_DIR`).
    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            print("UXAudit22Lote13DecididoUITests: captura no guardada: \(error)")
        }
    }

    // MARK: - L13-11

    /// Tras convertir un borrador, «Ver» del aviso cierra la Bandeja y abre el grupo al que fue.
    func test_convertDraft_viewOpensTheGroup() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos-invitado")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let inbox = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja.")
        inbox.tap()
        let row = app.buttons["inbox_draft_row_Almuerzo equipo"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció el borrador a convertir.")
        row.tap()
        let convert = app.buttons["inbox_convert_to_shared_button"]
        XCTAssertTrue(convert.waitForExistence(timeout: 5), "No apareció «Convertir a gasto compartido».")
        convert.tap()
        let save = app.buttons["group_expense_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 15), "No montó el formulario de grupo.")
        save.tap()

        let view = app.buttons["inbox_moved_to_group_view"]
        XCTAssertTrue(view.waitForExistence(timeout: 8), "No salió el aviso «Movido a…» con «Ver» (L13-11).")
        capture(app, "despues-L13-11-aviso")
        view.tap()

        XCTAssertTrue(
            app.buttons["group_detail_tab_records"].waitForExistence(timeout: 10),
            "«Ver» no abrió el grupo."
        )
    }
}
