//
//  TrendsCarouselWidget.swift
//  Yala
//
//  Unified Trends widget with 2-page carousel:
//  - Page 1: trend line chart (balance / income / expense)
//  - Page 2: period comparison chart (current vs previous)
//
//  Both pages share a single metric selector that writes to
//  `SessionState.selectedTransactionNatures` — the SSOT that also drives
//  the TrendsTab in Statistics.
//

import Charts
import SwiftData
import SwiftUI

struct TrendsCarouselWidget: View {
    @Bindable var viewModel: PanelViewModel
    @Bindable var sessionState: SessionState
    var currencyCode: String
    var currentBalance: Double
    var size: WidgetSize = .large
    var onShowMore: (() -> Void)? = nil

    @Environment(AppPreferences.self) private var appPreferences

    @Namespace private var animationNamespace
    @State private var showFilterBlockedMessage: Bool = false

    // MARK: - Data

    private var hasCategoryFilters: Bool {
        guard !sessionState.isExcludeMode else { return false }
        return !sessionState.selectedCategoryIDs.isEmpty
            || !sessionState.selectedSubcategoryIDs.isEmpty
            || !sessionState.selectedNeeds.isEmpty
    }

    private var hasNoTrendData: Bool {
        viewModel.processedTrendPoints.isEmpty
    }

    // MARK: - Body

    var body: some View {
        let _ = appPreferences.decimalPlaces
        let _ = appPreferences.currencyDisplayFormat

        if size == .small {
            smallBody
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header
                trendPage
                    .frame(height: 170)
            }
            .solidCard(padding: DS.Card.paddingCompact)
        }
    }

    // MARK: - Small layout (PP2-06c)
    // Forces .balance metric regardless of the user's global trend type selection:
    // the `.small` variant is a sparkline of the saldo, not a metric-switcher.

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PanelSmallWidgetHeader(
                title: L10n.TrendType.balance,
                accessibilityLabel: L10n.TrendType.balance,
                action: onShowMore
            )

            if hasNoTrendData {
                YalaEmptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    title: L10n.Empty.noData,
                    style: .widget
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(
                        YalaFormatter.currency(
                            value: viewModel.trendFinalBalance,
                            currencyCode: currencyCode,
                            forceSign: true
                        )
                    )
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                    // Variation chip — only when the global metric is balance,
                    // otherwise the comparison data belongs to a different metric.
                    if viewModel.trendType == .balance,
                       let delta = viewModel.periodComparisonWidget.deltaPercent {
                        VariationChip(
                            variation: delta,
                            size: .small,
                            isExpenseContext: false
                        )
                    }
                }

                TrendChartView(
                    trendPoints: viewModel.processedTrendPoints,
                    rawPoints: viewModel.rawTrendPoints,
                    yDomain: viewModel.processedYDomain,
                    grouping: viewModel.trendGrouping,
                    interval: viewModel.currentInterval,
                    currencyCode: currencyCode,
                    trendType: .balance,
                    focusedDate: .constant(nil),   // scrubbing disabled in .small
                    period: viewModel.currentPeriod,
                    chartHeight: 90,
                    compact: true
                )
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .solidCard(padding: DS.Card.paddingCompact)
        .frame(height: WidgetSize.smallHeight)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(trendTitle)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.thPrimaryText)

                if !hasNoTrendData {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text(currentKPIValue)
                            .font(DS.Typography.title)
                            .foregroundStyle(.thPrimaryText)

                        // "vs <previous total>" label — mirrors the CashFlow header pattern.
                        if let prevTotal = previousKPIValue {
                            Text("vs \(YalaFormatter.number(value: prevTotal))")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.thSecondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }

                        // Variation chip right of the "vs" label.
                        variationChip
                    }
                    .padding(.top, DS.Spacing.xs)
                }
            }

            Spacer()

            if !sessionState.isExpensesOnlyMode {
                metricSelector
            }
        }
    }

    /// Previous-period total for the currently selected metric, used to render the
    /// "vs …" label next to the KPI. Nil when comparison is unsupported (e.g. `.allTime`).
    private var previousKPIValue: Double? {
        let data = viewModel.periodComparisonWidget
        guard data.supportsComparison else { return nil }
        return data.previousTotal
    }

    /// Delta % chip rendered inline to the right of the "vs …" label.
    @ViewBuilder
    private var variationChip: some View {
        let data = viewModel.periodComparisonWidget
        if data.supportsComparison, let delta = data.deltaPercent {
            VariationChip(
                variation: delta,
                size: .small,
                isExpenseContext: data.trendType == .expense
            )
        }
    }

    // MARK: - Trend chart page

    @ViewBuilder
    private var trendPage: some View {
        if hasNoTrendData {
            YalaEmptyState(
                icon: "chart.line.uptrend.xyaxis",
                title: L10n.Empty.noData,
                style: .widget
            )
            .frame(maxWidth: .infinity)
        } else {
            TrendChartView(
                trendPoints: viewModel.processedTrendPoints,
                rawPoints: viewModel.rawTrendPoints,
                yDomain: viewModel.processedYDomain,
                grouping: viewModel.trendGrouping,
                interval: viewModel.currentInterval,
                currencyCode: currencyCode,
                trendType: viewModel.dataTrendType,
                focusedDate: $viewModel.focusedDate,
                period: viewModel.currentPeriod,
                chartHeight: 170
            )
        }
    }

    // MARK: - Metric selector (writes to SessionState SSOT)

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
                case .balance: sessionState.selectedTransactionNatures.removeAll()
                case .income:  sessionState.selectedTransactionNatures = [.income]
                case .expense: sessionState.selectedTransactionNatures = [.expense]
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

    // MARK: - Title + KPI

    private var trendTitle: String {
        switch viewModel.trendType {
        case .balance: return L10n.Trend.balanceTitle
        case .income: return L10n.Trend.incomeTitle
        case .expense: return L10n.Trend.expenseTitle
        }
    }

    private var currentKPIValue: String {
        if let focusedDate = viewModel.focusedDate,
           let point = viewModel.rawTrendPoints.first(where: {
               Calendar.current.isDate($0.date, inSameDayAs: focusedDate)
           }) {
            return YalaFormatter.currency(value: point.value, currencyCode: currencyCode)
        }

        let value: Double
        switch viewModel.trendType {
        case .balance: value = viewModel.trendFinalBalance
        case .income:  value = viewModel.trendTotalIncome
        case .expense: value = viewModel.trendTotalExpense
        }
        return YalaFormatter.currency(value: value, currencyCode: currencyCode)
    }

}
