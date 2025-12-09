import Charts
import SwiftData
import SwiftUI

struct TrendChartView: View {
    let transactions: [ChartTransaction]
    let historicalThreshold: Double
    let grouping: TrendGrouping
    let interval: DateInterval
    let currencyCode: String
    let trendType: TrendType
    @Binding var focusedDate: Date?

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

            // Past & Today: Solid Line & Area
            ForEach(pastPoints, id: \.date) { point in
                AreaMark(
                    x: .value("Fecha", point.date),
                    y: .value("Monto", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(areaGradient.opacity(dimOpacity))

                LineMark(
                    x: .value("Fecha", point.date),
                    y: .value("Monto", point.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .foregroundStyle(primaryLineColor.opacity(dimOpacity))
            }

            // Future: Dashed Line (Overlaps at Today to connect)
            ForEach(futurePoints, id: \.date) { point in
                LineMark(
                    x: .value("Fecha", point.date),
                    y: .value("Monto", point.value)
                )
                .interpolationMethod(.catmullRom)
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
        // X-Axis: Monthly Segments for Year View
        // X-Axis: Monthly Segments for Year View
        // Fix: Pad the domain slightly at the start? Or rely on aligned marks.
        .chartXScale(domain: interval.start...interval.end)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                // Visible Vertical Grid Lines at start of month
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.1))

                if let date = value.as(Date.self) {
                    AxisValueLabel(anchor: .topLeading) {  // Anchor TopLeading ensures first label hugs the start
                        // Month Abbreviated (ene, feb, etc.) Lowercase
                        Text(date, format: .dateTime.month(.abbreviated).locale(axisLocale))
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .textCase(.lowercase)  // Explicitly lowercase
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
            }
        }
        .frame(height: 220)
    }

    // Helper for "K" format (e.g. -15K, +15K)
    private func formatK(_ value: Double) -> String {
        let absValue = abs(value)
        // Sign logic: explicit '+' for positive, '-' for negative, nothing for zero
        let sign: String
        if value > 0 { sign = "+" } else if value < 0 { sign = "-" } else { sign = "" }

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
        let smoothWindow = (trendType == .expense) ? 14 : 7
        return movingAverage(for: barData, window: smoothWindow)
    }

    // 7-Day Rolling Average
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
