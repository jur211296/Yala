//
//  TopSubcategoriesWidget.swift
//  YalaWidgets
//
//  Widget showing top 3 expense subcategories.
//  Supports Medium size with progress bars.
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

        // Refresh every 4 hours
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()

        return Timeline(entries: [entry], policy: .after(refreshDate))
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

struct TopSubcategoriesWidgetView: View {
    var entry: TopSubcategoriesEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.sm) {
            // Header
            HStack {
                WidgetHeader(
                    title: String(localized: "widget.ui.topSubcategories", bundle: .main),
                    subtitle: entry.period.toWidgetPeriod.localizedDisplayName,
                    icon: "list.bullet.indent",
                    inline: true
                )
                Spacer()
            }

            if entry.subcategories.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: WDS.Spacing.xs) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("widget.ui.noExpenses", bundle: .main)
                            .font(WDS.Typography.body)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                // Subcategory list
                ForEach(entry.subcategories, id: \.id) { subcategory in
                    SubcategoryRow(
                        subcategory: subcategory,
                        currencyCode: entry.currencyCode,
                        displayFormat: entry.currencyDisplayFormat
                    )
                }

                Spacer(minLength: 0)
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "statistics/categories"))
    }
}

// MARK: - Subcategory Row

struct SubcategoryRow: View {
    let subcategory: WidgetSubcategory
    let currencyCode: String
    let displayFormat: String

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.xxs) {
            // Single line: Icon + Name + Amount + %
            HStack(spacing: WDS.Spacing.sm) {
                // Icon badge (same style as categories)
                ZStack {
                    Circle()
                        .fill(subcategoryColor.opacity(0.2))
                        .frame(width: WDS.ListItem.iconSizeCompact,
                               height: WDS.ListItem.iconSizeCompact)

                    Image(systemName: subcategory.iconName ?? "tag.fill")
                        .font(.system(size: WDS.Icon.sm))
                        .foregroundColor(subcategoryColor)
                        .widgetAccentable()
                }

                // Only subcategory name (no parent category)
                Text(subcategory.name)
                    .font(WDS.Typography.label)
                    .lineLimit(1)

                Spacer()

                // Amount
                Text(formattedAmount)
                    .font(WDS.Typography.value)
                    .foregroundStyle(.secondary)

                // Percentage inline
                Text("\(Int(subcategory.percentage))%")
                    .font(WDS.Typography.labelSmall)
                    .foregroundStyle(subcategoryColor)
                    .frame(width: WDS.ListItem.percentageWidth, alignment: .trailing)
                    .widgetAccentable()
            }

            // Progress bar aligned with text
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: WDS.Progress.heightCompact / 2)
                        .fill(Color.gray.opacity(0.15))

                    RoundedRectangle(cornerRadius: WDS.Progress.heightCompact / 2)
                        .fill(subcategoryColor)
                        .frame(width: geo.size.width * CGFloat(min(subcategory.percentage, 100) / 100))
                        .widgetAccentable()
                }
            }
            .frame(height: WDS.Progress.heightCompact)
            .padding(.leading, WDS.ListItem.iconSizeCompact + WDS.Spacing.sm)
        }
    }

    private var subcategoryColor: Color {
        Color(hex: subcategory.colorHex)
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let formatted = formatter.string(from: NSNumber(value: subcategory.amount)) ?? "0"
        let currency = displayFormat == "symbol"
            ? CurrencySymbols.symbol(for: currencyCode)
            : currencyCode

        return "\(currency) \(formatted)"
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
                .containerBackground(WidgetColors.yalaCard, for: .widget)
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
