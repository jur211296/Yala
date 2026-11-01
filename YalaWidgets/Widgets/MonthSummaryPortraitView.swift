//
//  MonthSummaryPortraitView.swift
//  YalaWidgets
//
//  «Resumen del mes» en el extragrande vertical del iPhone (iOS 27): las cuatro cifras del mes, el gasto por categoría
//  en un aro con su leyenda y los presupuestos más apretados, uno debajo de otro. Lo mismo que el de iPad, recolocado en
//  vertical, con las piezas compartidas de `MonthSummaryWidget.swift`.
//

import SwiftUI
import WidgetKit

struct MonthSummaryPortraitView: View {
    let entry: MonthSummaryEntry

    /// Presupuestos que caben debajo del aro a la altura del extragrande vertical.
    static let budgetLimit = 5

    var body: some View {
        // Las secciones reparten el alto que sobra (con pocos presupuestos, el hueco no se queda abajo).
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
            MonthSummaryHeader()

            Spacer(minLength: WidgetDS.Spacing.lg)

            figures

            Spacer(minLength: WidgetDS.Spacing.lg)

            WidgetPlainLink(destination: MonthSummaryLinks.url("statistics/categories")) {
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
                    Text("widget.ui.categories", bundle: .main)
                        .font(WidgetDS.Typography.labelSmall)
                        .foregroundStyle(.secondary)
                    MonthSummaryCategories(entry: entry)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: WidgetDS.Spacing.lg)

            WidgetPlainLink(destination: MonthSummaryLinks.url("budgets")) {
                MonthSummaryBudgets(entry: entry, limit: Self.budgetLimit, fillsHeight: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }

    // MARK: Cifras

    /// Disponible y Gastado arriba; Ingresos y Neto debajo. En «Solo gastos» la segunda fila no sale: el ingreso es 0
    /// por definición y el neto sería el gasto en negativo.
    private var figures: some View {
        Grid(alignment: .leading, horizontalSpacing: WidgetDS.Spacing.xl, verticalSpacing: WidgetDS.Spacing.md) {
            GridRow {
                MonthSummaryFigure(label: "widget.ui.available", value: entry.balance,
                                   entry: entry, isEstimate: entry.balanceIsApproximate)
                MonthSummaryFigure(label: "widget.ui.spent", value: entry.totalExpense,
                                   entry: entry, isEstimate: entry.expenseIsApproximate)
            }
            if !entry.isExpensesOnly {
                GridRow {
                    MonthSummaryFigure(label: "widget.ui.income", value: entry.totalIncome,
                                       entry: entry, isEstimate: entry.incomeIsApproximate,
                                       tint: .color(WidgetColors.incomeText))
                    MonthSummaryFigure(label: "widget.ui.net", value: entry.netCashFlow,
                                       entry: entry, isEstimate: entry.netCashFlowIsApproximate, forceSign: true)
                }
            }
        }
    }
}
