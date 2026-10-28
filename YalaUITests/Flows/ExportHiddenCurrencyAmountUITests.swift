//
//  ExportHiddenCurrencyAmountUITests.swift
//  YalaUITests
//
//  Ticket `export-wizard-amount-filter-in-hidden-currency` (2026-10-28): en el modo «Ocultar» de Exportar lo marcado es lo
//  que DESAPARECE, y el campo del monto dice la moneda que queda a la vista. Seed `minimal`: «Cuenta Principal» en PEN y
//  «Ahorros USD». Desmarcar «Ahorros USD» deja oculta la cuenta en PEN (y su moneda) y a la vista solo USD. Antes del
//  arreglo el monto no se ofrecía («Selecciona una única moneda») o se etiquetaba con la moneda oculta; la primera versión
//  del arreglo miraba las monedas de las cuentas OCULTAS y tampoco lo ofrecía aquí (lo cazó la review).
//

import XCTest

final class ExportHiddenCurrencyAmountUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_hideMode_amountIsInTheCurrencyLeftInView() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        let exportRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Exportar registros")).firstMatch
        XCTAssertTrue(exportRow.waitForExistence(timeout: 10), "No apareció la fila Exportar registros en el Perfil.")
        var swipes = 0
        while !exportRow.isHittable && swipes < 14 { app.swipeUp(); swipes += 1 }
        exportRow.tap()

        let more = app.buttons["export_more_options"]
        XCTAssertTrue(more.waitForExistence(timeout: 10), "Falta «Más opciones».")
        more.tap()
        let picker = app.segmentedControls["export_mode_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Falta el selector Mostrar solo / Ocultar.")
        picker.buttons.element(boundBy: 1).tap()

        // Arranca con todo marcado (todo oculto). Desmarcar «Ahorros USD» la deja a la vista: queda solo USD.
        let savings = app.buttons["export_account_chip_Ahorros USD"]
        swipes = 0
        while !(savings.exists && savings.isHittable) && swipes < 8 { app.swipeUp(); swipes += 1 }
        XCTAssertTrue(savings.isHittable, "No se llega al chip de «Ahorros USD».")
        savings.tap()
        XCTAssertTrue(waitForLabel(app.descendants(matching: .any)["export_count_line"], containing: "Saldrán"),
                      "Con «Ahorros USD» a la vista tiene que salir algo: el escenario no es el del ticket.")

        var condition: XCUIElement?
        swipes = 0
        while condition == nil && swipes < 10 {
            condition = app.segmentedControls.allElementsBoundByIndex.first { $0.buttons.count == 4 && $0.isHittable }
            if condition == nil { app.swipeUp(velocity: .slow); swipes += 1 }
        }
        XCTAssertNotNil(condition, "Con PEN oculto queda USD a la vista: el monto tiene que poder usarse.")
        condition?.buttons.element(boundBy: 1).tap()
        let currency = app.staticTexts["filters_amount_currency"]
        XCTAssertTrue(currency.waitForExistence(timeout: 5), "El campo del monto no dice en qué moneda compara.")
        XCTAssertEqual(currency.label, "USD", "Con PEN oculto, el monto compara en \(currency.label).")
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
