//
//  ToolbarVerticalBar.swift
//  Yala
//
//  iPhone Duo (compilando con el SDK de iOS 27.1): con el Duo cerrado, y abierto en horizontal, las barras de
//  navegación, herramientas y pestañas pasan a una barra vertical en el lateral, bajo la barra de estado. Pasan solos
//  los botones con icono; un item con vista propia (la bandeja del Panel, con su contador) se queda fuera si no se le
//  pide, y en el Panel —sin título arriba— acababa flotando abajo, encima de la gráfica. Y en la barra vertical cabe
//  poco: lo que no cabe se va al menú «···» del sistema. Estas envolturas dicen qué hace cada item; en un iPhone y en un
//  iPad, sin barra vertical y con sitio, no cambian nada.
//

import SwiftUI

extension ToolbarContent {
    /// Un item con vista propia que también va en la barra vertical. Para los que ya son un botón con icono no hace
    /// falta: van solos.
    @ToolbarContentBuilder
    func joinsVerticalBar() -> some ToolbarContent {
        if #available(iOS 27.1, *) {
            axisBehavior(.verticalPreferred)
        } else {
            self
        }
    }

    /// El último en irse al menú «···» cuando falta sitio: lo que lleva contador o se usa a menudo (Apple, «Designing
    /// for iPhone Duo»). Un item con vista propia, además, no tiene cómo pintarse dentro del menú.
    @ToolbarContentBuilder
    func overflowsLast() -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            visibilityPriority(.high)
        } else {
            self
        }
    }

    /// El primero en irse al menú «···» cuando falta sitio: un ajuste de la pantalla que se toca poco. Necesita título
    /// además de icono, que es lo que el menú enseña.
    @ToolbarContentBuilder
    func overflowsFirst() -> some ToolbarContent {
        if #available(iOS 27.0, *) {
            visibilityPriority(.low)
        } else {
            self
        }
    }
}
