//
//  RecordPendingDeletion.swift
//  Yala
//
//  Borrar un registro con unos segundos para deshacerlo (UX 2.2 · L15-13, opción C, Jürgen 2026-10-18): ⌫ pedía
//  confirmación, pero no había deshacer en toda la app y quien confirmaba por inercia perdía el registro. El molde es el
//  de los pagos planificados (`ScheduledPaymentPendingDeletion`, L10-15): el borrado de verdad espera a que pase el aviso
//  «Eliminaste «Uber · S/ 26» · Deshacer», porque un borrado hecho no se puede devolver igual (identidad, sincronización,
//  la pareja de una transferencia) y uno aplazado sí. Mientras espera, el registro no sale en Registros.
//
//  Si la app se cierra en esos segundos, el registro NO se borra: es el lado que no pierde nada.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class RecordPendingDeletion {
    static let shared = RecordPendingDeletion()

    /// Los registros que esperan su borrado, y las parejas de las transferencias entre ellos: Registros los esconde
    /// (`RecordsViewModel.applyFilters`).
    private(set) var pendingIDs: Set<PersistentIdentifier> = []
    private(set) var pendingTransferPairIDs: Set<String> = []
    private var transferPairByID: [PersistentIdentifier: String] = [:]
    private var tasks: [PersistentIdentifier: Task<Void, Never>] = [:]

    /// Lo que dura el aviso con «Deshacer».
    static let undoWindow: Duration = DraftDiscardUndoNotice.visibleDuration
    /// El borrado de verdad espera un poco más que el aviso: un toque en «Deshacer» justo al final tiene que llegar antes
    /// que el borrado, nunca después (review adversarial del 2026-10-20).
    static let commitDelay: Duration = undoWindow + .milliseconds(400)

    /// ¿Lo esconde Registros mientras espera?
    func hides(_ id: PersistentIdentifier, transferPairID: String?) -> Bool {
        if pendingIDs.contains(id) { return true }
        guard let transferPairID else { return false }
        return pendingTransferPairIDs.contains(transferPairID)
    }

    /// Esconde el registro, avisa con «Deshacer» y lo borra (`commit`) al terminar el aviso.
    func request(
        id: PersistentIdentifier,
        transferPairID: String?,
        name: String,
        commit: @escaping @MainActor () -> Void
    ) {
        // Su pareja ya espera: este registro se borra con ella y vuelve con ella si se deshace. Un segundo borrado aquí
        // dejaría la pareja suelta al deshacer uno de los dos (review adversarial del 2026-10-20).
        if let transferPairID, pendingTransferPairIDs.contains(transferPairID) { return }
        pendingIDs.insert(id)
        if let transferPairID {
            pendingTransferPairIDs.insert(transferPairID)
            transferPairByID[id] = transferPairID
        }
        SessionState.shared.incrementDataVersion()
        tasks[id]?.cancel()
        tasks[id] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: Self.commitDelay)
            } catch {
                return
            }
            self?.finish(id, commit: commit)
        }
        DraftDiscardUndoNotice.show(
            message: L10n.UXL10.deleted(name),
            systemImage: "trash",
            undoTitle: L10n.Inbox.undoDiscard,
            noticeIdentifier: "record_deleted_notice",
            undoIdentifier: "record_deleted_undo",
            undoesDeletion: true
        ) { [weak self] in
            self?.undo(id)
        }
    }

    /// «Deshacer» (o ⌘Z): el registro vuelve a Registros y no se borra.
    func undo(_ id: PersistentIdentifier) {
        tasks[id]?.cancel()
        tasks[id] = nil
        release(id)
        SessionState.shared.incrementDataVersion()
    }

    private func finish(_ id: PersistentIdentifier, commit: @MainActor () -> Void) {
        tasks[id] = nil
        guard pendingIDs.contains(id) else { return }
        commit()
        release(id)
    }

    private func release(_ id: PersistentIdentifier) {
        pendingIDs.remove(id)
        if let pair = transferPairByID.removeValue(forKey: id) {
            pendingTransferPairIDs.remove(pair)
        }
    }
}
