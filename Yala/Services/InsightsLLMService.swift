//
//  InsightsLLMService.swift
//  Yala
//
//  Service for generating AI-powered insights via OpenAI GPT-4.1 Nano.
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

@Observable
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
    func cacheKey(period: String, filterHash: Int, txnCount: Int, comparisonMode: String = "month") -> String {
        "\(period)_\(filterHash)_\(txnCount)_\(comparisonMode)"
    }

    /// Get cached response if valid (< 5 minutes old)
    func getCached(key: String) -> LLMInsightResponse? {
        guard let entry = cache[key],
              Date().timeIntervalSince(entry.timestamp) < 300 else {
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
        cacheKey key: String
    ) async throws -> LLMInsightResponse {
        guard let client = openAI else {
            throw InsightsLLMError.noAPIKey
        }

        // Rate limit: 5s between calls
        if let lastCall = lastCallTime,
           Date().timeIntervalSince(lastCall) < 5 {
            throw InsightsLLMError.rateLimited
        }

        // Evict expired entries
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.timestamp) < 300 }

        // Check cache
        if let cached = getCached(key: key) {
            return cached
        }

        lastCallTime = Date()

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

        let systemPrompt = """
        Eres un asistente financiero personal amigable. Analiza los datos agregados del usuario y genera insights.

        IDIOMA: Responde SIEMPRE en el idioma indicado por "locale" en los datos (\(locale)). Nunca mezcles idiomas.

        COMPARACIONES: Las variaciones en los datos se comparan contra "\(comparisonRef)" (\(comparisonLabel)). Usa esa referencia al mencionar cambios o tendencias.
        \(filterContext)
        REGLAS DE VOZ:
        - Tutea al usuario
        - Lidera con el dato, opinion despues
        - Nunca culpar ni juzgar
        - Celebrar con mesura
        - Solo afirmaciones, datos, observaciones y guias. NUNCA preguntas al usuario.
        - No menciones rachas ni streaks.

        FORMATO:
        - Usa **negritas** (doble asterisco markdown) para resaltar cifras, porcentajes y datos clave en cada texto.

        FORMATO DE RESPUESTA (JSON estricto):
        {
          "hero": "Texto principal del insight mas relevante (1-2 oraciones)",
          "cards": [
            {"icon": "SF Symbol name", "text": "Texto del insight", "sentiment": "positive|neutral|attention"}
          ],
          "funFact": "Dato curioso opcional combinando datos de formas inesperadas"
        }

        Genera entre 3 y 6 cards. El hero debe ser el insight mas impactante.
        Usa iconos SF Symbols validos: chart.line.uptrend.xyaxis, arrow.down.right, flame.fill, cart, fork.knife, etc.
        """

        let userMessage = "Datos financieros del periodo:\n\(jsonString)"

        let query = ChatQuery(
            messages: [
                .init(role: .system, content: systemPrompt)!,
                .init(role: .user, content: userMessage)!
            ],
            model: .gpt4_1_nano,
            responseFormat: .jsonObject
        )

        do {
            let result = try await client.chats(query: query)

            guard let content = result.choices.first?.message.content else {
                throw InsightsLLMError.parseFailed
            }

            let response = try parseResponse(content)

            // Cache the result
            cache[key] = CacheEntry(response: response, timestamp: Date())

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
                cards.append(LLMInsightCard(icon: icon, text: text, sentiment: sentiment))
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
        cacheKey key: String
    ) async throws -> String? {
        guard let client = openAI else {
            throw InsightsLLMError.noAPIKey
        }

        // Rate limit: 5s between contextual calls (independent from main insights)
        if let lastCall = lastContextualCallTime,
           Date().timeIntervalSince(lastCall) < 5 {
            throw InsightsLLMError.rateLimited
        }

        // Evict expired contextual entries (30 min TTL)
        let now = Date()
        contextualCache = contextualCache.filter { now.timeIntervalSince($0.value.timestamp) < 1800 }

        // Check cache (eviction above guarantees all entries are < 30 min)
        if let entry = contextualCache[key] {
            return entry.text
        }

        lastContextualCallTime = Date()

        // Build JSON payload
        let jsonData = try JSONSerialization.data(withJSONObject: aggregatedData)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let locale = aggregatedData["locale"] as? String ?? "es"

        // Rotate focus angle daily so insights don't repeat the same pattern
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let focusHint = Self.contextualFocusAngles[dayOfYear % Self.contextualFocusAngles.count]

        let systemPrompt = """
        Eres un asistente financiero personal. Genera UNA SOLA oración corta sobre las finanzas del usuario.
        IDIOMA: Responde SIEMPRE en el idioma indicado por locale (\(locale)). Tutea, lidera con el dato, nunca juzgar, nunca preguntas.
        ENFOQUE HOY: prioriza observaciones sobre "\(focusHint)". Si no hay dato relevante para ese enfoque, elige otro.
        JSON estricto: {"comment": "una oración"} o {"comment": null} si no hay nada interesante.
        Usa **negritas** (doble asterisco markdown) para cifras clave.
        """

        let userMessage = "Datos financieros del periodo:\n\(jsonString)"

        let query = ChatQuery(
            messages: [
                .init(role: .system, content: systemPrompt)!,
                .init(role: .user, content: userMessage)!
            ],
            model: .gpt4_1_nano,
            responseFormat: .jsonObject
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
                contextualCache[key] = ContextualCacheEntry(text: comment, timestamp: Date())
            }

            return comment
        } catch let error as InsightsLLMError {
            throw error
        } catch {
            throw InsightsLLMError.networkError(error)
        }
    }
}
