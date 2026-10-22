//
//  SettingsLote15UITests.swift
//  YalaUITests
//
//  Lote decidido 2.2 · 15 (Ajustes, ayuda y preferencias). Lo que se ve en pantalla de cada decisión, con su control
//  cuando lo hay. Seed `minimal`, scheme Yala Dev, en español. Cada caso deja su captura como adjunto (`capture`) y, con
//  `TEST_RUNNER_YALA_CAPTURE_DIR`, también en disco: son las capturas del «después» del lote.
//

import XCTest

final class SettingsLote15UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launch(_ configure: (XCUIApplication) -> Void = { $0.launchForUITest() }) -> XCUIApplication {
        let app = XCUIApplication()
        configure(app)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !(element.exists && element.isHittable) && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"], !dir.isEmpty {
            do {
                try shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("despues-\(name).png"))
            } catch {
                XCTFail("SettingsLote15UITests: no se pudo guardar la captura \(name): \(error)")
            }
        }
    }

    // MARK: - L16-1 · Ajustes se llama Ajustes

    func test_settingsSheet_isCalledAjustes() {
        let app = launch()
        XCTAssertEqual(app.buttons["profile_avatar"].label, "Ajustes", "El avatar no se anuncia como Ajustes.")
        app.openProfile()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 10), "La hoja no se titula «Ajustes».")
        capture(app, "L16-1-ajustes")
    }

    // MARK: - L16-2 · El nombre

    /// El nombre de serie no se escribe en el campo; se escribe uno y «Listo» lo guarda.
    func test_personalDetails_emptyFieldWithHint_andDoneSaves() {
        let app = launch()
        app.openProfile()
        app.openSettingsSection("profile_edit_button")

        let field = app.textFields["personal_details_name_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No apareció el campo Nombre.")
        XCTAssertNotEqual(field.value as? String, "Usuario", "El campo vuelve a traer «Usuario» escrito.")
        XCTAssertTrue(app.buttons["personal_details_more_about_data"].exists, "Falta «Más sobre tus datos».")
        capture(app, "L16-2-detalles-personales")

        field.tap()
        field.typeText("Lucia QA")
        let done = app.buttons["personal_details_done"]
        XCTAssertTrue(done.waitForHittable(timeout: 5), "Falta «Listo».")
        done.tap()
        XCTAssertTrue(app.staticTexts["Lucia QA"].waitForExistence(timeout: 5), "«Listo» no guardó el nombre.")
    }

    // MARK: - L16-4 · Tipos de cambio

    /// Con el buscador se llega al guaraní, y su tasa se lee al revés: «1 PEN = … PYG».
    func test_exchangeRates_searchAndInvertedWeakRate() {
        let app = launch()
        app.openProfile()
        scrollTo(app, "profile_currency").tap()
        let seeAll = app.buttons["Ver todas"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10), "No apareció «Ver todas».")
        seeAll.tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "No hay buscador arriba.")
        search.tap()
        search.typeText("guarani")
        let inverted = app.staticTexts["exchange_rate_inverted_PYG"]
        if inverted.waitForExistence(timeout: 10) {
            XCTAssertTrue(inverted.label.hasPrefix("1 PEN = "), "La tasa del guaraní no se invirtió: \(inverted.label)")
        } else {
            // Sin tasas en el simulador la fila dice «--»: lo que se prueba entonces es el buscador.
            XCTAssertTrue(app.staticTexts["PYG"].exists || app.staticTexts["1 PYG"].exists, "El buscador no encontró el guaraní.")
        }
        // «1 USD» y «1 EUR» siguen en el árbol: son las filas de la pantalla de debajo. La libra no está ahí.
        XCTAssertFalse(app.staticTexts["1 GBP"].exists, "El buscador no filtró la lista.")
        capture(app, "L16-4-tipos-de-cambio")
    }

    // MARK: - L16-6 · Solo gastos

    /// Activar pregunta con «Activar» y «Cancelar» a la vista; cancelar no cambia nada.
    func test_expensesOnly_asksWithActivateAndVisibleCancel() {
        let app = launch()
        app.openProfile()
        app.openSettingsSection("profile_personalization")
        let toggle = app.switches["personalization_row_expenses_only"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "No apareció «Solo gastos».")
        toggle.switches.firstMatch.tap()

        let activate = app.alerts.buttons["Activar"].firstMatch
        XCTAssertTrue(activate.waitForExistence(timeout: 5), "El aviso no ofrece «Activar».")
        let cancel = app.alerts.buttons["Cancelar"].firstMatch
        XCTAssertTrue(cancel.exists, "«Cancelar» no se ve.")
        capture(app, "L16-6-solo-gastos")
        cancel.tap()
        XCTAssertEqual(toggle.value as? String, "0", "Cancelar activó «Solo gastos».")
    }

    // MARK: - L16-7 · Personalización en palabras de usuario

    func test_personalization_userWordsAndWhereItShows() {
        let app = launch()
        app.openProfile()
        app.openSettingsSection("profile_personalization")
        XCTAssertTrue(app.switches["personalization_row_expenses_only"].waitForExistence(timeout: 10),
                      "No se abrió Personalización.")
        capture(app, "L16-7-personalizacion-1")
        // La lista monta solo las celdas visibles: se baja hasta la fila.
        let averageLine = app.buttons["personalization_row_average_line"]
        var tries = 0
        while !(averageLine.exists && averageLine.isHittable) && tries < 8 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(averageLine.exists, "No apareció la línea de promedio.")
        XCTAssertTrue(averageLine.label.hasPrefix("Línea de promedio en las gráficas"), averageLine.label)
        XCTAssertTrue(app.staticTexts["Lo ves en las gráficas del Panel."].exists, "El pie no dice dónde se ve.")
        let autoFocus = app.buttons["personalization_row_auto_focus"]
        tries = 0
        while !(autoFocus.exists && autoFocus.isHittable) && tries < 8 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(autoFocus.label.hasPrefix("Abrir el teclado en"), autoFocus.label)
        capture(app, "L16-7-personalizacion-2")
    }

    // MARK: - L16-10 · Elegir un tema no te saca

    func test_theme_appliesAndStaysOnThemes() {
        let app = launch()
        app.openProfile()
        scrollTo(app, "profile_theme").tap()
        let dark = app.buttons["theme_card_2"]
        XCTAssertTrue(dark.waitForExistence(timeout: 10), "No apareció el tema Oscuro.")
        dark.tap()
        // Antes, a los 300 ms se cerraba Ajustes entero.
        let stillThere = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: dark)
        XCTAssertEqual(XCTWaiter().wait(for: [stillThere], timeout: 2), .timedOut, "Elegir un tema cerró la pantalla.")
        XCTAssertTrue(dark.isSelected, "El tema elegido no quedó marcado.")
        capture(app, "L16-10-temas-tras-elegir")
        app.buttons["theme_card_8"].tap()
    }

    // MARK: - L16-13 · Pestañas de abajo

    func test_tabBarConfig_saysTheTwoRules() {
        let app = launch()
        app.tabBars.buttons["Más"].tap()
        let editor = app.buttons["more_editor_button"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "No apareció «Personalizar».")
        editor.tap()
        let tabBarButton = app.buttons["more_editor_tabbar_button"]
        XCTAssertTrue(tabBarButton.waitForExistence(timeout: 10), "No apareció «Pestañas de abajo».")
        XCTAssertTrue(tabBarButton.label.hasPrefix("Pestañas de abajo"), tabBarButton.label)
        tabBarButton.tap()
        let rules = app.staticTexts["tabconfig_rules_footer"]
        XCTAssertTrue(rules.waitForExistence(timeout: 10), "Falta el pie con las reglas.")
        XCTAssertEqual(rules.label, "Panel va siempre primero. Caben 3 más Más y Buscar.")
        capture(app, "L16-13-pestanas-de-abajo")
    }

    // MARK: - L16-14 · Permisos de Yala

    /// La fila abre la pantalla de permisos, dentro de Yala, con el estado de cada uno.
    func test_permissions_openInsideYala_withEachState() {
        let app = launch()
        app.openProfile()
        scrollTo(app, "profile_permissions").tap()
        for kind in ["notifications", "camera", "microphone", "photos"] {
            XCTAssertTrue(app.staticTexts["permission_status_\(kind)"].waitForExistence(timeout: 10),
                          "Falta el estado de «\(kind)».")
        }
        XCTAssertEqual(app.state, .runningForeground, "Permisos sacó de Yala.")
        capture(app, "L16-14-permisos")
    }

    // MARK: - L16-15 · Valorar y recomendar

    func test_rateAndRecommend_bothRows() {
        let app = launch()
        app.openProfile()
        let rate = scrollTo(app, "profile_rate_app")
        XCTAssertTrue(rate.exists, "Falta «Valorar Yala».")
        XCTAssertTrue(rate.label.hasPrefix("Valorar Yala"), rate.label)
        let recommend = scrollTo(app, "profile_recommend_app")
        XCTAssertTrue(recommend.exists, "Falta «Recomendar Yala».")
        capture(app, "L16-15-valorar-y-recomendar")
        recommend.tap()
        // La hoja de compartir del sistema.
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10)
                      || app.collectionViews.cells.firstMatch.waitForExistence(timeout: 5),
                      "«Recomendar Yala» no abrió la hoja de compartir.")
        capture(app, "L16-15-recomendar-compartir")
    }

    // MARK: - L16-16 · Tutoriales

    /// Al terminar un tutorial: «Ya sabes cómo…», «Hacerlo ahora» lleva a la pantalla, y la lista lo marca hecho.
    func test_tutorial_closesWithDoItNow_andTheListMarksItDone() {
        let app = launch()
        app.openProfile()
        scrollTo(app, "profile_help_tutorials").tap()
        let row = app.buttons["tutorial_row_createTags"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No apareció el tutorial de etiquetas.")
        row.tap()

        // Intro → pasos → cierre.
        for _ in 0..<6 {
            if app.buttons["tutorial_do_it_now"].exists { break }
            let next = app.buttons.matching(NSPredicate(format: "label IN %@", ["Empezar", "Siguiente", "Listo"])).firstMatch
            guard next.waitForExistence(timeout: 5) else { break }
            next.tap()
        }
        let doItNow = app.buttons["tutorial_do_it_now"]
        XCTAssertTrue(doItNow.waitForExistence(timeout: 10), "El cierre no ofrece «Hacerlo ahora».")
        XCTAssertTrue(app.staticTexts["Ya sabes cómo crear etiquetas"].exists, "El cierre sigue felicitando por algo hecho.")
        capture(app, "L16-16-tutorial-cierre")
        doItNow.tap()
        XCTAssertTrue(app.navigationBars["Etiquetas"].waitForExistence(timeout: 10)
                      || app.staticTexts["Etiquetas"].waitForExistence(timeout: 2),
                      "«Hacerlo ahora» no llevó a Etiquetas.")
    }

    // MARK: - L16-17 · Preguntas frecuentes

    func test_faq_newQuestions_andWriteToUs() {
        let app = launch()
        app.openProfile()
        let faq = scrollTo(app, "Preguntas frecuentes")
        XCTAssertTrue(faq.exists, "No apareció «Preguntas frecuentes».")
        faq.tap()
        XCTAssertTrue(app.buttons["faq_row_groups"].waitForExistence(timeout: 10), "Falta la pregunta de Grupos.")
        let writeToUs = scrollTo(app, "faq_write_to_us")
        XCTAssertTrue(writeToUs.exists, "Falta «Escríbenos».")
        capture(app, "L16-17-faq-final")
        writeToUs.tap()
        XCTAssertTrue(app.buttons["support_send_button"].waitForExistence(timeout: 10), "«Escríbenos» no abrió el formulario.")
    }

    // MARK: - L16-18 · Soporte

    func test_support_saysWhereItGoes() {
        let app = launch()
        app.openProfile()
        scrollTo(app, "profile_help_contact").tap()
        let footer = app.staticTexts["support_send_footer"]
        XCTAssertTrue(footer.waitForExistence(timeout: 10), "Falta el pie bajo «Enviar».")
        XCTAssertTrue(footer.label.contains("admin@yala-app.pe"), footer.label)
        capture(app, "L16-18-soporte")
    }

    // MARK: - L16-19 · Privacidad dentro de Yala

    func test_privacy_opensInsideYala() {
        let app = launch()
        app.openProfile()
        scrollTo(app, "profile_legal_privacy").tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertFalse(safari.wait(for: .runningForeground, timeout: 4), "La privacidad se abrió en Safari, fuera de Yala.")
        XCTAssertEqual(app.state, .runningForeground)
        capture(app, "L16-19-privacidad")
    }

    // MARK: - Tema de Pro al perder Pro

    /// Con un tema de Pro puesto y sin Pro, la hoja de fin de Pro avisa de que el tema vuelve a Liquid Glass.
    func test_proEnded_withProTheme_saysTheThemeGoesBack() {
        let app = launch {
            $0.launchForUITest(fakePricesTrialUsed: true, extraArguments: ["-userTheme", "4"])
        }
        guard let url = URL(string: "yaladev://uitest-notice?kind=pro-ended") else { return XCTFail("URL inválida") }
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        XCTAssertTrue(app.staticTexts["downgrade_title"].waitForExistence(timeout: 15), "No salió la hoja de fin de Pro.")
        XCTAssertTrue(app.descendants(matching: .any)["downgrade_theme_note"].exists, "La hoja no avisa del tema.")
        capture(app, "tema-pro-fin")
    }

    /// Control: con un tema gratis, la hoja no habla del tema (y sin nada más que decir, ni sale).
    func test_proEnded_withFreeTheme_noThemeNote() {
        let app = launch {
            $0.launchForUITest(seed: "realista", fakePricesTrialUsed: true, extraArguments: ["-userTheme", "8"])
        }
        guard let url = URL(string: "yaladev://uitest-notice?kind=pro-ended") else { return XCTFail("URL inválida") }
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
        XCTAssertTrue(app.staticTexts["downgrade_title"].waitForExistence(timeout: 15), "No salió la hoja de fin de Pro.")
        XCTAssertFalse(app.descendants(matching: .any)["downgrade_theme_note"].exists, "Habla del tema sin tema de Pro.")
    }
}
