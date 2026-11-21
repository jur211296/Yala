//
//  FlujoComoSeConvierteSheet.swift
//  Yala
//
//  «Cómo se convierte» (encargo del 2026-11-20, pregunta `fila`, opción A): la abre la cápsula «500 USD · promedio de
//  nov. 3.70» del detalle de una línea. Dice el original, la tasa de cada mes (tres cerrados, el en curso y dos
//  estimados) con lo que vale en la moneda del flujo, y de dónde salen las tasas.
//

import SwiftUI

struct FlujoComoSeConvierteSheet: View {

    struct Fila: Identifiable, Equatable {
        let mes: Date
        let tasa: FlujoTasaDelMes.Tasa
        let original: Double
        let convertido: Double
        var id: Date { mes }
    }

    struct Datos: Identifiable, Equatable {
        let nombre: String
        let esIngreso: Bool
        let moneda: String
        let monedaPlan: String
        let originalDelMes: Double
        let filas: [Fila]
        var id: String { "\(nombre)|\(moneda)" }
    }

    /// Los meses de la hoja: tres cerrados, el en curso y dos que vienen, con el límite de la línea en cada uno.
    static func datos(
        line: CashFlowLine, mesQueSeVe: Date, monedaPlan: String, converter: any CurrencyConverting, hoy: Date,
        calendar: Calendar
    ) -> Datos? {
        guard let actual = calendar.dateInterval(of: .month, for: hoy)?.start else { return nil }
        let meses = (-3...2).compactMap { calendar.date(byAdding: .month, value: $0, to: actual) }
        let fuentes = FlujoLimiteEnMoneda.Fuentes.deLinea(
            line, meses: meses + [mesQueSeVe], monedaPlan: monedaPlan, converter: converter, hoy: hoy, calendar: calendar
        )
        func desglose(_ mes: Date) -> FlujoLimiteEnMoneda.Resultado? {
            FlujoLimiteEnMoneda.resultado(line: line, mes: mes, monedaPlan: monedaPlan, fuentes: fuentes, calendar: calendar)
        }
        guard let delMes = desglose(mesQueSeVe), delMes.monedasExtranjeras.count == 1,
              let moneda = delMes.monedasExtranjeras.first else { return nil }
        let filas: [Fila] = meses.compactMap { mes in
            guard let r = desglose(mes) else { return nil }
            let tasa = fuentes.tasa(moneda, mes: mes, calendar: calendar)
            let enMoneda = r.pagos.filter { $0.estado == .suma && $0.moneda == moneda }
            let original = r.pagos.isEmpty
                ? (r.original?.monto ?? 0)
                : enMoneda.reduce(0) { $0 + $1.importe * Double($1.ocurrencias) }
            return Fila(mes: mes, tasa: tasa, original: original, convertido: original * tasa.factor)
        }
        let originalDelMes = delMes.original?.monto
            ?? delMes.pagos.filter { $0.estado == .suma && $0.moneda == moneda }
                .reduce(0) { $0 + $1.importe * Double($1.ocurrencias) }
        return Datos(nombre: line.name, esIngreso: line.isIncome, moneda: moneda, monedaPlan: monedaPlan,
                     originalDelMes: originalDelMes, filas: filas)
    }

    let datos: Datos

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    cabecera
                    VStack(spacing: DS.Spacing.none) {
                        ForEach(Array(datos.filas.enumerated()), id: \.element.id) { indice, fila in
                            if indice > 0 { Divider().padding(.leading, DS.Spacing.lg) }
                            filaView(fila)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(theme.card))
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(L10n.FlujoDetalleLinea.conviertePie)
                        if datos.filas.contains(where: { $0.tasa.esAproximada && $0.tasa.estado != .estimado }) {
                            Text(L10n.FlujoDetalleLinea.convierteAproximado)
                        }
                        Text(L10n.FlujoDetalleLinea.convierteFuente)
                    }
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(DS.Spacing.lg)
                .readableColumn()
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.FlujoDetalleLinea.convierteTitulo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("cashflow_how_converted_sheet")
    }

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.FlujoDetalleLinea.convierteLimiteDe(datos.nombre, esIngreso: datos.esIngreso))
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            AmountText(value: datos.originalDelMes, currencyCode: datos.moneda,
                       font: DS.Typography.panelHeroAmount)
                .accessibilityIdentifier("cashflow_how_converted_original")
            Text(L10n.FlujoDetalleLinea.convierteExplica(datos.monedaPlan))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(theme.card))
        .accessibilityElement(children: .combine)
    }

    private func estado(_ tasa: FlujoTasaDelMes.Tasa) -> String {
        switch tasa.estado {
        case .cerrado: L10n.FlujoDetalleLinea.convierteCerrado
        case .enCurso(let dias): L10n.FlujoDetalleLinea.convierteEnCurso(dias: dias)
        case .estimado: L10n.FlujoDetalleLinea.convierteEstimado
        }
    }

    private func filaView(_ fila: Fila) -> some View {
        let mes = fila.mes.formatted(Date.FormatStyle().month(.wide).locale(AppLocale.current)).capitalized(with: AppLocale.current)
        let tasa = FlujoMonedaTexto.tasa(fila.tasa)
        let monto = appPreferences.currency(fila.convertido, currencyCode: datos.monedaPlan, isEstimate: fila.tasa.esAproximada)
        return AdaptiveRowStack(spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(mes)
                    .font(DS.Typography.body.weight(fila.tasa.estado == .cerrado ? .regular : .semibold))
                Text(estado(fila.tasa))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        } trailing: {
            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text(monto)
                    .font(DS.Typography.amountSmall.monospacedDigit())
                Text(tasa)
                    .font(DS.Typography.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.FlujoDetalleLinea.convierteMesAccesible(mes, estado: estado(fila.tasa), tasa: tasa, monto: monto))
        .accessibilityIdentifier("cashflow_how_converted_month")
    }
}
