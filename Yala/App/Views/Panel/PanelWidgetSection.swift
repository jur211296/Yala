//
//  PanelWidgetSection.swift
//  Yala
//
//  Widget wrapper views that isolate @Observable tracking from PanelView's body.
//  Each section reads only its own slice of PanelViewModel in its own body scope.
//

import SwiftData
import SwiftUI

// MARK: - Widget Router

/// Routes a WidgetConfig to the appropriate section wrapper.
/// Reads only `config.type` in PanelView's body — all ViewModel reads happen in child bodies.
struct PanelWidgetRouter: View {
    let config: WidgetConfig
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let currencyCode: String
    let showVariations: Bool
    let reduceMotion: Bool
    let onNavigate: (DetailViewTab) -> Void
    let onEditBudgetFavorites: () -> Void

    var body: some View {
        switch config.type {
        case .trend:
            PanelTrendSection(viewModel: viewModel, sessionState: sessionState, currencyCode: currencyCode)
        case .topSpending:
            PanelCategoriesSection(viewModel: viewModel, currencyCode: currencyCode, size: config.size, showVariations: showVariations, reduceMotion: reduceMotion, onNavigate: onNavigate)
        case .topSubcategories:
            PanelSubcategoriesSection(viewModel: viewModel, currencyCode: currencyCode, size: config.size, showVariations: showVariations, reduceMotion: reduceMotion, onNavigate: onNavigate)
        case .categoriesPie:
            PanelCategoriesPieSection(viewModel: viewModel, currencyCode: currencyCode, size: config.size, showVariations: showVariations, reduceMotion: reduceMotion, onNavigate: onNavigate)
        case .subcategoriesPie:
            PanelSubcategoriesPieSection(viewModel: viewModel, currencyCode: currencyCode, size: config.size, showVariations: showVariations, reduceMotion: reduceMotion, onNavigate: onNavigate)
        case .cashFlow:
            PanelCashFlowSection(viewModel: viewModel, sessionState: sessionState, size: config.size, onNavigate: onNavigate)
        case .latestRecords:
            PanelRecentRecordsSection(viewModel: viewModel, currencyCode: currencyCode, onNavigate: onNavigate)
        case .expensesByNeed:
            PanelNeedTrendSection(viewModel: viewModel, currencyCode: currencyCode, size: config.size, showVariations: showVariations, reduceMotion: reduceMotion, onNavigate: onNavigate)
        case .exchangeRate:
            PanelExchangeRateSection(viewModel: viewModel, currencyCode: currencyCode)
        case .budgets:
            PanelBudgetsSection(viewModel: viewModel, sessionState: sessionState, currencyCode: currencyCode, size: config.size, onNavigate: onNavigate, onEditFavorites: onEditBudgetFavorites)
        case .scheduledPayments:
            PanelScheduledPaymentsSection(viewModel: viewModel, sessionState: sessionState, currencyCode: currencyCode, mode: config.scheduledPaymentsMode, onNavigate: onNavigate)
        }
    }
}

// MARK: - Trend

private struct PanelTrendSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let currencyCode: String

    var body: some View {
        TrendWidget(
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
    let onNavigate: (DetailViewTab) -> Void

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
            onShowMore: { onNavigate(.categories) },
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
    let onNavigate: (DetailViewTab) -> Void

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
            onShowMore: { onNavigate(.categories) },
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
    let onNavigate: (DetailViewTab) -> Void

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
            onShowDetail: { onNavigate(.categories) },
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
    let onNavigate: (DetailViewTab) -> Void

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
            onShowDetail: { onNavigate(.categories) },
            isExcludeMode: viewModel.isExcludeMode,
            size: size,
            period: viewModel.selectedPeriod,
            previousTotalAmount: viewModel.previousSubcategoriesTotalAmount,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
        )
    }
}

// MARK: - Cash Flow

private struct PanelCashFlowSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let size: WidgetSize
    let onNavigate: (DetailViewTab) -> Void

    var body: some View {
        if let summary = viewModel.cashFlowSummary {
            CashFlowWidget(
                summary: summary,
                size: size,
                period: viewModel.selectedPeriod.rawValue,
                grouping: viewModel.cashFlowGrouping,
                interval: viewModel.currentInterval,
                onShowDetail: { onNavigate(.trends) },
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
    let onNavigate: (DetailViewTab) -> Void

    var body: some View {
        RecentRecordsWidget(
            records: viewModel.latestRecords,
            currencyCode: currencyCode,
            onShowMore: { onNavigate(.records) }
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
    let onNavigate: (DetailViewTab) -> Void

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
            onShowDetail: { onNavigate(.categories) },
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
    let onNavigate: (DetailViewTab) -> Void
    let onEditFavorites: () -> Void

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
            onEditFavorites: onEditFavorites,
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
    let onNavigate: (DetailViewTab) -> Void

    var body: some View {
        ScheduledPaymentsWidget(
            payments: viewModel.scheduledPayments,
            currencyCode: currencyCode,
            period: viewModel.selectedPeriod,
            customDateRange: sessionState.customDateRange,
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
