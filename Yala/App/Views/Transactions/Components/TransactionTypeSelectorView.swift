//
//  TransactionTypeSelectorView.swift
//  Yala
//
//  Extracted from NewTransactionView - Transaction type selector (Expense/Income/Transfer)
//

import SwiftUI

// MARK: - Transaction Type Selector

struct TransactionTypeSelectorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedType: TransactionType
    var availableTypes: [TransactionType] = TransactionType.allCases
    var onTypeChange: ((TransactionType) -> Void)?

    var body: some View {
        // Hide selector completely when only one type available
        if availableTypes.count <= 1 {
            EmptyView()
        } else {
            selectorContent
        }
    }

    private var selectorContent: some View {
        HStack(spacing: DS.Spacing.none) {
            ForEach(availableTypes) { type in
                Button {
                    dsWithAnimation(reduceMotion) {
                        selectedType = type
                        onTypeChange?(type)
                    }
                } label: {
                    Text(type.displayName)
                        .font(
                            .subheadline.weight(
                                selectedType == type ? .semibold : .regular)
                        )
                        .foregroundStyle(selectedType == type ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Chip.paddingH)
                        .background(
                            Capsule()
                                .fill(selectedType == type ? type.color : Color.clear)
                        )
                }
            }
        }
        .padding(DS.Spacing.xs)
        .background(Capsule().fill(.thCard))
        .padding(.horizontal, DS.Spacing.lg)
    }
}
