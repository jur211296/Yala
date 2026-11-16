//
//  Estadisticas23ComparacionVoiceOverUITests.swift
//  YalaUITests
//
//  Decisiones 29 y 26 de la revisión 2.3 (9-nov), en Estadísticas › Tendencias:
//  - 29 (A): Tendencias lleva el mismo selector de comparación que Resumen y Distribución, que dice contra qué compara.
//    Antes no tenía ninguno y la comparación cambiaba sin avisar cuando se elegía en otra pestaña.
//  - 26 (V1): VoiceOver lee cada gráfica con su conclusión y sus cifras, no con un recuento («7 puntos»).
//  Se mide en el árbol de accesibilidad (la etiqueta y el valor que VoiceOver lee), no con VoiceOver encendido.
//  Seed `realista`, período «Este mes».
//

import XCTest

final class Estadisticas23ComparacionVoiceOverUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchOnTrends() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "realista", deeplinkURL: "yaladev://statistics/trends",
            extraArguments: ["-defaultPeriod", "thisMonth"]
        )
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let trends = app.buttons["detail_chip_tendencias"]
        XCTAssertTrue(trends.waitForExistence(timeout: 20), "No se abrió Estadísticas.")
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: trends)
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 15), .completed, "El enlace no abrió Tendencias.")
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func attach(_ name: String, _ app: XCUIApplication, tree: Bool = false) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        guard tree else { return }
        let dump = XCTAttachment(string: app.debugDescription)
        dump.name = "\(name)-arbol"
        dump.lifetime = .keepAlways
        add(dump)
    }

    /// Arrastres cortos hasta dejar el elemento en la franja central (un `swipeUp` lo deja bajo la barra de chips).
    private func bringToMiddle(_ target: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        var drags = 0
        while drags < 14,
              !(target.exists && target.frame.midY > window.height * 0.3 && target.frame.midY < window.height * 0.7) {
            let goingDown = !target.exists || target.frame.midY >= window.height * 0.7
            let from = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: goingDown ? 0.7 : 0.4))
            let to = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: goingDown ? 0.5 : 0.6))
            from.press(forDuration: 0.05, thenDragTo: to)
            drags += 1
        }
    }

    /// Lo que VoiceOver lee de una gráfica: etiqueta y valor. Tiene que traer cifras y no ser un recuento.
    private func assertSpeaksFigures(_ chart: XCUIElement, _ name: String) {
        let spoken = "\(chart.label) \(chart.value as? String ?? "")"
        XCTAssertNotNil(spoken.range(of: #"\d[\d.,]*\d|\d"#, options: .regularExpression),
                        "\(name): VoiceOver no lee ninguna cifra («\(spoken)»).")
        XCTAssertNil(spoken.range(of: #"^\s*\S.*?\b\d+ (puntos|data points|periodos|periods)\s*$"#, options: .regularExpression),
                     "\(name): VoiceOver sigue leyendo un recuento («\(spoken)»).")
        XCTAssertGreaterThan((chart.value as? String ?? "").count, 15,
                             "\(name): el valor no dice la conclusión («\(spoken)»).")
    }

    /// 29 · A: Tendencias enseña contra qué compara, y elegir el año pasado ahí cambia la frase.
    func test_trends_saysWhatItComparesWith_andLetsYouChange() {
        let app = launchOnTrends()
        let phrase = element(app, "comparison_phrase")
        let month = app.buttons["comparison_chip_month"]
        let year = app.buttons["comparison_chip_year"]

        let cardsReady = phrase.waitForExistence(timeout: 20)
        attach("tendencias-selector", app, tree: !cardsReady)
        XCTAssertTrue(cardsReady, "Tendencias no dice contra qué compara (sin «Comparado con…»).")
        bringToMiddle(year, in: app)
        XCTAssertTrue(month.exists && year.exists, "Faltan los chips de con qué comparar en Tendencias.")
        XCTAssertTrue(month.isSelected, "Por defecto se compara con el período anterior.")

        let monthPhrase = phrase.label
        year.tap()
        let picked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: year)
        XCTAssertEqual(XCTWaiter().wait(for: [picked], timeout: 5), .completed, "El chip del año pasado no quedó elegido.")
        XCTAssertNotEqual(phrase.label, monthPhrase, "La frase no cambió al elegir el año pasado.")
        attach("tendencias-selector-anio", app)
    }

    /// 26 · V1: la línea de tendencia, «Ver el mes anterior», entradas y salidas y el día de la semana dicen sus cifras.
    func test_trendsCharts_speakTheirConclusionWithFigures() {
        let app = launchOnTrends()

        let trend = element(app, "trend_chart")
        let found = trend.waitForExistence(timeout: 20)
        attach("tendencias-graficas", app, tree: true)
        XCTAssertTrue(found, "No se encontró la gráfica de tendencia (id `trend_chart`).")
        assertSpeaksFigures(trend, "Tendencia")

        let cashFlow = element(app, "cash_flow_chart")
        XCTAssertTrue(cashFlow.waitForExistence(timeout: 10), "No se encontró la gráfica de entradas y salidas.")
        assertSpeaksFigures(cashFlow, "Entradas y salidas")

        let weekday = element(app, "weekday_bar_chart")
        XCTAssertTrue(weekday.waitForExistence(timeout: 10), "No se encontró la gráfica del día de la semana.")
        assertSpeaksFigures(weekday, "Día de la semana")

        let toggle = app.buttons["trends_show_previous_toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Falta «Ver el mes anterior».")
        bringToMiddle(toggle, in: app)
        toggle.tap()
        let comparison = element(app, "trends_previous_period_chart")
        XCTAssertTrue(comparison.waitForExistence(timeout: 10), "«Ver el mes anterior» no enseñó la comparación.")
        attach("tendencias-mes-anterior", app, tree: true)
        assertSpeaksFigures(comparison, "Comparación")
    }
}
