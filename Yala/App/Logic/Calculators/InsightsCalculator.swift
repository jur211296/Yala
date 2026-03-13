//
//  InsightsCalculator.swift
//  Yala
//
//  Calculator for Smart Insights data. Accepts ModelContext for currency conversion.
//  Computes: period summary, quick stats, need distribution, weekday spending,
//  year-over-year, budgets at risk.
//

import Foundation
import SwiftData

// MARK: - Data Models

struct InsightData {
    let periodSummary: PeriodSummary
    let quickStats: QuickStats
    let commitments: Commitments
    let weekdaySpending: [WeekdaySpending]
    let needDistribution: NeedDistribution
    let yearOverYear: YearComparison?
    let ruleBasedInsights: [InsightResult]
}

struct PeriodSummary {
    let totalExpense: Double
    let totalIncome: Double
    let netBalance: Double
    let transactionCount: Int
    let expenseVariation: Double?
    let incomeVariation: Double?
    let balanceVariation: Double?
    let dailyAverageCount: Double
    let dailyAverageExpense: Double
    let dailyAverageVariation: Double?
    let previousPeriodLabel: String
}

struct QuickStats {
    let dailyAverage: Double
    let topCategories: [CategorySpendingSummary]
    let topSubcategories: [SubcategorySpendingSummary]
    let highestExpense: HighestExpenseInfo?
    let highestAvgWeekday: HighestAvgWeekdayInfo?
    let subscriptionsTotal: Double

    var topCategory: CategorySpendingSummary? { topCategories.first }
    var topSubcategory: SubcategorySpendingSummary? { topSubcategories.first }
}

struct HighestExpenseInfo {
    let amount: Double
    let note: String
}

struct HighestAvgWeekdayInfo {
    let weekdayName: String
    let average: Double
}

struct Commitments {
    let pendingPaymentsCount: Int
    let pendingPaymentsAmount: Double
    let activeSubscriptionsCount: Int
    let activeSubscriptionsMonthly: Double
    let budgetsAtRisk: [BudgetAtRisk]
}

struct BudgetAtRisk: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let usagePercent: Double
    let spent: Double
    let limit: Double
    let colorHex: String?
}

struct NeedDistribution {
    let essential: Double
    let priority: Double
    let optional: Double
    let total: Double

    var essentialPercent: Double { total > 0 ? (essential / total) * 100 : 0 }
    var priorityPercent: Double { total > 0 ? (priority / total) * 100 : 0 }
    var optionalPercent: Double { total > 0 ? (self.optional / total) * 100 : 0 }
}

struct YearComparison {
    let currentAmount: Double
    let previousYearAmount: Double
    let variation: Double?
}

struct InsightResult: Identifiable {
    let id: String
    let icon: String
    let text: AttributedString
    let sentiment: Sentiment
    let isProOnly: Bool
    let tip: AttributedString?

    init(id: String, icon: String, text: AttributedString, sentiment: Sentiment, isProOnly: Bool, tip: AttributedString? = nil) {
        self.id = id
        self.icon = icon
        self.text = text
        self.sentiment = sentiment
        self.isProOnly = isProOnly
        self.tip = tip
    }
}

enum Sentiment {
    case positive
    case neutral
    case attention
}

enum InsightTone: String, CaseIterable, Identifiable {
    case normal, considerate, sarcastic

    var id: String { rawValue }
    static let storageKey = "insightsTone"

    var displayName: String { L10n.Insights.toneName(self) }
    var previewText: String { L10n.Insights.tonePreview(self) }

    static var current: InsightTone {
        InsightTone(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .normal
    }
}

enum InsightFocus: String, CaseIterable, Identifiable {
    case balanced, saver, cautious

    var id: String { rawValue }
    static let storageKey = "insightsFocus"

    var displayName: String { L10n.Insights.focusName(self) }
    var descriptionText: String { L10n.Insights.focusDescription(self) }

    static var current: InsightFocus {
        InsightFocus(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .balanced
    }
}

// MARK: - Calculator

struct InsightsCalculator {

    /// Computes all insight data for the current period and filters.
    /// - Parameters:
    ///   - transactions: All transactions (unfiltered)
    ///   - accounts: All accounts
    ///   - categories: All categories
    ///   - budgets: All budgets
    ///   - scheduledPayments: All scheduled payments
    ///   - period: Current detail period
    ///   - criteria: Active filter criteria
    ///   - currencyCode: Preferred currency code
    ///   - customRange: Custom date range (for .custom period)
    ///   - context: ModelContext for currency conversion
    /// - Returns: Computed InsightData
    static func calculate(
        transactions: [TransactionItem],
        accounts: [Account],
        categories: [Category],
        budgets: [Budget],
        scheduledPayments: [ScheduledPayment],
        period: DetailPeriod,
        criteria: FilterCriteria,
        currencyCode: String,
        customRange: DateInterval?,
        comparisonMode: ComparisonMode = .month,
        tone: InsightTone = .normal,
        focus: InsightFocus = .balanced,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> InsightData {
        // Filter transactions using FilterService
        let filtered = FilterService.filterForTrends(
            transactions: transactions,
            accounts: accounts,
            criteria: criteria
        )

        let interval = period.dateInterval(customRange: customRange)

        // Transactions in current period
        let periodTxns = filtered.filter { interval.contains($0.date) }

        // Previous period for variations
        let prevInterval = PreviousPeriodHelper.previousInterval(for: period, mode: comparisonMode, customRange: customRange)
        let prevTxns = filtered.filter { prevInterval.contains($0.date) }

        // Period Summary
        let cashFlow = CashFlowCalculator.calculateCashFlow(
            transactions: periodTxns,
            interval: interval,
            grouping: .day,
            currencyCode: currencyCode,
            converter: converter
        )
        let prevCashFlow = CashFlowCalculator.calculateCashFlow(
            transactions: prevTxns,
            interval: prevInterval,
            grouping: .day,
            currencyCode: currencyCode,
            converter: converter
        )

        let expenseVariation = PreviousPeriodHelper.calculateVariation(
            currentAmount: cashFlow.totalExpense,
            previousAmount: prevCashFlow.totalExpense
        )
        let incomeVariation = PreviousPeriodHelper.calculateVariation(
            currentAmount: cashFlow.totalIncome,
            previousAmount: prevCashFlow.totalIncome
        )
        let balanceVariation = PreviousPeriodHelper.calculateVariation(
            currentAmount: cashFlow.netFlow,
            previousAmount: prevCashFlow.netFlow
        )

        let calendar = Calendar.current
        let daysInPeriod = max(1, calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1)
        let dailyAverageCount = Double(periodTxns.count) / Double(daysInPeriod)
        let dailyAverageExpense = cashFlow.totalExpense / Double(daysInPeriod)

        // Previous daily average for variation
        let prevDaysInPeriod = max(1, calendar.dateComponents([.day], from: prevInterval.start, to: prevInterval.end).day ?? 1)
        let prevDailyAvg = prevCashFlow.totalExpense / Double(prevDaysInPeriod)
        let dailyAverageVariation = PreviousPeriodHelper.calculateVariation(
            currentAmount: dailyAverageExpense,
            previousAmount: prevDailyAvg
        )

        // Label for previous period (e.g. "vs Feb 25")
        let previousPeriodLabel = PreviousPeriodHelper.formatComparisonText(
            previousInterval: prevInterval,
            period: period,
            mode: comparisonMode
        )

        let periodSummary = PeriodSummary(
            totalExpense: cashFlow.totalExpense,
            totalIncome: cashFlow.totalIncome,
            netBalance: cashFlow.netFlow,
            transactionCount: periodTxns.count,
            expenseVariation: expenseVariation,
            incomeVariation: incomeVariation,
            balanceVariation: balanceVariation,
            dailyAverageCount: dailyAverageCount,
            dailyAverageExpense: dailyAverageExpense,
            dailyAverageVariation: dailyAverageVariation,
            previousPeriodLabel: previousPeriodLabel
        )

        // Weekday Spending (computed before Quick Stats for highestAvgWeekday)
        let weekdaySpending = WeekdaySpendingCalculator.calculate(
            transactions: periodTxns,
            currencyCode: currencyCode,
            converter: converter
        )

        // Highest average weekday
        let highestAvgWeekday: HighestAvgWeekdayInfo? = {
            guard let best = weekdaySpending.max(by: { $0.average < $1.average }), best.average > 0 else { return nil }
            let symbols = Calendar.current.weekdaySymbols
            guard best.weekday >= 1, best.weekday <= 7 else { return nil }
            return HighestAvgWeekdayInfo(weekdayName: symbols[best.weekday - 1], average: best.average)
        }()

        // Quick Stats
        let topCategories = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: periodTxns,
            interval: interval,
            currencyCode: currencyCode,
            converter: converter
        )
        let topSubcategories = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: periodTxns,
            interval: interval,
            currencyCode: currencyCode,
            converter: converter
        )

        let highestExpense = findHighestExpense(periodTxns, currencyCode: currencyCode, converter: converter)
        let subscriptionsTotal = calculateSubscriptionsTotal(scheduledPayments, currencyCode: currencyCode, converter: converter)

        let quickStats = QuickStats(
            dailyAverage: dailyAverageExpense,
            topCategories: Array(topCategories.prefix(5)),
            topSubcategories: Array(topSubcategories.prefix(5)),
            highestExpense: highestExpense,
            highestAvgWeekday: highestAvgWeekday,
            subscriptionsTotal: subscriptionsTotal
        )

        // Commitments
        let commitments = calculateCommitments(
            budgets: budgets,
            scheduledPayments: scheduledPayments,
            periodTxns: periodTxns,
            allTransactions: transactions,
            interval: interval,
            currencyCode: currencyCode,
            converter: converter
        )

        // Need Distribution
        let needDistribution = calculateNeedDistribution(periodTxns, currencyCode: currencyCode, converter: converter)

        // Year-over-Year
        let yearOverYear = calculateYearOverYear(
            filtered: filtered,
            currentExpense: cashFlow.totalExpense,
            period: period,
            currencyCode: currencyCode,
            customRange: customRange,
            converter: converter
        )

        // Rule-based insights
        let ruleBasedInsights = generateRuleBasedInsights(
            periodSummary: periodSummary,
            quickStats: quickStats,
            commitments: commitments,
            needDistribution: needDistribution,
            yearOverYear: yearOverYear,
            topCategories: topCategories,
            prevCashFlow: prevCashFlow,
            currencyCode: currencyCode,
            tone: tone,
            focus: focus
        )

        return InsightData(
            periodSummary: periodSummary,
            quickStats: quickStats,
            commitments: commitments,
            weekdaySpending: weekdaySpending,
            needDistribution: needDistribution,
            yearOverYear: yearOverYear,
            ruleBasedInsights: ruleBasedInsights
        )
    }

    // MARK: - Currency Conversion

    private static func convertedAmount(
        _ amount: Double,
        from fromCode: String,
        to toCode: String,
        preferredCode: String? = nil,
        preferredAmount: Double? = nil,
        on date: Date,
        converter: CurrencyConverting
    ) -> Double {
        if fromCode == toCode {
            return abs(amount)
        }
        if let prefCode = preferredCode, prefCode == toCode, let prefAmt = preferredAmount {
            return abs(prefAmt)
        }
        let converted = converter.convert(
            Decimal(abs(amount)),
            from: fromCode,
            to: toCode,
            on: date
        )
        return NSDecimalNumber(decimal: converted).doubleValue
    }

    /// Convenience for TransactionItem → target currency
    private static func txAmount(_ tx: TransactionItem, currencyCode: String, converter: CurrencyConverting) -> Double {
        convertedAmount(
            tx.amount,
            from: tx.currencyCode,
            to: currencyCode,
            preferredCode: tx.preferredCurrencyCode,
            preferredAmount: tx.amountInPreferredCurrency,
            on: tx.date,
            converter: converter
        )
    }

    // MARK: - Helpers

    private static func findHighestExpense(
        _ transactions: [TransactionItem],
        currencyCode: String,
        converter: CurrencyConverting
    ) -> HighestExpenseInfo? {
        var highest: (amount: Double, note: String)? = nil

        for tx in transactions {
            guard let category = tx.category, !category.isIncome else { continue }
            guard tx.balanceAdjustmentType == nil else { continue }

            let amount = txAmount(tx, currencyCode: currencyCode, converter: converter)

            if highest.map({ amount > $0.amount }) ?? true {
                let note = tx.note ?? tx.subcategory?.name ?? category.name
                highest = (amount, note)
            }
        }

        guard let h = highest else { return nil }
        return HighestExpenseInfo(amount: h.amount, note: h.note)
    }

    private static func calculateSubscriptionsTotal(
        _ payments: [ScheduledPayment],
        currencyCode: String,
        converter: CurrencyConverting
    ) -> Double {
        var total: Double = 0
        let now = Date.now

        for payment in payments {
            guard payment.isActive else { continue }
            guard payment.isRecurring else { continue }

            let amount = convertedAmount(payment.amount, from: payment.currencyCode, to: currencyCode, on: now, converter: converter)
            total += amount
        }

        return total
    }

    /// Returns the current budget period interval based on the budget's periodType and Date.now.
    static func currentBudgetInterval(for budget: Budget) -> DateInterval {
        let calendar = Calendar.current
        let now = Date.now

        guard let periodType = BudgetPeriodType(rawValue: budget.periodType) else {
            let monthStart = calendar.startOfMonth(for: now)
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            return DateInterval(start: monthStart, end: monthEnd)
        }

        switch periodType {
        case .weekly:
            let weekStart = calendar.startOfWeek(for: now)
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            return DateInterval(start: weekStart, end: weekEnd)
        case .monthly:
            let monthStart = calendar.startOfMonth(for: now)
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            return DateInterval(start: monthStart, end: monthEnd)
        case .yearly:
            let year = calendar.component(.year, from: now)
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? yearStart
            return DateInterval(start: yearStart, end: yearEnd)
        case .unique:
            guard let start = budget.startDate, let end = budget.endDate else {
                let monthStart = calendar.startOfMonth(for: now)
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                return DateInterval(start: monthStart, end: monthEnd)
            }
            return DateInterval(start: start, end: end)
        }
    }

    private static func calculateCommitments(
        budgets: [Budget],
        scheduledPayments: [ScheduledPayment],
        periodTxns: [TransactionItem],
        allTransactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        converter: CurrencyConverting
    ) -> Commitments {
        let now = Date.now

        // Pending scheduled payments (due within period, not yet executed)
        var pendingCount = 0
        var pendingAmount: Double = 0
        var subscriptionCount = 0
        var subscriptionMonthly: Double = 0

        for payment in scheduledPayments {
            guard payment.isActive else { continue }

            let amount = convertedAmount(payment.amount, from: payment.currencyCode, to: currencyCode, on: now, converter: converter)

            if payment.isRecurring {
                subscriptionCount += 1
                subscriptionMonthly += amount
            }

            // Check if next due date is within period
            if interval.contains(payment.nextDueDate) {
                pendingCount += 1
                pendingAmount += amount
            }
        }

        // Budgets at risk (>75% spent) — pregroup expense transactions by category for efficiency
        let expenseTxns = allTransactions.filter { $0.category?.isIncome == false && $0.balanceAdjustmentType == nil }
        let txnsByCategory = Dictionary(grouping: expenseTxns, by: { $0.category?.persistentModelID })

        var budgetsAtRisk: [BudgetAtRisk] = []
        for budget in budgets {
            guard budget.isActive else { continue }
            guard budget.limitAmount > 0 else { continue }

            // Filter transactions within the budget's OWN current period (not the global Insights period)
            let budgetTxns: [TransactionItem]
            if let category = budget.category {
                let budgetInterval = currentBudgetInterval(for: budget)
                let categoryTxns = txnsByCategory[category.persistentModelID] ?? []
                budgetTxns = categoryTxns.filter { budgetInterval.contains($0.date) }
            } else {
                continue
            }

            // Sum expenses in budget currency
            let spent = budgetTxns.reduce(0.0) { sum, tx in
                sum + txAmount(tx, currencyCode: budget.currencyCode, converter: converter)
            }

            let usage = (spent / budget.limitAmount) * 100
            if usage >= 50 {
                budgetsAtRisk.append(BudgetAtRisk(
                    id: budget.persistentModelID,
                    name: budget.name,
                    usagePercent: usage,
                    spent: spent,
                    limit: budget.limitAmount,
                    colorHex: budget.category?.colorHex
                ))
            }
        }
        budgetsAtRisk.sort { $0.usagePercent > $1.usagePercent }

        return Commitments(
            pendingPaymentsCount: pendingCount,
            pendingPaymentsAmount: pendingAmount,
            activeSubscriptionsCount: subscriptionCount,
            activeSubscriptionsMonthly: subscriptionMonthly,
            budgetsAtRisk: budgetsAtRisk
        )
    }

    private static func calculateNeedDistribution(
        _ transactions: [TransactionItem],
        currencyCode: String,
        converter: CurrencyConverting
    ) -> NeedDistribution {
        var essential: Double = 0
        var priority: Double = 0
        var optional: Double = 0

        for tx in transactions {
            guard let category = tx.category, !category.isIncome else { continue }
            guard tx.balanceAdjustmentType == nil else { continue }

            let amount = txAmount(tx, currencyCode: currencyCode, converter: converter)

            let need = tx.subcategory?.need
            switch need {
            case .essential:
                essential += amount
            case .priority:
                priority += amount
            case .optional:
                optional += amount
            case .unclassified, nil:
                // Unclassified — group with optional
                optional += amount
            }
        }

        return NeedDistribution(
            essential: essential,
            priority: priority,
            optional: optional,
            total: essential + priority + optional
        )
    }

    private static func calculateYearOverYear(
        filtered: [TransactionItem],
        currentExpense: Double,
        period: DetailPeriod,
        currencyCode: String,
        customRange: DateInterval?,
        converter: CurrencyConverting
    ) -> YearComparison? {
        let prevYearInterval = PreviousPeriodHelper.previousInterval(for: period, mode: .year, customRange: customRange)
        let prevYearTxns = filtered.filter { prevYearInterval.contains($0.date) }

        guard !prevYearTxns.isEmpty else { return nil }

        let prevCashFlow = CashFlowCalculator.calculateCashFlow(
            transactions: prevYearTxns,
            interval: prevYearInterval,
            grouping: .day,
            currencyCode: currencyCode,
            converter: converter
        )

        let variation = PreviousPeriodHelper.calculateVariation(
            currentAmount: currentExpense,
            previousAmount: prevCashFlow.totalExpense
        )

        return YearComparison(
            currentAmount: currentExpense,
            previousYearAmount: prevCashFlow.totalExpense,
            variation: variation
        )
    }

    // MARK: - Rule-Based Insights

    static func generateRuleBasedInsights(
        periodSummary: PeriodSummary,
        quickStats: QuickStats,
        commitments: Commitments,
        needDistribution: NeedDistribution,
        yearOverYear: YearComparison?,
        topCategories: [CategorySpendingSummary],
        prevCashFlow: CashFlowSummary,
        currencyCode: String,
        tone: InsightTone = .normal,
        focus: InsightFocus = .balanced
    ) -> [InsightResult] {
        var insights: [InsightResult] = []

        // Focus-adjusted thresholds
        let topCategoryThreshold: Double = focus == .saver ? 30 : 40
        let expenseUpThreshold: Double = (focus == .saver || focus == .cautious) ? 10 : 15
        let budgetRiskThreshold: Double = focus == .cautious ? 75 : 90

        // Rule 1: Top category dominance
        if let top = topCategories.first, top.percentage > topCategoryThreshold {
            let text = AttributedString(L10n.Insights.ruleTopCategory(top.category.name, Int(top.percentage), tone: tone))
            let tip = AttributedString(L10n.Insights.tipTopCategory(top.category.name))
            insights.append(InsightResult(
                id: "top_category_dominant",
                icon: "chart.pie",
                text: text,
                sentiment: .neutral,
                isProOnly: false,
                tip: tip
            ))
        }

        // Rule 2: Expense trend
        if let variation = periodSummary.expenseVariation {
            if variation > expenseUpThreshold {
                let formatted = PreviousPeriodHelper.formatVariationValue(variation)
                let text = AttributedString(L10n.Insights.ruleExpenseUp(formatted, tone: tone))
                let tip = AttributedString(L10n.Insights.tipExpenseUp)
                insights.append(InsightResult(
                    id: "expense_up",
                    icon: "arrow.up.right",
                    text: text,
                    sentiment: .attention,
                    isProOnly: false,
                    tip: tip
                ))
            } else if variation < -10 {
                let formatted = PreviousPeriodHelper.formatVariationValue(abs(variation))
                let text = AttributedString(L10n.Insights.ruleExpenseDown(formatted, tone: tone))
                insights.append(InsightResult(
                    id: "expense_down",
                    icon: "arrow.down.right",
                    text: text,
                    sentiment: .positive,
                    isProOnly: false
                ))
            }
        }

        // Rule 3: Budgets at risk
        let maxBudgetAlerts = focus == .cautious ? 2 : 1
        for budget in commitments.budgetsAtRisk.lazy.filter({ $0.usagePercent >= budgetRiskThreshold }).prefix(maxBudgetAlerts) {
            let text = AttributedString(L10n.Insights.ruleBudgetRisk(budget.name, Int(budget.usagePercent), tone: tone))
            let tip = AttributedString(L10n.Insights.tipBudgetRisk(budget.name))
            insights.append(InsightResult(
                id: "budget_risk_\(budget.name)",
                icon: "exclamationmark.triangle",
                text: text,
                sentiment: .attention,
                isProOnly: false,
                tip: tip
            ))
        }

        // Rule 4: Need distribution shift
        if needDistribution.optionalPercent > 40 {
            let text = AttributedString(L10n.Insights.ruleOptionalHigh(Int(needDistribution.optionalPercent), tone: tone))
            let tip = AttributedString(L10n.Insights.tipOptionalHigh)
            insights.append(InsightResult(
                id: "optional_high",
                icon: "sparkles",
                text: text,
                sentiment: .neutral,
                isProOnly: false,
                tip: tip
            ))
        }

        return insights
    }
}
