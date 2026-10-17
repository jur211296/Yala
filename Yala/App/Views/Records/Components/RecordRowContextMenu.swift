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

extension RecordBulkActionLogic.DeleteDialog {
    var titleText: String {
        switch title {
        case .deleteCount(let count): L10n.Records.deleteConfirmTitle(count)
        case .onlyGroupRecords: L10n.Records.groupRecordsOnlyTitle
        }
    }

    var messageText: String {
        switch message {
        case .cannotUndo: L10n.Common.cannotUndo
        case .cannotUndoKeepingGroupRecords(let count): "\(L10n.Records.groupRecordsKept(count)) \(L10n.Common.cannotUndo)"
        case .deleteFromGroup: L10n.Records.groupRecordsDeleteFromGroup
        }
    }
}

/// La pregunta de borrado de un registro, igual en el menú, ⌫, el detalle, el modo selección y el editor (auditoría UX
/// 2.2, L8-7, opción B): dice qué se borra y sale centrada, con Cancelar a la vista.
enum RecordDeleteConfirmationText {
    /// «¿Eliminar «Uber · S/ 26»?». Sin nota ni categoría, solo el importe.
    static func title(for record: TransactionItem, preferences: AppPreferences) -> String {
        let amount = preferences.currency(abs(record.amount), currencyCode: record.currencyCode)
        let summary = RecordDeleteConfirmationLogic.displayName(
            note: record.note,
            subcategoryName: record.subcategory?.name,
            categoryName: record.category?.name
        ).map { RecordDeleteConfirmationLogic.summary(name: $0, amount: amount) } ?? amount
        return L10n.UXL8.deleteNamedTitle(summary)
    }

    /// Una transferencia se borra con su otra mitad: se dice.
    static func message(for record: TransactionItem) -> String {
        guard record.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer else { return L10n.Common.cannotUndo }
        return "\(L10n.UXL8.deleteTransferAlsoPair) \(L10n.Common.cannotUndo)"
    }
}

/// La confirmación del borrado en lote (modo selección), en una alerta centrada como la de un registro (L8-7). Con un
/// solo registro elegido que se puede borrar, lo nombra; con varios, los cuenta. Va en los dos sitios con modo
/// selección: Registros y Estadísticas › Registros.
struct RecordsBulkDeleteAlert: ViewModifier {
    @Environment(AppPreferences.self) private var appPreferences
    @Binding var isPresented: Bool
    let viewModel: RecordsViewModel
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented) {
            // Solo con algo que borrar: si todo lo elegido viene de un grupo, el aviso explica dónde se borra.
            if viewModel.bulkDeleteDialog.offersDelete {
                Button(L10n.Action.cancel, role: .cancel) {}
                Button(L10n.Action.delete, role: .destructive) { onDelete() }
            } else {
                Button(L10n.Common.understood, role: .cancel) {}
            }
        } message: {
            Text(viewModel.bulkDeleteDialog.messageText)
        }
    }

    private var title: String {
        if case .deleteCount(1) = viewModel.bulkDeleteDialog.title,
           viewModel.selectedRecordIDs.count == 1,
           let id = viewModel.selectedRecordIDs.first,
           let record = viewModel.groupedRecords.lazy.flatMap(\.records).first(where: { $0.persistentModelID == id }) {
            return RecordDeleteConfirmationText.title(for: record, preferences: appPreferences)
        }
        return viewModel.bulkDeleteDialog.titleText
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
        OpenInNewWindowButton(route: .record(id: record.persistentModelID))
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
    @Environment(AppPreferences.self) private var appPreferences
    @Bindable var viewModel: RecordsViewModel

    func body(content: Content) -> some View {
        content
            // Una alerta centrada que nombra el registro (L8-7). Antes, un diálogo anclado arriba, lejos de la fila,
            // sin Cancelar a la vista y titulado «¿Eliminar 1 registro?».
            .alert(pendingDeleteTitle, isPresented: $viewModel.isConfirmingSingleDelete) {
                Button(L10n.Action.cancel, role: .cancel) {}
                Button(L10n.Action.delete, role: .destructive) {
                    viewModel.confirmPendingDelete(context: modelContext)
                }
            } message: {
                Text(pendingDeleteMessage)
            }
            .sheet(item: $viewModel.categoryChangeRecord) { record in
                // «Cambiar subcategoría» (L8-9): aplica al elegir y avisa con Deshacer.
                RecordSubcategoryChangeSheet(record: record, viewModel: viewModel)
            }
    }

    /// El registro que espera la confirmación, entre los que se ven (el menú y ⌫ solo actúan sobre filas visibles).
    private var pendingDeleteRecord: TransactionItem? {
        guard let id = viewModel.pendingDeleteRecordID else { return nil }
        return viewModel.groupedRecords.lazy.flatMap(\.records).first { $0.persistentModelID == id }
    }

    private var pendingDeleteTitle: String {
        guard let record = pendingDeleteRecord else { return L10n.Records.deleteConfirmTitle(1) }
        return RecordDeleteConfirmationText.title(for: record, preferences: appPreferences)
    }

    private var pendingDeleteMessage: String {
        pendingDeleteRecord.map { RecordDeleteConfirmationText.message(for: $0) } ?? L10n.Common.cannotUndo
    }
}
