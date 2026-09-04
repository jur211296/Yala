//
//  VoiceInputCurrencyExamplesUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `voice-input-currency-examples` (escenarios 25.4.x):
//  la vista de entrada por voz muestra ejemplos de frases con la moneda preferida.
//  Esa sección es estática (no requiere grabar) → el permiso de micrófono (que se
//  pide en startRecording, no al abrir) queda fuera. Voz es Pro + requiere consent
//  IA → se lanza con `pro` + `-uitest-ai-consent` para destrabar la navegación
//  (sin grabar ni transcribir). La transcripción/parsing real queda manual.
//  Convenciones: ver CLAUDE.md (sin sleeps, page-objects, scheme Yala Dev).
//

import XCTest

final class VoiceInputCurrencyExamplesUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Abrir la entrada por voz (FAB → voz, Pro + consent) muestra la sección de
    /// ejemplos con la moneda. No se graba (sin prompt de micrófono).
    func test_voiceViewShowsCurrencyExamples() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, aiConsent: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Abrir el menú del FAB y elegir voz.
        app.revealPanelFAB().tap()

        let voice = app.buttons["fab_voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5), "El menú del FAB no ofreció voz (fab_voice).")
        voice.tap()

        // Con Pro + consent, se abre VoiceRecordingView (no el upsell ni el consent alert).
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "voice_examples").firstMatch
                .waitForExistence(timeout: 30),
            "No se mostró la sección de ejemplos de la entrada por voz (voice_examples)."
        )
    }
}
