//
//  ScheduledPaymentsWidget.swift
//  YalaWidgets
//
//  Widget showing upcoming scheduled payments.
//  Supports Medium size with filter configuration.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct ScheduledPaymentsWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Pagos planificados" }
    static var description: IntentDescription { "Muestra tus próximos pagos" }

    @Parameter(title: "Mostrar", default: .all)
    var filter: PaymentFilterOption
}

enum PaymentFilterOption: String, AppEnum {
    case all = "all"
    case recurring = "recurring"
    case subscription = "subscription"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Filtro"
    }

    static var caseDisplayRepresentations: [PaymentFilterOption: DisplayRepresentation] {
        [
            .all: "Todos",
            .recurring: "Planificados",
            .subscription: "Suscripciones"
        ]
    }

    var toServiceFilter: ScheduledPaymentFilter {
        switch self {
        case .all: return .all
        case .recurring: return .recurring
        case .subscription: return .subscription
        }
    }
}

// MARK: - Timeline Entry

struct ScheduledPaymentsEntry: TimelineEntry {
    let date: Date
    let payments: [WidgetScheduledPayment]
    let isPlaceholder: Bool
    let filter: PaymentFilterOption

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
            isPlaceholder: true,
            filter: .all
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
        let payments = WidgetDataService.getScheduledPayments(
            filter: configuration.filter.toServiceFilter,
            limit: 4
        )

        return ScheduledPaymentsEntry(
            date: Date(),
            payments: payments,
            isPlaceholder: false,
            filter: configuration.filter
        )
    }
}

// MARK: - Widget View

struct ScheduledPaymentsWidgetView: View {
    var entry: ScheduledPaymentsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(headerTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if entry.payments.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("Sin pagos pendientes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Payments list
                ForEach(entry.payments, id: \.id) { payment in
                    PaymentRow(payment: payment)
                }

                Spacer(minLength: 0)
            }
        }
        .padding()
        .widgetURL(URL(string: "yala://planning"))
    }

    private var headerTitle: String {
        switch entry.filter {
        case .all:
            return "Próximos pagos"
        case .recurring:
            return "Pagos planificados"
        case .subscription:
            return "Suscripciones"
        }
    }
}

struct PaymentRow: View {
    let payment: WidgetScheduledPayment

    var body: some View {
        HStack(spacing: 8) {
            // Overdue indicator or category icon
            ZStack {
                Circle()
                    .fill(payment.isOverdue ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 24, height: 24)

                Image(systemName: payment.isOverdue ? "exclamationmark" : categoryIcon)
                    .font(.system(size: 10))
                    .foregroundColor(payment.isOverdue ? .red : .blue)
            }

            // Name and date
            VStack(alignment: .leading, spacing: 0) {
                Text(payment.name)
                    .font(.caption)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundColor(payment.isOverdue ? .red : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Amount
            Text(formattedAmount)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(payment.isIncome ? .green : (payment.isOverdue ? .red : .primary))
        }
    }

    private var categoryIcon: String {
        payment.paymentCategory == "subscription" ? "repeat" : "calendar"
    }

    private var formattedDate: String {
        if payment.isOverdue {
            return "Vencido"
        }

        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(payment.nextDueDate) {
            return "Hoy"
        } else if calendar.isDateInTomorrow(payment.nextDueDate) {
            return "Mañana"
        } else {
            formatter.dateFormat = "d MMM"
            return formatter.string(from: payment.nextDueDate)
        }
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2

        let formatted = formatter.string(from: NSNumber(value: payment.amount)) ?? "0"
        let prefix = payment.isIncome ? "+" : ""
        return "\(prefix)\(formatted)"
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
        .configurationDisplayName("Pagos planificados")
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
