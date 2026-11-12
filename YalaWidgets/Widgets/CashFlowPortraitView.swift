//
//  CashFlowPortraitView.swift
//  YalaWidgets
//
//  «Entradas y salidas» en el extragrande vertical del iPhone (iOS 27): el neto con su comparación, ingresos y gastos
//  en barras, lo de cada día y el reparto por cuenta. Las mismas piezas que el grande (`CashFlowWidget.swift`), con
//  sitio para el reparto. El período es el que la persona eligió al configurar el widget.
//
//  El reparto por cuenta lo calcula la app con la misma suma que los totales (`WidgetPeriodSummary.accountFlows`), así
//  que las filas suman el neto de arriba. Con una foto que no lo trae, el bloque no sale.
//

import SwiftUI
import WidgetKit

struct CashFlowPortraitView: View {
    let entry: CashFlowEntry

    /// Cuentas que caben en el reparto; el resto no se pinta (las filas van de más a menos movimiento).
    static let accountLimit = 4

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.lg) {
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

            // Crece con lo que deja libre el reparto: con una o dos cuentas, el hueco va a la gráfica.
            CashFlowBarsChart(entry: entry)
                .frame(maxHeight: .infinity)

            if !accounts.isEmpty {
                VStack(alignment: .leading, spacing: WidgetDS.Spacing.sm) {
                    Text("widget.ui.byAccount", bundle: .main)
                        .font(WidgetDS.Typography.labelSmall)
                        .foregroundStyle(.secondary)
                    ForEach(accounts, id: \.id) { flow in
                        accountRow(flow)
                    }
                }
            }

            WidgetFreshnessNote(lastUpdated: entry.lastUpdated, now: entry.date)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: WidgetDeepLink.inAndOut))
    }

    // MARK: Por cuenta

    private var accounts: [WidgetAccountFlow] {
        Array((entry.accountFlows ?? []).prefix(Self.accountLimit))
    }

    /// El neto de la cuenta (en «Solo gastos», lo gastado). Solo el positivo lleva color: colorea la excepción.
    private func accountRow(_ flow: WidgetAccountFlow) -> some View {
        let value = entry.isExpensesOnly ? flow.expense : flow.net
        return HStack(spacing: WidgetDS.Spacing.sm) {
            Text(flow.name)
                .font(WidgetDS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: WidgetDS.Spacing.md)
            WidgetAmountText(
                value: value,
                currencyCode: entry.currencyCode,
                displayFormat: entry.currencyDisplayFormat,
                font: WidgetDS.Typography.subheadlineEmphasized,
                secondaryFont: WidgetDS.Typography.captionSmall,
                tint: !entry.isExpensesOnly && value > 0 ? .color(WidgetColors.incomeText) : .primary,
                forceSign: !entry.isExpensesOnly
            )
            .lineLimit(1)
            .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}
