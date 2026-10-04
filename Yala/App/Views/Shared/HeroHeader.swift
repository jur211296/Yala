//
//  HeroHeader.swift
//  Yala
//
//  La maqueta del hero de Yala: la del Panel (`HeroMonthView`), compartida con las cuatro pestañas de Estadísticas
//  y, por `RecordsTabView`, con la página Registros. Antes cada una tenía la suya —centrada, con el período encima y
//  el rótulo debajo de la cifra— y el usuario que pasaba del Panel a Estadísticas tenía que volver a orientarse
//  (ticket `distribution-subviews-miss-the-new-panel-hero`, decisión de Jürgen del 2026-10-03).
//
//  Tres piezas, con un solo eje de lectura a la izquierda:
//  - `label`: qué es la cifra («Disponible», «Saldo de cuentas», «Neto del período»…), arriba a la izquierda.
//  - `period`: la píldora del período, a su derecha. A tamaños de accesibilidad baja debajo (`AdaptiveRowStack`).
//  - `content`: la cifra y lo que la acompaña (entradas y salidas, recuento), alineados a la izquierda.
//
//  Solo maqueta: cada pantalla sigue eligiendo su número y su rótulo. Con poco alto (iPhone girado) Resumen y
//  Registros no lo usan: `SummaryHeaderStack` los pone en banda.
//

import SwiftUI

struct HeroHeader<Label: View, Period: View, Content: View>: View {
    @ViewBuilder var label: Label
    @ViewBuilder var period: Period
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            AdaptiveRowStack(spacing: DS.Spacing.xs, stackedSpacing: DS.Spacing.sm) {
                label
            } trailing: {
                period
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DS.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// El rótulo del hero: lo que dice qué es la cifra. Mismo estilo en el Panel y en Estadísticas.
struct HeroHeaderLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DS.Typography.subheadline)
            .foregroundStyle(.secondary)
            // Dos líneas y no una: en Estadísticas el rótulo es más largo que «Disponible» y en algunos idiomas no
            // cabe junto a la píldora. Cortarlo escondería justo lo que dice qué es el número.
            .lineLimit(2)
    }
}
