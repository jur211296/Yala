//
//  FavoritesAlRegistrar23UITests.swift
//  YalaUITests
//
//  Revisión 2.3 · Nuevo registro, decisiones 22, 69, 70, 71 y 72 del 9-nov
//  (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`, ficha en
//  `docs/ux/revision-vistas-2.3/32-nuevo-registro/`). Seed `formulario`: «Café» (gasto, S/ 12.00), «Sueldo» (ingreso),
//  «Ahorro del mes» (transferencia con destino) y «Transferencia vieja» (transferencia de antes de 2.2, sin destino).
//
//  - F1: tocar un favorito deja el importe seleccionado y el teclado abierto; escribir lo sustituye.
//  - 69: en «Ingreso», la fila de favoritos solo enseña ingresos.
//  - 70: el editor de favoritos nombra los tres tipos y «Transferencia» pide origen y destino.
//  - 71: deslizar un favorito en Ajustes pregunta antes de borrar.
//  - 72: un favorito de transferencia sin destino no se lista como «Cuenta Principal → …».
//
//  Cada caso adjunta su captura (`keepAlways`): son el antes y el después de la entrega.
//

import XCTest

final class FavoritesAlRegistrar23UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "formulario")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// «Nuevo» de la fila de acciones del Panel.
    private func openForm(_ app: XCUIApplication) {
        let new = app.buttons["panel_action_new"]
        XCTAssertTrue(new.waitForExistence(timeout: 10), "No apareció «Nuevo» en el Panel.")
        XCTAssertTrue(new.waitForHittable(timeout: 10), "«Nuevo» existe pero no se puede tocar.")
        new.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5), "No se abrió el formulario.")
    }

    private func openFavoritesSettings(_ app: XCUIApplication) {
        app.openProfile()
        app.openSettingsSection("profile_favorites")
        XCTAssertTrue(app.buttons["favorites_add_button"].waitForExistence(timeout: 5), "No se abrió Ajustes › Favoritos.")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - F1 · El favorito abre con el importe listo para cambiar (decisión 22)

    /// Ana repite su «Café» (S/ 12.00) pero hoy costó 4.50: toca el favorito y escribe encima, sin borrar «12.00».
    func test_f1_tappingAFavorite_opensTheKeyboardWithTheAmountSelected() {
        let app = launch()
        openForm(app)
        XCTAssertEqual(app.keyboards.count, 0, "El formulario abre sin teclado (preferencia «No abrir»).")

        let cafe = app.buttons["new_transaction_favorite_chip_Café"]
        XCTAssertTrue(cafe.waitForExistence(timeout: 5), "No está el favorito «Café» en la fila.")
        cafe.tap()

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "Tocar un favorito abre el teclado en el importe.")
        let amount = app.textFields["new_transaction_amount"]
        _ = app.waitForSettledLayout(of: amount)
        capture(app, "f1-favorito-con-importe-seleccionado")

        amount.typeText("4.5")
        XCTAssertEqual(amount.value as? String, "4.5",
                       "Escribir sustituye el importe del favorito en vez de sumarse a «12.00».")
        XCTAssertTrue(app.buttons["new_transaction_save"].exists, "«Guardar» está a mano con el teclado abierto (G1).")
    }

    // MARK: - 69 · La fila filtra por el tipo elegido

    func test_typeFilter_inIncome_theRowShowsOnlyIncomeFavorites() {
        let app = launch()
        openForm(app)
        XCTAssertTrue(app.buttons["new_transaction_favorite_chip_Café"].waitForExistence(timeout: 5),
                      "En «Gasto» sale el favorito de gasto.")

        app.buttons["new_transaction_type_income"].tap()
        XCTAssertTrue(app.buttons["new_transaction_favorite_chip_Sueldo"].waitForExistence(timeout: 5),
                      "En «Ingreso» sale el favorito de ingreso.")
        capture(app, "69-ingreso-solo-favoritos-de-ingreso")
        XCTAssertFalse(app.buttons["new_transaction_favorite_chip_Café"].exists, "En «Ingreso» no sale un gasto.")
        XCTAssertFalse(app.buttons["new_transaction_favorite_chip_Ahorro del mes"].exists,
                       "En «Ingreso» no sale una transferencia.")
    }

    // MARK: - 70 · El editor nombra los tres tipos

    func test_editor_namesTheThreeTypes_andTransferAsksForOriginAndDestination() {
        let app = launch()
        openFavoritesSettings(app)
        app.buttons["favorites_add_button"].tap()
        XCTAssertTrue(app.textFields["favorite_name_field"].waitForExistence(timeout: 5), "No se abrió el editor.")

        let expense = app.buttons["favorite_editor_type_expense"]
        let income = app.buttons["favorite_editor_type_income"]
        let transfer = app.buttons["favorite_editor_type_transfer"]
        let hasThree = expense.waitForExistence(timeout: 5) && income.exists && transfer.exists
        capture(app, "70-editor-tres-tipos")
        XCTAssertTrue(hasThree, "El editor nombra Gasto, Ingreso y Transferencia.")
        XCTAssertEqual(expense.label, "Gasto", "Los nombres son los del formulario, en singular.")
        XCTAssertEqual(income.label, "Ingreso")

        transfer.tap()
        XCTAssertTrue(app.buttons["favorite_editor_source_chip"].waitForExistence(timeout: 5),
                      "Una transferencia pide el origen.")
        XCTAssertTrue(app.buttons["favorite_editor_destination_chip"].exists, "Y el destino.")
        XCTAssertFalse(app.buttons["favorite_editor_subcategory_chip"].exists, "Sin categoría.")
        // Se puede volver a gasto: el selector no desaparece al elegir «Transferencia».
        XCTAssertTrue(expense.exists, "El selector sigue a la vista con «Transferencia» elegida.")
        expense.tap()
        XCTAssertTrue(app.buttons["favorite_editor_subcategory_chip"].waitForExistence(timeout: 5),
                      "Al volver a «Gasto», vuelve la categoría.")
    }

    // MARK: - 71 y 72 · Ajustes › Favoritos

    /// 72: «Transferencia vieja» (sin destino) dice su cuenta, no «Cuenta Principal → …». 71: deslizar pregunta; con
    /// «Cancelar» el favorito se queda, y con «Eliminar» se va.
    func test_settingsList_oldTransferShowsItsAccount_andSwipeDeleteAsksFirst() {
        let app = launch()
        openFavoritesSettings(app)

        let old = app.buttons["favorites_row_Transferencia vieja"]
        XCTAssertTrue(old.waitForExistence(timeout: 5), "No está la transferencia vieja del seed.")
        capture(app, "72-lista-transferencia-vieja")
        XCTAssertFalse(old.label.contains("…"), "La transferencia sin destino no lleva «→ …»: \(old.label)")
        XCTAssertTrue(old.label.contains("Cuenta Principal"), "Dice la cuenta que tiene: \(old.label)")

        let cafe = app.buttons["favorites_row_Café"]
        XCTAssertTrue(cafe.exists, "No está «Café» en la lista.")
        cafe.swipeLeft()
        // El botón del deslizamiento es del sistema y no lleva id; el idioma de la suite es fijo (es).
        let swipeDelete = app.buttons["Eliminar"].firstMatch
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 5), "Deslizar no ofreció «Eliminar».")
        swipeDelete.tap()

        let alert = app.alerts["¿Eliminar este favorito?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Deslizar y tocar «Eliminar» pregunta antes de borrar.")
        capture(app, "71-deslizar-pregunta")
        alert.buttons["Cancelar"].firstMatch.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "«Cancelar» cierra la pregunta.")
        XCTAssertTrue(cafe.waitForExistence(timeout: 5), "Con «Cancelar», el favorito se queda.")

        cafe.swipeLeft()
        XCTAssertTrue(swipeDelete.waitForExistence(timeout: 5), "Deslizar no ofreció «Eliminar» la segunda vez.")
        swipeDelete.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "La pregunta sale otra vez.")
        alert.buttons["Eliminar"].firstMatch.tap()
        XCTAssertTrue(cafe.waitForNonExistence(timeout: 5), "Con «Eliminar», el favorito se va.")
        XCTAssertTrue(app.buttons["favorites_row_Sueldo"].exists, "Y solo ese: los demás siguen.")
    }
}
