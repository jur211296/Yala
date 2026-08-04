//
//  TransactionsCrudUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `transactions-core-crud` (escenarios 5.x): el
//  flujo central de crear una transacción vía FAB. Establece el patrón de
//  SELECTORES (AccountSelectorSheet + SubcategorySelectorSheet, sheets compartidos).
//  Las filas se targetean por prefijo de ID (BEGINSWITH) para no acoplar al seed.
//  Seed `minimal`. Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class TransactionsCrudUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Smoke: el FAB abre el formulario de nueva transacción.
    func test_opensNewTransactionForm() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let fab = app.buttons["fab_new_transaction"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de nueva transacción.")
        fab.tap()
        // El FAB "+" expande un menú (voz/imagen/manual); "manual" abre el form.
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()

        XCTAssertTrue(
            app.textFields["new_transaction_amount"].waitForExistence(timeout: 5),
            "No se montó NewTransactionView (new_transaction_amount)."
        )
    }

    /// CRUD — crear una transacción (monto + cuenta + subcategoría) vía los
    /// selectores y verificar que el flujo completa y vuelve al Panel.
    /// Cubre el patrón de selectores (Account/Subcategory sheets) end-to-end.
    func test_createTransaction() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.buttons["fab_new_transaction"].tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()

        // Monto
        let amountField = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "No apareció new_transaction_amount.")
        amountField.tap()
        amountField.typeText("50")

        // Cuenta — abrir selector y elegir la primera fila (sin acoplar al nombre del seed).
        app.buttons["new_transaction_account_chip"].tap()
        let firstAccount = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "account_selector_row_"))
            .firstMatch
        XCTAssertTrue(firstAccount.waitForExistence(timeout: 5), "No se montó AccountSelectorSheet con filas.")
        firstAccount.tap()

        // Subcategoría — ídem.
        let subcatChip = app.buttons["new_transaction_subcategory_chip"]
        XCTAssertTrue(subcatChip.waitForExistence(timeout: 5), "No volvió al formulario tras elegir cuenta.")
        subcatChip.tap()
        let firstSubcat = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_"))
            .firstMatch
        XCTAssertTrue(firstSubcat.waitForExistence(timeout: 5), "No se montó SubcategorySelectorSheet con filas.")
        firstSubcat.tap()

        // Guardar → pantalla de éxito.
        let saveButton = app.buttons["new_transaction_save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció new_transaction_save.")
        XCTAssertTrue(saveButton.isEnabled, "El botón guardar está deshabilitado (canSave=false: monto/cuenta/subcategoría).")
        saveButton.tap()

        // Tras guardar, el flujo confirma con la pantalla de éxito. NO es transitoria:
        // vive dentro del mismo sheet y solo se cierra con «Aceptar». Cerrarla es parte
        // del flujo que este test cubre, y además lo que hace REAL la aserción de abajo:
        // con el sheet puesto, el Panel de fondo sigue en el árbol y `fab_new_transaction`
        // existe igual ⇒ afirmarlo a secas pasaba en verde sin probar el regreso.
        app.dismissTransactionSuccess()

        let fab = app.buttons["fab_new_transaction"]
        XCTAssertTrue(
            fab.waitForExistence(timeout: 10),
            "Tras guardar no se volvió al Panel — el flujo de creación de transacción no completó."
        )
        XCTAssertTrue(
            fab.waitForHittable(timeout: 5),
            "El Panel existe pero sigue tapado — el sheet de la transacción no se desmontó."
        )
        XCTAssertFalse(
            app.textFields["new_transaction_amount"].exists,
            "El formulario sigue abierto — el guardado no procesó."
        )
    }
}
