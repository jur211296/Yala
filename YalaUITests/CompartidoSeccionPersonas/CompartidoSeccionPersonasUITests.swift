//
//  CompartidoSeccionPersonasUITests.swift
//  YalaUITests
//
//  Lote 1 de Compartido (26-nov-2026): la pestaña lleva los chips «Grupos | Personas»; Grupos sigue como hoy y
//  Personas enseña una tarjeta por persona, con el botón de la barra que le toca a cada chip.
//

import XCTest

final class CompartidoSeccionPersonasUITests: XCTestCase {

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

    func test_chips_switchBetweenGroupsAndPeople_withTheirToolbarButton() {
        let app = launch()

        let groupsChip = app.buttons["compartido_chip_grupos"]
        let peopleChip = app.buttons["compartido_chip_personas"]
        XCTAssertTrue(groupsChip.waitForExistence(timeout: 15), "Faltan los chips de Compartido.")
        XCTAssertTrue(peopleChip.exists)
        XCTAssertTrue(groupsChip.isSelected, "Compartido abre en Grupos.")

        // Grupos, como hoy: tarjetas de grupo, fila de captura y «Nuevo grupo» en la barra.
        let groupCard = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(groupCard.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["groups_toolbar_new_group"].exists)
        XCTAssertFalse(app.buttons["compartido_toolbar_add_person"].exists)

        peopleChip.tap()
        XCTAssertTrue(peopleChip.waitForSelected(), "El chip Personas no quedó elegido.")

        let personCard = app.descendants(matching: .any).matching(identifier: "compartido_person_card").firstMatch
        XCTAssertTrue(personCard.waitForExistence(timeout: 10), "Personas no enseña ninguna tarjeta.")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "group_card").firstMatch.exists,
                       "Personas sigue enseñando tarjetas de grupo.")
        XCTAssertTrue(app.buttons["compartido_toolbar_add_person"].exists, "Falta «Añadir persona» en la barra.")
        XCTAssertFalse(app.buttons["groups_toolbar_new_group"].exists)

        groupsChip.tap()
        XCTAssertTrue(groupCard.waitForExistence(timeout: 10), "Volver a Grupos no trae las tarjetas.")
        XCTAssertTrue(app.buttons["groups_toolbar_new_group"].exists)
    }

    func test_people_cardNamesWhereYouShare() {
        let app = launch()
        let peopleChip = app.buttons["compartido_chip_personas"]
        XCTAssertTrue(peopleChip.waitForExistence(timeout: 15))
        peopleChip.tap()

        // Ana está en «Viaje a Cusco» y en «Piso compartido» con la misma cuenta: una sola tarjeta que nombra los dos.
        let ana = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'compartido_person_card' AND label BEGINSWITH 'Ana,'"))
        XCTAssertTrue(ana.firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(ana.count, 1, "Ana sale repetida: la cuenta no la juntó entre grupos.")
        let label = ana.firstMatch.label
        XCTAssertTrue(label.contains("Viaje a Cusco") && label.contains("Piso compartido"),
                      "La tarjeta de Ana no dice dónde comparten: \(label)")
    }

    /// `grupos-saldado`: «Viaje a Lima» queda a cero con Caro, que baja a «Ver liquidadas», plegada al empezar. En «Viaje
    /// a Cusco» el saldo del grupo es cero pero, con «Menos pagos» apagado, Ana te debe y le debes a Beto: siguen arriba,
    /// igual que en la tarjeta del grupo.
    func test_people_settledPersonGoesToTheSettledFold() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos-saldado", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady())
        let peopleChip = app.buttons["compartido_chip_personas"]
        XCTAssertTrue(peopleChip.waitForExistence(timeout: 15))
        peopleChip.tap()

        let toggle = app.buttons["compartido_settled_toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "Falta «Ver liquidadas».")
        let caroActive = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'compartido_person_card' AND label BEGINSWITH 'Caro,'"))
        XCTAssertEqual(caroActive.count, 0, "Caro está a mano y sigue entre las pendientes.")
        let settled = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'compartido_settled_card' AND label BEGINSWITH 'Caro,'"))
        XCTAssertFalse(settled.firstMatch.exists, "Las liquidadas tienen que empezar plegadas.")
        toggle.tap()
        XCTAssertTrue(settled.firstMatch.waitForExistence(timeout: 5), "«Ver liquidadas» no enseña a Caro.")
    }
}

private extension XCUIElement {
    func waitForSelected(timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
