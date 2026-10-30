//
//  ExportHiddenCurrencyAmountUITests.swift
//  YalaUITests
//
//  Ticket `export-wizard-amount-filter-in-hidden-currency` (2026-10-28): en el modo «Ocultar» de Exportar lo marcado es lo
//  que DESAPARECE, y el campo del monto dice la moneda que queda a la vista. Seed `minimal`: «Cuenta Principal» en PEN y
//  «Ahorros USD». Marcar «Cuenta Principal» la oculta (y su moneda) y deja a la vista solo USD. Antes del arreglo el monto
//  no se ofrecía («Selecciona una única moneda») o se etiquetaba con la moneda oculta; la primera versión del arreglo
//  miraba las monedas de las cuentas OCULTAS y tampoco lo ofrecía aquí (lo cazó la review).
//
//  Card k4iz (2026-10-30): al pasar a «Ocultar» se vacía lo marcado, así que sin tocar nada se exporta todo.
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

        openHideMode(app)

        // «Ocultar» arranca sin nada marcado (card k4iz). Marcar «Cuenta Principal» la oculta: queda solo USD.
        let principal = app.buttons["export_account_chip_Cuenta Principal"]
        var swipes = 0
        while !(principal.exists && principal.isHittable) && swipes < 8 { app.swipeUp(); swipes += 1 }
        XCTAssertTrue(principal.isHittable, "No se llega al chip de «Cuenta Principal».")
        principal.tap()
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

    /// Card k4iz: elegir «Ocultar» sin tocar nada más exporta todo, y el botón queda activo. Antes, «Ninguno con estos
    /// filtros»: lo que viene marcado se ocultaba.
    func test_hideMode_untouched_exportsEverything() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let countLine = app.descendants(matching: .any)["export_count_line"]
        openExport(app)
        XCTAssertTrue(waitForLabel(countLine, containing: "Saldrán"), "En «Mostrar solo» con todo marcado tiene que salir algo.")
        let before = countLine.label

        openHideMode(app, alreadyInExport: true)
        // La cifra se recuenta a los 150 ms del cambio: con lo marcado oculto pasaba a «Ninguno» enseguida. Se vigila
        // que no llegue a decirlo, y después que dice lo mismo que con todo a la vista.
        let saysNone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "Ninguno"), object: countLine)
        saysNone.isInverted = true
        XCTAssertEqual(XCTWaiter().wait(for: [saysNone], timeout: 3), .completed,
                       "«Ocultar» sin tocar nada no exporta nada: \(countLine.label)")
        XCTAssertEqual(countLine.label, before, "En «Ocultar» sin nada marcado tiene que salir lo mismo que con todo a la vista.")
        XCTAssertTrue(app.buttons["export_button"].isEnabled, "El botón de exportar sigue apagado.")
    }

    private func openExport(_ app: XCUIApplication) {
        app.openProfile()
        let exportRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Exportar registros")).firstMatch
        XCTAssertTrue(exportRow.waitForExistence(timeout: 10), "No apareció la fila Exportar registros en el Perfil.")
        var swipes = 0
        while !exportRow.isHittable && swipes < 14 { app.swipeUp(); swipes += 1 }
        exportRow.tap()
    }

    private func openHideMode(_ app: XCUIApplication, alreadyInExport: Bool = false) {
        if !alreadyInExport { openExport(app) }
        let more = app.buttons["export_more_options"]
        XCTAssertTrue(more.waitForExistence(timeout: 10), "Falta «Más opciones».")
        more.tap()
        let picker = app.segmentedControls["export_mode_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Falta el selector Mostrar solo / Ocultar.")
        picker.buttons.element(boundBy: 1).tap()
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
