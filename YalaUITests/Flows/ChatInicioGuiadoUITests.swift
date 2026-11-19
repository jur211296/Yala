//
//  ChatInicioGuiadoUITests.swift
//  YalaUITests
//
//  El inicio de Yala IA (encargo del 17-nov, «limpiar el chat lo más posible en cada paso»): el saludo con solo tres
//  botones; al tocar uno, se van, entra el mensaje de la persona y Yala contesta con sus opciones; al usarlas (o al
//  escribir otra cosa) las opciones se van y queda un chat normal. Sin red: las preguntas son las fijas de
//  `-uitest-chat-suggestions` y enviar contesta con `-uitest-chat-reply pizza`.
//

import XCTest

final class ChatInicioGuiadoUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func openChat(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "minimal", deeplink: "records", aiChatReady: true,
                            extraArguments: ["-uitest-chat-suggestions", "-uitest-chat-reply", "pizza"] + extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 180), "uitest_ready ausente — bootstrap/seed no completó.")
        let entry = app.buttons["stats_action_ai"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20), "No aparece la entrada de Yala IA en Registros.")
        entry.tap()
        XCTAssertTrue(app.buttons["chat_log_expense"].waitForExistence(timeout: 10), "El inicio no trae sus botones.")
        return app
    }

    /// Captura de la pantalla entera: la de la app sale descuadrada con el iPhone girado (medido en iOS 27.2).
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Los tres botones se van al tocar uno, y entra el mensaje de la persona.
    private func assertStartButtonsGone(_ app: XCUIApplication, said message: String) {
        XCTAssertTrue(app.buttons["chat_start_ask"].waitForNonExistence(timeout: 5), "Los botones del inicio siguen ahí.")
        XCTAssertFalse(app.buttons["chat_log_expense"].exists)
        XCTAssertFalse(app.buttons["chat_start_create"].exists)
        XCTAssertTrue(app.staticTexts[message].waitForExistence(timeout: 5), "Falta el mensaje «\(message)».")
    }

    // MARK: - Inicio

    func test_start_greetingAndOnlyThreeButtons() {
        let app = openChat()
        let log = app.buttons["chat_log_expense"]
        let ask = app.buttons["chat_start_ask"]
        let create = app.buttons["chat_start_create"]
        XCTAssertTrue(ask.exists && create.exists, "Faltan botones del inicio.")
        XCTAssertLessThan(log.frame.maxY, ask.frame.minY, "Rosa, índigo y turquesa, en ese orden.")
        XCTAssertLessThan(ask.frame.maxY, create.frame.minY)
        XCTAssertFalse(app.buttons.matching(identifier: "chat_suggestion").firstMatch.exists,
                       "Sin listas debajo de los botones.")
        XCTAssertFalse(app.buttons["chat_create_budget"].exists, "Sin atajos de crear en el inicio.")
        shot(app, "inicio")
    }

    // MARK: - Anotaré un gasto

    /// Tocar un ejemplo lo escribe en la caja sin enviarlo; al enviar, los ejemplos se van.
    func test_logExpense_examplesFillTheBox_andSendingClearsThem() {
        let app = openChat()
        app.buttons["chat_log_expense"].tap()
        assertStartButtonsGone(app, said: "Anotaré un gasto")

        let examples = app.buttons.matching(identifier: "chat_start_example")
        XCTAssertTrue(examples.firstMatch.waitForExistence(timeout: 5), "Yala no ofrece los ejemplos.")
        XCTAssertEqual(examples.count, 3)
        shot(app, "apuntar-1-ejemplos")

        let example = examples.element(boundBy: 0)
        let text = example.label
        example.tap()
        let input = app.textFields["chat_input"]
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "El ejemplo abre el teclado.")
        XCTAssertEqual(input.value as? String, text, "El ejemplo queda escrito en la caja.")
        // Enviar añade un mensaje y retira los ejemplos: que sigan es la prueba de que nada se envió solo. (El texto del
        // ejemplo no sirve de testigo: ya existe dentro de su propio botón.)
        XCTAssertTrue(examples.firstMatch.exists, "Sin enviar, los ejemplos siguen: nada se envió solo.")
        shot(app, "apuntar-2-caja-rellena")

        let send = app.buttons["chat_send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        send.tap()
        XCTAssertTrue(examples.firstMatch.waitForNonExistence(timeout: 10), "Al enviar, los ejemplos se van.")
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 5), "Lo enviado sale en el hilo.")
        shot(app, "apuntar-3-chat-limpio")
    }

    // MARK: - Preguntaré por mis finanzas

    /// Tocar una pregunta la envía sola, y las preguntas se van.
    func test_askFinances_aQuestionSendsItself_andTheOptionsGo() {
        let app = openChat()
        app.buttons["chat_start_ask"].tap()
        assertStartButtonsGone(app, said: "Preguntaré por mis finanzas")

        let questions = app.buttons.matching(identifier: "chat_suggestion")
        XCTAssertTrue(questions.firstMatch.waitForExistence(timeout: 5), "Yala no ofrece las preguntas de hoy.")
        XCTAssertEqual(questions.count, 3)
        shot(app, "preguntar-1-preguntas")

        let question = questions.element(boundBy: 0)
        let text = question.label
        question.tap()
        XCTAssertTrue(questions.firstMatch.waitForNonExistence(timeout: 10), "Al usar una, las preguntas se van.")
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 5), "La pregunta se envió sola.")
        shot(app, "preguntar-2-chat-limpio")
    }

    /// Si la persona escribe otra cosa, las preguntas también se van.
    func test_askFinances_typingSomethingElse_alsoClearsTheOptions() {
        let app = openChat()
        app.buttons["chat_start_ask"].tap()
        let questions = app.buttons.matching(identifier: "chat_suggestion")
        XCTAssertTrue(questions.firstMatch.waitForExistence(timeout: 5))

        let input = app.textFields["chat_input"]
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "No salió el teclado.")
        input.typeText("Taxi 30")
        let send = app.buttons["chat_send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        send.tap()
        XCTAssertTrue(questions.firstMatch.waitForNonExistence(timeout: 10), "Escribir otra cosa también las retira.")
    }

    // MARK: - Quiero crear algo

    /// Las opciones de crear abren el guiado de cada cosa, y se van.
    func test_create_optionsOpenTheGuidedFlow_andGo() {
        let app = openChat()
        app.buttons["chat_start_create"].tap()
        assertStartButtonsGone(app, said: "Quiero crear algo")

        for id in ["chat_create_budget", "chat_create_payment", "chat_create_account", "chat_create_category",
                   "chat_create_favorite", "chat_create_group"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5), "Falta la opción «\(id)».")
        }
        shot(app, "crear-1-opciones")

        app.buttons["chat_create_account"].tap()
        XCTAssertTrue(app.staticTexts["chat_guided_header"].waitForExistence(timeout: 10), "Abre el guiado de la cuenta.")
        XCTAssertFalse(app.buttons["chat_create_budget"].exists, "Al usarlas, las opciones se van.")
        XCTAssertTrue(app.staticTexts["Quiero crear una cuenta"].exists, "El pedido sale como mensaje de la persona.")
        shot(app, "crear-2-guiado")
    }

    // MARK: - Girado

    /// Con el iPhone girado, los tres botones y las opciones se leen y se tocan.
    func test_landscape_buttonsAndOptionsStayReachable() {
        let app = openChat()
        XCUIDevice.shared.orientation = .landscapeLeft
        let create = app.buttons["chat_start_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        shot(app, "girado-1-inicio")
        create.tap()
        let budget = app.buttons["chat_create_budget"]
        XCTAssertTrue(budget.waitForExistence(timeout: 5), "Las opciones de crear salen también girado.")
        shot(app, "girado-2-crear")
        XCTAssertTrue(budget.isHittable, "La primera opción se puede tocar girado.")
    }
}
