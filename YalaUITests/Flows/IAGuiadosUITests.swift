//
//  IAGuiadosUITests.swift
//  YalaUITests
//
//  Guiados de Yala IA (encargo del 2026-11-16): pedir un presupuesto o un pago planificado en el chat abre la tarjeta
//  guiada con las piezas de Primeros pasos, pregunta solo lo que falta, enseña «Revisa antes de crear» y crea con el
//  toque final. Sin red: la frase se entiende en el teléfono, así que no hace falta fingir respuestas del servidor.
//
//  Cada pantalla deja su captura en el resultado (`XCTAttachment`, nombre `guiado-<flujo>-<n>-<paso>`): son las del
//  recorrido visual del encargo.
//

import XCTest

final class IAGuiadosUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Presupuesto, pregunta a pregunta

    func test_budget_stepByStep_endsInTheConfirmation_andCreatesIt() {
        let app = openChat()
        send("Quiero crear un presupuesto", in: app)

        let card = app.staticTexts["chat_guided_header"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "El pedido no abrió la tarjeta guiada.")
        let tile = app.buttons.matching(identifier: "chat_guided_category").firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "La primera pregunta debe ser en qué categorías.")
        shot(app, "guiado-presupuesto-1-categorias")
        tile.tap()
        app.buttons.matching(identifier: "chat_guided_category").element(boundBy: 1).tap()
        tap("chat_guided_categories_continue", in: app)

        let monthly = app.buttons["chat_guided_period_monthly"]
        XCTAssertTrue(monthly.waitForExistence(timeout: 5), "Tras las categorías va el período.")
        shot(app, "guiado-presupuesto-2-periodo")
        monthly.tap()

        let amountField = app.textFields["chat_guided_amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5), "Tras el período va el monto.")
        shot(app, "guiado-presupuesto-3-monto")
        let saving = app.buttons["chat_guided_amount_saving"]
        if saving.exists {
            saving.tap()
        } else {
            amountField.tap()
            amountField.typeText("450")
            tap("chat_guided_amount_send", in: app)
        }
        answerCurrencyIfAsked(app)

        let create = app.buttons["chat_guided_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5), "Con todo contestado, sale la confirmación.")
        XCTAssertTrue(app.buttons["chat_guided_change_amount"].exists, "Cada respuesta se puede cambiar.")
        shot(app, "guiado-presupuesto-4-confirmar")
        create.tap()

        XCTAssertTrue(app.staticTexts["chat_guided_success"].waitForExistence(timeout: 10),
                      "Tras «Crear presupuesto» sale la tarjeta de éxito.")
        XCTAssertTrue(app.buttons["chat_guided_open"].exists, "La tarjeta de éxito lleva al presupuesto.")
        shot(app, "guiado-presupuesto-5-listo")
    }

    /// Lo que la frase ya dice no se pregunta: va directo a revisar, con «Lo dijiste tú».
    func test_budget_fullSentence_goesStraightToTheConfirmation() {
        let app = openChat()
        send("Quiero un presupuesto de 300 al mes para todos mis gastos", in: app)
        answerCurrencyIfAsked(app)
        let create = app.buttons["chat_guided_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "La frase completa debe ir directo a la confirmación.")
        shot(app, "guiado-presupuesto-frase-completa")
        // Cancelar no crea nada.
        tap("chat_guided_cancel", in: app)
        XCTAssertTrue(app.staticTexts["chat_guided_cancelled"].waitForExistence(timeout: 5))
        XCTAssertFalse(create.exists)
    }

    // MARK: - Pago planificado

    func test_scheduledPayment_stepByStep_createsIt() {
        let app = openChat()
        send("Quiero anotar un pago fijo", in: app)

        XCTAssertTrue(app.staticTexts["chat_guided_header"].waitForExistence(timeout: 10))
        let other = app.buttons["chat_guided_suggestion_other"]
        if other.waitForExistence(timeout: 3) {
            shot(app, "guiado-pago-1-sugerencias")
            other.tap()
        }

        let name = app.textFields["chat_guided_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "Se pregunta el nombre del pago.")
        name.tap()
        name.typeText("Luz")
        tap("chat_guided_name_send", in: app)

        let amount = app.textFields["chat_guided_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "Tras el nombre va el monto.")
        amount.tap()
        amount.typeText("80")
        shot(app, "guiado-pago-2-monto")
        tap("chat_guided_amount_send", in: app)

        tap("chat_guided_frequency_monthly", in: app)
        let day = app.buttons["chat_guided_day_15"]
        XCTAssertTrue(day.waitForExistence(timeout: 5), "Cada mes: se pregunta el día.")
        shot(app, "guiado-pago-3-dia")
        day.tap()

        let account = app.buttons.matching(identifier: "chat_guided_account").firstMatch
        if account.waitForExistence(timeout: 3) {
            shot(app, "guiado-pago-4-cuenta")
            account.tap()
        }
        let subcategory = app.buttons.matching(identifier: "chat_guided_subcategory").firstMatch
        XCTAssertTrue(subcategory.waitForExistence(timeout: 5), "Se pregunta la categoría.")
        shot(app, "guiado-pago-5-categoria")
        subcategory.tap()
        answerCurrencyIfAsked(app)

        let create = app.buttons["chat_guided_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5), "Con todo contestado, sale la confirmación.")
        shot(app, "guiado-pago-6-confirmar")
        create.tap()
        XCTAssertTrue(app.staticTexts["chat_guided_success"].waitForExistence(timeout: 10),
                      "Tras «Crear pago» sale la tarjeta de éxito.")
        shot(app, "guiado-pago-7-listo")
    }

    /// Lo que se dice de viva voz (la voz escribe la frase en la caja): nombre, día, monto y moneda ya rellenos.
    func test_scheduledPayment_spokenSentence_fillsWhatItSays() {
        let app = openChat()
        send("Recuérdame pagar el alquiler el 5 de cada mes, son 1200", in: app)
        XCTAssertTrue(app.staticTexts["chat_guided_header"].waitForExistence(timeout: 10))
        let firstQuestion = app.staticTexts["chat_guided_question"]
        XCTAssertTrue(firstQuestion.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["chat_guided_name"].exists, "El nombre ya lo dijo: no se pregunta.")
        XCTAssertFalse(app.textFields["chat_guided_amount"].exists, "El monto ya lo dijo: no se pregunta.")
        shot(app, "guiado-pago-frase-dicha")
    }

    // MARK: - Ayudantes

    private func openChat() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "records", aiChatReady: true,
                            extraArguments: ["-uitest-chat-suggestions"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 180), "uitest_ready ausente — bootstrap/seed no completó.")
        let entry = app.buttons["stats_action_ai"]
        XCTAssertTrue(entry.waitForExistence(timeout: 20), "No aparece la entrada de Yala IA en Registros.")
        entry.tap()
        XCTAssertTrue(app.textFields["chat_input"].waitForExistence(timeout: 10), "No se abrió Yala IA.")
        return app
    }

    private func send(_ text: String, in app: XCUIApplication) {
        let input = app.textFields["chat_input"]
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "No salió el teclado.")
        input.typeText(text)
        let send = app.buttons["chat_send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5), "Con texto, debe salir enviar.")
        send.tap()
    }

    private func tap(_ identifier: String, in app: XCUIApplication) {
        let button = app.buttons[identifier].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Falta «\(identifier)».")
        button.tap()
    }

    /// Con cuentas en varias monedas se pregunta la moneda: se toma la primera.
    private func answerCurrencyIfAsked(_ app: XCUIApplication) {
        let chip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chat_guided_currency_'")).firstMatch
        if chip.waitForExistence(timeout: 2) { chip.tap() }
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
