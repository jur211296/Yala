//
//  CashFlowCellMiniChart.swift
//  Yala
//
//  Mini chart showing cumulative daily spending vs planned goal.
//  Works for current and past months. Hover tooltip on selection.
//

import Accessibility
import Charts
import SwiftUI

struct CashFlowCellMiniChart: View {
    let transactions: [TransactionItem]
    let plannedAmount: Double
    let month: CashFlowMonth
    let currencyCode: String

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @State private var selectedDay: Int?

    private func chartYDomain(for data: [CumulativePoint]) -> ClosedRange<Double> {
        let maxVal = max(data.last?.cumulative ?? 0, plannedAmount)
        return 0...(maxVal * 1.1 + 1)
    }

    private func tooltipAlignment(for day: Int, in data: [CumulativePoint]) -> Alignment {
        guard let first = data.first?.day, let last = data.last?.day, last > first else { return .center }
        let pct = Double(day - first) / Double(last - first)
        if pct < 0.25 { return .leading }
        else if pct > 0.75 { return .trailing }
        else { return .center }
    }

    var body: some View {
        let data = cumulativeData
        let yDomain = chartYDomain(for: data)
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.cellDetailDailyProgress)
                .font(DS.Typography.headline)

            Chart {
                ForEach(data, id: \.day) { point in
                    LineMark(
                        x: .value("Day", point.day),
                        y: .value("Amount", point.cumulative)
                    )
                    .foregroundStyle(theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Day", point.day),
                        y: .value("Amount", point.cumulative)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.accent.opacity(0.2), theme.accent.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }

                // Goal line (dashed)
                RuleMark(y: .value("Goal", plannedAmount))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .annotation(position: .topTrailing) {
                        Text(YalaFormatter.amountCompactTable(value: plannedAmount))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }

                // Selection indicator
                if let day = selectedDay, let point = data.first(where: { $0.day == day }) {
                    let isUpperHalf = point.cumulative > yDomain.upperBound * 0.5

                    PointMark(
                        x: .value("Day", point.day),
                        y: .value("Amount", point.cumulative)
                    )
                    .foregroundStyle(theme.accent)
                    .symbolSize(40)
                    .annotation(
                        position: isUpperHalf ? .bottom : .top,
                        alignment: tooltipAlignment(for: point.day, in: data)
                    ) {
                        VStack(spacing: DS.Spacing.xxs) {
                            AmountText(
                                value: point.cumulative,
                                currencyCode: currencyCode,
                                font: DS.Typography.label.weight(.semibold).monospacedDigit()
                            )
                            if point.daily > 0 {
                                Text("+" + YalaFormatter.amountCompactTable(value: point.daily))
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .fill(.thCard.opacity(0.95))
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        )
                    }

                    RuleMark(x: .value("Day", point.day))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(theme.secondaryText.opacity(0.1))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(YalaFormatter.amountCompactTable(value: v))
                                .font(DS.Typography.captionSmall)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisValueLabel {
                        if let day = value.as(Int.self) {
                            Text("\(day)")
                                .font(DS.Typography.captionSmall)
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedDay)
            .chartYScale(domain: yDomain)
            .accessibilityChartDescriptor(CashFlowMiniChartDescriptor(
                data: data, plannedAmount: plannedAmount, currencyCode: currencyCode
            ))
            .frame(height: 160)

            // Legend
            HStack(spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.xs) {
                    Circle().fill(theme.accent).frame(width: 8, height: 8)
                    Text(L10n.CashFlowPlan.real)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: DS.Spacing.xs) {
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 1)
                    Text(L10n.CashFlowPlan.plan)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Data

    private var cumulativeData: [CumulativePoint] {
        let calendar = Calendar.current
        var dailyTotals: [Int: Double] = [:]

        for tx in transactions {
            let day = calendar.component(.day, from: tx.date)
            dailyTotals[day, default: 0] += abs(tx.amount)
        }

        guard !dailyTotals.isEmpty else { return [] }

        // For current month: up to today. For past months: full month.
        let maxDay: Int
        if month.isCurrent {
            maxDay = calendar.component(.day, from: .now)
        } else {
            let range = calendar.range(of: .day, in: .month, for: month.date)
            maxDay = range?.count ?? 31
        }

        var cumulative: Double = 0
        var points: [CumulativePoint] = []

        for day in 1...maxDay {
            let daily = dailyTotals[day] ?? 0
            cumulative += daily
            points.append(CumulativePoint(day: day, daily: daily, cumulative: cumulative))
        }

        return points
    }
}

private struct CumulativePoint {
    let day: Int
    let daily: Double
    let cumulative: Double
}

// MARK: - Accessibility Chart Descriptor

private struct CashFlowMiniChartDescriptor: AXChartDescriptorRepresentable {
    let data: [CumulativePoint]
    let plannedAmount: Double
    let currencyCode: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let minDay = Double(data.first?.day ?? 1)
        let maxDay = Double(data.last?.day ?? 31)
        let maxAmount = max(data.last?.cumulative ?? 0, plannedAmount) * 1.1 + 1

        let xAxis = AXNumericDataAxisDescriptor(
            title: "Day",
            range: minDay...maxDay,
            gridlinePositions: []
        ) { value in "\(Int(value))" }

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Amount",
            range: 0...maxAmount,
            gridlinePositions: []
        ) { value in YalaFormatter.amountCompactTable(value: value) }

        let series = AXDataSeriesDescriptor(
            name: L10n.CashFlowPlan.cellDetailDailyProgress,
            isContinuous: true,
            dataPoints: data.map { point in
                .init(x: Double(point.day), y: point.cumulative)
            }
        )

        return AXChartDescriptor(
            title: L10n.CashFlowPlan.cellDetailDailyProgress,
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
