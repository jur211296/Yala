//
//  NeedEditChip.swift
//  Yala
//
//  Editable nature chip for transaction form
//

import SwiftUI

// MARK: - Nature Edit Chip

struct NeedEditChip: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let need: SubcategoryNeed
    /// Relleno con el color de la necesidad y texto blanco AA (UX 2.2 · L2-19). Solo el formulario de registro lo pide.
    var filled: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(filled ? Color.white : need.color)
                    .frame(width: 6, height: 6)

                Text(need.displayName)
                    .font(DS.Typography.labelTiny)

                Image(systemName: "chevron.down")
                    .font(DS.Typography.captionSmall)
            }
            .foregroundStyle(filled ? Color.white : Color.secondary)
            .padding(.horizontal, DS.Chip.paddingH)
            .padding(.vertical, DS.Chip.paddingV)
            .background(
                Capsule().fill(filled ? Color.selectedFill(need.color) : need.color.opacity(0.1))
            )
            .animation(filled ? (reduceMotion ? .easeInOut(duration: DS.Animation.fast) : .spring(response: 0.3, dampingFraction: 0.7)) : nil,
                       value: need)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(need.displayName)
        .accessibilityIdentifier("new_transaction_need_chip")
    }
}
