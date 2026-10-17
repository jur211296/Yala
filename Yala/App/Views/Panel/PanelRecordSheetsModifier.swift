//
//  PanelRecordSheetsModifier.swift
//  Yala
//
//  El detalle de un registro tocado en «Últimos registros» y su editor (UX 2.2 · L3-12). Mismo reemplazo de hoja que
//  Registros: Editar marca la edición pendiente y cierra el detalle; al cerrarse, sube el editor. Va en su propio
//  modificador y no en `PanelSheetsModifier`, que ya está al límite de lo que el compilador del CI tipa.
//

import SwiftUI

struct PanelRecordSheetsModifier: ViewModifier {
    @Binding var sheets: PanelSheetState
    let viewModel: PanelViewModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $sheets.recordDetail, onDismiss: openEditorIfRequested) { presentation in
                TransactionDetailSheet(transaction: presentation.record) {
                    sheets.pendingEditRecord = presentation.record
                    sheets.recordDetail = nil
                }
            }
            .sheet(item: $sheets.recordToEdit, onDismiss: { viewModel.reloadAndRecalculate() }) { presentation in
                NewTransactionView(transactionToEdit: presentation.record)
                    .presentationDetents([.large])
            }
    }

    private func openEditorIfRequested() {
        guard let record = sheets.pendingEditRecord else {
            viewModel.reloadAndRecalculate()
            return
        }
        sheets.pendingEditRecord = nil
        sheets.recordToEdit = PanelRecordPresentation(record: record)
    }
}

/// Abrir un registro desde un widget del Panel. Va envuelto en un tipo y no como closure suelto: un closure en `@Entry`
/// no se puede comparar y SwiftUI invalidaría a quien lo lee en cada actualización (aviso del compilador).
struct OpenPanelRecordAction {
    let open: (TransactionItem) -> Void

    func callAsFunction(_ record: TransactionItem) {
        open(record)
    }
}

extension EnvironmentValues {
    /// Lo pone `PanelView`; fuera del Panel es `nil` y las filas no se tocan (la vista previa del «?» no abre nada).
    @Entry var openPanelRecord: OpenPanelRecordAction? = nil
}
