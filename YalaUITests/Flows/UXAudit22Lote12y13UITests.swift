//
//  UXAudit22Lote12y13UITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2, lotes 12 y 13 (Grupos), con la opción que eligió Jürgen el 15-oct:
//  - L12-10: tras crear un grupo, una hoja propone invitar («Más tarde» la cierra).
//  - L12-13: en Miembros, invitar es una tarjeta con su botón, arriba de la lista.
//  - L13-1: «Saldar» solo en las deudas tuyas.
//  - L13-2: un pago por confirmar sube arriba; «No me llegó» pregunta antes de quitarlo.
//  - L13-3: la pantalla de «¡Gasto agregado!» dice quién debe y qué se apuntó en tus finanzas.
//  Los estados vacíos (L12-2) los cubre `GroupsEmptyStateUITests`, que sigue sus identificadores.
//

import XCTest

final class UXAudit22Lote12y13UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(groupCreatedSheet: Bool = false, pendingSettlement: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "grupos", deeplink: "groups",
            groupCreatedSheet: groupCreatedSheet, pendingSettlement: pendingSettlement
        )
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func openFirstGroup(_ app: XCUIApplication) {
        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No apareció la tarjeta del grupo.")
        card.tap()
    }

    private func openBalances(_ app: XCUIApplication) {
        openFirstGroup(app)
        let tab = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "No apareció la pestaña de saldos del grupo.")
        tab.tap()
    }

    // MARK: - L12-10

    func test_createdGroupSheet_offersToInvite_andLaterClosesIt() {
        let app = launch(groupCreatedSheet: true)
        let invite = app.buttons["group_created_invite"]
        XCTAssertTrue(invite.waitForExistence(timeout: 15), "No salió la hoja «está listo» con el botón de invitar.")
        XCTAssertTrue(app.descendants(matching: .any)["group_created_title"].exists)
        let later = app.buttons["group_created_later"]
        XCTAssertTrue(later.exists, "La hoja no ofrece «Más tarde».")
        later.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: invite)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed, "«Más tarde» no cerró la hoja.")
    }

    // MARK: - L12-13

    func test_members_inviteIsACardWithItsButton() {
        let app = launch()
        openFirstGroup(app)
        let members = app.buttons["group_members_button"]
        XCTAssertTrue(members.waitForExistence(timeout: 10), "No apareció el botón de miembros.")
        members.tap()
        let share = app.buttons["group_members_invite_share"]
        XCTAssertTrue(share.waitForExistence(timeout: 10), "Miembros no ofrece «Compartir enlace» al dueño.")
        XCTAssertTrue(share.isHittable, "El botón de invitar no está a la vista al abrir Miembros.")
    }

    // MARK: - L13-1

    /// En el grupo sembrado Beto y Ana te deben, y Beto le debe a Ana: dos «Saldar», no tres.
    func test_balances_settleOnlyOnYourDebts() {
        let app = launch()
        openBalances(app)
        XCTAssertTrue(app.descendants(matching: .any)["group_balance_summary"].waitForExistence(timeout: 10),
                      "Falta el cuadro de lo tuyo arriba de los saldos.")
        let settle = app.descendants(matching: .any).matching(identifier: "group_debt_settle")
        XCTAssertTrue(settle.firstMatch.waitForExistence(timeout: 5), "No hay «Saldar» en tus deudas.")
        XCTAssertEqual(settle.count, 2, "«Saldar» tiene que salir solo en las dos deudas tuyas.")
    }

    // MARK: - L13-2

    func test_pendingPayment_noAsksBeforeRemoving_andYesConfirms() {
        let app = launch(pendingSettlement: true)
        openBalances(app)
        let yes = app.buttons["group_pending_confirm_yes"]
        let no = app.buttons["group_pending_confirm_no"]
        XCTAssertTrue(yes.waitForExistence(timeout: 10), "El pago de Ana por confirmar no subió arriba.")
        XCTAssertTrue(no.exists)

        no.tap()
        let cancel = app.buttons["group_pending_reject_cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "«No me llegó» no preguntó antes de quitar el pago.")
        cancel.tap()
        XCTAssertTrue(yes.waitForExistence(timeout: 5), "Cancelar quitó el pago igual.")

        yes.tap()
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: yes)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 8), .completed,
                       "Confirmar no retiró la tarjeta de «¿Lo recibiste?».")
    }

    // MARK: - L13-3

    /// Paga Ana (Caso B): te toca tu parte, la debes a Ana, y se apunta como gasto de grupo.
    func test_expenseSuccess_saysWhoOwesAndWhatWasNoted() {
        let app = launch()
        openFirstGroup(app)
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de nuevo gasto.")
        fab.tap()

        let description = app.textFields["group_expense_description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5))
        description.tap()
        description.typeText("Cena de prueba")
        let amount = app.textFields["group_expense_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("120")

        let payerRow = app.buttons["group_expense_paidby_row"]
        XCTAssertTrue(payerRow.waitForExistence(timeout: 5))
        payerRow.tap()
        let ana = app.buttons["group_expense_payer_Ana"]
        XCTAssertTrue(ana.waitForExistence(timeout: 5))
        ana.tap()

        let save = app.buttons["group_expense_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 8), .completed)
        save.tap()

        XCTAssertTrue(app.descendants(matching: .any)["group_expense_success_debt_line"].waitForExistence(timeout: 10),
                      "La pantalla de éxito no dice a quién debes.")
        XCTAssertTrue(app.descendants(matching: .any)["group_expense_success_money_line"].exists,
                      "La pantalla de éxito no dice qué se apuntó en tus finanzas.")
    }
}
