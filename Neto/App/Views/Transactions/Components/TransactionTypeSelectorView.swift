//
//  TransactionTypeSelectorView.swift
//  Neto
//
//  Extracted from NewTransactionView - Transaction type selector (Expense/Income/Transfer)
//

import SwiftUI

// MARK: - Transaction Type Selector

struct TransactionTypeSelectorView: View {
    @Binding var selectedType: TransactionType
    var onTypeChange: ((TransactionType) -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TransactionType.allCases) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedType == type ? type.color : Color.clear)
                        )
                }
            }
        }
        .padding(DS.Spacing.xs)
        .background(Capsule().fill(Color.netoCard))
        .padding(.horizontal, DS.Spacing.lg)
    }
}
