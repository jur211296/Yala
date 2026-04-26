//
//  ChatAssistantViewModel.swift
//  Yala
//
//  State management for Ask Yala chat assistant.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class ChatAssistantViewModel {

    // MARK: - State

    private(set) var messages: [ChatMessage] = []
    private(set) var isLoading = false
    private(set) var suggestions: [ChatSuggestion] = []
    private(set) var suggestionsLoading: Bool = false
    private(set) var suggestionsFailed: Bool = false

    /// El chat está disponible cuando el LLM responde correctamente. Si la primera carga
    /// del día falla, el input bar y temas se deshabilitan globalmente hasta que el user
    /// pulse "Reintentar".
    var isAIAvailable: Bool { !suggestionsFailed }
    private(set) var isRecording = false
    private(set) var isTranscribing = false
    private(set) var errorMessage: String?
    var inputText: String = ""

    // MARK: - Multi-turn Memory (todos los turnos del día calendario)

    /// Hard cap defensivo. Daily limit es 75; este cap solo aplica si algún día
    /// se sube ese limit. GPT-4.1-nano (128k context) maneja 50 turnos sin problema.
    private static let maxTurns = 50

    private(set) var allTurns: [QAPair] = []

    /// Número de turnos que el LLM recuerda activamente. Para mostrar contador en la UI.
    var turnCount: Int { allTurns.count }

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private let service = ChatAssistantService.shared

    // MARK: - Persistence (day-calendar `chat_session_<YYYY-MM-DD>`)

    private static let sessionKeyPrefix = "chat_session_"

    private static func sessionKey(for date: Date) -> String {
        sessionKeyPrefix + DayKeyFormatter.string(from: date)
    }

    // MARK: - Setup

    func setContext(_ ctx: ModelContext) {
        modelContext = ctx
        loadPersistedSession()
        if messages.isEmpty {
            Task { await loadSuggestions() }
        }
    }

    // MARK: - Suggestions (LLM-only — sin fallback rule-based)

    /// Carga sugerencias para el empty state. Si el LLM falla, expone el error
    /// vía `suggestionsFailed` para que la View muestre estado de no disponible.
    /// La View se encarga de deshabilitar funciones y ofrecer "Reintentar".
    func loadSuggestions() async {
        guard let context = modelContext else { return }

        suggestionsLoading = true
        suggestionsFailed = false
        defer { suggestionsLoading = false }

        let llmResults = await ChatSuggestionsLLMService.shared.fetchOrGenerate(modelContext: context)

        if llmResults.isEmpty {
            suggestionsFailed = true
            suggestions = []
        } else {
            suggestions = llmResults
        }
    }

    // MARK: - Send Question

    func sendQuestion(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let context = modelContext else { return }
        guard !isLoading else { return }

        errorMessage = nil
        isLoading = true
        inputText = ""

        // Add user message
        let userMessage = ChatMessage(role: .user, text: trimmed, timestamp: Date.now)
        messages.append(userMessage)

        do {
            let currencyCode = CurrencyDefaults.currentPreferred
            let (responseText, toolName) = try await service.processQuestion(
                question: trimmed,
                turns: allTurns,
                modelContext: context,
                currencyCode: currencyCode,
                converter: CurrencyConverter.shared
            )

            let assistantMessage = ChatMessage(role: .assistant, text: responseText, timestamp: Date.now)
            messages.append(assistantMessage)

            // Append turn al historial completo del día. Hard trim defensivo a maxTurns.
            allTurns.append(QAPair(
                question: trimmed,
                toolName: toolName,
                toolResultJSON: nil,
                response: responseText,
                timestamp: Date.now
            ))
            if allTurns.count > Self.maxTurns {
                allTurns.removeFirst(allTurns.count - Self.maxTurns)
            }

            TelemetryService.track(.chatQuestionAsked, parameters: [
                "source": "typed",
                "tool_used": toolName ?? "direct"
            ])

            // Autosave defensivo: persiste la sesión tras cada respuesta exitosa
            persistSession()
        } catch let error as ChatAssistantError {
            handleError(error)
        } catch {
            handleError(.networkError(error))
        }

        isLoading = false
    }

    func sendSuggestion(_ suggestion: ChatSuggestion) async {
        TelemetryService.track(.chatSuggestionTapped, parameters: [
            "type": String(describing: suggestion.type)
        ])
        await sendQuestion(suggestion.text)
    }

    // MARK: - Error Handling

    private func handleError(_ error: ChatAssistantError) {
        switch error {
        case .timeout:
            errorMessage = L10n.Chat.errorTimeout
        case .offline:
            errorMessage = L10n.Chat.errorOffline
        case .dailyLimitReached:
            errorMessage = L10n.Chat.dailyLimitReached
            TelemetryService.track(.chatDailyLimitReached)
        case .questionTooLong:
            errorMessage = L10n.Chat.questionTooLong
        case .rateLimited:
            errorMessage = nil // silent, just wait
        case .toolExecutionFailed:
            errorMessage = L10n.Chat.errorNoData
        default:
            errorMessage = L10n.Chat.errorGeneric
        }

        if errorMessage != nil {
            TelemetryService.track(.chatErrorOccurred, parameters: [
                "error": String(describing: error)
            ])
        }

        // Remove the user message if we got an error (so they can retry)
        if let last = messages.last, last.role == .user {
            inputText = last.text
            messages.removeLast()
        }
    }

    // MARK: - Context Hint (one-time, after first response)

    private var contextHintDismissed: Bool = UserDefaults.standard.bool(forKey: "hasSeenChatContextHint")

    var showContextHint: Bool {
        !contextHintDismissed && messages.contains(where: { $0.role == .assistant })
    }

    func dismissContextHint() {
        contextHintDismissed = true
        UserDefaults.standard.set(true, forKey: "hasSeenChatContextHint")
    }

    // MARK: - Limits

    var questionsRemaining: Int {
        max(0, ChatAssistantService.dailyLimit - service.questionsToday)
    }

    var showQuestionCounter: Bool {
        service.questionsToday >= ChatAssistantService.dailyLimit - 10
    }

    var canAskMore: Bool {
        service.questionsToday < ChatAssistantService.dailyLimit
    }

    // MARK: - Persistence (day-calendar via UserDefaults)

    /// Persiste la sesión actual en `UserDefaults` bajo `chat_session_<today>`.
    /// Llamado desde `onDisappear` y como autosave defensivo tras cada respuesta exitosa.
    func persistSession() {
        let key = Self.sessionKey(for: Date.now)
        let defaults = UserDefaults.standard

        guard !messages.isEmpty else {
            defaults.removeObject(forKey: key)
            return
        }

        let blob = ChatPersistedSession(messages: messages, allTurns: allTurns)
        do {
            let data = try JSONEncoder().encode(blob)
            defaults.set(data, forKey: key)
        } catch {
            #if DEBUG
            print("ChatAssistantViewModel: persistSession failed: \(error)")
            #endif
        }
    }

    /// Hidrata sesión del día actual si existe; limpia claves de días anteriores.
    private func loadPersistedSession() {
        let defaults = UserDefaults.standard
        let todayKey = Self.sessionKey(for: Date.now)

        // Cleanup: borra todas las claves chat_session_* que NO sean del día actual
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix(Self.sessionKeyPrefix) && key != todayKey {
            defaults.removeObject(forKey: key)
        }

        guard let data = defaults.data(forKey: todayKey) else { return }

        do {
            let blob = try JSONDecoder().decode(ChatPersistedSession.self, from: data)
            messages = blob.messages
            allTurns = blob.allTurns
            if !messages.isEmpty {
                TelemetryService.track(.chatPersistedSessionRehydrated, parameters: [
                    "messageCount": String(messages.count),
                    "turnCount": String(allTurns.count)
                ])
            }
        } catch {
            #if DEBUG
            print("ChatAssistantViewModel: loadPersistedSession decode failed: \(error)")
            #endif
            defaults.removeObject(forKey: todayKey)
        }
    }

    /// Borra la sesión del día actual de UserDefaults.
    func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: Self.sessionKey(for: Date.now))
    }

    // MARK: - Voice Input (Whisper)

    /// Inicia grabación de audio. Errores tipados → `errorMessage`.
    func startVoiceInput() async {
        errorMessage = nil
        do {
            try await AudioRecorderService.shared.startRecording()
            isRecording = true
        } catch RecordingError.microphonePermissionDenied,
                RecordingError.microphonePermissionRestricted {
            errorMessage = L10n.Chat.errorMicPermission
        } catch {
            errorMessage = L10n.Chat.errorTranscription
            #if DEBUG
            print("ChatAssistantViewModel: startVoiceInput failed: \(error)")
            #endif
        }
    }

    /// Detiene grabación, transcribe con Whisper, inserta el texto en `inputText` (no envía).
    /// Si ya hay texto tipeado, hace append con espacio (preserva lo escrito por el user).
    func stopVoiceInput() async {
        guard isRecording else { return }
        isRecording = false
        isTranscribing = true
        defer { isTranscribing = false }

        do {
            let audioData = try await AudioRecorderService.shared.stopRecording()
            let result = try await VoiceTranscriptionService.shared.transcribe(
                audioData: audioData,
                language: .system
            )
            let transcribed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

            // Whisper alucina con frases de relleno (créditos de subtítulos, "Thanks for
            // watching", música) cuando el audio está vacío o sólo es silencio. Filtramos.
            guard !transcribed.isEmpty, !Self.isWhisperHallucination(transcribed) else {
                errorMessage = L10n.Chat.noVoiceDetected
                return
            }

            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inputText = transcribed
            } else {
                inputText = inputText + " " + transcribed
            }

            TelemetryService.track(.chatVoiceInputUsed, parameters: [
                "transcribedLength": String(transcribed.count)
            ])
        } catch RecordingError.recordingTooShort {
            errorMessage = L10n.Chat.noVoiceDetected
        } catch {
            errorMessage = L10n.Chat.errorTranscription
            #if DEBUG
            print("ChatAssistantViewModel: stopVoiceInput failed: \(error)")
            #endif
        }
    }

    /// Detecta transcripciones alucinadas comunes de Whisper sobre audio vacío/silencioso.
    /// Lista basada en outputs reportados de whisper-1 en silencio: créditos de subtítulos
    /// (Amara.org, etc.), "Thanks for watching", música.
    private static func isWhisperHallucination(_ text: String) -> Bool {
        let normalized = text.lowercased()
        let patterns = [
            "amara.org",
            "subtítulos realizados por",
            "subtítulos por",
            "subtitles by",
            "subtitulado por",
            "thanks for watching",
            "thank you for watching",
            "gracias por ver",
            "ご視聴ありがとうございました",
            "[música]",
            "[music]",
            "[silence]"
        ]
        return patterns.contains { normalized.contains($0) }
    }

    func cancelVoiceInput() {
        AudioRecorderService.shared.cancelRecording()
        isRecording = false
        isTranscribing = false
    }

    // MARK: - Reset

    func reset() {
        messages = []
        allTurns = []
        errorMessage = nil
        inputText = ""
        isLoading = false
        clearPersistedSession()
        Task { await loadSuggestions() }
    }

    /// Reinicia el contexto de conversación sin afectar el listado de mensajes visible
    /// — útil para "Reiniciar contexto": el user limpia memoria del LLM y empieza fresh
    /// pero conserva la persistencia / sugerencias.
    func resetConversationContext() {
        messages = []
        allTurns = []
        errorMessage = nil
        clearPersistedSession()
    }
}
