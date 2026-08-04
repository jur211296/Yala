//
//  SecondaryCurrencyPromptUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `secondary-currency-and-notification-primer`
//  (escenario 46.1): al guardar una cuenta cuya divisa difiere de la preferida, la
//  app sugiere agregarla como divisa secundaria (alert). El seed trae una cuenta en
//  USD ("Ahorros USD") y otra en PEN (preferida, "Cuenta Principal"). 2 tests editan
//  cada una y guardan: (a) la USD dispara el prompt; (b) la PEN no (control). Editar
//  evita el selector de divisa (un NavigationLink que XCUITest no activa de forma
//  fiable). Seed `minimal`.
//  NOTA: el escenario 46.2 (notification permission primer) dispara el prompt nativo
//  del sistema — no determinista — y queda fuera del XCUITest.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class SecondaryCurrencyPromptUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Abre el editor de una cuenta del seed (por nombre) desde Perfil → Cuentas.
    private func editAccount(_ app: XCUIApplication, named name: String) {
        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let row = app.buttons["accounts_row_\(name)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció la cuenta '\(name)' del seed.")
        row.tap()
        XCTAssertTrue(
            app.buttons["toolbar_save_button"].waitForExistence(timeout: 5),
            "No se montó el editor de cuenta."
        )
    }

    /// Editar la cuenta en USD (≠ PEN preferida) y guardar → sugiere divisa secundaria.
    func test_secondaryCurrencyPromptAppearsForNonPreferred() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        editAccount(app, named: "Ahorros USD")
        app.buttons["toolbar_save_button"].tap()

        XCTAssertTrue(
            app.alerts.firstMatch.waitForExistence(timeout: 5),
            "No apareció el prompt para agregar la divisa USD como secundaria."
        )
    }

    /// Editar la cuenta en la divisa preferida (PEN) y guardar → sin prompt, cierra el editor.
    func test_noSecondaryCurrencyPromptForPreferred() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        editAccount(app, named: "Cuenta Principal")
        app.buttons["toolbar_save_button"].tap()

        // Sin prompt: el editor se CIERRA. Hay que afirmar su desmontaje, no la lista: con el
        // editor abierto `accounts_add_button` sigue en el árbol de fondo, así que este test
        // pasaba incluso sin guardar — justo el caso que debía cazar (medido 2026-08-04).
        XCTAssertTrue(
            app.buttons["toolbar_save_button"].waitForNonExistence(timeout: 5),
            "El editor no se cerró tras guardar — ¿apareció el prompt de divisa secundaria?"
        )
        XCTAssertTrue(
            app.buttons["accounts_add_button"].waitForExistence(timeout: 5),
            "El editor no se cerró tras guardar la cuenta con la divisa preferida (¿prompt inesperado?)."
        )
    }
}
