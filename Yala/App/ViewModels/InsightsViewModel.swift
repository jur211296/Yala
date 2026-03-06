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
            context: context
        )
    }

    // MARK: - AI Insights

    /// Generate AI insights if Pro + AI consent + online + has data.
    func generateAIInsights(
        period: DetailPeriod,
        filterHash: Int,
        txnCount: Int,
        currencyCode: String
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
            txnCount: txnCount
        )

        // Check cache first
        if let cached = InsightsLLMService.shared.getCached(key: key) {
            aiInsights = cached
            return
        }

        isLoadingAI = true
        aiError = nil

        // Build aggregated data (never individual transactions)
        let aggregated = buildAggregatedData(data, currencyCode: currencyCode)

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

    private func buildAggregatedData(_ data: InsightData, currencyCode: String) -> [String: Any] {
        var result: [String: Any] = [
            "currency": currencyCode,
            "spending_total_variation": data.periodSummary.expenseVariation.map { "\(Int($0))%" } ?? "N/A",
            "income_variation": data.periodSummary.incomeVariation.map { "\(Int($0))%" } ?? "N/A",
            "count": data.periodSummary.transactionCount,
            "daily_avg": Int(data.quickStats.dailyAverage),
            "streak": data.streak
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

        return result
    }
}
