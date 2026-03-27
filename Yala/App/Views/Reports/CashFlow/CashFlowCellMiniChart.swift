//
//  CashFlowCellMiniChart.swift
//  Yala
//
//  Mini chart showing cumulative daily spending vs planned goal.
//  Works for current and past months. Hover tooltip on selection.
//

import Charts
import SwiftUI

struct CashFlowCellMiniChart: View {
    let transactions: [TransactionItem]
    let plannedAmount: Double
    let month: CashFlowMonth
    let currencyCode: String

    @Environment(\.yalaTheme) private var theme
    @State private var selectedDay: Int?

    var body: some View {
        let data = cumulativeData
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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
                    PointMark(
                        x: .value("Day", point.day),
                        y: .value("Amount", point.cumulative)
                    )
                    .foregroundStyle(theme.accent)
                    .symbolSize(40)

                    RuleMark(x: .value("Day", point.day))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.gray.opacity(0.1))
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
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if let day = selectedDay,
                       let point = data.first(where: { $0.day == day }),
                       let xPos = proxy.position(forX: day) {
                        let plotFrame = proxy.plotFrame.map { geo[$0] } ?? geo.frame(in: .local)

                        VStack(spacing: DS.Spacing.xxs) {
                            Text(L10n.CashFlowPlan.cellDetailOf + " \(day)")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                            Text(YalaFormatter.currency(value: point.cumulative, currencyCode: currencyCode))
                                .font(DS.Typography.label)
                                .fontWeight(.semibold)
                                .monospacedDigit()
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
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        )
                        .position(
                            x: min(max(xPos + plotFrame.minX, 40), plotFrame.maxX - 40),
                            y: plotFrame.minY - 8
                        )
                    }
                }
            }
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
