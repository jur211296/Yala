//
//  AccountAnalysisUITests.swift
//  YalaUITests
//
//  La ficha de una cuenta con las gráficas de los widgets del Panel (2026-11-16, ticket `analisis-por-cuenta`). Seed
//  `tarjeta-corte`: «Visa QA» (PEN) con su línea en dólares; gastos de S/ 1,240 y S/ 386.50 en los últimos días.
//  Período «Últimos 30 días» para que los dos gastos entren cualquier día del mes.
//  - La ficha trae la curva del saldo (la de Tendencias) y «Tus gastos más grandes», con el más grande primero.
//  - Al cambiar a la línea en dólares, la curva sigue ahí.
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los nombres sembrados).
//

import XCTest

final class AccountAnalysisUITests: XCTestCase {

    private let card = "Visa QA"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openCard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "tarjeta-corte", extraArguments: ["-defaultPeriod", "last30Days"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "La app no llegó al Panel.")
        let first = app.buttons["panel_account_card_0"]
        if !first.waitForExistence(timeout: 3) {
            app.buttons["panel_panorama_header"].tap()
        }
        XCTAssertTrue(first.waitForExistence(timeout: 5), "No apareció la primera tarjeta.")
        let visa = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(card).")).firstMatch
        var swipes = 0
        while !visa.exists && swipes < 5 {
            first.swipeLeft()
            swipes += 1
        }
        XCTAssertTrue(visa.waitForExistence(timeout: 5), "No hay tarjeta de «\(card)».")
        visa.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["account_detail_sheet"].firstMatch.waitForExistence(timeout: 8),
            "No abrió la ficha."
        )
        return app
    }

    private func scrollUntilVisible(_ app: XCUIApplication, _ element: XCUIElement, swipes: Int = 8) {
        var count = 0
        while count < swipes && !(element.exists && app.windows.firstMatch.frame.contains(element.frame)) {
            app.swipeUp(velocity: .slow)
            count += 1
        }
    }

    /// La curva de Tendencias y los gastos más grandes, el de S/ 1,240 primero.
    func test_detail_showsTheTrendChart_andTheLargestExpenses() {
        let app = openCard()
        let trend = app.staticTexts["account_analysis_trend_title"]
        scrollUntilVisible(app, trend)
        XCTAssertTrue(trend.exists, "La ficha no trae la curva del saldo.")

        let largest = app.staticTexts["account_analysis_largest_title"]
        scrollUntilVisible(app, largest)
        XCTAssertTrue(largest.exists, "La ficha no trae «Tus gastos más grandes».")
        let supermarket = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Supermercado QA")).firstMatch
        let restaurant = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Restaurante QA")).firstMatch
        XCTAssertTrue(supermarket.exists, "Falta el gasto más grande.")
        XCTAssertTrue(restaurant.exists, "Falta el segundo gasto.")
        XCTAssertLessThan(
            supermarket.frame.minY, restaurant.frame.minY,
            "El gasto más grande (S/ 1,240) tiene que ir antes que el de S/ 386.50."
        )
    }

    /// La línea en dólares también tiene su curva.
    func test_usdLine_keepsTheTrendChart() {
        let app = openCard()
        let picker = app.descendants(matching: .any)["account_detail_line_picker"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "La tarjeta con dos divisas no trae el selector.")
        picker.buttons["USD"].tap()
        let trend = app.staticTexts["account_analysis_trend_title"]
        scrollUntilVisible(app, trend)
        XCTAssertTrue(trend.exists, "La línea en dólares no trae la curva del saldo.")
    }
}
