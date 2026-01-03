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
    var size: WidgetSize = .medium
    var currencyCode: String
    var currentBalance: Double

    @Namespace private var animationNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                chartHeight: 220
            )
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Components

    private var chartHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chartTitle)
                    .font(.headline)
                    .foregroundStyle(Color.netoPrimaryText)

                // Prominent KPI Value
                Text(currentKPIValue)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.netoPrimaryText)
                    .padding(.top, 4)
            }

            Spacer()

            // Metric selector
            metricSelector
        }
    }

    private var metricSelector: some View {
        HStack(spacing: 0) {
            ForEach(TrendType.allCases) { type in
                metricButton(for: type)
            }
        }
        .padding(3)
        .background(Color.netoSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func metricButton(for type: TrendType) -> some View {
        let isSelected = viewModel.trendType == type

        return Button {
            // Change metric - onChange in PanelView handles recalculation
            viewModel.trendType = type

            // Apply smooth animation for UI transition
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                // Triggers SwiftUI re-evaluation
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.iconName)
                    .font(.caption.weight(.semibold))
                if isSelected {
                    Text(type.rawValue)
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, isSelected ? 12 : 10)
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
}
