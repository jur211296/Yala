//
//  ScheduledPaymentsCrudUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `scheduled-payments` (escenarios 7.x): navegación
//  a la lista de Planificación (la fila de Ajustes salió con la decisión 47 de 2.3) y
//  creación de un pago desde el + de la lista (nombre + monto + cuenta vía Menu + subcategoría
//  vía sheet compartido + frecuencia por defecto). Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class ScheduledPaymentsCrudUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Una sola lista de pagos planificados, la de Planificación (UX 2.2 · L10-15). Desde la decisión 47 de 2.3 (B1)
    /// Ajustes ya no tiene la fila que llevaba ahí: se llega por Planificación.
    func test_opensScheduledListFromPlanning() {
        let app = XCUIApplication()
        app.launchForUITest(deeplink: "scheduledPayments")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        XCTAssertTrue(
            app.descendants(matching: .any)["scheduled_hero_pending"].waitForExistence(timeout: 10),
            "No se abrió la lista de Pagos planificados de Planificación."
        )
        app.openProfile()
        XCTAssertTrue(app.buttons["profile_accounts"].waitForExistence(timeout: 10), "No se abrió Ajustes.")
        XCTAssertFalse(app.buttons["profile_planned"].exists, "«Pagos planificados» volvió a Ajustes.")
    }

    /// CRUD — crear un pago planificado y verificar que aparece en la lista.
    func test_createScheduledPayment() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openScheduledPaymentsList()

        let addButton = app.buttons["scheduled_payments_create_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció el + de Pagos planificados.")
        addButton.tap()

        // Nombre
        let nameField = app.textFields["scheduled_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No se montó el editor (scheduled_name_field).")
        nameField.tap()
        let paymentName = "QA Pago"
        nameField.typeText(paymentName)

        // Monto
        let amountField = app.textFields["scheduled_amount_field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "No apareció scheduled_amount_field.")
        amountField.tap()
        amountField.typeText("100")

        // Cuenta — Menu con opciones; elegir la primera (sin acoplar al nombre del seed).
        app.buttons["scheduled_account_menu"].tap()
        let firstAccountOption = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "scheduled_account_option_"))
            .firstMatch
        XCTAssertTrue(firstAccountOption.waitForExistence(timeout: 5), "No se abrió el Menu de cuentas.")
        firstAccountOption.tap()

        // Subcategoría — sheet compartido; elegir la primera fila.
        app.buttons["scheduled_subcategory_row"].tap()
        let firstSubcat = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_"))
            .firstMatch
        XCTAssertTrue(firstSubcat.waitForExistence(timeout: 5), "No se montó SubcategorySelectorSheet con filas.")
        firstSubcat.tap()

        // Guardar (frecuencia usa el valor por defecto: hoy).
        let saveButton = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció toolbar_save_button.")
        saveButton.tap()

        // El primer pago cae hoy, así que sale en «Este mes», y el aviso dice cuándo (UX 2.2 · L10-5).
        XCTAssertTrue(
            app.descendants(matching: .any)["scheduled_saved_notice"].waitForExistence(timeout: 5),
            "Tras guardar no salió «Listo. Primer pago: …»."
        )
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", paymentName)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "El pago planificado creado no apareció en la lista.")
    }
}
