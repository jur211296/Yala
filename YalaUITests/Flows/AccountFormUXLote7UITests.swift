//
//  AccountFormUXLote7UITests.swift
//  YalaUITests
//
//  Formulario de cuenta tras la auditoría UX 2.2, lote 7: «Nueva cuenta» con el tipo en fichas y la ayuda
//  rosa del saldo (L7-1 … L7-4), la X que pregunta antes de tirar lo escrito (L7-5) y la pantalla «Editar el
//  saldo» (L7-6). Seed `minimal`; `launchForUITest` fija el idioma a `es`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class AccountFormUXLote7UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openNewAccountForm(_ app: XCUIApplication) {
        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let addButton = app.buttons["accounts_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció accounts_add_button.")
        addButton.tap()
        XCTAssertTrue(
            app.textFields["account_name_field"].waitForExistence(timeout: 5),
            "No apareció el formulario de cuenta."
        )
    }

    /// L7-1 · L7-2 · L7-3 · L7-4: la cuenta nueva se llama «Nueva cuenta», el tipo va en fichas con su frase,
    /// el campo vacío dice por qué no se puede guardar, la ayuda del saldo es la tarjeta rosa y no hay
    /// «Archivar» antes de que la cuenta exista.
    func test_newAccount_showsTypeChipsHintAndGuidedCard() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openNewAccountForm(app)

        XCTAssertTrue(app.navigationBars["Nueva cuenta"].waitForExistence(timeout: 5), "El alta no se titula «Nueva cuenta».")
        XCTAssertTrue(app.staticTexts["account_balance_required_hint"].exists, "Falta el aviso de por qué no se puede guardar.")

        let savings = app.buttons["account_type_chip_savings"]
        XCTAssertTrue(savings.waitForExistence(timeout: 5), "No aparecieron las fichas de tipo de cuenta.")
        savings.tap()
        XCTAssertTrue(savings.isSelected, "La ficha tocada no quedó elegida.")
        XCTAssertTrue(app.staticTexts["account_type_hint"].exists, "El tipo elegido no dice qué es.")

        var swipes = 0
        let guided = app.buttons["account_balance_guided_card"]
        while !guided.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(guided.isHittable, "No apareció la tarjeta «¿No sabes tu saldo?».")
        XCTAssertFalse(app.switches["account_archive_toggle"].exists, "«Archivar» sale antes de que la cuenta exista.")
        XCTAssertTrue(app.buttons["account_more_options"].exists, "Falta «Más opciones» con «Excluir».")

        // Con saldo escrito, el aviso se va.
        let balance = app.textFields["account_balance_field"]
        balance.tap()
        balance.typeText("100")
        XCTAssertTrue(
            app.staticTexts["account_balance_required_hint"].waitForNonExistence(timeout: 5),
            "El aviso del saldo sigue con un saldo escrito."
        )
    }

    /// L7-5: con algo escrito, la X pregunta «¿Descartar cambios?»; «Seguir editando» deja el formulario y
    /// «Descartar» lo cierra sin guardar.
    func test_closingWithChanges_asksBeforeDiscarding() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openNewAccountForm(app)

        let name = app.textFields["account_name_field"]
        name.tap()
        name.typeText("QA Descartar")

        let close = app.navigationBars.buttons["Cerrar"]
        close.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "La X tiró lo escrito sin preguntar.")
        alert.buttons["Seguir editando"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "«Seguir editando» no cerró la alerta.")
        XCTAssertTrue(name.exists, "«Seguir editando» cerró el formulario.")

        close.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "La segunda X no preguntó.")
        app.alerts.firstMatch.buttons["Descartar"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5), "«Descartar» no cerró el formulario.")
        XCTAssertFalse(app.buttons["accounts_row_QA Descartar"].exists, "Descartar guardó la cuenta.")
    }

    /// L7-6: al editar, se escribe cuánto hay de verdad hoy; sale la diferencia, las dos formas de corregirla
    /// y en cuánto queda la cuenta al guardar.
    func test_editBalance_showsDifferenceOptionsAndResult() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let row = app.buttons["accounts_row_Cuenta Principal"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "El seed no dejó «Cuenta Principal».")
        row.tap()

        XCTAssertTrue(app.navigationBars["Editar cuenta"].waitForExistence(timeout: 5), "La edición no se titula «Editar cuenta».")
        XCTAssertTrue(app.staticTexts["account_balance_yala_says"].waitForExistence(timeout: 5), "Falta «Según Yala».")

        let balance = app.textFields["account_balance_field"]
        var swipes = 0
        while !balance.isHittable && swipes < 4 {
            app.swipeUp()
            swipes += 1
        }
        balance.tap()
        balance.typeText("123456")

        XCTAssertTrue(app.staticTexts["account_balance_difference"].waitForExistence(timeout: 5), "No sale la diferencia.")
        let byEntry = app.buttons["account_balance_fix_entry"]
        let initial = app.buttons["account_balance_fix_initial"]
        XCTAssertTrue(byEntry.exists && initial.exists, "Faltan las dos formas de corregir el saldo.")
        initial.tap()
        XCTAssertTrue(app.staticTexts["account_balance_initial_change"].waitForExistence(timeout: 5),
                      "Corregir el saldo de partida no dice de cuánto a cuánto.")
        XCTAssertTrue(app.staticTexts["account_balance_result"].exists, "Falta «Al guardar, … queda en …».")
    }
}
