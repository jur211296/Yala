//
//  CashFlowCardPaymentRow.swift
//  Yala
//
//  El pago de una tarjeta de crédito en el mes del flujo de caja (card nmtk, D4-A de Jürgen): «Pago de Visa · 5 nov ·
//  S/ 1,240.00 — Ya está en tus gastos del mes en que compraste: no se resta otra vez.». Solo informa: los gastos con
//  tarjeta ya cuentan el mes en que se hicieron y pagar la tarjeta es una transferencia entre cuentas propias, así que
//  sumarlo contaría dos veces. Por eso no pasa por `CashFlowPlanViewModel` ni por la proyección: no hay cifra que mover.
//

import SwiftUI

struct CashFlowCardPaymentRow: View {
    let card: CreditCardStatementSummary.Card

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: "creditcard.fill")
                .font(DS.Typography.label)
                .foregroundStyle(theme.onAccent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(theme.accent))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    Text(L10n.CashFlowPlan.cardPaymentTitle(
                        card.name, CreditCardStatementBlock.shortDate(card.cycle.paymentDate)))
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DS.Spacing.sm)
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                            AmountText(
                                value: line.statement.billed,
                                currencyCode: line.currencyCode,
                                font: DS.Typography.headline.monospacedDigit(),
                                tint: .color(theme.primaryText)
                            )
                        }
                    }
                }
                Text(L10n.CashFlowPlan.cardPaymentNote)
                    .font(DS.Typography.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cashflow_card_payment_row")
    }
}
