//
//  PanelHeroLargeTextUITests.swift
//  YalaUITests
//
//  Pase de estrés 2.2 (card eb9i): con el texto al máximo, la cifra del saldo del Panel es lo mayor del hero. Antes la
//  cifra se quedaba en 36 pt fijos y los chips de entradas y salidas, que crecen con el texto, medían casi el doble.
//  El arreglo copia el molde de Grupos: la cifra crece hasta 60 pt con texto de accesibilidad y el rótulo y el detalle
//  dejan de crecer en AX2 (`HeroMonthView.figureFont`). Desde el 2026-11-16 el detalle es «Tu dinero hoy» (los chips
//  salieron del hero), y la cifra tiene que seguir siendo más alta que esa línea.
//
//  Seed `tarjeta-dos-lineas` (con tarjeta, para que salga la línea chica) y scheme Yala Dev.
//

import XCTest

final class PanelHeroLargeTextUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_accessibilityXXXL_balanceFigureIsTallerThanTheMoneyLine() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "tarjeta-dos-lineas", extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let figure = app.descendants(matching: .any)["panel_hero_figure"].firstMatch
        let money = app.descendants(matching: .any)["panel_hero_money_line"].firstMatch
        XCTAssertTrue(figure.waitForExistence(timeout: 15), "No aparece la cifra del hero del Panel (panel_hero_figure).")
        XCTAssertTrue(money.waitForExistence(timeout: 5), "No aparece «Tu dinero hoy».")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "panel-hero-ax5"
        shot.lifetime = .keepAlways
        add(shot)

        XCTAssertGreaterThan(figure.frame.height, money.frame.height,
                             "Con AX5 la cifra del saldo (\(figure.frame.height) pt) no es mayor que «Tu dinero hoy» (\(money.frame.height) pt).")
    }
}
