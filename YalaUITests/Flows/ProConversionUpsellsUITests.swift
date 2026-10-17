//
//  ProConversionUpsellsUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `pro-conversion-upsells`: un usuario free que toca
//  una feature Pro (entrada por voz desde el menú del FAB) ve el UpgradePromptSheet
//  de conversión; la entrada manual (gratuita) NO lo muestra (control).
//  Lanza SIN -uitest-pro (usuario free). El flujo es 100% determinista: el gate
//  setea un flag local (`showUpgradeForVoice`) que presenta el sheet — sin red,
//  StoreKit, LLM ni permisos de sistema. NO se toca el CTA "Actualizar a Pro"
//  (abriría SubscriptionView, que sí carga productos de StoreKit por red).
//  Seed `minimal` (basta con 1 cuenta activa + subcategorías para habilitar el menú).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class ProConversionUpsellsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Abre el menú del FAB (voz / imagen / manual) desde el Panel (tab default).
    private func openFABMenu(_ app: XCUIApplication) {
        app.revealPanelFAB().tap()
    }

    /// Usuario free → tocar la entrada por voz (feature Pro) dispara el upsell.
    func test_gatedVoiceFeatureShowsUpgradePrompt() {
        let app = XCUIApplication()
        app.launchForUITest(pro: false)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openFABMenu(app)

        let voiceButton = app.buttons["fab_voice"]
        XCTAssertTrue(voiceButton.waitForExistence(timeout: 5), "No apareció el botón de voz del menú del FAB.")
        voiceButton.tap()

        // El gate presenta UpgradePromptSheet(.voiceInput, .proFeature); su CTA
        // único confirma que el upsell de conversión está visible.
        XCTAssertTrue(
            app.buttons["upgrade_prompt_cta"].waitForExistence(timeout: 5),
            "No apareció el UpgradePromptSheet (upgrade_prompt_cta) al tocar una feature Pro siendo free."
        )
    }

    /// Control: la entrada manual es gratuita → abre el formulario, sin upsell.
    func test_manualEntryDoesNotShowUpsell() {
        let app = XCUIApplication()
        app.launchForUITest(pro: false)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openFABMenu(app)

        let manualButton = app.buttons["fab_manual"]
        XCTAssertTrue(manualButton.waitForExistence(timeout: 5), "No apareció el botón manual del menú del FAB.")
        manualButton.tap()

        // Abre el formulario de transacción (gratuito), no el upsell.
        XCTAssertTrue(
            app.textFields["new_transaction_amount"].waitForExistence(timeout: 5),
            "La entrada manual no abrió el formulario de transacción (new_transaction_amount)."
        )
        XCTAssertFalse(
            app.buttons["upgrade_prompt_cta"].exists,
            "La entrada manual (gratuita) no debería mostrar el upsell de conversión."
        )
    }
    // MARK: - Auditoría UX 2.2 · lote 17

    /// B1: en el simulador la App Store no devuelve precios (no hay configuración StoreKit en `xcodebuild test`),
    /// así que es el estado de «sin conexión» de un usuario real. Antes el paywall dejaba «Suscribirse» en gris sin
    /// decir nada; ahora lo dice y deja reintentar.
    func test_paywallWithoutPrices_saysSoAndOffersRetry() {
        let app = XCUIApplication()
        app.launchForUITest(pro: false)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openFABMenu(app)
        let voiceButton = app.buttons["fab_voice"]
        XCTAssertTrue(voiceButton.waitForExistence(timeout: 5), "No apareció el botón de voz del menú del FAB.")
        voiceButton.tap()
        let cta = app.buttons["upgrade_prompt_cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 5), "No apareció el UpgradePromptSheet.")
        cta.tap()

        let unavailable = app.descendants(matching: .any)["subscription_prices_unavailable"]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 20),
                      "Sin precios, el paywall tenía que decirlo (subscription_prices_unavailable).")
        XCTAssertTrue(app.buttons["subscription_prices_retry"].exists, "Falta «Reintentar» junto al aviso de precios.")
    }

    /// B6: «Prueba terminada» no la abre ninguna función, así que no destaca una. Antes decía «Registro por voz · PRO»
    /// a todo el mundo. Control: la hoja de la voz sí la destaca.
    func test_trialExpired_doesNotHighlightVoice() {
        let app = XCUIApplication()
        app.launchForUITest(pro: false)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        guard let url = URL(string: "yaladev://uitest-notice?kind=trial-expired") else { return XCTFail("URL inválida") }
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")

        XCTAssertTrue(app.buttons["upgrade_prompt_cta"].waitForExistence(timeout: 10), "No salió «Prueba terminada».")
        XCTAssertFalse(app.descendants(matching: .any)["upgrade_prompt_feature_row"].exists,
                       "«Prueba terminada» volvió a destacar una función concreta.")
    }

    /// Control de B6: la hoja que abre una función sí la destaca.
    func test_proFeaturePrompt_highlightsItsFeature() {
        let app = XCUIApplication()
        app.launchForUITest(pro: false)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openFABMenu(app)
        let voiceButton = app.buttons["fab_voice"]
        XCTAssertTrue(voiceButton.waitForExistence(timeout: 5), "No apareció el botón de voz del menú del FAB.")
        voiceButton.tap()
        XCTAssertTrue(app.buttons["upgrade_prompt_cta"].waitForExistence(timeout: 5), "No apareció el UpgradePromptSheet.")
        XCTAssertTrue(app.descendants(matching: .any)["upgrade_prompt_feature_row"].waitForExistence(timeout: 3),
                      "La hoja de la voz tenía que destacar «Registro por voz».")
    }
}
