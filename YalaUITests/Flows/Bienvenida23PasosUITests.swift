//
//  Bienvenida23PasosUITests.swift
//  YalaUITests
//
//  Lote 03 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md), sobre una instalación nueva con el mazo a la vista:
//   · Y23-07: «Crea tu primera cuenta» abre la página corta y las preguntas; una tarjeta con cierre, pago y recordatorio
//     queda creada y el mazo pasa a «Aprender a registrar».
//   · Y23-08 y Y23-10: «Aprender a registrar» abre las cuatro maneras; a mano, la guía de foco recorre monto →
//     categoría → cuenta → nombre → guardar; se omiten voz, foto y Yala IA; al terminar, «¿Borramos los de prueba?»
//     borra el registro, sale la guía de la Bandeja y el Panel se llena (vuelve «Nuevo registro», mazo en el paso 3).
//  La voz, la foto y Yala IA de verdad necesitan red y App Attest: van en el guion del iPhone (ticket en `qa`).
//  Cada momento adjunta su captura (`keepAlways`).
//

import XCTest

final class Bienvenida23PasosUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func launchFresh(seed: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: seed, extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func tapWhenSettled(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10,
                                file: StaticString = #filePath, line: UInt = #line) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "No apareció «\(id)».", file: file, line: line)
        _ = app.waitForSettledLayout(of: target)
        target.tap()
    }

    private func type(_ app: XCUIApplication, _ text: String, into id: String) {
        tapWhenSettled(app, id)
        element(app, id).typeText(text)
    }

    /// Y23-07: tarjeta con día de cierre, día de pago y recordatorio de 3 días; termina en «¡Lista!» y el mazo pasa al 2.
    func test_step1_card_withDaysAndReminder_thenDeckMovesToStep2() {
        let app = launchFresh()
        tapWhenSettled(app, "setup_deck_current")

        // La página corta, con «Crear mi primera cuenta» a la vista.
        XCTAssertTrue(element(app, "first_account_start").waitForExistence(timeout: 10), "No salió la página corta.")
        attach(app, "paso1-1-que-son-las-cuentas")
        tapWhenSettled(app, "first_account_start")

        // Tipo → moneda → nombre.
        XCTAssertTrue(element(app, "first_account_kind_creditCard").waitForExistence(timeout: 5))
        attach(app, "paso1-2-tipo")
        tapWhenSettled(app, "first_account_kind_creditCard")
        XCTAssertTrue(element(app, "first_account_add_currency").waitForExistence(timeout: 5),
                      "La moneda se pregunta con «+ Añadir moneda» antes de guardar.")
        attach(app, "paso1-3-moneda")
        tapWhenSettled(app, "first_account_currency_continue")
        type(app, "Visa del trabajo", into: "first_account_name_field")
        tapWhenSettled(app, "first_account_send")

        // Saldo: lo que debo, escrito.
        XCTAssertTrue(element(app, "first_account_help").waitForExistence(timeout: 5),
                      "El saldo ofrece «No sé, ayúdame a sacarlo».")
        attach(app, "paso1-4-saldo")
        type(app, "620", into: "first_account_amount")
        tapWhenSettled(app, "first_account_send")

        // Cierre, pago y recordatorio.
        XCTAssertTrue(element(app, "first_account_day_unknown").waitForExistence(timeout: 5))
        attach(app, "paso1-5-cierre")
        type(app, "18", into: "first_account_day")
        tapWhenSettled(app, "first_account_send")
        XCTAssertTrue(element(app, "first_account_day_private").waitForExistence(timeout: 5))
        type(app, "3", into: "first_account_day")
        tapWhenSettled(app, "first_account_send")
        XCTAssertTrue(element(app, "first_account_reminder_5").waitForExistence(timeout: 5),
                      "Con día de cierre se ofrecen 0/1/3/5 días.")
        attach(app, "paso1-6-recordatorio")
        tapWhenSettled(app, "first_account_reminder_3")

        // ¡Lista! y al Panel.
        XCTAssertTrue(element(app, "first_account_another").waitForExistence(timeout: 10), "No llegó a «¡Lista!».")
        attach(app, "paso1-7-lista")
        tapWhenSettled(app, "first_account_done")

        let deck = app.buttons["setup_deck_current"]
        XCTAssertTrue(deck.waitForExistence(timeout: 10))
        let movedOn = NSPredicate(format: "label CONTAINS %@", "2 de 7")
        expectation(for: movedOn, evaluatedWith: deck)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(deck.label.contains("Aprender a registrar"), "El mazo pasa al paso 2: «\(deck.label)».")
        attach(app, "paso1-8-panel-con-la-cuenta")
    }

    /// Y23-08 y Y23-10: a mano con la guía de foco, se omiten las otras tres, «¿Borramos los de prueba?» borra el
    /// registro, sale la guía de la Bandeja y el Panel se llena con el mazo en el paso 3.
    func test_step2_manualWithGuide_thenCleanupAndInboxGuide() {
        // Como al terminar el paso 1: categorías y una cuenta, sin registros (el paso 1 queda hecho por los datos).
        let app = launchFresh(seed: "una-cuenta")

        // Paso 2: las cuatro maneras.
        let deck = app.buttons["setup_deck_current"]
        expectation(for: NSPredicate(format: "label CONTAINS %@", "2 de 7"), evaluatedWith: deck)
        waitForExpectations(timeout: 10)
        tapWhenSettled(app, "setup_deck_current")
        XCTAssertTrue(element(app, "record_tutorial_start_manual").waitForExistence(timeout: 10),
                      "No salió «Cuatro maneras de anotar».")
        attach(app, "paso2-1-cuatro-maneras")
        tapWhenSettled(app, "record_tutorial_start_manual")

        // La guía de foco: 1 de 5, el monto.
        let progress = element(app, "coach_mark_progress")
        XCTAssertTrue(progress.waitForExistence(timeout: 10), "No salió la guía de foco en el formulario.")
        XCTAssertTrue(app.staticTexts["Empieza por el monto"].exists)
        attach(app, "paso2-2-guia-monto")
        type(app, "25", into: "new_transaction_amount")
        // Cerrar el teclado tocando un texto quieto: la guía vuelve en «¿En qué fue?».
        tapWhenSettled(app, "new_transaction_amount_question")
        XCTAssertTrue(app.staticTexts["¿En qué fue?"].waitForExistence(timeout: 5), "La guía no avanzó a la categoría.")
        attach(app, "paso2-3-guia-categoria")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")

        XCTAssertTrue(app.staticTexts["Tu cuenta ya está puesta"].waitForExistence(timeout: 5))
        attach(app, "paso2-4-guia-cuenta")
        tapWhenSettled(app, "coach_mark_primary")
        XCTAssertTrue(app.staticTexts["Un nombre, si quieres"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "coach_mark_secondary").exists, "El nombre ofrece «Escribir».")
        tapWhenSettled(app, "coach_mark_primary")
        XCTAssertTrue(app.staticTexts["Guárdalo"].waitForExistence(timeout: 5))
        attach(app, "paso2-5-guia-guardar")
        tapWhenSettled(app, "new_transaction_save")

        // «¡Listo!» de los primeros registros, y la pantalla de entre maneras.
        tapWhenSettled(app, "transaction_success_accept")
        let headline = element(app, "record_tutorial_headline")
        XCTAssertTrue(headline.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["¡Tu primer registro!"].exists, "Entre maneras se cuenta lo anotado.")
        attach(app, "paso2-6-entre-maneras")

        // Omitir voz, foto y Yala IA.
        for _ in 0..<3 { tapWhenSettled(app, "record_tutorial_skip") }
        tapWhenSettled(app, "record_tutorial_finish")

        // ¿Borramos los de prueba?
        XCTAssertTrue(element(app, "practice_cleanup_title").waitForExistence(timeout: 10),
                      "No subió la hoja «¿Borramos los de prueba?».")
        XCTAssertTrue(element(app, "practice_cleanup_delete").label.contains("1"), "El registro sale marcado.")
        attach(app, "paso2-7-borrar-de-prueba")
        tapWhenSettled(app, "practice_cleanup_delete")

        // La guía de la Bandeja y el Panel lleno.
        let guide = element(app, "place_guide_card")
        XCTAssertTrue(guide.waitForExistence(timeout: 10), "No salió la guía de la Bandeja.")
        XCTAssertTrue(app.staticTexts["Lo que Yala anota solo"].exists)
        attach(app, "paso2-8-guia-bandeja")
        tapWhenSettled(app, "place_guide_advance")
        XCTAssertTrue(guide.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element(app, "panel_action_new").waitForExistence(timeout: 10),
                      "Al terminar, vuelven las acciones del Panel.")
        expectation(for: NSPredicate(format: "label CONTAINS %@", "3 de 7"), evaluatedWith: deck)
        waitForExpectations(timeout: 10)
        attach(app, "paso2-9-panel-lleno")
    }

    /// Texto grande (AX XL): la página corta del paso 1, sus preguntas y la de las cuatro maneras se leen y sus botones
    /// se alcanzan (ficha «Cómo usar esta especificación»).
    func test_largeText_step1AndStep2PagesStayReachable() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, extraArguments: [
            "-uitest-fresh-install", "-uitest-show-setup-deck",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL",
        ])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        tapWhenSettled(app, "setup_deck_current")
        let start = element(app, "first_account_start")
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(start.isHittable, "Con texto grande, «Crear mi primera cuenta» se alcanza.")
        attach(app, "texto-grande-1-que-son-las-cuentas")
        start.tap()
        XCTAssertTrue(element(app, "first_account_kind_cash").waitForExistence(timeout: 5))
        attach(app, "texto-grande-2-tipo")
        tapWhenSettled(app, "first_account_kind_cash")
        let goOn = element(app, "first_account_currency_continue")
        XCTAssertTrue(goOn.waitForExistence(timeout: 5))
        attach(app, "texto-grande-3-moneda")
    }
}
