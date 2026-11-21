//
//  NuevoRegistroB1UITests.swift
//  YalaUITests
//
//  Hoja B1 de Nuevo registro y éxito minimalista (Jürgen, 2026-11-20; ficha
//  `tickets/done/2026-11-19-nuevo-registro-b-realista-maquetas.md`, «Cómo se sabe que está bien»): el tipo por el
//  título-menú, «Guardar S/ …» con el monto, «Agregar otro» que guarda y deja la hoja lista con la misma cuenta, y
//  «Favorito» y «Recurrente» desde la pantalla de éxito. «···» › Hacer recurrente lo cubre `TransactionFormDecided02UITests`.
//

import XCTest

final class NuevoRegistroB1UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchAndOpen(seed: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: seed)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let new = app.buttons["panel_action_new"]
        XCTAssertTrue(new.waitForExistence(timeout: 10), "No apareció «Nuevo» en el Panel.")
        XCTAssertTrue(new.waitForHittable(timeout: 10), "«Nuevo» existe pero no se puede tocar.")
        new.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5), "No se abrió el formulario.")
        return app
    }

    private func typeAmount(_ app: XCUIApplication, _ value: String) {
        let amount = app.textFields["new_transaction_amount"]
        amount.tap()
        amount.typeText(value)
    }

    /// El favorito pide el foco del importe 50 ms después de tocarlo: se espera al teclado antes de cerrarlo.
    private func dismissKeyboard(_ app: XCUIApplication) {
        guard app.keyboards.firstMatch.waitForExistence(timeout: 2) else { return }
        app.staticTexts["new_transaction_amount_question"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "El teclado no se cerró.")
    }

    /// El título dice el tipo y, al elegir otro en su menú, el formulario cambia con él.
    func test_titleMenu_changesTheTypeAndTheTitle() {
        let app = launchAndOpen(seed: "minimal")
        let menu = app.buttons["new_transaction_type_menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        let expenseTitle = menu.value as? String
        app.chooseNewTransactionType("transfer")
        XCTAssertTrue(app.buttons["new_transaction_source_chip"].waitForExistence(timeout: 5),
                      "Elegir «Transferencia» en el título-menú no cambió el formulario.")
        XCTAssertNotEqual(menu.value as? String, expenseTitle, "El título no cambió con el tipo.")
        XCTAssertFalse(app.buttons["new_transaction_subcategory_chip"].exists, "Una transferencia no lleva categoría.")
    }

    /// «Guardar» lleva el monto escrito.
    func test_saveButton_saysTheAmount() {
        let app = launchAndOpen(seed: "una-cuenta")
        let save = app.buttons["new_transaction_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        let empty = save.label
        typeAmount(app, "25")
        expectation(for: NSPredicate(format: "label CONTAINS '25'"), evaluatedWith: save)
        waitForExpectations(timeout: 5)
        XCTAssertNotEqual(save.label, empty, "Con monto, «Guardar» debía decirlo.")
    }

    /// «Agregar otro» guarda y deja la hoja vacía con la misma cuenta, sin pasar por la pantalla de éxito.
    func test_addAnother_savesAndLeavesTheFormReadyWithTheSameAccount() {
        let app = launchAndOpen(seed: "una-cuenta")
        typeAmount(app, "25")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        let account = app.buttons["new_transaction_account_chip"]
        XCTAssertTrue(account.waitForExistence(timeout: 5))
        let accountLabel = account.label
        XCTAssertTrue(account.isSelected, "Control: con una sola cuenta, viene puesta.")
        let subcategory = app.buttons["new_transaction_subcategory_chip"]
        XCTAssertTrue(subcategory.isSelected, "Control: la subcategoría quedó elegida.")

        let addAnother = app.buttons["new_transaction_add_another"]
        XCTAssertTrue(addAnother.waitForExistence(timeout: 5), "Falta «Agregar otro» junto a «Guardar».")
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: addAnother)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.waitForSettledLayout(of: addAnother))
        addAnother.tap()

        XCTAssertFalse(app.buttons["transaction_success_accept"].waitForExistence(timeout: 2),
                       "«Agregar otro» no pasa por la pantalla de éxito.")
        XCTAssertTrue(app.textFields["new_transaction_amount"].exists, "La hoja tenía que seguir abierta.")
        expectation(for: NSPredicate(format: "isSelected == false"), evaluatedWith: subcategory)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(account.label, accountLabel, "La cuenta se queda para el siguiente.")
        XCTAssertTrue(account.isSelected)
        let amountValue = app.textFields["new_transaction_amount"].value as? String ?? ""
        XCTAssertFalse(amountValue.contains("25"), "El monto tenía que quedar vacío (\(amountValue)).")
    }

    /// La pantalla de éxito minimalista ofrece «Favorito» y «Recurrente», y «Favorito» abre la hoja de siempre.
    func test_success_offersFavoriteAndRecurring_andFavoriteOpensItsSheet() {
        let app = launchAndOpen(seed: "formulario")
        let coffee = app.buttons["new_transaction_favorite_chip_Café"]
        XCTAssertTrue(coffee.waitForExistence(timeout: 5), "Falta el favorito «Café» del perfil `formulario`.")
        coffee.tap()
        dismissKeyboard(app)
        let save = app.buttons["new_transaction_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.waitForSettledLayout(of: save), "«Guardar» no dejó de moverse.")
        save.tap()

        XCTAssertTrue(app.buttons["transaction_success_accept"].waitForExistence(timeout: 10), "No salió el éxito.")
        XCTAssertTrue(app.buttons["transaction_success_create_another"].exists)
        let favorite = app.buttons["transaction_success_favorite"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5), "El éxito no ofrece «Favorito».")
        XCTAssertTrue(app.buttons["transaction_success_recurring"].exists, "El éxito no ofrece «Recurrente».")
        XCTAssertEqual(app.buttons["transaction_success_accept"].frame.midY,
                       app.buttons["transaction_success_create_another"].frame.midY, accuracy: 2,
                       "«Registrar otro» y «Aceptar» van lado a lado.")
        favorite.tap()
        XCTAssertTrue(app.textFields["save_favorite_name_field"].waitForExistence(timeout: 5),
                      "«Favorito» del éxito no abrió la hoja de guardar como favorito.")
    }
}
