//
//  SmartRefinementFabUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `smart-refinement-fab-stats` (escenarios 21.4-21.6):
//  el FAB de refinamiento con IA (sparkles, "fab_chat"). Hasta el 2026-10-03 aparecía SOLO
//  en la tab Registros de Estadísticas; desde la decisión de alinear Estadísticas con el Panel
//  (ticket `distribution-subviews-miss-the-new-panel-hero`) va en las cuatro pestañas, así que
//  el segundo caso afirma ahora que está también fuera de Registros. NO lo toca, porque abrir
//  el chat dispara red/LLM o el flujo de consentimiento (no determinista). Lanza en Pro para
//  evitar el estado bloqueado. Seed `minimal`. El recorrido entero —las cuatro pestañas y las
//  subvistas de Distribución— vive en `StatisticsHeroLikePanelUITests`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class SmartRefinementFabUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navega a Estadísticas → chip Registros (revelando el chip si queda fuera de vista).
    private func openStatsRecords(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 1).tap()
        let recordsChip = app.buttons["detail_chip_registros"]
        XCTAssertTrue(recordsChip.waitForExistence(timeout: 10), "No apareció el chip Registros.")
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists {
            chipsBar.swipeLeft()
        }
        recordsChip.tap()
    }

    /// El FAB de refinamiento IA aparece en la tab Registros de Estadísticas.
    func test_smartRefinementFabVisibleInRecords() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openStatsRecords(app)

        XCTAssertTrue(
            app.buttons["fab_chat"].waitForExistence(timeout: 5),
            "El FAB de refinamiento IA no apareció en la tab Registros."
        )
    }

    /// Desde el 2026-10-03 el FAB no es exclusivo de Registros: también está en Insights (la tab por defecto), y
    /// sigue al volver a Registros.
    func test_smartRefinementFabAlsoOutsideRecords() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "stats_tab_insights").firstMatch.waitForExistence(timeout: 10),
            "La tab Insights no montó."
        )
        XCTAssertTrue(
            app.buttons["fab_chat"].waitForExistence(timeout: 5),
            "El FAB de Yala IA tiene que estar también en Insights, como en el Panel."
        )

        openStatsRecords(app)
        XCTAssertTrue(
            app.buttons["fab_chat"].waitForExistence(timeout: 5),
            "El FAB de refinamiento no apareció al cambiar a Registros."
        )
    }
}
