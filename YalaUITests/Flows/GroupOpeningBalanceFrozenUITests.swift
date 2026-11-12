//
//  GroupOpeningBalanceFrozenUITests.swift
//  YalaUITests
//
//  Card jqgy · en un grupo congelado (se movió a la nube de Yala y aún no volviste a entrar), «Saldos iniciales» se ve
//  pero no deja guardar, y explica por qué.
//
//  Hasta el 2026-11-01 la sección de Miembros seguía ofreciendo «Añadir saldo inicial» y abría el editor de cada saldo;
//  al guardar, el servicio lo rechazaba y salía un error. El perfil `grupos-invitado` con `-uitest-invitee-admin` deja a
//  «Tú» como admin (puede gestionar los saldos), y `-uitest-invitee-frozen` congela el grupo y siembra un saldo inicial
//  de antes de la migración (Beto le debe 50 a Ana).
//
//  El detalle del grupo ya cerraba las otras entradas con el freeze (`canCurrentUserParticipate`): en los registros un
//  grupo congelado no abre ningún detalle, y «Añadir saldo inicial» de Saldos cuelga de `canManageOpeningBalances`.
//

import XCTest

final class GroupOpeningBalanceFrozenUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchToGroup() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true,
            seed: "grupos-invitado",
            deeplink: "groups",
            extraArguments: ["-uitest-invitee-admin", "-uitest-invitee-frozen"]
        )
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la tarjeta del grupo.")
        XCTAssertTrue(card.waitForHittable(timeout: 10), "La tarjeta del grupo existe pero no es alcanzable.")
        card.tap()
        XCTAssertTrue(app.buttons["group_members_button"].waitForExistence(timeout: 15), "El detalle no montó.")
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

    /// Miembros enseña el saldo que había, sin «Añadir», sin abrir el editor y con la explicación.
    func test_frozenGroup_membersShowsOpeningBalancesReadOnlyWithExplanation() {
        let app = launchToGroup()
        app.buttons["group_members_button"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["group_member_balance_Beto"].waitForExistence(timeout: 10),
            "Miembros no montó (no aparece el saldo de Beto)."
        )

        // Discriminante: el saldo sembrado está a la vista, así que la sección se pintó.
        let edge = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "opening_balance_edge_")).firstMatch
        XCTAssertTrue(reveal(app, edge).waitForExistence(timeout: 5), "La sección «Saldos iniciales» no enseña el saldo que había.")
        attachScreenshot("1-saldos-iniciales-congelado")

        // La nota va en el pie, debajo de donde estaría «Añadir»: con ella a la vista, esa fila ya está montada.
        let note = app.descendants(matching: .any)["opening_balance_frozen_note"]
        XCTAssertTrue(reveal(app, note).waitForExistence(timeout: 5), "La sección no explica por qué no se puede cambiar.")
        XCTAssertFalse(app.buttons["opening_balance_add"].exists, "Un grupo congelado ofrece «Añadir saldo inicial».")

        // Tocar el saldo no abre el editor.
        edge.tap()
        XCTAssertFalse(
            app.buttons["opening_balance_debtor"].waitForExistence(timeout: 2),
            "Tocar un saldo inicial en un grupo congelado abre el editor."
        )

        // Sin menú de admin por persona, y desde luego sin «Saldo inicial» en él.
        let actions = app.buttons["group_member_actions_Beto"]
        if actions.exists {
            actions.tap()
            XCTAssertFalse(
                app.buttons["Saldo inicial"].firstMatch.waitForExistence(timeout: 2),
                "El menú de Beto ofrece «Saldo inicial» en un grupo congelado."
            )
        }
    }
}
