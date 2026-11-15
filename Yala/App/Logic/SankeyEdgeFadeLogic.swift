//
//  SankeyEdgeFadeLogic.swift
//  Yala
//
//  Qué bordes del Sankey se funden. El Sankey se desplaza a lo ancho y la etiqueta de la columna que queda en el borde
//  visible se partía en seco a media cifra («Gastos S/ 3,507 (»): se leía como un dato roto (lote 07 de mejoras
//  necesarias 2.3). Como en los carruseles (Jürgen, 2026-10-25), el borde por el que queda contenido se funde en vez de
//  cortarse, y al llegar al final ese lado se ve entero.
//

import CoreGraphics

enum SankeyEdgeFadeLogic {

    struct Edges: Equatable {
        let leading: Bool
        let trailing: Bool

        static let none = Edges(leading: false, trailing: false)
    }

    /// Medio punto de margen: el desplazamiento rara vez acaba en el píxel exacto del extremo.
    private static let tolerance: CGFloat = 0.5

    /// `offsetX`: lo desplazado desde el inicio. Se funde el lado por el que queda contenido por ver.
    static func edges(offsetX: CGFloat, contentWidth: CGFloat, containerWidth: CGFloat) -> Edges {
        let scrollable = contentWidth - containerWidth
        guard scrollable > tolerance else { return .none }
        return Edges(
            leading: offsetX > tolerance,
            trailing: offsetX < scrollable - tolerance
        )
    }
}
