//
//  ScheduledPaymentsWidget.swift
//  YalaWidgets
//
//  Widget showing upcoming scheduled payments.
//  Supports Medium size with default sorting (overdue first, then by date).
//  Configurable: selection mode (auto/custom).
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct ScheduledPaymentsWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.scheduledPayments.title" }
    static var description: IntentDescription { "widget.intent.scheduledPayments.desc" }

    @Parameter(title: "widget.selection.mode.type", default: .automatic)
    var selectionMode: SelectionModeOption

    @Parameter(title: "widget.select.payments")
    var selectedPayments: [ScheduledPaymentAppEntity]?

    static var parameterSummary: some ParameterSummary {
        When(\ScheduledPaymentsWidgetIntent.$selectionMode, .equalTo, .custom) {
            Summary {
                \ScheduledPaymentsWidgetIntent.$selectionMode
                \ScheduledPaymentsWidgetIntent.$selectedPayments
            }
        } otherwise: {
            Summary {
                \ScheduledPaymentsWidgetIntent.$selectionMode
            }
        }
    }
}

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
                    isIncome: false,
                    iconName: "play.tv.fill",
                    colorHex: "#E50914"
                ),
                WidgetScheduledPayment(
                    id: "2",
                    name: "Alquiler",
                    amount: 1500.00,
                    currencyCode: "PEN",
                    nextDueDate: Date().addingTimeInterval(-86400),
                    isOverdue: true,
                    paymentCategory: "recurring",
                    isIncome: false,
                    iconName: "house.fill",
                    colorHex: "#6366F1"
                ),
                WidgetScheduledPayment(
                    id: "3",
                    name: "Spotify",
                    amount: 29.90,
                    currencyCode: "PEN",
                    nextDueDate: Date().addingTimeInterval(86400 * 5),
                    isOverdue: false,
                    paymentCategory: "subscription",
                    isIncome: false,
                    iconName: "music.note",
                    colorHex: "#1DB954"
                )
            ],
            currencyDisplayFormat: "symbol",
            isPlaceholder: true
        )
    }
}

// MARK: - Timeline Provider

struct ScheduledPaymentsProvider: AppIntentTimelineProvider {
    typealias Entry = ScheduledPaymentsEntry
    typealias Intent = ScheduledPaymentsWidgetIntent

    func placeholder(in context: Context) -> ScheduledPaymentsEntry {
        .placeholder
    }

    func snapshot(for configuration: ScheduledPaymentsWidgetIntent, in context: Context) async -> ScheduledPaymentsEntry {
        if context.isPreview {
            return .placeholder
        }
        return createEntry(for: configuration)
    }

    func timeline(for configuration: ScheduledPaymentsWidgetIntent, in context: Context) async -> Timeline<ScheduledPaymentsEntry> {
        let entry = createEntry(for: configuration)

        // Refresh at midnight or after 4 hours
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let fourHours = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        let refreshDate = min(midnight, fourHours)

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func createEntry(for configuration: ScheduledPaymentsWidgetIntent) -> ScheduledPaymentsEntry {
        var payments: [WidgetScheduledPayment]

        if configuration.selectionMode == .custom,
           let selected = configuration.selectedPayments,
           !selected.isEmpty {
            // Custom mode: filter by selected IDs and maintain selection order
            let allPayments = WidgetDataService.getScheduledPayments(filter: .all, limit: 100)
            payments = selected.compactMap { entity in
                allPayments.first { $0.id == entity.id }
            }
            payments = Array(payments.prefix(3))
        } else {
            // Automatic mode: next 3 by date (overdue first)
            payments = WidgetDataService.getScheduledPayments(filter: .all, limit: 3)
        }

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
        VStack(alignment: .leading, spacing: WDS.Spacing.sm) {
            // Header
            WidgetHeader(
                title: String(localized: "widget.ui.upcomingPayments", bundle: .main),
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
                        Text("widget.ui.noPayments", bundle: .main)
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
        HStack(spacing: WDS.Spacing.sm) {
            // Icon badge con color de la subcategoría/payment
            ZStack {
                Circle()
                    .fill(paymentColor.opacity(0.2))
                    .frame(width: WDS.ListItem.iconSizeCompact,
                           height: WDS.ListItem.iconSizeCompact)

                Image(systemName: iconName)
                    .font(.system(size: WDS.Icon.sm))
                    .foregroundColor(payment.isOverdue ? WidgetColors.overdue : paymentColor)
                    .widgetAccentable()
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
                .widgetAccentable()
        }
    }

    // Icono con fallback para backwards compatibility
    private var iconName: String {
        if payment.isOverdue {
            return "exclamationmark"
        }
        if let icon = payment.iconName {
            return icon
        }
        // Fallback basado en paymentCategory
        return payment.paymentCategory == "subscription"
            ? "creditcard.and.123"
            : "arrow.trianglehead.2.clockwise.rotate.90"
    }

    // Color con fallback para backwards compatibility
    private var paymentColor: Color {
        Color(hex: payment.colorHex ?? "#6366F1")
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
            return String(localized: "widget.ui.overdue", bundle: .main)
        }

        let calendar = Calendar.current

        if calendar.isDateInToday(payment.nextDueDate) {
            return String(localized: "widget.ui.today", bundle: .main)
        } else if calendar.isDateInTomorrow(payment.nextDueDate) {
            return String(localized: "widget.ui.tomorrow", bundle: .main)
        } else {
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("dMMM")
            return formatter.string(from: payment.nextDueDate)
        }
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let formatted = formatter.string(from: NSNumber(value: payment.amount)) ?? "0.00"
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
        AppIntentConfiguration(
            kind: kind,
            intent: ScheduledPaymentsWidgetIntent.self,
            provider: ScheduledPaymentsProvider()
        ) { entry in
            ScheduledPaymentsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("widget.gallery.scheduledPayments")
        .description("widget.gallery.scheduledPayments.desc")
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
