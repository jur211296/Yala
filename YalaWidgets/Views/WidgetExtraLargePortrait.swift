//
//  WidgetExtraLargePortrait.swift
//  YalaWidgets
//
//  El tamaño extragrande vertical del iPhone con iOS 27 (`systemExtraLargePortrait`: 4 × 6 casillas, una página
//  entera de la pantalla de inicio). La app es iOS 26+, así que el tamaño solo se ofrece detrás de `#available`, y
//  las vistas lo preguntan con `isExtraLargePortrait` en vez de nombrar el case (que no existe en iOS 26).
//

import SwiftUI
import WidgetKit

enum WidgetFamilies {
    /// `base` más el extragrande vertical cuando el sistema lo tiene. Lo usan Resumen del mes, Pagos planificados y
    /// Entradas y salidas (decisión de Jürgen del 2026-10-20, opción C).
    static func addingExtraLargePortrait(_ base: [WidgetFamily]) -> [WidgetFamily] {
        if #available(iOS 27.0, *) {
            return base + [.systemExtraLargePortrait]
        }
        return base
    }
}

extension WidgetFamily {
    /// `true` en el extragrande vertical de iOS 27; `false` en cualquier otro tamaño y en iOS 26.
    var isExtraLargePortrait: Bool {
        if #available(iOS 27.0, *) {
            return self == .systemExtraLargePortrait
        }
        return false
    }
}
