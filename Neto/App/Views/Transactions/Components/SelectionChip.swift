//
//  SelectionChip.swift
//  Neto
//
//  Extracted from NewTransactionView - Reusable selection chip component
//

import SwiftUI

// MARK: - Selection Chip

struct SelectionChip: View {
    let icon: String
    let text: String
    let isSelected: Bool
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))

                Text(text)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? (color ?? Color.electricIndigo) : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        isSelected ? (color ?? Color.electricIndigo).opacity(0.12) : Color.netoCard)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? (color ?? Color.electricIndigo).opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        SelectionChip(icon: "creditcard", text: "Cuenta", isSelected: false) {}
        SelectionChip(icon: "tag", text: "Comida", isSelected: true, color: .orange) {}
    }
    .padding()
}
