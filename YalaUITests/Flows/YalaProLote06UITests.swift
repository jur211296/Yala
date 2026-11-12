//
//  YalaProLote06UITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2 · lote decidido 06 — Yala Pro como lo decidió Jürgen (L17-1…L17-9, L16-11). Los precios son los de
//  `Configuration.storekit`, pintados con `-uitest-fake-prices` (en `xcodebuild test` la tienda de pruebas no devuelve
//  nada), y la compra sale bien con `-uitest-fake-purchase`. Cada caso lleva su control: el estado en que NO debe pasar.
//

import XCTest

final class YalaProLote06UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launch(_ configure: (XCUIApplication) -> Void) -> XCUIApplication {
        let app = XCUIApplication()
        configure(app)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func tapVoice(_ app: XCUIApplication) {
        let voice = app.buttons["panel_action_voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 10), "No apareció Voz en el Panel.")
        XCTAssertTrue(voice.waitForHittable(timeout: 10), "Voz existe pero no se puede tocar.")
        voice.tap()
    }

    private func openFromOutside(_ app: XCUIApplication, _ link: String) {
        guard let url = URL(string: link) else { return XCTFail("URL inválida: \(link)") }
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")
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
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - L17-3 · L17-4 · «Función Pro» con los planes dentro

    /// Con la prueba disponible, la hoja de la voz dice lo que pasa, trae los dos planes y su botón promete la prueba.
    func test_voiceGate_titleSaysWhatHappens_plansInside_tryProFree() {
        let app = launch { $0.launchForUITest(fakePrices: true) }
        tapVoice(app)

        let cta = app.buttons["upgrade_prompt_cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10), "No salió «Función Pro».")
        XCTAssertEqual(app.staticTexts["upgrade_prompt_title"].label, "Apuntar hablando es de Yala Pro")
        XCTAssertTrue(app.buttons["pro_plan_yearly"].exists, "Los planes tenían que estar dentro de la hoja.")
        XCTAssertTrue(app.buttons["pro_plan_monthly"].exists, "Falta el plan mensual.")
        XCTAssertEqual(cta.label, "Probar Pro gratis 1 mes")
        XCTAssertTrue(app.buttons["upgrade_prompt_not_now"].exists, "Falta «Ahora no».")
        capture(app, "funcion-pro-voz")
    }

    /// Control de L17-4: a quien ya usó la prueba, el botón no la promete.
    func test_voiceGate_trialUsed_saysSwitchToPro() {
        let app = launch { $0.launchForUITest(fakePricesTrialUsed: true) }
        tapVoice(app)

        let cta = app.buttons["upgrade_prompt_cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10), "No salió «Función Pro».")
        XCTAssertEqual(cta.label, "Pasarme a Pro")
    }

    // MARK: - L17-9 · Tras comprar, se abre lo que se quería

    /// Comprar desde la hoja de la voz y tocar «Comenzar» cierra todo y deja el micrófono escuchando.
    func test_purchaseFromVoiceGate_comenzarOpensVoice() {
        let app = launch {
            $0.launchForUITest(aiConsent: true, fakePrices: true, fakePurchase: true,
                               extraArguments: ["-uitest-voice-result", "one"])
        }
        tapVoice(app)
        let cta = app.buttons["upgrade_prompt_cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10), "No salió «Función Pro».")
        cta.tap()

        let start = app.buttons["subscription_success_continue"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "No salió la bienvenida a Pro.")
        XCTAssertTrue(app.staticTexts["Ya puedes apuntar hablando."].exists, "La bienvenida no habla de la voz.")
        start.tap()

        XCTAssertTrue(app.buttons["voice_done"].waitForExistence(timeout: 15),
                      "Tras «Comenzar» tenía que abrirse la voz escuchando.")
        XCTAssertFalse(cta.exists, "«Función Pro» seguía abierta debajo.")
    }

    /// Control de L17-9: cerrar con «Ahora no», sin comprar, no abre la voz.
    func test_voiceGate_notNow_doesNotOpenVoice() {
        let app = launch { $0.launchForUITest(aiConsent: true, fakePrices: true, fakePurchase: true) }
        tapVoice(app)
        let notNow = app.buttons["upgrade_prompt_not_now"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 10), "No salió «Función Pro».")
        notNow.tap()
        XCTAssertFalse(app.buttons["voice_done"].waitForExistence(timeout: 5), "Sin comprar no se abre la voz.")
    }

    // MARK: - L17-1 · L17-2 · Ajustes y paywall

    /// «Yala Pro» arriba de Ajustes con el estado, y el paywall con los planes arriba y «Así funciona la prueba».
    func test_settingsRow_showsStatus_andPaywallExplainsTheTrial() {
        let app = launch { $0.launchForUITest(fakePrices: true) }
        app.openProfile()
        let row = app.buttons["profile_yala_pro"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No salió la fila «Yala Pro».")
        XCTAssertTrue(row.label.contains("Gratis · prueba 1 mes gratis"), "La fila no dice el estado: \(row.label)")
        row.tap()

        XCTAssertTrue(app.buttons["pro_plan_yearly"].waitForExistence(timeout: 10), "El paywall no trae los planes.")
        XCTAssertTrue(app.descendants(matching: .any)["pro_trial_timeline"].exists, "Falta «Así funciona la prueba».")
        XCTAssertEqual(app.buttons["subscription_cta"].label, "Probar gratis 1 mes")
        capture(app, "paywall")
    }

    /// Control de L17-2: sin derecho a la prueba no hay «Así funciona la prueba» ni se promete en la fila.
    func test_trialUsed_paywallHasNoTrialTimeline() {
        let app = launch { $0.launchForUITest(fakePricesTrialUsed: true) }
        app.openProfile()
        let row = app.buttons["profile_yala_pro"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No salió la fila «Yala Pro».")
        XCTAssertFalse(row.label.contains("prueba"), "Sin derecho a la prueba, la fila no la promete: \(row.label)")
        row.tap()
        XCTAssertTrue(app.buttons["pro_plan_yearly"].waitForExistence(timeout: 10), "El paywall no trae los planes.")
        XCTAssertFalse(app.descendants(matching: .any)["pro_trial_timeline"].exists,
                       "Sin derecho a la prueba no se explica cómo funciona.")
        XCTAssertEqual(app.buttons["subscription_cta"].label, "Suscribirse")
    }

    // MARK: - L17-5 · La oferta de prueba

    /// La X y «Quizás después» se ven sin bajar, y la X cierra.
    func test_trialOffer_closeAndMaybeLater_areInView() {
        let app = launch { $0.launchForUITest(trialOffer: true) }
        let close = app.buttons["trial_offer_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 15), "No salió la oferta de prueba.")
        XCTAssertTrue(close.isHittable, "La X tiene que estar a la vista.")
        XCTAssertTrue(app.buttons["trial_offer_dismiss"].isHittable, "«Quizás después» tiene que verse sin bajar.")
        capture(app, "oferta-prueba")
        close.tap()
        XCTAssertFalse(app.buttons["trial_offer_cta"].waitForExistence(timeout: 3), "La X no cerró la oferta.")
    }

    /// Control de L17-5: a quien ya usó la prueba la oferta no se le enseña.
    func test_trialOffer_notShownWhenTrialWasUsed() {
        let app = launch { $0.launchForUITest(trialOffer: true, fakePricesTrialUsed: true) }
        XCTAssertFalse(app.buttons["trial_offer_cta"].waitForExistence(timeout: 8),
                       "La oferta salió a quien ya usó la prueba.")
    }

    // MARK: - L17-6 · Una sola hoja al terminar la prueba

    /// La hoja de fin de Pro: título de la prueba, «Elegidos 3 de 3», aviso al tocar uno de más; y tras confirmar,
    /// «Prueba terminada» ya no sale (antes eran dos hojas seguidas).
    func test_proEnded_oneSheet_chosenCount_hint_andNoSecondSheet() {
        let app = launch { $0.launchForUITest(seed: "realista", fakePricesTrialUsed: true) }
        openFromOutside(app, "yaladev://uitest-notice?kind=pro-ended")

        let title = app.staticTexts["downgrade_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "No salió la hoja de fin de Pro.")
        XCTAssertEqual(title.label, "Tu prueba de Pro terminó")
        XCTAssertEqual(app.staticTexts["downgrade_budgets_chosen"].label, "Elegidos 3 de 3")
        XCTAssertTrue(app.descendants(matching: .any)["downgrade_keep_note"].exists, "Falta «no se borra nada».")

        // Tocar uno sin elegir con el cupo lleno avisa qué hacer.
        let unchosen = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Movilidad'")).firstMatch
        XCTAssertTrue(unchosen.waitForExistence(timeout: 5), "No apareció el presupuesto Movilidad.")
        unchosen.tap()
        XCTAssertTrue(app.descendants(matching: .any)["downgrade_full_hint"].waitForExistence(timeout: 5),
                      "Tocar uno de más no dijo nada.")
        capture(app, "fin-prueba-elegir")

        let confirm = app.buttons["downgrade_confirm"]
        XCTAssertEqual(confirm.label, "Conservar estos 3")
        confirm.tap()
        XCTAssertFalse(title.waitForExistence(timeout: 3), "La hoja no se cerró al confirmar.")

        openFromOutside(app, "yaladev://uitest-notice?kind=trial-expired")
        XCTAssertFalse(app.buttons["upgrade_prompt_cta"].waitForExistence(timeout: 8),
                       "Tras la hoja de fin de Pro salió una segunda («Prueba terminada»).")
    }

    /// Control de L17-6: sin la hoja de fin de Pro, «Prueba terminada» sí sale, con su título nuevo.
    func test_trialExpiredAlone_stillShows() {
        let app = launch { $0.launchForUITest(fakePricesTrialUsed: true) }
        openFromOutside(app, "yaladev://uitest-notice?kind=trial-expired")
        XCTAssertTrue(app.buttons["upgrade_prompt_cta"].waitForExistence(timeout: 10), "No salió «Prueba terminada».")
        XCTAssertEqual(app.staticTexts["upgrade_prompt_title"].label, "Tu prueba de Pro terminó")
    }

    /// Si se pagó, la hoja habla de la suscripción y no de la prueba.
    func test_proEnded_paid_saysSubscriptionEnded() {
        let app = launch {
            $0.launchForUITest(seed: "realista", fakePricesTrialUsed: true, extraArguments: ["-uitest-pro-ended-paid"])
        }
        openFromOutside(app, "yaladev://uitest-notice?kind=pro-ended")
        let title = app.staticTexts["downgrade_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "No salió la hoja de fin de Pro.")
        XCTAssertEqual(title.label, "Tu suscripción terminó")
    }

    // MARK: - L17-7 · El banner de la prueba

    /// En los últimos 5 días: una línea con los días y el precio, y «Gestionar».
    func test_trialBanner_lastFiveDays_showsDaysPriceAndManage() {
        let app = launch { $0.launchForUITest(pro: true, fakePrices: true, proTrialDays: 3) }
        let line = app.staticTexts["trial_banner_line"]
        XCTAssertTrue(line.waitForExistence(timeout: 10), "No salió el banner de la prueba.")
        XCTAssertEqual(line.label, "Te quedan 3 días de prueba · después $29.99 al año")
        XCTAssertTrue(app.buttons["trial_banner_manage"].exists, "Falta «Gestionar».")
        XCTAssertFalse(app.buttons["Suscribirse"].exists, "Volvió «Suscribirse».")
        capture(app, "banner-prueba-3")
    }

    /// Control de L17-7: con más de 5 días por delante, nada en el Panel.
    func test_trialBanner_hiddenBeforeTheLastFiveDays() {
        let app = launch { $0.launchForUITest(pro: true, fakePrices: true, proTrialDays: 12) }
        XCTAssertTrue(app.buttons["panel_action_voice"].waitForExistence(timeout: 10), "El Panel no cargó.")
        XCTAssertFalse(app.staticTexts["trial_banner_line"].waitForExistence(timeout: 3),
                       "El banner de la prueba salió con 12 días por delante.")
    }

    // MARK: - L17-8 · Pro activo

    /// La tarjeta del plan con fecha y precio, «Gestionar o cancelar» y qué pasa si se cancela.
    func test_proActive_showsPlanCardManageAndWhatHappensIfYouCancel() {
        let app = launch { $0.launchForUITest(pro: true, fakePrices: true, proPlan: "yearly") }
        app.openProfile()
        let row = app.buttons["profile_yala_pro"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No salió la fila «Yala Pro».")
        XCTAssertTrue(row.label.contains("Anual · se renueva el"), "La fila no dice el plan: \(row.label)")
        row.tap()

        let line = app.staticTexts["subscription_plan_line"]
        XCTAssertTrue(line.waitForExistence(timeout: 10), "Falta la línea del plan.")
        XCTAssertTrue(line.label.hasPrefix("Se renueva el"), "La línea no dice cuándo se renueva: \(line.label)")
        XCTAssertTrue(line.label.hasSuffix("$29.99 al año"), "La línea no dice el precio: \(line.label)")
        XCTAssertTrue(app.buttons["subscription_manage"].exists, "Falta «Gestionar o cancelar».")
        XCTAssertTrue(app.staticTexts["subscription_if_cancel"].exists, "Falta qué pasa si cancelas.")
        capture(app, "pro-activo")
    }

    /// Control de L17-8: con la renovación apagada no se dice «Se renueva».
    func test_proActive_renewalOff_saysEnds() {
        let app = launch { $0.launchForUITest(pro: true, fakePrices: true, proPlan: "yearly-off") }
        app.openProfile()
        let row = app.buttons["profile_yala_pro"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No salió la fila «Yala Pro».")
        XCTAssertTrue(row.label.contains("Anual · termina el"), "Sin renovación, la fila tiene que decir «termina»: \(row.label)")
    }

    // MARK: - L16-11 · Vista previa del tema y del icono

    /// Tocar un tema Pro siendo gratis enseña ese tema en el muro.
    func test_themeWall_showsThePreviewOfTheTappedTheme() {
        let app = launch { $0.launchForUITest(fakePrices: true) }
        app.openProfile()
        let themeRow = scrollTo(app, "profile_theme")
        XCTAssertTrue(themeRow.waitForExistence(timeout: 5), "No apareció la fila Temas.")
        themeRow.tap()

        let rosa = app.buttons["theme_card_4"]
        XCTAssertTrue(rosa.waitForExistence(timeout: 5), "No apareció el tema Rosa.")
        rosa.tap()
        XCTAssertTrue(app.descendants(matching: .any)["upgrade_prompt_preview"].waitForExistence(timeout: 10),
                      "El muro no enseña la vista previa del tema.")
        XCTAssertEqual(app.staticTexts["upgrade_prompt_title"].label, "El tema Rosa es de Yala Pro")
        capture(app, "muro-tema")
    }

    /// Tocar un icono Pro siendo gratis enseña ese icono en el muro.
    func test_iconWall_showsThePreviewOfTheTappedIcon() {
        let app = launch { $0.launchForUITest(fakePrices: true) }
        app.openProfile()
        let iconRow = scrollTo(app, "profile_app_icon")
        XCTAssertTrue(iconRow.waitForExistence(timeout: 5), "No apareció la fila Icono de la app.")
        iconRow.tap()

        let neon = app.buttons["app_icon_neon"]
        XCTAssertTrue(neon.waitForExistence(timeout: 5), "No apareció el icono Neón.")
        neon.tap()
        XCTAssertTrue(app.descendants(matching: .any)["upgrade_prompt_preview"].waitForExistence(timeout: 10),
                      "El muro no enseña la vista previa del icono.")
        XCTAssertTrue(app.staticTexts["upgrade_prompt_title"].label.hasPrefix("El icono"),
                      "El título no habla del icono tocado.")
        capture(app, "muro-icono")
    }

    /// Control de L16-11: la hoja de la voz no trae vista previa.
    func test_voiceGate_hasNoPreview() {
        let app = launch { $0.launchForUITest(fakePrices: true) }
        tapVoice(app)
        XCTAssertTrue(app.buttons["upgrade_prompt_cta"].waitForExistence(timeout: 10), "No salió «Función Pro».")
        XCTAssertFalse(app.descendants(matching: .any)["upgrade_prompt_preview"].exists,
                       "La hoja de la voz no tiene nada que previsualizar.")
    }
}
