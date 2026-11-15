//
//  ContentSizedListHeight.swift
//  Yala
//
//  El alto de una `List` sin scroll propio metida en un `ScrollView` (Ajustes › Etiquetas y Cuentas, que la usan para
//  reordenar arrastrando). Una `List` así no dice cuánto mide: hasta ahora el alto se calculaba a mano (filas × alto de
//  fila), y con texto de accesibilidad las filas crecen más que esa cuenta y la última quedaba cortada (lote 05 de 2.3,
//  zona 39 P8 · H2).
//

import SwiftUI

extension View {
    /// Fija el alto de una `List` con `scrollDisabled(true)`. A tamaño normal, `estimated` tal cual: lo de siempre, al
    /// píxel. Con texto de accesibilidad, lo que mide su contenido (nunca menos que `estimated`, para que no encoja
    /// mientras mide).
    func contentSizedListHeight(estimated: CGFloat) -> some View {
        modifier(ContentSizedListHeight(estimated: estimated))
    }
}

private struct ContentSizedListHeight: ViewModifier {
    let estimated: CGFloat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var contentHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentSize.height
            } action: { _, height in
                contentHeight = height
            }
            .frame(height: dynamicTypeSize.isAccessibilitySize ? max(estimated, contentHeight) : estimated)
    }
}
