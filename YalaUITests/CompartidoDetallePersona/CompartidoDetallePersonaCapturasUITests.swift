//
//  CompartidoDetallePersonaCapturasUITests.swift
//  YalaUITests
//
//  Capturas del detalle de persona (lote 2 de Compartido, 26-nov-2026), en claro y en oscuro: el detalle de grupo de hoy
//  (el molde, el «antes») y el de Ana en sus tres páginas, con el menú del filtro abierto y con un grupo elegido. No
//  afirma nada del diseño; las aserciones viven en `CompartidoDetallePersonaUITests`.
//

import XCTest

final class CompartidoDetallePersonaCapturasUITests: XCTestCase {

    /// Oscuro es el tema por defecto; claro va con `-userTheme 1`.
    private let variants: [(name: String, args: [String])] = [("oscuro", []), ("claro", ["-userTheme", "1"])]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 1.0)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func select(_ app: XCUIApplication, _ id: String) {
        let chip = app.buttons[id]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        chip.tap()
        XCTAssertTrue(chip.waitForSelected())
    }

    func test_capturas() {
        for variant in variants {
            let app = XCUIApplication()
            app.launchForUITest(
                pro: true, seed: "grupos", deeplink: "groups",
                extraArguments: ["-uitest-seed-group-cross-debts"] + variant.args)
            XCTAssertTrue(app.waitForUITestReady())

            // Antes: el detalle de grupo de hoy, el molde del de persona.
            let groupCard = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
            XCTAssertTrue(groupCard.waitForExistence(timeout: 15))
            groupCard.tap()
            XCTAssertTrue(app.buttons["group_detail_tab_records"].waitForExistence(timeout: 10))
            attach(app, "antes-grupo-gastos-\(variant.name)")
            select(app, "group_detail_tab_balances")
            attach(app, "antes-grupo-saldos-\(variant.name)")
            select(app, "group_detail_tab_stats")
            attach(app, "antes-grupo-estadisticas-\(variant.name)")
            app.buttons["group_detail_back"].tap()

            // Después: Ana desde el chip Personas.
            let peopleChip = app.buttons["compartido_chip_personas"]
            XCTAssertTrue(peopleChip.waitForExistence(timeout: 10))
            peopleChip.tap()
            let ana = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'compartido_person_card' AND label BEGINSWITH 'Ana,'"))
                .firstMatch
            XCTAssertTrue(ana.waitForExistence(timeout: 10))
            attach(app, "personas-\(variant.name)")
            ana.tap()
            XCTAssertTrue(app.descendants(matching: .any)["compartido_person_detail_ready"].waitForExistence(timeout: 15))
            attach(app, "despues-persona-gastos-\(variant.name)")

            select(app, "compartido_person_tab_balances")
            attach(app, "despues-persona-saldos-todos-\(variant.name)")
            let filter = app.descendants(matching: .any)["compartido_detail_filter"]
            XCTAssertTrue(filter.waitForExistence(timeout: 5))
            filter.tap()
            let piso = app.buttons["Piso compartido"].firstMatch
            XCTAssertTrue(piso.waitForExistence(timeout: 5))
            attach(app, "despues-persona-filtro-menu-\(variant.name)")
            piso.tap()
            attach(app, "despues-persona-saldos-un-grupo-\(variant.name)")

            select(app, "compartido_person_tab_stats")
            attach(app, "despues-persona-estadisticas-un-grupo-\(variant.name)")
            filter.tap()
            let all = app.buttons.matching(NSPredicate(format: "label == 'Todos los grupos' OR label == 'All groups'"))
                .firstMatch
            if all.waitForExistence(timeout: 5) { all.tap() }
            attach(app, "despues-persona-estadisticas-todos-\(variant.name)")

            select(app, "compartido_person_tab_balances")
            let settleAll = app.buttons["compartido_settle_all"]
            if settleAll.waitForExistence(timeout: 5) {
                settleAll.tap()
                attach(app, "despues-persona-saldar-todo-\(variant.name)")
            }
            app.terminate()
        }
    }
}

fileprivate extension XCUIElement {
    /// El chip quedó elegido (el del lote 1 es privado de su fichero).
    func waitForSelected(timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
