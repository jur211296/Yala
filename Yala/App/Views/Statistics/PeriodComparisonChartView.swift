//
//  PeriodComparisonChartView.swift
//  Yala
//
//  Period comparison chart showing current vs previous period trends.
//

import Charts
import SwiftData
import SwiftUI

struct PeriodComparisonChartView: View {
    let currentPeriodPoints: [BarPoint]
    let previousPeriodPoints: [BarPoint]
    let yDomain: ClosedRange<Double>
    let grouping: TrendGrouping
    let currentInterval: DateInterval
    let previousInterval: DateInterval
    let currencyCode: String
    let trendType: TrendType
    let chartHeight: CGFloat
    let period: DetailPeriod
    let comparisonMode: ComparisonMode
    var showPreviousPeriod: Bool = true

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.yalaTheme) private var theme
    @State private var draggingDate: Date?  // For transient drag state

    // Filter points to only include those with actual data (non-zero values)
    private var filteredCurrentPoints: [BarPoint] {
        currentPeriodPoints.filter { $0.value != 0 }
    }

    // Calculate X domain based on actual data range (current period only).
    // Delega en DateAlignmentHelper (SSOT del dominio, compartido con el KPI — p20-15).
    private var dataXDomain: ClosedRange<Date> {
        DateAlignmentHelper.currentDataDomain(
            currentPoints: currentPeriodPoints,
            currentInterval: currentInterval
        )
    }

    // Previous period points aligned + clipped to the current period domain.
    // SSOT del pipeline de clipping, compartido con el KPI (`alignedPreviousTotal`)
    // — así la curva y el número no pueden divergir.
    private var clippedPreviousPoints: [BarPoint] {
        DateAlignmentHelper.clippedPreviousPoints(
            previousPoints: previousPeriodPoints,
            currentPoints: currentPeriodPoints,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: period,
            comparisonMode: comparisonMode
        )
    }

    var body: some View {
        Chart {
            let primaryLineColor = trendType.color
            let previousLineColor = theme.secondaryText

            // Previous period line - separate series (using clipped points) - only show when showPreviousPeriod is true
            if showPreviousPeriod {
                ForEach(clippedPreviousPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),  // Already adjusted in clippedPreviousPoints
                        y: .value("Previous", point.value),
                        series: .value("Period", "Previous")
                    )
                    .foregroundStyle(previousLineColor.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .interpolationMethod(.monotone)
                }

                // Single point: LineMark is invisible with 1 point, show a dot instead
                if clippedPreviousPoints.count == 1, let singlePoint = clippedPreviousPoints.first {
                    PointMark(
                        x: .value("Date", singlePoint.date),
                        y: .value("Previous", singlePoint.value)
                    )
                    .foregroundStyle(previousLineColor.opacity(0.5))
                    .symbolSize(64)
                }
            }

            // Current period line - separate series
            ForEach(filteredCurrentPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Current", point.value),
                    series: .value("Period", "Current")
                )
                .foregroundStyle(primaryLineColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }

            // Single point: LineMark is invisible with 1 point, show a dot instead
            if filteredCurrentPoints.count == 1, let singlePoint = filteredCurrentPoints.first {
                PointMark(
                    x: .value("Date", singlePoint.date),
                    y: .value("Current", singlePoint.value)
                )
                .foregroundStyle(primaryLineColor)
                .symbolSize(64)
            }

            // Zero baseline (for balance metric)
            if trendType == .balance {
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(.thSecondaryText.opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }

            // Interaction: Scrubbing Rule Mark
            if let activeDate = draggingDate,
                let selectedCurrentPoint = closestPoint(to: activeDate, in: filteredCurrentPoints)
            {
                // Find corresponding previous period point (already adjusted in clippedPreviousPoints)
                let selectedPreviousPoint = closestPoint(to: activeDate, in: clippedPreviousPoints)

                // Vertical dashed line
                RuleMark(x: .value("Selected Date", activeDate))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.thSecondaryText)

                // Ring Border (Background) on data point
                PointMark(
                    x: .value("Selected Date", activeDate),
                    y: .value("Selected Value", selectedCurrentPoint.value)
                )
                .symbolSize(140)
                .foregroundStyle(trendType.color)

                // Main Dot (Foreground) on data point
                PointMark(
                    x: .value("Selected Date", activeDate),
                    y: .value("Selected Value", selectedCurrentPoint.value)
                )
                .symbolSize(100)
                .foregroundStyle(.thCard)

                // Invisible anchor para tooltip ~25% bajo el top — evita choque con
                // el KPI del header del card (consistente con TrendChartView).
                let tooltipAnchorY = yDomain.upperBound
                    - (yDomain.upperBound - yDomain.lowerBound) * 0.25
                PointMark(
                    x: .value("Selected Date", activeDate),
                    y: .value("TooltipAnchor", tooltipAnchorY)
                )
                .symbolSize(0)
                .annotation(
                    position: .top,
                    alignment: tooltipAlignment(for: activeDate)
                ) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        // Current period value with date
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(trendType.color)
                                .frame(width: 6, height: 6)
                            Text("\(periodLabel(for: selectedCurrentPoint.date)):")
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.thPrimaryText)
                            // `.annotation` no propaga environment objects — AmountText (lee
                            // @Environment(AppPreferences.self)) dispara SIGTRAP aquí. Text pre-resuelto
                            // con el formatter estático (esta vista no inyecta AppPreferences).
                            Text(YalaFormatterStatic.currency(value: selectedCurrentPoint.value, currencyCode: currencyCode))
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.primary)
                        }

                        // Previous period value with original date (if exists)
                        if let previousPoint = selectedPreviousPoint {
                            let originalPrevDate = getOriginalPreviousDate(for: previousPoint.date)
                            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                                Circle()
                                    .fill(.thSecondaryText.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                Text("\(periodLabel(for: originalPrevDate)):")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.thSecondaryText)
                                Text(YalaFormatterStatic.currency(value: previousPoint.value, currencyCode: currencyCode))
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(.thCard.opacity(0.95))
                            .shadow(radius: 2)
                    )
                }
            }
        }
        .chartXScale(domain: dataXDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: smartAxisDates) { value in
                AxisGridLine()
                    .foregroundStyle(.thSecondaryText.opacity(0.1))

                if let date = value.as(Date.self) {
                    let isLast = date == smartAxisDates.last
                    let isFirst = date == smartAxisDates.first
                    let anchor: UnitPoint =
                        isLast ? .topTrailing : (isFirst ? .topLeading : .top)

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
                        Text(formatCurrencyShort(value: doubleValue))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.thSecondaryText)
                    }
                }
            }
        }
        .chartXSelection(value: $draggingDate)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Accessibility.periodComparison)
        .accessibilityValue(currentPeriodPoints.isEmpty ? L10n.Accessibility.noData :
            L10n.Accessibility.periodComparisonValue(currentPeriodPoints.count))
        .frame(height: chartHeight)  // Respect prop (callsite controls height)
        .chartLegend(position: .top, alignment: .leading) {
            HStack(spacing: DS.Spacing.lg) {
                // Current period legend
                HStack(spacing: DS.Spacing.xs) {
                    Rectangle()
                        .fill(trendType.color)
                        .frame(width: 20, height: 3)
                    Text(L10n.Statistics.currentPeriod)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thSecondaryText)
                }

                // Previous period legend (only show when showPreviousPeriod is true)
                if showPreviousPeriod {
                    HStack(spacing: DS.Spacing.xs) {
                        Rectangle()
                            .fill(.thSecondaryText.opacity(0.5))
                            .frame(width: 20, height: 3)
                        Text(L10n.Statistics.previousPeriod)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.thSecondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Get the original previous period date for a given current period date (inverse mapping).
    private func getOriginalPreviousDate(for currentDate: Date) -> Date {
        DateAlignmentHelper.getOriginalPreviousDate(
            for: currentDate,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: period,
            comparisonMode: comparisonMode
        )
    }

    /// Format currency value for Y-axis (shortened) - matches TrendChartView format
    private func formatCurrencyShort(value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""

        if absValue >= 1000 {
            let kValue = absValue / 1000.0
            return String(format: "%@%.0fK", sign, kValue)
        } else {
            return String(format: "%@%.0f", sign, absValue)
        }
    }

    /// Calculate smart axis dates aligned with actual data points
    private var smartAxisDates: [Date] {
        guard !filteredCurrentPoints.isEmpty else { return [] }

        let rawDates = SmartAxisHelper.calculateSmartAxisDates(
            forDataDates: filteredCurrentPoints.map(\.date),
            grouping: grouping.calendarComponent
        )

        guard let firstDate = currentFirstDate,
              let lastDate = currentLastDate else { return rawDates }
        return SmartAxisHelper.deduplicatedAxisDates(
            rawDates, firstDate: firstDate, lastDate: lastDate,
            forceGrouping: grouping.forceAxisGrouping)
    }

    /// Format axis label based on data span
    private var currentFirstDate: Date? { filteredCurrentPoints.first?.date }
    private var currentLastDate: Date? { filteredCurrentPoints.last?.date }

    private func smartAxisLabel(for date: Date) -> String {
        guard let firstDate = currentFirstDate,
            let lastDate = currentLastDate
        else { return "" }

        return SmartAxisHelper.formatAxisLabel(
            for: date, startDate: firstDate, endDate: lastDate, forceGrouping: grouping.forceAxisGrouping)
    }

    /// Find closest point to given date
    private func closestPoint(to date: Date, in data: [BarPoint]) -> BarPoint? {
        return data.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    /// Safe tooltip alignment based on date position in interval
    private func tooltipAlignment(for date: Date) -> Alignment {
        // Calculate position as percentage of interval
        let intervalDuration = currentInterval.end.timeIntervalSince(currentInterval.start)
        guard intervalDuration > 0 else { return .center }

        let datePosition = date.timeIntervalSince(currentInterval.start)
        let percentage = datePosition / intervalDuration

        if percentage < 0.25 {
            return .leading
        } else if percentage > 0.75 {
            return .trailing
        } else {
            return .center
        }
    }

    private static let periodDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "d MMM yy"
        return f
    }()

    private static let periodMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "MMM yy"
        return f
    }()

    /// Format period label for tooltip
    private func periodLabel(for date: Date) -> String {
        let formatter: DateFormatter
        switch grouping {
        case .day, .week: formatter = Self.periodDayFormatter
        case .month: formatter = Self.periodMonthFormatter
        }
        return formatter.string(from: date).lowercased().replacing(".", with: "")
    }

    /// Format amount for tooltip
    private func formattedAmount(_ value: Double) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(0))
        )
    }
}
