//
//  TransactionTypeSegmentedView.swift
//  Yala
//
//  Created by Yala - New Transaction Form.
//

import SwiftUI

// MARK: - Transaction Type Segmented View

/// Selector tipo cápsula iOS para Gasto/Ingreso/Transferencia
struct TransactionTypeSegmentedView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedType: TransactionType
    var availableTypes: [TransactionType] = TransactionType.allCases

    @Namespace private var animation

    var body: some View {
        HStack(spacing: DS.Spacing.none) {
            ForEach(availableTypes) { type in
                TransactionTypeButton(
                    type: type,
                    isSelected: selectedType == type,
                    animation: animation
                ) {
                    dsWithAnimation(reduceMotion) {
                        selectedType = type
                    }
                }
            }
        }
        .padding(DS.Spacing.xs)
        .background(
            Capsule()
                .fill(.thCard)
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
                .font(DS.Typography.label.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Chip.paddingV)
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
    .background(.thBackground)
}
