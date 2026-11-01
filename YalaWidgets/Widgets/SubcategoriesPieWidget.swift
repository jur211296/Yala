//
//  SubcategoriesPieWidget.swift
//  YalaWidgets
//
//  Grande: el gasto del período por subcategoría en un aro con el total en el centro y una leyenda de hasta cinco
//  filas (las cuatro primeras y «Otros» cuando hay más).
//

import WidgetKit
import SwiftUI
import AppIntents

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
    /// Marca «≈» del TOTAL. Las tajadas del pie no la llevan: son subconjuntos del gasto y su
    /// calculador no acumula calidad de conversión (`fx-category-totals-unmarked`).
    var expenseIsApproximate: Bool = false
    /// Hora de la foto de la app, para el pie «Actualizado ayer» (`WidgetFreshnessNote`).
    var lastUpdated: Date? = nil

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
        // La política común (medianoche o +4 h): a medianoche «Este mes» puede pasar a ser otro.
        return Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date)))
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
                    name: String(localized: "widget.ui.others", bundle: .main),
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
            period: configuration.period,
            expenseIsApproximate: summary?.expenseIsApproximate ?? false,
            lastUpdated: WidgetDataService.getLastUpdated()
        )
    }
}

// MARK: - Widget View

/// El aro con el total en el centro y la leyenda con importe y porcentaje (tanda 3 del rediseño 2.2; las piezas, en
/// `WidgetCategoryBreakdown.swift`). Pie de frescura si la foto no es de hoy, como los grandes de la tanda 1.
struct SubcategoriesPieWidgetView: View {
    var entry: SubcategoriesPieEntry

    private var items: [WidgetBreakdownItem] {
        entry.subcategories.map {
            WidgetBreakdownItem(id: $0.id, name: $0.name, iconName: $0.iconName ?? "tag.fill", colorHex: $0.colorHex,
                                amount: $0.amount, percentage: $0.percentage)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
            WidgetCardHeader(
                title: String(localized: "widget.ui.subcategories", bundle: .main),
                systemImage: "chart.pie.fill",
                tint: WidgetColors.electricIndigo
            ) {
                WidgetHeaderDetail(text: entry.period.toWidgetPeriod.localizedDisplayName)
            }

            if entry.subcategories.isEmpty {
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
        .widgetURL(WidgetURLHelper.url(for: WidgetDeepLink.subcategories))
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
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(WidgetColors.cardBackground, for: .widget)
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
