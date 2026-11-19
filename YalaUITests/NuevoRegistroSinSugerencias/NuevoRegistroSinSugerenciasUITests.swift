//
//  NuevoRegistroSinSugerenciasUITests.swift
//  YalaUITests
//
//  Jürgen, 17-nov-2026: bajo el importe de Nuevo registro ya no salen las tres categorías sugeridas ni «Más…»
//  (ocupaban demasiado y se veían mal). La categoría se elige por su chip de siempre, que abre la hoja con su buscador.
//  Seed `una-cuenta`: quien empieza, que es quien más píldoras veía (las tres de arranque).
//
//  Cada caso adjunta su captura (`keepAlways`): son el antes y el después de la entrega, a tamaño normal y con texto
//  grande (AX3, el tamaño de la revisión 2.3).
//

import XCTest

final class NuevoRegistroSinSugerenciasUITests: XCTestCase {

    private static let ax3 = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchAndOpenForm(largeText: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "una-cuenta", extraArguments: largeText ? Self.ax3 : [])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()
        let amount = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "No se abrió el formulario.")
        _ = app.waitForSettledLayout(of: amount)
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertNoSuggestedCategories(_ app: XCUIApplication) {
        let suggested = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'new_transaction_quick_category'"))
        XCTAssertEqual(suggested.count, 0, "Bajo el importe siguen saliendo categorías sugeridas o «Más…».")
    }

    /// Sin píldoras bajo el importe; la categoría se sigue eligiendo por su chip, con la hoja y su buscador.
    func test_noSuggestedCategoriesUnderTheAmount_andTheChipStillChooses() {
        let app = launchAndOpenForm(largeText: false)
        capture(app, "nuevo-registro-normal")
        assertNoSuggestedCategories(app)

        // Con el teclado del importe abierto, el chip vive en la barra de encima del teclado; si no, en el formulario.
        let barChip = app.buttons["new_transaction_keyboard_category_chip"]
        let formChip = app.buttons["new_transaction_subcategory_chip"]
        let chip = barChip.waitForExistence(timeout: 3) && barChip.isHittable ? barChip : formChip
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Falta el chip de categoría.")
        XCTAssertFalse(chip.isSelected, "La categoría no debía venir puesta en un registro nuevo.")
        chip.tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "El chip debía abrir la hoja de categorías con su buscador.")
        search.tap()
        search.typeText("café")
        let restaurants = app.descendants(matching: .any)["subcategory_selector_row_Restaurantes"].firstMatch
        XCTAssertTrue(restaurants.waitForExistence(timeout: 5), "«café» debía encontrar Restaurantes.")
        restaurants.tap()

        let chosen = app.buttons.matching(NSPredicate(
            format: "identifier IN %@ AND label == 'Restaurantes'",
            ["new_transaction_keyboard_category_chip", "new_transaction_subcategory_chip"]
        )).firstMatch
        XCTAssertTrue(chosen.waitForExistence(timeout: 5), "Elegir en la hoja debía dejar Restaurantes en el chip.")
    }

    /// Con texto grande tampoco hay píldoras; la captura sirve para mirar que no queda hueco bajo el importe.
    func test_largeText_noSuggestedCategoriesUnderTheAmount() {
        let app = launchAndOpenForm(largeText: true)
        capture(app, "nuevo-registro-texto-grande")
        // Con AX3 lo de debajo del importe queda bajo el pliegue: un arrastre corto lo sube para la segunda captura.
        let amount = app.textFields["new_transaction_amount"]
        amount.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)))
        _ = app.waitForSettledLayout(of: amount)
        capture(app, "nuevo-registro-texto-grande-abajo")
        assertNoSuggestedCategories(app)
    }
}
