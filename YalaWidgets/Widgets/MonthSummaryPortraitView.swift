//
//  MonthSummaryPortraitView.swift
//  YalaWidgets
//
//  «Resumen del mes» en el extragrande vertical del iPhone (iOS 27): las cuatro cifras del mes, las categorías en
//  círculo y los presupuestos más apretados, uno debajo de otro. Lo mismo que el de iPad, recolocado en vertical
//  (lienzo de la card `widgets-extragrandes-en-el-iphone-con-io-5fir`, opción C).
//

import SwiftUI
import WidgetKit

struct MonthSummaryPortraitView: View {
    let entry: MonthSummaryEntry

    /// Presupuestos que caben debajo del círculo a la altura del extragrande vertical.
    static let budgetLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.lg) {
            WidgetHeader(
                title: String(localized: "widget.ui.monthSummary", bundle: .main),
                subtitle: WidgetPeriod.thisMonth.localizedDisplayName,
                icon: "calendar"
            )

            figures

            Divider()

            Link(destination: MonthSummaryLinks.url("statistics/categories")) {
                categoriesSection
            }

            Divider()

            Link(destination: MonthSummaryLinks.url("budgets")) {
                budgetsSection
            }

            Spacer(minLength: 0)
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: "panel"))
    }

    // MARK: Cifras

    /// Disponible y Gastos arriba; Ingresos y Neto debajo. En «Solo gastos» la segunda fila no sale: el ingreso es 0
    /// por definición y el neto sería el gasto en negativo.
    private var figures: some View {
        Grid(alignment: .leading, horizontalSpacing: WDS.Spacing.xl, verticalSpacing: WDS.Spacing.md) {
            GridRow {
                WidgetLabeledAmount(
                    label: "widget.ui.available",
                    value: entry.balance,
                    currencyCode: entry.currencyCode,
                    displayFormat: entry.currencyDisplayFormat,
                    isEstimate: entry.balanceIsApproximate
                )
                WidgetLabeledAmount(
                    label: "widget.ui.expenses",
                    value: entry.totalExpense,
                    currencyCode: entry.currencyCode,
                    displayFormat: entry.currencyDisplayFormat,
                    tint: WidgetColors.expense,
                    isEstimate: entry.expenseIsApproximate
                )
            }
            if !entry.isExpensesOnly {
                GridRow {
                    WidgetLabeledAmount(
                        label: "widget.ui.income",
                        value: entry.totalIncome,
                        currencyCode: entry.currencyCode,
                        displayFormat: entry.currencyDisplayFormat,
                        tint: WidgetColors.income,
                        isEstimate: entry.incomeIsApproximate
                    )
                    WidgetLabeledAmount(
                        label: "widget.ui.net",
                        value: entry.netCashFlow,
                        currencyCode: entry.currencyCode,
                        displayFormat: entry.currencyDisplayFormat,
                        isEstimate: entry.netCashFlowIsApproximate,
                        forceSign: true
                    )
                }
            }
        }
    }

    // MARK: Categorías

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.md) {
            WidgetSectionTitle(key: "widget.ui.categories")

            if entry.categories.isEmpty {
                MonthSummaryEmptyState(icon: "chart.pie", text: "widget.ui.noExpenses")
            } else {
                HStack(alignment: .center, spacing: WDS.Spacing.xl) {
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
                    .frame(maxWidth: 116, maxHeight: 116)

                    VStack(alignment: .leading, spacing: WDS.Spacing.sm) {
                        ForEach(entry.categories, id: \.id) { category in
                            MonthSummaryCategoryRow(category: category)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Presupuestos

    private var budgetsSection: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.md) {
            WidgetSectionTitle(key: "widget.ui.budgets")

            if entry.budgets.isEmpty {
                MonthSummaryEmptyState(icon: "chart.pie", text: "widget.ui.noBudgets")
            } else {
                ForEach(entry.budgets.prefix(Self.budgetLimit), id: \.id) { budget in
                    BudgetRowView(budget: budget, displayFormat: entry.currencyDisplayFormat)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
