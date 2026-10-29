//
//  YalaAILoteDecidido07UITests.swift
//  YalaUITests
//
//  UX 2.2 · lote decidido 07 (Yala IA), lo que se ve:
//  - L14-6: «Temas» por áreas; un ejemplo de Apuntar se escribe en la caja, no se envía.
//  - L14-7: «Nueva conversación» borra sin preguntar y «Deshacer» la devuelve.
//  - L14-9: la tarjeta dice «Gasto» y lleva el signo; «Guardar los N» solo con dos completos.
//  - L14-10 / L14-12 / L16-8: Personalización con «Tono de Yala IA», el interruptor del botón también con Pro y la
//    hoja «Qué sale en el resumen» diciendo dónde se ve.
//  - L14-11: Privacidad nombra cada función; sin Pro, encender Yala IA abre la hoja de Pro, no el permiso.
//  - L14-13: la hoja de Pro de Yala IA enseña la demo animada.
//
//  Sin red no hay respuestas: `-uitest-chat-suggestions`, `chatConversation` y `-uitest-chat-draft` ponen el chat en
//  el estado de cada caso.
//

import XCTest

final class YalaAILoteDecidido07UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func openChat(
        pro: Bool = true, conversation: Bool = false, drafts: Bool = false, undoNoticeSeconds: Int? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: pro,
            deeplink: "records",
            aiChatReady: true,
            chatConversation: conversation,
            extraArguments: ["-uitest-chat-suggestions"] + (drafts ? ["-uitest-chat-draft"] : [])
                + (undoNoticeSeconds.map { ["-uitest-undo-notice-seconds", String($0)] } ?? [])
        )
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let chatEntry = app.buttons["fab_chat"]
        XCTAssertTrue(chatEntry.waitForExistence(timeout: 15), "No aparece la entrada de Yala IA en Registros.")
        chatEntry.tap()
        XCTAssertTrue(app.textFields["chat_input"].waitForExistence(timeout: 10), "No se abrió Yala IA.")
        return app
    }

    // MARK: - L14-6

    func test_topics_areGroupedByArea_andALogExampleLandsInTheBox() {
        let app = openChat()
        let suggestions = app.buttons.matching(identifier: "chat_suggestion")
        XCTAssertTrue(suggestions.firstMatch.waitForExistence(timeout: 10), "El saludo no trae sugerencias.")
        let greeting = Set(suggestions.allElementsBoundByIndex.map(\.label))
        app.buttons["chat_topics"].tap()

        let spending = app.descendants(matching: .any)["chat_topics_area_spending"]
        XCTAssertTrue(spending.waitForExistence(timeout: 10), "Temas no abrió con el área de Gastos.")
        XCTAssertTrue(app.descendants(matching: .any)["chat_topics_area_log"].exists, "Falta el área de Apuntar.")
        // Antes la hoja repetía el saludo, en el mismo orden.
        let topics = app.buttons.matching(identifier: "chat_topic").allElementsBoundByIndex.map(\.label)
        XCTAssertFalse(topics.isEmpty, "Gastos no trae preguntas.")
        XCTAssertTrue(greeting.isDisjoint(with: topics), "Temas repite las sugerencias del saludo: \(topics)")

        let logExample = app.buttons.matching(identifier: "chat_topic_log").firstMatch
        XCTAssertTrue(logExample.waitForExistence(timeout: 5), "Apuntar no trae ejemplos.")
        let text = logExample.label
        logExample.tap()

        let input = app.textFields["chat_input"]
        XCTAssertTrue(spending.waitForNonExistence(timeout: 10), "Temas no se cerró.")
        XCTAssertEqual(input.value as? String, text, "El ejemplo de Apuntar tiene que quedar escrito en la caja, sin enviarse.")
        // Sin nada enviado el hilo sigue vacío y el saludo sigue ahí: un envío lo habría sustituido por el mensaje, aunque
        // luego fallara por red y devolviera el texto a la caja.
        XCTAssertTrue(app.descendants(matching: .any)["chat_log_expense"].exists, "El ejemplo se envió: el saludo ya no está.")
        XCTAssertFalse(app.buttons["chat_new_conversation"].exists, "El ejemplo se envió: hay una conversación nueva.")
    }

    // MARK: - L14-7

    func test_newConversation_deletesWithoutAsking_andUndoBringsItBack() {
        // El aviso dura 5 s y antes de buscarlo se espera a que la conversación se vaya: en un runner frío del CI no cabe.
        // Molde: `UXAudit22Lote08UITests`.
        let app = openChat(conversation: true, undoNoticeSeconds: 30)
        let newConversation = app.buttons["chat_new_conversation"]
        XCTAssertTrue(newConversation.waitForExistence(timeout: 10), "Falta «Nueva conversación» bajo la respuesta.")
        XCTAssertEqual(newConversation.label, "Nueva conversación")
        newConversation.tap()

        XCTAssertTrue(newConversation.waitForNonExistence(timeout: 5), "No se borró la conversación.")
        XCTAssertFalse(app.alerts.firstMatch.exists, "«Nueva conversación» no pregunta.")
        let undo = app.buttons["chat_conversation_undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "Falta el aviso «Conversación borrada · Deshacer».")
        undo.tap()

        XCTAssertTrue(newConversation.waitForExistence(timeout: 5), "«Deshacer» no devolvió la conversación.")
    }

    // MARK: - L14-9

    func test_draftCard_saysExpenseWithItsSign_andSaveAllNeedsTwoCompleteOnes() {
        let app = openChat(drafts: true)

        let amount = app.descendants(matching: .any).matching(identifier: "chat_draft_amount").firstMatch
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "La tarjeta no enseña su importe.")
        XCTAssertTrue(amount.label.contains("Gasto"), "La tarjeta no dice que es un gasto: \(amount.label)")
        XCTAssertTrue(amount.label.contains("-"), "El gasto va con signo, como en Registros: \(amount.label)")

        // Uno completo y otro sin subcategoría: con un solo listo no hay «Guardar los N».
        XCTAssertFalse(app.buttons["chat_draft_save_all"].exists, "Con un solo registro listo sobra «Guardar los N».")

        app.buttons["chat_draft_chip_subcategory"].tap()
        let firstSubcategory = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_"))
            .firstMatch
        XCTAssertTrue(firstSubcategory.waitForExistence(timeout: 10), "No se abrió el selector de subcategoría.")
        firstSubcategory.tap()

        let saveAll = app.buttons["chat_draft_save_all"]
        XCTAssertTrue(saveAll.waitForExistence(timeout: 10), "Con dos registros completos falta «Guardar los 2».")
        XCTAssertEqual(saveAll.label, "Guardar los 2")
        saveAll.tap()

        XCTAssertTrue(saveAll.waitForNonExistence(timeout: 10), "«Guardar los 2» no guardó.")
        XCTAssertEqual(app.buttons.matching(identifier: "chat_draft_save").count, 0, "Quedó una tarjeta sin guardar.")
    }

    // MARK: - L14-11

    func test_privacy_namesEachFeature_andWithoutProYalaIAOpensProInsteadOfTheConsent() {
        let app = XCUIApplication()
        app.launchForUITest(pro: false, fakePrices: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        let privacy = app.buttons["profile_ai_privacy"]
        var swipes = 0
        while !(privacy.exists && privacy.isHittable) && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        privacy.tap()

        let chatRow = app.switches["ai_privacy_chat_row"]
        XCTAssertTrue(chatRow.waitForExistence(timeout: 10), "Falta la fila de Yala IA en Privacidad.")
        XCTAssertTrue(chatRow.label.hasPrefix("Yala IA"), "La fila se llama «\(chatRow.label)», no «Yala IA».")
        XCTAssertTrue(app.switches["ai_privacy_processing_row"].label.hasPrefix("Apuntar con voz o foto"))
        XCTAssertTrue(app.staticTexts["Responde tus preguntas sobre tu dinero y apunta gastos desde el chat."].exists,
                      "Falta la línea que dice qué hace Yala IA.")

        chatRow.switches.firstMatch.tap()
        XCTAssertTrue(app.buttons["upgrade_prompt_cta"].waitForExistence(timeout: 10),
                      "Sin Pro, encender Yala IA tenía que abrir la hoja de Pro.")
        XCTAssertFalse(app.alerts.firstMatch.exists, "Sin Pro no se pide un permiso que no sirve.")
        app.buttons["upgrade_prompt_not_now"].tap()
        XCTAssertTrue(chatRow.waitForExistence(timeout: 10))
        XCTAssertEqual(chatRow.value as? String, "0", "Sin comprar, la fila vuelve a apagado.")
    }

    // MARK: - L14-10 · L14-12 · L16-8

    func test_personalization_proCanHideTheButton_andFindsTheToneAndTheSummary() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        app.openSettingsSection("profile_personalization")

        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        let fab = app.switches["personalization_row_chat_fab"]
        var swipes = 0
        while !(fab.exists && fab.isHittable) && swipes < 6 {
            list.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(fab.exists, "Con Pro también se tiene que poder ocultar el botón de Yala IA.")
        XCTAssertTrue(fab.label.hasPrefix("Yala IA"), "El interruptor se llama «\(fab.label)».")

        // «Qué sale en el resumen» y «Tono» van ENCIMA del interruptor al que se bajó arriba. Desde el 2026-10-23 (L16-5) la
        // sección «Interfaz» sale siempre y la lista es más larga: la fila podía quedar bajo la barra de navegación y el
        // toque caía en ella (5 de 8 frente a 6 de 6 en la base). Se baja cada fila a la vista antes de tocarla; el marco,
        // no `isHittable`, que lanza con el elemento entero fuera (`testing.md`).
        let navBarBottom = app.navigationBars.firstMatch.frame.maxY
        func bringBelowTheBar(_ row: XCUIElement) {
            var pulls = 0
            while row.frame.minY < navBarBottom + 8 && pulls < 4 {
                list.swipeDown()
                pulls += 1
            }
            XCTAssertGreaterThan(row.frame.minY, navBarBottom, "«\(row.label)» sigue bajo la barra de navegación.")
        }

        let summary = app.buttons["personalization_row_ai_summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.label, "Qué sale en el resumen")
        bringBelowTheBar(summary)
        summary.tap()
        let where_ = app.descendants(matching: .any)["ai_summary_where"]
        XCTAssertTrue(where_.waitForExistence(timeout: 10), "La hoja no dice dónde se ve el resumen.")
        XCTAssertEqual(where_.label, "Lo ves en Estadísticas › Resumen.")
        XCTAssertTrue(app.switches["ai_summary_row_observations"].label.contains("IA"), "Observaciones lleva la marca de IA.")
        app.buttons["Listo"].firstMatch.tap()

        let tone = app.buttons["personalization_row_ai_tone"]
        XCTAssertTrue(tone.waitForExistence(timeout: 10), "Falta «Tono de Yala IA» en Personalización.")
        XCTAssertEqual(tone.label, "Tono de Yala IA")
        bringBelowTheBar(tone)
        tone.tap()
        XCTAssertTrue(app.buttons["yala_ai_onboarding_tone_normal"].waitForExistence(timeout: 10),
                      "La hoja de tono no reusa las opciones de la presentación.")
        XCTAssertTrue(app.descendants(matching: .any)["yala_ai_personalize_preview"].exists, "Falta el ejemplo.")
        XCTAssertTrue(app.descendants(matching: .any)["ai_settings_applies_hint"].exists, "Falta la nota.")
    }

    // MARK: - L14-13

    func test_chatPaywall_showsTheDemoOfWhatItDoes() {
        let app = XCUIApplication()
        app.launchForUITest(pro: false, deeplink: "panel", fakePrices: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let entry = app.buttons["panel_action_ai"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "No aparece la píldora de Yala IA.")
        entry.tap()

        XCTAssertTrue(app.buttons["upgrade_prompt_cta"].waitForExistence(timeout: 10), "No salió la hoja de Pro.")
        XCTAssertTrue(app.descendants(matching: .any)["upgrade_prompt_chat_demo"].exists,
                      "La hoja de Pro de Yala IA no enseña la demo.")
    }
}
