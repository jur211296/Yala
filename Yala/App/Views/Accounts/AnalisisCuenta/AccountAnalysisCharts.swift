//
//  AccountAnalysisCharts.swift
//  Yala
//
//  Las gráficas de la ficha de una cuenta con los componentes de los widgets del Panel (rediseño del 2026-11-16): la
//  curva de Tendencias (`TrendChartView`), el flujo de caja (`CashFlowWidget`) y la distribución por categoría
//  (`CategoriesPieWidget`). Se usan tal cual, sin acciones: en la ficha un toque no cambia los filtros del Panel, que
//  solo cambia «Filtrar por esta cuenta». Sin botón de información: la ficha no es el Panel y su ayuda habla del Panel.
//

import SwiftUI

struct AccountAnalysisCharts: View {
    let analysis: AccountAnalysis
    let currencyCode: String
    let period: DetailPeriod
    let customRange: DateInterval?
    let interval: DateInterval
    let isExpensesOnlyMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if analysis.trend.rawPoints.count > 1 {
                AccountTrendCard(
                    trend: analysis.trend,
                    currencyCode: currencyCode,
                    period: period,
                    interval: interval
                )
            }

            // Sin movimientos que lo muevan, el widget del Panel enseña su vacío; en la ficha sobra: lo dice
            // «Últimos registros».
            if analysis.cashFlow.totalIncome != 0 || analysis.cashFlow.totalExpense != 0 {
                CashFlowWidget(
                    summary: analysis.cashFlow,
                    size: .medium,
                    period: period.rawValue,
                    grouping: analysis.cashFlowGrouping,
                    interval: interval,
                    displayMode: isExpensesOnlyMode ? .expense : .balance,
                    previousAmount: analysis.previousCashFlowAmount,
                    variationDisplay: .panelCompact,
                    showInfoHint: false,
                    isExpensesOnlyMode: isExpensesOnlyMode
                )
            }

            if !analysis.categories.isEmpty {
                CategoriesPieWidget(
                    categories: analysis.categories,
                    currencyCode: currencyCode,
                    onSelectCategory: nil,
                    onShowDetail: nil,
                    // El grande: el donut con sus categorías alrededor. El mediano deja medio widget en blanco fuera de
                    // la rejilla del Panel (alto mínimo de 320 pensado para ir en pareja).
                    size: .large,
                    headerInfoButton: AnyView(EmptyView()),
                    period: period,
                    customRange: customRange,
                    previousTotalAmount: analysis.previousSpent,
                    showVariationHeader: analysis.previousSpent != nil,
                    variationDisplay: .panelCompact
                )
            }
        }
    }
}

/// La curva de la cuenta en una tarjeta como la de Tendencias del Panel: el nombre de la métrica, el período a la
/// derecha y la gráfica con su altura adaptable.
private struct AccountTrendCard: View {
    let trend: AccountAnalysis.Trend
    let currencyCode: String
    let period: DetailPeriod
    let interval: DateInterval

    @State private var focusedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                Text(trend.type.displayName)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.thPrimaryText)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("account_analysis_trend_title")
                Spacer(minLength: DS.Spacing.sm)
                Text(period.displayName)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                    .lineLimit(1)
            }
            AdaptiveChartHeight(base: 170) { chartHeight in
                TrendChartView(
                    trendPoints: trend.points,
                    rawPoints: trend.rawPoints,
                    yDomain: trend.yDomain,
                    grouping: .day,
                    interval: interval,
                    currencyCode: currencyCode,
                    trendType: trend.type,
                    focusedDate: $focusedDate,
                    period: period,
                    chartHeight: chartHeight
                )
                .frame(height: chartHeight)
            }
        }
        .panelCard()
    }
}
