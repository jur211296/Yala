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
                color: WidgetColors.forCashFlow(entry.netCashFlow),
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
        .widgetURL(URL(string: "yala://panel"))
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

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.sm) {
            // Header full width: title left, subtitle right
            WidgetHeader(
                title: "Flujo neto",
                subtitle: entry.period.toWidgetPeriod.displayName,
                icon: "arrow.left.arrow.right",
                inline: true
            )

            // Content: KPI + breakdown left, bars right
            HStack(spacing: WDS.Spacing.lg) {
                // Left: KPI and income/expense breakdown
                VStack(alignment: .leading, spacing: WDS.Spacing.xs) {
                    Spacer()

                    WidgetKPI(
                        amount: entry.netCashFlow,
                        currencyCode: entry.currencyCode,
                        displayFormat: entry.currencyDisplayFormat,
                        color: WidgetColors.forCashFlow(entry.netCashFlow),
                        size: .medium
                    )

                    // Income/Expense labels
                    HStack(spacing: WDS.Spacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ingresos")
                                .font(WDS.Typography.tiny)
                                .foregroundStyle(.secondary)
                            Text(formatAmount(entry.totalIncome))
                                .font(WDS.Typography.value)
                                .foregroundColor(WidgetColors.income)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gastos")
                                .font(WDS.Typography.tiny)
                                .foregroundStyle(.secondary)
                            Text(formatAmount(entry.totalExpense))
                                .font(WDS.Typography.value)
                                .foregroundColor(WidgetColors.expense)
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: 160, alignment: .leading)

                // Right: Stacked bars comparison
                CashFlowBars(
                    income: entry.totalIncome,
                    expense: entry.totalExpense
                )
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(URL(string: "yala://panel"))
    }

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
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
                    color: WidgetColors.forCashFlow(entry.netCashFlow),
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
                BidirectionalCashFlowChart(points: entry.cashFlowPoints)
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
        .widgetURL(URL(string: "yala://panel"))
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

/// Bidirectional bar chart showing daily income/expense
struct BidirectionalCashFlowChart: View {
    let points: [WidgetCashFlowPoint]

    private var maxValue: Double {
        let maxIncome = points.map(\.income).max() ?? 0
        let maxExpense = points.map(\.expense).max() ?? 0
        return max(maxIncome, maxExpense, 1)
    }

    var body: some View {
        GeometryReader { geo in
            let barWidth = max((geo.size.width - CGFloat(points.count - 1) * 2) / CGFloat(points.count), 4)
            let midY = geo.size.height / 2

            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    VStack(spacing: 0) {
                        // Income (above center)
                        Spacer(minLength: 0)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(WidgetColors.income)
                            .frame(
                                width: barWidth,
                                height: max(CGFloat(point.income / maxValue) * (midY - 4), point.income > 0 ? 2 : 0)
                            )

                        // Center line reference
                        Color.clear.frame(height: 1)

                        // Expense (below center)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(WidgetColors.expense)
                            .frame(
                                width: barWidth,
                                height: max(CGFloat(point.expense / maxValue) * (midY - 4), point.expense > 0 ? 2 : 0)
                            )

                        Spacer(minLength: 0)
                    }
                }
            }
            .overlay(
                // Center line
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                    .position(x: geo.size.width / 2, y: midY)
            )
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
                .containerBackground(.fill.tertiary, for: .widget)
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
