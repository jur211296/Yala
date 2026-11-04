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
        // Las secciones van arriba con el mismo aire entre ellas, y el alto que sobra lo toma el aro de las categorías.
        // Antes lo repartían tres `Spacer`: con un presupuesto, el widget quedaba con tres franjas vacías (card dz6c,
        // captura de Jürgen del 2026-11-04).
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
            MonthSummaryHeader()

            figures
                .padding(.top, WidgetDS.Spacing.xl)

            WidgetPlainLink(destination: MonthSummaryLinks.url("statistics/categories")) {
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
                    Text("widget.ui.categories", bundle: .main)
                        .font(WidgetDS.Typography.labelSmall)
                        .foregroundStyle(.secondary)
                    // El aro encima y grande si cabe; si no (muchos presupuestos debajo), al lado de la leyenda.
                    ViewThatFits(in: .vertical) {
                        MonthSummaryCategories(entry: entry, layout: .stacked)
                        MonthSummaryCategories(entry: entry, layout: .beside)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(.top, WidgetDS.Spacing.xl)

            WidgetPlainLink(destination: MonthSummaryLinks.url("budgets")) {
                MonthSummaryBudgets(entry: entry, limit: Self.budgetLimit, fillsHeight: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, WidgetDS.Spacing.xl)
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
