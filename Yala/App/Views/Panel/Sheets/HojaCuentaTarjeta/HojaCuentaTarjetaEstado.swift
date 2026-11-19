//
//  HojaCuentaTarjetaEstado.swift
//  Yala
//
//  El bloque de la tarjeta de crédito bajo el monto (pedido de Jürgen del 17-nov-2026, variante A «Wallet», como la
//  referencia): arriba lo que debes repartido entre facturado y por facturar, con su barra; abajo la fecha de pago con lo
//  facturado y el próximo corte. Los datos son los de siempre (`CreditCardStatementSummary`, sin tocar) y los textos que
//  ya existían (`L10n.CreditCardStatement`).
//
//  Sin límite de la tarjeta en Yala no hay «% usado»: la barra reparte lo que debes (`HojaCuentaTarjetaLogica.reparto`).
//  Con varias divisas no hay barra (no se suman) y cada cifra va en su divisa, apilada.
//

import SwiftUI

struct HojaCuentaTarjetaEstado: View {
    let card: CreditCardStatementSummary.Card

    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            reparto
                .padding(.vertical, DS.Spacing.md)
            Divider()
            pago
                .padding(.vertical, DS.Spacing.md)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .solidCard(radius: DS.Radius.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hoja_cuenta_estado")
    }

    // MARK: - Lo que debes, repartido

    private var lineas: [(facturado: Double, porFacturar: Double)] {
        card.lines.map { ($0.statement.billed, $0.statement.unbilled) }
    }

    @ViewBuilder
    private var reparto: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            AdaptiveRowStack {
                cifra(titulo: L10n.CreditCardStatement.billed, montos: card.lines.map { ($0.statement.billed, $0.currencyCode) },
                      tinte: theme.accentText, alineacion: .leading)
                    // Los ids del bloque de antes: `CreditCardStatementUITests` lee ahí las cifras.
                    .accessibilityIdentifier("cc_statement_billed")
            } trailing: {
                cifra(titulo: L10n.CreditCardStatement.unbilled,
                      montos: card.lines.map { ($0.statement.unbilled, $0.currencyCode) },
                      tinte: theme.secondaryText, alineacion: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing)
                    .accessibilityIdentifier("cc_statement_unbilled")
            }
            if let reparto = HojaCuentaTarjetaLogica.reparto(lineas: lineas) {
                barra(reparto)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hoja_cuenta_reparto")
    }

    private func cifra(titulo: String, montos: [(Double, String)], tinte: Color,
                       alineacion: HorizontalAlignment) -> some View {
        VStack(alignment: alineacion, spacing: DS.Spacing.xxs) {
            Text(titulo)
                .font(DS.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(tinte)
            ForEach(Array(montos.enumerated()), id: \.offset) { _, item in
                AmountText(
                    value: max(item.0, 0),
                    currencyCode: item.1,
                    font: DS.Typography.subheadlineEmphasized,
                    secondaryFont: DS.Typography.caption,
                    tint: .color(theme.primaryText)
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// La barra: el carril entero es lo que debes; el relleno, lo facturado. El relleno va en el overlay del carril
    /// (`swiftui-ds.md`, iPhone Duo: un hermano con el ancho medido no encoge).
    private func barra(_ reparto: HojaCuentaTarjetaLogica.Reparto) -> some View {
        Capsule()
            .fill(theme.accent.opacity(0.18))
            .frame(height: DS.Spacing.sm)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: proxy.size.width * reparto.fraccionFacturada)
                }
            }
            .accessibilityHidden(true)
    }

    // MARK: - Fecha de pago y próximo corte

    private var estado: CreditCardStatementLogic.BilledStatus {
        let billed = card.lines.map(\.statement.billed).max() ?? 0
        return CreditCardStatementLogic.billedStatus(billed: billed, cycle: card.cycle, now: .now, calendar: calendar)
    }

    private var tituloPago: String {
        switch estado {
        case .payBy(let date): return L10n.CreditCardStatement.payBy(CreditCardStatementBlock.longDate(date))
        case .overdue(let date): return L10n.CreditCardStatement.overdue(CreditCardStatementBlock.shortDate(date))
        case .settled: return L10n.CreditCardStatement.nothingDue
        }
    }

    private var pago: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(tituloPago)
                .font(DS.Typography.headline)
                .foregroundStyle(theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.HojaCuentaTarjeta.proximoCorte(CreditCardStatementBlock.shortDate(card.cycle.nextStatementDate)))
                .font(DS.Typography.subheadline)
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("hoja_cuenta_fechas")
    }
}

/// Tarjeta de crédito sin día de corte o de pago: lo dice y ofrece ponerlas (abre Editar).
struct HojaCuentaTarjetaSinFechas: View {
    let onAnadir: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "calendar.badge.clock")
                    .font(DS.Typography.title3)
                    .foregroundStyle(theme.accentText)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.HojaCuentaTarjeta.sinFechasTitulo)
                        .font(DS.Typography.headline)
                        .foregroundStyle(theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.HojaCuentaTarjeta.sinFechasDetalle)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            YalaSecondaryButton(L10n.HojaCuentaTarjeta.anadirFechas, icon: "calendar") {
                onAnadir()
            }
            .accessibilityIdentifier("hoja_cuenta_anadir_fechas")
        }
        .padding(DS.Spacing.lg)
        .solidCard(radius: DS.Radius.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hoja_cuenta_sin_fechas")
    }
}
