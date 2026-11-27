//
//  FlujoCrearPlanUITests.swift
//  YalaUITests
//
//  S5 del replanteo (18-nov-2026): crear el plan enseña el saldo de hoy sin «Cambiar», agrupa las líneas bajo su
//  categoría con una cabecera que se pliega, y «Agregar línea › Desde mis gastos» pide la subcategoría antes de dejar
//  guardar.
//

import XCTest

final class FlujoCrearPlanUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_armado_partedelSaldo_yLaCategoriaSePliega() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        app.openReport("flujoDeCaja")

        let amount = app.descendants(matching: .any).matching(identifier: "cashflow_setup_starting_amount").firstMatch
        XCTAssertTrue(amount.waitForExistence(timeout: 15), "No está «Tienes hoy».")
        XCTAssertTrue(app.staticTexts["cashflow_setup_starting_caption"].exists, "Falta de dónde parte el plan.")
        XCTAssertFalse(app.buttons["cashflow_setup_change_starting"].exists, "Sigue «Cambiar» del saldo inicial.")

        let header = app.buttons.matching(identifier: "cashflow_setup_group").firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 5), "No hay cabeceras de categoría.")
        // Desde el 24-nov-2026 los chips «Comparativa / Flujo de caja» van fijos dentro del scroll: un `swipeUp` dejaba
        // la cabecera debajo de ellos, XCUITest la daba por tocable y el toque caía en el chip. Se lleva al centro con un
        // arrastre sin inercia y por debajo de los chips.
        let chips = app.buttons["report_chip_flujoDeCaja"]
        var tries = 0
        while header.frame.midY > app.frame.height * 0.6 || header.frame.minY < chips.frame.maxY + 8, tries < 6 {
            let delta = header.frame.midY - app.frame.height * 0.45
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(
                forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -delta)),
                withVelocity: .slow, thenHoldForDuration: 0.3
            )
            tries += 1
        }
        // Nocturna del 22-nov (iOS 27.0, runner del CI): el toque llegaba con la página aún deslizándose y solo la
        // frenaba, y la cuenta de antes se leía en pleno movimiento. Se cuenta y se toca con la cabecera quieta, y el
        // plazo es de 15 s porque en el runner cada lectura del árbol cuesta 1-3 s.
        _ = app.waitForSettledLayout(of: header, timeout: 5)
        let lines = app.descendants(matching: .any).matching(identifier: "cashflow_setup_line")
        let before = lines.count
        XCTAssertGreaterThan(before, 0)
        header.tap()
        let fewer = NSPredicate(format: "count < %d", before)
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: fewer, object: lines)], timeout: 15),
            .completed, "Plegar la categoría no ocultó sus subcategorías."
        )
        _ = app.waitForSettledLayout(of: header, timeout: 5)
        header.tap()
        let back = NSPredicate(format: "count == %d", before)
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: back, object: lines)], timeout: 15),
            .completed, "Desplegarla no las devolvió."
        )
    }

    func test_agregarLinea_pideLaSubcategoria_antesDeGuardar() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        app.openReport("flujoDeCaja")
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_setup_view"].firstMatch.waitForExistence(timeout: 15))

        let create = app.buttons["primary_button"]
        var tries = 0
        while !(create.exists && create.isHittable), tries < 14 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(create.exists, "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15), "El plan no se creó.")
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) { skip.tap(); _ = skip.waitForNonExistence(timeout: 5) }

        let add = app.buttons["cashflow_add_line_expense"]
        tries = 0
        while !(add.exists && add.isHittable), tries < 14 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(add.exists, "No está «Agregar línea».")
        add.tap()
        let fromExpenses = app.buttons["cashflow_add_from_expenses"]
        XCTAssertTrue(fromExpenses.waitForExistence(timeout: 5))
        fromExpenses.tap()

        // La semilla `realista` siembra las categorías de gasto con subcategorías.
        let category = app.buttons.matching(identifier: "cashflow_add_category").firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        category.tap()
        let hint = app.staticTexts["cashflow_add_pick_subcategory"]
        XCTAssertTrue(hint.waitForExistence(timeout: 3), "No pide elegir la subcategoría.")
        let save = app.buttons["toolbar_save_button"]
        if save.exists { XCTAssertFalse(save.isEnabled, "Deja guardar una línea por categoría.") }

        // La primera que aún no está en el plan: las que ya tienen línea salen apagadas, con «En tu plan» (27-nov-2026).
        let sub = app.buttons.matching(identifier: "cashflow_add_subcategory")
            .matching(NSPredicate(format: "enabled == true")).firstMatch
        XCTAssertTrue(sub.waitForExistence(timeout: 3), "Todas las subcategorías ya están en el plan.")
        sub.tap()
        XCTAssertTrue(hint.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_add_limit_amount"].firstMatch.waitForExistence(timeout: 3),
                      "No enseña el límite con que nace la línea.")
    }
}
