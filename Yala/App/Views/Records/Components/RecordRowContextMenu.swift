//
//  RecordRowContextMenu.swift
//  Yala
//
//  Menú contextual de una fila de registro (fase 3 del carril adaptativo): clic secundario en el iPad, pulsación
//  larga en cualquier iPhone. Qué ofrece lo decide `RecordContextActionLogic`; aquí solo se cablea.
//

import SwiftData
import SwiftUI

extension RecordContextActionLogic.Shape {
    init(record: TransactionItem) {
        self.init(
            hasBalanceAdjustmentType: record.balanceAdjustmentType != nil,
            hasSplitExpenseID: record.splitExpenseID != nil,
            hasSplitSettlementID: record.splitSettlementID != nil,
            accountIsNil: record.account == nil,
            accountIsSystem: record.account?.isSystemAccount ?? false,
            subcategoryIsSystem: record.subcategory?.isAnySystem ?? false)
    }
}

/// Las acciones del menú. En modo selección no hay menú: ahí el toque selecciona.
struct RecordRowContextMenu: ViewModifier {
    let record: TransactionItem
    let viewModel: RecordsViewModel

    func body(content: Content) -> some View {
        content.contextMenu {
            if !viewModel.isSelectionMode {
                items
            }
        }
    }

    @ViewBuilder
    private var items: some View {
        let actions = RecordContextActionLogic.actions(.init(record: record))
        Button(L10n.Action.edit, systemImage: "pencil") {
            viewModel.editOpenRecord(record)
        }
        if actions.canDuplicate {
            Button(L10n.Action.duplicate, systemImage: "doc.on.doc") {
                viewModel.duplicateRecord(record)
            }
        }
        if actions.canChangeCategory {
            Button(L10n.Keyboard.changeCategory, systemImage: "folder") {
                viewModel.categoryChangeRecord = record
            }
        }
        if actions.canDelete {
            Divider()
            Button(L10n.Action.delete, systemImage: "trash", role: .destructive) {
                viewModel.requestDelete(record)
            }
        }
    }
}

/// Lo que el menú (y ⌫) presenta: la confirmación de borrado y el selector de categoría. Vive en la lista
/// (`RecordsTabView`), que comparten Registros y Estadísticas › Registros; el editor lo presenta cada host con su hoja
/// de siempre (`showEditTransaction`).
struct RecordRowActionsPresenter: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: RecordsViewModel

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                L10n.Records.deleteConfirmTitle(1),
                isPresented: $viewModel.isConfirmingSingleDelete,
                titleVisibility: .visible
            ) {
                Button(L10n.Action.delete, role: .destructive) {
                    viewModel.confirmPendingDelete(context: modelContext)
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Common.cannotUndo)
            }
            .sheet(item: $viewModel.categoryChangeRecord) { record in
                RecordCategoryChangeSheet(record: record, viewModel: viewModel)
            }
    }
}

/// El selector de subcategorías de siempre, para un registro. Aplica al cerrarse, como la edición masiva.
private struct RecordCategoryChangeSheet: View {
    @Environment(\.modelContext) private var modelContext
    let record: TransactionItem
    let viewModel: RecordsViewModel
    @State private var selected: Subcategory?

    var body: some View {
        SubcategorySelectorSheet(
            selectedSubcategory: $selected,
            transactionType: TransactionClassificationLogic.isIncome(record) ? .income : .expense
        )
        .onDisappear(perform: apply)
    }

    private func apply() {
        guard let selected else { return }
        viewModel.updateSubcategory(selected, ids: [record.persistentModelID], context: modelContext)
    }
}
