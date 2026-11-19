//
//  FlujoDetalleMesUITests.swift
//  YalaUITests
//
//  S2 del replanteo del flujo de caja (18-nov-2026): el detalle del mes cuenta una sola historia («Empezaste con ·
//  Entró · Salió · Terminas con») y cada categoría agrupa sus líneas y se pliega.
//

import XCTest

final class FlujoDetalleMesUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func skipCoachMarkIfShown(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
    }

    private func openFreshPlan(_ app: XCUIApplication) {
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openReport("flujoDeCaja")
        XCTAssertTrue(element(app, "cashflow_setup_view").waitForExistence(timeout: 15),
                      "La vista de Flujo de caja no montó.")
        skipCoachMarkIfShown(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15), "El plan no se creó.")
        skipCoachMarkIfShown(app)
    }

    /// La historia del mes en curso: empezaste, entró (con lo que falta), salió (con lo que falta) y la cifra grande. Y
    /// ninguna de las cifras retiradas.
    func test_elMesEnCurso_cuentaUnaSolaHistoria() {
        let app = XCUIApplication()
        openFreshPlan(app)
        for id in ["cashflow_story_started", "cashflow_story_in", "cashflow_story_out", "cashflow_month_end_closing"] {
            XCTAssertTrue(element(app, id).waitForExistence(timeout: 8), "Falta \(id) en la historia del mes.")
        }
        for retirado in ["cashflow_change_starting_balance", "cashflow_month_projected_end", "cashflow_month_net_line",
                         "cashflow_month_end_today"] {
            XCTAssertFalse(element(app, retirado).exists, "Volvió \(retirado).")
        }
    }

    /// Una categoría se pliega: sus líneas se van y la cabecera sigue.
    func test_unaCategoria_sePliega() {
        let app = XCUIApplication()
        openFreshPlan(app)
        let header = app.buttons.matching(identifier: "cashflow_group_header").firstMatch
        var drags = 0
        while !(header.exists && header.isHittable), drags < 8 { app.swipeUp(velocity: .slow); drags += 1 }
        XCTAssertTrue(header.exists, "No hay ninguna categoría en el detalle del mes.")
        let lines = app.buttons.matching(identifier: "cashflow_detail_line")
        let before = lines.count
        header.tap()
        let fewer = NSPredicate(format: "count < %d", before)
        let folded = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: fewer, object: lines)], timeout: 5)
        XCTAssertEqual(folded, .completed, "Plegar la categoría no quitó sus líneas (\(before) antes).")
        XCTAssertTrue(header.exists, "La cabecera desapareció al plegar.")
        header.tap()
        let back = NSPredicate(format: "count == %d", before)
        let unfolded = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: back, object: lines)], timeout: 5)
        XCTAssertEqual(unfolded, .completed, "Desplegar no devolvió las líneas.")
    }
}
