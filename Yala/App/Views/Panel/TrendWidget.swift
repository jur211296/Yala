//
//  TrendWidget.swift
//  Yala
//
//  Created for Panel Refresh.
//

import Charts
import SwiftData
import SwiftUI

struct TrendWidget: View {
    @Bindable var viewModel: PanelViewModel
    @Bindable var sessionState: SessionState
    var currencyCode: String
    var currentBalance: Double

    @Namespace private var animationNamespace
    @State private var showFilterBlockedMessage: Bool = false

    /// Check if any category/subcategory/need filters are active
    private var hasCategoryFilters: Bool {
        guard !sessionState.isExcludeMode else { return false }
        return !sessionState.selectedCategoryIDs.isEmpty
            || !sessionState.selectedSubcategoryIDs.isEmpty
            || !sessionState.selectedNeeds.isEmpty
    }

    /// Check if we have no data to display
    private var hasNoData: Bool {
        viewModel.processedTrendPoints.isEmpty
    }

    var body: some View {
        let _ = viewModel.dataVersion
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header - simplified when no data
            chartHeader

            if hasNoData {
                // Empty state
                emptyStateView
            } else {
                // Chart using TrendChartView
                // Always use dataTrendType for color to ensure data and color are always in sync
                // This eliminates the need for loading indicators during metric transitions
                TrendChartView(
                    trendPoints: viewModel.processedTrendPoints,
                    rawPoints: viewModel.rawTrendPoints,
                    yDomain: viewModel.processedYDomain,
                    grouping: viewModel.trendGrouping,
                    interval: viewModel.currentInterval,
                    currencyCode: currencyCode,
                    trendType: viewModel.dataTrendType,  // Use dataTrendType for guaranteed color sync
                    focusedDate: $viewModel.focusedDate,
                    period: viewModel.currentPeriod,
                    chartHeight: 160  // Fixed compact size
                )
                .padding(.top, DS.Spacing.sm)
            }
        }
        .padding(DS.Card.padding)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Card.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Card.radius, style: .continuous)
                .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
        )
        .dsCardShadow()
    }

    // MARK: - Components

    private var chartHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(chartTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)

                // Prominent KPI Value - only show when we have data
                if !hasNoData {
                    Text(currentKPIValue)
                        .font(DS.Typography.title)
                        .foregroundStyle(.thPrimaryText)
                        .padding(.top, DS.Spacing.xs)
                }
            }

            InfoHintButton(
                title: L10n.WidgetType.trend,
                message: L10n.Widget.Hint.trend
            )

            Spacer()

            // Metric selector (hidden in expenses-only mode)
            if !sessionState.isExpensesOnlyMode {
                metricSelector
            }
        }
    }

    private var emptyStateView: some View {
        YalaEmptyState(icon: "chart.line.uptrend.xyaxis", title: L10n.Empty.noData, style: .widget)
            .frame(height: 160)
    }

    private var metricSelector: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(TrendType.allCases) { type in
                metricButton(for: type)
            }
        }
        .filterBlockedPopover(
            isPresented: $showFilterBlockedMessage,
            title: L10n.Trend.filterBlockedTitle,
            message: L10n.Trend.filterBlockedMessage
        )
    }

    private func metricButton(for type: TrendType) -> some View {
        let isSelected = viewModel.trendType == type
        let isBlocked: Bool = {
            guard hasCategoryFilters else { return false }
            guard let nature = sessionState.activeFilterNature else { return false }
            switch nature {
            case .expense: return type != .expense
            case .income: return type != .income
            }
        }()

        return Button {
            if isBlocked {
                showFilterBlockedMessage = true
            } else {
                switch type {
                case .balance:
                    sessionState.selectedTransactionNatures.removeAll()
                case .income:
                    sessionState.selectedTransactionNatures = [.income]
                case .expense:
                    sessionState.selectedTransactionNatures = [.expense]
                }
            }
        } label: {
            Image(systemName: type.iconName)
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : (isBlocked ? type.color.opacity(0.4) : type.color))
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(type.color)
                            .matchedGeometryEffect(id: "metricBg", in: animationNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var chartTitle: String {
        switch viewModel.trendType {
        case .balance: return L10n.Trend.balanceTitle
        case .income: return L10n.Trend.incomeTitle
        case .expense: return L10n.Trend.expenseTitle
        }
    }

    private var currentKPIValue: String {
        // Show the value for the focused date if scrubbing (use raw points, not smoothed)
        if let focusedDate = viewModel.focusedDate,
            let point = viewModel.rawTrendPoints.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: focusedDate)
            })
        {
            return YalaFormatter.currency(value: point.value, currencyCode: currencyCode)
        }

        // Otherwise logic depends on type
        // Use unified KPI values from TrendDataProcessor
        let value: Double
        switch viewModel.trendType {
        case .balance:
            // Balance: use the actual final balance before smoothing
            value = viewModel.trendFinalBalance
        case .income:
            // For Income: Show TOTAL income from TrendDataProcessor
            value = viewModel.trendTotalIncome
        case .expense:
            // For Expense: Show TOTAL expense from TrendDataProcessor
            value = viewModel.trendTotalExpense
        }

        return YalaFormatter.currency(value: value, currencyCode: currencyCode)
    }

    private func title(for type: TrendType) -> String {
        switch type {
        case .balance: return L10n.TrendType.balance
        case .income: return L10n.TrendType.income
        case .expense: return L10n.TrendType.expense
        }
    }
}
