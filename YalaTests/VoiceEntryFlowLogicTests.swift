//
//  VoiceEntryFlowLogicTests.swift
//  YalaTests
//
//  El registro por voz (propuesta C): qué fallo se le cuenta al usuario por cada error y cuándo se puede guardar lo
//  entendido. Lógica pura, sin grabador, red ni SwiftData.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Registro por voz — lógica del flujo")
struct VoiceEntryFlowLogicTests {

    private struct Stub: Error {}

    // MARK: - Fallos de grabación

    @Test func micDenied_orRestricted_asksForSettings() {
        #expect(VoiceEntryFlowLogic.failure(for: RecordingError.microphonePermissionDenied) == .micPermission)
        #expect(VoiceEntryFlowLogic.failure(for: RecordingError.microphonePermissionRestricted) == .micPermission)
    }

    @Test func tooShortRecording_isNoVoice_notAGenericError() {
        #expect(VoiceEntryFlowLogic.failure(for: RecordingError.recordingTooShort) == .noVoice)
    }

    @Test func otherRecordingErrors_areGeneric() {
        #expect(VoiceEntryFlowLogic.failure(for: RecordingError.failedToStartRecording) == .generic)
        #expect(VoiceEntryFlowLogic.failure(for: RecordingError.noRecordingInProgress) == .generic)
        #expect(VoiceEntryFlowLogic.failure(for: RecordingError.failedToReadAudioFile) == .generic)
    }

    // MARK: - Fallos de transcripción y lectura

    /// El caso medido en el simulador el 2026-10-04: «Network error: … AppAttestError 2» salía tal cual. Con conexión,
    /// un error de red es un «inténtalo otra vez»; sin ella, la causa que el usuario sí puede arreglar.
    @Test func transcriptionNetworkError_dependsOnConnection() {
        let error = TranscriptionError.networkError(Stub())
        #expect(VoiceEntryFlowLogic.failure(for: error, isConnected: true) == .generic)
        #expect(VoiceEntryFlowLogic.failure(for: error, isConnected: false) == .noConnection)
    }

    @Test func transcriptionErrors_mapToWhatTheUserLives() {
        #expect(VoiceEntryFlowLogic.failure(for: TranscriptionError.noAPIKey, isConnected: true) == .serviceUnavailable)
        #expect(VoiceEntryFlowLogic.failure(for: TranscriptionError.emptyAudio, isConnected: true) == .noVoice)
        #expect(VoiceEntryFlowLogic.failure(for: TranscriptionError.transcriptionFailed("x"), isConnected: true) == .generic)
    }

    @Test func parserErrors_mapToWhatTheUserLives() {
        #expect(VoiceEntryFlowLogic.failure(for: ParserError.noAPIKey, isConnected: true) == .serviceUnavailable)
        #expect(VoiceEntryFlowLogic.failure(for: ParserError.emptyText, isConnected: true) == .noVoice)
        #expect(VoiceEntryFlowLogic.failure(for: ParserError.invalidResponse, isConnected: true) == .generic)
        #expect(VoiceEntryFlowLogic.failure(for: ParserError.parsingFailed("x"), isConnected: true) == .generic)
        #expect(VoiceEntryFlowLogic.failure(for: ParserError.networkError(Stub()), isConnected: false) == .noConnection)
    }

    @Test func unknownError_isNoConnection_onlyWhenOffline() {
        #expect(VoiceEntryFlowLogic.failure(forUnknownErrorWhenConnected: true) == .generic)
        #expect(VoiceEntryFlowLogic.failure(forUnknownErrorWhenConnected: false) == .noConnection)
    }

    /// Reenviar el mismo audio solo sirve si el fallo no estaba en el audio ni en algo que siga igual.
    @Test func onlyTransientFailures_retryTheSameAudio() {
        #expect(VoiceEntryFailure.generic.retriesSameAudio)
        #expect(VoiceEntryFailure.saveFailed.retriesSameAudio)
        for failure in [VoiceEntryFailure.noConnection, .micPermission, .noVoice, .noAmount, .serviceUnavailable] {
            #expect(!failure.retriesSameAudio, "\(failure)")
        }
    }

    // MARK: - Guardar

    private func ready(
        amount: Bool = true,
        account: Bool = true,
        archived: Bool = false,
        subcategory: Bool = true,
        future: Bool = false
    ) -> VoiceDraftReadiness {
        VoiceDraftReadiness(
            hasAmount: amount,
            hasAccount: account,
            accountIsArchived: archived,
            hasSubcategory: subcategory,
            isFutureDate: future
        )
    }

    @Test func completeDraft_canBeSaved() {
        #expect(VoiceEntryFlowLogic.canSave([ready()]))
        #expect(VoiceEntryFlowLogic.canSave([ready(), ready()]))
    }

    /// Cada condición que `DraftService.approveDraft` rechaza apaga «Guardar»: si no, el botón se vería encendido y
    /// fallaría al tocarlo.
    @Test func eachMissingPiece_blocksSave() {
        #expect(!VoiceEntryFlowLogic.canSave([ready(amount: false)]))
        #expect(!VoiceEntryFlowLogic.canSave([ready(account: false)]))
        #expect(!VoiceEntryFlowLogic.canSave([ready(archived: true)]))
        #expect(!VoiceEntryFlowLogic.canSave([ready(subcategory: false)]))
        #expect(!VoiceEntryFlowLogic.canSave([ready(future: true)]))
    }

    /// «Guardar 2» guarda los dos: con uno incompleto, ninguno.
    @Test func oneIncompleteDraft_blocksSavingAll() {
        #expect(!VoiceEntryFlowLogic.canSave([ready(), ready(subcategory: false)]))
    }

    @Test func nothingPending_hasNothingToSave() {
        #expect(!VoiceEntryFlowLogic.canSave([]))
    }
}
