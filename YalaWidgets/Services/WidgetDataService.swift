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

/// Complete widget data snapshot
struct WidgetDataSnapshot: Codable {
    let totalBalance: Double
    let preferredCurrencyCode: String
    let lastUpdated: Date
    let transactions: [WidgetTransaction]
    let budgets: [WidgetBudget]
    let scheduledPayments: [WidgetScheduledPayment]
    let trendData: WidgetTrendData
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

    // MARK: - Public API

    /// Loads the cached widget data snapshot
    /// Returns nil if no data is available or data is corrupted
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

    /// Returns the preferred currency code, or "USD" if no data
    static func getPreferredCurrency() -> String {
        loadSnapshot()?.preferredCurrencyCode ?? "USD"
    }

    /// Returns recent transactions (up to limit)
    static func getRecentTransactions(limit: Int = 5) -> [WidgetTransaction] {
        guard let snapshot = loadSnapshot() else { return [] }
        return Array(snapshot.transactions.prefix(limit))
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
        case .today, .yesterday, .thisWeek, .lastWeek, .thisMonth, .lastMonth:
            // Short/medium periods: use daily points
            return filterPoints(trendData.dailyPoints, for: period)

        case .thisQuarter, .lastQuarter, .thisYear, .lastYear:
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
}

// MARK: - Filter Types

enum ScheduledPaymentFilter: String, CaseIterable {
    case all = "all"
    case recurring = "recurring"
    case subscription = "subscription"

    var displayName: String {
        switch self {
        case .all: return "Todos"
        case .recurring: return "Planificados"
        case .subscription: return "Suscripciones"
        }
    }
}

// MARK: - Trend Period

/// Period options for widget trend data
enum WidgetPeriod: String, CaseIterable, Codable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
    case thisQuarter
    case lastQuarter
    case thisYear
    case lastYear
    case allTime

    var displayName: String {
        switch self {
        case .today: return "Hoy"
        case .yesterday: return "Ayer"
        case .thisWeek: return "Esta semana"
        case .lastWeek: return "Semana pasada"
        case .thisMonth: return "Este mes"
        case .lastMonth: return "Mes pasado"
        case .thisQuarter: return "Este trimestre"
        case .lastQuarter: return "Trimestre pasado"
        case .thisYear: return "Este año"
        case .lastYear: return "Año pasado"
        case .allTime: return "Todo el tiempo"
        }
    }

    /// Returns the date interval for this period
    func dateInterval() -> DateInterval {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            return DateInterval(start: start, end: now)

        case .yesterday:
            let todayStart = calendar.startOfDay(for: now)
            let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            return DateInterval(start: yesterdayStart, end: todayStart)

        case .thisWeek:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            return DateInterval(start: start, end: now)

        case .lastWeek:
            let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? now
            return DateInterval(start: lastWeekStart, end: thisWeekStart)

        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return DateInterval(start: start, end: now)

        case .lastMonth:
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
            return DateInterval(start: lastMonthStart, end: thisMonthStart)

        case .thisQuarter:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStartMonth
            components.day = 1
            let start = calendar.date(from: components) ?? now
            return DateInterval(start: start, end: now)

        case .lastQuarter:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStartMonth
            components.day = 1
            let thisQuarterStart = calendar.date(from: components) ?? now
            let lastQuarterStart = calendar.date(byAdding: .month, value: -3, to: thisQuarterStart) ?? now
            return DateInterval(start: lastQuarterStart, end: thisQuarterStart)

        case .thisYear:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            return DateInterval(start: start, end: now)

        case .lastYear:
            let thisYearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            let lastYearStart = calendar.date(byAdding: .year, value: -1, to: thisYearStart) ?? now
            return DateInterval(start: lastYearStart, end: thisYearStart)

        case .allTime:
            // Return a very large interval (from year 2000 to now)
            let start = calendar.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? now
            return DateInterval(start: start, end: now)
        }
    }
}
