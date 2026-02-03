//
//  SubcategoriesPieWidget.swift
//  YalaWidgets
//
//  Large widget showing subcategory distribution as a donut chart.
//  Displays up to 5 subcategories plus "Others".
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct SubcategoriesPieWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Subcategorías (Pie)" }
    static var description: IntentDescription { "Distribución de gastos por subcategoría" }

    @Parameter(title: "Período", default: .thisMonth)
    var period: WidgetPeriodOption
}

// MARK: - Timeline Entry

struct SubcategoriesPieEntry: TimelineEntry {
    let date: Date
    let subcategories: [WidgetSubcategory]
    let totalExpense: Double
    let currencyCode: String
    let currencyDisplayFormat: String
    let isPlaceholder: Bool
    let period: WidgetPeriodOption

    static var placeholder: SubcategoriesPieEntry {
        SubcategoriesPieEntry(
            date: Date(),
            subcategories: [
                WidgetSubcategory(id: "1", name: "Restaurantes", categoryName: "Alimentación", iconName: nil, colorHex: "6366F1", amount: 800, percentage: 25),
                WidgetSubcategory(id: "2", name: "Supermercado", categoryName: "Alimentación", iconName: nil, colorHex: "818CF8", amount: 400, percentage: 12),
                WidgetSubcategory(id: "3", name: "Taxi", categoryName: "Transporte", iconName: nil, colorHex: "FF0080", amount: 500, percentage: 15),
                WidgetSubcategory(id: "4", name: "Streaming", categoryName: "Entretenimiento", iconName: nil, colorHex: "00C2CB", amount: 350, percentage: 11),
                WidgetSubcategory(id: "5", name: "Otros", categoryName: "", iconName: nil, colorHex: "6B7280", amount: 1200, percentage: 37)
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

struct SubcategoriesPieWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = SubcategoriesPieEntry
    typealias Intent = SubcategoriesPieWidgetIntent

    func placeholder(in context: Context) -> SubcategoriesPieEntry {
        .placeholder
    }

    func snapshot(for configuration: SubcategoriesPieWidgetIntent, in context: Context) async -> SubcategoriesPieEntry {
        if context.isPreview {
            return .placeholder
        }
        return createEntry(for: configuration)
    }

    func timeline(for configuration: SubcategoriesPieWidgetIntent, in context: Context) async -> Timeline<SubcategoriesPieEntry> {
        let entry = createEntry(for: configuration)

        // Refresh every 4 hours
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func createEntry(for configuration: SubcategoriesPieWidgetIntent) -> SubcategoriesPieEntry {
        let currency = WidgetDataService.getPreferredCurrency()
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()
        let period = configuration.period.toWidgetPeriod

        // Get summary for the period
        let summary = WidgetDataService.calculateSummary(for: period)

        // Limit to 5 subcategories, group the rest as "Others"
        var subcategories = summary?.topSubcategories ?? []
        if subcategories.count > 5 {
            let top5 = Array(subcategories.prefix(5))
            let othersAmount = subcategories.dropFirst(5).reduce(0) { $0 + $1.amount }
            let totalExpense = summary?.totalExpense ?? 1
            let othersPercentage = totalExpense > 0 ? (othersAmount / totalExpense) * 100 : 0

            subcategories = top5 + [
                WidgetSubcategory(
                    id: "others",
                    name: "Otros",
                    categoryName: "",
                    iconName: nil,
                    colorHex: "6B7280",
                    amount: othersAmount,
                    percentage: othersPercentage
                )
            ]
        }

        return SubcategoriesPieEntry(
            date: Date(),
            subcategories: subcategories,
            totalExpense: summary?.totalExpense ?? 0,
            currencyCode: currency,
            currencyDisplayFormat: displayFormat,
            isPlaceholder: false,
            period: configuration.period
        )
    }
}

// MARK: - Widget View

struct SubcategoriesPieWidgetView: View {
    var entry: SubcategoriesPieEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.md) {
            // Header with total
            HStack {
                WidgetHeader(
                    title: "Subcategorías",
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

            if entry.subcategories.isEmpty {
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
                        segments: entry.subcategories.map { subcategory in
                            DonutSegment(
                                id: subcategory.id,
                                value: subcategory.amount,
                                color: Color(hex: subcategory.colorHex),
                                label: subcategory.name
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
                    ForEach(entry.subcategories, id: \.id) { subcategory in
                        SubcategoryPieLegendItem(
                            subcategory: subcategory,
                            currencyCode: entry.currencyCode,
                            displayFormat: entry.currencyDisplayFormat
                        )
                    }
                }
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "statistics/categories"))
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

struct SubcategoryPieLegendItem: View {
    let subcategory: WidgetSubcategory
    let currencyCode: String
    let displayFormat: String

    var body: some View {
        HStack(spacing: WDS.Spacing.xs) {
            Circle()
                .fill(Color(hex: subcategory.colorHex))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 0) {
                Text(subcategory.name)
                    .font(WDS.Typography.tiny)
                    .lineLimit(1)

                if !subcategory.categoryName.isEmpty {
                    Text(subcategory.categoryName)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(Int(subcategory.percentage))%")
                .font(WDS.Typography.tiny)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Widget Definition

struct SubcategoriesPieWidget: Widget {
    let kind: String = "SubcategoriesPieWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SubcategoriesPieWidgetIntent.self,
            provider: SubcategoriesPieWidgetProvider()
        ) { entry in
            SubcategoriesPieWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Subcategorías (Pie)")
        .description("Distribución de gastos por subcategoría")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Previews

#Preview("Large", as: .systemLarge) {
    SubcategoriesPieWidget()
} timeline: {
    SubcategoriesPieEntry.placeholder
}

#Preview("Empty", as: .systemLarge) {
    SubcategoriesPieWidget()
} timeline: {
    SubcategoriesPieEntry(
        date: Date(),
        subcategories: [],
        totalExpense: 0,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        isPlaceholder: false,
        period: .thisMonth
    )
}
