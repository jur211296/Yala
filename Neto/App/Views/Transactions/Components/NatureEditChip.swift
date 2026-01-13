//
//  NatureEditChip.swift
//  Neto
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
            HStack(spacing: 4) {
                Circle()
                    .fill(nature.color)
                    .frame(width: 6, height: 6)

                Text(nature.displayName)
                    .font(.caption2.weight(.medium))

                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(nature.color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}
