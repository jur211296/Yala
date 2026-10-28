//
//  GroupOpeningBalanceMemberUITests.swift
//  YalaUITests
//
//  Card t3fq · el saldo inicial de una persona ya aceptada, desde su menú en Miembros.
//
//  Hasta el 2026-10-28 solo se llegaba bajando a la sección «Saldos iniciales» (o por la pregunta que sale al aceptar), y
//  el formulario no tenía fecha. Estos casos recorren lo que Jürgen pidió: el menú «···» de Beto ofrece «Saldo inicial»,
//  el formulario llega con Beto en «Quién debe» y con su fecha, y al guardar el saldo aparece en Miembros y como
//  registro del grupo.
//
//  El perfil `grupos` siembra un grupo creado por mí con Ana y Beto activos y ningún saldo inicial.
//

import XCTest

final class GroupOpeningBalanceMemberUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchToMembers() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la tarjeta del grupo.")
        XCTAssertTrue(card.waitForHittable(timeout: 10), "La tarjeta del grupo existe pero no es alcanzable.")
        card.tap()
        let members = app.buttons["group_members_button"]
        XCTAssertTrue(members.waitForExistence(timeout: 15), "El detalle no montó.")
        members.tap()
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

    /// Abre «Saldo inicial» desde el menú de Beto y deja el formulario a la vista.
    private func openOpeningBalanceFromBetosMenu(_ app: XCUIApplication) {
        let actions = reveal(app, app.buttons["group_member_actions_Beto"])
        XCTAssertTrue(actions.waitForExistence(timeout: 10), "Beto no tiene menú de acciones.")
        actions.tap()
        // Dentro de un `Menu` el id no llega a la accesibilidad (regla de testing.md): por la etiqueta.
        let entry = app.buttons["Saldo inicial"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "El menú de Beto no ofrece «Saldo inicial».")
        attachScreenshot("despues-1-menu-de-beto")
        entry.tap()
        XCTAssertTrue(
            app.buttons["opening_balance_debtor"].waitForExistence(timeout: 5),
            "«Saldo inicial» no abrió el formulario."
        )
    }

    /// El menú de la persona lleva al formulario con ella puesta y con la fecha a la vista.
    func test_memberMenu_opensTheFormWithThatPersonAndADate() {
        let app = launchToMembers()
        openOpeningBalanceFromBetosMenu(app)

        let debtor = app.buttons["opening_balance_debtor"]
        XCTAssertTrue(
            debtor.label.contains("Beto"),
            "«Quién debe» no llega con Beto puesto: dice «\(debtor.label)»."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["opening_balance_date"].waitForExistence(timeout: 5),
            "El formulario no pide la fecha del saldo inicial."
        )
        attachScreenshot("despues-2-formulario")
    }

    /// Guardar desde el menú deja el saldo en Miembros y como registro del grupo.
    func test_savingFromTheMemberMenu_showsItInMembersAndAsAGroupRecord() {
        let app = launchToMembers()
        openOpeningBalanceFromBetosMenu(app)

        app.buttons["opening_balance_creditor"].tap()
        let ana = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Ana")).firstMatch
        XCTAssertTrue(ana.waitForExistence(timeout: 5), "El selector de «A quién» no ofrece a Ana.")
        ana.tap()
        XCTAssertTrue(
            app.buttons["opening_balance_creditor"].waitForExistence(timeout: 5),
            "El selector no volvió al formulario."
        )

        let amount = app.textFields["opening_balance_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("75")
        let save = app.buttons["opening_balance_save"]
        XCTAssertTrue(save.waitForHittable(timeout: 5), "«Guardar» no se puede tocar.")
        save.tap()
        XCTAssertTrue(
            app.buttons["opening_balance_debtor"].waitForNonExistence(timeout: 10),
            "El formulario no se cerró al guardar."
        )

        let edge = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "opening_balance_edge_")).firstMatch
        XCTAssertTrue(reveal(app, edge).waitForExistence(timeout: 5), "El saldo guardado no aparece en «Saldos iniciales».")
        attachScreenshot("despues-3-miembros-con-el-saldo")

        // Cerrar Miembros: el saldo es un registro del grupo.
        app.buttons["Cerrar"].firstMatch.tap()
        let record = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "group_opening_balance_row_")).firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 10), "El saldo inicial no aparece en los registros del grupo.")
        attachScreenshot("despues-4-registro-del-grupo")
    }
}
