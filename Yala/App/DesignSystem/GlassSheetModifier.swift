//
//  GlassSheetModifier.swift
//  Yala
//
//  iOS 26 Liquid Glass sheet modifier. Aplica el fondo glass canónico +
//  .presentationDragIndicator() en una llamada.
//
//  Uso (DENTRO del contenido de la sheet, NO en el .sheet modifier):
//
//      .sheet(isPresented: $show) {
//          NavigationStack {
//              MiFormulario()
//          }
//          .glassSheet()
//      }
//
//  Nota sobre la API nativa: el tipo `Glass` de iOS 26 (`Glass.regular`/`.clear`) NO
//  conforma `ShapeStyle`, así que `.presentationBackground(_:)` no lo acepta. El fondo
//  más cercano al Liquid Glass para sheets es `.ultraThinMaterial`, visualmente
//  equivalente. Si Apple expone un shorthand de ShapeStyle para glass en el futuro
//  (p.ej. `.glassMaterial`), el cambio se aplica en este único lugar.
//

import SwiftUI

extension View {
    /// iOS 26 Liquid Glass sheet presentation. Centraliza `.presentationBackground(...)`
    /// + `.presentationDragIndicator(.visible)` con el look glass canónico.
    ///
    /// Aplicar al contenido interior de `.sheet { ... }` (NavigationStack o vista raíz
    /// de la sheet), NO al view que presenta la sheet.
    ///
    /// - Parameter dragIndicator: Visibilidad del drag indicator. Default `.visible`.
    func glassSheet(dragIndicator: Visibility = .visible) -> some View {
        self
            .presentationBackground(.ultraThinMaterial)
            .presentationDragIndicator(dragIndicator)
    }
}
