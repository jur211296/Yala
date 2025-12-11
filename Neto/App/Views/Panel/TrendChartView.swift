import Charts
import SwiftData
import SwiftUI
import UIKit

struct TrendChartView: View {
    let transactions: [ChartTransaction]
    let historicalThreshold: Double
    let grouping: TrendGrouping
    let interval: DateInterval
    let currencyCode: String
    let trendType: TrendType
    @Binding var focusedDate: Date?

    let period: PanelViewModel.TrendPeriod

    @State private var hoveredIndex: Int? = nil
    @State private var draggingDate: Date?  // For transient drag state

    var body: some View {
        // Liquid Line Chart with Balance Trend
        liquidTrendChart
    }

    // MARK: - Gráfico Trend (Financial Grid Style)

    private var liquidTrendChart: some View {
        Chart {
            // Colors based on TrendType
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

            // --- SMOOTHED DATA ---
            let data = allSmoothedData
            // Split into Past and Future with overlapping connection at 'today'
            let pastPoints = data.filter {
                calendar.compare($0.date, to: today, toGranularity: .day) != .orderedDescending
            }
            let futurePoints = data.filter {
                calendar.compare($0.date, to: today, toGranularity: .day) != .orderedAscending
            }

            let yDomain = yAxisSmoothedDomain
            let yMin = yDomain.lowerBound
            let yMax = yDomain.upperBound
            // Clamp base to domain (0 if inside, otherwise edge)
            let yBase = min(max(yMin, 0), yMax)

            // Interpolation Logic:
            // User requested "Smoothed" line (no corners) but with "Natural" (Raw) data.
            // .catmullRom provides the requested smoothness.
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
                            .foregroundStyle(.secondary)
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
                .foregroundStyle(Color.gray)  // Explicit Gray for distinction
            }

            // Marker for "Today"
            RuleMark(x: .value("Hoy", today))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                .foregroundStyle(Color.gray.opacity(0.5))
                .annotation(position: .top, alignment: .center) {
                    Text("Hoy")
                        .font(.caption2.bold())
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 4))
                        .shadow(radius: 1)
                }

            // Interaction: Scrubbing Rule Mark
            if let activeDate = draggingDate ?? focusedDate,
                let selectedPoint = data.first(where: {
                    Calendar.current.isDate($0.date, inSameDayAs: activeDate)
                }),
                let rawValue = value(for: activeDate)  // Detailed Raw Value for text
            {

                RuleMark(x: .value("Selected Date", activeDate))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(Color.gray)

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
                .foregroundStyle(Color.white)

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
                            .foregroundStyle(.secondary)
                        Text("\(formattedAmount(rawValue)) \(currencyCode)")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.9))
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
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatK(doubleValue))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        // Y-Axis Scale (Tight Top Padding) - BASED ON SMOOTHED DATA
        .chartYScale(domain: yAxisSmoothedDomain)
        // X-Axis Scale with PADDING
        .chartXScale(domain: paddedXDomain)
        .chartXAxis {
            if period == .year {
                // For Year: Show Months (even if data is daily)
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.gray.opacity(0.1))

                    if let date = value.as(Date.self) {
                        AxisValueLabel(anchor: .topLeading) {
                            Text(date, format: .dateTime.month(.abbreviated).locale(axisLocale))
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                                .textCase(.lowercase)
                        }
                    }
                }
            } else {
                // For Week/Month: Show Days
                // Dynamic Stride: If Week, show all. If Month, show every 5 days to avoid overlap.
                let strideCount = (period == .month) ? 5 : 1

                AxisMarks(values: .stride(by: .day, count: strideCount)) { value in
                    if let date = value.as(Date.self) {
                        AxisGridLine()
                            .foregroundStyle(Color.gray.opacity(0.1))

                        AxisValueLabel(anchor: .top) {
                            Text(date, format: .dateTime.day().locale(axisLocale))
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
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
                                    let closest = closestDate(to: date)
                                {
                                    draggingDate = closest
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
        .frame(height: 220)
    }

    // Padded X Domain Logic
    private var paddedXDomain: ClosedRange<Date> {
        let span = interval.end.timeIntervalSince(interval.start)
        // Add 5% padding on each side
        let padding = span * 0.05
        let start = interval.start.addingTimeInterval(-padding)
        let end = interval.end.addingTimeInterval(padding)
        return start...end
    }

    private func formattedAmountShort(_ value: Double) -> String {
        // User requested full values for "This Week" labels, no "K".
        // Also respecting trendType sign logic implicitly via standard formatter?
        // No, standard formatter doesn't do sign usually immediately.
        // Let's format as integer (or 2 decimals? usually int fits better).
        // And handles sign manually if needed.

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

    // Helper for "K" format (e.g. -15K, +15K)
    private func formatK(_ value: Double) -> String {
        let absValue = abs(value)
        // Sign logic: explicit '+' for positive ONLY if balance, '-' for negative always
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

    private func value(for date: Date) -> Double? {
        barData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })?.value
    }

    private func closestDate(to date: Date) -> Date? {
        return barData.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })?.date
    }

    // MARK: - Utilidades de escala

    private var axisLocale: Locale {
        return Locale(identifier: "es")
    }

    private struct BarPoint {
        let date: Date
        let value: Double
    }

    private var barData: [BarPoint] {
        return transactions.map { tx in
            let val = (trendType == .balance) ? tx.balance : tx.expense
            return BarPoint(date: tx.date, value: val)
        }
    }

    private var allSmoothedData: [BarPoint] {
        // Only apply Moving Average for "This Year" (long term trend) AND if we have enough data (>30 days).
        // For short views (Week/Month) or sparse data, show raw values ("Natural").
        if period == .year && barData.count > 30 {
            // Use 14-day window for Expense/Income trends to smooth out daily volatility
            let smoothWindow = 14
            return movingAverage(for: barData, window: smoothWindow)
        }

        return barData
    }

    // 7-Day Rolling Average (Kept for reference or future use if needed, but unused now)
    private func movingAverage(for data: [BarPoint], window: Int) -> [BarPoint] {
        guard !data.isEmpty else { return [] }
        var result: [BarPoint] = []
        let sorted = data.sorted { $0.date < $1.date }

        for i in 0..<sorted.count {
            let start = max(0, i - window + 1)
            let chunk = sorted[start...i]
            let sum = chunk.map(\.value).reduce(0, +)
            let avg = sum / Double(chunk.count)
            result.append(BarPoint(date: sorted[i].date, value: avg))
        }
        return result
    }

    private var yAxisSmoothedDomain: ClosedRange<Double> {
        // Calculate domain based on SMOOTHED data to avoid outlier flattening
        let values = allSmoothedData.map(\.value)
        let maxVal = values.max() ?? 0
        let minVal = values.min() ?? 0

        let topBuffer = max(abs(maxVal) * 0.05, 100)

        if trendType == .expense {
            return 0...(maxVal + topBuffer)
        } else {
            let bottomBuffer = (minVal < 0) ? abs(minVal) * 0.05 : 0
            return (minVal - bottomBuffer)...(maxVal + topBuffer)
        }
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
