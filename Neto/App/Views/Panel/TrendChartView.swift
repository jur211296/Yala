import Charts
import SwiftData
import SwiftUI

struct TrendChartView: View {
    /// Points for chart visualization (may be smoothed)
    let trendPoints: [PanelViewModel.BarPoint]
    /// Original unsmoothed points for tooltip/hover display
    let rawPoints: [PanelViewModel.BarPoint]
    let yDomain: ClosedRange<Double>
    let grouping: TrendGrouping
    let interval: DateInterval
    let currencyCode: String
    let trendType: TrendType
    @Binding var focusedDate: Date?

    let period: DetailPeriod
    var chartHeight: CGFloat = 220

    @State private var draggingDate: Date?  // For transient drag state

    var body: some View {
        // Disable animations completely to prevent interpolation between data states
        // This fixes the visual glitch when switching between Balance/Income/Expense
        liquidTrendChart
            .animation(nil, value: trendPoints.count)
    }

    // MARK: - Gráfico Trend (Financial Grid Style)

    private var liquidTrendChart: some View {
        Chart {
            // Colors based on TrendType (Using Semantic Colors from TrendType)
            let primaryLineColor: Color = trendType.color
            let areaStartColor = primaryLineColor.opacity(0.1)
            let areaEndColor = primaryLineColor.opacity(0.05)

            // Dimming Factor: If focusedDate is set, reduce opacity of line/area
            let dimOpacity = focusedDate != nil ? 0.3 : 1.0

            let areaGradient = LinearGradient(
                colors: [areaStartColor, areaEndColor],
                startPoint: .top,
                endPoint: .bottom
            )

            let today = Calendar.current.startOfDay(for: Date())
            let calendar = Calendar.current

            // --- USE PROCESSED DATA ---
            let data = trendPoints

            // Split into Past and Future with overlapping connection at 'today'
            let pastPoints = data.filter {
                calendar.compare($0.date, to: today, toGranularity: .day) != .orderedDescending
            }
            let futurePoints = data.filter {
                calendar.compare($0.date, to: today, toGranularity: .day) != .orderedAscending
            }

            let yBase = min(max(yDomain.lowerBound, 0), yDomain.upperBound)

            // Interpolation Logic:
            let interpolation: InterpolationMethod = .catmullRom

            // Past & Today: Solid Line & Area
            ForEach(pastPoints, id: \.date) { point in
                AreaMark(
                    x: .value(L10n.Common.date, point.date),
                    yStart: .value(L10n.Common.base, yBase),
                    yEnd: .value(L10n.Common.amount, point.value)
                )
                .interpolationMethod(interpolation)
                .foregroundStyle(areaGradient.opacity(dimOpacity))

                LineMark(
                    x: .value(L10n.Common.date, point.date),
                    y: .value(L10n.Common.amount, point.value)
                )
                .interpolationMethod(interpolation)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(primaryLineColor.opacity(dimOpacity))

                // DATA ANNOTATIONS FOR WEEK VIEW
                if period == .thisWeek || period == .last7Days {
                    PointMark(
                        x: .value(L10n.Common.date, point.date),
                        y: .value(L10n.Common.amount, point.value)
                    )
                    .symbolSize(0)  // Invisible point just for annotation context
                    .annotation(position: .top, spacing: DS.Spacing.xs) {
                        Text(formattedAmountShort(point.value))
                            .font(.caption2.bold())
                            .foregroundStyle(Color.netoSecondaryText)
                    }
                }
            }

            // Future: Dashed Line (Overlaps at Today to connect)
            ForEach(futurePoints, id: \.date) { point in
                LineMark(
                    x: .value(L10n.Common.date, point.date),
                    y: .value(L10n.Common.amount, point.value)
                )
                .interpolationMethod(interpolation)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .foregroundStyle(Color.netoSecondaryText)  // Explicit Gray for distinction
            }

            // Marker for "Today"
            RuleMark(x: .value(L10n.Widget.today, today))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .foregroundStyle(Color.netoSecondaryText.opacity(0.5))
                .annotation(position: .top, alignment: .center) {
                    Text(L10n.Widget.today)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.netoPrimaryText)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(Color.netoCard, in: RoundedRectangle(cornerRadius: DS.Radius.xs))
                        .shadow(radius: 1)
                }

            // Interaction: Scrubbing Rule Mark
            if let activeDate = draggingDate ?? focusedDate,
                let selectedPoint = closestPoint(to: activeDate, in: data),
                let rawValue = value(for: activeDate, in: rawPoints)  // Use raw points for actual value
            {

                RuleMark(x: .value(L10n.Common.selectedDate, activeDate))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(Color.netoSecondaryText)

                // Ring Border (Background) at SMOOTHED position
                PointMark(
                    x: .value(L10n.Common.selectedDate, activeDate),
                    y: .value(L10n.Common.selectedValue, selectedPoint.value)
                )
                .symbolSize(140)
                .foregroundStyle(primaryLineColor)

                // Main Dot (Foreground) at SMOOTHED position
                PointMark(
                    x: .value(L10n.Common.selectedDate, activeDate),
                    y: .value(L10n.Common.selectedValue, selectedPoint.value)
                )
                .symbolSize(100)
                .foregroundStyle(Color.netoCard)

                // Tooltip - dynamic position based on point height
                .annotation(
                    position: tooltipShouldBeBelow(for: selectedPoint.value) ? .bottom : .top,
                    alignment: tooltipAlignment(for: activeDate)
                ) {
                    VStack(alignment: .center, spacing: DS.Spacing.xs) {
                        Text(periodLabel(for: activeDate))
                            .font(.caption2)
                            .foregroundStyle(Color.netoSecondaryText)
                        Text("\(formattedAmount(rawValue)) \(currencyCode)")
                            .font(.caption.bold())
                            .foregroundStyle(Color.netoPrimaryText)
                    }
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color.netoCard.opacity(0.95))
                            .shadow(radius: 2)
                    )
                    .offset(y: tooltipShouldBeBelow(for: selectedPoint.value) ? -30 : -30)
                }
            }
        }
        // Y-Axis: Right (Trailing) only - minimal gridlines
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
        // Y-Axis Scale from ViewModel
        .chartYScale(domain: yDomain)
        // X-Axis Scale from Interval
        .chartXScale(domain: paddedXDomain)
        .chartXAxis {
            // Smart dynamic X-axis labels
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
        .chartXSelection(value: $draggingDate)  // Native iOS 17+ selection - works with scroll
        .frame(height: chartHeight)
    }

    // Padded X Domain Logic - Use actual data range when available
    private var paddedXDomain: ClosedRange<Date> {
        // Use actual data range if available
        guard let firstDate = trendPoints.first?.date,
            let lastDate = trendPoints.last?.date
        else {
            // Fallback to interval if no data
            let span = interval.end.timeIntervalSince(interval.start)
            let padding = span * 0.05
            return interval.start.addingTimeInterval(
                -padding)...interval.end.addingTimeInterval(padding)
        }

        let span = lastDate.timeIntervalSince(firstDate)
        let padding = max(span * 0.05, 86400)  // At least 1 day padding
        return firstDate.addingTimeInterval(-padding)...lastDate.addingTimeInterval(padding)
    }

    // MARK: - Smart Axis Labels

    /// Maximum number of axis labels to show (to avoid crowding)
    private let maxAxisLabels = 5

    /// Calculate smart axis dates based on actual data range
    private var smartAxisDates: [Date] {
        guard let firstDate = trendPoints.first?.date,
            let lastDate = trendPoints.last?.date
        else {
            return []
        }

        // If only one point, return just that date
        if firstDate == lastDate {
            return [firstDate]
        }

        let calendar = Calendar.current
        let span = lastDate.timeIntervalSince(firstDate)
        let days = span / 86400

        // Always include first and last dates
        var dates: [Date] = [firstDate]

        // Calculate how many middle labels we can fit
        let middleLabelsCount = maxAxisLabels - 2  // minus first and last

        if middleLabelsCount > 0 && days > 1 {
            // Calculate step based on data range
            let step = span / Double(maxAxisLabels - 1)

            for i in 1..<(maxAxisLabels - 1) {
                let middleDate = firstDate.addingTimeInterval(step * Double(i))

                // Normalize to start of day for cleaner alignment
                let normalizedDate = calendar.startOfDay(for: middleDate)

                // Avoid duplicate if too close to first or last
                if normalizedDate > firstDate && normalizedDate < lastDate {
                    dates.append(normalizedDate)
                }
            }
        }

        dates.append(lastDate)

        // Sort and remove duplicates
        return Array(Set(dates)).sorted()
    }

    /// Format axis label based on data span (include year if multiple years)
    private func smartAxisLabel(for date: Date) -> String {
        guard let firstDate = trendPoints.first?.date,
            let lastDate = trendPoints.last?.date
        else {
            return formatDayNumber(date)
        }
        return SmartAxisHelper.formatAxisLabel(for: date, startDate: firstDate, endDate: lastDate)
    }

    private func formattedAmountShort(_ value: Double) -> String {
        let absValue = abs(value)
        let formattedNumber = absValue.formatted(.number.precision(.fractionLength(0)))

        if value < 0 {
            return "-\(formattedNumber)"
        } else if value > 0 && trendType == .balance {
            return "+\(formattedNumber)"
        } else {
            return formattedNumber
        }
    }

    private func formatK(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""

        if absValue >= 1000 {
            let kValue = absValue / 1000.0
            return String(format: "%@%.0fK", sign, kValue)
        } else {
            return String(format: "%@%.0f", sign, absValue)
        }
    }

    private func value(for date: Date, in data: [PanelViewModel.BarPoint]) -> Double? {
        data.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })?.value
    }

    private func closestPoint(to date: Date, in data: [PanelViewModel.BarPoint]) -> PanelViewModel
        .BarPoint?
    {
        return data.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    // MARK: - Utilidades de escala

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

    /// Format day as number only (1, 2, 3, etc.)
    private func formatDayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

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

    private func formattedAmount(_ value: Double) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(0))
        )
    }
}
