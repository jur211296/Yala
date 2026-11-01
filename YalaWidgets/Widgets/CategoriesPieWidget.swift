//
//  CategoriesPieWidget.swift
//  YalaWidgets
//
//  Grande: el gasto del período por categoría en un aro con el total en el centro y una leyenda de hasta cinco
//  filas (las cuatro primeras y «Otros» cuando hay más).
//

import WidgetKit
import SwiftUI
import AppIntents

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
    /// Marca «≈» del TOTAL. Las tajadas del pie no la llevan: son subconjuntos del gasto y su
    /// calculador no acumula calidad de conversión (`fx-category-totals-unmarked`).
    var expenseIsApproximate: Bool = false
    /// Hora de la foto de la app, para el pie «Actualizado ayer» (`WidgetFreshnessNote`).
    var lastUpdated: Date? = nil

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
        // La política común (medianoche o +4 h): a medianoche «Este mes» puede pasar a ser otro.
        return Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date)))
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
                    name: String(localized: "widget.ui.others", bundle: .main),
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
            period: configuration.period,
            expenseIsApproximate: summary?.expenseIsApproximate ?? false,
            lastUpdated: WidgetDataService.getLastUpdated()
        )
    }
}

// MARK: - Widget View

/// El aro con el total en el centro y la leyenda con importe y porcentaje (tanda 3 del rediseño 2.2; las piezas, en
/// `WidgetCategoryBreakdown.swift`). Pie de frescura si la foto no es de hoy, como los grandes de la tanda 1.
struct CategoriesPieWidgetView: View {
    var entry: CategoriesPieEntry

    private var items: [WidgetBreakdownItem] {
        entry.categories.map {
            WidgetBreakdownItem(id: $0.id, name: $0.name, iconName: $0.iconName, colorHex: $0.colorHex,
                                amount: $0.amount, percentage: $0.percentage)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
            WidgetCardHeader(
                title: String(localized: "widget.ui.categories", bundle: .main),
                systemImage: "chart.pie.fill",
                tint: WidgetColors.electricIndigo
            ) {
                WidgetHeaderDetail(text: entry.period.toWidgetPeriod.localizedDisplayName)
            }

            if entry.categories.isEmpty {
                WidgetBreakdownEmpty()
            } else {
                WidgetPieBreakdown(
                    items: items,
                    total: entry.totalExpense,
                    isEstimate: entry.expenseIsApproximate,
                    currencyCode: entry.currencyCode,
                    displayFormat: entry.currencyDisplayFormat
                )
                .layoutPriority(1)
                Spacer(minLength: WidgetDS.Spacing.none)
                WidgetFreshnessNote(lastUpdated: entry.lastUpdated, now: entry.date)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: "statistics/categories"))
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
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(WidgetColors.cardBackground, for: .widget)
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
