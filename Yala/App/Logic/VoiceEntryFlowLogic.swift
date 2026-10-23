//
//  VoiceEntryFlowLogic.swift
//  Yala
//
//  Lo que el registro por voz decide sin vista (propuesta C, 2026-10-04): qué le contamos al usuario cuando algo
//  falla y si lo entendido ya se puede guardar. Puro, para probarlo sin simulador.
//

import Foundation

/// Por qué no salió el registro, contado como lo vive el usuario. Nunca se le enseña `localizedDescription`: los
/// errores de grabación, transcripción y lectura vienen en inglés o en técnico («Network error… AppAttestError 2»).
enum VoiceEntryFailure: Equatable {
    case noConnection
    case micPermission
    /// La grabación llegó vacía o duró menos de lo mínimo.
    case noVoice
    case noAmount
    /// El servicio de voz no está disponible en esta versión (sin clave).
    case serviceUnavailable
    case saveFailed
    case generic
    /// El plan free ya usó su cupo de prueba de notas de voz: la salida es Yala Pro (no se repone esperando).
    case trialUsedUp
    /// El gateway frenó la petición por ráfaga (429 `yala_quota_burst`): esperar un minuto lo arregla (card vv0k).
    case busy
    /// Se acabó el cupo de notas de hoy (429 `yala_quota_daily`): vuelve mañana.
    case dailyLimit

    /// Si tiene sentido volver a mandar el MISMO audio. Con la conexión caída o sin clave, repetir falla igual; sin
    /// voz o sin importe, el audio es el problema y hay que grabar otra vez.
    var retriesSameAudio: Bool {
        switch self {
        case .generic, .saveFailed, .busy: true
        case .noConnection, .micPermission, .noVoice, .noAmount, .serviceUnavailable, .trialUsedUp, .dailyLimit: false
        }
    }
}

/// Lo justo de un borrador para saber si «Guardar» puede aprobarlo con `DraftService.approveDraft`, que exige
/// importe, cuenta activa, subcategoría y una fecha que no sea futura.
struct VoiceDraftReadiness: Equatable {
    var hasAmount: Bool
    var hasAccount: Bool
    var accountIsArchived: Bool
    var hasSubcategory: Bool
    var isFutureDate: Bool

    var isComplete: Bool {
        hasAmount && hasAccount && !accountIsArchived && hasSubcategory && !isFutureDate
    }
}

enum VoiceEntryFlowLogic {

    // MARK: - Fallos

    static func failure(for error: RecordingError) -> VoiceEntryFailure {
        switch error {
        case .microphonePermissionDenied, .microphonePermissionRestricted: .micPermission
        case .recordingTooShort: .noVoice
        case .failedToStartRecording, .noRecordingInProgress, .failedToReadAudioFile: .generic
        }
    }

    static func failure(for error: TranscriptionError, isConnected: Bool) -> VoiceEntryFailure {
        switch error {
        case .noAPIKey: .serviceUnavailable
        case .emptyAudio: .noVoice
        case .networkError(let inner): failure(forNetworkError: inner, isConnected: isConnected)
        case .transcriptionFailed: .generic
        }
    }

    static func failure(for error: ParserError, isConnected: Bool) -> VoiceEntryFailure {
        switch error {
        case .noAPIKey: .serviceUnavailable
        case .emptyText: .noVoice
        case .networkError(let inner): failure(forNetworkError: inner, isConnected: isConnected)
        case .parsingFailed, .invalidResponse: .generic
        }
    }

    /// Lo que el gateway contestó con nombre propio va con su texto; lo demás, sin red o «inténtalo otra vez».
    static func failure(forNetworkError inner: Error, isConnected: Bool) -> VoiceEntryFailure {
        if ProxyErrorMapper.isTrialExhausted(inner) { return .trialUsedUp }
        if ProxyErrorMapper.isDailyLimitReached(inner) { return .dailyLimit }
        if ProxyErrorMapper.isBurstLimited(inner) { return .busy }
        return isConnected ? .generic : .noConnection
    }

    /// El detalle del canario `aiEntryReadFailed`, o `nil` si el error no habla del camino al gateway.
    static func canaryDetail(for error: TranscriptionError) -> String? {
        switch error {
        case .networkError(let inner):
            ProxyErrorMapper.isTrialExhausted(inner) ? nil : "voice-transcribe|\(ProxyErrorMapper.failureKind(inner))"
        case .noAPIKey, .emptyAudio, .transcriptionFailed: nil
        }
    }

    static func canaryDetail(for error: ParserError) -> String? {
        switch error {
        case .networkError(let inner):
            ProxyErrorMapper.isTrialExhausted(inner) ? nil : "voice-parse|\(ProxyErrorMapper.failureKind(inner))"
        case .invalidResponse: "voice-parse|invalidResponse"
        case .noAPIKey, .emptyText, .parsingFailed: nil
        }
    }

    /// Cualquier otro error: sin conexión es lo único que el usuario puede arreglar; lo demás es un «inténtalo otra vez».
    static func failure(forUnknownErrorWhenConnected isConnected: Bool) -> VoiceEntryFailure {
        isConnected ? .generic : .noConnection
    }

    // MARK: - Guardar

    /// «Guardar» aprueba TODOS los que siguen pendientes de una vez, así que solo se enciende si todos están completos.
    /// Sin pendientes no hay nada que guardar.
    static func canSave(_ pending: [VoiceDraftReadiness]) -> Bool {
        !pending.isEmpty && pending.allSatisfy(\.isComplete)
    }
}
