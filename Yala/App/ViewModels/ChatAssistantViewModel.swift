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
    /// Inyectable para tests (suite aislada); producción usa `.standard`.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.contextHintDismissed = defaults.bool(forKey: "hasSeenChatContextHint")
    }

    // MARK: - Persistence (day-calendar `chat_session_<YYYY-MM-DD>`)

    private static let sessionKeyPrefix = "chat_session_"

    private static func sessionKey(for date: Date) -> String {
        sessionKeyPrefix + DayKeyFormatter.string(from: date)
    }

    // MARK: - Setup

    func setContext(_ ctx: ModelContext, autoLoadSuggestions: Bool = true) {
        modelContext = ctx
        loadPersistedSession()
        // Restaurar signal persistido si NTV guardó mientras el chat estaba cerrado
        // (o la app fue matada entre NTV-save y reapertura).
        SessionState.shared.restoreChatDraftSavedSignalIfNeeded()
        consumePersistedDraftSavedSignal()
        // Cargamos sugerencias SIEMPRE — el botón [+ Temas] funciona aún con conversación previa.
        // Si están en cache del día, no llama LLM.
        // `autoLoadSuggestions: false` se usa en tests para evitar Tasks en background
        // que sobreviven al test y crashean en cleanup.
        if autoLoadSuggestions {
            Task { await loadSuggestions() }
        }
    }

    /// Lee el signal persistido (si existe), marca el card y limpia.
    /// Defensivo: corre tanto en setContext como vía .onChange en ChatSheetView.
    private func consumePersistedDraftSavedSignal() {
        guard let signal = SessionState.shared.chatDraftSavedSignal else { return }
        markDraftSaved(messageID: signal.messageID, draftID: signal.draftID, transactionID: signal.transactionID)
        SessionState.shared.chatDraftSavedSignal = nil
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

    /// Envía un texto al pipeline. Si `forceIntent` está presente, el classifier se salta
    /// y el service usa directamente ese intent (usado por quick-reply chips de ambiguous
    /// para no reclasificar el mismo texto retórico).
    func sendQuestion(_ text: String, forceIntent: ChatIntent? = nil) async {
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
            let response = try await service.processQuestion(
                question: trimmed,
                turns: allTurns,
                modelContext: context,
                currencyCode: currencyCode,
                converter: CurrencyConverter.shared,
                forceIntent: forceIntent
            )

            let assistantMessage = ChatMessage(
                role: .assistant,
                text: response.text,
                timestamp: Date.now,
                attachments: response.attachments
            )
            messages.append(assistantMessage)

            // Append turn al historial completo del día. Hard trim defensivo a maxTurns.
            // `messageID` permite a replaceDraft localizar el turno sin matchear texto
            // (frágil con multi-tx donde varios turns tienen el mismo response prefix).
            allTurns.append(QAPair(
                question: trimmed,
                response: response.text,
                timestamp: Date.now,
                messageID: assistantMessage.id,
                attachments: response.attachments
            ))
            if allTurns.count > Self.maxTurns {
                allTurns.removeFirst(allTurns.count - Self.maxTurns)
            }

            // Telemetry — intent clasificado + draft proposed + ambiguous repregunta
            TelemetryService.track(.chatIntentClassified, parameters: [
                "intent": response.intent.rawValue,
                "used_force_intent": forceIntent != nil ? "true" : "false",
            ])
            if case .drafts(let drafts) = response.attachments?.first {
                TelemetryService.track(.chatDraftProposed, parameters: [
                    "count": String(drafts.count),
                ])
            }
            if case .ambiguous = response.attachments?.first {
                TelemetryService.track(.chatAmbiguousRepregunta)
            }
            TelemetryService.track(.chatQuestionAsked, parameters: [
                "source": "typed",
                "turn_count": String(allTurns.count),
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

    private func handleError(_ rawError: ChatAssistantError) {
        // Mapea errores de cuota del gateway (429) que llegan envueltos como .networkError
        // al error tipado correcto (límite diario / ráfaga). Aditivo: el resto queda igual.
        let error = ProxyErrorMapper.remap(rawError)
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

    private var contextHintDismissed: Bool

    var showContextHint: Bool {
        !contextHintDismissed && messages.contains(where: { $0.role == .assistant })
    }

    func dismissContextHint() {
        contextHintDismissed = true
        defaults.set(true, forKey: "hasSeenChatContextHint")
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

            // Si el blob legacy guardó messages pero no allTurns, reconstruimos los turnos
            // pareando user→assistant consecutivos. Sin esto, el LLM perdería el contexto
            // y el botón "Reiniciar contexto" no aparecería.
            //
            // Refactor context-rich: strippeamos `toolResultJSON` de los turnos rehidratados.
            // Bajo el nuevo pipeline el LLM no consume tool data inter-turno (cada turno trae
            // contexto fresh). Mantener payloads viejos solo gasta tokens.
            if blob.allTurns.isEmpty && !messages.isEmpty {
                allTurns = Self.reconstructTurns(from: messages)
            } else {
                allTurns = blob.allTurns.map { Self.stripToolPayload($0) }
            }

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

    /// Limpia el `toolResultJSON` de un QAPair rehidratado (siempre nil tras el refactor
    /// context-rich). Conserva todos los demás campos.
    static func stripToolPayload(_ pair: QAPair) -> QAPair {
        QAPair(
            question: pair.question,
            toolName: nil,
            toolResultJSON: nil,
            response: pair.response,
            timestamp: pair.timestamp,
            messageID: pair.messageID,
            attachments: pair.attachments
        )
    }

    /// Reconstruye `[QAPair]` a partir de `messages` pareando user→assistant consecutivos.
    /// Usado para hidratar contexto del LLM desde blobs legacy que solo guardaban `messages`.
    /// Mensajes huérfanos (sin par) se descartan.
    static func reconstructTurns(from messages: [ChatMessage]) -> [QAPair] {
        var turns: [QAPair] = []
        var i = 0
        while i < messages.count - 1 {
            let m1 = messages[i]
            let m2 = messages[i + 1]
            if m1.role == .user && m2.role == .assistant {
                turns.append(QAPair(
                    question: m1.text,
                    toolName: nil,
                    toolResultJSON: nil,
                    response: m2.text,
                    timestamp: m2.timestamp,
                    messageID: m2.id,
                    attachments: m2.attachments
                ))
                i += 2
            } else {
                i += 1
            }
        }
        return turns
    }

    /// Borra la sesión del día actual de UserDefaults.
    func clearPersistedSession() {
        defaults.removeObject(forKey: Self.sessionKey(for: Date.now))
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

    // MARK: - Draft Lifecycle (chat → register)

    /// Save de un draft → crea TransactionItem real, mark `.saved`, persistSession.
    /// Es bloqueante visualmente: durante `.saving` el card debe deshabilitar Save/Edit.
    /// Permite retry desde `.failed` (resetea a `.saving`).
    func saveDraft(messageID: UUID, draftID: UUID) async {
        guard let context = modelContext else { return }
        guard let location = locateDraft(messageID: messageID, draftID: draftID) else { return }
        var draft = location.draft

        guard draft.status == .pending || draft.status == .failed else { return }

        // Validaciones mínimas previas a Save (defensivas — la UI bloquea Save
        // cuando faltan campos, pero paths no-UI podrían intentarlo).
        guard let amount = draft.amount,
              draft.accountID != nil,
              draft.subcategoryID != nil
        else { return }
        let dbl = NSDecimalNumber(decimal: amount).doubleValue
        guard dbl.isFinite, dbl > 0, dbl < 1_000_000 else {
            errorMessage = L10n.Chat.Draft.saveFailedAmount
            draft.status = .failed
            replaceDraft(draft, at: location)
            return
        }

        // Resetea status si venía de .failed para que retry pase la guard.
        draft.status = .saving
        replaceDraft(draft, at: location)

        let accountID = draft.accountID!
        let subcategoryID = draft.subcategoryID!

        guard let account = context.model(for: accountID) as? Account else {
            #if DEBUG
            print("ChatAssistantViewModel.saveDraft: account not found for ID \(accountID)")
            #endif
            errorMessage = L10n.Chat.Draft.saveFailedAccount
            draft.status = .failed
            replaceDraft(draft, at: location)
            return
        }
        guard let subcategory = context.model(for: subcategoryID) as? Subcategory else {
            #if DEBUG
            print("ChatAssistantViewModel.saveDraft: subcategory not found for ID \(subcategoryID)")
            #endif
            errorMessage = L10n.Chat.Draft.saveFailedSubcategory
            draft.status = .failed
            replaceDraft(draft, at: location)
            return
        }

        let tags: [Tag] = draft.tagIDs.compactMap { context.model(for: $0) as? Tag }

        // Convertir Decimal → Double para TransactionItem (el modelo usa Double)
        let amountDouble = NSDecimalNumber(decimal: amount).doubleValue
        let preferredCurrency = CurrencyDefaults.currentPreferred
        let convertedDecimal = CurrencyConverter.shared.convertWithLatestRate(
            amount,
            from: draft.currencyCode,
            to: preferredCurrency,
            context: context
        )
        let amountInPreferred = NSDecimalNumber(decimal: convertedDecimal).doubleValue

        let transaction = TransactionItem(
            date: draft.date,
            amount: amountDouble,
            currencyCode: draft.currencyCode,
            note: draft.note.isEmpty ? nil : draft.note,
            category: subcategory.safeCategory,
            subcategory: subcategory,
            account: account,
            tags: tags,
            exchangeRate: 1.0,
            amountInPreferredCurrency: amountInPreferred,
            preferredCurrencyCode: preferredCurrency
        )

        // Inyectar context defensivamente — TransactionService es singleton y otras
        // vistas (NTV) usan `context.insert` directo, así que no podemos asumir que
        // setContext fue llamado. Sin esto: throws `noContext` ("No ModelContext available").
        TransactionService.shared.setContext(context)

        do {
            try TransactionService.shared.create(transaction)
            draft.status = .saved
            draft.savedTransactionID = transaction.persistentModelID
            replaceDraft(draft, at: location)
            TelemetryService.track(.chatDraftSaved)
            persistSession()
        } catch {
            #if DEBUG
            print("ChatAssistantViewModel.saveDraft: TransactionService.create failed: \(error)")
            #endif
            // Mensaje genérico al user — no exponer detalles técnicos del error.
            errorMessage = L10n.Chat.Draft.saveFailedGeneric
            draft.status = .failed
            replaceDraft(draft, at: location)
        }
    }

    /// Edit de un draft → enqueue intent para abrir NewTransactionView prefilled
    /// y dismiss del ChatSheet (lo hace la View con `@Environment(\.dismiss)`).
    /// Trackea draft+message en `pendingChatDraftEditOrigin` para que cuando NTV
    /// persista la transacción, el VM pueda marcar el card como `.saved` con el ID.
    /// Si el user CANCELA NTV, no se marca: card queda en `.pending`.
    func editDraft(messageID: UUID, draftID: UUID) {
        guard let location = locateDraft(messageID: messageID, draftID: draftID) else { return }
        let draft = location.draft

        let prefill = ChatDraftPrefill(
            originMessageID: messageID,
            originDraftID: draftID,
            accountID: draft.accountID,
            subcategoryID: draft.subcategoryID,
            amount: draft.amount,
            currencyCode: draft.currencyCode,
            note: draft.note,
            date: draft.date,
            isExpense: draft.isExpense,
            tagIDs: draft.tagIDs
        )
        RouterEntryGate.shared.submit(.presentNewTransactionFromChatDraft(prefill))

        TelemetryService.track(.chatDraftEditedExternally)
    }

    /// Update inline de un campo del draft (ej. user cambia monto en TextField, o
    /// elige otra cuenta en el menu picker). Recalcula `needsUserInput`.
    /// Permite update también desde `.failed` (el user puede ajustar antes de retry).
    func updateDraft(
        messageID: UUID,
        draftID: UUID,
        amount: Decimal? = nil,
        accountID: PersistentIdentifier?? = nil,
        subcategoryID: PersistentIdentifier?? = nil,
        note: String? = nil,
        date: Date? = nil,
        tagIDs: [PersistentIdentifier]? = nil
    ) {
        guard let location = locateDraft(messageID: messageID, draftID: draftID) else { return }
        var draft = location.draft
        guard draft.status == .pending || draft.status == .failed else { return }

        // Si user edita después de un fallo, resetear a pending para permitir retry.
        if draft.status == .failed { draft.status = .pending }

        if let amount {
            // Validación: monto debe ser finito y > 0 (TransactionService.create no lo
            // valida y crearía una transacción negativa). Si no cumple, se ignora.
            let dbl = NSDecimalNumber(decimal: amount).doubleValue
            if dbl.isFinite && dbl > 0 && dbl < 1_000_000 {
                draft.amount = amount
            } else {
                draft.amount = nil
            }
        }
        // Double-optional permite distinguir "no cambies" (nil-outer) de "set a nil" (.some(nil)).
        if case .some(let value) = accountID { draft.accountID = value }
        if case .some(let value) = subcategoryID {
            // Validación: si la subcategoría no es nil, debe matchear el tipo del draft
            // (income subcat para ingreso, expense subcat para gasto). La UI ya lo filtra,
            // pero defensivo contra paths no-UI.
            var typeMatches = true
            if let id = value, let context = modelContext {
                do {
                    let allSubs = try context.fetch(FetchDescriptor<Subcategory>())
                    if let sub = allSubs.first(where: { $0.persistentModelID == id }) {
                        typeMatches = sub.safeCategory.isIncome == !draft.isExpense
                    }
                } catch {
                    #if DEBUG
                    print("ChatAssistantViewModel: fetch de subcategorías falló: \(error)")
                    #endif
                }
            }
            if typeMatches { draft.subcategoryID = value }
        }
        if let note { draft.note = note }
        if let date { draft.date = date }
        if let tagIDs { draft.tagIDs = tagIDs }

        draft.needsUserInput = DraftBuilder.computeNeedsUserInput(
            hasAmount: draft.amount != nil,
            hasAccount: draft.accountID != nil,
            hasSubcategory: draft.subcategoryID != nil
        )
        replaceDraft(draft, at: location)
        persistSession()
    }

    /// Marca un draft como `.saved` con el ID de la transacción real. Lo usa
    /// el flujo Edit → NewTransactionView cuando NTV crea la transacción —
    /// el card del chat refleja el resultado en lugar de quedarse en `.pending`.
    /// Si el user CANCELA NTV, este método no se llama y el card sigue en `.pending`.
    func markDraftSaved(messageID: UUID, draftID: UUID, transactionID: PersistentIdentifier) {
        guard let location = locateDraft(messageID: messageID, draftID: draftID) else { return }
        var draft = location.draft
        guard draft.status != .saved else { return }
        draft.status = .saved
        draft.savedTransactionID = transactionID
        replaceDraft(draft, at: location)
        persistSession()
    }

    /// Descarta un draft `.pending` o `.failed`. Marca status `.discarded` (NO
    /// remueve — el card persiste como historial visual, dimmed y no clickeable).
    /// Si el draft ya está `.saved`, no hace nada (no se puede descartar lo
    /// persistido — usar Records para eliminar).
    func discardDraft(messageID: UUID, draftID: UUID) {
        guard let location = locateDraft(messageID: messageID, draftID: draftID) else { return }
        var draft = location.draft
        guard draft.status != .saved && draft.status != .discarded else { return }
        draft.status = .discarded
        replaceDraft(draft, at: location)
        TelemetryService.track(.chatDraftDismissed)
        persistSession()
    }

    /// Tap en quick-reply chip de ambiguous → reenvía el texto con `forceIntent`
    /// bypassando el classifier. NO añade un nuevo user message a la transcripción
    /// (ya existe el original), y reemplaza el bubble ambiguous por el resultado
    /// real (drafts o respuesta ask).
    func dismissAmbiguous(triggerText: String, forceIntent: ChatIntent) async {
        guard let context = modelContext, !isLoading else { return }

        // Encontrar y remover el bubble ambiguous (assistant) más reciente para
        // que no quede colgando junto al bubble de respuesta real.
        if let lastAmbiguousIdx = messages.lastIndex(where: { msg in
            guard msg.role == .assistant, let attachments = msg.attachments else { return false }
            return attachments.contains { if case .ambiguous = $0 { return true } else { return false } }
        }) {
            let removedID = messages[lastAmbiguousIdx].id
            messages.remove(at: lastAmbiguousIdx)
            allTurns.removeAll { $0.messageID == removedID }
        }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let currencyCode = CurrencyDefaults.currentPreferred
            let response = try await service.processQuestion(
                question: triggerText,
                turns: allTurns,
                modelContext: context,
                currencyCode: currencyCode,
                converter: CurrencyConverter.shared,
                forceIntent: forceIntent
            )

            let assistantMessage = ChatMessage(
                role: .assistant,
                text: response.text,
                timestamp: Date.now,
                attachments: response.attachments
            )
            messages.append(assistantMessage)
            allTurns.append(QAPair(
                question: triggerText,
                response: response.text,
                timestamp: Date.now,
                messageID: assistantMessage.id,
                attachments: response.attachments
            ))
            if allTurns.count > Self.maxTurns {
                allTurns.removeFirst(allTurns.count - Self.maxTurns)
            }

            TelemetryService.track(.chatIntentClassified, parameters: [
                "intent": response.intent.rawValue,
                "used_force_intent": "true",
            ])
            if case .drafts(let drafts) = response.attachments?.first {
                TelemetryService.track(.chatDraftProposed, parameters: ["count": String(drafts.count)])
            }

            persistSession()
        } catch let error as ChatAssistantError {
            handleError(error)
        } catch {
            handleError(.networkError(error))
        }
    }

    // MARK: - Draft locator helpers

    private struct DraftLocation {
        let messageIndex: Int
        let attachmentIndex: Int
        let draftIndex: Int
        let draft: ChatTransactionDraft
    }

    private func locateDraft(messageID: UUID, draftID: UUID) -> DraftLocation? {
        guard let mIdx = messages.firstIndex(where: { $0.id == messageID }),
              let attachments = messages[mIdx].attachments
        else { return nil }

        for (aIdx, attachment) in attachments.enumerated() {
            if case .drafts(let drafts) = attachment,
               let dIdx = drafts.firstIndex(where: { $0.id == draftID }) {
                return DraftLocation(
                    messageIndex: mIdx,
                    attachmentIndex: aIdx,
                    draftIndex: dIdx,
                    draft: drafts[dIdx]
                )
            }
        }
        return nil
    }

    private func replaceDraft(_ updated: ChatTransactionDraft, at location: DraftLocation) {
        let messageID = messages[location.messageIndex].id
        var msg = messages[location.messageIndex]
        guard var attachments = msg.attachments else { return }
        if case .drafts(var drafts) = attachments[location.attachmentIndex] {
            drafts[location.draftIndex] = updated
            attachments[location.attachmentIndex] = .drafts(drafts)
            msg.attachments = attachments
            messages[location.messageIndex] = msg
        }

        // Update allTurns localizando por messageID (estable, no colisiona en multi-tx).
        // Fallback a matching por response text para QAPairs legacy sin messageID.
        let turnIdx = allTurns.firstIndex(where: { $0.messageID == messageID })
            ?? allTurns.lastIndex(where: { $0.messageID == nil && $0.response == messages[location.messageIndex].text })
        if let turnIdx {
            var turn = allTurns[turnIdx]
            if var turnAttachments = turn.attachments,
               case .drafts(var drafts) = turnAttachments[location.attachmentIndex] {
                drafts[location.draftIndex] = updated
                turnAttachments[location.attachmentIndex] = .drafts(drafts)
                turn.attachments = turnAttachments
                allTurns[turnIdx] = turn
            }
        }
    }

}
