//
//  GroupBatchLeaveOrchestrator.swift
//  Yala
//
//  Orquestador KILL-SAFE del batch "salir de todos mis grupos" (D10). Molde de `GroupJoinReconciler`:
//  `@MainActor enum`, gate de quiescencia, resume en boot/foreground. Corre HEADLESS (el progreso se publica
//  vía `GroupBatchLeaveTracker`; no depende del ciclo de vida de ninguna vista — decisión B1).
//
//  Contrato:
//    - `start(context:)` — desde la UI: (re)clasifica todos los grupos, arma el intent y procesa.
//    - `resume(trigger:context:)` — boot/foreground: procesa el intent persistido pendiente.
//    - `requestStop()` — desde la UI (botón «Detener», D3): cancelación COOPERATIVA entre grupos.
//  Ambos funnelan en `drive`. Idempotente por grupo. GATE DE QUIESCENCIA (invariante b): cada paso mutante
//  verifica `isImportQuiescent` ANTES de tocar el mainContext compartido; si el import no está quiescente,
//  BAIL del loop (deja las fases grabadas) → el resume lo retoma. WRITE-AHEAD: la fase `.inProgress` se graba
//  ANTES de la red que la avanza; en resume, las `.inProgress` re-ejecutan la acción congelada (idempotente).
//  Guard de RE-ENTRANCY: los triggers user-start/boot/foreground ceden el actor en cada `await` de red — sin
//  el guard, dos pasadas solaparían el mismo grupo.
//
//  Los saves los hace `GroupService` (executeBatchStep → batchLeave/softDelete/transferOwnershipThenLeave);
//  aquí NO hay `context.save()`. El gate de quiescencia PRE-llamada reduce masivamente la ventana; los saves
//  INTERNOS de las primitivas quedan con el MISMO residual acotado del tap único (CLAUDE.md), amplificado en
//  frecuencia, no en riesgo por-llamada.
//

import Foundation
import OSLog
import SwiftData

@MainActor
enum GroupBatchLeaveOrchestrator {

    enum Trigger: String {
        case userStart, boot, foreground
    }

    private static let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    /// Guard de re-entrancy: una sola pasada a la vez (los triggers pueden solaparse por los `await` de red).
    private static var isRunning = false

    /// Bandera de cancelación COOPERATIVA (D3). La lee el loop ENTRE grupos; jamás interrumpe una operación en
    /// vuelo. Se resetea al entrar a `drive` — la parada vive PERSISTIDA en el store, no en este Bool.
    private static var stopRequested = false

    // MARK: - Seams inyectables (tests)

    /// Gate de quiescencia. Default: quiescencia del import personal. Los tests lo fuerzan.
    static var quiescenceProvider: @MainActor () -> Bool = { iCloudSyncService.shared.isImportQuiescent }

    /// Ejecutor de un paso. Default: `GroupService`. Los tests inyectan un fake para probar la máquina de
    /// fases + el resume sin red/SwiftData.
    static var performOverride: (@MainActor (BatchLeaveEntry) async -> GroupBatchLeaveLogic.StepResult)?

    // MARK: - Entradas públicas

    /// Desde la UI (user-tap "También salir de mis grupos"): arma el intent fresco y procesa.
    static func start(context: ModelContext) async {
        guard !isRunning else { return }
        do {
            let plan = try GroupService.shared.batchClassifyAllGroups()
            GroupBatchLeaveStore.replaceAll(plan)
            MetricsService.canary(.groupBatchLeaveStarted, value: Double(plan.count))
        } catch {
            logger.error("BatchLeave: classify failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        GroupBatchLeaveTracker.shared.refresh()
        await drive(trigger: .userStart)
    }

    /// El usuario pulsó «Detener» (D3). Cancelación COOPERATIVA: el grupo EN CURSO termina (`transfer`/`leave`
    /// son server-first — o completan o no ocurren; cortar el `await` dejaría un ack perdido post-COMMIT), y el
    /// loop no toma ninguno más. WRITE-AHEAD: la parada se PERSISTE aquí (retira las `.pending` + marcador) para
    /// que `resume(.boot/.foreground)` no re-arme lo que el usuario detuvo.
    ///
    /// Las `.inProgress` SOBREVIVEN a propósito: su operación pudo haber salido server-side y el resume debe
    /// completarla (residual honesto y declarado — tras detener, un grupo más puede terminar de salir).
    /// Sin `context.save()`: solo `UserDefaults` ⇒ el gate de quiescencia queda intacto.
    static func requestStop() {
        stopRequested = true
        let skipped = GroupBatchLeaveStore.stopPending()
        MetricsService.canary(.groupBatchLeaveStopped, value: Double(skipped))
        logger.notice("BatchLeave: stopped by user — \(skipped, privacy: .public) group(s) not processed")
        GroupBatchLeaveTracker.shared.refresh()
    }

    /// Resume en boot/foreground: procesa el intent persistido si queda trabajo no-terminal.
    static func resume(trigger: Trigger, context: ModelContext? = nil) async {
        guard !isRunning else { return }
        guard GroupBatchLeaveStore.hasUnfinishedWork() else {
            GroupBatchLeaveTracker.shared.refresh()   // rehidrata el resultado si hay terminales
            return
        }
        await drive(trigger: trigger)
    }

    // MARK: - Loop

    private static func drive(trigger: Trigger) async {
        guard !isRunning else { return }
        isRunning = true
        // Una parada previa NO envenena esta pasada: lo que el usuario detuvo ya se retiró del store, y las
        // `.inProgress` supervivientes DEBEN completarse.
        stopRequested = false
        GroupBatchLeaveTracker.shared.setRunning(true)
        defer {
            isRunning = false
            GroupBatchLeaveTracker.shared.setRunning(false)
            GroupBatchLeaveTracker.shared.refresh()
        }

        let perform = performOverride ?? { entry in await GroupService.shared.executeBatchStep(entry) }

        for entry in GroupBatchLeaveStore.unfinished() {
            // PARADA DEL USUARIO (D3): punto de sutura ENTRE grupos. El grupo previo ya terminó (o no empezó);
            // ninguno nuevo se toma. `requestStop` ya retiró las `.pending` del store — este guard corta el
            // snapshot que el loop capturó al entrar.
            guard !stopRequested else { break }

            // GATE DE QUIESCENCIA por grupo (pre-llamada): si el import arrancó, BAIL — el resume retoma.
            guard quiescenceProvider() else {
                logger.notice("BatchLeave[\(trigger.rawValue, privacy: .public)]: deferred — import not quiescent")
                MetricsService.canary(.groupBatchLeaveDeferred, detail: "importNotQuiescent")
                return
            }

            // WRITE-AHEAD: la op mutante puede salir → grabar `.inProgress` ANTES de la red.
            GroupBatchLeaveStore.update(entry.groupZoneID) { $0.phase = .inProgress }

            let result = await perform(entry)
            applyResult(result, to: entry.groupZoneID)
            GroupBatchLeaveTracker.shared.refresh()
        }
    }

    private static func applyResult(_ result: GroupBatchLeaveLogic.StepResult, to groupZoneID: String) {
        switch result {
        case .done:
            GroupBatchLeaveStore.update(groupZoneID) { $0.phase = .done; $0.lastError = nil }
        case .needsDecision(let reason):
            GroupBatchLeaveStore.update(groupZoneID) {
                $0.phase = .needsDecision
                $0.needsDecisionReason = reason
            }
            MetricsService.canary(.groupBatchLeaveNeedsDecision, detail: reason.rawValue)
        case .deferred:
            // Deja la entry `.inProgress` (write-ahead) → el resume la retoma. Sin transición.
            break
        case .failed(let message):
            GroupBatchLeaveStore.update(groupZoneID) { $0.phase = .failed; $0.lastError = message }
            MetricsService.canary(.groupBatchLeaveFailed)
            #if DEBUG
            logger.error("BatchLeave: group step failed: \(message, privacy: .public)")
            #endif
        }
    }
}
