//
//  NeedTrendWidget.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Charts
import SwiftUI

private let needPercentFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .percent
    f.maximumFractionDigits = 0
    return f
}()

struct NeedTrendWidget: View {
    @Environment(AppPreferences.self) private var appPreferences
    let trendPoints: [NeedTrendPoint]
    let selectedNeed: SubcategoryNeed?
    let currencyCode: String
    let size: TopCategoriesWidget.CardSize  // Reusing comparable size enum or WidgetSize
    let grouping: TrendGrouping
    let interval: DateInterval
    let onSelectNeed: (SubcategoryNeed) -> Void
    let onShowDetail: (() -> Void)?

    // MARK: - Period Comparison

    var period: DetailPeriod = .thisMonth
    var previousTotalAmount: Double? = nil
    var previousAmountByNeed: [SubcategoryNeed: Double] = [:]
    var showVariationHeader: Bool = false
    var comparisonMode: ComparisonMode = .month
    var variationDisplay: VariationDisplayConfig = .full

    /// When true, shows a message that need classification doesn't apply to income
    var isIncomeMode: Bool = false

    /// Slot pedagógico opcional inyectado en el header (Panel Polish #2).
    var headerInfoButton: AnyView? = nil

    private var totalAmount: Double {
        guard let need = selectedNeed else {
            return trendPoints.reduce(0) { $0 + $1.total }
        }
        return trendPoints.reduce(0) { $0 + $1.amount(for: need) }
    }

    private var variation: Double? {
        let previousAmount: Double?
        if let need = selectedNeed {
            previousAmount = previousAmountByNeed[need]
        } else {
            previousAmount = previousTotalAmount
        }
        guard let previous = previousAmount else { return nil }
        return PreviousPeriodHelper.calculateVariation(
            currentAmount: totalAmount,
            previousAmount: previous
        )
    }

    private var previousInterval: DateInterval {
        PreviousPeriodHelper.previousInterval(for: period, mode: comparisonMode, customRange: nil)
    }

    /// Totals per need across `trendPoints` — single-pass aggregation reused by the
    /// `.small` and `.medium` layouts instead of 4 separate `.reduce(…)` calls.
    private var needTotals: (essential: Double, priority: Double, optional: Double, unclassified: Double) {
        var e = 0.0, p = 0.0, o = 0.0, u = 0.0
        for point in trendPoints {
            e += point.essential
            p += point.priority
            o += point.optional
            u += point.unclassified
        }
        return (e, p, o, u)
    }

    private var comparisonText: String {
        PreviousPeriodHelper.formatComparisonText(
            previousInterval: previousInterval,
            period: period,
            mode: comparisonMode
        )
    }

    /// Calculate variation for a specific need
    private func variationForNeed(_ need: SubcategoryNeed, currentAmount: Double) -> Double? {
        guard let previousAmount = previousAmountByNeed[need] else { return nil }
        return PreviousPeriodHelper.calculateVariation(
            currentAmount: currentAmount,
            previousAmount: previousAmount
        )
    }

    init(
        trendPoints: [NeedTrendPoint],
        selectedNeed: SubcategoryNeed?,
        currencyCode: String,
        size: TopCategoriesWidget.CardSize,
        grouping: TrendGrouping,
        interval: DateInterval,
        onSelectNeed: @escaping (SubcategoryNeed) -> Void,
        onShowDetail: (() -> Void)? = nil,
        period: DetailPeriod = .thisMonth,
        previousTotalAmount: Double? = nil,
        previousAmountByNeed: [SubcategoryNeed: Double] = [:],
        showVariationHeader: Bool = false,
        comparisonMode: ComparisonMode = .month,
        variationDisplay: VariationDisplayConfig = .full,
        isIncomeMode: Bool = false,
        headerInfoButton: AnyView? = nil
    ) {
        self.trendPoints = trendPoints
        self.selectedNeed = selectedNeed
        self.currencyCode = currencyCode
        self.size = size
        self.grouping = grouping
        self.interval = interval
        self.onSelectNeed = onSelectNeed
        self.onShowDetail = onShowDetail
        self.period = period
        self.previousTotalAmount = previousTotalAmount
        self.previousAmountByNeed = previousAmountByNeed
        self.showVariationHeader = showVariationHeader
        self.comparisonMode = comparisonMode
        self.variationDisplay = variationDisplay
        self.isIncomeMode = isIncomeMode
        self.headerInfoButton = headerInfoButton
    }

    var body: some View {
        if size == .small {
            smallBody
        } else {
            regularBody
        }
    }

    // MARK: - Small layout (PP2-06c)

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PanelSmallWidgetHeader(
                title: L10n.Widget.distributionByNeed,
                accessibilityLabel: L10n.Widget.distributionByNeed,
                action: onShowDetail,
                headerInfoButton: headerInfoButton
            )

            if isIncomeMode {
                Text(L10n.Need.incomeNotApplicable)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if trendPoints.isEmpty {
                YalaEmptyState(icon: "chart.bar.fill", title: L10n.Empty.noExpenses, style: .widget)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                smallContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panelCard(small: true)
        .frame(height: WidgetSize.smallHeight)
    }

    private var smallContent: some View {
        let totals = needTotals

        // Always show the 3 canonical needs; add unclassified only if it has a value.
        var entries: [(need: SubcategoryNeed, amount: Double)] = [
            (.essential, totals.essential),
            (.priority, totals.priority),
            (.optional, totals.optional),
        ]
        if totals.unclassified > 0 {
            entries.append((.unclassified, totals.unclassified))
        }

        let total = entries.reduce(0) { $0 + $1.amount }

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                AmountText(
                    value: total,
                    currencyCode: currencyCode,
                    size: .headline
                )

                if variationDisplay.showsSmallVariation, showVariationHeader, let variation {
                    VariationChip(
                        variation: variation,
                        size: .small,
                        isExpenseContext: true
                    )
                }
            }

            VStack(spacing: DS.Spacing.md) {
                ForEach(entries, id: \.need) { entry in
                    smallNeedRow(
                        need: entry.need,
                        amount: entry.amount,
                        ratio: total > 0 ? (entry.amount / total) : 0
                    )
                }
            }
        }
    }

    private func smallNeedRow(
        need: SubcategoryNeed,
        amount: Double,
        ratio: Double
    ) -> some View {
        let dimmed = selectedNeed != nil && selectedNeed != need
        return PanelSmallBarRow(
            label: need.displayName,
            amount: amount,
            ratio: ratio,
            color: color(for: need),
            currencyCode: currencyCode,
            dimmed: dimmed,
            onTap: { onSelectNeed(need) }
        )
    }

    private func color(for need: SubcategoryNeed) -> Color {
        switch need {
        case .essential:    return .essentialNeed
        case .priority:     return .priorityNeed
        case .optional:     return .optionalNeed
        case .unclassified: return DS.Semantic.disabledForeground
        }
    }

    // MARK: - Medium / Large (existing)

    private var regularBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header - simplified when in income mode or no data (no KPI makes sense)
            HStack(alignment: .top) {
                // Left: Title and total amount (hide KPI in income mode or when no data)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text(L10n.Widget.distributionByNeed)
                            .font(DS.Typography.subheadlineEmphasized)
                            .foregroundStyle(.thPrimaryText)

                        WidgetHeaderInfoSlot(
                            injected: headerInfoButton,
                            legacyTitle: L10n.WidgetType.expensesByNeed,
                            legacyMessage: L10n.Widget.Hint.needTrend
                        )
                    }

                    if !isIncomeMode && !trendPoints.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                            AmountText(
                                value: totalAmount,
                                currencyCode: currencyCode,
                                size: .headline
                            )

                            if variationDisplay.showsPreviousAmountLabel, let prevAmount = previousTotalAmount {
                                Text("vs \(appPreferences.number(prevAmount))")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.thSecondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    }
                }

                Spacer()

                // Right: Variation chip and comparison text (only when showVariationHeader and has data, not in income mode)
                if !isIncomeMode && showVariationHeader && !trendPoints.isEmpty && variation != nil {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        VariationChip(variation: variation, size: .medium)

                        if variationDisplay.showsComparisonPeriodLabel && !comparisonText.isEmpty {
                            Text(comparisonText)
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }

            }

            // Content
            if isIncomeMode {
                // Income mode: need classification doesn't apply
                // Show centered message without KPI (header already hidden via conditional)
                Spacer()
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "info.circle")
                        .font(DS.Typography.title)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(L10n.Need.incomeNotApplicable)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else if trendPoints.isEmpty {
                YalaEmptyState(icon: "chart.bar.fill", title: L10n.Empty.noExpenses, style: .widget)
            } else {
                chartView
            }
        }
        .panelCard()
    }

    @ViewBuilder
    private var chartView: some View {
        if size == .large {
            // Large: Chart + Legend (legend handles filtering)
            VStack(spacing: DS.Spacing.lg) {
                NeedTrendChartView(
                    points: trendPoints, selectedNeed: selectedNeed, currencyCode: currencyCode,
                    grouping: grouping, interval: interval,
                    onSelectNeed: nil  // Legend handles explicit selection
                )

                NeedLegendView(
                    points: trendPoints,
                    selectedNeed: selectedNeed,
                    onSelect: onSelectNeed
                )
            }
        } else {
            // Compact: Summary Bars Layout (like CashFlowWidget)
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Single-pass totals — reused by Essential/Priority/Optional/Unclassified bars.
                let totals = needTotals
                let essentialTotal = totals.essential
                let priorityTotal = totals.priority
                let optionalTotal = totals.optional
                let unclassifiedTotal = totals.unclassified
                let maxVal = max(
                    essentialTotal, max(priorityTotal, max(optionalTotal, unclassifiedTotal)))

                VStack(spacing: DS.Spacing.md) {
                    // Essential Bar
                    NeedCompactBar(
                        need: .essential,
                        amount: essentialTotal,
                        maxAmount: maxVal,
                        currencyCode: currencyCode,
                        isSelected: selectedNeed == nil || selectedNeed == .essential,
                        onTap: { onSelectNeed(.essential) },
                        variation: variationForNeed(.essential, currentAmount: essentialTotal),
                        showNAWhenNil: showVariationHeader
                    )

                    // Priority Bar
                    NeedCompactBar(
                        need: .priority,
                        amount: priorityTotal,
                        maxAmount: maxVal,
                        currencyCode: currencyCode,
                        isSelected: selectedNeed == nil || selectedNeed == .priority,
                        onTap: { onSelectNeed(.priority) },
                        variation: variationForNeed(.priority, currentAmount: priorityTotal),
                        showNAWhenNil: showVariationHeader
                    )

                    // Optional Bar
                    NeedCompactBar(
                        need: .optional,
                        amount: optionalTotal,
                        maxAmount: maxVal,
                        currencyCode: currencyCode,
                        isSelected: selectedNeed == nil || selectedNeed == .optional,
                        onTap: { onSelectNeed(.optional) },
                        variation: variationForNeed(.optional, currentAmount: optionalTotal),
                        showNAWhenNil: showVariationHeader
                    )

                    // Unclassified Bar (only if has value)
                    if unclassifiedTotal > 0 {
                        NeedCompactBar(
                            need: .unclassified,
                            amount: unclassifiedTotal,
                            maxAmount: maxVal,
                            currencyCode: currencyCode,
                            isSelected: selectedNeed == nil || selectedNeed == .unclassified,
                            onTap: { onSelectNeed(.unclassified) },
                            variation: variationForNeed(.unclassified, currentAmount: unclassifiedTotal),
                            showNAWhenNil: showVariationHeader
                        )
                    }
                }
            }
        }
    }

}

struct NeedTrendChartView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    let points: [NeedTrendPoint]
    let selectedNeed: SubcategoryNeed?
    let currencyCode: String
    let grouping: TrendGrouping
    let interval: DateInterval
    let onSelectNeed: ((SubcategoryNeed) -> Void)?
    @State private var selectedDate: Date?

    // Flattened data struct for the chart
    struct ChartItem: Identifiable {
        var id: String { "\(need.rawValue)-\(Int(date.timeIntervalSince1970))" }
        let date: Date
        let need: SubcategoryNeed
        let amount: Double
    }

    // MARK: - Smart Axis Logic

    /// Calculate smart axis dates for chart X-axis
    /// Uses actual data dates to prevent duplicate labels (e.g., "ene", "ene", "feb")
    private var smartAxisDates: [Date] {
        guard !points.isEmpty else { return [] }

        let calendarUnit: Calendar.Component = {
            switch grouping {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            }
        }()

        let rawDates = SmartAxisHelper.calculateSmartAxisDates(
            forDataDates: points.map(\.date),
            grouping: calendarUnit
        )

        guard let firstDate = points.first?.date,
              let lastDate = points.last?.date else { return rawDates }
        return SmartAxisHelper.deduplicatedAxisDates(
            rawDates, firstDate: firstDate, lastDate: lastDate,
            forceGrouping: grouping.forceAxisGrouping)
    }

    /// Format axis label based on data span and grouping
    private func smartAxisLabel(for date: Date) -> String {
        guard let firstDate = points.first?.date,
            let lastDate = points.last?.date
        else { return "" }

        return SmartAxisHelper.formatAxisLabel(
            for: date,
            startDate: firstDate,
            endDate: lastDate,
            forceGrouping: grouping.forceAxisGrouping
        )
    }

    /// X-axis domain based on actual data range with extended padding for few data points
    private var dataXDomain: ClosedRange<Date> {
        guard let firstDate = points.first?.date,
            let lastDate = points.last?.date
        else { return interval.start...interval.end }

        let calendarUnit: Calendar.Component = {
            switch grouping {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            }
        }()

        return SmartAxisHelper.extendedXDomain(
            dataPoints: points.count,
            firstDate: firstDate,
            lastDate: lastDate,
            grouping: calendarUnit
        )
    }

    // MARK: - Average Line Logic

    private var shouldShowTotalAverage: Bool {
        appPreferences.averageLineMode == 1 && points.count >= 2
    }

    private var shouldShowSegmentedAverage: Bool {
        appPreferences.averageLineMode == 2
    }

    private var totalAverageValue: Double {
        guard !points.isEmpty else { return 0 }
        if let need = selectedNeed {
            let values = points.map { $0.amount(for: need) }
            return values.reduce(0, +) / Double(values.count)
        } else {
            let values = points.map { $0.total }
            return values.reduce(0, +) / Double(values.count)
        }
    }

    private var averageSegments: [AverageSegment] {
        let values: [(date: Date, amount: Double)]
        if let need = selectedNeed {
            values = points.map { (date: $0.date, amount: $0.amount(for: need)) }
        } else {
            values = points.map { (date: $0.date, amount: $0.total) }
        }
        return AverageSegment.compute(from: values, barGrouping: grouping)
    }

    var body: some View {
        let chartUnit = mapGroupingToUnit(grouping)

        // Calculate max value for Y domain with minimal padding
        let maxValue = calculateMaxValue()
        let yDomain: ClosedRange<Double> = 0...(maxValue * 1.05)  // 5% padding instead of default ~20%

        Chart {
            ForEach(flattenData(points)) { item in
                // If a need is selected, only show that nature (or dim others)
                // Design Choice: If filtered, show ONLY that line. If not, show ALL lines stacked?
                // Or show all lines but highlight selected?
                // Let's match typical behavior: If filtered, show only that ONE series.
                // If ALL (nil), show stacked area or multiple lines.
                // Given "Gastos por naturaleza", Stacked Bar is good for composition.

                if let selected = selectedNeed {
                    if item.need == selected {
                        BarMark(
                            x: .value("Fecha", item.date, unit: chartUnit),
                            y: .value("Monto", item.amount)
                        )
                        .foregroundStyle(item.need.color.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                                            }
                } else {
                    BarMark(
                        x: .value("Fecha", item.date, unit: chartUnit),
                        y: .value("Monto", item.amount)
                    )
                    .foregroundStyle(item.need.color.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                                    }
            }

            averageLineMarks
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Accessibility.needTrend)
        .accessibilityValue(points.isEmpty ? L10n.Accessibility.noData :
            L10n.Accessibility.periodsCount(points.count))
        .chartXScale(domain: dataXDomain)
        .chartYScale(domain: yDomain)
        .chartForegroundStyleScale([
            L10n.Need.essential: Color.essentialNeed,
            L10n.Need.priority: Color.priorityNeedNew,
            L10n.Need.optional: Color.optionalNeed,
            L10n.Need.unclassified: DS.Semantic.disabledForeground,
        ])
        .chartLegend(.hidden)
        // X-Axis: Smart dynamic labels matching TrendChartView
        .chartXAxis {
            // Center axis dates within calendar unit to align with BarMark centers
            let unit = mapGroupingToUnit(grouping)
            let centeredDates = SmartAxisHelper.centerDatesInCalendarUnit(smartAxisDates, unit: unit)

            AxisMarks(values: centeredDates) { value in
                AxisGridLine()
                    .foregroundStyle(.thSecondaryText.opacity(0.1))

                if let date = value.as(Date.self) {
                    let anchor = SmartAxisHelper.axisLabelAnchor(
                        for: date,
                        in: centeredDates,
                        dataPointCount: points.count
                    )

                    AxisValueLabel(anchor: anchor) {
                        Text(smartAxisLabel(for: date))
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(.thSecondaryText)
                    }
                }
            }
        }
        // Y-Axis: Right (Trailing), minimal gridlines for clean look
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.thSecondaryText.opacity(0.1))
                if let amount = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatAxisAmount(amount))
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
                if let activeDate = selectedDate,
                    let selectedData = points.first(where: {
                        Calendar.current.isDate(
                            $0.date, equalTo: activeDate,
                            toGranularity: grouping == .month
                                ? .month : (grouping == .week ? .weekOfYear : .day))
                    }),
                    let xPos = proxy.position(forX: selectedData.date)
                {
                    // Vertical Line
                    Rectangle()
                        .fill(.thSecondaryText.opacity(0.3))
                        .frame(width: 1, height: plotFrame.height)
                        .position(x: xPos + plotFrame.origin.x, y: plotFrame.midY)

                    // Tooltip Card
                    VStack(spacing: DS.Spacing.xs) {
                        Text(formatDateFull(selectedData.date, grouping: grouping))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.thSecondaryText)

                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            if selectedData.essential > 0 {
                                TooltipRow(
                                    need: .essential, amount: selectedData.essential,
                                    currencyCode: currencyCode)
                            }
                            if selectedData.priority > 0 {
                                TooltipRow(
                                    need: .priority, amount: selectedData.priority,
                                    currencyCode: currencyCode)
                            }
                            if selectedData.optional > 0 {
                                TooltipRow(
                                    need: .optional, amount: selectedData.optional,
                                    currencyCode: currencyCode)
                            }
                            if selectedData.unclassified > 0 {
                                TooltipRow(
                                    need: .unclassified, amount: selectedData.unclassified,
                                    currencyCode: currencyCode)
                            }
                            Divider()
                            HStack {
                                Text(L10n.Widget.total)
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                                Text(
                                    appPreferences.currency(selectedData.total, currencyCode: currencyCode)
                                )
                                .font(DS.Typography.labelTiny)
                                .foregroundStyle(Color.primary)
                            }

                            // Average line in tooltip
                            if let avg = tooltipAverage(for: selectedData.date) {
                                Divider()
                                HStack {
                                    Text(L10n.Widget.average)
                                        .font(DS.Typography.captionSmall)
                                        .foregroundStyle(Color.secondary)
                                    Spacer()
                                    Text(
                                        appPreferences.currency(avg, currencyCode: currencyCode)
                                    )
                                    .font(DS.Typography.labelTiny)
                                    .foregroundStyle(Color.primary)
                                }
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
                        y: 40
                    )
                }
            }
        }
    }

    // MARK: - Average Line Chart Content

    /// Whether bars should be dimmed (segmented average active)
    private var isSegmentedAverageActive: Bool {
        shouldShowSegmentedAverage && averageSegments.count >= 2
    }

    /// Returns the applicable average for a given date, or nil if off
    private func tooltipAverage(for date: Date) -> Double? {
        if shouldShowTotalAverage {
            return totalAverageValue
        }
        if isSegmentedAverageActive {
            return averageSegments.first(where: { date >= $0.startDate && date < $0.endDate })?.average
        }
        if appPreferences.averageLineMode == 2 && points.count >= 2 {
            return totalAverageValue
        }
        return nil
    }

    @ChartContentBuilder
    private var averageLineMarks: some ChartContent {
        if shouldShowTotalAverage {
            RuleMark(y: .value("Avg", totalAverageValue))
                .foregroundStyle(.thSecondaryText.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text(formatAxisAmount(totalAverageValue))
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
                    Text(formatAxisAmount(segment.average))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thSecondaryText)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(.thCard.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
                }
            }
        } else if appPreferences.averageLineMode == 2 && points.count >= 2 {
            RuleMark(y: .value("Avg", totalAverageValue))
                .foregroundStyle(.thSecondaryText.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .annotation(position: .top, alignment: .leading) {
                    Text(formatAxisAmount(totalAverageValue))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thSecondaryText)
                }
        }
    }

    private func calculateMaxValue() -> Double {
        guard !points.isEmpty else { return 100 }

        if let selected = selectedNeed {
            // If a need is selected, find max for that need
            return points.map { point in
                switch selected {
                case .essential: return point.essential
                case .priority: return point.priority
                case .optional: return point.optional
                case .unclassified: return point.unclassified
                }
            }.max() ?? 100
        } else {
            // If showing all, find max total per date (stacked)
            return points.map { $0.total }.max() ?? 100
        }
    }

    private static let fullDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "d MMM yy"
        return f
    }()

    private static let fullMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "MMM yy"
        return f
    }()

    private func formatDateFull(_ date: Date, grouping: TrendGrouping) -> String {
        let formatter: DateFormatter
        switch grouping {
        case .day, .week: formatter = Self.fullDayFormatter
        case .month: formatter = Self.fullMonthFormatter
        }
        return formatter.string(from: date).lowercased().replacing(".", with: "")
    }

    struct TooltipRow: View {
        @Environment(AppPreferences.self) private var appPreferences
        let need: SubcategoryNeed
        let amount: Double
        let currencyCode: String

        var body: some View {
            HStack {
                Circle().fill(need.color).frame(width: 6, height: 6)
                Text(need.displayName)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(Color.primary)
                Spacer()
                // Simple formatting for tooltip
                Text(appPreferences.currency(amount, currencyCode: currencyCode))
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(Color.primary)
            }
        }
    }

    private func mapGroupingToUnit(_ grouping: TrendGrouping) -> Calendar.Component {
        switch grouping {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        }
    }

    private func flattenData(_ points: [NeedTrendPoint]) -> [ChartItem] {
        var items: [ChartItem] = []
        for point in points {
            // Add all natures
            if shouldShow(.essential) {
                items.append(
                    ChartItem(date: point.date, need: .essential, amount: point.essential))
            }
            if shouldShow(.priority) {
                items.append(ChartItem(date: point.date, need: .priority, amount: point.priority))
            }
            if shouldShow(.optional) {
                items.append(ChartItem(date: point.date, need: .optional, amount: point.optional))
            }
            if shouldShow(.unclassified) {  // Only show if > 0 or if logic requires?
                items.append(
                    ChartItem(date: point.date, need: .unclassified, amount: point.unclassified))
            }
        }
        return items
    }

    private func shouldShow(_ need: SubcategoryNeed) -> Bool {
        if let selected = selectedNeed {
            return selected == need
        }
        return true
    }

    private func formatAxisAmount(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        if absValue >= 1000 {
            let kValue = absValue / 1000.0
            return String(format: "%@%.0fK", sign, kValue)
        }
        return String(format: "%@%.0f", sign, absValue)
    }
}

struct NeedLegendView: View {
    let points: [NeedTrendPoint]
    let selectedNeed: SubcategoryNeed?
    let onSelect: (SubcategoryNeed) -> Void

    var body: some View {
        // Horizontal Grid or Flex
        let essentials = points.reduce(0) { $0 + $1.essential }
        let priorities = points.reduce(0) { $0 + $1.priority }
        let optionals = points.reduce(0) { $0 + $1.optional }
        let unclassified = points.reduce(0) { $0 + $1.unclassified }
        let total = essentials + priorities + optionals + unclassified

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                CompactLegendChip(
                    need: .essential, amount: essentials, total: total,
                    isSelected: selectedNeed == .essential || selectedNeed == nil,
                    onTap: { onSelect(.essential) })
                CompactLegendChip(
                    need: .priority, amount: priorities, total: total,
                    isSelected: selectedNeed == .priority || selectedNeed == nil,
                    onTap: { onSelect(.priority) })
                CompactLegendChip(
                    need: .optional, amount: optionals, total: total,
                    isSelected: selectedNeed == .optional || selectedNeed == nil,
                    onTap: { onSelect(.optional) })
                if unclassified > 0 {
                    CompactLegendChip(
                        need: .unclassified, amount: unclassified, total: total,
                        isSelected: selectedNeed == .unclassified || selectedNeed == nil,
                        onTap: { onSelect(.unclassified) })
                }
            }
        }
    }
}

struct LegendItem: View {
    let need: SubcategoryNeed
    let amount: Double
    let total: Double
    let isSelected: Bool
    let onTap: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(extensionColor(for: need))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: DS.Spacing.none) {
                    Text(need.displayName)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color.primary)

                    Text("\(formattedPercent(amount, total))")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
            }
            .padding(DS.Spacing.sm)
            .background(isSelected ? theme.background : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .opacity(isSelected ? 1.0 : 0.4)
        }
    }

    private func extensionColor(for need: SubcategoryNeed) -> Color {
        need.color
    }

    private func formattedPercent(_ value: Double, _ total: Double) -> String {
        guard total > 0 else { return "0%" }
        let pct = value / total
        return needPercentFormatter.string(from: NSNumber(value: pct)) ?? "0%"
    }
}

// MARK: - Compact Legend Chip for Horizontal Layout

struct CompactLegendChip: View {
    @Environment(\.yalaTheme) private var theme

    let need: SubcategoryNeed
    let amount: Double
    let total: Double
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(chipColor(for: need))
                    .frame(width: 6, height: 6)

                Text(need.displayName)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(Color.primary)

                Text(formattedPercent(amount, total))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(isSelected ? theme.background.opacity(0.5) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .opacity(isSelected ? 1.0 : 0.4)
        }
    }

    private func chipColor(for need: SubcategoryNeed) -> Color {
        need.color
    }

    private func formattedPercent(_ value: Double, _ total: Double) -> String {
        guard total > 0 else { return "0%" }
        let pct = value / total
        return needPercentFormatter.string(from: NSNumber(value: pct)) ?? "0%"
    }
}

// MARK: - Compact Mini Legend for Medium Size

struct CompactNeedLegendView: View {
    let selectedNeed: SubcategoryNeed?
    let onSelect: (SubcategoryNeed) -> Void

    private let allNeeds: [SubcategoryNeed] = [.essential, .priority, .optional, .unclassified]

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(allNeeds, id: \.self) { need in
                Button {
                    onSelect(need)
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(need.color)
                            .frame(width: 8, height: 8)

                        Text(need.displayName)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(Color.primary)
                    }
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(isSelected(need) ? need.color.opacity(0.15) : Color.clear)
                    )
                    .opacity(isActiveOrNoFilter(need) ? 1.0 : 0.4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isSelected(_ need: SubcategoryNeed) -> Bool {
        selectedNeed == need
    }

    private func isActiveOrNoFilter(_ need: SubcategoryNeed) -> Bool {
        selectedNeed == nil || selectedNeed == need
    }
}

// Extension to map need to color in View
// Uses distinct colors from brand palette to avoid confusion
extension SubcategoryNeed {
    var color: Color {
        switch self {
        case .essential: return .essentialNeed    // Amber
        case .priority: return .priorityNeedNew   // Violet
        case .optional: return .optionalNeed      // Rose
        case .unclassified: return .gray
        }
    }
}

// MARK: - Compact Bar Component (CashFlow Style)

struct NeedCompactBar: View {
    let need: SubcategoryNeed
    let amount: Double
    let maxAmount: Double
    let currencyCode: String
    let isSelected: Bool
    let onTap: () -> Void
    var variation: Double? = nil
    var showNAWhenNil: Bool = false

    @Environment(AppPreferences.self) private var appPreferences

    @State private var barWidth: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.xs) {
                // Name and Amount + Variation
                HStack {
                    Text(need.displayName)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    Spacer()
                    AmountText(
                        value: amount,
                        currencyCode: currencyCode,
                        size: .subheadline,
                        tint: isSelected ? .primary : .secondary
                    )

                    // Variation chip (aligned right of amount)
                    VariationChip(variation: variation, size: .small, showNAWhenNil: showNAWhenNil)
                }

                // Progress Bar
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: 8)

                    // Fill
                    let ratio = maxAmount > 0 ? (amount / maxAmount) : 0
                    Capsule()
                        .fill(need.color)
                        .frame(width: max(barWidth * ratio, 6), height: 8)
                }
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { barWidth = $0 }
            }
            .opacity(isSelected ? 1.0 : 0.4)
        }
        .buttonStyle(.plain)
    }
}
