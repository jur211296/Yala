//
//  ScheduledPaymentsCrudUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `scheduled-payments` (escenarios 7.x): navegación
//  Perfil → Pagos planificados y creación de un pago (nombre + monto + cuenta vía
//  Menu + subcategoría vía sheet compartido + frecuencia por defecto). Reusa el
//  selector de subcategoría establecido (subcategory_selector_row). Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class ScheduledPaymentsCrudUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navegación Perfil → Pagos planificados.
    func test_opensScheduledListFromProfile() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_planned")

        XCTAssertTrue(
            app.buttons["scheduled_add_button"].waitForExistence(timeout: 5),
            "No se montó ScheduledPaymentsSettingsView tras tocar profile_planned."
        )
    }

    /// CRUD — crear un pago planificado y verificar que aparece en la lista.
    func test_createScheduledPayment() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_planned")

        let addButton = app.buttons["scheduled_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció scheduled_add_button.")
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

        // Guardar (frecuencia usa el valor por defecto).
        let saveButton = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció toolbar_save_button.")
        XCTAssertTrue(saveButton.isEnabled, "El botón guardar está deshabilitado (faltan campos requeridos).")
        saveButton.tap()

        // Tras guardar, el dismiss del editor (sheet dentro de NavigationStack dentro de
        // sheet) cierra el Perfil entero y vuelve al Panel. Re-navegar a la lista para
        // verificar la persistencia, manejando el estado en que quedemos.
        if !app.buttons["scheduled_add_button"].waitForExistence(timeout: 5) {
            if app.buttons["profile_avatar"].exists {
                app.openProfile()
            }
            app.openSettingsSection("profile_planned")
        }
        XCTAssertTrue(
            app.buttons["scheduled_row_\(paymentName)"].waitForExistence(timeout: 5),
            "El pago planificado creado no apareció en la lista."
        )
    }
}
