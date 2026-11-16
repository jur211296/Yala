//
//  GroupOpeningBalanceAdminUITests.swift
//  YalaUITests
//
//  Card yd2w · cualquier admin del grupo gestiona los saldos iniciales, no solo quien lo creó.
//
//  Hasta el 2026-10-31 la app solo enseñaba «Saldos iniciales» al dueño: en el grupo Matri Jürgen es admin y la opción ni
//  aparecía. El perfil `grupos-invitado` siembra «Viaje a Cusco» con Ana como dueña; con `-uitest-invitee-admin`, «Tú»
//  entra como admin sin ser dueño. Sin el flag eres un miembro normal: ese caso es el control, y sigue sin ver nada.
//

import XCTest

final class GroupOpeningBalanceAdminUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchToMembers(asAdmin: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true,
            seed: "grupos-invitado",
            deeplink: "groups",
            extraArguments: asAdmin ? ["-uitest-invitee-admin"] : []
        )
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la tarjeta del grupo.")
        XCTAssertTrue(card.waitForHittable(timeout: 10), "La tarjeta del grupo existe pero no es alcanzable.")
        card.tap()
        let members = app.buttons["group_members_button"]
        XCTAssertTrue(members.waitForExistence(timeout: 15), "El detalle no montó.")
        members.tap()
        // Discriminante de las aserciones negativas: Miembros está a la vista, con Beto y su saldo.
        XCTAssertTrue(
            app.descendants(matching: .any)["group_member_balance_Beto"].waitForExistence(timeout: 10),
            "Miembros no montó (no aparece el saldo de Beto)."
        )
        return app
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

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Un admin que no es el dueño ve la sección «Saldos iniciales» y «Saldo inicial» en el menú de cada persona.
    func test_adminWhoIsNotTheOwner_seesOpeningBalancesInMembers() {
        let app = launchToMembers(asAdmin: true)
        attachScreenshot("1-miembros")

        let add = reveal(app, app.buttons["opening_balance_add"])
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Un admin no dueño no ve «Añadir saldo inicial» en Miembros.")
        attachScreenshot("2-seccion-saldos-iniciales")

        let actions = reveal(app, app.buttons["group_member_actions_Beto"])
        actions.tap()
        // Dentro de un `Menu` el id no llega a la accesibilidad (regla de testing.md): por la etiqueta.
        XCTAssertTrue(
            app.buttons["Saldo inicial"].firstMatch.waitForExistence(timeout: 5),
            "El menú de Beto no le ofrece «Saldo inicial» a un admin no dueño."
        )
        attachScreenshot("3-menu-de-beto")
    }

    /// Un admin no dueño crea un saldo inicial, lo ve en el detalle con Editar y Eliminar, y lo borra.
    func test_adminWhoIsNotTheOwner_addsEditsAndDeletesAnOpeningBalance() {
        let app = launchToMembers(asAdmin: true)

        let add = reveal(app, app.buttons["opening_balance_add"])
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Un admin no dueño no ve «Añadir saldo inicial».")
        add.tap()

        app.buttons["opening_balance_debtor"].tap()
        let beto = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Beto")).firstMatch
        XCTAssertTrue(beto.waitForExistence(timeout: 5), "El selector de «Quién debe» no ofrece a Beto.")
        beto.tap()
        XCTAssertTrue(app.buttons["opening_balance_creditor"].waitForExistence(timeout: 5))
        app.buttons["opening_balance_creditor"].tap()
        let ana = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Ana")).firstMatch
        XCTAssertTrue(ana.waitForExistence(timeout: 5), "El selector de «A quién» no ofrece a Ana.")
        ana.tap()

        let amount = app.textFields["opening_balance_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("75")
        let save = app.buttons["opening_balance_save"]
        XCTAssertTrue(save.waitForHittable(timeout: 5), "«Guardar» no se puede tocar.")
        save.tap()
        XCTAssertTrue(
            app.buttons["opening_balance_debtor"].waitForNonExistence(timeout: 10),
            "El formulario no se cerró al guardar: el servicio rechazó a un admin no dueño."
        )

        let edge = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "opening_balance_edge_")).firstMatch
        XCTAssertTrue(reveal(app, edge).waitForExistence(timeout: 5), "El saldo guardado no aparece en «Saldos iniciales».")
        attachScreenshot("4-saldo-creado")

        // El detalle del registro ofrece Editar y Eliminar al admin.
        app.buttons["group_members_close"].tap()
        let record = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "group_opening_balance_row_")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 10), "El saldo inicial no aparece en los registros del grupo.")
        record.tap()
        XCTAssertTrue(
            app.buttons["group_opening_balance_detail_edit"].waitForExistence(timeout: 5),
            "El detalle no ofrece «Editar» a un admin no dueño."
        )
        let delete = app.buttons["group_opening_balance_detail_delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "El detalle no ofrece «Eliminar» a un admin no dueño.")
        attachScreenshot("5-detalle-con-editar-y-eliminar")

        delete.tap()
        let confirm = app.buttons["group_opening_balance_detail_delete_confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No salió la confirmación de borrado.")
        confirm.tap()
        XCTAssertTrue(
            record.waitForNonExistence(timeout: 10),
            "El saldo inicial sigue en los registros: el servicio no dejó borrarlo a un admin no dueño."
        )
    }

    /// Rellena el formulario abierto con «quién debe», «a quién» y el monto, y toca «Guardar».
    private func fillAndSave(_ app: XCUIApplication, debtor: String, creditor: String, amount: String) {
        XCTAssertTrue(app.buttons["opening_balance_debtor"].waitForExistence(timeout: 5))
        app.buttons["opening_balance_debtor"].tap()
        let debtorRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", debtor)).firstMatch
        XCTAssertTrue(debtorRow.waitForExistence(timeout: 5), "El selector de «Quién debe» no ofrece a \(debtor).")
        debtorRow.tap()
        XCTAssertTrue(app.buttons["opening_balance_creditor"].waitForExistence(timeout: 5))
        app.buttons["opening_balance_creditor"].tap()
        let creditorRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", creditor)).firstMatch
        XCTAssertTrue(creditorRow.waitForExistence(timeout: 5), "El selector de «A quién» no ofrece a \(creditor).")
        creditorRow.tap()
        let field = app.textFields["opening_balance_amount"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(amount)
        let save = app.buttons["opening_balance_save"]
        XCTAssertTrue(save.waitForHittable(timeout: 5), "«Guardar» no se puede tocar.")
        save.tap()
    }

    /// Lote 2.3 de Grupos (10-nov): añadir un saldo inicial entre dos personas que ya tienen uno lo reemplazaba sin
    /// avisar, en cualquier sentido. Ahora pregunta; «Cancelar» deja el formulario y el saldo como estaban, y
    /// «Reemplazar» guarda lo de siempre (queda uno solo).
    func test_addingASecondOpeningBalanceBetweenTheSamePair_asksBeforeReplacing() {
        let app = launchToMembers(asAdmin: true)

        let add = reveal(app, app.buttons["opening_balance_add"])
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        fillAndSave(app, debtor: "Beto", creditor: "Ana", amount: "75")
        // Control: el primero no pregunta nada, se guarda y cierra.
        XCTAssertFalse(app.buttons["opening_balance_replace_confirm"].exists, "El primer saldo ya preguntó.")
        XCTAssertTrue(app.buttons["opening_balance_debtor"].waitForNonExistence(timeout: 10), "El primero no se guardó.")

        // El segundo, en el otro sentido entre las mismas dos personas.
        reveal(app, app.buttons["opening_balance_add"]).tap()
        fillAndSave(app, debtor: "Ana", creditor: "Beto", amount: "30")
        let replace = app.buttons["opening_balance_replace_confirm"].firstMatch
        XCTAssertTrue(replace.waitForExistence(timeout: 5), "Reemplazar el saldo de Beto y Ana no preguntó antes.")
        attachScreenshot("6-pregunta-antes-de-reemplazar")

        app.buttons["opening_balance_replace_cancel"].firstMatch.tap()
        XCTAssertTrue(app.buttons["opening_balance_debtor"].waitForExistence(timeout: 5),
                      "«Cancelar» cerró el formulario.")

        app.buttons["opening_balance_save"].tap()
        XCTAssertTrue(replace.waitForExistence(timeout: 5), "Al volver a guardar no preguntó.")
        replace.tap()
        XCTAssertTrue(app.buttons["opening_balance_debtor"].waitForNonExistence(timeout: 10),
                      "«Reemplazar» no guardó.")
        let edges = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "opening_balance_edge_"))
        XCTAssertTrue(reveal(app, edges.firstMatch).waitForExistence(timeout: 5))
        XCTAssertEqual(edges.count, 1, "Reemplazar dejó dos saldos iniciales entre Ana y Beto.")
    }

    /// CONTROL: un miembro que no es admin sigue sin ver los saldos iniciales.
    func test_memberWhoIsNotAdmin_stillDoesNotSeeOpeningBalances() {
        let app = launchToMembers(asAdmin: false)
        let add = reveal(app, app.buttons["opening_balance_add"])
        XCTAssertFalse(add.exists, "Un miembro normal ve «Añadir saldo inicial».")
        // Sin ser admin no hay menú de acciones por persona, y con él tampoco «Saldo inicial».
        XCTAssertFalse(app.buttons["group_member_actions_Beto"].exists, "Un miembro normal tiene el menú de admin de Beto.")
    }
}
