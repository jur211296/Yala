//
//  PanelHeroLargeTextUITests.swift
//  YalaUITests
//
//  Pase de estrés 2.2 (card eb9i): con el texto al máximo, la cifra del saldo del Panel es lo mayor del hero. Antes la
//  cifra se quedaba en 36 pt fijos y los chips de entradas y salidas, que crecen con el texto, medían casi el doble.
//  El arreglo copia el molde de Grupos: la cifra crece hasta 60 pt con texto de accesibilidad y el rótulo y los chips
//  dejan de crecer en AX2 (`HeroMonthView.figureFont`).
//
//  Seed `realista` (cifras de seis dígitos, las que se invertían) y scheme Yala Dev.
//

import XCTest

final class PanelHeroLargeTextUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_accessibilityXXXL_balanceFigureIsTallerThanTheChips() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let figure = app.descendants(matching: .any)["panel_hero_figure"].firstMatch
        let income = app.buttons["panel_hero_income_pill"].firstMatch
        let expense = app.buttons["panel_hero_expense_pill"].firstMatch
        XCTAssertTrue(figure.waitForExistence(timeout: 15), "No aparece la cifra del hero del Panel (panel_hero_figure).")
        XCTAssertTrue(income.waitForExistence(timeout: 5) && expense.exists, "No aparecen los chips de entradas y salidas.")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "panel-hero-ax5"
        shot.lifetime = .keepAlways
        add(shot)

        // El chip lleva su cápsula (4 pt arriba y abajo): aun así, la cifra tiene que ser más alta que cualquiera.
        XCTAssertGreaterThan(figure.frame.height, income.frame.height,
                             "Con AX5 la cifra del saldo (\(figure.frame.height) pt) no es mayor que el chip de entradas (\(income.frame.height) pt).")
        XCTAssertGreaterThan(figure.frame.height, expense.frame.height,
                             "Con AX5 la cifra del saldo (\(figure.frame.height) pt) no es mayor que el chip de salidas (\(expense.frame.height) pt).")
    }
}
