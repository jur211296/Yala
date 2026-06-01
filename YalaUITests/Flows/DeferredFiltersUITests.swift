//
//  DeferredFiltersUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `deferred-filters-apply-discard` (escenarios 42.x):
//  el sheet de filtros aplica los cambios SOLO al tocar "Aplicar"
//  (commitToViewModel); cerrar con la X los descarta. 2 tests demuestran el par:
//  (a) descartar — escribir nota + X → al reabrir NO persiste; (b) aplicar —
//  escribir nota + Aplicar → al reabrir SÍ persiste. Reusa la navegación a Records
//  y los IDs de filtros. Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class DeferredFiltersUITests: XCTestCase {
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

    /// Descartar (X) NO aplica los cambios: la nota escrita no persiste al reabrir.
    func test_discardingFiltersDoesNotPersist() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecords(app)
        app.buttons["filters_toolbar_button"].tap()

        let noteField = app.textFields["filters_note_field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 5), "No apareció filters_note_field.")
        noteField.tap()
        noteField.typeText("QA descartar")

        // Cerrar con la X (descarta — no commitea al ViewModel).
        app.buttons["filters_close_button"].tap()

        // Reabrir: el campo de nota no debe conservar el texto descartado.
        let filtersButton = app.buttons["filters_toolbar_button"]
        XCTAssertTrue(filtersButton.waitForExistence(timeout: 5), "No volvió a Registros tras descartar.")
        filtersButton.tap()

        let reopened = app.textFields["filters_note_field"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 5), "No reabrió el sheet de filtros.")
        let value = reopened.value as? String ?? ""
        XCTAssertFalse(
            value.contains("QA"),
            "El filtro descartado no debería persistir; el campo tenía: \(value)"
        )
    }

    /// Aplicar SÍ commitea: la nota persiste al reabrir (contraste con descartar).
    func test_applyingFiltersPersists() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecords(app)
        app.buttons["filters_toolbar_button"].tap()

        let noteField = app.textFields["filters_note_field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 5), "No apareció filters_note_field.")
        noteField.tap()
        let query = "QA aplicar"
        noteField.typeText(query)

        app.buttons["filters_apply_button"].tap()

        let filtersButton = app.buttons["filters_toolbar_button"]
        XCTAssertTrue(filtersButton.waitForExistence(timeout: 5), "No volvió a Registros tras aplicar.")
        filtersButton.tap()

        let reopened = app.textFields["filters_note_field"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 5), "No reabrió el sheet de filtros.")
        XCTAssertEqual(reopened.value as? String, query, "El filtro aplicado no persistió.")
    }
}
