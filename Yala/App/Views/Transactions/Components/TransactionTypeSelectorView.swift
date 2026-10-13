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
                    // Tocar el tipo que ya está elegido no cambia nada. Antes volvía a llamar a
                    // `onTypeChange`, que borra la subcategoría (y con ella la necesidad): un toque
                    // de más sobre «Gasto» dejaba el formulario sin categoría y «Guardar» apagado.
                    // Auditoría UX 2.2, lote 2, B2.
                    guard type != selectedType else { return }
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
                        .padding(.vertical, DS.Chip.paddingV)
                        .background(
                            Capsule()
                                .fill(selectedType == type ? type.color : Color.clear)
                        )
                }
                .accessibilityAddTraits(selectedType == type ? .isSelected : [])
                .accessibilityIdentifier("new_transaction_type_\(type.rawValue)")
            }
        }
        .padding(DS.Spacing.xs)
        .background(Capsule().fill(.thCard))
        .padding(.horizontal, DS.Spacing.lg)
    }
}
