//
//  NotificationTapDestinationsUITests.swift
//  YalaUITests
//
//  Cada tipo de notificación abre su destino en los tres estados de la app: cerrada (el toque llega antes de que termine
//  el arranque), en segundo plano (llega al volver) y delante (banner de `willPresent`). El toque se finge con
//  `-uitest-inbox-notification-tap <modo>` + `-uitest-notification-tap-link <deepLink>`, que entran por el mismo
//  `NotificationService.routeTap` que el toque real (ticket `notification-tap-opens-inbox-then-inbox-notice-pops-after`).
//
//  Los destinos con id (`budgets/<uuid>`, `scheduledPayments/<uuid>`, `accounts/<uuid>`, `statistics/<pestaña>/<período>`)
//  ya tienen su caso con la app delante (`BudgetsLote9UITests`, `ScheduledPaymentsLote10UITests`,
//  `UXAudit22Lote11y16UITests`); aquí van los destinos de pestaña en los tres estados.
//

import XCTest

final class NotificationTapDestinationsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private enum AppState: String { case cold, background = "warm-tap-first", foreground }

    private func launch(_ state: AppState, link: String, seed: String = "minimal") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: seed, extraArguments: [
            "-uitest-inbox-notification-tap", state.rawValue, "-uitest-notification-tap-link", link,
        ])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        // Los borradores de la semilla son nuevos al arrancar: su aviso sale antes de nada y se contesta.
        let dismiss = app.buttons["inbox_alert_dismiss"]
        if dismiss.waitForExistence(timeout: 10) { dismiss.tap() }
        if state == .background {
            XCUIDevice.shared.press(.home)
            XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
            app.activate()
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "Yala no volvió delante.")
        }
        return app
    }

    private func assertExists(_ app: XCUIApplication, _ id: String, _ message: String) {
        XCTAssertTrue(app.descendants(matching: .any)[id].firstMatch.waitForExistence(timeout: 20), message)
    }

    // MARK: - Resumen de pagos planificados (`scheduledPayments`) → Planificación › Pagos

    private func assertScheduledPayments(_ state: AppState) {
        let app = launch(state, link: "scheduledPayments")
        assertExists(app, "scheduled_payments_create_button", "\(state): el resumen de pagos no abrió Pagos planificados.")
        XCTAssertFalse(app.descendants(matching: .any)["budgets_create_button"].exists,
                       "\(state): el resumen de pagos dejó Presupuestos delante.")
    }

    func test_scheduledPaymentsSummary_cold() { assertScheduledPayments(.cold) }
    func test_scheduledPaymentsSummary_background() { assertScheduledPayments(.background) }
    func test_scheduledPaymentsSummary_foreground() { assertScheduledPayments(.foreground) }

    // MARK: - Recordatorio diario (`recordsStandalone`) → Registros

    private func assertRecords(_ state: AppState) {
        let app = launch(state, link: "recordsStandalone")
        assertExists(app, "records_summary_balance", "\(state): el recordatorio diario no abrió Registros.")
    }

    func test_dailyReminder_cold() { assertRecords(.cold) }
    func test_dailyReminder_background() { assertRecords(.background) }
    func test_dailyReminder_foreground() { assertRecords(.foreground) }

    // MARK: - Aviso de varios grupos del servidor (`groups`) → Grupos

    private func assertGroups(_ state: AppState) {
        let app = launch(state, link: "groups", seed: "grupos")
        assertExists(app, "group_card", "\(state): el aviso de grupos no abrió Grupos.")
    }

    func test_groupsPush_cold() { assertGroups(.cold) }
    func test_groupsPush_background() { assertGroups(.background) }
    func test_groupsPush_foreground() { assertGroups(.foreground) }
}
