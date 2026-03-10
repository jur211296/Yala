//
//  NeedEditChip.swift
//  Yala
//
//  Editable nature chip for transaction form
//

import SwiftUI

// MARK: - Nature Edit Chip

struct NeedEditChip: View {
    let need: SubcategoryNeed
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(need.color)
                    .frame(width: 6, height: 6)

                Text(need.displayName)
                    .font(DS.Typography.labelTiny)

                Image(systemName: "chevron.down")
                    .font(DS.Typography.captionSmall)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.Chip.paddingH)
            .padding(.vertical, DS.Chip.paddingV)
            .background(
                Capsule().fill(need.color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(need.displayName)
    }
}
