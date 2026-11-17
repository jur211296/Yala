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

    // MARK: - Cuenta, categoría y favorito (encargo del 16-nov)

    func test_account_stepByStep_createsIt() {
        let app = openChat()
        send("Quiero crear una cuenta", in: app)
        let savings = app.buttons["chat_guided_account_kind_savings"]
        XCTAssertTrue(savings.waitForExistence(timeout: 10), "La primera pregunta de la cuenta es el tipo.")
        shot(app, "guiado-cuenta-1-tipo")
        savings.tap()

        let currencies = app.buttons["chat_guided_currencies_continue"]
        if currencies.waitForExistence(timeout: 3) {
            shot(app, "guiado-cuenta-2-monedas")
            currencies.tap()
        }
        let name = app.textFields["chat_guided_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "En ahorros, la persona escribe el nombre.")
        shot(app, "guiado-cuenta-3-nombre")
        name.tap()
        name.typeText("Ahorro viaje\n")

        let zero = app.buttons["chat_guided_balance_zero"]
        XCTAssertTrue(zero.waitForExistence(timeout: 5), "Tras el nombre va el saldo.")
        shot(app, "guiado-cuenta-4-saldo")
        zero.tap()
        skipAdvanced(app)

        let create = app.buttons["chat_guided_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5), "Con todo contestado, «Revisa antes de crear».")
        XCTAssertTrue(app.buttons["chat_guided_change_accountName"].exists, "Cada respuesta se puede cambiar.")
        shot(app, "guiado-cuenta-5-revisar")
        create.tap()
        XCTAssertTrue(app.staticTexts["chat_guided_success"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["chat_guided_open"].exists, "La tarjeta de éxito lleva a la cuenta.")
        shot(app, "guiado-cuenta-6-lista")
    }

    func test_category_new_withSubcategoriesAndNeeds() {
        let app = openChat()
        send("Crea una categoría nueva", in: app)
        let name = app.textFields["chat_guided_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "Dijo «categoría»: va directo al nombre.")
        shot(app, "guiado-categoria-1-nombre")
        name.tap()
        name.typeText("Mascotas\n")

        let look = app.buttons["chat_guided_look_continue"]
        XCTAssertTrue(look.waitForExistence(timeout: 5), "Tras el nombre, ícono y color.")
        shot(app, "guiado-categoria-2-icono")
        look.tap()

        let field = app.textFields["chat_guided_subcategory_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Subcategorías siempre.")
        field.tap()
        field.typeText("Veterinario\n")
        field.typeText("Comida\n")
        XCTAssertTrue(app.buttons.matching(identifier: "chat_guided_subcategory_name").element(boundBy: 1)
            .waitForExistence(timeout: 5), "Las dos subcategorías quedan como chips.")
        dismissKeyboard(app)
        shot(app, "guiado-categoria-3-subcategorias")
        tap("chat_guided_subcategories_continue", in: app)

        let yes = app.buttons["chat_guided_advanced_yes"]
        XCTAssertTrue(yes.waitForExistence(timeout: 5))
        yes.tap()
        let essential = app.buttons.matching(identifier: "chat_guided_need_esencial").firstMatch
        XCTAssertTrue(essential.waitForExistence(timeout: 5), "Opciones avanzadas: la necesidad de cada una.")
        essential.tap()
        shot(app, "guiado-categoria-4-necesidad")
        tap("chat_guided_needs_continue", in: app)

        let create = app.buttons["chat_guided_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        shot(app, "guiado-categoria-5-revisar")
        create.tap()
        XCTAssertTrue(app.staticTexts["chat_guided_success"].waitForExistence(timeout: 10))
        shot(app, "guiado-categoria-6-lista")
        tap("chat_guided_open", in: app)
        let close = app.buttons["chat_guided_list_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), "«Ver tus categorías» abre la lista de Ajustes.")
        shot(app, "guiado-categoria-7-ver")
        close.tap()
    }

    func test_subcategories_inAnExistingCategory() {
        let app = openChat()
        send("Agrega subcategorías", in: app)
        let parent = app.buttons.matching(identifier: "chat_guided_parent").firstMatch
        XCTAssertTrue(parent.waitForExistence(timeout: 10), "Dijo «subcategorías»: pregunta en cuál.")
        shot(app, "guiado-subcategorias-1-cual")
        parent.tap()
        let field = app.textFields["chat_guided_subcategory_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Propinas\n")
        dismissKeyboard(app)
        shot(app, "guiado-subcategorias-2-nombres")
        tap("chat_guided_subcategories_continue", in: app)
        skipAdvanced(app)
        let create = app.buttons["chat_guided_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        shot(app, "guiado-subcategorias-3-revisar")
        create.tap()
        XCTAssertTrue(app.staticTexts["chat_guided_success"].waitForExistence(timeout: 10))
    }

    func test_favorite_stepByStep_savesIt() {
        let app = openChat()
        send("Crea un favorito", in: app)
        let expense = app.buttons["chat_guided_favorite_type_expense"]
        XCTAssertTrue(expense.waitForExistence(timeout: 10), "La primera pregunta del favorito es qué registras.")
        shot(app, "guiado-favorito-1-tipo")
        expense.tap()

        let tile = app.buttons.matching(identifier: "chat_guided_subcategory").firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5), "Subcategorías siempre: las más usadas.")
        shot(app, "guiado-favorito-2-subcategoria")
        tile.tap()

        let account = app.buttons.matching(identifier: "chat_guided_account").firstMatch
        if account.waitForExistence(timeout: 3) {
            shot(app, "guiado-favorito-3-cuenta")
            account.tap()
        }
        let amount = app.textFields["chat_guided_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "Tras la cuenta, el monto.")
        shot(app, "guiado-favorito-4-monto")
        amount.tap()
        amount.typeText("12")
        tap("chat_guided_amount_send", in: app)

        let idea = app.buttons.matching(identifier: "chat_guided_name_idea").firstMatch
        XCTAssertTrue(idea.waitForExistence(timeout: 5), "El nombre propone la subcategoría.")
        shot(app, "guiado-favorito-5-nombre")
        idea.tap()
        skipAdvanced(app)

        let create = app.buttons["chat_guided_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        shot(app, "guiado-favorito-6-revisar")
        create.tap()
        XCTAssertTrue(app.staticTexts["chat_guided_success"].waitForExistence(timeout: 10))
        shot(app, "guiado-favorito-7-listo")
    }

    /// Un registro dicho con la palabra «cuenta» sigue siendo un registro: no abre la tarjeta.
    func test_aRecordThatNamesAnAccount_doesNotOpenAGuidedFlow() {
        let app = openChat()
        send("Agrega 20 soles a la cuenta BCP", in: app)
        XCTAssertFalse(app.staticTexts["chat_guided_header"].waitForExistence(timeout: 4),
                       "«Agrega 20 soles a la cuenta…» es un registro.")
    }

    // MARK: - Grupos (encargo del 17-nov)

    /// «Pagué 90 de la cena con Ana y Beto»: Ana y Beto son del viaje, así que es un gasto de ese grupo, pagado por ti y
    /// en partes iguales entre los tres. Va directo a lo que falta.
    func test_groupExpense_namedPeople_goesStraightToWhatIsMissing() {
        let app = openChat(seed: "grupos")
        send("Pagué 90 de la cena con Ana y Beto", in: app)
        XCTAssertTrue(app.staticTexts["chat_guided_header"].waitForExistence(timeout: 10),
                      "Una cifra y gente de tus grupos abre el gasto de grupo.")
        shot(app, "guiado-gasto-grupo-frase-1")
        chooseAccountIfAsked(app)
        skipAdvanced(app)
        let create = app.buttons["chat_guided_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5), "Con todo dicho, sale la confirmación.")
        XCTAssertTrue(app.buttons["chat_guided_change_expensePayer"].exists, "Quién pagó se puede cambiar.")
        XCTAssertTrue(app.buttons["chat_guided_change_expenseSplit"].exists, "El reparto se puede cambiar.")
        shot(app, "guiado-gasto-grupo-frase-2-revisar")
        create.tap()
        XCTAssertTrue(app.staticTexts["chat_guided_success"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["chat_guided_open"].exists, "El éxito lleva al grupo.")
        shot(app, "guiado-gasto-grupo-frase-3-listo")
    }

    /// Pregunta a pregunta: grupo → qué fue → ¿Quién pagó? → ¿Cómo lo dividen? (solo entre algunos) → revisar.
    func test_groupExpense_stepByStep_whoPaidAndHowToSplit() {
        let app = openChat(seed: "grupos")
        send("Anota un gasto de grupo de 60", in: app)
        let group = app.buttons.matching(identifier: "chat_guided_group").firstMatch
        XCTAssertTrue(group.waitForExistence(timeout: 10), "Con dos grupos, primero: ¿en qué grupo?")
        shot(app, "guiado-gasto-grupo-1-grupo")
        group.tap()

        let description = app.textFields["chat_guided_description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), "Luego: ¿qué fue?")
        description.tap()
        description.typeText("Taxi")
        tap("chat_guided_description_send", in: app)

        let payer = app.buttons.matching(identifier: "chat_guided_payer")
        XCTAssertTrue(payer.firstMatch.waitForExistence(timeout: 5), "Luego: ¿Quién pagó?")
        shot(app, "guiado-gasto-grupo-2-quien-pago")
        payer.element(boundBy: 1).tap()

        let some = app.buttons["chat_guided_split_some"]
        XCTAssertTrue(some.waitForExistence(timeout: 5), "Luego: ¿Cómo lo dividen?")
        shot(app, "guiado-gasto-grupo-3-como-dividen")
        some.tap()
        let person = app.buttons.matching(identifier: "chat_guided_person")
        XCTAssertTrue(person.firstMatch.waitForExistence(timeout: 5), "«Solo entre algunos» enseña a la gente.")
        person.element(boundBy: 2).tap()
        shot(app, "guiado-gasto-grupo-4-solo-algunos")
        tap("chat_guided_split_some_continue", in: app)

        chooseAccountIfAsked(app)
        skipAdvanced(app)
        let create = app.buttons["chat_guided_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        shot(app, "guiado-gasto-grupo-5-revisar")
        create.tap()
        XCTAssertTrue(app.staticTexts["chat_guided_success"].waitForExistence(timeout: 10))
        shot(app, "guiado-gasto-grupo-6-listo")
    }

    /// Deuda de antes: grupo → quién debía → a quién → cuánto → revisar con la frase.
    func test_openingBalance_stepByStep() {
        let app = openChat(seed: "grupos")
        send("Anota una deuda de antes", in: app)
        let group = app.buttons.matching(identifier: "chat_guided_group").firstMatch
        XCTAssertTrue(group.waitForExistence(timeout: 10), "Primero: ¿en qué grupo?")
        shot(app, "guiado-deuda-1-grupo")
        group.tap()

        let debtor = app.buttons.matching(identifier: "chat_guided_debtor")
        XCTAssertTrue(debtor.firstMatch.waitForExistence(timeout: 5), "Luego: ¿quién debía?")
        shot(app, "guiado-deuda-2-quien-debia")
        debtor.element(boundBy: 1).tap()

        let creditor = app.buttons.matching(identifier: "chat_guided_creditor")
        XCTAssertTrue(creditor.firstMatch.waitForExistence(timeout: 5), "Luego: ¿a quién?")
        shot(app, "guiado-deuda-3-a-quien")
        creditor.firstMatch.tap()

        let amount = app.textFields["chat_guided_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "Luego: ¿cuánto?")
        amount.tap()
        amount.typeText("120")
        shot(app, "guiado-deuda-4-cuanto")
        tap("chat_guided_amount_send", in: app)

        skipAdvanced(app)
        let create = app.buttons["chat_guided_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["chat_guided_debt_sentence"].exists, "La revisión dice quién le debe a quién.")
        shot(app, "guiado-deuda-5-revisar")
        create.tap()
        XCTAssertTrue(app.staticTexts["chat_guided_success"].waitForExistence(timeout: 10))
        shot(app, "guiado-deuda-6-listo")
    }

    /// Crear un grupo hasta «Revisa antes de crear» (crearlo va al servidor, que el XCUITest no toca).
    func test_createGroup_stepByStep_untilTheConfirmation() {
        let app = openChat(seed: "grupos", cloudSession: true, groupsConsent: true)
        send("Crea un grupo", in: app)
        let trip = app.buttons["chat_guided_purpose_trip"]
        XCTAssertTrue(trip.waitForExistence(timeout: 10), "Primero: ¿para qué es el grupo?")
        shot(app, "guiado-grupo-1-para-que")
        trip.tap()

        let name = app.textFields["chat_guided_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "Luego: ¿cómo se llama?")
        name.tap()
        name.typeText("Viaje a Arequipa")
        shot(app, "guiado-grupo-2-nombre")
        tap("chat_guided_name_send", in: app)

        let yourName = app.textFields["chat_guided_your_name"]
        if yourName.waitForExistence(timeout: 3) {
            yourName.tap()
            yourName.typeText("Jur")
            shot(app, "guiado-grupo-3-tu-nombre")
            tap("chat_guided_your_name_send", in: app)
        }
        let each = app.buttons["chat_guided_currency_each"]
        if each.waitForExistence(timeout: 3) {
            shot(app, "guiado-grupo-4-monedas")
            each.tap()
        }
        let equal = app.buttons["chat_guided_split_type_equal"]
        XCTAssertTrue(equal.waitForExistence(timeout: 5), "Luego: ¿cómo suelen dividir?")
        shot(app, "guiado-grupo-5-como-dividen")
        equal.tap()
        skipAdvanced(app)
        XCTAssertTrue(app.buttons["chat_guided_create"].waitForExistence(timeout: 5), "Sale «Revisa antes de crear».")
        XCTAssertTrue(app.buttons["chat_guided_change_groupName"].exists)
        shot(app, "guiado-grupo-6-revisar")
    }

    /// Sin la cuenta de Yala, Yala IA lo dice y no abre la tarjeta.
    func test_createGroup_withoutAccount_doesNotOpenTheCard() {
        let app = openChat(seed: "grupos")
        send("Crea un grupo", in: app)
        XCTAssertFalse(app.staticTexts["chat_guided_header"].waitForExistence(timeout: 4),
                       "Sin cuenta de Yala no se puede crear un grupo: no se abre la tarjeta.")
        shot(app, "guiado-grupo-sin-cuenta")
    }

    /// Si pagaste tú y el gasto se refleja en tus cuentas, se pregunta con cuál: se toma la primera.
    private func chooseAccountIfAsked(_ app: XCUIApplication) {
        let account = app.buttons.matching(identifier: "chat_guided_account").firstMatch
        if account.waitForExistence(timeout: 3) {
            shot(app, "guiado-gasto-grupo-cuenta")
            account.tap()
        }
    }

    // MARK: - Ayudantes

    private func openChat(seed: String = "realista", cloudSession: Bool = false, groupsConsent: Bool = false,
                          extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: seed, deeplink: "records", aiChatReady: true, cloudSession: cloudSession,
                            groupsConsent: groupsConsent, extraArguments: ["-uitest-chat-suggestions"] + extra)
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

    /// Baja el teclado tocando el título de la pregunta: el chat lo baja al tocar fuera de un campo
    /// (`dismissKeyboardOnTap`). Arrastrar no vale: el chat es una hoja y el gesto intentaría cerrarla.
    private func dismissKeyboard(_ app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }
        let question = app.staticTexts["chat_guided_question"]
        if question.exists { question.tap() }
        let gone = NSPredicate(format: "count == 0")
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: gone, object: app.keyboards)], timeout: 3)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
