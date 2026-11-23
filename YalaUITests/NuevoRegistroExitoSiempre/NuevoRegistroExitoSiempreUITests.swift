//
//  NuevoRegistroExitoSiempreUITests.swift
//  YalaUITests
//
//  Decisión de Jürgen del 2026-11-23: al guardar un registro nuevo, la pantalla de éxito sale SIEMPRE. Hasta ese día solo
//  salía en los tres primeros registros; desde el cuarto, el formulario se cerraba con el aviso breve (UX 2.2 · L2-5).
//  Cada caso arranca con cinco registros ya guardados (`-uitest-transactions-saved 5`), que es justo donde antes no salía,
//  y guarda un gasto, un ingreso o una transferencia. Cada caso adjunta su captura (`keepAlways`).
//

import XCTest

final class NuevoRegistroExitoSiempreUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// `formulario`: varias cuentas y el favorito de transferencia «Ahorro del mes». Con 5 registros guardados.
    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "formulario", extraArguments: ["-uitest-transactions-saved", "5"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func openForm(_ app: XCUIApplication) {
        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5), "No se abrió el formulario.")
    }

    private func typeAmount(_ app: XCUIApplication, _ value: String) {
        let amount = app.textFields["new_transaction_amount"]
        amount.tap()
        amount.typeText(value)
    }

    /// Monto, categoría y, si no viene puesta, la cuenta.
    private func fillAmountCategoryAndAccount(_ app: XCUIApplication, amount: String) {
        typeAmount(app, amount)
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        let account = app.buttons["new_transaction_account_chip"]
        XCTAssertTrue(account.waitForExistence(timeout: 5), "Falta el chip de cuenta.")
        if !account.isSelected {
            app.chooseFirstSelectorRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
        }
    }

    private func saveAndExpectSuccess(_ app: XCUIApplication, capture name: String) {
        let save = app.buttons["new_transaction_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled, "Con todo puesto, «Guardar» debía estar activo.")
        save.tap()

        let accept = app.buttons["transaction_success_accept"]
        let shown = accept.waitForExistence(timeout: 10)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(shown, "Al guardar un registro nuevo, la pantalla de éxito sale siempre (también desde el cuarto).")
        XCTAssertFalse(app.descendants(matching: .any)["saved_record_notice"].exists,
                       "Con la pantalla de éxito no sale además el aviso breve.")

        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 8), "«Aceptar» cierra la pantalla de éxito.")
    }

    // MARK: - Casos

    func test_gasto_desdeElQuintoRegistro_saleLaPantallaDeExito() {
        let app = launch()
        openForm(app)
        fillAmountCategoryAndAccount(app, amount: "25")
        saveAndExpectSuccess(app, capture: "exito-gasto")
    }

    func test_ingreso_desdeElQuintoRegistro_saleLaPantallaDeExito() {
        let app = launch()
        openForm(app)
        app.chooseNewTransactionType("income")
        fillAmountCategoryAndAccount(app, amount: "300")
        saveAndExpectSuccess(app, capture: "exito-ingreso")
    }

    /// El favorito «Ahorro del mes» pone origen, destino y monto (L2-14): basta tocarlo para poder guardar.
    func test_transferencia_desdeElQuintoRegistro_saleLaPantallaDeExito() {
        let app = launch()
        openForm(app)
        app.chooseNewTransactionType("transfer")
        let saving = app.buttons["new_transaction_favorite_chip_Ahorro del mes"]
        XCTAssertTrue(saving.waitForExistence(timeout: 5), "En «Transferencia» debía salir el favorito «Ahorro del mes».")
        saving.tap()
        XCTAssertTrue(app.buttons["new_transaction_source_chip"].exists, "Debía quedarse en Transferencia.")
        saveAndExpectSuccess(app, capture: "exito-transferencia")
    }
}
