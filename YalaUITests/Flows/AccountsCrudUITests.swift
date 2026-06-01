//
//  AccountsCrudUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `accounts-crud` (escenarios 2.x): navegación
//  Perfil → Cuentas y creación de cuenta. Determinista vía seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class AccountsCrudUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navegación Perfil → Cuentas. Cubre el blocker histórico donde el tap en
    /// `profile_accounts` no empujaba `AccountsSettingsListView` en XCUITest.
    func test_opensAccountsListFromProfile() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_accounts")

        XCTAssertTrue(
            app.buttons["accounts_add_button"].waitForExistence(timeout: 5),
            "No se montó AccountsSettingsListView tras tocar profile_accounts."
        )
    }

    /// CRUD — crear una cuenta y verificar que aparece en la lista activa.
    func test_createAccountAppearsInList() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_accounts")

        let addButton = app.buttons["accounts_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció accounts_add_button.")
        addButton.tap()

        let nameField = app.textFields["account_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No apareció el formulario de cuenta (account_name_field).")
        nameField.tap()
        let accountName = "QA Cuenta Test"
        nameField.typeText(accountName)

        // Las cuentas nuevas exigen saldo inicial (isBalanceValid → canSave).
        let balanceField = app.textFields["account_balance_field"]
        XCTAssertTrue(balanceField.waitForExistence(timeout: 5), "No apareció account_balance_field.")
        balanceField.tap()
        balanceField.typeText("100")

        let saveButton = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció toolbar_save_button.")
        saveButton.tap()

        XCTAssertTrue(
            app.buttons["accounts_row_\(accountName)"].waitForExistence(timeout: 5),
            "La cuenta creada no apareció en la lista."
        )
    }
}
