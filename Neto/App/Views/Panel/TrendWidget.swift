//
//  TrendWidget.swift
//  Neto
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

    /// Check if expense-only filters are active (category/subcategory/nature)
    private var hasExpenseOnlyFilters: Bool {
        !sessionState.selectedCategoryIDs.isEmpty
            || !sessionState.selectedSubcategoryIDs.isEmpty
            || !sessionState.selectedNatures.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header with KPI
            chartHeader

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
        .padding(DS.Card.padding)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Card.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Card.radius, style: .continuous)
                .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
        )
        .dsCardShadow()
        .overlay(alignment: .top) {
            if showFilterBlockedMessage {
                Text(L10n.Trend.filterBlockedMessage)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Color.netoSecondaryText.opacity(0.9))
                    .clipShape(Capsule())
                    .padding(.top, DS.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onTapGesture {
                        showFilterBlockedMessage = false
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showFilterBlockedMessage)
    }

    // MARK: - Components

    private var chartHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(chartTitle)
                    .font(.headline)
                    .foregroundStyle(Color.netoPrimaryText)

                // Prominent KPI Value
                Text(currentKPIValue)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.netoPrimaryText)
                    .padding(.top, DS.Spacing.xs)
            }

            Spacer()

            // Metric selector
            metricSelector
        }
    }

    private var metricSelector: some View {
        HStack(spacing: 0) {
            // Always show all options - user can switch freely
            ForEach(TrendType.allCases) { type in
                metricButton(for: type)
            }
        }
        .padding(DS.Spacing.xxs)
        .background(Color.netoSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func metricButton(for type: TrendType) -> some View {
        let isSelected = viewModel.trendType == type
        // Block balance/income when expense-only filters are active
        let isBlocked = hasExpenseOnlyFilters && type != .expense

        return Button {
            if isBlocked {
                // Show help message instead of changing
                showFilterBlockedMessage = true
                // Auto-hide after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showFilterBlockedMessage = false
                }
            } else {
                // Set global transaction nature filter - metric auto-adjusts via enforceTrendLock()
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
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: type.iconName)
                    .font(.caption.weight(.semibold))
                // Show label only when selected
                if isSelected {
                    Text(title(for: type))
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, isSelected ? 12 : 14)
            .padding(.vertical, DS.Spacing.sm)
            .foregroundStyle(isSelected ? .white : (isBlocked ? type.color.opacity(0.4) : type.color))
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(type.color)
                            .matchedGeometryEffect(id: "metricSelector", in: animationNamespace)
                    }
                }
            )
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
            return NetoFormatter.currency(value: point.value, currencyCode: currencyCode)
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

        return NetoFormatter.currency(value: value, currencyCode: currencyCode)
    }

    private func title(for type: TrendType) -> String {
        switch type {
        case .balance: return L10n.TrendType.balance
        case .income: return L10n.TrendType.income
        case .expense: return L10n.TrendType.expense
        }
    }
}
