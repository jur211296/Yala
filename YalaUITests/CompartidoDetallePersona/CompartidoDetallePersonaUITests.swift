//
//  CompartidoDetallePersonaUITests.swift
//  YalaUITests
//
//  Lote 2 de Compartido (26-nov-2026): abrir una persona desde el chip Personas enseña Gastos, Saldos y Estadísticas como
//  en un grupo, con el filtro de grupo en las tres; con «Todos los grupos» se salda todo con su desglose y con un grupo
//  elegido, solo ese, con el botón de siempre. El detalle de un grupo sigue sin filtro.
//
//  Semilla: `grupos` + `-uitest-seed-group-cross-debts`. Ana está en «Viaje a Cusco» (te debe) y en «Piso compartido»
//  (le debes), con la misma cuenta.
//

import XCTest

final class CompartidoDetallePersonaUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups",
                            extraArguments: ["-uitest-seed-group-cross-debts"])
        XCTAssertTrue(app.waitForUITestReady())
        return app
    }

    /// Chip Personas → tarjeta de Ana → su detalle, ya cargado.
    private func openAna(_ app: XCUIApplication) {
        let peopleChip = app.buttons["compartido_chip_personas"]
        XCTAssertTrue(peopleChip.waitForExistence(timeout: 15), "Faltan los chips de Compartido.")
        peopleChip.tap()
        let ana = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'compartido_person_card' AND label BEGINSWITH 'Ana,'"))
            .firstMatch
        XCTAssertTrue(ana.waitForExistence(timeout: 10), "No sale la tarjeta de Ana.")
        ana.tap()
        let ready = app.descendants(matching: .any)["compartido_person_detail_ready"]
        XCTAssertTrue(ready.waitForExistence(timeout: 15), "El detalle de Ana no terminó de cargar.")
    }

    func test_person_opensWithTheThreeChipsAndTheGroupFilter() {
        let app = launch()
        openAna(app)

        for tab in ["records", "balances", "stats"] {
            XCTAssertTrue(app.buttons["compartido_person_tab_\(tab)"].exists, "Falta el chip \(tab).")
        }
        XCTAssertTrue(app.buttons["compartido_person_tab_records"].isSelected, "El detalle abre en Gastos.")
        XCTAssertTrue(app.descendants(matching: .any)["compartido_detail_filter"].waitForExistence(timeout: 5),
                      "Falta el filtro de grupo junto a la cifra.")

        // Cada fila dice su grupo.
        let tag = app.descendants(matching: .any).matching(identifier: "compartido_row_group_tag").firstMatch
        XCTAssertTrue(tag.waitForExistence(timeout: 10), "Las filas de Gastos no dicen su grupo.")

        // Saldos, con todos los grupos: saldar todo con el desglose por grupo.
        app.buttons["compartido_person_tab_balances"].tap()
        XCTAssertTrue(app.buttons["compartido_person_tab_balances"].waitForSelected())
        XCTAssertTrue(app.descendants(matching: .any)["compartido_detail_filter"].waitForExistence(timeout: 5),
                      "Saldos perdió el filtro.")
        let breakdown = app.descendants(matching: .any).matching(identifier: "compartido_settle_breakdown_row")
        XCTAssertTrue(breakdown.firstMatch.waitForExistence(timeout: 10), "Falta el desglose por grupo.")
        XCTAssertEqual(breakdown.count, 2, "El desglose de Ana debería tener sus dos grupos.")
        XCTAssertTrue(app.buttons["compartido_settle_all"].exists, "Falta «Saldar todo».")

        // Estadísticas, también con el filtro.
        app.buttons["compartido_person_tab_stats"].tap()
        XCTAssertTrue(app.buttons["compartido_person_tab_stats"].waitForSelected())
        XCTAssertTrue(app.descendants(matching: .any)["compartido_detail_filter"].waitForExistence(timeout: 5),
                      "Estadísticas perdió el filtro.")
    }

    func test_filter_oneGroup_settlesOnlyThatGroupWithTheUsualButton() {
        let app = launch()
        openAna(app)
        app.buttons["compartido_person_tab_balances"].tap()
        XCTAssertTrue(app.buttons["compartido_person_tab_balances"].waitForSelected())

        let filter = app.descendants(matching: .any)["compartido_detail_filter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.tap()
        // Dentro de un menú, por la etiqueta (`testing.md`): es el nombre de la semilla, no un texto traducido.
        let piso = app.buttons["Piso compartido"].firstMatch
        XCTAssertTrue(piso.waitForExistence(timeout: 5), "El menú del filtro no ofrece «Piso compartido».")
        piso.tap()

        XCTAssertTrue(app.buttons["group_debt_settle"].waitForExistence(timeout: 10),
                      "Con un grupo elegido, falta el «Saldar» de siempre.")
        XCTAssertFalse(app.buttons["compartido_settle_all"].exists, "Con un grupo elegido no hay «Saldar todo».")
        XCTAssertEqual(
            app.descendants(matching: .any).matching(identifier: "compartido_settle_breakdown_row").count, 0)
    }

    func test_groupDetail_hasNoGroupFilter() {
        let app = launch()
        let groupCard = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(groupCard.waitForExistence(timeout: 15))
        groupCard.tap()
        XCTAssertTrue(app.buttons["group_detail_tab_records"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["compartido_detail_filter"].exists,
                       "El detalle de un grupo no lleva el filtro de grupo.")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "compartido_row_group_tag").firstMatch.exists,
                       "Las filas de un grupo no llevan etiqueta de grupo.")
    }
}

fileprivate extension XCUIElement {
    /// El chip quedó elegido (el del lote 1 es privado de su fichero).
    func waitForSelected(timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
