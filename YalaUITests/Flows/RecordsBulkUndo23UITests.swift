//
//  RecordsBulkUndo23UITests.swift
//  YalaUITests
//
//  Registros, decisión 18 y 75 de la revisión 2.3 (E1 + E2), lo que se ve en pantalla:
//  - «Seleccionar todo» pasa a «Seleccionar los N» y cada día trae «Seleccionar día».
//  - Borrar lo elegido pregunta con fechas y dice que hay unos segundos para deshacerlo; «Deshacer» lo devuelve.
//  - «Editar N registros» dice «Ahora:», no «Hoy:», y aplicar deja un aviso con «Deshacer» que devuelve lo de antes.
//  Seed `minimal`, idioma fijo de la suite (es-419). Cada paso deja su captura en el `.xcresult` (evidencia del PR).
//

import XCTest

final class RecordsBulkUndo23UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El aviso dura 30 s: el runner del CI tarda más de 5 s entre dos esperas (regla de `testing.md`).
    private func launchInRecords() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(deeplink: "records", extraArguments: ["-uitest-undo-notice-seconds", "30"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 15), "No hay filas de registro.")
        return app
    }

    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "record_row")
    }

    private func enterSelectMode(_ app: XCUIApplication) {
        let select = app.buttons["records_select_visible"]
        XCTAssertTrue(select.waitForExistence(timeout: 10), "«Seleccionar» no está en la barra de Registros.")
        select.tap()
        XCTAssertTrue(app.descendants(matching: .any)["records_selection_hint"].waitForExistence(timeout: 10),
                      "Tocar «Seleccionar» no activó el modo selección.")
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - E2 + E1: seleccionar todo dice cuántos, borrar se puede deshacer

    func test_selectAll_saysHowMany_deleteAsksWithDates_andUndoBringsThemBack() {
        let app = launchInRecords()
        enterSelectMode(app)
        XCTAssertTrue(app.buttons["records_select_day_button"].firstMatch.waitForExistence(timeout: 5),
                      "La cabecera del día no ofrece «Seleccionar día».")
        shot(app, "despues-1-seleccionar")

        let selectAll = app.buttons["records_select_all_button"]
        XCTAssertTrue(selectAll.waitForExistence(timeout: 5), "No está el botón de seleccionar todo.")
        XCTAssertTrue(selectAll.label.hasPrefix("Seleccionar "), "«\(selectAll.label)»")
        XCTAssertNotEqual(selectAll.label, "Seleccionar todo", "El botón no dice cuántos marca.")
        let total = selectAll.label.replacingOccurrences(of: "Seleccionar los ", with: "")
        selectAll.tap()

        let count = app.staticTexts["records_selection_count"]
        XCTAssertTrue(count.waitForExistence(timeout: 10), "La barra no dice cuántos hay elegidos.")
        XCTAssertTrue(count.label.hasPrefix(total), "Elegidos «\(count.label)» frente a «\(total)» del botón.")
        shot(app, "despues-2-todo-seleccionado")

        app.buttons["bulk_delete_button"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Borrar lo elegido no preguntó.")
        let message = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " ")
        XCTAssertTrue(message.contains("deshacerlo"), "La pregunta sigue diciendo que no se puede deshacer: «\(message)».")
        XCTAssertTrue(message.contains(" al ") || message.hasPrefix("El "), "La pregunta no dice de qué fechas: «\(message)».")
        shot(app, "despues-3-pregunta-borrar")
        alert.buttons["Eliminar"].firstMatch.tap()

        let undo = app.buttons["record_deleted_undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10), "Borrar en lote no dejó el aviso con «Deshacer».")
        XCTAssertTrue(rows(app).firstMatch.waitForNonExistence(timeout: 10), "Lo borrado sigue en la lista.")
        shot(app, "despues-4-aviso-borrado")
        undo.tap()
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 10), "«Deshacer» no devolvió los registros.")
    }

    // MARK: - E2: Seleccionar día

    func test_selectDay_marksThatDay_andASecondTapUnmarksIt() {
        let app = launchInRecords()
        enterSelectMode(app)
        let day = app.buttons["records_select_day_button"].firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 5), "La cabecera del día no ofrece «Seleccionar día».")
        XCTAssertTrue(day.label.hasPrefix("Seleccionar día"), "«\(day.label)»")
        day.tap()
        let count = app.staticTexts["records_selection_count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "«Seleccionar día» no eligió nada.")
        XCTAssertTrue(day.label.hasPrefix("Deseleccionar día"), "«\(day.label)»")
        day.tap()
        XCTAssertTrue(app.descendants(matching: .any)["records_selection_hint"].waitForExistence(timeout: 5),
                      "El segundo toque no quitó el día.")
    }

    // MARK: - Decisión 75 + E1: «Ahora:» y deshacer la edición

    func test_bulkEdit_saysNow_andTheNoticeUndoesTheChange() {
        let app = launchInRecords()
        enterSelectMode(app)
        let first = rows(app).element(boundBy: 0)
        let firstLabel = first.label
        first.tap()
        rows(app).element(boundBy: 1).tap()
        let count = app.staticTexts["records_selection_count"]
        let two = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH '2'"), object: count)
        XCTAssertEqual(XCTWaiter().wait(for: [two], timeout: 10), .completed, "No quedaron dos elegidos.")
        app.buttons["bulk_edit_button"].tap()

        let accountOption = app.buttons["bulk_edit_option_account"]
        XCTAssertTrue(accountOption.waitForExistence(timeout: 5), "No se abrió «Editar 2 registros».")
        let labels = [accountOption.label, app.buttons["bulk_edit_option_note"].label]
        XCTAssertFalse(labels.contains { $0.contains("Hoy:") }, "La hoja sigue diciendo «Hoy:»: \(labels)")
        XCTAssertTrue(labels.contains { $0.contains("Ahora:") }, "La hoja no dice «Ahora:»: \(labels)")
        shot(app, "despues-5-editar-ahora")

        app.buttons["bulk_edit_option_note"].tap()
        let noteField = app.textFields["bulk_note_field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 5), "No se abrió la nota.")
        noteField.tap()
        noteField.typeText("Nota del lote")
        app.buttons["toolbar_save_button"].tap()
        let apply = app.buttons["bulk_edit_apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5))
        apply.tap()

        let undo = app.buttons["records_bulk_edit_undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10), "Aplicar el lote no dejó el aviso con «Deshacer».")
        XCTAssertTrue(rows(app).element(boundBy: 0).label.contains("Nota del lote"), "El lote no se aplicó.")
        shot(app, "despues-6-aviso-editar")
        undo.tap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", firstLabel),
                                                 object: rows(app).element(boundBy: 0))
        XCTAssertEqual(XCTWaiter().wait(for: [restored], timeout: 10), .completed,
                       "«Deshacer» no devolvió la nota: «\(rows(app).element(boundBy: 0).label)».")
    }
}
