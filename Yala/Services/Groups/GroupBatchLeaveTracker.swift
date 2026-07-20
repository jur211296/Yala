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

    private init() {}

    /// `true` cuando ya no queda trabajo no-terminal (la vista muestra el resultado).
    var isComplete: Bool {
        !isRunning && total > 0 && !GroupBatchLeaveStore.hasUnfinishedWork()
    }

    func setRunning(_ running: Bool) {
        isRunning = running
    }

    /// Recalcula los agregados desde el store (single source of truth).
    func refresh() {
        let entries = GroupBatchLeaveStore.all()
        total = entries.count
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

    /// El usuario cerró el resultado: limpia el intent (los grupos `needsDecision` siguen visibles en el tab
    /// Grupos — la verdad no depende de este store). Reset del estado observable.
    func acknowledge() {
        GroupBatchLeaveStore.clearAll()
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
    }
}
