//
//  SeedRelaunchT4UITests.swift
//  YalaUITests
//
//  Lote T4 de la cola 2.3 (datos de prueba y relanzar). Cada caso fija una de las cinco cards:
//
//  1. `grupos-con-heredero` pinta «Transferir y salir»; `grupos` (sin heredero) no.
//  2. `grupos-rechazado`: la tarjeta ofrece salir sin abrir el detalle; el aviso del detalle quita el grupo.
//  3. Relanzar con la misma siembra y sin `-uitest-reset` no duplica los datos.
//  4. Relanzar sin `-uitest-reset` conserva el Panel de usuario nuevo.
//  5. El «OK» del aviso de cierre bloqueado se pulsa por su identificador (en `SessionExitsPerCellUITests`).
//
//  Scheme Yala Dev, sin sleeps, por `accessibilityIdentifier`.
//

import XCTest

final class SeedRelaunchT4UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func openFirstGroupSettings(_ app: XCUIApplication) {
        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "No apareció la tarjeta del grupo.")
        card.tap()
        let gear = app.buttons["group_settings_button"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15), "El detalle no montó.")
        gear.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
    }

    /// Baja por la lista hasta que el elemento se pueda tocar: la lista monta solo las celdas visibles.
    @discardableResult
    private func reveal(_ app: XCUIApplication, _ element: XCUIElement, swipes: Int = 8) -> XCUIElement {
        var tries = 0
        while !(element.exists && element.isHittable) && tries < swipes {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    // MARK: - 1 · Heredero

    /// Con los co-miembros identificados (`userID` + `memberKey`) hay heredero, y el dueño con deuda ve «Transferir y
    /// salir». Discrimina: es el mismo dataset que `grupos`, que no lo pinta (caso de abajo).
    func test_heirProfile_offersTransferAndLeave() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos-con-heredero", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openFirstGroupSettings(app)

        let transfer = reveal(app, app.buttons["group_settings_transfer"])
        XCTAssertTrue(transfer.waitForExistence(timeout: 5),
                      "Con heredero, Ajustes del grupo no ofrece «Transferir y salir».")
    }

    /// El control: `grupos` sigue siendo el callejón sin heredero. Se baja hasta «Eliminar», que va DESPUÉS de
    /// «Transferir y salir», para que la ausencia no sea por no haber llegado.
    func test_groupsProfile_keepsTheNoHeirDeadEnd() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openFirstGroupSettings(app)

        let delete = reveal(app, app.buttons["group_settings_delete"])
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "No se llegó a «Eliminar».")
        XCTAssertFalse(app.buttons["group_settings_transfer"].exists,
                       "`grupos` ofrece «Transferir y salir»: perdimos el caso del dueño sin heredero.")
    }

    // MARK: - 2 · Solicitud rechazada

    /// En la lista, tocar la tarjeta de un grupo con mi solicitud rechazada pregunta si salir y NO abre el detalle.
    /// Confirmar la salida desde aquí pasa por el servidor (`leave_group`), que en el simulador no hay: solo se cancela.
    func test_rejectedProfile_cardOffersToLeave_withoutOpeningTheDetail() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos-rechazado", deeplink: "groups", icloudIdentity: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.buttons.matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "El grupo rechazado no aparece en la lista.")
        XCTAssertTrue(card.waitForHittable(timeout: 10), "La tarjeta no es alcanzable.")
        card.tap()

        // Por estructura (`alerts`), no por texto.
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10),
                      "Tocar la tarjeta de un grupo rechazado no ofreció salir.")
        XCTAssertFalse(app.buttons["group_members_button"].exists,
                       "Se abrió el detalle de un grupo donde me rechazaron.")
    }

    /// El aviso de rechazo del detalle (al que se llega por un enlace o una notificación) y su botón, que quita el grupo
    /// de ESTE teléfono sin pasar por el servidor. Dos arranques: el enlace `seeded-first` se resuelve contra el grupo
    /// que publicó la siembra del primero.
    func test_rejectedProfile_detailShowsTheNotice_andItsButtonRemovesTheGroup() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos-rechazado", icloudIdentity: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.terminate()

        app.launchForUITest(reset: false, pro: true, seed: nil, deeplinkURL: "yala://groups/seeded-first",
                            icloudIdentity: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente en el relanzamiento.")

        let leave = app.buttons["group_rejected_leave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 20), "El detalle no enseña el aviso de solicitud rechazada.")
        leave.tap()

        XCTAssertTrue(leave.waitForNonExistence(timeout: 15), "«Salir del grupo» no cerró el detalle.")
        XCTAssertFalse(app.buttons.matching(identifier: "group_card").firstMatch.waitForExistence(timeout: 5),
                       "Tras «Salir del grupo» el grupo rechazado sigue en la lista.")
    }

    // MARK: - 3 · Relanzar con la misma siembra

    /// `grupos` siembra dos grupos. Relanzar con el mismo perfil y sin reset daba cuatro.
    func test_relaunchWithTheSameSeedAndNoReset_doesNotDuplicate() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let cards = app.buttons.matching(identifier: "group_card")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 30), "No se montó la lista de Grupos.")
        let first = cards.count
        XCTAssertGreaterThan(first, 0)
        app.terminate()

        app.launchForUITest(reset: false, pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente en el relanzamiento.")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 30), "No se montó la lista en el relanzamiento.")
        XCTAssertEqual(cards.count, first, "Relanzar con la misma siembra y sin reset duplicó los grupos.")
    }

    // MARK: - 4 · Panel de usuario nuevo tras relanzar

    /// El fallo salía en arranques alternos (la corrida que partía de un disco vacío sí escribía), así que se miden dos
    /// parejas reset → relanzamiento: una de las dos cae siempre en la rama que perdía el Panel.
    func test_relaunchWithoutReset_keepsTheNewUserPanel() {
        let app = XCUIApplication()
        for round in 1...2 {
            app.launchForUITest()
            XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente (ronda \(round), con reset).")
            XCTAssertTrue(element(app, "panel_section_planificacion").waitForExistence(timeout: 15),
                          "El Panel no montó (ronda \(round)).")
            app.terminate()

            app.launchForUITest(reset: false, seed: nil)
            XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente (ronda \(round), sin reset).")
            XCTAssertTrue(element(app, "panel_section_planificacion").waitForExistence(timeout: 15),
                          "El Panel no montó tras relanzar (ronda \(round)).")
            XCTAssertFalse(element(app, "panel_section_distribucion").exists,
                           "Relanzar sin reset enseñó Distribución: se perdió el Panel de usuario nuevo (ronda \(round)).")
            app.terminate()
        }
    }
}
