//
//  FirstExpensePracticeAlertUITests.swift
//  YalaUITests
//
//  El primer gasto de un usuario nuevo arma el aviso «¿era de prueba?». Hasta el 2026-10-11 el Panel lo encendía
//  en el acto, con la hoja de Nuevo registro todavía encima, y el `.alert` desmontaba el formulario antes de su
//  pantalla de éxito (ticket `first-expense-practice-alert-tears-down-the-success-screen`). Ahora el aviso pasa por
//  el candado del Panel (`RouterConsumerGateLogic.panelCanDrain`) y sale al cerrar la pantalla de éxito.
//
//  Seed `sin-registros`: cuentas y categorías, cero registros — el único estado en el que el guardado arma el aviso.
//

import XCTest

final class FirstExpensePracticeAlertUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_firstExpense_showsSuccessScreenBeforePracticeAlert() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "sin-registros")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // La píldora del hero y no el FAB: con cero registros el Panel puede no tener scroll para que el FAB entre.
        let newRecord = app.buttons["panel_action_new"]
        XCTAssertTrue(newRecord.waitForHittable(timeout: 10), "No apareció «Nuevo registro» en el hero del Panel.")
        newRecord.tap()

        let amountField = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "No apareció new_transaction_amount.")
        amountField.tap()
        amountField.typeText("12")

        app.chooseFirstSelectorRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
        XCTAssertTrue(
            app.buttons["new_transaction_subcategory_chip"].waitForExistence(timeout: 5),
            "No volvió al formulario tras elegir cuenta."
        )
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")

        let saveButton = app.buttons["new_transaction_save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció new_transaction_save.")
        XCTAssertTrue(saveButton.isEnabled, "Guardar deshabilitado: falta monto, cuenta o subcategoría.")
        saveButton.tap()

        // La pantalla de éxito se ve, y sin el aviso encima: el aviso es del Panel y espera a que la hoja se cierre.
        let accept = app.buttons["transaction_success_accept"]
        XCTAssertTrue(
            accept.waitForExistence(timeout: 10),
            "No apareció la pantalla de éxito: el aviso «¿era de prueba?» cerró el formulario antes de tiempo."
        )
        let keep = app.alerts.buttons["Guardarlo"]  // UX 2.2 · L5-5: antes «Conservar»
        XCTAssertFalse(keep.exists, "El aviso «¿era de prueba?» salió encima de la pantalla de éxito.")
        // Se espera: la pantalla de éxito entra con animación y `isHittable` da `false` mientras se desliza.
        XCTAssertTrue(accept.waitForHittable(timeout: 5), "La pantalla de éxito está tapada.")

        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 10), "La pantalla de éxito no se cerró tras «Aceptar».")

        // Y el aviso llega después, sobre el Panel. Por su texto: el locale lo fija `launchForUITest` (es_PE) y los
        // botones de un `.alert` no llevan identificador.
        XCTAssertTrue(
            keep.waitForExistence(timeout: 10),
            "Tras cerrar la pantalla de éxito no apareció el aviso «¿era de prueba?» (botón «Guardarlo»)."
        )
        keep.tap()
        XCTAssertTrue(keep.waitForNonExistence(timeout: 5), "El aviso no se cerró con «Guardarlo».")
        XCTAssertTrue(newRecord.waitForHittable(timeout: 10), "Tras el aviso el Panel no quedó usable.")
    }
}
