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

    nonisolated private static func cacheKey(for date: Date) -> String {
        ChatSuggestionsConstants.cacheKeyPrefix + DayKeyFormatter.string(from: date)
    }

    nonisolated static func cachedSuggestions(for date: Date) -> [ChatSuggestion]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: date)) else { return nil }
        return try? JSONDecoder().decode([ChatSuggestion].self, from: data)
    }

    nonisolated static func setCached(_ suggestions: [ChatSuggestion], for date: Date) {
        guard let data = try? JSONEncoder().encode(suggestions) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey(for: date))
    }

    // MARK: - Public API

    /// Devuelve sugerencias del cache diario o las genera con LLM. Fallback a `[]` en cualquier error.
    /// Si el LLM genera sugerencias que mencionan elementos inexistentes (ej: budget llamado
    /// "Entretenimiento" cuando el user no lo tiene), pasa por `SuggestionsRewriterService`
    /// para reescribirlas usando solo nombres reales del user.
    func fetchOrGenerate(modelContext: ModelContext) async -> [ChatSuggestion] {
        // Cache hit
        if let cached = Self.cachedSuggestions(for: Date.now), cached.count >= ChatSuggestionsConstants.minItems {
            return cached
        }

        // Generate via LLM (call 1)
        do {
            let context = buildContext(modelContext: modelContext)
            let raw = try await generate(context: context)

            // Validate + rewrite si hay inválidas (call 2 condicional)
            let whitelist = SuggestionsRewriterService.Whitelist(
                categories: context.topCategories,
                subcategories: context.subcategoryNames,
                budgets: context.activeBudgets,
                tags: context.tagNames,
                merchants: context.merchantNames
            )
            let validated = try await SuggestionsRewriterService.shared.process(
                suggestions: raw,
                whitelist: whitelist,
                language: context.language
            )
            Self.setCached(validated, for: Date.now)
            TelemetryService.track(.chatSuggestionsLLMSucceeded, parameters: ["count": String(validated.count)])
            return validated
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
            guard !trimmed.isEmpty, trimmed.count <= ChatSuggestionsConstants.maxTextLength else { continue }

            let rawIcon = (item["icon"] as? String) ?? "sparkles"
            let icon = ChatSuggestionsConstants.allowedIcons.contains(rawIcon) ? rawIcon : "sparkles"

            result.append(ChatSuggestion(text: trimmed, icon: icon, type: .general))
        }

        guard result.count >= ChatSuggestionsConstants.minItems else { throw ChatSuggestionsParseError.tooFewItems }
        return Array(result.prefix(ChatSuggestionsConstants.maxItems))
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
                try await Task.sleep(for: .seconds(ChatSuggestionsConstants.timeoutSeconds))
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

        var topCategories: [String] = []
        var subcategoryNames: [String] = []
        var merchantNames: [String] = []
        var activeBudgets: [String] = []
        var tagNames: [String] = []
        var recurringPaidNames: [String] = []
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

            for tx in txs {
                if tx.category?.isIncome == true {
                    totalIncome += abs(tx.amountInPreferredCurrency)
                } else {
                    totalExpense += abs(tx.amountInPreferredCurrency)
                }
            }

            let expenseTxs = txs.filter { $0.category?.isIncome == false }

            // Top 10 categorías (era top 3) — el rewriter necesita whitelist amplio.
            var catTotals: [String: Double] = [:]
            for tx in expenseTxs {
                guard let name = tx.category?.name else { continue }
                catTotals[name, default: 0] += abs(tx.amountInPreferredCurrency)
            }
            topCategories = catTotals.sorted { $0.value > $1.value }.prefix(10).map(\.key)

            // Todas las subcategorías con tx>0 del mes.
            var subTotals: [String: Double] = [:]
            for tx in expenseTxs {
                guard let name = tx.subcategory?.name else { continue }
                subTotals[name, default: 0] += abs(tx.amountInPreferredCurrency)
            }
            subcategoryNames = subTotals.keys.sorted()

            // Top 10 merchants (era top 1).
            var merchantTotals: [String: Double] = [:]
            for tx in expenseTxs {
                if let note = tx.note, !note.isEmpty {
                    let canonical = MerchantCanonicalizer.canonicalize(note)
                    if !canonical.isEmpty {
                        merchantTotals[canonical, default: 0] += abs(tx.amountInPreferredCurrency)
                    }
                }
            }
            merchantNames = merchantTotals.sorted { $0.value > $1.value }.prefix(10).map(\.key)

            // Top 5 tags.
            var tagTotals: [String: Double] = [:]
            for tx in expenseTxs {
                for tag in tx.tags ?? [] {
                    tagTotals[tag.name, default: 0] += abs(tx.amountInPreferredCurrency)
                }
            }
            tagNames = tagTotals.sorted { $0.value > $1.value }.prefix(5).map(\.key)
        } catch {
            #if DEBUG
            print("ChatSuggestionsLLMService: fetch failed \(error)")
            #endif
        }

        // TODOS los budgets activos (era top 3).
        do {
            let budgets = try modelContext.fetch(FetchDescriptor<Budget>())
            activeBudgets = budgets.compactMap { $0.isActive ? $0.name : nil }
        } catch {
            // ignore
        }

        // Recurring paid del mes (nombres) — usa ScheduledPayment activos cuya fecha cae en el mes y <= now.
        do {
            let payments = try modelContext.fetch(FetchDescriptor<ScheduledPayment>()).filter(\.isActive)
            for payment in payments {
                let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: payment.dateCalculatorParams,
                    month: now,
                    calendar: calendar
                )
                if dates.contains(where: { $0 <= now && !payment.isDateSkipped($0) }) {
                    recurringPaidNames.append(payment.name)
                }
            }
        } catch {
            // ignore
        }

        return ChatSuggestionsContext(
            language: language,
            topCategories: topCategories,
            subcategoryNames: subcategoryNames,
            merchantNames: merchantNames,
            activeBudgets: activeBudgets,
            tagNames: tagNames,
            recurringPaidNames: recurringPaidNames,
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
            parts.append("Top categorías: \(context.topCategories.joined(separator: ", "))")
        }
        if !context.subcategoryNames.isEmpty {
            parts.append("Subcategorías: \(context.subcategoryNames.prefix(20).joined(separator: ", "))")
        }
        if !context.merchantNames.isEmpty {
            parts.append("Merchants frecuentes: \(context.merchantNames.joined(separator: ", "))")
        }
        if !context.activeBudgets.isEmpty {
            parts.append("Presupuestos activos: \(context.activeBudgets.joined(separator: ", "))")
        }
        if !context.tagNames.isEmpty {
            parts.append("Etiquetas: \(context.tagNames.joined(separator: ", "))")
        }
        if !context.recurringPaidNames.isEmpty {
            parts.append("Recurrentes pagados este mes: \(context.recurringPaidNames.joined(separator: ", "))")
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
    let subcategoryNames: [String]
    let merchantNames: [String]
    let activeBudgets: [String]
    let tagNames: [String]
    let recurringPaidNames: [String]
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

// MARK: - Constants (nonisolated para uso desde parseSuggestions / cacheKey)

nonisolated enum ChatSuggestionsConstants {
    static let cacheKeyPrefix = "chat_suggestions_"
    static let timeoutSeconds: TimeInterval = 8
    static let maxItems = 10
    static let minItems = 3
    static let maxTextLength = 80

    static let allowedIcons: Set<String> = [
        "chart.bar", "chart.pie", "chart.line.uptrend.xyaxis", "calendar",
        "arrow.left.arrow.right", "creditcard", "storefront", "dollarsign.circle",
        "percent", "banknote", "cart", "sparkles"
    ]
}
