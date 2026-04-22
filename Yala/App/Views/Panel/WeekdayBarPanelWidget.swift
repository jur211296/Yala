//
//  WeekdayBarPanelWidget.swift
//  Yala
//

import SwiftUI

struct WeekdayBarPanelWidget: View {
    let data: [WeekdaySpending]
    let currencyCode: String

    private var hasData: Bool {
        data.contains(where: { $0.average > 0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            header
            if hasData {
                WeekdayBarChart(data: data, currencyCode: currencyCode)
            } else {
                YalaEmptyState(
                    icon: "calendar.day.timeline.left",
                    title: L10n.Widget.noExpensesPeriod,
                    style: .widget
                )
            }
        }
        .solidCard(padding: DS.Card.paddingCompact)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(voiceoverLabel)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.WidgetType.weekdayBar)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.thPrimaryText)
            Text(L10n.Panel.weekdaySubtitle)
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
        }
    }

    private var voiceoverLabel: String {
        var parts: [String] = [L10n.WidgetType.weekdayBar]
        let mondayFirst = [2, 3, 4, 5, 6, 7, 1]
        for day in mondayFirst {
            guard let entry = data.first(where: { $0.weekday == day }), entry.average > 0 else { continue }
            let amount = YalaFormatter.currency(value: entry.average, currencyCode: currencyCode)
            parts.append("\(entry.shortName): \(amount)")
        }
        return parts.joined(separator: ". ")
    }
}
