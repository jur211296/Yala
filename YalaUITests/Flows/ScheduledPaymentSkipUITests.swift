//
//  ScheduledPaymentSkipUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `scheduled-payment-skip-occurrences` (escenarios
//  37.x): saltar una ocurrencia de un pago programado. Flujo: tab Planificación
//  (boundBy:2) → sub-tab Pagos programados (planning_chip_scheduledPayments) →
//  detalle del primer pago → tocar una ocurrencia → diálogo → Saltar. Verifica el
//  salto reabriendo la ocurrencia (el diálogo ofrece "Deshacer salto"), sin leer
//  el badge interno del row. Seed `minimal` (8 pagos recurrentes con ocurrencias
//  futuras). Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class ScheduledPaymentSkipUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navega al tab Planificación → sub-tab Pagos programados → detalle del primer pago.
    private func openFirstPaymentDetail(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 2).tap()
        let scheduledChip = app.buttons["planning_chip_scheduledPayments"]
        XCTAssertTrue(scheduledChip.waitForExistence(timeout: 10), "No apareció el sub-tab Pagos programados.")
        scheduledChip.tap()

        let firstRow = app.buttons["scheduled_payment_row"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "No se montó la lista de pagos programados.")
        firstRow.tap()
    }

    /// Smoke: el detalle de un pago programado muestra sus ocurrencias.
    func test_opensPaymentDetailWithOccurrences() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openFirstPaymentDetail(app)

        XCTAssertTrue(
            app.buttons["scheduled_occurrence"].firstMatch.waitForExistence(timeout: 5),
            "El detalle del pago no mostró ocurrencias."
        )
    }

    /// Saltar una ocurrencia: tras saltar, reabrir la ocurrencia ofrece "Deshacer salto".
    func test_skippingOccurrencePersists() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openFirstPaymentDetail(app)

        // Abrir el diálogo de la primera ocurrencia y saltarla.
        let occurrence = app.buttons["scheduled_occurrence"].firstMatch
        XCTAssertTrue(occurrence.waitForExistence(timeout: 5), "No apareció ninguna ocurrencia.")
        occurrence.tap()

        // Cada ocurrencia monta su propio confirmationDialog (mismo ID); el action sheet
        // presentado es el único en `app.sheets`, así que desambiguamos por ahí.
        let skipButton = app.sheets.buttons["scheduled_skip_button"].firstMatch
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5), "No apareció la opción Saltar en el diálogo.")
        skipButton.tap()

        // Reabrir la misma ocurrencia: ahora debe ofrecer "Deshacer salto" (quedó saltada).
        let occurrenceAgain = app.buttons["scheduled_occurrence"].firstMatch
        XCTAssertTrue(occurrenceAgain.waitForExistence(timeout: 5), "La ocurrencia desapareció tras saltar.")
        occurrenceAgain.tap()

        XCTAssertTrue(
            app.sheets.buttons["scheduled_unskip_button"].firstMatch.waitForExistence(timeout: 5),
            "Tras saltar, el diálogo no ofreció Deshacer salto — la ocurrencia no quedó saltada."
        )
    }
}
