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
        data.max(by: { $0.total < $1.total })?.weekday
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
                y: .value("Amount", item.total)
            )
            .foregroundStyle(item.weekday == maxWeekday ? Color.expenseGraph.gradient : Color.expenseGraph.opacity(0.3).gradient)
            .cornerRadius(DS.Radius.xs)
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
        .frame(height: 180)
    }
}
