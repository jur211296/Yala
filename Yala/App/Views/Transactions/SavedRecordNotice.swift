//
//  SavedRecordNotice.swift
//  Yala
//
//  El aviso breve tras guardar un registro (UX 2.2 · L2-5, decidido por Jürgen el 14-oct y cerrado el 21-oct): el
//  formulario se cierra y, sobre la pantalla de origen, sale «Gasto guardado · S/ 12.00» con «Editar» y «Deshacer»
//  durante 5 s. Es el mismo aviso de la Bandeja (`DraftDiscardUndoNotice`): vive en su propia ventana, así que se ve
//  aunque el formulario ya no exista.
//

import SwiftData
import SwiftUI

// MARK: - Quién abre el editor

/// «Editar» del aviso abre el registro en la pantalla que abrió el formulario. Cada pantalla que presenta el formulario
/// pone el suyo (`.environment(\.savedRecordEditorOpener, …)`) con SU estado de presentación: así la edición pasa por la
/// misma hoja que ya usa para editar un registro (y por su matriz de presentaciones), y nunca hay dos anclas
/// presentando lo mismo. Va envuelto en un tipo por lo mismo que `OpenPanelRecordAction`: un closure suelto en `@Entry`
/// no se puede comparar.
struct SavedRecordEditorOpener {
    let open: @MainActor (TransactionItem) -> Void
}

extension EnvironmentValues {
    /// `nil` donde nadie lo pone: el aviso sale sin «Editar».
    @Entry var savedRecordEditorOpener: SavedRecordEditorOpener? = nil
}

// MARK: - El aviso

@MainActor
enum SavedRecordNotice {

    /// «Gasto guardado · S/ 12.00», «Ingreso guardado · …» o «Transferencia guardada · …».
    static func message(for type: TransactionType, formattedAmount: String) -> String {
        switch type {
        case .expense: return L10n.UXL2.savedExpense(formattedAmount)
        case .income: return L10n.UXL2.savedIncome(formattedAmount)
        case .transfer: return L10n.UXL2.savedTransfer(formattedAmount)
        }
    }

    /// «Guardado · se repetirá cada mes» (L2-15).
    static func recurringMessage(for recurrence: RecurrenceType) -> String {
        switch recurrence {
        case .weekly: return L10n.UXL2.savedRepeatsWeekly
        case .yearly: return L10n.UXL2.savedRepeatsYearly
        case .monthly, .daily: return L10n.UXL2.savedRepeatsMonthly
        }
    }

    /// El aviso de un registro nuevo. `recordIDs` son las filas que guardó (las dos patas de una transferencia);
    /// `scheduledPaymentID`, el pago planificado que creó «Hacer recurrente», que «Deshacer» también se lleva.
    static func showSaved(
        message: String,
        recordIDs: [PersistentIdentifier],
        scheduledPaymentID: UUID? = nil,
        context: ModelContext,
        opener: SavedRecordEditorOpener?
    ) {
        var editAction: (@MainActor () -> Void)?
        if let opener {
            editAction = {
                // Con algo presentado (el formulario aún cerrándose, otra hoja) el ancla no está libre: presentar ahí
                // se descarta o espera turno, y una hoja que no monta deja retenido al router (`swiftui-ds.md`).
                guard !ModalPresentationProbe.isAnythingPresented,
                      let record = SavedRecordUndo.liveRecord(recordIDs.first, in: context) else { return }
                opener.open(record)
            }
        }
        DraftDiscardUndoNotice.show(
            message: message,
            systemImage: "checkmark.circle",
            undoTitle: L10n.Inbox.undoDiscard,
            noticeIdentifier: noticeIdentifier,
            undoIdentifier: "saved_record_undo",
            secondaryTitle: L10n.Action.edit,
            secondaryIdentifier: "saved_record_edit",
            onSecondary: editAction
        ) {
            SavedRecordUndo.undo(recordIDs: recordIDs, scheduledPaymentID: scheduledPaymentID, context: context)
        }
        retireWhenSomethingElseOpens()
    }

    /// «Cambios guardados», sin botones: guardar una edición nunca enseña la pantalla completa.
    static func showEdited() {
        showInfo(message: L10n.UXL2.savedChanges)
    }

    /// El aviso sin botones.
    static func showInfo(message: String) {
        DraftDiscardUndoNotice.show(
            message: message,
            systemImage: "checkmark.circle",
            noticeIdentifier: noticeIdentifier,
            onUndo: nil
        )
        retireWhenSomethingElseOpens()
    }

    static let noticeIdentifier = "saved_record_notice"
    private static var watchTask: Task<Void, Never>?

    /// El aviso vive en su propia ventana, por encima de cualquier hoja (review adversarial del 2026-10-22): abierto el
    /// detalle del registro recién guardado, «Deshacer» lo borraba con la hoja pintándolo; abierto otro formulario, la
    /// franja del aviso caía sobre sus chips y su «Guardar». Así que en cuanto se presenta algo nuevo, el aviso se va.
    /// «Nuevo» es después de que el formulario que lo dejó termine de cerrarse: mientras se cierra, también cuenta como
    /// presentado.
    private static func retireWhenSomethingElseOpens() {
        watchTask?.cancel()
        watchTask = Task { @MainActor in
            var sawNothingPresented = false
            let deadline = ContinuousClock.now + DraftDiscardUndoNotice.visibleDuration
            while ContinuousClock.now < deadline {
                do {
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    return
                }
                guard DraftDiscardUndoNotice.currentNoticeIdentifier == noticeIdentifier else { return }
                if !ModalPresentationProbe.isAnythingPresented {
                    sawNothingPresented = true
                } else if sawNothingPresented {
                    DraftDiscardUndoNotice.hide()
                    return
                }
            }
        }
    }
}

// MARK: - Deshacer

/// «Deshacer» borra el registro como un borrado normal: con él la pareja de una transferencia, y saldos y presupuestos
/// vuelven solos porque se calculan de los registros. Si venía de «Hacer recurrente», se va también el pago planificado.
@MainActor
enum SavedRecordUndo {

    /// La fila viva, por un fetch y no por `model(for:)`, que fabrica un objeto aunque el registro ya no exista.
    static func liveRecord(_ id: PersistentIdentifier?, in context: ModelContext) -> TransactionItem? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("SavedRecordUndo: Error: fetch del registro guardado: \(error)")
            #endif
            return nil
        }
    }

    static func undo(recordIDs: [PersistentIdentifier], scheduledPaymentID: UUID?, context: ModelContext) {
        // Los registros primero: el borrado del pago planificado se lleva sus registros del mes, y un registro de otro
        // mes solo lo desenlazaría.
        for id in recordIDs {
            guard let record = liveRecord(id, in: context) else { continue }
            if record.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer,
               let partner = TransferPartnerLookup.partner(of: record, in: context),
               !recordIDs.contains(partner.persistentModelID) {
                context.delete(partner)
            }
            context.delete(record)
        }
        do {
            try context.save()
            context.processPendingChanges()
        } catch {
            #if DEBUG
            print("SavedRecordUndo: Error: borrar lo guardado: \(error)")
            #endif
            return
        }

        if let scheduledPaymentID {
            deleteScheduledPayment(scheduledPaymentID, context: context)
        }

        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    private static func deleteScheduledPayment(_ id: UUID, context: ModelContext) {
        var descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        do {
            guard let payment = try context.fetch(descriptor).first else { return }
            EntityDeletionService.shared.setContext(context)
            try EntityDeletionService.shared.deleteScheduledPayment(payment)
        } catch {
            #if DEBUG
            print("SavedRecordUndo: Error: borrar el pago planificado: \(error)")
            #endif
        }
    }
}
