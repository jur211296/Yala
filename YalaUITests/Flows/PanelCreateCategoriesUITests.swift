//
//  PanelCreateCategoriesUITests.swift
//  YalaUITests
//
//  Card omw5 (2026-10-27): tras un onboarding de cero, el Panel enseñaba «Nuevo registro», Voz y Foto apagados y sin
//  explicación. Había cuenta y ninguna categoría, porque la semilla salía por su centinela de una vida anterior.
//
//  Seed `sin-categorias`: cuentas, cero categorías y el centinela de la semilla puesto. Con el bug dentro, la fila sale
//  apagada y no hay botón «Crear categorías»; con él fuera, el botón dice qué falta, crea las categorías aunque el
//  centinela esté puesto, y el registro llega hasta «Guardar» habilitado.
//

import XCTest

final class PanelCreateCategoriesUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_accountWithoutCategories_explainsAndCreatesThem_thenRecordingWorks() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "sin-categorias")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Lo que falta, dicho: el botón de categorías en el sitio de la fila, y la fila no está.
        let createCategories = app.buttons["panel_create_categories"]
        XCTAssertTrue(
            createCategories.waitForHittable(timeout: 15),
            "Con cuenta y sin categorías, el Panel no ofreció «Crear categorías»."
        )
        XCTAssertFalse(app.buttons["panel_action_new"].exists, "La fila apagada siguió ahí junto al botón.")
        XCTAssertFalse(app.buttons["panel_create_first_account"].exists, "Pidió una cuenta que ya existe.")

        createCategories.tap()

        // La fila vuelve en cuanto hay categorías: el centinela puesto no anuló la petición.
        let newRecord = app.buttons["panel_action_new"]
        XCTAssertTrue(newRecord.waitForHittable(timeout: 10), "«Crear categorías» no creó nada: la fila no volvió.")
        XCTAssertTrue(newRecord.isEnabled, "«Nuevo registro» sigue deshabilitado tras crear las categorías.")
        XCTAssertFalse(createCategories.exists, "El botón de categorías siguió en pantalla con categorías ya creadas.")

        // Hasta el último gesto: un registro con cuenta y categoría deja «Guardar» habilitado.
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
        XCTAssertTrue(saveButton.isEnabled, "Guardar deshabilitado: no hubo categoría que elegir.")

        // Sale sin guardar.
        app.closeNewTransactionDiscarding()
        XCTAssertTrue(amountField.waitForNonExistence(timeout: 10), "El formulario no se cerró.")
    }
}
