//
//  GroupPendingMemberDoorUITests.swift
//  YalaUITests
//
//  La puerta del grupo para un miembro `pendingApproval` (decisión owner 2026-09-06).
//
//  El caso viene de campo: Jürgen, 2026-08-28, TestFlight 2.1 build 12, dos teléfonos. B se une por
//  enlace, queda pendiente, el grupo le sale en la lista y **al tocarlo entraba**. Veredicto: mal.
//
//  El seed es `grupos-pendiente`, y es nuevo porque ninguno de los siete servía: todos siembran al
//  usuario propio como `.active` (`grupos`, `grupos-invitado`, `grupos-saldado`, `solo-grupos`) o
//  dejan pendiente a OTRA persona con el usuario de admin (`grupos-sin-flag`). Sin un perfil donde el
//  pendiente sea uno mismo, este AC no tiene red determinista posible.
//
//  Se aterriza por deep link al TAB (`groups`) y no navegando desde «Más»: la card de ese dashboard
//  vive en un `LazyVGrid` que iOS 27.0 no materializa con swipes sintéticos (regla de área
//  `testing.md`, medido el 2026-07-29).
//

import XCTest

final class GroupPendingMemberDoorUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// El AC en un test: con el miembro pendiente, tocar la tarjeta NO abre el detalle y sí explica.
    ///
    /// **Prueba la DECISIÓN, no el flujo** (la familia de falsos verdes de `testing.md`): no hay ningún
    /// seam `-uitest-*` que fuerce el predicado — la puerta se decide contra el `status` que el seed
    /// escribió y la identidad que resuelve `cloudKitUserRecordID`. Verificado por MUTACIÓN: devolver
    /// `allowsDetailEntry` a `true` lo pone en rojo por la segunda aserción.
    func test_pendingMember_cardDoesNotOpenDetail_andExplainsWhy() {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "grupos-pendiente", deeplink: "groups", icloudIdentity: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.buttons["group_card"].firstMatch
        XCTAssertTrue(
            card.waitForExistence(timeout: 20),
            "El grupo del pendiente NO aparece en la lista. Eso NO es este arreglo: el servidor sigue "
                + "entregándoselo a propósito (`is_group_member` admite pendingApproval) y quitarlo de "
                + "la lista es la variante que el owner descartó el 2026-09-06.")
        // `exists` no implica alcanzable — regla de área: un tap sobre algo tapado se sintetiza en
        // {-1,-1} y se pierde SIN error de aserción, dejando un verde que no probó nada.
        XCTAssertTrue(
            card.waitForHittable(timeout: 10),
            "La tarjeta existe pero no es alcanzable: el tap se perdería y el test daría un falso verde.")
        card.tap()

        // 1) Se explica. Por estructura (`alerts`) y no por texto: el copy es localizado y la regla de
        //    área prohíbe targetear por él.
        XCTAssertTrue(
            app.alerts.firstMatch.waitForExistence(timeout: 10),
            "Tocar la tarjeta de un grupo pendiente no dijo NADA. Un muro mudo cumple media decisión "
                + "(no entra) y falla la otra media: el AC pide una superficie que diga en qué estado "
                + "está y qué puede hacer.")

        // 2) Y NO se entró. `group_members_button` vive en la toolbar del detalle y en ningún otro
        //    sitio, así que su ausencia es prueba inequívoca de que seguimos en la lista (la banda de
        //    balance NO sirve: el resumen global de la lista también la pinta → ambiguo).
        XCTAssertFalse(
            app.buttons["group_members_button"].waitForExistence(timeout: 3),
            "La puerta sigue abierta: el detalle del grupo se montó para un miembro pendingApproval.")
    }

    /// La otra mitad, y la que evita que este arreglo se pase de frenada: al cerrar la puerta al
    /// pendiente no se le puede cerrar a nadie más.
    ///
    /// El control positivo del camino normal (miembro `.active` → la tarjeta SÍ abre el detalle) ya lo
    /// sostiene `GroupMembersAdminUITests.launchToMembers`, con el mismo gesto y sobre el mismo id.
    /// Aquí se cubre lo que aquel no toca: que el aviso se pueda cerrar y devuelva a la lista con el
    /// grupo intacto — si el alert dejara la lista muerta, el pendiente quedaría atrapado.
    func test_pendingNotice_dismisses_andLeavesTheListUsable() {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "grupos-pendiente", deeplink: "groups", icloudIdentity: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.buttons["group_card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "No se montó la lista de Grupos.")
        XCTAssertTrue(card.waitForHittable(timeout: 10), "La tarjeta no es alcanzable.")
        card.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "No se presentó el aviso de «en revisión».")
        let dismiss = alert.buttons.firstMatch
        XCTAssertTrue(dismiss.waitForHittable(timeout: 5), "El aviso no ofrece forma de cerrarse.")
        dismiss.tap()

        // El aviso se va…
        let alertGone = NSPredicate(format: "exists == false")
        expectation(for: alertGone, evaluatedWith: alert)
        waitForExpectations(timeout: 10)

        // …y la lista sigue viva y usable (la tarjeta vuelve a aceptar un tap, no quedó tapada por el
        // alert a medio cerrar — el modo exacto del falso verde que documenta `testing.md`).
        XCTAssertTrue(
            card.waitForHittable(timeout: 10),
            "Tras cerrar el aviso la lista quedó inerte: la tarjeta ya no es alcanzable.")
    }
}
