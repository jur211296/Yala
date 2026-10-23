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
    let icon: String
    let text: String
    let isSelected: Bool
    var color: Color? = nil
    /// Falta para poder guardar (UX 2.2 · L2-2): borde del color de acento.
    var isMissing: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(DS.Typography.labelSmall)

                Text(text)
                    .font(DS.Typography.label)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? (color ?? theme.accent) : .secondary)
            .padding(.horizontal, DS.FormRow.paddingV)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(
                        isSelected ? (color ?? theme.accent).opacity(0.12) : theme.card)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isMissing ? theme.accent : (isSelected ? (color ?? theme.accent).opacity(0.3) : Color.clear),
                        lineWidth: isMissing ? 1.5 : 1
                    )
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
        SelectionChip(icon: "tag", text: "Comida", isSelected: true, color: .orange) {}
    }
    .padding()
}
