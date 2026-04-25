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
    var showYAxis: Bool = true
    var showBarAnnotations: Bool = true
    /// When set, annotations are rendered only on the top-N bars by average.
    /// Passing nil annotates every bar with a non-zero value (default).
    var annotationTopCount: Int? = nil
    var chartHeight: CGFloat? = 200

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    private var maxWeekday: Int? {
        data.max(by: { $0.average < $1.average })?.weekday
    }

    /// Minimum average that still qualifies for an annotation, given `annotationTopCount`.
    /// Returns 0 when no cap is set (all non-zero bars qualify).
    private var annotationThreshold: Double {
        guard let topCount = annotationTopCount, topCount > 0 else { return 0 }
        let sorted = data.map(\.average).filter { $0 > 0 }.sorted(by: >)
        return sorted.prefix(topCount).last ?? .infinity
    }

    /// Reorder weekdays respecting the user's `firstWeekday` preference.
    /// Missing weekdays are still shown as empty bars so the axis never collapses.
    private var orderedData: [WeekdaySpending] {
        let order = Self.weekdayOrder(firstWeekday: appPreferences.firstWeekday)
        return order.map { day in
            data.first(where: { $0.weekday == day })
                ?? WeekdaySpending(weekday: day, total: 0, count: 0, dayOccurrences: 0)
        }
    }

    /// Rotation helper shared with `WeekdayBarPanelWidget` (voiceover label order).
    /// Wrapper around `Calendar.orderedWeekdays(firstWeekday:)` for backward compat.
    static func weekdayOrder(firstWeekday: Int) -> [Int] {
        Calendar.orderedWeekdays(firstWeekday: firstWeekday)
    }

    var body: some View {
        Chart(orderedData) { item in
            BarMark(
                x: .value("Day", item.axisLabel),
                y: .value("Amount", item.average)
            )
            .foregroundStyle(item.weekday == maxWeekday ? Color.expenseGraph.gradient : Color.expenseGraph.opacity(0.3).gradient)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
            .annotation(position: .top, spacing: 2) {
                if showBarAnnotations, item.average > 0, item.average >= annotationThreshold {
                    Text(YalaFormatter.compactCurrency(value: item.average))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxis {
            if showYAxis {
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
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .font(DS.Typography.captionSmall)
            }
        }
        .modifier(OptionalHeightModifier(height: chartHeight))
    }
}

private struct OptionalHeightModifier: ViewModifier {
    let height: CGFloat?
    func body(content: Content) -> some View {
        if let height {
            content.frame(height: height)
        } else {
            content
        }
    }
}
