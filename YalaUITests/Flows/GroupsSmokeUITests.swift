//
//  GroupsSmokeUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest "no-crash" (smoke) del subsistema de Grupos (gastos
//  compartidos). Cubre 4 áreas montando su vista principal con el seed `grupos`
//  (1 grupo "Viaje a Cusco", 3 miembros, 3 gastos):
//   - groups-crud-balances-settlements → GroupsContainerView (lista de grupos)
//   - groups-form → GroupFormView (crear grupo)
//   - groups-expense-form → GroupExpenseFormView (registrar gasto compartido)
//   - groups-bridge-settings-optout → GroupsGlobalSettingsView (ajustes de bridge)
//  NOTA (memoria/CLAUDE.md): el XCUITest de grupos confirma NO-CRASH / montaje,
//  no el display correcto (cálculos de balances, etc.). Las áreas
//  groups-bridge-personal (servicio sin UI, ~60 tests pure-logic) y
//  groups-pending-approval-reconnect (requiere CKShare real) NO son alcanzables
//  de forma determinista → reclasificadas a agentic.
//  El tab Grupos vive oculto en "Más" (config default [panel, statistics, planning]).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class GroupsSmokeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navega al tab Grupos (oculto en "Más"): tab "Más" (4º del tab bar, tras
    /// panel/statistics/planning) → card Grupos del dashboard de "Más".
    private func openGroups(_ app: XCUIApplication) {
        let moreTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "No apareció el tab Más.")
        moreTab.tap()

        let groupsRow = app.buttons["more_card_groups"]
        XCTAssertTrue(groupsRow.waitForExistence(timeout: 5), "No apareció la card Grupos en Más.")
        groupsRow.tap()
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// groups-crud-balances-settlements: la lista de grupos monta con el grupo del seed.
    func test_groupsContainerMountsWithSeededGroup() {
        let app = launch()
        openGroups(app)

        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "group_card").firstMatch.waitForExistence(timeout: 10),
            "GroupsContainerView no montó la tarjeta del grupo sembrado."
        )
    }

    /// groups-form: el FAB abre el formulario de crear grupo.
    func test_groupFormOpens() {
        let app = launch()
        openGroups(app)

        let fab = app.buttons["groups_fab_new"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de crear grupo.")
        fab.tap()

        XCTAssertTrue(
            app.textFields["group_form_name_input"].waitForExistence(timeout: 5),
            "GroupFormView no montó (group_form_name_input)."
        )
    }

    /// groups-expense-form: grupo → detalle → FAB nuevo gasto → formulario de gasto.
    func test_groupExpenseFormOpens() {
        let app = launch()
        openGroups(app)

        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        card.tap()

        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de nuevo gasto en el detalle.")
        fab.tap()

        XCTAssertTrue(
            app.textFields["group_expense_amount"].waitForExistence(timeout: 5),
            "GroupExpenseFormView no montó (group_expense_amount)."
        )
    }

    /// groups-bridge-settings-optout: el botón de ajustes globales abre la vista
    /// con el toggle del bridge.
    func test_groupsGlobalSettingsOpens() {
        let app = launch()
        openGroups(app)

        let gear = app.buttons["groups_global_settings_button"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "No apareció el botón de ajustes globales de grupos.")
        gear.tap()

        XCTAssertTrue(
            app.switches["groups_bridge_toggle"].waitForExistence(timeout: 5),
            "GroupsGlobalSettingsView no montó (groups_bridge_toggle)."
        )
    }
}
