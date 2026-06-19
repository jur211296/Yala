//
//  PreviewMode.swift
//  Yala
//
//  Environment flag para evitar recursión visual cuando un widget se renderiza
//  dentro del preview de su propia sheet pedagógica. Cuando el flag está
//  activo, los botones `info.circle` (legacy `InfoHintButton` y nuevo
//  `WidgetInfoButton`) se ocultan.
//

import SwiftUI

private struct WidgetPreviewModeKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// True cuando la vista se renderiza dentro del recuadro de preview de
    /// `WidgetInfoSheet`. Los componentes que muestran `info.circle` deben
    /// retornar `EmptyView` en ese caso para evitar abrir un segundo sheet.
    var isWidgetPreviewMode: Bool {
        get { self[WidgetPreviewModeKey.self] }
        set { self[WidgetPreviewModeKey.self] = newValue }
    }
}
