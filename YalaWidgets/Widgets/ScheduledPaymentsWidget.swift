//
//  ScheduledPaymentsWidget.swift
//  YalaWidgets
//
//  Widget showing upcoming scheduled payments.
//  Medium: 3 payments. Large: 7. Extragrande vertical (iPhone, iOS 27): el mes en calendario + 4 +
//  lo que falta pagar este mes. Default sorting (overdue first, then by date).
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
    /// La persona no tiene ningún pago planificado: el widget invita a crear uno en vez de enseñar «Sin pagos
    /// pendientes» con un ✓, que se leía como «estás al día» (UX 2.2 · L15-2).
    var hasNoPayments: Bool = false
    /// Divisa principal: la de «Te falta pagar este mes» del extragrande vertical.
    var currencyCode: String = "PEN"
    /// El mes de pagos que calculó la app (`WidgetDataCache.buildPaymentsMonth`); `nil` en una foto anterior a 2.2.
    var paymentsMonth: WidgetPaymentsMonth?

    /// El mes de pagos SOLO si es el mes de `date`: una foto de otro mes (la app no se abre desde el día 1) pintaría
    /// días y una cifra que ya no son de este calendario.
    func paymentsMonth(for date: Date, calendar: Calendar = .current) -> WidgetPaymentsMonth? {
        guard let paymentsMonth,
              calendar.isDate(paymentsMonth.monthStart, equalTo: date, toGranularity: .month) else { return nil }
        return paymentsMonth
    }

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
                ),
                WidgetScheduledPayment(
                    id: "4",
                    name: "Internet",
                    amount: 119.00,
                    currencyCode: "PEN",
                    nextDueDate: Date().addingTimeInterval(86400 * 8),
                    isOverdue: false,
                    paymentCategory: "recurring",
                    isIncome: false,
                    iconName: "wifi",
                    colorHex: "#00C2CB"
                ),
                WidgetScheduledPayment(
                    id: "5",
                    name: "Gimnasio",
                    amount: 150.00,
                    currencyCode: "PEN",
                    nextDueDate: Date().addingTimeInterval(86400 * 12),
                    isOverdue: false,
                    paymentCategory: "subscription",
                    isIncome: false,
                    iconName: "figure.run",
                    colorHex: "#F59E0B"
                ),
                WidgetScheduledPayment(
                    id: "6",
                    name: "iCloud+",
                    amount: 9.90,
                    currencyCode: "PEN",
                    nextDueDate: Date().addingTimeInterval(86400 * 15),
                    isOverdue: false,
                    paymentCategory: "subscription",
                    isIncome: false,
                    iconName: "icloud.fill",
                    colorHex: "#3B82F6"
                ),
                WidgetScheduledPayment(
                    id: "7",
                    name: "Seguro",
                    amount: 210.00,
                    currencyCode: "PEN",
                    nextDueDate: Date().addingTimeInterval(86400 * 20),
                    isOverdue: false,
                    paymentCategory: "recurring",
                    isIncome: false,
                    iconName: "shield.fill",
                    colorHex: "#8B5CF6"
                )
            ],
            currencyDisplayFormat: "symbol",
            isPlaceholder: true,
            paymentsMonth: WidgetPaymentsMonth(
                monthStart: Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date(),
                pendingDays: [],
                paidDays: [],
                remainingToPay: 2_013.70
            )
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
        return createEntry(for: configuration, family: context.family)
    }

    func timeline(for configuration: ScheduledPaymentsWidgetIntent, in context: Context) async -> Timeline<ScheduledPaymentsEntry> {
        let entry = createEntry(for: configuration, family: context.family)

        // Refresh at midnight or after 4 hours
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let fourHours = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        let refreshDate = min(midnight, fourHours)

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    /// Filas del extragrande vertical: debajo del calendario caben cuatro.
    static let extraLargePortraitLimit = 4

    /// Cuántas filas caben por tamaño.
    static func paymentLimit(for family: WidgetFamily) -> Int {
        if family.isExtraLargePortrait { return extraLargePortraitLimit }
        return family == .systemLarge ? 7 : 3
    }

    private func createEntry(for configuration: ScheduledPaymentsWidgetIntent, family: WidgetFamily) -> ScheduledPaymentsEntry {
        let limit = Self.paymentLimit(for: family)
        let payments: [WidgetScheduledPayment]

        // Automático: los próximos por fecha (vencidos primero). Lo elegido a mano que ya no existe vuelve a eso en vez
        // de dejar el widget vacío (UX 2.2 · L15-2, `WidgetSelectionFallback`).
        let allPayments = WidgetDataService.getScheduledPayments(filter: .all, limit: 100)
        let selectedIDs = configuration.selectionMode == .custom
            ? (configuration.selectedPayments ?? []).map(\.id)
            : []
        payments = WidgetSelectionFallback.resolve(
            selectedIDs: selectedIDs,
            available: allPayments,
            automatic: allPayments,
            id: \.id,
            limit: limit
        )

        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()

        return ScheduledPaymentsEntry(
            date: Date(),
            payments: payments,
            currencyDisplayFormat: displayFormat,
            isPlaceholder: false,
            hasNoPayments: allPayments.isEmpty,
            currencyCode: WidgetDataService.getPreferredCurrency(),
            paymentsMonth: WidgetDataService.getPaymentsMonth()
        )
    }
}

// MARK: - Widget View

struct ScheduledPaymentsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ScheduledPaymentsEntry

    var body: some View {
        if family.isExtraLargePortrait {
            ScheduledPaymentsPortraitView(entry: entry)
        } else {
            list
        }
    }

    /// Mediano y grande: la lista de próximos pagos.
    private var list: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? WDS.Spacing.md : WDS.Spacing.sm) {
            // Header
            WidgetHeader(
                title: String(localized: "widget.ui.upcomingPayments", bundle: .main),
                icon: "calendar.badge.clock"
            )

            if entry.hasNoPayments {
                Spacer()
                WidgetCreateFirstView(icon: "calendar.badge.plus", message: "widget.empty.noPaymentsYet")
                Spacer()
            } else if entry.payments.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: WDS.Spacing.xs) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2) // A11Y-DT: widget empty state icon
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
                ForEach(entry.payments.prefix(ScheduledPaymentsProvider.paymentLimit(for: family)), id: \.id) { payment in
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
        .widgetURL(WidgetURLHelper.url(
            for: entry.hasNoPayments ? WidgetDeepLink.newScheduledPayment : "planning/scheduled-payments"))
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
                    .font(.system(size: WDS.Icon.sm)) // A11Y-DT: widget fixed layout
                    .foregroundStyle(payment.isOverdue ? WidgetColors.overdue : paymentColor)
                    .widgetAccentable()
            }

            // Name and date
            VStack(alignment: .leading, spacing: 0) {
                Text(payment.name)
                    .font(WDS.Typography.label)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(WDS.Typography.tiny)
                    .foregroundStyle(payment.isOverdue ? WidgetColors.overdue : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Amount
            WidgetAmountText(
                value: payment.isIncome ? abs(payment.amount) : -abs(payment.amount),
                currencyCode: payment.currencyCode,
                displayFormat: displayFormat,
                font: WDS.Typography.value,
                secondaryFont: WDS.Typography.valueSecondary,
                tint: .color(amountColor),
                forceSign: true,
                isEstimate: payment.isVariableAmount ?? false,
                fractionDigits: 2
            )
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
        return WidgetColors.expense
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
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(Color(.secondarySystemGroupedBackground), for: .widget)
        }
        .configurationDisplayName("widget.gallery.scheduledPayments")
        .description("widget.gallery.scheduledPayments.desc")
        .supportedFamilies(WidgetFamilies.addingExtraLargePortrait([.systemMedium, .systemLarge]))
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    ScheduledPaymentsWidget()
} timeline: {
    ScheduledPaymentsEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
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
