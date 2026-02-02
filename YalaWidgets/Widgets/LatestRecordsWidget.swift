//
//  LatestRecordsWidget.swift
//  YalaWidgets
//
//  Widget showing the latest transactions.
//  Supports Medium size with 3-5 records.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct LatestRecordsEntry: TimelineEntry {
    let date: Date
    let transactions: [WidgetTransaction]
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
                    categoryColor: "#45B7D1",
                    categoryIcon: "banknote",
                    subcategoryName: "Salario",
                    isIncome: true,
                    amountInPreferredCurrency: 2500.00
                )
            ],
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
        let transactions = WidgetDataService.getRecentTransactions(limit: 5)
        return LatestRecordsEntry(
            date: Date(),
            transactions: transactions,
            isPlaceholder: false
        )
    }
}

// MARK: - Widget View

struct LatestRecordsWidgetView: View {
    var entry: LatestRecordsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Últimos registros")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if entry.transactions.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Sin registros")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Transaction list
                ForEach(Array(entry.transactions.prefix(4).enumerated()), id: \.element.id) { _, transaction in
                    TransactionRow(transaction: transaction)
                }

                Spacer(minLength: 0)
            }
        }
        .padding()
        .widgetURL(URL(string: "yala://statistics/records"))
    }
}

struct TransactionRow: View {
    let transaction: WidgetTransaction

    var body: some View {
        HStack(spacing: 8) {
            // Category icon with color
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 24, height: 24)

                Image(systemName: transaction.categoryIcon ?? "questionmark")
                    .font(.system(size: 10))
                    .foregroundColor(categoryColor)
            }

            // Note/category
            VStack(alignment: .leading, spacing: 0) {
                Text(transaction.note ?? transaction.categoryName ?? "Sin nota")
                    .font(.caption)
                    .lineLimit(1)

                if let subcategory = transaction.subcategoryName {
                    Text(subcategory)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount
            Text(formattedAmount)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(transaction.isIncome ? .green : .primary)
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
        formatter.maximumFractionDigits = 2

        let amount = transaction.amountInPreferredCurrency != 0
            ? transaction.amountInPreferredCurrency
            : transaction.amount

        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "0"
        let prefix = transaction.isIncome ? "+" : "-"
        return "\(prefix)\(formatted)"
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
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
                .containerBackground(.fill.tertiary, for: .widget)
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
