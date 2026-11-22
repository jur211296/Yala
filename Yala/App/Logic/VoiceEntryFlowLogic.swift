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

    // MARK: - Importe en «Esto leí»

    /// El importe que pinta la tarjeta de revisión de voz y foto: sin signo, como en 2.1 (card ex73). El borrador lo
    /// guarda con signo (negativo es gasto) y eso no cambia; solo cambia cómo se enseña.
    static func reviewDisplayedAmount(_ signedAmount: Double) -> Double {
        abs(signedAmount)
    }

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

// MARK: - «Esto leí» con la tarjeta B1 (opción A)

/// Lo que la hoja «Esto leí» / «Esto entendí» decide sin pintar nada desde la opción A (elegida por Jürgen el
/// 2026-11-22; maqueta en `docs/propuestas/2026-11-22-esto-lei/`). Puro, para probarlo sin simulador
/// (`YalaTests/EstoLei/`).
enum EstoLeiLogic {

    /// Lo que le falta a un registro para guardarse, en el orden en que la tarjeta lo pide.
    enum Missing: Equatable {
        case amount
        case subcategory
        case account
    }

    static func missing(_ readiness: VoiceDraftReadiness) -> [Missing] {
        var missing: [Missing] = []
        if !readiness.hasAmount { missing.append(.amount) }
        if !readiness.hasSubcategory { missing.append(.subcategory) }
        if !readiness.hasAccount || readiness.accountIsArchived { missing.append(.account) }
        return missing
    }

    /// Con varios, la fila que sale desplegada sola: la primera, en el orden en que se pintan, que está marcada, sigue
    /// pendiente y le falta algo. Si ninguna, ninguna.
    static func autoExpanded<ID: Hashable>(
        _ items: [MultiDraftReviewLogic.Item<ID>],
        _ selection: MultiDraftReviewLogic.Selection<ID>,
        order: [ID]
    ) -> ID? {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return order.first { id in
            guard let item = byID[id] else { return false }
            return item.isPending && !item.isComplete && selection.contains(id)
        }
    }

    /// La fila desplegada sigue siéndolo mientras exista; si desapareció (guardada desde «Ver todo», descartada) o no
    /// había ninguna, se abre la siguiente que lo pida.
    static func expandedAfterChange<ID: Hashable>(
        current: ID?,
        _ items: [MultiDraftReviewLogic.Item<ID>],
        _ selection: MultiDraftReviewLogic.Selection<ID>,
        order: [ID]
    ) -> ID? {
        if let current, items.contains(where: { $0.id == current && !$0.isSaved }) { return current }
        return autoExpanded(items, selection, order: order)
    }

    /// «Otra foto» / «Otra vez» suman a lo que ya está en la hoja (recorrido A, paso 4). La deduplicación puede devolver
    /// un borrador que ya se enseña (se leyó dos veces el mismo recibo): ese no se repite.
    static func appended<Element, ID: Hashable>(_ existing: [Element], _ new: [Element], id: (Element) -> ID) -> [Element] {
        var seen = Set(existing.map(id))
        var result = existing
        for element in new where seen.insert(id(element)).inserted {
            result.append(element)
        }
        return result
    }

    /// Lo que dijiste, tras otra grabación: lo de antes y lo nuevo, en dos párrafos.
    static func joinedTranscription(_ previous: String, _ new: String) -> String {
        let old = previous.trimmingCharacters(in: .whitespacesAndNewlines)
        let added = new.trimmingCharacters(in: .whitespacesAndNewlines)
        if old.isEmpty { return added }
        if added.isEmpty { return old }
        return "\(old)\n\n\(added)"
    }

    /// Al cerrar con algo sin guardar, el aviso «Lo que leí quedó en tu Bandeja · Ver» (recorrido A, paso 5). No en la
    /// práctica guiada, que ya dice qué pasa con lo de prueba.
    static func showsInboxNoticeOnClose(pendingCount: Int, isSetupTrial: Bool) -> Bool {
        pendingCount > 0 && !isSetupTrial
    }

    /// La primera oración de la línea ✦ («Elegí BCP Crédito porque la imagen lo dice.»), para cuando la frase entera no
    /// cabe en una línea. Sin punto seguido de espacio, la frase entera.
    static func firstSentence(_ text: String) -> String {
        guard let range = text.range(of: ". ") else { return text }
        return String(text[..<range.lowerBound]) + "."
    }

    /// Los botones de abajo van siempre en una fila (nunca uno debajo de otro): con texto de accesibilidad, «Otra foto»
    /// / «Otra vez» se quedan en su icono y «Guardar» se lleva el ancho.
    static func secondaryShowsTitle(isAccessibilitySize: Bool) -> Bool {
        !isAccessibilitySize
    }
}
