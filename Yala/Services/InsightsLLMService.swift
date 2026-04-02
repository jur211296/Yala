//
//  InsightsLLMService.swift
//  Yala
//
//  Service for generating AI-powered insights via OpenAI GPT-4.1 Mini.
//  Follows VoiceTranscriptionService pattern: singleton, lazy OpenAI init, async/throws.
//

import Foundation
import OpenAI

// MARK: - LLM Insight Result

struct LLMInsightResponse {
    let heroText: String
    let cards: [LLMInsightCard]
    let funFact: String?
}

struct LLMInsightCard {
    let icon: String
    let text: String
    let sentiment: String  // "positive", "neutral", "attention"
    let tip: String?
}

// MARK: - LLM Error

enum InsightsLLMError: Error, LocalizedError {
    case noAPIKey
    case notProUser
    case noAIConsent
    case offline
    case rateLimited
    case parseFailed
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "OpenAI API key not configured"
        case .notProUser: return "Pro subscription required"
        case .noAIConsent: return "AI data consent not given"
        case .offline: return "No internet connection"
        case .rateLimited: return "Rate limited — try again shortly"
        case .parseFailed: return "Failed to parse AI response"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Cache Entry

private struct CacheEntry {
    let response: LLMInsightResponse
    let timestamp: Date
}

// MARK: - Service

@MainActor @Observable
final class InsightsLLMService {

    // MARK: - Singleton

    static let shared = InsightsLLMService()

    init() {}

    // MARK: - Properties

    @ObservationIgnored
    private var _openAI: OpenAI?
    @ObservationIgnored
    private var _openAIInitialized = false

    @ObservationIgnored
    private var cache: [String: CacheEntry] = [:]

    @ObservationIgnored
    private var lastCallTime: Date?

    private var openAI: OpenAI? {
        if !_openAIInitialized {
            _openAIInitialized = true
            if let apiKey = APIKeyService.openAIAPIKey {
                _openAI = OpenAI(apiToken: apiKey)
            }
        }
        return _openAI
    }

    // MARK: - Cache

    /// Build a cache key from period + filter hash + transaction count + comparison mode + locale context
    func cacheKey(period: String, filterHash: Int, txnCount: Int, comparisonMode: String = "month", tone: InsightTone = .normal, focus: InsightFocus = .balanced) -> String {
        let country = Locale.current.region?.identifier ?? ""
        let currencyFormat = UserDefaults.standard.string(forKey: "currencyDisplayFormat") ?? "code"
        return "\(period)_\(filterHash)_\(txnCount)_\(comparisonMode)_\(tone.rawValue)_\(focus.rawValue)_\(country)_\(currencyFormat)"
    }

    /// Get cached response if valid (< 5 minutes old)
    func getCached(key: String) -> LLMInsightResponse? {
        guard let entry = cache[key],
              Date.now.timeIntervalSince(entry.timestamp) < 300 else {
            return nil
        }
        return entry.response
    }

    // MARK: - Generate

    /// Generate AI insights from aggregated financial data.
    /// - Parameters:
    ///   - aggregatedData: JSON-serializable dictionary of aggregated stats (never individual transactions)
    ///   - cacheKey: Key for caching the response
    /// - Returns: LLMInsightResponse with hero text, cards, and optional fun fact
    func generateInsights(
        aggregatedData: [String: Any],
        cacheKey key: String,
        tone: InsightTone = .normal,
        focus: InsightFocus = .balanced
    ) async throws -> LLMInsightResponse {
        guard let client = openAI else {
            throw InsightsLLMError.noAPIKey
        }

        // Rate limit: 5s between calls
        if let lastCall = lastCallTime,
           Date.now.timeIntervalSince(lastCall) < 5 {
            throw InsightsLLMError.rateLimited
        }

        // Evict expired entries
        let now = Date.now
        cache = cache.filter { now.timeIntervalSince($0.value.timestamp) < 300 }

        // Check cache
        if let cached = getCached(key: key) {
            return cached
        }

        lastCallTime = Date.now

        // Build JSON payload
        let jsonData = try JSONSerialization.data(withJSONObject: aggregatedData)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        // Extract locale, country and comparison context from aggregated data
        let locale = aggregatedData["locale"] as? String ?? "es"
        let country = aggregatedData["country"] as? String ?? ""
        let comparisonRef = aggregatedData["comparison_ref"] as? String ?? "periodo anterior"
        let comparisonLabel = aggregatedData["comparison_label"] as? String ?? ""

        // Build filter context for prompt if active
        let filterContext: String
        if let filters = aggregatedData["active_filters"] as? [String: Any],
           let summary = filters["summary"] as? String,
           !summary.isEmpty {
            let mode = filters["mode"] as? String ?? "include"
            if mode == "exclude" {
                filterContext = """

                FILTROS ACTIVOS (EXCLUSIÓN): \(summary)
                IMPORTANTE: Los datos que recibes EXCLUYEN los elementos mencionados. Todos los porcentajes, promedios y distribuciones son relativos al subconjunto visible, NO al total general. Por ejemplo, si se excluyen gastos esenciales, un 80% de "opcional" significa 80% dentro de los gastos no-esenciales, no del total. Menciona esta perspectiva filtrada en tus insights cuando sea relevante para evitar confusión.
                """
            } else {
                filterContext = """

                FILTROS ACTIVOS (INCLUSIÓN): \(summary)
                IMPORTANTE: Los datos que recibes solo incluyen los elementos mencionados. Los porcentajes y promedios son relativos a este subconjunto filtrado, no al total de todas las finanzas. Menciona esta perspectiva filtrada en tus insights cuando sea relevante.
                """
            }
        } else {
            filterContext = ""
        }

        let toneInstruction = Self.toneInstruction(for: tone, country: country)
        let focusInstruction = Self.focusInstruction(for: focus)

        let currencyCode = aggregatedData["currency"] as? String ?? "USD"
        let currencyDisplay = aggregatedData["currency_display"] as? String ?? currencyCode

        let systemPrompt = """
        Eres un analista financiero personal. Analizas EXCLUSIVAMENTE los datos agregados proporcionados.

        REGLAS CRÍTICAS:
        1. NUNCA menciones datos, categorías, montos o relaciones que NO estén en el JSON
        2. NUNCA cruces información de campos no relacionados (ej: NO mezcles el nombre de una categoría con un presupuesto de otra categoría)
        3. Cada afirmación DEBE corresponder a un campo específico de los datos
        4. Si un campo dice "N/A" o no existe, NO menciones ese tema
        5. Los montos están en \(currencyCode). SIEMPRE formatea: \(currencyDisplay) NÚMERO (ej: \(currencyDisplay) 4,500). La divisa SIEMPRE va ANTES del número, NUNCA después.

        IDIOMA: Responde SIEMPRE en \(locale). Nunca mezcles idiomas.

        COMPARACIONES: Las variaciones se comparan contra "\(comparisonRef)" (\(comparisonLabel)).
        \(filterContext)
        FRAMEWORK DE ANÁLISIS (sigue este orden de prioridad):
        1. PANORAMA: total_expense, total_income, net_balance y sus variaciones. ¿Mes positivo o negativo? ¿Tendencia?
        2. CONCENTRACIÓN: top_categories — ¿alguna categoría domina excesivamente? ¿Distribución saludable?
        3. COMPROMISOS: budgets_at_risk (compara spent vs limit), subscriptions (suscripciones: Netflix, Spotify, gym), recurring_payments (pagos fijos: renta, servicios, nómina), pending_payments
        4. PATRONES: highest_avg_weekday, daily_avg y su variación, highest_expense (gasto atípico?)
        5. NECESIDADES: distribución essential/priority/optional — ¿equilibrio razonable?

        Genera insights que conecten estos datos de forma lógica. Por ejemplo:
        - Si el gasto subió 20% Y la categoría top creció, esa categoría puede ser la causa
        - Si un presupuesto está al 90% Y quedan días del mes, hay riesgo real
        - Si el opcional supera al esencial, es una señal de alerta

        REGLAS DE VOZ (OBLIGATORIAS — aplican siempre, independiente del tono):
        - Tutea al usuario ("tú"), como un amigo que sabe de finanzas
        - Lidera con el dato, opinión después
        - NUNCA culpar, regañar ni juzgar — siempre constructivo y orientado a solución
        - NUNCA uses: "Debes...", "Tienes que...", "Es fácil", "Obviamente...", "Como ya sabes..."
        - Celebrar logros genuinamente pero con mesura
        - Solo afirmaciones, datos, observaciones y guías. NUNCA preguntas
        - Usa "gasto" o "ingreso", NUNCA "transacción" (excepto contexto técnico)
        - No menciones rachas ni streaks
        - Propón alternativas en vez de señalar problemas — inspira, no asustes
        \(toneInstruction)\(focusInstruction)
        FORMATO:
        - Usa **negritas** para cifras, porcentajes y datos clave

        RESPUESTA (JSON estricto):
        {
          "hero": "Insight más impactante (1-2 oraciones, DEBE citar cifras reales del JSON)",
          "cards": [
            {"icon": "SF Symbol", "text": "Insight anclado en datos", "sentiment": "positive|neutral|attention", "tip": "consejo específico y accionable (opcional)"}
          ],
          "funFact": "Observación curiosa combinando datos de formas inesperadas (opcional)"
        }

        Genera 3-6 cards. El hero DEBE referenciar números específicos de los datos.
        Los tips deben ser específicos y accionables — nunca genéricos como "intenta gastar menos".
        SF Symbols válidos: chart.line.uptrend.xyaxis, arrow.down.right, flame.fill, cart.fill, creditcard, calendar, banknote, etc.
        """

        let userMessage = "Datos financieros del periodo:\n\(jsonString)"

        let query = ChatQuery(
            messages: try buildChatMessages(system: systemPrompt, user: userMessage),
            model: .gpt4_1_mini,
            responseFormat: .jsonObject,
            temperature: 0.4
        )

        do {
            let result = try await client.chats(query: query)

            guard let content = result.choices.first?.message.content else {
                throw InsightsLLMError.parseFailed
            }

            let response = try parseResponse(content)

            // Cache the result
            cache[key] = CacheEntry(response: response, timestamp: Date.now)

            return response
        } catch let error as InsightsLLMError {
            throw error
        } catch {
            throw InsightsLLMError.networkError(error)
        }
    }

    // MARK: - Chat Helpers

    private func buildChatMessages(system: String, user: String) throws -> [ChatQuery.ChatCompletionMessageParam] {
        let messages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: system),
            .init(role: .user, content: user)
        ].compactMap { $0 }
        guard messages.count == 2 else { throw InsightsLLMError.parseFailed }
        return messages
    }

    // MARK: - Parse

    private func parseResponse(_ json: String) throws -> LLMInsightResponse {
        guard let data = json.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hero = dict["hero"] as? String else {
            throw InsightsLLMError.parseFailed
        }

        var cards: [LLMInsightCard] = []
        if let cardsArray = dict["cards"] as? [[String: Any]] {
            for cardDict in cardsArray {
                guard let text = cardDict["text"] as? String else { continue }
                let icon = cardDict["icon"] as? String ?? "sparkles"
                let sentiment = cardDict["sentiment"] as? String ?? "neutral"
                let tip = cardDict["tip"] as? String
                cards.append(LLMInsightCard(icon: icon, text: text, sentiment: sentiment, tip: tip))
            }
        }

        let funFact = dict["funFact"] as? String

        return LLMInsightResponse(heroText: hero, cards: cards, funFact: funFact)
    }

    /// Invalidate all cached responses
    func invalidateCache() {
        cache.removeAll()
        contextualCache.removeAll()
    }

    // MARK: - Tone & Focus Instructions

    private static func toneInstruction(for tone: InsightTone, country: String = "") -> String {
        let regionHint = country.isEmpty ? "no especificado — usa español neutro" : country
        switch tone {
        case .normal:
            return ""
        case .considerate:
            return """

            ESTILO — ANALISTA CUIDADOSO:
            Eres un analista meticuloso que presenta datos con mucho cuidado. Te preocupa ser preciso y no causar alarma innecesaria.

            PERSONALIDAD:
            - Analítico y preciso, siempre contextualizas antes de opinar
            - Usas matices y calificadores: "técnicamente", "en principio", "si consideramos que...", "vale la pena notar que..."
            - Suavizas datos negativos por precisión, no por lástima ("no necesariamente es negativo", "podría tener explicación")
            - Reconoces logros de forma genuina pero algo torpe ("los datos muestran que lo estás haciendo bien")
            - Presentas alternativas antes de conclusiones ("podría ser estacional, o podría indicar un cambio")
            - NO eres condescendiente — eres cauteloso porque respetas los datos
            - REGIONALIZACIÓN: País del usuario: \(regionHint). Adapta modismos y registro al país e idioma del usuario, usando expresiones naturales y suaves de esa región. IMPORTANTE: la adaptación regional nunca debe violar las reglas de voz — nunca regañar, nunca juzgar, siempre constructivo.

            EJEMPLO de cómo suenas:
            - "El gasto total fue **2,400**, técnicamente un **12%** menos que el periodo anterior — un dato positivo"
            - "Comida lleva el **87%** del presupuesto, aunque vale considerar que este mes tuvo más días hábiles"
            - "Delivery subió a **380**, casi el doble. No necesariamente es un problema si fue un mes atípico"

            """
        case .sarcastic:
            return """

            ESTILO — TU AMIGO CERCANO:
            Eres el amigo que entiende de finanzas. Hablas con total confianza, como si estuvieran revisando los números juntos.

            PERSONALIDAD:
            - Directo y sin rodeos, pero siempre desde el cariño
            - Ironía ligera y natural, nunca forzada ni cruel ("delivery subió bastante, revisa qué pasó")
            - Celebras genuinamente los logros ("muy bien, bajaste el gasto 15%")
            - NO fuerzas chistes, metáforas rebuscadas ni juegos de palabras
            - NUNCA regañes ni culpes — eres directo pero siempre constructivo
            - El tono es de confianza, como alguien que te conoce y quiere que te vaya bien
            - REGIONALIZACIÓN: País del usuario: \(regionHint). Adapta modismos y expresiones coloquiales al país e idioma del usuario, usando un registro cercano y natural de esa región. IMPORTANTE: la adaptación regional nunca debe violar las reglas de voz — nunca regañar, nunca juzgar, siempre constructivo.

            EJEMPLO de cómo suenas:
            - "Gastaste **2,400** este mes, tranqui — bajó **12%** vs el anterior"
            - "Ojo que Comida va al **87%** del presupuesto y recién vamos a mitad de mes"
            - "Delivery subió a **380**, casi el doble que el mes pasado. Vale la pena revisarlo"

            """
        }
    }

    private static func focusInstruction(for focus: InsightFocus) -> String {
        switch focus {
        case .balanced:
            return """

            ENFOQUE — EQUILIBRADO:
            Cubre todas las áreas del framework de análisis con peso similar. No priorices ahorro ni riesgo por encima del otro — presenta el panorama completo.
            - Dedica al menos 1 card a panorama general (ingresos vs gastos, tendencia)
            - Dedica al menos 1 card a patrones de gasto (categorías, día de mayor gasto, gasto atípico)
            - Si hay presupuestos en riesgo O oportunidades de ahorro, menciónalos pero sin dramatizar ni celebrar en exceso
            - El hero debe reflejar el dato más relevante del periodo, sea positivo o de atención
            - BRAND VOICE: nunca regañar, siempre constructivo, proponer alternativas. Usa "gasto"/"ingreso", no "transacción".

            """
        case .saver:
            return """

            ENFOQUE — AHORRO:
            Tu lente principal es encontrar dónde el usuario puede optimizar su dinero. Prioriza insights que ayuden a gastar menos o gastar mejor.

            PRIORIDADES DE ANÁLISIS:
            1. Reducciones de gasto vs periodo anterior → celebrar con cifras concretas
            2. Gastos opcionales (need_split.optional) → si son altos, señalar como área de oportunidad
            3. Categorías o subcategorías que crecieron más → oportunidades de ajuste
            4. Suscripciones → ¿el monto mensual es significativo respecto al gasto total?
            5. Promedio diario y su variación → ¿va mejorando o empeorando?

            REGLAS:
            - Celebra SIEMPRE que algo bajó — es lo que el usuario quiere escuchar
            - Los tips deben ser concretos y accionables: "cocinar 2 días más por semana" > "intenta gastar menos en comida"
            - Si el gasto subió, enmarca como oportunidad ("aquí hay margen para ajustar") no como fracaso
            - El hero debe destacar el ahorro logrado o la mayor oportunidad de ahorro
            - BRAND VOICE: nunca regañar ni culpar por gastar. Proponer alternativas, inspirar. Usa "gasto"/"ingreso", no "transacción". NUNCA "Debes...", "Tienes que...".

            """
        case .cautious:
            return """

            ENFOQUE — PRECAVIDO:
            Tu lente principal es anticipar riesgos antes de que se conviertan en problemas. Prioriza señales tempranas y protección financiera.

            PRIORIDADES DE ANÁLISIS:
            1. Presupuestos en riesgo → comparar spent vs limit, proyectar si llegará al límite al ritmo actual
            2. Tendencias al alza → gastos que subieron vs periodo anterior, especialmente si son recurrentes
            3. Pagos pendientes (pending_payments) → monto comprometido que aún no se ha ejecutado
            4. Concentración excesiva → si una categoría domina >50% del gasto, es un riesgo de dependencia
            5. Balance negativo o en deterioro → net_balance y balance_variation como señal de alerta

            REGLAS:
            - Las alertas deben ser tempranas y constructivas, NUNCA alarmistas
            - Enmarca como "vale la pena tenerlo en el radar" no como "estás en peligro"
            - Si un presupuesto va al 80%+, calcula cuánto margen queda en términos concretos
            - Si todo está bien, reconócelo — no inventes riesgos donde no los hay
            - El hero debe destacar la señal más importante que el usuario necesita ver
            - Los tips deben ser preventivos: "si mantienes este ritmo, llegarías al límite el día X" > "cuidado con gastar tanto"
            - BRAND VOICE: alertar sin asustar. NUNCA "estás en peligro", "error grave", "crítico". Proponer alternativas constructivas. Usa "gasto"/"ingreso", no "transacción". NUNCA "Debes...", "Tienes que...".

            """
        }
    }

    // MARK: - Contextual Insight (PanelView)

    private static let contextualFocusAngles = [
        "variación de gasto vs periodo anterior",
        "categoría o subcategoría con mayor cambio",
        "distribución entre esencial/prioritario/opcional",
        "presupuestos en riesgo o bien encaminados",
        "ingreso vs gasto del periodo",
        "promedio diario comparado con lo habitual",
        "dato sorprendente o inusual en los datos"
    ]

    @ObservationIgnored
    private var lastContextualCallTime: Date?
    @ObservationIgnored
    private var lastDeviationCallTime: Date?

    @ObservationIgnored
    private var contextualCache: [String: ContextualCacheEntry] = [:]

    private struct ContextualCacheEntry {
        let text: String
        let timestamp: Date
    }

    /// Invalidate contextual cache entries matching a prefix.
    func invalidateContextualCache(forKeyContaining prefix: String) {
        contextualCache = contextualCache.filter { !$0.key.contains(prefix) }
    }

    /// Returns a random focus angle different from today's default rotation.
    static func randomAlternativeAngle() -> String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        let current = contextualFocusAngles[dayOfYear % contextualFocusAngles.count]
        let others = contextualFocusAngles.filter { $0 != current }
        return others.randomElement() ?? current
    }

    /// Generate a single-sentence contextual insight for PanelView.
    /// Internal 30-min TTL cache — caller only provides cacheKey.
    func generateContextualInsight(
        aggregatedData: [String: Any],
        cacheKey key: String,
        tone: InsightTone = .normal,
        focus: InsightFocus = .balanced,
        excludeText: String? = nil,
        forcedAngle: String? = nil
    ) async throws -> String? {
        guard let client = openAI else {
            throw InsightsLLMError.noAPIKey
        }

        // Rate limit: 5s between contextual calls (independent from main insights)
        if let lastCall = lastContextualCallTime,
           Date.now.timeIntervalSince(lastCall) < 5 {
            throw InsightsLLMError.rateLimited
        }

        // Evict expired contextual entries (30 min default, 24h for cash flow)
        let now = Date.now
        contextualCache = contextualCache.filter { entry in
            let ttl: TimeInterval = entry.key.hasPrefix("cashflow_") ? 86400 : 1800
            return now.timeIntervalSince(entry.value.timestamp) < ttl
        }

        // Check cache (eviction above guarantees all entries are < 30 min)
        if let entry = contextualCache[key] {
            return entry.text
        }

        lastContextualCallTime = Date.now

        // Build JSON payload
        let jsonData = try JSONSerialization.data(withJSONObject: aggregatedData)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let locale = aggregatedData["locale"] as? String ?? "es"
        let country = aggregatedData["country"] as? String ?? ""

        // Use forced angle if provided, otherwise rotate daily
        let focusHint: String
        if let forcedAngle {
            focusHint = forcedAngle
        } else {
            let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date.now) ?? 1
            focusHint = Self.contextualFocusAngles[dayOfYear % Self.contextualFocusAngles.count]
        }

        let toneInstruction = Self.toneInstruction(for: tone, country: country)
        let focusInstruction = Self.focusInstruction(for: focus)

        let currencyCode = aggregatedData["currency"] as? String ?? "USD"
        let currencyDisplay = aggregatedData["currency_display"] as? String ?? currencyCode

        let systemPrompt = """
        Eres un analista financiero personal. Genera UNA SOLA oración corta (máximo 150 caracteres) sobre las finanzas del usuario.

        REGLAS CRÍTICAS:
        - SOLO menciona datos presentes en el JSON. NUNCA inventes categorías, montos o relaciones
        - Cada afirmación debe corresponder a un campo específico de los datos

        IDIOMA: \(locale). Tutea ("tú"), lidera con el dato, nunca regañes ni juzgues, nunca hagas preguntas. NUNCA uses "Debes...", "Tienes que...", "Obviamente...". Usa "gasto"/"ingreso", no "transacción". Siempre constructivo y orientado a solución.

        ÁNGULO HOY: Prioriza observaciones sobre "\(focusHint)". Si no hay dato relevante, elige el dato más notable.
        \(excludeText.map { "PROHIBIDO repetir esta observación: \"\($0)\". Genera una COMPLETAMENTE diferente.\n" } ?? "")\(toneInstruction)\(focusInstruction)
        REGLA DE ANCLAJE: Tu oración DEBE citar al menos un número específico de los datos (monto, porcentaje o conteo).

        Usa **negritas** para la cifra clave. Los montos están en \(currencyCode). SIEMPRE formatea: \(currencyDisplay) NÚMERO (ej: \(currencyDisplay) 4,500). La divisa SIEMPRE va ANTES del número, NUNCA después.

        JSON: {"comment": "una oración"} o {"comment": null} si no hay nada interesante.
        """

        let userMessage = "Datos financieros del periodo:\n\(jsonString)"

        let query = ChatQuery(
            messages: try buildChatMessages(system: systemPrompt, user: userMessage),
            model: .gpt4_1_mini,
            responseFormat: .jsonObject,
            temperature: 0.4
        )

        do {
            let result = try await client.chats(query: query)

            guard let content = result.choices.first?.message.content,
                  let data = content.data(using: .utf8),
                  let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw InsightsLLMError.parseFailed
            }

            // comment can be null → no insight
            let comment = dict["comment"] as? String

            if let comment {
                contextualCache[key] = ContextualCacheEntry(text: comment, timestamp: Date.now)
            }

            return comment
        } catch let error as InsightsLLMError {
            throw error
        } catch {
            throw InsightsLLMError.networkError(error)
        }
    }

    // MARK: - Cash Flow Projection Insight

    /// Generate a single-sentence insight about the cash flow projection.
    /// Uses contextualCache with 24h TTL. Key includes projection hash for invalidation.
    func generateCashFlowInsight(
        projection: CashFlowProjection,
        currencyCode: String
    ) async throws -> String? {
        guard let client = openAI else {
            throw InsightsLLMError.noAPIKey
        }

        if let lastCall = lastContextualCallTime,
           Date.now.timeIntervalSince(lastCall) < 5 {
            throw InsightsLLMError.rateLimited
        }

        // Cache key: date + projection hash
        let dayString = Self.dayFormatter.string(from: Date.now)
        let projHash = Self.projectionHash(projection)
        let cacheKey = "cashflow_\(dayString)_\(projHash)"

        // Check cache (24h TTL)
        if let entry = contextualCache[cacheKey],
           Date.now.timeIntervalSince(entry.timestamp) < 86400 {
            return entry.text
        }

        lastContextualCallTime = Date.now

        // Build compact JSON
        let data = Self.buildCashFlowPayload(projection: projection, currencyCode: currencyCode)
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let currencyDisplay = CurrencyCode(rawValue: currencyCode)?.symbol ?? currencyCode

        let systemPrompt = """
        Eres un analista financiero personal. Genera UNA SOLA oración (máximo 150 caracteres) sobre la proyección de flujo de caja del usuario.

        REGLAS CRÍTICAS:
        - SOLO menciona datos presentes en el JSON. NUNCA inventes montos o meses
        - Cada afirmación debe corresponder a un campo específico
        - Tutea ("tú"), lidera con el dato, nunca regañes ni juzgues, nunca hagas preguntas
        - NUNCA uses "Debes...", "Tienes que...", "Obviamente..."
        - Usa "gasto"/"ingreso", no "transacción". Siempre constructivo
        - Usa **negritas** para la cifra clave
        - Montos en \(currencyCode): SIEMPRE \(currencyDisplay) NÚMERO (ej: \(currencyDisplay) 4,500). Divisa ANTES del número

        JSON: {"comment": "una oración"} o {"comment": null} si no hay nada interesante.
        """

        let query = ChatQuery(
            messages: try buildChatMessages(system: systemPrompt, user: "Proyección de flujo de caja:\n\(jsonString)"),
            model: .gpt4_1_mini,
            responseFormat: .jsonObject,
            temperature: 0.4
        )

        do {
            let result = try await client.chats(query: query)

            guard let content = result.choices.first?.message.content,
                  let rawData = content.data(using: .utf8),
                  let dict = try JSONSerialization.jsonObject(with: rawData) as? [String: Any] else {
                throw InsightsLLMError.parseFailed
            }

            let comment = dict["comment"] as? String

            if let comment {
                contextualCache[cacheKey] = ContextualCacheEntry(text: comment, timestamp: Date.now)
            }

            return comment
        } catch let error as InsightsLLMError {
            throw error
        } catch {
            throw InsightsLLMError.networkError(error)
        }
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func projectionHash(_ projection: CashFlowProjection) -> Int {
        var hash = projection.months.count
        hash = hash &* 31 &+ Int(projection.months.last?.accumulatedBalance ?? 0)
        hash = hash &* 31 &+ Int(projection.totalProjectedNet)
        return hash
    }

    private static func buildCashFlowPayload(projection: CashFlowProjection, currencyCode: String) -> [String: Any] {
        let months = projection.months
        let currentMonth = months.first(where: { $0.isCurrent })
        let lowestMonth = months.min(by: { $0.accumulatedBalance < $1.accumulatedBalance })
        let monthsNegative = months.filter { $0.accumulatedBalance < 0 }.count
        let avgNet = months.isEmpty ? 0 : months.map(\.netFlow).reduce(0, +) / Double(months.count)

        var payload: [String: Any] = [
            "startingBalance": projection.startingBalance,
            "monthsTotal": months.count,
            "monthsPositive": months.count - monthsNegative,
            "monthsNegative": monthsNegative,
            "avgMonthlyNet": Int(avgNet),
            "currency": currencyCode,
        ]

        if let current = currentMonth {
            payload["currentMonth"] = [
                "name": current.date.formatted(.dateTime.month(.abbreviated).year()).lowercased(),
                "income": Int(current.totalIncome),
                "expense": Int(current.totalExpense),
                "net": Int(current.netFlow),
                "accumulated": Int(current.accumulatedBalance),
            ]
        }

        if let last = months.last {
            payload["endMonth"] = [
                "name": last.date.formatted(.dateTime.month(.abbreviated).year()).lowercased(),
                "accumulated": Int(last.accumulatedBalance),
            ]
        }

        if let lowest = lowestMonth {
            payload["lowestAccumulated"] = [
                "month": lowest.date.formatted(.dateTime.month(.abbreviated).year()).lowercased(),
                "balance": Int(lowest.accumulatedBalance),
            ]
        }

        return payload
    }

    // MARK: - Cash Flow Deviation Insight

    func generateDeviationInsight(
        deviations: [(name: String, planned: Double, actual: Double, excess: Double)],
        currencyCode: String
    ) async throws -> String? {
        guard let client = openAI else {
            throw InsightsLLMError.noAPIKey
        }

        if let lastCall = lastDeviationCallTime,
           Date.now.timeIntervalSince(lastCall) < 5 {
            throw InsightsLLMError.rateLimited
        }

        guard !deviations.isEmpty else { return nil }

        let cacheKey = "deviation_\(Self.dayFormatter.string(from: Date.now))_\(deviations.map(\.name).joined())"

        if let entry = contextualCache[cacheKey],
           Date.now.timeIntervalSince(entry.timestamp) < 86400 {
            return entry.text
        }

        lastDeviationCallTime = Date.now

        let items = deviations.map { d in
            ["name": d.name, "planned": Int(d.planned), "actual": Int(d.actual), "excess": Int(d.excess)] as [String: Any]
        }
        let totalExcess = deviations.reduce(0.0) { $0 + $1.excess }
        let payload: [String: Any] = [
            "items": items,
            "totalExcess": Int(totalExcess),
            "currency": currencyCode,
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        let currencyDisplay = CurrencyCode(rawValue: currencyCode)?.symbol ?? currencyCode

        let systemPrompt = """
        Eres un analista financiero personal. Genera UNA SOLA oración (máximo 150 caracteres) sobre las subcategorías donde el usuario gastó más de lo planeado.

        REGLAS CRÍTICAS:
        - SOLO menciona datos presentes en el JSON. NUNCA inventes montos o nombres
        - Tutea ("tú"), lidera con el dato, nunca regañes ni juzgues, nunca hagas preguntas
        - NUNCA uses "Debes...", "Tienes que...", "Obviamente..."
        - Usa "gasto", no "transacción". Siempre constructivo, sugiere algo práctico si puedes
        - Usa **negritas** para la cifra clave
        - Montos en \(currencyCode): SIEMPRE \(currencyDisplay) NÚMERO (ej: \(currencyDisplay) 4,500). Divisa ANTES del número

        JSON: {"comment": "una oración"} o {"comment": null} si no hay nada interesante.
        """

        let query = ChatQuery(
            messages: try buildChatMessages(system: systemPrompt, user: "Desviaciones del plan:\n\(jsonString)"),
            model: .gpt4_1_mini,
            responseFormat: .jsonObject,
            temperature: 0.4
        )

        do {
            let result = try await client.chats(query: query)

            guard let content = result.choices.first?.message.content,
                  let rawData = content.data(using: .utf8),
                  let dict = try JSONSerialization.jsonObject(with: rawData) as? [String: Any] else {
                throw InsightsLLMError.parseFailed
            }

            let comment = dict["comment"] as? String

            if let comment {
                contextualCache[cacheKey] = ContextualCacheEntry(text: comment, timestamp: Date.now)
            }

            return comment
        } catch let error as InsightsLLMError {
            throw error
        } catch {
            throw InsightsLLMError.networkError(error)
        }
    }
}
