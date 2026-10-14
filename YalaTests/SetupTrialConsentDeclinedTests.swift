//
//  SetupTrialConsentDeclinedTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 5 · B2: cancelar el aviso de IA en la práctica de voz o de imagen de «Primeros pasos»
//  dejaba la función abierta sin Pro. `PanelSheetState.endSetupTrialsThatNeverOpened` apaga lo que quedó armado y
//  dice qué funciones hay que volver a cerrar.
//

import Testing

@testable import Yala

@Suite("Práctica de «Primeros pasos» sin aceptar el aviso de IA")
struct SetupTrialConsentDeclinedTests {

    @Test func voicePractice_isEnded_andVoiceIsReturned() {
        var sheets = PanelSheetState()
        sheets.isVoiceSetupTrial = true

        #expect(sheets.endSetupTrialsThatNeverOpened() == [.voiceInput])
        #expect(!sheets.isVoiceSetupTrial)
    }

    @Test func imagePractice_isEnded_withItsExampleImages() {
        var sheets = PanelSheetState()
        sheets.isImageSetupTrial = true
        sheets.setupTrialExampleImages = []

        #expect(sheets.endSetupTrialsThatNeverOpened() == [.imageInput])
        #expect(!sheets.isImageSetupTrial)
        #expect(sheets.setupTrialExampleImages == nil)
    }

    /// Sin práctica armada —el aviso salió desde el botón Voz del Panel— no se cierra nada.
    @Test func withoutPractice_nothingToClose() {
        var sheets = PanelSheetState()
        #expect(sheets.endSetupTrialsThatNeverOpened().isEmpty)
    }
}
