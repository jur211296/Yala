//
//  ChatMessagingLayoutUITests.swift
//  YalaUITests
//
//  Yala IA con la forma de un chat de mensajería (ticket ai-chat-reads-heavier-than-a-messaging-app):
//
//  - Chat vacío: el saludo y las tres sugerencias en UNA burbuja; la fecha y los dos avisos en un solo bloque
//    arriba del hilo, y nada gris debajo de la caja de escribir.
//  - Caja de escribir: el «+» de Temas fuera, a la izquierda; dentro, el micro mientras no hay texto y enviar en
//    cuanto lo hay.
//  - Respuesta: cada párrafo es su propio texto dentro de la burbuja.
//
//  Sin red no hay sugerencias ni respuestas: `-uitest-chat-suggestions` fija las tres sugerencias y
//  `chatConversation` deja guardada una pregunta con su respuesta, y `-uitest-chat-draft` abre con dos registros
//  propuestos. Corre igual en iPhone (hoja) y en iPad (columna).
//

import XCTest

final class ChatMessagingLayoutUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func openChat(conversation: Bool = false, drafts: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true,
            deeplink: "records",
            aiChatReady: true,
            chatConversation: conversation,
            extraArguments: ["-uitest-chat-suggestions"] + (drafts ? ["-uitest-chat-draft"] : [])
        )
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let chatEntry = app.buttons["fab_chat"]
        XCTAssertTrue(chatEntry.waitForExistence(timeout: 15), "No aparece la entrada de Yala IA en Registros.")
        chatEntry.tap()
        XCTAssertTrue(app.textFields["chat_input"].waitForExistence(timeout: 10), "No se abrió Yala IA.")
        return app
    }

    /// El chat vacío: el bloque de fecha y avisos arriba, las tres sugerencias debajo dentro del saludo, y ningún
    /// aviso por debajo de la caja de escribir (antes «puede cometer errores» iba ahí).
    func test_emptyChat_noticesSitAboveTheThread_andSuggestionsLiveInTheGreeting() {
        let app = openChat()
        let input = app.textFields["chat_input"]

        let header = app.descendants(matching: .any)["chat_thread_header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "Falta el bloque de fecha y avisos arriba del hilo.")

        let suggestions = app.buttons.matching(identifier: "chat_suggestion")
        XCTAssertTrue(suggestions.firstMatch.waitForExistence(timeout: 10), "No salen las sugerencias de arranque.")
        XCTAssertEqual(suggestions.count, 3, "El chat vacío debe ofrecer tres sugerencias.")
        XCTAssertLessThan(header.frame.maxY, suggestions.firstMatch.frame.minY, "Los avisos deben ir antes del saludo.")

        let noticesBelowInput = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "cometer errores"))
            .allElementsBoundByIndex
            .filter { $0.frame.minY >= input.frame.maxY }
        XCTAssertTrue(noticesBelowInput.isEmpty, "Debajo de la caja de escribir no debe quedar ningún aviso.")
    }

    /// La caja de escribir: «+» a la izquierda, fuera de la píldora; el micro se cambia por enviar al escribir.
    func test_inputPill_topicsOutside_andMicTurnsIntoSendWhenThereIsText() {
        let app = openChat()
        let input = app.textFields["chat_input"]

        let topics = app.buttons["chat_topics"]
        XCTAssertTrue(topics.waitForExistence(timeout: 5), "Falta el «+» de Temas.")
        XCTAssertLessThanOrEqual(topics.frame.maxX, input.frame.minX, "El «+» debe ir fuera de la píldora, a la izquierda.")

        XCTAssertTrue(app.buttons["chat_mic"].exists, "Sin texto, la píldora lleva el micro.")
        XCTAssertFalse(app.buttons["chat_send"].exists, "Sin texto no hay botón de enviar.")

        input.tap()
        input.typeText("Hola")
        XCTAssertTrue(app.buttons["chat_send"].waitForExistence(timeout: 5), "Con texto, sale enviar.")
        XCTAssertFalse(app.buttons["chat_mic"].exists, "Con texto, enviar sustituye al micro.")
    }

    /// Una respuesta con dos párrafos se pinta como dos textos dentro de la burbuja, no como uno con un hueco.
    func test_answer_paragraphsAreSeparateTexts() {
        let app = openChat(conversation: true)

        let first = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Este mes llevas")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "No se ve la respuesta guardada.")
        let second = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "La mayor parte es")).firstMatch
        XCTAssertTrue(second.exists, "No se ve el segundo párrafo de la respuesta.")
        XCTAssertFalse(first.label.contains("La mayor parte es"), "Los dos párrafos salieron en un solo texto.")
        XCTAssertLessThan(first.frame.maxY, second.frame.minY, "El segundo párrafo debe ir debajo del primero.")
    }

    /// `-uitest-chat-draft` abre el chat con dos registros propuestos: el completo deja guardar y el que no tiene
    /// subcategoría no. Es el seam con el que se captura y se prueba la card sin red.
    func test_draftSeam_showsTwoProposedRecords_onlyTheCompleteOneSaves() {
        let app = openChat(drafts: true)

        let save = app.buttons.matching(identifier: "chat_draft_save")
        XCTAssertTrue(save.firstMatch.waitForExistence(timeout: 10), "No sale ninguna card de registro propuesto.")
        XCTAssertEqual(save.count, 2, "El seam debe proponer dos registros.")
        XCTAssertTrue(save.element(boundBy: 0).isEnabled, "El registro completo debe poder guardarse.")
        XCTAssertFalse(save.element(boundBy: 1).isEnabled, "Sin subcategoría no se puede guardar.")
    }

    /// La píldora de lo que falta abre el MISMO selector de subcategoría que Nuevo registro, y al elegir una la card
    /// queda lista para guardar (decisión de Jürgen, 2026-10-04: la experiencia es la de crear un registro a mano).
    func test_draftChip_opensTheNewRecordSubcategorySelector_andCompletesTheDraft() {
        let app = openChat(drafts: true)

        let chip = app.buttons["chat_draft_chip_subcategory"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "La card sin subcategoría debe ofrecer elegirla.")
        chip.tap()

        let firstSubcategory = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_"))
            .firstMatch
        XCTAssertTrue(firstSubcategory.waitForExistence(timeout: 10), "No se abrió el selector de subcategoría de Nuevo registro.")
        firstSubcategory.tap()

        XCTAssertTrue(chip.waitForNonExistence(timeout: 10), "Con subcategoría elegida, la píldora de lo que falta se va.")
        let save = app.buttons.matching(identifier: "chat_draft_save")
        XCTAssertEqual(save.count, 2)
        XCTAssertTrue(save.element(boundBy: 1).isEnabled, "Con la subcategoría elegida, el registro se puede guardar.")
    }

    /// «Detalles» abre la hoja sobre el chat, y la cuenta se elige con el selector de cuentas de Nuevo registro.
    func test_draftDetails_opensSheet_withTheNewRecordAccountSelector() {
        let app = openChat(drafts: true)

        let details = app.buttons.matching(identifier: "chat_draft_details").firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 10), "Falta «Detalles» en la card.")
        details.tap()

        let accountRow = app.buttons["chat_draft_detail_account"]
        XCTAssertTrue(accountRow.waitForExistence(timeout: 10), "No se abrió la hoja de detalles.")
        XCTAssertTrue(app.textFields["chat_input"].exists, "La hoja va sobre el chat: el chat sigue montado debajo.")
        accountRow.tap()

        let anyAccount = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "account_selector_row_"))
            .firstMatch
        XCTAssertTrue(anyAccount.waitForExistence(timeout: 10), "No se abrió el selector de cuentas de Nuevo registro.")
        anyAccount.tap()

        XCTAssertTrue(accountRow.waitForExistence(timeout: 10), "Tras elegir cuenta se vuelve a la hoja de detalles.")
    }
}
