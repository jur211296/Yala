//
//  ScheduledPaymentPendingDeletion.swift
//  Yala
//
//  Borrar un pago planificado con unos segundos para deshacerlo (UX 2.2 · L10-15 B, Jürgen 2026-10-15). El borrado de
//  verdad espera a que pase el aviso «Eliminaste «Matrícula» · Deshacer»: un borrado hecho no se puede devolver igual
//  (identidad, sincronización), y uno aplazado sí. Mientras espera, el pago no sale en la lista.
//
//  Si la app se cierra en esos segundos, el pago NO se borra: es el lado que no pierde nada.
//

import Foundation
import Observation

@MainActor
@Observable
final class ScheduledPaymentPendingDeletion {
    static let shared = ScheduledPaymentPendingDeletion()

    /// Los pagos que esperan su borrado. La lista los esconde (`ScheduledPaymentsViewModel.loadPayments`).
    private(set) var pendingIDs: Set<UUID> = []
    private var tasks: [UUID: Task<Void, Never>] = [:]

    /// Lo que dura el aviso con «Deshacer».
    static let undoWindow: Duration = DraftDiscardUndoNotice.visibleDuration

    /// Esconde el pago, avisa con «Deshacer» y lo borra (`commit`) al terminar el aviso.
    func request(paymentID: UUID, name: String, commit: @escaping @MainActor () -> Void) {
        pendingIDs.insert(paymentID)
        SessionState.shared.incrementDataVersion()
        tasks[paymentID]?.cancel()
        tasks[paymentID] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.undoWindow)
            } catch {
                return
            }
            self?.finish(paymentID, commit: commit)
        }
        DraftDiscardUndoNotice.show(
            message: L10n.UXL10.deleted(name),
            systemImage: "trash",
            undoTitle: L10n.Inbox.undoDiscard,
            noticeIdentifier: "scheduled_deleted_notice",
            undoIdentifier: "scheduled_deleted_undo"
        ) { [weak self] in
            self?.undo(paymentID)
        }
    }

    /// «Deshacer»: el pago vuelve a la lista y no se borra.
    func undo(_ paymentID: UUID) {
        tasks[paymentID]?.cancel()
        tasks[paymentID] = nil
        pendingIDs.remove(paymentID)
        SessionState.shared.incrementDataVersion()
    }

    private func finish(_ paymentID: UUID, commit: @MainActor () -> Void) {
        tasks[paymentID] = nil
        guard pendingIDs.contains(paymentID) else { return }
        commit()
        pendingIDs.remove(paymentID)
    }
}
