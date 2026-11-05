//
//  ScheduledPaymentsLoteP1UITests.swift
//  YalaUITests
//
//  Lote P1 de la 2.3 (pagos planificados):
//  - «Pagar ahora» (antes «Adelantar gasto») guarda y vuelve al detalle del pago, sin la pantalla de éxito de la Bandeja
//    ni «Guardar el siguiente», que llevaba a otros borradores (ticket `inbox-success-says-transaction-created`; el
//    arreglo es del lote 10 y no tenía test).
//  - El borrador de un pago que vence se alcanza y se aprueba desde la Bandeja (ticket
//    `scheduled-due-draft-cannot-be-reached-in-uitest`), con el seam `-uitest-process-due-scheduled`.
//
//  Convenciones: CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class ScheduledPaymentsLoteP1UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    // MARK: - «Pagar ahora» vuelve al pago

    func test_payNow_savesAndReturnsToThePayment_withoutTheInboxSuccessScreen() {
        let app = XCUIApplication()
        // Sembrado como si hoy fuera el día 1: el primer pago de la lista tiene su próxima fecha aún por llegar.
        app.launchForUITest(pro: true, scheduledSeedDay: 1)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openScheduledPaymentsList()
        let row = app.buttons["scheduled_payment_row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No se montó ninguna fila.")
        row.tap()
        let status = element(app, "scheduled_detail_status")
        XCTAssertTrue(status.waitForExistence(timeout: 5), "No se abrió el detalle.")

        // La primera fecha es la próxima por llegar («Próximos» va antes del historial): ahí se ofrece «Pagar ahora».
        let occurrence = app.buttons["scheduled_occurrence"].firstMatch
        XCTAssertTrue(occurrence.waitForExistence(timeout: 5), "No apareció ninguna fecha.")
        occurrence.tap()
        let payNow = app.buttons["scheduled_pay_now_button"].firstMatch
        XCTAssertTrue(payNow.waitForExistence(timeout: 5), "El menú de la próxima fecha no ofrece «Pagar ahora».")
        payNow.tap()

        let save = app.buttons["inbox_approve_button"]
        XCTAssertTrue(save.waitForHittable(timeout: 10), "«Pagar ahora» no abrió el formulario del borrador.")
        save.tap()

        XCTAssertTrue(save.waitForNonExistence(timeout: 10), "Guardar no cerró el formulario.")
        XCTAssertTrue(status.waitForHittable(timeout: 10), "Tras guardar no se volvió al detalle del pago.")
        XCTAssertFalse(app.buttons["inbox_success_accept"].exists, "Salió la pantalla de éxito de la Bandeja.")
        XCTAssertFalse(app.buttons["Guardar el siguiente"].exists, "Se ofreció pasar a otro borrador de la Bandeja.")
    }

    // MARK: - El borrador de un pago vencido

    func test_dueScheduledPayment_leavesItsDraftInTheInbox_andItApproves() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, scheduledDueToday: true, processDueScheduled: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()

        // El id de la fila es la nota del borrador, que es el nombre del pago (`DevSeedScheduledPayments.dueTodayName`).
        let draftRow = app.buttons["inbox_draft_row_Recibo vence hoy"]
        XCTAssertTrue(draftRow.waitForExistence(timeout: 10), "El pago que vence hoy no dejó su borrador en la Bandeja.")
        draftRow.tap()

        let save = app.buttons["inbox_approve_button"]
        XCTAssertTrue(save.waitForHittable(timeout: 10), "No se abrió el formulario del borrador.")
        save.tap()

        // Desde la Bandeja sí sale la pantalla de éxito; al aceptarla, el borrador ya no está pendiente.
        let accept = app.buttons["inbox_success_accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "Aprobar no llegó a la pantalla de éxito.")
        accept.tap()
        XCTAssertTrue(draftRow.waitForNonExistence(timeout: 10), "El borrador aprobado sigue en la Bandeja.")
    }
}
