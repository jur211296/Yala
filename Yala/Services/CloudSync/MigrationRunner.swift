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
//     `fatalError` (un 401 recuperable no debe producir un rollback espurio).
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

/// Resultado de un paso del uploader del snapshot (w4). `pageConfirmed` avanza el cursor sin cambiar de
/// fase (re-loop); `completed` cierra la subida; `transient` corta retomable.
enum SnapshotStepOutcome: Equatable {
    case completed
    case pageConfirmed(cursor: String)
    case transient
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

    /// Reinicio EXPLÍCITO tras un `failedRollback` (S2): la máquina no tiene arista de salida de ese
    /// estado terminal a propósito (el reinicio es una decisión del USUARIO, no una transición
    /// automática). Resetea el journal COMPLETO a `notStarted` (fase, efectos, campos scoped y
    /// `startedAt`). No-op fuera de `failedRollback`. I14 lo invoca desde el botón "reintentar".
    func resetAfterRollback() async {
        guard await awaitQuiescence() else {
            CloudSyncBreadcrumb.migrationQuiescenceTimeout()
            return
        }
        await runGuarded {
            let state = try self.loadState()
            guard state.readPhase().phase == .failedRollback else { return }
            state.setPhase(.notStarted)
            state.setPendingEffects([])
            state.leaderDeviceID = nil
            state.verifyMismatchRetries = 0
            state.verifyNetworkRetries = 0
            state.snapshotCursorJSON = nil
            state.startedAt = nil
            state.updatedAt = self.now()
            try self.context.save()
            CloudSyncBreadcrumb.migrationJournaled(phase: "notStarted (reset tras rollback)")
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
            // S2 (review adversarial): al llegar a un estado de CIERRE de intento, limpiar los campos
            // SCOPED a la migración en el MISMO save — un `leaderDeviceID`/contador/cursor stale que
            // sobreviva a un intento anterior envenenaría al siguiente (p.ej. contadores S9 ya gastados
            // → rollback prematuro). `startedAt` se conserva en `failedRollback` (diagnóstico del intento
            // fallido) y se limpia en `notStarted` (adopt/decline — sin migración en curso).
            if next == .notStarted || next == .failedRollback {
                state.leaderDeviceID = nil
                state.verifyMismatchRetries = 0
                state.verifyNetworkRetries = 0
                state.snapshotCursorJSON = nil
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
            try await handle(.claimResult(claimState, sameDeviceReclaim: false))
            return true
        case .sessionExpired:
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "sessionExpired")
            return false
        case .accountUnavailable:
            CloudSyncBreadcrumb.migrationAccountUnavailable()
            return false
        case .transient:
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

    /// Cutover, un sub-estado por vuelta (§g.4). Devuelve `false` para cortar retomable.
    private func driveCutover(_ sub: CutoverSubstate) async throws -> Bool {
        switch sub {
        case .pending:
            guard await executor.confirmCutoverServer() else { return false }
            try await handle(.serverConfirmedAck)
            return true
        case .serverConfirmed:
            guard await executor.persistLocalMode() else { return false }
            try await handle(.localModePersisted)          // efecto: startParallelHistoryCapture
            return true
        case .localModeSet:
            try await handle(.markerWritten)               // efecto: writeCloudKitMarker
            return true
        case .markerWritten:
            try await handle(.mirrorDisabled)              // efecto: disableMirrorAndRelaunch (puede matar el proceso)
            return true
        case .mirrorOff:
            // Resuelto SIEMPRE por observación (forward tras ejecutar el efecto, o resume post-relaunch).
            guard executor.isMirrorConfirmedOff() else { return false }
            try await handle(.mirrorRelaunchCompleted)     // → done
            return true
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
            try await handle(.leaderCompleted)             // → notStarted + adoptBackendAccount
        case .success(.claimingInProgress):
            return                                         // sigue esperando, sin evento
        case .success(.created):
            // El líder se esfumó → re-claim. TRADUCIR a leaderVanished y REUSAR el resultado ya obtenido
            // (sin 2º POST). `sameDeviceReclaim: false` — ver doc de `driveClaim` (para `.created` la
            // máquina lo ignora de todas formas).
            try await handle(.leaderVanished)              // → claimingMigration
            try await handle(.claimResult(.created, sameDeviceReclaim: false))
        case .sessionExpired:
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "sessionExpired")
            return
        case .accountUnavailable:
            CloudSyncBreadcrumb.migrationAccountUnavailable()
            return
        case .transient:
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
