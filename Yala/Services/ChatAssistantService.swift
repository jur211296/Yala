//
//  ChatAssistantService.swift
//  Yala
//
//  Pipeline LLM for Yala IA chat assistant — context-rich (Opción B).
//  Single-step: build FullFinancialContext + 1 LLM call. No function calling.
//  El system prompt incluye TODA la data financiera del user en JSON, así que
//  el LLM no necesita clasificar intent ni llamar tools.
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

    // MARK: - Context Builder (caché 60s vive aquí)

    @ObservationIgnored
    private let contextBuilder = FullFinancialContextBuilder()

    // MARK: - Rate Limiting

    @ObservationIgnored
    private var lastCallTime: Date?

    private static let rateLimitInterval: TimeInterval = 5
    static let dailyLimit = 75
    private static let maxQuestionLength = 500
    private static let timeoutSeconds: TimeInterval = 20  // mini con context grande puede tardar más

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

    /// Process a user question through the context-rich pipeline.
    /// `turns` contiene el historial multi-turno del día. Returns (text, toolName)
    /// where toolName is ALWAYS nil (kept in the signature for API compat).
    func processQuestion(
        question: String,
        turns: [QAPair],
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

        // Detect anomaly request → include anomalies in context
        let needsAnomalies = AnomalyKeywords.matches(question)

        // Build full context (caché 60s aplica)
        let locale = Locale.current
        let language = LanguageManager.overrideLanguage ?? locale.language.languageCode?.identifier ?? "es"
        let country = locale.region?.identifier ?? "US"
        let currencyDisplay = CurrencyCode(rawValue: currencyCode)?.symbol ?? currencyCode

        let context = contextBuilder.build(
            modelContext: modelContext,
            currencyCode: currencyCode,
            currencyDisplay: currencyDisplay,
            converter: converter,
            language: language,
            country: country,
            includeAnomalies: needsAnomalies
        )

        let systemPrompt = buildSystemPrompt(
            context: context,
            modelContext: modelContext,
            language: language,
            country: country,
            currencyCode: currencyCode,
            currencyDisplay: currencyDisplay
        )

        let messages = buildMessages(systemPrompt: systemPrompt, turns: turns, currentQuestion: question)

        let query = ChatQuery(
            messages: messages,
            model: .gpt4_1_mini,
            temperature: 0.4,
            stream: false
        )

        let result = try await callWithTimeout(query, client: client)
        guard let content = result.choices.first?.message.content else {
            throw ChatAssistantError.parseFailed
        }

        incrementDailyCounter()
        return (text: content, toolName: nil)
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

    /// Construye los messages para OpenAI: system prompt + todos los turnos del día
    /// (Q+A only) + la pregunta nueva. NO se manda toolResultJSON (siempre nil tras refactor).
    private func buildMessages(
        systemPrompt: String,
        turns: [QAPair],
        currentQuestion: String
    ) -> [ChatQuery.ChatCompletionMessageParam] {
        var messages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: systemPrompt)
        ].compactMap { $0 }

        for turn in turns {
            if let userMsg = ChatQuery.ChatCompletionMessageParam(role: .user, content: turn.question) {
                messages.append(userMsg)
            }
            if let assistantMsg = ChatQuery.ChatCompletionMessageParam(role: .assistant, content: turn.response) {
                messages.append(assistantMsg)
            }
        }
        if let userMsg = ChatQuery.ChatCompletionMessageParam(role: .user, content: currentQuestion) {
            messages.append(userMsg)
        }
        return messages
    }

    // MARK: - System Prompt (split static + dynamic for prompt caching)

    private func buildSystemPrompt(
        context: FullFinancialContext,
        modelContext: ModelContext,
        language: String,
        country: String,
        currencyCode: String,
        currencyDisplay: String
    ) -> String {
        let staticPart = buildSystemPromptStatic(
            language: language,
            country: country,
            currencyCode: currencyCode,
            currencyDisplay: currencyDisplay
        )
        let dynamicPart = buildSystemPromptDynamic(context: context)

        // STATIC primero para que OpenAI cache el prefix estable.
        return staticPart + "\n\n" + dynamicPart
    }

    /// Bloque estable (cacheable): identidad, reglas, tono, focus, few-shot.
    /// Cambia solo cuando el user cambia tono/focus/idioma.
    private func buildSystemPromptStatic(
        language: String,
        country: String,
        currencyCode: String,
        currencyDisplay: String
    ) -> String {
        // Tone (shared with Insights)
        let tone = InsightTone.current
        let toneInstruction: String
        switch tone {
        case .normal: toneInstruction = ""
        case .considerate: toneInstruction = "Sé amable y empático. Suaviza datos negativos con contexto positivo."
        case .sarcastic: toneInstruction = "Sé directo y con humor sutil, como un amigo cercano que tiene confianza."
        }

        let focus = InsightFocus.current
        let focusInstruction: String
        switch focus {
        case .balanced: focusInstruction = ""
        case .saver: focusInstruction = "Enfatiza oportunidades de ahorro y señala gastos potencialmente innecesarios."
        case .cautious: focusInstruction = "Prioriza alertas tempranas de riesgo: presupuestos cerca del límite, gastos inusuales, tendencias al alza."
        }

        let register: String
        switch language {
        case "es": register = "tuteo (tú)"
        case "de": register = "du"
        case "fr": register = "tu"
        case "it": register = "tu"
        case "pt": register = "você"
        default: register = "informal you"
        }

        return """
        Eres el asistente financiero de Yala. Ayudas al usuario a entender sus finanzas respondiendo preguntas sobre gastos, ingresos, presupuestos, cuentas, patrones y proyecciones.

        REGLAS CRÍTICAS:
        1. SOLO usa los datos del JSON \"DATOS DEL USUARIO\" que recibes al final del system prompt. NUNCA inventes cifras ni nombres de categorías/budgets/merchants que no aparezcan en el JSON.
        2. Si la pregunta requiere data que no está en el JSON, dilo honestamente.
        3. Responde en el idioma del usuario: \(language).
        4. Usa el formato de moneda del usuario: \(currencyDisplay) antes del monto.
        5. Negritas para cifras importantes (**\(currencyDisplay)45.50**).
        6. Máximo 3-4 oraciones. Sé conciso pero informativo.
        7. Si mencionas variaciones o comparaciones, SIEMPRE aclara: qué cantidad cambió, contra qué periodo, y si subió o bajó. Ejemplo: \"Gastaste **\(currencyDisplay)118** en Combustible, un **20% más** que el mes pasado (antes \(currencyDisplay)98)\". NUNCA digas solo un porcentaje sin explicar qué significa.
        8. NUNCA des consejos de inversión ni recomendaciones de productos financieros.
        9. Registro: \(register).
        10. Si la pregunta NO es sobre finanzas personales, responde amablemente que solo puedes ayudar con temas financieros.
        11. Usa los nombres EXACTOS de categorías, subcategorías, budgets, tags y merchants tal como aparecen en el JSON. Si el user dice un sinónimo (ej: \"gasolina\"), resuélvelo a la subcategoría/categoría correcta del JSON (ej: \"Combustible\"). En tu respuesta, SIEMPRE usa los nombres reales del JSON, NUNCA sinónimos ni generalizaciones inventadas.
        12. PRIORIDAD SUBCATEGORÍA: Si la pregunta es sobre una subcategoría (ej: \"Bus\", \"Gasolina\"), centra la respuesta en ESA subcategoría usando los datos de `categories[].subcategories[]` del JSON. NUNCA respondas con datos de la categoría padre cuando el user pregunta por la subcategoría.
        13. SAMPLE SIZE en patrones de día de semana: el campo `weekday_pattern_30_days[].sample_size` indica cuántas tx hay en ese weekday durante los 30 días. Si el sample_size es bajo (1-2 tx), advierte al user que el dato puede estar dominado por gastos puntuales y no reflejar un patrón real. NUNCA presentes un weekday total como \"patrón\" si solo se basa en 1-2 tx.
        14. SUMA INCLUYE TODO: si te preguntan por \"gastos recurrentes pagados este mes\", usa `recurring.paid_this_month` (lista con fechas y montos). Para pendientes, usa `recurring.pending_next_30_days`.
        \(toneInstruction.isEmpty ? "" : "15. Tono: \(toneInstruction)")
        \(focusInstruction.isEmpty ? "" : "16. Enfoque: \(focusInstruction)")

        MANEJO DE CONTEXTO MULTI-TURNO:
        - El historial puede tener varios turnos sobre temas distintos. Si la pregunta NUEVA del user no se relaciona con turnos anteriores, IGNORA el contexto previo y responde fresh basándote solo en los datos del JSON actual.
        - Si la pregunta es ambigua (ej: \"¿y eso?\", \"¿cuánto fue?\", \"¿el mayor?\") y hay 3+ temas distintos en los últimos turnos, NO adivines: pide clarificación breve.
        - NUNCA mezcles datos de turnos viejos con la pregunta actual a menos que sea claramente un follow-up.

        EJEMPLOS DE INTERPRETACIÓN (few-shot):

        EJEMPLO 1 — Patrón de día de semana con sample size bajo:
        User: \"¿En qué días gasto más en transporte?\"
        Datos relevantes: weekday_pattern_30_days incluye Sunday con total \(currencyDisplay)3400, sample_size=2, day_occurrences=4.
        Respuesta esperada: \"Los domingos aparece tu mayor total (**\(currencyDisplay)3400**), pero ojo: solo hay 2 tx en domingos del último mes, así que puede estar dominado por un gasto puntual y no reflejar un patrón real.\"

        EJEMPLO 2 — Pregunta sobre subcategoría específica:
        User: \"¿Cómo se comparan mis gastos en bus con meses anteriores?\"
        Datos relevantes: categories incluye \"Transporte\" con subcategories[] que tiene \"Bus\" con total_current_month=120, total_last_month=180, total_two_months_ago=200.
        Respuesta esperada: \"En **Bus** llevas **\(currencyDisplay)120** este mes, **33% menos** que el pasado (**\(currencyDisplay)180**) y bastante por debajo de los **\(currencyDisplay)200** de hace 2 meses.\" — NO mezcles con totales de \"Transporte\".

        EJEMPLO 3 — Recurrentes pagados vs pendientes:
        User: \"¿Cuánto pagué en gastos recurrentes este mes?\"
        Datos relevantes: recurring.paid_this_month incluye 4 entries con amount sumando 280.
        Respuesta esperada: \"Has pagado **\(currencyDisplay)280** en pagos recurrentes este mes, distribuidos en 4 cargos.\" Si pregunta por pendientes, usa pending_next_30_days.

        EJEMPLO 4 — Pregunta no-financiera (redirección):
        User: \"¿Cuál es la capital de Francia?\"
        Respuesta esperada: \"Solo puedo ayudarte con tus finanzas personales — gastos, ingresos, presupuestos, patrones, etc. ¿Algo de eso?\"

        BRAND VOICE:
        - Tutea ("\(register)"). Cercano pero respetuoso.
        - NUNCA regañar, juzgar o culpar al user por gastar.
        - Lidera con el dato, opinión después.
        - Usa "gasto"/"ingreso", NO "transacción" (excepto contexto técnico).
        """
    }

    /// Bloque dinámico: JSON con TODA la data financiera + DateContext.
    /// Cambia cada llamada (o cada 60s con caché del builder).
    private func buildSystemPromptDynamic(context: FullFinancialContext) -> String {
        let dateContext = DateContextProvider.buildDateContext()
        return """
        DATOS DEL USUARIO (JSON):
        \(context.toJSONString())

        CONTEXTO DE FECHA:
        \(dateContext)
        """
    }
}
