//
//  FlujoDetalleMesHistoriaView.swift
//  Yala
//
//  Las filas de la historia del mes debajo de la cifra grande (S2 del replanteo, variante A «libro del mes»):
//  «Empezaste con S/ X», «Entró S/ Y», «Salió S/ Z» y, si la suma no cuadra con tus cuentas, «Ajustes de saldo». En el
//  mes en curso, debajo de lo que entró y salió, lo que falta (estimado). La cifra grande, «Terminas con», la pone quien
//  la monta: la historia se lee de arriba abajo como una suma que da esa cifra.
//

import SwiftUI

struct FlujoDetalleMesHistoriaView: View {
    let historia: FlujoDetalleMesLogica.Historia
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            if let empezaste = historia.empezaste {
                fila(
                    L10n.FlujoDetalleMes.empezaste(historia.tiempo), value: empezaste, sign: false,
                    identifier: "cashflow_story_started"
                )
            }
            flujo(
                L10n.FlujoDetalleMes.entro(historia.tiempo), historia.entro,
                left: L10n.FlujoDetalleMes.faltaEntrar, identifier: "cashflow_story_in"
            )
            flujo(
                L10n.FlujoDetalleMes.salio(historia.tiempo), historia.salio,
                left: L10n.FlujoDetalleMes.faltaSalir, identifier: "cashflow_story_out"
            )
            if let ajuste = historia.ajuste {
                fila(L10n.FlujoDetalleMes.ajustes, value: ajuste, sign: true, identifier: "cashflow_story_adjustment")
            }
        }
        .padding(.top, DS.Spacing.xxs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cashflow_story")
    }

    /// Entró o Salió. En un mes cerrado, lo real; en el que viene, lo estimado con «≈»; en el mes en curso, lo real y
    /// debajo lo que falta, estimado.
    @ViewBuilder
    private func flujo(
        _ label: String, _ flujo: FlujoDetalleMesLogica.Flujo, left: String, identifier: String
    ) -> some View {
        // Sin signo: «Entró» y «Salió» ya dicen hacia dónde va el dinero, y el signo de `AmountText` cae detrás del
        // símbolo («S/ -7,206»). Solo «Ajustes de saldo» lo lleva, porque puede ir a cualquier lado.
        let shown = historia.tiempo == .futuro ? flujo.estimado : flujo.real
        fila(label, value: shown, sign: false, isEstimate: historia.tiempo == .futuro, identifier: identifier)
        if historia.tiempo == .enCurso, flujo.tieneEstimado {
            AdaptiveRowStack(spacing: DS.Spacing.sm, stackedSpacing: DS.Spacing.xxs) {
                Text(left)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } trailing: {
                AmountText(
                    value: flujo.estimado,
                    currencyCode: currencyCode,
                    font: DS.Typography.caption.monospacedDigit(),
                    tint: .secondary,
                    isEstimate: true
                )
            }
            .padding(.leading, DS.Spacing.md)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("\(identifier)_left")
        }
    }

    private func fila(
        _ label: String, value: Double, sign: Bool, isEstimate: Bool = false, identifier: String
    ) -> some View {
        AdaptiveRowStack(spacing: DS.Spacing.sm, stackedSpacing: DS.Spacing.xxs) {
            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } trailing: {
            AmountText(
                value: value,
                currencyCode: currencyCode,
                font: DS.Typography.subheadlineEmphasized.monospacedDigit(),
                forceSign: sign,
                isEstimate: isEstimate || historia.tiempo == .futuro
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
