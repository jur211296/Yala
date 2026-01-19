//
//  NatureTrendWidget.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Charts
import SwiftUI

struct NatureTrendWidget: View {
    let trendPoints: [NatureTrendPoint]
    let selectedNature: SubcategoryNature?
    let currencyCode: String
    let size: TopCategoriesWidget.CardSize  // Reusing comparable size enum or WidgetSize
    let grouping: TrendGrouping
    let interval: DateInterval
    let onSelectNature: (SubcategoryNature) -> Void
    let onShowDetail: (() -> Void)?

    // MARK: - Period Comparison

    var period: DetailPeriod = .thisMonth
    var previousTotalAmount: Double? = nil
    var previousAmountByNature: [SubcategoryNature: Double] = [:]
    var showVariationHeader: Bool = false
    var comparisonMode: ComparisonMode = .month

    /// When true, shows a message that nature classification doesn't apply to income
    var isIncomeMode: Bool = false

    private var totalAmount: Double {
        trendPoints.reduce(0) { $0 + $1.total }
    }

    private var variation: Double? {
        guard let previous = previousTotalAmount else { return nil }
        return PreviousPeriodHelper.calculateVariation(
            currentAmount: totalAmount,
            previousAmount: previous
        )
    }

    private var previousInterval: DateInterval {
        PreviousPeriodHelper.previousInterval(for: period, mode: comparisonMode, customRange: nil)
    }

    private var comparisonText: String {
        PreviousPeriodHelper.formatComparisonText(
            previousInterval: previousInterval,
            period: period,
            mode: comparisonMode
        )
    }

    /// Calculate variation for a specific nature
    private func variationForNature(_ nature: SubcategoryNature, currentAmount: Double) -> Double? {
        guard let previousAmount = previousAmountByNature[nature] else { return nil }
        return PreviousPeriodHelper.calculateVariation(
            currentAmount: currentAmount,
            previousAmount: previousAmount
        )
    }

    init(
        trendPoints: [NatureTrendPoint],
        selectedNature: SubcategoryNature?,
        currencyCode: String,
        size: TopCategoriesWidget.CardSize,
        grouping: TrendGrouping,
        interval: DateInterval,
        onSelectNature: @escaping (SubcategoryNature) -> Void,
        onShowDetail: (() -> Void)? = nil,
        period: DetailPeriod = .thisMonth,
        previousTotalAmount: Double? = nil,
        previousAmountByNature: [SubcategoryNature: Double] = [:],
        showVariationHeader: Bool = false,
        comparisonMode: ComparisonMode = .month,
        isIncomeMode: Bool = false
    ) {
        self.trendPoints = trendPoints
        self.selectedNature = selectedNature
        self.currencyCode = currencyCode
        self.size = size
        self.grouping = grouping
        self.interval = interval
        self.onSelectNature = onSelectNature
        self.onShowDetail = onShowDetail
        self.period = period
        self.previousTotalAmount = previousTotalAmount
        self.previousAmountByNature = previousAmountByNature
        self.showVariationHeader = showVariationHeader
        self.comparisonMode = comparisonMode
        self.isIncomeMode = isIncomeMode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header - simplified when in income mode (no KPI makes sense)
            HStack(alignment: .top) {
                // Left: Title and total amount (hide KPI in income mode)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L10n.Nature.title)
                        .font(.headline)
                        .foregroundStyle(Color.netoPrimaryText)

                    // Total amount with "vs previous" comparison - only show when NOT in income mode
                    if !isIncomeMode {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                            Text(
                                NetoFormatter.currency(
                                    value: totalAmount, currencyCode: currencyCode)
                            )
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.netoPrimaryText)

                            // Show previous period value for comparison
                            if let prevAmount = previousTotalAmount {
                                Text("vs \(NetoFormatter.number(value: prevAmount))")
                                    .font(.caption)
                                    .foregroundStyle(Color.netoSecondaryText)
                            }
                        }
                    }
                }

                Spacer()

                // Right: Variation chip and comparison text (only when showVariationHeader and has data, not in income mode)
                if !isIncomeMode && showVariationHeader && !trendPoints.isEmpty && variation != nil {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        VariationChip(variation: variation, size: .medium)

                        if !comparisonText.isEmpty {
                            Text(comparisonText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Navigation / Detail
                if onShowDetail != nil {
                    Button {
                        onShowDetail?()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundStyle(Color.secondary.opacity(0.7))
                    }
                    .padding(.top, DS.Spacing.xs)
                }
            }

            // Content
            if isIncomeMode {
                // Income mode: nature classification doesn't apply
                // Show centered message without KPI (header already hidden via conditional)
                Spacer()
                VStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(L10n.Nature.incomeNotApplicable)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else if trendPoints.isEmpty {
                Spacer()
                Text(L10n.Widget.noExpensesNaturePeriod)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                chartView
            }
        }
        .padding(DS.Card.paddingCompact)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.netoCard)
                .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 4)
        )
    }

    @ViewBuilder
    private var chartView: some View {
        if size == .large {
            // Large: Chart + Legend (legend handles filtering)
            VStack(spacing: DS.Spacing.lg) {
                NatureTrendChartView(
                    points: trendPoints, selectedNature: selectedNature, currencyCode: currencyCode,
                    grouping: grouping, interval: interval,
                    onSelectNature: nil  // Legend handles explicit selection
                )

                NatureLegendView(
                    points: trendPoints,
                    selectedNature: selectedNature,
                    onSelect: onSelectNature
                )
            }
        } else {
            // Compact: Summary Bars Layout (like CashFlowWidget)
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Calculate totals and max for normalization
                let essentialTotal = trendPoints.reduce(0) { $0 + $1.essential }
                let priorityTotal = trendPoints.reduce(0) { $0 + $1.priority }
                let optionalTotal = trendPoints.reduce(0) { $0 + $1.optional }
                let unclassifiedTotal = trendPoints.reduce(0) { $0 + $1.unclassified }
                let maxVal = max(
                    essentialTotal, max(priorityTotal, max(optionalTotal, unclassifiedTotal)))

                VStack(spacing: DS.Spacing.md) {
                    // Essential Bar
                    NatureCompactBar(
                        nature: .essential,
                        amount: essentialTotal,
                        maxAmount: maxVal,
                        currencyCode: currencyCode,
                        isSelected: selectedNature == nil || selectedNature == .essential,
                        onTap: { onSelectNature(.essential) },
                        variation: variationForNature(.essential, currentAmount: essentialTotal),
                        showNAWhenNil: showVariationHeader
                    )

                    // Priority Bar
                    NatureCompactBar(
                        nature: .priority,
                        amount: priorityTotal,
                        maxAmount: maxVal,
                        currencyCode: currencyCode,
                        isSelected: selectedNature == nil || selectedNature == .priority,
                        onTap: { onSelectNature(.priority) },
                        variation: variationForNature(.priority, currentAmount: priorityTotal),
                        showNAWhenNil: showVariationHeader
                    )

                    // Optional Bar
                    NatureCompactBar(
                        nature: .optional,
                        amount: optionalTotal,
                        maxAmount: maxVal,
                        currencyCode: currencyCode,
                        isSelected: selectedNature == nil || selectedNature == .optional,
                        onTap: { onSelectNature(.optional) },
                        variation: variationForNature(.optional, currentAmount: optionalTotal),
                        showNAWhenNil: showVariationHeader
                    )

                    // Unclassified Bar (only if has value)
                    if unclassifiedTotal > 0 {
                        NatureCompactBar(
                            nature: .unclassified,
                            amount: unclassifiedTotal,
                            maxAmount: maxVal,
                            currencyCode: currencyCode,
                            isSelected: selectedNature == nil || selectedNature == .unclassified,
                            onTap: { onSelectNature(.unclassified) },
                            variation: variationForNature(.unclassified, currentAmount: unclassifiedTotal),
                            showNAWhenNil: showVariationHeader
                        )
                    }
                }
            }
        }
    }

    private func getTotal(for nature: SubcategoryNature) -> Double {
        trendPoints.reduce(0) { partialResult, point in
            switch nature {
            case .essential: return partialResult + point.essential
            case .priority: return partialResult + point.priority
            case .optional: return partialResult + point.optional
            case .unclassified: return partialResult + point.unclassified
            }
        }
    }

}

struct NatureTrendChartView: View {
    let points: [NatureTrendPoint]
    let selectedNature: SubcategoryNature?
    let currencyCode: String
    let grouping: TrendGrouping
    let interval: DateInterval
    let onSelectNature: ((SubcategoryNature) -> Void)?
    @State private var selectedDate: Date?

    // Flattened data struct for the chart
    struct ChartItem: Identifiable {
        let id = UUID()
        let date: Date
        let nature: SubcategoryNature
        let amount: Double
    }

    // MARK: - Smart Axis Logic

    /// Calculate smart axis dates for chart X-axis
    private var smartAxisDates: [Date] {
        guard !points.isEmpty else { return [] }
        guard let firstDate = points.first?.date,
            let lastDate = points.last?.date
        else { return [] }
        return SmartAxisHelper.calculateSmartAxisDates(from: firstDate, to: lastDate)
    }

    /// Format axis label based on data span
    private func smartAxisLabel(for date: Date) -> String {
        guard let firstDate = points.first?.date,
            let lastDate = points.last?.date
        else { return "" }
        return SmartAxisHelper.formatAxisLabel(for: date, startDate: firstDate, endDate: lastDate)
    }

    /// X-axis domain based on actual data range (not period range)
    private var dataXDomain: ClosedRange<Date> {
        guard let firstDate = points.first?.date,
            let lastDate = points.last?.date
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

    var body: some View {
        let chartUnit = mapGroupingToUnit(grouping)

        // Calculate max value for Y domain with minimal padding
        let maxValue = calculateMaxValue()
        let yDomain: ClosedRange<Double> = 0...(maxValue * 1.05)  // 5% padding instead of default ~20%

        Chart {
            ForEach(flattenData(points)) { item in
                // If a nature is selected, only show that nature (or dim others)
                // Design Choice: If filtered, show ONLY that line. If not, show ALL lines stacked?
                // Or show all lines but highlight selected?
                // Let's match typical behavior: If filtered, show only that ONE series.
                // If ALL (nil), show stacked area or multiple lines.
                // Given "Gastos por naturaleza", Stacked Bar is good for composition.

                if let selected = selectedNature {
                    if item.nature == selected {
                        BarMark(
                            x: .value("Fecha", item.date, unit: chartUnit),
                            y: .value("Monto", item.amount)
                        )
                        .foregroundStyle(item.nature.color.gradient)
                        .cornerRadius(DS.Radius.xs)
                    }
                } else {
                    BarMark(
                        x: .value("Fecha", item.date, unit: chartUnit),
                        y: .value("Monto", item.amount)
                    )
                    .foregroundStyle(item.nature.color.gradient)
                    .cornerRadius(DS.Radius.xs)
                }
            }
        }
        .chartXScale(domain: dataXDomain)
        .chartYScale(domain: yDomain)
        .chartForegroundStyleScale([
            L10n.Nature.essential: Color.essentialNature,
            L10n.Nature.priority: Color.priorityNatureNew,
            L10n.Nature.optional: Color.optionalNature,
            L10n.Nature.unclassified: Color.gray,
        ])
        .chartLegend(.hidden)
        // X-Axis: Smart dynamic labels matching TrendChartView
        .chartXAxis {
            AxisMarks(values: smartAxisDates) { value in
                AxisGridLine()
                    .foregroundStyle(Color.netoSecondaryText.opacity(0.1))

                if let date = value.as(Date.self) {
                    // Use trailing anchor for last label to prevent truncation
                    let isLast = date == smartAxisDates.last
                    let isFirst = date == smartAxisDates.first
                    let anchor: UnitPoint = isLast ? .topTrailing : (isFirst ? .topLeading : .top)

                    AxisValueLabel(anchor: anchor) {
                        Text(smartAxisLabel(for: date))
                            .font(.caption2.bold())
                            .foregroundStyle(Color.netoSecondaryText)
                    }
                }
            }
        }
        // Y-Axis: Right (Trailing), minimal gridlines for clean look
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.netoSecondaryText.opacity(0.1))
                if let amount = value.as(Double.self) {
                    AxisValueLabel {
                        Text(formatAxisAmount(amount))
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
                        .fill(Color.netoSecondaryText.opacity(0.3))
                        .frame(width: 1, height: plotFrame.height)
                        .position(x: xPos + plotFrame.origin.x, y: plotFrame.midY)

                    // Tooltip Card
                    VStack(spacing: DS.Spacing.xs) {
                        Text(formatDateFull(selectedData.date, grouping: grouping))
                            .font(.caption2)
                            .foregroundStyle(Color.netoSecondaryText)

                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            if selectedData.essential > 0 {
                                TooltipRow(
                                    nature: .essential, amount: selectedData.essential,
                                    currencyCode: currencyCode)
                            }
                            if selectedData.priority > 0 {
                                TooltipRow(
                                    nature: .priority, amount: selectedData.priority,
                                    currencyCode: currencyCode)
                            }
                            if selectedData.optional > 0 {
                                TooltipRow(
                                    nature: .optional, amount: selectedData.optional,
                                    currencyCode: currencyCode)
                            }
                            if selectedData.unclassified > 0 {
                                TooltipRow(
                                    nature: .unclassified, amount: selectedData.unclassified,
                                    currencyCode: currencyCode)
                            }
                            Divider()
                            HStack {
                                Text(L10n.Widget.total)
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondary)
                                Spacer()
                                Text(
                                    NetoFormatter.currency(
                                        value: selectedData.total, currencyCode: currencyCode)
                                )
                                .font(.caption2.bold())
                                .foregroundStyle(Color.primary)
                            }
                        }
                    }
                    .padding(DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color.netoCard)
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

    private func calculateMaxValue() -> Double {
        guard !points.isEmpty else { return 100 }

        if let selected = selectedNature {
            // If a nature is selected, find max for that nature
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

    private func formatDateFull(_ date: Date, grouping: TrendGrouping) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        switch grouping {
        case .day: formatter.dateFormat = "d MMM yy"  // 19 dic 25
        case .week: formatter.dateFormat = "d MMM yy"  // 19 dic 25
        case .month: formatter.dateFormat = "MMM yy"  // ene 25
        }
        return formatter.string(from: date).lowercased().replacingOccurrences(of: ".", with: "")
    }

    struct TooltipRow: View {
        let nature: SubcategoryNature
        let amount: Double
        let currencyCode: String

        var body: some View {
            HStack {
                Circle().fill(nature.color).frame(width: 6, height: 6)
                Text(nature.displayName)
                    .font(.caption2)
                    .foregroundStyle(Color.primary)
                Spacer()
                // Simple formatting for tooltip
                Text(NetoFormatter.currency(value: amount, currencyCode: currencyCode))
                    .font(.caption2.bold())
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

    private func formatDate(_ date: Date, grouping: TrendGrouping) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        switch grouping {
        case .day: formatter.dateFormat = "d"
        case .week: formatter.dateFormat = "d MMM"
        case .month: formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }

    private func flattenData(_ points: [NatureTrendPoint]) -> [ChartItem] {
        var items: [ChartItem] = []
        for point in points {
            // Add all natures
            if shouldShow(.essential) {
                items.append(
                    ChartItem(date: point.date, nature: .essential, amount: point.essential))
            }
            if shouldShow(.priority) {
                items.append(ChartItem(date: point.date, nature: .priority, amount: point.priority))
            }
            if shouldShow(.optional) {
                items.append(ChartItem(date: point.date, nature: .optional, amount: point.optional))
            }
            if shouldShow(.unclassified) {  // Only show if > 0 or if logic requires?
                items.append(
                    ChartItem(date: point.date, nature: .unclassified, amount: point.unclassified))
            }
        }
        return items
    }

    private func shouldShow(_ nature: SubcategoryNature) -> Bool {
        if let selected = selectedNature {
            return selected == nature
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

struct NatureLegendView: View {
    let points: [NatureTrendPoint]
    let selectedNature: SubcategoryNature?
    let onSelect: (SubcategoryNature) -> Void

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
                    nature: .essential, amount: essentials, total: total,
                    isSelected: selectedNature == .essential || selectedNature == nil,
                    onTap: { onSelect(.essential) })
                CompactLegendChip(
                    nature: .priority, amount: priorities, total: total,
                    isSelected: selectedNature == .priority || selectedNature == nil,
                    onTap: { onSelect(.priority) })
                CompactLegendChip(
                    nature: .optional, amount: optionals, total: total,
                    isSelected: selectedNature == .optional || selectedNature == nil,
                    onTap: { onSelect(.optional) })
                if unclassified > 0 {
                    CompactLegendChip(
                        nature: .unclassified, amount: unclassified, total: total,
                        isSelected: selectedNature == .unclassified || selectedNature == nil,
                        onTap: { onSelect(.unclassified) })
                }
            }
        }
    }
}

struct LegendItem: View {
    let nature: SubcategoryNature
    let amount: Double
    let total: Double
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(extensionColor(for: nature))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 0) {
                    Text(nature.displayName)
                        .font(.caption)
                        .foregroundStyle(Color.primary)

                    Text("\(formattedPercent(amount, total))")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
            }
            .padding(DS.Spacing.sm)
            .background(isSelected ? Color.netoBackground : Color.clear)
            .cornerRadius(DS.Radius.sm)
            .opacity(isSelected ? 1.0 : 0.4)
        }
    }

    private func extensionColor(for nature: SubcategoryNature) -> Color {
        nature.color
    }

    private func formattedPercent(_ value: Double, _ total: Double) -> String {
        guard total > 0 else { return "0%" }
        let pct = value / total
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: pct)) ?? "0%"
    }
}

// MARK: - Compact Legend Chip for Horizontal Layout

struct CompactLegendChip: View {
    let nature: SubcategoryNature
    let amount: Double
    let total: Double
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(chipColor(for: nature))
                    .frame(width: 6, height: 6)

                Text(nature.displayName)
                    .font(.caption2)
                    .foregroundStyle(Color.primary)

                Text(formattedPercent(amount, total))
                    .font(.caption2)
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background(isSelected ? Color.netoBackground.opacity(0.5) : Color.clear)
            .cornerRadius(DS.Radius.md)
            .opacity(isSelected ? 1.0 : 0.4)
        }
    }

    private func chipColor(for nature: SubcategoryNature) -> Color {
        nature.color
    }

    private func formattedPercent(_ value: Double, _ total: Double) -> String {
        guard total > 0 else { return "0%" }
        let pct = value / total
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: pct)) ?? "0%"
    }
}

// MARK: - Compact Mini Legend for Medium Size

struct CompactNatureLegendView: View {
    let selectedNature: SubcategoryNature?
    let onSelect: (SubcategoryNature) -> Void

    private let allNatures: [SubcategoryNature] = [.essential, .priority, .optional, .unclassified]

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(allNatures, id: \.self) { nature in
                Button {
                    onSelect(nature)
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(nature.color)
                            .frame(width: 8, height: 8)

                        Text(nature.displayName)
                            .font(.caption2)
                            .foregroundStyle(Color.primary)
                    }
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(isSelected(nature) ? nature.color.opacity(0.15) : Color.clear)
                    )
                    .opacity(isActiveOrNoFilter(nature) ? 1.0 : 0.4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isSelected(_ nature: SubcategoryNature) -> Bool {
        selectedNature == nature
    }

    private func isActiveOrNoFilter(_ nature: SubcategoryNature) -> Bool {
        selectedNature == nil || selectedNature == nature
    }
}

// Extension to map nature to color in View
// Uses distinct colors from brand palette to avoid confusion
extension SubcategoryNature {
    var color: Color {
        switch self {
        case .essential: return .essentialNature    // Amber
        case .priority: return .priorityNatureNew   // Violet
        case .optional: return .optionalNature      // Rose
        case .unclassified: return .gray
        }
    }
}

// MARK: - Compact Bar Component (CashFlow Style)

struct NatureCompactBar: View {
    let nature: SubcategoryNature
    let amount: Double
    let maxAmount: Double
    let currencyCode: String
    let isSelected: Bool
    let onTap: () -> Void
    var variation: Double? = nil
    var showNAWhenNil: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.xs) {
                // Name and Amount + Variation
                HStack {
                    Text(nature.displayName)
                        .font(.subheadline)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    Spacer()
                    Text(NetoFormatter.currency(value: amount, currencyCode: currencyCode))
                        .font(DS.Typography.amountSmall)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)

                    // Variation chip (aligned right of amount)
                    VariationChip(variation: variation, size: .small, showNAWhenNil: showNAWhenNil)
                }

                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        Capsule()
                            .fill(Color.primary.opacity(0.05))
                            .frame(height: 8)

                        // Fill
                        let width = maxAmount > 0 ? (amount / maxAmount) * geo.size.width : 0
                        Capsule()
                            .fill(nature.color)
                            .frame(width: max(width, 6), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .opacity(isSelected ? 1.0 : 0.4)
        }
        .buttonStyle(.plain)
    }
}
