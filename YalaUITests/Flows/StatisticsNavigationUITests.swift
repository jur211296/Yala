//
//  StatisticsNavigationUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `statistics` (escenarios 10.1-10.6): navegación
//  entre las 4 tabs de Estadísticas (Insights, Tendencias, Categorías, Registros)
//  vía los chips de DetailContainerView. Verifica que cada tab monta su contenido
//  (accessibilityIdentifier `stats_tab_<x>` en cada TabView del switch). Reusa la
//  navegación por tab (boundBy:1) y los chips `detail_chip_*`. Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class StatisticsNavigationUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Busca un elemento por identifier sin acoplar al tipo (los TabView se
    /// resuelven a ScrollView; el ID vive en el contenedor de cada tab).
    private func tabContainer(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Smoke: el 2º tab abre Estadísticas con la tab Insights (default) montada.
    func test_opensStatisticsInsightsTab() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.tabBars.buttons.element(boundBy: 1).tap()

        XCTAssertTrue(
            tabContainer(app, "stats_tab_insights").waitForExistence(timeout: 10),
            "La tab Insights de Estadísticas no montó."
        )
    }

    /// Navegación — recorre las 4 tabs de Estadísticas vía sus chips y verifica que
    /// cada una monta su contenido.
    func test_navigatesAllStatisticsTabs() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(tabContainer(app, "stats_tab_insights").waitForExistence(timeout: 10), "La tab Insights no montó.")

        app.buttons["detail_chip_tendencias"].tap()
        XCTAssertTrue(tabContainer(app, "stats_tab_trends").waitForExistence(timeout: 5), "La tab Tendencias no montó.")

        app.buttons["detail_chip_categorías"].tap()
        XCTAssertTrue(tabContainer(app, "stats_tab_categories").waitForExistence(timeout: 5), "La tab Categorías no montó.")

        // El chip Registros (último) puede quedar fuera de vista en el ScrollView
        // horizontal de chips → revelar con swipe sobre el contenedor.
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists {
            chipsBar.swipeLeft()
        }
        app.buttons["detail_chip_registros"].tap()
        XCTAssertTrue(tabContainer(app, "stats_tab_records").waitForExistence(timeout: 5), "La tab Registros no montó.")
    }
}
