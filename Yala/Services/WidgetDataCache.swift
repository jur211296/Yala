//
//  WidgetDataCache.swift
//  Yala
//
//  Service to cache data for widgets in shared App Group container.
//  This runs in the main app and pushes data to UserDefaults for widget access.
//

import Foundation
import SwiftData
import WidgetKit

// MARK: - Codable DTOs for Widget Data

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

// MARK: - WidgetDataCache

@MainActor
enum WidgetDataCache {

    private static let cacheKey = "widget_data_cache"

    /// Shared UserDefaults for App Group
    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: SharedContainerService.appGroupIdentifier)
    }

    // MARK: - Public API

    /// Updates the widget cache with current data from SwiftData
    /// Call this after any data change that should reflect in widgets
    static func updateCache(context: ModelContext) {
        let snapshot = buildSnapshot(context: context)
        saveSnapshot(snapshot)

        // Trigger widget refresh
        WidgetCenter.shared.reloadAllTimelines()

        #if DEBUG
        print("WidgetDataCache: Cache updated at \(Date())")
        #endif
    }

    /// Clears the widget cache
    static func clearCache() {
        sharedDefaults?.removeObject(forKey: cacheKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Private Helpers

    private static func buildSnapshot(context: ModelContext) -> WidgetDataSnapshot {
        // Fetch ALL transactions for correct balance calculation
        let allTransactionsDescriptor = FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        var allTransactions: [TransactionItem] = []
        do {
            allTransactions = try context.fetch(allTransactionsDescriptor)
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error fetching transactions: \(error)")
            #endif
        }

        // Filter to last 90 days for widget display (max 500)
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let recentTransactions = Array(allTransactions.filter { $0.date >= ninetyDaysAgo }.prefix(500))

        // Fetch active budgets
        let budgetDescriptor = FetchDescriptor<Budget>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.name)]
        )

        var budgets: [Budget] = []
        do {
            budgets = try context.fetch(budgetDescriptor)
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error fetching budgets: \(error)")
            #endif
        }

        // Fetch active scheduled payments
        let paymentDescriptor = FetchDescriptor<ScheduledPayment>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )

        var scheduledPayments: [ScheduledPayment] = []
        do {
            scheduledPayments = try context.fetch(paymentDescriptor)
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error fetching scheduled payments: \(error)")
            #endif
        }

        // Fetch all accounts to calculate total balance
        let accountDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate { !$0.isArchived }
        )

        var accounts: [Account] = []
        do {
            accounts = try context.fetch(accountDescriptor)
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error fetching accounts: \(error)")
            #endif
        }

        // Calculate total balance using ALL transactions (not just recent)
        let totalBalance = calculateTotalBalance(accounts: accounts, transactions: allTransactions)

        // Get preferred currency (from first account or default)
        let preferredCurrency = accounts.first?.currencyCode ?? "USD"

        // Build widget transactions (last 10 for display, from recent 90 days)
        let widgetTransactions = Array(recentTransactions.prefix(10)).map { tx in
            WidgetTransaction(
                id: tx.persistentModelID.hashValue.description,
                date: tx.date,
                amount: tx.amount,
                currencyCode: tx.currencyCode,
                note: tx.note,
                categoryName: tx.category?.name,
                categoryColor: tx.category?.colorHex,
                categoryIcon: tx.category?.iconName,
                subcategoryName: tx.subcategory?.name,
                isIncome: tx.category?.isIncome ?? false,
                amountInPreferredCurrency: tx.amountInPreferredCurrency
            )
        }

        // Build widget budgets with spent calculation (using recent transactions)
        let widgetBudgets = budgets.map { budget in
            let spent = calculateBudgetSpent(budget: budget, transactions: recentTransactions)
            let percentUsed = budget.limitAmount > 0 ? (spent / budget.limitAmount) * 100 : 0

            return WidgetBudget(
                id: budget.id.uuidString,
                name: budget.name,
                limitAmount: budget.limitAmount,
                spentAmount: spent,
                currencyCode: budget.currencyCode,
                periodType: budget.periodType,
                percentUsed: percentUsed
            )
        }

        // Build widget scheduled payments
        let today = Calendar.current.startOfDay(for: Date())
        let widgetPayments = scheduledPayments.map { payment in
            WidgetScheduledPayment(
                id: payment.id.uuidString,
                name: payment.name,
                amount: payment.amount,
                currencyCode: payment.currencyCode,
                nextDueDate: payment.nextDueDate,
                isOverdue: payment.nextDueDate < today,
                paymentCategory: payment.paymentCategory,
                isIncome: payment.transactionType == "income"
            )
        }

        // Build trend data with multiple granularities (uses ALL transactions)
        let trendData = buildTrendData(transactions: allTransactions, totalBalance: totalBalance)

        return WidgetDataSnapshot(
            totalBalance: totalBalance,
            preferredCurrencyCode: preferredCurrency,
            lastUpdated: Date(),
            transactions: widgetTransactions,
            budgets: widgetBudgets,
            scheduledPayments: widgetPayments,
            trendData: trendData
        )
    }

    private static func calculateTotalBalance(accounts: [Account], transactions: [TransactionItem]) -> Double {
        // Filter to only eligible accounts (not archived, not excluded from statistics)
        let eligibleAccountIDs = Set(
            accounts.filter { !$0.isArchived && !$0.excludeFromStatistics }
                .map { $0.persistentModelID }
        )

        // Sum all transactions in preferred currency
        // NOTE: amount already has the correct sign (positive = income, negative = expense)
        // This aligns with BalanceHelper.totalBalance() which is the source of truth
        var total: Double = 0
        for tx in transactions {
            guard let account = tx.account,
                  eligibleAccountIDs.contains(account.persistentModelID) else { continue }

            // amount is already signed correctly, just sum it
            total += tx.amountInPreferredCurrency != 0 ? tx.amountInPreferredCurrency : tx.amount
        }
        return total
    }

    private static func calculateBudgetSpent(budget: Budget, transactions: [TransactionItem]) -> Double {
        // Get period date range
        let calendar = Calendar.current
        let now = Date()

        var startDate: Date
        var endDate: Date = now

        switch budget.periodType {
        case "weekly":
            startDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        case "monthly":
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case "yearly":
            startDate = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        case "unique":
            startDate = budget.startDate ?? now
            endDate = budget.endDate ?? now
        default:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        }

        // Filter transactions in period
        let periodTransactions = transactions.filter { tx in
            tx.date >= startDate && tx.date <= endDate
        }

        // Sum expenses that match budget criteria
        var spent: Double = 0
        for tx in periodTransactions {
            // Skip income
            if tx.category?.isIncome == true { continue }

            // Check if transaction matches budget filters
            let matchesSubcategory = (budget.subcategories ?? []).isEmpty ||
                (budget.subcategories ?? []).contains(where: { $0.name == tx.subcategory?.name })
            let matchesAccount = (budget.accounts ?? []).isEmpty ||
                (budget.accounts ?? []).contains(where: { $0.name == tx.account?.name })

            if matchesSubcategory && matchesAccount {
                spent += tx.amountInPreferredCurrency != 0 ? tx.amountInPreferredCurrency : tx.amount
            }
        }

        return spent
    }

    private static func buildTrendData(transactions: [TransactionItem], totalBalance: Double) -> WidgetTrendData {
        let calendar = Calendar.current

        // Group transactions by day (amount already has correct sign)
        var transactionsByDay: [Date: Double] = [:]
        for tx in transactions {
            let day = calendar.startOfDay(for: tx.date)
            let amount = tx.amountInPreferredCurrency != 0 ? tx.amountInPreferredCurrency : tx.amount
            transactionsByDay[day, default: 0] += amount
        }

        // Build daily points (last 90 days)
        let dailyPoints = buildDailyTrend(
            transactionsByDay: transactionsByDay,
            totalBalance: totalBalance,
            days: 90,
            calendar: calendar
        )

        // Build weekly points (last 2 years = 104 weeks)
        let weeklyPoints = buildAggregatedTrend(
            transactionsByDay: transactionsByDay,
            totalBalance: totalBalance,
            periods: 104,
            component: .weekOfYear,
            calendar: calendar
        )

        // Build monthly points (last 10 years = 120 months max)
        let monthlyPoints = buildAggregatedTrend(
            transactionsByDay: transactionsByDay,
            totalBalance: totalBalance,
            periods: 120,
            component: .month,
            calendar: calendar
        )

        return WidgetTrendData(
            dailyPoints: dailyPoints,
            weeklyPoints: weeklyPoints,
            monthlyPoints: monthlyPoints
        )
    }

    /// Build daily trend points going backwards from current balance
    private static func buildDailyTrend(
        transactionsByDay: [Date: Double],
        totalBalance: Double,
        days: Int,
        calendar: Calendar
    ) -> [WidgetTrendPoint] {
        var trendPoints: [WidgetTrendPoint] = []
        var runningBalance = totalBalance

        for daysAgo in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }
            let day = calendar.startOfDay(for: date)

            trendPoints.append(WidgetTrendPoint(date: day, balance: runningBalance))

            if let dayChange = transactionsByDay[day] {
                runningBalance -= dayChange
            }
        }

        return trendPoints.reversed()
    }

    /// Build aggregated trend points (weekly or monthly) going backwards
    private static func buildAggregatedTrend(
        transactionsByDay: [Date: Double],
        totalBalance: Double,
        periods: Int,
        component: Calendar.Component,
        calendar: Calendar
    ) -> [WidgetTrendPoint] {
        var trendPoints: [WidgetTrendPoint] = []
        var runningBalance = totalBalance
        let today = Date()

        // Get the start of current period
        var currentPeriodStart: Date
        if component == .weekOfYear {
            currentPeriodStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        } else {
            currentPeriodStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        }

        for periodIndex in 0..<periods {
            guard let periodStart = calendar.date(byAdding: component, value: -periodIndex, to: currentPeriodStart) else { continue }

            // Calculate period end
            let periodEnd: Date
            if let nextPeriod = calendar.date(byAdding: component, value: 1, to: periodStart) {
                periodEnd = nextPeriod
            } else {
                continue
            }

            // For the first period, use current balance
            // For subsequent periods, subtract all transactions in the period
            trendPoints.append(WidgetTrendPoint(date: periodStart, balance: runningBalance))

            // Sum all transactions in this period
            var periodChange: Double = 0
            for (day, amount) in transactionsByDay {
                if day >= periodStart && day < periodEnd {
                    periodChange += amount
                }
            }
            runningBalance -= periodChange
        }

        return trendPoints.reversed()
    }

    private static func saveSnapshot(_ snapshot: WidgetDataSnapshot) {
        guard let defaults = sharedDefaults else {
            #if DEBUG
            print("WidgetDataCache: Failed to access shared UserDefaults")
            #endif
            return
        }

        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: cacheKey)
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error encoding snapshot: \(error)")
            #endif
        }
    }
}
