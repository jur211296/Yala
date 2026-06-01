//
//  FavoritesCrudUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `favorites` (escenarios 8.x): navegación
//  Perfil → Favoritos y creación de favorito. Crear solo exige nombre (cuenta/
//  subcategoría son opcionales). Seed `minimal`. Reusa openProfile/openSettingsSection.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class FavoritesCrudUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navegación Perfil → Favoritos: el tap en `profile_favorites` empuja FavoritesListView.
    func test_opensFavoritesListFromProfile() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_favorites")

        XCTAssertTrue(
            app.buttons["favorites_add_button"].waitForExistence(timeout: 5),
            "No se montó FavoritesListView tras tocar profile_favorites."
        )
    }

    /// CRUD — crear un favorito y verificar que aparece en la lista.
    func test_createFavoriteAppearsInList() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_favorites")

        let addButton = app.buttons["favorites_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció favorites_add_button.")
        addButton.tap()

        let nameField = app.textFields["favorite_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No apareció el editor de favorito (favorite_name_field).")
        nameField.tap()
        let favoriteName = "QA Favorito"
        nameField.typeText(favoriteName)

        let saveButton = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "No apareció toolbar_save_button.")
        saveButton.tap()

        XCTAssertTrue(
            app.buttons["favorites_row_\(favoriteName)"].waitForExistence(timeout: 5),
            "El favorito creado no apareció en la lista."
        )
    }
}
