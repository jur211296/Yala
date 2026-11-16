//
//  ProductividadLote23UITests.swift
//  YalaUITests
//
//  Lote de productividad de 2.3: gastos hormiga en Estadísticas › Resumen (card ea78), logos de suscripción en pagos
//  planificados (card 9nn7) y sugerencias de descripción en Nuevo registro (card y6du).
//

import XCTest

final class ProductividadLote23UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Captura para el PR (se exporta del `.xcresult`).
    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - Gastos hormiga

    /// El corpus `realista` repite el bus y el delivery: Resumen › Detalle enseña la tarjeta con su total y sus filas.
    func test_insights_showsTheSmallRecurringSpendingCard() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "realista", deeplink: "statistics")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = element(app, "insights_ant_expenses_card")
        XCTAssertTrue(card.waitForExistence(timeout: 20), "Resumen no enseñó la tarjeta de gastos hormiga.")
        XCTAssertTrue(element(app, "insights_ant_expenses_summary").exists, "La tarjeta no dice cuánto suman.")
        XCTAssertTrue(element(app, "insights_ant_expenses_row").exists, "La tarjeta no nombra ningún gasto hormiga.")
    }

    // MARK: - Logos de suscripción

    /// Un nombre conocido propone su logo; se puede quitar y volver al automático; el pago se guarda con él.
    func test_scheduledPayment_knownName_proposesItsLogo_canRemoveIt_andTheListShowsIt() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openScheduledPaymentsList()

        let addButton = app.buttons["scheduled_payments_create_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció el + de Pagos planificados.")
        addButton.tap()

        let nameField = app.textFields["scheduled_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No se montó el editor.")
        nameField.tap()
        nameField.typeText("Spotify Duo")

        let badge = element(app, "scheduled_editor_brand_badge_spotify")
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "El editor no propuso el logo de Spotify.")
        keepScreenshot(app, "despues-5-editor-logo-propuesto")

        // Quitarlo.
        let logoRow = app.buttons["scheduled_logo_row"]
        XCTAssertTrue(logoRow.waitForExistence(timeout: 5), "No apareció la fila Logo.")
        logoRow.tap()
        let none = app.buttons["scheduled_logo_option_none"].exists
            ? app.buttons["scheduled_logo_option_none"] : app.buttons["Sin logo"].firstMatch
        XCTAssertTrue(none.waitForExistence(timeout: 5), "El menú del logo no ofrece «Sin logo».")
        none.tap()
        XCTAssertTrue(badge.waitForNonExistence(timeout: 5), "«Sin logo» no quitó el logo.")

        // Volver al automático.
        logoRow.tap()
        let auto = app.buttons["scheduled_logo_option_auto"].exists
            ? app.buttons["scheduled_logo_option_auto"] : app.buttons["Spotify (automático)"].firstMatch
        XCTAssertTrue(auto.waitForExistence(timeout: 5), "El menú del logo no ofrece el automático.")
        auto.tap()
        XCTAssertTrue(badge.waitForExistence(timeout: 5), "El automático no devolvió el logo.")

        // Guardar con monto, cuenta y subcategoría.
        let amountField = app.textFields["scheduled_amount_field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("25")
        app.buttons["scheduled_account_menu"].tap()
        let firstAccount = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "scheduled_account_option_")).firstMatch
        XCTAssertTrue(firstAccount.waitForExistence(timeout: 5), "No se abrió el menú de cuentas.")
        firstAccount.tap()
        app.buttons["scheduled_subcategory_row"].tap()
        let firstSubcat = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_")).firstMatch
        XCTAssertTrue(firstSubcat.waitForExistence(timeout: 5), "No se abrió el selector de subcategoría.")
        firstSubcat.tap()
        let save = app.buttons["toolbar_save_button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        // En la lista el distintivo es decorativo (VoiceOver ya lee el nombre): se comprueba que el pago llegó; que la
        // fila pinta su logo lo fijan `SubscriptionBrandCatalogTests` y la captura del PR.
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Spotify Duo")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "El pago guardado no aparece en la lista.")
    }

    // MARK: - Sugerencias de descripción

    /// Al escribir «Bu», Nuevo registro propone «Bus» (lo más usado del corpus) y tocarlo pone el texto exacto.
    func test_newRecord_typingSuggestsPreviousDescriptions_andTappingFillsTheExactText() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let new = app.buttons["panel_action_new"]
        XCTAssertTrue(new.waitForExistence(timeout: 10), "No apareció «Nuevo registro» en el Panel.")
        new.tap()

        let note = app.textFields["new_transaction_note"]
        XCTAssertTrue(note.waitForExistence(timeout: 5), "No se abrió el formulario.")
        note.tap()
        note.typeText("bu")

        let suggestion = app.buttons
            .matching(identifier: "new_transaction_description_suggestion").firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5), "No aparecieron sugerencias al escribir.")
        keepScreenshot(app, "despues-6-nuevo-registro-sugerencias")
        let text = suggestion.label
        XCTAssertFalse(text.isEmpty)
        suggestion.tap()

        XCTAssertEqual(note.value as? String, text, "Tocar la sugerencia no puso su texto exacto.")
        XCTAssertTrue(app.buttons.matching(identifier: "new_transaction_description_suggestion").firstMatch
                        .waitForNonExistence(timeout: 5),
                      "Tras elegir una sugerencia siguen saliendo otras.")
    }
}
