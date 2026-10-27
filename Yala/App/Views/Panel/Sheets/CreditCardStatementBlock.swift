//
//  CreditCardStatementBlock.swift
//  Yala
//
//  «Estado de cuenta» en la ficha de una tarjeta de crédito (card nmtk, D2-A de Jürgen): bajo el saldo, lo FACTURADO en
//  el último corte («Paga antes del jueves 5 nov») y lo POR FACTURAR («Entra en el corte del 15 nov»). Los dos suman el
//  «Por pagar» de la cabecera, que no cambia. Con varias divisas, una cifra por divisa apilada, como la cabecera: el banco
//  factura cada una por separado y no se suman.
//

import SwiftUI

struct CreditCardStatementBlock: View {
    let card: CreditCardStatementSummary.Card

    @Environment(\.yalaTheme) private var theme

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            Text(L10n.CreditCardStatement.title(Self.shortDate(card.cycle.statementDate)))
                .font(DS.Typography.caption)
                .foregroundStyle(theme.secondaryText)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xs)
                .accessibilityAddTraits(.isHeader)

            row(title: L10n.CreditCardStatement.billed, caption: billedCaption, captionTint: billedTint,
                amounts: card.lines.map { ($0.statement.billed, $0.currencyCode) }, emphasized: true)
                .accessibilityIdentifier("cc_statement_billed")

            Divider()

            row(title: L10n.CreditCardStatement.unbilled,
                caption: L10n.CreditCardStatement.nextStatement(Self.shortDate(card.cycle.nextStatementDate)),
                captionTint: theme.secondaryText,
                amounts: card.lines.map { ($0.statement.unbilled, $0.currencyCode) }, emphasized: false)
                .accessibilityIdentifier("cc_statement_unbilled")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xs)
        .solidCard(radius: DS.Radius.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cc_statement_block")
    }

    /// Queda algo por pagar si alguna divisa lo tiene.
    private var status: CreditCardStatementLogic.BilledStatus {
        let billed = card.lines.map(\.statement.billed).max() ?? 0
        return CreditCardStatementLogic.billedStatus(billed: billed, cycle: card.cycle, now: .now, calendar: calendar)
    }

    private var billedCaption: String {
        switch status {
        case .payBy(let date): return L10n.CreditCardStatement.payBy(Self.longDate(date))
        case .overdue(let date): return L10n.CreditCardStatement.overdue(Self.shortDate(date))
        case .settled: return L10n.CreditCardStatement.nothingDue
        }
    }

    /// La fecha en el acento (el token de TEXTO, legible en los diez temas) solo mientras quede algo por pagar. No el
    /// naranja de aviso: sobre la tarjeta blanca no llega al 4,5:1 de un texto (`swiftui-ds.md`).
    private var billedTint: Color {
        switch status {
        case .payBy, .overdue: return theme.accentText
        case .settled: return theme.secondaryText
        }
    }

    private func row(title: String, caption: String, captionTint: Color, amounts: [(Double, String)],
                     emphasized: Bool) -> some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(emphasized ? DS.Typography.headline : DS.Typography.body)
                    .foregroundStyle(theme.primaryText)
                Text(caption)
                    .font(DS.Typography.caption)
                    .foregroundStyle(captionTint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DS.Spacing.sm)
            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                ForEach(Array(amounts.enumerated()), id: \.offset) { _, item in
                    AmountText(
                        value: item.0,
                        currencyCode: item.1,
                        font: emphasized ? DS.Typography.title3.bold() : DS.Typography.headline,
                        secondaryFont: DS.Typography.caption,
                        tint: .color(emphasized ? theme.primaryText : theme.secondaryText)
                    )
                }
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    /// «15 oct».
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(AppLocale.current))
    }

    /// «jueves 5 nov».
    static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(AppLocale.current))
    }
}
