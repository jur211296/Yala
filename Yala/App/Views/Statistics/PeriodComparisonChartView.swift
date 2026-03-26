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

    private var filteredPreviousPoints: [BarPoint] {
        previousPeriodPoints.filter { $0.value != 0 }
    }

    // Calculate X domain based on actual data range (current period only)
    // Previous period dates are adjusted to fit within current period domain
    private var dataXDomain: ClosedRange<Date> {
        guard !filteredCurrentPoints.isEmpty else { return currentInterval.start...currentInterval.end }
        guard let firstDate = filteredCurrentPoints.first?.date,
              let lastDate = filteredCurrentPoints.last?.date
        else { return currentInterval.start...currentInterval.end }

        // Add some padding
        let calendar = Calendar.current
        let paddingDays = 1
        let paddedStart = calendar.date(byAdding: .day, value: -paddingDays, to: firstDate) ?? firstDate
        let paddedEnd = calendar.date(byAdding: .day, value: paddingDays, to: lastDate) ?? lastDate

        return paddedStart...paddedEnd
    }

    // Filter previous period points to only show those that fit within current period domain
    // IMPORTANT: Sort by date after adjustment to prevent line from looping back
    private var clippedPreviousPoints: [BarPoint] {
        let domain = dataXDomain
        return filteredPreviousPoints.compactMap { point in
            let adjustedDate = adjustDateToCurrent(point.date)
            // Only include if adjusted date is within the domain
            guard adjustedDate >= domain.lowerBound && adjustedDate <= domain.upperBound else {
                return nil
            }
            return BarPoint(date: adjustedDate, value: point.value)
        }.sorted { $0.date < $1.date }
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

                // Invisible anchor point at top of chart for tooltip
                PointMark(
                    x: .value("Selected Date", activeDate),
                    y: .value("Top", yDomain.upperBound)
                )
                .symbolSize(0)
                .annotation(
                    position: .top,
                    alignment: tooltipAlignment(for: activeDate)
                ) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        // Current period value with date
                        HStack(spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(trendType.color)
                                .frame(width: 6, height: 6)
                            Text("\(periodLabel(for: selectedCurrentPoint.date)): \(formattedAmount(selectedCurrentPoint.value))")
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.thPrimaryText)
                        }

                        // Previous period value with original date (if exists)
                        if let previousPoint = selectedPreviousPoint {
                            let originalPrevDate = getOriginalPreviousDate(for: previousPoint.date)
                            HStack(spacing: DS.Spacing.xs) {
                                Circle()
                                    .fill(.thSecondaryText.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                Text("\(periodLabel(for: originalPrevDate)): \(formattedAmount(previousPoint.value))")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.thSecondaryText)
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
        .frame(height: 220)  // Match TrendChartView height
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

    /// Determines the alignment strategy based on period and comparison mode
    private var alignmentStrategy: AlignmentStrategy {
        switch comparisonMode {
        case .year:
            // Year mode: always align by exact calendar date (-1 year)
            return .calendarYear
        case .month:
            // Month mode: depends on period type
            switch period {
            case .thisWeek:
                // Weekly periods: align by day of week (Mon↔Mon, Tue↔Tue)
                return .dayOfWeek
            case .thisMonth, .lastMonth:
                // Monthly periods: align by day of month (13↔13)
                return .dayOfMonth
            case .last7Days, .last30Days, .custom, .thisYear, .lastYear, .allTime:
                // Rolling/custom periods: proportional mapping (day 1↔day 1)
                return .proportional
            }
        }
    }

    private enum AlignmentStrategy {
        case calendarYear   // Exact date -1 year
        case dayOfMonth     // Same day of month (13 → 13)
        case dayOfWeek      // Same day of week (Mon → Mon)
        case proportional   // Position-based (day 1 → day 1)
    }

    /// Adjust previous period dates to align with current period on X-axis
    /// Uses different strategies based on period type and comparison mode
    private func adjustDateToCurrent(_ previousDate: Date) -> Date {
        let calendar = Calendar.current

        switch alignmentStrategy {
        case .calendarYear:
            // Add 1 year to previous date to align with current
            return calendar.date(byAdding: .year, value: 1, to: previousDate) ?? previousDate

        case .dayOfMonth:
            // Align by day of month: Dec 13 → Jan 13
            let dayOfMonth = calendar.component(.day, from: previousDate)
            // Get the month/year from current interval start
            var components = calendar.dateComponents([.year, .month], from: currentInterval.start)
            components.day = dayOfMonth
            // Handle edge case: day doesn't exist in current month (e.g., 31 in Feb)
            if let targetDate = calendar.date(from: components) {
                return targetDate
            }
            // Fallback: use last day of current month
            let lastDayOfMonth = calendar.range(of: .day, in: .month, for: currentInterval.start)?.upperBound ?? 28
            components.day = min(dayOfMonth, lastDayOfMonth - 1)
            return calendar.date(from: components) ?? previousDate

        case .dayOfWeek:
            // Align by day of week: Mon → Mon, Tue → Tue
            let weekday = calendar.component(.weekday, from: previousDate)
            // Find the same weekday in current interval
            let currentWeekStart = currentInterval.start
            let currentWeekday = calendar.component(.weekday, from: currentWeekStart)
            let dayOffset = weekday - currentWeekday
            return calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart) ?? previousDate

        case .proportional:
            // Original proportional mapping
            let previousDuration = previousInterval.duration
            let currentDuration = currentInterval.duration
            guard previousDuration > 0 else { return previousDate }
            let relativePosition = previousDate.timeIntervalSince(previousInterval.start) / previousDuration
            return currentInterval.start.addingTimeInterval(relativePosition * currentDuration)
        }
    }

    /// Get the original previous period date for a given current period date (inverse mapping)
    private func getOriginalPreviousDate(for currentDate: Date) -> Date {
        let calendar = Calendar.current

        switch alignmentStrategy {
        case .calendarYear:
            // Subtract 1 year from current date
            return calendar.date(byAdding: .year, value: -1, to: currentDate) ?? currentDate

        case .dayOfMonth:
            // Inverse: get day of month from current, apply to previous month
            let dayOfMonth = calendar.component(.day, from: currentDate)
            var components = calendar.dateComponents([.year, .month], from: previousInterval.start)
            components.day = dayOfMonth
            if let targetDate = calendar.date(from: components) {
                return targetDate
            }
            // Fallback: use last day of previous month
            let lastDayOfMonth = calendar.range(of: .day, in: .month, for: previousInterval.start)?.upperBound ?? 28
            components.day = min(dayOfMonth, lastDayOfMonth - 1)
            return calendar.date(from: components) ?? currentDate

        case .dayOfWeek:
            // Inverse: get weekday from current, find same in previous week
            let weekday = calendar.component(.weekday, from: currentDate)
            let previousWeekStart = previousInterval.start
            let previousWeekday = calendar.component(.weekday, from: previousWeekStart)
            let dayOffset = weekday - previousWeekday
            return calendar.date(byAdding: .day, value: dayOffset, to: previousWeekStart) ?? currentDate

        case .proportional:
            // Original inverse proportional mapping
            let currentDuration = currentInterval.duration
            let previousDuration = previousInterval.duration
            guard currentDuration > 0 else { return currentDate }
            let relativePosition = currentDate.timeIntervalSince(currentInterval.start) / currentDuration
            return previousInterval.start.addingTimeInterval(relativePosition * previousDuration)
        }
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

        let calendarUnit: Calendar.Component = {
            switch grouping {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            }
        }()

        let rawDates = SmartAxisHelper.calculateSmartAxisDates(
            forDataDates: filteredCurrentPoints.map(\.date),
            grouping: calendarUnit
        )

        // Deduplicate: remove dates that would produce the same formatted label
        guard let firstDate = filteredCurrentPoints.first?.date,
              let lastDate = filteredCurrentPoints.last?.date else { return rawDates }

        let forceGrouping: Calendar.Component? = {
            switch grouping {
            case .month: return .month
            case .week: return .weekOfYear
            case .day: return nil
            }
        }()

        var seen = Set<String>()
        return rawDates.filter { date in
            let label = SmartAxisHelper.formatAxisLabel(
                for: date, startDate: firstDate, endDate: lastDate, forceGrouping: forceGrouping)
            return seen.insert(label).inserted
        }
    }

    /// Format axis label based on data span
    private func smartAxisLabel(for date: Date) -> String {
        guard let firstDate = filteredCurrentPoints.first?.date,
            let lastDate = filteredCurrentPoints.last?.date
        else { return "" }

        let forceGrouping: Calendar.Component? = {
            switch grouping {
            case .month: return .month
            case .week: return .weekOfYear
            case .day: return nil
            }
        }()

        return SmartAxisHelper.formatAxisLabel(
            for: date, startDate: firstDate, endDate: lastDate, forceGrouping: forceGrouping)
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
