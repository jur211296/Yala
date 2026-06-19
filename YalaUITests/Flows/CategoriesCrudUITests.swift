//
//  CategoriesCrudUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `categories-subcategories-crud` (escenarios 3.x):
//  navegación Perfil → Categorías y creación de categoría con subcategoría
//  (flujo de 3 niveles: lista → CategoryDetail → SubcategoryDetail). El guardado
//  de una categoría nueva EXIGE ≥1 subcategoría (saveCategory). Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class CategoriesCrudUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navegación Perfil → Categorías: el tap en `profile_categories` empuja
    /// CategoriesSettingsListView.
    func test_opensCategoriesListFromProfile() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_categories")

        XCTAssertTrue(
            app.buttons["categories_add_button"].waitForExistence(timeout: 5),
            "No se montó CategoriesSettingsListView tras tocar profile_categories."
        )
    }

    /// CRUD — crear categoría + subcategoría y verificar que aparece en la lista.
    func test_createCategoryWithSubcategory() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_categories")

        let addButton = app.buttons["categories_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció categories_add_button.")
        addButton.tap()

        // CategoryDetailView (categoría nueva) — nombre.
        let catNameField = app.textFields["category_name_field"]
        XCTAssertTrue(catNameField.waitForExistence(timeout: 5), "No se montó CategoryDetailView (category_name_field).")
        catNameField.tap()
        let categoryName = "QA Categoria"
        catNameField.typeText(categoryName)

        // Añadir subcategoría (requerida para guardar) → SubcategoryDetailView.
        let addSub = app.buttons["category_add_subcategory"]
        XCTAssertTrue(addSub.waitForExistence(timeout: 5), "No apareció category_add_subcategory.")
        addSub.tap()

        let subNameField = app.textFields["subcategory_name_field"]
        XCTAssertTrue(subNameField.waitForExistence(timeout: 5), "No se montó SubcategoryDetailView (subcategory_name_field).")
        subNameField.tap()
        subNameField.typeText("QA Sub")

        // Guardar subcategoría (vuelve a CategoryDetailView).
        let saveSub = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveSub.waitForExistence(timeout: 5), "No apareció save de subcategoría.")
        saveSub.tap()

        // De vuelta en CategoryDetailView, guardar la categoría (vuelve a la lista).
        let saveCat = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveCat.waitForExistence(timeout: 5), "No apareció save de categoría.")
        saveCat.tap()

        XCTAssertTrue(
            app.buttons["categories_row_\(categoryName)"].waitForExistence(timeout: 5),
            "La categoría creada no apareció en la lista."
        )
    }
}
