//
//  BalanceWidget.swift
//  YalaWidgets
//
//  Widget showing total balance with optional trend chart.
//  Supports Small (KPI only) and Medium (KPI + chart) sizes.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct BalanceWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Balance" }
    static var description: IntentDescription { "Muestra tu balance total" }

    @Parameter(title: "Periodo de tendencia", default: .week)
    var trendPeriod: TrendPeriod
}

enum TrendPeriod: String, AppEnum {
    case week = "week"
    case month = "month"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Periodo"
    }

    static var caseDisplayRepresentations: [TrendPeriod: DisplayRepresentation] {
        [
            .week: "Última semana",
            .month: "Último mes"
        ]
    }
}

// MARK: - Timeline Entry

struct BalanceEntry: TimelineEntry {
    let date: Date
    let balance: Double
    let currencyCode: String
    let trendData: [WidgetTrendPoint]
    let isPlaceholder: Bool
    let trendPeriod: TrendPeriod

    static var placeholder: BalanceEntry {
        BalanceEntry(
            date: Date(),
            balance: 12500.00,
            currencyCode: "PEN",
            trendData: [],
            isPlaceholder: true,
            trendPeriod: .week
        )
    }
}

// MARK: - Timeline Provider

struct BalanceWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = BalanceEntry
    typealias Intent = BalanceWidgetIntent

    func placeholder(in context: Context) -> BalanceEntry {
        .placeholder
    }

    func snapshot(for configuration: BalanceWidgetIntent, in context: Context) async -> BalanceEntry {
        if context.isPreview {
            return .placeholder
        }
        return createEntry(for: configuration)
    }

    func timeline(for configuration: BalanceWidgetIntent, in context: Context) async -> Timeline<BalanceEntry> {
        let entry = createEntry(for: configuration)

        // Refresh every 4 hours
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func createEntry(for configuration: BalanceWidgetIntent) -> BalanceEntry {
        let balance = WidgetDataService.getTotalBalance()
        let currency = WidgetDataService.getPreferredCurrency()
        var trendData = WidgetDataService.getTrendData()

        // Filter trend data based on period
        if configuration.trendPeriod == .week {
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            trendData = trendData.filter { $0.date >= weekAgo }
        }

        return BalanceEntry(
            date: Date(),
            balance: balance,
            currencyCode: currency,
            trendData: trendData,
            isPlaceholder: false,
            trendPeriod: configuration.trendPeriod
        )
    }
}

// MARK: - Widget Views

struct BalanceWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: BalanceEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallBalanceView(entry: entry)
        case .systemMedium:
            MediumBalanceView(entry: entry)
        default:
            SmallBalanceView(entry: entry)
        }
    }
}

struct SmallBalanceView: View {
    let entry: BalanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Balance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formattedBalance)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundColor(entry.balance >= 0 ? .primary : .red)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(entry.currencyCode)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .widgetURL(URL(string: "yala://panel"))
    }

    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        let absBalance = abs(entry.balance)
        let formatted = formatter.string(from: NSNumber(value: absBalance)) ?? "0.00"
        return entry.balance >= 0 ? formatted : "-\(formatted)"
    }
}

struct MediumBalanceView: View {
    let entry: BalanceEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Balance info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(formattedBalance)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(entry.balance >= 0 ? .primary : .red)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(entry.currencyCode)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(periodLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: 120, alignment: .leading)

            // Right: Trend chart
            VStack {
                if entry.trendData.count >= 2 {
                    MiniTrendChart(
                        dataPoints: entry.trendData,
                        lineColor: entry.balance >= 0 ? Color.green : Color.red,
                        fillColor: (entry.balance >= 0 ? Color.green : Color.red).opacity(0.15)
                    )
                } else {
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Sin datos")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding()
        .widgetURL(URL(string: "yala://panel"))
    }

    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        let absBalance = abs(entry.balance)
        let formatted = formatter.string(from: NSNumber(value: absBalance)) ?? "0.00"
        return entry.balance >= 0 ? formatted : "-\(formatted)"
    }

    private var periodLabel: String {
        switch entry.trendPeriod {
        case .week:
            return "Última semana"
        case .month:
            return "Último mes"
        }
    }
}

// MARK: - Widget Definition

struct BalanceWidget: Widget {
    let kind: String = "BalanceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: BalanceWidgetIntent.self,
            provider: BalanceWidgetProvider()
        ) { entry in
            BalanceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Balance")
        .description("Tu balance total con tendencia")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    BalanceWidget()
} timeline: {
    BalanceEntry(
        date: Date(),
        balance: 15420.50,
        currencyCode: "PEN",
        trendData: [],
        isPlaceholder: false,
        trendPeriod: .week
    )
}

#Preview("Medium", as: .systemMedium) {
    BalanceWidget()
} timeline: {
    BalanceEntry(
        date: Date(),
        balance: 15420.50,
        currencyCode: "PEN",
        trendData: [
            WidgetTrendPoint(date: Date().addingTimeInterval(-6 * 86400), balance: 14000),
            WidgetTrendPoint(date: Date().addingTimeInterval(-5 * 86400), balance: 14500),
            WidgetTrendPoint(date: Date().addingTimeInterval(-4 * 86400), balance: 14200),
            WidgetTrendPoint(date: Date().addingTimeInterval(-3 * 86400), balance: 15000),
            WidgetTrendPoint(date: Date().addingTimeInterval(-2 * 86400), balance: 15200),
            WidgetTrendPoint(date: Date().addingTimeInterval(-1 * 86400), balance: 15100),
            WidgetTrendPoint(date: Date(), balance: 15420),
        ],
        isPlaceholder: false,
        trendPeriod: .week
    )
}
