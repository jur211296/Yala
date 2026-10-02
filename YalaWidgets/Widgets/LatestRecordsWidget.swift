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
    let date: Date
    let transactions: [WidgetTransaction]
    let currencyDisplayFormat: String
    let isPlaceholder: Bool

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
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(refreshDate))
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
            isPlaceholder: false
        )
    }
}

// MARK: - Widget View

struct LatestRecordsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: LatestRecordsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemLarge ? WDS.Spacing.md : WDS.Spacing.sm) {
            // Header
            WidgetHeader(
                title: String(localized: "widget.ui.latestRecords", bundle: .main),
                icon: "list.bullet.rectangle"
            )

            if entry.transactions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: WDS.Spacing.xs) {
                        Image(systemName: "tray")
                            .font(.title2) // A11Y-DT: widget empty state icon
                            .foregroundStyle(.tertiary)
                        Text("widget.ui.noRecords", bundle: .main)
                            .font(WDS.Typography.body)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Transaction list
                ForEach(Array(entry.transactions.prefix(LatestRecordsProvider.recordLimit(for: family)).enumerated()), id: \.element.id) { _, transaction in
                    TransactionRowView(
                        transaction: transaction,
                        displayFormat: entry.currencyDisplayFormat
                    )
                }

                Spacer(minLength: 0)
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "records"))
    }
}

// MARK: - Transaction Row

struct TransactionRowView: View {
    let transaction: WidgetTransaction
    let displayFormat: String

    var body: some View {
        HStack(spacing: WDS.Spacing.sm) {
            // Category icon with color
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: WDS.ListItem.iconSizeCompact,
                           height: WDS.ListItem.iconSizeCompact)

                Image(systemName: transaction.subcategoryIcon ?? transaction.categoryIcon ?? "questionmark")
                    .font(.system(size: WDS.Icon.sm)) // A11Y-DT: widget fixed layout
                    .foregroundStyle(categoryColor)
                    .widgetAccentable()
            }

            // Note/category
            VStack(alignment: .leading, spacing: 0) {
                Text(transaction.note ?? transaction.categoryName ?? String(localized: "widget.ui.noNote", bundle: .main))
                    .font(WDS.Typography.label)
                    .lineLimit(1)

                if let subcategory = transaction.subcategoryName {
                    Text(subcategory)
                        .font(WDS.Typography.tiny)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount (show in original currency)
            WidgetAmountText(
                value: transaction.isIncome ? abs(transaction.amount) : -abs(transaction.amount),
                currencyCode: transaction.currencyCode,
                displayFormat: displayFormat,
                font: WDS.Typography.value,
                secondaryFont: WDS.Typography.valueSecondary,
                tint: .color(transaction.isIncome ? WidgetColors.income : WidgetColors.expense),
                forceSign: true,
                fractionDigits: 2
            )
            .widgetAccentable()
        }
    }

    private var categoryColor: Color {
        if let hex = transaction.categoryColor {
            return Color(hex: hex)
        }
        return .gray
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
                .containerBackground(Color(.secondarySystemGroupedBackground), for: .widget)
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
