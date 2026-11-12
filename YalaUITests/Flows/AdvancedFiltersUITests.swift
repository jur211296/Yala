//
//  AdvancedFiltersUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `advanced-filters-exclude-include` (escenarios
//  40.1, 40.7): el selector «Mostrar solo / Ocultar» de RecordsFiltersView. Desde el
//  2026-10-25 las dos pestañas se combinan (opción B): lo oculto persiste al aplicar
//  y la hoja reabre en «Ocultar» si es lo único que hay. Reusa la navegación a
//  Records (Estadísticas → chip Registros). Seed `minimal`.
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

    /// Acción — ocultar una moneda, aplicar y reabrir: lo oculto persiste y la hoja vuelve en «Ocultar», que es donde
    /// está lo único elegido. Ya no hay «modo» que persistir: cambiar de pestaña sin marcar nada no filtra nada.
    func test_hiddenValuePersistsAfterApply() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openRecords(app)

        app.openRecordsFilters()

        let picker = app.segmentedControls["filters_include_exclude_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "No se montó el selector Mostrar solo / Ocultar.")
        // Segmento «Ocultar» = 2º.
        picker.buttons.element(boundBy: 1).tap()
        let usdChip = app.buttons["filters_currency_chip_USD"]
        XCTAssertTrue(usdChip.waitForExistence(timeout: 5), "No apareció el chip de moneda USD.")
        usdChip.tap()

        let apply = app.buttons["filters_apply_button"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5), "No apareció filters_apply_button.")
        apply.tap()

        XCTAssertTrue(app.recordsOverflowMenu.waitForExistence(timeout: 5), "No volvió a Registros tras aplicar.")
        app.openRecordsFilters()

        let pickerReopened = app.segmentedControls["filters_include_exclude_picker"]
        XCTAssertTrue(pickerReopened.waitForExistence(timeout: 5), "No reabrió el sheet de filtros.")
        XCTAssertTrue(
            pickerReopened.buttons.element(boundBy: 1).isSelected,
            "Con solo USD oculto, la hoja no reabrió en «Ocultar»."
        )
        XCTAssertTrue(app.buttons["filters_currency_chip_USD"].isSelected, "USD no siguió oculto tras aplicar.")
    }
}
