//
//  MonthSummaryWidget.swift
//  YalaWidgets
//
//  Widget extragrande: el mes en una pieza — disponible, gasto del mes repartido por categoría y los
//  presupuestos más apretados. En iPad, el apaisado (`systemExtraLarge`); en el iPhone con iOS 27, el
//  vertical (`systemExtraLargePortrait`, `MonthSummaryPortraitView`), que suma ingresos y neto. Rediseño 2.2,
//  tanda 2: piezas de la tanda 1, aro sólido con importes en la leyenda y enlaces sin el tinte azul de `Link`.
//
//  No añade nada al DTO del App Group: todo sale de campos que ya viajan
//  (`periodSummaries` / `thisMonthSummary`, `budgets`). Así un widget nuevo no puede apagar a los
//  que ya existen por un `keyNotFound` en el snapshot.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct MonthSummaryEntry: TimelineEntry {
    let date: Date
    let balance: Double
    let balanceIsApproximate: Bool
    let totalExpense: Double
    let expenseIsApproximate: Bool
    let categories: [WidgetCategory]
    let budgets: [WidgetBudget]
    let currencyCode: String
    let currencyDisplayFormat: String
    let isPlaceholder: Bool
    /// Ingresos y neto del mes: solo los pinta el extragrande vertical. Al final y con default para que el placeholder
    /// y las previews del de iPad no tengan que declararlos.
    var totalIncome: Double = 0
    var incomeIsApproximate: Bool = false
    var netCashFlow: Double = 0
    var netCashFlowIsApproximate: Bool = false
    /// Modo «Solo gastos»: el vertical no enseña ingresos ni neto, como el resto de widgets.
    var isExpensesOnly: Bool = false
    /// Cuándo escribió la app la foto: el ritmo de los presupuestos se mide a esa hora.
    var lastUpdated: Date? = nil

    /// Categorías que caben en la leyenda; el resto se agrupa en «Otros».
    static let categoryLimit = 5
    /// Presupuestos que caben en su columna a la altura del extragrande de iPad.
    static let budgetLimit = 4

    static var placeholder: MonthSummaryEntry {
        MonthSummaryEntry(
            date: Date(),
            balance: 12_480,
            balanceIsApproximate: false,
            totalExpense: 3_250,
            expenseIsApproximate: false,
            categories: [
                WidgetCategory(id: "1", name: "Alimentación", iconName: "fork.knife", colorHex: "6366F1", amount: 1_100, percentage: 34),
                WidgetCategory(id: "2", name: "Transporte", iconName: "car.fill", colorHex: "FF0080", amount: 650, percentage: 20),
                WidgetCategory(id: "3", name: "Servicios", iconName: "bolt.fill", colorHex: "00C2CB", amount: 520, percentage: 16),
                WidgetCategory(id: "4", name: "Entretenimiento", iconName: "gamecontroller.fill", colorHex: "F59E0B", amount: 430, percentage: 13),
                WidgetCategory(id: "5", name: "Salud", iconName: "heart.fill", colorHex: "EF4444", amount: 300, percentage: 9),
                WidgetCategory(id: "others", name: "Otros", iconName: "ellipsis.circle", colorHex: "6B7280", amount: 250, percentage: 8)
            ],
            budgets: Array(BudgetsEntry.placeholder.budgets.prefix(budgetLimit)),
            currencyCode: "PEN",
            currencyDisplayFormat: "symbol",
            isPlaceholder: true,
            totalIncome: 5_200,
            netCashFlow: 1_950
        )
    }
}

// MARK: - Timeline Provider

struct MonthSummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> MonthSummaryEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (MonthSummaryEntry) -> Void) {
        completion(context.isPreview ? .placeholder : createEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MonthSummaryEntry>) -> Void) {
        let entry = createEntry()
        // Medianoche o +4 h: el día 1 el mes cambia y el resumen tiene que cambiar con él.
        completion(Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date))))
    }

    private func createEntry() -> MonthSummaryEntry {
        let summary = WidgetDataService.calculateSummary(for: .thisMonth)
        let totalExpense = summary?.totalExpense ?? 0
        let isExpensesOnly = WidgetDataService.isExpensesOnlyMode

        return MonthSummaryEntry(
            date: Date(),
            balance: WidgetDataService.getBalance(for: .thisMonth),
            balanceIsApproximate: WidgetDataService.getBalanceIsApproximate(for: .thisMonth),
            totalExpense: totalExpense,
            expenseIsApproximate: summary?.expenseIsApproximate ?? false,
            categories: Self.groupCategories(summary?.topCategories ?? [], totalExpense: totalExpense),
            budgets: Array(
                WidgetDataService.getBudgets(sortByCritical: true)
                    .prefix(max(MonthSummaryEntry.budgetLimit, MonthSummaryPortraitView.budgetLimit))
            ),
            currencyCode: WidgetDataService.getPreferredCurrency(),
            currencyDisplayFormat: WidgetDataService.getCurrencyDisplayFormat(),
            isPlaceholder: false,
            totalIncome: isExpensesOnly ? 0 : (summary?.totalIncome ?? 0),
            incomeIsApproximate: isExpensesOnly ? false : (summary?.incomeIsApproximate ?? false),
            netCashFlow: summary?.netCashFlow ?? 0,
            netCashFlowIsApproximate: summary?.netCashFlowIsApproximate ?? false,
            isExpensesOnly: isExpensesOnly,
            lastUpdated: WidgetDataService.getLastUpdated()
        )
    }

    /// Las `categoryLimit` primeras y, si sobran, una tajada «Otros» con el resto — el mismo
    /// criterio que el donut grande de Categorías, a otra escala.
    static func groupCategories(_ categories: [WidgetCategory], totalExpense: Double) -> [WidgetCategory] {
        let limit = MonthSummaryEntry.categoryLimit
        guard categories.count > limit else { return categories }
        let othersAmount = categories.dropFirst(limit).reduce(0) { $0 + $1.amount }
        let othersPercentage = totalExpense > 0 ? (othersAmount / totalExpense) * 100 : 0
        return Array(categories.prefix(limit)) + [
            WidgetCategory(
                id: "others",
                name: String(localized: "widget.ui.others", bundle: .main),
                iconName: "ellipsis.circle",
                colorHex: "6B7280",
                amount: othersAmount,
                percentage: othersPercentage
            )
        ]
    }
}

// MARK: - Widget View

struct MonthSummaryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: MonthSummaryEntry

    var body: some View {
        if family.isExtraLargePortrait {
            MonthSummaryPortraitView(entry: entry)
        } else {
            landscape
        }
    }

    /// El de iPad (`systemExtraLarge`): dos columnas, gasto a la izquierda y presupuestos a la derecha.
    private var landscape: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
            MonthSummaryHeader()

            HStack(alignment: .top, spacing: WidgetDS.Spacing.xl) {
                WidgetPlainLink(destination: MonthSummaryLinks.url("statistics/categories")) {
                    VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
                        HStack(alignment: .top, spacing: WidgetDS.Spacing.xl) {
                            MonthSummaryFigure(label: "widget.ui.available", value: entry.balance,
                                               entry: entry, isEstimate: entry.balanceIsApproximate)
                            MonthSummaryFigure(label: "widget.ui.spent", value: entry.totalExpense,
                                               entry: entry, isEstimate: entry.expenseIsApproximate)
                            Spacer(minLength: 0)
                        }
                        MonthSummaryCategories(entry: entry)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Divider()

                WidgetPlainLink(destination: MonthSummaryLinks.url("budgets")) {
                    MonthSummaryBudgets(entry: entry, limit: MonthSummaryEntry.budgetLimit)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }
}

// MARK: - Piezas compartidas por los dos tamaños

/// Insignia del calendario, «Resumen del mes» y el mes.
struct MonthSummaryHeader: View {
    var body: some View {
        WidgetCardHeader(
            title: String(localized: "widget.ui.monthSummary", bundle: .main),
            systemImage: "calendar",
            tint: WidgetColors.electricIndigo
        ) {
            WidgetHeaderDetail(text: WidgetPeriod.thisMonth.localizedDisplayName)
        }
    }
}

/// Una cifra del mes con su rótulo gris encima. Solo el ingreso lleva color de texto (`incomeText`).
struct MonthSummaryFigure: View {
    let label: LocalizedStringKey
    let value: Double
    let entry: MonthSummaryEntry
    var isEstimate: Bool = false
    var tint: WidgetAmountText.Tint = .primary
    var forceSign: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
            Text(label, bundle: .main)
                .font(WidgetDS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            WidgetAmountText(
                value: value,
                currencyCode: entry.currencyCode,
                displayFormat: entry.currencyDisplayFormat,
                font: WidgetDS.Typography.title2,
                secondaryFont: WidgetDS.Typography.caption,
                tint: tint,
                forceSign: forceSign,
                isEstimate: isEstimate
            )
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .widgetNumericTransition(value)
        }
        .accessibilityElement(children: .combine)
    }
}

/// El gasto del mes por categoría: el aro y, al lado, cada categoría con su importe y su porcentaje.
struct MonthSummaryCategories: View {
    let entry: MonthSummaryEntry

    var body: some View {
        if entry.categories.isEmpty {
            Text("widget.ui.noExpenses", bundle: .main)
                .font(WidgetDS.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .center, spacing: WidgetDS.Spacing.md) {
                WidgetDonut(slices: entry.categories.map {
                    WidgetDonutSlice(id: $0.id, value: $0.amount, color: WidgetColors.fill(hex: $0.colorHex))
                }) {
                    EmptyView()
                }
                .frame(width: WidgetDS.Chart.donutSize, height: WidgetDS.Chart.donutSize)

                VStack(alignment: .leading, spacing: WidgetDS.Spacing.xs) {
                    ForEach(entry.categories, id: \.id) { category in
                        MonthSummaryCategoryRow(category: category, entry: entry)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Una categoría de la leyenda: punto de su color, nombre, importe y porcentaje.
struct MonthSummaryCategoryRow: View {
    let category: WidgetCategory
    let entry: MonthSummaryEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: WidgetDS.Spacing.xs) {
            Circle()
                .fill(WidgetColors.fill(hex: category.colorHex))
                .frame(width: WidgetDS.Chart.legendDot, height: WidgetDS.Chart.legendDot)
                .accessibilityHidden(true)

            Text(category.name)
                .font(WidgetDS.Typography.labelSmall)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: WidgetDS.Spacing.xs)

            WidgetAmountText(
                value: category.amount,
                currencyCode: entry.currencyCode,
                displayFormat: entry.currencyDisplayFormat,
                font: WidgetDS.Typography.labelSmall,
                secondaryFont: WidgetDS.Typography.captionSmall
            )
            .lineLimit(1)
            .fixedSize()

            Text((category.percentage / 100).formatted(.percent.precision(.fractionLength(0))))
                .font(WidgetDS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Los presupuestos más apretados, con la fila de Presupuestos (`BudgetRowView`): «Te quedan / Te pasaste por», la
/// barra y la marca del ritmo del mes.
struct MonthSummaryBudgets: View {
    let entry: MonthSummaryEntry
    let limit: Int
    /// En la columna del iPad, la sección ocupa el alto y deja el hueco abajo; en el vertical, mide lo suyo.
    var fillsHeight: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
            Text("widget.ui.budgets", bundle: .main)
                .font(WidgetDS.Typography.labelSmall)
                .foregroundStyle(.secondary)

            if entry.budgets.isEmpty {
                Text("widget.ui.noBudgets", bundle: .main)
                    .font(WidgetDS.Typography.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.budgets.prefix(limit), id: \.id) { budget in
                    BudgetRowView(
                        budget: budget,
                        displayFormat: entry.currencyDisplayFormat,
                        asOf: entry.lastUpdated ?? entry.date
                    )
                }
            }

            if fillsHeight { Spacer(minLength: 0) }
        }
    }
}

enum MonthSummaryLinks {
    /// `Link` exige una URL no opcional. Si el helper no pudiera formarla, el toque cae en el Panel
    /// como el del resto del widget.
    static func url(_ path: String) -> URL {
        if let url = WidgetURLHelper.url(for: path) { return url }
        if let panel = WidgetURLHelper.url(for: "panel") { return panel }
        return URL(fileURLWithPath: "/")
    }
}

// MARK: - Widget Definition

struct MonthSummaryWidget: Widget {
    let kind: String = "MonthSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MonthSummaryProvider()) { entry in
            MonthSummaryWidgetView(entry: entry)
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder)
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(WidgetColors.cardBackground, for: .widget)
        }
        .configurationDisplayName("widget.gallery.monthSummary")
        .description("widget.gallery.monthSummary.desc")
        .supportedFamilies(WidgetFamilies.addingExtraLargePortrait([.systemExtraLarge]))
    }
}

// MARK: - Previews

#Preview("Extra Large", as: .systemExtraLarge) {
    MonthSummaryWidget()
} timeline: {
    MonthSummaryEntry.placeholder
}

#Preview("Empty", as: .systemExtraLarge) {
    MonthSummaryWidget()
} timeline: {
    MonthSummaryEntry(
        date: Date(),
        balance: 0,
        balanceIsApproximate: false,
        totalExpense: 0,
        expenseIsApproximate: false,
        categories: [],
        budgets: [],
        currencyCode: "PEN",
        currencyDisplayFormat: "symbol",
        isPlaceholder: false
    )
}
