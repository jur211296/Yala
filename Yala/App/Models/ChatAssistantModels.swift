//
//  ChatAssistantModels.swift
//  Yala
//
//  DTOs, enums and param structs for the Ask Yala chat assistant.
//

import Foundation

// MARK: - Chat Error

enum ChatAssistantError: Error, LocalizedError {
    case noAPIKey
    case notProUser
    case noAIConsent
    case offline
    case rateLimited
    case dailyLimitReached
    case questionTooLong
    case emptyQuestion
    case toolExecutionFailed(String)
    case parseFailed
    case networkError(Error)
    case timeout

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key configured"
        case .notProUser: return "Pro subscription required"
        case .noAIConsent: return "AI consent not accepted"
        case .offline: return "No internet connection"
        case .rateLimited: return "Please wait a few seconds"
        case .dailyLimitReached: return "Daily question limit reached"
        case .questionTooLong: return "Question too long"
        case .emptyQuestion: return "Question is empty"
        case .toolExecutionFailed(let reason): return "Tool execution failed: \(reason)"
        case .parseFailed: return "Failed to parse response"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .timeout: return "Request timed out"
        }
    }
}

// MARK: - QA Pair (1-turn memory)

nonisolated struct QAPair: Codable {
    let question: String
    let toolName: String?
    let toolResultJSON: String?
    let response: String
    let timestamp: Date

    var isExpired: Bool {
        Date.now.timeIntervalSince(timestamp) > 300
    }
}

// MARK: - Chat Tool Name

enum ChatToolName: String, CaseIterable {
    case searchTransactions = "search_transactions"
    case spendingSummary = "spending_summary"
    case budgetStatus = "budget_status"
    case comparePeriods = "compare_periods"
    case financialOverview = "financial_overview"
    case accountBalances = "account_balances"
    case upcomingPayments = "upcoming_payments"
    case analyzePatterns = "analyze_patterns"
    case spendingProjection = "spending_projection"
}

// MARK: - Analysis Type (for analyze_patterns tool)

enum ChatAnalysisType: String, Codable {
    case smallRecurring = "small_recurring"
    case frequencyRanking = "frequency_ranking"
    case unusualSpending = "unusual_spending"
    case weekdayPattern = "weekday_pattern"
    case needsBreakdown = "needs_breakdown"
}

// MARK: - Chat Date Range

enum ChatDateRange: String, Codable {
    case today
    case yesterday
    case thisWeek = "this_week"
    case lastWeek = "last_week"
    case thisMonth = "this_month"
    case lastMonth = "last_month"
    case thisYear = "this_year"
    case last7Days = "last_7_days"
    case last30Days = "last_30_days"
    case custom

    func toDateInterval(dateFrom: String? = nil, dateTo: String? = nil) -> DateInterval {
        let calendar = Calendar.current
        let now = Date.now
        let startOfToday = calendar.startOfDay(for: now)

        switch self {
        case .today:
            return DateInterval(start: startOfToday, end: now)
        case .yesterday:
            let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
            return DateInterval(start: yesterday, end: startOfToday)
        case .thisWeek:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
            return DateInterval(start: weekStart, end: now)
        case .lastWeek:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
            let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? startOfToday
            return DateInterval(start: prevWeekStart, end: weekStart)
        case .thisMonth:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            return DateInterval(start: monthStart, end: now)
        case .lastMonth:
            let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            let prevMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? startOfToday
            return DateInterval(start: prevMonthStart, end: monthStart)
        case .thisYear:
            let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? startOfToday
            return DateInterval(start: yearStart, end: now)
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: now)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: now)
        case .custom:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let start = dateFrom.flatMap { formatter.date(from: $0) } ?? startOfToday
            let end = dateTo.flatMap { formatter.date(from: $0) } ?? now
            return DateInterval(start: start, end: end)
        }
    }
}

// MARK: - Tool Parameter Structs (Codable, parsed from LLM function_call arguments)

struct SearchTransactionsParams: Codable {
    let merchant: String?
    let category: String?
    let dateRange: String?
    let dateFrom: String?
    let dateTo: String?
    let type: String?
    let currency: String?
    let limit: Int?
    let amountMin: Double?
    let amountMax: Double?
    let sortBy: String?
    let tag: String?
    let account: String?

    enum CodingKeys: String, CodingKey {
        case merchant, category
        case dateRange = "date_range"
        case dateFrom = "date_from"
        case dateTo = "date_to"
        case type, currency, limit
        case amountMin = "amount_min"
        case amountMax = "amount_max"
        case sortBy = "sort_by"
        case tag, account
    }
}

struct SpendingSummaryParams: Codable {
    let dateRange: String
    let groupBy: String
    let type: String?
    let limit: Int?
    let amountMin: Double?
    let amountMax: Double?

    enum CodingKeys: String, CodingKey {
        case dateRange = "date_range"
        case groupBy = "group_by"
        case type, limit
        case amountMin = "amount_min"
        case amountMax = "amount_max"
    }
}

struct BudgetStatusParams: Codable {
    let category: String?
    let dateRange: String?

    enum CodingKeys: String, CodingKey {
        case category
        case dateRange = "date_range"
    }
}

struct ComparePeriodsParams: Codable {
    let metric: String
    let periodA: String
    let periodB: String
    let category: String?
    let merchant: String?

    enum CodingKeys: String, CodingKey {
        case metric
        case periodA = "period_a"
        case periodB = "period_b"
        case category, merchant
    }
}

struct FinancialOverviewParams: Codable {
    let dateRange: String

    enum CodingKeys: String, CodingKey {
        case dateRange = "date_range"
    }
}

struct AccountBalancesParams: Codable {
    let account: String?
}

struct UpcomingPaymentsParams: Codable {
    let daysAhead: Int?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case daysAhead = "days_ahead"
        case category
    }
}

struct AnalyzePatternsParams: Codable {
    let analysisType: String
    let dateRange: String
    let thresholdAmount: Double?
    let category: String?
    let limit: Int?

    enum CodingKeys: String, CodingKey {
        case analysisType = "analysis_type"
        case dateRange = "date_range"
        case thresholdAmount = "threshold_amount"
        case category, limit
    }
}

struct SpendingProjectionParams: Codable {
    let category: String?
}

// MARK: - Chat Message

nonisolated struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, text: String, timestamp: Date) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
    }

    enum MessageRole: String, Codable {
        case user
        case assistant
    }
}

// MARK: - Chat Suggestion

nonisolated struct ChatSuggestion: Identifiable, Codable {
    let id: UUID
    let text: String
    let icon: String
    let type: SuggestionType

    init(id: UUID = UUID(), text: String, icon: String, type: SuggestionType) {
        self.id = id
        self.text = text
        self.icon = icon
        self.type = type
    }

    enum SuggestionType: String, Codable {
        case topMerchant
        case biggestCategory
        case activeBudget
        case comparison
        case general
    }
}

// MARK: - Persisted Session (day-calendar storage blob)

/// Blob JSON guardado en `UserDefaults` con clave `chat_session_<YYYY-MM-DD>`.
/// Persiste mensajes + todos los turnos del día (allTurns) para que el LLM reciba
/// contexto multi-turno completo en cada nueva pregunta.
nonisolated struct ChatPersistedSession: Codable {
    let messages: [ChatMessage]
    let allTurns: [QAPair]

    init(messages: [ChatMessage], allTurns: [QAPair]) {
        self.messages = messages
        self.allTurns = allTurns
    }

    enum CodingKeys: String, CodingKey {
        case messages
        case allTurns
        case previousQA
    }

    /// Decoder con migración: blobs antiguos guardaban `previousQA: QAPair?` (1-turn).
    /// Se hidratan como `allTurns: [previousQA]` para no perder contexto.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.messages = try c.decodeIfPresent([ChatMessage].self, forKey: .messages) ?? []

        if let turns = try c.decodeIfPresent([QAPair].self, forKey: .allTurns) {
            self.allTurns = turns
        } else if let legacy = try c.decodeIfPresent(QAPair.self, forKey: .previousQA) {
            self.allTurns = [legacy]
        } else {
            self.allTurns = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(messages, forKey: .messages)
        try c.encode(allTurns, forKey: .allTurns)
    }
}
