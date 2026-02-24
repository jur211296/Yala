//
//  NatureEditChip.swift
//  Yala
//
//  Editable nature chip for transaction form
//

import SwiftUI

// MARK: - Nature Edit Chip

struct NatureEditChip: View {
    let nature: SubcategoryNature
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(nature.color)
                    .frame(width: 6, height: 6)

                Text(nature.displayName)
                    .font(DS.Typography.labelTiny)

                Image(systemName: "chevron.down")
                    .font(DS.Typography.captionSmall)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Chip.paddingH)
            .padding(.vertical, DS.Chip.paddingV)
            .background(
                Capsule().fill(nature.color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(nature.displayName)
    }
}
