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
    static var title: LocalizedStringResource { "widget.intent.balance.title" }
    static var description: IntentDescription { "widget.intent.balance.desc" }

    @Parameter(title: "widget.period.type", default: .sameAsApp)
    var period: WidgetPeriodOption

}

/// AppEnum wrapper for WidgetPeriod (AppIntents requires AppEnum conformance)
/// Aligned with DetailPeriod from main app (8 cases, excluding custom)
/// sameAsApp reads user's default period from app settings
enum WidgetPeriodOption: String, AppEnum {
    case sameAsApp
    case thisWeek
    case last7Days
    case last30Days
    case thisMonth
    case lastMonth
    case thisYear
    case lastYear
    case allTime

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.period.type")
    }

    static var caseDisplayRepresentations: [WidgetPeriodOption: DisplayRepresentation] {
        [
            .sameAsApp: DisplayRepresentation(title: "widget.period.sameAsApp"),
            .thisWeek: DisplayRepresentation(title: "widget.period.thisWeek"),
            .last7Days: DisplayRepresentation(title: "widget.period.last7Days"),
            .last30Days: DisplayRepresentation(title: "widget.period.last30Days"),
            .thisMonth: DisplayRepresentation(title: "widget.period.thisMonth"),
            .lastMonth: DisplayRepresentation(title: "widget.period.lastMonth"),
            .thisYear: DisplayRepresentation(title: "widget.period.thisYear"),
            .lastYear: DisplayRepresentation(title: "widget.period.lastYear"),
            .allTime: DisplayRepresentation(title: "widget.period.allTime")
        ]
    }

    var toWidgetPeriod: WidgetPeriod {
        switch self {
        case .sameAsApp: return WidgetDataService.getAppDefaultPeriod()
        case .thisWeek: return .thisWeek
        case .last7Days: return .last7Days
        case .last30Days: return .last30Days
        case .thisMonth: return .thisMonth
        case .lastMonth: return .lastMonth
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
    /// Marca «≈» del saldo. Al final y con default: placeholders y previews traen cifras
    /// inventadas y exactas.
    var balanceIsApproximate: Bool = false
    /// Cuánto subió o bajó el saldo en el período (`WidgetInsightsLogic.balanceChange`); `nil` en «Todo el tiempo» o
    /// si la curva no llega a antes del inicio.
    var change: Double? = nil
    /// Cuándo escribió la app la foto: si no es de hoy, el widget lo dice.
    var lastUpdated: Date? = nil

    static var placeholder: BalanceEntry {
        BalanceEntry(
            date: Date(),
            balance: 12500.00,
            currencyCode: "PEN",
            currencyDisplayFormat: "symbol",
            trendData: Self.sampleTrend(ending: 12_500),
            isPlaceholder: true,
            period: .thisMonth,
            change: 640
        )
    }

    /// Curva de ejemplo para la galería: tres semanas que acaban en `ending`.
    static func sampleTrend(ending: Double) -> [WidgetTrendPoint] {
        let deltas: [Double] = [0, -120, -80, 40, -260, -30, 900, -140, -60, -20, 310, -90, -45, -180, 20, -60, 450, -70, -20, -40, 95]
        var value = ending - deltas.reduce(0, +)
        return deltas.enumerated().map { index, delta in
            value += delta
            return WidgetTrendPoint(date: Date().addingTimeInterval(Double(index - deltas.count + 1) * 86400), balance: value)
        }
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
        return Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date)))
    }

    private func createEntry(for configuration: BalanceWidgetIntent) -> BalanceEntry {
        let now = Date()
        let period = configuration.period.toWidgetPeriod
        let balance = WidgetDataService.getBalance(for: period)
        let currency = WidgetDataService.getPreferredCurrency()
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()
        let lastUpdated = WidgetDataService.getLastUpdated()
        // Las cifras de la foto se calcularon cuando la app la escribió: el período se mide a esa hora, no a la de ahora.
        let asOf = lastUpdated ?? now

        return BalanceEntry(
            date: now,
            balance: balance,
            currencyCode: currency,
            currencyDisplayFormat: displayFormat,
            trendData: WidgetDataService.getTrendData(for: period, asOf: asOf),
            isPlaceholder: false,
            period: configuration.period,
            balanceIsApproximate: WidgetDataService.getBalanceIsApproximate(for: period),
            // Con «Comparar con el período anterior» apagado en la app, sin la píldora (como el hero del Panel).
            change: WidgetDataService.showsVariations ? Self.change(for: period, balance: balance, asOf: asOf) : nil,
            lastUpdated: lastUpdated
        )
    }

    /// La variación del período contra el cierre anterior a su inicio: curva diaria para semanas y meses, mensual para
    /// los años (la semanal empieza en lunes y su cierre puede caer dentro del año).
    static func change(for period: WidgetPeriod, balance: Double, asOf: Date) -> Double? {
        guard period != .allTime, let data = WidgetDataService.getTrendData() else { return nil }
        let closings = (period == .thisYear || period == .lastYear) ? data.monthlyPoints : data.dailyPoints
        return WidgetInsightsLogic.balanceChange(
            balance: balance,
            closings: closings.map { (date: $0.date, balance: $0.balance) },
            periodStart: period.dateInterval(now: asOf).start
        )
    }
}

// MARK: - Widget Views

struct BalanceWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: BalanceEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumBalanceView(entry: entry)
        default:
            SmallBalanceView(entry: entry)
        }
    }
}

/// Lo que comparten los dos tamaños: el título, la variación y su tono.
private extension BalanceEntry {
    var title: String { String(localized: "widget.ui.available", bundle: .main) }
    var periodName: String { period.toWidgetPeriod.localizedDisplayName }

    /// Subir es bueno (índigo) y bajar, malo (rosa): los colores de la app para un saldo.
    var changeTone: WidgetTone {
        guard let change, abs(change) >= 0.5 else { return .neutral }
        return change > 0 ? .good : .bad
    }
}

struct SmallBalanceView: View {
    let entry: BalanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
            WidgetCardHeader(title: entry.title, systemImage: "wallet.bifold.fill", tint: WidgetColors.electricIndigo)

            Spacer(minLength: WidgetDS.Spacing.xs)

            WidgetHeroAmount(
                value: entry.balance,
                currencyCode: entry.currencyCode,
                displayFormat: entry.currencyDisplayFormat,
                isEstimate: entry.balanceIsApproximate
            )

            BalanceChangeLine(entry: entry)
                .padding(.top, WidgetDS.Spacing.xxs)

            if entry.trendData.count >= 2 {
                BalanceTrendChart(points: entry.trendData)
                    .frame(height: WidgetDS.Chart.sparklineHeight)
                    .padding(.top, WidgetDS.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }
}

struct MediumBalanceView: View {
    let entry: BalanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
            WidgetCardHeader(title: entry.title, systemImage: "wallet.bifold.fill", tint: WidgetColors.electricIndigo) {
                WidgetHeaderDetail(text: entry.periodName)
            }

            HStack(alignment: .bottom, spacing: WidgetDS.Spacing.lg) {
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.xs) {
                    Spacer(minLength: 0)
                    WidgetHeroAmount(
                        value: entry.balance,
                        currencyCode: entry.currencyCode,
                        displayFormat: entry.currencyDisplayFormat,
                        isEstimate: entry.balanceIsApproximate
                    )
                    BalanceChangeLine(entry: entry, showsPeriod: false)
                    WidgetFreshnessNote(lastUpdated: entry.lastUpdated, now: entry.date)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if entry.trendData.count >= 2 {
                    BalanceTrendChart(points: entry.trendData)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("widget.ui.noData", bundle: .main)
                        .font(WidgetDS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }
}

/// «▲ S/ 320 · Este mes»: cuánto subió o bajó el saldo en el período. Sin variación (todo el tiempo, o sin datos de
/// antes), solo el período; en el mediano el período ya va en la cabecera (`showsPeriod: false`).
private struct BalanceChangeLine: View {
    let entry: BalanceEntry
    var showsPeriod: Bool = true

    var body: some View {
        HStack(spacing: WidgetDS.Spacing.xs) {
            if let change = entry.change {
                let runs = WidgetAmountSplitter.split(
                    value: abs(change),
                    symbol: CurrencySymbols.display(for: entry.currencyCode, format: entry.currencyDisplayFormat),
                    fractionDigits: 0
                )
                WidgetPill(
                    text: runs.accessibilityFormatted,
                    systemImage: entry.changeTone == .neutral ? "equal" : (change > 0 ? "arrow.up" : "arrow.down"),
                    tone: entry.changeTone
                )
                .accessibilityLabel(Text(String(format: String(localized: "widget.balance.change.a11y", bundle: .main),
                                                 (change > 0 ? "+" : change < 0 ? "-" : "") + runs.accessibilityFormatted,
                                                 entry.periodName)))
            }
            if showsPeriod {
                Text(entry.periodName)
                    .font(WidgetDS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

/// La curva del saldo en el período: línea índigo con su área tenue y el punto de hoy. Sin ejes: la cifra y la píldora
/// ya dicen cuánto; la curva dice cómo se llegó. En tintado NO se tiñe: lo teñido es la cifra (una cosa por widget).
struct BalanceTrendChart: View {
    let points: [WidgetTrendPoint]

    private var domain: ClosedRange<Double> {
        let values = points.map(\.balance)
        let low = values.min() ?? 0
        let high = values.max() ?? 0
        let pad = max((high - low) * 0.15, 1)
        return (low - pad)...(high + pad)
    }

    var body: some View {
        let floor = domain.lowerBound
        Chart {
            ForEach(points, id: \.date) { point in
                AreaMark(
                    x: .value("Fecha", point.date),
                    yStart: .value("Base", floor),
                    yEnd: .value("Saldo", point.balance)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(WidgetColors.electricIndigo.opacity(WidgetDS.Opacity.subtle))

                LineMark(x: .value("Fecha", point.date), y: .value("Saldo", point.balance))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: WidgetDS.Chart.lineWidth, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(WidgetColors.electricIndigo)
            }
            if let last = points.last {
                PointMark(x: .value("Fecha", last.date), y: .value("Saldo", last.balance))
                    .symbolSize(WidgetDS.Chart.pointArea)
                    .foregroundStyle(WidgetColors.electricIndigo)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: domain)
        .chartLegend(.hidden)
        .accessibilityHidden(true)
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
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder, message: "widget.empty.openYalaBalance")
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(WidgetColors.cardBackground, for: .widget)
        }
        .configurationDisplayName("widget.gallery.balance")
        .description("widget.gallery.balance.desc")
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
        trendData: BalanceEntry.sampleTrend(ending: 15_420.50),
        isPlaceholder: false,
        period: .thisMonth,
        change: 820
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
        period: .thisWeek,
        change: 1_420
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
        trendData: BalanceEntry.sampleTrend(ending: -2_350),
        isPlaceholder: false,
        period: .thisMonth,
        change: -1_180
    )
}
