//
//  PeriodComparisonChartView.swift
//  Neto
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
    let interval: DateInterval
    let currencyCode: String
    let trendType: TrendType
    let chartHeight: CGFloat

    @Environment(\.colorScheme) var colorScheme
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
        guard !filteredCurrentPoints.isEmpty else { return interval.start...interval.end }
        guard let firstDate = filteredCurrentPoints.first?.date,
              let lastDate = filteredCurrentPoints.last?.date
        else { return interval.start...interval.end }

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
            let previousLineColor = Color.netoSecondaryText

            // Previous period line - separate series (using clipped points)
            ForEach(clippedPreviousPoints) { point in
                LineMark(
                    x: .value("Date", point.date),  // Already adjusted in clippedPreviousPoints
                    y: .value("Previous", point.value),
                    series: .value("Period", "Previous")
                )
                .foregroundStyle(previousLineColor.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                .interpolationMethod(.catmullRom)
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
                .interpolationMethod(.catmullRom)
            }

            // Zero baseline (for balance metric)
            if trendType == .balance {
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.netoSecondaryText.opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
            }

            // Interaction: Scrubbing Rule Mark
            if let activeDate = draggingDate,
                let selectedCurrentPoint = closestPoint(to: activeDate, in: filteredCurrentPoints)
            {
                // Find corresponding previous period point (already adjusted in clippedPreviousPoints)
                let selectedPreviousPoint = closestPoint(to: activeDate, in: clippedPreviousPoints)

                RuleMark(x: .value("Selected Date", activeDate))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(Color.netoSecondaryText)

                // Ring Border (Background)
                PointMark(
                    x: .value("Selected Date", activeDate),
                    y: .value("Selected Value", selectedCurrentPoint.value)
                )
                .symbolSize(140)
                .foregroundStyle(trendType.color)

                // Main Dot (Foreground)
                PointMark(
                    x: .value("Selected Date", activeDate),
                    y: .value("Selected Value", selectedCurrentPoint.value)
                )
                .symbolSize(100)
                .foregroundStyle(Color.netoCard)

                // Tooltip showing both values - dynamic position based on point height
                .annotation(
                    position: tooltipShouldBeBelow(for: selectedCurrentPoint.value) ? .bottom : .top,
                    alignment: tooltipAlignment(for: activeDate)
                ) {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(periodLabel(for: activeDate))
                            .font(.caption2)
                            .foregroundStyle(Color.netoSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)

                        // Current period value
                        HStack(spacing: DS.Spacing.xs) {
                            Circle()
                                .fill(trendType.color)
                                .frame(width: 6, height: 6)
                            Text("\(formattedAmount(selectedCurrentPoint.value)) \(currencyCode)")
                                .font(.caption.bold())
                                .foregroundStyle(Color.netoPrimaryText)
                        }

                        // Previous period value (if exists)
                        if let previousPoint = selectedPreviousPoint {
                            HStack(spacing: DS.Spacing.xs) {
                                Circle()
                                    .fill(Color.netoSecondaryText.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                Text("\(formattedAmount(previousPoint.value)) \(currencyCode)")
                                    .font(.caption)
                                    .foregroundStyle(Color.netoSecondaryText)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color.netoCard.opacity(0.95))
                            .shadow(radius: 2)
                    )
                    .offset(y: tooltipShouldBeBelow(for: selectedCurrentPoint.value) ? -30 : -30)
                }
            }
        }
        .chartXScale(domain: dataXDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: smartAxisDates) { value in
                AxisGridLine()
                    .foregroundStyle(Color.netoSecondaryText.opacity(0.1))

                if let date = value.as(Date.self) {
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
                        Text(formatCurrencyShort(value: doubleValue))
                            .font(.caption2)
                            .foregroundStyle(Color.netoSecondaryText)
                    }
                }
            }
        }
        .chartXSelection(value: $draggingDate)
        .frame(height: 220)  // Match TrendChartView height
        .chartLegend(position: .top, alignment: .leading) {
            HStack(spacing: DS.Spacing.lg) {
                // Current period legend
                HStack(spacing: DS.Spacing.xs) {
                    Rectangle()
                        .fill(trendType.color)
                        .frame(width: 20, height: 3)
                    Text(L10n.Statistics.currentPeriod)
                        .font(.caption2)
                        .foregroundStyle(Color.netoSecondaryText)
                }

                // Previous period legend
                HStack(spacing: DS.Spacing.xs) {
                    Rectangle()
                        .fill(Color.netoSecondaryText.opacity(0.5))
                        .frame(width: 20, height: 3)
                    Text(L10n.Statistics.previousPeriod)
                        .font(.caption2)
                        .foregroundStyle(Color.netoSecondaryText)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Adjust previous period dates to align with current period on X-axis
    /// Uses calendar-based alignment to correctly handle months with different lengths
    private func adjustDateToCurrent(_ previousDate: Date) -> Date {
        let calendar = Calendar.current

        // Get day-of-month from previous date
        let dayOfMonth = calendar.component(.day, from: previousDate)

        // Create date in current period with same day-of-month
        var components = calendar.dateComponents([.year, .month], from: interval.start)
        components.day = dayOfMonth

        // If day doesn't exist in current month (e.g., Nov 30 → Feb 30), clamp to last day
        if let adjustedDate = calendar.date(from: components) {
            // Check if the date is within the current interval
            if adjustedDate >= interval.start && adjustedDate < interval.end {
                return adjustedDate
            }
        }

        // Fallback: use proportional mapping for edge cases
        // Calculate position in previous period and map to current period
        let previousInterval = DateInterval(
            start: calendar.date(byAdding: .month, value: -1, to: interval.start) ?? previousDate,
            end: interval.start
        )

        let previousDuration = previousInterval.duration
        let currentDuration = interval.duration

        guard previousDuration > 0 else { return previousDate }

        let relativePosition = previousDate.timeIntervalSince(previousInterval.start) / previousDuration
        return interval.start.addingTimeInterval(relativePosition * currentDuration)
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

    /// Calculate smart axis dates for chart X-axis (based on actual data)
    private var smartAxisDates: [Date] {
        guard !filteredCurrentPoints.isEmpty else { return [] }
        guard let firstDate = filteredCurrentPoints.first?.date,
            let lastDate = filteredCurrentPoints.last?.date
        else { return [] }
        return SmartAxisHelper.calculateSmartAxisDates(from: firstDate, to: lastDate)
    }

    /// Format axis label based on data span
    private func smartAxisLabel(for date: Date) -> String {
        guard let firstDate = filteredCurrentPoints.first?.date,
            let lastDate = filteredCurrentPoints.last?.date
        else { return "" }
        return SmartAxisHelper.formatAxisLabel(for: date, startDate: firstDate, endDate: lastDate)
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
        let intervalDuration = interval.end.timeIntervalSince(interval.start)
        guard intervalDuration > 0 else { return .center }

        let datePosition = date.timeIntervalSince(interval.start)
        let percentage = datePosition / intervalDuration

        if percentage < 0.25 {
            return .leading
        } else if percentage > 0.75 {
            return .trailing
        } else {
            return .center
        }
    }

    /// Determines if tooltip should be below the point (when point is in upper portion of chart)
    private func tooltipShouldBeBelow(for value: Double) -> Bool {
        let range = yDomain.upperBound - yDomain.lowerBound
        guard range > 0 else { return false }

        let normalizedValue = (value - yDomain.lowerBound) / range
        // If point is in upper 30% of chart, put tooltip below
        return normalizedValue > 0.70
    }

    /// Format period label for tooltip
    private func periodLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        switch grouping {
        case .day: formatter.dateFormat = "d MMM yy"  // 19 dic 25
        case .week: formatter.dateFormat = "d MMM yy"  // 19 dic 25
        case .month: formatter.dateFormat = "MMM yy"  // ene 25
        }
        return formatter.string(from: date).lowercased().replacingOccurrences(of: ".", with: "")
    }

    /// Format amount for tooltip
    private func formattedAmount(_ value: Double) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(0))
        )
    }
}
