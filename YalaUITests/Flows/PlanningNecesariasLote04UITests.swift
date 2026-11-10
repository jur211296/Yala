//
//  PlanningNecesariasLote04UITests.swift
//  YalaUITests
//
//  Lote 04 de mejoras necesarias 2.3 (Planificación), lo que se ve en pantalla:
//  (1) tras «Saltar este mes», el detalle no dice que el mes está pagado: dice que se saltó.
//  (2) un mes cerrado no dice «Te quedan» sobre la columna de cifras: dice «Te sobró».
//  Las capturas quedan en el `.xcresult` como antes/después del PR. Scheme Yala Dev.
//

import XCTest

final class PlanningNecesariasLote04UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - (1) Saltar no es pagar

    func test_skipThisMonth_detailSaysSkipped_notPaid() {
        let app = XCUIApplication()
        // Seed del día 1: el pago de «este mes» está por pagar sea el día que sea (molde de `ScheduledPaymentsLote10UITests`).
        app.launchForUITest(pro: true, scheduledSeedDay: 1)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openScheduledPaymentsList()
        XCTAssertTrue(element(app, "scheduled_section_toPay").waitForExistence(timeout: 5), "Falta la sección «Por pagar».")
        let row = app.buttons["scheduled_payment_row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No se montó ninguna fila.")
        row.tap()
        XCTAssertTrue(element(app, "scheduled_detail_status").waitForExistence(timeout: 5), "No se abrió el detalle.")
        XCTAssertFalse(element(app, "scheduled_detail_month_paid").exists, "Precondición: el mes aún no está hecho.")

        app.buttons["scheduled_detail_skip_button"].tap()
        let skipped = element(app, "scheduled_detail_month_skipped")
        // La espera va antes de la captura para que el «antes» (sin el arreglo) también la deje en el `.xcresult`.
        let saysSkipped = skipped.waitForExistence(timeout: 5)
        attach(app, "lote04-1-detalle-tras-saltar")

        XCTAssertFalse(element(app, "scheduled_detail_month_paid").exists,
                       "Tras «Saltar este mes» el detalle dice que el mes ya está pagado.")
        XCTAssertTrue(saysSkipped, "Tras «Saltar este mes» el detalle no dice que se saltó.")
    }

    // MARK: - (5) VoiceOver: los selectores del editor tienen nombre

    /// Lo que VoiceOver lee de un control es su `label` en el árbol. Sin nombre, el segmentado «Una sola vez / Repetir»
    /// salía vacío y el del día del mes decía solo el número. Sin texto localizado: se pide que haya un nombre y, en el
    /// del día, que no sea solo la cifra elegida.
    func test_paymentEditor_selectorsHaveNames() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openScheduledPaymentsList()
        XCTAssertFalse(app.descendants(matching: .any)["scheduled_tab_picker"].label.isEmpty,
                       "El segmentado de la lista no tiene nombre.")
        let newPayment = app.buttons["scheduled_payments_create_button"]
        XCTAssertTrue(newPayment.waitForExistence(timeout: 5), "No apareció «Nuevo pago planificado».")
        newPayment.tap()

        let recurrence = app.segmentedControls["scheduled_recurrence_picker"]
        XCTAssertTrue(recurrence.waitForExistence(timeout: 5), "No se montó el editor.")
        let dayOfMonth = element(app, "scheduled_day_of_month_picker")
        XCTAssertTrue(dayOfMonth.waitForExistence(timeout: 5), "El editor no abrió en mensual.")
        let named = app.popUpButtons.allElementsBoundByIndex.map { "«\($0.label)»" }.joined(separator: " ")
        add(XCTAttachment(string: "segmentado: «\(recurrence.label)» · día: «\(dayOfMonth.label)» · menús: \(named)"))

        XCTAssertFalse(recurrence.label.isEmpty, "«Una sola vez / Repetir» no tiene nombre.")
        XCTAssertNotNil(dayOfMonth.label.rangeOfCharacter(from: .letters),
                        "El día del mes solo dice la cifra: «\(dayOfMonth.label)».")
    }

    // MARK: - (2) Mes cerrado: «Te sobró»

    func test_closedMonth_saysLeftOver_notRemaining() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "budgets")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let previous = app.buttons["period_navigation_previous"].firstMatch
        XCTAssertTrue(previous.waitForExistence(timeout: 15), "No se montó el navegador de mes de Presupuestos.")
        XCTAssertTrue(app.buttons["budget_row_Movilidad"].waitForExistence(timeout: 15), "No está la fila de Movilidad.")
        previous.tap()

        let saysLeftOver = element(app, "budgets_section_leftover_label").waitForExistence(timeout: 10)
        attach(app, "lote04-2-mes-cerrado")

        XCTAssertFalse(element(app, "budgets_section_remaining_label").exists, "Un mes cerrado sigue diciendo «Te quedan».")
        XCTAssertTrue(saysLeftOver, "Un mes cerrado no dice «Te sobró».")
    }
}
