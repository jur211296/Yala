//
//  PanelHeroVocabularyUITests.swift
//  YalaUITests
//
//  Decisión 8 de la revisión 2.3 (opción C): la cifra grande del Panel es lo que hay en las cuentas («Tienes hoy») y
//  no sigue a las píldoras ni al período; lo que mueven es la línea del mes de debajo («Te queda» → «Gastos de
//  noviembre»). Antes la cifra grande era el «Balance de noviembre» y la píldora de gastos la cambiaba por el gasto.
//  Seed `minimal`.
//

import XCTest

final class PanelHeroVocabularyUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_expensePill_movesTheMonthLine_andNotTheBigFigure() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let figure = app.descendants(matching: .any)["panel_hero_figure"].firstMatch
        let monthLine = app.descendants(matching: .any)["panel_hero_month_line"].firstMatch
        let expensePill = app.buttons["panel_hero_expense_pill"]
        XCTAssertTrue(figure.waitForExistence(timeout: 15), "No aparece la cifra grande del hero.")
        XCTAssertTrue(monthLine.waitForExistence(timeout: 5), "No aparece la línea del mes bajo la cifra grande.")
        XCTAssertTrue(expensePill.waitForExistence(timeout: 5), "No aparece la píldora de gastos.")

        let figureBefore = figure.label
        let lineBefore = monthLine.label
        XCTAssertFalse(figureBefore.isEmpty, "La cifra grande no tiene importe.")

        expensePill.tap()
        XCTAssertTrue(app.buttons["panel_hero_nature_chip"].waitForExistence(timeout: 5), "La píldora no filtró.")

        // La línea cambia de rótulo y de importe…
        let lineChanged = NSPredicate(format: "label != %@", lineBefore)
        let changed = expectation(for: lineChanged, evaluatedWith: monthLine)
        XCTAssertEqual(XCTWaiter().wait(for: [changed], timeout: 5), .completed,
                       "La línea del mes no siguió a la píldora (sigue «\(lineBefore)»).")
        // …y la cifra grande no: es lo que hay en las cuentas.
        XCTAssertEqual(figure.label, figureBefore,
                       "La píldora cambió la cifra grande: «Tienes hoy» no debe seguir al filtro de gastos.")
    }
}
