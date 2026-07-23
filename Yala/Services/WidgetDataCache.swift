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
    let iconName: String
    let colorHex: String
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
    let iconName: String
    let colorHex: String
    let isVariableAmount: Bool

    init(id: String, name: String, amount: Double, currencyCode: String, nextDueDate: Date, isOverdue: Bool, paymentCategory: String, isIncome: Bool, iconName: String, colorHex: String, isVariableAmount: Bool = false) {
        self.id = id; self.name = name; self.amount = amount; self.currencyCode = currencyCode
        self.nextDueDate = nextDueDate; self.isOverdue = isOverdue; self.paymentCategory = paymentCategory
        self.isIncome = isIncome; self.iconName = iconName; self.colorHex = colorHex
        self.isVariableAmount = isVariableAmount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decode(Double.self, forKey: .amount)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        nextDueDate = try container.decode(Date.self, forKey: .nextDueDate)
        isOverdue = try container.decode(Bool.self, forKey: .isOverdue)
        paymentCategory = try container.decode(String.self, forKey: .paymentCategory)
        isIncome = try container.decode(Bool.self, forKey: .isIncome)
        iconName = try container.decode(String.self, forKey: .iconName)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        isVariableAmount = try container.decodeIfPresent(Bool.self, forKey: .isVariableAmount) ?? false
    }
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
    /// For current periods: current total balance
    /// For past periods: balance as it was at the end of that period
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
    let allTimeSummary: WidgetPeriodSummary

    // Precalculated summaries for all periods (keyed by period rawValue)
    let periodSummaries: [String: WidgetPeriodSummary]
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
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
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
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date.now) ?? Date.now
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

        // Fetch ALL accounts (including archived) — archived still count for total balance
        let accountDescriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.name)]
        )

        var accounts: [Account] = []
        do {
            accounts = try context.fetch(accountDescriptor)
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error fetching accounts: \(error)")
            #endif
        }

        // Pre-filter: exclude transactions from accounts excluded from statistics
        let excludedAccountIDs = Set(
            accounts.filter { $0.excludeFromStatistics }.map { $0.persistentModelID }
        )
        let isEligible: (TransactionItem) -> Bool = { tx in
            guard let account = tx.account else { return true }
            return !excludedAccountIDs.contains(account.persistentModelID)
        }
        let eligibleTransactions = allTransactions.filter(isEligible)
        let eligibleRecentTransactions = recentTransactions.filter(isEligible)

        // Netea los gastos de grupo bridgeados a "mi parte" en las superficies de stats.
        // Se construye del set MÁS AMPLIO (`allTransactions`, antes del filtro de elegibilidad)
        // para garantizar AMBAS hermanas del bridge; el consumo usa el subset elegible.
        let adjustment = GroupBridgeStatsAdjustment.build(from: allTransactions, context: context)

        // Get preferred currency from user settings (single source of truth)
        let preferredCurrency = UserDefaults.standard.string(forKey: CurrencyDefaults.preferredCurrencyKey) ?? "USD"

        // Total balance: TC actual sobre saldo nativo (LiveBalanceCalculator).
        // El widget consume este Double ya convertido — el calculator NO se
        // expone al target widget extension.
        let totalBalance = LiveBalanceCalculator.liveBalance(
            accounts: accounts,
            transactions: eligibleTransactions,
            preferredCurrencyCode: preferredCurrency
        )

        // Build widget transactions (last 10 for display, from recent 90 days, excluyendo cuentas excluidas de stats)
        let widgetTransactions = Array(eligibleRecentTransactions.prefix(10)).map { tx in
            WidgetTransaction(
                id: tx.persistentModelID.hashValue.description,
                date: tx.date,
                amount: tx.amount,
                currencyCode: tx.currencyCode,
                note: tx.note,
                categoryName: tx.category?.name,
                categoryColor: tx.category?.colorHex,
                categoryIcon: tx.category?.iconName,
                subcategoryIcon: tx.subcategory?.iconName ?? tx.category?.iconName,
                subcategoryName: tx.subcategory?.name,
                isIncome: isIncomeTx(tx),
                amountInPreferredCurrency: tx.amountInPreferredCurrency
            )
        }

        // Build widget budgets with spent calculation
        // For yearly/unique budgets, use allTransactions (90-day window is insufficient)
        let widgetBudgets = budgets.map { budget in
            let transactionsForBudget: [TransactionItem]
            let periodType = BudgetPeriodType(rawValue: budget.periodType)
            if periodType == .yearly || periodType == .unique {
                transactionsForBudget = allTransactions
            } else {
                transactionsForBudget = recentTransactions
            }
            let spent = calculateBudgetSpent(budget: budget, transactions: transactionsForBudget, adjustment: adjustment)
            let percentUsed = budget.limitAmount > 0 ? (spent / budget.limitAmount) * 100 : 0
            // CSV mirror SSOT con fallback M2M para legacy budgets pre-deploy.
            let (icon, color) = Budget.computeDisplayProperties(for: budget, in: context)

            return WidgetBudget(
                id: budget.id.uuidString,
                name: budget.name,
                limitAmount: budget.limitAmount,
                spentAmount: spent,
                currencyCode: budget.currencyCode,
                periodType: budget.periodType,
                percentUsed: percentUsed,
                iconName: icon,
                colorHex: color
            )
        }

        // Build widget scheduled payments
        let today = Calendar.current.startOfDay(for: Date.now)
        let widgetPayments = scheduledPayments.map { payment in
            let (icon, color) = getPaymentDisplayProperties(payment: payment)

            return WidgetScheduledPayment(
                id: payment.id.uuidString,
                name: payment.name,
                amount: payment.amount,
                currencyCode: payment.currencyCode,
                nextDueDate: payment.nextDueDate,
                isOverdue: payment.nextDueDate < today,
                paymentCategory: payment.paymentCategory,
                isIncome: payment.transactionType == "income",
                iconName: icon,
                colorHex: color,
                isVariableAmount: payment.isVariableAmount
            )
        }

        // Build trend data with multiple granularities (uses eligible transactions)
        let trendData = buildTrendData(transactions: eligibleTransactions, totalBalance: totalBalance)

        // Build account balances for widgets (only visible accounts shown as cards).
        // Cada card muestra el saldo en moneda NATIVA de la cuenta. Una sola
        // pasada O(N+M) sobre transactions vía batchCalculateBalances.
        let visibleAccounts = filterVisibleAccountsForWidget(accounts)
        let nativeBalancesByAccount = AccountBalanceCalculator.batchCalculateBalances(
            accounts: visibleAccounts, transactions: allTransactions
        )
        let widgetAccountBalances = visibleAccounts.map { account in
            let nativeBalance = nativeBalancesByAccount[account.persistentModelID] ?? 0
            return WidgetAccountBalance(
                id: account.persistentModelID.hashValue.description,
                name: account.name,
                balance: NSDecimalNumber(decimal: nativeBalance).doubleValue,
                currencyCode: account.currencyCode,
                isExcludedFromStats: account.excludeFromStatistics
            )
        }

        // Get currency display format preference
        let currencyDisplayFormat = UserDefaults.standard.string(forKey: "currencyDisplayFormat") ?? "symbol"

        // Build summaries for ALL widget periods using DetailPeriod (source of truth)
        // Uses allTransactions to ensure correct data for past periods like lastYear
        var periodSummaries: [String: WidgetPeriodSummary] = [:]

        // Widget periods aligned with DetailPeriod (excluding custom)
        let widgetPeriods: [DetailPeriod] = [
            .thisWeek, .last7Days, .last30Days, .thisMonth,
            .lastMonth, .thisYear, .lastYear, .allTime
        ]

        for period in widgetPeriods {
            let interval = period.dateInterval()
            let summary = buildPeriodSummary(
                transactions: eligibleTransactions,
                periodStart: interval.start,
                periodEnd: interval.end,
                currencyCode: preferredCurrency,
                allTransactionsForBalance: eligibleTransactions,
                adjustment: adjustment
            )
            periodSummaries[period.rawValue] = summary
        }

        // Legacy fields for backwards compatibility
        let thisMonthSummary = periodSummaries[DetailPeriod.thisMonth.rawValue] ?? buildPeriodSummary(
            transactions: eligibleRecentTransactions,
            periodStart: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date.now)) ?? Date.now,
            periodEnd: Date.now,
            currencyCode: preferredCurrency,
            adjustment: adjustment
        )

        let allTimeSummary = periodSummaries[DetailPeriod.allTime.rawValue] ?? buildPeriodSummary(
            transactions: eligibleTransactions,
            periodStart: Date.distantPast,
            periodEnd: Date.now,
            currencyCode: preferredCurrency,
            adjustment: adjustment
        )

        return WidgetDataSnapshot(
            lastUpdated: Date.now,
            preferredCurrencyCode: preferredCurrency,
            currencyDisplayFormat: currencyDisplayFormat,
            accountBalances: widgetAccountBalances,
            totalBalance: totalBalance,
            transactions: widgetTransactions,
            budgets: widgetBudgets,
            scheduledPayments: widgetPayments,
            trendData: trendData,
            thisMonthSummary: thisMonthSummary,
            allTimeSummary: allTimeSummary,
            periodSummaries: periodSummaries
        )
    }

    /// Spent del budget vía SSOT `BudgetsViewModel.calculateSpending`.
    static func calculateBudgetSpent(
        budget: Budget,
        transactions: [TransactionItem],
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> Double {
        let calendar = Calendar.current
        let now = Date.now
        let interval: DateInterval

        let periodType = BudgetPeriodType(rawValue: budget.periodType) ?? .monthly
        switch periodType {
        case .weekly:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
            interval = DateInterval(start: start, end: now)
        case .monthly:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            interval = DateInterval(start: start, end: now)
        case .yearly:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            interval = DateInterval(start: start, end: now)
        case .unique:
            interval = DateInterval(start: budget.startDate ?? now, end: budget.endDate ?? now)
        }

        return BudgetsViewModel.calculateSpending(
            budget: budget,
            transactions: transactions,
            interval: interval,
            adjustment: adjustment
        )
    }

    /// Income/expense por `category.isIncome`. Tx sin categoría → no es income.
    /// Centraliza la regla y descarta heurísticas de signo del monto.
    static func isIncomeTx(_ tx: TransactionItem) -> Bool {
        tx.category?.isIncome ?? false
    }

    /// Cuentas visibles para widgets: no archivadas y no excluidas de stats.
    static func filterVisibleAccountsForWidget(_ accounts: [Account]) -> [Account] {
        accounts.filter { !$0.isArchived && !$0.excludeFromStatistics }
    }

    /// Monto en moneda preferida con fallback al monto nativo si la conversión
    /// aún no se ha calculado (`amountInPreferredCurrency == 0`).
    static func preferredAmount(_ tx: TransactionItem) -> Double {
        tx.amountInPreferredCurrency != 0 ? tx.amountInPreferredCurrency : tx.amount
    }

    /// Igual que `preferredAmount(_:)` pero proyectando el gasto de grupo bridgeado a
    /// "mi parte" (neto). Con `adjustment == .none` es byte-idéntico al de arriba.
    /// SOLO para superficies de gasto/ingreso — NUNCA para saldos/tendencia.
    static func preferredAmount(_ tx: TransactionItem, adjustment: GroupBridgeStatsAdjustment) -> Double {
        let preferred = adjustment.amountInPreferredCurrency(tx)
        return preferred != 0 ? preferred : adjustment.amount(tx)
    }

    /// Extracts display properties (icon, color) from a budget based on its subcategories
    /// Extracts display properties (icon, color) from a scheduled payment
    private static func getPaymentDisplayProperties(payment: ScheduledPayment) -> (icon: String, color: String) {
        if let subcategory = payment.subcategory {
            // Use subcategory icon/color, or fallback to category
            let icon = subcategory.iconName ?? subcategory.safeCategory.iconName ?? "creditcard.fill"
            let color = subcategory.colorHex ?? subcategory.safeCategory.colorHex
            return (icon, color)
        }

        // No subcategory: use icon based on payment category
        if payment.paymentCategory == "subscription" {
            return ("creditcard.and.123", "#6366F1")
        }
        return ("arrow.trianglehead.2.clockwise.rotate.90", "#6366F1")
    }

    private static func buildTrendData(transactions: [TransactionItem], totalBalance: Double) -> WidgetTrendData {
        let calendar = Calendar.current

        // Group transactions by day (amount already has correct sign)
        var transactionsByDay: [Date: Double] = [:]
        for tx in transactions {
            let day = calendar.startOfDay(for: tx.date)
            transactionsByDay[day, default: 0] += preferredAmount(tx)
        }

        // Find the earliest transaction date to avoid showing flat line before data exists
        let earliestTransactionDate = transactions.map(\.date).min()
        let daysOfData: Int
        if let earliest = earliestTransactionDate {
            daysOfData = calendar.dateComponents([.day], from: earliest, to: Date.now).day ?? 90
        } else {
            daysOfData = 0
        }

        // Build daily points (limited to days with actual data, max 90)
        let dailyDays = min(daysOfData + 1, 90)  // +1 to include the first transaction day
        let dailyPoints = buildDailyTrend(
            transactionsByDay: transactionsByDay,
            totalBalance: totalBalance,
            days: dailyDays,
            calendar: calendar
        )

        // Build weekly points (limited to weeks with actual data, max 104)
        let weeksOfData = (daysOfData / 7) + 1
        let weeklyPeriods = min(weeksOfData, 104)
        let weeklyPoints = buildAggregatedTrend(
            transactionsByDay: transactionsByDay,
            totalBalance: totalBalance,
            periods: weeklyPeriods,
            component: .weekOfYear,
            calendar: calendar
        )

        // Build monthly points (limited to months with actual data, max 120)
        let monthsOfData = (daysOfData / 30) + 1
        let monthlyPeriods = min(monthsOfData, 120)
        let monthlyPoints = buildAggregatedTrend(
            transactionsByDay: transactionsByDay,
            totalBalance: totalBalance,
            periods: monthlyPeriods,
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
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date.now) else { continue }
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
        let today = Date.now

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

            // Sync firstWeekday preference for widget calendar calculations
            let firstWeekday = UserDefaults.standard.integer(forKey: "firstWeekday")
            defaults.set(firstWeekday > 0 ? firstWeekday : 2, forKey: "firstWeekday")

            // Sync defaultPeriod preference for "Same as app" option in widgets
            let defaultPeriod = UserDefaults.standard.string(forKey: "defaultPeriod") ?? "allTime"
            defaults.set(defaultPeriod, forKey: "defaultPeriod")
        } catch {
            #if DEBUG
            print("WidgetDataCache: Error encoding snapshot: \(error)")
            #endif
        }
    }

    // MARK: - Period Summary Calculations

    static func buildPeriodSummary(
        transactions: [TransactionItem],
        periodStart: Date,
        periodEnd: Date,
        currencyCode: String,
        allTransactionsForBalance: [TransactionItem]? = nil,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> WidgetPeriodSummary {
        // Filter transactions for the period, excluding balance adjustments
        let periodTransactions = transactions.filter { tx in
            tx.date >= periodStart && tx.date <= periodEnd && tx.balanceAdjustmentType == nil
        }

        // Calculate totals (income-aware): suprime la pata de préstamo derivada y
        // proyecta el gasto de grupo Caso A a "mi parte".
        var totalIncome: Double = 0
        var totalExpense: Double = 0

        for tx in periodTransactions {
            guard tx.category != nil else { continue }
            if adjustment.isSuppressed(tx) { continue }
            let amount = preferredAmount(tx, adjustment: adjustment)
            if isIncomeTx(tx) {
                totalIncome += abs(amount)
            } else {
                totalExpense += abs(amount)
            }
        }

        let netCashFlow = totalIncome - totalExpense

        // Calculate historical balance at end of period
        // This is the sum of ALL transactions up to periodEnd (not just period transactions)
        // Matches TrendDataProcessor.fillBalanceBuckets logic
        var periodBalance: Double = 0
        if let allTx = allTransactionsForBalance {
            for tx in allTx where tx.date < periodEnd {
                periodBalance += preferredAmount(tx)
            }
        }

        // Build top categories (expenses only, top 20 for Large widgets)
        let topCategories = buildTopCategories(
            transactions: periodTransactions,
            totalExpense: totalExpense,
            limit: 20,
            adjustment: adjustment
        )

        // Build top subcategories (expenses only, top 20 for Large widgets)
        let topSubcategories = buildTopSubcategories(
            transactions: periodTransactions,
            totalExpense: totalExpense,
            limit: 20,
            adjustment: adjustment
        )

        // Build cash flow by day
        let cashFlowPoints = buildCashFlowByDay(
            transactions: periodTransactions,
            periodStart: periodStart,
            periodEnd: periodEnd,
            adjustment: adjustment
        )

        return WidgetPeriodSummary(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            netCashFlow: netCashFlow,
            topCategories: topCategories,
            topSubcategories: topSubcategories,
            cashFlowPoints: cashFlowPoints,
            periodBalance: allTransactionsForBalance != nil ? periodBalance : nil
        )
    }

    static func buildTopCategories(
        transactions: [TransactionItem],
        totalExpense: Double,
        limit: Int,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> [WidgetCategory] {
        // Group expenses by category
        var categoryTotals: [String: (category: Category, amount: Double)] = [:]

        for tx in transactions {
            // Skip balance adjustments
            guard tx.balanceAdjustmentType == nil else { continue }
            // Skip la pata de préstamo derivada (bridge) e income (clasif. por categoría)
            guard !adjustment.isSuppressed(tx) else { continue }
            guard !isIncomeTx(tx) else { continue }
            guard let category = tx.category else { continue }

            let amount = abs(preferredAmount(tx, adjustment: adjustment))
            let key = category.name

            if var existing = categoryTotals[key] {
                existing.amount += amount
                categoryTotals[key] = existing
            } else {
                categoryTotals[key] = (category: category, amount: amount)
            }
        }

        // Sort by amount and take top N
        let sorted = categoryTotals.values.sorted { $0.amount > $1.amount }
        let topN = Array(sorted.prefix(limit))

        return topN.map { item in
            let percentage = totalExpense > 0 ? (item.amount / totalExpense) * 100 : 0
            return WidgetCategory(
                id: item.category.persistentModelID.hashValue.description,
                name: item.category.name,
                iconName: item.category.iconName ?? "folder",
                colorHex: item.category.colorHex,
                amount: item.amount,
                percentage: percentage
            )
        }
    }

    static func buildTopSubcategories(
        transactions: [TransactionItem],
        totalExpense: Double,
        limit: Int,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> [WidgetSubcategory] {
        // Group expenses by subcategory
        var subcategoryTotals: [String: (subcategory: Subcategory, category: Category, amount: Double)] = [:]

        for tx in transactions {
            // Skip balance adjustments
            guard tx.balanceAdjustmentType == nil else { continue }
            // Skip la pata de préstamo derivada (bridge) e income (clasif. por categoría)
            guard !adjustment.isSuppressed(tx) else { continue }
            guard !isIncomeTx(tx) else { continue }
            guard let subcategory = tx.subcategory,
                  let category = tx.category else { continue }

            let amount = abs(preferredAmount(tx, adjustment: adjustment))
            let key = "\(category.name)_\(subcategory.name)"

            if var existing = subcategoryTotals[key] {
                existing.amount += amount
                subcategoryTotals[key] = existing
            } else {
                subcategoryTotals[key] = (subcategory: subcategory, category: category, amount: amount)
            }
        }

        // Sort by amount and take top N
        let sorted = subcategoryTotals.values.sorted { $0.amount > $1.amount }
        let topN = Array(sorted.prefix(limit))

        return topN.map { item in
            let percentage = totalExpense > 0 ? (item.amount / totalExpense) * 100 : 0
            return WidgetSubcategory(
                id: item.subcategory.persistentModelID.hashValue.description,
                name: item.subcategory.name,
                categoryName: item.category.name,
                iconName: item.subcategory.iconName ?? item.category.iconName,
                colorHex: item.category.colorHex,
                amount: item.amount,
                percentage: percentage
            )
        }
    }

    static func buildCashFlowByDay(
        transactions: [TransactionItem],
        periodStart: Date,
        periodEnd: Date,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> [WidgetCashFlowPoint] {
        let calendar = Calendar.current

        // Group transactions by day
        var dailyData: [Date: (income: Double, expense: Double)] = [:]

        for tx in transactions {
            // Skip balance adjustments
            guard tx.balanceAdjustmentType == nil else { continue }
            guard tx.category != nil else { continue }
            // Suprime la pata de préstamo derivada (bridge): mata el ingreso fantasma +lent.
            if adjustment.isSuppressed(tx) { continue }

            let day = calendar.startOfDay(for: tx.date)
            let rawAmount = preferredAmount(tx, adjustment: adjustment)

            var existing = dailyData[day] ?? (income: 0, expense: 0)
            if isIncomeTx(tx) {
                existing.income += abs(rawAmount)
            } else {
                existing.expense += abs(rawAmount)
            }
            dailyData[day] = existing
        }

        // Build points for each day in period
        // For very long periods (allTime), only include days with actual transactions
        // to avoid generating millions of empty points
        var points: [WidgetCashFlowPoint] = []

        let daysBetween = calendar.dateComponents([.day], from: periodStart, to: periodEnd).day ?? 0
        let isLongPeriod = daysBetween > 365  // More than 1 year

        if isLongPeriod {
            // For long periods, only include days that have data
            for (day, data) in dailyData {
                points.append(WidgetCashFlowPoint(
                    date: day,
                    income: data.income,
                    expense: data.expense,
                    net: data.income - data.expense
                ))
            }
            points.sort { $0.date < $1.date }
        } else {
            // For short periods, fill in all days (including empty ones)
            var currentDate = calendar.startOfDay(for: periodStart)
            let endDay = calendar.startOfDay(for: periodEnd)

            while currentDate <= endDay {
                let data = dailyData[currentDate] ?? (income: 0, expense: 0)
                points.append(WidgetCashFlowPoint(
                    date: currentDate,
                    income: data.income,
                    expense: data.expense,
                    net: data.income - data.expense
                ))

                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDay
            }
        }

        return points
    }
}
