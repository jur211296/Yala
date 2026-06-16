//
//  FiltersUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `filters` (escenarios 11.1-11.6): el sheet de
//  filtros de Registros y la aplicación de un filtro de texto (nota). Flujo:
//  abrir filtros → escribir nota → aplicar → reabrir → el texto persiste.
//  Reusa la navegación a Records, el menú (···) (`openRecordsFilters`) y `filters_apply_button`.
//  Seed `minimal`. Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class FiltersUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navega a Estadísticas → chip Registros (revelando el chip si queda fuera de vista).
    private func openRecords(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 1).tap()
        let recordsChip = app.buttons["detail_chip_registros"]
        XCTAssertTrue(recordsChip.waitForExistence(timeout: 10), "No apareció el chip Registros.")
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists {
            chipsBar.swipeLeft()
        }
        recordsChip.tap()
    }

    /// Smoke: el botón de filtros abre el sheet con el campo de búsqueda por nota.
    func test_opensFiltersWithNoteField() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecords(app)
        app.openRecordsFilters()

        XCTAssertTrue(
            app.textFields["filters_note_field"].waitForExistence(timeout: 5),
            "No se montó RecordsFiltersView (filters_note_field)."
        )
    }

    /// Acción — aplicar un filtro de texto (nota) y verificar que persiste al reabrir.
    func test_noteFilterPersistsAfterApply() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecords(app)
        app.openRecordsFilters()

        let noteField = app.textFields["filters_note_field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 5), "No apareció filters_note_field.")
        noteField.tap()
        let query = "QA"
        noteField.typeText(query)

        app.buttons["filters_apply_button"].tap()

        // Reabrir filtros: el texto del filtro de nota debe persistir.
        XCTAssertTrue(app.recordsOverflowMenu.waitForExistence(timeout: 5), "No volvió a Registros tras aplicar.")
        app.openRecordsFilters()

        let noteFieldReopened = app.textFields["filters_note_field"]
        XCTAssertTrue(noteFieldReopened.waitForExistence(timeout: 5), "No reabrió el sheet de filtros.")
        XCTAssertEqual(noteFieldReopened.value as? String, query, "El filtro de nota no persistió tras aplicar.")
    }
}
