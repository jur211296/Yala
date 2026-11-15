//
//  RecordsQuickFilters23UITests.swift
//  YalaUITests
//
//  Revisión 2.3, decisiones 15 y 16 (9-nov). Cada caso cae con el código de antes:
//  - chips rápidos sobre Registros que aplican al tocar (antes, «···» › Filtros › … › «Aplicar»), y su filtro llega a la
//    banda del Panel con «Quitar todo» (los filtros siguen siendo de la sesión);
//  - en Categorías cada fila se llama como su categoría para VoiceOver (antes, once «Seleccionar todo»), se elige
//    tocando la fila entera, y el resumen dice el grupo («Alimentación», no «Delivery +3»);
//  - con la lista vacía, todos los filtros quedan a la vista dentro de la pantalla, con una ✕ de 44 pt y «Quitar todo»;
//  - «Limpiar filtros» está en la cabecera de la hoja, aplica y cierra.
//  Seed `minimal`, scheme Yala Dev.
//

import XCTest

final class RecordsQuickFilters23UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchInRecords() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(deeplink: "records")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Abre el chip «Cuenta ▾» y elige la cuenta del menú.
    private func chooseAccount(_ name: String, in app: XCUIApplication) {
        let chip = app.descendants(matching: .any)["records_quick_account"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No hay chip «Cuenta» sobre la lista de Registros.")
        chip.tap()
        let item = app.buttons[name].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "El menú de cuentas no ofrece «\(name)».")
        item.tap()
    }

    // MARK: - Punto 1 · chips rápidos

    func test_accountChip_appliesOnTap_andTheBandReachesThePanel() {
        let app = launchInRecords()
        chooseAccount("Cuenta Principal", in: app)

        let chip = app.descendants(matching: .any)["records_quick_account"].firstMatch
        XCTAssertTrue(
            chip.waitForValue("Cuenta Principal", timeout: 5),
            "El chip no dice la cuenta elegida (valor: \(String(describing: chip.value)))."
        )
        // Sin «Aplicar»: las filas que quedan son de esa cuenta.
        let firstRow = app.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "La lista se quedó vacía tras elegir la cuenta.")
        XCTAssertTrue(firstRow.label.contains("Cuenta Principal"), "La lista no quedó filtrada: \(firstRow.label)")

        // Los filtros siguen siendo de la sesión: el Panel lo dice en su banda, con «Quitar todo».
        app.selectTab(.panel)
        let removeAll = app.buttons["filter_band_remove_all"].firstMatch
        XCTAssertTrue(removeAll.waitForExistence(timeout: 10), "El Panel no enseña la banda con «Quitar todo».")
        removeAll.tap()
        XCTAssertTrue(removeAll.waitForNonExistence(timeout: 5), "«Quitar todo» no quitó el filtro del Panel.")
    }

    // MARK: - Puntos 2 y 3 · Categorías

    func test_categorySelector_rowsSayTheirName_andTheSummarySaysTheGroup() {
        let app = launchInRecords()
        let more = app.buttons["records_quick_more"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 10), "No hay chip «Más filtros».")
        more.tap()

        let categoriesRow = app.buttons["filters_categories_row"].firstMatch
        XCTAssertTrue(categoriesRow.waitForExistence(timeout: 5), "No se abrió la hoja de Filtros.")
        categoriesRow.tap()

        let rows = app.buttons.matching(identifier: "category_selector_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "El selector no tiene filas de categoría tocables.")
        // VoiceOver: una sola «Seleccionar todo» (la de arriba), no una por categoría.
        let selectAllLabel = app.buttons.matching(NSPredicate(format: "label == %@", "Seleccionar todo"))
        XCTAssertLessThanOrEqual(selectAllLabel.count, 1, "Las categorías se siguen llamando «Seleccionar todo».")

        let first = rows.firstMatch
        let categoryName = first.label
        XCTAssertNotEqual(categoryName, "Seleccionar todo")
        // La fila entera elige la categoría con todas sus subcategorías.
        first.tap()
        XCTAssertTrue(first.isSelected, "Tocar la fila no eligió «\(categoryName)».")

        app.buttons["category_selector_back"].firstMatch.tap()

        XCTAssertTrue(categoriesRow.waitForExistence(timeout: 5))
        XCTAssertTrue(
            categoriesRow.waitForValue(categoryName, timeout: 5),
            "El resumen no dice «\(categoryName)» (dice «\(String(describing: categoriesRow.value))»)."
        )
    }

    // MARK: - Puntos 4 y 5 · la banda con la lista vacía y «Limpiar filtros»

    func test_emptyList_everyFilterStaysOnScreen_withBigCloseAndRemoveAll() {
        let app = launchInRecords()
        chooseAccount("Cuenta Principal", in: app)

        app.buttons["records_quick_more"].firstMatch.tap()
        let note = app.textFields["filters_note_field"]
        XCTAssertTrue(note.waitForExistence(timeout: 5), "No se abrió la hoja de Filtros.")
        note.tap()
        note.typeText("nota que no existe en ningún registro")
        app.buttons["filters_apply_button"].tap()

        let removeAll = app.buttons["filter_band_remove_all"].firstMatch
        XCTAssertTrue(removeAll.waitForExistence(timeout: 10), "La banda no trae «Quitar todo».")
        XCTAssertFalse(app.buttons.matching(identifier: "record_row").firstMatch.exists, "La lista no quedó vacía.")

        let window = app.windows.firstMatch.frame
        let chips = app.buttons.matching(identifier: "applied_filter_chip").allElementsBoundByIndex
        XCTAssertFalse(chips.isEmpty, "La banda no enseña el filtro de la nota.")
        for chip in chips {
            XCTAssertLessThanOrEqual(chip.frame.maxX, window.maxX + 1, "«\(chip.label)» queda fuera de la pantalla.")
            XCTAssertGreaterThanOrEqual(chip.frame.minX, window.minX - 1, "«\(chip.label)» queda fuera de la pantalla.")
        }
        for close in app.buttons.matching(identifier: "applied_filter_chip_remove").allElementsBoundByIndex {
            XCTAssertGreaterThanOrEqual(close.frame.width.rounded(), 44, "La ✕ mide \(close.frame.width) pt de ancho.")
            XCTAssertGreaterThanOrEqual(close.frame.height.rounded(), 44, "La ✕ mide \(close.frame.height) pt de alto.")
        }
        // La cuenta la dice el chip, no la banda.
        let account = app.descendants(matching: .any)["records_quick_account"].firstMatch
        XCTAssertEqual(account.value as? String, "Cuenta Principal")

        removeAll.tap()
        XCTAssertTrue(
            app.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 5),
            "«Quitar todo» no devolvió la lista."
        )
        XCTAssertTrue(account.waitForValue("", timeout: 5), "«Quitar todo» dejó la cuenta elegida.")
    }

    func test_clearFilters_inTheSheetHeader_appliesAndCloses() {
        let app = launchInRecords()
        chooseAccount("Cuenta Principal", in: app)
        let account = app.descendants(matching: .any)["records_quick_account"].firstMatch
        XCTAssertTrue(account.waitForValue("Cuenta Principal", timeout: 5))

        app.buttons["records_quick_more"].firstMatch.tap()
        let clear = app.buttons["filters_clear_button"].firstMatch
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "«Limpiar filtros» no está en la cabecera de la hoja.")
        clear.tap()

        XCTAssertTrue(
            app.buttons["filters_apply_button"].waitForNonExistence(timeout: 5),
            "«Limpiar filtros» no cerró la hoja."
        )
        XCTAssertTrue(account.waitForValue("", timeout: 5), "«Limpiar filtros» no aplicó: la cuenta sigue elegida.")
    }
}

private extension XCUIElement {
    /// Espera a que el valor de accesibilidad sea `expected` («» = sin valor).
    func waitForValue(_ expected: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { object, _ in
            guard let element = object as? XCUIElement else { return false }
            return ((element.value as? String) ?? "") == expected
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
