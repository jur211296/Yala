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
import Charts

// MARK: - Configuration Intent

struct SubcategoriesPieWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.subcategoriesPie.title" }
    static var description: IntentDescription { "widget.intent.subcategoriesPie.desc" }

    @Parameter(title: "widget.period.type", default: .sameAsApp)
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
                WidgetSubcategory(id: "1", name: "Restaurantes", categoryName: "Alimentación", iconName: "fork.knife", colorHex: "6366F1", amount: 800, percentage: 20),
                WidgetSubcategory(id: "2", name: "Supermercado", categoryName: "Alimentación", iconName: "cart.fill", colorHex: "818CF8", amount: 600, percentage: 15),
                WidgetSubcategory(id: "3", name: "Taxi", categoryName: "Transporte", iconName: "car.fill", colorHex: "FF0080", amount: 500, percentage: 13),
                WidgetSubcategory(id: "4", name: "Streaming", categoryName: "Entretenimiento", iconName: "play.tv.fill", colorHex: "00C2CB", amount: 350, percentage: 9),
                WidgetSubcategory(id: "5", name: "Electricidad", categoryName: "Servicios", iconName: "bolt.fill", colorHex: "F59E0B", amount: 400, percentage: 10),
                WidgetSubcategory(id: "6", name: "Gasolina", categoryName: "Transporte", iconName: "fuelpump.fill", colorHex: "EF4444", amount: 350, percentage: 9),
                WidgetSubcategory(id: "7", name: "Gimnasio", categoryName: "Salud", iconName: "dumbbell.fill", colorHex: "10B981", amount: 250, percentage: 6),
                WidgetSubcategory(id: "8", name: "Otros", categoryName: "", iconName: "ellipsis.circle", colorHex: "6B7280", amount: 750, percentage: 18)
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

        // Limit to 12 subcategories (matching PanelView), group the rest as "Others"
        var subcategories = summary?.topSubcategories ?? []
        if subcategories.count > 12 {
            let top12 = Array(subcategories.prefix(12))
            let othersAmount = subcategories.dropFirst(12).reduce(0) { $0 + $1.amount }
            let totalExpense = summary?.totalExpense ?? 1
            let othersPercentage = totalExpense > 0 ? (othersAmount / totalExpense) * 100 : 0

            subcategories = top12 + [
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
                    title: String(localized: "widget.ui.subcategories", bundle: .main),
                    subtitle: entry.period.toWidgetPeriod.localizedDisplayName,
                    icon: "chart.pie.fill"
                )

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text("widget.ui.total", bundle: .main)
                        .font(WDS.Typography.tiny)
                        .foregroundStyle(.secondary)
                    WidgetAmountText(
                        value: entry.totalExpense,
                        currencyCode: entry.currencyCode,
                        displayFormat: entry.currencyDisplayFormat,
                        font: WDS.Typography.kpiSmall,
                        secondaryFont: WDS.Typography.kpiSmallSecondary,
                        tint: .color(WidgetColors.expense)
                    )
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
                    segments: entry.subcategories.map { subcategory in
                        WidgetSectorSegment(
                            id: subcategory.id,
                            name: subcategory.name,
                            iconName: subcategory.iconName,
                            amount: subcategory.amount,
                            percentage: subcategory.percentage,
                            colorHex: subcategory.colorHex
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
                .containerBackground(Color(.secondarySystemGroupedBackground), for: .widget)
        }
        .configurationDisplayName("widget.gallery.subcategoriesPie")
        .description("widget.gallery.subcategoriesPie.desc")
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
