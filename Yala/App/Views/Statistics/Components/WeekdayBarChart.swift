//
//  WeekdayBarChart.swift
//  Yala
//
//  7 BarMarks (Mon-Sun), highlight max with accent color.
//
//  UX 2.2 · L11-11: barras de color sólido —el día más caro en rosa y el resto en el color de acento suave— en vez del
//  degradado rosa, y en Tendencias el importe de cada barra con su moneda y sin decimales («S/ 1,185») en vez de
//  «1.2 K» junto a «174.5».
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
    /// Cómo se escribe el importe encima de cada barra: compacto («1.2 K», el widget pequeño del Panel) o con la moneda
    /// y sin decimales («S/ 1,185», Tendencias).
    var annotationStyle: AnnotationStyle = .compact

    enum AnnotationStyle {
        case compact
        case wholeCurrency
    }

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    /// «Ocultar montos» del Panel (`AmountPrivacy`): las cifras sobre las barras salen como `•••••`. Fuera del Panel, `false`.
    @Environment(\.amountsHidden) private var amountsHidden

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
        let order = Self.weekdayOrder(firstWeekday: appPreferences.firstWeekday.rawValue)
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

    private func annotationText(_ value: Double) -> String {
        if amountsHidden { return AmountPrivacy.mask }
        switch annotationStyle {
        case .compact:
            return YalaFormatter.compactCurrency(value: value)
        case .wholeCurrency:
            return CurrencyFormattingHelper.currency(
                value.rounded(),
                decimals: 0,
                identifier: appPreferences.currencyIdentifier(for: currencyCode),
                forceSign: false,
                isEstimate: false
            )
        }
    }

    var body: some View {
        Chart(orderedData) { item in
            BarMark(
                x: .value("Day", item.axisLabel),
                y: .value("Amount", item.average)
            )
            .foregroundStyle(item.weekday == maxWeekday ? Color.expenseGraph : theme.accent.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs))
            .annotation(position: .top, spacing: 2) {
                // Texto ya resuelto: una anotación de Swift Charts no recibe el entorno (`AppPreferences`).
                if showBarAnnotations, item.average > 0, item.average >= annotationThreshold {
                    Text(annotationText(item.average))
                        .font(DS.Typography.captionSmall.weight(item.weekday == maxWeekday ? .bold : .regular))
                        .foregroundStyle(item.weekday == maxWeekday ? Color.emphasisPinkText : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
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
        // Decisión 26 de la revisión 2.3: un elemento con el día más caro y el más barato, con cifras (V1), y la
        // descripción de gráficas de iOS para recorrer los siete días (V2). Antes cada barra decía «Ju, 2,314».
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Accessibility.Chart.weekdayTitle)
        .accessibilityValue(spokenSummary)
        .accessibilityChartDescriptor(chartDescriptor)
        .accessibilityIdentifier("weekday_bar_chart")
        .modifier(OptionalHeightModifier(height: chartHeight))
    }

    private var amountFormat: ChartAmountFormat {
        appPreferences.chartAmountFormat(currencyCode: currencyCode, hidden: amountsHidden)
    }

    private var spokenSummary: String {
        ChartSpokenSummary.weekday(orderedData.map { (name: $0.weekdayLongName, average: $0.average) }, format: amountFormat)
    }

    private var chartDescriptor: ChartAccessibilityDescriptor {
        ChartAccessibilityDescriptor(
            title: L10n.Accessibility.Chart.weekdayTitle,
            summary: spokenSummary,
            xTitle: L10n.Accessibility.Chart.axisWeekday,
            xAxis: .categories(orderedData.map(\.weekdayLongName)),
            yTitle: L10n.Accessibility.Chart.axisAmount,
            series: [.init(name: L10n.Accessibility.Chart.weekdayTitle, isContinuous: false,
                           points: orderedData.map { .named($0.weekdayLongName, $0.average) })],
            format: amountFormat
        )
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
