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
import Charts

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

        // Build expense trend from cashFlowPoints (cumulative expense over time)
        let cashFlowPoints = summary?.cashFlowPoints ?? []
        var cumulativeExpense: Double = 0
        let expenseTrendData: [WidgetTrendPoint] = cashFlowPoints.map { point in
            cumulativeExpense += point.expense
            return WidgetTrendPoint(date: point.date, balance: cumulativeExpense)
        }

        return ExpenseEntry(
            date: Date(),
            totalExpense: totalExpense,
            currencyCode: currency,
            currencyDisplayFormat: displayFormat,
            trendData: expenseTrendData,
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
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }
}

struct MediumExpenseView: View {
    let entry: ExpenseEntry

    /// Line color for expenses
    private var lineColor: Color {
        WidgetColors.expense
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
        return max(0, minVal - padding)...(maxVal + padding)
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
                    Text("Gastos")
                        .font(WDS.Typography.title)
                        .foregroundStyle(.primary)
                    Text(entry.period.toWidgetPeriod.displayName)
                        .font(WDS.Typography.subtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                WidgetKPI(
                    amount: entry.totalExpense,
                    currencyCode: entry.currencyCode,
                    displayFormat: entry.currencyDisplayFormat,
                    color: WidgetColors.expense,
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
                            yEnd: .value("Expense", point.balance)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(areaGradient)

                        // Line
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Expense", point.balance)
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
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "panel"))
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
                .containerBackground(WidgetColors.yalaCard, for: .widget)
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
