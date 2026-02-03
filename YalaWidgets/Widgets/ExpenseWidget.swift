//
//  ExpenseWidget.swift
//  YalaWidgets
//
//  Widget showing total expenses for a period.
//  Supports Small (KPI only) and Medium (KPI + trend) sizes.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct ExpenseWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Gastos" }
    static var description: IntentDescription { "Muestra tus gastos totales" }

    @Parameter(title: "Período", default: .thisMonth)
    var period: WidgetPeriodOption
}

// MARK: - Timeline Entry

struct ExpenseEntry: TimelineEntry {
    let date: Date
    let totalExpense: Double
    let currencyCode: String
    let currencyDisplayFormat: String
    let trendData: [WidgetTrendPoint]
    let isPlaceholder: Bool
    let period: WidgetPeriodOption

    static var placeholder: ExpenseEntry {
        ExpenseEntry(
            date: Date(),
            totalExpense: 3250.00,
            currencyCode: "PEN",
            currencyDisplayFormat: "symbol",
            trendData: [],
            isPlaceholder: true,
            period: .thisMonth
        )
    }
}

// MARK: - Timeline Provider

struct ExpenseWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = ExpenseEntry
    typealias Intent = ExpenseWidgetIntent

    func placeholder(in context: Context) -> ExpenseEntry {
        .placeholder
    }

    func snapshot(for configuration: ExpenseWidgetIntent, in context: Context) async -> ExpenseEntry {
        if context.isPreview {
            return .placeholder
        }
        return createEntry(for: configuration)
    }

    func timeline(for configuration: ExpenseWidgetIntent, in context: Context) async -> Timeline<ExpenseEntry> {
        let entry = createEntry(for: configuration)

        // Refresh every 4 hours
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func createEntry(for configuration: ExpenseWidgetIntent) -> ExpenseEntry {
        let currency = WidgetDataService.getPreferredCurrency()
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()
        let period = configuration.period.toWidgetPeriod

        // Get summary for the period
        let summary = WidgetDataService.calculateSummary(for: period)
        let totalExpense = summary?.totalExpense ?? 0

        // Get trend data for the selected period
        let trendData = WidgetDataService.getTrendData(for: period)

        return ExpenseEntry(
            date: Date(),
            totalExpense: totalExpense,
            currencyCode: currency,
            currencyDisplayFormat: displayFormat,
            trendData: trendData,
            isPlaceholder: false,
            period: configuration.period
        )
    }
}

// MARK: - Widget Views

struct ExpenseWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: ExpenseEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallExpenseView(entry: entry)
        case .systemMedium:
            MediumExpenseView(entry: entry)
        default:
            SmallExpenseView(entry: entry)
        }
    }
}

struct SmallExpenseView: View {
    let entry: ExpenseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.xs) {
            WidgetHeader(
                title: "Gastos",
                subtitle: entry.period.toWidgetPeriod.displayName,
                icon: "arrow.down.circle.fill"
            )

            Spacer()

            WidgetKPI(
                amount: entry.totalExpense,
                currencyCode: entry.currencyCode,
                displayFormat: entry.currencyDisplayFormat,
                color: WidgetColors.expense,
                size: .large
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WDS.Spacing.xl)
        .clipped()
        .widgetURL(URL(string: "yala://statistics/records"))
    }
}

struct MediumExpenseView: View {
    let entry: ExpenseEntry

    var body: some View {
        HStack(spacing: WDS.Spacing.xl) {
            // Left: Expense info
            VStack(alignment: .leading, spacing: WDS.Spacing.xs) {
                WidgetHeader(
                    title: "Gastos",
                    subtitle: entry.period.toWidgetPeriod.displayName,
                    icon: "arrow.down.circle.fill"
                )

                Spacer()

                WidgetKPI(
                    amount: entry.totalExpense,
                    currencyCode: entry.currencyCode,
                    displayFormat: entry.currencyDisplayFormat,
                    color: WidgetColors.expense,
                    size: .medium
                )
            }
            .frame(maxWidth: 140, alignment: .leading)

            // Right: Trend chart (expense trend)
            VStack {
                if entry.trendData.count >= 2 {
                    MiniTrendChart(
                        dataPoints: entry.trendData,
                        lineColor: WidgetColors.trendExpense,
                        fillColor: WidgetColors.trendExpense.opacity(0.2)
                    )
                } else {
                    VStack(spacing: WDS.Spacing.xs) {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Sin datos")
                            .font(WDS.Typography.tiny)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(WDS.Spacing.xl)
        .clipped()
        .widgetURL(URL(string: "yala://statistics/records"))
    }
}

// MARK: - Widget Definition

struct ExpenseWidget: Widget {
    let kind: String = "ExpenseWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ExpenseWidgetIntent.self,
            provider: ExpenseWidgetProvider()
        ) { entry in
            ExpenseWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Gastos")
        .description("Tus gastos totales del período")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    ExpenseWidget()
} timeline: {
    ExpenseEntry(
        date: Date(),
        totalExpense: 3250.00,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        trendData: [],
        isPlaceholder: false,
        period: .thisMonth
    )
}

#Preview("Medium", as: .systemMedium) {
    ExpenseWidget()
} timeline: {
    ExpenseEntry(
        date: Date(),
        totalExpense: 3250.00,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        trendData: [
            WidgetTrendPoint(date: Date().addingTimeInterval(-6 * 86400), balance: 500),
            WidgetTrendPoint(date: Date().addingTimeInterval(-5 * 86400), balance: 1200),
            WidgetTrendPoint(date: Date().addingTimeInterval(-4 * 86400), balance: 1800),
            WidgetTrendPoint(date: Date().addingTimeInterval(-3 * 86400), balance: 2100),
            WidgetTrendPoint(date: Date().addingTimeInterval(-2 * 86400), balance: 2600),
            WidgetTrendPoint(date: Date().addingTimeInterval(-1 * 86400), balance: 2900),
            WidgetTrendPoint(date: Date(), balance: 3250),
        ],
        isPlaceholder: false,
        period: .thisMonth
    )
}
