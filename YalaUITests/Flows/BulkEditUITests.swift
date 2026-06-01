//
//  BulkEditUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `transactions-bulk-edit` (escenarios 5.14-5.22):
//  modo selección en la lista de Registros (Estadísticas → chip Registros) +
//  edición masiva de la nota de varias transacciones. La verificación es de
//  FLUJO (el modo selección termina y vuelve a la lista normal), no de contenido,
//  porque las filas no tienen texto estable. Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class BulkEditUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navega a Estadísticas (2º tab del config por defecto) → chip Registros
    /// (el chip por defecto es Insights) → activa el modo selección. La barra de
    /// chips es un ScrollView horizontal y Registros (el último) puede quedar fuera
    /// de vista → se revela con swipe sobre un chip visible antes de tocarlo.
    private func enterRecordsSelectionMode(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 1).tap()

        let recordsChip = app.buttons["detail_chip_registros"]
        XCTAssertTrue(recordsChip.waitForExistence(timeout: 10), "No apareció el chip Registros en Estadísticas.")
        // Scrollear el contenedor horizontal de chips para revelar Registros (último).
        // (Consultar .isHittable de un elemento fuera de vista lanza, así que se
        // scrollea el ScrollView que contiene los chips directamente.)
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists {
            chipsBar.swipeLeft()
        }
        recordsChip.tap()

        let selectButton = app.buttons["records_select_button"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 5), "No apareció el botón de modo selección.")
        selectButton.tap()
    }

    /// Smoke: modo selección → seleccionar 2 TX → editar masivo abre BulkEditSheet.
    /// (Con una sola TX seleccionada el botón abre el editor individual, no el masivo.)
    func test_opensBulkEditSheet() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        enterRecordsSelectionMode(app)

        let rows = app.buttons.matching(identifier: "record_row")
        XCTAssertTrue(rows.element(boundBy: 0).waitForExistence(timeout: 5), "No hay filas de transacción (record_row) para seleccionar.")
        rows.element(boundBy: 0).tap()
        rows.element(boundBy: 1).tap()

        let editButton = app.buttons["bulk_edit_button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "No apareció el botón de editar masivo.")
        editButton.tap()

        XCTAssertTrue(
            app.buttons["bulk_edit_option_note"].waitForExistence(timeout: 5),
            "No se montó BulkEditSheet (bulk_edit_option_note)."
        )
    }

    /// CRUD — editar masivamente la nota de 2 transacciones y verificar que el flujo
    /// completa (aplica el cambio y vuelve a la lista en modo normal).
    func test_bulkEditNoteCompletes() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        enterRecordsSelectionMode(app)

        // Seleccionar 2 transacciones (el seed minimal produce varias).
        let rows = app.buttons.matching(identifier: "record_row")
        XCTAssertTrue(rows.element(boundBy: 0).waitForExistence(timeout: 5), "No hay filas de transacción para seleccionar.")
        XCTAssertGreaterThanOrEqual(rows.count, 2, "El seed no produjo ≥2 transacciones para edición masiva.")
        rows.element(boundBy: 0).tap()
        rows.element(boundBy: 1).tap()

        // Abrir editar masivo → opción Nota.
        app.buttons["bulk_edit_button"].tap()
        let noteOption = app.buttons["bulk_edit_option_note"]
        XCTAssertTrue(noteOption.waitForExistence(timeout: 5), "No se montó BulkEditSheet (bulk_edit_option_note).")
        noteOption.tap()

        // Editor de nota: escribir y guardar (el campo auto-enfoca).
        let noteField = app.textFields["bulk_note_field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 5), "No se montó BulkNoteEditorSheet (bulk_note_field).")
        noteField.tap()
        noteField.typeText("QA Nota Masiva")

        let saveNote = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveNote.waitForExistence(timeout: 5), "No apareció toolbar_save_button en el editor de nota.")
        saveNote.tap()

        // De vuelta en BulkEditSheet: el cambio aplicado habilita "Done"; cerrar con él.
        let done = app.buttons["bulk_edit_done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "No apareció bulk_edit_done tras aplicar la nota (el cambio no se registró).")
        done.tap()

        // El flujo completó: vuelve a la lista en modo normal (botón de selección disponible).
        XCTAssertTrue(
            app.buttons["records_select_button"].waitForExistence(timeout: 5),
            "Tras la edición masiva no se volvió a la lista en modo normal."
        )
    }
}
