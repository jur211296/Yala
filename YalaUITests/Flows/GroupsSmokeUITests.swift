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

        // La card Grupos vive en la sección "Más herramientas" (la última del
        // dashboard de "Más", tras Estadísticas/Planificación/Reportes), dentro
        // de un LazyVGrid: no se instancia hasta scrollearla a la vista. Bajamos
        // hasta que aparezca antes de tapearla.
        let groupsRow = app.buttons["more_card_groups"]
        var scrollAttempts = 0
        while !groupsRow.exists && scrollAttempts < 8 {
            app.swipeUp()
            scrollAttempts += 1
        }
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

    /// groups-form: el FAB despliega el menú y "Nuevo grupo" abre el formulario de crear grupo.
    /// (Con ≥1 grupo elegible el FAB es expandible; el seed `grupos` cumple esa condición.)
    func test_groupFormOpens() {
        let app = launch()
        openGroups(app)

        let fab = app.buttons["groups_fab_new"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de Grupos.")
        fab.tap()

        let newGroup = app.buttons["groups_fab_new_group"]
        XCTAssertTrue(newGroup.waitForExistence(timeout: 5), "No apareció la opción 'Nuevo grupo' del FAB.")
        newGroup.tap()

        XCTAssertTrue(
            app.textFields["group_form_name_input"].waitForExistence(timeout: 5),
            "GroupFormView no montó (group_form_name_input)."
        )
    }

    /// groups-expense-form: desde el tab, FAB → "Nuevo gasto" abre el composer con el chip de
    /// grupo editable (2 grupos en el seed) y el cambio de grupo desde el selector.
    func test_groupExpenseFromTabFAB() {
        let app = launch()
        openGroups(app)

        let fab = app.buttons["groups_fab_new"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB de Grupos.")
        fab.tap()

        let newExpense = app.buttons["groups_fab_new_expense"]
        XCTAssertTrue(newExpense.waitForExistence(timeout: 5), "No apareció la opción 'Nuevo gasto' del FAB.")
        newExpense.tap()

        XCTAssertTrue(
            app.textFields["group_expense_amount"].waitForExistence(timeout: 5),
            "El composer de gasto no montó (group_expense_amount)."
        )

        // El chip arranca con el primer grupo elegible ("Viaje a Cusco"). Con 2 grupos en el
        // seed es EDITABLE (Button), su a11y label es "Grupo: <nombre>".
        let chip = app.descendants(matching: .any).matching(identifier: "group_expense_group_chip").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "No apareció el chip de grupo en el composer.")
        XCTAssertTrue(chip.label.contains("Viaje a Cusco"), "El chip no mostró el grupo inicial. label=\(chip.label)")
        chip.tap()

        // El selector de grupo lista las opciones (filas con id prefijo group_picker_row_).
        // Targeteamos la fila por identifier para no chocar con el group_card de la lista de fondo.
        let limaRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'group_picker_row_' AND label CONTAINS[c] 'Viaje a Lima'")
        ).firstMatch
        XCTAssertTrue(limaRow.waitForExistence(timeout: 5), "El selector de grupo no listó 'Viaje a Lima'.")
        limaRow.tap()

        // El composer se remonta con el grupo nuevo: el chip pasa a reflejar "Viaje a Lima".
        let switched = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS[c] 'Viaje a Lima'"),
            object: chip
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [switched], timeout: 8),
            .completed,
            "El chip no reflejó el cambio a 'Viaje a Lima' tras elegirlo en el selector."
        )
        XCTAssertTrue(
            app.textFields["group_expense_amount"].waitForExistence(timeout: 5),
            "El composer no se remontó tras cambiar de grupo."
        )
    }

    /// groups-expense-form: desde el FAB del PANEL, la opción "Grupo" navega al tab Grupos y
    /// abre el composer "Nuevo gasto" allí (integración Panel → Grupos). El gate beta se
    /// desbloquea en uitest (la opción aparece) y el seed `grupos` siembra cuentas personales
    /// (FAB del Panel habilitado) + 2 grupos elegibles.
    func test_groupExpenseFromPanelFAB() {
        let app = launch()

        // Arranca en el tab Panel (default). El FAB del Panel despliega su menú de opciones.
        let fab = app.buttons["fab_new_transaction"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB del Panel.")
        fab.tap()

        let groupOption = app.buttons["panel_fab_group"]
        XCTAssertTrue(groupOption.waitForExistence(timeout: 5), "No apareció la opción 'Grupo' del FAB del Panel.")
        groupOption.tap()

        // El tap navega al tab Grupos y abre el composer allí: su textField de monto debe montar.
        XCTAssertTrue(
            app.textFields["group_expense_amount"].waitForExistence(timeout: 10),
            "El composer de gasto no montó tras tocar 'Grupo' en el FAB del Panel."
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

    /// groups-expense-form: editar un gasto del feed → botón papelera del toolbar →
    /// confirmar en el confirmationDialog → el gasto se borra de la lista y el sheet
    /// cierra. Cubre el botón de eliminar añadido al toolbar del form (commit 22774f8e),
    /// que el resto del smoke no ejercita. El seed `grupos` crea "Viaje a Cusco" con
    /// 9 gastos donde el usuario es owner → puede participar → onDelete cableado.
    /// "Mercado" es un gasto de ESTE mes (sección superior, visible sin scroll) y su
    /// descripción es única en el seed → identifier de fila estable.
    func test_groupExpenseDeleteFromFormToolbar() {
        let app = launch()
        openGroups(app)

        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        card.tap()

        // Toca un gasto del feed → abre el form en modo edición (con onDelete).
        let expenseRow = app.buttons["group_expense_row_Mercado"]
        XCTAssertTrue(expenseRow.waitForExistence(timeout: 10), "No apareció la fila del gasto 'Mercado' en el feed.")
        expenseRow.tap()

        // El form de edición monta (mismo campo de monto que el smoke de creación).
        let amountField = app.textFields["group_expense_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "GroupExpenseFormView no montó en modo edición.")

        // Botón de papelera del toolbar (solo en modo edición con onDelete != nil).
        let deleteButton = app.buttons["group_expense_delete"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "No apareció el botón de eliminar en el toolbar del form.")
        deleteButton.tap()

        // Confirma en el confirmationDialog. Se desambigua por `app.sheets` (gotcha:
        // GroupRecordsView monta otro confirmationDialog con el mismo título "Eliminar").
        let confirm = app.sheets.buttons["group_expense_delete_confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No apareció el botón destructivo del confirmationDialog.")
        confirm.tap()

        // El sheet del form cierra → el campo de monto desaparece.
        XCTAssertTrue(amountField.waitForNonExistence(timeout: 10), "El form no se cerró tras eliminar el gasto.")
        // Y el gasto desaparece del feed.
        XCTAssertTrue(expenseRow.waitForNonExistence(timeout: 10), "El gasto eliminado sigue en el feed.")
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
