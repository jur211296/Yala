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
//  La línea «X % usado · disponible de N» sale solo cuando la tarjeta tiene límite (`Account.creditLimit`, decisión de
//  Jürgen del 22-nov-2026, opción A). Sin límite (`nil`), no se pinta.
//  Con varias divisas no hay barra (no se suman) y cada cifra va en su divisa, apilada. La línea sí sale (decisión del
//  22-nov-2026): lo que debes en otra divisa se convierte a la del límite con el último tipo de cambio guardado, y una
//  nota lo dice. Sin tipo de cambio real (solo la tabla estática), no se pinta.
//

import SwiftUI

struct HojaCuentaTarjetaEstado: View {
    let card: CreditCardStatementSummary.Card
    /// El límite de la tarjeta (`Account.creditLimit` de la principal). `nil` = sin límite: la línea no se pinta.
    var limite: Double? = nil
    /// La divisa del límite: la de la principal. `nil` = la de la primera línea (una sola divisa).
    var divisaLimite: String? = nil

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var prefs
    @Environment(\.amountsHidden) private var amountsHidden
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(CurrencyConverter.self) private var currencyConverter

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
            if let divisa = divisaDelLimite, let calculo = usoDeLineaCalculado(divisa: divisa) {
                usoDeLinea(calculo.uso, divisa: divisa)
                if !calculo.divisasConvertidas.isEmpty {
                    notaConversion(calculo.divisasConvertidas)
                }
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

    private var divisaDelLimite: String? {
        divisaLimite.map(normalizeCurrencyCode) ?? card.lines.first?.currencyCode
    }

    /// El uso de línea en la divisa del límite. Lo de otra divisa, con el último tipo de cambio guardado; si para esa
    /// pareja solo está la tabla estática, no hay tipo de cambio de verdad y la línea no sale.
    private func usoDeLineaCalculado(divisa: String) -> HojaCuentaTarjetaLogica.UsoDeLineaConvertido? {
        let lineasEnDivisa = card.lines.map {
            HojaCuentaTarjetaLogica.LineaEnDivisa(facturado: $0.statement.billed, porFacturar: $0.statement.unbilled,
                                                  divisa: $0.currencyCode)
        }
        return HojaCuentaTarjetaLogica.usoDeLinea(lineas: lineasEnDivisa, limite: limite, divisaLimite: divisa) { monto, desde in
            let resultado = currencyConverter.convertCheckedWithLatestRate(Decimal(monto), from: desde, to: divisa)
            guard resultado.quality != .staticFallback else { return nil }
            return (resultado.amount as NSDecimalNumber).doubleValue
        }
    }

    /// «Aprox.: incluye lo que debes en USD, al último tipo de cambio.» Bajo la línea, en el mismo tono; sin botón.
    private func notaConversion(_ divisas: [String]) -> some View {
        Text(L10n.LimiteTarjeta.notaConversion(divisas: divisas.formatted(.list(type: .and)
            .locale(LanguageManager.resolved.locale))))
            .font(DS.Typography.caption)
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("hoja_cuenta_uso_de_linea_nota")
    }

    /// «16 % usado · 6.752,50 disponible de 8.000,00». Con los montos ocultos, las cifras van tapadas como en el resto.
    private func usoDeLinea(_ uso: HojaCuentaTarjetaLogica.UsoDeLinea, divisa: String) -> some View {
        let porcentaje = uso.fraccionUsada.formatted(.percent.precision(.fractionLength(0)).locale(LanguageManager.resolved.locale))
        let monto: (Double) -> String = { valor in
            amountsHidden ? L10n.Panel.amountHidden : prefs.currency(valor, currencyCode: divisa)
        }
        return Text(L10n.HojaCuentaTarjeta.usoDeLinea(porcentaje: porcentaje, disponible: monto(uso.disponible),
                                                      limite: monto(uso.limite)))
            .font(DS.Typography.caption)
            .foregroundStyle(theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("hoja_cuenta_uso_de_linea")
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
