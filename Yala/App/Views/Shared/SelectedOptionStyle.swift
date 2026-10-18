//
//  SelectedOptionStyle.swift
//  Yala
//
//  UX 2.2 · L16-9 (variante 1 elegida por Jürgen el 2026-10-15). En Temas, Icono de la app y las hojas de selección de
//  Ajustes lo elegido se distinguía solo por un contorno o un ✓ pequeño, y todo lo demás era la misma tarjeta gris. El
//  criterio de Jürgen: lo elegido va relleno de color, no solo con contorno.
//
//  Dos piezas: el relleno índigo suave con borde (para filas y tarjetas) y la etiqueta «En uso» (para tarjetas, donde
//  el ✓ quedaba perdido junto al nombre).
//

import SwiftUI

/// El relleno de una opción elegida: el color de acento suave por dentro y un borde del mismo color. Sin elegir, nada:
/// la fila o la tarjeta conservan su fondo.
struct SelectedOptionFill: ViewModifier {
    let isSelected: Bool
    var radius: CGFloat = DS.Radius.md
    var lineWidth: CGFloat = 1.5

    @Environment(\.yalaTheme) private var theme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(isSelected ? theme.accent.opacity(0.28) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(isSelected ? theme.accent : Color.clear, lineWidth: lineWidth)
            )
    }
}

extension View {
    /// Rellena la opción elegida de una fila o tarjeta de selección (UX 2.2 · L16-9).
    func selectedOptionFill(_ isSelected: Bool, radius: CGFloat = DS.Radius.md, lineWidth: CGFloat = 1.5) -> some View {
        modifier(SelectedOptionFill(isSelected: isSelected, radius: radius, lineWidth: lineWidth))
    }
}

/// «En uso»: la etiqueta de la tarjeta elegida en Temas e Icono de la app, rellena del color de acento.
struct InUseBadge: View {
    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Text(L10n.UXL16.inUse)
            .font(DS.Typography.captionSmall.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.xxs)
            .background(Capsule().fill(theme.accent))
            .accessibilityHidden(true)
    }
}
