//
//  LatestRecordsWidget.swift
//  YalaWidgets
//
//  Widget showing the latest transactions.
//  Supports Medium size with 3-4 records.
//

import WidgetKit
import SwiftUI

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

struct LatestRecordsProvider: TimelineProvider {
    typealias Entry = LatestRecordsEntry

    func placeholder(in context: Context) -> LatestRecordsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (LatestRecordsEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(createEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LatestRecordsEntry>) -> Void) {
        let entry = createEntry()
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func createEntry() -> LatestRecordsEntry {
        let transactions = WidgetDataService.getRecentTransactions(limit: 4)
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
        VStack(alignment: .leading, spacing: WDS.Spacing.md) {
            // Header
            WidgetHeader(
                title: "Últimos registros",
                icon: "list.bullet.rectangle"
            )

            if entry.transactions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: WDS.Spacing.xs) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Sin registros")
                            .font(WDS.Typography.body)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Transaction list
                ForEach(Array(entry.transactions.prefix(4).enumerated()), id: \.element.id) { _, transaction in
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
        .widgetURL(WidgetURLHelper.url(for: "statistics/records"))
    }
}

// MARK: - Transaction Row

struct TransactionRowView: View {
    let transaction: WidgetTransaction
    let displayFormat: String

    var body: some View {
        HStack(spacing: WDS.ListItem.internalSpacing) {
            // Category icon with color
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: WDS.ListItem.iconSize, height: WDS.ListItem.iconSize)

                Image(systemName: transaction.categoryIcon ?? "questionmark")
                    .font(.system(size: WDS.Icon.sm))
                    .foregroundColor(categoryColor)
            }

            // Note/category
            VStack(alignment: .leading, spacing: 0) {
                Text(transaction.note ?? transaction.categoryName ?? "Sin nota")
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
            Text(formattedAmount)
                .font(WDS.Typography.value)
                .foregroundColor(transaction.isIncome ? WidgetColors.income : WidgetColors.expense)
        }
    }

    private var categoryColor: Color {
        if let hex = transaction.categoryColor {
            return Color(hex: hex)
        }
        return .gray
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        // Use original currency amount
        let amount = transaction.amount
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"

        let prefix = transaction.isIncome ? "+" : "-"
        let currency = displayFormat == "symbol"
            ? CurrencySymbols.symbol(for: transaction.currencyCode)
            : transaction.currencyCode

        return "\(prefix)\(currency) \(formatted)"
    }
}

// MARK: - Widget Definition

struct LatestRecordsWidget: Widget {
    let kind: String = "LatestRecordsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: LatestRecordsProvider()
        ) { entry in
            LatestRecordsWidgetView(entry: entry)
                .containerBackground(WidgetColors.yalaCard, for: .widget)
        }
        .configurationDisplayName("Últimos registros")
        .description("Tus transacciones más recientes")
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
