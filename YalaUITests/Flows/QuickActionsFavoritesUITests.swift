//
//  QuickActionsFavoritesUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `transactions-quick-actions-favorites` (escenarios
//  5.23-5.30): guardar una transacción a medio armar como favorito (plantilla) vía
//  el quick action "Favorito" del formulario. Reusa el flujo de creación de TX
//  (fab_manual + selectores Account/Subcategory) y verifica la persistencia en la
//  lista de Favoritos (favorites_row_<name>, patrón de FavoritesCrudUITests).
//  Seed `minimal`. Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class QuickActionsFavoritesUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Smoke: el quick action "Favorito" del formulario abre SaveAsFavoriteSheet.
    func test_opensSaveAsFavoriteSheetFromForm() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.buttons["fab_new_transaction"].tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()

        XCTAssertTrue(
            app.textFields["new_transaction_amount"].waitForExistence(timeout: 5),
            "No se montó NewTransactionView (new_transaction_amount)."
        )

        // El quick action "Favorito" vive en la quickActionsBar (dentro del ScrollView).
        let favoriteAction = app.buttons["new_transaction_favorite_action"]
        XCTAssertTrue(favoriteAction.waitForExistence(timeout: 5), "No apareció el quick action de favorito.")
        favoriteAction.tap()

        XCTAssertTrue(
            app.textFields["save_favorite_name_field"].waitForExistence(timeout: 5),
            "No se montó SaveAsFavoriteSheet (save_favorite_name_field)."
        )
    }

    /// CRUD — armar una transacción (monto + cuenta + subcategoría), guardarla como
    /// favorito, registrar la TX para volver al Panel, y verificar que el favorito
    /// aparece en la lista de Favoritos.
    func test_saveAsFavoriteFromTransactionAppearsInList() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.buttons["fab_new_transaction"].tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()

        // Monto
        let amountField = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "No apareció new_transaction_amount.")
        amountField.tap()
        amountField.typeText("75")

        // Cuenta — primera fila del selector (sin acoplar al nombre del seed).
        app.buttons["new_transaction_account_chip"].tap()
        let firstAccount = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "account_selector_row_"))
            .firstMatch
        XCTAssertTrue(firstAccount.waitForExistence(timeout: 5), "No se montó AccountSelectorSheet con filas.")
        firstAccount.tap()

        // Subcategoría — ídem.
        let subcatChip = app.buttons["new_transaction_subcategory_chip"]
        XCTAssertTrue(subcatChip.waitForExistence(timeout: 5), "No volvió al formulario tras elegir cuenta.")
        subcatChip.tap()
        let firstSubcat = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_"))
            .firstMatch
        XCTAssertTrue(firstSubcat.waitForExistence(timeout: 5), "No se montó SubcategorySelectorSheet con filas.")
        firstSubcat.tap()

        // Guardar como favorito vía el quick action.
        let favoriteAction = app.buttons["new_transaction_favorite_action"]
        XCTAssertTrue(favoriteAction.waitForExistence(timeout: 5), "No apareció el quick action de favorito.")
        favoriteAction.tap()

        let nameField = app.textFields["save_favorite_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No se montó SaveAsFavoriteSheet (save_favorite_name_field).")
        nameField.tap()
        let favoriteName = "QA Fav TX"
        nameField.typeText(favoriteName)

        let saveFavoriteButton = app.buttons["save_favorite_save_button"]
        XCTAssertTrue(saveFavoriteButton.waitForExistence(timeout: 5), "No apareció save_favorite_save_button.")
        XCTAssertTrue(saveFavoriteButton.isEnabled, "El botón guardar favorito está deshabilitado (nombre vacío).")
        saveFavoriteButton.tap()

        // Tras guardar el favorito, el sheet se cierra y volvemos al formulario.
        // Registramos la transacción para volver al Panel de forma determinista.
        let saveTransaction = app.buttons["new_transaction_save"]
        XCTAssertTrue(saveTransaction.waitForExistence(timeout: 5), "No volvió al formulario tras guardar el favorito.")
        XCTAssertTrue(saveTransaction.isEnabled, "new_transaction_save deshabilitado (monto/cuenta/subcategoría).")
        saveTransaction.tap()

        XCTAssertTrue(
            app.buttons["fab_new_transaction"].waitForExistence(timeout: 10),
            "Tras guardar no se volvió al Panel."
        )

        // Verificar persistencia del favorito en Perfil → Favoritos.
        app.openProfile()
        app.openSettingsSection("profile_favorites")

        XCTAssertTrue(
            app.buttons["favorites_row_\(favoriteName)"].waitForExistence(timeout: 5),
            "El favorito guardado desde la transacción no apareció en la lista."
        )
    }
}
