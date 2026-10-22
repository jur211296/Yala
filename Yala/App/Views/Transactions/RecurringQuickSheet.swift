//
//  RecurringQuickSheet.swift
//  Yala
//
//  «Hacer recurrente» del formulario de registro (UX 2.2 · L2-15, decidido por Jürgen el 14-oct y cerrado el 21-oct):
//  una hoja corta con tres frecuencias que salen de la fecha del registro, y «Más opciones…» para el editor completo.
//

import SwiftUI

/// Las tres filas de la hoja, con el texto que sale de la fecha del registro. Lógica pura para fijarla con tests.
enum RecurringQuickChoiceLogic {

    struct Choice: Equatable {
        let recurrence: RecurrenceType
        let title: String
    }

    /// «Cada semana, el martes», «Cada mes, el día 13», «Cada año, el 13 de octubre».
    static func choices(for date: Date, locale: Locale, calendar: Calendar = .current) -> [Choice] {
        let weekday = DateFormatter()
        weekday.locale = locale
        weekday.calendar = calendar
        weekday.setLocalizedDateFormatFromTemplate("EEEE")

        let dayMonth = DateFormatter()
        dayMonth.locale = locale
        dayMonth.calendar = calendar
        dayMonth.setLocalizedDateFormatFromTemplate("dMMMM")

        let day = calendar.component(.day, from: date)
        return [
            Choice(recurrence: .weekly, title: L10n.UXL2.recurringWeekly(weekday.string(from: date))),
            Choice(recurrence: .monthly, title: L10n.UXL2.recurringMonthly(day)),
            Choice(recurrence: .yearly, title: L10n.UXL2.recurringYearly(dayMonth.string(from: date))),
        ]
    }

    /// El ancla del pago planificado para cada frecuencia: el día de la semana, el día del mes o el día y el mes de la
    /// fecha del registro. Antes, con precarga, el día de la semana se quedaba en lunes.
    struct Anchor: Equatable {
        let weekday: Int
        let dayOfMonth: Int
        let month: Int
    }

    static func anchor(for date: Date, calendar: Calendar = .current) -> Anchor {
        Anchor(
            weekday: calendar.component(.weekday, from: date),
            dayOfMonth: calendar.component(.day, from: date),
            month: calendar.component(.month, from: date)
        )
    }
}

struct RecurringQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    let transactionDate: Date
    let onPick: (RecurrenceType) -> Void
    let onMoreOptions: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text(L10n.UXL2.recurringHeader)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, DS.Spacing.xs)
                        .accessibilityIdentifier("recurring_quick_header")

                    ForEach(
                        RecurringQuickChoiceLogic.choices(for: transactionDate, locale: AppLocale.current),
                        id: \.recurrence
                    ) { choice in
                        row(title: choice.title, icon: "repeat", identifier: "recurring_quick_\(choice.recurrence.rawValue)") {
                            onPick(choice.recurrence)
                        }
                    }

                    row(title: L10n.UXL2.recurringMoreOptions, icon: "slider.horizontal.3",
                        identifier: "recurring_quick_more", showsChevron: true) {
                        onMoreOptions()
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.UXL2.recurringTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .yalaScreenBackground(.partialSheet, ignoredEdges: [])
        }
        .yalaSheetDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(
        title: String,
        icon: String,
        identifier: String,
        showsChevron: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(theme.card)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
