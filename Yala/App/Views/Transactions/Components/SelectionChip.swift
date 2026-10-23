//
//  SelectionChip.swift
//  Yala
//
//  Extracted from NewTransactionView - Reusable selection chip component
//

import SwiftUI

// MARK: - Selection Chip

struct SelectionChip: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let icon: String
    let text: String
    let isSelected: Bool
    var color: Color? = nil
    /// Falta para poder guardar (UX 2.2 · L2-2): borde del color de acento.
    var isMissing: Bool = false
    /// Lo elegido va relleno con su color y texto blanco AA, con un rebote del icono y el relleno animado (UX 2.2 · L2-19
    /// y L2-21). Solo el formulario de registro lo pide; los demás formularios siguen con el tinte de siempre.
    var fillsWhenSelected: Bool = false
    let action: () -> Void

    private var baseColor: Color { color ?? theme.accent }

    private var foreground: Color {
        guard isSelected else { return .secondary }
        return fillsWhenSelected ? .white : baseColor
    }

    private var background: Color {
        guard isSelected else { return theme.card }
        return fillsWhenSelected ? Color.selectedFill(baseColor) : baseColor.opacity(0.12)
    }

    private var stroke: Color {
        if isMissing { return theme.accent }
        guard isSelected, !fillsWhenSelected else { return .clear }
        return baseColor.opacity(0.3)
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(DS.Typography.labelSmall)
                    .symbolEffect(.bounce, value: fillsWhenSelected && !reduceMotion ? isSelected : false)

                Text(text)
                    .font(DS.Typography.label)
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, DS.FormRow.paddingV)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(background))
            .overlay(
                Capsule()
                    .stroke(stroke, lineWidth: isMissing ? 1.5 : 1)
            )
            // Con «Reducir movimiento», solo un fundido de color (L2-21).
            .animation(
                fillsWhenSelected
                    ? (reduceMotion ? .easeInOut(duration: DS.Animation.fast) : .spring(response: 0.3, dampingFraction: 0.7))
                    : nil,
                value: isSelected
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityValue(isMissing ? L10n.UXL2.missingChipValue : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        SelectionChip(icon: "creditcard", text: "Cuenta", isSelected: false) {}
        SelectionChip(icon: "tag", text: "Comida", isSelected: true, color: .orange, fillsWhenSelected: true) {}
    }
    .padding()
}
