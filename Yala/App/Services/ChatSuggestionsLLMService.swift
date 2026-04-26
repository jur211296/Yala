//
//  ChatSuggestionsLLMService.swift
//  Yala
//
//  Genera sugerencias de chat dinámicas y personalizadas con LLM, cacheadas por día.
//  Fallback silencioso a [] si cualquier paso falla; el VM cae a sugerencias rule-based.
//

import Foundation
import OpenAI
import SwiftData

@MainActor @Observable
final class ChatSuggestionsLLMService {

    // MARK: - Singleton

    static let shared = ChatSuggestionsLLMService()
    private init() {}

    // MARK: - OpenAI Client (lazy)

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

    // MARK: - Cache (UserDefaults, key chat_suggestions_<YYYY-MM-DD>)

    private static let cacheKeyPrefix = "chat_suggestions_"

    nonisolated private static func cacheKey(for date: Date) -> String {
        cacheKeyPrefix + DayKeyFormatter.string(from: date)
    }

    nonisolated static func cachedSuggestions(for date: Date) -> [ChatSuggestion]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: date)) else { return nil }
        return try? JSONDecoder().decode([ChatSuggestion].self, from: data)
    }

    nonisolated static func setCached(_ suggestions: [ChatSuggestion], for date: Date) {
        guard let data = try? JSONEncoder().encode(suggestions) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: date))
    }

    // MARK: - Constants

    private static let timeoutSeconds: TimeInterval = 8
    private static let maxItems = 10
    private static let minItems = 3
    private static let maxTextLength = 80

    private static let allowedIcons: Set<String> = [
        "chart.bar", "chart.pie", "chart.line.uptrend.xyaxis", "calendar",
        "arrow.left.arrow.right", "creditcard", "storefront", "dollarsign.circle",
        "percent", "banknote", "cart", "sparkles"
    ]

    // MARK: - Public API

    /// Devuelve sugerencias del cache diario o las genera con LLM. Fallback a `[]` en cualquier error.
    func fetchOrGenerate(modelContext: ModelContext) async -> [ChatSuggestion] {
        // Cache hit
        if let cached = Self.cachedSuggestions(for: Date.now), cached.count >= Self.minItems {
            return cached
        }

        // Generate via LLM
        do {
            let context = buildContext(modelContext: modelContext)
            let suggestions = try await generate(context: context)
            Self.setCached(suggestions, for: Date.now)
            TelemetryService.track(.chatSuggestionsLLMSucceeded, parameters: ["count": String(suggestions.count)])
            return suggestions
        } catch {
            TelemetryService.track(.chatSuggestionsLLMFailed, parameters: ["reason": String(describing: error)])
            return []
        }
    }

    // MARK: - Parser (estático, aislado para testing sin mockear OpenAI)

    /// Parsea el JSON `{ "suggestions": [{ "text": "…", "icon": "…" }, ...] }` y valida.
    nonisolated static func parseSuggestions(json: String) throws -> [ChatSuggestion] {
        guard let data = json.data(using: .utf8) else {
            throw ChatSuggestionsParseError.malformedJSON
        }
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ChatSuggestionsParseError.malformedJSON
        }
        guard let dict = parsed as? [String: Any],
              let array = dict["suggestions"] as? [[String: Any]] else {
            throw ChatSuggestionsParseError.malformedJSON
        }

        guard !array.isEmpty else { throw ChatSuggestionsParseError.emptyArray }

        var result: [ChatSuggestion] = []
        for item in array {
            guard let text = item["text"] as? String else { continue }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= maxTextLength else { continue }

            let rawIcon = (item["icon"] as? String) ?? "sparkles"
            let icon = allowedIcons.contains(rawIcon) ? rawIcon : "sparkles"

            result.append(ChatSuggestion(text: trimmed, icon: icon, type: .general))
        }

        guard result.count >= minItems else { throw ChatSuggestionsParseError.tooFewItems }
        return Array(result.prefix(maxItems))
    }

    // MARK: - Generation

    private func generate(context: ChatSuggestionsContext) async throws -> [ChatSuggestion] {
        guard let client = openAI else { throw ChatSuggestionsLLMError.noAPIKey }
        guard NetworkMonitor.shared.isConnected else { throw ChatSuggestionsLLMError.offline }

        let systemPrompt = buildSystemPrompt(language: context.language)
        let userPrompt = buildUserPrompt(context: context)

        let messages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: systemPrompt),
            .init(role: .user, content: userPrompt)
        ].compactMap { $0 }

        let query = ChatQuery(
            messages: messages,
            model: .gpt4_1_nano,
            responseFormat: .jsonObject,
            temperature: 0.7
        )

        let result = try await callWithTimeout(query, client: client)
        guard let content = result.choices.first?.message.content else {
            throw ChatSuggestionsLLMError.parseFailed
        }
        return try Self.parseSuggestions(json: content)
    }

    private func callWithTimeout(_ query: ChatQuery, client: OpenAI) async throws -> ChatResult {
        try await withThrowingTaskGroup(of: ChatResult.self) { group in
            group.addTask { try await client.chats(query: query) }
            group.addTask {
                try await Task.sleep(for: .seconds(Self.timeoutSeconds))
                throw ChatSuggestionsLLMError.timeout
            }
            guard let first = try await group.next() else {
                throw ChatSuggestionsLLMError.timeout
            }
            group.cancelAll()
            return first
        }
    }

    // MARK: - Context Builder

    private func buildContext(modelContext: ModelContext) -> ChatSuggestionsContext {
        let language = LanguageManager.overrideLanguage
            ?? Locale.current.language.languageCode?.identifier
            ?? "es"

        let now = Date.now
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now

        // Top categorías del mes
        var topCategories: [String] = []
        var topMerchant: String?
        var totalIncome: Double = 0
        var totalExpense: Double = 0

        do {
            let descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { $0.date >= monthStart },
                sortBy: [SortDescriptor(\TransactionItem.date, order: .reverse)]
            )
            let txs = try modelContext.fetch(descriptor).filter {
                $0.balanceAdjustmentType == nil && $0.account?.excludeFromStatistics != true
            }

            // Income / expense totals
            for tx in txs {
                if tx.category?.isIncome == true {
                    totalIncome += abs(tx.amountInPreferredCurrency)
                } else {
                    totalExpense += abs(tx.amountInPreferredCurrency)
                }
            }

            // Top categories (expense)
            let expenseTxs = txs.filter { $0.category?.isIncome == false }
            var catTotals: [String: Double] = [:]
            for tx in expenseTxs {
                guard let name = tx.category?.name else { continue }
                catTotals[name, default: 0] += abs(tx.amountInPreferredCurrency)
            }
            topCategories = catTotals.sorted { $0.value > $1.value }.prefix(3).map(\.key)

            // Top merchant
            var merchantCounts: [String: Int] = [:]
            for tx in expenseTxs {
                if let note = tx.note, !note.isEmpty {
                    let canonical = MerchantCanonicalizer.canonicalize(note)
                    if !canonical.isEmpty { merchantCounts[canonical, default: 0] += 1 }
                }
            }
            topMerchant = merchantCounts.max(by: { $0.value < $1.value })?.key
        } catch {
            #if DEBUG
            print("ChatSuggestionsLLMService: fetch failed \(error)")
            #endif
        }

        // Active budgets
        var activeBudgets: [String] = []
        do {
            let budgets = try modelContext.fetch(FetchDescriptor<Budget>())
            activeBudgets = budgets.compactMap { $0.isActive ? $0.category?.name : nil }.prefix(3).map { $0 }
        } catch {
            // ignore
        }

        return ChatSuggestionsContext(
            language: language,
            topCategories: topCategories,
            topMerchant: topMerchant,
            activeBudgets: activeBudgets,
            totalIncome: totalIncome,
            totalExpense: totalExpense
        )
    }

    // MARK: - Prompts

    private func buildSystemPrompt(language: String) -> String {
        """
        You generate personalized chat conversation starters for a personal finance app.

        CRITICAL RULES:
        - RESPOND ONLY IN \(language). Do NOT translate. Do NOT mix languages.
        - Output STRICT JSON: { "suggestions": [{ "text": "…", "icon": "<sf-symbol>" }, ...] }
        - Generate exactly 10 suggestions.
        - Each text ≤ 80 chars, phrased as a question the user could ask the assistant.
        - Be SPECIFIC to the user's data: cite categories, merchants or budget names provided in the user message. Avoid generic questions.
        - Mix topics: spending breakdown, budgets, comparisons, trends, projections, day-of-week patterns, recurring payments.
        - Tone: cercano, 2nd person ("tú"). Brand voice: nunca regaña.
        - Allowed icons: chart.bar, chart.pie, chart.line.uptrend.xyaxis, calendar, arrow.left.arrow.right, creditcard, storefront, dollarsign.circle, percent, banknote, cart, sparkles.

        EXAMPLE (ES):
        {
          "suggestions": [
            { "text": "¿Por qué gasté más en Restaurantes este mes?", "icon": "chart.pie" },
            { "text": "¿Cuánto me queda del presupuesto de Mercado?", "icon": "chart.bar" }
          ]
        }
        """
    }

    private func buildUserPrompt(context: ChatSuggestionsContext) -> String {
        var parts: [String] = []
        if !context.topCategories.isEmpty {
            parts.append("Top categorías de gasto: \(context.topCategories.joined(separator: ", "))")
        }
        if let merchant = context.topMerchant {
            parts.append("Merchant más frecuente: \(merchant)")
        }
        if !context.activeBudgets.isEmpty {
            parts.append("Presupuestos activos: \(context.activeBudgets.joined(separator: ", "))")
        }
        parts.append("Ingresos del mes: \(Int(context.totalIncome))")
        parts.append("Gastos del mes: \(Int(context.totalExpense))")
        return parts.joined(separator: "\n")
    }
}

// MARK: - Supporting Types

struct ChatSuggestionsContext {
    let language: String
    let topCategories: [String]
    let topMerchant: String?
    let activeBudgets: [String]
    let totalIncome: Double
    let totalExpense: Double
}

enum ChatSuggestionsLLMError: Error {
    case noAPIKey
    case offline
    case timeout
    case parseFailed
}

enum ChatSuggestionsParseError: Error {
    case malformedJSON
    case emptyArray
    case tooFewItems
}
