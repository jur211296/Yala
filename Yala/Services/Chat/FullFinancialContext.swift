//
//  FullFinancialContext.swift
//  Yala
//
//  Single struct serializable to JSON con TODA la data financiera relevante del
//  user. Se inyecta en el system prompt de Yala IA en cada llamada (Opción B
//  context-rich). El LLM responde directo sin function calling.
//
//  Keys del JSON en inglés (los LLMs procesan keys EN universalmente). Valores
//  localizados (nombres reales: "Mercado", "Restaurantes").
//

import Foundation

struct FullFinancialContext: Codable, Equatable {
    let metadata: Metadata
    let balances: BalancesSection
    let periods: PeriodsSection
    let categories: [CategoryEntry]
    let uncategorized: UncategorizedBucket
    let merchantsTop20: [MerchantEntry]
    let budgets: [BudgetEntry]
    let recurring: RecurringSection
    let patterns: PatternsSection
    let tagsTop10: [TagEntry]
    let topTxBySubcategory: [SubcategoryTxEntry]
    let anomalies: [AnomalyEntry]?

    enum CodingKeys: String, CodingKey {
        case metadata, balances, periods, categories, uncategorized
        case merchantsTop20 = "merchants_top_20"
        case budgets, recurring, patterns
        case tagsTop10 = "tags_top_10"
        case topTxBySubcategory = "top_tx_by_subcategory"
        case anomalies
    }

    /// Serialize to compact JSON for system prompt injection.
    func toJSONString() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }
}

// MARK: - Metadata

extension FullFinancialContext {

    struct Metadata: Codable, Equatable {
        let dateToday: String       // ISO yyyy-MM-dd
        let weekday: String         // "Sunday" .. "Saturday"
        let monthLabel: String      // e.g., "April 2026"
        let currency: String        // "USD"
        let currencyDisplay: String // "$" or "USD"
        let language: String        // "es", "en", etc.
        let country: String         // "PE", "US", etc.
        let excludedAccounts: [String] // Names of accounts excluded from aggregates

        enum CodingKeys: String, CodingKey {
            case dateToday = "date_today"
            case weekday
            case monthLabel = "month_label"
            case currency
            case currencyDisplay = "currency_display"
            case language, country
            case excludedAccounts = "excluded_accounts"
        }
    }
}

// MARK: - Balances

extension FullFinancialContext {

    struct BalancesSection: Codable, Equatable {
        let accounts: [AccountEntry]
        let totalBalance: Double

        enum CodingKeys: String, CodingKey {
            case accounts
            case totalBalance = "total_balance"
        }
    }

    struct AccountEntry: Codable, Equatable {
        let name: String
        let type: String
        let balance: Double
        let currency: String
    }
}

// MARK: - Periods

extension FullFinancialContext {

    struct PeriodsSection: Codable, Equatable {
        let today: PeriodSummary
        let currentWeek: PeriodSummary
        let lastWeek: PeriodSummary
        let last4Weeks: [WeekSummary]
        let currentMonth: PeriodSummary
        let lastMonth: PeriodSummary
        let twoMonthsAgo: PeriodSummary
        let threeMonthsAgo: PeriodSummary
        let currentYear: PeriodSummary

        enum CodingKeys: String, CodingKey {
            case today
            case currentWeek = "current_week"
            case lastWeek = "last_week"
            case last4Weeks = "last_4_weeks"
            case currentMonth = "current_month"
            case lastMonth = "last_month"
            case twoMonthsAgo = "two_months_ago"
            case threeMonthsAgo = "three_months_ago"
            case currentYear = "current_year"
        }
    }

    struct PeriodSummary: Codable, Equatable {
        let income: Double
        let expense: Double
        let balance: Double
        let txCount: Int
        let dailyAvg: Double
        let savingsRatePercent: Double?  // null if income == 0

        enum CodingKeys: String, CodingKey {
            case income, expense, balance
            case txCount = "tx_count"
            case dailyAvg = "daily_avg"
            case savingsRatePercent = "savings_rate_percent"
        }
    }

    struct WeekSummary: Codable, Equatable {
        let weekStart: String   // ISO yyyy-MM-dd
        let income: Double
        let expense: Double

        enum CodingKeys: String, CodingKey {
            case weekStart = "week_start"
            case income, expense
        }
    }
}

// MARK: - Categories

extension FullFinancialContext {

    struct CategoryEntry: Codable, Equatable {
        let name: String
        let totalCurrentMonth: Double
        let totalLastMonth: Double
        let totalTwoMonthsAgo: Double
        let variationPercentVsLastMonth: Double?  // null if last month was 0
        let txCountCurrentMonth: Int
        let subcategories: [SubcategoryEntry]

        enum CodingKeys: String, CodingKey {
            case name
            case totalCurrentMonth = "total_current_month"
            case totalLastMonth = "total_last_month"
            case totalTwoMonthsAgo = "total_two_months_ago"
            case variationPercentVsLastMonth = "variation_percent_vs_last_month"
            case txCountCurrentMonth = "tx_count_current_month"
            case subcategories
        }
    }

    struct SubcategoryEntry: Codable, Equatable {
        let name: String
        let totalCurrentMonth: Double
        let totalLastMonth: Double
        let totalTwoMonthsAgo: Double
        let variationPercentVsLastMonth: Double?
        let txCountCurrentMonth: Int

        enum CodingKeys: String, CodingKey {
            case name
            case totalCurrentMonth = "total_current_month"
            case totalLastMonth = "total_last_month"
            case totalTwoMonthsAgo = "total_two_months_ago"
            case variationPercentVsLastMonth = "variation_percent_vs_last_month"
            case txCountCurrentMonth = "tx_count_current_month"
        }
    }

    /// Bucket explícito para tx con `category == nil` — se mantienen visibles al LLM.
    struct UncategorizedBucket: Codable, Equatable {
        let totalCurrentMonth: Double
        let txCountCurrentMonth: Int

        enum CodingKeys: String, CodingKey {
            case totalCurrentMonth = "total_current_month"
            case txCountCurrentMonth = "tx_count_current_month"
        }
    }
}

// MARK: - Merchants

extension FullFinancialContext {

    struct MerchantEntry: Codable, Equatable {
        let name: String       // canonicalized
        let totalCurrentMonth: Double
        let totalLastMonth: Double
        let txCount: Int
        let avgAmount: Double
        let variationPercentVsLastMonth: Double?

        enum CodingKeys: String, CodingKey {
            case name
            case totalCurrentMonth = "total_current_month"
            case totalLastMonth = "total_last_month"
            case txCount = "tx_count"
            case avgAmount = "avg_amount"
            case variationPercentVsLastMonth = "variation_percent_vs_last_month"
        }
    }
}

// MARK: - Budgets

extension FullFinancialContext {

    struct BudgetEntry: Codable, Equatable {
        let name: String
        let category: String?
        let limit: Double
        let spent: Double
        let usagePercent: Double?      // null if limit == 0
        let daysLeft: Int
        let status: BudgetStatus
        let periodType: String         // "monthly" | "weekly" | "yearly" | "unique"
        let currency: String

        enum CodingKeys: String, CodingKey {
            case name, category, limit, spent
            case usagePercent = "usage_percent"
            case daysLeft = "days_left"
            case status
            case periodType = "period_type"
            case currency
        }
    }

    enum BudgetStatus: String, Codable, Equatable {
        case onTrack = "on_track"
        case atRisk = "at_risk"
        case exceeded
        case noLimit = "no_limit"
    }
}

// MARK: - Recurring

extension FullFinancialContext {

    struct RecurringSection: Codable, Equatable {
        let paidThisMonth: [RecurringPaidEntry]
        let pendingNext30Days: [RecurringPendingEntry]
        let totals: RecurringTotals

        enum CodingKeys: String, CodingKey {
            case paidThisMonth = "paid_this_month"
            case pendingNext30Days = "pending_next_30_days"
            case totals
        }
    }

    struct RecurringPaidEntry: Codable, Equatable {
        let name: String
        let amount: Double
        let date: String   // ISO yyyy-MM-dd
        let category: String?
        let subcategory: String?
    }

    struct RecurringPendingEntry: Codable, Equatable {
        let name: String
        let amount: Double
        let dueDate: String  // ISO yyyy-MM-dd
        let category: String?
        let subcategory: String?
        let type: String     // "subscription" | "recurring" | "one_time"

        enum CodingKeys: String, CodingKey {
            case name, amount
            case dueDate = "due_date"
            case category, subcategory, type
        }
    }

    struct RecurringTotals: Codable, Equatable {
        let subscriptionsMonthly: Double
        let recurringMonthly: Double

        enum CodingKeys: String, CodingKey {
            case subscriptionsMonthly = "subscriptions_monthly"
            case recurringMonthly = "recurring_monthly"
        }
    }
}

// MARK: - Patterns

extension FullFinancialContext {

    struct PatternsSection: Codable, Equatable {
        let weekdayPattern30Days: [WeekdayEntry]
        let needsBreakdownCurrentMonth: NeedsBreakdownEntry

        enum CodingKeys: String, CodingKey {
            case weekdayPattern30Days = "weekday_pattern_30_days"
            case needsBreakdownCurrentMonth = "needs_breakdown_current_month"
        }
    }

    /// Weekday pattern entry — incluye `sampleSize` (count de tx) Y `dayOccurrences`
    /// (cuántos `<weekday>` hay en el periodo) para que el LLM pueda razonar sobre
    /// representatividad. Resuelve bug #2 (caso "domingo S/3400" dominado por 1-2 tx).
    struct WeekdayEntry: Codable, Equatable {
        let weekday: String      // "Sunday" .. "Saturday"
        let total: Double
        let avgPerDay: Double    // total / dayOccurrences
        let sampleSize: Int      // count de tx (== `count` del calculator)
        let dayOccurrences: Int  // cuántas veces aparece este weekday en los 30d

        enum CodingKeys: String, CodingKey {
            case weekday, total
            case avgPerDay = "avg_per_day"
            case sampleSize = "sample_size"
            case dayOccurrences = "day_occurrences"
        }
    }

    struct NeedsBreakdownEntry: Codable, Equatable {
        let essential: Double
        let priority: Double
        let optional: Double
        let unclassified: Double
        let total: Double
    }
}

// MARK: - Tags

extension FullFinancialContext {

    struct TagEntry: Codable, Equatable {
        let name: String
        let totalCurrentMonth: Double
        let txCount: Int

        enum CodingKeys: String, CodingKey {
            case name
            case totalCurrentMonth = "total_current_month"
            case txCount = "tx_count"
        }
    }
}

// MARK: - Top transactions per subcategory

extension FullFinancialContext {

    struct SubcategoryTxEntry: Codable, Equatable {
        let subcategoryName: String
        let categoryName: String
        let transactions: [TxLite]

        enum CodingKeys: String, CodingKey {
            case subcategoryName = "subcategory_name"
            case categoryName = "category_name"
            case transactions
        }
    }

    struct TxLite: Codable, Equatable {
        let date: String      // ISO yyyy-MM-dd
        let amount: Double
        let merchant: String? // canonicalized
        let account: String?
    }
}
