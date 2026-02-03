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
import Charts

// MARK: - Configuration Intent

struct BalanceWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Balance" }
    static var description: IntentDescription { "Muestra tu balance total" }

    @Parameter(title: "Período", default: .thisMonth)
    var period: WidgetPeriodOption
}

/// AppEnum wrapper for WidgetPeriod (AppIntents requires AppEnum conformance)
enum WidgetPeriodOption: String, AppEnum {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case lastMonth
    case thisQuarter
    case lastQuarter
    case thisYear
    case lastYear
    case allTime

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Período"
    }

    static var caseDisplayRepresentations: [WidgetPeriodOption: DisplayRepresentation] {
        [
            .today: "Hoy",
            .yesterday: "Ayer",
            .thisWeek: "Esta semana",
            .lastWeek: "Semana pasada",
            .thisMonth: "Este mes",
            .lastMonth: "Mes pasado",
            .thisQuarter: "Este trimestre",
            .lastQuarter: "Trimestre pasado",
            .thisYear: "Este año",
            .lastYear: "Año pasado",
            .allTime: "Todo el tiempo"
        ]
    }

    var toWidgetPeriod: WidgetPeriod {
        switch self {
        case .today: return .today
        case .yesterday: return .yesterday
        case .thisWeek: return .thisWeek
        case .lastWeek: return .lastWeek
        case .thisMonth: return .thisMonth
        case .lastMonth: return .lastMonth
        case .thisQuarter: return .thisQuarter
        case .lastQuarter: return .lastQuarter
        case .thisYear: return .thisYear
        case .lastYear: return .lastYear
        case .allTime: return .allTime
        }
    }
}

// MARK: - Timeline Entry

struct BalanceEntry: TimelineEntry {
    let date: Date
    let balance: Double
    let currencyCode: String
    let currencyDisplayFormat: String
    let trendData: [WidgetTrendPoint]
    let isPlaceholder: Bool
    let period: WidgetPeriodOption

    static var placeholder: BalanceEntry {
        BalanceEntry(
            date: Date(),
            balance: 12500.00,
            currencyCode: "PEN",
            currencyDisplayFormat: "symbol",
            trendData: [],
            isPlaceholder: true,
            period: .thisMonth
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
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()
        let period = configuration.period.toWidgetPeriod

        // Get trend data for the selected period
        let trendData = WidgetDataService.getTrendData(for: period)

        return BalanceEntry(
            date: Date(),
            balance: balance,
            currencyCode: currency,
            currencyDisplayFormat: displayFormat,
            trendData: trendData,
            isPlaceholder: false,
            period: configuration.period
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
        VStack(alignment: .leading, spacing: WDS.Spacing.xs) {
            WidgetHeader(
                title: "Balance",
                subtitle: entry.period.toWidgetPeriod.displayName,
                icon: "creditcard.fill"
            )

            Spacer()

            WidgetKPI(
                amount: entry.balance,
                currencyCode: entry.currencyCode,
                displayFormat: entry.currencyDisplayFormat,
                color: .primary,
                size: .large
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }
}

struct MediumBalanceView: View {
    let entry: BalanceEntry

    /// Line color based on balance (electric indigo for positive, expense for negative)
    private var lineColor: Color {
        entry.balance >= 0 ? WidgetColors.electricIndigo : WidgetColors.expense
    }

    /// Area gradient matching PanelView TrendChartView exactly
    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [lineColor.opacity(0.1), lineColor.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Y-axis domain with padding
    private var yDomain: ClosedRange<Double> {
        guard !entry.trendData.isEmpty else { return 0...100 }
        let values = entry.trendData.map(\.balance)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 100
        let padding = max((maxVal - minVal) * 0.1, 1)
        return (minVal - padding)...(maxVal + padding)
    }

    /// X-axis domain based on data range
    private var xDomain: ClosedRange<Date> {
        guard let first = entry.trendData.first?.date,
              let last = entry.trendData.last?.date else {
            return Date()...Date()
        }
        let span = last.timeIntervalSince(first)
        let padding = max(span * 0.05, 86400)
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }

    /// Smart axis dates using SmartAxisHelper
    private var smartAxisDates: [Date] {
        guard let first = entry.trendData.first?.date,
              let last = entry.trendData.last?.date else { return [] }
        return SmartAxisHelper.calculateSmartAxisDates(from: first, to: last)
    }

    /// Format axis label using SmartAxisHelper
    private func smartAxisLabel(for date: Date) -> String {
        guard let first = entry.trendData.first?.date,
              let last = entry.trendData.last?.date else { return "" }
        return SmartAxisHelper.formatAxisLabel(for: date, startDate: first, endDate: last)
    }

    /// Format Y value as K
    private func formatK(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        if absValue >= 1000 {
            return String(format: "%@%.0fK", sign, absValue / 1000.0)
        }
        return String(format: "%@%.0f", sign, absValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.sm) {
            // Header row: title+subtitle left, KPI right
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: WDS.Spacing.xxs) {
                    Text("Balance")
                        .font(WDS.Typography.title)
                        .foregroundStyle(.primary)
                    Text(entry.period.toWidgetPeriod.displayName)
                        .font(WDS.Typography.subtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                WidgetKPI(
                    amount: entry.balance,
                    currencyCode: entry.currencyCode,
                    displayFormat: entry.currencyDisplayFormat,
                    color: .primary,
                    size: .small
                )
            }

            // Full-width trend chart
            if entry.trendData.count >= 2 {
                Chart {
                    let yBase = min(max(yDomain.lowerBound, 0), yDomain.upperBound)

                    ForEach(entry.trendData, id: \.date) { point in
                        // Area fill
                        AreaMark(
                            x: .value("Date", point.date),
                            yStart: .value("Base", yBase),
                            yEnd: .value("Balance", point.balance)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(areaGradient)

                        // Line
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Balance", point.balance)
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(lineColor)
                    }
                }
                .chartXScale(domain: xDomain)
                .chartYScale(domain: yDomain)
                .chartXAxis {
                    AxisMarks(values: smartAxisDates) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(0.1))
                        if let date = value.as(Date.self) {
                            let isFirst = date == smartAxisDates.first
                            let isLast = date == smartAxisDates.last
                            let anchor: UnitPoint = isLast ? .topTrailing : (isFirst ? .topLeading : .top)

                            AxisValueLabel(anchor: anchor) {
                                Text(smartAxisLabel(for: date))
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.secondary.opacity(0.1))
                        if let doubleValue = value.as(Double.self) {
                            AxisValueLabel {
                                Text(formatK(doubleValue))
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                // Empty state
                VStack(spacing: WDS.Spacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("Sin datos")
                        .font(WDS.Typography.tiny)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "panel"))
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
                .containerBackground(WidgetColors.yalaCard, for: .widget)
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
        currencyDisplayFormat: "symbol",
        trendData: [],
        isPlaceholder: false,
        period: .thisMonth
    )
}

#Preview("Medium", as: .systemMedium) {
    BalanceWidget()
} timeline: {
    BalanceEntry(
        date: Date(),
        balance: 15420.50,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
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
        period: .thisWeek
    )
}

#Preview("Negative Balance", as: .systemSmall) {
    BalanceWidget()
} timeline: {
    BalanceEntry(
        date: Date(),
        balance: -2350.00,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        trendData: [],
        isPlaceholder: false,
        period: .thisMonth
    )
}
