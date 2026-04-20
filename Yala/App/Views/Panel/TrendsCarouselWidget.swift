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

    @Environment(AppPreferences.self) private var appPreferences

    private enum Page: Hashable {
        case trend
        case comparison
    }

    @Namespace private var animationNamespace
    @State private var showFilterBlockedMessage: Bool = false
    @State private var selectedPage: Page = .trend

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

    private var comparisonData: PanelPeriodComparisonData {
        viewModel.periodComparisonWidget
    }

    // MARK: - Body

    var body: some View {
        let _ = appPreferences.decimalPlaces
        let _ = appPreferences.currencyDisplayFormat

        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            header
            carousel
        }
        .solidCard(padding: DS.Card.padding)
    }

    // MARK: - Header (shared across pages)

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(pageTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)

                pageSubtitle
            }

            Spacer()

            if !sessionState.isExpensesOnlyMode {
                metricSelector
            }
        }
    }

    @ViewBuilder
    private var pageSubtitle: some View {
        switch selectedPage {
        case .trend where !hasNoTrendData:
            Text(currentKPIValue)
                .font(DS.Typography.title)
                .foregroundStyle(.thPrimaryText)
                .padding(.top, DS.Spacing.xs)
        case .comparison:
            if let subtitle = comparisonSubtitle {
                Text(subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .padding(.top, DS.Spacing.xs)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Carousel

    private var carousel: some View {
        TabView(selection: $selectedPage) {
            VStack(spacing: 0) {
                trendPage
                Spacer(minLength: 0)
            }
            .tag(Page.trend)

            VStack(spacing: 0) {
                comparisonPage
                Spacer(minLength: 0)
            }
            .tag(Page.comparison)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .frame(height: 260)
    }

    // MARK: - Page 1 — Trend chart

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
                chartHeight: 220  // Match PeriodComparisonChartView hardcoded height
            )
        }
    }

    // MARK: - Page 2 — Period comparison chart

    @ViewBuilder
    private var comparisonPage: some View {
        let data = comparisonData
        if !data.supportsComparison {
            YalaEmptyState(
                icon: "calendar",
                title: L10n.Panel.PeriodComparison.requiresPeriod,
                style: .widget
            )
            .frame(maxWidth: .infinity)
        } else if data.currentPoints.isEmpty && data.previousPoints.isEmpty {
            YalaEmptyState(
                icon: "chart.xyaxis.line",
                title: L10n.Widget.noExpensesPeriod,
                style: .widget
            )
            .frame(maxWidth: .infinity)
        } else {
            PeriodComparisonChartView(
                currentPeriodPoints: data.currentPoints,
                previousPeriodPoints: data.previousPoints,
                yDomain: data.yDomain,
                grouping: data.grouping,
                currentInterval: data.currentInterval,
                previousInterval: data.previousInterval,
                currencyCode: currencyCode,
                trendType: data.trendType,
                chartHeight: 160,
                period: data.period,
                comparisonMode: data.comparisonMode,
                showPreviousPeriod: true
            )
        }
    }

    // MARK: - Metric selector (shared — writes to SessionState SSOT)

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

    // MARK: - Titles & subtitles

    private var pageTitle: String {
        switch selectedPage {
        case .comparison:
            return comparisonData.comparisonMode == .year
                ? L10n.Statistics.vsPreviousYear
                : L10n.Statistics.vsPreviousPeriod
        case .trend:
            switch viewModel.trendType {
            case .balance: return L10n.Trend.balanceTitle
            case .income: return L10n.Trend.incomeTitle
            case .expense: return L10n.Trend.expenseTitle
            }
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

    /// "↑ 12% vs marzo" / "↓ 5% vs diciembre 26" / "= vs 2025" / nil if no data.
    private var comparisonSubtitle: String? {
        let data = comparisonData
        guard data.supportsComparison, let delta = data.deltaPercent else { return nil }

        let percent = formatPercent(delta)
        let label = vsLabel(
            previousStart: data.previousInterval.start,
            currentStart: data.currentInterval.start,
            mode: data.comparisonMode
        )
        return "\(percent) \(label)"
    }

    // MARK: - Formatting helpers

    private func formatPercent(_ value: Double) -> String {
        let absValue = Swift.abs(value)
        let symbol: String
        if value > 0.5 { symbol = "↑" }
        else if value < -0.5 { symbol = "↓" }
        else { symbol = "=" }
        let pct = String(format: "%.0f%%", absValue)
        return "\(symbol) \(pct)"
    }

    private func monthLongName(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.setLocalizedDateFormatFromTemplate("LLLL")
        return fmt.string(from: date)
    }

    private func yearShort(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.setLocalizedDateFormatFromTemplate("yy")
        return fmt.string(from: date)
    }

    private func yearFull(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.setLocalizedDateFormatFromTemplate("yyyy")
        return fmt.string(from: date)
    }

    private func vsLabel(previousStart: Date, currentStart: Date, mode: ComparisonMode) -> String {
        let cal = Calendar.current
        if mode == .year {
            return L10n.Panel.PeriodComparison.vs(yearFull(for: previousStart))
        }
        let previousYear = cal.component(.year, from: previousStart)
        let currentYear = cal.component(.year, from: currentStart)
        let monthName = monthLongName(for: previousStart)
        if previousYear == currentYear {
            return L10n.Panel.PeriodComparison.vs(monthName)
        }
        return L10n.Panel.PeriodComparison.vsWithYear(monthName, yearShort(for: previousStart))
    }
}
