//
//  ScheduledPaymentsWidget.swift
//  YalaWidgets
//
//  Widget showing upcoming scheduled payments.
//  Supports Medium size with default sorting (overdue first, then by date).
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct ScheduledPaymentsEntry: TimelineEntry {
    let date: Date
    let payments: [WidgetScheduledPayment]
    let currencyDisplayFormat: String
    let isPlaceholder: Bool

    static var placeholder: ScheduledPaymentsEntry {
        ScheduledPaymentsEntry(
            date: Date(),
            payments: [
                WidgetScheduledPayment(
                    id: "1",
                    name: "Netflix",
                    amount: 44.90,
                    currencyCode: "PEN",
                    nextDueDate: Date().addingTimeInterval(86400 * 2),
                    isOverdue: false,
                    paymentCategory: "subscription",
                    isIncome: false
                ),
                WidgetScheduledPayment(
                    id: "2",
                    name: "Alquiler",
                    amount: 1500.00,
                    currencyCode: "PEN",
                    nextDueDate: Date().addingTimeInterval(-86400),
                    isOverdue: true,
                    paymentCategory: "recurring",
                    isIncome: false
                ),
                WidgetScheduledPayment(
                    id: "3",
                    name: "Spotify",
                    amount: 29.90,
                    currencyCode: "PEN",
                    nextDueDate: Date().addingTimeInterval(86400 * 5),
                    isOverdue: false,
                    paymentCategory: "subscription",
                    isIncome: false
                )
            ],
            currencyDisplayFormat: "symbol",
            isPlaceholder: true
        )
    }
}

// MARK: - Timeline Provider

struct ScheduledPaymentsProvider: TimelineProvider {
    typealias Entry = ScheduledPaymentsEntry

    func placeholder(in context: Context) -> ScheduledPaymentsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduledPaymentsEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(createEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduledPaymentsEntry>) -> Void) {
        let entry = createEntry()

        // Refresh at midnight or after 4 hours
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let fourHours = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        let refreshDate = min(midnight, fourHours)

        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func createEntry() -> ScheduledPaymentsEntry {
        let payments = WidgetDataService.getScheduledPayments(filter: .all, limit: 4)
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()

        return ScheduledPaymentsEntry(
            date: Date(),
            payments: payments,
            currencyDisplayFormat: displayFormat,
            isPlaceholder: false
        )
    }
}

// MARK: - Widget View

struct ScheduledPaymentsWidgetView: View {
    var entry: ScheduledPaymentsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.md) {
            // Header
            WidgetHeader(
                title: "Próximos pagos",
                icon: "calendar.badge.clock"
            )

            if entry.payments.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: WDS.Spacing.xs) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundStyle(WidgetColors.success)
                        Text("Sin pagos pendientes")
                            .font(WDS.Typography.body)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Payments list
                ForEach(entry.payments, id: \.id) { payment in
                    PaymentRowView(
                        payment: payment,
                        displayFormat: entry.currencyDisplayFormat
                    )
                }

                Spacer(minLength: 0)
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "planning"))
    }
}

// MARK: - Payment Row

struct PaymentRowView: View {
    let payment: WidgetScheduledPayment
    let displayFormat: String

    var body: some View {
        HStack(spacing: WDS.ListItem.internalSpacing) {
            // Overdue indicator or category icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: WDS.ListItem.iconSize, height: WDS.ListItem.iconSize)

                Image(systemName: iconName)
                    .font(.system(size: WDS.Icon.sm))
                    .foregroundColor(iconColor)
            }

            // Name and date
            VStack(alignment: .leading, spacing: 0) {
                Text(payment.name)
                    .font(WDS.Typography.label)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(WDS.Typography.tiny)
                    .foregroundColor(payment.isOverdue ? WidgetColors.overdue : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Amount
            Text(formattedAmount)
                .font(WDS.Typography.value)
                .foregroundColor(amountColor)
        }
    }

    private var iconName: String {
        if payment.isOverdue {
            return "exclamationmark"
        }
        return payment.paymentCategory == "subscription" ? "repeat" : "calendar"
    }

    private var iconColor: Color {
        payment.isOverdue ? WidgetColors.overdue : WidgetColors.accent
    }

    private var iconBackgroundColor: Color {
        (payment.isOverdue ? WidgetColors.overdue : WidgetColors.accent).opacity(0.2)
    }

    private var amountColor: Color {
        if payment.isIncome {
            return WidgetColors.income
        }
        if payment.isOverdue {
            return WidgetColors.overdue
        }
        return .primary
    }

    private var formattedDate: String {
        if payment.isOverdue {
            return "Vencido"
        }

        let calendar = Calendar.current

        if calendar.isDateInToday(payment.nextDueDate) {
            return "Hoy"
        } else if calendar.isDateInTomorrow(payment.nextDueDate) {
            return "Mañana"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: payment.nextDueDate)
        }
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: payment.amount)) ?? "0"
        let prefix = payment.isIncome ? "+" : ""
        let currency = displayFormat == "symbol"
            ? CurrencySymbols.symbol(for: payment.currencyCode)
            : payment.currencyCode

        return "\(prefix)\(currency) \(formatted)"
    }
}

// MARK: - Widget Definition

struct ScheduledPaymentsWidget: Widget {
    let kind: String = "ScheduledPaymentsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: ScheduledPaymentsProvider()
        ) { entry in
            ScheduledPaymentsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Próximos pagos")
        .description("Tus próximos pagos y suscripciones")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    ScheduledPaymentsWidget()
} timeline: {
    ScheduledPaymentsEntry.placeholder
}

#Preview("Empty", as: .systemMedium) {
    ScheduledPaymentsWidget()
} timeline: {
    ScheduledPaymentsEntry(
        date: Date(),
        payments: [],
        currencyDisplayFormat: "symbol",
        isPlaceholder: false
    )
}
