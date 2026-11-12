//
//  SelectedFillColor.swift
//  Yala
//
//  El relleno de lo elegido (UX 2.2 · L2-19): el color de la cosa, oscurecido lo justo para que el texto blanco encima
//  dé ≥ 4,5:1. La cuenta lógica vive en `SelectedFillContrast`; aquí solo el puente a `Color`.
//

import SwiftUI
import UIKit

extension Color {
    /// Relleno de un chip o una fila elegida con texto blanco encima, a partir del hex de la cuenta, categoría, necesidad
    /// o etiqueta.
    static func selectedFill(hex: String) -> Color {
        guard let rgb = SelectedFillContrast.rgb(fromHex: hex) else { return Color(hex: hex) }
        return Color(SelectedFillContrast.fill(for: rgb))
    }

    /// Lo mismo a partir de un `Color` ya resuelto (el acento del tema, el color de una necesidad).
    static func selectedFill(_ color: Color) -> Color {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return color }
        let rgb = SelectedFillContrast.RGB(red: Double(red), green: Double(green), blue: Double(blue))
        return Color(SelectedFillContrast.fill(for: rgb))
    }

    private init(_ rgb: SelectedFillContrast.RGB) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue) // A11Y-DM: relleno derivado del color elegido
    }
}
