//
//  WeekdayBarChart.swift
//  Yala
//
//  7 BarMarks (Mon-Sun), highlight max with accent color.
//

import Charts
import SwiftUI

struct WeekdayBarChart: View {
    let data: [WeekdaySpending]
    let currencyCode: String

    @Environment(\.yalaTheme) private var theme

    private var maxWeekday: Int? {
        data.max(by: { $0.average < $1.average })?.weekday
    }

    /// Reorder weekdays to start from Monday (weekday 2)
    private var orderedData: [WeekdaySpending] {
        let mondayFirst = [2, 3, 4, 5, 6, 7, 1]
        return mondayFirst.compactMap { day in
            data.first(where: { $0.weekday == day })
        }
    }

    var body: some View {
        Chart(orderedData) { item in
            BarMark(
                x: .value("Day", item.shortName),
                y: .value("Amount", item.average)
            )
            .foregroundStyle(item.weekday == maxWeekday ? Color.expenseGraph.gradient : Color.expenseGraph.opacity(0.3).gradient)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
            .annotation(position: .top, spacing: 2) {
                if item.average > 0 {
                    Text(YalaFormatter.compactCurrency(value: item.average))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.thSecondaryText.opacity(0.1))
                AxisValueLabel {
                    if let doubleVal = value.as(Double.self) {
                        Text(YalaFormatter.compactCurrency(value: doubleVal))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.thSecondaryText)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(DS.Typography.captionSmall)
            }
        }
        .frame(height: 200)
    }
}
