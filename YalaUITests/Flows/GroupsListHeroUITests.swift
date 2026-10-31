//
//  GroupsListHeroUITests.swift
//  YalaUITests
//
//  El resumen de la lista de Grupos tras la decisión de Jürgen del 2026-10-30: «Te deben» con su monto, ninguna fila de
//  «Debes» si no debes nada, el aviso morado del neto solo en Yala completo y la lista sin buscador propio (la búsqueda
//  es la pestaña Buscar). Las filas por persona viven dentro del botón de la tarjeta, que es un solo elemento de
//  accesibilidad: su orden y su tope los fija `GroupsListBalanceLogicTests`.
//
//  La semilla `grupos` deja al usuario acreedor (Viaje a Cusco y Viaje a Lima), así que el lado «Debes» no sale.
//

import XCTest

final class GroupsListHeroUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_fullYala_showsOwedSide_netNotice_andNoSearchField() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la lista de Grupos.")
        let any = app.descendants(matching: .any)
        XCTAssertTrue(any["groups_hero_owed"].exists, "Falta «Te deben» en el resumen.")
        XCTAssertFalse(any["groups_hero_iowe"].exists, "«Debes» sale sin que el usuario deba nada.")
        XCTAssertTrue(any["groups_hero_net_notice"].exists, "Yala completo sin el aviso del neto en la moneda principal.")
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
        XCTAssertFalse(any["groups_hero_net_notice"].exists, "En Yala gratis no hay moneda principal: el aviso sobra.")
    }
}
