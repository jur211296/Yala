//
//  ScheduledPaymentsPortraitView.swift
//  YalaWidgets
//
//  «Pagos planificados» en el extragrande vertical del iPhone (iOS 27): el mes en calendario con los días de pago,
//  los próximos pagos y lo que falta pagar este mes (lienzo de la card `widgets-extragrandes-en-el-iphone-con-io-5fir`,
//  opción C).
//
//  Los días y la cifra los calcula la app (`WidgetDataSnapshot.paymentsMonth`): el widget no tiene las recurrencias ni
//  los tipos de cambio. Si la foto es de otro mes, o de una versión que no la traía, el calendario sale sin marcas y
//  la cifra no sale: mejor nada que un mes equivocado.
//

import SwiftUI
import WidgetKit

struct ScheduledPaymentsPortraitView: View {
    let entry: ScheduledPaymentsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.lg) {
            WidgetHeader(
                title: String(localized: "widget.ui.upcomingPayments", bundle: .main),
                subtitle: PaymentsMonthCalendar.monthTitle(for: entry.date),
                icon: "calendar.badge.clock"
            )

            if entry.hasNoPayments {
                Spacer()
                WidgetCreateFirstView(icon: "calendar.badge.plus", message: "widget.empty.noPaymentsYet")
                Spacer()
            } else {
                PaymentsMonthCalendar(
                    now: entry.date,
                    month: entry.paymentsMonth(for: entry.date)
                )

                Divider()

                if entry.payments.isEmpty {
                    HStack(spacing: WDS.Spacing.xs) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(WidgetColors.success)
                        Text("widget.ui.noPayments", bundle: .main)
                            .font(WDS.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: WDS.Spacing.md) {
                        ForEach(
                            entry.payments.prefix(ScheduledPaymentsProvider.extraLargePortraitLimit),
                            id: \.id
                        ) { payment in
                            PaymentRowView(payment: payment, displayFormat: entry.currencyDisplayFormat)
                        }
                    }
                }

                Spacer(minLength: 0)

                if let month = entry.paymentsMonth(for: entry.date) {
                    Divider()
                    HStack(alignment: .firstTextBaseline) {
                        Text("widget.ui.leftToPayThisMonth", bundle: .main)
                            .font(WDS.Typography.label)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: WDS.Spacing.md)
                        WidgetAmountText(
                            value: month.remainingToPay,
                            currencyCode: entry.currencyCode,
                            displayFormat: entry.currencyDisplayFormat,
                            font: WDS.Typography.kpiSmall,
                            secondaryFont: WDS.Typography.kpiSmallSecondary,
                            tint: .primary,
                            fractionDigits: 2
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(
            for: entry.hasNoPayments ? WidgetDeepLink.newScheduledPayment : "planning/scheduled-payments"))
    }
}

// MARK: - Calendario del mes

struct PaymentsMonthCalendar: View {
    let now: Date
    /// `nil` = sin datos de este mes: se pinta el mes sin marcas.
    let month: WidgetPaymentsMonth?

    private var calendar: Calendar { WidgetDataService.widgetConfiguredCalendar() }
    static let cellHeight: CGFloat = 24

    var body: some View {
        let weeks = Self.weeks(for: now, calendar: calendar)
        let today = calendar.component(.day, from: now)
        let pending = Set(month?.pendingDays ?? [])
        let paid = Set(month?.paidDays ?? [])

        Grid(horizontalSpacing: WDS.Spacing.xs, verticalSpacing: WDS.Spacing.xs) {
            GridRow {
                ForEach(Array(Self.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(WDS.Typography.labelSmall)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                GridRow {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        dayCell(day, today: today, pending: pending, paid: paid)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Int?, today: Int, pending: Set<Int>, paid: Set<Int>) -> some View {
        if let day {
            let isPending = pending.contains(day)
            let isPaid = !isPending && paid.contains(day)
            Text("\(day)")
                .font(WDS.Typography.value)
                .monospacedDigit()
                .fontWeight(isPending ? .bold : .regular)
                .foregroundStyle(isPending ? AnyShapeStyle(WidgetColors.primary)
                                 : isPaid ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .frame(maxWidth: .infinity)
                .frame(height: Self.cellHeight)
                .background {
                    RoundedRectangle(cornerRadius: WDS.Radius.xs)
                        .fill(isPending ? WidgetColors.primary.opacity(0.16)
                              : isPaid ? Color.primary.opacity(0.06) : .clear)
                }
                .overlay {
                    if day == today {
                        RoundedRectangle(cornerRadius: WDS.Radius.xs)
                            .strokeBorder(WidgetColors.primary, lineWidth: 1.5)
                    }
                }
                .widgetAccentable(isPending)
        } else {
            // Alto FIJO: un `Color.clear` es flexible y estiraba la semana que tiene huecos.
            Color.clear.frame(maxWidth: .infinity).frame(height: Self.cellHeight)
        }
    }

    /// Las semanas del mes de `date`, empezando por el primer día de la semana de la persona; `nil` = hueco.
    static func weeks(for date: Date, calendar: Calendar) -> [[Int?]] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let dayRange = calendar.range(of: .day, in: .month, for: date) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Int?] = Array(repeating: nil, count: leading) + dayRange.map { Optional($0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// Iniciales de los días en el orden de la semana de la persona.
    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// «octubre» / «October»: el mes en el idioma del widget, sin año.
    static func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("LLLL")
        return formatter.string(from: date).capitalized(with: .current)
    }
}
