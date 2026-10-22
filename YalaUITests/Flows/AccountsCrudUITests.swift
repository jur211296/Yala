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

    /// Archivar enciende «Excluir de las estadísticas» y lo dice debajo; volver a incluirla a mano
    /// apaga el aviso y deja la cuenta archivada. Ticket `archived-accounts-still-count-in-the-panel-total`.
    func test_archivingAccount_turnsOnExcludeAndShowsNotice() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_accounts")

        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'accounts_row_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "El seed no dejó ninguna cuenta en la lista.")
        row.tap()

        let archive = app.switches["account_archive_toggle"]
        let exclude = app.switches["account_exclude_stats_toggle"]
        XCTAssertTrue(archive.waitForExistence(timeout: 5), "No apareció el toggle de archivar.")
        var swipes = 0
        while !archive.isHittable && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(archive.waitForHittable(timeout: 3), "El toggle de archivar no quedó a la vista.")
        XCTAssertEqual(exclude.value as? String, "0", "El seed debía dejar la cuenta incluida.")
        XCTAssertFalse(app.staticTexts["account_archive_excluded_notice"].exists)

        archive.switches.firstMatch.tap()

        let notice = app.staticTexts["account_archive_excluded_notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "Archivar no avisó de la exclusión.")
        XCTAssertEqual(exclude.value as? String, "1", "Archivar no encendió «Excluir de las estadísticas».")

        // El toggle sigue siendo del usuario: re-incluirla a mano retira el aviso y no desarchiva.
        exclude.switches.firstMatch.tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: notice)
        wait(for: [gone], timeout: 5)
        XCTAssertEqual(archive.value as? String, "1", "Re-incluir la cuenta la desarchivó.")
    }
}
