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

    /// Build a cache key from period + filter hash + transaction count + comparison mode
    func cacheKey(period: String, filterHash: Int, txnCount: Int, comparisonMode: String = "month", tone: InsightTone = .normal, focus: InsightFocus = .balanced) -> String {
        "\(period)_\(filterHash)_\(txnCount)_\(comparisonMode)_\(tone.rawValue)_\(focus.rawValue)"
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

        // Extract locale and comparison context from aggregated data
        let locale = aggregatedData["locale"] as? String ?? "es"
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

        let toneInstruction = Self.toneInstruction(for: tone)
        let focusInstruction = Self.focusInstruction(for: focus)

        let currencyCode = aggregatedData["currency"] as? String ?? "USD"

        let systemPrompt = """
        Eres un analista financiero personal. Analizas EXCLUSIVAMENTE los datos agregados proporcionados.

        REGLAS CRÍTICAS:
        1. NUNCA menciones datos, categorías, montos o relaciones que NO estén en el JSON
        2. NUNCA cruces información de campos no relacionados (ej: NO mezcles el nombre de una categoría con un presupuesto de otra categoría)
        3. Cada afirmación DEBE corresponder a un campo específico de los datos
        4. Si un campo dice "N/A" o no existe, NO menciones ese tema
        5. Los montos están en la moneda indicada por el campo "currency" (\(currencyCode)). Usa el símbolo apropiado: PEN→S/, USD→$, EUR→€, MXN→MX$, etc.

        IDIOMA: Responde SIEMPRE en \(locale). Nunca mezcles idiomas.

        COMPARACIONES: Las variaciones se comparan contra "\(comparisonRef)" (\(comparisonLabel)).
        \(filterContext)
        FRAMEWORK DE ANÁLISIS (sigue este orden de prioridad):
        1. PANORAMA: total_expense, total_income, net_balance y sus variaciones. ¿Mes positivo o negativo? ¿Tendencia?
        2. CONCENTRACIÓN: top_categories — ¿alguna categoría domina excesivamente? ¿Distribución saludable?
        3. COMPROMISOS: budgets_at_risk (compara spent vs limit), subscriptions, pending_payments
        4. PATRONES: highest_avg_weekday, daily_avg y su variación, highest_expense (gasto atípico?)
        5. NECESIDADES: distribución essential/priority/optional — ¿equilibrio razonable?

        Genera insights que conecten estos datos de forma lógica. Por ejemplo:
        - Si el gasto subió 20% Y la categoría top creció, esa categoría puede ser la causa
        - Si un presupuesto está al 90% Y quedan días del mes, hay riesgo real
        - Si el opcional supera al esencial, es una señal de alerta

        REGLAS DE VOZ:
        - Tutea al usuario
        - Lidera con el dato, opinión después
        - Nunca culpar ni juzgar
        - Celebrar con mesura
        - Solo afirmaciones, datos, observaciones y guías. NUNCA preguntas
        - No menciones rachas ni streaks
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
            messages: [
                .init(role: .system, content: systemPrompt)!,
                .init(role: .user, content: userMessage)!
            ],
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

    private static func toneInstruction(for tone: InsightTone) -> String {
        switch tone {
        case .normal:
            return ""
        case .considerate:
            return "\nESTILO: Empatico y comprensivo. Reconoce esfuerzos. Suaviza datos negativos con contexto ('entiendo que...', 'es normal que...'). Siempre con respeto y sin juzgar.\n"
        case .sarcastic:
            return "\nESTILO: Humor carinoso y ligero. Ironia amable, NUNCA cruel ni hiriente. Metaforas cotidianas divertidas. Datos precisos aunque el tono sea jugueton. Siempre con carino.\n"
        }
    }

    private static func focusInstruction(for focus: InsightFocus) -> String {
        switch focus {
        case .balanced:
            return ""
        case .saver:
            return "\nENFOQUE: Prioriza oportunidades de ahorro. Compara con periodos de menor gasto. Celebra reducciones. Sugiere areas donde optimizar.\n"
        case .cautious:
            return "\nENFOQUE: Alertas tempranas. Prioriza presupuestos en riesgo y proyecciones de sobregasto. Destaca tendencias preocupantes antes de que se consoliden.\n"
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
    private var contextualCache: [String: ContextualCacheEntry] = [:]

    private struct ContextualCacheEntry {
        let text: String
        let timestamp: Date
    }

    /// Generate a single-sentence contextual insight for PanelView.
    /// Internal 30-min TTL cache — caller only provides cacheKey.
    func generateContextualInsight(
        aggregatedData: [String: Any],
        cacheKey key: String,
        tone: InsightTone = .normal,
        focus: InsightFocus = .balanced
    ) async throws -> String? {
        guard let client = openAI else {
            throw InsightsLLMError.noAPIKey
        }

        // Rate limit: 5s between contextual calls (independent from main insights)
        if let lastCall = lastContextualCallTime,
           Date.now.timeIntervalSince(lastCall) < 5 {
            throw InsightsLLMError.rateLimited
        }

        // Evict expired contextual entries (30 min TTL)
        let now = Date.now
        contextualCache = contextualCache.filter { now.timeIntervalSince($0.value.timestamp) < 1800 }

        // Check cache (eviction above guarantees all entries are < 30 min)
        if let entry = contextualCache[key] {
            return entry.text
        }

        lastContextualCallTime = Date.now

        // Build JSON payload
        let jsonData = try JSONSerialization.data(withJSONObject: aggregatedData)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let locale = aggregatedData["locale"] as? String ?? "es"

        // Rotate focus angle daily so insights don't repeat the same pattern
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date.now) ?? 1
        let focusHint = Self.contextualFocusAngles[dayOfYear % Self.contextualFocusAngles.count]

        let toneInstruction = Self.toneInstruction(for: tone)
        let focusInstruction = Self.focusInstruction(for: focus)

        let currencyCode = aggregatedData["currency"] as? String ?? "USD"

        let systemPrompt = """
        Eres un analista financiero personal. Genera UNA SOLA oración sobre las finanzas del usuario.

        REGLAS CRÍTICAS:
        - SOLO menciona datos presentes en el JSON. NUNCA inventes categorías, montos o relaciones
        - Cada afirmación debe corresponder a un campo específico de los datos

        IDIOMA: \(locale). Tutea, lidera con el dato, nunca juzgues, nunca hagas preguntas.

        ÁNGULO HOY: Prioriza observaciones sobre "\(focusHint)". Si no hay dato relevante, elige el dato más notable.
        \(toneInstruction)\(focusInstruction)
        REGLA DE ANCLAJE: Tu oración DEBE citar al menos un número específico de los datos (monto, porcentaje o conteo).

        Usa **negritas** para la cifra clave. Los montos están en \(currencyCode).

        JSON: {"comment": "una oración"} o {"comment": null} si no hay nada interesante.
        """

        let userMessage = "Datos financieros del periodo:\n\(jsonString)"

        let query = ChatQuery(
            messages: [
                .init(role: .system, content: systemPrompt)!,
                .init(role: .user, content: userMessage)!
            ],
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
}
