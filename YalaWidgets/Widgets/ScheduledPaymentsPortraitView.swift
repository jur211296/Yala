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
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.lg) {
            ScheduledPaymentsHeader(entry: entry, subtitle: PaymentsMonthCalendar.monthTitle(for: entry.date))

            if entry.hasNoPayments {
                Spacer(minLength: 0)
                WidgetCreateFirstView(icon: "calendar.badge.plus", message: "widget.empty.noPaymentsYet")
                Spacer(minLength: 0)
            } else {
                PaymentsMonthCalendar(
                    now: entry.date,
                    month: entry.paymentsMonth(for: entry.date)
                )

                Divider()

                if entry.payments.isEmpty {
                    Label {
                        Text("widget.ui.noPayments", bundle: .main)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .font(WidgetDS.Typography.caption)
                    .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
                        ForEach(
                            entry.payments.prefix(ScheduledPaymentsProvider.extraLargePortraitLimit),
                            id: \.id
                        ) { payment in
                            PaymentRowView(payment: payment, displayFormat: entry.currencyDisplayFormat, now: entry.date)
                        }
                    }
                }

                Spacer(minLength: 0)

                if let month = entry.paymentsMonth(for: entry.date) {
                    Divider()
                    HStack(alignment: .firstTextBaseline) {
                        Text("widget.ui.leftToPayThisMonth", bundle: .main)
                            .font(WidgetDS.Typography.label)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: WidgetDS.Spacing.md)
                        WidgetAmountText(
                            value: month.remainingToPay,
                            currencyCode: entry.currencyCode,
                            displayFormat: entry.currencyDisplayFormat,
                            font: WidgetDS.Typography.headline,
                            secondaryFont: WidgetDS.Typography.caption,
                            tint: .primary,
                            fractionDigits: 2
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
    static let cellHeight = WidgetDS.Spacing.xxl

    var body: some View {
        let weeks = Self.weeks(for: now, calendar: calendar)
        let today = calendar.component(.day, from: now)
        let pending = Set(month?.pendingDays ?? [])
        let paid = Set(month?.paidDays ?? [])

        Grid(horizontalSpacing: WidgetDS.Spacing.xs, verticalSpacing: WidgetDS.Spacing.xs) {
            GridRow {
                ForEach(Array(Self.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(WidgetDS.Typography.labelTiny)
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

    @Environment(\.widgetRenderingMode) private var renderingMode

    /// Día con pago pendiente: relleno índigo sólido con el número en blanco (en tintado, translúcido: un relleno opaco
    /// se comería el número). Pagado: gris tenue. Hoy: contorno.
    @ViewBuilder
    private func dayCell(_ day: Int?, today: Int, pending: Set<Int>, paid: Set<Int>) -> some View {
        if let day {
            let isPending = pending.contains(day)
            let isPaid = !isPending && paid.contains(day)
            let solid = isPending && renderingMode == .fullColor
            Text("\(day)")
                .font(WidgetDS.Typography.caption)
                .monospacedDigit()
                .fontWeight(isPending ? .semibold : .regular)
                .foregroundStyle(solid ? AnyShapeStyle(Color.white)
                                 : isPaid ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .frame(maxWidth: .infinity)
                .frame(height: Self.cellHeight)
                .background {
                    RoundedRectangle(cornerRadius: WidgetDS.Radius.sm, style: .continuous)
                        .fill(isPending ? (solid ? WidgetColors.electricIndigo : Color.primary.opacity(WidgetDS.Opacity.overlay))
                              : isPaid ? Color.primary.opacity(WidgetDS.Opacity.faint) : .clear)
                }
                .overlay {
                    if day == today {
                        RoundedRectangle(cornerRadius: WidgetDS.Radius.sm, style: .continuous)
                            .strokeBorder(isPending ? Color.primary : WidgetColors.accentText, lineWidth: WidgetDS.Spacing.xxs)
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
