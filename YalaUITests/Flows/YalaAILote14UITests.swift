//
//  YalaAILote14UITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2, lote 14 (Yala IA), lo decidido por Jürgen el 2026-10-15:
//  - L14-2: la primera vez no sale el aviso de permiso ANTES de nada; la presentación lo pide en su último paso,
//    «Antes de empezar», y aceptarlo ahí abre el chat y deja la entrada abriendo el chat directo.
//  - L14-3: tono y estilo en un solo paso, con lo elegido marcado.
//  - L14-4: el saludo enseña «Apunta un gasto» (que abre el teclado) y las tres preguntas.
//  Seed `minimal`, Pro, scheme Yala Dev. Sin `-uitest-ai-chat-ready`: se recorre el camino de la primera vez.
//

import XCTest

final class YalaAILote14UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_firstTime_presentationAsksConsentLast_andThenTheEntryOpensTheChat() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, extraArguments: ["-uitest-chat-suggestions"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let entry = app.buttons["panel_action_ai"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "No aparece la píldora de Yala IA en el Panel.")
        entry.tap()

        // L14-2: lo primero es la presentación, no el aviso del sistema.
        let next = app.buttons["yala_ai_onboarding_continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10), "La primera vez debe abrir la presentación de Yala IA.")
        XCTAssertEqual(app.alerts.count, 0, "El aviso de permiso no debe salir antes de la presentación.")

        next.tap()
        XCTAssertTrue(next.waitForHittable(timeout: 5), "No se pasó al paso 2.")
        next.tap()

        // L14-3: tono y estilo en el mismo paso; lo que se toca queda elegido.
        let direct = app.buttons["yala_ai_onboarding_tone_sarcastic"]
        let saver = app.buttons["yala_ai_onboarding_focus_saver"]
        XCTAssertTrue(direct.waitForExistence(timeout: 5), "Falta el selector de tono en «Hazla a tu manera».")
        XCTAssertTrue(saver.exists, "El estilo debe estar en el mismo paso que el tono.")
        direct.tap()
        saver.tap()
        XCTAssertTrue(direct.isSelected, "El tono tocado debe quedar elegido.")
        XCTAssertTrue(saver.isSelected, "El estilo tocado debe quedar elegido.")
        XCTAssertFalse(app.buttons["yala_ai_onboarding_tone_normal"].isSelected, "Solo un tono elegido a la vez.")

        XCTAssertTrue(next.waitForHittable(timeout: 5), "Falta «Continuar» en el paso de tono y estilo.")
        next.tap()

        // L14-2: el último paso es el permiso, con su botón «Aceptar y empezar».
        let accept = app.buttons["yala_ai_onboarding_accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5), "El último paso debe pedir el permiso.")
        XCTAssertTrue(
            app.descendants(matching: .any)["yala_ai_onboarding_consent"].exists,
            "Faltan las tres filas de qué lee, qué no hace y dónde se apaga."
        )
        accept.tap()

        // L14-4: el chat abre con las dos cosas que hace.
        let input = app.textFields["chat_input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Aceptar debe abrir el chat.")
        XCTAssertEqual(app.alerts.count, 0, "Aceptado en la presentación, no debe volver a pedirse en un aviso.")
        let logExpense = app.buttons["chat_log_expense"]
        XCTAssertTrue(logExpense.waitForExistence(timeout: 5), "El saludo debe ofrecer «Apunta un gasto».")
        let suggestions = app.buttons.matching(identifier: "chat_suggestion")
        XCTAssertTrue(suggestions.firstMatch.waitForExistence(timeout: 10), "Faltan las preguntas del saludo.")
        XCTAssertEqual(suggestions.count, 3, "El saludo debe ofrecer tres preguntas.")
        XCTAssertLessThan(logExpense.frame.maxY, suggestions.firstMatch.frame.minY, "Apuntar va antes que preguntar.")

        logExpense.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "«Apunta un gasto» debe abrir el teclado.")

        // Cerrar y volver a entrar: ya no hay presentación ni aviso, el chat abre directo.
        let close = app.buttons["chat_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Falta la X del chat.")
        close.tap()
        XCTAssertTrue(entry.waitForHittable(timeout: 10), "No se volvió al Panel.")
        entry.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 10), "La segunda vez la entrada debe abrir el chat directo.")
        XCTAssertFalse(next.exists, "La presentación no debe volver a salir.")
        XCTAssertEqual(app.alerts.count, 0, "El permiso ya aceptado no debe volver a pedirse.")
    }
}
