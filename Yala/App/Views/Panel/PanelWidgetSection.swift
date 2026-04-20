//
//  PanelWidgetSection.swift
//  Yala
//
//  Widget wrapper views that isolate @Observable tracking from PanelView's body.
//  Each section reads only its own slice of PanelViewModel in its own body scope.
//  Parent-to-child navigation uses viewModel methods, not closure parameters.
//

import SwiftData
import SwiftUI

// MARK: - Widget Router

/// Routes a WidgetConfig to the appropriate section wrapper.
/// Reads only `config.type` — all ViewModel reads happen in child bodies.
struct PanelWidgetRouter: View {
    let config: WidgetConfig
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let currencyCode: String
    let showVariations: Bool
    let reduceMotion: Bool
    @Binding var showBudgetFavoritesSettings: Bool

    var body: some View {
        switch config.type {
        case .trend:
            PanelTrendSection(viewModel: viewModel, sessionState: sessionState, currencyCode: currencyCode)
        case .topSpending:
            PanelCategoriesSection(viewModel: viewModel, currencyCode: currencyCode, size: config.size, showVariations: showVariations, reduceMotion: reduceMotion)
        case .topSubcategories:
            PanelSubcategoriesSection(viewModel: viewModel, currencyCode: currencyCode, size: config.size, showVariations: showVariations, reduceMotion: reduceMotion)
        case .categoriesPie:
            PanelCategoriesPieSection(viewModel: viewModel, currencyCode: currencyCode, size: config.size, showVariations: showVariations, reduceMotion: reduceMotion)
        case .subcategoriesPie:
            PanelSubcategoriesPieSection(viewModel: viewModel, currencyCode: currencyCode, size: config.size, showVariations: showVariations, reduceMotion: reduceMotion)
        case .cashFlow:
            PanelCashFlowSection(viewModel: viewModel, sessionState: sessionState, size: config.size)
        case .latestRecords:
            PanelRecentRecordsSection(viewModel: viewModel, currencyCode: currencyCode)
        case .expensesByNeed:
            PanelNeedTrendSection(viewModel: viewModel, currencyCode: currencyCode, size: config.size, showVariations: showVariations, reduceMotion: reduceMotion)
        case .exchangeRate:
            PanelExchangeRateSection(viewModel: viewModel, currencyCode: currencyCode)
        case .budgets:
            PanelBudgetsSection(viewModel: viewModel, sessionState: sessionState, currencyCode: currencyCode, size: config.size, showBudgetFavoritesSettings: $showBudgetFavoritesSettings)
        case .scheduledPayments:
            PanelScheduledPaymentsSection(viewModel: viewModel, sessionState: sessionState, currencyCode: currencyCode, mode: config.scheduledPaymentsMode)
        case .weekdayBar:
            WeekdayBarPanelWidget(
                data: viewModel.weekdayWidget.weekdaySpending,
                currencyCode: currencyCode
            )
        case .tagsPie:
            PanelTagsPieSection(
                viewModel: viewModel,
                sessionState: sessionState,
                currencyCode: currencyCode,
                showVariations: showVariations,
                reduceMotion: reduceMotion
            )
        }
    }
}

// MARK: - Trend

private struct PanelTrendSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let currencyCode: String

    var body: some View {
        TrendsCarouselWidget(
            viewModel: viewModel,
            sessionState: sessionState,
            currencyCode: currencyCode,
            currentBalance: viewModel.currentBalance
        )
    }
}

// MARK: - Top Categories

private struct PanelCategoriesSection: View {
    let viewModel: PanelViewModel
    let currencyCode: String
    let size: WidgetSize
    let showVariations: Bool
    let reduceMotion: Bool

    var body: some View {
        TopCategoriesWidget(
            categories: viewModel.topSpendingCategories,
            currencyCode: currencyCode,
            selectedCategoryID: viewModel.selectedCategoryID,
            isExcludeMode: viewModel.isExcludeMode,
            onSelectCategory: { id in
                dsWithAnimation(reduceMotion) {
                    viewModel.toggleCategoryFilter(id)
                }
            },
            onShowMore: { viewModel.navigateToStatistics(.categories) },
            size: mapWidgetSize(size),
            period: viewModel.selectedPeriod,
            previousTotalAmount: viewModel.previousCategoriesTotalAmount,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
        )
    }
}

// MARK: - Top Subcategories

private struct PanelSubcategoriesSection: View {
    @Bindable var viewModel: PanelViewModel
    let currencyCode: String
    let size: WidgetSize
    let showVariations: Bool
    let reduceMotion: Bool

    var body: some View {
        TopSubcategoriesWidget(
            subcategories: viewModel.topSubcategories,
            currencyCode: currencyCode,
            globalCategoryFilterID: viewModel.selectedCategoryID,
            localCategoryFilterID: $viewModel.subcategoriesWidgetFilter,
            onSelectSubcategory: { subcategoryID in
                dsWithAnimation(reduceMotion) {
                    viewModel.toggleSubcategoryFilterFromPanel(subcategoryID)
                }
            },
            selectedSubcategoryIDs: viewModel.selectedSubcategoryIDs,
            isExcludeMode: viewModel.isExcludeMode,
            onShowMore: { viewModel.navigateToStatistics(.categories) },
            size: mapWidgetSize(size),
            period: viewModel.selectedPeriod,
            previousTotalAmount: viewModel.previousSubcategoriesTotalAmount,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
        )
    }
}

// MARK: - Categories Pie

private struct PanelCategoriesPieSection: View {
    let viewModel: PanelViewModel
    let currencyCode: String
    let size: WidgetSize
    let showVariations: Bool
    let reduceMotion: Bool

    var body: some View {
        CategoriesPieWidget(
            categories: viewModel.topSpendingCategories,
            currencyCode: currencyCode,
            selectedCategoryIDs: viewModel.selectedCategoryID.map { Set([$0]) } ?? [],
            onSelectCategory: { id in
                dsWithAnimation(reduceMotion) {
                    viewModel.toggleCategoryFilter(id)
                }
            },
            onShowDetail: { viewModel.navigateToStatistics(.categories) },
            isExcludeMode: viewModel.isExcludeMode,
            size: size,
            period: viewModel.selectedPeriod,
            previousTotalAmount: viewModel.previousCategoriesTotalAmount,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
        )
    }
}

// MARK: - Subcategories Pie

private struct PanelSubcategoriesPieSection: View {
    let viewModel: PanelViewModel
    let currencyCode: String
    let size: WidgetSize
    let showVariations: Bool
    let reduceMotion: Bool

    var body: some View {
        SubcategoriesPieWidget(
            subcategories: viewModel.topSubcategories,
            currencyCode: currencyCode,
            selectedCategoryID: viewModel.selectedCategoryID,
            selectedSubcategoryIDs: viewModel.selectedSubcategoryIDs,
            onSelectSubcategory: { subcategoryID in
                dsWithAnimation(reduceMotion) {
                    viewModel.toggleSubcategoryFilterFromPanel(subcategoryID)
                }
            },
            onShowDetail: { viewModel.navigateToStatistics(.categories) },
            isExcludeMode: viewModel.isExcludeMode,
            size: size,
            period: viewModel.selectedPeriod,
            previousTotalAmount: viewModel.previousSubcategoriesTotalAmount,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
        )
    }
}

// MARK: - Tags Pie (P20-09)

private struct PanelTagsPieSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let currencyCode: String
    let showVariations: Bool
    let reduceMotion: Bool

    var body: some View {
        TagsPieWidget(
            tags: viewModel.topTags,
            currencyCode: currencyCode,
            selectedTagIDs: viewModel.selectedTags,
            onSelectTag: { id in
                dsWithAnimation(reduceMotion) {
                    viewModel.toggleTagFilter(id)
                }
            },
            onShowDetail: { viewModel.navigateToStatistics(.categories) },
            isExcludeMode: viewModel.isExcludeMode,
            size: .large,
            period: viewModel.selectedPeriod,
            customRange: sessionState.customDateRange,
            previousTotalAmount: viewModel.previousTagsTotalAmount,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
        )
    }
}

// MARK: - Cash Flow

private struct PanelCashFlowSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let size: WidgetSize

    var body: some View {
        if let summary = viewModel.cashFlowSummary {
            CashFlowWidget(
                summary: summary,
                size: size,
                period: viewModel.selectedPeriod.rawValue,
                grouping: viewModel.cashFlowGrouping,
                interval: viewModel.currentInterval,
                onShowDetail: { viewModel.navigateToStatistics(.trends) },
                displayMode: viewModel.trendType,
                selectedTransactionNatures: viewModel.selectedTransactionNatures,
                isExpensesOnlyMode: sessionState.isExpensesOnlyMode
            )
        } else {
            YalaEmptyState(
                icon: "chart.bar.fill",
                title: L10n.Empty.noData,
                message: L10n.Statistics.noRecordsDescription
            )
            .frame(height: 200)
        }
    }
}

// MARK: - Recent Records

private struct PanelRecentRecordsSection: View {
    let viewModel: PanelViewModel
    let currencyCode: String

    var body: some View {
        RecentRecordsWidget(
            records: viewModel.latestRecords,
            currencyCode: currencyCode,
            onShowMore: { viewModel.navigateToStatistics(.records) }
        )
    }
}

// MARK: - Need Trend

private struct PanelNeedTrendSection: View {
    let viewModel: PanelViewModel
    let currencyCode: String
    let size: WidgetSize
    let showVariations: Bool
    let reduceMotion: Bool

    var body: some View {
        NeedTrendWidget(
            trendPoints: viewModel.needTrendPoints,
            selectedNeed: viewModel.selectedNeed,
            currencyCode: currencyCode,
            size: mapWidgetSize(size),
            grouping: viewModel.needGrouping,
            interval: viewModel.currentInterval,
            onSelectNeed: { need in
                dsWithAnimation(reduceMotion) {
                    viewModel.toggleNeedFilter(need)
                }
            },
            onShowDetail: { viewModel.navigateToStatistics(.categories) },
            period: viewModel.selectedPeriod,
            previousTotalAmount: viewModel.previousNeedTotalAmount,
            previousAmountByNeed: viewModel.previousNeedAmounts,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime,
            isIncomeMode: viewModel.selectedTransactionNatures == [.income]
        )
    }
}

// MARK: - Exchange Rate

private struct PanelExchangeRateSection: View {
    @Bindable var viewModel: PanelViewModel
    let currencyCode: String

    var body: some View {
        ExchangeRateWidget(
            data: viewModel.exchangeRateWidgetData,
            preferredCurrency: currencyCode,
            selectedCurrencies: $viewModel.selectedComparisonCurrencies,
            grouping: viewModel.exchangeRateGrouping,
            onShowDetail: nil
        )
    }
}

// MARK: - Budgets

private struct PanelBudgetsSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let currencyCode: String
    let size: WidgetSize
    @Binding var showBudgetFavoritesSettings: Bool

    var body: some View {
        let selectedBudget = sessionState.selectedBudgetID.flatMap { selectedID in
            viewModel.topBudgetSummaries.first { $0.budget.persistentModelID == selectedID }?.budget
        }
        let displayCurrency = selectedBudget?.currencyCode ?? currencyCode

        BudgetsWidget(
            budgets: viewModel.topBudgetSummaries,
            currencyCode: displayCurrency,
            hasBudgetsButNoFavorites: viewModel.hasBudgetsButNoFavorites,
            selectedBudgetID: sessionState.selectedBudgetID,
            isExcludeMode: viewModel.isExcludeMode,
            onSelectBudget: { budget in
                sessionState.applyBudgetFilters(budget)
            },
            onShowMore: { sessionState.navigateToBudgets() },
            onEditFavorites: { showBudgetFavoritesSettings = true },
            size: mapBudgetsWidgetSize(size)
        )
    }
}

// MARK: - Scheduled Payments

private struct PanelScheduledPaymentsSection: View {
    @Bindable var viewModel: PanelViewModel
    let sessionState: SessionState
    let currencyCode: String
    let mode: ScheduledPaymentsWidgetMode

    var body: some View {
        ScheduledPaymentsWidget(
            data: viewModel.scheduledPaymentsWidget,
            currencyCode: currencyCode,
            mode: mode,
            filter: $viewModel.scheduledPaymentsWidgetFilter,
            onShowMore: { sessionState.navigateToScheduledPayments() }
        )
    }
}

// MARK: - Helpers

private func mapWidgetSize(_ size: WidgetSize) -> TopCategoriesWidget.CardSize {
    switch size {
    case .medium: return .medium
    case .large: return .large
    }
}

private func mapBudgetsWidgetSize(_ size: WidgetSize) -> BudgetsWidget.CardSize {
    switch size {
    case .medium: return .medium
    case .large: return .large
    }
}
