//
//  LatestRecordsWidget.swift
//  YalaWidgets
//
//  Widget showing the latest transactions.
//  Supports Medium size with 3 records.
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
                    amountInPreferredCurrency: 45.50
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
                    amountInPreferredCurrency: 150.00
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
                    amountInPreferredCurrency: 2500.00
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
        return createEntry(for: configuration)
    }

    func timeline(for configuration: LatestRecordsWidgetIntent, in context: Context) async -> Timeline<LatestRecordsEntry> {
        let entry = createEntry(for: configuration)
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func createEntry(for configuration: LatestRecordsWidgetIntent) -> LatestRecordsEntry {
        let transactions = WidgetDataService.getRecentTransactions(limit: 3)
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
    var entry: LatestRecordsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.sm) {
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
                ForEach(Array(entry.transactions.prefix(3).enumerated()), id: \.element.id) { _, transaction in
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
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
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
