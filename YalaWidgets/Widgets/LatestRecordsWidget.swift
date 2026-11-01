//
//  LatestRecordsWidget.swift
//  YalaWidgets
//
//  Widget showing the latest transactions.
//  Medium: 3 records. Large: 7 (misma fila, más alto).
//
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct LatestRecordsWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.latestRecords.title" }
    static var description: IntentDescription { "widget.intent.latestRecords.desc" }

}

// MARK: - Timeline Entry

struct LatestRecordsEntry: TimelineEntry {
    var date: Date
    let transactions: [WidgetTransaction]
    let currencyDisplayFormat: String
    let isPlaceholder: Bool
    /// Cuándo escribió la app la foto.
    var lastUpdated: Date? = nil

    static var placeholder: LatestRecordsEntry {
        LatestRecordsEntry(
            date: Date(),
            transactions: [
                WidgetTransaction(
                    id: "1",
                    date: Date(),
                    amount: 45.50,
                    currencyCode: "PEN",
                    note: "Almuerzo",
                    categoryName: "Alimentación",
                    categoryColor: "#FF6B6B",
                    categoryIcon: "fork.knife",
                    subcategoryIcon: "fork.knife",
                    subcategoryName: "Restaurantes",
                    isIncome: false,
                    amountInPreferredCurrency: 45.50,
                    isExchangeRateProvisional: false
                ),
                WidgetTransaction(
                    id: "2",
                    date: Date().addingTimeInterval(-3600),
                    amount: 150.00,
                    currencyCode: "PEN",
                    note: "Uber",
                    categoryName: "Transporte",
                    categoryColor: "#4ECDC4",
                    categoryIcon: "car.fill",
                    subcategoryIcon: "car.fill",
                    subcategoryName: "Taxi",
                    isIncome: false,
                    amountInPreferredCurrency: 150.00,
                    isExchangeRateProvisional: false
                ),
                WidgetTransaction(
                    id: "3",
                    date: Date().addingTimeInterval(-7200),
                    amount: 2500.00,
                    currencyCode: "PEN",
                    note: "Salario",
                    categoryName: "Ingresos",
                    categoryColor: "#00C2CB",
                    categoryIcon: "banknote",
                    subcategoryIcon: "banknote",
                    subcategoryName: "Salario",
                    isIncome: true,
                    amountInPreferredCurrency: 2500.00,
                    isExchangeRateProvisional: false
                ),
                WidgetTransaction(
                    id: "4",
                    date: Date().addingTimeInterval(-86400),
                    amount: 89.90,
                    currencyCode: "PEN",
                    note: "Supermercado",
                    categoryName: "Alimentación",
                    categoryColor: "#FF6B6B",
                    categoryIcon: "cart.fill",
                    subcategoryIcon: "cart.fill",
                    subcategoryName: "Supermercado",
                    isIncome: false,
                    amountInPreferredCurrency: 89.90,
                    isExchangeRateProvisional: false
                ),
                WidgetTransaction(
                    id: "5",
                    date: Date().addingTimeInterval(-90000),
                    amount: 35.00,
                    currencyCode: "PEN",
                    note: "Farmacia",
                    categoryName: "Salud",
                    categoryColor: "#EF4444",
                    categoryIcon: "cross.case.fill",
                    subcategoryIcon: "cross.case.fill",
                    subcategoryName: "Farmacia",
                    isIncome: false,
                    amountInPreferredCurrency: 35.00,
                    isExchangeRateProvisional: false
                ),
                WidgetTransaction(
                    id: "6",
                    date: Date().addingTimeInterval(-172800),
                    amount: 120.00,
                    currencyCode: "PEN",
                    note: "Luz",
                    categoryName: "Servicios",
                    categoryColor: "#00C2CB",
                    categoryIcon: "bolt.fill",
                    subcategoryIcon: "bolt.fill",
                    subcategoryName: "Electricidad",
                    isIncome: false,
                    amountInPreferredCurrency: 120.00,
                    isExchangeRateProvisional: false
                ),
                WidgetTransaction(
                    id: "7",
                    date: Date().addingTimeInterval(-180000),
                    amount: 18.50,
                    currencyCode: "PEN",
                    note: "Café",
                    categoryName: "Alimentación",
                    categoryColor: "#FF6B6B",
                    categoryIcon: "cup.and.saucer.fill",
                    subcategoryIcon: "cup.and.saucer.fill",
                    subcategoryName: "Cafetería",
                    isIncome: false,
                    amountInPreferredCurrency: 18.50,
                    isExchangeRateProvisional: false
                )
            ],
            currencyDisplayFormat: "symbol",
            isPlaceholder: true
        )
    }
}

// MARK: - Timeline Provider

struct LatestRecordsProvider: AppIntentTimelineProvider {
    typealias Entry = LatestRecordsEntry
    typealias Intent = LatestRecordsWidgetIntent

    func placeholder(in context: Context) -> LatestRecordsEntry {
        .placeholder
    }

    func snapshot(for configuration: LatestRecordsWidgetIntent, in context: Context) async -> LatestRecordsEntry {
        if context.isPreview {
            return .placeholder
        }
        return createEntry(for: configuration, family: context.family)
    }

    func timeline(for configuration: LatestRecordsWidgetIntent, in context: Context) async -> Timeline<LatestRecordsEntry> {
        let entry = createEntry(for: configuration, family: context.family)
        // A medianoche «Hoy» pasa a «Ayer»; los registros nuevos llegan antes, cuando la app guarda.
        return WidgetRefresh.dayAwareTimeline(entry) { midnight in
            var next = entry
            next.date = midnight
            return next
        }
    }

    /// Cuántas filas caben por tamaño.
    static func recordLimit(for family: WidgetFamily) -> Int {
        family == .systemLarge ? 7 : 3
    }

    private func createEntry(for configuration: LatestRecordsWidgetIntent, family: WidgetFamily) -> LatestRecordsEntry {
        let transactions = WidgetDataService.getRecentTransactions(limit: Self.recordLimit(for: family))
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()

        return LatestRecordsEntry(
            date: Date(),
            transactions: transactions,
            currencyDisplayFormat: displayFormat,
            isPlaceholder: false,
            lastUpdated: WidgetDataService.getLastUpdated()
        )
    }
}

// MARK: - Widget View

struct LatestRecordsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LatestRecordsEntry

    private var isLarge: Bool { family == .systemLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: isLarge ? WidgetDS.Spacing.md : WidgetDS.Spacing.sm) {
            WidgetCardHeader(
                title: String(localized: "widget.ui.latestRecords", bundle: .main),
                systemImage: "list.bullet",
                tint: WidgetColors.electricIndigo
            ) {
                NewRecordButton()
            }

            if entry.transactions.isEmpty {
                Spacer(minLength: 0)
                VStack(spacing: WidgetDS.Spacing.xxs) {
                    Text("widget.ui.noRecords", bundle: .main)
                        .font(WidgetDS.Typography.label)
                        .foregroundStyle(.primary)
                    Text("widget.records.emptyHint", bundle: .main)
                        .font(WidgetDS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                let rows = Array(entry.transactions.prefix(LatestRecordsProvider.recordLimit(for: family)))
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, transaction in
                        if index > 0 { Spacer(minLength: WidgetDS.Spacing.xs) }
                        TransactionRowView(transaction: transaction, displayFormat: entry.currencyDisplayFormat, now: entry.date)
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
        .widgetURL(WidgetURLHelper.url(for: "records"))
    }
}

/// El «+» de la cabecera: abre Nuevo registro desde el widget, sin pasar por la lista. Relleno índigo sólido como el
/// botón de la app; en tintado, translúcido (un relleno opaco se comería el «+»).
struct NewRecordButton: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Link(destination: MonthSummaryLinks.url("new-transaction")) {
            Image(systemName: "plus")
                .font(WidgetDS.Typography.indicator)
                .foregroundStyle(renderingMode == .fullColor ? Color.white : Color.primary)
                .frame(width: WidgetDS.Icon.badgeSmall, height: WidgetDS.Icon.badgeSmall)
                .background(Circle().fill(renderingMode == .fullColor
                                          ? WidgetColors.electricIndigo
                                          : Color.primary.opacity(WidgetDS.Opacity.subtle)))
        }
        .accessibilityLabel(Text("widget.ui.newRecord", bundle: .main))
    }
}

// MARK: - Transaction Row

/// Un registro: insignia sólida de su categoría, la nota (o la subcategoría), «categoría · cuándo» y el importe con su
/// signo en la divisa en que se guardó. Solo el ingreso lleva color.
struct TransactionRowView: View {
    let transaction: WidgetTransaction
    let displayFormat: String
    var now: Date = Date()

    var body: some View {
        HStack(spacing: WidgetDS.Spacing.sm) {
            WidgetBadge(systemImage: iconName, color: categoryColor)

            VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
                Text(title)
                    .font(WidgetDS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(WidgetDS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: WidgetDS.Spacing.xs)

            // Importe en su divisa original, como la fila de Registros.
            WidgetAmountText(
                value: transaction.isIncome ? abs(transaction.amount) : -abs(transaction.amount),
                currencyCode: transaction.currencyCode,
                displayFormat: displayFormat,
                font: WidgetDS.Typography.subheadlineEmphasized,
                secondaryFont: WidgetDS.Typography.captionSmall,
                tint: transaction.isIncome ? .color(WidgetColors.incomeText) : .primary,
                forceSign: true,
                fractionDigits: 2
            )
            .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    private var note: String? {
        guard let note = transaction.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else { return nil }
        return note
    }

    /// La nota; sin nota, la subcategoría; sin ella, la categoría.
    private var title: String {
        note ?? transaction.subcategoryName ?? transaction.categoryName
            ?? String(localized: "widget.ui.uncategorized", bundle: .main)
    }

    /// Lo que el título no dijo (la subcategoría o la categoría) y el día.
    private var subtitle: String {
        let context: String?
        if note != nil {
            context = transaction.subcategoryName ?? transaction.categoryName
        } else if transaction.subcategoryName != nil {
            context = transaction.categoryName
        } else {
            context = nil
        }
        return [context, dayText].compactMap { $0 }.joined(separator: " · ")
    }

    private var dayText: String {
        switch WidgetInsightsLogic.dayLabel(for: transaction.date, now: now, calendar: .current) {
        case .today: return String(localized: "widget.ui.today", bundle: .main)
        case .yesterday: return String(localized: "widget.ui.yesterday", bundle: .main)
        case .date: return transaction.date.formatted(.dateTime.day().month(.abbreviated))
        }
    }

    private var iconName: String {
        transaction.subcategoryIcon ?? transaction.categoryIcon ?? WidgetDataService.uncategorizedIconName
    }

    private var categoryColor: Color {
        Color(hex: transaction.categoryColor ?? WidgetDataService.uncategorizedColorHex)
    }
}

// MARK: - Widget Definition

struct LatestRecordsWidget: Widget {
    let kind: String = "LatestRecordsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: LatestRecordsWidgetIntent.self,
            provider: LatestRecordsProvider()
        ) { entry in
            LatestRecordsWidgetView(entry: entry)
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(WidgetColors.cardBackground, for: .widget)
        }
        .configurationDisplayName("widget.gallery.latestRecords")
        .description("widget.gallery.latestRecords.desc")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    LatestRecordsWidget()
} timeline: {
    LatestRecordsEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    LatestRecordsWidget()
} timeline: {
    LatestRecordsEntry.placeholder
}

#Preview("Empty", as: .systemMedium) {
    LatestRecordsWidget()
} timeline: {
    LatestRecordsEntry(
        date: Date(),
        transactions: [],
        currencyDisplayFormat: "symbol",
        isPlaceholder: false
    )
}
