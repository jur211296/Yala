//
//  MonthSummaryWidget.swift
//  YalaWidgets
//
//  Widget extragrande: el mes en una pieza — balance, gasto del mes repartido por categoría y los
//  presupuestos más apretados. En iPad, el apaisado (`systemExtraLarge`); en el iPhone con iOS 27, el
//  vertical (`systemExtraLargePortrait`, `MonthSummaryPortraitView`), que suma ingresos y neto.
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

    /// Categorías que caben en la leyenda; el resto se agrupa en «Otros».
    static let categoryLimit = 5
    /// Presupuestos que caben en su columna a la altura del extragrande.
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
        // Cada 4 horas, y a medianoche: el día 1 el mes cambia y el resumen tiene que cambiar con él.
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let fourHours = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(min(midnight, fourHours))))
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
                WidgetDataService.getBudgets(sortByCritical: true).prefix(MonthSummaryEntry.budgetLimit)
            ),
            currencyCode: WidgetDataService.getPreferredCurrency(),
            currencyDisplayFormat: WidgetDataService.getCurrencyDisplayFormat(),
            isPlaceholder: false,
            totalIncome: isExpensesOnly ? 0 : (summary?.totalIncome ?? 0),
            incomeIsApproximate: isExpensesOnly ? false : (summary?.incomeIsApproximate ?? false),
            netCashFlow: summary?.netCashFlow ?? 0,
            netCashFlowIsApproximate: summary?.netCashFlowIsApproximate ?? false,
            isExpensesOnly: isExpensesOnly
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
        VStack(alignment: .leading, spacing: WDS.Spacing.lg) {
            WidgetHeader(
                title: String(localized: "widget.ui.monthSummary", bundle: .main),
                subtitle: WidgetPeriod.thisMonth.localizedDisplayName,
                icon: "calendar"
            )

            HStack(alignment: .top, spacing: WDS.Spacing.xl) {
                Link(destination: MonthSummaryLinks.url("statistics/categories")) {
                    spendingColumn
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Divider()

                Link(destination: MonthSummaryLinks.url("budgets")) {
                    budgetsColumn
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }

    // MARK: Columna izquierda: balance, gasto y su reparto

    private var spendingColumn: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.lg) {
            HStack(alignment: .top, spacing: WDS.Spacing.xl) {
                kpi(
                    label: "widget.ui.balance",
                    value: entry.balance,
                    tint: .primary,
                    isEstimate: entry.balanceIsApproximate
                )
                kpi(
                    label: "widget.ui.expenses",
                    value: entry.totalExpense,
                    tint: WidgetColors.expense,
                    isEstimate: entry.expenseIsApproximate
                )
                Spacer(minLength: 0)
            }

            if entry.categories.isEmpty {
                MonthSummaryEmptyState(icon: "chart.pie", text: "widget.ui.noExpenses")
            } else {
                HStack(alignment: .center, spacing: WDS.Spacing.lg) {
                    WidgetSectorChart(
                        segments: entry.categories.map { category in
                            WidgetSectorSegment(
                                id: category.id,
                                name: category.name,
                                iconName: category.iconName,
                                amount: category.amount,
                                percentage: category.percentage,
                                colorHex: category.colorHex
                            )
                        },
                        innerRadiusRatio: 0.55,
                        showBubbles: false
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 130, maxHeight: 130)

                    VStack(alignment: .leading, spacing: WDS.Spacing.sm) {
                        ForEach(entry.categories, id: \.id) { category in
                            MonthSummaryCategoryRow(category: category)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func kpi(label: LocalizedStringKey, value: Double, tint: Color, isEstimate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label, bundle: .main)
                .font(WDS.Typography.tiny)
                .foregroundStyle(.secondary)
            WidgetKPI(
                amount: value,
                currencyCode: entry.currencyCode,
                displayFormat: entry.currencyDisplayFormat,
                color: tint,
                size: .medium,
                isEstimate: isEstimate
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    // MARK: Columna derecha: presupuestos

    private var budgetsColumn: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.md) {
            Text("widget.ui.budgets", bundle: .main)
                .font(WDS.Typography.label)
                .foregroundStyle(.secondary)

            if entry.budgets.isEmpty {
                MonthSummaryEmptyState(icon: "chart.pie", text: "widget.ui.noBudgets")
            } else {
                ForEach(entry.budgets.prefix(MonthSummaryEntry.budgetLimit), id: \.id) { budget in
                    MonthSummaryBudgetRow(budget: budget, displayFormat: entry.currencyDisplayFormat)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Piezas compartidas por los dos tamaños


/// La fila de presupuesto de ANTES del rediseño 2.2, que solo usa el Resumen del mes hasta su tanda (S35f1): así ese
/// widget no cambia sin sus capturas. La retira esa tanda.
struct MonthSummaryBudgetRow: View {
    let budget: WidgetBudget
    let displayFormat: String

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.xxs) {
            // Row 1: Icon + Name + %
            HStack(spacing: WDS.Spacing.sm) {
                // Icon badge compacto
                ZStack {
                    Circle()
                        .fill(budgetColor.opacity(0.2))
                        .frame(width: WDS.ListItem.iconSizeCompact,
                               height: WDS.ListItem.iconSizeCompact)

                    Image(systemName: budget.iconName ?? "chart.pie.fill")
                        .font(.system(size: WDS.Icon.sm)) // A11Y-DT: widget fixed layout
                        .foregroundStyle(budgetColor)
                        .widgetAccentable()
                }

                Text(budget.name)
                    .font(WDS.Typography.label)
                    .lineLimit(1)

                Spacer()

                // Spent/Limit compact con jerarquía visual: símbolo subordinado.
                // Caso especial — el formato compuesto "S/720/800" no encaja en
                // WidgetAmountText (que asume un solo número). HStack manual de 2 runs.
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(currencySymbol)
                        .font(WDS.Typography.valueSecondary)
                        .foregroundStyle(.tertiary)
                    Text(amountRatio)
                        .font(WDS.Typography.tiny)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)

                Text("\(Int(budget.percentUsed))%")
                    .font(WDS.Typography.labelSmall)
                    .foregroundStyle(progressColor)
                    .fixedSize(horizontal: true, vertical: false)
                    .widgetAccentable()
            }

            // Row 2: Progress bar alineada con texto
            WidgetProgressBar.budget(
                percentUsed: budget.percentUsed,
                height: WDS.Progress.heightCompact
            )
            .padding(.leading, WDS.ListItem.iconSizeCompact + WDS.Spacing.sm)
        }
    }

    private var budgetColor: Color {
        Color(hex: budget.colorHex ?? "#6366F1")
    }

    private var progressColor: Color {
        WidgetColors.forBudget(percentUsed: budget.percentUsed)
    }

    private var currencySymbol: String {
        displayFormat == "symbol"
            ? CurrencySymbols.symbol(for: budget.currencyCode)
            : budget.currencyCode
    }

    private var amountRatio: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let spent = formatter.string(from: NSNumber(value: budget.spentAmount)) ?? "0"
        let limit = formatter.string(from: NSNumber(value: budget.limitAmount)) ?? "0"
        return "\(spent)/\(limit)"
    }
}


/// Una categoría de la leyenda: punto de color, nombre y porcentaje.
struct MonthSummaryCategoryRow: View {
    let category: WidgetCategory

    var body: some View {
        HStack(spacing: WDS.Spacing.sm) {
            Circle()
                .fill(Color(hex: category.colorHex))
                .frame(width: 8, height: 8)
                .widgetAccentable()

            Text(category.name)
                .font(WDS.Typography.label)
                .lineLimit(1)

            Spacer(minLength: WDS.Spacing.xs)

            Text("\(Int(category.percentage.rounded()))%")
                .font(WDS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize()
        }
    }
}

struct MonthSummaryEmptyState: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: WDS.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2) // A11Y-DT: widget empty state icon
                .foregroundStyle(.tertiary)
            Text(text, bundle: .main)
                .font(WDS.Typography.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .containerBackground(Color(.secondarySystemGroupedBackground), for: .widget)
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
