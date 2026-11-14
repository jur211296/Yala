//
//  GruposAjustesLote23ChicoUITests.swift
//  YalaUITests
//
//  Lote chico de 2.3 de Grupos y Ajustes. Discriminante, punto por punto, con el código de antes:
//  1 · la cabecera de Grupos decía «Debes S/ 10.00» con «Piso compartido» en «Le debes a Ana S/ 40 · Beto te debe S/ 30»;
//  2 · «Menos pagos entre ustedes» nacía apagado en un grupo nuevo;
//  3 · Saldos no decía que Yala había juntado las deudas ni dejaba ver las de cada par;
//  4 · Ajustes tenía «Presupuestos» (abría las estrellas del Panel) y «Pagos planificados» (te sacaba de Ajustes), y
//      «Favoritos» a secas; Configurar Panel no tenía «Presupuestos en el Panel»;
//  5 · «Solo gastos» vivía en Personalización › «Modo de uso» y no en «Cómo usas Yala».
//

import XCTest

final class GruposAjustesLote23ChicoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 1 · Cabecera de la lista = tarjetas

    func test_groupsList_headerSaysWhatTheCardsSay() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups",
                            extraArguments: ["-uitest-seed-group-cross-debts"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Piso compartido")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No apareció «Piso compartido».")
        XCTAssertTrue(card.label.contains("Le debes a Ana S/ 40.00"), card.label)

        let iOwe = element(app, "groups_hero_iowe")
        XCTAssertTrue(iOwe.waitForExistence(timeout: 10), "No apareció «Debes» en la cabecera.")
        // «Piso compartido» es el único grupo de la semilla en el que debes algo: la cabecera dice sus S/ 40.
        XCTAssertTrue(iOwe.label.contains("S/ 40.00"), "La cabecera no suma lo que dice la tarjeta: \(iOwe.label)")
        capture(app, "1-lista-grupos")
    }

    // MARK: - 2 · Grupo nuevo con «Menos pagos» encendido

    func test_newGroup_startsWithMenosPagosOn() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", cloudSession: true, groupsConsent: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Desde el 2026-11-14 «Nuevo grupo» va en la barra (con grupos) y en la fila solo sin grupos: vale cualquiera.
        let newGroup = app.buttons.matching(NSPredicate(format: "identifier IN %@", ["groups_toolbar_new_group", "groups_action_new_group"])).firstMatch
        XCTAssertTrue(newGroup.waitForExistence(timeout: 15), "No apareció «Nuevo grupo».")
        newGroup.tap()
        let more = app.buttons["group_form_more_options"]
        XCTAssertTrue(more.waitForExistence(timeout: 10), "No se abrió el formulario de grupo.")
        more.tap()

        let simplify = app.switches["group_form_simplify_toggle"]
        XCTAssertTrue(simplify.waitForExistence(timeout: 5), "No apareció «Menos pagos entre ustedes».")
        XCTAssertEqual(simplify.value as? String, "1", "«Menos pagos» tiene que nacer encendido en un grupo nuevo.")
        capture(app, "2-nuevo-grupo")
    }

    // MARK: - 3 · La línea al pie de Saldos

    func test_balances_saysDebtsWereCombined_andShowsEachPair() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups",
                            extraArguments: ["-uitest-seed-group-cross-debts", "-uitest-seed-group-cross-debts-simplified"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Piso compartido")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No apareció «Piso compartido».")
        card.tap()
        let tab = app.buttons["group_detail_tab_balances"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "No apareció la pestaña de saldos.")
        tab.tap()

        let note = element(app, "group_balances_menos_pagos_note")
        scrollTo(app, note)
        XCTAssertTrue(note.label.hasPrefix("Yala juntó las deudas"), note.label)
        // Juntadas: Beto → Ana S/ 70 y tú → Ana S/ 10. Se pueden saldar.
        XCTAssertTrue(labelled(app, "S/ 70.00").exists, "No se ve la deuda juntada de Beto a Ana.")
        let settleButtons = app.buttons.matching(
            NSPredicate(format: "identifier IN %@", ["group_debt_settle", "group_debt_settle_others"]))
        let settleBefore = settleButtons.count
        XCTAssertGreaterThan(settleBefore, 0, "Las juntadas tienen que poder saldarse.")
        capture(app, "3-saldos-juntadas")

        let toggle = app.buttons["group_balances_menos_pagos_toggle"]
        XCTAssertTrue(toggle.exists, "No hay «Ver las deudas de cada par».")
        XCTAssertEqual(toggle.label, "Ver las deudas de cada par")
        toggle.tap()

        // De cada par: tú → Ana 40, Beto → Ana 40, Beto → tú 30. Solo para mirar: sin «Saldar».
        let pairsNote = element(app, "group_balances_menos_pagos_note")
        XCTAssertTrue(pairsNote.waitForExistence(timeout: 5))
        XCTAssertTrue(pairsNote.label.hasPrefix("Así quedan las deudas de cada par"), pairsNote.label)
        XCTAssertTrue(labelled(app, "S/ 30.00").waitForExistence(timeout: 5), "No se ven las deudas de cada par.")
        XCTAssertFalse(labelled(app, "S/ 70.00").exists, "Siguen las juntadas con las de cada par a la vista.")
        XCTAssertEqual(settleButtons.count, 0, "Las de cada par no se saldan (había \(settleBefore) con las juntadas).")
        capture(app, "3-saldos-cada-par")

        XCTAssertEqual(app.buttons["group_balances_menos_pagos_toggle"].label, "Ver con menos pagos")
        app.buttons["group_balances_menos_pagos_toggle"].tap()
        XCTAssertTrue(labelled(app, "S/ 70.00").waitForExistence(timeout: 5), "No volvieron las juntadas.")
    }

    // MARK: - 4 · Ajustes: filas que abren lo que dicen (B1)

    func test_settings_rowsSayWhatTheyOpen() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let favorites = app.buttons["profile_favorites"]
        XCTAssertTrue(favorites.waitForExistence(timeout: 10), "No apareció la fila de favoritos.")
        XCTAssertEqual(favorites.label, "Registros favoritos")
        XCTAssertFalse(app.buttons["profile_planned"].exists, "«Pagos planificados» sigue en Ajustes.")
        XCTAssertFalse(app.buttons["Presupuestos"].exists, "«Presupuestos» sigue en Ajustes.")
        let footer = element(app, "profile_organization_footer")
        XCTAssertTrue(footer.exists, "Falta el pie que dice dónde quedó cada cosa.")
        capture(app, "4-ajustes-organizacion")
    }

    func test_configurePanel_opensBudgetsOnPanel() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let config = app.buttons["panel_sections_config"].firstMatch
        XCTAssertTrue(config.waitForExistence(timeout: 15), "No aparece «Configurar Panel».")
        config.tap()

        let row = app.buttons["panel_sections_config_budgets_on_panel"].firstMatch
        scrollTo(app, row)
        XCTAssertTrue(row.label.hasPrefix("Presupuestos en el Panel"), row.label)
        capture(app, "4-configurar-panel")
        row.tap()
        XCTAssertTrue(app.navigationBars["Presupuestos en el Panel"].waitForExistence(timeout: 10),
                      "La fila no abrió «Presupuestos en el Panel».")
        capture(app, "4-presupuestos-en-el-panel")
    }

    // MARK: - 5 · «Solo gastos» en «Cómo usas Yala» (F1)

    func test_usageMode_holdsExpensesOnly_andPersonalizationNoLonger() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let usageRow = app.buttons["profile_usage_mode"]
        scrollTo(app, usageRow)
        XCTAssertTrue(usageRow.label.hasSuffix("Yala completo"), usageRow.label)
        usageRow.tap()

        let toggle = app.switches["usage_mode_expenses_only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "«Solo gastos» no está en «Cómo usas Yala».")
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.switches.firstMatch.tap()

        let activate = app.alerts.buttons["Activar"].firstMatch
        XCTAssertTrue(activate.waitForExistence(timeout: 5), "El aviso de activar no salió.")
        XCTAssertTrue(app.alerts.buttons["Cancelar"].firstMatch.exists, "«Cancelar» no se ve.")
        capture(app, "5-solo-gastos-aviso")
        activate.tap()
        XCTAssertTrue(waitForValue(toggle, "1"), "Activar no encendió «Solo gastos».")
        capture(app, "5-como-usas-yala")

        // La fila de Ajustes dice el modo entero; Personalización ya no tiene «Modo de uso».
        let back = app.buttons["chevron.left"].firstMatch
        if back.exists { back.tap() } else { app.navigationBars.buttons.element(boundBy: 0).tap() }
        XCTAssertTrue(usageRow.waitForExistence(timeout: 10))
        XCTAssertTrue(usageRow.label.hasSuffix("Yala completo · solo gastos"), usageRow.label)
        app.openSettingsSection("profile_personalization")
        XCTAssertTrue(app.buttons["personalization_row_app_language"].waitForExistence(timeout: 10),
                      "No se abrió Personalización.")
        XCTAssertFalse(app.switches["personalization_row_expenses_only"].exists, "«Solo gastos» sigue en Personalización.")
        XCTAssertFalse(app.staticTexts["Modo de uso"].exists, "Personalización sigue con «Modo de uso».")
    }

    // MARK: - Ayudas

    /// El importe de una deuda no es un texto suelto (va oculto y se lee en la etiqueta de su tarjeta).
    private func labelled(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Baja con arrastres cortos hasta que el elemento existe y se puede tocar.
    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement, file: StaticString = #filePath,
                          line: UInt = #line) {
        _ = element.waitForExistence(timeout: 5)
        var tries = 0
        while !(element.exists && element.isHittable) && tries < 10 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            tries += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, "No se llegó a «\(element.identifier)».",
                      file: file, line: line)
    }

    private func waitForValue(_ element: XCUIElement, _ value: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("despues-\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            print("GruposAjustesLote23ChicoUITests: captura no guardada: \(error)")
        }
    }
}
