//
//  CurrencyPickerUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `currency-picker-onboarding-and-secondary` (25.5):
//  la lógica del SecondaryCurrencyPickerSheet — muestra divisas recomendadas
//  (25.5.1) y EXCLUYE la divisa preferida (25.5.2, PEN en el seed). Ángulo distinto
//  al área `settings-currency-exchange` (que cubre el FLUJO de agregar una secundaria).
//  El escenario 25.2 (picker en el onboarding) se ejercita vía el área onboarding-flow.
//  Reusa openProfile/openSettingsSection. Seed `minimal` (preferida = PEN).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class CurrencyPickerUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openSecondaryPicker(_ app: XCUIApplication) {
        app.openProfile()
        app.openSettingsSection("profile_currency")
        let secondaryButton = app.buttons["currency_secondary_button"]
        XCTAssertTrue(secondaryButton.waitForExistence(timeout: 5), "No apareció currency_secondary_button.")
        secondaryButton.tap()
    }

    /// 25.5.1: el picker monta y ofrece divisas disponibles (recomendadas/continentes).
    func test_secondaryPickerShowsOptions() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openSecondaryPicker(app)

        XCTAssertTrue(
            app.buttons["secondary_currency_row_USD"].waitForExistence(timeout: 5),
            "El picker de divisa secundaria no ofrece USD (recomendada/disponible)."
        )
    }

    /// 25.5.2: el picker EXCLUYE la divisa preferida (PEN en el seed) — no se puede
    /// agregar la preferida como secundaria.
    func test_secondaryPickerExcludesPreferredCurrency() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openSecondaryPicker(app)

        // Esperar a que el picker monte (una fila cualquiera) antes de comprobar ausencia.
        XCTAssertTrue(
            app.buttons["secondary_currency_row_USD"].waitForExistence(timeout: 5),
            "El picker no montó (secondary_currency_row_USD ausente)."
        )
        XCTAssertFalse(
            app.buttons["secondary_currency_row_PEN"].exists,
            "El picker no debería ofrecer la divisa preferida (PEN) como secundaria."
        )
    }
}
