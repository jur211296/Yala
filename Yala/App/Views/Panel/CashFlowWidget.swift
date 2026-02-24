//
//  CashFlowWidget.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Charts
import SwiftUI

struct CashFlowWidget: View {
    @Environment(\.yalaTheme) private var theme
    @AppStorage("averageLineMode") private var averageLineMode: Int = 1
    let summary: CashFlowSummary
    let size: WidgetSize
    let period: String
    let grouping: TrendGrouping
    let interval: DateInterval
    let onShowDetail: (() -> Void)?
    let customTitle: String?
    let displayMode: TrendType?

    // Period Comparison (optional)
    let previousAmount: Double?
    let comparisonPeriodText: String?

    // Filter state for dimming non-selected bars
    let selectedTransactionNatures: Set<TransactionNature>

    // Control whether to show InfoHintButton (false when shown in parent header)
    let showInfoHint: Bool

    // When true, hides income bars and KPIs in compact layout
    let isExpensesOnlyMode: Bool

    init(
        summary: CashFlowSummary,
        size: WidgetSize,
        period: String,
        grouping: TrendGrouping,
        interval: DateInterval,
        onShowDetail: (() -> Void)? = nil,
        customTitle: String? = nil,
        displayMode: TrendType? = nil,
        previousAmount: Double? = nil,
        comparisonPeriodText: String? = nil,
        selectedTransactionNatures: Set<TransactionNature> = [],
        showInfoHint: Bool = true,
        isExpensesOnlyMode: Bool = false
    ) {
        self.summary = summary
        self.size = size
        self.period = period
        self.grouping = grouping
        self.interval = interval
        self.onShowDetail = onShowDetail
        self.customTitle = customTitle
        self.displayMode = displayMode
        self.previousAmount = previousAmount
        self.comparisonPeriodText = comparisonPeriodText
        self.selectedTransactionNatures = selectedTransactionNatures
        self.showInfoHint = showInfoHint
        self.isExpensesOnlyMode = isExpensesOnlyMode
    }

    /// Check if we have no data to display
    private var hasNoData: Bool {
        summary.totalIncome == 0 && summary.totalExpense == 0
    }

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
        // If customTitle is provided, use it (for account/currency specific views)
        if let title = customTitle {
            return title
        }

        // Otherwise, use display mode label
        switch displayMode {
        case .balance:
            return L10n.CashFlow.netFlow
        case .income:
            return L10n.CashFlow.income
        case .expense:
            return L10n.CashFlow.expense
        case .none:
            return L10n.CashFlow.title
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

    /// Waterfall mode: daily grouping + bidirectional data (not expenses-only or income-only)
    private var isWaterfallMode: Bool {
        grouping == .day && !hasOnlyExpenses && !hasOnlyIncome
    }

    /// Chart data for waterfall mode: exclude days where net is exactly zero
    /// (income == expense produces invisible bars that still occupy axis space)
    private var waterfallChartData: [CashFlowData] {
        nonEmptyChartData.filter { $0.net != 0 }
    }

    /// Active chart data: waterfall-filtered in waterfall mode, otherwise standard nonEmpty
    private var activeChartData: [CashFlowData] {
        isWaterfallMode ? waterfallChartData : nonEmptyChartData
    }

    /// Cumulative waterfall bars: each bar starts where the previous ended
    private var waterfallBars: [(date: Date, net: Double, yStart: Double, yEnd: Double)] {
        var cumulative = 0.0
        return waterfallChartData.map { point in
            let start = cumulative
            cumulative += point.net
            return (date: point.date, net: point.net, yStart: start, yEnd: cumulative)
        }
    }

    // MARK: - Compact Bar Dimming Logic

    /// Whether income bar should be dimmed (expense filter is active)
    private var isIncomeDimmed: Bool {
        selectedTransactionNatures == [.expense]
    }

    /// Whether expense bar should be dimmed (income filter is active)
    private var isExpenseDimmed: Bool {
        selectedTransactionNatures == [.income]
    }

    /// Calculate smart axis dates for chart X-axis
    /// Uses actual data dates to prevent duplicate labels (e.g., "ene", "ene", "feb")
    private var smartAxisDates: [Date] {
        guard !activeChartData.isEmpty else { return [] }

        let calendarUnit: Calendar.Component = {
            switch grouping {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            }
        }()

        return SmartAxisHelper.calculateSmartAxisDates(
            forDataDates: activeChartData.map(\.date),
            grouping: calendarUnit
        )
    }

    /// Format axis label based on data span and grouping
    private func smartAxisLabel(for date: Date) -> String {
        guard let firstDate = activeChartData.first?.date,
            let lastDate = activeChartData.last?.date
        else { return "" }

        // Determine calendar unit for forceGrouping
        let forceGrouping: Calendar.Component? = {
            switch grouping {
            case .month: return .month
            case .week: return .weekOfYear
            case .day: return nil  // Use span-based logic for days
            }
        }()

        return SmartAxisHelper.formatAxisLabel(
            for: date,
            startDate: firstDate,
            endDate: lastDate,
            forceGrouping: forceGrouping
        )
    }

    /// X-axis domain based on actual data range (not period range)
    /// Uses SmartAxisHelper to extend domain when few data points to prevent overly wide bars
    private var dataXDomain: ClosedRange<Date> {
        guard let firstDate = activeChartData.first?.date,
            let lastDate = activeChartData.last?.date
        else { return interval.start...interval.end }

        let calendarUnit: Calendar.Component = {
            switch grouping {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            }
        }()

        return SmartAxisHelper.extendedXDomain(
            dataPoints: activeChartData.count,
            firstDate: firstDate,
            lastDate: lastDate,
            grouping: calendarUnit
        )
    }

    /// Y-axis domain with independent scales for income and expense
    private var dataYDomain: ClosedRange<Double> {
        // Waterfall: domain based on cumulative yStart/yEnd values
        if isWaterfallMode {
            let bars = waterfallBars
            let allValues = bars.flatMap { [$0.yStart, $0.yEnd] }
            let maxVal = allValues.max() ?? 0
            let minVal = allValues.min() ?? 0
            let top = max(maxVal * 1.1, 0)
            let bottom = min(minVal * 1.1, 0)
            if top == bottom { return -1...1 }
            return bottom...top
        }

        let maxIncome = nonEmptyChartData.map { $0.income }.max() ?? 0
        let maxExpense = nonEmptyChartData.map { $0.expense }.max() ?? 0

        // If only expenses: show expenses as positive bars (0 to max)
        if hasOnlyExpenses {
            let maxValue = maxExpense * 1.1
            if maxValue == 0 { return 0...1 }
            return 0...maxValue
        }

        // If only income: show income bars (0 to max)
        if hasOnlyIncome {
            let maxValue = maxIncome * 1.1
            if maxValue == 0 { return 0...1 }
            return 0...maxValue
        }

        // Default: bidirectional (expenses down, income up)
        let incomeTop = maxIncome * 1.1
        let expenseBottom = -maxExpense * 1.1
        return expenseBottom...incomeTop
    }

    // MARK: - Average Line Logic

    /// Whether the total average line should be shown
    private var shouldShowTotalAverage: Bool {
        averageLineMode == 1
            && activeChartData.count >= 2
            && !isWaterfallMode
            && (hasOnlyExpenses || hasOnlyIncome)
    }

    /// Whether segmented average should be shown
    private var shouldShowSegmentedAverage: Bool {
        averageLineMode == 2
            && !isWaterfallMode
            && (hasOnlyExpenses || hasOnlyIncome)
    }

    /// Average value for total mode
    private var totalAverageValue: Double {
        guard !activeChartData.isEmpty else { return 0 }
        let values = activeChartData.map { hasOnlyExpenses ? $0.expense : $0.income }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Compute average segments for segmented mode
    private var averageSegments: [AverageSegment] {
        let values: [(date: Date, amount: Double)] = activeChartData.map {
            (date: $0.date, amount: hasOnlyExpenses ? $0.expense : $0.income)
        }
        return AverageSegment.compute(
            from: values,
            barGrouping: grouping
        )
    }

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            // Header with title, subtitle and value
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(kpiLabel)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .padding(.bottom, DS.Spacing.xxs)

                    // KPI with "vs previous amount" - only show when we have data
                    if !hasNoData {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                            Text(
                                YalaFormatter.currency(
                                    value: kpiValue, currencyCode: summary.currencyCode,
                                    forceSign: displayMode == .balance || displayMode == .none)
                            )
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                            // Show previous period value for comparison
                            if let prevAmount = previousAmount {
                                Text("vs \(YalaFormatter.number(value: prevAmount))")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.thSecondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    }
                }

                if showInfoHint {
                    InfoHintButton(
                        title: L10n.WidgetType.cashFlow,
                        message: L10n.Widget.Hint.cashFlow
                    )
                }

                Spacer()

                // Variation chip and comparison text (when previousAmount is available and has data)
                if !hasNoData && previousAmount != nil {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        VariationChip(
                            currentAmount: kpiValue,
                            previousAmount: previousAmount,
                            size: .medium,
                            showNAWhenNil: true,
                            isExpenseContext: displayMode == .expense
                        )

                        if let periodText = comparisonPeriodText, !periodText.isEmpty {
                            Text(periodText)
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.thSecondaryText)
                        }
                    }
                }

                if onShowDetail != nil {
                    Button(action: { onShowDetail?() }) {
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.headline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Accessibility.viewDetails)
                }
            }
            .padding([.horizontal, .top], DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)

            if hasNoData {
                emptyStateView
            } else {
                contentView
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(.thCard)
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
                            .foregroundStyle(.thSecondaryText.opacity(0.2))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    }

                    if isWaterfallMode {
                        // WATERFALL: cumulative bars — each starts where previous ended
                        ForEach(Array(waterfallBars.enumerated()), id: \.offset) { _, bar in
                            BarMark(
                                x: .value("Date", bar.date, unit: calendarUnit(for: grouping)),
                                yStart: .value("Start", bar.yStart),
                                yEnd: .value("End", bar.yEnd)
                            )
                            .foregroundStyle(
                                bar.net >= 0 ? Color.incomeGraph.gradient : Color.expenseGraph.gradient
                            )
                            .cornerRadius(DS.Radius.xs)
                        }
                    } else {
                        ForEach(activeChartData) { data in
                            if hasOnlyExpenses {
                                // Only expenses mode: show expenses as positive bars upward
                                BarMark(
                                    x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                    y: .value("Expense", data.expense)
                                )
                                .foregroundStyle(Color.expenseGraph.gradient)
                                .cornerRadius(DS.Radius.xs)
                                                            } else if hasOnlyIncome {
                                // Only income mode: show income bars upward (teal)
                                BarMark(
                                    x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                    y: .value("Income", data.income)
                                )
                                .foregroundStyle(Color.incomeGraph.gradient)
                                .cornerRadius(DS.Radius.xs)
                                                            } else {
                                // Default bidirectional mode (monthly)
                                BarMark(
                                    x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                    y: .value("Income", data.income)
                                )
                                .foregroundStyle(Color.incomeGraph.gradient)
                                .cornerRadius(DS.Radius.xs)

                                BarMark(
                                    x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                    y: .value("Expense", -data.expense)
                                )
                                .foregroundStyle(Color.expenseGraph.gradient)
                                .cornerRadius(DS.Radius.xs)

                                // Net Flow Line - Purple line
                                if grouping == .month {
                                    LineMark(
                                        x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                        y: .value("Net", data.net)
                                    )
                                    .foregroundStyle(theme.accent)
                                    .lineStyle(StrokeStyle(lineWidth: 2))
                                    .interpolationMethod(.monotone)

                                    PointMark(
                                        x: .value("Date", data.date, unit: calendarUnit(for: grouping)),
                                        y: .value("Net", data.net)
                                    )
                                    .foregroundStyle(theme.accent)
                                    .symbolSize(20)
                                }
                            }
                        }
                    }

                    averageLineMarks
                }  // Close Chart
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.Accessibility.cashFlowChart)
                .accessibilityValue(activeChartData.isEmpty ? L10n.Accessibility.noData :
                    L10n.Accessibility.cashFlowSummary(income: YalaFormatter.currency(value: summary.totalIncome, currencyCode: summary.currencyCode), expense: YalaFormatter.currency(value: summary.totalExpense, currencyCode: summary.currencyCode)))
                .chartXScale(domain: dataXDomain)
                .chartYScale(domain: dataYDomain)
                .chartXAxis {
                    // Center axis dates within calendar unit to align with BarMark centers
                    let unit = calendarUnit(for: grouping)
                    let centeredDates = SmartAxisHelper.centerDatesInCalendarUnit(smartAxisDates, unit: unit)

                    AxisMarks(values: centeredDates) { value in
                        AxisGridLine()
                            .foregroundStyle(.thSecondaryText.opacity(0.1))

                        if let date = value.as(Date.self) {
                            let anchor = SmartAxisHelper.axisLabelAnchor(
                                for: date,
                                in: centeredDates,
                                dataPointCount: activeChartData.count
                            )

                            AxisValueLabel(anchor: anchor) {
                                Text(smartAxisLabel(for: date))
                                    .font(DS.Typography.labelTiny)
                                    .foregroundStyle(.thSecondaryText)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.thSecondaryText.opacity(0.1))
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(formatK(doubleValue))
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.thSecondaryText)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedDate)  // Native iOS 17+ selection
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        let plotFrame = proxy.plotFrame.map { geo[$0] } ?? geo.frame(in: .local)

                        // Tooltip only (no gesture - chartXSelection handles it)
                        // Use activeChartData so waterfall mode only matches rendered bars
                        if let activeDate = selectedDate,
                            let selectedData = activeChartData.first(where: {
                                Calendar.current.isDate(
                                    $0.date, equalTo: activeDate,
                                    toGranularity: grouping == .month
                                        ? .month : (grouping == .week ? .weekOfYear : .day))
                            }),
                            let xPos = proxy.position(forX: selectedData.date)
                        {
                            VStack(spacing: DS.Spacing.xs) {
                                Text(formatTooltipDate(selectedData.date, grouping: grouping))
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.thSecondaryText)

                                if isWaterfallMode {
                                    // Waterfall: show net with color matching bar sign
                                    HStack(spacing: DS.Spacing.xs) {
                                        Circle()
                                            .fill(selectedData.net >= 0 ? Color.incomeGraph : Color.expenseGraph)
                                            .frame(width: 6, height: 6)
                                        Text(
                                            YalaFormatter.currency(
                                                value: selectedData.net,
                                                currencyCode: summary.currencyCode, forceSign: true)
                                        )
                                        .font(DS.Typography.labelTiny)
                                        .foregroundStyle(.primary)
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                        HStack(spacing: DS.Spacing.xs) {
                                            Circle().fill(Color.incomeGraph).frame(width: 6, height: 6)
                                            Text(
                                                YalaFormatter.currency(
                                                    value: selectedData.income,
                                                    currencyCode: summary.currencyCode, forceSign: true)
                                            )
                                            .font(DS.Typography.labelTiny)
                                            .foregroundStyle(.primary)
                                        }
                                        HStack(spacing: DS.Spacing.xs) {
                                            Circle().fill(Color.expenseGraph).frame(width: 6, height: 6)
                                            Text(
                                                YalaFormatter.currency(
                                                    value: -selectedData.expense,
                                                    currencyCode: summary.currencyCode)
                                            )
                                            .font(DS.Typography.labelTiny)
                                            .foregroundStyle(.primary)
                                        }
                                        Divider()
                                        HStack(spacing: DS.Spacing.xs) {
                                            Circle().fill(theme.accent).frame(width: 6, height: 6)
                                            Text(
                                                YalaFormatter.currency(
                                                    value: selectedData.net,
                                                    currencyCode: summary.currencyCode, forceSign: true)
                                            )
                                            .font(DS.Typography.labelTiny)
                                            .foregroundStyle(.primary)
                                        }
                                    }
                                }

                                // Average line in tooltip
                                if let avg = tooltipAverage(for: selectedData.date) {
                                    Divider()
                                    HStack(spacing: DS.Spacing.xs) {
                                        Text("x̄")
                                            .font(DS.Typography.labelTiny)
                                            .foregroundStyle(.thSecondaryText)
                                            .frame(width: 6)
                                        Text(
                                            YalaFormatter.currency(
                                                value: avg,
                                                currencyCode: summary.currencyCode)
                                        )
                                        .font(DS.Typography.labelTiny)
                                        .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .padding(DS.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .fill(.thCard)
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

                // Legend (only for bidirectional mode, hidden in waterfall — colors are self-evident)
                if !isWaterfallMode && !hasOnlyExpenses && !hasOnlyIncome {
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
                    // Income Group (hidden in expenses-only mode)
                    if !isExpensesOnlyMode {
                        VStack(spacing: DS.Spacing.xs) {
                            HStack {
                                Text(L10n.CashFlow.income)
                                    .font(DS.Typography.subheadline)
                                    .foregroundStyle(.thSecondaryText)
                                Spacer()
                                Text(
                                    YalaFormatter.currency(
                                        value: summary.totalIncome, currencyCode: summary.currencyCode)
                                )
                                .font(DS.Typography.amountSmall)
                                .foregroundStyle(.thPrimaryText)
                            }
                            // Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Track
                                    Capsule()
                                        .fill(.thPrimaryText.opacity(0.05))
                                        .frame(height: 8)

                                    // Fill - teal color for income
                                    let width =
                                        maxVal > 0 ? (summary.totalIncome / maxVal) * geo.size.width : 0
                                    Capsule()
                                        .fill(Color.incomeGraph)
                                        .frame(width: max(width, 6), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .opacity(isIncomeDimmed ? 0.4 : 1.0)
                    }

                    // Expense Group
                    VStack(spacing: DS.Spacing.xs) {
                        HStack {
                            Text(L10n.Transaction.expense)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.thSecondaryText)
                            Spacer()
                            Text(
                                YalaFormatter.currency(
                                    value: summary.totalExpense, currencyCode: summary.currencyCode)
                            )
                            .font(DS.Typography.amountSmall)
                        }
                        // Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Track
                                Capsule()
                                    .fill(.thPrimaryText.opacity(0.05))
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
                    .opacity(isExpenseDimmed ? 0.4 : 1.0)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    // MARK: - Average Line Chart Content

    @ChartContentBuilder
    private var averageLineMarks: some ChartContent {
        if shouldShowTotalAverage {
            RuleMark(y: .value("Avg", totalAverageValue))
                .foregroundStyle(.thSecondaryText.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text(formatK(totalAverageValue))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thSecondaryText)
                }
        }

        if shouldShowSegmentedAverage && averageSegments.count >= 2 {
            ForEach(Array(averageSegments.enumerated()), id: \.offset) { index, segment in
                RuleMark(
                    xStart: .value("SegStart", segment.startDate),
                    xEnd: .value("SegEnd", segment.endDate),
                    y: .value("Avg", segment.average)
                )
                .foregroundStyle(.thSecondaryText.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 3))
                .annotation(
                    position: index.isMultiple(of: 2) ? .top : .bottom,
                    alignment: .center
                ) {
                    averageSegmentLabel(segment: segment, index: index)
                }
            }
        } else if averageLineMode == 2 && !isWaterfallMode
            && (hasOnlyExpenses || hasOnlyIncome) && activeChartData.count >= 2
        {
            // Fallback to total when < 2 segments
            RuleMark(y: .value("Avg", totalAverageValue))
                .foregroundStyle(.thSecondaryText.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text(formatK(totalAverageValue))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thSecondaryText)
                }
        }
    }

    // MARK: - Average Segment Label

    @ViewBuilder
    private func averageSegmentLabel(segment: AverageSegment, index: Int) -> some View {
        Text(formatK(segment.average))
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.thSecondaryText)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .background(.thCard.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
    }

    /// Whether bars should be dimmed (segmented average active)
    private var isSegmentedAverageActive: Bool {
        shouldShowSegmentedAverage && averageSegments.count >= 2
    }

    /// Returns the applicable average for a given date (total or segment), or nil if off
    private func tooltipAverage(for date: Date) -> Double? {
        if shouldShowTotalAverage {
            return totalAverageValue
        }
        if isSegmentedAverageActive {
            return averageSegments.first(where: { date >= $0.startDate && date < $0.endDate })?.average
        }
        // Fallback: segmented mode but < 2 segments → total
        if averageLineMode == 2 && !isWaterfallMode
            && (hasOnlyExpenses || hasOnlyIncome) && activeChartData.count >= 2
        {
            return totalAverageValue
        }
        return nil
    }

    // Empty state view
    private var emptyStateView: some View {
        YalaEmptyState(icon: "chart.bar.xaxis", title: L10n.Empty.noData, style: .widget)
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

    private static let tooltipDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "d MMM yy"
        return f
    }()

    private static let tooltipMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "MMM yy"
        return f
    }()

    private func formatTooltipDate(_ date: Date, grouping: TrendGrouping) -> String {
        let formatter: DateFormatter
        switch grouping {
        case .day, .week: formatter = Self.tooltipDayFormatter
        case .month: formatter = Self.tooltipMonthFormatter
        }
        return formatter.string(from: date).lowercased().replacingOccurrences(of: ".", with: "")
    }
}

// MARK: - CashFlow Legend View

struct CashFlowLegendView: View {
    @Environment(\.yalaTheme) private var theme
    let showNet: Bool

    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Income
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(Color.incomeGraph)
                    .frame(width: 6, height: 6)
                Text(L10n.CashFlow.income)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.thSecondaryText)
            }

            // Expense
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(Color.expenseGraph)
                    .frame(width: 6, height: 6)
                Text(L10n.CashFlow.expense)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.thSecondaryText)
            }

            // Net (only for monthly grouping)
            if showNet {
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 6, height: 6)
                    Text(L10n.CashFlow.netFlow)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thSecondaryText)
                }
            }
        }
    }
}
