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
        var tries = 0
        while !header.isHittable || header.frame.minY > app.frame.height * 0.6, tries < 6 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
        let lines = app.descendants(matching: .any).matching(identifier: "cashflow_setup_line")
        let before = lines.count
        XCTAssertGreaterThan(before, 0)
        header.tap()
        let fewer = NSPredicate(format: "count < %d", before)
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: fewer, object: lines)], timeout: 5),
            .completed, "Plegar la categoría no ocultó sus subcategorías."
        )
        header.tap()
        let back = NSPredicate(format: "count == %d", before)
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: back, object: lines)], timeout: 5),
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

        let sub = app.buttons.matching(identifier: "cashflow_add_subcategory").firstMatch
        XCTAssertTrue(sub.waitForExistence(timeout: 3))
        sub.tap()
        XCTAssertTrue(hint.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_add_limit_amount"].firstMatch.waitForExistence(timeout: 3),
                      "No enseña el límite con que nace la línea.")
    }
}
