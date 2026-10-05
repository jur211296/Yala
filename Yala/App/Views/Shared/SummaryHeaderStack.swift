//
//  SummaryHeaderStack.swift
//  Yala
//
//  La cabecera de resumen de Registros y de Estadísticas › Resumen, que se compacta cuando el contenedor tiene poco
//  alto (ticket `iphone-landscape-headers-fill-the-short-screen`, ADR «Yala se adapta por espacio, no por
//  dispositivo»). Cuatro piezas: `period` (el selector de período), `caption` (qué es la cifra), `figure` (la cifra)
//  y `detail` (entradas y salidas, recuento).
//
//  Con alto suficiente es el hero del Panel (`HeroHeader`): rótulo y período arriba, cifra y detalle debajo, todo a
//  la izquierda (ticket `distribution-subviews-miss-the-new-panel-hero`, 2026-10-03; antes era una pila centrada).
//  Con poco alto (un iPhone girado: 375 pt en un SE) el hero se comía casi toda la pantalla y la primera fila quedaba
//  bajo la barra de pestañas. Entonces, de la primera que quepa a lo ancho, con el rótulo bajo la cifra:
//
//  1. Banda: la cifra a la izquierda; período y detalle a la derecha. Mide lo que mide la cifra (~80 pt en vez de
//     ~180), y por eso el período va a la derecha y no encima de la cifra: encima, la columna izquierda volvía a
//     tener tres filas y la primera fila de Registros seguía bajo la barra (medido en el SE).
//  2. El período al lado de la cifra, y el detalle debajo. Es la que cabe en la columna de lista del Pro Max girado
//     (352 pt de cabecera), donde la banda no.
//  3. La pila de siempre con el detalle en una sola fila.
//  4. La pila de siempre.
//
//  Las cuatro con el margen vertical reducido y sin margen lateral propio. Lo decide el alto MEDIDO del contenedor (`DS.Adaptive
//  .isShortContainer`), nunca la orientación; y el ancho, `ViewThatFits`: con texto AX5 o en la columna de lista del
//  Pro Max girado la banda no cabe y baja sola a la siguiente.
//

import SwiftUI

struct SummaryHeaderStack<Period: View, Caption: View, Figure: View, Detail: View>: View {
    /// El contenedor tiene poco alto (`DS.Adaptive.isShortContainer`).
    let isShort: Bool
    /// Margen vertical con alto suficiente: el de siempre de cada cabecera.
    let verticalPadding: CGFloat
    @ViewBuilder var period: Period
    @ViewBuilder var caption: Caption
    @ViewBuilder var figure: Figure
    @ViewBuilder var detail: Detail

    var body: some View {
        Group {
            if isShort {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: DS.Spacing.xl) {
                        VStack(alignment: .center, spacing: DS.Spacing.xs) { figureWithCaption }
                        VStack(alignment: .center, spacing: DS.Spacing.xs) {
                            period
                            detail
                        }
                    }
                    VStack(alignment: .center, spacing: DS.Spacing.xs) {
                        HStack(alignment: .center, spacing: DS.Spacing.md) {
                            period
                            VStack(alignment: .center, spacing: DS.Spacing.xs) { figureWithCaption }
                        }
                        detail
                    }
                    VStack(alignment: .center, spacing: DS.Spacing.xs) {
                        period
                        figureWithCaption
                        HStack(spacing: DS.Spacing.md) { detail }
                    }
                    VStack(alignment: .center, spacing: DS.Spacing.xs) {
                        period
                        figureWithCaption
                        detail
                    }
                }
                .padding(.vertical, DS.Spacing.xs)
            } else {
                HeroHeader {
                    caption
                } period: {
                    period
                } content: {
                    figure
                    detail
                }
                .padding(.vertical, verticalPadding)
            }
        }
        // Sin margen lateral propio en ninguno de los dos: el del scroll (`scrollViewGlassEdges`) ya pone los 16 pt
        // del resto de la pantalla, y el hero, alineado a la izquierda, tiene que caer en ese mismo eje (como en el
        // Panel). Con poco alto, además, en la columna de lista del Pro Max girado esos 32 pt son los que dejan caber
        // el período al lado de la cifra (medido: 320 → 352).
        .frame(maxWidth: .infinity)
    }

    /// En la banda el rótulo va bajo la cifra, centrado: arriba no hay fila de período donde ponerlo.
    @ViewBuilder
    private var figureWithCaption: some View {
        figure
        caption
            .multilineTextAlignment(.center)
    }
}

extension View {
    /// Mide el alto de este contenedor —con las barras que se le superponen, que son márgenes de seguridad— y
    /// escribe en `isShort` si está por debajo de `DS.Adaptive.shortContainerMaxHeight`. Para el `ScrollView` que
    /// lleva una `SummaryHeaderStack`.
    func measuresShortContainer(_ isShort: Binding<Bool>) -> some View {
        onGeometryChange(for: Bool.self) { proxy in
            DS.Adaptive.isShortContainer(
                height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
        } action: { short in
            isShort.wrappedValue = short
        }
    }
}
