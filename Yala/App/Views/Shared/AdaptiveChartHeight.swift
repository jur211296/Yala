//
//  AdaptiveChartHeight.swift
//  Yala
//
//  Da a una gráfica un alto que crece con su propio ancho en los iPhone grandes, sin tocar el iPhone pequeño ni el
//  iPad. La regla vive en `DS.Adaptive.chartHeight(base:width:sizeClass:)`.
//

import SwiftUI

/// Mide el ancho que recibe su contenido y le pasa el alto que le toca.
///
/// El contenido ocupa todo el ancho ofrecido (las gráficas lo hacen), así que el ancho medido es el de la gráfica. El
/// alto no influye en el ancho, de modo que medir y aplicar no se realimentan. Antes de la primera medida pinta `base`,
/// que es lo mismo que pintaba antes de este contenedor.
struct AdaptiveChartHeight<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var width: CGFloat = 0

    private let base: CGFloat
    private let content: (CGFloat) -> Content

    init(base: CGFloat, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.base = base
        self.content = content
    }

    var body: some View {
        content(DS.Adaptive.chartHeight(base: base, width: width, sizeClass: sizeClass))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}
