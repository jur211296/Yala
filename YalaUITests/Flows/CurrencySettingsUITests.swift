//
//  CurrencySettingsUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `settings-currency-exchange` (escenarios 13.2, 13.3,
//  13.3.1, 13.3.2): navegación a Divisa y cambio + agregar una divisa secundaria
//  (acción aislada que NO recalcula transacciones, a diferencia de cambiar la
//  divisa preferida). Verifica que la divisa agregada aparece en el display de
//  secundarias. Reusa openProfile/openSettingsSection. Seed `minimal`.
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

        // EUR está en la sección "Recomendadas" del picker (visible sin scroll).
        let eurRow = app.buttons.matching(identifier: "secondary_currency_row_EUR").firstMatch
        XCTAssertTrue(eurRow.waitForExistence(timeout: 5), "No se montó SecondaryCurrencyPickerSheet (secondary_currency_row_EUR).")
        eurRow.tap()

        // Cerrar el picker (la selección ya se aplicó al togglear).
        app.buttons["secondary_currency_done"].tap()

        // El picker se DESMONTA: `secondaryButton` es del fondo y sigue en el árbol
        // mientras el sheet esté puesto, así que afirmar su existencia no probaría el
        // regreso (medido 2026-08-04). La señal es que el picker desapareció.
        XCTAssertTrue(
            app.buttons["secondary_currency_done"].waitForNonExistence(timeout: 5),
            "El picker de divisa secundaria no se cerró tras «Listo»."
        )

        // El display de divisas secundarias debe reflejar EUR.
        XCTAssertTrue(secondaryButton.waitForExistence(timeout: 5), "No volvió a CurrencySettingsView.")
        let showsEUR = secondaryButton.label.contains("EUR") || secondaryButton.staticTexts["EUR"].exists
        XCTAssertTrue(showsEUR, "El display de divisas secundarias no refleja EUR tras agregarlo.")
    }
}
