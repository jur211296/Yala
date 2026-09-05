//
//  MigrationRunner.swift
//  Yala
//
//  Orquestador JOURNAL-THEN-EXECUTE de la migración iCloud→nube (I10-wiring, ciclo A / w2). Consume la
//  máquina PURA `MigrationStateMachine` (que no ejecuta nada) y el journal DURABLE `MigrationState`
//  (single-row, store sync-meta), y realiza el trabajo real vía el seam `MigrationWorkExecuting` (los
//  ejecutores reales llegan en w3-w6; en este ciclo solo el fake de tests).
//
//  Invariantes que encarna (§g + notas del review adversarial de I10-pre):
//   - Journal-then-execute (molde SpikeS6): una transición se journalea en UN `save()` (fase + efectos
//     PENDIENTES + contadores) ANTES de ejecutar cada efecto; cada efecto completado se remueve del
//     pending con su propio `save()`. Un efecto que lanza queda journaled → stop retomable (N1).
//   - Gate de QUIESCENCIA (§b.3 + saga de Grupos): `awaitQuiescence()` corre UNA VEZ a la entrada de
//     cada acción pública, ANTES del PRIMER `save()` del journal — el store sync-meta comparte el
//     `mainContext` en prod y un `save()` flushearía el grafo personal a medio importar.
//   - Contadores S9 INDEPENDIENTES (mismatch/red) inyectados desde el journal al construir el
//     `verifyOutcome`, incrementados en el MISMO `save()` que journalea la transición.
//   - `leaderDeviceID` journaled ANTES del POST del claim → `sameDeviceReclaim` en un re-claim tras kill.
//   - Follower (M3): el re-poll del claim se TRADUCE a `leaderCompleted`/`leaderVanished`; jamás se
//     alimenta un `claimResult` crudo en `waitingForLeader`.
//   - Contrato especial `.disableMirrorAndRelaunch` (cruza el process boundary): en `resume()` se
//     resuelve por OBSERVACIÓN (`isMirrorConfirmedOff`), no por re-ejecución ciega → sin relaunch-loop.
//   - `ClaimOutcome` no-success (sessionExpired/accountUnavailable/transient) → stop SIN evento, JAMÁS
//     `fatalError` (un 401 recuperable no debe producir un rollback espurio). Lo que SÍ se registra es
//     la CAUSA, en `lastClaimBlocker` y fuera del journal: sin ella los tres se veían iguales desde la
//     pantalla del adopt, que dejaba «Conectando con tu cuenta…» puesta también ante un 403.
//
//  DARK: NADA de producción instancia este runner ni lee el journal (la UI de migración llega en I14;
//  el panel DEBUG en w7). Solo lo ejercitan los tests de este ciclo.
//

import Foundation
import SwiftData

// MARK: - Seam de trabajo por fase

/// Resultado del sondeo de verificación (§g.3 + S9). El runner mapea esto a `VerifyOutcome` inyectando
/// los contadores desde el journal (el enum de la máquina lleva `retriesSoFar`; este NO).
enum VerifyProbe: Equatable {
    case match
    case mismatch
    case networkTimeout
    case newDeltaDetected
}

/// Por qué se aparcó un claim cuando la causa **no es la red**. Es el hecho que separa «no te llega la
/// conexión» de «tu cuenta no está disponible», dos cosas que hasta ahora se veían como la misma barra
/// «Conectando con tu cuenta…» con su botón de reintentar (ticket `reentry-counts-as-fresh-install` §3).
///
/// No es un `MigrationEvent`: el docblock del runner prohíbe alimentar `fatalError` desde un no-success
/// del claim —haría un rollback espurio— y aquí no hay nada que revertir, porque sin claim otorgado no
/// se creó nada. Es el mismo molde que `cutoverBlocker`: un hecho que solo elige el copy honesto.
nonisolated enum ClaimBlocker: Equatable {
    /// 403 — la cuenta no está disponible (suspendida). Reintentar no la despierta.
    case accountUnavailable
    /// 401 — la sesión ya no vale. Hay que volver a entrar, no reintentar.
    case sessionExpired
}

/// Resultado de un paso del uploader del snapshot (w4). `pageConfirmed` avanza el cursor sin cambiar de
/// fase (re-loop); `completed` cierra la subida; `transient` corta retomable.
enum SnapshotStepOutcome: Equatable {
    case completed
    case pageConfirmed(cursor: String)
    case transient
}

// MARK: - Outcomes de la reversa (§h, I11-2). `nonisolated` Equatable: los compara la lógica de tests.

/// Resultado del `reverse_claim` (§h). `accepted` = reserva otorgada; `otherLeader` = otro device ya es
/// reverse-líder (desatascador); el resto = stop retomable. I11-3 cabla el server real; hoy `.transient`.
nonisolated enum ReverseClaimOutcome: Equatable {
    case accepted
    case otherLeader
    case sessionExpired
    case transient
    case rejected(reason: String)
}

/// Resultado de un paso genérico de la reversa (drain final / freeze). `completed` avanza; `transient` corta.
nonisolated enum ReverseStepOutcome: Equatable {
    case completed
    case transient
}

/// Resultado del barrido de zombies (§h.3 `deletingZombies`). `completed(deleted:)` = filas vivas
/// tombstoneadas borradas (0 = no-op idempotente, caso normal); `transient` = red del pull → retomable.
nonisolated enum ZombieSweepOutcome: Equatable {
    case completed(deleted: Int)
    case transient
}

/// Estado del drenaje del store al mirror en `reverseUpload` (§h). `drained` = todo exportó (o hizo
/// round-trip); `pending(count:)` = `count` filas aún sin metadata/export → retomable.
nonisolated enum ReverseUploadStatus: Equatable {
    case drained
    case pending(count: Int)
}

/// Seam del trabajo REAL por fase (los ejecutores reales llegan en w3-w6; aquí solo el fake de tests).
/// `@MainActor`: manipula red/identidad/ModelContext en prod.
@MainActor
protocol MigrationWorkExecuting: AnyObject {
    /// `POST /account/claim` (§f.1) — reusa `ClaimOutcome` de `CloudAccountClient`.
    func performClaim() async -> ClaimOutcome
    /// w3: backfill de `syncID` (gate permanente) + captura `(ckRecordName, ckZoneName)` con el mirror vivo.
    func assignIdentity() async throws
    /// w4: sube el snapshot completo en batches idempotentes. `cursor` = última página confirmada (journal).
    func uploadSnapshot(cursor: String?) async -> SnapshotStepOutcome
    /// w5: cuenta + checksum Merkle local vs backend, confirmado server-side.
    func verify() async -> VerifyProbe
    /// w6 paso 1: escribe `profiles.migrated_at` y espera el ack síncrono del backend.
    func confirmCutoverServer() async -> Bool
    /// w6 paso 2: persiste `storageMode=.cloud` atómicamente.
    func persistLocalMode() async -> Bool
    /// Ejecuta un efecto DECLARATIVO (beacon KV, marker CK, mirror-off+relaunch, reconcile, rollback, adopt).
    func execute(_ effect: MigrationEffect) async throws
    /// Observación post-relaunch: ¿el mirror personal está confirmado OFF? (resuelve `.disableMirrorAndRelaunch`).
    func isMirrorConfirmedOff() -> Bool
    /// Gate de EXPORT del marcador (§g.4, entre paso 3 y 4): ¿el `CloudMigrationMarker` LLEGÓ a CloudKit?
    /// El save del marcador exporta ASYNC; apagar el mirror antes lo perdería. `false` = aún sin exportar.
    func isMarkerExported() -> Bool

    // MARK: Reversa (§h, I11-2). El server-side (claim/freeze) queda notWired hasta I11-3.

    /// `reverse_claim` (§h). I11-3 cabla el RPC real; hoy `.transient` + breadcrumb notWired.
    func performReverseClaim() async -> ReverseClaimOutcome
    /// `reverseDrainAll` (§h): pull final + drain del outbox propio + push del residual (reusa piezas de `verify()`).
    func reverseDrainOnce() async -> ReverseStepOutcome
    /// `reverseFreezeBackend` (§h): marca la cuenta backend "reverting". I11-3; hoy `false` + breadcrumb notWired.
    func freezeBackendForReverse() async -> Bool
    /// Observación post-relaunch: ¿el mirror `.private` está confirmado ON? (resuelve `.mountMirrorAndRelaunch`,
    /// análogo a `isMirrorConfirmedOff`). CONTRATO I11-2: debe ser fake-able en tests (el testigo real reporta
    /// `.icloud` por default → "montado SIEMPRE" = falso verde).
    func isMirrorConfirmedOn() -> Bool
    /// §h.3 `deletingZombies`: barrido tombstones-del-backend vs filas VIVAS locales (borra las resucitadas).
    /// `sinceSeq` = corte del pull en enumeración PURA (sin applyPage, sin avanzar cursor/testigos).
    func sweepZombies(sinceSeq: Int64) async -> ZombieSweepOutcome
    /// §h.3 `rebindingUUIDs`: verificación (v1) de `SyncIdentity.lastReboundAt` con fila viva presente.
    /// Devuelve el conteo verificado (sin deletes — el replay del mirror exporta el update de campo, S5).
    func verifyRebinds() -> Int
    /// §h.3 `dedupHealed`: AUTO-CURA (I11-4) de copias idénticas de Account/Tag. Devuelve el nº de filas
    /// perdedoras fusionadas+borradas (idempotente: 2ª pasada → 0).
    func healDuplicates() -> Int
    /// §h `reverseUpload`: muestreo CKIdentityCapture sobre las filas vivas → `.drained` / `.pending(count)`.
    func reverseUploadStatus() -> ReverseUploadStatus

    // MARK: Heartbeat del lease (I14-pre, residual pendiente #3)

    /// Refresca `profiles.migration_updated_at` (heartbeat del lease de 60 min) MIENTRAS un paso largo
    /// progresa. BEST-EFFORT: el runner lo llama POR PROGRESO (el dueño del pacing); el executor aplica el
    /// THROTTLE (a lo sumo una vez por ventana) y NUNCA lanza ni altera el outcome del paso. Default no-op
    /// en la extension de abajo → los fakes/ejecutores que no laten heredan sin cambios.
    func sendLeaseHeartbeatIfDue() async

    // MARK: Canal iCloud (C-1)

    /// Veredicto del canal por el que el marcador del cutover tiene que viajar. Read-only y SIN red (cuenta
    /// iCloud + huella CloudKit local + último `CKError` observado). El runner lo consulta en la ENTRADA del
    /// cutover (para no empezar lo que no puede cerrar) y en el paso 4 (para clasificar el atasco y elegir el
    /// presupuesto del tope). Default `.healthy` en la extension de abajo → los fakes que no guionan el canal
    /// se comportan EXACTAMENTE como antes de C-1.
    func probeICloudChannel() async -> ICloudChannelVerdict
}

extension MigrationWorkExecuting {
    /// Default NO-OP del heartbeat (I14-pre): un conformador que no necesita latir (fakes del runner que no
    /// lo asertan, ejecutores futuros verify-only) no está obligado a implementarlo. El ejecutor real lo
    /// override con el tick throttled best-effort.
    func sendLeaseHeartbeatIfDue() async {}

    /// Default C-1: canal SANO. Mismo molde que el heartbeat — un conformador que no modela el canal iCloud
    /// (los fakes de las suites existentes) mantiene el camino feliz byte-idéntico: `.healthy` no bloquea la
    /// entrada y clasifica el atasco como `.unknown` (presupuesto largo).
    func probeICloudChannel() async -> ICloudChannelVerdict { .healthy }
}

// MARK: - Runner

@MainActor
final class MigrationRunner {

    /// Señal interna de parada RETOMABLE (efecto que lanza) — se desenreda hasta la acción pública, que
    /// la traga en silencio (el journal quedó consistente; el próximo `resume()` retoma).
    private enum Stop: Error { case effectFailed }

    private let context: ModelContext
    private let executor: MigrationWorkExecuting
    private let policy: MigrationPolicy
    private let deviceID: String
    private let quiescenceSignal: () -> Bool
    private let now: () -> Date
    private let sleeper: (Double) async -> Void
    private let quiescenceTimeoutSeconds: Double
    private let quiescenceTickSeconds: Double

    /// Guarda contra un bucle de trabajo sin progreso (bug de secuenciación) — alto, nunca alcanzado en
    /// flujos correctos.
    private static let maxDriveIterations = 100_000

    /// Fila del journal cacheada por instancia (se re-lee del store en una instancia nueva = tras kill).
    private var cachedState: MigrationState?

    /// Guard de reentrada (S1 del review adversarial): las entradas públicas son async con `await`s
    /// largos (red, quiescencia) — una doble invocación (double-tap del panel w7) intercalaría en cada
    /// suspensión (doble POST de claim, doble backfill). A lo sumo UNA en vuelo; las demás no-op.
    private var isRunning = false

    /// Por qué se aparcó el ÚLTIMO claim, cuando la causa no fue la red (`nil` = ninguna, o red).
    ///
    /// En memoria a propósito, y no journaleado: describe el INTENTO —no el estado durable de la
    /// migración, que sigue siendo `claimingMigration` retomable— y cada claim nuevo lo repone o lo
    /// limpia. Lo lee `CloudMigrationController.refresh()` para que la pantalla de adopt deje de
    /// enseñar «Conectando con tu cuenta…» ante un fallo que esperar no arregla.
    private(set) var lastClaimBlocker: ClaimBlocker?

    init(
        context: ModelContext,
        executor: MigrationWorkExecuting,
        deviceID: String,
        policy: MigrationPolicy = .default,
        quiescenceSignal: @escaping () -> Bool,
        now: @escaping () -> Date = { .now },
        sleeper: @escaping (Double) async -> Void = { seconds in
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                #if DEBUG
                print("MigrationRunner: quiescence sleep cancelado: \(error)")
                #endif
            }
        },
        quiescenceTimeoutSeconds: Double = 120,
        quiescenceTickSeconds: Double = 0.5
    ) {
        self.context = context
        self.executor = executor
        self.deviceID = deviceID
        self.policy = policy
        self.quiescenceSignal = quiescenceSignal
        self.now = now
        self.sleeper = sleeper
        self.quiescenceTimeoutSeconds = quiescenceTimeoutSeconds
        self.quiescenceTickSeconds = quiescenceTickSeconds
    }

    // MARK: - Entradas públicas (todas gateadas por quiescencia ANTES del primer save)

    /// Arranca la migración desde la UI (`userActivated`). `dryRun == true` → simular; `false` → proceder.
    func startMigration(dryRun: Bool) async {
        await submit(.userActivated(dryRun: dryRun))
    }

    /// Entrega un evento EXTERNO (UI/auth: consent/sign-in) y luego retoma el trabajo autónomo.
    func submit(_ event: MigrationEvent) async {
        guard await awaitQuiescence() else {
            CloudSyncBreadcrumb.migrationQuiescenceTimeout()
            return
        }
        await runGuarded {
            // M1 (review adversarial): un journal corrupto que entre por una acción de USUARIO también
            // debe sonar + resetear (misma normalización que resume()) — no solo el camino de boot.
            if try self.normalizeCorruptJournalIfNeeded() { return }
            try self.markStartedIfNeeded()
            try await self.handle(event)
            try await self.drive()
        }
    }

    /// Re-arranque tras un kill: normaliza la fase journaleada (§g.2), ejecuta los efectos pendientes
    /// residuales (N1, con el contrato especial del relaunch) y continúa el trabajo.
    func resume() async {
        guard await awaitQuiescence() else {
            CloudSyncBreadcrumb.migrationQuiescenceTimeout()
            return
        }
        await runGuarded {
            try await self.resumeInternal()
        }
    }

    /// Reinicio EXPLÍCITO tras un rollback (S2): la máquina no tiene arista de salida de esos estados
    /// terminales a propósito (el reinicio es una decisión del USUARIO, no una transición automática). No-op
    /// fuera de `failedRollback`/`reverseFailedRollback`. I14 lo invoca desde el botón "reintentar".
    ///  - `failedRollback` (forward) → reset COMPLETO a `notStarted` (fase, efectos, campos scoped, startedAt).
    ///  - `reverseFailedRollback` (I11-2) → repone la fase ORIGEN journaleada (`reverseOriginRaw`, fallback
    ///    `.done`), NO `notStarted` ciego — un líder que revirtió desde `done` que resetee a `notStarted`
    ///    mentiría para siempre a `markerReconciliation` (marker vivo + sin traza → falso
    ///    `secondaryDeviceCloudLogin`). Limpia lo scoped + `reverseOriginRaw`.
    func resetAfterRollback() async {
        guard await awaitQuiescence() else {
            CloudSyncBreadcrumb.migrationQuiescenceTimeout()
            return
        }
        await runGuarded {
            let state = try self.loadState()
            let phase = state.readPhase().phase
            let target: MigrationPhase
            switch phase {
            case .failedRollback:
                // Forward: reinicio COMPLETO a notStarted (la máquina no tiene arista de salida a propósito).
                target = .notStarted
            case .reverseFailedRollback:
                // Reversa (I11-2): reponer la fase ORIGEN journaleada, NO `notStarted` ciego — un líder que
                // revirtió desde `done` que resetee a `notStarted` mentiría para siempre a
                // `markerReconciliation` (marker vivo + sin traza → falso secondaryDeviceCloudLogin). Fallback
                // `.done`: veraz para el único caso real (líder migrado); benigno para ambos (con el mirror
                // off el marker no es visible ⇒ markerReconciliation no dispara).
                let origin = state.reverseOriginRaw.flatMap(ReverseOrigin.init(rawValue:)) ?? .done
                target = (origin == .notStarted) ? .notStarted : .done
            default:
                return                                     // no-op fuera de los dos estados de rollback
            }
            // C-1: DRENAR antes de limpiar. El abort del paso 4 deja pendiente `.persistICloudMode` (la que
            // devuelve el device a `.icloud` + desarma el mirror-off). Si el usuario toca "Reintentar" antes
            // de que ese pendiente drene, el `setPendingEffects([])` de abajo lo TIRARÍA y quedaría
            // `notStarted` + `.cloud` = fase ESTABLE con el mirror vivo ⇒ exactamente la doble escritura que
            // este arreglo mata. Si el drenaje lanza, `runGuarded` aborta el reset y el journal queda intacto:
            // el tap se convierte en un reintento del abort, que es la semántica correcta.
            try await self.drainPendingEffects(isResume: true)
            state.setPhase(target)
            state.setPendingEffects([])
            state.leaderDeviceID = nil
            state.verifyMismatchRetries = 0
            state.verifyNetworkRetries = 0
            state.snapshotCursorJSON = nil
            state.reverseOriginRaw = nil
            state.markerWrittenSince = nil
            state.cutoverICloudVerdictRaw = nil
            if target == .notStarted { state.startedAt = nil }
            state.updatedAt = self.now()
            try self.context.save()
            CloudSyncBreadcrumb.migrationJournaled(phase: "\(target) (reset tras rollback)")
        }
    }

    /// Follower (M3): un poll externo estando en `waitingForLeader`. Re-claima y TRADUCE el resultado a
    /// `leaderCompleted`/`leaderVanished` — nunca alimenta un `claimResult` crudo en esa fase.
    func pollLeader() async {
        guard await awaitQuiescence() else {
            CloudSyncBreadcrumb.migrationQuiescenceTimeout()
            return
        }
        await runGuarded {
            try await self.pollLeaderInternal()
        }
    }

    // MARK: - Núcleo

    private func runGuarded(_ body: () async throws -> Void) async {
        // S1: reentrada → no-op (a lo sumo una acción pública en vuelo).
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        do {
            try await body()
        } catch Stop.effectFailed {
            // Efecto journaled + stop; el próximo resume() retoma. Sin ruido adicional (ya hubo breadcrumb).
        } catch {
            #if DEBUG
            print("MigrationRunner: error no recuperable en el ciclo: \(error)")
            #endif
        }
    }

    /// Un paso Mealy: `transition` → `.invalid` ⇒ breadcrumb + no-op (journal intacto); `.transition`
    /// ⇒ UN `save()` que journalea fase + efectos pendientes (+ mutación de contadores del caller) → luego
    /// drena los efectos ejecutándolos y removiéndolos del pending.
    private func handle(
        _ event: MigrationEvent,
        mutate: (MigrationState, MigrationPhase) -> Void = { _, _ in }
    ) async throws {
        let state = try loadState()
        let current = state.readPhase().phase
        switch MigrationStateMachine.transition(from: current, event: event, policy: policy) {
        case let .invalid(from, ev):
            CloudSyncBreadcrumb.migrationInvalidTransition(from: "\(from)", event: "\(ev)")
        case let .transition(next, effects):
            state.setPhase(next)
            state.setPendingEffects(effects)
            // I11-2: al CRUZAR reverseConfirm(origin) → reverseClaimLeader, journalar el ORIGIN (la máquina
            // no lo propaga) + resetear los contadores S9 (pueden traer gasto del verify forward — el
            // S2-cleanup solo resetea en notStarted/failedRollback). En el MISMO save de la transición (N1).
            if case let .reverseConfirm(origin) = current, next == .reverseClaimLeader {
                state.reverseOriginRaw = origin.rawValue
                state.verifyMismatchRetries = 0
                state.verifyNetworkRetries = 0
                state.snapshotCursorJSON = nil
                // C-1: los campos del cutover de la IDA no tienen sentido en la reversa (el reloj del paso 4
                // y el veredicto del canal iCloud son de un intento ya cerrado).
                state.markerWrittenSince = nil
                state.cutoverICloudVerdictRaw = nil
            }
            // S2 (review adversarial): al llegar a un estado de CIERRE de intento, limpiar los campos
            // SCOPED a la migración en el MISMO save — un `leaderDeviceID`/contador/cursor stale que
            // sobreviva a un intento anterior envenenaría al siguiente (p.ej. contadores S9 ya gastados
            // → rollback prematuro). `startedAt` se conserva en `failedRollback` (diagnóstico del intento
            // fallido) y se limpia en `notStarted` (adopt/decline — sin migración en curso). `icloudActive`
            // (terminal de la reversa) se une al bloque (I11-2): la reversa terminó → limpia lo scoped +
            // `reverseOriginRaw`. `reverseFailedRollback` NO entra: conserva `reverseOriginRaw` para que
            // `resetAfterRollback` reponga la fase origen (no `notStarted` ciego).
            if next == .notStarted || next == .failedRollback || next == .icloudActive {
                state.leaderDeviceID = nil
                state.verifyMismatchRetries = 0
                state.verifyNetworkRetries = 0
                state.snapshotCursorJSON = nil
                state.reverseOriginRaw = nil
                // C-1: el reloj del paso 4 es SCOPED al intento — un `markerWrittenSince` stale haría que el
                // siguiente cutover naciera con el presupuesto ya vencido (abort inmediato).
                state.markerWrittenSince = nil
                // El VEREDICTO en cambio SOBREVIVE a `failedRollback` a propósito: es lo que le permite al
                // `failedCard` decir la verdad ("iCloud se quedó sin espacio" vs. "no hay iCloud activo") en
                // vez del genérico. Se limpia en los cierres donde ya no hay nada que explicar.
                if next != .failedRollback { state.cutoverICloudVerdictRaw = nil }
                if next == .notStarted { state.startedAt = nil }
            }
            mutate(state, next)
            state.updatedAt = now()
            try context.save()
            CloudSyncBreadcrumb.migrationJournaled(phase: "\(next)")
            try await drainPendingEffects(isResume: false)
        }
    }

    /// Drena los efectos journaleados PENDIENTES en orden, con save por efecto completado. En `resume`,
    /// un `.disableMirrorAndRelaunch` pendiente se resuelve por OBSERVACIÓN (no re-ejecución ciega).
    private func drainPendingEffects(isResume: Bool) async throws {
        let state = try loadState()
        while let effect = state.readPendingEffects().first {
            if effect == .disableMirrorAndRelaunch, isResume, executor.isMirrorConfirmedOff() {
                // El relaunch YA surtió efecto → consumir el pendiente + avanzar por el evento sintético.
                removeFirstPending(state)
                try context.save()
                try await handle(.mirrorRelaunchCompleted)
                return
            }
            if effect == .mountMirrorAndRelaunch, isResume, executor.isMirrorConfirmedOn() {
                // Simétrico al mirror-off (§h): el relaunch remontó el mirror `.private` → consumir el
                // pendiente + avanzar por observación (nunca re-ejecución ciega del efecto que cruza el
                // process boundary).
                removeFirstPending(state)
                try context.save()
                try await handle(.reverseMirrorMounted)
                return
            }
            do {
                try await executor.execute(effect)
            } catch {
                CloudSyncBreadcrumb.migrationEffectFailed(effect: effect.rawValue, reason: "\(error)")
                throw Stop.effectFailed
            }
            removeFirstPending(state)
            try context.save()
        }
    }

    private func removeFirstPending(_ state: MigrationState) {
        var pending = state.readPendingEffects()
        if !pending.isEmpty { pending.removeFirst() }
        state.setPendingEffects(pending)
        state.updatedAt = now()
    }

    /// Bucle de trabajo autónomo: según la fase actual invoca al executor y produce el evento; corta en
    /// estados terminales, `waitingForLeader` (espera poll externo) o outcomes transient/no-success.
    private func drive() async throws {
        var iterations = 0
        while true {
            iterations += 1
            if iterations > Self.maxDriveIterations {
                #if DEBUG
                print("MigrationRunner: drive() excedió el tope de iteraciones — corto por seguridad")
                #endif
                return
            }
            let phase = try loadState().readPhase().phase
            switch phase {
            case .notStarted, .dryRun, .consent, .authenticating, .done, .failedRollback:
                return                       // terminal / requiere evento externo (UI/auth, I14)
            case .waitingForLeader:
                return                       // espera `pollLeader()` externo
            case .claimingMigration:
                if !(try await driveClaim()) { return }
            case .assigningIdentity:
                do {
                    try await executor.assignIdentity()
                } catch {
                    #if DEBUG
                    print("MigrationRunner: assignIdentity falló (retomable): \(error)")
                    #endif
                    return
                }
                try await handle(.identityAssigned)
            case .uploadingSnapshot:
                if !(try await driveUpload()) { return }
            case .verifying:
                if !(try await driveVerify()) { return }
            case let .cutover(sub):
                if !(try await driveCutover(sub)) { return }
            case .reverseConfirm, .icloudActive, .reverseFailedRollback:
                // reverseConfirm espera el evento de UI (reverseConfirmed/reverseDeclined, I14);
                // icloudActive/reverseFailedRollback son terminales estables. DARK: nada de producción
                // emite `reverseActivated`, así que estas fases no se alcanzan hoy en runtime.
                return
            case .reverseClaimLeader:
                if !(try await driveReverseClaim()) { return }
            case .reverseDrainAll:
                switch await executor.reverseDrainOnce() {
                case .completed:
                    try await handle(.reverseDrainCompleted)
                    // Heartbeat (I14-pre): el drain de una época nube grande puede tardar minutos — late al
                    // cerrar el paso para no dejar la lease de 60 min usurpable a mitad de la reversa.
                    await executor.sendLeaseHeartbeatIfDue()
                case .transient: return
                }
            case .reverseVerify:
                if !(try await driveReverseVerify()) { return }
            case .reverseFreezeBackend:
                // `reverse_freeze` server-side (I11-3): false = rechazo/red → stop retomable SIN evento.
                guard await executor.freezeBackendForReverse() else { return }
                try await handle(.reverseBackendFrozen)        // efecto: mountMirrorAndRelaunch
            case .reverseMountMirror:
                // Resuelto SIEMPRE por observación (forward tras ejecutar el efecto, o resume post-relaunch):
                // el efecto `mountMirrorAndRelaunch` desarma el flag; el mirror monta al RELANZAR.
                guard executor.isMirrorConfirmedOn() else { return }
                try await handle(.reverseMirrorMounted)        // → reverseReconcile(.awaitingQuiescence)
            case let .reverseReconcile(sub):
                if !(try await driveReverseReconcile(sub)) { return }
            case .reverseUpload:
                if !(try await driveReverseUpload()) { return }
            }
        }
    }

    /// `claimingMigration`. Journalea `leaderDeviceID = deviceID` ANTES del POST (diagnóstico/panel).
    ///
    /// `sameDeviceReclaim` es SIEMPRE `false` (B1 del review adversarial): el backend COLAPSA el
    /// re-claim del MISMO `device_id` líder a `created` (golden 4 de `account.goldens.test.ts`,
    /// verificado contra staging real) → un `claiming_in_progress` recibido significa SIEMPRE "otro
    /// device lidera". Derivarlo del `leaderDeviceID` local (intent pre-POST, no lease otorgado)
    /// promovería a un device PERDEDOR como 2º líder: A journalea intent → su POST falla transient
    /// ANTES de crear la fila → B reclama y lidera → A retoma con leaderDeviceID==A → falso
    /// sameDeviceReclaim → la máquina lo avanzaría a assigningIdentity. Dos líderes. La arista
    /// `claimingInProgress + sameDeviceReclaim=true` de la máquina queda intencionalmente
    /// INALCANZABLE desde este runner.
    ///
    /// Devuelve `false` para cortar el bucle (no-success).
    private func driveClaim() async throws -> Bool {
        let state = try loadState()
        if state.leaderDeviceID != deviceID {
            state.leaderDeviceID = deviceID
            state.updatedAt = now()
            try context.save()
        }
        switch await executor.performClaim() {
        case let .success(claimState):
            lastClaimBlocker = nil
            try await handle(.claimResult(claimState, sameDeviceReclaim: false))
            return true
        case .sessionExpired:
            lastClaimBlocker = .sessionExpired
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "sessionExpired")
            return false
        case .accountUnavailable:
            lastClaimBlocker = .accountUnavailable
            CloudSyncBreadcrumb.migrationAccountUnavailable()
            return false
        case .transient:
            // La red SÍ se reintenta: no es un bloqueo de cuenta y no debe apagar la barra de progreso.
            lastClaimBlocker = nil
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "transient")
            return false
        }
    }

    /// `uploadingSnapshot`. `pageConfirmed` journalea el cursor (no cambia de fase, re-loop); `completed`
    /// avanza; `transient` corta retomable.
    private func driveUpload() async throws -> Bool {
        let cursor = try loadState().snapshotCursorJSON
        switch await executor.uploadSnapshot(cursor: cursor) {
        case .completed:
            try await handle(.snapshotUploaded)
            return true
        case let .pageConfirmed(newCursor):
            let state = try loadState()
            state.snapshotCursorJSON = newCursor
            state.updatedAt = now()
            try context.save()
            // Heartbeat (I14-pre): el snapshot de un corpus 10k+ podría superar los 60 min del lease — late
            // por página confirmada (el throttle del executor lo capa a 1/min) para mantenerlo vivo.
            await executor.sendLeaseHeartbeatIfDue()
            return true                       // re-loop: sigue subiendo desde el cursor confirmado
        case .transient:
            return false                      // el caller reintenta después (sin retry-loop de red aquí)
        }
    }

    /// `verifying` (S9). Inyecta el `retriesSoFar` desde el journal; incrementa el contador correcto en el
    /// MISMO `save()` que journalea la transición, y SOLO cuando la transición realmente reintenta.
    /// Devuelve `false` para CORTAR el bucle retomable: tras un `networkTimeout` que reintenta, drive()
    /// NO re-verifica inmediatamente — un tight-loop quemaría el presupuesto global de 8 retries en
    /// segundos ante un túnel/ascensor (S9: "no pude verificar por red" es un fallo LENTO, el retry
    /// llega por el próximo resume()/submit externo, que da el pacing natural). `newDeltaDetected` SÍ
    /// re-verifica inmediato (hay trabajo real que empujar; acotado por actividad del usuario).
    private func driveVerify() async throws -> Bool {
        let probe = await executor.verify()
        switch probe {
        case .match:
            // C-1: precondición del canal iCloud ANTES de journalear `cutover(.pending)`. Aquí no hay claim
            // del cutover, ni `migrated_at`, ni `.cloud` persistido, ni marcador: si el canal por el que el
            // marcador tiene que viajar está sabido-roto, abortamos SIN haber tocado nada durable. Es la
            // diferencia entre "no empezamos" y "empezamos y no podemos terminar".
            if try await abortCutoverEntryIfChannelBroken() { return true }
            try await handle(.verifyOutcome(.match))
            return true
        case .newDeltaDetected:
            try await handle(.verifyOutcome(.newDeltaDetected))   // no consume retry
            return true
        case .mismatch:
            let spent = try loadState().verifyMismatchRetries
            try await handle(.verifyOutcome(.mismatch(retriesSoFar: spent))) { state, next in
                // Solo si REINTENTA (uploadingSnapshot) se gasta un retry + se limpia el cursor.
                if next == .uploadingSnapshot {
                    state.verifyMismatchRetries += 1
                    state.snapshotCursorJSON = nil
                }
            }
            return true
        case .networkTimeout:
            let spent = try loadState().verifyNetworkRetries
            try await handle(.verifyOutcome(.networkTimeout(retriesSoFar: spent))) { state, next in
                if next == .verifying { state.verifyNetworkRetries += 1 }
            }
            // Si degradó a failedRollback (tope), drive() corta solo en la próxima vuelta; si reintenta
            // (sigue en verifying), corta AQUÍ retomable (sin tight-loop de red).
            return try loadState().readPhase().phase != .verifying
        }
    }

    /// C-1: consulta el canal iCloud y, si está sabido-roto, journalea el abort de ENTRADA. Devuelve `true`
    /// si abortó (el caller debe devolver `true` para que `drive()` re-lea la fase y salga por el terminal).
    ///
    /// Se consulta en los DOS puntos de entrada posibles (`verifying` rama `.match` y `cutover(.pending)`)
    /// porque un kill entre ambos deja el journal en `pending` y el resume entraría por el segundo sin pasar
    /// por el primero. Del sub-estado `.serverConfirmed` en adelante ya NO se consulta: ahí el server estampó
    /// `migrated_at` y quien manda es el tope del paso 4 — un abort de entrada tardío sería una regresión de
    /// la regla "el cutover jamás hace rollback".
    private func abortCutoverEntryIfChannelBroken() async throws -> Bool {
        let verdict = await executor.probeICloudChannel()
        guard verdict.blocksCutoverEntry else { return false }
        CloudSyncBreadcrumb.migrationICloudPreconditionFailed(reason: verdict.rawValue)
        MetricsService.cloudCutoverICloudBlocked(verdict: verdict.rawValue)
        try await handle(.icloudCutoverPreconditionFailed) { state, _ in
            state.cutoverICloudVerdictRaw = verdict.rawValue
        }
        return true
    }

    /// Cutover, un sub-estado por vuelta (§g.4). Devuelve `false` para cortar retomable.
    private func driveCutover(_ sub: CutoverSubstate) async throws -> Bool {
        switch sub {
        case .pending:
            // C-1: segunda puerta de la precondición — cubre el resume que entra directo aquí tras un kill
            // entre el verify y el cutover. Nada durable ha cambiado todavía en este sub-estado.
            if try await abortCutoverEntryIfChannelBroken() { return true }
            guard await executor.confirmCutoverServer() else { return false }
            try await handle(.serverConfirmedAck)
            return true
        case .serverConfirmed:
            guard await executor.persistLocalMode() else { return false }
            try await handle(.localModePersisted)          // efecto: startParallelHistoryCapture
            return true
        case .localModeSet:
            try await handle(.markerWritten) { state, next in
                // C-1: sello ÚNICO del reloj del tope, en el MISMO save que journalea el sub-estado. NO se
                // re-escribe: si cada resume lo re-sellara, el presupuesto nunca vencería y el limbo seguiría
                // siendo eterno — que es exactamente el bug.
                if next == .cutover(.markerWritten), state.markerWrittenSince == nil {
                    state.markerWrittenSince = self.now()
                }
            }                                              // efecto: writeCloudKitMarker
            return true
        case .markerWritten:
            // Gate de EXPORT del marcador (§g.4 ajuste de /review-plan): solo apagar el mirror cuando el
            // marcador LLEGÓ a CloudKit. El save del marcador exporta ASYNC — apagarlo antes lo perdería
            // para siempre (los 2º devices jamás se auto-bloquearían = divergencia silenciosa, el punto
            // entero del paso 3).
            if executor.isMarkerExported() {
                try await handle(.mirrorDisabled)          // efecto: disableMirrorAndRelaunch (persiste flag; NO mata el proceso)
                return true
            }
            // C-1: el gate no se satisface. Antes de esperar, preguntar POR QUÉ — porque hay un caso en el que
            // esperar es esperar para siempre y degradar sería aún peor.
            let verdict = await executor.probeICloudChannel()
            if verdict == .noChannelNoFootprint {
                // WAIVER: sin cuenta iCloud Y sin huella CloudKit no existe copia del corpus en CloudKit, así
                // que el marcador es indeliverable Y prescindible (no hay nadie a quien avisar ni copia de la
                // que divergir). Degradar aquí sería PEOR que el bug: la condición es PERMANENTE, así que
                // "Reintentar" fallaría siempre y el modo nube quedaría vetado para quien no usa iCloud.
                // Se relaja el gate de EXPORT, nunca la cadena de fases.
                CloudSyncBreadcrumb.migrationMarkerExportWaived()
                MetricsService.cloudCutoverMarkerWaived()
                try await handle(.mirrorDisabled) { state, _ in
                    state.cutoverICloudVerdictRaw = verdict.rawValue
                }
                return true
            }
            CloudSyncBreadcrumb.migrationMarkerExportPending()
            guard let since = try loadState().markerWrittenSince else {
                // Journal escrito por un build ANTERIOR a C-1 (devices de dev): sellar el reloj ahora y cortar
                // retomable. El presupuesto empieza a contar desde esta primera observación, no retroactivo.
                try await handle(.markerExportStalled(elapsedSeconds: 0, cause: verdict.stallCause)) { st, _ in
                    st.markerWrittenSince = self.now()
                }
                return false
            }
            let elapsed = now().timeIntervalSince(since)
            CloudSyncBreadcrumb.migrationMarkerExportStalled(
                elapsedSeconds: elapsed, reason: verdict.rawValue)
            // El canario se emite en CADA observación, no solo al agotar: un atasco SISTÉMICO (p.ej. el record
            // type del marcador sin desplegar a CloudKit Production) se ve así en el dashboard mucho antes de
            // que ningún device llegue a degradar.
            MetricsService.cloudCutoverMarkerStalled(verdict: verdict.rawValue)
            try await handle(.markerExportStalled(elapsedSeconds: elapsed, cause: verdict.stallCause)) { st, next in
                if next != .cutover(.markerWritten) { st.cutoverICloudVerdictRaw = verdict.rawValue }
            }
            // Bajo presupuesto la máquina holdea en el mismo sub-estado → cortar retomable (sin tight-loop,
            // molde del `networkTimeout` del verify). Si degradó, seguir para que `drive()` salga por el terminal.
            guard try loadState().readPhase().phase != .cutover(.markerWritten) else { return false }
            CloudSyncBreadcrumb.migrationCutoverAbortedToICloud()
            MetricsService.cloudCutoverAborted(verdict: verdict.rawValue)
            return true
        case .mirrorOff:
            // Resuelto SIEMPRE por observación (forward tras ejecutar el efecto, o resume post-relaunch).
            guard executor.isMirrorConfirmedOff() else { return false }
            try await handle(.mirrorRelaunchCompleted)     // → done
            return true
        }
    }

    // MARK: - Reversa (§h, I11-2) — driving por fase

    /// `reverseClaimLeader`. `accepted` → avanza; `otherLeader` → desatascador (vuelve al origin
    /// journaleado); el resto (session/transient/rejected) → stop retomable SIN evento (un resume re-claima).
    /// Devuelve `false` para cortar el bucle.
    private func driveReverseClaim() async throws -> Bool {
        switch await executor.performReverseClaim() {
        case .accepted:
            try await handle(.reverseLeaderClaimed)
            return true
        case .otherLeader:
            CloudSyncBreadcrumb.reverseOtherLeader()
            try await handle(.reverseOtherLeader(returnTo: try originFromJournal()))
            return false                                   // la máquina ya movió al origin (terminal/forward)
        case .sessionExpired:
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "reverse: sessionExpired")
            return false
        case .transient:
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "reverse: transient")
            return false
        case let .rejected(reason):
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "reverse: \(reason)")
            return false
        }
    }

    /// `reverseVerify` (S9 REUSADO; autoridad backend→local → un mismatch RE-DRENA, no re-sube). Inyecta el
    /// `retriesSoFar` desde el journal e incrementa el contador correcto en el MISMO save. Corta tras un
    /// `networkTimeout` que reintenta (anti tight-loop, igual que el verify forward).
    private func driveReverseVerify() async throws -> Bool {
        switch await executor.verify() {
        case .match:
            try await handle(.reverseVerifyOutcome(.match))
            return true
        case .newDeltaDetected:
            try await handle(.reverseVerifyOutcome(.newDeltaDetected))   // no consume retry
            return true
        case .mismatch:
            let spent = try loadState().verifyMismatchRetries
            try await handle(.reverseVerifyOutcome(.mismatch(retriesSoFar: spent))) { state, next in
                // Solo si REINTENTA (reverseDrainAll = re-pull) se gasta un retry. NO se limpia cursor (la
                // reversa no re-sube snapshot).
                if next == .reverseDrainAll { state.verifyMismatchRetries += 1 }
            }
            return true
        case .networkTimeout:
            let spent = try loadState().verifyNetworkRetries
            try await handle(.reverseVerifyOutcome(.networkTimeout(retriesSoFar: spent))) { state, next in
                if next == .reverseVerify { state.verifyNetworkRetries += 1 }
            }
            // Si degradó a reverseFailedRollback (tope), drive() corta solo en la próxima vuelta; si reintenta
            // (sigue en reverseVerify), corta AQUÍ retomable (sin tight-loop de red).
            return try loadState().readPhase().phase != .reverseVerify
        }
    }

    /// `reverseReconcile`, un sub-estado por vuelta (§h.3, orden estricto). Devuelve `false` para cortar retomable.
    private func driveReverseReconcile(_ sub: ReverseReconcileSubstate) async throws -> Bool {
        switch sub {
        case .awaitingQuiescence:
            // El PRIMER delete+save espera quiescencia del import del mirror remontado (SERIO 3 v3, molde SpikeS6).
            guard quiescenceSignal() else { return false }
            try await handle(.reverseQuiescenceReached)
            return true
        case .deletingZombies:
            switch await executor.sweepZombies(sinceSeq: try reverseSeqCut()) {
            case let .completed(deleted):
                CloudSyncBreadcrumb.reverseZombiesSwept(count: deleted)
                try await handle(.reverseZombiesDeleted)
                return true
            case .transient:
                return false
            }
        case .rebindingUUIDs:
            let verified = executor.verifyRebinds()
            CloudSyncBreadcrumb.reverseRebindsVerified(count: verified)
            try await handle(.reverseUUIDsRebound)
            return true
        case .dedupHealed:
            let healed = executor.healDuplicates()
            CloudSyncBreadcrumb.reverseDuplicatesHealed(count: healed)
            try await handle(.reverseDedupHealed)
            return true
        }
    }

    /// `reverseUpload`. `drained` → cierra a `icloudActive` (con el cuarteto de efectos); `pending(count)` →
    /// breadcrumb + stop retomable (el resume/panel re-sondea el drenaje del mirror).
    private func driveReverseUpload() async throws -> Bool {
        switch executor.reverseUploadStatus() {
        case .drained:
            try await handle(.reverseUploadCompleted)      // → icloudActive [marker, beacon, mode, server]
            return true
        case let .pending(count):
            CloudSyncBreadcrumb.reverseUploadPending(count: count)
            // Heartbeat (I14-pre): cada re-poll del panel/resume mientras el mirror aún exporta mantiene la
            // lease viva (el drenaje a CloudKit puede tardar).
            await executor.sendLeaseHeartbeatIfDue()
            return false
        }
    }

    /// El `origin` de la reversa journaleado (`reverseOriginRaw`) para el desatascador `reverseOtherLeader`.
    /// Fallback `.done` si falta (benigno: markerReconciliation(done)→.none; veraz para el líder migrado —
    /// el único caso real actual).
    private func originFromJournal() throws -> ReverseOrigin {
        (try loadState().reverseOriginRaw).flatMap(ReverseOrigin.init(rawValue:)) ?? .done
    }

    /// Corte `serverSeqCut` para el barrido de zombies. Fuente PRIMARIA: la fila local `CloudMigrationMarker`
    /// (vive hasta `icloudActive`); FALLBACK: `MigrationState.serverSeqCut` (journal — hoy NADIE lo escribe,
    /// queda 0); FALLBACK: 0 + breadcrumb (since-0 es correcto, solo más caro). Nunca lanza por un fallo de
    /// fetch (degrada a 0).
    private func reverseSeqCut() throws -> Int64 {
        if let cut = markerSeqCut(), cut > 0 { return cut }
        let journalCut = try loadState().serverSeqCut
        if journalCut > 0 { return journalCut }
        CloudSyncBreadcrumb.reverseSeqCutFallbackZero()
        return 0
    }

    /// `CloudMigrationMarker.serverSeqCut` de la fila local (single-row). Lectura pura; `nil` si no hay marcador
    /// o el fetch falla.
    private func markerSeqCut() -> Int64? {
        do {
            var descriptor = FetchDescriptor<CloudMigrationMarker>()
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.serverSeqCut
        } catch {
            #if DEBUG
            print("MigrationRunner: fetch(CloudMigrationMarker) para serverSeqCut falló: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Resume

    /// Normalización compartida (M1): journal ilegible (rot del enum) → breadcrumb RUIDOSO + reset
    /// completo a `notStarted` (incl. campos scoped — no dejar restos de un intento ilegible).
    /// Devuelve `true` si hubo corrupción (el caller corta).
    private func normalizeCorruptJournalIfNeeded() throws -> Bool {
        let state = try loadState()
        guard state.readPhase().decodeFailed else { return false }
        CloudSyncBreadcrumb.migrationPhaseDecodeFailed()
        state.setPhase(.notStarted)
        state.setPendingEffects([])
        state.leaderDeviceID = nil
        state.verifyMismatchRetries = 0
        state.verifyNetworkRetries = 0
        state.snapshotCursorJSON = nil
        state.markerWrittenSince = nil
        state.cutoverICloudVerdictRaw = nil
        state.startedAt = nil
        state.updatedAt = now()
        try context.save()
        return true
    }

    private func resumeInternal() async throws {
        if try normalizeCorruptJournalIfNeeded() { return }
        let state = try loadState()
        let journaled = state.readPhase().phase
        let resumed = MigrationStateMachine.resume(fromJournaled: journaled)
        if resumed != journaled {
            // Estados no-durables (dryRun/consent/authenticating) reingresan desde notStarted.
            state.setPhase(resumed)
            state.setPendingEffects([])
            state.updatedAt = now()
            try context.save()
            CloudSyncBreadcrumb.migrationJournaled(phase: "\(resumed)")
        }
        try await drainPendingEffects(isResume: true)      // N1 + contrato del relaunch
        try await drive()
    }

    // MARK: - Follower (M3)

    private func pollLeaderInternal() async throws {
        guard try loadState().readPhase().phase == .waitingForLeader else { return }
        switch await executor.performClaim() {
        case .success(.existingStable):
            lastClaimBlocker = nil
            try await handle(.leaderCompleted)             // → notStarted + adoptBackendAccount
        case .success(.claimingInProgress):
            lastClaimBlocker = nil
            return                                         // sigue esperando, sin evento
        case .success(.created):
            lastClaimBlocker = nil
            // El líder se esfumó → re-claim. TRADUCIR a leaderVanished y REUSAR el resultado ya obtenido
            // (sin 2º POST). `sameDeviceReclaim: false` — ver doc de `driveClaim` (para `.created` la
            // máquina lo ignora de todas formas).
            try await handle(.leaderVanished)              // → claimingMigration
            try await handle(.claimResult(.created, sameDeviceReclaim: false))
        case .sessionExpired:
            lastClaimBlocker = .sessionExpired
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "sessionExpired")
            return
        case .accountUnavailable:
            lastClaimBlocker = .accountUnavailable
            CloudSyncBreadcrumb.migrationAccountUnavailable()
            return
        case .transient:
            lastClaimBlocker = nil
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "transient")
            return                                         // red del poll → sin evento (reintento posterior)
        }
        try await drive()
    }

    // MARK: - Journal helpers

    private func loadState() throws -> MigrationState {
        if let cached = cachedState { return cached }
        let state = try MigrationState.loadOrCreate(in: context)
        cachedState = state
        return state
    }

    private func markStartedIfNeeded() throws {
        let state = try loadState()
        if state.startedAt == nil {
            state.startedAt = now()
            state.updatedAt = now()
            try context.save()
        }
    }

    // MARK: - Quiescencia (estilo SpikeS6, tope + tick INYECTABLES para determinismo en tests)

    /// Espera `quiescenceSignal()` en ticks deterministas (`maxTicks = ceil(tope/tick)`). Devuelve si se
    /// alcanzó. NO escribe nada del journal (ni un `save()`) mientras espera.
    private func awaitQuiescence() async -> Bool {
        if quiescenceSignal() { return true }
        let maxTicks = max(1, Int((quiescenceTimeoutSeconds / quiescenceTickSeconds).rounded(.up)))
        for _ in 0..<maxTicks {
            await sleeper(quiescenceTickSeconds)
            if quiescenceSignal() { return true }
        }
        return quiescenceSignal()
    }
}
