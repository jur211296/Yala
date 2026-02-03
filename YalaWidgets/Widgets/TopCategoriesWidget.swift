//
//  TopCategoriesWidget.swift
//  YalaWidgets
//
//  Widget showing top 3 expense categories.
//  Supports Medium size with progress bars.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct TopCategoriesWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Top Categorías" }
    static var description: IntentDescription { "Muestra tus categorías con más gastos" }

    @Parameter(title: "Período", default: .thisMonth)
    var period: WidgetPeriodOption
}

// MARK: - Timeline Entry

struct TopCategoriesEntry: TimelineEntry {
    let date: Date
    let categories: [WidgetCategory]
    let totalExpense: Double
    let currencyCode: String
    let currencyDisplayFormat: String
    let isPlaceholder: Bool
    let period: WidgetPeriodOption

    static var placeholder: TopCategoriesEntry {
        TopCategoriesEntry(
            date: Date(),
            categories: [
                WidgetCategory(id: "1", name: "Alimentación", iconName: "fork.knife", colorHex: "FF6B6B", amount: 1200, percentage: 37),
                WidgetCategory(id: "2", name: "Transporte", iconName: "car.fill", colorHex: "4ECDC4", amount: 800, percentage: 25),
                WidgetCategory(id: "3", name: "Entretenimiento", iconName: "gamecontroller.fill", colorHex: "45B7D1", amount: 600, percentage: 18)
            ],
            totalExpense: 3250,
            currencyCode: "PEN",
            currencyDisplayFormat: "symbol",
            isPlaceholder: true,
            period: .thisMonth
        )
    }
}

// MARK: - Timeline Provider

struct TopCategoriesWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TopCategoriesEntry
    typealias Intent = TopCategoriesWidgetIntent

    func placeholder(in context: Context) -> TopCategoriesEntry {
        .placeholder
    }

    func snapshot(for configuration: TopCategoriesWidgetIntent, in context: Context) async -> TopCategoriesEntry {
        if context.isPreview {
            return .placeholder
        }
        return createEntry(for: configuration)
    }

    func timeline(for configuration: TopCategoriesWidgetIntent, in context: Context) async -> Timeline<TopCategoriesEntry> {
        let entry = createEntry(for: configuration)

        // Refresh every 4 hours
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func createEntry(for configuration: TopCategoriesWidgetIntent) -> TopCategoriesEntry {
        let currency = WidgetDataService.getPreferredCurrency()
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()
        let period = configuration.period.toWidgetPeriod

        // Get summary for the period
        let summary = WidgetDataService.calculateSummary(for: period)

        return TopCategoriesEntry(
            date: Date(),
            categories: Array((summary?.topCategories ?? []).prefix(3)),
            totalExpense: summary?.totalExpense ?? 0,
            currencyCode: currency,
            currencyDisplayFormat: displayFormat,
            isPlaceholder: false,
            period: configuration.period
        )
    }
}

// MARK: - Widget View

struct TopCategoriesWidgetView: View {
    var entry: TopCategoriesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.md) {
            // Header
            HStack {
                WidgetHeader(
                    title: "Top Categorías",
                    subtitle: entry.period.toWidgetPeriod.displayName,
                    icon: "chart.bar.fill"
                )
                Spacer()
            }

            if entry.categories.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: WDS.Spacing.xs) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Sin gastos")
                            .font(WDS.Typography.body)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Category list
                ForEach(entry.categories, id: \.id) { category in
                    CategoryRow(
                        category: category,
                        currencyCode: entry.currencyCode,
                        displayFormat: entry.currencyDisplayFormat
                    )
                }

                Spacer(minLength: 0)
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(URL(string: "yala://statistics/categories"))
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: WidgetCategory
    let currencyCode: String
    let displayFormat: String

    var body: some View {
        HStack(spacing: WDS.Spacing.md) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: WDS.ListItem.iconSize, height: WDS.ListItem.iconSize)

                Image(systemName: category.iconName)
                    .font(.system(size: WDS.Icon.sm))
                    .foregroundColor(categoryColor)
            }

            // Name and progress
            VStack(alignment: .leading, spacing: WDS.Spacing.xxs) {
                HStack {
                    Text(category.name)
                        .font(WDS.Typography.label)
                        .lineLimit(1)

                    Spacer()

                    Text(formattedAmount)
                        .font(WDS.Typography.value)
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: WDS.Progress.heightCompact / 2)
                            .fill(Color.gray.opacity(0.15))

                        RoundedRectangle(cornerRadius: WDS.Progress.heightCompact / 2)
                            .fill(categoryColor)
                            .frame(width: geo.size.width * CGFloat(min(category.percentage, 100) / 100))
                    }
                }
                .frame(height: WDS.Progress.heightCompact)

                // Percentage
                Text("\(Int(category.percentage))%")
                    .font(WDS.Typography.tiny)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var categoryColor: Color {
        Color(hex: category.colorHex)
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: category.amount)) ?? "0"
        let currency = displayFormat == "symbol"
            ? CurrencySymbols.symbol(for: currencyCode)
            : currencyCode

        return "\(currency) \(formatted)"
    }
}

// MARK: - Widget Definition

struct TopCategoriesWidget: Widget {
    let kind: String = "TopCategoriesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TopCategoriesWidgetIntent.self,
            provider: TopCategoriesWidgetProvider()
        ) { entry in
            TopCategoriesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Top Categorías")
        .description("Tus categorías con más gastos")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    TopCategoriesWidget()
} timeline: {
    TopCategoriesEntry.placeholder
}

#Preview("Empty", as: .systemMedium) {
    TopCategoriesWidget()
} timeline: {
    TopCategoriesEntry(
        date: Date(),
        categories: [],
        totalExpense: 0,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        isPlaceholder: false,
        period: .thisMonth
    )
}
