//
//  NewRecordDraftSurvivesCloseUITests.swift
//  YalaUITests
//
//  Card 77j1: lo que se escribe en Nuevo registro sobrevive a que iOS cierre Yala. El cierre de iOS se imita con lo que
//  hace el sistema: la app pasa a segundo plano y el proceso muere sin pasar por ningún `onDisappear`
//  (`XCUIApplication.terminate()` desde segundo plano). El segundo arranque va sin `-uitest-reset` ni semilla: el
//  borrador vive en el `UserDefaults` del simulador y una semilla duplicaría el corpus (`testing.md`).
//

import XCTest

final class NewRecordDraftSurvivesCloseUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Manda Yala a segundo plano y espera a que iOS la suspenda: es desde ahí desde donde el sistema la cierra sin
    /// avisar. Matarla en el instante en que deja de estar delante no es lo que hace iOS, y la escritura del borrador
    /// podía no haber llegado a disco (medido: el primer borrador se perdía así en la corrida del gate).
    private func sendToBackgroundUntilSuspended(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10) || app.state == .runningBackgroundSuspended,
                      "Yala no pasó a segundo plano.", file: file, line: line)
        _ = app.wait(for: .runningBackgroundSuspended, timeout: 15)
    }

    private func openNewRecord(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).",
                      file: file, line: line)
        manual.tap()
        let amount = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "No se montó Nuevo registro.", file: file, line: line)
        return amount
    }

    /// Escribir, salir a otra app y que iOS cierre Yala: al volver a abrir Nuevo registro sale lo escrito con la línea
    /// que lo dice. «Empezar de cero» lo borra, y la siguiente apertura ya no lo trae.
    func test_whatYouTyped_survivesIOSClosingYala_andStartOverDropsIt() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let amount = openNewRecord(app)
        amount.tap()
        amount.typeText("45")

        // iOS cierra Yala desde segundo plano: sin `onDisappear`, sin cerrar el formulario.
        sendToBackgroundUntilSuspended(app)
        app.terminate()

        app.launchForUITest(reset: false, seed: nil)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente en el segundo arranque.")

        let restoredAmount = openNewRecord(app)
        let line = app.descendants(matching: .any)["new_transaction_draft_restored"]
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Nuevo registro no avisó de que recuperó el borrador.")
        XCTAssertTrue((restoredAmount.value as? String ?? "").contains("45"),
                      "El monto escrito no volvió: \(String(describing: restoredAmount.value)).")

        let startOver = app.buttons["new_transaction_draft_start_over"]
        XCTAssertTrue(startOver.waitForExistence(timeout: 5), "Falta «Empezar de cero».")
        startOver.tap()
        XCTAssertTrue(line.waitForNonExistence(timeout: 5), "La línea del borrador siguió tras «Empezar de cero».")
        XCTAssertFalse((restoredAmount.value as? String ?? "").contains("45"), "«Empezar de cero» dejó el monto.")

        // Sin nada escrito la X cierra sin preguntar; al abrir otra vez, nada que recuperar.
        app.closeNewTransactionDiscarding()
        _ = openNewRecord(app)
        XCTAssertFalse(line.waitForExistence(timeout: 2), "El borrador volvió tras «Empezar de cero».")
    }

    /// Descartar con la X es decir que no se quiere: el borrador guardado al pasar a segundo plano se va con él.
    func test_discardingTheForm_dropsTheSavedDraft() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let amount = openNewRecord(app)
        amount.tap()
        amount.typeText("12")

        // Segundo plano (se guarda el borrador) y vuelta, sin que iOS cierre nada.
        sendToBackgroundUntilSuspended(app)
        app.activate()
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "Al volver, Nuevo registro no seguía abierto.")

        app.closeNewTransactionDiscarding()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5), "Nuevo registro no se cerró al descartar.")
        // Más tarde, iOS cierra Yala desde segundo plano.
        sendToBackgroundUntilSuspended(app)
        app.terminate()

        app.launchForUITest(reset: false, seed: nil)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente en el segundo arranque.")
        _ = openNewRecord(app)
        XCTAssertFalse(app.descendants(matching: .any)["new_transaction_draft_restored"].waitForExistence(timeout: 2),
                       "Tras descartar, el borrador volvió en el siguiente arranque.")
    }
}
