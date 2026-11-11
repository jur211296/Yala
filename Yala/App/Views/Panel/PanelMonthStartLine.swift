//
//  PanelMonthStartLine.swift
//  Yala
//
//  Los días 1 y 2 de «Este mes», bajo la cifra del hero: «Día 1 de 31 · Ver últimos 30 días · Ver octubre» (decisión 10
//  de la revisión 2.3, opción E). Dice por qué hay poco y ofrece dos atajos que cambian el selector de período de verdad,
//  como si la persona lo hubiera elegido en la píldora: la app nunca cambia el período sola. Desde el día 3, o con otro
//  período elegido, no está.
//

import SwiftUI

struct PanelMonthStartLine: View {
    let selectedPeriod: DetailPeriod
    let onSelectPeriod: (DetailPeriod) -> Void

    var body: some View {
        if let start = PanelEarlyMonthLogic.monthStart(period: selectedPeriod, now: .now, calendar: .current) {
            let day = Text(L10n.Panel.MonthStart.dayOfMonth(start.day, start.daysInMonth))
                .foregroundStyle(.secondary)
            let previousMonth = PanelEarlyMonthLogic.previousMonthName(
                now: .now, calendar: .current, locale: AppLocale.current)
            // En una línea si cabe; si no, el día arriba y los atajos debajo; con texto muy grande, uno por línea.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    day
                    separator
                    last30DaysButton
                    separator
                    previousMonthButton(previousMonth)
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    day
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        last30DaysButton
                        separator
                        previousMonthButton(previousMonth)
                    }
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    day
                    last30DaysButton
                    previousMonthButton(previousMonth)
                }
            }
            .font(DS.Typography.subheadline)
            .lineLimit(1)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("panel_month_start_line")
        }
    }

    private var separator: some View {
        Text(verbatim: "·")
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private var last30DaysButton: some View {
        Button {
            DS.Haptic.selection()
            onSelectPeriod(.last30Days)
        } label: {
            Text(L10n.Panel.MonthStart.last30Days)
                .foregroundStyle(.thAccentText)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("panel_month_start_last30")
    }

    private func previousMonthButton(_ month: String) -> some View {
        Button {
            DS.Haptic.selection()
            onSelectPeriod(.lastMonth)
        } label: {
            Text(L10n.Panel.MonthStart.previousMonth(month))
                .foregroundStyle(.thAccentText)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("panel_month_start_previous_month")
    }
}
