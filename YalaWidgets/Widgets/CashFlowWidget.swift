//
//  CashFlowWidget.swift
//  YalaWidgets
//
//  «Entradas y salidas»: lo que entró, lo que salió y lo que queda (el neto) en el período elegido. Rediseño 2.2,
//  tanda 2 (`docs/widgets/AUDITORIA-WIDGETS-2-2.md`): el neto es la cifra grande, con la comparación con el período
//  anterior a la misma fecha; ingresos y gastos van en dos barras sólidas (turquesa y rosa de marca) y, en el grande y en
//  el extragrande vertical (`CashFlowPortraitView`), lo de cada día (o mes) en barras sin ejes: lo que entró hacia
//  arriba y lo que salió hacia abajo.
//
//  En «Solo gastos» la cifra grande es lo gastado y no hay ingresos ni comparación del neto: va el promedio diario.
//

import WidgetKit
import SwiftUI
import AppIntents
import Charts

// MARK: - Configuration Intent

struct CashFlowWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.cashFlow.title" }
    static var description: IntentDescription { "widget.intent.cashFlow.desc" }

    @Parameter(title: "widget.period.type", default: .sameAsApp)
    var period: WidgetPeriodOption

}

// MARK: - Timeline Entry

/// Lo que entró y salió en un día (o un mes) del período: una barra de la gráfica.
struct WidgetFlowBucket: Identifiable {
    let index: Int
    let income: Double
    let expense: Double
    var id: Int { index }
    /// La banda de la gráfica.
    var key: String { String(index) }
}

/// El neto del período anterior a la misma fecha y la diferencia (`WidgetInsightsLogic.flowComparison`).
struct CashFlowComparison {
    /// «setiembre», «2025»: cómo se nombra el período anterior.
    let previousLabel: String
    var previousIsYear: Bool = false
    let result: WidgetInsightsLogic.FlowComparison
}

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
    /// Las marcas «≈», una por número. Van **al final y con default** para que placeholders y
    /// previews —que muestran cifras inventadas y exactas— no tengan que declararlas.
    var incomeIsApproximate: Bool = false
    var expenseIsApproximate: Bool = false
    var netCashFlowIsApproximate: Bool = false
    /// Modo «Solo gastos»: la cifra grande es lo gastado, en positivo, y el rótulo dice «Gastado», como el Panel
    /// (decisión A de Jürgen del 2026-10-26, auditoría «Solo gastos» L4). Antes decía «Flujo neto» con el gasto en
    /// negativo, el único sitio donde ese usuario veía un flujo.
    var isExpensesOnly: Bool = false
    /// El reparto por cuenta del período (solo lo pinta el extragrande vertical). `nil` con una foto anterior a 2.2.
    var accountFlows: [WidgetAccountFlow]? = nil
    /// Las barras de la gráfica: el período entero, un día (o un mes en los períodos de un año o más) por barra.
    var buckets: [WidgetFlowBucket] = []
    /// Comparación del neto con el período anterior a la misma fecha. `nil` fuera de «Este mes» y «Este año», sin datos
    /// del anterior, en «Solo gastos» o con «Comparar con el período anterior» apagado en la app.
    var comparison: CashFlowComparison? = nil
    /// Promedio diario de lo gastado: lo que se enseña en «Solo gastos».
    var dailyAverage: Double = 0
    /// Cuándo escribió la app la foto.
    var lastUpdated: Date? = nil

    /// El rótulo de la cifra grande: `fallbackKey` (flujo neto o flujo de caja, según el tamaño) o «Gastado».
    func kpiTitle(fallbackKey: String.LocalizationValue) -> String {
        isExpensesOnly
            ? String(localized: "widget.ui.spent", bundle: .main)
            : String(localized: fallbackKey, bundle: .main)
    }

    static var placeholder: CashFlowEntry {
        let expenses: [Double] = [120, 60, 540, 60, 60, 140, 450, 70, 90, 180, 370, 90, 90, 360, 100, 60, 70, 290, 130]
        var buckets = expenses.enumerated().map { WidgetFlowBucket(index: $0.offset, income: 0, expense: $0.element) }
        buckets[0] = WidgetFlowBucket(index: 0, income: 4_200, expense: 120)
        buckets[14] = WidgetFlowBucket(index: 14, income: 800, expense: 100)
        buckets += (expenses.count..<30).map { WidgetFlowBucket(index: $0, income: 0, expense: 0) }
        return CashFlowEntry(
            date: Date(),
            totalIncome: 5000.00,
            totalExpense: 3250.00,
            netCashFlow: 1750.00,
            currencyCode: "PEN",
            currencyDisplayFormat: "symbol",
            cashFlowPoints: [],
            isPlaceholder: true,
            period: .thisMonth,
            // Solo lo pinta el extragrande vertical: así su vista previa de la galería enseña el reparto.
            accountFlows: [
                WidgetAccountFlow(id: "1", name: "Cuenta principal", income: 5000, expense: 2590, net: 2410),
                WidgetAccountFlow(id: "2", name: "Tarjeta", income: 0, expense: 515, net: -515),
                WidgetAccountFlow(id: "3", name: "Efectivo", income: 0, expense: 145, net: -145)
            ],
            buckets: buckets,
            comparison: CashFlowComparison(
                previousLabel: WidgetDateText.monthName(
                    Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()),
                result: WidgetInsightsLogic.FlowComparison(previousNetToDate: 1_320, change: 430)),
            dailyAverage: 171
        )
    }
}

// MARK: - Timeline Provider

struct CashFlowWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = CashFlowEntry
    typealias Intent = CashFlowWidgetIntent

    /// Meses que pinta «Todo el tiempo»: los últimos dos años. Más barras no caben con un ancho que se lea.
    static let allTimeMonthLimit = 24

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
        return Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date)))
    }

    private func createEntry(for configuration: CashFlowWidgetIntent) -> CashFlowEntry {
        let currency = WidgetDataService.getPreferredCurrency()
        let displayFormat = WidgetDataService.getCurrencyDisplayFormat()
        let period = configuration.period.toWidgetPeriod
        let isExpensesOnly = WidgetDataService.isExpensesOnlyMode
        let now = Date()
        let lastUpdated = WidgetDataService.getLastUpdated()
        // Las cifras de la foto se calcularon cuando la app la escribió: período, días y comparación se miden a esa hora.
        let asOf = lastUpdated ?? now
        let calendar = WidgetDataService.widgetConfiguredCalendar()

        // Get summary for the period
        let summary = WidgetDataService.calculateSummary(for: period)
        let netCashFlow = isExpensesOnly ? (summary?.totalExpense ?? 0) : (summary?.netCashFlow ?? 0)

        let interval = period.dateInterval(now: asOf)
        let daily = (summary?.cashFlowPoints ?? []).map {
            (date: $0.date, income: isExpensesOnly ? 0 : $0.income, expense: $0.expense)
        }
        // «Todo el tiempo» empieza diez años atrás: las barras arrancan en el primer movimiento.
        // El mismo arranque que Gastos (`ExpenseWidgetProvider`), para que el promedio diario de los dos coincida.
        let start = period == .allTime
            ? (daily.map(\.date).min().map { calendar.startOfDay(for: $0) } ?? interval.start)
            : interval.start
        let byMonth = [.thisYear, .lastYear, .allTime].contains(period)
        var buckets = WidgetInsightsLogic.flowBuckets(
            daily, start: start,
            end: ExpenseWidgetProvider.fullPeriodEnd(for: period, interval: interval, asOf: asOf, calendar: calendar),
            byMonth: byMonth, calendar: calendar)
        if period == .allTime { buckets = Array(buckets.suffix(Self.allTimeMonthLimit)) }

        return CashFlowEntry(
            date: now,
            totalIncome: isExpensesOnly ? 0 : (summary?.totalIncome ?? 0),
            totalExpense: summary?.totalExpense ?? 0,
            netCashFlow: isExpensesOnly ? (summary?.totalExpense ?? 0) : (summary?.netCashFlow ?? 0),
            currencyCode: currency,
            currencyDisplayFormat: displayFormat,
            cashFlowPoints: summary?.cashFlowPoints ?? [],
            isPlaceholder: false,
            period: configuration.period,
            // En Solo Gastos el widget fuerza el ingreso a 0 y la cifra grande al gasto: la marca sigue
            // al número, así que las tres pasan a ser la del gasto. Marcar el «ingreso» de 0 con la
            // señal del ingreso real pondría «≈» sobre un cero.
            incomeIsApproximate: isExpensesOnly ? false : (summary?.incomeIsApproximate ?? false),
            expenseIsApproximate: summary?.expenseIsApproximate ?? false,
            netCashFlowIsApproximate: isExpensesOnly
                ? (summary?.expenseIsApproximate ?? false)
                : (summary?.netCashFlowIsApproximate ?? false),
            isExpensesOnly: isExpensesOnly,
            accountFlows: summary?.accountFlows,
            buckets: buckets.enumerated().map { WidgetFlowBucket(index: $0.offset, income: $0.element.income, expense: $0.element.expense) },
            comparison: isExpensesOnly || !WidgetDataService.showsVariations
                ? nil
                : Self.comparison(for: period, currentNet: netCashFlow, asOf: asOf, calendar: calendar),
            dailyAverage: WidgetInsightsLogic.dailyAverage(
                total: summary?.totalExpense ?? 0, start: start, end: interval.end, now: asOf, calendar: calendar),
            lastUpdated: lastUpdated
        )
    }

    /// Solo los períodos en curso con un «anterior» en la foto: el mes y el año (como Gastos).
    static func comparison(for period: WidgetPeriod, currentNet: Double, asOf: Date, calendar: Calendar) -> CashFlowComparison? {
        let previousPeriod: WidgetPeriod
        switch period {
        case .thisMonth: previousPeriod = .lastMonth
        case .thisYear: previousPeriod = .lastYear
        default: return nil
        }
        guard let previous = WidgetDataService.calculateSummary(for: previousPeriod) else { return nil }
        let previousInterval = previousPeriod.dateInterval(now: asOf)
        guard let result = WidgetInsightsLogic.flowComparison(
            currentNet: currentNet,
            previousDaily: previous.cashFlowPoints.map { (date: $0.date, income: $0.income, expense: $0.expense) },
            previousStart: previousInterval.start,
            currentStart: period.dateInterval(now: asOf).start,
            now: asOf,
            calendar: calendar
        ) else { return nil }
        let isYear = period == .thisYear
        return CashFlowComparison(
            previousLabel: isYear ? WidgetDateText.year(previousInterval.start) : WidgetDateText.monthName(previousInterval.start),
            previousIsYear: isYear,
            result: result
        )
    }
}

// MARK: - Lo común a los tamaños

extension CashFlowEntry {
    var periodName: String { period.toWidgetPeriod.localizedDisplayName }

    /// Subir el neto es bueno (índigo), bajarlo malo (rosa). Menos de medio sol es «igual».
    var changeTone: WidgetTone {
        guard let change = comparison?.result.change, abs(change) >= 0.5 else { return .neutral }
        return change > 0 ? .good : .bad
    }

    func amountText(_ value: Double, forceSign: Bool = false) -> String {
        WidgetAmountSplitter.split(
            value: value,
            symbol: CurrencySymbols.display(for: currencyCode, format: currencyDisplayFormat),
            fractionDigits: 0,
            forceSign: forceSign
        ).accessibilityFormatted
    }

    /// Una cifra con signo dentro de una frase, en el orden de la cifra grande (`WidgetAmountText`: símbolo, signo y
    /// número, «S/ +3,334»), para que las dos formas no convivan en el mismo widget.
    func signedText(_ value: Double) -> String {
        let runs = WidgetAmountSplitter.split(
            value: value,
            symbol: CurrencySymbols.display(for: currencyCode, format: currencyDisplayFormat),
            fractionDigits: 0,
            forceSign: true
        )
        return runs.symbol + " " + runs.sign + runs.integer
    }

    /// Hay algo que pintar en la gráfica.
    var hasMovements: Bool { buckets.contains { $0.income != 0 || $0.expense != 0 } }
}

/// La cifra grande: el neto con su signo («S/ +1,750»), o lo gastado en «Solo gastos».
struct CashFlowHero: View {
    let entry: CashFlowEntry

    var body: some View {
        WidgetHeroAmount(
            value: entry.netCashFlow,
            currencyCode: entry.currencyCode,
            displayFormat: entry.currencyDisplayFormat,
            isEstimate: entry.netCashFlowIsApproximate,
            forceSign: !entry.isExpensesOnly
        )
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// «▲ S/ 430 vs. setiembre» (el neto, a la misma fecha), o «S/ 171 al día» en «Solo gastos». Sin comparación, nada.
struct CashFlowComparisonLine: View {
    let entry: CashFlowEntry

    var body: some View {
        if let comparison = entry.comparison {
            let change = comparison.result.change
            HStack(spacing: WidgetDS.Spacing.xs) {
                WidgetPill(
                    text: entry.amountText(abs(change)),
                    systemImage: entry.changeTone == .neutral ? "equal" : (change > 0 ? "arrow.up" : "arrow.down"),
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
                format: String(localized: "widget.flow.comparison.a11y", bundle: .main),
                entry.amountText(change, forceSign: true), comparison.previousLabel)))
        } else if entry.isExpensesOnly {
            Text(String(format: String(localized: "widget.expense.perDay", bundle: .main), entry.amountText(entry.dailyAverage)))
                .font(WidgetDS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// «Neto en setiembre a esta fecha: S/ +1,320».
struct CashFlowPreviousNote: View {
    let entry: CashFlowEntry

    var body: some View {
        if let comparison = entry.comparison {
            Text(String(
                format: comparison.previousIsYear
                    ? String(localized: "widget.flow.previousToDate.year", bundle: .main)
                    : String(localized: "widget.flow.previousToDate", bundle: .main),
                comparison.previousLabel, entry.signedText(comparison.result.previousNetToDate)))
                .font(WidgetDS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

/// Ingresos y gastos del período: rótulo, importe y una barra sólida proporcional al mayor de los dos. El ingreso es lo
/// único con color en el texto (`incomeText`); las barras llevan los colores de marca como relleno. En «Solo gastos»,
/// solo la de gastos.
struct CashFlowTotals: View {
    let entry: CashFlowEntry
    var compact: Bool = false

    private var scale: Double { max(entry.totalIncome, entry.totalExpense, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? WidgetDS.Spacing.xs : WidgetDS.Spacing.sm) {
            if !entry.isExpensesOnly {
                row(label: String(localized: "widget.ui.income", bundle: .main),
                    value: entry.totalIncome, isEstimate: entry.incomeIsApproximate,
                    fill: WidgetColors.yalaTeal, tint: .color(WidgetColors.incomeText))
            }
            row(label: String(localized: "widget.ui.expenses", bundle: .main),
                value: entry.totalExpense, isEstimate: entry.expenseIsApproximate,
                fill: WidgetColors.hotPink, tint: .primary)
        }
    }

    private func row(label: String, value: Double, isEstimate: Bool, fill: Color, tint: WidgetAmountText.Tint) -> some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: WidgetDS.Spacing.xs) {
                Text(label)
                    .font(compact ? WidgetDS.Typography.captionSmall : WidgetDS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: WidgetDS.Spacing.xs)
                WidgetAmountText(
                    value: value,
                    currencyCode: entry.currencyCode,
                    displayFormat: entry.currencyDisplayFormat,
                    font: compact ? WidgetDS.Typography.labelSmall : WidgetDS.Typography.subheadlineEmphasized,
                    secondaryFont: WidgetDS.Typography.captionSmall,
                    tint: tint,
                    isEstimate: isEstimate
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            CashFlowTotalBar(fraction: value / scale, color: fill,
                             height: compact ? WidgetDS.Sizing.progressBarHeight : WidgetDS.Chart.totalBarHeight)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Carril tenue y relleno sólido. No se tiñe: en tintado lo teñido es la cifra.
struct CashFlowTotalBar: View {
    let fraction: Double
    let color: Color
    let height: CGFloat

    var body: some View {
        Capsule()
            .fill(WidgetColors.track)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(color)
                        .frame(width: max(height, geo.size.width * min(max(fraction, 0), 1)))
                }
            }
            .accessibilityHidden(true)
    }
}

/// Lo de cada día (o mes) del período: lo que entró hacia arriba, en turquesa, y lo que salió hacia abajo, en rosa, sobre
/// una línea de cero. Sin ejes: la escala la dan las cifras de arriba. En «Solo gastos», solo lo gastado y hacia arriba.
struct CashFlowBarsChart: View {
    let entry: CashFlowEntry

    private var expenseSign: Double { entry.isExpensesOnly ? 1 : -1 }

    private var yDomain: ClosedRange<Double> {
        WidgetInsightsLogic.flowChartRange(entry.buckets.map { (income: $0.income, expense: $0.expense) },
                                           expensesUp: entry.isExpensesOnly)
    }

    var body: some View {
        if entry.hasMovements {
            Chart {
                // Sin `if` dentro de la gráfica (un `if/else` de `ChartContent` solo compila en iOS 27): una barra que vale
                // cero no pinta nada, y en «Solo gastos» el ingreso ya llega a cero.
                ForEach(entry.buckets) { bucket in
                    BarMark(x: .value("día", bucket.key), y: .value("entró", bucket.income),
                            width: .ratio(WidgetDS.Chart.dayBarWidthRatio))
                        .foregroundStyle(WidgetColors.yalaTeal)
                        .cornerRadius(WidgetDS.Radius.xs)
                    BarMark(x: .value("día", bucket.key), y: .value("salió", expenseSign * bucket.expense),
                            width: .ratio(WidgetDS.Chart.dayBarWidthRatio))
                        .foregroundStyle(WidgetColors.hotPink)
                        .cornerRadius(WidgetDS.Radius.xs)
                }
                RuleMark(y: .value("cero", 0))
                    .foregroundStyle(WidgetColors.track)
                    .lineStyle(StrokeStyle(lineWidth: WidgetDS.Chart.referenceLineWidth))
            }
            // Eje por categorías (un día, una banda): el ancho `.ratio` de una barra solo existe en un eje de bandas.
            .chartXScale(domain: entry.buckets.map(\.key))
            .chartYScale(domain: yDomain)
            .clipped()
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .accessibilityHidden(true)
        } else {
            Text("widget.ui.notEnoughData", bundle: .main)
                .font(WidgetDS.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// La insignia de la cabecera: dos flechas en turquesa profundo (el relleno AA con blanco encima).
enum CashFlowBadge {
    static let systemImage = "arrow.left.arrow.right"
    static let tint = WidgetColors.tealFill
}

// MARK: - Widget Views

struct CashFlowWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: CashFlowEntry

    var body: some View {
        if family.isExtraLargePortrait {
            CashFlowPortraitView(entry: entry)
        } else {
            sizedView
        }
    }

    @ViewBuilder
    private var sizedView: some View {
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

/// Cabecera, el neto y las dos barras (en «Solo gastos», lo gastado y el promedio diario).
struct SmallCashFlowView: View {
    let entry: CashFlowEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
            WidgetCardHeader(
                title: entry.kpiTitle(fallbackKey: "widget.ui.netFlow"),
                systemImage: CashFlowBadge.systemImage,
                tint: CashFlowBadge.tint
            )

            Spacer(minLength: WidgetDS.Spacing.xs)

            CashFlowHero(entry: entry)

            // El período: la cabecera del pequeño no tiene sitio para él.
            WidgetHeaderDetail(text: entry.periodName)

            if entry.isExpensesOnly {
                CashFlowComparisonLine(entry: entry)
                    .padding(.top, WidgetDS.Spacing.xxs)
            } else {
                CashFlowTotals(entry: entry, compact: true)
                    .padding(.top, WidgetDS.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: WidgetDeepLink.inAndOut))
    }
}

// MARK: - Medium View

/// El neto y su comparación a la izquierda; ingresos y gastos en barras a la derecha.
struct MediumCashFlowView: View {
    let entry: CashFlowEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
            WidgetCardHeader(
                title: entry.kpiTitle(fallbackKey: "widget.ui.cashFlow"),
                systemImage: CashFlowBadge.systemImage,
                tint: CashFlowBadge.tint
            ) {
                WidgetHeaderDetail(text: entry.periodName)
            }

            HStack(alignment: .bottom, spacing: WidgetDS.Spacing.lg) {
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.xs) {
                    Spacer(minLength: 0)
                    CashFlowHero(entry: entry)
                    CashFlowComparisonLine(entry: entry)
                    WidgetFreshnessNote(lastUpdated: entry.lastUpdated, now: entry.date)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if entry.isExpensesOnly {
                    // Lo gastado de cada día: la cifra grande ya es el total.
                    CashFlowBarsChart(entry: entry)
                        .frame(maxWidth: .infinity)
                } else {
                    CashFlowTotals(entry: entry)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: WidgetDeepLink.inAndOut))
    }
}

// MARK: - Large View

/// El neto con su comparación, las dos barras de totales y las barras de cada día.
struct LargeCashFlowView: View {
    let entry: CashFlowEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
            WidgetCardHeader(
                title: entry.kpiTitle(fallbackKey: "widget.ui.cashFlow"),
                systemImage: CashFlowBadge.systemImage,
                tint: CashFlowBadge.tint
            ) {
                WidgetHeaderDetail(text: entry.periodName)
            }

            VStack(alignment: .leading, spacing: WidgetDS.Spacing.xs) {
                CashFlowHero(entry: entry)
                CashFlowComparisonLine(entry: entry)
                CashFlowPreviousNote(entry: entry)
            }

            // En «Solo gastos» la fila de gastos repetiría la cifra grande con la barra llena.
            if !entry.isExpensesOnly {
                CashFlowTotals(entry: entry)
            }

            CashFlowBarsChart(entry: entry)
                .frame(maxHeight: .infinity)

            WidgetFreshnessNote(lastUpdated: entry.lastUpdated, now: entry.date)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: WidgetDeepLink.inAndOut))
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
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(WidgetColors.cardBackground, for: .widget)
        }
        .configurationDisplayName("widget.gallery.cashFlow")
        .description("widget.gallery.cashFlow.desc")
        .supportedFamilies(WidgetFamilies.addingExtraLargePortrait([.systemSmall, .systemMedium, .systemLarge]))
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    CashFlowWidget()
} timeline: {
    CashFlowEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    CashFlowWidget()
} timeline: {
    CashFlowEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    CashFlowWidget()
} timeline: {
    CashFlowEntry.placeholder
}
