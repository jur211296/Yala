//
//  WidgetCardBackground.swift
//  YalaWidgets
//
//  El fondo de todos los widgets de la pantalla de inicio (`containerBackground(for: .widget)`): un degradado vertical
//  muy sutil y un borde fino iluminado arriba. La referencia es el widget de batería de Apple en oscuro (pedido de
//  Jürgen del 2026-11-02): casi negro, con profundidad y sin competir con las cifras.
//
//  Es la excepción de los widgets a «sin degradados» de la marca: el degradado es de un solo tono y no lleva brillos
//  ni glows. Un widget de terceros no tiene glass de verdad en iOS (`WidgetTexture.glass` es solo de visionOS y un
//  `Material` no ve el fondo de pantalla); en tintado, transparente y StandBy el sistema quita este fondo y pone el
//  suyo, así que aquí no hay nada que adaptar a esos modos.
//

import SwiftUI

struct WidgetCardBackground: View {
    /// Un relleno de marca (el azulejo pequeño de Entrada rápida) en vez de la tarjeta.
    var fill: Color?

    init(fill: Color? = nil) {
        self.fill = fill
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: surface, startPoint: .top, endPoint: .bottom)
            ContainerRelativeShape()
                .strokeBorder(
                    LinearGradient(colors: edge, startPoint: .top, endPoint: .bottom),
                    lineWidth: WidgetDS.Card.edgeWidth
                )
        }
    }

    private var surface: [Color] {
        guard let fill else { return [WidgetColors.cardTop, WidgetColors.cardBottom] }
        return [fill, fill.mix(with: .black, by: WidgetDS.Card.fillShade)]
    }

    private var edge: [Color] {
        guard fill != nil else { return [WidgetColors.cardEdgeTop, WidgetColors.cardEdgeBottom] }
        return [Color.white.opacity(WidgetDS.Card.fillEdgeTop), Color.white.opacity(WidgetDS.Card.fillEdgeBottom)]
    }
}
