//
//  StatisticsLoadingSkeleton.swift
//  Yala
//
//  El esqueleto de Estadísticas mientras llegan las cifras (G1 de la decisión 28, revisión 2.3 problema 7). Con diez
//  años de datos la primera pasada tarda segundos en el iPhone; antes el Panel se quedaba congelado sin ninguna señal
//  hasta tenerla. Ahora la pestaña cambia en el acto con la barra de chips y este esqueleto donde irán las cifras.
//
//  Va ENCIMA de las páginas, no en su lugar: las páginas siguen montadas debajo y no se vuelven a montar al llegar las
//  cifras (con `yalaSkeleton`, que alterna dos ramas, se rehacían y Tendencias repetía su cálculo).
//

import SwiftUI

struct StatisticsLoadingSkeleton: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                // El hero: rótulo, cifra grande y detalle.
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    bar(width: 140, height: 14)
                    bar(width: 220, height: 40)
                    bar(width: 180, height: 14)
                }
                bar(height: 44)
                card(height: 220)
                card(height: 160)
                card(height: 120)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .readableColumn()
            .shimmer()
        }
        .scrollDisabled(true)
        .yalaScreenBackground()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Common.loading)
        .accessibilityIdentifier("stats_loading_skeleton")
    }

    private func bar(width: CGFloat? = nil, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.sm)
            .fill(.thSecondaryText.opacity(0.15))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    private func card(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
            .fill(.thSecondaryText.opacity(0.1))
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

/// Las tarjetas de una página de Estadísticas mientras llega su primer cálculo (Tendencias, Distribución). La cabecera
/// de la página sigue a la vista; solo las tarjetas esperan.
struct StatisticsCardsSkeleton: View {

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            card(height: 220)
            card(height: 180)
            card(height: 140)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .shimmer()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Common.loading)
        .accessibilityIdentifier("stats_cards_skeleton")
    }

    private func card(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
            .fill(.thSecondaryText.opacity(0.1))
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}
