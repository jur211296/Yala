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
    @Binding var selectedType: TransactionType
    var availableTypes: [TransactionType] = TransactionType.allCases

    var body: some View {
        GenericSegmentedPill(
            options: availableTypes,
            selection: $selectedType,
            labelProvider: { $0.displayName },
            selectedFillColorProvider: { $0.color }
        )
        .shadow(color: DS.Shadow.subtle.color, radius: DS.Shadow.medium.radius, x: 0, y: DS.Shadow.medium.y)
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
