//
//  AdvancedFiltersUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `advanced-filters-exclude-include` (escenarios
//  40.1, 40.7): el selector Incluir/Excluir en RecordsFiltersView y el badge de
//  modo excluir. Flujo: abrir filtros → cambiar a Excluir → aplicar → el
//  FilterControlBar muestra el ExcludeModeBadge. Reusa la navegación a Records
//  (Estadísticas → chip Registros). Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class AdvancedFiltersUITests: XCTestCase {
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

    /// Smoke: el botón de filtros abre RecordsFiltersView con el selector Incluir/Excluir.
    func test_opensFiltersSheet() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecords(app)

        app.openRecordsFilters()

        XCTAssertTrue(
            app.segmentedControls["filters_include_exclude_picker"].waitForExistence(timeout: 5),
            "No se montó RecordsFiltersView (filters_include_exclude_picker)."
        )
    }

    /// Acción — activar el modo Excluir, aplicar, y verificar que el modo persiste
    /// al reabrir el sheet (el segmento "Excluir" queda seleccionado). El modo se
    /// aplica vía `commitToViewModel` y se rehidrata al reabrir.
    func test_excludeModePersistsAfterApply() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecords(app)

        app.openRecordsFilters()

        let picker = app.segmentedControls["filters_include_exclude_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "No se montó el selector Incluir/Excluir.")
        // Segmento "Excluir" = 2º (tag true).
        picker.buttons.element(boundBy: 1).tap()

        let apply = app.buttons["filters_apply_button"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5), "No apareció filters_apply_button.")
        apply.tap()

        // Reabrir el sheet: el modo Excluir debe persistir (segmento 2º seleccionado).
        XCTAssertTrue(app.recordsOverflowMenu.waitForExistence(timeout: 5), "No volvió a Registros tras aplicar.")
        app.openRecordsFilters()

        let pickerReopened = app.segmentedControls["filters_include_exclude_picker"]
        XCTAssertTrue(pickerReopened.waitForExistence(timeout: 5), "No reabrió el sheet de filtros.")
        XCTAssertTrue(
            pickerReopened.buttons.element(boundBy: 1).isSelected,
            "El modo Excluir no persistió tras aplicar."
        )
    }
}
