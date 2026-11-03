//
//  GroupPushOpensWithTheChangeUITests.swift
//  YalaUITests
//
//  Card th4n (TestFlight 2.2 (5)): tocar el aviso de un grupo abría el grupo correcto con los datos de antes, y el cambio
//  que avisaba solo entraba tirando para refrescar. Aquí, el grupo se abre YA con el cambio: el gasto nuevo, el gasto
//  editado o la liquidación están en pantalla en cuanto lo están las filas de antes.
//
//  El toque se finge con `-uitest-inbox-notification-tap <modo>` + `-uitest-notification-tap-link groups/seeded-first`
//  (entra por el mismo `NotificationService.routeTap` que el de verdad), y el cambio con `-uitest-group-push-change
//  <new|edit|settlement>`: una vuelta FINGIDA del canal de Grupos que aplica el cambio al acabar, como un pull. En frío y
//  con la app delante, esa vuelta sigue en vuelo cuando el grupo se abre; en segundo plano, acaba con la app fuera y el
//  grupo ya estaba abierto.
//
//  Medido con mutantes (2026-11-03): sin la espera a la vuelta en vuelo caen el caso en frío y los tres con la app
//  delante. El de segundo plano con el grupo abierto pasa también sin su arreglo (el refresco al tocar el aviso): en el
//  simulador la vuelta a primer plano recarga el detalle por su cuenta (`scenePhase` y `applyPendingChangesIfNeeded`), y
//  lo que en el iPhone se pierde no se reproduce aquí. Se queda como red de ese recorrido, no como prueba del arreglo.
//

import XCTest

final class GroupPushOpensWithTheChangeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private let link = "groups/seeded-first"
    private let change = "Cambio remoto"

    private func tapArgs(_ mode: String, kind: String) -> [String] {
        ["-uitest-inbox-notification-tap", mode, "-uitest-notification-tap-link", link, "-uitest-group-push-change", kind]
    }

    private func row(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// El detalle deja el esqueleto (`group_detail_ready`, marca solo de XCUITest: la copia redactada del esqueleto
    /// también expone las filas) y en ese mismo instante el cambio ya está, junto a las filas de antes (`anchor`).
    private func assertOpensWithTheChange(_ app: XCUIApplication, anchor: String, changed: XCUIElement, _ state: String) {
        XCTAssertTrue(row(app, "group_members_button").waitForExistence(timeout: 25),
                      "\(state): el aviso no abrió el detalle del grupo.")
        XCTAssertTrue(row(app, "group_detail_ready").waitForExistence(timeout: 15),
                      "\(state): el grupo no dejó de cargar.")
        XCTAssertTrue(changed.exists, "\(state): el grupo se abrió con los datos de antes; el cambio del aviso no estaba.")
        XCTAssertTrue(row(app, anchor).exists, "\(state): el grupo no enseñó sus gastos de antes.")
    }

    // MARK: - En frío

    /// Dos arranques: el primero siembra el grupo (y publica su id); el segundo, sin reset, es el toque con la app cerrada.
    func test_cold_newExpense_opensWithIt() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — el seed de grupos no completó.")
        app.terminate()

        app.launchForUITest(reset: false, pro: true, seed: nil, extraArguments: tapArgs("cold", kind: "new"))
        assertOpensWithTheChange(app, anchor: "group_expense_row_Mercado",
                                 changed: row(app, "group_expense_row_\(change)"), "en frío")
    }

    // MARK: - Con la app delante

    private func launchForeground(kind: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", extraArguments: tapArgs("foreground", kind: kind))
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — el seed de grupos no completó.")
        return app
    }

    func test_foreground_newExpense_opensWithIt() {
        let app = launchForeground(kind: "new")
        assertOpensWithTheChange(app, anchor: "group_expense_row_Mercado",
                                 changed: row(app, "group_expense_row_\(change)"), "delante (gasto nuevo)")
    }

    func test_foreground_editedExpense_opensWithIt() {
        let app = launchForeground(kind: "edit")
        assertOpensWithTheChange(app, anchor: "group_expense_row_Transporte",
                                 changed: row(app, "group_expense_row_\(change)"), "delante (gasto editado)")
        XCTAssertFalse(row(app, "group_expense_row_Mercado").exists, "delante (gasto editado): sigue el nombre de antes.")
    }

    func test_foreground_settlement_opensWithIt() {
        let app = launchForeground(kind: "settlement")
        let settlement = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'group_settlement_row_'")).firstMatch
        assertOpensWithTheChange(app, anchor: "group_expense_row_Mercado", changed: settlement, "delante (liquidación)")
    }

    // MARK: - En segundo plano, con ese mismo grupo abierto

    /// El grupo está abierto, la app pasa a segundo plano, el aviso la despierta y el cambio baja con ella fuera; al
    /// tocarlo, el detalle (que no se vuelve a montar) tiene que enseñarlo.
    func test_background_sameGroupOpen_showsTheChange() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups",
                            extraArguments: tapArgs("warm-tap-first", kind: "new"))
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — el seed de grupos no completó.")
        let card = row(app, "group_card")
        XCTAssertTrue(card.waitForExistence(timeout: 20), "La lista de grupos no salió.")
        card.tap()
        XCTAssertTrue(row(app, "group_expense_row_Mercado").waitForExistence(timeout: 15), "El grupo no se abrió.")
        XCTAssertFalse(row(app, "group_expense_row_\(change)").exists, "El cambio ya estaba antes del aviso.")

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 15), "Yala no pasó a segundo plano.")
        // La vuelta fingida empieza medio segundo después de salir y dura uno: acaba con la app fuera.
        Thread.sleep(forTimeInterval: 3)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "Yala no volvió delante.")

        XCTAssertTrue(row(app, "group_expense_row_\(change)").waitForExistence(timeout: 6),
                      "en segundo plano: el grupo abierto siguió con lo de antes tras tocar el aviso.")
    }
}
