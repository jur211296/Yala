//
//  VoiceInputCurrencyExamplesUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `voice-input-currency-examples` (escenarios 25.4.x).
//
//  Desde el 2026-10-04 (registro por voz, propuesta C) la hoja de voz NO tiene pantalla de reposo con ejemplos: al
//  abrirse ya escucha, con el panel del dictado de Yala IA (orbe, tiempo, Cancelar / Listo) y una pista sin moneda que
//  sirve en cualquier país. Este caso fija esa entrada: tocar Voz (Pro + consent) monta el panel de escucha, no el
//  upsell, ni el aviso de consentimiento, ni la pantalla vieja.
//
//  El simulador pide permiso de micrófono al abrir; el caso no toca nada después, así que el aviso del sistema no
//  cambia el veredicto. La grabación, la transcripción y la lectura reales quedan en el device-QA del ticket
//  `voice-entry-end-to-end`.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class VoiceInputCurrencyExamplesUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Abrir la entrada por voz (FAB → voz, Pro + consent) monta directamente el panel de escucha.
    func test_voiceEntryOpensListeningRightAway() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, aiConsent: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.revealPanelFAB().tap()

        let voice = app.buttons["fab_voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5), "El menú del FAB no ofreció voz (fab_voice).")
        voice.tap()

        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "voice_listening_panel").firstMatch
                .waitForExistence(timeout: 30),
            "Tocar Voz no montó el panel de escucha (voice_listening_panel)."
        )
        XCTAssertTrue(
            app.buttons["voice_cancel"].exists,
            "El panel de escucha no ofrece Cancelar (voice_cancel)."
        )
        XCTAssertFalse(
            app.descendants(matching: .any).matching(identifier: "voice_examples").firstMatch.exists,
            "Sigue la pantalla de reposo con ejemplos (voice_examples): la hoja tenía que abrir escuchando."
        )
    }
}
