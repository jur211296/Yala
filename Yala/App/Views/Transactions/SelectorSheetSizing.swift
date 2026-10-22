//
//  SelectorSheetSizing.swift
//  Yala
//
//  Cómo abre un selector de registro (cuenta, etiquetas, subcategoría). Desde Nuevo registro, el formulario de
//  gasto de grupo y la card de Yala IA abre a media altura y el usuario la estira a grande si quiere (ticket
//  `record-selectors-open-at-medium-detent`). El resto de anfitriones (edición masiva, Inbox, favoritos…) sigue
//  como estaba: `.large`, que no declara detent y deja decidir a quien presenta.
//
//  Mismo patrón que el formulario de cuenta (`AccountFormView`): `[.medium, .large]` con `.yalaSheetDetents`,
//  grande en ventana ancha y con texto de accesibilidad, y fondo transparente a media altura.
//

import SwiftUI

enum SelectorSheetSizing {
    /// Como siempre: el selector no declara detent.
    case large
    /// Media altura al abrir; el usuario la estira a grande.
    case mediumFirst

    /// Los detents que declara el selector. Vacío = no declara ninguno.
    func detents(dynamicTypeSize: DynamicTypeSize) -> Set<PresentationDetent> {
        switch self {
        case .large:
            return []
        case .mediumFirst:
            // Con texto de accesibilidad, media altura enseña una o dos filas: abre grande.
            return dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large]
        }
    }

    /// Fondo de la hoja: transparente mientras está a media altura, `.subtle` cuando se ve grande —porque el usuario
    /// la estiró, porque la ventana ancha la fuerza a `.large` o porque no hay medium que mostrar—.
    func background(
        selectedDetent: PresentationDetent,
        usesLargeSheets: Bool,
        dynamicTypeSize: DynamicTypeSize
    ) -> YalaBackgroundVariant {
        guard detents(dynamicTypeSize: dynamicTypeSize).contains(.medium) else { return .subtle }
        return usesLargeSheets || selectedDetent == .large ? .subtle : .transparent
    }
}

/// Aplica los detents del selector, o nada si es `.large`.
private struct SelectorSheetSizingModifier: ViewModifier {
    let sizing: SelectorSheetSizing
    @Binding var selectedDetent: PresentationDetent
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    func body(content: Content) -> some View {
        let detents = sizing.detents(dynamicTypeSize: dynamicTypeSize)
        if detents.isEmpty {
            content
        } else {
            content.yalaSheetDetents(detents, selection: $selectedDetent)
        }
    }
}

extension View {
    func selectorSheetSizing(_ sizing: SelectorSheetSizing, selectedDetent: Binding<PresentationDetent>) -> some View {
        modifier(SelectorSheetSizingModifier(sizing: sizing, selectedDetent: selectedDetent))
    }
}
