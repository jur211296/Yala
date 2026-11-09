//
//  GroupBridgeLeftoversUITests.swift
//  YalaUITests
//
//  Bug del 2026-11-09 (seed `grupos-repetidos`): dos gastos de grupo pagados con cuenta a los que una pasada ciega del
//  puente dejó un borrador «Elige cuenta» en la Bandeja y el «Préstamo a grupos» repetido.
//  - La fila del borrador en USD se pinta en USD, no en la divisa por defecto (S/).
//  - La Bandeja avisa, la hoja enseña qué sobra y, tras confirmar, los borradores se van y el aviso también.
//

import XCTest

final class GroupBridgeLeftoversUITests: XCTestCase {

    private let usdExpense = "Google One"
    private let penExpense = "Gasolina"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openInbox(_ app: XCUIApplication) {
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()
    }

    func test_usdDraftWithoutAccount_isShownInUSD() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos-repetidos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openInbox(app)

        let usd = app.buttons["inbox_draft_row_\(usdExpense)"]
        let pen = app.buttons["inbox_draft_row_\(penExpense)"]
        XCTAssertTrue(usd.waitForExistence(timeout: 8), "La Bandeja no enseña el borrador de «\(usdExpense)».")
        XCTAssertTrue(pen.exists, "La Bandeja no enseña el borrador de «\(penExpense)».")
        // Control: el de soles sí sale en S/; el de dólares no.
        XCTAssertTrue(pen.label.contains("S/"), "El borrador en PEN debía salir en S/: \(pen.label)")
        XCTAssertFalse(usd.label.contains("S/"), "El borrador en USD salió en soles: \(usd.label)")
    }

    func test_notice_listsTheLeftovers_andConfirmingRemovesThem() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos-repetidos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openInbox(app)

        let banner = app.buttons["inbox_group_leftovers_banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 8), "La Bandeja no avisa de los gastos de grupo repetidos.")
        XCTAssertTrue(banner.label.contains("2"), "El aviso debía contar 2 gastos: \(banner.label)")
        banner.tap()

        let remove = app.buttons["inbox_group_leftovers_remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "No se abrió la hoja de los repetidos.")
        XCTAssertTrue(app.descendants(matching: .any)["inbox_group_leftovers_intro"].exists)
        remove.tap()

        // Nada se quita sin el «sí»: primero la confirmación.
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Quitar no pidió confirmación.")
        XCTAssertTrue(app.buttons["inbox_draft_row_\(usdExpense)"].exists, "Se quitó algo antes de confirmar.")
        alert.buttons["Quitar"].firstMatch.tap()

        XCTAssertTrue(app.buttons["inbox_draft_row_\(usdExpense)"].waitForNonExistence(timeout: 8),
                      "El borrador sobrante de «\(usdExpense)» sigue en la Bandeja tras confirmar.")
        XCTAssertFalse(app.buttons["inbox_draft_row_\(penExpense)"].exists,
                       "El borrador sobrante de «\(penExpense)» sigue en la Bandeja tras confirmar.")
        XCTAssertFalse(banner.exists, "El aviso sigue tras quitar lo repetido.")
    }

    func test_cancellingTheConfirmation_removesNothing() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos-repetidos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openInbox(app)

        let banner = app.buttons["inbox_group_leftovers_banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 8))
        banner.tap()
        let remove = app.buttons["inbox_group_leftovers_remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Cancelar"].firstMatch.tap()
        app.buttons["inbox_group_leftovers_cancel"].tap()

        XCTAssertTrue(app.buttons["inbox_draft_row_\(usdExpense)"].waitForExistence(timeout: 5),
                      "Cancelar se llevó el borrador.")
        XCTAssertTrue(banner.exists, "Cancelar quitó el aviso.")
    }
}
