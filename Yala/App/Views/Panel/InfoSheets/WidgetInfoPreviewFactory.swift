//
//  WidgetInfoPreviewFactory.swift
//  Yala
//
//  Construye el preview del `WidgetInfoSheet` a partir de un `WidgetType`.
//  Replica fielmente el cuerpo de los closures inline de `PanelWidgetSection`
//  con interactividad apagada — los call-sites del Panel real siguen usando
//  sus closures inline (firmas heterogéneas por struct hacen impráctico el
//  refactor unificado en este momento).
//
//  Llamado desde `PanelSectionPreferencesSheet.widgetRow` cuando el usuario
//  toca el `info.circle` para abrir la sheet pedagógica desde la configuración
//  de sección.
//

import SwiftUI

@MainActor
struct WidgetInfoPreviewFactory {
    @ViewBuilder
    static func preview(
        for type: WidgetType,
        viewModel: PanelViewModel,
        sessionState: SessionState,
        currencyCode: String,
        showVariations: Bool,
        reduceMotion: Bool,
        size: WidgetSize
    ) -> some View {
        switch type {
        case .trend:
            TrendsCarouselWidget(
                viewModel: viewModel,
                sessionState: sessionState,
                currencyCode: currencyCode,
                currentBalance: viewModel.currentBalance,
                size: size,
                onShowMore: nil
            )

        case .topSpending:
            TopCategoriesWidget(
                categories: viewModel.topSpendingCategories,
                currencyCode: currencyCode,
                selectedCategoryID: nil,
                isExcludeMode: false,
                onSelectCategory: nil,
                onShowMore: nil,
                size: mapTopWidgetSize(size),
                period: viewModel.selectedPeriod,
                previousTotalAmount: nil,
                showVariationHeader: false
            )

        case .topSubcategories:
            TopSubcategoriesWidget(
                subcategories: viewModel.topSubcategories,
                currencyCode: currencyCode,
                globalCategoryFilterID: viewModel.selectedCategoryID,
                localCategoryFilterID: .constant(viewModel.subcategoriesWidgetFilter),
                onSelectSubcategory: nil,
                selectedSubcategoryIDs: [],
                isExcludeMode: false,
                onShowMore: nil,
                size: mapTopWidgetSize(size),
                period: viewModel.selectedPeriod,
                previousTotalAmount: nil,
                showVariationHeader: false
            )

        case .categoriesPie:
            CategoriesPieWidget(
                categories: viewModel.topSpendingCategories,
                currencyCode: currencyCode,
                selectedCategoryIDs: [],
                onSelectCategory: nil,
                onShowDetail: nil,
                isExcludeMode: false,
                size: size,
                period: viewModel.selectedPeriod,
                previousTotalAmount: nil,
                showVariationHeader: false
            )

        case .subcategoriesPie:
            SubcategoriesPieWidget(
                subcategories: viewModel.topSubcategories,
                currencyCode: currencyCode,
                selectedCategoryID: viewModel.selectedCategoryID,
                selectedSubcategoryIDs: [],
                onSelectSubcategory: nil,
                onShowDetail: nil,
                isExcludeMode: false,
                size: size,
                period: viewModel.selectedPeriod,
                previousTotalAmount: nil,
                showVariationHeader: false
            )

        case .tagsPie:
            TagsPieWidget(
                tags: viewModel.topTags,
                currencyCode: currencyCode,
                selectedTagIDs: [],
                onSelectTag: nil,
                onShowDetail: nil,
                isExcludeMode: false,
                size: size,
                period: viewModel.selectedPeriod,
                customRange: sessionState.customDateRange,
                previousTotalAmount: nil,
                showVariationHeader: false
            )

        case .cashFlow:
            let realSummary = viewModel.cashFlowSummary
            let summary: CashFlowSummary = (realSummary != nil && !realSummary!.chartData.isEmpty)
                ? realSummary!
                : .previewSample
            CashFlowWidget(
                summary: summary,
                size: size,
                period: viewModel.selectedPeriod.rawValue,
                grouping: viewModel.cashFlowGrouping,
                interval: viewModel.currentInterval,
                onShowDetail: nil,
                displayMode: viewModel.trendType,
                previousAmount: nil,
                selectedTransactionNatures: [],
                showInfoHint: false,
                isExpensesOnlyMode: false
            )

        case .latestRecords:
            RecentRecordsWidget(
                records: viewModel.latestRecords,
                currencyCode: currencyCode,
                onShowMore: nil
            )

        case .expensesByNeed:
            let isIncomeMode = viewModel.selectedTransactionNatures == [.income]
            let previewPoints = viewModel.needTrendPoints.isEmpty
                ? [NeedTrendPoint].previewSample
                : viewModel.needTrendPoints
            NeedTrendWidget(
                trendPoints: previewPoints,
                selectedNeed: nil,
                currencyCode: currencyCode,
                size: mapTopWidgetSize(size),
                grouping: viewModel.needGrouping,
                interval: viewModel.currentInterval,
                onSelectNeed: { _ in },
                onShowDetail: nil,
                period: viewModel.selectedPeriod,
                previousTotalAmount: nil,
                previousAmountByNeed: [:],
                showVariationHeader: false,
                isIncomeMode: isIncomeMode
            )

        case .exchangeRate:
            let usesRealData: Bool = {
                guard let realData = viewModel.exchangeRateWidgetData,
                      !realData.chartPoints.isEmpty else { return false }
                return viewModel.selectedComparisonCurrencies.contains { $0.rawValue != currencyCode }
            }()
            ExchangeRateWidget(
                data: usesRealData ? viewModel.exchangeRateWidgetData : .previewSample,
                preferredCurrency: currencyCode,
                selectedCurrencies: .constant(usesRealData
                    ? viewModel.selectedComparisonCurrencies
                    : [.usd, .eur]),
                grouping: viewModel.exchangeRateGrouping
            )

        case .budgets:
            BudgetsWidget(
                budgets: viewModel.topBudgetSummaries,
                currencyCode: currencyCode,
                hasBudgetsButNoFavorites: viewModel.hasBudgetsButNoFavorites,
                selectedBudgetID: nil,
                isExcludeMode: false,
                onSelectBudget: nil,
                onShowMore: nil,
                onEditFavorites: nil,
                size: mapBudgetsSize(size)
            )

        case .scheduledPayments:
            ScheduledPaymentsWidget(
                data: viewModel.scheduledPaymentsWidget,
                currencyCode: currencyCode,
                size: size,
                filter: .constant(viewModel.scheduledPaymentsWidgetFilter),
                onShowMore: nil
            )

        case .weekdayBar:
            let real = viewModel.weekdayWidget.weekdaySpending
            let previewData = real.contains { $0.average > 0 } ? real : [WeekdaySpending].previewSample
            WeekdayBarPanelWidget(
                data: previewData,
                currencyCode: currencyCode,
                size: size,
                onShowMore: nil
            )
        }
    }

    private static func mapTopWidgetSize(_ size: WidgetSize) -> TopCategoriesWidget.CardSize {
        switch size {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        }
    }

    private static func mapBudgetsSize(_ size: WidgetSize) -> BudgetsWidget.CardSize {
        switch size {
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        }
    }
}
