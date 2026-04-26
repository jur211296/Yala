//
//  ChatAssistantService.swift
//  Yala
//
//  Pipeline LLM for Ask Yala chat assistant.
//  Step 1: Classify intent via function calling (GPT-4.1-nano)
//  Step 2: Execute tool locally (ChatToolExecutor)
//  Step 3: Format response via LLM (GPT-4.1-nano)
//

import Foundation
import OpenAI
import SwiftData

@MainActor
@Observable
final class ChatAssistantService {

    // MARK: - Singleton

    static let shared = ChatAssistantService()
    private init() {}

    // MARK: - OpenAI Client

    @ObservationIgnored
    private var _openAI: OpenAI?
    @ObservationIgnored
    private var _openAIInitialized = false

    private var openAI: OpenAI? {
        if !_openAIInitialized {
            _openAIInitialized = true
            if let apiKey = APIKeyService.openAIAPIKey {
                _openAI = OpenAI(apiToken: apiKey)
            }
        }
        return _openAI
    }

    // MARK: - Rate Limiting

    @ObservationIgnored
    private var lastCallTime: Date?

    private static let rateLimitInterval: TimeInterval = 5
    static let dailyLimit = 30
    private static let maxQuestionLength = 500
    private static let timeoutSeconds: TimeInterval = 15

    // MARK: - Daily Counter

    var questionsToday: Int {
        let lastDate = UserDefaults.standard.string(forKey: "chatLastQuestionDate") ?? ""
        let todayStr = Self.todayString()
        if lastDate != todayStr { return 0 }
        return UserDefaults.standard.integer(forKey: "chatQuestionsToday")
    }

    private func incrementDailyCounter() {
        let todayStr = Self.todayString()
        let lastDate = UserDefaults.standard.string(forKey: "chatLastQuestionDate") ?? ""
        if lastDate != todayStr {
            UserDefaults.standard.set(todayStr, forKey: "chatLastQuestionDate")
            UserDefaults.standard.set(1, forKey: "chatQuestionsToday")
        } else {
            let current = UserDefaults.standard.integer(forKey: "chatQuestionsToday")
            UserDefaults.standard.set(current + 1, forKey: "chatQuestionsToday")
        }
    }

    private static func todayString() -> String {
        DayKeyFormatter.string(from: Date.now)
    }

    // MARK: - Main Entry Point

    /// Process a user question through the 2-step LLM pipeline.
    /// Returns (responseText, toolName) where toolName is nil if the LLM responded directly.
    func processQuestion(
        question: String,
        previousQA: QAPair?,
        modelContext: ModelContext,
        currencyCode: String,
        converter: CurrencyConverting
    ) async throws -> (text: String, toolName: String?) {
        // Validations
        guard let client = openAI else { throw ChatAssistantError.noAPIKey }
        guard NetworkMonitor.shared.isConnected else { throw ChatAssistantError.offline }
        guard questionsToday < Self.dailyLimit else { throw ChatAssistantError.dailyLimitReached }
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ChatAssistantError.emptyQuestion }
        guard question.count <= Self.maxQuestionLength else { throw ChatAssistantError.questionTooLong }

        // Rate limiting
        if let last = lastCallTime, Date.now.timeIntervalSince(last) < Self.rateLimitInterval {
            throw ChatAssistantError.rateLimited
        }
        lastCallTime = Date.now

        let systemPrompt = buildSystemPrompt(modelContext: modelContext)

        // Step 1: Classify intent
        let (toolCall, directResponse) = try await classifyIntent(
            client: client, question: question, previousQA: previousQA, systemPrompt: systemPrompt
        )

        // If LLM responded directly (no tool call — e.g., non-financial question, greeting)
        if let direct = directResponse {
            incrementDailyCounter()
            return (text: direct, toolName: nil)
        }

        // Step 2: Execute tool locally
        guard let call = toolCall else {
            throw ChatAssistantError.parseFailed
        }

        let executor = ChatToolExecutor(
            modelContext: modelContext,
            currencyCode: currencyCode,
            converter: converter
        )
        let toolResult = try executor.execute(toolName: call.name, arguments: call.arguments)

        // Serialize tool result to JSON
        let toolResultJSON: String
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: toolResult, options: [.sortedKeys])
            toolResultJSON = String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            throw ChatAssistantError.toolExecutionFailed("JSON serialization failed")
        }

        // Step 3: Format response
        let responseText = try await formatResponse(
            client: client, question: question, toolName: call.name,
            toolResultJSON: toolResultJSON, previousQA: previousQA, systemPrompt: systemPrompt
        )

        incrementDailyCounter()
        return (text: responseText, toolName: call.name)
    }

    // MARK: - Step 1: Classify Intent

    private struct ToolCallInfo {
        let name: String
        let arguments: String
    }

    private func classifyIntent(
        client: OpenAI,
        question: String,
        previousQA: QAPair?,
        systemPrompt: String
    ) async throws -> (toolCall: ToolCallInfo?, directResponse: String?) {
        var messages = buildMessages(systemPrompt: systemPrompt, previousQA: previousQA)

        if let userMsg = ChatQuery.ChatCompletionMessageParam(role: .user, content: question) {
            messages.append(userMsg)
        }

        let query = ChatQuery(
            messages: messages,
            model: .gpt4_1_nano,
            tools: ChatToolDefinitions.allTools,
            stream: false
        )

        let result = try await callWithTimeout(query, client: client)

        guard let choice = result.choices.first else {
            throw ChatAssistantError.parseFailed
        }

        // Check for tool calls
        if let toolCalls = choice.message.toolCalls, let firstCall = toolCalls.first {
            return (
                toolCall: ToolCallInfo(name: firstCall.function.name, arguments: firstCall.function.arguments),
                directResponse: nil
            )
        }

        // Direct text response (no tool call)
        if let content = choice.message.content {
            return (toolCall: nil, directResponse: content)
        }

        throw ChatAssistantError.parseFailed
    }

    // MARK: - Step 3: Format Response

    private func formatResponse(
        client: OpenAI,
        question: String,
        toolName: String,
        toolResultJSON: String,
        previousQA: QAPair?,
        systemPrompt: String
    ) async throws -> String {
        var messages = buildMessages(systemPrompt: systemPrompt, previousQA: previousQA)

        let userContent = """
        Pregunta del usuario: \(question)

        Resultado de \(toolName):
        \(toolResultJSON)
        """
        if let userMsg = ChatQuery.ChatCompletionMessageParam(role: .user, content: userContent) {
            messages.append(userMsg)
        }

        let query = ChatQuery(
            messages: messages,
            model: .gpt4_1_nano,
            temperature: 0.4,
            stream: false
        )

        let result = try await callWithTimeout(query, client: client)

        guard let content = result.choices.first?.message.content else {
            throw ChatAssistantError.parseFailed
        }
        return content
    }

    // MARK: - Helpers

    private func callWithTimeout(_ query: ChatQuery, client: OpenAI) async throws -> ChatResult {
        try await withThrowingTaskGroup(of: ChatResult.self) { group in
            group.addTask { try await client.chats(query: query) }
            group.addTask {
                try await Task.sleep(for: .seconds(Self.timeoutSeconds))
                throw ChatAssistantError.timeout
            }
            guard let first = try await group.next() else {
                throw ChatAssistantError.timeout
            }
            group.cancelAll()
            return first
        }
    }

    private func buildMessages(
        systemPrompt: String,
        previousQA: QAPair?
    ) -> [ChatQuery.ChatCompletionMessageParam] {
        var messages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: systemPrompt)
        ].compactMap { $0 }

        if let prev = previousQA, !prev.isExpired {
            if let userMsg = ChatQuery.ChatCompletionMessageParam(role: .user, content: prev.question) {
                messages.append(userMsg)
            }
            if let assistantMsg = ChatQuery.ChatCompletionMessageParam(role: .assistant, content: prev.response) {
                messages.append(assistantMsg)
            }
        }
        return messages
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(modelContext: ModelContext) -> String {
        let locale = Locale.current
        let language = LanguageManager.overrideLanguage ?? locale.language.languageCode?.identifier ?? "es"
        let currencyCode = CurrencyDefaults.currentPreferred
        let currencySymbol = CurrencyCode(rawValue: currencyCode)?.symbol ?? "$"
        let country = locale.region?.identifier ?? "US"
        let dateContext = DateContextProvider.buildDateContext()

        // Tone (shared with Insights)
        let tone = InsightTone.current
        let toneInstruction: String
        switch tone {
        case .normal: toneInstruction = ""
        case .considerate: toneInstruction = "Sé amable y empático. Suaviza datos negativos con contexto positivo."
        case .sarcastic: toneInstruction = "Sé directo y con humor sutil, como un amigo cercano que tiene confianza."
        }

        // Focus (shared with Insights)
        let focus = InsightFocus.current
        let focusInstruction: String
        switch focus {
        case .balanced: focusInstruction = ""
        case .saver: focusInstruction = "Enfatiza oportunidades de ahorro y señala gastos potencialmente innecesarios."
        case .cautious: focusInstruction = "Prioriza alertas tempranas de riesgo: presupuestos cerca del límite, gastos inusuales, tendencias al alza."
        }

        // Register (formality based on language)
        let register: String
        switch language {
        case "es": register = "tuteo (tú)"
        case "de": register = "du"
        case "fr": register = "tu"
        case "it": register = "tu"
        case "pt": register = "você"
        default: register = "informal you"
        }

        // Category → Subcategory tree for resolution
        let categories: [Category]
        do {
            categories = try modelContext.fetch(FetchDescriptor<Category>())
        } catch {
            categories = []
        }
        let categoryTree = categories.visibleCategoryTreeLabels().joined(separator: "; ")

        // Account names for context
        let accountNames: String
        do {
            let accounts = try modelContext.fetch(FetchDescriptor<Account>())
            accountNames = accounts.map(\.name).joined(separator: ", ")
        } catch {
            accountNames = ""
        }

        return """
        Eres el asistente financiero de Yala. Ayudas al usuario a entender sus finanzas respondiendo preguntas sobre gastos, ingresos, presupuestos, cuentas, patrones y proyecciones.

        REGLAS CRÍTICAS:
        1. SOLO usa datos que las tools te devuelvan. NUNCA inventes cifras.
        2. Si una tool no retorna datos suficientes, dilo honestamente.
        3. Responde en el idioma del usuario: \(language).
        4. Usa el formato de moneda del usuario: \(currencySymbol) antes del monto.
        5. Negritas para cifras importantes (**\(currencySymbol)45.50**).
        6. Máximo 3-4 oraciones. Sé conciso pero informativo.
        7. Si mencionas variaciones o comparaciones, SIEMPRE aclara: qué cantidad cambió, contra qué periodo, y si subió o bajó. Ejemplo: "Gastaste **\(currencySymbol)118** en Combustible, un **20% más** que el mes pasado (antes \(currencySymbol)98)". NUNCA digas solo un porcentaje sin explicar qué significa.
        8. NUNCA des consejos de inversión ni recomendaciones de productos financieros.
        9. Registro: \(register)
        10. Si la pregunta NO es sobre finanzas personales, responde amablemente que solo puedes ayudar con temas financieros. NO llames ninguna tool.
        11. Usa los nombres exactos de categorías y subcategorías del usuario para buscar. Si el usuario dice un sinónimo (ej: "gasolina"), resuélvelo a la subcategoría correcta (ej: "Combustible" dentro de "Vehículo"). En tu respuesta, SIEMPRE usa los nombres reales de categorías/subcategorías, NUNCA sinónimos ni generalizaciones.
        12. PRIORIDAD SUBCATEGORÍA: Si la pregunta es sobre una subcategoría (ej: "Bus", "Gasolina"), centra la respuesta en ESA subcategoría. Si los datos incluyen "matched_level": "subcategory", el foco DEBE ser la subcategoría.
        \(toneInstruction.isEmpty ? "" : "13. Tono: \(toneInstruction)")
        \(focusInstruction.isEmpty ? "" : "14. Enfoque: \(focusInstruction)")

        VOCABULARIO NATURAL → TOOL:
        - "gastos hormiga/chiquitos/gastitos/latte factor" → analyze_patterns(small_recurring)
        - "me excedí/me pasé/reventé presupuesto" → budget_status(date_range=last_month)
        - "gastos fijos/suscripciones/pagos que se vienen" → upcoming_payments
        - "cuánto tengo/mi plata/mi balance/mis cuentas" → account_balances
        - "a este ritmo/me alcanza/cuánto puedo gastar por día" → spending_projection
        - "algo raro/inusual/sospechoso en mis gastos" → analyze_patterns(unusual_spending)
        - "qué día gasto más/fines de semana" → analyze_patterns(weekday_pattern)
        - "gastos innecesarios/podría recortar/esenciales" → analyze_patterns(needs_breakdown)
        - "mi gasto más grande/caro/top gastos" → search_transactions(sort_by=amount_desc, limit=N)
        - "más repetido/frecuente/cuántas veces" → analyze_patterns(frequency_ranking)
        - "estoy ahorrando/gasto más de lo que gano" → financial_overview (tiene savings_rate)
        - "menores a X/mayores a X/entre X e Y" → search_transactions o spending_summary con amount_min/amount_max

        GUÍA DE SELECCIÓN:
        - BALANCE/CUENTAS ("cuánto tengo") → account_balances
        - PRESUPUESTO ("me excedí", "presupuesto de X") → budget_status
        - PAGOS FUTUROS ("qué se viene", "suscripciones") → upcoming_payments
        - PROYECCIÓN ("a este ritmo", "me alcanza") → spending_projection
        - PATRONES ("gastos hormiga", "qué día", "algo raro", "innecesarios") → analyze_patterns
        - MERCHANT/CATEGORÍA específica ("cuánto en Starbucks") → search_transactions
        - RANKING de categorías/merchants ("en qué más gasté") → spending_summary
        - COMPARACIÓN entre periodos ("marzo vs febrero") → compare_periods
        - RESUMEN general ("cómo me fue", "resumen del mes") → financial_overview
        Si la pregunta combina temas, usa la tool más específica al tema principal.

        CONTEXTO:
        - Moneda principal: \(currencyCode)
        - Idioma: \(language)
        - País: \(country)
        - Categorías y subcategorías: \(categoryTree)
        - Cuentas: \(accountNames)

        \(dateContext)
        """
    }
}
