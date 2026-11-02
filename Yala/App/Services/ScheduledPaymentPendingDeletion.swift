//
//  ScheduledPaymentPendingDeletion.swift
//  Yala
//
//  Borrar un pago planificado con unos segundos para deshacerlo (UX 2.2 · L10-15 B, Jürgen 2026-10-15). El borrado de
//  verdad espera a que pase el aviso «Eliminaste «Matrícula» · Deshacer»: un borrado hecho no se puede devolver igual
//  (identidad, sincronización), y uno aplazado sí. Mientras espera, el pago no sale en ninguna pantalla.
//
//  Desde el 2026-10-29 sigue el molde que el borrado de registros estrenó el 2026-10-25 (`RecordPendingDeletion`, ticket
//  `scheduled-payment-pending-deletion-loses-undo-on-a-second-delete`): dos borrados seguidos comparten aviso y plazo, lo
//  pendiente no cuenta fuera de Planificación y el borrado espera un poco más que el aviso.
//
//  Si la app se cierra en esos segundos, el pago NO se borra: es el lado que no pierde nada.
//

import Foundation
import Observation

@MainActor
@Observable
final class ScheduledPaymentPendingDeletion {
    static let shared = ScheduledPaymentPendingDeletion()

    /// Los pagos que esperan su borrado: no se ven en ninguna pantalla (`hides`, `visible(_:)`).
    private(set) var pendingIDs: Set<UUID> = []
    private var commits: [UUID: @MainActor () -> Void] = [:]
    /// Un solo plazo para todo lo que espera. Dos borrados seguidos comparten aviso («Eliminaste 2 pagos · Deshacer») y
    /// plazo: el segundo alarga el del primero en vez de quitarle su «Deshacer». Hasta el 2026-10-29 cada pago tenía su
    /// plazo y el aviso del segundo retiraba el del primero, que se borraba sin botón.
    private var batchTask: Task<Void, Never>?
    /// Cuándo empezó el lote que espera. Alargar el plazo con cada borrado no puede ser para siempre: pasado
    /// `maxBatchSpan`, lo que ya esperaba se borra antes de empezar otro lote.
    private var batchStartedAt: ContinuousClock.Instant?
    /// Lo que rehace la foto de los widgets al deshacer. La foto pudo escribirse mientras el pago esperaba (sin él), y
    /// «Deshacer» solo sube `dataVersion`, que la foto no escucha.
    private var refreshAfterUndo: (@MainActor () -> Void)?

    /// Lo que dura el aviso con «Deshacer».
    static let undoWindow: Duration = DraftDiscardUndoNotice.visibleDuration
    /// El borrado de verdad espera un poco más que el aviso: un toque en «Deshacer» justo al final tiene que llegar antes
    /// que el borrado, nunca después (el mismo margen que los registros).
    static let commitDelay: Duration = undoWindow + .milliseconds(400)
    /// Lo más que un lote puede alargarse con borrados nuevos antes de borrar lo que ya esperaba. Nunca por debajo de dos
    /// avisos: con el aviso alargado de un XCUITest (`-uitest-undo-notice-seconds 30`), un tope de 30 s cortaba el lote
    /// antes del segundo borrado. Con el aviso de siempre (5 s) son 30 s.
    static let maxBatchSpan: Duration = max(.seconds(30), undoWindow * 2)
    /// El plazo que usa esta instancia. Solo los tests lo acortan, para ver el borrado sin esperar cinco segundos.
    var commitDelayForBatch: Duration = ScheduledPaymentPendingDeletion.commitDelay

    /// ¿Se esconde mientras espera?
    func hides(_ paymentID: UUID) -> Bool {
        pendingIDs.contains(paymentID)
    }

    /// Los pagos sin lo que espera su borrado. Planificación, el Panel, Estadísticas, el Informe, el flujo de caja y los
    /// widgets cargan por aquí: durante esos segundos el pago no cuenta en ninguna cifra ni se puede abrir desde otra
    /// pantalla. Sin nada pendiente devuelve el mismo array, sin recorrerlo.
    func visible(_ payments: [ScheduledPayment]) -> [ScheduledPayment] {
        guard !pendingIDs.isEmpty else { return payments }
        return payments.filter { !pendingIDs.contains($0.id) }
    }

    /// Esconde el pago, avisa con «Deshacer» y lo borra (`commit`) al terminar el aviso.
    func request(
        paymentID: UUID,
        name: String,
        refreshAfterUndo: (@MainActor () -> Void)? = nil,
        commit: @escaping @MainActor () -> Void
    ) {
        // Un lote que lleva demasiado esperando se borra ya: el pago nuevo empieza otro.
        if let started = batchStartedAt, ContinuousClock.now - started >= Self.maxBatchSpan {
            batchTask?.cancel()
            finishAll()
        }
        if pendingIDs.isEmpty { batchStartedAt = ContinuousClock.now }
        if let refreshAfterUndo { self.refreshAfterUndo = refreshAfterUndo }
        pendingIDs.insert(paymentID)
        commits[paymentID] = commit
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
            message: count == 1 ? L10n.UXL10.deleted(name) : L10n.UXL10.deletedPayments(count),
            systemImage: "trash",
            undoTitle: L10n.Inbox.undoDiscard,
            noticeIdentifier: "scheduled_deleted_notice",
            undoIdentifier: "scheduled_deleted_undo",
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

    /// Devuelve un pago y deja esperando a los demás.
    func undo(_ paymentID: UUID) {
        guard pendingIDs.contains(paymentID) else { return }
        release(paymentID)
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
        // Las pantallas recargan aunque un borrado no llegara a hacerse (el pago ya no está, un fallo al guardar): sin
        // esto, un pago que sigue en la base quedaba fuera de todas hasta la siguiente mutación.
        SessionState.shared.incrementDataVersion()
    }

    private func release(_ paymentID: UUID) {
        pendingIDs.remove(paymentID)
        commits[paymentID] = nil
    }
}
