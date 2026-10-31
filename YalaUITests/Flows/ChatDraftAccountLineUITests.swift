//
//  ChatDraftAccountLineUITests.swift
//  YalaUITests
//
//  Card y1z6 (Jürgen, 2026-10-30): en un registro propuesto por Yala IA, tras cambiar la cuenta a la línea en dólares de
//  una tarjeta con dos divisas, volver a tocar la tarjeta no hacía nada: el borrador ya iba en USD y la tarjeta se
//  enrutaba con esa divisa, de vuelta a la misma línea. Recorre el selector de cuenta de la tarjeta propuesta: línea,
//  tarjeta, otra cuenta y otra vez la línea, mirando la píldora tras cada cambio.
//
//  Seed `tarjeta-dos-lineas` («Visa QA» en soles con su línea «Visa QA · USD», y «Ahorros QA» en soles) y
//  `-uitest-chat-draft` (dos registros propuestos sin servidor).
//

import XCTest

final class ChatDraftAccountLineUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func openChatWithDrafts() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true,
            seed: "tarjeta-dos-lineas",
            deeplink: "records",
            aiChatReady: true,
            extraArguments: ["-uitest-chat-draft"]
        )
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let chatEntry = app.buttons["fab_chat"]
        XCTAssertTrue(chatEntry.waitForExistence(timeout: 15), "No aparece la entrada de Yala IA en Registros.")
        chatEntry.tap()
        XCTAssertTrue(app.textFields["chat_input"].waitForExistence(timeout: 10), "No se abrió Yala IA.")
        return app
    }

    /// Abre el selector desde la píldora de cuenta del primer registro propuesto, toca `rowName` y espera a que la
    /// píldora diga `expected`.
    private func choose(_ rowName: String, expecting expected: String, in app: XCUIApplication) {
        let chip = app.buttons.matching(identifier: "chat_draft_chip_account").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No aparece la píldora de cuenta del registro propuesto.")
        chip.tap()
        let row = app.buttons["account_selector_row_\(rowName)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "El selector de cuenta no enseña «\(rowName)».")
        row.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 10), "El selector de cuenta no se cerró tras elegir «\(rowName)».")
        let settled = NSPredicate(format: "label == %@", expected)
        let changed = expectation(for: settled, evaluatedWith: chip)
        wait(for: [changed], timeout: 5)
        XCTAssertEqual(chip.label, expected, "Tras elegir «\(rowName)» la píldora de cuenta dice «\(chip.label)».")
    }

    func test_draftAccount_canChangeAgainAfterPickingTheSecondLine() {
        let app = openChatWithDrafts()
        choose("Visa QA · USD", expecting: "Visa QA · USD", in: app)
        // El bug: la tarjeta volvía a la línea en dólares y la píldora no cambiaba.
        choose("Visa QA", expecting: "Visa QA", in: app)
        choose("Ahorros QA", expecting: "Ahorros QA", in: app)
        choose("Visa QA · USD", expecting: "Visa QA · USD", in: app)
        choose("Visa QA", expecting: "Visa QA", in: app)
    }
}
