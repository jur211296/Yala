//
//  CloudSyncRuntime.swift
//  Yala
//
//  Orquestador (dueño del ciclo de vida) del motor Modo Nube (incremento I9). El motor —captura,
//  push, pull/apply, Merkle— estaba COMPLETO y verificado E2E componente-a-componente; lo que faltaba
//  era QUIÉN decide cuándo drenar/subir/pullear/verificar, con backoff y las redes de arranque
//  (rehydrate del espejo, guard de cuarentena recreada, drenaje del upgrade path) y de teardown (M1).
//  Este archivo es ese dueño.
//
//  TODO DARK: con `CloudSyncFlags.syncRuntimeEnabled == false` (default de PRODUCCIÓN HOY) `start()` es
//  un no-op TOTAL — cero red, cero cadencia, cero mutación de store. El provider de sesión de producción
//  (`NoopCloudSessionProvider`) además NO tiene sesión → aunque el flag se encendiera, `start()` cae en
//  `idle(signedOut)` sin tocar nada (el despertar real por sign-in es I7c).
//
//  INVARIANTES CRÍTICOS (violarlos = bug grave):
//   - Anti-laundering (D-2/F-1/F-8): el apply de deltas remotos entra SOLO por `pullAndApplyOnce` (que
//     drena SÍNCRONO antes de cada página); el drenaje de cuarentena replica la disciplina (drain
//     síncrono inmediatamente antes, sin `await` entre medio).
//   - `.accountUnavailable` (403) / attest terminal → stop SIN reintentos (S6). `.sessionExpired` →
//     stop hasta re-firmar, re-evaluable en `handleBecameActive`.
//   - Remediación Merkle: UNA por sesión de proceso, jamás loop.
//   - Anti-solape: a lo sumo un ciclo en vuelo; `handleBecameActive` durante un ciclo no reentra
//     (coalescing "one in-flight, one queued", como el drain).
//
//  `@MainActor final class`: muta `ModelContext`/`@Model` (regla inviolable) y coordina el motor
//  `@MainActor`. Instancia ÚNICA owned por AppBootstrapper (NO singleton global); `shared` se asigna en
//  el wiring para el acceso desde `handleBecameActive`.
//

import Foundation
import SwiftData

// MARK: - Notification (fan-out post-apply, §i.4)

extension Notification.Name {
    /// Se postea tras un ciclo del runtime con `pagesApplied > 0` (llegaron cambios remotos). El wiring
    /// DARK de AppBootstrapper lo cablea a `SessionState.markRemoteChangePending()` para refrescar la UI.
    static let cloudSyncAppliedRemoteChanges = Notification.Name("cloudSyncAppliedRemoteChanges")
}

// MARK: - Seam de sesión (I7c)

/// Proveedor de la sesión de sync (JWT de Supabase + attest + identidad). Seam que I7c implementará de
/// verdad; en I9 el único implementador de producción es `NoopCloudSessionProvider` (sin sesión). El
/// contrato del error de `attestToken()` es `AppAttestError` (el runtime lo clasifica con
/// `AttestSyncGate`); no se inventa un tipo nuevo (regla del review).
@MainActor
protocol CloudSyncSessionProviding: AnyObject {
    /// El `sub` de la sesión (owner-scoping del espejo + gate de arranque). `nil` = sin sesión.
    var currentUserID: String? { get }
    /// JWT de Supabase para las llamadas al gateway. `nil` = sin sesión.
    func accessToken() async -> String?
    /// ¿La sesión puede renovarse silenciosamente (refresh token vigente)? Consumido por
    /// `SessionExpiryPolicy` (pendientes + no-renovable → estado accionable "inicia sesión").
    var canRenewSession: Bool { get }
    /// Token de sesión de App Attest. `nil` = attest no requerido / no disponible (DARK). Lanza
    /// `AppAttestError` cuando la adquisición falla (el runtime clasifica transient/terminal).
    func attestToken() async throws -> String?
    /// Acción de claim resuelta por el flujo de auth (I7c). `nil` = sin claim (Noop → proceed). El gate
    /// de arranque solo deja arrancar el sync para las acciones proceed-like.
    var claimAction: AccountClaimDecision.AuthAction? { get }
}

extension CloudSyncSessionProviding {
    var claimAction: AccountClaimDecision.AuthAction? { nil }
}

/// Implementación DARK de producción: SIN sesión. `start()` con este provider cae en `idle(signedOut)`
/// sin tocar red ni store. I7c lo reemplaza por el provider real que despierta con el sign-in.
@MainActor
final class NoopCloudSessionProvider: CloudSyncSessionProviding {
    var currentUserID: String? { nil }
    func accessToken() async -> String? { nil }
    var canRenewSession: Bool { false }
    func attestToken() async throws -> String? { nil }
}

// MARK: - CloudSyncRuntime

@MainActor
final class CloudSyncRuntime {

    /// Instancia asignada por el wiring de AppBootstrapper (para `handleBecameActive` desde el bootstrapper).
    /// NO es un singleton global auto-creado — se asigna explícitamente en `startShared`.
    static private(set) var shared: CloudSyncRuntime?

    // MARK: Estado del ciclo de vida

    enum RuntimeState: Equatable {
        /// Aún no arrancó (o teardown lo devolvió aquí por falta de sesión).
        case idle
        /// Arrancó pero no hay sesión (I7c la despierta al firmar).
        case idleSignedOut
        /// Cadencia activa.
        case running
        /// Detenido hasta re-firmar (401 / sesión no renovable). Re-evaluable en `handleBecameActive`.
        case stoppedUntilSignIn
        /// Detenido hasta relanzar (403 / attest terminal). Pegado A PROPÓSITO (sin loop).
        case stoppedUntilRelaunch
    }

    private(set) var state: RuntimeState = .idle

    // MARK: Dependencias inyectadas

    private let engine: CloudSyncEngine
    private let pushClient: SyncPushClient
    private let pullClient: SyncPullClient
    private let merkleClient: SyncMerkleClient
    private let mirror: SyncOutboxMirror?
    private let coordinator: SyncQuiescenceCoordinator
    private let session: CloudSyncSessionProviding
    private let onRemoteChangesApplied: (() -> Void)?

    /// I13 (prefs sync): transporte + cola durable de preferencias. `nil` = paso de prefs deshabilitado
    /// (tests del runtime que no lo ejercitan). El merge del pull lo aplica `PreferenceSyncService.shared`.
    private let prefsClient: PrefsSyncClient?
    private let prefsOutbox: PrefsOutbox?

    /// El contexto sobre el que opera (el `mainContext` compartido en prod). Se fija en `start()`.
    private var context: ModelContext?

    // MARK: Estado interno de cadencia / anti-solape

    private var isCycling = false
    private var pendingCycle = false
    private var consecutiveTransients = 0
    private var cadenceTask: Task<Void, Never>?

    /// SERIO-2 (teardown M1 vs ciclo en vuelo): `Task.cancel()` es COOPERATIVO y `performCycle` no
    /// chequea cancelación en sus awaits — un push suspendido terminaría y APLICARÍA resultados (purga
    /// de outbox/espejo) bajo una sesión que ya no existe. Este contador de época lo corta: cada
    /// teardown lo incrementa; `performCycle` captura la época al entrar y la re-verifica tras CADA
    /// `await` — si cambió, aborta SIN aplicar resultados ni tocar el store.
    private var sessionEpoch = 0

    // MARK: Estado de Merkle

    private var completedPullsSinceMerkle = 0
    private var lastMerkleAt: Date?
    /// Throttle anti-loop: máximo UNA remediación Merkle por sesión de proceso (E-bis).
    private var didRemediateMerkleThisSession = false

    // MARK: Estado de attest (retry budget → terminal)

    private var attestRetryCount = 0

    // MARK: Init

    init(
        engine: CloudSyncEngine,
        pushClient: SyncPushClient,
        pullClient: SyncPullClient,
        merkleClient: SyncMerkleClient,
        mirror: SyncOutboxMirror?,
        coordinator: SyncQuiescenceCoordinator,
        session: CloudSyncSessionProviding,
        onRemoteChangesApplied: (() -> Void)?,
        prefsClient: PrefsSyncClient? = nil,
        prefsOutbox: PrefsOutbox? = nil
    ) {
        self.engine = engine
        self.pushClient = pushClient
        self.pullClient = pullClient
        self.merkleClient = merkleClient
        self.mirror = mirror
        self.coordinator = coordinator
        self.session = session
        self.onRemoteChangesApplied = onRemoteChangesApplied
        self.prefsClient = prefsClient
        self.prefsOutbox = prefsOutbox
    }

    // MARK: - Emisión de IdentityRemap (DIFERIDOS #29, §b.4)

    /// El motor de captura, expuesto SOLO para que `CategoryDeduplicationService.repairCollapsedIdentityUUIDs`
    /// (App layer, static) emita el IdentityRemap en la MISMA transacción de su save (§b.4 crítica #6) reusando
    /// el reloj HLC + el espejo App Group ya montados por el runtime. NO se expone para otros usos: el ciclo de
    /// vida del motor lo gobierna el runtime. Alcanzable solo vía `shared` (⇒ runtime vivo, gate estructural).
    var identityRemapEmitter: CloudSyncEngine { engine }

    // MARK: - Gate puro de arranque (AccountClaimDecision, §f.1)

    /// Solo las acciones proceed-like arrancan el sync (el flujo de claim UI completo es I7c/I14):
    /// seed/migración/returning-user proceden; follower (`waitForLeader`) y provider-mismatch NO. Puro.
    static func shouldStartSync(after action: AccountClaimDecision.AuthAction) -> Bool {
        switch action {
        case .seedBornCloud, .proceedMigration, .routeReturningUser:
            return true
        case .waitForLeader, .showProviderMismatch:
            return false
        }
    }

    /// P0: ¿puede correr el runtime del DOMINIO? Solo en `.cloud` y con la fase de migración ESTABLE
    /// (`done`/`notStarted`). Consultado por `start()` y por `handleBecameActive` (re-arranques). En
    /// `.icloud` (todo device de producción HOY) o en una fase transicional → `false`.
    static func canRunDomain() -> Bool {
        CloudSyncFlags.storageMode == .cloud
            && MigrationRuntimeGate.isDomainStablePhase(MigrationPhaseStore.shared.currentPhase)
    }

    // MARK: - Wiring de producción (DARK)

    /// Construye (perezosamente) e inicia la instancia `shared`. No-op si el flag está apagado. Con el
    /// `NoopCloudSessionProvider` (sin sesión) `start()` cae en `idle(signedOut)` sin tocar nada.
    static func startShared(context: ModelContext) async {
        guard CloudSyncFlags.syncRuntimeEnabled else { return }
        let runtime = shared ?? makeDefault()
        shared = runtime
        // P4: idempotente — si la instancia ya está corriendo su cadencia, no re-arrancar (el paso 14.7
        // del boot y el coordinator de migración P4 pueden ambos llamar aquí; el segundo debe ser no-op).
        if runtime.state == .running { return }
        await runtime.start(context: context)
    }

    /// Fábrica de producción (DARK): motor + clients con providers de la sesión + espejo App Group. Con
    /// `CloudBackendConfig.isConfigured` usa el `LiveCloudSessionProvider` (sesión real de I7c); si no
    /// (producción placeholder), conserva el `NoopCloudSessionProvider` de I9 → sin sesión, sin cambio.
    private static func makeDefault() -> CloudSyncRuntime {
        // `session` capturado FUERTE por los providers (viven en los clients → runtime). Sin ciclo de
        // vuelta al runtime. Evita el doble-opcional del optional-chaining.
        let session: CloudSyncSessionProviding = CloudBackendConfig.isConfigured
            ? LiveCloudSessionProvider()
            : NoopCloudSessionProvider()
        let token: () async -> String? = { await session.accessToken() }
        let attest: () async -> String? = { try? await session.attestToken() }
        let engine = CloudSyncEngine()
        let push = SyncPushClient(tokenProvider: token, attestProvider: attest)
        let pull = SyncPullClient(tokenProvider: token, attestProvider: attest)
        let merkle = SyncMerkleClient(tokenProvider: token, attestProvider: attest)
        return CloudSyncRuntime(
            engine: engine,
            pushClient: push,
            pullClient: pull,
            merkleClient: merkle,
            mirror: SyncOutboxMirror(),
            coordinator: .shared,
            session: session,
            // Fan-out cableado por el observer DARK de AppBootstrapper vía `.cloudSyncAppliedRemoteChanges`
            // (el runtime SIEMPRE postea la Notification además de este closure opcional).
            onRemoteChangesApplied: nil,
            // I13: prefs sync (transporte + cola durable App Group). Mismos providers de sesión/attest.
            prefsClient: PrefsSyncClient(tokenProvider: token, attestProvider: attest),
            prefsOutbox: PrefsOutbox()
        )
    }

    // MARK: - Arranque

    /// Secuencia de arranque (≈ el "startEngines" del motor). DOBLE red además del call-site: el guard
    /// del flag. Sin sesión → `idle(signedOut)`. Gate de claim (Noop → proceed). Inyecta espejo +
    /// identidad + gate de reconcilers en el motor, corre las redes de arranque (guard de recreación →
    /// rehydrate → drain síncrono → drenaje de cuarentena → reconcilers de arranque) y arranca la cadencia.
    func start(context: ModelContext) async {
        guard CloudSyncFlags.syncRuntimeEnabled else { return }
        self.context = context

        // P0: DOBLE guard del DOMINIO (además del de flag). El corpus NUNCA sube en `.icloud` (espeja el
        // S1 de prefs, ahora para todo el ciclo) y el runtime NO compite con un cutover/reversa/adopt en
        // vuelo (en `.cloud` con fase transicional quien conduce es el `MigrationRunner`; el coordinator
        // de boot re-arranca el runtime al quedar la fase estable).
        guard Self.canRunDomain() else {
            state = .idle
            CloudSyncBreadcrumb.runtimeIdle(reason: "domain-gate")
            return
        }

        guard let userID = session.currentUserID else {
            state = .idleSignedOut
            CloudSyncBreadcrumb.runtimeIdle(reason: "signed-out")
            return
        }
        // P6 (AJUSTE review #1, guard de IDENTIDAD): en `.cloud`, un `currentUserID` SIN registro de claim
        // deja el runtime `.idle` — todo camino legítimo a `.cloud` estampa el claim-store (migración o
        // adopt); un Apple ID DISTINTO en un device migrado (reinstalación borra `storageMode` → vuelve
        // `.icloud`, pero un user-switch sin reinstalar no) NO debe pushear el corpus del dueño a otra
        // cuenta. `claimAction == nil` en `.cloud` = identidad no-claimeada.
        if CloudSyncFlags.storageMode == .cloud, session.claimAction == nil {
            state = .idle
            CloudSyncBreadcrumb.runtimeBlockedByUnclaimedIdentity()
            return
        }
        if let action = session.claimAction, !Self.shouldStartSync(after: action) {
            state = .idle
            CloudSyncBreadcrumb.runtimeIdle(reason: "claim-not-proceed")
            return
        }

        // Inyectar deps de runtime en el motor. SERIO-1: el gate de reconcilers usa la señal DEDICADA
        // a saves del propio motor (`isQuiescentForEngineSaves`), NO `isImportQuiescent` — esa queda
        // `false` durante toda la ventana markApplyBegan/Ended que envuelve al pull (donde corren los
        // reconcilers) → en `.cloud` sería deferral perpetuo.
        engine.outboxMirror = mirror
        engine.currentUserID = userID
        engine.reconcilerQuiescenceGate = { [coordinator] in coordinator.isQuiescentForEngineSaves }

        // Redes de arranque (orden importa): guard de recreación → rehydrate → drain síncrono → drenaje
        // de cuarentena (F-8 exige el drain síncrono inmediatamente antes) → reconcilers de arranque.
        engine.recoverIfQuarantineRecreated(context: context)
        engine.rehydrateOutboxFromMirror(userID: userID, context: context)
        engine.drainOnce(context: context)
        engine.drainQuarantineOnce(context: context)
        engine.runStartupReconcilersIfQuiescent(context: context)

        CloudSyncBreadcrumb.runtimeStarted()
        // Cadencia: el loop corre el PRIMER ciclo inmediatamente en su primera vuelta (no se corre un
        // ciclo aparte para no duplicarlo). El loop NO se testea — se testean `syncCycle` + policy puros.
        startCadenceLoop()
    }

    // MARK: - Foreground

    /// Al volver a foreground: dispara un ciclo inmediato si la cadencia está viva; en `stoppedUntilSignIn`
    /// re-evalúa la sesión y DESPIERTA si el usuario re-firmó; `stoppedUntilRelaunch` queda pegado (S6).
    func handleBecameActive() {
        guard CloudSyncFlags.syncRuntimeEnabled else { return }
        // P0: re-verifica el gate del dominio antes de re-arrancar la cadencia (un cutover/reversa pudo
        // haber empezado mientras la app estaba en background — no competir con el runner).
        guard Self.canRunDomain() else { return }
        switch state {
        case .stoppedUntilRelaunch, .idle, .idleSignedOut:
            // Relaunch pegado (403/attest terminal); idle sin sesión → el arranque/sign-in (I7c) lo mueve.
            return
        case .stoppedUntilSignIn:
            // El usuario pudo re-firmar: si ahora hay sesión, re-arranca la cadencia (el ciclo re-evalúa
            // `SessionExpiryPolicy` con el `canRenewSession` actual y sube lo pendiente).
            guard session.currentUserID != nil else { return }
            startCadenceLoop()
        case .running:
            // Cancela el sleep actual y corre un ciclo ya (re-arrancar el loop = ciclo inmediato).
            startCadenceLoop()
        }
    }

    // MARK: - Teardown de sesión invitada (M1)

    /// Red M1(a): al cerrar la sesión invitada en un device compartido, purga TODO el espejo App Group
    /// (contiene montos), limpia la identidad del motor y detiene la cadencia. El call-site real
    /// (sign-out invitado) llega con I7c; aquí el hook + su test.
    ///
    /// SERIO-2: además de cancelar el loop (cooperativo), INCREMENTA `sessionEpoch` → un `performCycle`
    /// suspendido en un `await` (p.ej. un push en vuelo) detecta el cambio de época al reanudar y aborta
    /// SIN aplicar resultados (no purga outbox/espejo, no aplica deltas, no confirma nada post-teardown).
    ///
    /// CONTRATO (TODO I7c): este hook NO borra las filas `SyncOutbox`/`SyncQuarantine` ni el cursor del
    /// store sync-meta — podrían pertenecer al owner LEGÍTIMO del device (el store es compartido y
    /// `liveOutboxRows` NO filtra por userID hoy). La purga selectiva/total del estado de sync del store
    /// en el sign-out es responsabilidad del flujo de I7c, que sabe QUIÉN cierra sesión y qué identidad
    /// tienen las filas. Aquí solo se purga el ESPEJO App Group (M1(a), la superficie con montos que
    /// cruza usuarios) y se detiene el motor.
    func teardownGuestSession() {
        sessionEpoch += 1  // aborta el ciclo en vuelo en su próximo re-chequeo post-await
        mirror?.purgeAll()
        prefsOutbox?.purgeAll()  // I13/M1: el outbox de prefs contiene VALORES → no puede cruzar owners
        engine.currentUserID = nil
        cadenceTask?.cancel()
        cadenceTask = nil
        state = .idleSignedOut
        CloudSyncBreadcrumb.runtimeTeardown()
    }

    // MARK: - Cadencia (loop; NO testeado — pragmático)

    private func startCadenceLoop() {
        cadenceTask?.cancel()
        state = .running
        cadenceTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let outcome = await self.performCycleCoalesced()
                if Task.isCancelled { return }
                switch outcome {
                case .transient:
                    self.consecutiveTransients += 1
                case .completed, .sessionExpired, .accountUnavailable:
                    self.consecutiveTransients = 0
                case .coalesced:
                    break  // sin señal de red — NO toca el contador (fix MENOR del review)
                }
                let action = SyncCadencePolicy.nextAction(
                    outcome: outcome, consecutiveTransients: self.consecutiveTransients
                )
                switch action {
                case .scheduleNext(let delay), .backoff(let delay):
                    do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                case .stopUntilSignIn:
                    self.state = .stoppedUntilSignIn
                    CloudSyncBreadcrumb.runtimeStopped(reason: "session-expired")
                    return
                case .stopUntilRelaunch:
                    self.state = .stoppedUntilRelaunch
                    CloudSyncBreadcrumb.runtimeStopped(reason: "account-unavailable")
                    return
                }
            }
        }
    }

    // MARK: - Ciclo (testeable)

    /// Entrada testeable: fija el contexto y corre UN ciclo coalescido. Devuelve el outcome normalizado
    /// para la política de cadencia.
    @discardableResult
    func syncCycle(context: ModelContext) async -> SyncCadencePolicy.CadenceOutcome {
        self.context = context
        return await performCycleCoalesced()
    }

    /// Anti-solape "one in-flight, one queued" (patrón del drain, pero async): si ya hay un ciclo en
    /// vuelo, marca uno pendiente (a lo sumo uno) y retorna `.coalesced`; el ciclo en vuelo lo ejecuta
    /// al terminar. `.coalesced` (no `.transient`) para NO contaminar `consecutiveTransients` con
    /// ráfagas de `handleBecameActive` (fix MENOR del review — un backoff espurio sin fallo real).
    @discardableResult
    private func performCycleCoalesced() async -> SyncCadencePolicy.CadenceOutcome {
        if isCycling {
            pendingCycle = true
            return .coalesced
        }
        isCycling = true
        defer { isCycling = false }
        var last: SyncCadencePolicy.CadenceOutcome = .coalesced
        repeat {
            pendingCycle = false
            last = await performCycle()
        } while pendingCycle
        return last
    }

    /// UN ciclo: drain → attest gate → SessionExpiry gate + push (partición poison #26) → pull/apply
    /// (reconcilers gateados) → fan-out si aplicó → Merkle si toca → purga de history (doble-DARK).
    /// Devuelve el outcome de cadencia.
    ///
    /// SERIO-2: captura `sessionEpoch` al entrar y lo re-verifica tras CADA `await`. Un teardown
    /// (`teardownGuestSession`) durante una suspensión aborta el ciclo con `.coalesced` (resultado sin
    /// señal de cadencia — el loop ya está cancelado) SIN aplicar resultados ni tocar el store.
    private func performCycle() async -> SyncCadencePolicy.CadenceOutcome {
        guard let context else { return .transient }
        let epoch = sessionEpoch

        // 1) Drain SÍNCRONO al entrar (captura escrituras locales pendientes antes de tocar la red).
        engine.drainOnce(context: context)

        // 2) Gate de attest (seam I7b): terminal → stop; transient → backoff; ok → seguir.
        switch await resolveAttest() {
        case .ok:
            break
        case .transient:
            return .transient
        case .terminal:
            TelemetryService.cloudSyncBlockedByAttestUnavailable(platform: "ios")
            CloudSyncBreadcrumb.runtimeStopped(reason: "attest-terminal")
            return .accountUnavailable  // stopUntilRelaunch (sin loop)
        }
        guard epoch == sessionEpoch else { return .coalesced }  // SERIO-2: teardown durante el attest

        // 3) Push de filas vivas (partición poison ANTES; dead-letter poison + canario; el resto sube).
        let liveRows = liveOutboxRows(context)
        if !liveRows.isEmpty {
            let (buildable, poison) = pushClient.partitionBuildable(liveRows)
            if !poison.isEmpty { deadLetterPoison(poison, context: context) }

            // Gate de sesión expirada (pendientes + no-renovable → estado accionable, sin loop).
            // CONTRATO I7c (nota del review): el provider real DEBE devolver `canRenewSession == true`
            // siempre que el access token esté VIGENTE (aunque el refresh token esté en duda) — si lo
            // reporta false con token vigente, este preflight bloquea pushes que habrían tenido éxito.
            if case .blockedNeedsSignIn(let pending) = SessionExpiryPolicy.decide(
                pending: buildable.count, canRenewSession: session.canRenewSession
            ) {
                TelemetryService.cloudSyncBlockedByExpiredSession(pending: pending)
                CloudSyncBreadcrumb.runtimeStopped(reason: "session-expiry-preflight")
                return .sessionExpired
            }

            if !buildable.isEmpty {
                let pushOutcome = await pushClient.push(buildable)
                // SERIO-2: teardown durante el push suspendido → NO aplicar resultados (no purgar
                // outbox/espejo bajo una sesión que ya no existe).
                guard epoch == sessionEpoch else { return .coalesced }
                switch pushOutcome {
                case .completed(let results):
                    await pushClient.applyResults(results, rows: buildable, engine: engine, context: context)
                    guard epoch == sessionEpoch else { return .coalesced }  // teardown durante applyResults
                case .sessionExpired:
                    return .sessionExpired
                case .accountUnavailable:
                    return .accountUnavailable
                case .transient:
                    return .transient
                }
            }
        }

        // 4) Pull + apply (reconcilers gateados por el gate ya instalado). El batch se envuelve en
        //    markApplyBegan/Ended para que `isPersonalApplyQuiescent` refleje el apply en vuelo (consumido
        //    por el wrapper de arranque en `.cloud`; el gate de reconcilers usa la señal dedicada
        //    `isQuiescentForEngineSaves`, que NO ve esta ventana — SERIO-1). El drain interno de
        //    `pullAndApplyOnce` mantiene F-1.
        coordinator.markApplyBegan()
        let pullOutcome = await engine.pullAndApplyOnce(using: pullClient, context: context)
        coordinator.markApplyEnded()
        guard epoch == sessionEpoch else { return .coalesced }  // SERIO-2: teardown durante el pull

        let pagesApplied: Int
        switch pullOutcome {
        case .completed(let n): pagesApplied = n
        case .transient(let n): pagesApplied = n
        case .busy: pagesApplied = 0
        case .sessionExpired: return .sessionExpired
        case .accountUnavailable: return .accountUnavailable
        }

        // 5) Fan-out post-apply (§i.4): solo si llegó algo remoto.
        if pagesApplied > 0 { fanOutRemoteChangesApplied() }

        // 5.5) Prefs sync (I13): push del outbox de prefs + pull/merge, MISMA cadencia que el dominio
        //      (latencia ≈60s foreground — decisión v1, paridad con la latencia de dominio). Piggyback
        //      tras el push/pull de dominio. Aborta limpio si un teardown cambió la época.
        await syncPrefsOnce(epoch: epoch)
        guard epoch == sessionEpoch else { return .coalesced }

        // 6) Primer pull completado + contador de Merkle (solo avanza en ciclos `.completed`) + purga
        //    de history (DOBLE-DARK: syncRuntimeEnabled gatea todo el runtime Y historyPurgeEnabled
        //    gatea la purga — se togglea SOLO tras el veredicto del spike device S2, ver CloudSyncFlags).
        if case .completed = pullOutcome {
            if !coordinator.hasCompletedFirstPull { coordinator.markFirstPullCompleted() }
            completedPullsSinceMerkle += 1
            if SyncCadencePolicy.shouldRunMerkle(
                completedPullsSinceMerkle: completedPullsSinceMerkle,
                lastMerkleAt: lastMerkleAt, now: .now
            ) {
                await runMerkleVerification(context: context, now: .now)
                guard epoch == sessionEpoch else { return .coalesced }  // SERIO-2: teardown durante Merkle
            }
            if CloudSyncFlags.historyPurgeEnabled {
                _ = engine.purgeHistoryOnce(context: context)
            }
        }

        switch pullOutcome {
        case .completed: return .completed
        case .transient, .busy: return .transient
        case .sessionExpired, .accountUnavailable: return .transient  // ya retornados arriba; defensivo
        }
    }

    // MARK: - Merkle (verificación + remediación E-bis)

    /// Verifica integridad y, si `.diverged`, REMEDIA una sola vez por sesión (reset cursor + re-pull).
    /// Testeable directamente. `now` inyectado. Devuelve el veredicto para asserts.
    /// SERIO-2: un teardown durante el fetch del snapshot aborta ANTES de la remediación (que muta el
    /// cursor y aplica deltas).
    @discardableResult
    func runMerkleVerification(context: ModelContext, now: Date = .now) async -> MerkleVerdict {
        let epoch = sessionEpoch
        let verdict = await engine.verifyIntegrity(using: merkleClient, context: context)
        guard epoch == sessionEpoch else { return verdict }
        lastMerkleAt = now
        completedPullsSinceMerkle = 0
        if case .diverged = verdict, !didRemediateMerkleThisSession {
            didRemediateMerkleThisSession = true
            engine.resetServerSeqCursor(context: context)
            _ = await engine.pullAndApplyOnce(using: pullClient, context: context)
            CloudSyncBreadcrumb.merkleRemediated()
        }
        return verdict
    }

    // MARK: - Prefs sync (I13)

    /// UN ciclo de sync de preferencias: push del outbox (owner-scoped) → purga de las aplicadas; luego
    /// pull por cursor → merge vía `PreferenceSyncService` (semánticas NO-LWW client-side) → avance del
    /// cursor (persistido en el propio archivo del outbox, NO en `SyncCursor`). No-op si el paso está
    /// deshabilitado (deps nil) o no hay sesión. Cero silencios: los fallos de I/O del outbox se loguean.
    ///
    /// SERIO-2: re-verifica `sessionEpoch` tras cada `await` — un teardown durante un push/pull suspendido
    /// aborta SIN purgar el outbox ni avanzar el cursor (no se toca estado bajo una sesión que ya no existe).
    private func syncPrefsOnce(epoch: Int) async {
        // S1 (review I13): gate DURO por storageMode — espeja el de `set()`/`bootstrap()`. Sin él, un
        // device `.icloud` con syncRuntimeEnabled=true (ventana de SPIKES de device) pullearía prefs del
        // backend mientras las escrituras van a iKV = split-brain (y los markers de test de staging
        // pisarían prefs reales del user de spike). El sync de prefs solo existe en `.cloud`.
        guard CloudSyncFlags.storageMode == .cloud else { return }
        guard let prefsClient, let prefsOutbox, let userID = session.currentUserID else { return }

        // Push: subir las entries del owner actual (owner-scoping M1).
        let entries = prefsOutbox.entries(forUserID: userID)
        if !entries.isEmpty {
            let wire = entries.map { WirePref(key: $0.key, value: $0.entry.value, hlc: $0.entry.hlc) }
            let outcome = await prefsClient.push(wire)
            guard epoch == sessionEpoch else { return }
            if case .completed(let results) = outcome {
                // `applied`/`noop` (LWW resuelto server-side) → purgar del outbox. `reason` != nil (upstream
                // transitorio) NO llega como `applied`/`noop` → la entry queda y se reintenta.
                let done = results.filter { $0.reason == nil }.map(\.key)
                do { try prefsOutbox.removeEntries(keys: done) } catch {
                    #if DEBUG
                    print("CloudSyncRuntime.syncPrefsOnce: removeEntries falló: \(error)")
                    #endif
                }
            }
        }

        // Pull: bajar desde el cursor y mergear.
        let since = prefsOutbox.pullCursor
        let pullOutcome = await prefsClient.pull(since: since)
        guard epoch == sessionEpoch else { return }
        if case .page(let page) = pullOutcome {
            PreferenceSyncService.shared.applyPulledPrefs(page.prefs)
            if page.maxServerSeq > since {
                do { try prefsOutbox.setPullCursor(page.maxServerSeq) } catch {
                    #if DEBUG
                    print("CloudSyncRuntime.syncPrefsOnce: setPullCursor falló: \(error)")
                    #endif
                }
            }
        }
    }

    // MARK: - Helpers

    /// Filas de outbox VIVAS (dead-letters excluidos — nunca suben).
    private func liveOutboxRows(_ context: ModelContext) -> [SyncOutbox] {
        do {
            return try context.fetch(FetchDescriptor<SyncOutbox>())
                .filter { $0.rejectedReason == nil }
        } catch {
            #if DEBUG
            print("CloudSyncRuntime.liveOutboxRows: fetch falló: \(error)")
            #endif
            return []
        }
    }

    /// Dead-letterea las filas poison (#26): `rejectedReason` + `rejectedAt` bajo `outboxSaveAuthor`
    /// (echo-suppression) + canario `cloudSyncMutationRejected`. El espejo NO se borra (coherente con los
    /// dead-letters de I8e — la fila queda para el panel DEBUG).
    private func deadLetterPoison(_ poison: [SyncPushClient.PoisonRow], context: ModelContext) {
        do {
            try engine.saveWithAuthor(context, CloudSyncEngine.outboxSaveAuthor) {
                for p in poison {
                    p.row.rejectedReason = p.reason
                    p.row.rejectedAt = .now
                }
            }
        } catch {
            #if DEBUG
            print("CloudSyncRuntime.deadLetterPoison: save falló: \(error)")
            #endif
            return
        }
        for p in poison { TelemetryService.cloudSyncMutationRejected(reason: p.reason) }
    }

    /// Fan-out: closure inyectado + Notification (AppBootstrapper lo cablea a la UI en el paso DARK).
    private func fanOutRemoteChangesApplied() {
        onRemoteChangesApplied?()
        NotificationCenter.default.post(name: .cloudSyncAppliedRemoteChanges, object: nil)
    }

    // MARK: - Attest (seam I7b, AttestSyncGate)

    private enum AttestResolution { case ok, transient, terminal }

    /// Intenta adquirir el token de attest de la sesión; clasifica el fallo con `AttestSyncGate` (retry
    /// budget → terminal). Con el Noop provider retorna `nil` sin lanzar → `.ok` (DARK: attest opcional).
    private func resolveAttest() async -> AttestResolution {
        do {
            _ = try await session.attestToken()
            attestRetryCount = 0
            return .ok
        } catch let error as AppAttestError {
            switch AttestSyncGate.classify(error: error, retryCount: attestRetryCount) {
            case .transient:
                attestRetryCount += 1
                return .transient
            case .terminal:
                return .terminal
            }
        } catch {
            // Error no-attest en el seam (no debe ocurrir por contrato) → transient conservador.
            attestRetryCount += 1
            return .transient
        }
    }
}
