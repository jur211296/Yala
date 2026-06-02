//
//  NotificationsSettingsUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `notifications-settings-crud` (escenarios 24.x):
//  navegación Perfil → Notificaciones y creación de un recordatorio personalizado.
//  El prompt de permiso del sistema se suprime en uitest (NotificationsSettingsView
//  `.task` con `guard !UITestHooks.isActive`), por lo que el CRUD de reglas es
//  determinista. El permiso real del SO y el envío de prueba quedan fuera (manual).
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class NotificationsSettingsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navegación Perfil → Notificaciones: la vista monta sin disparar el prompt
    /// de permiso del sistema (suprimido en uitest) y expone el botón de añadir.
    func test_opensNotificationsListFromProfile() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_notifications")

        XCTAssertTrue(
            app.buttons["notifications_add"].waitForExistence(timeout: 5),
            "No se montó NotificationsSettingsView tras tocar profile_notifications."
        )
    }

    /// CRUD — crear un recordatorio personalizado (nombre + texto) y verificar
    /// que aparece en la lista. Custom requiere nombre y texto (canSave).
    func test_createCustomNotificationAppearsInList() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_notifications")

        let addButton = app.buttons["notifications_add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció notifications_add.")
        addButton.tap()

        // El editor de un recordatorio nuevo es de tipo .custom: nombre + texto.
        let nameField = app.textFields["notification_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No apareció el editor (notification_name_field).")
        let notifName = "QA Recordatorio"
        nameField.tap()
        nameField.typeText(notifName)

        let textField = app.textFields["notification_text_field"]
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "No apareció notification_text_field.")
        textField.tap()
        textField.typeText("Mensaje de prueba QA")

        let saveButton = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció toolbar_save_button.")
        saveButton.tap()

        // El recordatorio creado aparece como tarjeta (Toggle con el nombre como label).
        let created = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", notifName))
            .firstMatch
        XCTAssertTrue(
            created.waitForExistence(timeout: 5),
            "El recordatorio creado no apareció en la lista."
        )
    }
}
