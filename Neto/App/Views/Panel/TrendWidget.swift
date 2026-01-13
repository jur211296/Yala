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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header with KPI
            chartHeader

            // Chart using TrendChartView
            // Always use dataTrendType for color to ensure data and color are always in sync
            // This eliminates the need for loading indicators during metric transitions
            TrendChartView(
                trendPoints: viewModel.processedTrendPoints,
                yDomain: viewModel.processedYDomain,
                grouping: viewModel.trendGrouping,
                interval: viewModel.currentInterval,
                currencyCode: currencyCode,
                trendType: viewModel.dataTrendType,  // Use dataTrendType for guaranteed color sync
                focusedDate: $viewModel.focusedDate,
                period: viewModel.currentPeriod,
                chartHeight: 160  // Fixed compact size
            )
            .padding(.top, 8)
        }
        .padding(DS.Card.padding)
        .background(Color.netoCard)
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
            // When locked to expense (filters applied), only show expense button
            // Otherwise show all options
            ForEach(availableMetricTypes) { type in
                metricButton(for: type)
            }
        }
        .padding(3)
        .background(Color.netoSecondaryText.opacity(0.08))
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.2), value: viewModel.isTrendLockedToExpense)
    }

    /// Returns available metric types based on filter state
    private var availableMetricTypes: [TrendType] {
        if viewModel.isTrendLockedToExpense {
            return [.expense]  // Only expense when filters are applied
        }
        return TrendType.allCases
    }

    private func metricButton(for type: TrendType) -> some View {
        let isSelected = viewModel.trendType == type
        let isLocked = viewModel.isTrendLockedToExpense

        return Button {
            // Only allow change if not locked
            guard !isLocked else { return }

            // Change metric manually (marks as user selection, not automatic)
            viewModel.setTrendTypeManually(type, sessionState: sessionState)

            // Apply smooth animation for UI transition
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                // Triggers SwiftUI re-evaluation
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.iconName)
                    .font(.caption.weight(.semibold))
                // When locked, always show the label since there's only one option
                if isSelected || isLocked {
                    Text(title(for: type))
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, isSelected || isLocked ? 12 : 10)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : type.color)
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
        // Show the value for the focused date if scrubbing
        if let focusedDate = viewModel.focusedDate,
            let point = viewModel.processedTrendPoints.first(where: {
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
            // For Balance: Show True Current Balance (not chart interactions)
            value = currentBalance
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
