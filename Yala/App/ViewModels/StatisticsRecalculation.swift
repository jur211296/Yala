//
//  StatisticsRecalculation.swift
//  Yala
//
//  Una pasada de cálculo de Estadísticas: Registros, Tendencias y Resumen (`insightData` + Salud Financiera).
//  Sale de `DetailContainerView` para poder probarla sin la vista.
//

import Foundation
import SwiftData

/// Recalcula todo lo que pintan las pestañas de Estadísticas a partir de los datos ya cargados (sin fetch).
///
/// **No mira qué pestaña está a la vista.** Hasta el 2026-10-05 `insightData` solo se calculaba en Resumen y
/// Distribución, una optimización de cuando eran las únicas que lo leían. El hero de Tendencias empezó a leerlo
/// después y nadie lo añadió a la lista: al cambiar el período desde Tendencias, las gráficas seguían al período y
/// el hero se quedaba con el anterior (`trends-hero-keeps-the-previous-period-after-changing-it-on-trends`). Una
/// lista de lectores escrita a mano es lo que se rompió, así que no hay lista: `InsightsViewModel` ya descarta una
/// pasada cuyas entradas no cambiaron.
@MainActor
final class StatisticsRecalculation {

    /// Lo que la pasada lee y la vista ya tiene cargado.
    struct Inputs {
        var transactions: [TransactionItem]
        var accounts: [Account]
        var categories: [Category]
        var tags: [Tag]
        var budgets: [Budget]
        var scheduledPayments: [ScheduledPayment]
        var period: DetailPeriod
        var customRange: DateInterval?
        var comparisonMode: ComparisonMode
        var currencyCode: String
        var dataVersion: Int
        var includeGroupTransactionsInStats: Bool
    }

    /// Firma de las entradas de la última Salud Financiera. El score depende de los datos y del intervalo, no de
    /// los filtros: sin esta firma, cada chip de filtro repetía los dos fetches de `loadPaidAmounts`.
    private var lastScoreSignature: Int?

    func run(
        _ inputs: Inputs,
        records: RecordsViewModel,
        trends: StatisticsViewModel,
        insights: InsightsViewModel,
        context: ModelContext
    ) {
        // Proyección «mi parte» (neto) desde el set AMPLIO (con AMBAS hermanas del bridge), compartida por todas
        // las superficies de esta pantalla.
        let adjustment = GroupBridgeStatsAdjustment.build(from: inputs.transactions, context: context)
        records.applyFilters(
            transactions: inputs.transactions,
            accounts: inputs.accounts,
            categories: inputs.categories,
            tags: inputs.tags,
            context: context
        )
        trends.calculateTrendData(
            accounts: inputs.accounts,
            transactions: inputs.transactions,
            allTags: inputs.tags,
            defaultCurrencyCode: inputs.currencyCode,
            adjustment: adjustment
        )
        calculateInsights(inputs, trends: trends, insights: insights, context: context, adjustment: adjustment)
    }

    private func calculateInsights(
        _ inputs: Inputs,
        trends: StatisticsViewModel,
        insights: InsightsViewModel,
        context: ModelContext,
        adjustment: GroupBridgeStatsAdjustment
    ) {
        let criteria = trends.filterCriteria(withTagCatalog: inputs.tags)
        insights.calculateInsightsData(
            transactions: inputs.transactions,
            accounts: inputs.accounts,
            categories: inputs.categories,
            budgets: inputs.budgets,
            scheduledPayments: inputs.scheduledPayments,
            period: inputs.period,
            criteria: criteria,
            currencyCode: inputs.currencyCode,
            customRange: inputs.customRange,
            comparisonMode: inputs.comparisonMode,
            adjustment: adjustment
        )

        // Salud Financiera del período. Depende de los datos y del intervalo; los filtros no la mueven.
        let scoreInterval = trends.detailPeriod.dateInterval(customRange: trends.customDateRange)
        var scoreHasher = Hasher()
        scoreHasher.combine(inputs.dataVersion)
        scoreHasher.combine(scoreInterval.start)
        scoreHasher.combine(scoreInterval.end)
        // El toggle de grupos cambia el dataset del score (incluye o excluye las TX bridgeadas).
        scoreHasher.combine(inputs.includeGroupTransactionsInStats)
        let scoreSignature = scoreHasher.finalize()
        if scoreSignature != lastScoreSignature {
            lastScoreSignature = scoreSignature
            let activePayments = inputs.scheduledPayments.filter(\.isActive)
            let paidAmounts = ScheduledPaymentPaidStatusHelper.loadPaidAmounts(
                for: activePayments,
                interval: scoreInterval,
                context: context
            )
            insights.calculateFinancialScore(
                transactions: inputs.transactions,
                budgets: inputs.budgets,
                scheduledPayments: inputs.scheduledPayments,
                accounts: inputs.accounts,
                paidAmounts: paidAmounts,
                period: trends.detailPeriod,
                customRange: trends.customDateRange,
                preferredCurrencyCode: inputs.currencyCode,
                adjustment: adjustment
            )
        }

        // El análisis con IA describe el contexto anterior: vuelve el botón.
        insights.resetAIState()
        insights.storeGenerationContext(
            period: inputs.period,
            filterHash: criteria.hashValue,
            txnCount: inputs.transactions.count,
            currencyCode: inputs.currencyCode,
            comparisonMode: inputs.comparisonMode,
            criteria: criteria,
            accounts: inputs.accounts,
            categories: inputs.categories,
            tags: inputs.tags
        )
    }
}
