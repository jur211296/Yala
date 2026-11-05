//
//  StatisticsGuideScrollsAwayUITests.swift
//  YalaUITests
//
//  La guía de primera visita de Estadísticas («Yala analiza por ti», la de Distribución…) se va con el contenido al
//  desplazar, como la del Panel. Antes la montaba `DetailContainerView` encima de las páginas: se quedaba fija bajo los
//  chips y las tarjetas pasaban por debajo, cortadas (ticket
//  `statistics-summary-guide-banner-stays-pinned-over-the-cards`, lote P3 de 2.3).
//
//  Las guías se callan bajo `-uitest`; `-uitest-show-guides` las devuelve solo aquí. `-guide.<id>.dismissed NO` las deja
//  sin cerrar aunque el simulador traiga la marca de otra sesión.
//
//  Discrimina: con la guía fija, su marco no se mueve al desplazar (medido con el código de antes).
//

import XCTest

final class StatisticsGuideScrollsAwayUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, extraArguments: [
            "-uitest-show-guides",
            "-guide.insights.dismissed", "NO",
            "-guide.categories.dismissed", "NO",
        ])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Desplaza la página y comprueba que la guía subió con ella (o salió de la ventana).
    private func assertGuideScrollsAway(_ app: XCUIApplication, in place: String,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let close = app.buttons["contextual_guide_dismiss"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 15), "\(place): no se ve la guía.", file: file, line: line)
        let before = close.frame.minY

        let caption = app.staticTexts["stats_hero_caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 10), "\(place): no se ve el hero.", file: file, line: line)
        let heroBefore = caption.frame.minY
        // Arrastre por coordenadas en la mitad baja: un `swipeUp` sobre el hero no desplaza (el hero tiene su propio
        // gesto de período y se queda el arrastre; medido en el vídeo del `.xcresult`).
        let window = app.windows.firstMatch
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        RunLoop.current.run(until: Date().addingTimeInterval(1))

        // La guía tiene que moverse COMO el hero, que va dentro del scroll. Fija, solo baja lo que pliega el título
        // grande (52 pt medidos con el código de antes) mientras el hero sube cientos.
        let heroMoved = heroBefore - caption.frame.minY
        XCTAssertGreaterThan(heroMoved, 120, "\(place): el arrastre no desplazó la página.", file: file, line: line)
        let guideMoved = close.exists ? before - close.frame.minY : .infinity
        XCTAssertGreaterThan(
            guideMoved, heroMoved - 20,
            "\(place): la guía subió \(guideMoved) pt y el hero \(heroMoved): se quedó fija sobre las tarjetas.",
            file: file, line: line)
    }

    func test_guideScrollsWithTheContent_inSummaryAndDistribution() {
        let app = launch()
        app.selectTab(.statistics)
        assertGuideScrollsAway(app, in: "Resumen")

        let chip = app.buttons["detail_chip_categorías"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No apareció el chip de Distribución.")
        chip.tap()
        assertGuideScrollsAway(app, in: "Distribución")
    }
}
