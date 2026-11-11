//
//  NetFlowSummaryView.swift
//  Yala
//
//  Summary view showing net cash flow with comparison.
//
//  UX 2.2 · L18-3/L18-4: «Flujo neto» pasa a «Te quedó» (o «Te faltó» si salió más de lo que entró), con una línea que
//  dice qué es y cuánto quedó en el período anterior: «Ingresos menos gastos. En setiembre te quedaron S/ 5,617.»
//

import SwiftUI

struct NetFlowSummaryView: View {

    let currentAmount: Double
    let previousAmount: Double?
    let variation: Double?
    let currencyCode: String
    /// `false` en «Todo el tiempo»: no hay período anterior con el que comparar.
    var showsComparison: Bool = true
    /// El período anterior dentro de una frase («setiembre», «el 1–21 de septiembre» no: aquí va sin artículo).
    var previousPeriodName: String = ""

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var showVariations: Bool { appPreferences.showVariations }

    private var caption: String {
        guard showsComparison, let previousAmount, !previousPeriodName.isEmpty else { return L10n.UXL18.netCaption }
        let amount = appPreferences.currency(abs(previousAmount), currencyCode: currencyCode)
        return previousAmount >= 0
            ? L10n.UXL18.netCaptionGainBefore(previousPeriodName, amount)
            : L10n.UXL18.netCaptionLossBefore(previousPeriodName, amount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Con texto de accesibilidad «Te quedó» va solo en su línea y la cifra con el cambio debajo: en una fila el
            // título se partía por sílabas («Te que-dó») y la cifra se cortaba (lote 05 de 2.3, zona 36 P5).
            if dynamicTypeSize.isAccessibilitySize {
                title
                HStack(spacing: DS.Spacing.sm) {
                    amount
                    Spacer(minLength: DS.Spacing.sm)
                    chip
                }
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    title

                    Spacer(minLength: DS.Spacing.sm)

                    amount

                    chip
                }
            }

            Text(caption)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.lg)
        .solidCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("report_net_summary")
    }

    private var title: some View {
        Text(currentAmount >= 0 ? L10n.UXL18.netGain : L10n.UXL18.netLoss)
            .font(DS.Typography.label)
            .fontWeight(.semibold)
            .foregroundStyle(.primary)
    }

    private var amount: some View {
        AmountText(
            value: abs(currentAmount),
            currencyCode: currencyCode,
            font: DS.Typography.label.weight(.semibold),
            tint: .color(currentAmount >= 0 ? Color.electricIndigo : Color.hotPink)
        )
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private var chip: some View {
        if showVariations && showsComparison {
            VariationChip(
                variation: variation,
                size: .small,
                showNAWhenNil: previousAmount == nil,
                isExpenseContext: false
            )
        }
    }
}
