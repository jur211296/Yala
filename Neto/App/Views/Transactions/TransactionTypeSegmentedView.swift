//
//  TransactionTypeSegmentedView.swift
//  Neto
//
//  Created by Neto - New Transaction Form.
//

import SwiftUI

// MARK: - Transaction Type Segmented View

/// Selector tipo cápsula iOS para Gasto/Ingreso/Transferencia
struct TransactionTypeSegmentedView: View {
    @Binding var selectedType: TransactionType

    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TransactionType.allCases) { type in
                TransactionTypeButton(
                    type: type,
                    isSelected: selectedType == type,
                    animation: animation
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedType = type
                    }
                }
            }
        }
        .padding(DS.Spacing.xs)
        .background(
            Capsule()
                .fill(Color.netoCard)
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Transaction Type Button

struct TransactionTypeButton: View {
    let type: TransactionType
    let isSelected: Bool
    let animation: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(type.displayName)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(type.color)
                            .matchedGeometryEffect(id: "selection", in: animation)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: DS.Spacing.xl) {
        TransactionTypeSegmentedView(selectedType: .constant(.expense))
        TransactionTypeSegmentedView(selectedType: .constant(.income))
        TransactionTypeSegmentedView(selectedType: .constant(.transfer))
    }
    .padding()
    .background(Color.netoBackground)
}
