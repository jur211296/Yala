//
//  InboxDuplicateCheckUITests.swift
//  YalaUITests
//
//  Lote 03 de las necesarias 2.3, punto 1 (ticket `inbox-bulk-save-and-swipe-skip-the-duplicate-check`). Con
//  `-uitest-inbox-duplicate-draft` la semilla guarda un registro gemelo de «Almuerzo equipo» (mismo día, importe y
//  cuenta), el caso del pago que llega por el correo del banco y por Apple Pay. Antes, «Guardar los N listos» y deslizar
//  lo guardaban otra vez sin decir nada; solo el borrador abierto avisaba.
//

import XCTest

final class InboxDuplicateCheckUITests: XCTestCase {
    private let twinDraft = "Almuerzo equipo"
    private let otherDraft = "Taxi aeropuerto"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchWithTheTwin() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-uitest-inbox-duplicate-draft"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()
        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(twinDraft)"].waitForExistence(timeout: 5),
            "La Bandeja no mostró el borrador gemelo."
        )
        return app
    }

    private func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// «Guardar los 2 listos» guarda el que no se parece a nada, deja el gemelo en la Bandeja y lo dice.
    func test_saveReady_leavesThePossibleDuplicatePending_andSaysSo() {
        let app = launchWithTheTwin()

        let saveReady = app.buttons["inbox_save_ready"]
        XCTAssertTrue(saveReady.waitForExistence(timeout: 5), "Con dos borradores completos no salió «Guardar los listos».")
        saveReady.tap()
        let confirm = app.alerts.firstMatch.buttons["inbox_save_ready_confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No se pidió confirmación antes de guardar todo.")
        confirm.tap()

        let back = app.buttons["inbox_bulk_success_back"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "No salió la pantalla final tras guardar los listos.")
        attachScreenshot("lote-pantalla-final", of: app)
        // La línea es un `Label` con icono: el id llega al icono y al texto, y se busca el texto.
        let duplicates = app.staticTexts.matching(
            NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "inbox_bulk_success_duplicates", "posible duplicado")
        ).firstMatch
        XCTAssertTrue(duplicates.exists, "La pantalla final no dice que uno se quedó por posible duplicado.")
        XCTAssertTrue(duplicates.label.hasSuffix(": 1"), "La línea de duplicados dice «\(duplicates.label)».")
        back.tap()

        // Queda uno pendiente: la Bandeja sigue abierta, con el gemelo dentro y sin el otro.
        XCTAssertTrue(back.waitForNonExistence(timeout: 10), "La pantalla final no se cerró al volver a la Bandeja.")
        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(twinDraft)"].waitForExistence(timeout: 5),
            "El posible duplicado salió de pendientes: se guardó dos veces."
        )
        XCTAssertFalse(app.buttons["inbox_draft_row_\(otherDraft)"].exists, "El borrador sin gemelo no se guardó.")
    }

    /// Deslizar sobre el gemelo pregunta antes de guardar; «Cancelar» lo deja en la Bandeja.
    func test_swipeToSave_onAPossibleDuplicate_asksFirst_andCancelKeepsIt() {
        let app = launchWithTheTwin()
        swipeToSave(app.buttons["inbox_draft_row_\(twinDraft)"])

        let cancel = app.alerts.firstMatch.buttons["inbox_swipe_duplicate_cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Deslizar guardó el posible duplicado sin preguntar.")
        attachScreenshot("deslizar-aviso", of: app)
        cancel.tap()

        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5), "El aviso no se cerró con «Cancelar».")
        // Con el borrador guardado, la fila sale de pendientes en menos de un segundo (lo mide el caso de al lado).
        XCTAssertFalse(
            app.buttons["inbox_draft_row_\(twinDraft)"].waitForNonExistence(timeout: 3),
            "«Cancelar» guardó igual el borrador."
        )
    }

    /// «Guardar de todas formas» lo guarda: la salida de quien sabe que son dos pagos distintos sigue ahí. Se mide por el
    /// borrador que sale de pendientes y no por la pantalla de éxito: la de deslizar sale vacía también sin duplicado
    /// (fallo previo, ticket `inbox-swipe-save-success-sheet-shows-blank`).
    func test_swipeToSave_onAPossibleDuplicate_saveAnywaySavesIt() {
        let app = launchWithTheTwin()
        let row = app.buttons["inbox_draft_row_\(twinDraft)"]
        swipeToSave(row)

        let saveAnyway = app.alerts.firstMatch.buttons["inbox_swipe_duplicate_save_anyway"].firstMatch
        XCTAssertTrue(saveAnyway.waitForExistence(timeout: 5), "Deslizar guardó el posible duplicado sin preguntar.")
        saveAnyway.tap()

        XCTAssertTrue(row.waitForNonExistence(timeout: 10), "«Guardar de todas formas» no guardó el borrador.")
    }

    /// El deslizamiento completo hacia la derecha guarda (molde de `InboxCrudUITests` para el de la izquierda).
    private func swipeToSave(_ row: XCUIElement) {
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció la fila a deslizar.")
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5))
        let end = row.coordinate(withNormalizedOffset: CGVector(dx: 1.6, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }
}
