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
        let fab = app.buttons["fab_new_transaction"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el FAB principal (fab_new_transaction).")
        fab.tap()
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
}
