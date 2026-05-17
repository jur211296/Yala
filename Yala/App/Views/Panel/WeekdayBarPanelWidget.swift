//
//  WeekdayBarPanelWidget.swift
//  Yala
//

import SwiftUI

struct WeekdayBarPanelWidget: View {
    let data: [WeekdaySpending]
    let currencyCode: String
    var size: WidgetSize = .large
    var onShowMore: (() -> Void)? = nil

    /// Slot pedagógico opcional inyectado en el header (Panel Polish #2).
    var headerInfoButton: AnyView? = nil

    @Environment(AppPreferences.self) private var appPreferences

    private var hasData: Bool {
        data.contains(where: { $0.average > 0 })
    }

    /// Weekday with the highest average spend — seeds the "priciest day" KPI in `.small`.
    private var topWeekday: WeekdaySpending? {
        data.filter { $0.average > 0 }.max(by: { $0.average < $1.average })
    }

    var body: some View {
        Group {
            if size == .small {
                smallBody
            } else {
                largeBody
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(voiceoverLabel)
    }

    // MARK: - Large (existing, full-width)

    private var largeBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            largeHeader
            if hasData {
                WeekdayBarChart(
                    data: data,
                    currencyCode: currencyCode,
                    chartHeight: 140
                )
            } else {
                YalaEmptyState(
                    icon: "calendar.day.timeline.left",
                    title: L10n.Widget.noExpensesPeriod,
                    style: .widget
                )
            }
        }
        .panelCard()
    }

    private var largeHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Text(L10n.Panel.WeekdayBar.largeTitle)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.thPrimaryText)

            if let headerInfoButton {
                headerInfoButton
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Small (PP2-06c)

    private var smallBody: some View {
        // Weekly average — sum of each weekday's average. Held as a local so the
        // body doesn't re-reduce on every incidental re-render.
        let weeklyAverage = data.reduce(0) { $0 + $1.average }
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PanelSmallWidgetHeader(
                title: L10n.Panel.WeekdayBar.smallTitle,
                accessibilityLabel: L10n.Panel.WeekdayBar.smallTitle,
                action: onShowMore,
                headerInfoButton: headerInfoButton
            )
            if hasData {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                    AmountText(
                        value: weeklyAverage,
                        currencyCode: currencyCode,
                        font: DS.Typography.headline, secondaryFont: DS.Typography.caption
                    )
                    Text(L10n.Panel.WeekdayBar.perWeekSuffix)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                }

                WeekdayBarChart(
                    data: data,
                    currencyCode: currencyCode,
                    showYAxis: false,
                    showBarAnnotations: true,
                    annotationTopCount: 2,
                    chartHeight: nil
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            } else {
                YalaEmptyState(
                    icon: "calendar.day.timeline.left",
                    title: L10n.Widget.noExpensesPeriod,
                    style: .widget
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panelCard(small: true)
        .frame(height: WidgetSize.smallHeight)
    }

    private var voiceoverLabel: String {
        var parts: [String] = [L10n.WidgetType.weekdayBar]
        for day in WeekdayBarChart.weekdayOrder(firstWeekday: appPreferences.firstWeekday.rawValue) {
            guard let entry = data.first(where: { $0.weekday == day }), entry.average > 0 else { continue }
            let amount = appPreferences.currency(entry.average, currencyCode: currencyCode)
            parts.append("\(entry.shortName): \(amount)")
        }
        return parts.joined(separator: ". ")
    }
}
