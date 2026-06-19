//
//  InboxNewItemsModalUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `inbox-new-items-modal` (escenarios 26.x): el
//  InboxAlertModal que normalmente dispara el sync de CloudKit. El hook
//  `-uitest-inbox-alert` encola `.showInboxAlert` con un payload de muestra tras
//  el seed (mismo path que el sync real), volviendo el modal determinista.
//  GOTCHA: el modal es un fullScreenCover que cubre el root → NO usar
//  waitForUITestReady (el uitest_ready queda tapado); esperar el botón del modal.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class InboxNewItemsModalUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El InboxAlertModal se presenta con el payload simulado por el hook.
    func test_inboxAlertModalPresentsOnLaunch() {
        let app = XCUIApplication()
        app.launchForUITest(inboxAlert: true)

        // El modal cubre el root → esperar su CTA directo (no uitest_ready).
        XCTAssertTrue(
            app.buttons["inbox_alert_view"].waitForExistence(timeout: 30),
            "No se presentó el InboxAlertModal (inbox_alert_view ausente)."
        )
        // El botón de descartar también está presente.
        XCTAssertTrue(
            app.buttons["inbox_alert_dismiss"].exists,
            "El modal no expone el botón de descartar (inbox_alert_dismiss)."
        )
    }

    /// Descartar el modal lo cierra y descubre el Panel debajo.
    func test_inboxAlertModalDismisses() {
        let app = XCUIApplication()
        app.launchForUITest(inboxAlert: true)

        let dismiss = app.buttons["inbox_alert_dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 30), "No apareció inbox_alert_dismiss.")
        dismiss.tap()

        // Tras descartar, el modal desaparece y el Panel queda accesible.
        XCTAssertTrue(
            app.buttons["inbox_alert_view"].waitForNonExistence(timeout: 5),
            "El InboxAlertModal no se cerró al descartar."
        )
        XCTAssertTrue(
            app.buttons["fab_new_transaction"].waitForExistence(timeout: 5),
            "No se descubrió el Panel tras cerrar el modal."
        )
    }
}
