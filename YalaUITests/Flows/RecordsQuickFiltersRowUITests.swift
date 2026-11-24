//
//  RecordsQuickFiltersRowUITests.swift
//  YalaUITests
//
//  Chips rápidos de Registros, 16-nov (Jürgen, con captura). Cada caso cae con el código de antes:
//  - no hay chip de período y Cuenta · Categoría · Más filtros van en la MISMA línea que Lista/Calendario (antes, los
//    botones de vista en una fila aparte, con el hueco de la captura);
//  - «Cuenta» elige varias a la vez en la hoja de filas de Nuevo registro (antes, un menú de una sola);
//  - «Categoría» elige varias categorías con la rejilla del primer presupuesto, y quitar una subcategoría la deja a
//    medias (antes, una sola fila de una lista con buscador).
//  Seed `minimal`, scheme Yala Dev.
//

import XCTest

final class RecordsQuickFiltersRowUITests: XCTestCase {
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

    func test_noPeriodChip_andTheChipsShareTheLineWithListAndCalendar() {
        let app = launchInRecords()
        let account = app.descendants(matching: .any)["records_quick_account"].firstMatch
        XCTAssertTrue(account.waitForExistence(timeout: 10), "No hay chip «Cuenta» sobre la lista.")
        XCTAssertFalse(app.descendants(matching: .any)["records_quick_date"].exists, "Sigue el chip de período.")

        let list = app.buttons["records_view_mode_list"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), "No están los botones Lista/Calendario.")
        // Misma línea: el centro de los botones cae dentro del alto del chip.
        XCTAssertTrue(
            list.frame.midY > account.frame.minY && list.frame.midY < account.frame.maxY,
            "Lista/Calendario no van en la línea de los chips: botón \(list.frame), chip \(account.frame)."
        )
        let window = app.windows.firstMatch.frame
        for id in ["records_quick_account", "records_quick_category", "records_quick_more", "records_view_mode_calendar"] {
            let element = app.descendants(matching: .any)[id].firstMatch
            XCTAssertTrue(element.exists, "Falta \(id).")
            XCTAssertLessThanOrEqual(element.frame.maxX, window.maxX + 1, "\(id) se sale por la derecha.")
        }
    }

    func test_accountSheet_choosesSeveralAccounts() {
        let app = launchInRecords()
        let chip = app.descendants(matching: .any)["records_quick_account"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()

        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'account_selector_row_'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "La hoja de cuentas no usa la fila de Nuevo registro.")
        XCTAssertGreaterThanOrEqual(rows.count, 2, "El seed necesita dos cuentas para este caso.")
        rows.element(boundBy: 0).tap()
        rows.element(boundBy: 1).tap()
        XCTAssertTrue(rows.element(boundBy: 0).isSelected, "La primera cuenta se desmarcó al tocar la segunda.")
        XCTAssertTrue(rows.element(boundBy: 1).isSelected, "La segunda cuenta no quedó marcada.")

        app.buttons["records_quick_account_done"].firstMatch.tap()
        let expected = NSPredicate(format: "value BEGINSWITH '2 '")
        expectation(for: expected, evaluatedWith: chip)
        waitForExpectations(timeout: 5)
    }

    func test_categorySheet_twoCategories_thenOneSubcategoryOff() {
        let app = launchInRecords()
        let chip = app.descendants(matching: .any)["records_quick_category"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()

        let tiles = app.buttons.matching(identifier: "records_quick_category_tile")
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 5), "La hoja de categorías no usa la rejilla del onboarding.")
        let subcategories = app.buttons.matching(identifier: "records_quick_subcategory")
        // Por encima de «Listo»: lo que queda bajo la barra de abajo da `isHittable` y el toque cae en el botón.
        let done = app.buttons["records_quick_category_done"].firstMatch

        // Por nombre, no por posición: la rejilla es perezosa y, al bajar la hoja, el índice pasa a otra tarjeta.
        let firstName = tiles.element(boundBy: 0).label
        tiles.element(boundBy: 0).tap()
        // Desde el 24-nov, elegir una categoría sube la hoja a grande y la baja sola hasta sus subcategorías. Se espera a
        // que acabe: tocar la segunda mientras la hoja se mueve cae en el sitio viejo. La segunda va en la segunda fila,
        // porque la primera queda medio tapada por la barra de la hoja tras bajar.
        let revealDeadline = Date().addingTimeInterval(8)
        while Date() < revealDeadline,
              !(subcategories.firstMatch.exists && subcategories.firstMatch.frame.maxY < done.frame.minY) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(
            subcategories.firstMatch.exists && subcategories.firstMatch.frame.maxY < done.frame.minY,
            "Elegir una categoría no dejó sus subcategorías a la vista sobre «Listo»."
        )
        let second = tiles.element(boundBy: 3)
        XCTAssertTrue(app.waitForSettledLayout(of: second), "La hoja no dejó de moverse tras elegir la primera categoría.")
        let secondName = second.label
        second.tap()
        // Elegidas las dos, cada una tiene su grupo de subcategorías con su nombre de título. La marca de la tarjeta no se
        // puede leer: al bajar la hoja hasta el final, la rejilla suelta la primera fila.
        for name in [firstName, secondName] {
            let header = app.staticTexts.matching(NSPredicate(format: "label == %@", name)).firstMatch
            XCTAssertTrue(header.waitForExistence(timeout: 5), "«\(name)» no quedó elegida: no sale su grupo de subcategorías.")
        }

        // Las subcategorías salen debajo de la rejilla; si hace falta, se baja hasta ellas como con el dedo.
        let hint = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'subcategor'")).firstMatch
        for _ in 0..<8 where !(subcategories.firstMatch.exists
                               && subcategories.firstMatch.frame.maxY < done.frame.minY - 16) {
            app.swipeUp()
        }
        XCTAssertTrue(hint.exists || subcategories.firstMatch.exists, "No sale la ayuda de las subcategorías.")
        XCTAssertTrue(subcategories.firstMatch.waitForExistence(timeout: 5), "No salen las subcategorías de lo elegido.")
        let first = subcategories.element(boundBy: 0)
        XCTAssertTrue(first.isSelected, "Una categoría elegida entera tiene que traer sus subcategorías marcadas.")
        first.tap()
        XCTAssertFalse(first.isSelected, "Tocar la subcategoría no la quitó.")
        // La rejilla ya quedó arriba, fuera de la vista: que su categoría sigue elegida lo dicen sus otras subcategorías.
        XCTAssertTrue(subcategories.element(boundBy: 1).isSelected, "Quitar una subcategoría quitó las demás de su categoría.")

        done.tap()
        XCTAssertTrue(
            app.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 5)
                || app.descendants(matching: .any)["records_empty_state"].exists,
            "La lista no volvió tras filtrar."
        )
        let value = chip.value as? String ?? ""
        XCTAssertTrue(value.contains("+"), "El chip no dice que hay varias elegidas (valor: \(value)).")
    }
}
