//
//  CashFlowPortraitView.swift
//  YalaWidgets
//
//  «Entradas y salidas» en el extragrande vertical del iPhone (iOS 27): ingresos y gastos, la gráfica día a día, el
//  reparto por cuenta y el neto del período (lienzo de la card `widgets-extragrandes-en-el-iphone-con-io-5fir`,
//  opción C). El período es el que la persona eligió al configurar el widget, como en los otros tamaños.
//
//  El reparto por cuenta lo calcula la app con la misma suma que los totales (`WidgetPeriodSummary.accountFlows`), así
//  que las filas suman el neto de abajo. Con una foto que no lo trae, el bloque no sale.
//

import SwiftUI
import WidgetKit

struct CashFlowPortraitView: View {
    let entry: CashFlowEntry

    /// Cuentas que caben en el reparto; el resto no se pinta (las filas van de más a menos movimiento).
    static let accountLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: WDS.Spacing.lg) {
            WidgetHeader(
                title: entry.kpiTitle(fallbackKey: "widget.ui.cashFlow"),
                subtitle: entry.period.toWidgetPeriod.localizedDisplayName,
                icon: "arrow.left.arrow.right"
            )

            figures

            chart

            if !accounts.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: WDS.Spacing.md) {
                    WidgetSectionTitle(key: "widget.ui.byAccount")
                    ForEach(accounts, id: \.id) { flow in
                        accountRow(flow)
                    }
                }
            }

            if !entry.isExpensesOnly {
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text("widget.ui.net", bundle: .main)
                        .font(WDS.Typography.label)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: WDS.Spacing.md)
                    WidgetAmountText(
                        value: entry.netCashFlow,
                        currencyCode: entry.currencyCode,
                        displayFormat: entry.currencyDisplayFormat,
                        font: WDS.Typography.kpiSmall,
                        secondaryFont: WDS.Typography.kpiSmallSecondary,
                        tint: .primary,
                        forceSign: true,
                        isEstimate: entry.netCashFlowIsApproximate
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(WDS.Spacing.xs)
        .clipped()
        .widgetURL(WidgetURLHelper.url(for: WidgetDeepLink.inAndOut))
    }

    // MARK: Cifras

    /// Ingresos y gastos lado a lado; en «Solo gastos», solo lo gastado (el ingreso llega a 0 por definición).
    private var figures: some View {
        HStack(alignment: .top, spacing: WDS.Spacing.xl) {
            if !entry.isExpensesOnly {
                WidgetLabeledAmount(
                    label: "widget.ui.income",
                    value: entry.totalIncome,
                    currencyCode: entry.currencyCode,
                    displayFormat: entry.currencyDisplayFormat,
                    tint: WidgetColors.income,
                    isEstimate: entry.incomeIsApproximate
                )
            }
            WidgetLabeledAmount(
                label: entry.isExpensesOnly ? "widget.ui.spent" : "widget.ui.expenses",
                value: entry.totalExpense,
                currencyCode: entry.currencyCode,
                displayFormat: entry.currencyDisplayFormat,
                tint: WidgetColors.expense,
                isEstimate: entry.expenseIsApproximate
            )
        }
    }

    // MARK: Gráfica

    @ViewBuilder
    private var chart: some View {
        if entry.cashFlowPoints.count >= 2 {
            BidirectionalCashFlowChart(
                points: entry.cashFlowPoints,
                period: entry.period,
                resolvedPeriod: entry.period.toWidgetPeriod,
                expensesOnly: entry.isExpensesOnly || entry.totalIncome == 0
            )
            // Mínimo 150 y crece con lo que deja libre el reparto: con una o dos cuentas, el hueco va a la gráfica.
            .frame(minHeight: 150, maxHeight: .infinity)
        } else {
            VStack(spacing: WDS.Spacing.xs) {
                Image(systemName: "chart.bar")
                    .font(.title2) // A11Y-DT: widget empty state icon
                    .foregroundStyle(.tertiary)
                Text("widget.ui.notEnoughData", bundle: .main)
                    .font(WDS.Typography.body)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 110, maxHeight: .infinity)
        }
    }

    // MARK: Por cuenta

    private var accounts: [WidgetAccountFlow] {
        Array((entry.accountFlows ?? []).prefix(Self.accountLimit))
    }

    /// El neto de la cuenta (en «Solo gastos», lo gastado). Solo el positivo lleva color: colorea la excepción.
    private func accountRow(_ flow: WidgetAccountFlow) -> some View {
        let value = entry.isExpensesOnly ? flow.expense : flow.net
        return HStack(spacing: WDS.Spacing.sm) {
            Text(flow.name)
                .font(WDS.Typography.label)
                .lineLimit(1)
            Spacer(minLength: WDS.Spacing.md)
            WidgetAmountText(
                value: value,
                currencyCode: entry.currencyCode,
                displayFormat: entry.currencyDisplayFormat,
                font: WDS.Typography.value,
                secondaryFont: WDS.Typography.valueSecondary,
                tint: !entry.isExpensesOnly && value > 0 ? .color(WidgetColors.income) : .primary,
                forceSign: !entry.isExpensesOnly
            )
            .lineLimit(1)
            .fixedSize()
        }
    }
}
