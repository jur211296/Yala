//
//  SettlementAmountChangeNoticeUITests.swift
//  YalaUITests
//
//  Ticket `settlement-amount-edited-after-approval-leaves-the-bank-stale`: Ana me pagó 25, lo aprobé a «Banco QA» y la
//  liquidación pasa a 30 (`-uitest-seed-settlement-amount-change`, que re-puentea por el camino del pull). El Inbox tiene
//  que avisar, y las dos respuestas tienen que quitar el aviso sin que vuelva en el arranque siguiente (la pasada en frío
//  `reconcileSettlementAmountChangeNotices` corre en cada arranque). El dinero lo fijan los unit tests
//  (`SettlementAmountChangeNoticeTests`); aquí se prueba que el aviso se ve, se abre y se contesta.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class SettlementAmountChangeNoticeUITests: XCTestCase {
    /// Nota del escenario sembrado (`DevSeedSettlementAmountChange.note`): asidero, no copy.
    private let noticeRow = "inbox_draft_row_QA liquidación"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openInbox(_ app: XCUIApplication) {
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón del Inbox en el Panel.")
        inboxButton.tap()
    }

    /// Abre el aviso y comprueba que la hoja ofrece las dos salidas con las cifras del escenario.
    private func openNotice(_ app: XCUIApplication) {
        let row = app.buttons[noticeRow]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "El Inbox no avisó del importe cambiado.")
        XCTAssertTrue(row.label.contains("30"), "La fila del aviso no lleva el importe nuevo: «\(row.label)».")
        row.tap()
        let adjust = app.buttons["primary_button"]
        XCTAssertTrue(adjust.waitForExistence(timeout: 5), "No se abrió la hoja del aviso.")
        XCTAssertTrue(adjust.label.contains("30"), "«Ajustar» no nombra el importe nuevo: «\(adjust.label)».")
        let keep = app.buttons["group_draft_secondary_button"]
        XCTAssertTrue(keep.exists, "La hoja del aviso no ofrece dejarla como está.")
        XCTAssertTrue(keep.label.contains("25"), "«Dejar» no nombra lo que tiene la cuenta: «\(keep.label)».")
    }

    /// Relanza sobre el mismo store (sin reset ni seeds) y vuelve al Inbox: el aviso contestado no puede volver.
    private func relaunchAndExpectNoNotice(_ app: XCUIApplication) {
        app.terminate()
        app.launchForUITest(reset: false, seed: nil)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente en el segundo arranque.")
        openInbox(app)
        XCTAssertTrue(app.buttons["inbox_draft_row_Almuerzo equipo"].waitForExistence(timeout: 10),
                      "El Inbox del segundo arranque no cargó (control).")
        XCTAssertFalse(app.buttons[noticeRow].exists, "El arranque volvió a preguntar por una corrección ya contestada.")
    }

    func test_adjust_removesTheNotice_andItDoesNotComeBack() {
        let app = XCUIApplication()
        app.launchForUITest(settlementAmountChange: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openInbox(app)
        openNotice(app)

        app.buttons["primary_button"].tap()

        XCTAssertTrue(app.buttons[noticeRow].waitForNonExistence(timeout: 10), "Ajustar no quitó el aviso.")
        relaunchAndExpectNoNotice(app)
    }

    func test_keep_removesTheNotice_andItDoesNotComeBack() {
        let app = XCUIApplication()
        app.launchForUITest(settlementAmountChange: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openInbox(app)
        openNotice(app)

        app.buttons["group_draft_secondary_button"].tap()

        XCTAssertTrue(app.buttons[noticeRow].waitForNonExistence(timeout: 10), "Dejarla como está no quitó el aviso.")
        relaunchAndExpectNoNotice(app)
    }
}
