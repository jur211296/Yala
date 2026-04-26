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
    private(set) var isRecording = false
    private(set) var isTranscribing = false
    private(set) var errorMessage: String?
    var inputText: String = ""

    // MARK: - 1-Turn Memory

    private var previousQA: QAPair?

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private let service = ChatAssistantService.shared

    // MARK: - Persistence (day-calendar `chat_session_<YYYY-MM-DD>`)

    private static let sessionKeyPrefix = "chat_session_"

    private static let sessionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func sessionKey(for date: Date) -> String {
        sessionKeyPrefix + sessionDateFormatter.string(from: date)
    }

    // MARK: - Setup

    func setContext(_ ctx: ModelContext) {
        modelContext = ctx
        loadPersistedSession()
        if messages.isEmpty {
            Task { await loadSuggestions() }
        }
    }

    // MARK: - Suggestions (LLM-first con fallback rule-based)

    /// Carga sugerencias para el empty state. Intenta LLM (cache diario), cae a rule-based si falla.
    /// `suggestions` puede tener hasta 10 items; la View limita a 3 chips visibles.
    func loadSuggestions() async {
        guard let context = modelContext else { return }

        suggestionsLoading = true
        defer { suggestionsLoading = false }

        // Intento 1: LLM (cache diario o generación)
        let llmResults = await ChatSuggestionsLLMService.shared.fetchOrGenerate(modelContext: context)
        if !llmResults.isEmpty {
            suggestions = llmResults
            return
        }

        // Fallback: rule-based local
        suggestions = buildRuleBasedSuggestions(modelContext: context)
    }

    private func buildRuleBasedSuggestions(modelContext context: ModelContext) -> [ChatSuggestion] {
        var result: [ChatSuggestion] = []

        // Top merchant this month
        do {
            let monthStart = Calendar.current.dateInterval(of: .month, for: Date.now)?.start ?? Date.now
            let descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { $0.date >= monthStart },
                sortBy: [SortDescriptor(\TransactionItem.date, order: .reverse)]
            )
            let txns = try context.fetch(descriptor)
            let monthTxns = txns.filter {
                $0.balanceAdjustmentType == nil &&
                $0.category?.isIncome == false && $0.account?.excludeFromStatistics != true
            }

            // Find top merchant
            var merchantCounts: [String: Int] = [:]
            for tx in monthTxns {
                if let note = tx.note, !note.isEmpty {
                    let canonical = MerchantCanonicalizer.canonicalize(note)
                    if !canonical.isEmpty { merchantCounts[canonical, default: 0] += 1 }
                }
            }
            if let topMerchant = merchantCounts.max(by: { $0.value < $1.value })?.key {
                result.append(ChatSuggestion(
                    text: L10n.Chat.Suggestion.topMerchantWith(topMerchant.capitalized),
                    icon: "storefront", type: .topMerchant
                ))
            }

            // Biggest category
            result.append(ChatSuggestion(
                text: L10n.Chat.Suggestion.biggestCategory,
                icon: "chart.pie", type: .biggestCategory
            ))

            // Active budget at risk
            let budgets = try context.fetch(FetchDescriptor<Budget>())
            if let budget = budgets.first(where: { $0.isActive && $0.limitAmount > 0 }),
               let catName = budget.category?.name {
                result.append(ChatSuggestion(
                    text: L10n.Chat.Suggestion.activeBudget(catName),
                    icon: "chart.bar", type: .activeBudget
                ))
            } else {
                result.append(ChatSuggestion(
                    text: L10n.Chat.Suggestion.general,
                    icon: "chart.bar", type: .general
                ))
            }

        } catch {
            #if DEBUG
            print("ChatAssistantViewModel: Error loading suggestions: \(error)")
            #endif
            // Fallback hard-coded
            result = [
                ChatSuggestion(text: L10n.Chat.Suggestion.biggestCategory, icon: "chart.pie", type: .biggestCategory),
                ChatSuggestion(text: L10n.Chat.Suggestion.general, icon: "chart.bar", type: .general),
                ChatSuggestion(text: L10n.Chat.Suggestion.topMerchant, icon: "storefront", type: .topMerchant)
            ]
        }

        return result
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
                previousQA: previousQA,
                modelContext: context,
                currencyCode: currencyCode,
                converter: CurrencyConverter.shared
            )

            let assistantMessage = ChatMessage(role: .assistant, text: responseText, timestamp: Date.now)
            messages.append(assistantMessage)

            // Save for 1-turn memory
            previousQA = QAPair(
                question: trimmed,
                toolName: toolName,
                toolResultJSON: nil,
                response: responseText,
                timestamp: Date.now
            )

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
        service.questionsToday >= ChatAssistantService.dailyLimit - 5
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

        let blob = ChatPersistedSession(messages: messages, previousQA: previousQA)
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
            if let qa = blob.previousQA, !qa.isExpired {
                previousQA = qa
            }
            if !messages.isEmpty {
                TelemetryService.track(.chatPersistedSessionRehydrated, parameters: [
                    "messageCount": String(messages.count)
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
            guard !transcribed.isEmpty else { return }

            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inputText = transcribed
            } else {
                inputText = inputText + " " + transcribed
            }

            TelemetryService.track(.chatVoiceInputUsed, parameters: [
                "transcribedLength": String(transcribed.count)
            ])
        } catch {
            errorMessage = L10n.Chat.errorTranscription
            #if DEBUG
            print("ChatAssistantViewModel: stopVoiceInput failed: \(error)")
            #endif
        }
    }

    func cancelVoiceInput() {
        AudioRecorderService.shared.cancelRecording()
        isRecording = false
        isTranscribing = false
    }

    // MARK: - Reset

    func reset() {
        messages = []
        previousQA = nil
        errorMessage = nil
        inputText = ""
        isLoading = false
        clearPersistedSession()
        Task { await loadSuggestions() }
    }
}
