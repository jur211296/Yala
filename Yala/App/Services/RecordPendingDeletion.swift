//
//  RecordPendingDeletion.swift
//  Yala
//
//  Borrar un registro con unos segundos para deshacerlo (UX 2.2 · L15-13, opción C, Jürgen 2026-10-18): ⌫ pedía
//  confirmación, pero no había deshacer en toda la app y quien confirmaba por inercia perdía el registro. El molde es el
//  de los pagos planificados (`ScheduledPaymentPendingDeletion`, L10-15): el borrado de verdad espera a que pase el aviso
//  «Eliminaste «Uber · S/ 26» · Deshacer», porque un borrado hecho no se puede devolver igual (identidad, sincronización,
//  la pareja de una transferencia) y uno aplazado sí. Mientras espera, el registro no sale en ninguna pantalla.
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

    /// Los registros que esperan su borrado, y las parejas de las transferencias entre ellos: no se ven en ninguna
    /// pantalla (`hides`, `visible(_:)`).
    private(set) var pendingIDs: Set<PersistentIdentifier> = []
    private(set) var pendingTransferPairIDs: Set<String> = []
    private var transferPairByID: [PersistentIdentifier: String] = [:]
    private var commits: [PersistentIdentifier: @MainActor () -> Void] = [:]
    /// Un solo plazo para todo lo que espera. Dos borrados seguidos comparten aviso («Eliminaste 2 registros ·
    /// Deshacer») y plazo: el segundo alarga el del primero en vez de quitarle su «Deshacer» (ticket
    /// `record-pending-deletion-still-counts-outside-records`). Hasta el 2026-10-25 el aviso del segundo retiraba el del
    /// primero, que se quedaba sin botón ni ⌘Z antes de tiempo.
    private var batchTask: Task<Void, Never>?
    /// Cuándo empezó el lote que espera. Alargar el plazo con cada borrado no puede ser para siempre: pasado
    /// `maxBatchSpan`, lo que ya esperaba se borra antes de empezar otro lote (review adversarial del lote 12.5: borrando
    /// uno cada pocos segundos, nada llegaba a borrarse y un «Deshacer» devolvía decenas).
    private var batchStartedAt: ContinuousClock.Instant?
    /// Lo que rehace la foto de los widgets al deshacer. La foto pudo escribirse mientras el registro esperaba (sin él), y
    /// «Deshacer» solo sube `dataVersion`, que la foto no escucha.
    private var refreshAfterUndo: (@MainActor () -> Void)?

    /// Lo que dura el aviso con «Deshacer».
    static let undoWindow: Duration = DraftDiscardUndoNotice.visibleDuration
    /// El borrado de verdad espera un poco más que el aviso: un toque en «Deshacer» justo al final tiene que llegar antes
    /// que el borrado, nunca después (review adversarial del 2026-10-20).
    static let commitDelay: Duration = undoWindow + .milliseconds(400)
    /// Lo más que un lote puede alargarse con borrados nuevos antes de borrar lo que ya esperaba.
    static let maxBatchSpan: Duration = .seconds(30)
    /// El plazo que usa esta instancia. Solo los tests lo acortan, para ver el borrado sin esperar cinco segundos.
    var commitDelayForBatch: Duration = RecordPendingDeletion.commitDelay

    /// ¿Se esconde mientras espera?
    func hides(_ id: PersistentIdentifier, transferPairID: String?) -> Bool {
        if pendingIDs.contains(id) { return true }
        guard let transferPairID else { return false }
        return pendingTransferPairIDs.contains(transferPairID)
    }

    /// Los registros sin lo que espera su borrado. El Panel, Estadísticas, Buscar y los widgets cargan por aquí: durante
    /// esos segundos el registro no cuenta en ninguna cifra ni se puede editar desde otra pantalla (la edición se
    /// perdería con el borrado). Sin nada pendiente devuelve el mismo array, sin recorrerlo.
    func visible(_ transactions: [TransactionItem]) -> [TransactionItem] {
        guard !pendingIDs.isEmpty else { return transactions }
        return transactions.filter { !hides($0.persistentModelID, transferPairID: $0.transferPairID) }
    }

    /// Esconde el registro, avisa con «Deshacer» y lo borra (`commit`) al terminar el aviso.
    func request(
        id: PersistentIdentifier,
        transferPairID: String?,
        name: String,
        refreshAfterUndo: (@MainActor () -> Void)? = nil,
        commit: @escaping @MainActor () -> Void
    ) {
        // Su pareja ya espera: este registro se borra con ella y vuelve con ella si se deshace. Un segundo borrado aquí
        // dejaría la pareja suelta al deshacer uno de los dos (review adversarial del 2026-10-20).
        if let transferPairID, pendingTransferPairIDs.contains(transferPairID) { return }
        // Un lote que lleva demasiado esperando se borra ya: el registro nuevo empieza otro.
        if let started = batchStartedAt, ContinuousClock.now - started >= Self.maxBatchSpan {
            batchTask?.cancel()
            finishAll()
        }
        if pendingIDs.isEmpty { batchStartedAt = ContinuousClock.now }
        if let refreshAfterUndo { self.refreshAfterUndo = refreshAfterUndo }
        pendingIDs.insert(id)
        commits[id] = commit
        if let transferPairID {
            pendingTransferPairIDs.insert(transferPairID)
            transferPairByID[id] = transferPairID
        }
        SessionState.shared.incrementDataVersion()
        batchTask?.cancel()
        let delay = commitDelayForBatch
        batchTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            self?.finishAll()
        }
        let count = pendingIDs.count
        DraftDiscardUndoNotice.show(
            message: count == 1 ? L10n.UXL10.deleted(name) : L10n.UXL10.deletedRecords(count),
            systemImage: "trash",
            undoTitle: L10n.Inbox.undoDiscard,
            noticeIdentifier: "record_deleted_notice",
            undoIdentifier: "record_deleted_undo",
            undoesDeletion: true
        ) { [weak self] in
            self?.undoAll()
            // Deshacer el borrado no falla: lo que esperaba vuelve (card C3; mapa de `DS.Haptic`).
            DS.Haptic.success()
        }
    }

    /// «Deshacer» (o ⌘Z) del aviso: todo lo que esperaba vuelve y no se borra.
    func undoAll() {
        batchTask?.cancel()
        batchTask = nil
        batchStartedAt = nil
        for id in pendingIDs { release(id) }
        SessionState.shared.incrementDataVersion()
        let refresh = refreshAfterUndo
        refreshAfterUndo = nil
        refresh?()
    }

    /// Devuelve un registro y deja esperando a los demás.
    func undo(_ id: PersistentIdentifier) {
        guard pendingIDs.contains(id) else { return }
        release(id)
        if pendingIDs.isEmpty {
            batchTask?.cancel()
            batchTask = nil
            batchStartedAt = nil
        }
        SessionState.shared.incrementDataVersion()
    }

    private func finishAll() {
        batchTask = nil
        batchStartedAt = nil
        refreshAfterUndo = nil
        let due = commits
        guard !due.isEmpty else { return }
        for (id, commit) in due where pendingIDs.contains(id) {
            commit()
            release(id)
        }
        // Las pantallas recargan aunque un borrado no llegara a hacerse (la fila ya no está, un fallo al guardar): sin
        // esto, un registro que sigue en la base quedaba fuera de todas hasta la siguiente mutación.
        SessionState.shared.incrementDataVersion()
    }

    private func release(_ id: PersistentIdentifier) {
        pendingIDs.remove(id)
        commits[id] = nil
        if let pair = transferPairByID.removeValue(forKey: id) {
            pendingTransferPairIDs.remove(pair)
        }
    }
}
