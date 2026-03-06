//
//  InsightsLLMService.swift
//  Yala
//
//  Service for generating AI-powered insights via OpenAI GPT-4o Mini.
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

    /// Build a cache key from period + filter hash + transaction count
    func cacheKey(period: String, filterHash: Int, txnCount: Int) -> String {
        "\(period)_\(filterHash)_\(txnCount)"
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

        let systemPrompt = """
        Eres un asistente financiero personal amigable. Analiza los datos agregados del usuario y genera insights.

        REGLAS DE VOZ:
        - Tutea al usuario
        - Lidera con el dato, opinion despues
        - Nunca culpar ni juzgar
        - Proponer, no imponer ("que tal si...?")
        - Celebrar con mesura
        - Ofrecer accion ("revisamos?", "ajustamos?")

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
            model: .gpt4_o_mini,
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
    }
}
