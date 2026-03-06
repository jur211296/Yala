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
        comparisonMode: ComparisonMode = .month,
        context: ModelContext
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
            context: context
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

        let key = InsightsLLMService.shared.cacheKey(
            period: period.rawValue,
            filterHash: filterHash,
            txnCount: txnCount,
            comparisonMode: comparisonMode.rawValue
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
                cacheKey: key
            )
            aiInsights = response
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
            "comparison_ref": comparisonLabel,
            "comparison_label": data.periodSummary.previousPeriodLabel,
            "spending_total_variation": data.periodSummary.expenseVariation.map { "\(Int($0))%" } ?? "N/A",
            "income_variation": data.periodSummary.incomeVariation.map { "\(Int($0))%" } ?? "N/A",
            "count": data.periodSummary.transactionCount,
            "daily_avg": Int(data.quickStats.dailyAverage)
        ]

        // Top categories (name + percentage only, never amounts)
        if let top = data.quickStats.topCategory {
            result["top_category"] = ["name": top.category.name, "pct": Int(top.percentage)]
        }

        // Nature split
        let nature = data.natureDistribution
        if nature.total > 0 {
            result["nature_split"] = [
                "essential": Int(nature.essentialPercent),
                "priority": Int(nature.priorityPercent),
                "optional": Int(nature.optionalPercent)
            ]
        }

        // Budgets at risk
        if !data.commitments.budgetsAtRisk.isEmpty {
            result["budgets_at_risk"] = data.commitments.budgetsAtRisk.map {
                ["name": $0.name, "usage_pct": Int($0.usagePercent)]
            }
        }

        // Year-over-year
        if let yoy = data.yearOverYear, let variation = yoy.variation {
            result["year_ago_variation"] = "\(Int(variation))%"
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

        // Natures
        if !criteria.selectedNatures.isEmpty {
            let names = criteria.selectedNatures.map { $0.displayName }
            filters["natures"] = names
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
