//
//  NewTransactionTypeSelectorUITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2, lote 2 — dos bugs del selector de tipo de «Nuevo registro»:
//  B2 · tocar el tipo que YA está elegido borraba la subcategoría (y «Guardar» se apagaba).
//  B7 · «Recurrente» se ofrecía en una transferencia, y un pago planificado no puede serlo.
//  Seed `minimal`. Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class NewTransactionTypeSelectorUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openNewTransaction(_ app: XCUIApplication) {
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()
        XCTAssertTrue(
            app.textFields["new_transaction_amount"].waitForExistence(timeout: 5),
            "No se montó NewTransactionView (new_transaction_amount)."
        )
    }

    /// B2: con monto, cuenta y subcategoría puestos, volver a tocar «Gasto» (el tipo elegido) no cambia nada.
    func test_retappingTheSelectedType_keepsTheSubcategory() {
        let app = XCUIApplication()
        openNewTransaction(app)

        let amountField = app.textFields["new_transaction_amount"]
        amountField.tap()
        amountField.typeText("50")
        app.chooseFirstSelectorRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")

        let subcategoryChip = app.buttons["new_transaction_subcategory_chip"]
        XCTAssertTrue(subcategoryChip.waitForExistence(timeout: 5), "No volvió al formulario tras elegir cuenta.")
        let emptyLabel = subcategoryChip.label
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")

        XCTAssertTrue(subcategoryChip.waitForExistence(timeout: 5), "No volvió al formulario tras elegir subcategoría.")
        let chosenLabel = subcategoryChip.label
        XCTAssertNotEqual(chosenLabel, emptyLabel, "La subcategoría no quedó elegida: el caso no prueba nada.")
        let saveButton = app.buttons["new_transaction_save"]
        XCTAssertTrue(saveButton.isEnabled, "Con monto, cuenta y subcategoría, «Guardar» debía estar activo.")

        let expense = app.buttons["new_transaction_type_expense"]
        XCTAssertTrue(expense.waitForExistence(timeout: 5), "No apareció el selector de tipo (Gasto).")
        expense.tap()

        XCTAssertEqual(subcategoryChip.label, chosenLabel, "Tocar el tipo ya elegido borró la subcategoría (B2).")
        XCTAssertTrue(saveButton.isEnabled, "Tocar el tipo ya elegido apagó «Guardar» (B2).")
    }

    /// B7: «Recurrente» está en un gasto y desaparece en una transferencia.
    func test_transfer_doesNotOfferRecurring() {
        let app = XCUIApplication()
        openNewTransaction(app)

        let recurring = app.buttons["new_transaction_recurring_action"]
        XCTAssertTrue(recurring.waitForExistence(timeout: 5), "En un gasto, «Recurrente» debía estar: control del caso.")

        let transfer = app.buttons["new_transaction_type_transfer"]
        XCTAssertTrue(transfer.waitForExistence(timeout: 5), "No apareció el selector de tipo (Transferencia).")
        transfer.tap()

        XCTAssertTrue(
            app.buttons["new_transaction_favorite_action"].waitForExistence(timeout: 5),
            "No se pintó la fila de acciones de la transferencia."
        )
        XCTAssertFalse(recurring.exists, "Una transferencia no puede ser un pago planificado: «Recurrente» sobra (B7).")
    }
}
