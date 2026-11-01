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
    var date: Date
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
    /// Cuándo escribió la app la foto.
    var lastUpdated: Date? = nil

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
        // A medianoche cambian «Hoy», «Mañana» y «En N días».
        return WidgetRefresh.dayAwareTimeline(entry) { midnight in
            var next = entry
            next.date = midnight
            return next
        }
    }

    /// Filas del extragrande vertical: debajo del calendario caben cinco con la fila compacta de 2.2.
    static let extraLargePortraitLimit = 5

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
            paymentsMonth: WidgetDataService.getPaymentsMonth(),
            lastUpdated: WidgetDataService.getLastUpdated()
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

    private var isLarge: Bool { family == .systemLarge }

    /// Mediano y grande: la lista de próximos pagos.
    private var list: some View {
        VStack(alignment: .leading, spacing: isLarge ? WidgetDS.Spacing.md : WidgetDS.Spacing.sm) {
            ScheduledPaymentsHeader(entry: entry)

            if entry.hasNoPayments {
                Spacer(minLength: 0)
                WidgetCreateFirstView(icon: "calendar.badge.plus", message: "widget.empty.noPaymentsYet")
                Spacer(minLength: 0)
            } else if entry.payments.isEmpty {
                Spacer(minLength: 0)
                Label {
                    Text("widget.ui.noPayments", bundle: .main)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(WidgetDS.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                let rows = Array(entry.payments.prefix(ScheduledPaymentsProvider.paymentLimit(for: family)))
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, payment in
                        if index > 0 { Spacer(minLength: WidgetDS.Spacing.xs) }
                        PaymentRowView(payment: payment, displayFormat: entry.currencyDisplayFormat, now: entry.date)
                    }
                    if isLarge {
                        Spacer(minLength: WidgetDS.Spacing.sm)
                        WidgetFreshnessNote(lastUpdated: entry.lastUpdated, now: entry.date)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(
            for: entry.hasNoPayments ? WidgetDeepLink.newScheduledPayment : "planning/scheduled-payments"))
    }
}

/// «Pagos planificados» y, a la derecha, lo que falta pagar este mes (la cifra que calcula la app; sin ella, o en
/// cero, nada).
struct ScheduledPaymentsHeader: View {
    let entry: ScheduledPaymentsEntry
    var subtitle: String? = nil

    var body: some View {
        WidgetCardHeader(
            title: String(localized: "widget.ui.upcomingPayments", bundle: .main),
            systemImage: "calendar",
            tint: WidgetColors.electricIndigo
        ) {
            if let subtitle {
                WidgetHeaderDetail(text: subtitle)
            } else if let month = entry.paymentsMonth(for: entry.date), month.remainingToPay > 0.005 {
                let symbol = CurrencySymbols.display(for: entry.currencyCode, format: entry.currencyDisplayFormat)
                WidgetHeaderDetail(text: String(
                    format: String(localized: "widget.payments.leftShort", bundle: .main),
                    WidgetAmountSplitter.split(value: month.remainingToPay, symbol: symbol, fractionDigits: 0).accessibilityFormatted))
            }
        }
    }
}

// MARK: - Payment Row

/// Un pago: insignia sólida con su icono y color, el nombre, cuándo vence («Hoy», «Mañana», «En 3 días», «Vencido · 28
/// oct.») y el importe con signo. Solo el ingreso lleva color; el vencido avisa en el «cuándo», sin cambiar el icono.
struct PaymentRowView: View {
    let payment: WidgetScheduledPayment
    let displayFormat: String
    var now: Date = Date()

    var body: some View {
        HStack(spacing: WidgetDS.Spacing.sm) {
            WidgetBadge(systemImage: iconName, color: WidgetColors.fill(hex: payment.colorHex))

            VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
                Text(payment.name)
                    .font(WidgetDS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(dueText)
                    .font(WidgetDS.Typography.captionSmall)
                    .foregroundStyle(isOverdue ? WidgetColors.alertText : Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: WidgetDS.Spacing.xs)

            WidgetAmountText(
                value: payment.isIncome ? abs(payment.amount) : -abs(payment.amount),
                currencyCode: payment.currencyCode,
                displayFormat: displayFormat,
                font: WidgetDS.Typography.subheadlineEmphasized,
                secondaryFont: WidgetDS.Typography.captionSmall,
                tint: payment.isIncome ? .color(WidgetColors.incomeText) : .primary,
                forceSign: true,
                isEstimate: payment.isVariableAmount ?? false,
                fractionDigits: 2
            )
            .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    private var label: WidgetInsightsLogic.DueLabel {
        WidgetInsightsLogic.dueLabel(due: payment.nextDueDate, isOverdue: payment.isOverdue, now: now, calendar: .current)
    }

    private var isOverdue: Bool { label == .overdue }

    // Icono con fallback para fotos antiguas (sin icono propio).
    private var iconName: String {
        if let icon = payment.iconName { return icon }
        return payment.paymentCategory == "subscription"
            ? "creditcard.and.123"
            : "arrow.trianglehead.2.clockwise.rotate.90"
    }

    private var dueText: String {
        WidgetDateText.due(payment.nextDueDate, isOverdue: payment.isOverdue, now: now)
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
                .containerBackground(WidgetColors.cardBackground, for: .widget)
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
