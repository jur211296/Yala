import Charts
import SwiftData
import SwiftUI
import UIKit

struct TrendChartView: View {
    let trendPoints: [PanelViewModel.BarPoint]
    let yDomain: ClosedRange<Double>
    let grouping: TrendGrouping
    let interval: DateInterval
    let currencyCode: String
    let trendType: TrendType
    @Binding var focusedDate: Date?

    let period: PanelViewModel.TrendPeriod
    var chartHeight: CGFloat = 220

    @State private var hoveredIndex: Int? = nil
    @State private var draggingDate: Date?  // For transient drag state

    var body: some View {
        // Liquid Line Chart with Balance Trend
        // Using .id(period) forces complete re-render when period changes,
        // avoiding weird intermediate chart states during animation
        liquidTrendChart
            .id(period)
    }

    // MARK: - Gráfico Trend (Financial Grid Style)

    private var liquidTrendChart: some View {
        Chart {
            // Colors based on TrendType (Using Semantic Colors)
            let primaryLineColor: Color = (trendType == .balance) ? .brandPrimary : .expenseGraph
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
                    x: .value("Fecha", point.date),
                    yStart: .value("Base", yBase),
                    yEnd: .value("Monto", point.value)
                )
                .interpolationMethod(interpolation)
                .foregroundStyle(areaGradient.opacity(dimOpacity))

                LineMark(
                    x: .value("Fecha", point.date),
                    y: .value("Monto", point.value)
                )
                .interpolationMethod(interpolation)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(primaryLineColor.opacity(dimOpacity))

                // DATA ANNOTATIONS FOR WEEK VIEW
                if period == .week {
                    PointMark(
                        x: .value("Fecha", point.date),
                        y: .value("Monto", point.value)
                    )
                    .symbolSize(0)  // Invisible point just for annotation context
                    .annotation(position: .top, spacing: 4) {
                        Text(formattedAmountShort(point.value))
                            .font(.caption2.bold())
                            .foregroundStyle(Color.netoSecondaryText)
                    }
                }
            }

            // Future: Dashed Line (Overlaps at Today to connect)
            ForEach(futurePoints, id: \.date) { point in
                LineMark(
                    x: .value("Fecha", point.date),
                    y: .value("Monto", point.value)
                )
                .interpolationMethod(interpolation)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .foregroundStyle(Color.netoSecondaryText)  // Explicit Gray for distinction
            }

            // Marker for "Today"
            RuleMark(x: .value("Hoy", today))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .foregroundStyle(Color.netoSecondaryText.opacity(0.5))
                .annotation(position: .top, alignment: .center) {
                    Text("Hoy")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.netoPrimaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.netoCard, in: RoundedRectangle(cornerRadius: 4))
                        .shadow(radius: 1)
                }

            // Interaction: Scrubbing Rule Mark
            if let activeDate = draggingDate ?? focusedDate,
                let selectedPoint = closestPoint(to: activeDate, in: data),
                let rawValue = value(for: activeDate, in: data)
            {

                RuleMark(x: .value("Selected Date", activeDate))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(Color.netoSecondaryText)

                // Ring Border (Background) at SMOOTHED position
                PointMark(
                    x: .value("Selected Date", activeDate),
                    y: .value("Selected Value", selectedPoint.value)
                )
                .symbolSize(140)
                .foregroundStyle(primaryLineColor)

                // Main Dot (Foreground) at SMOOTHED position
                PointMark(
                    x: .value("Selected Date", activeDate),
                    y: .value("Selected Value", selectedPoint.value)
                )
                .symbolSize(100)
                .foregroundStyle(Color.netoCard)

                // Tooltip
                .annotation(
                    position: .top,
                    alignment: activeDate < Calendar.current.date(
                        byAdding: .month, value: 3, to: interval.start)!
                        ? .leading
                        : activeDate > Calendar.current.date(
                            byAdding: .month, value: -3, to: interval.end)! ? .trailing : .center
                ) {
                    VStack(alignment: .center, spacing: 4) {
                        Text(periodLabel(for: activeDate))
                            .font(.caption2)
                            .foregroundStyle(Color.netoSecondaryText)
                        Text("\(formattedAmount(rawValue)) \(currencyCode)")
                            .font(.caption.bold())
                            .foregroundStyle(Color.netoPrimaryText)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                            .fill(Color.netoCard.opacity(0.95))
                            .shadow(radius: 2)
                    )
                    .offset(y: -10)
                }
            }
        }
        // Y-Axis: Right (Trailing) only
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(dash: [5, 5]))
                    .foregroundStyle(Color.netoSecondaryText.opacity(0.2))
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
            if period == .year {
                // For Year: Show Months
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.netoSecondaryText.opacity(0.1))

                    if let date = value.as(Date.self) {
                        AxisValueLabel(anchor: .topLeading) {
                            Text(date, format: .dateTime.month(.abbreviated).locale(axisLocale))
                                .font(.caption2.bold())
                                .foregroundStyle(Color.netoSecondaryText)
                                .textCase(.lowercase)
                        }
                    }
                }
            } else {
                // For Week/Month: Show Days
                let strideCount = (period == .month) ? 5 : 1

                AxisMarks(values: .stride(by: .day, count: strideCount)) { value in
                    if let date = value.as(Date.self) {
                        AxisGridLine()
                            .foregroundStyle(Color.netoSecondaryText.opacity(0.1))

                        AxisValueLabel(anchor: .top) {
                            Text(date, format: .dateTime.day().locale(axisLocale))
                                .font(.caption2.bold())
                                .foregroundStyle(Color.netoSecondaryText)
                        }
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - geo[proxy.plotFrame!].origin.x
                                if let date: Date = proxy.value(atX: x),
                                    let closest = closestPoint(to: date, in: trendPoints)
                                {
                                    draggingDate = closest.date
                                }
                            }
                            .onEnded { _ in
                                draggingDate = nil
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                if let current = draggingDate {
                                    withAnimation {
                                        focusedDate = current
                                    }
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                            }
                    )
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                withAnimation {
                                    focusedDate = nil
                                }
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                    )
            }
        }
        .frame(height: chartHeight)
    }

    // Padded X Domain Logic
    private var paddedXDomain: ClosedRange<Date> {
        let span = interval.end.timeIntervalSince(interval.start)
        let padding = span * 0.05
        let start = interval.start.addingTimeInterval(-padding)
        let end = interval.end.addingTimeInterval(padding)
        return start...end
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
        let sign: String
        if value < 0 {
            sign = "-"
        } else if value > 0 && trendType == .balance {
            sign = "+"
        } else {
            sign = ""
        }

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

    private var axisLocale: Locale {
        return Locale(identifier: "es")
    }

    private func periodLabel(for date: Date) -> String {
        return date.formatted(
            .dateTime.day().month(.abbreviated).year(.twoDigits).locale(axisLocale)
        )
    }

    private func formattedAmount(_ value: Double) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(0))
        )
    }
}
