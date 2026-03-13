//
//  InsightsViewModel.swift
//  Yala
//
//  ViewModel for Smart Insights tab. Computes local data via InsightsCalculator,
//  optionally generates AI insights for Pro users.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class InsightsViewModel {

    // MARK: - Data

    private(set) var insightData: InsightData?

    // MARK: - AI State

    private(set) var aiInsights: LLMInsightResponse?
    private(set) var isLoadingAI = false
    private(set) var aiError: String?

    // MARK: - Preferences

    var currentTone: InsightTone { .current }
    var currentFocus: InsightFocus { .current }

    // MARK: - Calculation

    /// Computes all insights data from filtered transactions.
    func calculateInsightsData(
        transactions: [TransactionItem],
        accounts: [Account],
        categories: [Category],
        budgets: [Budget],
        scheduledPayments: [ScheduledPayment],
        period: DetailPeriod,
        criteria: FilterCriteria,
        currencyCode: String,
        customRange: DateInterval?,
        comparisonMode: ComparisonMode = .month
    ) {
        insightData = InsightsCalculator.calculate(
            transactions: transactions,
            accounts: accounts,
            categories: categories,
            budgets: budgets,
            scheduledPayments: scheduledPayments,
            period: period,
            criteria: criteria,
            currencyCode: currencyCode,
            customRange: customRange,
            comparisonMode: comparisonMode,
            tone: currentTone,
            focus: currentFocus
        )
    }

    // MARK: - AI Insights

    /// Generate AI insights if Pro + AI consent + online + has data.
    func generateAIInsights(
        period: DetailPeriod,
        filterHash: Int,
        txnCount: Int,
        currencyCode: String,
        comparisonMode: ComparisonMode = .month,
        criteria: FilterCriteria = .empty,
        accounts: [Account] = [],
        categories: [Category] = [],
        tags: [Tag] = []
    ) async {
        guard let data = insightData else { return }

        // Check prerequisites
        let isPro = FeatureGateService.shared.canAccess(.smartInsightsAI)
        let hasConsent = UserDefaults.standard.bool(forKey: "aiDataConsentAccepted")
        let isOnline = NetworkMonitor.shared.isConnected

        guard isPro, hasConsent, isOnline else {
            aiInsights = nil
            return
        }

        let tone = currentTone
        let focus = currentFocus

        let key = InsightsLLMService.shared.cacheKey(
            period: period.rawValue,
            filterHash: filterHash,
            txnCount: txnCount,
            comparisonMode: comparisonMode.rawValue,
            tone: tone,
            focus: focus
        )

        // Check cache first
        if let cached = InsightsLLMService.shared.getCached(key: key) {
            aiInsights = cached
            return
        }

        isLoadingAI = true
        aiError = nil

        // Build aggregated data (never individual transactions)
        let aggregated = buildAggregatedData(
            data,
            currencyCode: currencyCode,
            comparisonMode: comparisonMode,
            criteria: criteria,
            accounts: accounts,
            categories: categories,
            tags: tags
        )

        do {
            let response = try await InsightsLLMService.shared.generateInsights(
                aggregatedData: aggregated,
                cacheKey: key,
                tone: tone,
                focus: focus
            )
            aiInsights = response
            TelemetryService.track(.aiInsightsGenerated)
        } catch {
            aiError = error.localizedDescription
            #if DEBUG
            print("InsightsViewModel: AI error: \(error)")
            #endif
        }

        isLoadingAI = false
    }

    // MARK: - Helpers

    private func buildAggregatedData(
        _ data: InsightData,
        currencyCode: String,
        comparisonMode: ComparisonMode,
        criteria: FilterCriteria = .empty,
        accounts: [Account] = [],
        categories: [Category] = [],
        tags: [Tag] = []
    ) -> [String: Any] {
        let comparisonLabel = comparisonMode == .year ? "año anterior" : "periodo anterior"
        var result: [String: Any] = [
            "currency": currencyCode,
            "locale": Locale.current.language.languageCode?.identifier ?? "es",
            "country": Locale.current.region?.identifier ?? "",
            "comparison_ref": comparisonLabel,
            "comparison_label": data.periodSummary.previousPeriodLabel,
            "total_expense": Int(data.periodSummary.totalExpense),
            "total_income": Int(data.periodSummary.totalIncome),
            "net_balance": Int(data.periodSummary.netBalance),
            "spending_total_variation": data.periodSummary.expenseVariation.map { "\(Int($0))%" } ?? "N/A",
            "income_variation": data.periodSummary.incomeVariation.map { "\(Int($0))%" } ?? "N/A",
            "daily_avg_variation": data.periodSummary.dailyAverageVariation.map { "\(Int($0))%" } ?? "N/A",
            "balance_variation": data.periodSummary.balanceVariation.map { "\(Int($0))%" } ?? "N/A",
            "count": data.periodSummary.transactionCount,
            "daily_avg": Int(data.quickStats.dailyAverage)
        ]

        // Top 5 categories with amounts
        if !data.quickStats.topCategories.isEmpty {
            result["top_categories"] = data.quickStats.topCategories.map {
                ["name": $0.category.name, "amount": Int($0.amount), "pct": Int($0.percentage)] as [String: Any]
            }
        }

        // Top subcategory
        if let topSub = data.quickStats.topSubcategory {
            let subName = topSub.subcategory?.name ?? topSub.subcategoryName
            let totalExpense = data.periodSummary.totalExpense
            let pctOfTotal = totalExpense > 0 ? Int((topSub.amount / totalExpense) * 100) : 0
            result["top_subcategory"] = ["name": subName, "amount": Int(topSub.amount), "pct_of_total": pctOfTotal] as [String: Any]
        }

        // Highest expense
        if let highest = data.quickStats.highestExpense {
            result["highest_expense"] = ["amount": Int(highest.amount), "description": highest.note] as [String: Any]
        }

        // Highest average weekday
        if let weekday = data.quickStats.highestAvgWeekday {
            result["highest_avg_weekday"] = ["day": weekday.weekdayName, "avg": Int(weekday.average)] as [String: Any]
        }

        // Subscriptions
        if data.commitments.activeSubscriptionsCount > 0 {
            result["subscriptions"] = ["count": data.commitments.activeSubscriptionsCount, "monthly_total": Int(data.commitments.activeSubscriptionsMonthly)] as [String: Any]
        }

        // Pending payments
        if data.commitments.pendingPaymentsCount > 0 {
            result["pending_payments"] = ["count": data.commitments.pendingPaymentsCount, "amount": Int(data.commitments.pendingPaymentsAmount)] as [String: Any]
        }

        // Need split with amounts
        let needDist = data.needDistribution
        if needDist.total > 0 {
            result["need_split"] = [
                "essential": ["pct": Int(needDist.essentialPercent), "amount": Int(needDist.essential)] as [String: Any],
                "priority": ["pct": Int(needDist.priorityPercent), "amount": Int(needDist.priority)] as [String: Any],
                "optional": ["pct": Int(needDist.optionalPercent), "amount": Int(needDist.optional)] as [String: Any]
            ]
        }

        // Budgets at risk with spent + limit
        if !data.commitments.budgetsAtRisk.isEmpty {
            result["budgets_at_risk"] = data.commitments.budgetsAtRisk.map {
                ["name": $0.name, "spent": Int($0.spent), "limit": Int($0.limit), "usage_pct": Int($0.usagePercent)] as [String: Any]
            }
        }

        // Year-over-year with absolute amounts
        if let yoy = data.yearOverYear {
            var yoyDict: [String: Any] = [
                "current": Int(yoy.currentAmount),
                "previous": Int(yoy.previousYearAmount)
            ]
            if let variation = yoy.variation {
                yoyDict["variation"] = "\(Int(variation))%"
            }
            result["year_ago"] = yoyDict
        }

        // Active filters context — tells the AI what subset of data it's seeing
        if criteria.hasActiveFilters {
            result["active_filters"] = buildFilterContext(
                criteria: criteria,
                accounts: accounts,
                categories: categories,
                tags: tags
            )
        }

        return result
    }

    /// Builds a human-readable description of active filters for the AI prompt.
    private func buildFilterContext(
        criteria: FilterCriteria,
        accounts: [Account],
        categories: [Category],
        tags: [Tag]
    ) -> [String: Any] {
        let mode = criteria.isExcludeMode ? "exclude" : "include"
        var filters: [String: Any] = ["mode": mode]
        var descriptions: [String] = []

        // Accounts
        if !criteria.selectedAccounts.isEmpty {
            let names = accounts
                .filter { criteria.selectedAccounts.contains($0.persistentModelID) }
                .map { $0.name }
            if !names.isEmpty {
                filters["accounts"] = names
                let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
                descriptions.append("\(verb) cuentas: \(names.joined(separator: ", "))")
            }
        }

        // Categories
        if !criteria.selectedCategories.isEmpty {
            let names = categories
                .filter { criteria.selectedCategories.contains($0.persistentModelID) }
                .map { $0.name }
            if !names.isEmpty {
                filters["categories"] = names
                let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
                descriptions.append("\(verb) categorías: \(names.joined(separator: ", "))")
            }
        }

        // Subcategories
        if !criteria.selectedSubcategories.isEmpty {
            let names = categories
                .flatMap { $0.subcategories ?? [] }
                .filter { criteria.selectedSubcategories.contains($0.persistentModelID) }
                .map { $0.name }
            if !names.isEmpty {
                filters["subcategories"] = names
                let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
                descriptions.append("\(verb) subcategorías: \(names.joined(separator: ", "))")
            }
        }

        // Tags
        if !criteria.selectedTags.isEmpty {
            let names = tags
                .filter { criteria.selectedTags.contains($0.persistentModelID) }
                .map { $0.name }
            if !names.isEmpty {
                filters["tags"] = names
                let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
                descriptions.append("\(verb) etiquetas: \(names.joined(separator: ", "))")
            }
        }

        // Needs
        if !criteria.selectedNeeds.isEmpty {
            let names = criteria.selectedNeeds.map { $0.displayName }
            filters["needs"] = names
            let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
            descriptions.append("\(verb) naturalezas: \(names.joined(separator: ", "))")
        }

        // Currencies
        if !criteria.selectedCurrencies.isEmpty {
            let codes = criteria.selectedCurrencies.map { $0.rawValue }
            filters["currencies"] = codes
            let verb = criteria.isExcludeMode ? "Excluyendo" : "Solo"
            descriptions.append("\(verb) monedas: \(codes.joined(separator: ", "))")
        }

        // Transaction nature (income/expense) — always include semantics
        if criteria.selectedTransactionNatures.count == 1,
           let nature = criteria.selectedTransactionNatures.first {
            filters["transaction_type"] = nature == .income ? "income" : "expense"
            descriptions.append("Solo \(nature.displayName.lowercased())")
        }

        // Search text
        if !criteria.searchText.isEmpty {
            filters["search"] = criteria.searchText
            descriptions.append("Buscando: \"\(criteria.searchText)\"")
        }

        filters["summary"] = descriptions.joined(separator: ". ")

        return filters
    }
}
