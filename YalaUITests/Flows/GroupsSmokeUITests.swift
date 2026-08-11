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

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Aterriza DIRECTO en el tab Grupos vía `-uitest-deeplink groups`, sin pasar por el dashboard
    /// de "Más".
    ///
    /// Antes se navegaba por UI: tab "Más" → scroll → card `more_card_groups`. Eso **no es
    /// alcanzable de forma determinista en iOS 27.0** y costó media tarde de diagnóstico: la card
    /// vive en un `LazyVGrid` que no materializa la celda hasta scrollearla, y en 27.0 ningún swipe
    /// sintético la revela. Medido el 2026-07-29 con el mismo binario: **8/8 verde en iOS 26.4 con
    /// UN solo swipe · 1/8 en 27.0**, con 93 swipes sobre el elemento Aplicación y 81 sobre el
    /// `scrollView` —las dos vías— sin que la celda aparezca nunca. No es flake (los fallos se
    /// agrupaban entre 27,7 y 28,0 s), no es el orden de las suites (falla igual aislada) ni el
    /// disco (mismo patrón con 22 GB y con 66 GB libres). Detalle en la Lista Negra de
    /// TESTING-STRATEGY.md.
    ///
    /// Estos tests verifican las PANTALLAS de Grupos, no cómo se llega a ellas, así que el deeplink
    /// prueba exactamente lo suyo y deja de depender de un scroll que el runtime no honra. La
    /// navegación "Más → Grupos" queda como cobertura NO determinista, declarada en
    /// `qa/coverage-index.json` — el mismo trato que ya reciben `groups-bridge-personal` y
    /// `groups-pending-approval-reconnect` (ver la cabecera de este fichero).
    ///
    /// El tab Grupos sí monta bien en 27.0: `test_groupExpenseFromPanelFAB`, que llega por el FAB
    /// del Panel, es el único de los ocho que pasaba antes de este cambio.
    private func launchOnGroups() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// groups-crud-balances-settlements: la lista de grupos monta con el grupo del seed.
    func test_groupsContainerMountsWithSeededGroup() {
        let app = launchOnGroups()

        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "group_card").firstMatch.waitForExistence(timeout: 10),
            "GroupsContainerView no montó la tarjeta del grupo sembrado."
        )
    }

    /// Variante de `launchOnGroups()` con sesión de nube FINGIDA y consent de Grupos ya aceptado.
    ///
    /// Con `groupsBackendEnabled` ON —lo que ocurre en TODO XCUITest bajo `Yala Dev`— abrir el form de
    /// crear grupo exige AMBAS cosas: `GroupCreateRoutingLogic.route` rutea a sign-in sin sesión, y al
    /// consent con sesión pero sin consent. En los dos casos el form no llega a montarse, que es lo que
    /// puso este test en rojo tras el flip `5490544d`. Ninguno de los dos args crea backend real: el
    /// guardado seguiría muriendo en el guard del JWT, y este test no guarda — solo abre el formulario.
    /// El helper es aparte para que los otros siete casos conserven sus launch args byte-idénticos.
    private func launchOnGroupsWithSession() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups",
                            cloudSession: true, groupsConsent: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// groups-form: el FAB despliega el menú y "Nuevo grupo" abre el formulario de crear grupo.
    /// (Con ≥1 grupo elegible el FAB es expandible; el seed `grupos` cumple esa condición.)
    func test_groupFormOpens() {
        let app = launchOnGroupsWithSession()

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

    /// groups-form: con «Moneda única para deudas» activado, tocar la fila de divisa abre el
    /// selector de moneda.
    ///
    /// **Este test es el pin de un bug de PRODUCTO, no un smoke de montaje.** El label del botón
    /// de la fila es un `HStack` con `Spacer()` y sin fondo relleno; mientras el
    /// `.contentShape(Rectangle())` vivió en el `Button` en vez de dentro del label, el hueco
    /// central de la fila no era tocable y **solo respondían los glifos de los extremos**. XCUITest
    /// sintetiza el tap en el centro del frame de accesibilidad, que cae exacto en ese hueco ⇒
    /// `.tap()` sobre la fila es el mutante natural del fix: devolver el `contentShape` al `Button`
    /// deja este test en rojo y ninguno de los otros siete se entera. Medido el 2026-08-07 en
    /// iPhone 17 Pro / iOS 26.5 (dos taps sobre la MISMA fila y la MISMA `y`: sobre el glifo abre,
    /// al centro no corre ni la acción). No es flake — es determinista, y a un dedo humano que
    /// apunte al medio de la fila le pasaba igual.
    func test_groupFormCurrencyRowOpensSelector() {
        let app = launchOnGroupsWithSession()

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

        // La fila de divisa solo existe con el toggle ON.
        let toggle = app.switches["group_form_single_currency_toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "No apareció el toggle de moneda única.")
        toggle.tap()

        let currencyRow = app.buttons["group_form_currency_row"]
        XCTAssertTrue(
            currencyRow.waitForExistence(timeout: 5),
            "El toggle no reveló la fila de divisa (group_form_currency_row)."
        )
        currencyRow.tap()

        // El selector monta con su sección de recomendadas, donde USD está SIEMPRE (regional +
        // USD/EUR/GBP) y sin necesidad de scroll.
        XCTAssertTrue(
            app.buttons["currency_selector_row_USD"].waitForExistence(timeout: 5),
            "El tap al CENTRO de la fila de divisa no abrió CurrencySelectorView — el hueco del Spacer volvió a quedar muerto."
        )
    }

    /// groups-expense-form: desde el tab, FAB → "Nuevo gasto" abre el composer con el chip de
    /// grupo editable (2 grupos en el seed) y el cambio de grupo desde el selector.
    func test_groupExpenseFromTabFAB() {
        let app = launchOnGroups()

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
    /// abre el composer "Nuevo gasto" allí (integración Panel → Grupos). La opción ya no está
    /// gateada por nada (el código beta se retiró en 2.1) y el seed `grupos` siembra cuentas
    /// personales (FAB del Panel habilitado) + 2 grupos elegibles.
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
        let app = launchOnGroups()

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

    /// groups-crud-balances-settlements: tocar un gasto del feed abre el detalle
    /// read-only (detent medium) — NO el editor; el botón Editar lo reemplaza por
    /// el editor en large. Cubre el flujo de dos fases (commit 233544fa).
    func test_groupExpenseDetailThenEdit() {
        let app = launchOnGroups()

        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        card.tap()

        // Fase 1: el tap abre el detalle read-only. Su botón Editar debe montar y
        // el campo editable de monto NO debe existir todavía (es read-only).
        let expenseRow = app.buttons["group_expense_row_Mercado"]
        XCTAssertTrue(expenseRow.waitForExistence(timeout: 10), "No apareció la fila del gasto 'Mercado'.")
        expenseRow.tap()

        let editButton = app.buttons["group_expense_detail_edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "No montó el detalle del gasto (group_expense_detail_edit).")
        XCTAssertFalse(
            app.textFields["group_expense_amount"].exists,
            "El detalle read-only no debería exponer el campo editable de monto."
        )

        // Fase 2: Editar baja el detalle y sube el editor (large) con el campo de monto.
        editButton.tap()
        XCTAssertTrue(
            app.textFields["group_expense_amount"].waitForExistence(timeout: 5),
            "El editor no montó tras tocar Editar en el detalle."
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
        let app = launchOnGroups()

        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        card.tap()

        // Toca un gasto del feed → abre el detalle read-only (medium); "Editar"
        // sube el editor en large (flujo de dos fases, commit 233544fa).
        let expenseRow = app.buttons["group_expense_row_Mercado"]
        XCTAssertTrue(expenseRow.waitForExistence(timeout: 10), "No apareció la fila del gasto 'Mercado' en el feed.")
        expenseRow.tap()

        let editButton = app.buttons["group_expense_detail_edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "No apareció el botón Editar del detalle del gasto.")
        editButton.tap()

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
        let app = launchOnGroups()

        let gear = app.buttons["groups_global_settings_button"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "No apareció el botón de ajustes globales de grupos.")
        gear.tap()

        XCTAssertTrue(
            app.switches["groups_bridge_toggle"].waitForExistence(timeout: 5),
            "GroupsGlobalSettingsView no montó (groups_bridge_toggle)."
        )
    }
}
