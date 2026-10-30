//
//  GroupDetailChipsUITests.swift
//  YalaUITests
//
//  Barrido iOS 27 (card yc6k, 2026-10-30): la fila de chips del detalle de grupo pinta su propia elección
//  (`chipsSelection`) por delante de la pestaña montada, para animar el cambio antes de montar lo caro
//  (`NavigationChipButton.switchTab`). Lo que este caso fija es la otra mitad: cuando la pestaña cambia desde FUERA de la
//  fila —tocar el saldo de arriba—, el chip la sigue. Sin el `onChange` que los ata, la pestaña pasaba a Saldos con el
//  chip de Gastos aún elegido.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, a11y ids).
//

import XCTest

final class GroupDetailChipsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_tappingTheHeaderBalance_movesTheChipToSaldos() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos", deeplink: "groups", cloudSession: true, groupsConsent: true)

        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la tarjeta del grupo.")
        card.tap()

        let balance = app.buttons["group_header_balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 10), "No apareció el saldo de arriba del grupo.")
        balance.tap()

        let saldos = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(saldos.staticTexts["Saldos"].waitForExistence(timeout: 5),
                      "Tocar el saldo cambió de pestaña sin mover el chip: «Saldos» no enseña su nombre.")
        let records = app.buttons["group_detail_tab_records"]
        XCTAssertFalse(records.staticTexts.firstMatch.exists,
                       "El chip de Gastos sigue elegido después de pasar a Saldos.")
    }
}
