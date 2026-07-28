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
        //
        // Timeout 20 s y no 5 s (Lista Negra 2026-07-28, cerrada): lo que se afirma aquí es que el
        // cover NO queda pegado PARA SIEMPRE —el bug «toolbar muerta» de TestFlight 2.0.5—, no
        // cuánto tarda en irse. Medido con os_log sobre el mismo binario: la app pide el
        // desmontaje siempre a los 284 ms del tap (invariante en verdes y rojas), pero el
        // dismissal efectivo del `fullScreenCover` lo completa SwiftUI/UIKit entre 554 ms y más de
        // 7 s según la carga del arranque. Con 5 s el test caía ~1 de cada 2 sin que nada
        // estuviera roto. El timeout solo se consume en el caso malo: cuando pasa, resuelve al
        // primer check (~0,8 s).
        XCTAssertTrue(
            app.buttons["inbox_alert_view"].waitForNonExistence(timeout: 20),
            "El InboxAlertModal no se cerró al descartar."
        )
        XCTAssertTrue(
            app.buttons["fab_new_transaction"].waitForExistence(timeout: 5),
            "No se descubrió el Panel tras cerrar el modal."
        )
    }
}
