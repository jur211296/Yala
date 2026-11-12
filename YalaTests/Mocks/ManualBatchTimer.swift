//
//  ManualBatchTimer.swift
//  YalaTests
//
//  El plazo de un borrado con «Deshacer» (`RecordPendingDeletion`, `ScheduledPaymentPendingDeletion`) sin reloj: el test
//  decide cuándo vence. Con `Task.sleep` de verdad, bajo la carga de la suite entera el hilo principal no despachaba el
//  borrado a tiempo (300 ms de espera para un plazo de 60 ms) y el caso salía rojo a veces (card vrs1, 2026-11-03).
//
//  Cada espera viva es un plazo pendiente. Cancelar la tarea del lote (lo que hace un borrado nuevo) cancela su espera.
//

import Foundation

@MainActor
final class ManualBatchTimer {
    private var waiters: [Int: CheckedContinuation<Void, Error>] = [:]
    private var nextID = 0
    /// Los plazos con los que se pidió cada espera, en orden.
    private(set) var requestedDelays: [Duration] = []

    /// Plazos que esperan a vencer ahora mismo.
    var pendingCount: Int { waiters.count }

    func sleep(_ delay: Duration) async throws {
        let id = nextID
        nextID += 1
        requestedDelays.append(delay)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters[id] = continuation
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    /// Vencen todos los plazos vivos.
    func fireAll() {
        let due = waiters
        waiters = [:]
        for continuation in due.values { continuation.resume() }
    }

    private func cancel(_ id: Int) {
        waiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
    }

    /// Espera a que se cumpla `condition` cediendo el hilo principal, con un tope amplio: lo que se mide es el ORDEN, no
    /// cuánto tarda. Devuelve si se cumplió.
    func settle(timeout: Duration = .seconds(10), until condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            if ContinuousClock.now >= deadline { return false }
            do {
                try await Task.sleep(for: .milliseconds(5))
            } catch {
                return condition()
            }
        }
        return true
    }
}
