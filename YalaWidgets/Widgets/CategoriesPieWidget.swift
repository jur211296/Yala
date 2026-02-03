//
//  CategoriesPieWidget.swift
//  YalaWidgets
//
//  Large widget showing category distribution as a donut chart.
//  Displays up to 5 categories plus "Others".
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct CategoriesPieWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Categorías (Pie)" }
    static var description: IntentDescription { "Distribución de gastos por categoría" }

    @Parameter(title: "Período", default: .thisMonth)
    var period: WidgetPeriodOption
}

// MARK: - Timeline Entry

struct CategoriesPieEntry: TimelineEntry {
    let date: Date
    let categories: [WidgetCategory]
    let totalExpense: Double
    let currencyCode: String
    let currencyDisplayFormat: String
    let isPlaceholder: Bool
    let period: WidgetPeriodOption

    static var placeholder: CategoriesPieEntry {
        CategoriesPieEntry(
            date: Date(),
            categories: [
                WidgetCategory(id: "1", name: "Alimentación", iconName: "fork.knife", colorHex: "6366F1", amount: 1200, percentage: 37),
                WidgetCategory(id: "2", name: "Transporte", iconName: "car.fill", colorHex: "FF0080", amount: 800, percentage: 25),
                WidgetCategory(id: "3", name: "Servicios", iconName: "bolt.fill", colorHex: "00C2CB", amount: 600, percentage: 18),
                WidgetCategory(id: "4", name: "Entretenimiento", iconName: "gamecontroller.fill", colorHex: "F59E0B", amount: 400, percentage: 12),
                WidgetCategory(id: "5", name: "Otros", iconName: "ellipsis.circle", colorHex: "6B7280", amount: 250, percentage: 8)
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

struct CategoriesPieWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = CategoriesPieEntry
    typealias Intent = CategoriesPieWidgetIntent

    func placeholder(in context: Context) -> CategoriesPieEntry {
        .placeholder
    }

    func snapshot(for configuration: CategoriesPieWidgetIntent, in context: Context) async -> CategoriesPieEntry {
        if context.isPreview {
            return .placeholder
        }
        return createEntry(for: configuration)
    }

    func timeline(for configuration: CategoriesPieWidgetIntent, in context: Context) async -> Timeline<CategoriesPieEntry> {
        let entry = createEntry(for: configuration)

        // Refresh every 4 hours
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func createEntry(for configuration: CategoriesPieWidgetIntent) -> CategoriesPieEntry {
        let currency = WidgetDataService.getPreferredCurrency()
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()
        let period = configuration.period.toWidgetPeriod

        // Get summary for the period
        let summary = WidgetDataService.calculateSummary(for: period)

        // Limit to 5 categories, group the rest as "Others"
        var categories = summary?.topCategories ?? []
        if categories.count > 5 {
            let top5 = Array(categories.prefix(5))
            let othersAmount = categories.dropFirst(5).reduce(0) { $0 + $1.amount }
            let totalExpense = summary?.totalExpense ?? 1
            let othersPercentage = totalExpense > 0 ? (othersAmount / totalExpense) * 100 : 0

            categories = top5 + [
                WidgetCategory(
                    id: "others",
                    name: "Otros",
                    iconName: "ellipsis.circle",
                    colorHex: "6B7280",
                    amount: othersAmount,
                    percentage: othersPercentage
                )
            ]
        }

        return CategoriesPieEntry(
            date: Date(),
            categories: categories,
            totalExpense: summary?.totalExpense ?? 0,
            currencyCode: currency,
            currencyDisplayFormat: displayFormat,
            isPlaceholder: false,
            period: configuration.period
        )
    }
}

// MARK: - Widget View

struct CategoriesPieWidgetView: View {
    var entry: CategoriesPieEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.md) {
            // Header with total
            HStack {
                WidgetHeader(
                    title: "Categorías",
                    subtitle: entry.period.toWidgetPeriod.displayName,
                    icon: "chart.pie.fill"
                )

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text("Total")
                        .font(WDS.Typography.tiny)
                        .foregroundStyle(.secondary)
                    Text(formattedTotal)
                        .font(WDS.Typography.kpiSmall)
                        .foregroundColor(WidgetColors.expense)
                }
            }

            if entry.categories.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: WDS.Spacing.xs) {
                        Image(systemName: "chart.pie")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("Sin gastos")
                            .font(WDS.Typography.body)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Donut chart
                HStack {
                    Spacer()
                    MiniDonutChart(
                        segments: entry.categories.map { category in
                            DonutSegment(
                                id: category.id,
                                value: category.amount,
                                color: Color(hex: category.colorHex),
                                label: category.name
                            )
                        },
                        innerRadiusRatio: 0.55
                    )
                    .frame(width: 100, height: 100)
                    Spacer()
                }

                Spacer(minLength: WDS.Spacing.sm)

                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: WDS.Spacing.sm) {
                    ForEach(entry.categories, id: \.id) { category in
                        PieLegendItem(
                            category: category,
                            currencyCode: entry.currencyCode,
                            displayFormat: entry.currencyDisplayFormat
                        )
                    }
                }
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(URL(string: "yala://statistics/categories"))
    }

    private var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: entry.totalExpense)) ?? "0"
        let currency = entry.currencyDisplayFormat == "symbol"
            ? CurrencySymbols.symbol(for: entry.currencyCode)
            : entry.currencyCode

        return "\(currency) \(formatted)"
    }
}

// MARK: - Legend Item

struct PieLegendItem: View {
    let category: WidgetCategory
    let currencyCode: String
    let displayFormat: String

    var body: some View {
        HStack(spacing: WDS.Spacing.xs) {
            Circle()
                .fill(Color(hex: category.colorHex))
                .frame(width: 8, height: 8)

            Text(category.name)
                .font(WDS.Typography.tiny)
                .lineLimit(1)

            Spacer()

            Text("\(Int(category.percentage))%")
                .font(WDS.Typography.tiny)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget Definition

struct CategoriesPieWidget: Widget {
    let kind: String = "CategoriesPieWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CategoriesPieWidgetIntent.self,
            provider: CategoriesPieWidgetProvider()
        ) { entry in
            CategoriesPieWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Categorías (Pie)")
        .description("Distribución de gastos por categoría")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Previews

#Preview("Large", as: .systemLarge) {
    CategoriesPieWidget()
} timeline: {
    CategoriesPieEntry.placeholder
}

#Preview("Empty", as: .systemLarge) {
    CategoriesPieWidget()
} timeline: {
    CategoriesPieEntry(
        date: Date(),
        categories: [],
        totalExpense: 0,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        isPlaceholder: false,
        period: .thisMonth
    )
}
