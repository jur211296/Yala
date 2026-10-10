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
//  La lista abre en «Este mes», así que el test depende de que algún pago caiga en el mes en
//  curso. Los 8 del fixture van del día 3 al 28 y el calculador descarta lo anterior a la siembra:
//  del 29 en adelante «Este mes» quedaba vacío y los dos casos caían con «No se montó la lista».
//  El perfil `minimal` siembra además «Recibo fin de mes» (último día de cada mes), y los casos
//  `_onLastDayOfMonth` / `_onFirstDayOfMonth` fuerzan la fecha de la siembra con
//  `-uitest-scheduled-seed-day` para medirlo cualquier día, sin esperar a fin de mes.
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
        assertSkippingOccurrencePersists(seedDay: nil)
    }

    /// Fin de mes: sembrando el último día, solo «Recibo fin de mes» cae en «Este mes». Sin él, la lista
    /// sale vacía y este caso cae en `openFirstPaymentDetail` — el rojo del ticket, reproducido a demanda.
    func test_skippingOccurrencePersists_onLastDayOfMonth() {
        assertSkippingOccurrencePersists(seedDay: 31)
    }

    /// Principio de mes: los 9 pagos caen en «Este mes» y el primero sigue siendo uno del fixture de siempre.
    func test_skippingOccurrencePersists_onFirstDayOfMonth() {
        assertSkippingOccurrencePersists(seedDay: 1)
    }

    private func assertSkippingOccurrencePersists(seedDay: Int?) {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, scheduledSeedDay: seedDay)
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
