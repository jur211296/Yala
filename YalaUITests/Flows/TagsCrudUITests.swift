//
//  TagsCrudUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `tags-crud` (escenarios 4.x): navegación
//  Perfil → Etiquetas y creación de etiqueta. Determinista vía seed `minimal`.
//  Reusa los helpers de navegación de Settings (openProfile/openSettingsSection).
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class TagsCrudUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navegación Perfil → Etiquetas: el tap en `profile_tags` empuja TagsSettingsListView.
    func test_opensTagsListFromProfile() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_tags")

        XCTAssertTrue(
            app.buttons["tags_add_button"].waitForExistence(timeout: 5),
            "No se montó TagsSettingsListView tras tocar profile_tags."
        )
    }

    /// CRUD — crear una etiqueta y verificar que aparece en la lista activa.
    func test_createTagAppearsInList() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_tags")

        let addButton = app.buttons["tags_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció tags_add_button.")
        addButton.tap()

        let nameField = app.textFields["tag_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No apareció el formulario de etiqueta (tag_name_field).")
        nameField.tap()
        let tagName = "QA Etiqueta"
        nameField.typeText(tagName)

        let saveButton = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció toolbar_save_button.")
        saveButton.tap()

        XCTAssertTrue(
            app.buttons["tags_row_\(tagName)"].waitForExistence(timeout: 5),
            "La etiqueta creada no apareció en la lista."
        )
    }
}
