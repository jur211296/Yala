//
//  CurrencySettingsUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `settings-currency-exchange` (escenarios 13.2, 13.3,
//  13.3.1, 13.3.2): navegación a Divisa y cambio + agregar una divisa secundaria
//  (acción aislada que NO recalcula transacciones, a diferencia de cambiar la
//  divisa preferida). El seed uitest restaura USD+EUR; el alta prueba GBP
//  (deselecciona USD para liberar el tope de 2). Reusa openProfile/openSettingsSection. Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class CurrencySettingsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navegación: Perfil → Divisa y cambio (CurrencySettingsView monta).
    func test_opensCurrencySettingsFromProfile() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_currency")

        XCTAssertTrue(
            app.buttons["currency_secondary_button"].waitForExistence(timeout: 5),
            "No se montó CurrencySettingsView (currency_secondary_button)."
        )
    }

    /// Acción — agregar EUR como divisa secundaria y verificar que aparece en el
    /// display. La selección se aplica al instante (onChange), sin red bloqueante.
    func test_addSecondaryCurrency() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_currency")

        let secondaryButton = app.buttons["currency_secondary_button"]
        XCTAssertTrue(secondaryButton.waitForExistence(timeout: 5), "No apareció currency_secondary_button.")
        secondaryButton.tap()

        // El seed uitest restaura USD+EUR (tope 2). EUR ya está seleccionada: tocarla
        // la QUITARÍA. Deseleccionamos USD (sección Selected) y agregamos GBP
        // (Recomendadas, visible sin scroll) para seguir probando el alta.
        let usdRow = app.buttons.matching(identifier: "secondary_currency_row_USD").firstMatch
        XCTAssertTrue(usdRow.waitForExistence(timeout: 5), "No se montó SecondaryCurrencyPickerSheet (secondary_currency_row_USD).")
        usdRow.tap()

        let gbpRow = app.buttons.matching(identifier: "secondary_currency_row_GBP").firstMatch
        XCTAssertTrue(gbpRow.waitForExistence(timeout: 5), "No apareció secondary_currency_row_GBP tras liberar un hueco.")
        gbpRow.tap()

        // Cerrar el picker (la selección ya se aplicó al togglear).
        app.buttons["secondary_currency_done"].tap()

        // El picker se DESMONTA: `secondaryButton` es del fondo y sigue en el árbol
        // mientras el sheet esté puesto, así que afirmar su existencia no probaría el
        // regreso (medido 2026-08-04). La señal es que el picker desapareció.
        XCTAssertTrue(
            app.buttons["secondary_currency_done"].waitForNonExistence(timeout: 5),
            "El picker de divisa secundaria no se cerró tras «Listo»."
        )

        // El display de divisas secundarias debe reflejar GBP.
        XCTAssertTrue(secondaryButton.waitForExistence(timeout: 5), "No volvió a CurrencySettingsView.")
        let showsGBP = secondaryButton.label.contains("GBP") || secondaryButton.staticTexts["GBP"].exists
        XCTAssertTrue(showsGBP, "El display de divisas secundarias no refleja GBP tras agregarlo.")
    }
}
