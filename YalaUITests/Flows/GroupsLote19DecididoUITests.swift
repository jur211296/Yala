//
//  GroupsLote19DecididoUITests.swift
//  YalaUITests
//
//  Lote 19 de la auditoría UX 2.2 tal como lo decidió Jürgen (18-oct): administrar el grupo, archivar, eliminar,
//  salir y salir de varios. Convenciones: scheme Yala Dev, sin sleeps, por `accessibilityIdentifier`.
//
//  Lo que solo pasa contra el servidor (el cambio de rol de un grupo de la nube, salir de verdad) no se ejerce aquí:
//  las semillas son grupos locales. Ahí manda `GroupChangeRoleBackendTests` y el banco `qa/cloud/g22_01-local-test.sh`.
//

import XCTest

final class GroupsLote19DecididoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(seed: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: seed, deeplink: "groups", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func openFirstGroup(_ app: XCUIApplication) {
        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la tarjeta del grupo.")
        card.tap()
        XCTAssertTrue(app.buttons["group_settings_button"].waitForExistence(timeout: 15), "El detalle no montó.")
    }

    private func openSettings(_ app: XCUIApplication) {
        app.buttons["group_settings_button"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }

    /// Baja por la lista hasta que el elemento se pueda tocar. La lista monta solo las celdas visibles.
    @discardableResult
    private func reveal(_ app: XCUIApplication, _ element: XCUIElement, swipes: Int = 8) -> XCUIElement {
        var tries = 0
        while !(element.exists && element.isHittable) && tries < swipes {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    // MARK: - L19-3 · El rol en Miembros

    /// La semilla es un grupo de la nube y Beto no tiene cuenta (un hueco, `userID` nulo): el servidor no le dejaría
    /// administrar, así que la app no se lo ofrece, pero sí «Quitar del grupo». El rol se llama «Administrador».
    /// Ofrecerlo a quien tiene cuenta y el camino al servidor los fijan `GroupChangeRoleBackendTests` (en el simulador
    /// no hay servidor) y el banco `qa/cloud/g22_01-local-test.sh`.
    func test_memberWithoutAccount_isNotOfferedAdmin_andTheRoleSaysAdministrador() {
        let app = launch(seed: "grupos")
        openFirstGroup(app)
        app.buttons["group_members_button"].tap()

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@", "Administrador")).firstMatch
            .waitForExistence(timeout: 10), "La insignia del rol no dice «Administrador».")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label == %@", "Admin")).firstMatch.exists,
                       "Queda la insignia vieja «Admin».")

        let actions = reveal(app, app.buttons["group_member_actions_Beto"])
        XCTAssertTrue(actions.waitForExistence(timeout: 10), "Beto no tiene menú de acciones.")
        actions.tap()
        XCTAssertTrue(app.buttons["Quitar del grupo"].firstMatch.waitForExistence(timeout: 5),
                      "El menú no ofrece «Quitar del grupo».")
        XCTAssertFalse(app.buttons["Hacer administrador"].firstMatch.exists,
                       "Se ofrece hacer administrador a un hueco sin cuenta: el servidor lo rechazaría.")
    }

    // MARK: - L19-4 · Quitar a alguien que debe

    /// Con deuda, el aviso lleva «Saldar primero» y un «Cancelar» a la vista.
    func test_removeMemberWithDebt_offersSettleFirst() {
        let app = launch(seed: "grupos")
        openFirstGroup(app)
        app.buttons["group_members_button"].tap()

        let actions = reveal(app, app.buttons["group_member_actions_Beto"])
        XCTAssertTrue(actions.waitForExistence(timeout: 10))
        actions.tap()
        app.buttons["Quitar del grupo"].firstMatch.tap()

        let settleFirst = app.buttons["group_member_remove_settle_first"].firstMatch
        XCTAssertTrue(settleFirst.waitForExistence(timeout: 5), "Quitar a quien debe no ofrece «Saldar primero».")
        XCTAssertTrue(app.buttons["group_member_remove_with_debt_cancel"].firstMatch.exists)

        settleFirst.tap()
        let settle = app.buttons["settlement_form_save"]
        let balances = app.descendants(matching: .any)["group_balance_summary"]
        let landed = settle.waitForExistence(timeout: 8) || balances.exists
        XCTAssertTrue(landed, "«Saldar primero» no llevó ni a «Saldar» ni a Saldos.")
    }

    // MARK: - L19-8 · Archivar avisa y se deshace · L19-10 · el residuo no es deuda

    /// `grupos-saldado`: Viaje a Cusco queda a mano salvo el residuo de repartir dólares entre tres. Archivar ya no
    /// pregunta por «deudas» (era el residuo), avisa «Lo moviste a Archivados» y «Deshacer» lo devuelve a la lista.
    func test_archiveWithOnlyRoundingResidue_noDebtWarning_noticeAndUndo() {
        // El aviso dura 5 s y antes de buscarlo se gastan 2 s afirmando que no hubo pregunta: en un runner frío del CI
        // el aviso ya se había ido (nocturna 40899279330, 3 de 3). Molde: `UXAudit22Lote08UITests`.
        let app = launch(seed: "grupos-saldado", extra: ["-uitest-undo-notice-seconds", "30"])
        let cards = app.buttons.matching(identifier: "group_card")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 30))
        let before = cards.count
        openFirstGroup(app)
        openSettings(app)

        let archive = reveal(app, app.buttons["group_settings_archive"])
        XCTAssertTrue(archive.waitForExistence(timeout: 5), "Falta la fila de archivar.")
        archive.tap()

        XCTAssertFalse(app.buttons["group_settings_archive_cancel"].firstMatch.waitForExistence(timeout: 2),
                       "Archivar preguntó por deudas en un grupo cuyo único saldo es residuo de redondeo.")
        let undo = app.buttons["group_archived_undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "No salió el aviso «Lo moviste a Archivados».")
        undo.tap()
        XCTAssertTrue(cards.element(boundBy: before - 1).waitForExistence(timeout: 5),
                      "Deshacer no devolvió el grupo a la lista.")
        XCTAssertEqual(cards.count, before)
    }

    /// Con el residuo fuera, «Eliminar» se puede tocar en el grupo saldado.
    func test_deleteIsEnabled_whenTheOnlyBalanceIsRoundingResidue() {
        let app = launch(seed: "grupos-saldado")
        openFirstGroup(app)
        openSettings(app)
        let delete = reveal(app, app.buttons["group_settings_delete"])
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        XCTAssertTrue(delete.isEnabled, "Eliminar sigue bloqueado por dos céntimos de redondeo.")
        XCTAssertFalse(app.buttons["group_settings_see_balances"].exists)
    }

    // MARK: - L19-10 · Eliminar bloqueado nombra la deuda y lleva a Saldos

    func test_blockedDelete_namesTheDebt_andSeeBalancesOpensBalances() {
        let app = launch(seed: "grupos")
        openFirstGroup(app)
        openSettings(app)
        let seeBalances = reveal(app, app.buttons["group_settings_see_balances"])
        XCTAssertTrue(seeBalances.waitForExistence(timeout: 5), "El bloqueo de eliminar no ofrece «Ver los saldos».")
        let body = app.staticTexts["group_settings_delete_body"]
        XCTAssertTrue(body.exists)
        XCTAssertTrue(body.label.contains("debe"), "El bloqueo no dice quién debe: \(body.label)")
        seeBalances.tap()
        XCTAssertTrue(app.descendants(matching: .any)["group_balance_summary"].waitForExistence(timeout: 8),
                      "«Ver los saldos» no llevó a Saldos.")
    }

    // MARK: - L19-9 · Un grupo archivado lo dice

    func test_archivedGroup_showsTheBanner_andTheListKeepsItsDebt() {
        let app = launch(seed: "grupos")
        openFirstGroup(app)
        openSettings(app)
        let archive = reveal(app, app.buttons["group_settings_archive"])
        archive.tap()
        let confirm = app.sheets.buttons.matching(NSPredicate(format: "label == %@", "Archivar grupo")).firstMatch
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }

        XCTAssertTrue(app.descendants(matching: .any)["groups_archived_debt_line"].waitForExistence(timeout: 10),
                      "La lista no dice lo que se debe en el grupo archivado.")

        let showArchived = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "archivados")).firstMatch
        reveal(app, showArchived)
        showArchived.tap()
        // Archivar deja 5 s el aviso «Lo moviste a Archivados» en su ventana, sobre la franja donde cae la tarjeta
        // archivada: tocarla antes de que se vaya toca el aviso y no abre nada. En el simulador local caía 4 de 4; en el
        // runner lento del CI pasaba porque el aviso ya se había ido. El aviso tapa la franja por diseño.
        XCTAssertTrue(app.descendants(matching: .any)["group_archived_notice"].waitForNonExistence(timeout: 15),
                      "El aviso de archivado no se retiró.")
        let cards = app.buttons.matching(identifier: "group_card")
        cards.element(boundBy: cards.count - 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["group_archived_banner"].waitForExistence(timeout: 10),
                      "El detalle de un grupo archivado no lo dice.")
        XCTAssertTrue(app.buttons["group_archived_unarchive"].exists, "Quien administra no ve «Desarchivar».")
    }

    // MARK: - L19-11 · Salir con deuda

    func test_leaveWithDebt_offersSettleFirst() {
        let app = launch(seed: "grupos-invitado")
        openFirstGroup(app)
        openSettings(app)
        let leave = reveal(app, app.buttons["group_settings_leave"])
        XCTAssertTrue(leave.waitForExistence(timeout: 5))
        leave.tap()
        let settleFirst = app.buttons["group_settings_leave_settle_first"].firstMatch
        XCTAssertTrue(settleFirst.waitForExistence(timeout: 5), "Salir con deuda no ofrece «Saldar primero».")
        XCTAssertTrue(app.buttons["group_settings_leave_with_debt_cancel"].firstMatch.exists)

        // Pulsarlo de verdad: cierra Ajustes y lleva a «Saldar» (una sola deuda) o a Saldos (varias).
        settleFirst.tap()
        let settle = app.buttons["settlement_form_save"]
        let balances = app.descendants(matching: .any)["group_balance_summary"]
        let landed = settle.waitForExistence(timeout: 8) || balances.exists
        XCTAssertTrue(landed, "«Saldar primero» no llevó ni a «Saldar» ni a Saldos.")
    }

    // MARK: - L19-6 · El presupuesto en su hoja

    func test_budgetSheet_previewsSpendingAgainstTheTypedLimit_andSaves() {
        let app = launch(seed: "grupos")
        openFirstGroup(app)
        openSettings(app)
        let row = reveal(app, app.buttons["group_settings_budget_row"])
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let field = app.textFields["group_budget_sheet_amount"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "La hoja del presupuesto no montó.")
        field.typeText("100")
        XCTAssertTrue(app.descendants(matching: .any)["group_budget_sheet_preview"].waitForExistence(timeout: 5),
                      "La hoja no enseña lo gastado contra la cifra.")
        app.buttons["group_budget_sheet_save"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertFalse(field.exists, "Guardar no cerró la hoja.")
    }

    // MARK: - L19-13 · Un botón por grupo que no se pudo dejar

    func test_batchLeaveResult_offersOpeningEachGroupsSettings() {
        let app = launch(seed: "grupos-saldado", extra: ["-uitest-groups-batch-demo"])
        let gear = app.buttons["groups_global_settings_button"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        let leaveAll = reveal(app, app.buttons["groups_settings_leave_all"])
        XCTAssertTrue(leaveAll.waitForExistence(timeout: 5))
        leaveAll.tap()
        app.alerts.firstMatch.buttons["Salir de todos"].firstMatch.tap()
        XCTAssertTrue(app.buttons["batch_leave_open_settings_demo-needs-1"].waitForExistence(timeout: 5),
                      "El grupo que necesita tu decisión no tiene botón para abrir sus ajustes.")
    }
}
