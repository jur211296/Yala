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
    private(set) var errorMessage: String?
    var inputText: String = ""

    // MARK: - 1-Turn Memory

    private var previousQA: QAPair?

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private let service = ChatAssistantService.shared

    // MARK: - Cache (5 min persistence across sheet dismiss/reopen)

    private static let cacheTTL: TimeInterval = 300
    private var cacheTimestamp: Date?
    private var cachedMessages: [ChatMessage]?
    private var cachedPreviousQA: QAPair?

    // MARK: - Setup

    func setContext(_ ctx: ModelContext) {
        modelContext = ctx
        restoreFromCache()
        if messages.isEmpty {
            loadSuggestions()
        }
    }

    // MARK: - Suggestions (generated locally, no API)

    func loadSuggestions() {
        guard let context = modelContext else { return }
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
            // Fallback suggestions
            result = [
                ChatSuggestion(text: L10n.Chat.Suggestion.biggestCategory, icon: "chart.pie", type: .biggestCategory),
                ChatSuggestion(text: L10n.Chat.Suggestion.general, icon: "chart.bar", type: .general),
                ChatSuggestion(text: L10n.Chat.Suggestion.topMerchant, icon: "storefront", type: .topMerchant)
            ]
        }

        suggestions = Array(result.prefix(3))
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

    // MARK: - Cache (persist across sheet dismiss/reopen for 5 min)

    func saveToCache() {
        cachedMessages = messages
        cachedPreviousQA = previousQA
        cacheTimestamp = Date.now
    }

    private func restoreFromCache() {
        guard let timestamp = cacheTimestamp,
              Date.now.timeIntervalSince(timestamp) < Self.cacheTTL,
              let cached = cachedMessages, !cached.isEmpty else {
            clearCache()
            return
        }
        messages = cached
        previousQA = cachedPreviousQA
    }

    func clearCache() {
        cachedMessages = nil
        cachedPreviousQA = nil
        cacheTimestamp = nil
    }

    // MARK: - Reset

    func reset() {
        messages = []
        previousQA = nil
        errorMessage = nil
        inputText = ""
        isLoading = false
        clearCache()
        loadSuggestions()
    }
}
