//
//  YalaIACloudExploreConsentUITests.swift
//  YalaUITests
//
//  Yala IA con la cuenta en la nube (decisiones 1A y 4A de Jürgen, 2026-10-18):
//
//  - Con el camino ampliado disponible, la primera pregunta enseña N1 antes de salir. «Ahora no» la envía igual y N1
//    no vuelve a salir.
//  - En privado no sale nunca.
//  - En la burbuja, un enlace a yala-app.pe se puede tocar y uno a otro dominio sale como texto.
//
//  Sin red: `-uitest-chat-reply pizza` contesta sin llamar a nadie (la pregunta entra en el hilo igual), y
//  `-uitest-ai-cloud-explore` finge la nube y el flag, no la decisión. Qué ruta toma la pregunta lo fija
//  `YalaIAChatRoutingTests`.
//

import XCTest

final class YalaIACloudExploreConsentUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func openChat(cloud: Bool, links: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true,
            deeplink: "records",
            aiChatReady: true,
            chatConversation: links,
            extraArguments: ["-uitest-chat-suggestions", "-uitest-chat-reply", "pizza"]
                + (cloud ? ["-uitest-ai-cloud-explore"] : [])
                + (links ? ["-uitest-chat-links"] : [])
        )
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let chatEntry = app.buttons["fab_chat"]
        XCTAssertTrue(chatEntry.waitForExistence(timeout: 15), "No aparece la entrada de Yala IA en Registros.")
        chatEntry.tap()
        XCTAssertTrue(app.textFields["chat_input"].waitForExistence(timeout: 10), "No se abrió Yala IA.")
        return app
    }

    private func send(_ text: String, in app: XCUIApplication) {
        let input = app.textFields["chat_input"]
        input.tap()
        input.typeText(text)
        let send = app.buttons["chat_send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5), "Con texto, debe salir enviar.")
        send.tap()
    }

    private func message(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    private func n1Alert(in app: XCUIApplication) -> XCUIElement {
        app.alerts.matching(NSPredicate(format: "label == %@", "Yala IA con tu cuenta en la nube")).firstMatch
    }

    func test_cloud_firstQuestionAsksN1Once_andNotNowStillSendsIt() {
        let app = openChat(cloud: true)

        send("Primera pregunta", in: app)
        let alert = n1Alert(in: app)
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "La primera pregunta en la nube debe enseñar N1.")
        XCTAssertTrue(
            alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "movimientos de cualquier fecha con su nota"))
                .firstMatch.exists,
            "El aviso no trae el texto N1."
        )
        XCTAssertFalse(message("Primera pregunta", in: app).exists, "La pregunta no puede salir antes de contestar N1.")

        alert.buttons["Ahora no"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
        XCTAssertTrue(message("Primera pregunta", in: app).waitForExistence(timeout: 5), "«Ahora no» debe enviar la pregunta.")

        // La respuesta del perfil (una card de gasto) tarda un momento; la segunda pregunta va cuando ha llegado.
        XCTAssertTrue(app.buttons["chat_draft_save"].firstMatch.waitForExistence(timeout: 15), "No llegó la respuesta.")

        send("Segunda pregunta", in: app)
        XCTAssertTrue(message("Segunda pregunta", in: app).waitForExistence(timeout: 5), "La segunda pregunta debe salir.")
        XCTAssertFalse(n1Alert(in: app).exists, "N1 sale una sola vez.")
    }

    func test_private_neverAsksN1() {
        let app = openChat(cloud: false)

        send("Pregunta en privado", in: app)
        XCTAssertTrue(message("Pregunta en privado", in: app).waitForExistence(timeout: 5), "La pregunta debe salir.")
        XCTAssertFalse(n1Alert(in: app).exists, "En privado N1 no sale.")
    }

    func test_answerBubble_onlyTheYalaLinkIsTappable() {
        let app = openChat(cloud: false, links: true)

        let paragraph = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "este enlace")).firstMatch
        XCTAssertTrue(paragraph.waitForExistence(timeout: 10), "No se ve el párrafo con los dos enlaces.")
        XCTAssertTrue(
            app.links.matching(NSPredicate(format: "label == %@", "ayuda de Yala")).firstMatch.exists,
            "El enlace a yala-app.pe debe poder tocarse."
        )
        XCTAssertFalse(
            app.links.matching(NSPredicate(format: "label == %@", "este enlace")).firstMatch.exists,
            "El enlace a otro dominio debe salir como texto."
        )
    }
}
