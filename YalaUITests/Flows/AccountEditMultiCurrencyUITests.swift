//
//  AccountEditMultiCurrencyUITests.swift
//  YalaUITests
//
//  S30 (card «editar cuenta de doble línea»). Seed `tarjeta-dos-lineas`: «Visa QA» (crédito, PEN) con su línea
//  «Visa QA · USD», que tiene un movimiento («Hotel QA»). Editar cuenta abre a pantalla completa, enseña un selector
//  PEN | USD, la línea guarda su saldo inicial con «Guardar», eliminarla pregunta qué hacer con su movimiento, y
//  renombrar la tarjeta renombra su línea.
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los nombres sembrados y los códigos ISO).
//

import XCTest

final class AccountEditMultiCurrencyUITests: XCTestCase {

    private let card = "Visa QA"
    private let line = "Visa QA · USD"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openCardForm() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "tarjeta-dos-lineas")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "La app no llegó al Panel.")
        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let row = app.buttons["accounts_row_\(card)"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No sale la tarjeta en Ajustes › Cuentas.")
        row.tap()
        XCTAssertTrue(app.textFields["account_name_field"].waitForExistence(timeout: 5), "No se abrió Editar cuenta.")
        return app
    }

    private func picker(_ app: XCUIApplication) -> XCUIElement {
        app.segmentedControls["account_line_currency_picker"]
    }

    private func selectSegment(_ app: XCUIApplication, _ code: String) {
        let segment = picker(app).buttons.matching(NSPredicate(format: "label CONTAINS %@", code)).firstMatch
        XCTAssertTrue(segment.waitForExistence(timeout: 5), "No hay segmento \(code).")
        var swipes = 0
        while !segment.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        segment.tap()
    }

    /// Editar abre a pantalla completa: el nombre queda arriba, no a media pantalla.
    func test_editForm_opensFullScreen() {
        let app = openCardForm()
        let name = app.textFields["account_name_field"]
        let window = app.windows.firstMatch.frame
        XCTAssertLessThan(name.frame.minY, window.height * 0.3,
                          "Editar cuenta abrió a media altura: el nombre está en y=\(name.frame.minY) de \(window.height).")
    }

    /// El selector PEN | USD: la línea guarda su saldo inicial con «Guardar» y al reabrir lo trae.
    func test_lineSegment_savesItsInitialBalance() {
        let app = openCardForm()
        XCTAssertTrue(picker(app).waitForExistence(timeout: 5), "La tarjeta con dos líneas no enseña el selector de moneda.")
        selectSegment(app, "USD")

        let field = app.textFields["account_line_initial_balance_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "El segmento USD no enseña el saldo inicial de la línea.")
        field.tap()
        field.typeText("50")
        app.buttons["toolbar_save_button"].tap()
        XCTAssertTrue(app.buttons["accounts_row_\(card)"].waitForExistence(timeout: 5), "El formulario no se cerró al guardar.")

        app.buttons["accounts_row_\(card)"].tap()
        XCTAssertTrue(picker(app).waitForExistence(timeout: 5))
        selectSegment(app, "USD")
        let reopened = app.textFields["account_line_initial_balance_field"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 5))
        XCTAssertTrue((reopened.value as? String ?? "").contains("50"),
                      "La línea no guardó su saldo inicial: «\(reopened.value as? String ?? "")».")
    }

    /// Eliminar la línea con un movimiento abre la hoja que pregunta qué hacer con él; Cancelar no borra nada.
    func test_lineSegment_delete_asksWhatToDoWithItsRecords_andCancelKeepsIt() {
        let app = openCardForm()
        selectSegment(app, "USD")
        let delete = app.buttons["account_line_delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "El segmento USD no ofrece eliminar la línea.")
        var swipes = 0
        while !delete.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        delete.tap()
        XCTAssertTrue(app.otherElements["account_removal_sheet"].waitForExistence(timeout: 5)
                      || app.navigationBars.buttons["account_removal_cancel"].waitForExistence(timeout: 2),
                      "Eliminar una línea con movimientos no preguntó qué hacer con ellos.")
        app.buttons["account_removal_cancel"].tap()
        XCTAssertTrue(picker(app).waitForExistence(timeout: 5), "Tras cancelar, el formulario no sigue abierto.")
        XCTAssertTrue(app.buttons["account_line_delete"].waitForExistence(timeout: 5),
                      "Cancelar se llevó la línea o cambió de divisa: el segmento USD ya no está elegido.")
    }

    /// Una línea vacía (añadida aquí mismo) se elimina con la confirmación corta, y el formulario sigue abierto en la
    /// divisa de la cuenta. Es también el caso de la review: la línea recién añadida trae su propio saldo inicial.
    func test_emptyLine_addedHere_hasItsOwnBalance_andDeletesWithConfirmation_formStaysOpen() {
        let app = openCardForm()
        let add = app.buttons["account_lines_add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        var swipes = 0
        while !add.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        add.tap()
        let eur = app.buttons["account_line_currency_EUR"]
        XCTAssertTrue(eur.waitForExistence(timeout: 5), "No se abrió «Añadir línea».")
        eur.tap()
        app.buttons["account_line_add_confirm"].tap()

        selectSegment(app, "EUR")
        XCTAssertTrue(app.textFields["account_line_initial_balance_field"].waitForExistence(timeout: 5),
                      "La línea recién añadida no enseña su propio saldo inicial.")
        XCTAssertFalse(app.textFields["account_balance_field"].exists,
                       "Bajo el segmento EUR sale el saldo de la cuenta principal.")

        let delete = app.buttons["account_line_delete"]
        swipes = 0
        while !delete.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        delete.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Eliminar una línea vacía no pidió confirmación.")
        alert.buttons["Eliminar"].firstMatch.tap()

        XCTAssertTrue(app.textFields["account_name_field"].waitForExistence(timeout: 5),
                      "Eliminar la línea cerró el formulario.")
        XCTAssertTrue(picker(app).waitForExistence(timeout: 5), "La tarjeta sigue con USD: el selector debe seguir.")
        XCTAssertFalse(picker(app).buttons.matching(NSPredicate(format: "label CONTAINS %@", "EUR")).firstMatch.exists,
                       "La línea en EUR sigue en el selector.")
    }

    /// Renombrar la tarjeta renombra su línea: en Ajustes sale «<nombre nuevo> · USD».
    func test_renamingTheCard_renamesItsLine() {
        let app = openCardForm()
        let name = app.textFields["account_name_field"]
        name.tap()
        let current = name.value as? String ?? ""
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        name.typeText("Visa BCP")
        app.buttons["toolbar_save_button"].tap()
        XCTAssertTrue(app.buttons["accounts_row_Visa BCP"].waitForExistence(timeout: 5), "La tarjeta no se renombró.")
        XCTAssertTrue(app.buttons["accounts_line_row_Visa BCP · USD"].waitForExistence(timeout: 5),
                      "La línea conservó el nombre viejo.")
        XCTAssertFalse(app.buttons["accounts_line_row_\(line)"].exists)
    }
}
