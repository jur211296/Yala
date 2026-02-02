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

/// Complete widget data snapshot
struct WidgetDataSnapshot: Codable {
    let totalBalance: Double
    let preferredCurrencyCode: String
    let lastUpdated: Date
    let transactions: [WidgetTransaction]
    let budgets: [WidgetBudget]
    let scheduledPayments: [WidgetScheduledPayment]
    let trendData: [WidgetTrendPoint]
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

    /// Returns trend data for chart
    static func getTrendData() -> [WidgetTrendPoint] {
        loadSnapshot()?.trendData ?? []
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
