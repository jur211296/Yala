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
    /// La cápsula elegida se desliza de un tipo al otro en vez de fundirse (card pjum).
    @Namespace private var selectionNamespace
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
                    DS.Haptic.selection()
                    dsWithAnimation(reduceMotion, DS.Animation.selection) {
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
                        .background {
                            if selectedType == type {
                                Capsule()
                                    .fill(type.color)
                                    .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                            }
                        }
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
