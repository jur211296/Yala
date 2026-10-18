//
//  ScheduledPaymentsLote10UITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2 · lote 10 (pagos planificados): la lista separa lo que falta de lo pagado y su cabecera dice lo que
//  falta (L10-1, L10-2); tres vistas del mes con leyenda en el calendario (L10-1 C, L10-3); el detalle con «Ya lo pagué»
//  y «Saltar este mes» con «Deshacer» (L10-8, L10-9, L10-10); pausar (L10-7); el ✓ que lleva a lo que falta (L10-4);
//  la rueda nativa del mes; y los avisos que abren el pago y la tarjeta (L10-13, L10-14).
//
//  Seed `minimal` sembrado como si hoy fuera el día 1 (`-uitest-scheduled-seed-day 1`): así hay fechas vencidas y
//  ninguna pagada, cualquier día que corra. Convenciones: CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class ScheduledPaymentsLote10UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ app: XCUIApplication, scheduledAlertTap: String? = nil, accountAlertTap: String? = nil) {
        app.launchForUITest(
            pro: true,
            scheduledAlertTap: scheduledAlertTap,
            accountAlertTap: accountAlertTap,
            scheduledSeedDay: 1
        )
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openFirstPendingPayment(_ app: XCUIApplication) {
        app.openScheduledPaymentsList()
        XCTAssertTrue(element(app, "scheduled_section_toPay").waitForExistence(timeout: 5), "Falta la sección «Por pagar».")
        let row = app.buttons["scheduled_payment_row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No se montó ninguna fila.")
        row.tap()
        XCTAssertTrue(element(app, "scheduled_detail_status").waitForExistence(timeout: 5), "No se abrió el detalle.")
    }

    // MARK: - Lista y cabecera (L10-1, L10-2, L10-3)

    func test_listAndHero_sayWhatIsLeft_andTheThreeViews() {
        let app = XCUIApplication()
        launch(app)
        app.openScheduledPaymentsList()

        XCTAssertTrue(element(app, "scheduled_hero_paid_of").exists, "La cabecera no dice «Pagaste X de Y».")
        XCTAssertTrue(element(app, "scheduled_section_toPay").exists, "Falta la sección «Por pagar».")
        XCTAssertTrue(element(app, "scheduled_status_pill").exists, "Las filas no llevan la píldora de estado.")

        app.buttons["scheduled_view_mode_timeline"].tap()
        XCTAssertTrue(app.buttons["scheduled_timeline_row"].firstMatch.waitForExistence(timeout: 5), "La línea de tiempo no se montó.")

        app.buttons["scheduled_view_mode_calendar"].tap()
        XCTAssertTrue(element(app, "scheduled_calendar_legend").waitForExistence(timeout: 5), "El calendario no lleva leyenda.")
    }

    // MARK: - Detalle: «Ya lo pagué» → «Apuntarlo ahora» (L10-8, L10-9)

    func test_paidButton_recordsTheMonth_inOneTap() {
        let app = XCUIApplication()
        launch(app)
        openFirstPendingPayment(app)
        XCTAssertFalse(element(app, "scheduled_detail_month_paid").exists, "Precondición: el mes aún no está pagado.")

        app.buttons["scheduled_detail_paid_button"].tap()
        let recordNow = app.buttons["scheduled_paid_record_now"]
        XCTAssertTrue(recordNow.waitForExistence(timeout: 5), "La hoja «Ya lo pagué» no ofreció «Apuntarlo ahora».")
        recordNow.tap()

        XCTAssertTrue(
            element(app, "scheduled_detail_month_paid").waitForExistence(timeout: 5),
            "Tras apuntarlo, el detalle no dice que el mes ya está pagado."
        )
    }

    // MARK: - «Saltar este mes» y «Deshacer» (L10-10)

    func test_skipThisMonth_showsUndo_andUndoRestores() {
        let app = XCUIApplication()
        launch(app)
        openFirstPendingPayment(app)
        let status = element(app, "scheduled_detail_status")
        let before = status.label

        app.buttons["scheduled_detail_skip_button"].tap()
        let undo = app.buttons["scheduled_skip_undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3), "Tras saltar no salió el aviso con «Deshacer».")
        XCTAssertNotEqual(status.label, before, "Saltar no movió la próxima fecha.")

        undo.tap()
        let restored = NSPredicate(format: "label == %@", before)
        expectation(for: restored, evaluatedWith: status)
        waitForExpectations(timeout: 5)
    }

    // MARK: - Pausar (L10-7)

    func test_pause_movesThePaymentToPaused_andResumeIsOffered() {
        let app = XCUIApplication()
        launch(app)
        openFirstPendingPayment(app)

        app.buttons["scheduled_detail_pause_button"].tap()
        XCTAssertTrue(app.buttons["scheduled_detail_resume_button"].waitForExistence(timeout: 5), "Pausado no ofrece «Reanudar».")

        app.buttons["chevron.left"].firstMatch.tap() // el «Atrás» del detalle (`YalaToolbarButton`)
        XCTAssertTrue(element(app, "scheduled_section_paused").waitForExistence(timeout: 5), "La lista no tiene sección «Pausados».")
    }

    // MARK: - Formulario (L10-4)

    func test_saveWithSomethingMissing_marksWhatIsMissing() {
        let app = XCUIApplication()
        launch(app)
        app.openScheduledPaymentsList()
        app.buttons["scheduled_payments_create_fab"].tap()
        let save = app.buttons["toolbar_save_button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No se abrió el editor.")
        XCTAssertTrue(save.isEnabled, "El ✓ debe poder tocarse aunque falte algo.")

        save.tap()
        XCTAssertTrue(element(app, "scheduled_missing_badge").waitForExistence(timeout: 3), "El ✓ no marcó lo que falta.")
        XCTAssertTrue(app.textFields["scheduled_name_field"].exists, "El editor se cerró con campos vacíos.")
    }

    // MARK: - Rueda del mes (card «el selector de período se cierra al arrastrar la rueda»)

    func test_periodSelector_isTheNativeWheel() {
        let app = XCUIApplication()
        launch(app)
        app.openScheduledPaymentsList()
        app.buttons.matching(identifier: "period_navigation_label").firstMatch.tap()
        let wheel = element(app, "budget_period_wheel")
        XCTAssertTrue(wheel.waitForExistence(timeout: 5), "El selector de mes no es la rueda nativa.")
        wheel.swipeDown()
        XCTAssertTrue(wheel.exists, "Arrastrar la rueda cerró la hoja.")
    }

    // MARK: - Avisos (L10-13, L10-14)

    func test_reminderTap_opensThatPaymentsDetail() {
        let app = XCUIApplication()
        launch(app, scheduledAlertTap: "Netflix")
        XCTAssertTrue(
            element(app, "scheduled_detail_status").waitForExistence(timeout: 10),
            "Tocar el recordatorio no abrió el detalle del pago."
        )
        XCTAssertTrue(app.navigationBars["Netflix"].exists, "Abrió el detalle de otro pago.")
    }

    func test_cardReminderTap_opensTheAccountSheet() {
        let app = XCUIApplication()
        launch(app, accountAlertTap: "*")
        XCTAssertTrue(
            element(app, "account_detail_sheet").waitForExistence(timeout: 10),
            "Tocar el aviso de la tarjeta no abrió su ficha."
        )
    }
}
