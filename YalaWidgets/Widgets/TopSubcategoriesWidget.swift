//
//  TopSubcategoriesWidget.swift
//  YalaWidgets
//
//  Mediano: las tres subcategorías que más gastan, en ranking con barras.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct TopSubcategoriesWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.topSubcategories.title" }
    static var description: IntentDescription { "widget.intent.topSubcategories.desc" }

    @Parameter(title: "widget.period.type", default: .sameAsApp)
    var period: WidgetPeriodOption

}

// MARK: - Timeline Entry

struct TopSubcategoriesEntry: TimelineEntry {
    let date: Date
    let subcategories: [WidgetSubcategory]
    let totalExpense: Double
    let currencyCode: String
    let currencyDisplayFormat: String
    let isPlaceholder: Bool
    let period: WidgetPeriodOption

    static var placeholder: TopSubcategoriesEntry {
        TopSubcategoriesEntry(
            date: Date(),
            subcategories: [
                WidgetSubcategory(id: "1", name: "Restaurantes y Cafés", categoryName: "Alimentación", iconName: "fork.knife", colorHex: "FF6B6B", amount: 800, percentage: 25),
                WidgetSubcategory(id: "2", name: "Taxi y Transporte", categoryName: "Transporte", iconName: "car.fill", colorHex: "4ECDC4", amount: 500, percentage: 15),
                WidgetSubcategory(id: "3", name: "Streaming y Suscripciones", categoryName: "Entretenimiento", iconName: "play.tv", colorHex: "45B7D1", amount: 350, percentage: 11)
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

struct TopSubcategoriesWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TopSubcategoriesEntry
    typealias Intent = TopSubcategoriesWidgetIntent

    func placeholder(in context: Context) -> TopSubcategoriesEntry {
        .placeholder
    }

    func snapshot(for configuration: TopSubcategoriesWidgetIntent, in context: Context) async -> TopSubcategoriesEntry {
        if context.isPreview {
            return .placeholder
        }
        return createEntry(for: configuration)
    }

    func timeline(for configuration: TopSubcategoriesWidgetIntent, in context: Context) async -> Timeline<TopSubcategoriesEntry> {
        let entry = createEntry(for: configuration)
        // La política común (medianoche o +4 h): a medianoche «Este mes» puede pasar a ser otro.
        return Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date)))
    }

    private func createEntry(for configuration: TopSubcategoriesWidgetIntent) -> TopSubcategoriesEntry {
        let currency = WidgetDataService.getPreferredCurrency()
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()
        let period = configuration.period.toWidgetPeriod

        // Get summary for the period
        let summary = WidgetDataService.calculateSummary(for: period)

        return TopSubcategoriesEntry(
            date: Date(),
            subcategories: Array((summary?.topSubcategories ?? []).prefix(3)),
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
struct TopSubcategoriesWidgetView: View {
    var entry: TopSubcategoriesEntry

    private var items: [WidgetBreakdownItem] {
        entry.subcategories.map {
            WidgetBreakdownItem(id: $0.id, name: $0.name, iconName: $0.iconName ?? "tag.fill", colorHex: $0.colorHex,
                                amount: $0.amount, percentage: $0.percentage)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.xs) {
            WidgetBreakdownHeader(
                title: String(localized: "widget.ui.topSubcategories", bundle: .main),
                shortTitle: String(localized: "widget.ui.subcategories", bundle: .main),
                systemImage: "list.bullet.indent",
                period: entry.period.toWidgetPeriod.localizedDisplayName
            )

            if entry.subcategories.isEmpty {
                WidgetBreakdownEmpty()
            } else {
                WidgetRankingList(items: items, currencyCode: entry.currencyCode, displayFormat: entry.currencyDisplayFormat)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: WidgetDeepLink.subcategories))
    }
}

// MARK: - Widget Definition

struct TopSubcategoriesWidget: Widget {
    let kind: String = "TopSubcategoriesWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: TopSubcategoriesWidgetIntent.self,
            provider: TopSubcategoriesWidgetProvider()
        ) { entry in
            TopSubcategoriesWidgetView(entry: entry)
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(WidgetColors.cardBackground, for: .widget)
        }
        .configurationDisplayName("widget.gallery.topSubcategories")
        .description("widget.gallery.topSubcategories.desc")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    TopSubcategoriesWidget()
} timeline: {
    TopSubcategoriesEntry.placeholder
}

#Preview("Empty", as: .systemMedium) {
    TopSubcategoriesWidget()
} timeline: {
    TopSubcategoriesEntry(
        date: Date(),
        subcategories: [],
        totalExpense: 0,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        isPlaceholder: false,
        period: .thisMonth
    )
}
