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
        // Fetch recent transactions (last 30 days, max 50)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let transactionDescriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.date >= thirtyDaysAgo },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        var transactions: [TransactionItem] = []
        do {
            transactions = try context.fetch(transactionDescriptor)
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error fetching transactions: \(error)")
            #endif
        }

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

        // Calculate total balance
        let totalBalance = calculateTotalBalance(accounts: accounts, transactions: transactions)

        // Get preferred currency (from first account or default)
        let preferredCurrency = accounts.first?.currencyCode ?? "USD"

        // Build widget transactions (last 10 for display)
        let widgetTransactions = Array(transactions.prefix(10)).map { tx in
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

        // Build widget budgets with spent calculation
        let widgetBudgets = budgets.map { budget in
            let spent = calculateBudgetSpent(budget: budget, transactions: transactions)
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

        // Build trend data (daily balance for last 30 days)
        let trendData = buildTrendData(transactions: transactions, totalBalance: totalBalance)

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
        // Sum all transactions in preferred currency
        var total: Double = 0
        for tx in transactions {
            let amount = tx.amountInPreferredCurrency != 0 ? tx.amountInPreferredCurrency : tx.amount
            if tx.category?.isIncome == true {
                total += amount
            } else {
                total -= amount
            }
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

    private static func buildTrendData(transactions: [TransactionItem], totalBalance: Double) -> [WidgetTrendPoint] {
        let calendar = Calendar.current
        var trendPoints: [WidgetTrendPoint] = []
        var runningBalance = totalBalance

        // Group transactions by day
        var transactionsByDay: [Date: Double] = [:]
        for tx in transactions {
            let day = calendar.startOfDay(for: tx.date)
            let amount = tx.amountInPreferredCurrency != 0 ? tx.amountInPreferredCurrency : tx.amount
            let signedAmount = (tx.category?.isIncome == true) ? amount : -amount
            transactionsByDay[day, default: 0] += signedAmount
        }

        // Build trend for last 30 days (going backwards)
        for daysAgo in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }
            let day = calendar.startOfDay(for: date)

            trendPoints.append(WidgetTrendPoint(date: day, balance: runningBalance))

            // Subtract today's transactions to get yesterday's balance
            if let dayChange = transactionsByDay[day] {
                runningBalance -= dayChange
            }
        }

        return trendPoints.reversed()  // Return chronological order
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
