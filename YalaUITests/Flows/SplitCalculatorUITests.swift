//
//  SplitCalculatorUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `split-calculator` (escenarios 52.x): la calculadora
//  que divide el monto de un gasto. Reusa el form de transacción (FAB → fab_manual).
//  2 tests: (a) abrir la calculadora con un gasto de 100, aplicar el preset 50%
//  (modo porcentaje, default) y verificar que calcula la porción (50) y habilita
//  el botón Usar; (b) aplicar la división y verificar el chip de split en el form.
//  La calculadora no usa Swift Charts → árbol de accesibilidad ligero. Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class SplitCalculatorUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Abre el form de gasto con monto 100, lanza la calculadora y aplica el preset
    /// 50% (modo porcentaje por defecto). Deja el sheet abierto con el resultado.
    private func openSplitWith50Percent(_ app: XCUIApplication) {
        app.buttons["fab_new_transaction"].tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()

        let amountField = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "No apareció new_transaction_amount.")
        amountField.tap()
        amountField.typeText("100")

        // Acción rápida "Dividir" (solo en gastos) → abre SplitCalculatorSheet con el
        // total prefilado (100).
        let splitAction = app.buttons["new_transaction_split_action"]
        XCTAssertTrue(splitAction.waitForExistence(timeout: 5), "No apareció la acción de dividir.")
        splitAction.tap()

        // Modo porcentaje (default) + preset 50%.
        let preset = app.buttons["split_calc_preset_50"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5), "No se montó SplitCalculatorSheet (preset 50%).")
        preset.tap()
    }

    /// La calculadora divide 100 al 50% → porción 50, y habilita el botón Usar.
    func test_splitCalculatorComputesPortion() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openSplitWith50Percent(app)

        let result = app.staticTexts["split_calc_result"]
        XCTAssertTrue(result.waitForExistence(timeout: 5), "No apareció el resultado del cálculo.")
        XCTAssertTrue(
            result.label.contains("50"),
            "Dividir 100 al 50% debería dar 50; el resultado fue: \(result.label)"
        )

        let useButton = app.buttons["split_calc_use_button"]
        XCTAssertTrue(useButton.waitForExistence(timeout: 5), "No apareció el botón Usar monto.")
        XCTAssertTrue(useButton.isEnabled, "El botón Usar monto debería habilitarse con un resultado válido.")
    }

    /// Aplicar la división cierra el sheet y muestra el chip de split en el form.
    func test_applyingSplitShowsChipInForm() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openSplitWith50Percent(app)

        let useButton = app.buttons["split_calc_use_button"]
        XCTAssertTrue(useButton.waitForExistence(timeout: 5), "No apareció el botón Usar monto.")
        useButton.tap()

        XCTAssertTrue(
            app.buttons["new_transaction_split_chip"].waitForExistence(timeout: 5),
            "Tras aplicar la división, el formulario no mostró el chip de split."
        )
    }
}
