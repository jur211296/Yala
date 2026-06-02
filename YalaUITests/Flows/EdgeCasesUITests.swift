//
//  EdgeCasesUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `edge-cases-logic` (14.1 empty states + 14.3 montos
//  extremos): la app monta sin crash con 0 datos (empty state) y guarda montos
//  en los límites (0.01). Los otros escenarios del área (14.4 límites de texto,
//  14.5 muchas entidades) son validación de formato/volumen → unit/perf.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class EdgeCasesUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// 14.1: con 0 datos (reset + sin seed) la app llega al Panel sin crash.
    func test_emptyStateMountsWithoutCrash() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil)  // reset + skip onboarding, sin sembrar nada
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó con 0 datos.")

        // El Panel monta (el avatar del toolbar está siempre presente) sin crashear.
        XCTAssertTrue(
            app.buttons["profile_avatar"].waitForExistence(timeout: 10),
            "El Panel no montó con 0 datos (profile_avatar ausente)."
        )
        // Config de secciones también disponible (Panel funcional aun vacío).
        XCTAssertTrue(
            app.buttons["panel_sections_config"].exists,
            "panel_sections_config ausente — el Panel no renderizó su chrome con 0 datos."
        )
    }

    /// 14.3: un monto mínimo (0.01) se guarda sin romper el flujo de creación.
    func test_extremeMinimumAmountSaves() {
        let app = XCUIApplication()
        app.launchForUITest()  // seed minimal (cuentas + subcategorías)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.buttons["fab_new_transaction"].tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()

        let amountField = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "No apareció new_transaction_amount.")
        amountField.tap()
        amountField.typeText("0.01")

        app.buttons["new_transaction_account_chip"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "account_selector_row_"))
            .firstMatch.tap()

        let subcatChip = app.buttons["new_transaction_subcategory_chip"]
        XCTAssertTrue(subcatChip.waitForExistence(timeout: 5), "No volvió al formulario tras elegir cuenta.")
        subcatChip.tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_"))
            .firstMatch.tap()

        let saveButton = app.buttons["new_transaction_save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció new_transaction_save.")
        XCTAssertTrue(saveButton.isEnabled, "El botón guardar está deshabilitado con monto 0.01.")
        saveButton.tap()

        // El monto mínimo se guarda y el flujo vuelve al Panel sin romperse.
        XCTAssertTrue(
            app.buttons["fab_new_transaction"].waitForExistence(timeout: 10),
            "Tras guardar 0.01 no se volvió al Panel — el monto extremo rompió el guardado."
        )
    }
}
