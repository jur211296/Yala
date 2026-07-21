//
//  GroupBatchLeaveOrchestratorTests.swift
//  YalaTests
//
//  Máquina de fases + resume kill-safe + gate de quiescencia del orquestador del batch "salir de todos mis
//  grupos" (D10). Inyecta `performOverride` (ejecutor fake — sin GroupService/SwiftData) y `quiescenceProvider`,
//  y aísla `GroupBatchLeaveStore.defaults`. `.serialized`: toca singletons (store defaults, tracker, seams del
//  orquestador).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("GroupBatchLeaveOrchestrator", .serialized)
struct GroupBatchLeaveOrchestratorTests {

    /// Log de invocaciones del ejecutor fake (referencia, capturable por el closure @MainActor).
    private final class CallLog { var ids: [String] = [] }

    /// Aísla el store + resetea el tracker + captura los seams; devuelve el cleanup.
    private func makeEnvironment() -> () -> Void {
        let d = makeIsolatedDefaults(prefix: "batchleave")
        GroupBatchLeaveStore.defaults = d
        GroupBatchLeaveTracker.shared.reset()
        return {
            GroupBatchLeaveStore.clearAll()
            GroupBatchLeaveStore.defaults = .standard
            GroupBatchLeaveOrchestrator.performOverride = nil
            GroupBatchLeaveOrchestrator.quiescenceProvider = { iCloudSyncService.shared.isImportQuiescent }
            GroupBatchLeaveTracker.shared.reset()
        }
    }

    private func entry(_ zone: String, _ action: GroupBatchLeaveLogic.Action,
                       phase: GroupBatchLeaveLogic.Phase = .pending) -> BatchLeaveEntry {
        BatchLeaveEntry(groupZoneID: zone, groupName: "Grp-\(zone)", phase: phase, plannedAction: action)
    }

    @Test("resume: entries pending → done; ejecutor llamado por grupo; tracker cuenta salidos")
    func resumePendingToDone() async {
        let cleanup = makeEnvironment(); defer { cleanup() }
        GroupBatchLeaveStore.replaceAll([entry("A", .leave), entry("B", .deleteSolo)])
        let log = CallLog()
        GroupBatchLeaveOrchestrator.quiescenceProvider = { true }
        GroupBatchLeaveOrchestrator.performOverride = { e in log.ids.append(e.groupZoneID); return .done }

        await GroupBatchLeaveOrchestrator.resume(trigger: .boot)

        #expect(Set(log.ids) == ["A", "B"])
        #expect(GroupBatchLeaveStore.entry(groupZoneID: "A")?.phase == .done)
        #expect(GroupBatchLeaveStore.entry(groupZoneID: "B")?.phase == .done)
        #expect(!GroupBatchLeaveStore.hasUnfinishedWork())
        #expect(GroupBatchLeaveTracker.shared.leftCount == 2)
    }

    @Test("resume: needsDecision persiste fase + motivo; no cuenta como salido")
    func resumeNeedsDecision() async {
        let cleanup = makeEnvironment(); defer { cleanup() }
        GroupBatchLeaveStore.replaceAll([entry("A", .transferThenLeave)])
        GroupBatchLeaveOrchestrator.quiescenceProvider = { true }
        GroupBatchLeaveOrchestrator.performOverride = { _ in .needsDecision(.backendNoEligibleHeir) }

        await GroupBatchLeaveOrchestrator.resume(trigger: .userStart)

        let e = GroupBatchLeaveStore.entry(groupZoneID: "A")
        #expect(e?.phase == .needsDecision)
        #expect(e?.needsDecisionReason == .backendNoEligibleHeir)
        #expect(GroupBatchLeaveTracker.shared.needsDecision.count == 1)
        #expect(GroupBatchLeaveTracker.shared.leftCount == 0)
    }

    @Test("kill-sim: una entry .inProgress (kill tras write-ahead) se RE-EJECUTA en resume")
    func killSimInProgressReExecuted() async {
        let cleanup = makeEnvironment(); defer { cleanup() }
        // Simula un kill: la entry quedó en .inProgress (write-ahead) sin completar.
        GroupBatchLeaveStore.replaceAll([entry("A", .transferThenLeave, phase: .inProgress)])
        let log = CallLog()
        GroupBatchLeaveOrchestrator.quiescenceProvider = { true }
        GroupBatchLeaveOrchestrator.performOverride = { e in log.ids.append(e.groupZoneID); return .done }

        await GroupBatchLeaveOrchestrator.resume(trigger: .boot)

        #expect(log.ids == ["A"])   // re-ejecutada (idempotente)
        #expect(GroupBatchLeaveStore.entry(groupZoneID: "A")?.phase == .done)
    }

    @Test("gate de quiescencia: import no-quiescente → NO ejecuta ni muta; al recuperar quiescencia procesa")
    func quiescenceGate() async {
        let cleanup = makeEnvironment(); defer { cleanup() }
        GroupBatchLeaveStore.replaceAll([entry("A", .leave), entry("B", .leave)])
        let log = CallLog()
        GroupBatchLeaveOrchestrator.performOverride = { e in log.ids.append(e.groupZoneID); return .done }

        // No quiescente → bail sin tocar nada (fases intactas en .pending).
        GroupBatchLeaveOrchestrator.quiescenceProvider = { false }
        await GroupBatchLeaveOrchestrator.resume(trigger: .foreground)
        #expect(log.ids.isEmpty)
        #expect(GroupBatchLeaveStore.entry(groupZoneID: "A")?.phase == .pending)
        #expect(GroupBatchLeaveStore.hasUnfinishedWork())

        // Recupera quiescencia → procesa.
        GroupBatchLeaveOrchestrator.quiescenceProvider = { true }
        await GroupBatchLeaveOrchestrator.resume(trigger: .foreground)
        #expect(Set(log.ids) == ["A", "B"])
        #expect(!GroupBatchLeaveStore.hasUnfinishedWork())
    }

    @Test("deferred (transitorio): deja la entry .inProgress para el próximo resume; luego .done")
    func deferredStaysInProgress() async {
        let cleanup = makeEnvironment(); defer { cleanup() }
        GroupBatchLeaveStore.replaceAll([entry("A", .leave)])
        GroupBatchLeaveOrchestrator.quiescenceProvider = { true }
        GroupBatchLeaveOrchestrator.performOverride = { _ in .deferred }

        await GroupBatchLeaveOrchestrator.resume(trigger: .boot)
        #expect(GroupBatchLeaveStore.entry(groupZoneID: "A")?.phase == .inProgress)  // write-ahead, no avanza
        #expect(GroupBatchLeaveStore.hasUnfinishedWork())

        GroupBatchLeaveOrchestrator.performOverride = { _ in .done }
        await GroupBatchLeaveOrchestrator.resume(trigger: .boot)
        #expect(GroupBatchLeaveStore.entry(groupZoneID: "A")?.phase == .done)
    }

    // MARK: - Parada del usuario (D3)

    @Test("stop: corta ENTRE grupos — el grupo en curso termina, los siguientes no se tocan")
    func stopBreaksBetweenGroups() async {
        let cleanup = makeEnvironment(); defer { cleanup() }
        GroupBatchLeaveStore.replaceAll([
            entry("A", .leave), entry("B", .leave), entry("C", .leave),
        ])
        let log = CallLog()
        GroupBatchLeaveOrchestrator.quiescenceProvider = { true }
        // El usuario pulsa «Detener» DURANTE la operación del primer grupo (dentro del `await perform`).
        GroupBatchLeaveOrchestrator.performOverride = { e in
            log.ids.append(e.groupZoneID)
            if log.ids.count == 1 { GroupBatchLeaveOrchestrator.requestStop() }
            return .done
        }

        await GroupBatchLeaveOrchestrator.resume(trigger: .userStart)

        // El grupo en curso COMPLETÓ (jamás se corta a medias) y ninguno más se ejecutó.
        #expect(log.ids.count == 1)
        let processed = log.ids[0]
        #expect(GroupBatchLeaveStore.entry(groupZoneID: processed)?.phase == .done)
        // Los otros dos se retiraron del store (no quedan como trabajo pendiente).
        #expect(GroupBatchLeaveStore.all().count == 1)
        #expect(GroupBatchLeaveStore.wasStopped)
        #expect(GroupBatchLeaveStore.skippedCount == 2)
        // Resultado honesto: 1 salido, 2 sin procesar, total del batch preservado.
        #expect(GroupBatchLeaveTracker.shared.leftCount == 1)
        #expect(GroupBatchLeaveTracker.shared.skippedCount == 2)
        #expect(GroupBatchLeaveTracker.shared.total == 3)
        #expect(GroupBatchLeaveTracker.shared.wasStopped)
    }

    @Test("stop: lo detenido NO resume en boot/foreground")
    func stoppedDoesNotResume() async {
        let cleanup = makeEnvironment(); defer { cleanup() }
        GroupBatchLeaveStore.replaceAll([entry("A", .leave), entry("B", .leave)])
        GroupBatchLeaveOrchestrator.quiescenceProvider = { true }

        // Parada con el batch ocioso (nada en curso): ambas entries `.pending` se retiran.
        GroupBatchLeaveOrchestrator.requestStop()
        #expect(!GroupBatchLeaveStore.hasUnfinishedWork())

        let log = CallLog()
        GroupBatchLeaveOrchestrator.performOverride = { e in log.ids.append(e.groupZoneID); return .done }
        await GroupBatchLeaveOrchestrator.resume(trigger: .boot)
        await GroupBatchLeaveOrchestrator.resume(trigger: .foreground)

        #expect(log.ids.isEmpty)   // el resume NO re-arma lo que el usuario detuvo
        #expect(GroupBatchLeaveStore.skippedCount == 2)
    }

    @Test("stop: una `.inProgress` SOBREVIVE a la parada y el resume la completa (write-ahead)")
    func stopPreservesInProgress() async {
        let cleanup = makeEnvironment(); defer { cleanup() }
        // A quedó `.inProgress` (su RPC pudo haber salido server-side); B está `.pending`.
        GroupBatchLeaveStore.replaceAll([entry("A", .leave, phase: .inProgress), entry("B", .leave)])

        GroupBatchLeaveOrchestrator.requestStop()

        #expect(GroupBatchLeaveStore.entry(groupZoneID: "A")?.phase == .inProgress)  // conservada
        #expect(GroupBatchLeaveStore.entry(groupZoneID: "B") == nil)                 // retirada
        #expect(GroupBatchLeaveStore.skippedCount == 1)
        // La vista muestra el RESULTADO pese a quedar trabajo vivo: sin la rama `wasStopped` de `isComplete`,
        // el spinner quedaría clavado justo después de pulsar «Detener».
        #expect(GroupBatchLeaveStore.hasUnfinishedWork())
        #expect(GroupBatchLeaveTracker.shared.wasStopped)
        #expect(GroupBatchLeaveTracker.shared.isComplete)

        // El resume SÍ completa la operación ambigua (invariante kill-safe).
        let log = CallLog()
        GroupBatchLeaveOrchestrator.quiescenceProvider = { true }
        GroupBatchLeaveOrchestrator.performOverride = { e in log.ids.append(e.groupZoneID); return .done }
        await GroupBatchLeaveOrchestrator.resume(trigger: .boot)

        #expect(log.ids == ["A"])
        #expect(GroupBatchLeaveStore.entry(groupZoneID: "A")?.phase == .done)
    }

    @Test("stop: relanzar desde la UI limpia los marcadores (batch nuevo, cifras frescas)")
    func restartClearsStopMarkers() async {
        let cleanup = makeEnvironment(); defer { cleanup() }
        GroupBatchLeaveStore.replaceAll([entry("A", .leave), entry("B", .leave)])
        GroupBatchLeaveOrchestrator.requestStop()
        #expect(GroupBatchLeaveStore.wasStopped)

        // Relanzar (molde de `start`: `replaceAll` con el plan fresco).
        GroupBatchLeaveStore.replaceAll([entry("A", .leave), entry("B", .leave)])
        #expect(!GroupBatchLeaveStore.wasStopped)
        #expect(GroupBatchLeaveStore.skippedCount == 0)

        let log = CallLog()
        GroupBatchLeaveOrchestrator.quiescenceProvider = { true }
        GroupBatchLeaveOrchestrator.performOverride = { e in log.ids.append(e.groupZoneID); return .done }
        await GroupBatchLeaveOrchestrator.resume(trigger: .userStart)

        #expect(Set(log.ids) == ["A", "B"])   // la parada previa no envenena la corrida nueva
    }

    @Test("acknowledge: retira lo terminal y CONSERVA las no-terminales en vuelo")
    func acknowledgeKeepsInProgress() async {
        let cleanup = makeEnvironment(); defer { cleanup() }
        GroupBatchLeaveStore.replaceAll([entry("A", .leave, phase: .done), entry("B", .leave, phase: .inProgress)])

        GroupBatchLeaveTracker.shared.acknowledge()

        #expect(GroupBatchLeaveStore.entry(groupZoneID: "A") == nil)                 // terminal → fuera
        #expect(GroupBatchLeaveStore.entry(groupZoneID: "B")?.phase == .inProgress)  // en vuelo → conservada
        #expect(!GroupBatchLeaveStore.wasStopped)
    }
}
