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

        // Subcategorías siempre: llegan todas marcadas y se puede quitar alguna.
        let chip = app.buttons.matching(identifier: "chat_guided_subcategory_chip").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Tras las categorías: «¿Algo que no quieras contar?».")
        chip.tap()
        shot(app, "guiado-presupuesto-1b-subcategorias")
        tap("chat_guided_subcategories_continue", in: app)

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
        skipAdvanced(app)

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
        skipAdvanced(app)
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

        // «Cada cierto tiempo»: cada 2 semanas, en la misma pregunta.
        tap("chat_guided_every_weekly", in: app)
        shot(app, "guiado-pago-3-cada-n")
        tap("chat_guided_every_send", in: app)
        let day = app.buttons["chat_guided_weekday_6"]
        XCTAssertTrue(day.waitForExistence(timeout: 5), "Cada 2 semanas: se pregunta el día de la semana.")
        shot(app, "guiado-pago-3b-dia")
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
        skipAdvanced(app)

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

    // MARK: - Mejoras del 16-nov

    /// El saludo dice que crea conversando, y sus atajos abren el guiado sin escribir nada.
    func test_greeting_shortcuts_openTheGuidedFlows() {
        let app = openChat()
        let budget = app.buttons["chat_create_budget"]
        XCTAssertTrue(budget.waitForExistence(timeout: 10), "El saludo trae el atajo «Un presupuesto».")
        XCTAssertTrue(app.buttons["chat_create_payment"].exists, "Y el de «Un pago planificado».")
        shot(app, "guiado-saludo")
        budget.tap()
        XCTAssertTrue(app.staticTexts["chat_guided_header"].waitForExistence(timeout: 10),
                      "El atajo abre la tarjeta guiada.")
        XCTAssertTrue(app.buttons.matching(identifier: "chat_guided_category").firstMatch.waitForExistence(timeout: 5))
    }

    /// Presupuesto de una sola vez, dicho con palabras, y las opciones avanzadas una a una con «Saltar».
    func test_budget_oneTime_withWords_andAdvancedOptions() {
        let app = openChat()
        send("Quiero un presupuesto de una sola vez de dos mil para todos mis gastos", in: app)

        let datesContinue = app.buttons["chat_guided_dates_continue"]
        XCTAssertTrue(datesContinue.waitForExistence(timeout: 10), "Una sola vez: se preguntan las fechas.")
        shot(app, "guiado-presupuesto-una-vez-fechas")
        datesContinue.tap()
        answerCurrencyIfAsked(app)

        let advancedYes = app.buttons["chat_guided_advanced_yes"]
        XCTAssertTrue(advancedYes.waitForExistence(timeout: 5), "Antes de revisar: ¿opciones avanzadas?")
        shot(app, "guiado-presupuesto-avanzadas-pregunta")
        advancedYes.tap()

        let skip = app.buttons["chat_guided_skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "Cada opción avanzada se puede saltar.")
        shot(app, "guiado-presupuesto-avanzadas-nombre")
        skip.tap()
        let alert = app.buttons["chat_guided_alert_100"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "La siguiente es la de los avisos.")
        shot(app, "guiado-presupuesto-avanzadas-avisos")
        alert.tap()
        let create = app.buttons["chat_guided_create"]
        var guard_ = 0
        while !create.waitForExistence(timeout: 2), guard_ < 8 {
            tap("chat_guided_skip", in: app)
            guard_ += 1
        }
        XCTAssertTrue(create.exists, "Saltando lo demás se llega a revisar.")
        XCTAssertTrue(app.buttons["chat_guided_change_dates"].exists, "Las fechas salen en la revisión.")
        XCTAssertTrue(app.buttons["chat_guided_change_budgetAlerts"].exists, "Y el aviso elegido.")
        shot(app, "guiado-presupuesto-avanzadas-revisar")
        create.tap()
        XCTAssertTrue(app.staticTexts["chat_guided_success"].waitForExistence(timeout: 10))
    }

    /// Pago «cada N» dicho con palabras: nombre, monto y frecuencia ya rellenos.
    func test_payment_everyTwoWeeks_withWords() {
        let app = openChat()
        send("Recuérdame pagar el gimnasio cada dos semanas, son ochenta", in: app)
        XCTAssertTrue(app.staticTexts["chat_guided_header"].waitForExistence(timeout: 10))
        let weekday = app.buttons["chat_guided_weekday_2"]
        XCTAssertTrue(weekday.waitForExistence(timeout: 5), "Lo único que falta del cuándo es el día de la semana.")
        XCTAssertFalse(app.textFields["chat_guided_amount"].exists, "El monto dicho con palabras no se pregunta.")
        shot(app, "guiado-pago-cada-dos-semanas")
        weekday.tap()
        let account = app.buttons.matching(identifier: "chat_guided_account").firstMatch
        if account.waitForExistence(timeout: 3) { account.tap() }
        let subcategory = app.buttons.matching(identifier: "chat_guided_subcategory").firstMatch
        if subcategory.waitForExistence(timeout: 3) { subcategory.tap() }
        answerCurrencyIfAsked(app)
        skipAdvanced(app)
        let create = app.buttons["chat_guided_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        shot(app, "guiado-pago-cada-dos-semanas-revisar")
    }

    /// Las capturas del recorrido en claro y en oscuro (temas Claro y Oscuro de Yala).
    func test_captures_lightTheme() { captureWalkthrough(theme: "1", suffix: "claro") }

    func test_captures_darkTheme() { captureWalkthrough(theme: "2", suffix: "oscuro") }

    private func captureWalkthrough(theme: String, suffix: String) {
        let app = openChat(extra: ["-userTheme", theme])
        XCTAssertTrue(app.buttons["chat_create_budget"].waitForExistence(timeout: 10))
        shot(app, "tema-\(suffix)-1-saludo")
        send("Quiero un presupuesto de trescientos al mes para alimentación", in: app)
        let chip = app.buttons.matching(identifier: "chat_guided_subcategory_chip").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "Nombró la categoría: se ofrecen sus subcategorías.")
        shot(app, "tema-\(suffix)-2-subcategorias")
        tap("chat_guided_subcategories_continue", in: app)
        answerCurrencyIfAsked(app)
        let advancedYes = app.buttons["chat_guided_advanced_yes"]
        XCTAssertTrue(advancedYes.waitForExistence(timeout: 5))
        shot(app, "tema-\(suffix)-3-avanzadas")
        advancedYes.tap()
        XCTAssertTrue(app.buttons["chat_guided_skip"].waitForExistence(timeout: 5))
        tap("chat_guided_skip", in: app)
        XCTAssertTrue(app.buttons["chat_guided_alert_75"].waitForExistence(timeout: 5))
        shot(app, "tema-\(suffix)-4-avisos")
        let create = app.buttons["chat_guided_create"]
        var guard_ = 0
        while !create.waitForExistence(timeout: 2), guard_ < 8 {
            tap("chat_guided_skip", in: app)
            guard_ += 1
        }
        XCTAssertTrue(create.exists)
        shot(app, "tema-\(suffix)-5-revisar")
    }

    // MARK: - Ayudantes

    private func openChat(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "records", aiChatReady: true,
                            extraArguments: ["-uitest-chat-suggestions"] + extra)
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

    /// «¿Quieres revisar las opciones avanzadas?» → «No, seguir así».
    private func skipAdvanced(_ app: XCUIApplication) {
        let no = app.buttons["chat_guided_advanced_no"]
        XCTAssertTrue(no.waitForExistence(timeout: 5), "Antes de revisar se ofrecen las opciones avanzadas.")
        no.tap()
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
