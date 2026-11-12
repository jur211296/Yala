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

    /// Card 93ta: un favorito de transferencia se edita como transferencia. Con el seed `formulario`, «Ahorro del mes» va
    /// de «Cuenta Principal» a «Ahorros USD». El editor enseña origen y destino, sin categoría ni etiquetas, y el selector
    /// de destino no ofrece el origen. Antes abría el editor de gasto/ingreso sin ningún tipo marcado y sin el destino.
    func test_transferFavorite_editsOriginAndDestination() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "formulario")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_favorites")

        let row = app.buttons["favorites_row_Ahorro del mes"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció el favorito de transferencia del seed.")
        row.tap()

        XCTAssertTrue(app.textFields["favorite_name_field"].waitForExistence(timeout: 5), "No se abrió el editor.")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "editor-favorito-transferencia"
        shot.lifetime = .keepAlways
        add(shot)

        let source = app.buttons["favorite_editor_source_chip"]
        let destination = app.buttons["favorite_editor_destination_chip"]
        XCTAssertTrue(source.waitForExistence(timeout: 5), "El editor de un favorito de transferencia no enseña el origen.")
        XCTAssertTrue(destination.exists, "El editor de un favorito de transferencia no enseña el destino.")
        XCTAssertTrue(destination.label.contains("Ahorros"), "El destino no es el del favorito: \(destination.label)")
        XCTAssertFalse(app.buttons["favorite_editor_subcategory_chip"].exists,
                       "Una transferencia no lleva categoría, y el editor la ofrece.")

        // El selector de destino no ofrece la cuenta de origen: origen igual a destino no se puede elegir.
        destination.tap()
        let ahorros = app.descendants(matching: .any)["account_selector_row_Ahorros USD"].firstMatch
        XCTAssertTrue(ahorros.waitForExistence(timeout: 5), "No se abrió el selector de destino.")
        XCTAssertFalse(app.descendants(matching: .any)["account_selector_row_Cuenta Principal"].exists,
                       "El selector de destino ofrece la cuenta de origen.")
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
