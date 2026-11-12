//
//  CategoryQuickPick23UITests.swift
//  YalaUITests
//
//  Decisión 21 de la revisión 2.3 (9-nov-2026), C2 + C3, con alguien que empieza (seed `una-cuenta`: categorías y
//  «Cuenta Principal», sin registros): bajo el importe salen Restaurantes, Supermercados y Taxis y apps más «Más…», un
//  toque elige la categoría sin abrir ninguna hoja, y en la hoja «café» encuentra Restaurantes. Los ids llevan el nombre
//  de la categoría, como las filas de la hoja; la suite corre en español (`launchForUITest`).
//

import XCTest

final class CategoryQuickPick23UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchAndOpenForm() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "una-cuenta")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5), "No se abrió el formulario.")
        return app
    }

    /// Sin registros, la fila trae las tres de arranque y «Más…»; un toque deja la categoría puesta.
    func test_firstRecord_showsTheThreeStarters_andOneTapChoosesTheCategory() {
        let app = launchAndOpenForm()

        let restaurants = app.buttons["new_transaction_quick_category_Restaurantes"]
        XCTAssertTrue(restaurants.waitForExistence(timeout: 5), "Falta Restaurantes en la fila de categorías a un toque.")
        XCTAssertTrue(app.buttons["new_transaction_quick_category_Supermercados y tiendas"].exists, "Falta Supermercados.")
        XCTAssertTrue(app.buttons["new_transaction_quick_category_Taxis y apps"].exists, "Falta Taxis y apps.")
        XCTAssertTrue(app.buttons["new_transaction_quick_category_more"].exists, "Falta «Más…».")

        let categoryChip = app.buttons["new_transaction_subcategory_chip"]
        XCTAssertTrue(categoryChip.waitForExistence(timeout: 5))
        XCTAssertFalse(categoryChip.isSelected, "La categoría no debía venir puesta en un registro nuevo.")

        restaurants.tap()

        XCTAssertTrue(
            restaurants.waitForSelected(timeout: 5),
            "Tras el toque, Restaurantes debía quedar elegida en la fila."
        )
        XCTAssertTrue(categoryChip.isSelected, "El chip de categoría de abajo debía quedar puesto con un toque.")
        XCTAssertEqual(categoryChip.label, "Restaurantes")
        XCTAssertFalse(app.searchFields.firstMatch.exists, "Elegir de la fila no abre la hoja de categorías.")
    }

    /// «Más…» abre la hoja con todas, y su buscador entiende «café».
    func test_moreOpensTheSheet_andCafeFindsRestaurants() {
        let app = launchAndOpenForm()

        let more = app.buttons["new_transaction_quick_category_more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Falta «Más…».")
        more.tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "«Más…» debía abrir la hoja de categorías con su buscador.")
        search.tap()
        search.typeText("café")

        let restaurantsRow = app.descendants(matching: .any)["subcategory_selector_row_Restaurantes"].firstMatch
        XCTAssertTrue(restaurantsRow.waitForExistence(timeout: 5), "«café» debía encontrar Restaurantes.")
        XCTAssertFalse(
            app.descendants(matching: .any)["subcategory_selector_row_Delivery"].firstMatch.exists,
            "«café» no debía traer el resto de Alimentación: lo encuentra la palabra, no el grupo."
        )
        XCTAssertFalse(
            app.descendants(matching: .any)["subcategory_selector_search_empty"].firstMatch.exists,
            "«café» no debía dar «sin resultados»."
        )
    }
}

private extension XCUIElement {
    /// Espera a que el elemento quede seleccionado (`isSelected`), sin `sleep`.
    func waitForSelected(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isSelected == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
