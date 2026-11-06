//
//  ProjectedFlowUITests.swift
//  YalaUITests
//
//  «Ver proyectado» (card «Flujo proyectado en Tendencias y Panel», 2026-11-06): la píldora sale solo con días del
//  período por delante (3A), enseña la línea punteada con la cifra al cierre, es excluyente con «Ver el mes
//  anterior» (8A) y es la misma preferencia en Tendencias y el Panel (9A).
//
//  El período se fija con `-defaultPeriod`: «Este año» tiene días por delante todo el año salvo el 31 de diciembre, y
//  «Este mes» no los tiene el último día de cada mes (esos casos se saltan diciéndolo).
//

import XCTest

final class ProjectedFlowUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launch(deeplink: String, period: String = "thisYear", reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(reset: reset, seed: "realista", deeplink: deeplink, extraArguments: ["-defaultPeriod", period])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Deja la píldora apagada. `-uitest-reset` borra la clave del disco, pero `AppPreferences` ya la leyó al arrancar:
    /// una corrida anterior que la dejó encendida la trae encendida. (Fijarla con `-showsProjectedFlow NO` no sirve:
    /// el dominio de argumentos gana también después de tocarla, y la píldora no se enciende nunca.)
    private func turnOffIfOn(_ app: XCUIApplication, toggle: XCUIElement) {
        if element(app, "trend_projected_caption").waitForExistence(timeout: 2) {
            toggle.tap()
            XCTAssertTrue(element(app, "trend_projected_caption").waitForNonExistence(timeout: 5),
                          "«Ver proyectado» no se apaga al tocarla encendida.")
        }
    }

    private func openTrends(_ app: XCUIApplication) {
        let chip = app.buttons["detail_chip_tendencias"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "El chip Tendencias no apareció.")
        chip.tap()
    }

    /// Baja con arrastres cortos hasta que el elemento está en pantalla.
    @discardableResult
    private func scrollTo(_ app: XCUIApplication, _ target: XCUIElement, swipes: Int = 14) -> Bool {
        for _ in 0..<swipes {
            if target.exists, target.isHittable { return true }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
        return target.exists && target.isHittable
    }

    /// En «Este mes», que es donde convive con «Ver el mes anterior» («Este año» no tiene comparación).
    func test_trends_projectionToggle_showsTheClosingFigure_andExcludesThePreviousPeriod() throws {
        let calendar = Calendar.current
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now),
           calendar.component(.month, from: tomorrow) != calendar.component(.month, from: .now) {
            throw XCTSkip("El último día del mes «Este mes» no tiene días por delante.")
        }
        let app = launch(deeplink: "statistics", period: "thisMonth")
        openTrends(app)

        let toggle = element(app, "trend_projected_toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 15), "Falta «Ver proyectado» con días por delante.")
        turnOffIfOn(app, toggle: toggle)
        XCTAssertFalse(element(app, "trend_projected_caption").exists, "La cifra al cierre sale sin pedirla.")

        toggle.tap()
        XCTAssertTrue(element(app, "trend_projected_caption").waitForExistence(timeout: 5),
                      "«Ver proyectado» no enseña la cifra al cierre.")
        XCTAssertTrue(toggle.isSelected, "La píldora encendida no se marca como elegida.")

        let previous = element(app, "trends_show_previous_toggle")
        XCTAssertTrue(previous.waitForExistence(timeout: 5), "Falta «Ver el mes anterior».")
        previous.tap()
        XCTAssertTrue(element(app, "trends_previous_period_chart").waitForExistence(timeout: 5),
                      "«Ver el mes anterior» no superpone la curva anterior.")
        XCTAssertTrue(element(app, "trend_projected_caption").waitForNonExistence(timeout: 5),
                      "Con el mes anterior a la vista, la proyección sigue: tienen que ser excluyentes (8A).")

        toggle.tap()
        XCTAssertTrue(element(app, "trend_projected_caption").waitForExistence(timeout: 5),
                      "Volver a «Ver proyectado» no la enseña.")
        XCTAssertTrue(element(app, "trends_previous_period_chart").waitForNonExistence(timeout: 5),
                      "Encender la proyección no apaga la curva del mes anterior (8A).")
    }

    /// Un período que acaba hoy o antes no tiene nada que proyectar: sin píldora (3A).
    func test_trends_closedPeriod_hasNoProjectionToggle() {
        let app = launch(deeplink: "statistics", period: "lastMonth")
        openTrends(app)
        XCTAssertTrue(element(app, "trends_show_previous_toggle").waitForExistence(timeout: 15),
                      "La tarjeta de tendencia no cargó.")
        XCTAssertFalse(element(app, "trend_projected_toggle").exists, "«Ver proyectado» sale en un mes cerrado.")
    }

    /// La preferencia es una para las dos pantallas (9A): encendida en el Panel, Tendencias ya la enseña.
    func test_panel_projectionToggle_isSharedWithTrends() throws {
        if Calendar.current.component(.month, from: .now) == 12, Calendar.current.component(.day, from: .now) == 31 {
            throw XCTSkip("El 31 de diciembre «Este año» no tiene días por delante.")
        }
        let app = launch(deeplink: "panel")
        let toggle = element(app, "trend_projected_toggle")
        XCTAssertTrue(scrollTo(app, toggle), "Falta «Ver proyectado» en el widget de tendencia del Panel.")
        turnOffIfOn(app, toggle: toggle)
        toggle.tap()
        XCTAssertTrue(element(app, "trend_projected_caption").waitForExistence(timeout: 5),
                      "En el Panel, «Ver proyectado» no enseña la cifra al cierre.")

        // Sin `-uitest-reset`, que borra las preferencias: lo que se mide es que la preferencia sigue puesta.
        app.terminate()
        let again = launch(deeplink: "statistics", reset: false)
        openTrends(again)
        XCTAssertTrue(element(again, "trend_projected_caption").waitForExistence(timeout: 15),
                      "Tendencias no recuerda «Ver proyectado» encendido desde el Panel.")
    }
}
