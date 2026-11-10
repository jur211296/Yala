//
//  ReadableColumn.swift
//  Yala
//
//  Ancho legible de una página (decisión 7 de la revisión 2.3, opción C, Jürgen, 9-nov): en una ventana ancha el
//  contenido no pasa de `DS.Adaptive.readableWidth` (700 pt) y queda centrado; más allá, concepto e importe dejan de
//  leerse juntos. Va DENTRO del scroll, en el contenido: el scroll sigue a todo lo ancho y se desplaza también desde
//  los márgenes. En el iPhone en vertical no cambia nada (ningún iPhone llega a 700). Decide el ancho, no el aparato.
//
//  Las dos columnas, cuando lleguen, se diseñan vista por vista con maqueta: esto no las sustituye.
//

import SwiftUI

extension View {
    /// El contenido de una página a ancho legible y centrado. Lo usan Distribución, Reportes, las páginas del detalle de
    /// un grupo y el formulario de una cuenta (`ReadableWidthIPadUITests`).
    func readableColumn() -> some View {
        frame(maxWidth: DS.Adaptive.readableWidth)
            .frame(maxWidth: .infinity)
    }
}
