//
//  CashFlowWidget.swift
//  YalaWidgets
//
//  Widget showing net cash flow (income - expenses).
//  Supports Small (KPI), Medium (KPI + bars), and Large (KPI + bidirectional chart).
//

import WidgetKit
import SwiftUI
import AppIntents
import Charts

// MARK: - Configuration Intent

struct CashFlowWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Flujo de dinero" }
    static var description: IntentDescription { "Muestra tu flujo de dinero neto" }

    @Parameter(title: "Período", default: .thisMonth)
    var period: WidgetPeriodOption
}

// MARK: - Timeline Entry

struct CashFlowEntry: TimelineEntry {
    let date: Date
    let totalIncome: Double
    let totalExpense: Double
    let netCashFlow: Double
    let currencyCode: String
    let currencyDisplayFormat: String
    let cashFlowPoints: [WidgetCashFlowPoint]
    let isPlaceholder: Bool
    let period: WidgetPeriodOption

    static var placeholder: CashFlowEntry {
        CashFlowEntry(
            date: Date(),
            totalIncome: 5000.00,
            totalExpense: 3250.00,
            netCashFlow: 1750.00,
            currencyCode: "PEN",
            currencyDisplayFormat: "symbol",
            cashFlowPoints: [],
            isPlaceholder: true,
            period: .thisMonth
        )
    }
}

// MARK: - Timeline Provider

struct CashFlowWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = CashFlowEntry
    typealias Intent = CashFlowWidgetIntent

    func placeholder(in context: Context) -> CashFlowEntry {
        .placeholder
    }

    func snapshot(for configuration: CashFlowWidgetIntent, in context: Context) async -> CashFlowEntry {
        if context.isPreview {
            return .placeholder
        }
        return createEntry(for: configuration)
    }

    func timeline(for configuration: CashFlowWidgetIntent, in context: Context) async -> Timeline<CashFlowEntry> {
        let entry = createEntry(for: configuration)

        // Refresh every 4 hours
        let refreshDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()

        return Timeline(entries: [entry], policy: .after(refreshDate))
    }

    private func createEntry(for configuration: CashFlowWidgetIntent) -> CashFlowEntry {
        let currency = WidgetDataService.getPreferredCurrency()
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()
        let period = configuration.period.toWidgetPeriod

        // Get summary for the period
        let summary = WidgetDataService.calculateSummary(for: period)

        return CashFlowEntry(
            date: Date(),
            totalIncome: summary?.totalIncome ?? 0,
            totalExpense: summary?.totalExpense ?? 0,
            netCashFlow: summary?.netCashFlow ?? 0,
            currencyCode: currency,
            currencyDisplayFormat: displayFormat,
            cashFlowPoints: summary?.cashFlowPoints ?? [],
            isPlaceholder: false,
            period: configuration.period
        )
    }
}

// MARK: - Widget Views

struct CashFlowWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: CashFlowEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallCashFlowView(entry: entry)
        case .systemMedium:
            MediumCashFlowView(entry: entry)
        case .systemLarge:
            LargeCashFlowView(entry: entry)
        default:
            SmallCashFlowView(entry: entry)
        }
    }
}

// MARK: - Small View

struct SmallCashFlowView: View {
    let entry: CashFlowEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.xs) {
            WidgetHeader(
                title: "Flujo neto",
                subtitle: entry.period.toWidgetPeriod.displayName,
                icon: "arrow.left.arrow.right"
            )

            Spacer()

            WidgetKPI(
                amount: entry.netCashFlow,
                currencyCode: entry.currencyCode,
                displayFormat: entry.currencyDisplayFormat,
                color: .primary,
                size: .large
            )

            // Small income/expense summary (vertical layout to avoid truncation)
            VStack(alignment: .leading, spacing: WDS.Spacing.xxs) {
                Label {
                    Text(formatAmount(entry.totalIncome))
                        .font(WDS.Typography.tiny)
                } icon: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(WidgetColors.income)

                Label {
                    Text(formatAmount(entry.totalExpense))
                        .font(WDS.Typography.tiny)
                } icon: {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(WidgetColors.expense)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }

    private func formatAmount(_ value: Double) -> String {
        let symbol = entry.currencyDisplayFormat == "symbol"
            ? CurrencySymbols.symbol(for: entry.currencyCode)
            : entry.currencyCode
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "\(symbol) \(formatter.string(from: NSNumber(value: value)) ?? "0")"
    }
}

// MARK: - Medium View

struct MediumCashFlowView: View {
    let entry: CashFlowEntry

    private var maxValue: Double {
        max(entry.totalIncome, entry.totalExpense, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.sm) {
            // Header row: title+subtitle left, KPI right
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: WDS.Spacing.xxs) {
                    Text("Flujo neto")
                        .font(WDS.Typography.title)
                        .foregroundStyle(.primary)
                    Text(entry.period.toWidgetPeriod.displayName)
                        .font(WDS.Typography.subtitle)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                WidgetKPI(
                    amount: entry.netCashFlow,
                    currencyCode: entry.currencyCode,
                    displayFormat: entry.currencyDisplayFormat,
                    color: .primary,
                    size: .small
                )
            }

            Spacer(minLength: WDS.Spacing.xs)

            // Bars section - identical to PanelView compact
            VStack(spacing: WDS.Spacing.md) {
                // Income bar
                VStack(spacing: WDS.Spacing.xxs) {
                    HStack {
                        Text("Ingresos")
                            .font(WDS.Typography.label)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatCurrency(entry.totalIncome))
                            .font(WDS.Typography.value)
                            .foregroundStyle(.primary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            Capsule()
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 8)
                            // Fill
                            Capsule()
                                .fill(WidgetColors.income)
                                .frame(width: max(geo.size.width * CGFloat(entry.totalIncome / maxValue), 6), height: 8)
                        }
                    }
                    .frame(height: 8)
                }

                // Expense bar
                VStack(spacing: WDS.Spacing.xxs) {
                    HStack {
                        Text("Gastos")
                            .font(WDS.Typography.label)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatCurrency(entry.totalExpense))
                            .font(WDS.Typography.value)
                            .foregroundStyle(.primary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            Capsule()
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 8)
                            // Fill
                            Capsule()
                                .fill(WidgetColors.expense)
                                .frame(width: max(geo.size.width * CGFloat(entry.totalExpense / maxValue), 6), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }

    private func formatCurrency(_ value: Double) -> String {
        let symbol = entry.currencyDisplayFormat == "symbol"
            ? CurrencySymbols.symbol(for: entry.currencyCode)
            : entry.currencyCode
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "\(symbol) \(formatter.string(from: NSNumber(value: value)) ?? "0")"
    }
}

// MARK: - Large View

struct LargeCashFlowView: View {
    let entry: CashFlowEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.md) {
            // Header row
            HStack {
                WidgetHeader(
                    title: "Flujo de dinero",
                    subtitle: entry.period.toWidgetPeriod.displayName,
                    icon: "arrow.left.arrow.right"
                )

                Spacer()

                WidgetKPI(
                    amount: entry.netCashFlow,
                    currencyCode: entry.currencyCode,
                    displayFormat: entry.currencyDisplayFormat,
                    color: .primary,
                    size: .small
                )
            }

            // Summary row
            HStack(spacing: WDS.Spacing.xl) {
                HStack(spacing: WDS.Spacing.xs) {
                    Circle()
                        .fill(WidgetColors.income)
                        .frame(width: 8, height: 8)
                    Text("Ingresos: \(formatAmount(entry.totalIncome))")
                        .font(WDS.Typography.label)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: WDS.Spacing.xs) {
                    Circle()
                        .fill(WidgetColors.expense)
                        .frame(width: 8, height: 8)
                    Text("Gastos: \(formatAmount(entry.totalExpense))")
                        .font(WDS.Typography.label)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Cash flow chart
            if entry.cashFlowPoints.count >= 2 {
                BidirectionalCashFlowChart(points: entry.cashFlowPoints, period: entry.period)
            } else {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: WDS.Spacing.xs) {
                            Image(systemName: "chart.bar")
                                .font(.title)
                                .foregroundStyle(.tertiary)
                            Text("Sin datos suficientes")
                                .font(WDS.Typography.body)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

// MARK: - Supporting Views

/// Horizontal comparison bars for income vs expense
struct CashFlowBars: View {
    let income: Double
    let expense: Double

    private var maxValue: Double {
        max(income, expense, 1)
    }

    var body: some View {
        VStack(spacing: WDS.Spacing.md) {
            // Income bar
            VStack(alignment: .leading, spacing: WDS.Spacing.xxs) {
                HStack {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                    Text("Ingresos")
                        .font(WDS.Typography.tiny)
                }
                .foregroundColor(WidgetColors.income)

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: WDS.Radius.xs)
                        .fill(WidgetColors.income)
                        .frame(width: geo.size.width * CGFloat(income / maxValue))
                }
                .frame(height: 12)
                .background(
                    RoundedRectangle(cornerRadius: WDS.Radius.xs)
                        .fill(Color.gray.opacity(0.15))
                )
            }

            // Expense bar
            VStack(alignment: .leading, spacing: WDS.Spacing.xxs) {
                HStack {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("Gastos")
                        .font(WDS.Typography.tiny)
                }
                .foregroundColor(WidgetColors.expense)

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: WDS.Radius.xs)
                        .fill(WidgetColors.expense)
                        .frame(width: geo.size.width * CGFloat(expense / maxValue))
                }
                .frame(height: 12)
                .background(
                    RoundedRectangle(cornerRadius: WDS.Radius.xs)
                        .fill(Color.gray.opacity(0.15))
                )
            }
        }
    }
}

/// Bidirectional bar chart showing income/expense using Swift Charts
/// Groups data according to period: week→day, month→week, quarter/year→month
struct BidirectionalCashFlowChart: View {
    let points: [WidgetCashFlowPoint]
    let period: WidgetPeriodOption

    /// Grouping type based on period
    private enum Grouping {
        case day
        case week
        case month

        var calendarUnit: Calendar.Component {
            switch self {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            }
        }

        var xPadding: Int {
            switch self {
            case .day: return 1
            case .week: return 4
            case .month: return 15
            }
        }
    }

    /// Determine grouping based on period
    private var grouping: Grouping {
        switch period {
        case .today, .yesterday, .thisWeek, .lastWeek:
            return .day
        case .thisMonth, .lastMonth:
            return .week
        case .thisQuarter, .lastQuarter, .thisYear, .lastYear, .allTime:
            return .month
        }
    }

    /// Group points according to the grouping strategy
    private var groupedPoints: [WidgetCashFlowPoint] {
        let calendar = Calendar.current

        // Group by the appropriate granularity
        var grouped: [Date: (income: Double, expense: Double)] = [:]

        for point in points {
            let groupDate: Date
            switch grouping {
            case .day:
                groupDate = calendar.startOfDay(for: point.date)
            case .week:
                let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: point.date)
                groupDate = calendar.date(from: components) ?? point.date
            case .month:
                let components = calendar.dateComponents([.year, .month], from: point.date)
                groupDate = calendar.date(from: components) ?? point.date
            }

            var existing = grouped[groupDate] ?? (income: 0, expense: 0)
            existing.income += point.income
            existing.expense += point.expense
            grouped[groupDate] = existing
        }

        return grouped
            .map { date, data in
                WidgetCashFlowPoint(
                    date: date,
                    income: data.income,
                    expense: data.expense,
                    net: data.income - data.expense
                )
            }
            .filter { $0.income > 0 || $0.expense > 0 }
            .sorted { $0.date < $1.date }
    }

    /// Y-axis domain with bidirectional scale
    private var yDomain: ClosedRange<Double> {
        let maxIncome = groupedPoints.map(\.income).max() ?? 0
        let maxExpense = groupedPoints.map(\.expense).max() ?? 0
        let incomeTop = maxIncome * 1.1
        let expenseBottom = -maxExpense * 1.1
        return expenseBottom...incomeTop
    }

    /// X-axis domain with asymmetric padding
    private var xDomain: ClosedRange<Date> {
        guard let firstDate = groupedPoints.first?.date,
              let lastDate = groupedPoints.last?.date else {
            return Date()...Date()
        }
        let calendar = Calendar.current
        let paddedEnd = calendar.date(byAdding: .day, value: grouping.xPadding, to: lastDate) ?? lastDate
        return firstDate...paddedEnd
    }

    /// Smart axis dates using SmartAxisHelper (up to 5 labels)
    private var smartAxisDates: [Date] {
        guard let first = groupedPoints.first?.date,
              let last = groupedPoints.last?.date else { return [] }
        return SmartAxisHelper.calculateSmartAxisDates(from: first, to: last)
    }

    /// Format axis label using SmartAxisHelper
    private func smartAxisLabel(for date: Date) -> String {
        guard let first = groupedPoints.first?.date,
              let last = groupedPoints.last?.date else { return "" }
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
        Chart {
            // Zero baseline (dashed line)
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(Color.gray.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

            ForEach(Array(groupedPoints.enumerated()), id: \.offset) { _, point in
                // Income bars (upward - teal)
                BarMark(
                    x: .value("Date", point.date, unit: grouping.calendarUnit),
                    y: .value("Income", point.income)
                )
                .foregroundStyle(WidgetColors.income.gradient)
                .cornerRadius(WDS.Radius.xs)

                // Expense bars (downward - pink)
                BarMark(
                    x: .value("Date", point.date, unit: grouping.calendarUnit),
                    y: .value("Expense", -point.expense)
                )
                .foregroundStyle(WidgetColors.expense.gradient)
                .cornerRadius(WDS.Radius.xs)

                // Net flow line (purple)
                LineMark(
                    x: .value("Date", point.date, unit: grouping.calendarUnit),
                    y: .value("Net", point.net)
                )
                .foregroundStyle(WidgetColors.electricIndigo)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)

                // Net flow points (purple dots)
                PointMark(
                    x: .value("Date", point.date, unit: grouping.calendarUnit),
                    y: .value("Net", point.net)
                )
                .foregroundStyle(WidgetColors.electricIndigo)
                .symbolSize(20)
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: smartAxisDates) { value in
                AxisGridLine()
                    .foregroundStyle(Color.secondary.opacity(0.1))
                if let date = value.as(Date.self) {
                    // Smart anchoring: first label left-aligned, last right-aligned
                    let isFirst = date == smartAxisDates.first
                    let isLast = date == smartAxisDates.last
                    let anchor: UnitPoint = isLast ? .topTrailing : (isFirst ? .topLeading : .top)

                    AxisValueLabel(anchor: anchor) {
                        Text(smartAxisLabel(for: date))
                            .font(.caption2.bold())
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
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Widget Definition

struct CashFlowWidget: Widget {
    let kind: String = "CashFlowWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CashFlowWidgetIntent.self,
            provider: CashFlowWidgetProvider()
        ) { entry in
            CashFlowWidgetView(entry: entry)
                .containerBackground(WidgetColors.yalaCard, for: .widget)
        }
        .configurationDisplayName("Flujo de dinero")
        .description("Tu flujo de dinero neto")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    CashFlowWidget()
} timeline: {
    CashFlowEntry(
        date: Date(),
        totalIncome: 5000.00,
        totalExpense: 3250.00,
        netCashFlow: 1750.00,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        cashFlowPoints: [],
        isPlaceholder: false,
        period: .thisMonth
    )
}

#Preview("Small Negative", as: .systemSmall) {
    CashFlowWidget()
} timeline: {
    CashFlowEntry(
        date: Date(),
        totalIncome: 2000.00,
        totalExpense: 3500.00,
        netCashFlow: -1500.00,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        cashFlowPoints: [],
        isPlaceholder: false,
        period: .thisMonth
    )
}

#Preview("Medium", as: .systemMedium) {
    CashFlowWidget()
} timeline: {
    CashFlowEntry(
        date: Date(),
        totalIncome: 5000.00,
        totalExpense: 3250.00,
        netCashFlow: 1750.00,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        cashFlowPoints: [],
        isPlaceholder: false,
        period: .thisMonth
    )
}

#Preview("Large", as: .systemLarge) {
    CashFlowWidget()
} timeline: {
    CashFlowEntry(
        date: Date(),
        totalIncome: 5000.00,
        totalExpense: 3250.00,
        netCashFlow: 1750.00,
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        cashFlowPoints: [
            WidgetCashFlowPoint(date: Date().addingTimeInterval(-6 * 86400), income: 1000, expense: 400, net: 600),
            WidgetCashFlowPoint(date: Date().addingTimeInterval(-5 * 86400), income: 0, expense: 600, net: -600),
            WidgetCashFlowPoint(date: Date().addingTimeInterval(-4 * 86400), income: 500, expense: 300, net: 200),
            WidgetCashFlowPoint(date: Date().addingTimeInterval(-3 * 86400), income: 2000, expense: 800, net: 1200),
            WidgetCashFlowPoint(date: Date().addingTimeInterval(-2 * 86400), income: 0, expense: 450, net: -450),
            WidgetCashFlowPoint(date: Date().addingTimeInterval(-1 * 86400), income: 1500, expense: 500, net: 1000),
            WidgetCashFlowPoint(date: Date(), income: 0, expense: 200, net: -200),
        ],
        isPlaceholder: false,
        period: .thisWeek
    )
}
