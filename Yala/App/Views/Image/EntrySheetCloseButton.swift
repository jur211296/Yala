//
//  EntrySheetCloseButton.swift
//  Yala
//
//  La X de las hojas de foto (personal y Grupos) y de voz de Grupos: el botón de cerrar del sistema (`role: .close`,
//  iOS 26), con el círculo de cristal y la zona táctil de 44 pt de la X de las barras, la de Nuevo registro (encargo «X
//  nativa en la hoja de foto», 2026-11-17). Antes era un `YalaToolbarButton` con `.glass` fuera de una barra y salía
//  diminuto. Va en la fila de la cabecera y no en una barra de navegación: la hoja cambia de alto y presenta otras hojas
//  encima, y una pila de navegación solo para la X cambiaría su fondo y sus anclas.
//

import SwiftUI

struct EntrySheetCloseButton: View {
    let action: () -> Void

    /// El lado del círculo de la X de las barras de iOS 26.
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 44 // A11Y-DT: X del sistema, 44 pt como en las barras

    var body: some View {
        let diameter = min(max(side, 44), 56) // A11Y-DT: nunca menos que la X del sistema; tope con letra grande
        Button(role: .close, action: action) {
            Image(systemName: "xmark")
                .font(DS.Typography.body.weight(.medium))
                .foregroundStyle(Color.primary)
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(L10n.Action.close)
    }
}

/// ‹ en el sitio de la X, con el mismo círculo de cristal: vuelve a lo leído sin cerrar la hoja («Otra foto» y «Otra vez»
/// suman a lo leído, opción A de «Esto leí», 2026-11-22).
struct EntrySheetBackButton: View {
    let action: () -> Void

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 44 // A11Y-DT: misma medida que la X

    var body: some View {
        let diameter = min(max(side, 44), 56) // A11Y-DT: nunca menos que la X del sistema; tope con letra grande
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(DS.Typography.body.weight(.medium))
                .foregroundStyle(Color.primary)
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(L10n.Action.back)
    }
}
