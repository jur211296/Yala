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
import Charts

// MARK: - Configuration Intent

struct CategoriesPieWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.categoriesPie.title" }
    static var description: IntentDescription { "widget.intent.categoriesPie.desc" }

    @Parameter(title: "widget.period.type", default: .sameAsApp)
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
                WidgetCategory(id: "1", name: "Alimentación", iconName: "fork.knife", colorHex: "6366F1", amount: 1200, percentage: 30),
                WidgetCategory(id: "2", name: "Transporte", iconName: "car.fill", colorHex: "FF0080", amount: 800, percentage: 20),
                WidgetCategory(id: "3", name: "Servicios", iconName: "bolt.fill", colorHex: "00C2CB", amount: 600, percentage: 15),
                WidgetCategory(id: "4", name: "Entretenimiento", iconName: "gamecontroller.fill", colorHex: "F59E0B", amount: 400, percentage: 10),
                WidgetCategory(id: "5", name: "Salud", iconName: "heart.fill", colorHex: "EF4444", amount: 350, percentage: 9),
                WidgetCategory(id: "6", name: "Educación", iconName: "book.fill", colorHex: "8B5CF6", amount: 250, percentage: 6),
                WidgetCategory(id: "7", name: "Hogar", iconName: "house.fill", colorHex: "10B981", amount: 200, percentage: 5),
                WidgetCategory(id: "8", name: "Otros", iconName: "ellipsis.circle", colorHex: "6B7280", amount: 200, percentage: 5)
            ],
            totalExpense: 4000,
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

        // Limit to 12 categories (matching PanelView), group the rest as "Others"
        var categories = summary?.topCategories ?? []
        if categories.count > 12 {
            let top12 = Array(categories.prefix(12))
            let othersAmount = categories.dropFirst(12).reduce(0) { $0 + $1.amount }
            let totalExpense = summary?.totalExpense ?? 1
            let othersPercentage = totalExpense > 0 ? (othersAmount / totalExpense) * 100 : 0

            categories = top12 + [
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
                    title: String(localized: "widget.ui.categories", bundle: .main),
                    subtitle: entry.period.toWidgetPeriod.localizedDisplayName,
                    icon: "chart.pie.fill"
                )

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text("widget.ui.total", bundle: .main)
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
                        Text("widget.ui.noExpenses", bundle: .main)
                            .font(WDS.Typography.body)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Pie chart with bubbles (full width, no legend)
                WidgetSectorChart(
                    segments: entry.categories.map { category in
                        WidgetSectorSegment(
                            id: category.id,
                            name: category.name,
                            iconName: category.iconName,
                            amount: category.amount,
                            percentage: category.percentage,
                            colorHex: category.colorHex
                        )
                    },
                    innerRadiusRatio: 0.50,
                    showBubbles: true
                )
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
                .containerBackground(WidgetColors.yalaCard, for: .widget)
        }
        .configurationDisplayName("widget.gallery.categoriesPie")
        .description("widget.gallery.categoriesPie.desc")
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
