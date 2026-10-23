//
//  UXAudit22Decidido14UITests.swift
//  YalaUITests
//
//  Lote decidido 2.2 · 14 (Grupos: invitar, unirse, aprobar solicitudes y avisos), recorrido en pantalla. Lo que no se
//  puede ver en el simulador —el aviso real al ser aprobado, el enlace por WhatsApp contra la web desplegada— va al guion
//  de iPhone de las cards.
//
//  Si `TEST_RUNNER_YALA_CAPTURES` apunta a una carpeta, cada caso deja ahí su captura (`despues-*.png`).
//

import XCTest

final class UXAudit22Decidido14UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURES"], !dir.isEmpty else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        try? app.screenshot().pngRepresentation.write(to: url)
    }

    private static let inviteLink =
        "yaladev://invite?g=11111111-2222-3333-4444-555555555555&t=uitest-token&n=Depa%20Miraflores"
        + "&i=house.fill&c=E91E63&m=Luc%C3%ADa,Ana,Beto&u=Luc%C3%ADa"

    /// L12-17 · L12-18 · L12-8. La tarjeta dice a qué grupo, quién invita y quién está; al entrar, «Ya estás en «X»» con
    /// sus dos salidas y el permiso de avisos dentro, que se enciende ahí mismo.
    func test_groupCard_thenReady_withNextStepsAndNotifications() {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, inviteOnboarding: true, inviteBranded: true,
                            joinPhase: "active")

        XCTAssertTrue(app.staticTexts["invite_group_name"].waitForExistence(timeout: 30), "No salió la tarjeta del grupo.")
        XCTAssertTrue(app.staticTexts["invite_inviter"].exists, "La tarjeta no dice quién invita.")
        XCTAssertTrue(app.staticTexts["invite_members"].exists, "La tarjeta no dice quién está.")

        app.buttons["invite_join_button"].tap()

        XCTAssertTrue(app.staticTexts["invite_ready_title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["invite_ready_members"].exists, "«Ya estás en» no dice con quién.")
        XCTAssertTrue(app.buttons["invite_ready_add_expense"].exists)
        XCTAssertTrue(app.buttons["invite_ready_view_group"].exists)

        let enable = app.buttons["group_notifications_enable"]
        XCTAssertTrue(enable.waitForExistence(timeout: 10), "El permiso de avisos no se pide en «Ya estás en».")
        capture(app, "despues-2-ya-estas")
        enable.tap()
        XCTAssertTrue(app.descendants(matching: .any)["group_notifications_enabled"].waitForExistence(timeout: 10),
                      "Tras activar, la tarjeta no dice que los avisos están activados.")
    }

    /// L12-17 · EL CASO. Un enlace real sin cuenta: lo primero es la tarjeta del grupo, y su «Unirme» sigue al inicio de
    /// sesión. Antes, el enlace abría directamente «Conecta tu cuenta».
    func test_realLinkWithoutAccount_showsTheGroupBeforeSigningIn() {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, deeplinkURL: Self.inviteLink)

        let name = app.staticTexts["invite_group_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 30), "El enlace no enseñó primero el grupo.")
        XCTAssertFalse(app.buttons["groups_signin_button"].exists, "Se pidió la cuenta antes de enseñar el grupo.")
        XCTAssertTrue(app.staticTexts["invite_next_account_hint"].exists, "No dice qué viene después de «Unirme».")
        capture(app, "despues-1-invitacion")

        app.buttons["invite_join_button"].tap()
        XCTAssertTrue(app.buttons["groups_signin_button"].waitForExistence(timeout: 15),
                      "«Unirme» en la tarjeta no siguió al inicio de sesión.")
    }

    /// L12-20 · L12-8. «Solicitud enviada» promete avisar, y pide aquí el permiso para poder cumplirlo.
    func test_pendingApproval_offersTheNotificationsItPromises() {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, inviteOnboarding: true, joinPhase: "pendingApproval")
        let join = app.buttons["invite_join_button"]
        XCTAssertTrue(join.waitForExistence(timeout: 30))
        join.tap()

        XCTAssertTrue(app.buttons["invite_pending_continue"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["group_notifications_card"].waitForExistence(timeout: 10),
                      "«Te avisaremos» sin pedir el permiso de avisos.")
        capture(app, "despues-3-solicitud-enviada")
    }

    /// L12-19. Con una unión en curso, la pestaña dice que el grupo está en camino y no ofrece crear otro.
    func test_joinInProgress_tabSaysTheGroupIsOnTheWay() {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, inviteOnboarding: true, joinPhase: "waitingForZone",
                            joinSoftTimeout: "2")
        let join = app.buttons["invite_join_button"]
        XCTAssertTrue(join.waitForExistence(timeout: 30))
        join.tap()
        let exit = app.buttons["invite_slow_continue"]
        XCTAssertTrue(exit.waitForExistence(timeout: 15))
        exit.tap()

        XCTAssertTrue(app.descendants(matching: .any)["groups_empty_state_on_the_way"].waitForExistence(timeout: 20),
                      "La pestaña no dice que el grupo está en camino.")
        XCTAssertTrue(app.descendants(matching: .any)["invite_sync_banner"].exists, "Falta el chip de la unión.")
        XCTAssertFalse(app.descendants(matching: .any)["groups_empty_state"].exists,
                       "Se ofrece crear un grupo con la unión en curso.")
        capture(app, "despues-4-pestana-en-camino")
    }

    private func launchToGroupDetail(openingBalancePrompt: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos-sin-flag", deeplink: "groups", openingBalancePrompt: openingBalancePrompt,
                            icloudIdentity: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        let card = app.buttons["group_card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        XCTAssertTrue(card.waitForHittable(timeout: 10))
        card.tap()
        return app
    }

    /// L19-1. Una solicitud se ve dentro del grupo; «Revisar» lleva a su tarjeta en Miembros, que ya no la repite en la
    /// lista.
    func test_joinRequest_bannerInsideTheGroup_opensItsCardInMembers() {
        let app = launchToGroupDetail()

        let review = app.buttons["group_join_requests_review"]
        XCTAssertTrue(review.waitForExistence(timeout: 20), "La solicitud de Carla no se ve dentro del grupo.")
        // El detalle sigue asentándose al empujarse: sin esperar a que el botón sea alcanzable el toque se pierde.
        XCTAssertTrue(review.waitForHittable(timeout: 10))
        capture(app, "despues-6-detalle-solicitud")
        review.tap()

        XCTAssertTrue(app.buttons["group_member_approve_Carla"].waitForExistence(timeout: 10),
                      "«Revisar» no llevó a la tarjeta de Carla.")
        XCTAssertTrue(app.buttons["group_member_reject_Carla"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "group_member_approve_Carla").count, 1,
                       "La solicitud sale dos veces: en su tarjeta y en la lista.")
        capture(app, "despues-7-miembros-solicitud")
    }

    /// L19-2. La pregunta que sigue a aceptar, con sus dos salidas. Aceptar de verdad pide el servidor, así que la abre el
    /// seam `-uitest-opening-balance-prompt` al entrar en Miembros; el texto (en 16 idiomas) lo fija la paridad.
    func test_afterAccepting_theOpeningBalanceQuestionOffersBothAnswers() {
        let app = launchToGroupDetail(openingBalancePrompt: true)
        let members = app.buttons["group_members_button"]
        XCTAssertTrue(members.waitForExistence(timeout: 20))
        XCTAssertTrue(members.waitForHittable(timeout: 10))
        members.tap()

        XCTAssertTrue(app.buttons.matching(identifier: "opening_balance_prompt_add").firstMatch.waitForExistence(timeout: 10),
                      "Falta «Sí, apuntarlo».")
        XCTAssertTrue(app.buttons.matching(identifier: "opening_balance_prompt_skip").firstMatch.exists,
                      "Falta «No, empieza en cero».")
        capture(app, "despues-8-cuentas-pendientes")
    }

    /// L12-16. El mensaje entero de WhatsApp vale: el campo se queda con el enlace limpio y «Unirme» se enciende. El botón
    /// «Pegar» es el control del sistema y no acepta toques sintéticos: aquí se comprueba que está, y su toque va al guion
    /// de iPhone.
    func test_wholeMessage_leavesTheCleanLink_andThePasteButtonIsThere() {
        let link = "https://yala-app.pe/invite?g=11111111-2222-3333-4444-555555555555&t=uitest-token&n=Depa"
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil)
        let hero = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(hero.waitForExistence(timeout: 30))
        hero.tap()
        let inviteBranch = app.buttons["welcome_chooser_invite"]
        XCTAssertTrue(inviteBranch.waitForExistence(timeout: 10))
        inviteBranch.tap()
        let joinCard = app.buttons["welcome_groups_join"]
        XCTAssertTrue(joinCard.waitForExistence(timeout: 10))
        joinCard.tap()

        XCTAssertTrue(app.buttons["invite_recovery_paste"].waitForExistence(timeout: 10), "No hay botón «Pegar».")
        capture(app, "despues-10-pega-tu-enlace")

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Lucía te invita a «Depa» en Yala. Toca el enlace para entrar: \(link)")

        let clean = NSPredicate(format: "value == %@", link)
        expectation(for: clean, evaluatedWith: field)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["primary_button"].isEnabled, "Con el enlace dentro del mensaje, «Unirme» sigue apagado.")
        capture(app, "despues-11-mensaje-pegado")
    }
}
