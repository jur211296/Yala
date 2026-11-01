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
    static var title: LocalizedStringResource { "widget.intent.expense.title" }
    static var description: IntentDescription { "widget.intent.expense.desc" }

    @Parameter(title: "widget.period.type", default: .sameAsApp)
    var period: WidgetPeriodOption

}

// MARK: - Timeline Entry

struct ExpenseEntry: TimelineEntry {
    let date: Date
    let totalExpense: Double
    let currencyCode: String
    let currencyDisplayFormat: String
    /// Gasto acumulado del período, un punto por día hasta hoy (lo que pinta la línea rosa).
    let trendData: [WidgetTrendPoint]
    let isPlaceholder: Bool
    let period: WidgetPeriodOption
    /// Marca «≈» del gasto. Al final y con default: placeholders y previews traen cifras
    /// inventadas y exactas.
    var expenseIsApproximate: Bool = false
    /// La comparación con el período anterior a la misma altura («Este mes» contra el mes pasado, «Este año» contra el
    /// año pasado). `nil` en los demás períodos o sin datos del anterior.
    var comparison: ExpenseComparison? = nil
    /// Promedio diario del período: lo que se enseña cuando no hay comparación.
    var dailyAverage: Double = 0
    /// Días que tiene el período: el ancho de la gráfica (la línea llega hasta hoy y el resto queda por delante).
    var periodDays: Int = 0
    /// Cuándo escribió la app la foto.
    var lastUpdated: Date? = nil

    static var placeholder: ExpenseEntry {
        let current: [Double] = [120, 180, 640, 700, 760, 900, 1_350, 1_420, 1_510, 1_690, 2_060, 2_150, 2_240, 2_600,
                                 2_700, 2_760, 2_830, 3_120, 3_250]
        let previous: [Double] = [90, 160, 300, 900, 1_000, 1_080, 1_400, 1_600, 1_700, 2_100, 2_350, 2_400, 2_600,
                                  2_900, 3_000, 3_100, 3_350, 3_480, 3_690, 3_800, 4_050, 4_120, 4_300, 4_420, 4_510,
                                  4_700, 4_820, 4_900, 5_050, 5_120]
        return ExpenseEntry(
            date: Date(),
            totalExpense: 3_250,
            currencyCode: "PEN",
            currencyDisplayFormat: "symbol",
            trendData: current.enumerated().map { WidgetTrendPoint(date: Date().addingTimeInterval(Double($0.offset - current.count + 1) * 86400), balance: $0.element) },
            isPlaceholder: true,
            period: .thisMonth,
            comparison: ExpenseComparison(
                previousLabel: WidgetDateText.monthName(
                    Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()),
                result: WidgetInsightsLogic.SpendingComparison(previousToDate: 3_690, change: -440),
                previousCumulative: previous),
            dailyAverage: 171,
            periodDays: 30
        )
    }
}

/// Lo gastado en el período anterior hasta la misma fecha, y su curva entera (la línea punteada).
struct ExpenseComparison {
    /// «octubre», «2025»: cómo se nombra el período anterior.
    let previousLabel: String
    /// Si el anterior es un año: el texto de «a esta fecha» cambia con él en algunos idiomas («im Oktober» / «2025»).
    var previousIsYear: Bool = false
    /// La cuenta de `WidgetInsightsLogic.spendingComparison`: lo gastado entonces a la misma fecha y la diferencia.
    let result: WidgetInsightsLogic.SpendingComparison
    /// Acumulado por día del período anterior completo.
    let previousCumulative: [Double]

    var previousToDate: Double { result.previousToDate }
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
        return Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date)))
    }

    private func createEntry(for configuration: ExpenseWidgetIntent) -> ExpenseEntry {
        let currency = WidgetDataService.getPreferredCurrency()
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()
        let period = configuration.period.toWidgetPeriod
        let now = Date()
        let lastUpdated = WidgetDataService.getLastUpdated()
        // Las cifras de la foto se calcularon cuando la app la escribió: el período, los días que van y la comparación se
        // miden a esa hora. Con el reloj de ahora, una foto de ayer cruzaba meses (a medianoche del día 1, «Este mes» era
        // noviembre y el gasto, el de octubre).
        let asOf = lastUpdated ?? now
        let calendar = WidgetDataService.widgetConfiguredCalendar()

        let summary = WidgetDataService.calculateSummary(for: period)
        let totalExpense = summary?.totalExpense ?? 0
        let interval = period.dateInterval(now: asOf)
        let daily = (summary?.cashFlowPoints ?? []).map { (date: $0.date, value: $0.expense) }
        // «Todo el tiempo» empieza diez años atrás: la curva y el promedio arrancan en el primer movimiento.
        let start = period == .allTime
            ? (daily.map(\.date).min().map { calendar.startOfDay(for: $0) } ?? interval.start)
            : interval.start
        // El ancho de la gráfica es el período ENTERO (el mes, la semana, el año): la línea llega hasta hoy y el resto
        // queda por delante. El intervalo de un período en curso acaba hoy a las 23:59:59, que no sirve para esto.
        let periodDays = WidgetInsightsLogic.daysElapsed(
            from: start, to: Self.fullPeriodEnd(for: period, interval: interval, asOf: asOf, calendar: calendar),
            calendar: calendar)
        let elapsedDays = min(WidgetInsightsLogic.daysElapsed(from: start, to: min(interval.end, asOf), calendar: calendar),
                              periodDays)

        // Acumulado día a día hasta la foto (o hasta el cierre, en un período pasado).
        let cumulative = WidgetInsightsLogic.cumulativeByDay(daily, start: start, days: elapsedDays, calendar: calendar)
        let trend = cumulative.enumerated().compactMap { index, value -> WidgetTrendPoint? in
            guard let day = calendar.date(byAdding: .day, value: index, to: calendar.startOfDay(for: start)) else { return nil }
            return WidgetTrendPoint(date: day, balance: value)
        }

        return ExpenseEntry(
            date: now,
            totalExpense: totalExpense,
            currencyCode: currency,
            currencyDisplayFormat: displayFormat,
            trendData: trend,
            isPlaceholder: false,
            period: configuration.period,
            expenseIsApproximate: summary?.expenseIsApproximate ?? false,
            comparison: Self.comparison(for: period, current: totalExpense, asOf: asOf, calendar: calendar),
            dailyAverage: WidgetInsightsLogic.dailyAverage(
                total: totalExpense, start: start, end: interval.end, now: asOf, calendar: calendar),
            periodDays: periodDays,
            lastUpdated: lastUpdated
        )
    }

    /// El último instante del período entero: la semana, el mes o el año de calendario en curso; en los demás, el final
    /// de su intervalo.
    static func fullPeriodEnd(for period: WidgetPeriod, interval: DateInterval, asOf: Date, calendar: Calendar) -> Date {
        let component: Calendar.Component
        switch period {
        case .thisWeek: component = .weekOfYear
        case .thisMonth: component = .month
        case .thisYear: component = .year
        default: return interval.end
        }
        guard let whole = calendar.dateInterval(of: component, for: asOf) else { return interval.end }
        return whole.end.addingTimeInterval(-1)
    }

    /// Solo los períodos en curso que tienen un «anterior» en la foto: el mes y el año.
    static func comparison(for period: WidgetPeriod, current: Double, asOf: Date, calendar: Calendar) -> ExpenseComparison? {
        let previousPeriod: WidgetPeriod
        switch period {
        case .thisMonth: previousPeriod = .lastMonth
        case .thisYear: previousPeriod = .lastYear
        default: return nil
        }
        guard let previous = WidgetDataService.calculateSummary(for: previousPeriod) else { return nil }
        let previousInterval = previousPeriod.dateInterval(now: asOf)
        let previousDaily = previous.cashFlowPoints.map { (date: $0.date, expense: $0.expense) }
        guard let result = WidgetInsightsLogic.spendingComparison(
            current: current,
            previousDaily: previousDaily,
            previousStart: previousInterval.start,
            currentStart: period.dateInterval(now: asOf).start,
            now: asOf,
            calendar: calendar
        ) else { return nil }
        let previousDays = WidgetInsightsLogic.daysElapsed(from: previousInterval.start, to: previousInterval.end, calendar: calendar)
        let isYear = period == .thisYear
        return ExpenseComparison(
            previousLabel: isYear ? WidgetDateText.year(previousInterval.start) : WidgetDateText.monthName(previousInterval.start),
            previousIsYear: isYear,
            result: result,
            previousCumulative: WidgetInsightsLogic.cumulativeByDay(
                previousDaily.map { (date: $0.date, value: $0.expense) },
                start: previousInterval.start, days: previousDays, calendar: calendar)
        )
    }
}

// MARK: - Widget Views

struct ExpenseWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: ExpenseEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumExpenseView(entry: entry)
        default:
            SmallExpenseView(entry: entry)
        }
    }
}

private extension ExpenseEntry {
    var title: String { String(localized: "widget.ui.expenses", bundle: .main) }
    var periodName: String { period.toWidgetPeriod.localizedDisplayName }

    /// La diferencia contra el anterior a la misma fecha, en proporción; `nil` sin comparación o si entonces no se
    /// había gastado nada. La cuenta es la de `WidgetInsightsLogic.SpendingComparison`.
    var changeFraction: Double? { comparison?.result.fraction }

    /// En un gasto, subir es malo (rosa) y bajar, bueno (índigo): los colores de `VariationChip`. Menos de un 1 % es
    /// «igual».
    var changeTone: WidgetTone {
        guard let fraction = changeFraction, abs(fraction) >= 0.01 else { return .neutral }
        return fraction > 0 ? .bad : .good
    }

    /// Hay gráfica con un día de datos (el día 1 ya tiene su punto) o con la curva del período anterior.
    var hasChart: Bool { !trendData.isEmpty || comparison != nil }

    func amountText(_ value: Double) -> String {
        WidgetAmountSplitter.split(
            value: value,
            symbol: CurrencySymbols.display(for: currencyCode, format: currencyDisplayFormat),
            fractionDigits: 0
        ).accessibilityFormatted
    }
}

/// «▲ 21 % vs. octubre», o «S/ 308 al día» cuando no hay con qué comparar.
private struct ExpenseComparisonLine: View {
    let entry: ExpenseEntry

    var body: some View {
        if let comparison = entry.comparison, let fraction = entry.changeFraction {
            HStack(spacing: WidgetDS.Spacing.xs) {
                WidgetPill(
                    text: abs(fraction).formatted(.percent.precision(.fractionLength(0))),
                    systemImage: entry.changeTone == .neutral ? "equal" : (fraction > 0 ? "arrow.up" : "arrow.down"),
                    tone: entry.changeTone
                )
                Text(String(format: String(localized: "widget.expense.vsPrevious", bundle: .main), comparison.previousLabel))
                    .font(WidgetDS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(
                format: String(localized: "widget.expense.comparison.a11y", bundle: .main),
                (fraction >= 0 ? "+" : "-") + abs(fraction).formatted(.percent.precision(.fractionLength(0))),
                comparison.previousLabel)))
        } else {
            Text(String(format: String(localized: "widget.expense.perDay", bundle: .main), entry.amountText(entry.dailyAverage)))
                .font(WidgetDS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

struct SmallExpenseView: View {
    let entry: ExpenseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
            WidgetCardHeader(title: entry.title, systemImage: "arrow.down.right", tint: WidgetColors.hotPink)

            Spacer(minLength: WidgetDS.Spacing.xs)

            WidgetHeroAmount(
                value: entry.totalExpense,
                currencyCode: entry.currencyCode,
                displayFormat: entry.currencyDisplayFormat,
                isEstimate: entry.expenseIsApproximate
            )

            ExpenseComparisonLine(entry: entry)
                .padding(.top, WidgetDS.Spacing.xxs)

            if entry.hasChart {
                ExpensePaceChart(entry: entry)
                    .frame(height: WidgetDS.Chart.sparklineHeight)
                    .padding(.top, WidgetDS.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: WidgetDeepLink.expenses))
    }
}

struct MediumExpenseView: View {
    let entry: ExpenseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
            WidgetCardHeader(title: entry.title, systemImage: "arrow.down.right", tint: WidgetColors.hotPink) {
                WidgetHeaderDetail(text: entry.periodName)
            }

            HStack(alignment: .bottom, spacing: WidgetDS.Spacing.lg) {
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.xs) {
                    Spacer(minLength: 0)
                    WidgetHeroAmount(
                        value: entry.totalExpense,
                        currencyCode: entry.currencyCode,
                        displayFormat: entry.currencyDisplayFormat,
                        isEstimate: entry.expenseIsApproximate
                    )
                    ExpenseComparisonLine(entry: entry)
                    if let comparison = entry.comparison {
                        Text(String(
                            format: comparison.previousIsYear
                                ? String(localized: "widget.expense.previousToDate.year", bundle: .main)
                                : String(localized: "widget.expense.previousToDate", bundle: .main),
                            comparison.previousLabel, entry.amountText(comparison.previousToDate)))
                            .font(WidgetDS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    WidgetFreshnessNote(lastUpdated: entry.lastUpdated, now: entry.date)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if entry.hasChart {
                    ExpensePaceChart(entry: entry)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("widget.ui.noExpenses", bundle: .main)
                        .font(WidgetDS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: WidgetDeepLink.expenses))
    }
}

/// El ritmo del gasto: lo acumulado este período (rosa, hasta hoy) contra el período anterior entero (gris punteado),
/// sobre el mismo eje de días. Si la línea rosa va por debajo de la gris, se va gastando menos que entonces. El año se
/// dibuja por semanas para que la gráfica no cargue 730 puntos. En tintado no se tiñe: lo teñido es la cifra.
struct ExpensePaceChart: View {
    let entry: ExpenseEntry

    private var step: Int { entry.periodDays > 62 ? 7 : 1 }

    private func sampled(_ values: [Double]) -> [(day: Int, value: Double)] {
        guard !values.isEmpty else { return [] }
        var points = stride(from: 0, to: values.count, by: step).map { (day: $0, value: values[$0]) }
        if points.last?.day != values.count - 1 { points.append((day: values.count - 1, value: values[values.count - 1])) }
        return points
    }

    var body: some View {
        let current = sampled(entry.trendData.map(\.balance))
        let previous = sampled(entry.comparison?.previousCumulative ?? [])
        let top = max(current.map(\.value).max() ?? 0, previous.map(\.value).max() ?? 0, 1) * 1.1
        // Índices de día, no número de puntos muestreados: el año se dibuja por semanas pero llega al día 365.
        let lastDay = max(entry.periodDays, entry.comparison?.previousCumulative.count ?? 0, entry.trendData.count, 2) - 1

        Chart {
            ForEach(previous, id: \.day) { point in
                LineMark(x: .value("Día", point.day), y: .value("Gasto", point.value), series: .value("Serie", "anterior"))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: WidgetDS.Chart.referenceLineWidth, lineCap: .round,
                                           dash: WidgetDS.Chart.referenceDash))
                    .foregroundStyle(Color.secondary)
            }
            ForEach(current, id: \.day) { point in
                AreaMark(x: .value("Día", point.day), y: .value("Gasto", point.value), series: .value("Serie", "actual"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(WidgetColors.hotPink.opacity(WidgetDS.Opacity.subtle))
                LineMark(x: .value("Día", point.day), y: .value("Gasto", point.value), series: .value("Serie", "actual"))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: WidgetDS.Chart.lineWidth, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(WidgetColors.hotPink)
            }
            if let last = current.last {
                PointMark(x: .value("Día", last.day), y: .value("Gasto", last.value))
                    .symbolSize(WidgetDS.Chart.pointArea)
                    .foregroundStyle(WidgetColors.hotPink)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartXScale(domain: 0...lastDay)
        .chartYScale(domain: 0...top)
        .accessibilityHidden(true)
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
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(WidgetColors.cardBackground, for: .widget)
        }
        .configurationDisplayName("widget.gallery.expense")
        .description("widget.gallery.expense.desc")
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
