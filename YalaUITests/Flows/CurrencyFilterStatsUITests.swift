//
//  CurrencyFilterStatsUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `currency-filter-statistics` (escenarios 25.3.x):
//  el filtro por moneda en el sheet de filtros (sección de monedas, visible cuando
//  hay transacciones en ≥1 divisa). El seed tiene cuentas PEN + USD → la sección
//  aparece. 2 tests: (a) la sección de monedas ofrece el chip USD; (b) seleccionar
//  USD + Aplicar persiste al reabrir (el chip queda con el trait .isSelected).
//  Reusa la navegación a Records y los IDs de filtros. Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class CurrencyFilterStatsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navega a Estadísticas → chip Registros y abre el sheet de filtros.
    private func openFilters(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 1).tap()
        let recordsChip = app.buttons["detail_chip_registros"]
        XCTAssertTrue(recordsChip.waitForExistence(timeout: 10), "No apareció el chip Registros.")
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists {
            chipsBar.swipeLeft()
        }
        recordsChip.tap()
        app.buttons["filters_toolbar_button"].tap()
    }

    /// Smoke: el sheet de filtros ofrece el chip de moneda USD (multi-moneda en el seed).
    func test_currencyFilterSectionOffersCurrencyChip() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openFilters(app)

        XCTAssertTrue(
            app.buttons["filters_currency_chip_USD"].waitForExistence(timeout: 5),
            "El sheet de filtros no ofreció el chip de moneda USD."
        )
    }

    /// Seleccionar la moneda USD y aplicar: la selección persiste al reabrir.
    func test_currencyFilterPersistsAfterApply() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openFilters(app)

        let usdChip = app.buttons["filters_currency_chip_USD"]
        XCTAssertTrue(usdChip.waitForExistence(timeout: 5), "No apareció el chip de moneda USD.")
        usdChip.tap()

        app.buttons["filters_apply_button"].tap()

        // Reabrir filtros: el chip USD debe seguir seleccionado (.isSelected).
        let filtersButton = app.buttons["filters_toolbar_button"]
        XCTAssertTrue(filtersButton.waitForExistence(timeout: 5), "No volvió a Registros tras aplicar.")
        filtersButton.tap()

        let usdReopened = app.buttons["filters_currency_chip_USD"]
        XCTAssertTrue(usdReopened.waitForExistence(timeout: 5), "No reabrió el sheet de filtros.")
        XCTAssertTrue(usdReopened.isSelected, "El filtro de moneda USD no persistió tras aplicar.")
    }
}
