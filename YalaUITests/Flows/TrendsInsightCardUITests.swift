//
//  TrendsInsightCardUITests.swift
//  YalaUITests
//
//  Trend Insight Card V2 (ticket trends-insight-card-v2-bullets): el resumen al
//  final de Tendencias es una lista de bullets, uno por gráfica visible.
//  Seed `realista` (cientos de movimientos repartidos en dos años: siempre hay
//  ≥ 5 en el período, gasto, ingreso y día pico).
//

import XCTest

final class TrendsInsightCardUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Entra por deeplink a Estadísticas: así vale para la barra de pestañas del iPhone y
    /// para la barra lateral del iPad.
    private func launch(pro: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: pro, seed: "realista", deeplink: "statistics")
        return app
    }

    private func openTrends(_ app: XCUIApplication) {
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let chip = app.buttons["detail_chip_tendencias"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "El chip Tendencias no apareció.")
        chip.tap()
        XCTAssertTrue(element(app, "stats_tab_trends").waitForExistence(timeout: 5), "La tab Tendencias no montó.")
    }

    /// V2-02: en «Todo el tiempo» no hay gráfica de Comparativa, así que tampoco su
    /// bullet; flujo de efectivo y día de la semana sí.
    func test_free_allTime_showsCashFlowAndWeekdayBullets_withoutComparison() {
        let app = launch()
        openTrends(app)

        XCTAssertTrue(element(app, "trends_insight_title").waitForExistence(timeout: 10), "La card de resumen no se montó.")
        XCTAssertTrue(element(app, "trends_insight_bullet_cashFlow").exists, "Falta el bullet del flujo de efectivo.")
        XCTAssertTrue(element(app, "trends_insight_bullet_weekday").exists, "Falta el bullet del día de la semana.")
        XCTAssertFalse(element(app, "trends_insight_bullet_comparison").exists,
                       "En «Todo el tiempo» no debería haber bullet de Comparativa.")
        XCTAssertTrue(app.buttons["Refinar con IA"].exists, "Free debería ver el CTA de upsell.")
    }

    /// V2-01: con un período comparable aparece el bullet de Comparativa, en su
    /// orden, y el gate de 5 movimientos se mide en Tendencias (sin pasar por Resumen
    /// después de cambiar el período).
    func test_free_lastMonth_addsTheComparisonBullet() {
        let app = launch()
        openTrends(app)

        let periodMenu = app.buttons["Todo el tiempo"].firstMatch
        XCTAssertTrue(periodMenu.waitForExistence(timeout: 5), "No apareció el selector de período.")
        periodMenu.tap()
        let lastMonth = app.buttons["Mes pasado"].firstMatch
        XCTAssertTrue(lastMonth.waitForExistence(timeout: 5), "No apareció «Mes pasado» en el menú.")
        lastMonth.tap()

        let comparison = element(app, "trends_insight_bullet_comparison")
        XCTAssertTrue(comparison.waitForExistence(timeout: 10), "Falta el bullet de Comparativa en «Mes pasado».")
        let cashFlow = element(app, "trends_insight_bullet_cashFlow")
        XCTAssertTrue(cashFlow.exists, "Falta el bullet del flujo de efectivo.")
        XCTAssertLessThan(comparison.frame.minY, cashFlow.frame.minY, "Los bullets deben seguir el orden de las gráficas.")
    }

    /// V2-04: Pro sin análisis generado ve los mismos bullets + el CTA de IA.
    func test_pro_beforeAI_showsRuleBullets_andGenerateCTA() {
        let app = launch(pro: true)
        openTrends(app)

        XCTAssertTrue(element(app, "trends_insight_title").waitForExistence(timeout: 10), "La card de resumen no se montó.")
        XCTAssertTrue(element(app, "trends_insight_bullet_weekday").exists, "Pro pre-IA debería ver los bullets de reglas.")
        XCTAssertTrue(element(app, "trends_insight_generate_ai").exists, "Falta el CTA «Generar análisis IA».")
    }
}
