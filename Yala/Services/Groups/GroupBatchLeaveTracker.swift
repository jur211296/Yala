//
//  GroupBatchLeaveTracker.swift
//  Yala
//
//  Fachada @Observable del batch "salir de todos mis grupos" (D10) para la vista dedicada del flujo. Molde de
//  `GroupJoinIntentTracker`: solo PUBLICA el estado; la fuente de verdad es `GroupBatchLeaveStore`. El
//  orquestador llama `refresh()` tras cada grupo y setea `isRunning`; la vista lee los agregados (N salidos,
//  M transferidos, K pendientes de tu decisión). Corre HEADLESS: si el usuario abandona la vista o cierra
//  Ajustes, el batch sigue y el resultado se refleja en el tab Grupos; la pantalla de resultado NO está
//  garantizada (residual declarado — decisión B1 "paso separado").
//

import Foundation

@MainActor
@Observable
final class GroupBatchLeaveTracker {

    static let shared = GroupBatchLeaveTracker()

    /// Un grupo que cayó a "necesitan tu decisión" (para la lista con acceso directo + copy honesto).
    struct NeedsDecisionItem: Identifiable, Equatable {
        var id: String { groupZoneID }
        let groupZoneID: String
        let groupName: String
        let reason: GroupBatchLeaveLogic.NeedsDecisionReason
    }

    /// `true` mientras el orquestador procesa (guard de re-entrancy vive en el orquestador; esto es solo UI).
    private(set) var isRunning = false
    private(set) var total = 0
    private(set) var processedCount = 0
    /// Salidas limpias: `leave` + `deleteSolo` completados.
    private(set) var leftCount = 0
    /// Transferencias completadas (`transferThenLeave`).
    private(set) var transferredCount = 0
    private(set) var failedCount = 0
    private(set) var needsDecision: [NeedsDecisionItem] = []
    /// El usuario pulsó «Detener» (D3): cambia la headline del resultado y habilita mostrarlo con trabajo vivo.
    private(set) var wasStopped = false
    /// Grupos que quedaron sin procesar por la parada ("M sin procesar" del resultado honesto).
    private(set) var skippedCount = 0

    private init() {}

    /// `true` cuando la vista debe mostrar el resultado: no queda trabajo no-terminal, **o** el usuario detuvo.
    ///
    /// La rama `wasStopped` es necesaria porque una parada puede dejar entries `.inProgress` vivas (deferred por
    /// red) que el resume completará en background: sin ella la vista quedaría clavada en el spinner justo
    /// después de pulsar «Detener».
    var isComplete: Bool {
        !isRunning && total > 0 && (!GroupBatchLeaveStore.hasUnfinishedWork() || wasStopped)
    }

    func setRunning(_ running: Bool) {
        isRunning = running
    }

    /// Recalcula los agregados desde el store (single source of truth).
    func refresh() {
        let entries = GroupBatchLeaveStore.all()
        wasStopped = GroupBatchLeaveStore.wasStopped
        skippedCount = GroupBatchLeaveStore.skippedCount
        // Con parada, las entries retiradas ya no están en el store: el total del batch es lo que queda + lo
        // que se retiró (si no, "3 / 3" mentiría sobre un batch de 11 grupos).
        total = entries.count + skippedCount
        var left = 0, transferred = 0, failed = 0
        var pending: [NeedsDecisionItem] = []
        for e in entries {
            switch e.phase {
            case .done:
                if e.plannedAction == .transferThenLeave { transferred += 1 } else { left += 1 }
            case .failed:
                failed += 1
            case .needsDecision:
                pending.append(NeedsDecisionItem(
                    groupZoneID: e.groupZoneID,
                    groupName: e.groupName,
                    reason: e.needsDecisionReason ?? .operationFailed
                ))
            case .pending, .inProgress:
                break
            }
        }
        leftCount = left
        transferredCount = transferred
        failedCount = failed
        needsDecision = pending
        processedCount = left + transferred + failed + pending.count
    }

    /// El usuario cerró el resultado: limpia lo terminal (los grupos `needsDecision` siguen visibles en el tab
    /// Grupos — la verdad no depende de este store). Reset del estado observable.
    ///
    /// `clearFinished()` (no `clearAll()`) CONSERVA las entries no-terminales: tras una parada pueden quedar
    /// `.inProgress` en vuelo cuyo RPC salió server-side y el resume debe completar. Sin parada es equivalente
    /// (`isComplete` exigía que no quedara trabajo).
    func acknowledge() {
        GroupBatchLeaveStore.clearFinished()
        reset()
    }

    func reset() {
        isRunning = false
        total = 0
        processedCount = 0
        leftCount = 0
        transferredCount = 0
        failedCount = 0
        needsDecision = []
        wasStopped = false
        skippedCount = 0
    }
}
