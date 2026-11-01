//
//  TopCategoriesWidget.swift
//  YalaWidgets
//
//  Mediano: las tres categorías que más gastan, en ranking con barras.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct TopCategoriesWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.topCategories.title" }
    static var description: IntentDescription { "widget.intent.topCategories.desc" }

    @Parameter(title: "widget.period.type", default: .sameAsApp)
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
                WidgetCategory(id: "1", name: "Alimentación y Bebidas", iconName: "fork.knife", colorHex: "FF6B6B", amount: 1200, percentage: 37),
                WidgetCategory(id: "2", name: "Transporte Público", iconName: "car.fill", colorHex: "4ECDC4", amount: 800, percentage: 25),
                WidgetCategory(id: "3", name: "Entretenimiento y Ocio", iconName: "gamecontroller.fill", colorHex: "45B7D1", amount: 600, percentage: 18)
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
        // La política común (medianoche o +4 h): a medianoche «Este mes» puede pasar a ser otro.
        return Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date)))
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

/// Las tres que más gastan, en ranking: insignia sólida, nombre, importe y porcentaje, y la barra de su parte del gasto
/// (tanda 3 del rediseño 2.2; las piezas, en `WidgetCategoryBreakdown.swift`).
struct TopCategoriesWidgetView: View {
    var entry: TopCategoriesEntry

    private var items: [WidgetBreakdownItem] {
        entry.categories.map {
            WidgetBreakdownItem(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex,
                                amount: $0.amount, percentage: $0.percentage)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.xs) {
            WidgetBreakdownHeader(
                title: String(localized: "widget.ui.topCategories", bundle: .main),
                shortTitle: String(localized: "widget.ui.categories", bundle: .main),
                systemImage: "chart.bar.fill",
                period: entry.period.toWidgetPeriod.localizedDisplayName
            )

            if entry.categories.isEmpty {
                WidgetBreakdownEmpty()
            } else {
                WidgetRankingList(items: items, currencyCode: entry.currencyCode, displayFormat: entry.currencyDisplayFormat)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: "statistics/categories"))
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
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(WidgetColors.cardBackground, for: .widget)
        }
        .configurationDisplayName("widget.gallery.topCategories")
        .description("widget.gallery.topCategories.desc")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    TopCategoriesWidget()
} timeline: {
    TopCategoriesEntry.placeholder
}



