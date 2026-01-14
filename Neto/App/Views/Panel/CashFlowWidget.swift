//
//  CashFlowWidget.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Charts
import SwiftUI

struct CashFlowWidget: View {
    let summary: CashFlowSummary
    let size: WidgetSize
    let period: String
    let grouping: TrendGrouping
    let interval: DateInterval
    let onShowDetail: (() -> Void)?
    let customTitle: String?
    let displayMode: TrendType?

    init(
        summary: CashFlowSummary,
        size: WidgetSize,
        period: String,
        grouping: TrendGrouping,
        interval: DateInterval,
        onShowDetail: (() -> Void)? = nil,
        customTitle: String? = nil,
        displayMode: TrendType? = nil
    ) {
        self.summary = summary
        self.size = size
        self.period = period
        self.grouping = grouping
        self.interval = interval
        self.onShowDetail = onShowDetail
        self.customTitle = customTitle
        self.displayMode = displayMode
    }

    @Environment(\.colorScheme) var colorScheme

    // MARK: - KPI Value Logic

    /// KPI value based on display mode
    private var kpiValue: Double {
        switch displayMode {
        case .balance:
            return summary.netFlow
        case .income:
            return summary.totalIncome
        case .expense:
            return summary.totalExpense
        case .none:
            return summary.netFlow
        }
    }

    /// KPI label based on display mode
    private var kpiLabel: String {
        switch displayMode {
        case .balance:
            return L10n.CashFlow.netFlow
        case .income:
            return L10n.CashFlow.income
        case .expense:
            return L10n.CashFlow.expense
        case .none:
            return customTitle ?? L10n.CashFlow.title
        }
    }

    // MARK: - Smart Axis Logic

    /// Filter chart data to only include points with actual data (non-zero income or expense)
    private var nonEmptyChartData: [CashFlowData] {
        summary.chartData.filter { $0.income > 0 || $0.expense > 0 }
    }

    /// Detect if chart only has expenses (no income at all)
    /// Also returns true if displayMode is explicitly set to expense
    private var hasOnlyExpenses: Bool {
        // If displayMode is explicitly set to expense, show only expenses
        if displayMode == .expense {
            return true
        }

        let totalIncome = nonEmptyChartData.reduce(0) { $0 + $1.income }
        let totalExpense = nonEmptyChartData.reduce(0) { $0 + $1.expense }
        return totalIncome == 0 && totalExpense > 0
    }

    /// Detect if chart only has income (no expenses at all)
    /// Also returns true if displayMode is explicitly set to income
    private var hasOnlyIncome: Bool {
        // If displayMode is explicitly set to income, show only income
        if displayMode == .income {
            return true
        }

        let totalIncome = nonEmptyChartData.reduce(0) { $0 + $1.income }
        let totalExpense = nonEmptyChartData.reduce(0) { $0 + $1.expense }
        return totalExpense == 0 && totalIncome > 0
    }

    /// Calculate smart axis dates for chart X-axis
    private var smartAxisDates: [Date] {
        guard !nonEmptyChartData.isEmpty else { return [] }
        guard let firstDate = nonEmptyChartData.first?.date,
            let lastDate = nonEmptyChartData.last?.date
        else { return [] }
        return SmartAxisHelper.calculateSmartAxisDates(from: firstDate, to: lastDate)
    }

    /// Format axis label based on data span
    private func smartAxisLabel(for date: Date) -> String {
        guard let firstDate = nonEmptyChartData.first?.date,
            let lastDate = nonEmptyChartData.last?.date
        else { return "" }
        return SmartAxisHelper.formatAxisLabel(for: date, startDate: firstDate, endDate: lastDate)
    }

    /// X-axis domain based on actual data range (not period range)
    private var dataXDomain: ClosedRange<Date> {
        guard let firstDate = nonEmptyChartData.first?.date,
            let lastDate = nonEmptyChartData.last?.date
        else { return interval.start...interval.end }
        // Asymmetric padding: less on left, more on right (where Y-axis labels are)
        let calendar = Calendar.current
        let (startPadding, endPadding): (Int, Int) = {
            switch grouping {
            case .day: return (0, 1)
            case .week: return (0, 4)
            case .month: return (0, 30)
            }
        }()
        let paddedStart =
            calendar.date(byAdding: .day, value: -startPadding, to: firstDate) ?? firstDate
        let paddedEnd = calendar.date(byAdding: .day, value: endPadding, to: lastDate) ?? lastDate
        return paddedStart...paddedEnd
    }

    /// Y-axis domain with independent scales for income and expense
    private var dataYDomain: ClosedRange<Double> {
        let maxIncome = nonEmptyChartData.map { $0.income }.max() ?? 0
        let maxExpense = nonEmptyChartData.map { $0.expense }.max() ?? 0

        // If only expenses: show expenses as positive bars (0 to max)
        if hasOnlyExpenses {
            let maxValue = maxExpense * 1.1
            return 0...maxValue
        }

        // If only income: show income bars (0 to max)
        if hasOnlyIncome {
            let maxValue = maxIncome * 1.1
            return 0...maxValue
        }

        // Default: bidirectional (expenses down, income up)
        let incomeTop = maxIncome * 1.1
        let expenseBottom = -maxExpense * 1.1
        return expenseBottom...incomeTop
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with title, subtitle and value
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(kpiLabel)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .padding(.bottom, 2)

                    Text(
                        NetoFormatter.currency(
                            value: kpiValue, currencyCode: summary.currencyCode,
                            forceSign: displayMode == .balance || displayMode == .none)
                    )
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                }

                Spacer()

                if onShowDetail != nil {
                    Button(action: { onShowDetail?() }) {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundStyle(Color.gray.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding([.horizontal, .top], DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)

            contentView
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(Color.netoCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
        )
    }

    @State private var selectedDate: Date?

    @ViewBuilder
    private var contentView: some View {
        if size == .large {
            // Large - Chart View
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Chart
                Chart {
                    // Zero Baseline (only show for bidirectional charts)
                    if !hasOnlyExpenses && !hasOnlyIncome {
                        RuleMark(y: .value("Zero", 0))
                            .foregroundStyle(Color.netoSecondaryText.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }

                    ForEach(nonEmptyChartData) { data in
                        if hasOnlyExpenses {
                            // Only expenses mode: show expenses as positive bars upward
                            BarMark(
                                x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                y: .value("Expense", data.expense)
                            )
                            .foregroundStyle(Color.expenseGraph.gradient)
                            .cornerRadius(4)
                        } else if hasOnlyIncome {
                            // Only income mode: show income bars upward (teal)
                            BarMark(
                                x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                y: .value("Income", data.income)
                            )
                            .foregroundStyle(Color.incomeGraph.gradient)
                            .cornerRadius(4)
                        } else {
                            // Default bidirectional mode
                            // Income (Up) - Teal bars
                            BarMark(
                                x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                y: .value("Income", data.income)
                            )
                            .foregroundStyle(Color.incomeGraph.gradient)
                            .cornerRadius(4)

                            // Expense (Down)
                            BarMark(
                                x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                y: .value("Expense", -data.expense)
                            )
                            .foregroundStyle(Color.expenseGraph.gradient)
                            .cornerRadius(4)

                            // Net Flow Line - Purple line
                            if grouping == .month {
                                LineMark(
                                    x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                    y: .value("Net", data.net)
                                )
                                .foregroundStyle(Color.brandPrimary)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.catmullRom)

                                // Points on Line
                                PointMark(
                                    x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                    y: .value("Net", data.net)
                                )
                                .foregroundStyle(Color.brandPrimary)
                                .symbolSize(20)
                            }
                        }
                    }
                }  // Close Chart
                .chartXScale(domain: dataXDomain)
                .chartYScale(domain: dataYDomain)
                .chartXAxis {
                    // Smart dynamic X-axis labels (matching TrendChartView)
                    AxisMarks(values: smartAxisDates) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.netoSecondaryText.opacity(0.1))

                        if let date = value.as(Date.self) {
                            // Use trailing anchor for last label to prevent truncation
                            let isLast = date == smartAxisDates.last
                            let isFirst = date == smartAxisDates.first
                            let anchor: UnitPoint =
                                isLast ? .topTrailing : (isFirst ? .topLeading : .top)

                            AxisValueLabel(anchor: anchor) {
                                Text(smartAxisLabel(for: date))
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.netoSecondaryText)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.netoSecondaryText.opacity(0.1))
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(formatK(doubleValue))
                                    .font(.caption2)
                                    .foregroundStyle(Color.netoSecondaryText)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedDate)  // Native iOS 17+ selection
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        let plotFrame = proxy.plotFrame.map { geo[$0] } ?? geo.frame(in: .local)

                        // Tooltip only (no gesture - chartXSelection handles it)
                        if let activeDate = selectedDate,
                            let selectedData = summary.chartData.first(where: {
                                Calendar.current.isDate(
                                    $0.date, equalTo: activeDate,
                                    toGranularity: grouping == .month
                                        ? .month : (grouping == .week ? .weekOfYear : .day))
                            }),
                            let xPos = proxy.position(forX: selectedData.date)
                        {
                            VStack(spacing: 6) {
                                Text(formatTooltipDate(selectedData.date, grouping: grouping))
                                    .font(.caption2)
                                    .foregroundStyle(Color.netoSecondaryText)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Circle().fill(Color.incomeGraph).frame(width: 6, height: 6)
                                        Text(
                                            NetoFormatter.currency(
                                                value: selectedData.income,
                                                currencyCode: summary.currencyCode, forceSign: true)
                                        )
                                        .font(.caption2.bold())
                                        .foregroundStyle(.primary)
                                    }
                                    HStack(spacing: 6) {
                                        Circle().fill(Color.expenseGraph).frame(width: 6, height: 6)
                                        Text(
                                            NetoFormatter.currency(
                                                value: -selectedData.expense,
                                                currencyCode: summary.currencyCode)
                                        )
                                        .font(.caption2.bold())
                                        .foregroundStyle(.primary)
                                    }
                                    Divider()
                                    HStack(spacing: 6) {
                                        Circle().fill(Color.brandPrimary).frame(width: 6, height: 6)
                                        Text(
                                            NetoFormatter.currency(
                                                value: selectedData.net,
                                                currencyCode: summary.currencyCode, forceSign: true)
                                        )
                                        .font(.caption2.bold())
                                        .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .fill(Color.netoCard)
                                    .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 2)
                            )
                            .fixedSize()
                            .position(
                                x: max(80, min(xPos + plotFrame.origin.x, geo.size.width - 80)),
                                y: plotFrame.minY + 20
                            )
                            .offset(y: -50)
                        }
                    }
                }

                // Legend (only for bidirectional mode)
                if !hasOnlyExpenses && !hasOnlyIncome {
                    CashFlowLegendView(showNet: grouping == .month)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)

        } else {
            // Small & Medium - Summary Layout (With Bars)
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Bars Section
                // Calculate max value for normalization
                let maxVal = max(summary.totalIncome, summary.totalExpense)

                VStack(spacing: DS.Spacing.md) {
                    // Income Group
                    VStack(spacing: 6) {
                        HStack {
                            Text(L10n.CashFlow.income)
                                .font(.subheadline)
                                .foregroundStyle(Color.netoSecondaryText)
                            Spacer()
                            Text(
                                NetoFormatter.currency(
                                    value: summary.totalIncome, currencyCode: summary.currencyCode)
                            )
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.netoPrimaryText)
                        }
                        // Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Track
                                Capsule()
                                    .fill(Color.netoPrimaryText.opacity(0.05))
                                    .frame(height: 8)

                                // Fill
                                let width =
                                    maxVal > 0 ? (summary.totalIncome / maxVal) * geo.size.width : 0
                                Capsule()
                                    .fill(Color.brandPrimary)
                                    .frame(width: max(width, 6), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }

                    // Expense Group
                    VStack(spacing: 6) {
                        HStack {
                            Text(L10n.Transaction.expense)
                                .font(.subheadline)
                                .foregroundStyle(Color.netoSecondaryText)
                            Spacer()
                            Text(
                                NetoFormatter.currency(
                                    value: summary.totalExpense, currencyCode: summary.currencyCode)
                            )
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        // Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Track
                                Capsule()
                                    .fill(Color.netoPrimaryText.opacity(0.05))
                                    .frame(height: 8)

                                // Fill
                                let width =
                                    maxVal > 0
                                    ? (summary.totalExpense / maxVal) * geo.size.width : 0
                                Capsule()
                                    .fill(Color.expenseGraph)
                                    .frame(width: max(width, 6), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    // Consistent Widget Background Logic
    private var cardBackgroundColor: Color {
        if colorScheme == .dark {
            return Color.deepSlate.opacity(0.6)
        } else {
            return Color.white.opacity(0.7)
        }
    }

    // Helpers
    private func formatK(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : (value > 0 ? "" : "")  // Only negative sign for Y axis usually
        // Note: User image had "-40K".

        if absValue >= 1000 {
            let kValue = absValue / 1000.0
            return String(format: "%@%.0fK", sign, kValue)
        } else {
            return String(format: "%@%.0f", sign, absValue)
        }
    }

    private func calendarUnit(for grouping: TrendGrouping) -> Calendar.Component {
        switch grouping {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }

    private func formatTooltipDate(_ date: Date, grouping: TrendGrouping) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        switch grouping {
        case .day: formatter.dateFormat = "d MMM yy"  // 19 dic 25
        case .week: formatter.dateFormat = "d MMM yy"  // 19 dic 25
        case .month: formatter.dateFormat = "MMM yy"  // ene 25
        }
        return formatter.string(from: date).lowercased().replacingOccurrences(of: ".", with: "")
    }
}

// MARK: - CashFlow Legend View

struct CashFlowLegendView: View {
    let showNet: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Income
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.incomeGraph)
                    .frame(width: 6, height: 6)
                Text(L10n.CashFlow.income)
                    .font(.caption2)
                    .foregroundStyle(Color.netoSecondaryText)
            }

            // Expense
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.expenseGraph)
                    .frame(width: 6, height: 6)
                Text(L10n.CashFlow.expense)
                    .font(.caption2)
                    .foregroundStyle(Color.netoSecondaryText)
            }

            // Net (only for monthly grouping)
            if showNet {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.brandPrimary)
                        .frame(width: 6, height: 6)
                    Text(L10n.CashFlow.netFlow)
                        .font(.caption2)
                        .foregroundStyle(Color.netoSecondaryText)
                }
            }
        }
    }
}
