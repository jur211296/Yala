//
//  WidgetDataService.swift
//  YalaWidgets
//
//  Service to read cached data from the main app via shared App Group.
//  This runs in the widget extension and reads from UserDefaults.
//

import Foundation

// MARK: - Codable DTOs (must match WidgetDataCache.swift)

/// Lightweight transaction data for widgets
struct WidgetTransaction: Codable {
    let id: String
    let date: Date
    let amount: Double
    let currencyCode: String
    let note: String?
    let categoryName: String?
    let categoryColor: String?
    let categoryIcon: String?
    let subcategoryIcon: String?
    let subcategoryName: String?
    let isIncome: Bool
    let amountInPreferredCurrency: Double
}

/// Lightweight budget data for widgets
struct WidgetBudget: Codable {
    let id: String
    let name: String
    let limitAmount: Double
    let spentAmount: Double
    let currencyCode: String
    let periodType: String
    let percentUsed: Double
    let iconName: String?   // Optional for backwards compatibility - fallback: "chart.pie.fill"
    let colorHex: String?   // Optional for backwards compatibility - fallback: "#6366F1"
}

/// Lightweight scheduled payment data for widgets
struct WidgetScheduledPayment: Codable {
    let id: String
    let name: String
    let amount: Double
    let currencyCode: String
    let nextDueDate: Date
    let isOverdue: Bool
    let paymentCategory: String  // "recurring" or "subscription"
    let isIncome: Bool
    let iconName: String?   // Optional for backwards compatibility - fallback based on paymentCategory
    let colorHex: String?   // Optional for backwards compatibility - fallback: "#6366F1"
    var isVariableAmount: Bool?  // Optional for backwards compatibility - fallback: false
}

/// Balance trend data point for widgets
struct WidgetTrendPoint: Codable {
    let date: Date
    let balance: Double
}

/// Multi-granularity trend data for different periods
struct WidgetTrendData: Codable {
    /// Daily points for short periods (last 90 days)
    let dailyPoints: [WidgetTrendPoint]
    /// Weekly points for medium periods (last 2 years, ~104 points max)
    let weeklyPoints: [WidgetTrendPoint]
    /// Monthly points for long periods (all time, ~120 points max for 10 years)
    let monthlyPoints: [WidgetTrendPoint]
}

/// Account balance for widget calculations
struct WidgetAccountBalance: Codable {
    let id: String
    let name: String
    let balance: Double
    let currencyCode: String
    let isExcludedFromStats: Bool
}

/// Category with aggregated data for widgets
struct WidgetCategory: Codable {
    let id: String
    let name: String
    let iconName: String
    let colorHex: String
    let amount: Double
    let percentage: Double
}

/// Subcategory with aggregated data for widgets
struct WidgetSubcategory: Codable {
    let id: String
    let name: String
    let categoryName: String
    let iconName: String?
    let colorHex: String
    let amount: Double
    let percentage: Double
}

/// Cash flow point for bidirectional charts
struct WidgetCashFlowPoint: Codable {
    let date: Date
    let income: Double
    let expense: Double
    let net: Double
}

/// Precalculated summary for a period
struct WidgetPeriodSummary: Codable {
    let totalIncome: Double
    let totalExpense: Double
    let netCashFlow: Double
    let topCategories: [WidgetCategory]
    let topSubcategories: [WidgetSubcategory]
    let cashFlowPoints: [WidgetCashFlowPoint]
    /// Historical balance at the END of the period (sum of all transactions up to period end)
    /// Optional for backwards compatibility with old cache format
    let periodBalance: Double?
}

/// Complete widget data snapshot
struct WidgetDataSnapshot: Codable {
    // Metadata
    let lastUpdated: Date
    let preferredCurrencyCode: String
    let currencyDisplayFormat: String  // "symbol" or "code"

    // Account data for real balance calculation
    let accountBalances: [WidgetAccountBalance]
    let totalBalance: Double

    // Raw transactions for dynamic calculations (last 90 days, max 500)
    let transactions: [WidgetTransaction]

    // Budgets and payments (not filtered by period)
    let budgets: [WidgetBudget]
    let scheduledPayments: [WidgetScheduledPayment]

    // Trend data with multiple granularities
    let trendData: WidgetTrendData

    // Precalculated for "This Month" (most common period)
    let thisMonthSummary: WidgetPeriodSummary

    // Precalculated for "All Time" using ALL transactions (not just 90 days)
    // Optional for backwards compatibility with old cache format
    let allTimeSummary: WidgetPeriodSummary?

    // Precalculated summaries for all periods (keyed by WidgetPeriod.rawValue)
    // Optional for backwards compatibility
    let periodSummaries: [String: WidgetPeriodSummary]?

    /// SELLO de identidad de la sesión que lo escribió (`WidgetSessionSeal`). Opcional por la MISMA razón
    /// que los dos de arriba y por una más: todo snapshot ya escrito en los teléfonos lo trae ausente, y
    /// `nil` significa «sesión del dueño», que es exactamente de quien era. Lo compara `loadSnapshot()`.
    let sessionSeal: String?
}

// MARK: - WidgetDataService

enum WidgetDataService {

    private static let cacheKey = "widget_data_cache"

    /// App Group identifier read from Info.plist
    private static var appGroupIdentifier: String {
        Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String
            ?? "group.com.jurgenschmidt.yala"
    }

    /// Shared UserDefaults for App Group
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    // MARK: - Calendar Helper

    /// Returns calendar configured with user's firstWeekday preference from App Group
    static func widgetConfiguredCalendar() -> Calendar {
        var calendar = Calendar.current
        if let defaults = sharedDefaults {
            let firstWeekday = defaults.integer(forKey: "firstWeekday")
            calendar.firstWeekday = firstWeekday > 0 ? firstWeekday : 2  // Default: Monday
        }
        return calendar
    }

    /// Returns the user's default period from the main app
    /// Falls back to .thisMonth if not set or invalid
    static func getAppDefaultPeriod() -> WidgetPeriod {
        guard let defaults = sharedDefaults,
              let rawValue = defaults.string(forKey: "defaultPeriod"),
              let period = WidgetPeriod(rawValue: rawValue) else {
            return .thisMonth
        }
        return period
    }

    // MARK: - Expenses Only Mode

    /// Whether the app is in expenses-only mode (synced via App Group UserDefaults)
    static var isExpensesOnlyMode: Bool {
        sharedDefaults?.bool(forKey: "expensesOnlyMode") ?? false
    }

    // MARK: - Public API

    /// Loads the cached widget data snapshot
    /// Returns nil if no data is available or data is corrupted
    ///
    /// EL SELLO. Un snapshot cuya identidad no case con la sesión viva se trata como AUSENTE: es lo que
    /// impide que los saldos de una sesión de visita (M1) sigan pintándose en la pantalla de inicio del
    /// dueño después de que ella cierre sesión. La garantía no depende de que ninguna limpieza llegue a
    /// correr — la key activa la retira `SecondarySessionStore.clear` en la frontera, así que un snapshot
    /// suyo que sobreviva en disco deja de servirse igual. Ver `WidgetSessionSeal`.
    static func loadSnapshot() -> WidgetDataSnapshot? {
        guard let defaults = sharedDefaults else {
            #if DEBUG
            print("WidgetDataService: Failed to access shared UserDefaults")
            #endif
            return nil
        }

        guard let data = defaults.data(forKey: cacheKey) else {
            #if DEBUG
            print("WidgetDataService: No cached data found")
            #endif
            return nil
        }

        do {
            let snapshot = try JSONDecoder().decode(WidgetDataSnapshot.self, from: data)
            guard WidgetSessionSeal.isFresh(
                snapshotSeal: snapshot.sessionSeal,
                activeSeal: WidgetSessionSeal.activeSeal(in: defaults)
            ) else {
                #if DEBUG
                print("WidgetDataService: snapshot de otra sesión — se descarta")
                #endif
                return nil
            }
            return snapshot
        } catch {
            #if DEBUG
            print("WidgetDataService: Error decoding snapshot: \(error)")
            #endif
            return nil
        }
    }

    /// Returns the total balance, or 0 if no data
    static func getTotalBalance() -> Double {
        loadSnapshot()?.totalBalance ?? 0
    }

    /// Returns the historical balance for a specific period
    /// For current periods (thisMonth, thisWeek, etc.): returns current total balance
    /// For past periods (lastMonth, lastYear, etc.): returns balance as it was at the end of that period
    static func getBalance(for period: WidgetPeriod) -> Double {
        guard let snapshot = loadSnapshot() else { return 0 }

        // Try to get precalculated periodBalance from summary
        if let summaries = snapshot.periodSummaries,
           let summary = summaries[period.rawValue],
           let periodBalance = summary.periodBalance {
            return periodBalance
        }

        // Fallback to current total balance for current periods
        // (old cache format or current periods)
        return snapshot.totalBalance
    }

    /// Returns the preferred currency code, or "USD" if no data
    static func getPreferredCurrency() -> String {
        loadSnapshot()?.preferredCurrencyCode ?? "USD"
    }

    /// Returns recent transactions (up to limit)
    static func getRecentTransactions(limit: Int = 5) -> [WidgetTransaction] {
        guard let snapshot = loadSnapshot() else { return [] }
        var transactions = snapshot.transactions
        if isExpensesOnlyMode {
            transactions = transactions.filter { !$0.isIncome }
        }
        return Array(transactions.prefix(limit))
    }

    /// Returns active budgets sorted by percent used (most critical first)
    static func getBudgets(sortByCritical: Bool = true) -> [WidgetBudget] {
        guard let snapshot = loadSnapshot() else { return [] }

        if sortByCritical {
            return snapshot.budgets.sorted { $0.percentUsed > $1.percentUsed }
        }
        return snapshot.budgets
    }

    /// Returns upcoming scheduled payments
    static func getScheduledPayments(
        filter: ScheduledPaymentFilter = .all,
        limit: Int = 5
    ) -> [WidgetScheduledPayment] {
        guard let snapshot = loadSnapshot() else { return [] }

        var payments = snapshot.scheduledPayments

        // Filter income payments in expenses-only mode
        if isExpensesOnlyMode {
            payments = payments.filter { !$0.isIncome }
        }

        // Apply filter
        switch filter {
        case .recurring:
            payments = payments.filter { $0.paymentCategory == "recurring" }
        case .subscription:
            payments = payments.filter { $0.paymentCategory == "subscription" }
        case .all:
            break
        }

        // Sort by due date (overdue first, then closest)
        payments.sort { payment1, payment2 in
            if payment1.isOverdue != payment2.isOverdue {
                return payment1.isOverdue  // Overdue first
            }
            return payment1.nextDueDate < payment2.nextDueDate
        }

        return Array(payments.prefix(limit))
    }

    /// Returns trend data for chart (full structure with all granularities)
    static func getTrendData() -> WidgetTrendData? {
        loadSnapshot()?.trendData
    }

    /// Returns trend data appropriate for the given period
    /// - Parameter period: The period to get trend data for
    /// - Returns: Array of trend points at appropriate granularity
    static func getTrendData(for period: WidgetPeriod) -> [WidgetTrendPoint] {
        guard let trendData = getTrendData() else { return [] }

        switch period {
        case .thisWeek, .last7Days, .last30Days, .thisMonth, .lastMonth:
            // Short/medium periods: use daily points
            return filterPoints(trendData.dailyPoints, for: period)

        case .thisYear, .lastYear:
            // Long periods: use weekly points
            return filterPoints(trendData.weeklyPoints, for: period)

        case .allTime:
            // All time: use monthly points
            return trendData.monthlyPoints
        }
    }

    /// Filter points to match the requested period
    private static func filterPoints(_ points: [WidgetTrendPoint], for period: WidgetPeriod) -> [WidgetTrendPoint] {
        let interval = period.dateInterval()
        return points.filter { interval.contains($0.date) }
    }

    /// Returns the last update timestamp
    static func getLastUpdated() -> Date? {
        loadSnapshot()?.lastUpdated
    }

    /// Checks if data is stale (older than specified hours)
    static func isDataStale(olderThanHours hours: Int = 24) -> Bool {
        guard let lastUpdated = getLastUpdated() else { return true }
        let staleThreshold = Calendar.current.date(byAdding: .hour, value: -hours, to: Date()) ?? Date()
        return lastUpdated < staleThreshold
    }

    /// Returns the currency display format preference ("symbol" or "code")
    static func getCurrencyDisplayFormat() -> String {
        loadSnapshot()?.currencyDisplayFormat ?? "symbol"
    }

    /// Returns account balances
    static func getAccountBalances() -> [WidgetAccountBalance] {
        loadSnapshot()?.accountBalances ?? []
    }

    /// Returns the thisMonth summary (precalculated)
    static func getThisMonthSummary() -> WidgetPeriodSummary? {
        loadSnapshot()?.thisMonthSummary
    }

    /// Returns precalculated summary for a specific period
    /// All summaries are precalculated in WidgetDataCache to ensure accuracy
    static func calculateSummary(for period: WidgetPeriod) -> WidgetPeriodSummary? {
        guard let snapshot = loadSnapshot() else { return nil }

        // First try the new periodSummaries dictionary (preferred)
        if let summaries = snapshot.periodSummaries,
           let summary = summaries[period.rawValue] {
            return summary
        }

        // Fallback to legacy fields for backwards compatibility
        if period == .thisMonth {
            return snapshot.thisMonthSummary
        }

        if period == .allTime, let allTimeSummary = snapshot.allTimeSummary {
            return allTimeSummary
        }

        // Last resort: calculate from raw transactions (only works for recent periods within 90 days)
        let interval = period.dateInterval()
        let filtered = snapshot.transactions.filter { interval.contains($0.date) }

        return buildPeriodSummary(from: filtered)
    }

    /// Builds a period summary from filtered transactions
    private static func buildPeriodSummary(from transactions: [WidgetTransaction]) -> WidgetPeriodSummary {
        var totalIncome: Double = 0
        var totalExpense: Double = 0

        for tx in transactions {
            let amount = abs(tx.amountInPreferredCurrency)
            if tx.isIncome {
                totalIncome += amount
            } else {
                totalExpense += amount
            }
        }

        let netCashFlow = totalIncome - totalExpense

        // Build top categories
        let topCategories = buildTopCategories(from: transactions, totalExpense: totalExpense)

        // Build top subcategories
        let topSubcategories = buildTopSubcategories(from: transactions, totalExpense: totalExpense)

        // Build cash flow by day
        let cashFlowPoints = buildCashFlowByDay(from: transactions)

        return WidgetPeriodSummary(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            netCashFlow: netCashFlow,
            topCategories: topCategories,
            topSubcategories: topSubcategories,
            cashFlowPoints: cashFlowPoints,
            periodBalance: nil  // Fallback calculation doesn't have access to all transactions
        )
    }

    private static func buildTopCategories(
        from transactions: [WidgetTransaction],
        totalExpense: Double,
        limit: Int = 20
    ) -> [WidgetCategory] {
        // Group expenses by category
        var categoryTotals: [String: (name: String, icon: String, color: String, amount: Double)] = [:]

        for tx in transactions where !tx.isIncome {
            guard let categoryName = tx.categoryName else { continue }
            let amount = abs(tx.amountInPreferredCurrency)

            if var existing = categoryTotals[categoryName] {
                existing.amount += amount
                categoryTotals[categoryName] = existing
            } else {
                categoryTotals[categoryName] = (
                    name: categoryName,
                    icon: tx.categoryIcon ?? "folder",
                    color: tx.categoryColor ?? "#808080",
                    amount: amount
                )
            }
        }

        // Sort by amount and take top N
        let sorted = categoryTotals.values.sorted { $0.amount > $1.amount }
        let topN = Array(sorted.prefix(limit))

        return topN.enumerated().map { index, item in
            let percentage = totalExpense > 0 ? (item.amount / totalExpense) * 100 : 0
            return WidgetCategory(
                id: "\(index)",
                name: item.name,
                iconName: item.icon,
                colorHex: item.color,
                amount: item.amount,
                percentage: percentage
            )
        }
    }

    private static func buildTopSubcategories(
        from transactions: [WidgetTransaction],
        totalExpense: Double,
        limit: Int = 20
    ) -> [WidgetSubcategory] {
        // Group expenses by subcategory
        var subcategoryTotals: [String: (name: String, categoryName: String, icon: String?, color: String, amount: Double)] = [:]

        for tx in transactions where !tx.isIncome {
            guard let subcategoryName = tx.subcategoryName,
                  let categoryName = tx.categoryName else { continue }
            let amount = abs(tx.amountInPreferredCurrency)
            let key = "\(categoryName)_\(subcategoryName)"

            if var existing = subcategoryTotals[key] {
                existing.amount += amount
                subcategoryTotals[key] = existing
            } else {
                subcategoryTotals[key] = (
                    name: subcategoryName,
                    categoryName: categoryName,
                    icon: tx.categoryIcon,  // Use category icon as fallback
                    color: tx.categoryColor ?? "#808080",
                    amount: amount
                )
            }
        }

        // Sort by amount and take top N
        let sorted = subcategoryTotals.values.sorted { $0.amount > $1.amount }
        let topN = Array(sorted.prefix(limit))

        return topN.enumerated().map { index, item in
            let percentage = totalExpense > 0 ? (item.amount / totalExpense) * 100 : 0
            return WidgetSubcategory(
                id: "\(index)",
                name: item.name,
                categoryName: item.categoryName,
                iconName: item.icon,
                colorHex: item.color,
                amount: item.amount,
                percentage: percentage
            )
        }
    }

    private static func buildCashFlowByDay(from transactions: [WidgetTransaction]) -> [WidgetCashFlowPoint] {
        let calendar = Calendar.current

        // Group transactions by day
        var dailyData: [Date: (income: Double, expense: Double)] = [:]

        for tx in transactions {
            let day = calendar.startOfDay(for: tx.date)
            let amount = abs(tx.amountInPreferredCurrency)

            var existing = dailyData[day] ?? (income: 0, expense: 0)
            if tx.isIncome {
                existing.income += amount
            } else {
                existing.expense += amount
            }
            dailyData[day] = existing
        }

        // Sort by date and return
        return dailyData
            .map { day, data in
                WidgetCashFlowPoint(
                    date: day,
                    income: data.income,
                    expense: data.expense,
                    net: data.income - data.expense
                )
            }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - Filter Types

enum ScheduledPaymentFilter: String, CaseIterable {
    case all = "all"
    case recurring = "recurring"
    case subscription = "subscription"

    var displayName: String {
        switch self {
        case .all: return String(localized: "widget.paymentCategory.all", bundle: .main)
        case .recurring: return String(localized: "widget.paymentCategory.recurring", bundle: .main)
        case .subscription: return String(localized: "widget.paymentCategory.subscription", bundle: .main)
        }
    }
}

// MARK: - Trend Period

/// Period options for widget trend data
/// Aligned with DetailPeriod from main app (8 cases, excluding custom)
enum WidgetPeriod: String, CaseIterable, Codable {
    case thisWeek
    case last7Days
    case last30Days
    case thisMonth
    case lastMonth
    case thisYear
    case lastYear
    case allTime

    var displayName: String {
        localizedDisplayName
    }

    var localizedDisplayName: String {
        switch self {
        case .thisWeek: return String(localized: "widget.period.thisWeek", bundle: .main)
        case .last7Days: return String(localized: "widget.period.last7Days", bundle: .main)
        case .last30Days: return String(localized: "widget.period.last30Days", bundle: .main)
        case .thisMonth: return String(localized: "widget.period.thisMonth", bundle: .main)
        case .lastMonth: return String(localized: "widget.period.lastMonth", bundle: .main)
        case .thisYear: return String(localized: "widget.period.thisYear", bundle: .main)
        case .lastYear: return String(localized: "widget.period.lastYear", bundle: .main)
        case .allTime: return String(localized: "widget.period.allTime", bundle: .main)
        }
    }

    /// Returns the date interval for this period
    /// Matches DetailPeriod.dateInterval() exactly for consistency with main app
    func dateInterval() -> DateInterval {
        let calendar = WidgetDataService.widgetConfiguredCalendar()
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now

        switch self {
        case .thisWeek:
            let startOfWeek = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? startOfToday
            return DateInterval(start: startOfWeek, end: endOfToday)

        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: endOfToday)

        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday
            return DateInterval(start: start, end: endOfToday)

        case .thisMonth:
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)) ?? startOfToday
            return DateInterval(start: startOfMonth, end: endOfToday)

        case .lastMonth:
            let startOfThisMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)) ?? startOfToday
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? startOfToday
            let endOfLastMonth = calendar.date(byAdding: .second, value: -1, to: startOfThisMonth) ?? startOfThisMonth
            return DateInterval(start: startOfLastMonth, end: endOfLastMonth)

        case .thisYear:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? startOfToday
            return DateInterval(start: startOfYear, end: endOfToday)

        case .lastYear:
            let startOfThisYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? startOfToday
            let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear) ?? startOfToday
            let endOfLastYear = calendar.date(byAdding: .second, value: -1, to: startOfThisYear) ?? startOfThisYear
            return DateInterval(start: startOfLastYear, end: endOfLastYear)

        case .allTime:
            let start = calendar.date(byAdding: .year, value: -10, to: now) ?? startOfToday
            return DateInterval(start: start, end: endOfToday)
        }
    }
}
