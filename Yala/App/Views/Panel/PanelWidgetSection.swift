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
            PanelTrendSection(viewModel: viewModel, sessionState: sessionState, currencyCode: currencyCode, size: config.size)
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
            PanelScheduledPaymentsSection(viewModel: viewModel, sessionState: sessionState, currencyCode: currencyCode, size: config.size)
        case .weekdayBar:
            WeekdayBarPanelWidget(
                data: viewModel.weekdayWidget.weekdaySpending,
                currencyCode: currencyCode,
                size: config.size,
                onShowMore: { viewModel.navigateToStatistics(.insights) }
            )
        case .tagsPie:
            PanelTagsPieSection(
                viewModel: viewModel,
                sessionState: sessionState,
                currencyCode: currencyCode,
                size: config.size,
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
    let size: WidgetSize

    var body: some View {
        TrendsCarouselWidget(
            viewModel: viewModel,
            sessionState: sessionState,
            currencyCode: currencyCode,
            currentBalance: viewModel.currentBalance,
            size: size,
            onShowMore: { viewModel.navigateToStatistics(.trends) },
            headerInfoButton: trendInfoButton
        )
    }

    /// Botón info pedagógico inyectado en el header del Trend. El preview
    /// reusa el VM real (con sus datos actuales) — la gráfica de Trend está
    /// fuertemente acoplada a múltiples propiedades del VM (processedTrendPoints,
    /// rawTrendPoints, processedYDomain, trendType) que no se cargan en un VM
    /// sample minimal sin re-correr el pipeline completo de cálculo.
    private var trendInfoButton: AnyView? {
        AnyView(
            WidgetInfoButton(kind: .trend, viewModel: viewModel) { previewSize in
                TrendsCarouselWidget(
                    viewModel: viewModel,
                    sessionState: sessionState,
                    currencyCode: currencyCode,
                    currentBalance: viewModel.currentBalance,
                    size: previewSize,
                    onShowMore: nil
                )
                .allowsHitTesting(false)
            }
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
            headerInfoButton: topCategoriesInfoButton,
            period: viewModel.selectedPeriod,
            previousTotalAmount: viewModel.previousCategoriesTotalAmount,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
        )
    }

    /// Botón info pedagógico inyectado en el header. Reusa las categorías reales
    /// del VM (@Model) — empty state visual si el user no tiene categorías.
    private var topCategoriesInfoButton: AnyView? {
        AnyView(
            WidgetInfoButton(kind: .topCategories, viewModel: viewModel) { previewSize in
                TopCategoriesWidget(
                    categories: viewModel.topSpendingCategories,
                    currencyCode: currencyCode,
                    selectedCategoryID: nil,
                    isExcludeMode: false,
                    onSelectCategory: nil,
                    onShowMore: nil,
                    size: mapWidgetSize(previewSize),
                    period: viewModel.selectedPeriod,
                    previousTotalAmount: nil,
                    showVariationHeader: false
                )
                .allowsHitTesting(false)
            }
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
            headerInfoButton: topSubcategoriesInfoButton,
            period: viewModel.selectedPeriod,
            previousTotalAmount: viewModel.previousSubcategoriesTotalAmount,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
        )
    }

    /// Botón info pedagógico inyectado en el header. Reusa el VM real
    /// (subcategorías @Model) — respeta el filtro global y local existentes.
    private var topSubcategoriesInfoButton: AnyView? {
        AnyView(
            WidgetInfoButton(kind: .topSubcategories, viewModel: viewModel) { previewSize in
                TopSubcategoriesWidget(
                    subcategories: viewModel.topSubcategories,
                    currencyCode: currencyCode,
                    globalCategoryFilterID: viewModel.selectedCategoryID,
                    localCategoryFilterID: .constant(viewModel.subcategoriesWidgetFilter),
                    onSelectSubcategory: nil,
                    selectedSubcategoryIDs: [],
                    isExcludeMode: false,
                    onShowMore: nil,
                    size: mapWidgetSize(previewSize),
                    period: viewModel.selectedPeriod,
                    previousTotalAmount: nil,
                    showVariationHeader: false
                )
                .allowsHitTesting(false)
            }
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
            headerInfoButton: categoriesPieInfoButton,
            period: viewModel.selectedPeriod,
            previousTotalAmount: viewModel.previousCategoriesTotalAmount,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
        )
    }

    /// Botón info pedagógico inyectado en el header. El preview reusa el VM real
    /// (categorías @Model) — si está vacío, el widget muestra su empty state.
    /// `.allowsHitTesting(false)` aísla los gestos del preview del Panel.
    private var categoriesPieInfoButton: AnyView? {
        AnyView(
            WidgetInfoButton(kind: .categoriesPie, viewModel: viewModel) { previewSize in
                CategoriesPieWidget(
                    categories: viewModel.topSpendingCategories,
                    currencyCode: currencyCode,
                    selectedCategoryIDs: [],
                    onSelectCategory: nil,
                    onShowDetail: nil,
                    isExcludeMode: false,
                    size: previewSize,
                    period: viewModel.selectedPeriod,
                    previousTotalAmount: nil,
                    showVariationHeader: false
                )
                .allowsHitTesting(false)
            }
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
            headerInfoButton: subcategoriesPieInfoButton,
            period: viewModel.selectedPeriod,
            previousTotalAmount: viewModel.previousSubcategoriesTotalAmount,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
        )
    }

    /// Botón info pedagógico inyectado en el header. El preview reusa el VM real
    /// (subcategorías @Model) — respeta el filtro de categoría global existente.
    private var subcategoriesPieInfoButton: AnyView? {
        AnyView(
            WidgetInfoButton(kind: .subcategoriesPie, viewModel: viewModel) { previewSize in
                SubcategoriesPieWidget(
                    subcategories: viewModel.topSubcategories,
                    currencyCode: currencyCode,
                    selectedCategoryID: viewModel.selectedCategoryID,
                    selectedSubcategoryIDs: [],
                    onSelectSubcategory: nil,
                    onShowDetail: nil,
                    isExcludeMode: false,
                    size: previewSize,
                    period: viewModel.selectedPeriod,
                    previousTotalAmount: nil,
                    showVariationHeader: false
                )
                .allowsHitTesting(false)
            }
        )
    }
}

// MARK: - Tags Pie (P20-09)

private struct PanelTagsPieSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let currencyCode: String
    let size: WidgetSize
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
            size: size,
            headerInfoButton: tagsPieInfoButton,
            period: viewModel.selectedPeriod,
            customRange: sessionState.customDateRange,
            previousTotalAmount: viewModel.previousTagsTotalAmount,
            showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
        )
    }

    /// Botón info pedagógico inyectado en el header. El preview reusa los tags
    /// reales del VM (@Model) — empty state visual si el user no tiene tags.
    private var tagsPieInfoButton: AnyView? {
        AnyView(
            WidgetInfoButton(kind: .tagsPie, viewModel: viewModel) { previewSize in
                TagsPieWidget(
                    tags: viewModel.topTags,
                    currencyCode: currencyCode,
                    selectedTagIDs: [],
                    onSelectTag: nil,
                    onShowDetail: nil,
                    isExcludeMode: false,
                    size: previewSize,
                    period: viewModel.selectedPeriod,
                    customRange: sessionState.customDateRange,
                    previousTotalAmount: nil,
                    showVariationHeader: false
                )
                .allowsHitTesting(false)
            }
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
                previousAmount: viewModel.cashFlowPreviousNet,
                selectedTransactionNatures: viewModel.selectedTransactionNatures,
                isExpensesOnlyMode: sessionState.isExpensesOnlyMode,
                headerInfoButton: cashFlowInfoButton(realSummary: summary)
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

    /// Botón info pedagógico inyectado en el header del CashFlow. El preview
    /// reusa el summary real cuando hay datos; sino el `previewSample`.
    private func cashFlowInfoButton(realSummary: CashFlowSummary) -> AnyView {
        AnyView(
            WidgetInfoButton(kind: .cashFlow, viewModel: viewModel) { previewSize in
                CashFlowWidget(
                    summary: realSummary.chartData.isEmpty ? .previewSample : realSummary,
                    size: previewSize,
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
                .allowsHitTesting(false)
            }
        )
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
            onShowMore: { viewModel.navigateToStatistics(.records) },
            headerInfoButton: recentRecordsInfoButton
        )
    }

    /// Botón info pedagógico inyectado en el header. Reusa el VM real
    /// (TransactionItem @Model) — empty state visual si el VM no tiene datos.
    private var recentRecordsInfoButton: AnyView? {
        AnyView(
            WidgetInfoButton(kind: .recentRecords, viewModel: viewModel) { _ in
                RecentRecordsWidget(
                    records: viewModel.latestRecords,
                    currencyCode: currencyCode,
                    onShowMore: nil
                )
                .allowsHitTesting(false)
            }
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

    private var isIncomeMode: Bool {
        viewModel.selectedTransactionNatures == [.income]
    }

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
            isIncomeMode: isIncomeMode,
            headerInfoButton: needTrendInfoButton
        )
    }

    /// Botón info pedagógico inyectado en el header. Si el VM no tiene puntos
    /// reales, el preview cae a `[NeedTrendPoint].previewSample` (struct simple,
    /// no @Model). Propaga `isIncomeMode` real para no divergir del estado actual.
    private var needTrendInfoButton: AnyView? {
        AnyView(
            WidgetInfoButton(kind: .expensesByNeed, viewModel: viewModel) { previewSize in
                let previewPoints = viewModel.needTrendPoints.isEmpty
                    ? [NeedTrendPoint].previewSample
                    : viewModel.needTrendPoints
                NeedTrendWidget(
                    trendPoints: previewPoints,
                    selectedNeed: nil,
                    currencyCode: currencyCode,
                    size: mapWidgetSize(previewSize),
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
                .allowsHitTesting(false)
            }
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
            grouping: viewModel.exchangeRateGrouping
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
            size: mapBudgetsWidgetSize(size),
            headerInfoButton: budgetsInfoButton(displayCurrency: displayCurrency)
        )
    }

    /// Botón info pedagógico inyectado en el header. Propaga `hasBudgetsButNoFavorites`
    /// real para no divergir del estado actual del usuario en el preview.
    private func budgetsInfoButton(displayCurrency: String) -> AnyView? {
        AnyView(
            WidgetInfoButton(kind: .budgets, viewModel: viewModel) { previewSize in
                BudgetsWidget(
                    budgets: viewModel.topBudgetSummaries,
                    currencyCode: displayCurrency,
                    hasBudgetsButNoFavorites: viewModel.hasBudgetsButNoFavorites,
                    selectedBudgetID: nil,
                    isExcludeMode: false,
                    onSelectBudget: nil,
                    onShowMore: nil,
                    onEditFavorites: nil,
                    size: mapBudgetsWidgetSize(previewSize)
                )
                .allowsHitTesting(false)
            }
        )
    }
}

// MARK: - Scheduled Payments

private struct PanelScheduledPaymentsSection: View {
    @Bindable var viewModel: PanelViewModel
    let sessionState: SessionState
    let currencyCode: String
    let size: WidgetSize

    var body: some View {
        ScheduledPaymentsWidget(
            data: viewModel.scheduledPaymentsWidget,
            currencyCode: currencyCode,
            size: size,
            filter: $viewModel.scheduledPaymentsWidgetFilter,
            onShowMore: { sessionState.navigateToScheduledPayments() },
            headerInfoButton: scheduledPaymentsInfoButton
        )
    }

    /// Botón info pedagógico inyectado en el header. Reusa el VM real con
    /// `filter` actual del binding (sin scrubbing) — `.constant` para el preview
    /// porque no debe mutar el filter del Panel.
    private var scheduledPaymentsInfoButton: AnyView? {
        AnyView(
            WidgetInfoButton(kind: .scheduledPayments, viewModel: viewModel) { previewSize in
                ScheduledPaymentsWidget(
                    data: viewModel.scheduledPaymentsWidget,
                    currencyCode: currencyCode,
                    size: previewSize,
                    filter: .constant(viewModel.scheduledPaymentsWidgetFilter),
                    onShowMore: nil
                )
                .allowsHitTesting(false)
            }
        )
    }
}

// MARK: - Helpers

private func mapWidgetSize(_ size: WidgetSize) -> TopCategoriesWidget.CardSize {
    switch size {
    case .small: return .small
    case .medium: return .medium
    case .large: return .large
    }
}

private func mapBudgetsWidgetSize(_ size: WidgetSize) -> BudgetsWidget.CardSize {
    // PP2-06b: BudgetsWidget.CardSize now matches WidgetSize 1:1.
    switch size {
    case .small: return .small
    case .medium: return .medium
    case .large: return .large
    }
}
