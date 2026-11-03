//
//  GroupsListHeroUITests.swift
//  YalaUITests
//
//  El resumen de la lista de Grupos (propuesta 2 de Jürgen, 2026-11-03): la cifra grande con el neto en la moneda
//  principal solo en Yala completo, y siempre los dos lados, «Debes» y «Te deben» (un lado vacío dice 0.00 en gris).
//  La lista no tiene buscador propio (la búsqueda es la pestaña Buscar). La barra, las líneas por divisa con su tope y
//  las filas por persona de cada tarjeta los fija `GroupsListBalanceLogicTests`.
//
//  La semilla `grupos` deja al usuario acreedor (Viaje a Cusco y Viaje a Lima): el neto va a su favor.
//

import XCTest

final class GroupsListHeroUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_fullYala_showsTheNet_bothSides_andNoSearchField() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la lista de Grupos.")
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["groups_hero_net"].exists, "Yala completo sin la cifra grande del neto en la moneda principal.")
        XCTAssertTrue(any["groups_hero_owed"].exists, "Falta «Te deben» en el resumen.")
        XCTAssertTrue(any["groups_hero_iowe"].exists, "Falta «Debes»: el lado vacío también sale, en gris.")
        XCTAssertFalse(any["groups_hero_net_notice"].exists, "Vuelve el aviso morado que sustituyó la cifra grande.")
        XCTAssertEqual(app.searchFields.count, 0, "La lista de Grupos vuelve a tener buscador.")
    }

    func test_groupsOnly_hasNoNetNotice() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "solo-grupos", groupInvite: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la lista de Grupos.")
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["groups_hero_owed"].exists, "Falta «Te deben» en el resumen de solo grupos.")
        XCTAssertFalse(any["groups_hero_net"].exists, "En Yala gratis no hay moneda principal: la cifra grande sobra.")
        XCTAssertTrue(any["groups_hero_iowe"].exists, "Sin neto, los dos lados siguen.")
    }
}
