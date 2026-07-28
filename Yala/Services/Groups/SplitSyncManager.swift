//
//  SplitSyncManager.swift
//  Yala
//
//  Core sync service for shared group data via CKSyncEngine.
//  Two engines: private (zones I own) + shared (zones I was invited to).
//  Coexists with SwiftData auto-sync for private database.
//

import CloudKit
import Foundation
import os.log
import Observation
import SwiftData

@MainActor @Observable
final class SplitSyncManager {

    // MARK: - Singleton

    static let shared = SplitSyncManager()

    // MARK: - Observable State

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case error(String)
        case noAccount
    }

    private(set) var syncStatus: SyncStatus = .idle

    // MARK: - Engines

    private(set) var privateEngine: CKSyncEngine?
    private(set) var sharedEngine: CKSyncEngine?

    // nonisolated references for identity check from delegate. Updated whenever an engine is
    // created OR recreated (promotion to auto-sync). The delegate discards events from an engine
    // that is neither — a stale callback from a recreated engine must not persist state nor route.
    @ObservationIgnored nonisolated(unsafe) private var _privateEngineRef: CKSyncEngine?
    @ObservationIgnored nonisolated(unsafe) private var _sharedEngineRef: CKSyncEngine?

    // MARK: - Dependencies

    /// The shared `mainContext` (set via `setContext`). The group-sync delegate reads + saves here.
    /// Saving the half-imported personal graph mid-restore is prevented NOT by isolating the context
    /// (a dedicated `ModelContext(container)` made `#Predicate` keypaths fail to resolve → crashed
    /// record export in `buildRecord`) but by the QUIESCENCE gate: the engines stay export-only and
    /// `deferMainContextWork` defers every delegate save until the personal first import has settled
    /// AND gone quiet (`evaluateQuiescentPromotion`). After promotion the store is quiescent, so
    /// delegate saves are safe — same as the last-known-good mainContext builds (≤28).
    private var modelContext: ModelContext?
    private var container: CKContainer?
    private let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    // Delegate must be kept alive
    private var delegate: SplitSyncDelegate?

    // MARK: - Start Gate (crash-loop fix on iCloud restore)
    // The engines are deferred until the personal first import settles, so the group
    // `save()` never lands on a half-imported personal graph in the shared mainContext.
    // See `SplitSyncStartGate`.
    private var enginesStarted = false

    /// C-3: guard de re-entrada de `performAccountSwitchCleanup` — el evento de cuenta llega una vez por
    /// engine y la recreación puede re-emitirlo.
    private var identityCleanupInFlight = false
    /// `true` once the engines run with `automaticallySync = true` (personal import settled, or
    /// no iCloud, or hard cap). While `false` the engines are in "export-only" mode: they exist
    /// (so create/invite/enqueue work) but never fetch automatically, and the delegate defers
    /// every `modelContext.save()` so it can't persist the half-imported personal graph.
    private(set) var autoSyncActive = false
    private var firstImportObserver: NSObjectProtocol?
    private var gateWaitTask: Task<Void, Never>?
    private static let hardCapSeconds: TimeInterval = 300  // absolute last-resort cap
    private static let pollInterval: TimeInterval = 15
    /// Grace from gate start before promoting an EMPTY store (no `.import` ever observed). Long enough that a
    /// populated account's import would have STARTED by now (flipping `hasObservedImportActivity`), so an
    /// empty store promotes ~here while a restore-with-data keeps waiting for its real import to settle.
    /// Keep a multiple of `pollInterval`: promotion can only fire on a poll tick, so a non-multiple value
    /// silently rounds up to the next tick.
    private static let noImportGraceSeconds: TimeInterval = 60

    // MARK: - Manual sync (pull-to-refresh / foreground)
    /// Single-flight slot para `syncNow()`: llamadas concurrentes (pull-to-refresh + foreground +
    /// entrada al tab) esperan el mismo fetch en curso en vez de duplicar trabajo.
    private var syncNowTask: Task<Void, Never>?
    /// Último fetch explícito exitoso, para debounce de los disparadores automáticos (tab + foreground).
    /// El pull-to-refresh usa `force: true` y salta el debounce.
    private var lastSyncNowAt: Date?
    private static let syncNowDebounce: TimeInterval = 10
    /// Un pull EXPLÍCITO (`force`) no aborta si el sync aún no está listo (promoción pendiente o
    /// import personal no quiescente): espera hasta este tope, reevaluando cada `poll`. El spinner
    /// del `.refreshable` refleja la espera — antes el pull "moría al instante" sin hacer nada.
    private static let syncNowForceWaitTimeout: TimeInterval = 10
    private static let syncNowForceWaitPoll: TimeInterval = 0.5

    // Pending record IDs — internal tracking, not observed by views
    private var pendingRecordSaves: Set<CKRecord.ID> = []

    // MARK: - Deferred fetch buffers (export-only window)
    // CKSyncEngine advances (and persists) its change token once the delegate RETURNS from a fetch
    // event — a handler that early-returns via `deferMainContextWork` would lose those records
    // FOREVER (they're never re-delivered). No fetch should run while export-only (no auto-fetch,
    // syncNow gated), so these are defence-in-depth: buffer the event, re-apply on promotion.
    private var deferredFetchedRecordZoneEvents: [(event: CKSyncEngine.Event.FetchedRecordZoneChanges, engineName: String)] = []
    private var deferredFetchedDatabaseEvents: [(event: CKSyncEngine.Event.FetchedDatabaseChanges, engineName: String)] = []
    /// Zonas cuyo `didFetchRecordZoneChanges` llegó durante la ventana export-only:
    /// el cierre del baseline de primer import se drena DESPUÉS de los record events.
    private var deferredZoneFetchCompletions: [String] = []
    /// Sign-out/switch during the export-only window: run `clearAllLocalGroupData` after promotion
    /// (clearing supersedes any buffered fetched data — buffers are discarded).
    private var deferredClearAllRequested = false

    // Coalescing task for deferred bridge/notifications after remote changes
    private var deferredBridgeTask: Task<Void, Never>?
    private var pendingBridgeExpenseIDs: Set<UUID> = []
    /// Settlement IDs pending bridge. Tracked separately from `pendingBridgeChangeSet` so the bridge
    /// (which writes personal models) can be deferred by import quiescence WITHOUT re-sending the
    /// notifications, which are processed + cleared every pass.
    private var pendingBridgeSettlementIDs: Set<UUID> = []
    private var pendingBridgeChangeSet = RemoteChangeSet()

    // Cleanup observers: acumulan zoneIDs durante el batch de remote records,
    // procesados post-save junto al deferredBridgeTask.
    /// Zones donde el SplitGroup remoto flipped a `isHiddenForAll=true` → dispara `freezeForSoftDelete`.
    private var pendingFreezeZoneIDs: Set<String> = []
    /// Zones donde el current user pasó de `.active → .removed` vía admin remoto → dispara full cleanup.
    private var pendingRemovedSelfZoneNames: Set<String> = []

    // Records that failed due to quota exceeded — retried on foreground
    private var quotaFailedRecordIDs: Set<CKRecord.ID> = []

    // MARK: - Testigo PASIVO del ciclo de fetch (C-4)
    // El uploader de la migración a backend necesita saber si el FETCH DE GRUPOS está quieto ANTES de
    // congelar un grupo (paso 3), porque a partir del flip el guard simétrico de pull descarta todo lo
    // de esa zona. La señal se OBSERVA, jamás se fuerza: un `fetchChanges()` provocado fetchea la base
    // privada ENTERA y descartaría, con avance de token, lo de las zonas ya congeladas en esa misma
    // pasada. `@ObservationIgnored`: son contadores de alta frecuencia, no estado de UI.

    /// Ciclos de fetch EN VUELO por engine (`willFetchChanges` ++ / `didFetchChanges` --).
    @ObservationIgnored private var fetchCyclesInFlight: [String: Int] = [:]

    /// Engines que cerraron ≥1 ciclo de fetch ENTERO en esta sesión. Se CONSERVA al promover a auto-sync
    /// porque los eventos que aquellos ciclos dejaron bufferados SÍ se aplican en
    /// `drainDeferredFetchEvents()`; en el arranque export-only el set está vacío de todos modos (no hay
    /// auto-fetch), así que la conservación solo importa si alguna vez se fuerza un fetch antes de
    /// promover. SÍ se limpia en `resetLocalGroupsSyncState()`: ahí los change tokens se invalidan y
    /// «ya completó un ciclo» deja de decir nada sobre el corpus que viene.
    @ObservationIgnored private var enginesWithCompletedFetchCycle: Set<String> = []

    /// Zonas cuyo `didFetchRecordZoneChanges` llegó CON error y aún no han vuelto a cerrar limpio: su
    /// contenido no bajó. Se auto-sana (un ciclo limpio posterior de la misma zona la retira), así que
    /// un transitorio no deja el gate clavado. Testigo NEGATIVO a propósito: exigir presencia en un set
    /// de «zonas fetcheadas limpiamente» deadlockearía, porque una zona sin cambios no produce el evento.
    /// Se alimenta de AMBOS engines (el evento no trae `engineName`). Inofensivo para el gate: los
    /// candidatos son `isOwner` ⇒ sus zonas solo llegan por el engine privado.
    @ObservationIgnored private var zonesWithFailedFetchThisSession: Set<String> = []

    /// Un apply de records fetcheados NO llegó a persistir en esta sesión (save fallido o handler sin
    /// `modelContext`). El token YA avanzó ⇒ el ciclo «completo» no prueba que el store lo esté, y
    /// esperar no lo arregla: CloudKit no re-entrega.
    @ObservationIgnored private var fetchApplyFailedThisSession = false

    /// [C-4 PIEZA 2] Algún engine arrancó SIN estado persistido en esta sesión (o fue reconstruido con
    /// `state: nil`) ⇒ CloudKit está RE-ENTREGANDO EL CORPUS ENTERO, y el RESCATE de pull queda
    /// suspendido mientras dure la sesión.
    ///
    /// POR QUÉ, y por qué de SESIÓN. Sin token, toda fila que el backend BORRÓ después de migrar vuelve
    /// por CloudKit como «nunca vista» (localmente ya no está: el tombstone del pull la borró) → el
    /// rescate la adoptaría → el drain la empujaría → `apply_group_delta` la reinstauraría para TODO el
    /// grupo. Resurrección en masa. La avalancha llega repartida en muchos ciclos de fetch a lo largo de
    /// la sesión, así que suspender solo hasta el primer ciclo cerrado dejaría el rescate abierto justo
    /// cuando llega el grueso. NUNCA se apaga dentro de la sesión: el proceso siguiente ya arranca con
    /// token y el rescate vuelve solo.
    ///
    /// Contrapartida aceptada: en una instalación fresca (o tras un reset) no se rescata nada, así que
    /// un gasto de invitado rezagado que caiga en esa sesión se pierde. Es la dirección segura — ahí la
    /// verdad es el backend y la copia CloudKit es justo lo que G6-3 C2 manda descartar.
    @ObservationIgnored private var replayingFullCorpus = false

    /// [C-4 PIEZA 2] Un batch adoptó filas por rescate y hay que drenarlas al outbox del canal backend.
    /// Lo consume `processPendingRemoteChanges` (50 ms después, fuera del handler del engine).
    @ObservationIgnored private var pendingRescueDrain = false

    /// [C-4 PIEZA 2] Seam del estado del canal backend para el gate del rescate. El default de
    /// PRODUCCIÓN lee el canal real; los tests lo sustituyen. Un default inerte (constante `false`)
    /// dejaría los tests en verde con el rescate MUERTO en producción — por eso lo pinnea el
    /// source-scan de `GroupPullRescueWiringTests`.
    @ObservationIgnored
    var backendPullSignalProvider: (String, ModelContext) -> (completed: Bool, hasCursor: Bool) = {
        zoneName, context in
        GroupsSyncClient.shared.backendPullSignal(groupID: zoneName, context: context)
    }

    /// Instantánea PASIVA para el gate del uploader, acotada a las zonas que la pasada va a congelar.
    /// SOLO LEE: no dispara `fetchChanges()` ni evalúa la promoción (`evaluateQuiescentPromotion` puede
    /// llamar a `enableAutoSync()`, que lanza un `Task { fetchChanges() }` que NADIE awaitea → el batch
    /// llegaría DESPUÉS del flip). Las derivaciones viven en `GroupFetchQuiescenceGate.signal` para que
    /// tengan test propio; aquí solo se eligen los campos.
    func privateFetchGateSignal(candidateZoneNames: Set<String>) -> GroupFetchQuiescenceGate.Signal {
        GroupFetchQuiescenceGate.signal(
            accountAvailable: iCloudSyncService.shared.isAccountAvailable,
            privateEngineMounted: privateEngine != nil,
            autoSyncActive: autoSyncActive,
            privateCyclesInFlight: fetchCyclesInFlight["private"] ?? 0,
            privateCompletedCycle: enginesWithCompletedFetchCycle.contains("private"),
            deferredRecordZoneEventCount: deferredFetchedRecordZoneEvents.count,
            deferredDatabaseEventCount: deferredFetchedDatabaseEvents.count,
            deferredClearAllRequested: deferredClearAllRequested,
            applyFailedThisSession: fetchApplyFailedThisSession,
            candidateZoneNames: candidateZoneNames,
            zonesWithFailedFetch: zonesWithFailedFetchThisSession)
    }

    // MARK: - State Persistence

    // nonisolated-safe: file I/O only, no model access
    private nonisolated let stateDirectory: URL = {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to Documents (not /tmp/ which OS can purge)
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fallback = docs.appendingPathComponent("SplitSync", isDirectory: true)
            try? fm.createDirectory(at: fallback, withIntermediateDirectories: true)
            return fallback
        }
        let dir = appSupport.appendingPathComponent("SplitSync", isDirectory: true)
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            #if DEBUG
            print("SplitSyncManager: Failed to create state directory: \(error)")
            #endif
        }
        return dir
    }()

    // MARK: - Initialization

    private init() {}

    /// Call from AppBootstrapper after services with context are set up.
    ///
    /// Sets up the container + delegate, then either starts the engines now or defers
    /// their creation until the personal CloudKit first import settles. Deferring avoids
    /// a `save()` on the half-imported personal graph (shared mainContext) that crashes
    /// SwiftData with an internal `_assertionFailure` on an iCloud-restored device.
    /// Called once per cold launch (warm resume does not re-initialize).
    func initialize() {
        setupContainerAndDelegate()

        // Testigo de MONTAJE (qué modo montó ESTE proceso el store personal), NUNCA lo persistido:
        // en el kill-window del cutover §g.4 la key persistida ya dice `.cloud` pero el mirror personal
        // SIGUE montado hasta el relaunch armado (el par `.cloud && mirrorOffArmed`) → promover directo
        // ahí sería la clase del crash de restore (un `save()` del delegate sobre un grafo personal a
        // medio hidratar). En ese window el testigo queda `.icloud` → gate normal (defer). Mismo árbitro
        // que `MigrationWorkExecutor.isMirrorConfirmedOff()`.
        let mirrorConfirmedOff = SwiftDataConfiguration.personalStoreMountedMode == .cloud

        let decision = SplitSyncStartGate.decideStart(
            isAccountAvailable: iCloudSyncService.shared.isAccountAvailable,
            hasCompletedFirstImport: iCloudSyncService.shared.hasCompletedFirstImport,
            personalMirrorConfirmedOff: mirrorConfirmedOff
        )
        // Diagnóstico INTENCIONALMENTE fuera de `#if DEBUG`: este crash solo reproduce en
        // CloudKit Production (device restaurado de iCloud), verificable solo vía TestFlight
        // Release en Console.app. Sin PII — solo bools de estado, counts y "private"/"shared".
        // Eventos puntuales (1× por cold launch), no hot path.
        logger.notice("SplitSync gate: decision=\(String(describing: decision), privacy: .public) account=\(iCloudSyncService.shared.isAccountAvailable, privacy: .public) firstImport=\(iCloudSyncService.shared.hasCompletedFirstImport, privacy: .public) mirrorConfirmedOff=\(mirrorConfirmedOff, privacy: .public)")

        switch decision {
        case .startNow:
            // En `.cloud` (mirror confirmado OFF) los engines arrancan directo sin pasar NUNCA por el
            // modo export-only, así que `enableAutoSync()` — y con él el canario
            // `cloudkitGroupSyncPromotedToAuto detail=importSettled=false` — jamás corre. Emitimos el
            // canario AQUÍ con un `detail` DISTINTO (`cloudModeDirect`) para conservar la señal "grupos
            // promovió a auto" SIN contaminar el barrido del gate D9, que agrupa por `importSettled=<bool>`:
            // estos devices producían ~14 promociones espurias `importSettled=false` vía el poll de
            // quiescencia (esperando un import personal de iCloud que en `.cloud` NO existe). Solo cuando
            // el mirror está OFF — el `.startNow` normal (offline / import asentado, `.icloud`) nunca
            // emitió este canario y no debe empezar a hacerlo.
            if mirrorConfirmedOff {
                MetricsService.canary(.cloudkitGroupSyncPromotedToAuto, detail: "cloudModeDirect")
            }
            startEngines(autoSync: true)
        case .deferUntilImport:
            // Create the engines in export-only mode (so create/invite/enqueue work) and observe
            // the personal import to promote them to auto-sync once the graph is safe to save on.
            startEngines(autoSync: false)
            observeFirstImportThenStart()
        }

        // Boot-guard GAP 1: el Apple ID del OS pudo cambiar con la app CERRADA — la
        // limpieza reactiva (.accountChange del engine) no está garantizada en ese
        // camino. Async post-arranque: `initialize()` es síncrona, el Task corre
        // después SIEMPRE; correr con engines vivos tiene el mismo precedente que el
        // `.switchAccounts` reactivo (además CKSyncEngine entregará su propio evento
        // si también lo detecta — camino idempotente). No corre en secundaria/uitest
        // (initialize() no corre ahí — AppBootstrapper gatea, y es lo correcto:
        // en secundaria el engine jamás toca datos de Grupos).
        Task { @MainActor in await self.runIdentityBootGuard() }
    }

    /// GAP 1 (gap-estados.md): compara la identidad de Grupos PERSISTIDA contra la
    /// cuenta iCloud actual y, en mismatch, corre la limpieza de account-switch.
    /// Un fetch fallido (red / sin cuenta) JAMÁS limpia — reintento en el próximo boot.
    private func runIdentityBootGuard() async {
        // M1 / D8 (G5-C): bajo el canal grupos→backend, la identidad de Grupos es el `sub` de la sesión,
        // NO el recordName del Apple ID del OS — este boot-guard CloudKit-era se RETIRA. Con flag OFF
        // (TODO device prod hoy) es byte-idéntico. `GroupsIdentityBootGuardLogic`/`performAccountSwitch
        // Cleanup` NO se borran (retiro real post-G6).
        // ⚠️ CONDICIÓN DE ENCENDIDO (H2 del review G5-C): encender el flag ANTES de G6 (p.ej. QA) con
        // grupos CloudKit legacy VIVOS pierde este belt — un cambio de Apple ID del OS dejaría solo la
        // limpieza reactiva `.accountChange` del engine (no garantizada) y las zonas del ID viejo
        // podrían re-encolarse a la private DB del nuevo (la partición de G5-A NO cubre legacy). El
        // encendido único D9 (post-G6) lo hace seguro — anotado en el gate de flags §12.
        guard !CloudSyncFlags.groupsBackendEnabled else { return }
        guard let cached = GroupUserIdentityService.shared.cachedRecordName, !cached.isEmpty else {
            return  // Primera instalación / cache limpio: nada que comparar.
        }
        let fresh: String?
        do {
            fresh = try await GroupUserIdentityService.shared.fetchFreshRecordName()
        } catch {
            logger.notice("SplitSync identityBootGuard: fetch failed — skip (no evidence): \(error.localizedDescription, privacy: .public)")
            return
        }
        guard GroupsIdentityBootGuardLogic.decide(cached: cached, fresh: fresh) == .runSwitchCleanup else {
            return
        }
        // Sin PII: JAMÁS loguear los recordNames.
        logger.notice("SplitSync identityBootGuard: MISMATCH — running account-switch cleanup")
        MetricsService.canary(.groupsIdentityBootMismatch)
        performAccountSwitchCleanup()
    }

    /// Cheap, no-network setup: CKContainer, one-time state migration, delegate.
    /// Kept separate from engine creation so `container`/`delegate` exist while the
    /// engines are deferred (e.g. `acceptShare` needs `container`).
    private func setupContainerAndDelegate() {
        let containerID = CKConstants.containerID
        self.container = CKContainer(identifier: containerID)

        // One-time: clear stale state from old container after migration
        let migrationKey = "SplitSync_ContainerMigrated_v1"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            clearState(name: "private")
            clearState(name: "shared")
            UserDefaults.standard.set(true, forKey: migrationKey)
            #if DEBUG
            logger.info("Cleared old sync state for container migration")
            #endif
        }

        delegate = SplitSyncDelegate(manager: self)
    }

    /// Builds one CKSyncEngine from a loaded state serialization. Shared by `startEngines` (initial,
    /// either mode) and `enableAutoSync` (recreate in auto mode) so engine config lives in one place.
    private func makeEngine(database: CKDatabase, state: CKSyncEngine.State.Serialization?, autoSync: Bool, delegate: SplitSyncDelegate) -> CKSyncEngine {
        var config = CKSyncEngine.Configuration(database: database, stateSerialization: state, delegate: delegate)
        config.automaticallySync = autoSync
        return CKSyncEngine(config)
    }

    /// Creates both CKSyncEngines. Idempotent — single-flight via `enginesStarted`.
    ///
    /// `autoSync = true` → normal mode (the engine fetches/sends automatically; safe when the
    /// personal import has settled or there's no iCloud). `autoSync = false` → "export-only" mode:
    /// the engines exist (so create/invite/enqueue work) but never fetch on their own, and the
    /// delegate defers every `save()`. `enableAutoSync()` later recreates them with `autoSync = true`.
    private func startEngines(autoSync: Bool) {
        guard !enginesStarted else { return }
        guard let container, let delegate else { return }
        enginesStarted = true
        autoSyncActive = autoSync
        // Only cancel the gate when starting in auto mode. In export-only mode the gate
        // (observer + poll) must stay alive to drive `enableAutoSync()` once the import settles.
        if autoSync { cancelGate() }

        let privateState = loadState(name: "private")
        privateEngine = makeEngine(database: container.privateCloudDatabase, state: privateState, autoSync: autoSync, delegate: delegate)
        _privateEngineRef = privateEngine

        let sharedState = loadState(name: "shared")
        sharedEngine = makeEngine(database: container.sharedCloudDatabase, state: sharedState, autoSync: autoSync, delegate: delegate)
        _sharedEngineRef = sharedEngine

        // C-4 (PIEZA 2): sin estado persistido, CloudKit re-entrega el corpus ENTERO en esta sesión ⇒
        // el rescate de pull se suspende (si no, toda fila borrada en el backend post-migración volvería
        // como «nunca vista» y se reinstauraría para todo el grupo). Basta con que UNO de los dos venga
        // fresco: la re-entrega de esa base ya trae la avalancha.
        if privateState == nil || sharedState == nil { replayingFullCorpus = true }

        // Export-only window: surface `.syncing` so the indicator doesn't read as "up to date"
        // while the engines are still waiting to fetch.
        syncStatus = autoSync ? .idle : .syncing

        logger.notice("SplitSync engines created — autoSync=\(autoSync, privacy: .public), firstImport=\(iCloudSyncService.shared.hasCompletedFirstImport, privacy: .public), private=\(privateState != nil ? "resumed" : "fresh", privacy: .public), shared=\(sharedState != nil ? "resumed" : "fresh", privacy: .public)")

        // Recover owned groups whose zone never reached CloudKit (created while a previous launch's
        // engines were deferred → createZone no-op'd). Idempotent; gated by the heuristic.
        recoverOwnedGroupZonesIfNeeded()

        // Recover individual records that never round-tripped (nil system fields) — e.g. dropped by
        // CKSyncEngine after a definitive server rejection. Idempotent; complements zone recovery.
        recoverUnsyncedRecordsIfNeeded()
    }

    /// Promotes the engines from export-only to auto-sync once the personal import has settled
    /// (or the hard cap fired). Recreates both engines with `automaticallySync = true` from the
    /// persisted state (which already holds anything enqueued during the export-only window), so
    /// the proven automatic mode — push, coalescing, retry — resumes. Idempotent.
    private func enableAutoSync() {
        guard !autoSyncActive else { return }
        guard let container, let delegate else { return }

        let importSettled = iCloudSyncService.shared.hasCompletedFirstImport
        autoSyncActive = true
        cancelGate()

        // Capture the OLD engines' in-memory pending changes BEFORE rebuilding. `state.add(...)`
        // persists to disk asynchronously (via the `.stateUpdate` delegate callback), so an enqueue
        // made moments ago during the export-only window (zone recovery, or a user create/invite)
        // may not be in `loadState(...)` yet. Transferring them directly makes the promotion
        // independent of that flush — nothing enqueued is lost on the fast path.
        let oldPrivateRecordChanges = privateEngine?.state.pendingRecordZoneChanges ?? []
        let oldPrivateDBChanges = privateEngine?.state.pendingDatabaseChanges ?? []
        let oldSharedRecordChanges = sharedEngine?.state.pendingRecordZoneChanges ?? []
        let oldSharedDBChanges = sharedEngine?.state.pendingDatabaseChanges ?? []

        // Recreate both engines in auto mode. The persisted stateSerialization carries the change
        // tokens (same mechanism as resume between cold launches).
        let newPrivate = makeEngine(database: container.privateCloudDatabase, state: loadState(name: "private"), autoSync: true, delegate: delegate)
        let newShared = makeEngine(database: container.sharedCloudDatabase, state: loadState(name: "shared"), autoSync: true, delegate: delegate)

        // Assign engines + identity refs together to minimise the window where an old-engine
        // callback could be misrouted. Refs first so events from the new engines route correctly.
        _privateEngineRef = newPrivate
        _sharedEngineRef = newShared
        privateEngine = newPrivate
        sharedEngine = newShared
        // C-4: la promoción SUSTITUYE ambos engines y el delegate descarta los eventos de los viejos
        // (`isCurrentEngine`), así que un `didFetchChanges` en vuelo del viejo NUNCA llegaría a
        // decrementar: sin este reset el contador quedaría clavado > 0 y el gate diferiría para siempre.
        // Solo el contador en vuelo — `enginesWithCompletedFetchCycle` se CONSERVA a propósito: los
        // eventos que aquellos ciclos bufferaron se aplican en `drainDeferredFetchEvents()` unas líneas
        // más abajo, así que el testigo sigue siendo cierto.
        fetchCyclesInFlight.removeAll()

        // Re-enqueue the captured pending changes onto the new engines (idempotent — duplicates of
        // changes already in the loaded state are coalesced). Now safe to send (auto-sync on).
        if !oldPrivateDBChanges.isEmpty { newPrivate.state.add(pendingDatabaseChanges: oldPrivateDBChanges) }
        if !oldPrivateRecordChanges.isEmpty { newPrivate.state.add(pendingRecordZoneChanges: oldPrivateRecordChanges) }
        if !oldSharedDBChanges.isEmpty { newShared.state.add(pendingDatabaseChanges: oldSharedDBChanges) }
        if !oldSharedRecordChanges.isEmpty { newShared.state.add(pendingRecordZoneChanges: oldSharedRecordChanges) }
        syncStatus = .idle

        logger.notice("SplitSync promoted to auto-sync — importSettled=\(importSettled, privacy: .public)")
        MetricsService.canary(.cloudkitGroupSyncPromotedToAuto, detail: "importSettled=\(importSettled)")

        // Re-apply any fetch events that were buffered during the export-only window BEFORE the
        // post-promotion fetch (older events first — preserves CloudKit event order). The store is
        // quiescent here (promotion required it), so the handlers' saves are safe now.
        drainDeferredFetchEvents()

        // Kick an immediate fetch on both new engines so newly-joined / remote changes appear promptly:
        // `cancelGate()` removed the poll backstop, and `acceptShare`'s immediate fetch was gated off during
        // the export-only window. Non-fatal: auto-sync retries on failure (a participant fetches via shared,
        // an owner via private; fetching both covers it).
        //
        // ONLY when the personal store is quiescent: a normal (settled+quiet) or empty-store promotion is safe
        // to fetch+save now. But a HARD-CAP force-promotion (the absolute last resort) can fire while the
        // personal import is still ACTIVE; forcing an immediate fetch there would run a fetch-handler `save()`
        // over the half-imported graph — the saga crash. In that rare case skip the explicit fetch and let
        // auto-sync schedule it once the import settles (it gives the natural grace window). `isImportQuiescent`
        // is false there (import in flight) and true for both safe paths, so it's the right discriminator.
        if iCloudSyncService.shared.isImportQuiescent {
            let promotedShared = newShared
            let promotedPrivate = newPrivate
            Task { @MainActor [weak self] in
                do { try await promotedShared.fetchChanges() }
                catch { self?.logger.error("post-promote shared fetch failed (auto-sync will retry): \(error.localizedDescription, privacy: .public)") }
                do { try await promotedPrivate.fetchChanges() }
                catch { self?.logger.error("post-promote private fetch failed (auto-sync will retry): \(error.localizedDescription, privacy: .public)") }
            }
        }
    }

    // MARK: - Owned Zone Recovery

    /// Re-enqueues the zone + records of owned groups whose GroupMeta never reached CloudKit
    /// (created while a previous launch's engines were deferred → `createZone` no-op'd, leaving the
    /// group un-invitable — e.g. the owner's "Jurpi"). **Read-only on the mainContext** (fetch +
    /// `engine.state.add`); never saves, so it's safe during the export-only window. Idempotent —
    /// `.saveZone`/`.saveRecord` are ignored by CloudKit's change tag if already present. Gated by
    /// `needsZoneRecovery` (owner + no system fields) so synced groups are skipped (no sync storm).
    private func recoverOwnedGroupZonesIfNeeded() {
        guard let modelContext, privateEngine != nil else { return }
        // Fetch owned groups; the recovery heuristic (no uploaded GroupMeta) lives in the tested
        // pure-logic `needsZoneRecovery`, applied as the in-memory filter (single source of truth).
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.isOwner == true }
        )
        let toRecover: [SplitGroup]
        do {
            toRecover = try modelContext.fetch(descriptor).filter {
                // C2: un grupo backend sin zona CloudKit es LEGÍTIMO (nace vía RPC), no "grupo roto" — sin
                // este guard el recovery re-encolaría su zona + records a CKSyncEngine (createZone directo).
                // C-3: se amplía al grupo CONGELADO porque este recovery llama `createZone` DIRECTO (no pasa
                // por el guard de `enqueueSave`) y, con la fila retenida tras un cambio de Apple ID,
                // RE-CREARÍA la zona en el iCloud del ID NUEVO. Cambia UN caso, a propósito: un owner con
                // `movedToBackendAt != nil`, `!isBackendGroup` y SIN `ckSystemFieldsData` cumple a la vez el
                // freeze y `needsZoneRecovery` — hoy se le re-crea la zona; con el guard se salta, que es lo
                // correcto porque su verdad ya vive en el backend. La mitigación #9 no lo cubre (exige
                // `ckSystemFieldsData != nil`).
                guard !($0.isBackendGroup || $0.isMigratedFrozen) else {
                    GroupsSyncBreadcrumb.groupsCkEnqueueSkippedBackendGroup(site: "zoneRecovery")
                    return false
                }
                return SplitSyncStartGate.needsZoneRecovery(isOwner: $0.isOwner, hasSystemFields: $0.ckSystemFieldsData != nil)
            }
        } catch {
            logger.error("SplitSync zone recovery fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard !toRecover.isEmpty else { return }

        let zoneManager = SplitZoneManager(syncManager: self)
        for group in toRecover {
            zoneManager.createZone(for: group)  // re-enqueue zone + GroupMeta (no mainContext save)
            reEnqueueOwnedGroupRecords(group: group, context: modelContext)
        }

        logger.notice("SplitSync recovered \(toRecover.count, privacy: .public) owned group zone(s) with no uploaded GroupMeta")
        MetricsService.canary(.cloudkitGroupZoneRecovered, value: Double(toRecover.count))
    }

    /// Re-enqueues a group's member/expense/share/settlement records to the private engine WITHOUT
    /// touching the mainContext (fetch + `engine.state.add` via `enqueueSave`). Used by zone
    /// recovery so the recovered group syncs complete (incl. the admin member) once changes flush.
    private func reEnqueueOwnedGroupRecords(group: SplitGroup, context: ModelContext) {
        let zoneName = group.cloudKitZoneID
        do {
            for m in try context.fetch(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                enqueueSave(modelID: m.id, group: group)
            }
            for e in try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                enqueueSave(modelID: e.id, group: group)
            }
            for s in try context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                enqueueSave(modelID: s.id, group: group)
            }
            for st in try context.fetch(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName })) {
                enqueueSave(modelID: st.id, group: group)
            }
        } catch {
            logger.error("SplitSync re-enqueue records failed for \(zoneName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Unsynced Record Recovery

    /// Re-enqueues group records (member/expense/share/settlement) that never round-tripped to
    /// CloudKit (`ckSystemFieldsData == nil` — see `SplitSyncStartGate.needsRecordRecovery`).
    /// CKSyncEngine DROPS a record from its pending queue after a definitive server rejection
    /// (e.g. the un-deployed `isOpeningBalance` schema field, 27-jun→1-jul, killed every
    /// SplitExpense save for 4 days); without this, those records stay local-only forever unless
    /// the user re-edits each one by hand. **Read-only on the mainContext** (fetch +
    /// `engine.state.add`); never saves, so it's safe during the export-only window — enqueued
    /// changes persist in the engine state and send after promotion.
    ///
    /// Conscious behaviors: (a) a permanently-invalid record re-enqueues ONCE per launch and fails
    /// visibly (log + telemetry canary — bounded, not a hot loop); (b) if the zone is gone
    /// server-side, the resulting `zoneNotFound` runs the standard local-cache cleanup (dead
    /// group); (c) orphaned deletions are not recoverable (the local model no longer exists).
    private func recoverUnsyncedRecordsIfNeeded() {
        // BOTH engines required: groups route to private (owner) or shared (invitee), and
        // markPendingChange silently no-ops on a nil engine — an || here would half-run the
        // recovery and report recovered counts for records that never got enqueued.
        guard let modelContext, privateEngine != nil, sharedEngine != nil else { return }

        let groups: [SplitGroup]
        do {
            groups = try modelContext.fetch(FetchDescriptor<SplitGroup>())
        } catch {
            logger.error("SplitSync record recovery group fetch failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        var recovered = 0
        for group in groups {
            // C2: los records de un grupo backend SIEMPRE tienen `ckSystemFieldsData == nil` (jamás hicieron
            // round-trip CloudKit — viven en el backend) → sin este skip, `needsRecordRecovery` los re-encolaría
            // TODOS a CKSyncEngine al boot. Excluir el grupo entero (más barato que filtrar cada record).
            // C-3: se amplía al grupo CONGELADO (primitiva `GroupFreezeLogic`, NO `movedToBackendAt != nil`
            // a secas): sus writes a CloudKit se perderían igual porque la verdad se mudó al backend, y con
            // la fila retenida tras un cambio de Apple ID irían a la private DB del ID NUEVO. Usar la
            // primitiva de freeze PRESERVA la mitigación #9 (owner tras reinstall), cuyos records local-only
            // siguen teniendo aquí su último camino de subida — con el predicado crudo lo perderían.
            if group.isBackendGroup || group.isMigratedFrozen {
                GroupsSyncBreadcrumb.groupsCkEnqueueSkippedBackendGroup(site: "recordRecovery")
                continue
            }
            // Soft-deleted for everyone → its zone is on the way out; don't resurrect records.
            if group.isHiddenForAll { continue }
            // Owner groups with no uploaded GroupMeta are FULLY re-enqueued (zone + all records)
            // by recoverOwnedGroupZonesIfNeeded — skip to avoid double-enqueueing (harmless but noisy).
            if SplitSyncStartGate.needsZoneRecovery(isOwner: group.isOwner, hasSystemFields: group.ckSystemFieldsData != nil) { continue }

            let zoneName = group.cloudKitZoneID
            do {
                for m in try modelContext.fetch(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName }))
                where SplitSyncStartGate.needsRecordRecovery(hasSystemFields: m.ckSystemFieldsData != nil) {
                    enqueueSave(modelID: m.id, group: group)
                    recovered += 1
                }
                for e in try modelContext.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName }))
                where SplitSyncStartGate.needsRecordRecovery(hasSystemFields: e.ckSystemFieldsData != nil) {
                    enqueueSave(modelID: e.id, group: group)
                    recovered += 1
                }
                for s in try modelContext.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneName }))
                where SplitSyncStartGate.needsRecordRecovery(hasSystemFields: s.ckSystemFieldsData != nil) {
                    enqueueSave(modelID: s.id, group: group)
                    recovered += 1
                }
                for st in try modelContext.fetch(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName }))
                where SplitSyncStartGate.needsRecordRecovery(hasSystemFields: st.ckSystemFieldsData != nil) {
                    enqueueSave(modelID: st.id, group: group)
                    recovered += 1
                }
            } catch {
                logger.error("SplitSync record recovery fetch failed for \(zoneName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        guard recovered > 0 else { return }
        logger.notice("SplitSync recovered \(recovered, privacy: .public) unsynced record(s) with no system fields")
        MetricsService.canary(.cloudkitGroupRecordsRecovered, value: Double(recovered))
    }

    /// Waits for the personal first import to settle, then PROMOTES the export-only engines to
    /// auto-sync (`enableAutoSync()`). The engines already exist (created in export-only mode by
    /// `startEngines(autoSync: false)`); this only flips them to automatic once the graph is safe.
    /// Fast path: the `.iCloudFirstImportCompleted` observer. Safety nets: a periodic poll that promotes an
    /// EMPTY store once the no-import grace passes (no import ever appeared + quiet), and the absolute hard
    /// cap (so group sync never stays export-only forever).
    private func observeFirstImportThenStart() {
        // Defensive: the import may have already settled+quieted between decideStart and here. (The no-import
        // grace has NOT elapsed at t=0, so an empty store is NOT promoted here — it promotes via the poll.)
        if evaluateQuiescentPromotion(noImportGraceElapsed: false, reachedHardCap: false) { return }

        logger.notice("SplitSync export-only — awaiting personal import QUIESCENCE before enabling auto-sync")

        // Fast re-eval when the first import completes — but promotion still needs the quiet window,
        // so this usually just hands off to the poll (which fires once the store goes quiescent).
        firstImportObserver = NotificationCenter.default.addObserver(
            forName: .iCloudFirstImportCompleted, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in _ = self.evaluateQuiescentPromotion(noImportGraceElapsed: false, reachedHardCap: false) }
        }

        gateWaitTask = Task { @MainActor [weak self] in
            var elapsed: TimeInterval = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pollInterval))
                guard !Task.isCancelled, let self, !self.autoSyncActive else { return }
                elapsed += Self.pollInterval
                if self.evaluateQuiescentPromotion(
                    noImportGraceElapsed: elapsed >= Self.noImportGraceSeconds,
                    reachedHardCap: elapsed >= Self.hardCapSeconds
                ) { return }
            }
        }
    }

    /// Promote the engines to auto-sync IFF the personal import has settled AND gone quiet, OR — for an EMPTY
    /// personal store — the no-import grace passed with NO import activity ever observed (and quiet), or the
    /// absolute hard cap fired. Shared by the `.iCloudFirstImportCompleted` observer and the poll.
    /// Returns `true` once promoted (or already promoted) so the poll loop can exit.
    @discardableResult
    private func evaluateQuiescentPromotion(noImportGraceElapsed: Bool, reachedHardCap: Bool) -> Bool {
        guard !autoSyncActive else { return true }
        let firstImport = iCloudSyncService.shared.hasCompletedFirstImport
        let observedImport = iCloudSyncService.shared.hasObservedImportActivity
        let isQuiescent = iCloudSyncService.shared.isImportQuiescent
        let resolution = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: firstImport,
            hasObservedImportActivity: observedImport,
            isQuiescent: isQuiescent,
            noImportGraceElapsed: noImportGraceElapsed,
            reachedHardCap: reachedHardCap
        )
        guard resolution == .start else { return false }
        if SplitSyncStartGate.promotedWhileNotQuiescent(hasCompletedFirstImport: firstImport, isQuiescent: isQuiescent) {
            if isQuiescent && !observedImport {
                // Empty store: the grace passed and NO personal `.import` ever appeared (a populated account
                // would have fired one as the import started) and the store is quiet → safe to promote. This
                // unblocks a user with no personal data (e.g. groups-only) whose empty store never sets
                // `hasCompletedFirstImport`. No half-imported personal graph exists → the delegate save is safe.
                logger.notice("SplitSync promoting (no personal import appeared within grace — empty store)")
                MetricsService.canary(.cloudkitGroupSyncNoImportPromote)
            } else {
                // Absolute hard cap reached while NOT settled+quiet — last-resort force so group sync never
                // hangs export-only on a stuck `.syncing` import.
                logger.warning("SplitSync gate HARD CAP \(Int(Self.hardCapSeconds))s — promoting to auto-sync while NOT quiescent (firstImport=\(firstImport, privacy: .public), isSyncing=\(iCloudSyncService.shared.status.isSyncing, privacy: .public))")
                MetricsService.canary(.cloudkitGroupSyncGateHardCap, detail: "isSyncing=\(iCloudSyncService.shared.status.isSyncing)")
            }
        }
        enableAutoSync()
        return true
    }

    /// Removes the gate observer + cancels the poll task. Called by whichever start path wins.
    private func cancelGate() {
        if let firstImportObserver {
            NotificationCenter.default.removeObserver(firstImportObserver)
            self.firstImportObserver = nil
        }
        gateWaitTask?.cancel()
        gateWaitTask = nil
    }

    func setContext(_ ctx: ModelContext) {
        // The delegate uses the shared mainContext directly. The user-visible save paths
        // (`handleFetchedDatabaseChanges`, `clearAllLocalGroupData`, `processPendingRemoteChanges`)
        // signal a UI refresh via `markRemoteChangePending()`; the internal-only saves (system
        // fields, conflict, zone recovery) don't need one — matching the last-known-good builds (≤28).
        modelContext = ctx
    }

    // MARK: - Engine Identity

    // nonisolated: Called from CKSyncEngine delegate (off MainActor)
    nonisolated func isPrivateEngine(_ engine: CKSyncEngine) -> Bool {
        engine === _privateEngineRef
    }

    /// `true` if `engine` is one of the live engines. After `enableAutoSync()` recreates the
    /// engines, a stale callback from a discarded engine must be ignored — otherwise its
    /// `.stateUpdate` would be saved under the wrong file name (corrupting the other engine's
    /// state) and its events would route incorrectly.
    nonisolated func isCurrentEngine(_ engine: CKSyncEngine) -> Bool {
        engine === _privateEngineRef || engine === _sharedEngineRef
    }

    nonisolated func engineName(for engine: CKSyncEngine) -> String {
        isPrivateEngine(engine) ? "private" : "shared"
    }

    // MARK: - State Persistence

    // nonisolated: Called synchronously from CKSyncEngine delegate (not on MainActor)
    nonisolated func saveState(_ serialization: CKSyncEngine.State.Serialization, name: String) {
        let fm = FileManager.default
        let dir = stateDirectory
        // Defensive: re-create directory if purged by OS (disk pressure cleanup)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        let url = dir.appendingPathComponent("\(name).json")
        do {
            let data = try JSONEncoder().encode(serialization)
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            logger.error("Failed to save sync state '\(name)': \(error)")
            #endif
        }
    }

    nonisolated func loadState(name: String) -> CKSyncEngine.State.Serialization? {
        let url = stateDirectory.appendingPathComponent("\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            #if DEBUG
            logger.info("No saved sync state for '\(name)' — starting fresh")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
        } catch {
            #if DEBUG
            logger.error("Failed to load sync state '\(name)': \(error)")
            #endif
            return nil
        }
    }

    private nonisolated func clearState(name: String) {
        let url = stateDirectory.appendingPathComponent("\(name).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            #if DEBUG
            print("SplitSyncManager: clearState('\(name)') failed: \(error)")
            #endif
        }
    }

    // MARK: - Share Acceptance

    /// Accept a CKShare invitation (called from AppDelegate).
    /// - Parameter skipNavigation: When true, accepts share but does NOT navigate (used for invite onboarding).
    func acceptShare(metadata: CKShare.Metadata, skipNavigation: Bool = false) async {
        let zoneID = metadata.share.recordID.zoneID
        guard let container else {
            #if DEBUG
            logger.error("Cannot accept share: container not initialized")
            #endif
            GroupJoinIntentTracker.shared.noteAcceptFailed(zoneName: zoneID.zoneName, recoverable: false)
            // Solo la sesión secundaria ALERTA: es un estado permanente sin retry (el
            // engine jamás arranca ahí). Container nil fuera de secundaria es una
            // ventana transitoria (cold launch pre-initialize) cubierta por el retry de
            // PendingInviteStore — alertar sería un error espurio (ver la logic).
            if GroupAcceptShareErrorLogic.classify(
                containerAvailable: false,
                isSecondarySession: SecondarySessionStore.isActive(),
                ckErrorCode: nil
            ) == .secondarySession {
                RouterEntryGate.shared.submit(.showGroupSyncError(
                    String(localized: "groups.sync.errorAcceptShareSecondary")
                ))
            }
            return
        }

        GroupJoinIntentTracker.shared.noteAcceptStarted(zoneName: zoneID.zoneName)

        do {
            _ = try await container.accept(metadata)
            #if DEBUG
            logger.info("Share accepted — shared engine will fetch zone data automatically")
            #endif

            // Join intent PERSISTENTE: "acepté la zona X; mi member debe nacer".
            // El member ya no es un one-shot gateado por `if let group` (bug
            // 2026-07-11: si la zona no había bajado, se saltaba EN SILENCIO y
            // nadie lo reintentaba) — GroupJoinReconciler lo reconcilia aquí y
            // en remoteInsert/boot/foreground hasta lograrlo (TTL 7d).
            PendingJoinStore.save(PendingJoinEntry(
                zoneName: zoneID.zoneName,
                zoneOwnerName: zoneID.ownerName
            ))
            MetricsService.canary(.groupJoinIntentPersisted)
            GroupJoinIntentTracker.shared.noteAcceptSucceeded(zoneName: zoneID.zoneName)

            // Force immediate fetch so the group appears quickly — but only once auto-sync is on.
            // During the export-only window a fetch would run the fetch handler (a save on the
            // half-imported personal graph). The shared engine recreated by enableAutoSync()
            // auto-fetches the joined zone, so the group still appears, just slightly later.
            if autoSyncActive, let sharedEngine {
                do {
                    try await sharedEngine.fetchChanges()
                } catch {
                    logger.error("acceptShare: immediate fetch failed (engine will retry on auto-sync): \(error.localizedDescription, privacy: .public)")
                }
            }

            // Ensure the current iCloud user has a member record in the joined
            // group. Si la zona aún no materializó, el reconciliador loguea el
            // motivo (waitForGroup) y reintenta en los triggers posteriores.
            await GroupJoinReconciler.reconcile(trigger: .acceptShare, context: modelContext)

            // Recompute local isCurrentUser flags (device-specific; not synced).
            await GroupService.shared.refreshCurrentUserFlags(context: modelContext)

            // Navigate to Groups tab (unless routing is handled by invite/reconnect flow)
            if !skipNavigation {
                await MainActor.run { RouterEntryGate.shared.submit(.navigate(.groups)) }
            }
        } catch {
            logger.error("Share acceptance failed: \(error.localizedDescription, privacy: .public)")
            GroupJoinIntentTracker.shared.noteAcceptFailed(
                zoneName: zoneID.zoneName,
                recoverable: AppBootstrapper.isRecoverableInviteFetchError(error)
            )
            // `.notAuthenticated` = sin sesión de iCloud en el device: copy específico
            // "necesitas iCloud" en vez del genérico de sync (endurecimiento Grupos-v1).
            let kind = GroupAcceptShareErrorLogic.classify(
                containerAvailable: true,
                isSecondarySession: false,
                ckErrorCode: (error as? CKError)?.code
            )
            let message = kind == .noICloudAccount
                ? String(localized: "groups.sync.errorAcceptShareNoICloud")
                : String(localized: "groups.sync.errorAcceptShare")
            RouterEntryGate.shared.submit(.showGroupSyncError(message))
        }
    }

    /// Query the local SplitGroup name for a given zone ID (resolved after sync).
    func groupName(for zoneID: String) -> String? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zoneID }
        )
        do {
            return try context.fetch(descriptor).first?.name
        } catch {
            logger.error("groupName(for:) fetch failed for zone \(zoneID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Fetch the local SplitGroup for a given zone ID (resolved after sync).
    /// Sorted by `createdAt asc` so the canonical (oldest) group wins consistently
    /// if a CloudKit sync race produced duplicates sharing the same `cloudKitZoneID`.
    /// G6-3 (C2): zone names de los grupos LOCALES `isBackendGroup=true` (ya migrados al backend). El guard
    /// simétrico de PULL salta todo record/deletion CloudKit de estas zonas. `#Predicate` CONCRETO por tipo.
    func backendGroupZoneNames(context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.isBackendGroup == true })
        do {
            return Set(try context.fetch(descriptor).map(\.cloudKitZoneID))
        } catch {
            #if DEBUG
            logger.error("backendGroupZoneNames fetch failed: \(error.localizedDescription, privacy: .public)")
            #endif
            return []
        }
    }

    func group(for zoneID: String) -> SplitGroup? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zoneID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let results: [SplitGroup]
        do {
            results = try context.fetch(descriptor)
        } catch {
            logger.error("group(for:) fetch failed for zone \(zoneID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
        if results.count > 1 {
            #if DEBUG
            logger.error("SplitSyncManager.group(for:): \(results.count) duplicate SplitGroups for zone \(zoneID)")
            #endif
            MetricsService.cloudkitDuplicateDetected(
                model: "SplitGroup",
                count: results.count,
                context: .runtimeFetch,
                keySuffix: zoneID
            )
        }
        return results.first
    }

    /// Current user's `SplitMember` en una zone (canonical: oldest `joinedAt` si hubiera duplicados).
    /// Reusado por `currentMemberStatus(zoneName:)` y por callsites del bridge.
    func currentUserMember(zoneID: String) -> SplitMember? {
        guard let context = modelContext else { return nil }
        var descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true },
            sortBy: [SortDescriptor(\.joinedAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            logger.error("currentUserMember(zoneID:) fetch failed for \(zoneID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Estado local del current user en una zone. Nil si no soy miembro local.
    /// Usado para detectar `.alreadyMember` / `.pendingDuplicate` / `.rejectedRetry` /
    /// `.leftRetry` / `.removedRetry` antes de aceptar el share.
    func currentMemberStatus(zoneName: String) -> SplitMemberStatus? {
        currentUserMember(zoneID: zoneName)?.memberStatus
    }

    /// D5 (§3.3.4, aviso de "Eliminar mi cuenta"): resumen READ-ONLY de los grupos del usuario. Recorre los
    /// grupos NO soft-deleted (`isHiddenForAll == false`) y devuelve, sin escribir NADA (fetches + cálculo
    /// puro — invariante de quiescencia (b) intacto):
    ///  - `outstandingDebtGroupCount`: cuántos tienen un saldo pendiente para el usuario actual
    ///    (`|net| > 0.01` en alguna moneda; molde `GroupSettingsView.recomputeOutstandingDebt`, agregado y
    ///    filtrado al member del usuario). Un grupo cuyo `isCurrentUser` aún no resolvió se SALTA → posible
    ///    sub-conteo, JAMÁS sobre-aviso (dirección segura: el aviso solo informa, nunca bloquea).
    ///  - `hasLegacyCloudKitFootprint`: si algún grupo tiene zona CloudKit viva (`ckSystemFieldsData != nil`),
    ///    donde el nombre persiste tras el GDPR delete (`groups_forget_user` anonimiza SOLO el backend). Se
    ///    evalúa en memoria (evita el gotcha de `#Predicate` sobre opcionales).
    /// Degrada a `.empty` si el contexto no está montado o un fetch lanza. La composición del copy vive en
    /// `AccountDeletionMessageLogic`; el conteo se delega a `AccountDeletionDebtLogic` (ambos puros/testeados).
    ///
    /// `context` inyectable (default `nil` → `self.modelContext`, producción intacta): permite testear la
    /// glue SwiftData→resumen sin mutar el singleton `.shared`. La resolución del member del usuario se hace
    /// INLINE contra ese `context` (mismo predicado que `currentUserMember(zoneID:)`) — así el método es
    /// determinista respecto al contexto pasado y no lee estado del singleton.
    func accountDeletionGroupsSummary(context: ModelContext? = nil) -> AccountDeletionGroupsSummary {
        guard let context = context ?? modelContext else { return .empty }
        do {
            let groups = try context.fetch(FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.isHiddenForAll == false }))
            let hasLegacy = groups.contains { $0.ckSystemFieldsData != nil }

            var perGroupNets: [[Double]] = []
            for group in groups {
                let zoneID = group.cloudKitZoneID

                // Member del usuario actual en esta zona (canonical: oldest joinedAt), INLINE contra el
                // `context` pasado. No resuelto (isCurrentUser aún sin asentar) ⇒ salta → sub-conteo, jamás
                // sobre-aviso.
                var meDesc = FetchDescriptor<SplitMember>(
                    predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true },
                    sortBy: [SortDescriptor(\.joinedAt, order: .forward)])
                meDesc.fetchLimit = 1
                guard let me = try context.fetch(meDesc).first else { continue }
                let myMemberID = me.id.uuidString

                // Early exit O(1): grupo sin gastos ⇒ sin deuda posible (delega a SQL COUNT).
                let expensesCount = try context.fetchCount(FetchDescriptor<SplitExpense>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                guard expensesCount > 0 else { continue }

                let expenses = try context.fetch(FetchDescriptor<SplitExpense>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                let shares = try context.fetch(FetchDescriptor<SplitShare>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                let settlements = try context.fetch(FetchDescriptor<SplitSettlement>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                let members = try context.fetch(FetchDescriptor<SplitMember>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))

                let balances = GroupBalanceService.calculateBalances(
                    expenses: expenses, shares: shares, members: members, settlements: settlements)
                perGroupNets.append(balances.filter { $0.memberID == myMemberID }.map(\.netBalance))
            }

            return AccountDeletionGroupsSummary(
                outstandingDebtGroupCount: AccountDeletionDebtLogic.groupsWithOutstandingBalance(
                    perGroupUserNetBalances: perGroupNets),
                hasLegacyCloudKitFootprint: hasLegacy,
                hasGroups: !groups.isEmpty)
        } catch {
            logger.error("accountDeletionGroupsSummary fetch failed: \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }

    /// Find the most recently synced group (useful after accepting a share).
    func mostRecentGroup() -> SplitGroup? {
        guard let context = modelContext else { return nil }
        var descriptor = FetchDescriptor<SplitGroup>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            logger.error("mostRecentGroup() fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    // MARK: - Access Requests (iOS 26)

    /// Request access to a group share without a direct invitation.
    /// The share owner will be notified and can approve/deny.
    func requestAccess(shareURL: URL) async throws {
        guard let container else {
            throw SplitZoneError.engineNotInitialized
        }

        let operation = CKShareRequestAccessOperation(shareURLs: [shareURL])

        return try await withCheckedThrowingContinuation { continuation in
            operation.perShareAccessRequestResultBlock = { _, _ in
                // Individual results logged only if needed for debugging
            }
            operation.shareAccessRequestResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }

    // MARK: - Manual Sync (pull-to-refresh / foreground / tab)

    /// Forces a fetch of remote group changes. Wired to pull-to-refresh, tab entry, and foreground
    /// resume — the group `CKSyncEngine`s otherwise only fetch on receipt of a push (not handled) or
    /// the one-shot post-promotion fetch (which is skipped when the personal import just settled).
    /// Apple's documented manual-sync pattern (`fetchChanges` on pull-to-refresh).
    ///
    /// - Parameter force: `true` for an explicit user pull-to-refresh (skips the debounce). The
    ///   automatic triggers (tab appear / foreground) omit it so a burst coalesces.
    ///
    /// Single-flight: coalesces concurrent syncs so we never fetch in parallel. A `force` (explicit
    /// pull-to-refresh) that arrives while a NON-forced sync is in flight does NOT settle for its
    /// result — the non-forced one may have skipped via debounce/quiescence — it waits for it to
    /// finish, then runs its own fetch. A non-forced caller coalesces onto whatever is in flight.
    /// Matches the inflight-Task idiom in `GroupUserIdentityService` / `AppAttestClient`.
    func syncNow(force: Bool = false) async {
        if let existing = syncNowTask {
            await existing.value
            if !force { return }
        }
        let task = Task { await self.performSyncNow(force: force) }
        syncNowTask = task
        defer { syncNowTask = nil }
        await task.value
    }

    private func performSyncNow(force: Bool) async {
        // No iCloud account (e.g. simulator) → nothing to fetch; return so pull-to-refresh doesn't hang.
        guard iCloudSyncService.shared.isAccountAvailable else { return }

        // Debounce automatic triggers (foreground + tab appear can fire back-to-back). An explicit
        // pull-to-refresh (`force`) always proceeds.
        if !force, let last = lastSyncNowAt, Date.now.timeIntervalSince(last) < Self.syncNowDebounce {
            return
        }

        if force {
            // Explicit pull: don't silently abort while the sync warms up (promotion pending and/or
            // import not yet quiescent — both are common in the first seconds after a cold launch,
            // exactly when users pull). Wait with a cap; the refresh spinner shows the wait.
            guard await awaitReadyForForcedFetch() else { return }
        } else {
            // Still export-only: try to promote if it's safe now; if it can't, the fetch happens when
            // the gate promotes on its own (poll) — don't fetch here.
            if !autoSyncActive {
                _ = evaluateQuiescentPromotion(noImportGraceElapsed: false, reachedHardCap: false)
                guard autoSyncActive else { return }
            }

            // Don't fire straight into an import that's already running. This NARROWS but does NOT
            // close the window: the import can still START during the `await fetchChanges()` below,
            // and the fetch handler's `save()` isn't gated on quiescence (it can't be — deferring it
            // would drop the CKSyncEngine token). That residual is the SAME one the promoted
            // auto-sync already carries; the root fix is decoupling the group store (deferred, see
            // plan). Low for a groups-only device (its personal store is idle); the guard just
            // avoids the obvious case.
            guard iCloudSyncService.shared.isImportQuiescent else { return }
        }

        // Private + shared are independent CloudKit round-trips → fetch concurrently (spinner waits
        // the max, not the sum). Both apply on the @MainActor handler as before.
        async let priv: Void = fetchEngineChanges(privateEngine, name: "private")
        async let shar: Void = fetchEngineChanges(sharedEngine, name: "shared")
        _ = await (priv, shar)
        lastSyncNowAt = .now

        // No dataVersion bump here: the fetch handler already calls markRemoteChangePending when
        // records actually arrive. Bumping unconditionally would recalc every mounted tab even with
        // zero changes, and double-refresh when there were some. Callers (pull / tab appear) reload
        // the Groups view directly after awaiting this.
    }

    /// Waits (bounded) until the engines are promoted AND the personal import is quiescent, trying
    /// the promotion itself on every tick — `evaluateQuiescentPromotion` can promote at ANY moment
    /// once conditions hold; the 15s gate poll is just its periodic caller, so an explicit pull
    /// shouldn't have to wait for the next tick. Returns `false` on timeout (logged, no fetch —
    /// same TOCTOU residual as before applies after `true`).
    private func awaitReadyForForcedFetch() async -> Bool {
        let deadline = Date.now.addingTimeInterval(Self.syncNowForceWaitTimeout)
        while true {
            if !autoSyncActive {
                _ = evaluateQuiescentPromotion(noImportGraceElapsed: false, reachedHardCap: false)
            }
            if autoSyncActive && iCloudSyncService.shared.isImportQuiescent { return true }
            if Date.now >= deadline {
                logger.notice("syncNow(force): not ready after \(Int(Self.syncNowForceWaitTimeout), privacy: .public)s (autoSync=\(self.autoSyncActive, privacy: .public), quiescent=\(iCloudSyncService.shared.isImportQuiescent, privacy: .public)) — skipping fetch")
                return false
            }
            do { try await Task.sleep(for: .seconds(Self.syncNowForceWaitPoll)) }
            catch { return false }  // cancelled (e.g. view gone) → no fetch
        }
    }

    /// Fetches one engine's changes; logs (no `try?`) on failure so auto-sync retries later.
    private func fetchEngineChanges(_ engine: CKSyncEngine?, name: String) async {
        guard let engine else { return }
        do { try await engine.fetchChanges() }
        catch { logger.error("syncNow: \(name, privacy: .public) fetch failed: \(error.localizedDescription, privacy: .public)") }
    }

    // MARK: - Pending Changes (Low-Level)

    func markPendingChange(for recordID: CKRecord.ID, in engine: CKSyncEngine?) {
        guard let engine else {
            // Fuera de #if DEBUG a propósito (excepción SplitSync, sin PII —
            // recordName/zoneName son UUIDs): un enqueue con engine nil es un
            // DROP definitivo (pre-initialize / post-signOut) que antes era
            // invisible. Canario en telemetría: >0 en prod = incidente.
            logger.error("SplitSync markPendingChange DROPPED — engine nil, record \(recordID.recordName, privacy: .public) zone \(recordID.zoneID.zoneName, privacy: .public)")
            MetricsService.canary(.cloudkitGroupEnqueueDroppedNoEngine, detail: "save")
            return
        }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        pendingRecordSaves.insert(recordID)
    }

    func markPendingDeletion(for recordID: CKRecord.ID, in engine: CKSyncEngine?) {
        guard let engine else {
            logger.error("SplitSync markPendingDeletion DROPPED — engine nil, record \(recordID.recordName, privacy: .public) zone \(recordID.zoneID.zoneName, privacy: .public)")
            MetricsService.canary(.cloudkitGroupEnqueueDroppedNoEngine, detail: "delete")
            return
        }
        engine.state.add(pendingRecordZoneChanges: [.deleteRecord(recordID)])
        pendingRecordSaves.remove(recordID)
    }

    // MARK: - Pending Changes (High-Level — for GC-03 services)

    /// Enqueue a model save for a group I own (private engine).
    func enqueueSave(modelID: UUID, groupID: UUID) {
        let zoneID = CKConstants.zoneID(for: groupID)
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        markPendingChange(for: recordID, in: privateEngine)
    }

    /// G6-3 (C2): encola el MARCADOR de migración (`GroupMeta` con `movedToBackendAt` +
    /// `backendReInviteToken` YA escritos en el `SplitGroup`) a CKSyncEngine. Llama al primitivo
    /// guard-free `enqueueSave(modelID:groupID:)` (owner→private engine; el GroupMeta se identifica con
    /// `modelID == group.id`, como createZone/updateGroup) — DELIBERADAMENTE sin el guard `isBackendGroup`
    /// de la variante `group:`: es la ÚNICA escritura CloudKit legítima sobre un grupo `isBackendGroup=true`
    /// (el marcador debe viajar a los devices de los members para que deriven el estado congelado). El grupo
    /// migrado es del owner ⇒ private engine.
    func enqueueMigrationMarker(group: SplitGroup) {
        enqueueSave(modelID: group.id, groupID: group.id)
        GroupsSyncBreadcrumb.groupsCkMigrationMarkerEnqueued()
    }

    /// Enqueue a model deletion for a group I own (private engine).
    func enqueueDeletion(modelID: UUID, groupID: UUID) {
        let zoneID = CKConstants.zoneID(for: groupID)
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        markPendingDeletion(for: recordID, in: privateEngine)
    }

    /// Enqueue a save for a group I was invited to (shared engine).
    func enqueueSharedSave(modelID: UUID, groupZoneID: String, groupZoneOwnerName: String) {
        let ownerName = groupZoneOwnerName.isEmpty ? CKCurrentUserDefaultName : groupZoneOwnerName
        let zoneID = CKRecordZone.ID(zoneName: groupZoneID, ownerName: ownerName)
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        markPendingChange(for: recordID, in: sharedEngine)
    }

    /// Enqueue a deletion for a group I was invited to (shared engine).
    func enqueueSharedDeletion(modelID: UUID, groupZoneID: String, groupZoneOwnerName: String) {
        let ownerName = groupZoneOwnerName.isEmpty ? CKCurrentUserDefaultName : groupZoneOwnerName
        let zoneID = CKRecordZone.ID(zoneName: groupZoneID, ownerName: ownerName)
        let recordID = CKConstants.recordID(for: modelID, in: zoneID)
        markPendingDeletion(for: recordID, in: sharedEngine)
    }

    /// Enqueue a save, auto-routing to the correct engine based on group ownership.
    func enqueueSave(modelID: UUID, group: SplitGroup) {
        // C2 choke point: un grupo del canal BACKEND no sincroniza por CKSyncEngine — sus records viven en el
        // backend (sync vía GroupsSyncClient). Este guard cubre de un golpe los ~30 call-sites de
        // GroupService/GroupExpenseService/GroupJoinReconciler/backfills que enrutan por esta variante `group:`.
        // C-3: el predicado se amplía al grupo CONGELADO, no solo al backend. Tras un cambio de Apple ID
        // SOBREVIVEN copias congeladas (D1) y este es el choke point por el que
        // `GroupService.refreshCurrentUserFlags` (backfill de `cloudKitUserRecordID` al boot) las subiría a
        // la private DB del Apple ID NUEVO. Se usa la primitiva de freeze de `GroupFreezeLogic` y NO
        // `movedToBackendAt != nil` a secas: su mitigación #9 (owner tras reinstall, con
        // `ckSystemFieldsData`) está NO congelada a propósito y el predicado crudo le quitaría su último
        // camino de subida.
        guard !(group.isBackendGroup || group.isMigratedFrozen) else {
            GroupsSyncBreadcrumb.groupsCkEnqueueSkippedBackendGroup(site: "enqueueSave")
            return
        }
        if group.isOwner {
            enqueueSave(modelID: modelID, groupID: group.id)
        } else {
            enqueueSharedSave(modelID: modelID, groupZoneID: group.cloudKitZoneID, groupZoneOwnerName: resolvedOwnerName(for: group))
        }
    }

    /// `true` si el engine que le tocaría a un grupo (private para owner, shared
    /// para invitado) existe. Guard del reconciliador de join intents: un enqueue
    /// contra engine nil es un drop definitivo.
    func hasEngine(forOwned isOwner: Bool) -> Bool {
        (isOwner ? privateEngine : sharedEngine) != nil
    }

    /// Enqueue a deletion, auto-routing to the correct engine based on group ownership.
    func enqueueDeletion(modelID: UUID, group: SplitGroup) {
        // C2 choke point (par de enqueueSave): grupo backend → jamás a CKSyncEngine.
        // C-3: mismo ensanche que su par — un grupo CONGELADO retenido tras un cambio de Apple ID tampoco
        // puede emitir deletions a la private DB del ID nuevo.
        guard !(group.isBackendGroup || group.isMigratedFrozen) else {
            GroupsSyncBreadcrumb.groupsCkEnqueueSkippedBackendGroup(site: "enqueueDeletion")
            return
        }
        if group.isOwner {
            enqueueDeletion(modelID: modelID, groupID: group.id)
        } else {
            enqueueSharedDeletion(modelID: modelID, groupZoneID: group.cloudKitZoneID, groupZoneOwnerName: resolvedOwnerName(for: group))
        }
    }

    private func resolvedOwnerName(for group: SplitGroup) -> String {
        if !group.cloudKitZoneOwnerName.isEmpty { return group.cloudKitZoneOwnerName }
        if let data = group.ckSystemFieldsData,
           let record = CKRecordTranslator.recordFromSystemFields(data)
        {
            return record.recordID.zoneID.ownerName
        }
        return CKCurrentUserDefaultName
    }

    func sendPendingChanges(for group: SplitGroup) async throws {
        let engine = group.isOwner ? privateEngine : sharedEngine
        guard let engine else { throw SplitSyncError.engineNotInitialized }
        try await engine.sendChanges()
    }

    // MARK: - Event Processing (called from delegate)

    func processEvent(_ event: CKSyncEngine.Event, engine: CKSyncEngine) {
        let name = engineName(for: engine)

        switch event {
        case .stateUpdate:
            break // Handled synchronously in delegate (not dispatched)

        case .accountChange(let change):
            handleAccountChange(change)

        case .fetchedDatabaseChanges(let fetched):
            handleFetchedDatabaseChanges(fetched, engineName: name, engine: engine)

        case .fetchedRecordZoneChanges(let fetched):
            handleFetchedRecordZoneChanges(fetched, engineName: name)

        case .sentDatabaseChanges(let sent):
            handleSentDatabaseChanges(sent, engineName: name)

        case .sentRecordZoneChanges(let sent):
            handleSentRecordZoneChanges(sent, engineName: name)

        case .willFetchChanges:
            syncStatus = .syncing
            // Señal PASIVA del gate C-4: un ciclo de fetch acaba de abrirse en este engine.
            fetchCyclesInFlight[name, default: 0] += 1

        case .didFetchChanges:
            syncStatus = .idle
            // El ciclo cerró: decrementa con clamp (un `will` puede haberse perdido si su engine fue
            // recreado — el delegate descarta los eventos del viejo vía `isCurrentEngine`) y deja el
            // testigo de «este engine ya completó un ciclo entero en esta sesión».
            fetchCyclesInFlight[name] = max(0, (fetchCyclesInFlight[name] ?? 0) - 1)
            enginesWithCompletedFetchCycle.insert(name)

        case .willFetchRecordZoneChanges:
            break

        case .didFetchRecordZoneChanges(let event):
            // Señal "el engine terminó de fetchear TODOS los cambios de esta zona
            // en este ciclo" — cierra la ventana de supresión del primer import
            // (inmune a multi-batch, a diferencia de contar batches).
            handleDidFetchRecordZoneChanges(event)

        case .willSendChanges:
            syncStatus = .syncing

        case .didSendChanges:
            syncStatus = .idle

        @unknown default:
            break
        }
    }

    // MARK: - Delegate save gate

    /// Guard for every delegate handler that would touch the shared `mainContext`. During the
    /// export-only window (`autoSyncActive == false`, personal import not settled) persisting the
    /// half-imported personal graph can trip SwiftData's internal `_assertionFailure`. Returns
    /// `true` (and logs) when the handler must defer. FETCH events must then be BUFFERED by the
    /// caller (`deferredFetched*Events`, drained on promotion) — the engine's token advances past a
    /// handled event, so a dropped fetch would be lost FOREVER (a later fetch does NOT re-deliver
    /// it). Sent/conflict handlers may drop safely (they reconcile via `serverRecordChanged`).
    /// With `automaticallySync = false` the fetch handlers don't run on their own — the buffering
    /// is defence-in-depth plus the real gate for the sent/conflict handlers (export path).
    private func deferMainContextWork(_ reason: String) -> Bool {
        guard SplitSyncStartGate.shouldDeferDelegateSave(autoSyncActive: autoSyncActive) else { return false }
        logger.notice("SplitSync deferring delegate work [\(reason, privacy: .public)] — export-only window, reconciled after auto-sync")
        return true
    }

    /// Re-applies fetch events buffered during the export-only window. Called from
    /// `enableAutoSync()` AFTER `autoSyncActive = true` (so the handlers don't re-defer) and BEFORE
    /// the post-promotion fetch (event order). A deferred sign-out supersedes the buffers: apply-
    /// then-clear would be wasted work, so they're discarded. Engines are resolved by NAME — the
    /// promotion recreated them, a captured reference would target a discarded engine.
    private func drainDeferredFetchEvents() {
        if deferredClearAllRequested {
            deferredClearAllRequested = false
            deferredFetchedDatabaseEvents.removeAll()
            deferredFetchedRecordZoneEvents.removeAll()
            deferredZoneFetchCompletions.removeAll()
            clearAllLocalGroupData()
            return
        }
        guard !deferredFetchedDatabaseEvents.isEmpty || !deferredFetchedRecordZoneEvents.isEmpty
            || !deferredZoneFetchCompletions.isEmpty
        else { return }

        let dbEvents = deferredFetchedDatabaseEvents
        let recordEvents = deferredFetchedRecordZoneEvents
        let zoneCompletions = deferredZoneFetchCompletions
        deferredFetchedDatabaseEvents.removeAll()
        deferredFetchedRecordZoneEvents.removeAll()
        deferredZoneFetchCompletions.removeAll()

        logger.notice("SplitSync draining deferred fetch events — db=\(dbEvents.count, privacy: .public), recordZone=\(recordEvents.count, privacy: .public)")

        for (event, name) in dbEvents {
            guard let engine = (name == "private") ? privateEngine : sharedEngine else { continue }
            handleFetchedDatabaseChanges(event, engineName: name, engine: engine)
        }
        for (event, name) in recordEvents {
            handleFetchedRecordZoneChanges(event, engineName: name)
        }
        // DESPUÉS de los record events: cerrar el baseline de primer import de las
        // zonas cuyo ciclo completó en la ventana. Si dos ciclos se intercalaron,
        // el peor caso es suprimir de más (dirección segura).
        for zoneName in zoneCompletions {
            completeInitialMemberImport(zoneName: zoneName)
        }
    }

    // MARK: - Event Handlers

    /// Cierra la ventana de supresión de notifs de membership al completar el
    /// ciclo de fetch de una zona (sin error). Durante export-only se difiere
    /// (el save tocaría el mainContext compartido) y se drena tras los record
    /// events en `drainDeferredFetchEvents`.
    private func handleDidFetchRecordZoneChanges(_ event: CKSyncEngine.Event.DidFetchRecordZoneChanges) {
        let zoneName = event.zoneID.zoneName
        guard event.error == nil else {
            // C-4: el fetch de ESTA zona falló, su contenido no bajó. La migración no puede congelar un
            // grupo cuya zona no se ha podido leer en esta sesión. Se AUTO-SANA: el ciclo limpio
            // siguiente de la misma zona la retira del set (un `changeTokenExpired` u otro transitorio
            // no deja el gate clavado). Testigo NEGATIVO a propósito — exigir presencia en un set de
            // «zonas fetcheadas limpiamente» deadlockearía: una zona SIN cambios no produce el evento.
            zonesWithFailedFetchThisSession.insert(zoneName)
            return
        }
        zonesWithFailedFetchThisSession.remove(zoneName)
        if deferMainContextWork("didFetchRecordZoneChanges") {
            deferredZoneFetchCompletions.append(zoneName)
            return
        }
        completeInitialMemberImport(zoneName: zoneName)
    }

    /// Limpia `initialMemberImportStartedAt` del SplitGroup de la zona. No-op si
    /// el grupo no existe o el baseline ya estaba cerrado (evita saves gratuitos
    /// en cada ciclo de fetch).
    private func completeInitialMemberImport(zoneName: String) {
        guard let context = modelContext,
              let group = group(for: zoneName),
              group.initialMemberImportStartedAt != nil
        else { return }
        group.initialMemberImportStartedAt = nil
        do {
            SaveBreadcrumb.willSave("SplitSyncManager.completeInitialMemberImport")
            try context.save()
            SaveBreadcrumb.didSave("SplitSyncManager.completeInitialMemberImport")
        } catch {
            // El baseline queda vigente; la ventana de 15 min lo auto-sana.
            logger.error("completeInitialMemberImport save failed for \(zoneName, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handleFetchedDatabaseChanges(_ fetched: CKSyncEngine.Event.FetchedDatabaseChanges, engineName: String, engine: CKSyncEngine) {
        #if DEBUG
        logger.info("[\(engineName)] fetchedDatabaseChanges: \(fetched.modifications.count) mods, \(fetched.deletions.count) dels")
        #endif

        if deferMainContextWork("fetchedDatabaseChanges") {
            // Buffer, don't drop: the engine's token advances past this event when we return.
            deferredFetchedDatabaseEvents.append((fetched, engineName))
            return
        }
        guard !fetched.deletions.isEmpty, let modelContext else { return }

        for deletion in fetched.deletions {
            let zoneName = deletion.zoneID.zoneName
            guard let groupID = CKConstants.groupID(from: zoneName) else { continue }

            // G6-3 (C2/C5): la zona de un grupo MIGRADO puede borrarse legítimamente (C5 "borrar mi copia
            // congelada" del owner) — el borrado de la zona CloudKit NO debe destruir los datos locales:
            // (a) member ya RE-JOINEADO (isBackendGroup=true): su verdad vive en el backend — nuke aquí
            //     borraría el grupo backend entero de su device; (b) member NO re-joineado (congelado,
            //     movedToBackendAt != nil): su copia congelada porta el TOKEN del CTA de re-join — borrarla
            //     lo dejaría fuera sin camino de vuelta (el path del member queda FUERA de v1 en C5).
            // Solo se purgan los pending changes del engine (no debería haber).
            if let localGroup = group(for: zoneName),
               localGroup.isBackendGroup || localGroup.movedToBackendAt != nil {
                GroupsSyncBreadcrumb.groupsCkPullSkippedBackendGroup(site: "zoneDeletion")
                purgePendingChanges(for: deletion.zoneID, engine: engine)
                continue
            }

            switch deletion.reason {
            case .deleted:
                #if DEBUG
                logger.info("[\(engineName)] Zone deleted: \(zoneName) — cleaning up local data")
                #endif
                deleteGroupCache(groupID: groupID, context: modelContext)
                purgePendingChanges(for: deletion.zoneID, engine: engine)

            case .purged:
                #if DEBUG
                logger.info("[\(engineName)] Zone purged: \(zoneName) — clearing data + state")
                #endif
                deleteGroupCache(groupID: groupID, context: modelContext)
                purgePendingChanges(for: deletion.zoneID, engine: engine)
                clearState(name: engineName)
                // C-4 (PIEZA 2): tirar el estado ⇒ re-entrega completa en el próximo arranque.
                replayingFullCorpus = true

            case .encryptedDataReset:
                #if DEBUG
                logger.info("[\(engineName)] Encrypted data reset: \(zoneName) — clearing system fields + re-uploading")
                #endif
                clearState(name: engineName)
                replayingFullCorpus = true
                reuploadGroupRecords(groupID: groupID, zoneID: deletion.zoneID, engine: engine, context: modelContext)

            @unknown default:
                deleteGroupCache(groupID: groupID, context: modelContext)
                purgePendingChanges(for: deletion.zoneID, engine: engine)
            }
        }

        do {
            SaveBreadcrumb.willSave("SplitSync.fetchedDatabaseChanges")
            try modelContext.save()
            SaveBreadcrumb.didSave("SplitSync.fetchedDatabaseChanges")
            SessionState.shared.markRemoteChangePending()
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Failed to save after zone deletion cleanup: \(error)")
            #endif
        }
    }

    private func handleAccountChange(_ change: CKSyncEngine.Event.AccountChange) {
        switch change.changeType {
        case .signIn:
            syncStatus = .idle
            #if DEBUG
            logger.info("iCloud account signed in")
            #endif

        case .signOut:
            syncStatus = .noAccount
            // D2 (C-3): el sign-out del Apple ID resetea TAMBIÉN el estado de CKSyncEngine. Borrar filas
            // dejando los change tokens intactos deja a CloudKit convencido de que este device está al día
            // ⇒ esos records no se re-entregan JAMÁS y el mismo humano que vuelve a firmar pierde sus
            // grupos con los datos vivos en la nube — el anti-patrón que nombra la doc de
            // `resetLocalGroupsSyncState` y la trampa (1) de `.claude/rules/swiftdata-cloudkit.md`.
            // `performAccountSwitchCleanup()` es EXACTAMENTE lo que hacía esta rama
            // (el borrado de filas + `GroupUserIdentityService.clearCache()`, que va DENTRO de
            // `resetLocalGroupsSyncState`) MÁS el reset del estado de los engines.
            // CAMBIO DE COMPORTAMIENTO EN PRODUCCIÓN, aceptado conscientemente por el owner: el siguiente
            // sign-in hace un re-fetch COMPLETO de las zonas de grupos en vez de incremental.
            performAccountSwitchCleanup()
            #if DEBUG
            logger.info("iCloud account signed out — cleared local group data + engine state")
            #endif

        case .switchAccounts:
            syncStatus = .idle
            performAccountSwitchCleanup()
            #if DEBUG
            logger.info("iCloud account switched — cleared data + state for re-fetch")
            #endif

        @unknown default:
            break
        }
    }

    /// Limpieza de "cambió el Apple ID" — reusada por `handleAccountChange(.switchAccounts)`
    /// (reactivo, evento del engine) y por `runIdentityBootGuard()` (proactivo, GAP 1).
    /// `clearAllLocalGroupData` auto-difiere en la ventana export-only
    /// (`deferredClearAllRequested`); borrar los state files con engines vivos tiene el
    /// mismo precedente que el switch reactivo (los engines ya cargaron su
    /// stateSerialization en memoria — el re-fetch bajo la identidad nueva lo regenera).
    private func performAccountSwitchCleanup() {
        // C-3: `handleAccountChange` corre UNA VEZ POR ENGINE (private + shared) y la recreación de abajo
        // puede hacer que un engine recién creado vuelva a emitir su propio `.accountChange`. Sin este
        // guard el par borrar-todo → save → recrear → borrar-todo se realimenta.
        guard !identityCleanupInFlight else { return }
        identityCleanupInFlight = true
        defer { identityCleanupInFlight = false }

        clearAllLocalGroupData()
        resetLocalGroupsSyncState()
        recreateEnginesAfterIdentityChange()
    }

    /// C-3 (D2): reset EFECTIVO del estado de CKSyncEngine tras un cambio de identidad de iCloud.
    ///
    /// `clearState(name:)` solo borra el fichero `<name>.json`: los engines siguen VIVOS con su
    /// `stateSerialization` (change tokens + pending changes) en MEMORIA, y el delegate la re-escribe tal
    /// cual en el siguiente `.stateUpdate`. Sin esto, «resetear los tokens» es no-determinista — en la
    /// práctica el reset solo llegaba en el próximo cold start, y a veces ni eso.
    ///
    /// Molde EXACTO de `enableAutoSync()`: refs de identidad primero (el delegate descarta callbacks de
    /// engines viejos vía `isCurrentEngine`, y un `.stateUpdate` tardío del viejo se guardaría con el
    /// nombre equivocado), luego las propiedades. DIFERENCIA deliberada con la promoción: se construyen
    /// con `state: nil` y NO se transfieren los `pendingRecordZoneChanges` — esos pendientes son del Apple
    /// ID que se fue y enviarlos bajo el nuevo es la fuga. Ese drop es justamente lo que obliga a
    /// re-armar `markerEnqueuedFlag` en el gate (el marcador de migración vivía ahí).
    ///
    /// Se llama SOLO desde `performAccountSwitchCleanup`, que a su vez tiene TRES entradas:
    /// `handleAccountChange(.signOut)` (D2), `handleAccountChange(.switchAccounts)` y
    /// `runIdentityBootGuard()` (proactivo del boot, VIVO hoy con el flag OFF). NO se llama desde
    /// `resetLocalGroupsSyncState`: el camino de handover «empiezo de cero»
    /// (`DataWipeService.wipeLocalGroupsDomain`) reusa ese segundo y debe quedar byte-idéntico.
    private func recreateEnginesAfterIdentityChange() {
        guard enginesStarted, let container, let delegate else { return }

        let newPrivate = makeEngine(
            database: container.privateCloudDatabase, state: nil, autoSync: autoSyncActive, delegate: delegate)
        let newShared = makeEngine(
            database: container.sharedCloudDatabase, state: nil, autoSync: autoSyncActive, delegate: delegate)
        _privateEngineRef = newPrivate
        _sharedEngineRef = newShared
        privateEngine = newPrivate
        sharedEngine = newShared

        // C-4 (PIEZA 2): estos engines nacen con `state: nil` ⇒ re-entrega COMPLETA en esta misma
        // sesión, sin esperar al próximo arranque. `resetLocalGroupsSyncState` ya lo enciende en el
        // único camino que llega hasta aquí; se repite porque es DONDE se produce la condición (el
        // `state: nil` de arriba), y así ninguna reordenación futura lo pierde.
        replayingFullCorpus = true

        // Espejos en memoria de las colas que se acaban de tirar: `quotaFailedRecordIDs` los RE-ENCOLA en
        // `retryQuotaFailedRecords()` (foreground) y apuntan a zonas del Apple ID anterior.
        pendingRecordSaves.removeAll()
        quotaFailedRecordIDs.removeAll()

        logger.notice("SplitSync engines recreated after identity change — state dropped (autoSync=\(self.autoSyncActive, privacy: .public))")
    }

    /// Mitad NO-SwiftData de la limpieza de arriba: estado persistido de los engines + identidad
    /// cacheada. Extraída para que la purga del dominio Grupos en «empiezo de cero»
    /// (`DataWipeService.wipeLocalGroupsDomain`, handover de dispositivo) la reuse SIN pasar por
    /// `clearAllLocalGroupData`, que borra las filas vía el delegate y por tanto se auto-difiere en
    /// la ventana export-only (`deferMainContextWork`) — en un camino de usuario en primer plano
    /// diferir significaría no borrar nada.
    ///
    /// Va SIEMPRE emparejada con el borrado de las filas, en ambas direcciones: borrar filas sin
    /// resetear los tokens deja a CloudKit convencido de que este dispositivo está al día y esos
    /// records no se reenvían nunca (pérdida local permanente); resetear los tokens sin borrar las
    /// filas provoca un re-fetch completo sobre datos que ya están. La rama `.signOut` de
    /// `handleAccountChange` era el anti-patrón a NO copiar (borraba filas sin tocar el estado); C-3/D2 la
    /// arregló: ahora enruta por `performAccountSwitchCleanup`, igual que `.switchAccounts`.
    func resetLocalGroupsSyncState() {
        clearState(name: "private")
        clearState(name: "shared")
        GroupUserIdentityService.shared.clearCache()
        // C-4: los tokens se invalidan ⇒ el canal vuelve a estar «sin leer» y los testigos del ciclo de
        // fetch hablan de un corpus que ya no es el que viene. Sin este reset el gate leería como asentado
        // un canal que va a re-fetchear la base entera.
        fetchCyclesInFlight.removeAll()
        enginesWithCompletedFetchCycle.removeAll()
        zonesWithFailedFetchThisSession.removeAll()
        fetchApplyFailedThisSession = false
        // C-4 (PIEZA 2): invalidar los tokens ES la condición de re-entrega completa. Se enciende aquí —
        // y no solo en `startEngines` — porque este segundo lo reusa el handover «empiezo de cero»
        // (`DataWipeService.wipeLocalGroupsDomain`) SIN recrear engines: ahí la re-entrega llega en el
        // próximo arranque, pero encenderlo ya deja la sesión en curso del lado seguro.
        replayingFullCorpus = true
    }

    /// Delete all local group data (used on sign-out and account switch for privacy).
    private func clearAllLocalGroupData() {
        // Edge case only: a sign-out/switch during the initial restore window (the user just signed
        // in) is near-impossible. Defer the save to stay crash-safe (flagged — runs after promotion,
        // superseding any buffered fetched data); a normal sign-out (after the import settled,
        // autoSyncActive == true) clears immediately.
        if deferMainContextWork("clearAllLocalGroupData") {
            deferredClearAllRequested = true
            return
        }
        guard let modelContext else { return }

        do {
            // C-3 (D1 + D4): las zonas del canal BACKEND se CONSERVAN mientras haya sesión de nube viva —
            // su identidad es el `sub` de la cuenta Yala, no el Apple ID del OS — y pierden TODA credencial
            // de re-join. Sin sesión de nube se borra todo, como hoy. Las zonas del canal CloudKit se van
            // enteras (privacidad, commit 31dded30). Se decide por ZONA y no por fila: existen `SplitGroup`
            // duplicados con el MISMO `cloudKitZoneID` (`SplitGroupDeduplicationService`) y el flip de canal
            // solo marca uno — borrar el duplicado «por zona» vaciaría el grupo backend recién retenido.
            // El cursor del pull backend (`GroupSyncCursor.groupCursorsJSON`) NO se toca: filas retenidas +
            // cursor vivo es el par COHERENTE; era «filas borradas + cursor vivo» lo que perdía los datos
            // para siempre (el server solo manda `server_seq > cursor`).
            let result = try GroupsIdentityPurgeGate.apply(in: modelContext)
            SaveBreadcrumb.willSave("SplitSync.clearAllLocalGroupData")
            try modelContext.save()
            SaveBreadcrumb.didSave("SplitSync.clearAllLocalGroupData")
            SessionState.shared.markRemoteChangePending()
            if result.retainedOwnedZones + result.retainedFrozenZones > 0 {
                GroupsSyncBreadcrumb.groupsIdentityChangeRetained(
                    owned: result.retainedOwnedZones,
                    frozen: result.retainedFrozenZones,
                    credentialsRevoked: result.credentialsRevoked,
                    markersReQueued: result.markersReQueued,
                    pendingJoinsRevoked: result.pendingJoinsRevoked)
            }
            if result.failedZones > 0 {
                GroupsSyncBreadcrumb.groupsIdentityChangePurgeFailed(zones: result.failedZones)
            }
        } catch {
            #if DEBUG
            logger.error("clearAllLocalGroupData: Failed: \(error)")
            #endif
        }
    }

    /// Retry records that previously failed due to iCloud quota exceeded.
    /// Call from sceneDidBecomeActive or when quota status may have changed.
    func retryQuotaFailedRecords() {
        guard !quotaFailedRecordIDs.isEmpty else { return }
        let toRetry = quotaFailedRecordIDs
        quotaFailedRecordIDs.removeAll()

        // Re-enqueue to private engine (shared records go through the same path)
        if let engine = privateEngine {
            engine.state.add(pendingRecordZoneChanges: toRetry.map { .saveRecord($0) })
        }
        if let engine = sharedEngine {
            engine.state.add(pendingRecordZoneChanges: toRetry.map { .saveRecord($0) })
        }

        syncStatus = .idle
        #if DEBUG
        logger.info("Retrying \(toRetry.count) quota-failed records")
        #endif
    }

    private func handleFetchedRecordZoneChanges(_ fetched: CKSyncEngine.Event.FetchedRecordZoneChanges, engineName: String) {
        if deferMainContextWork("fetchedRecordZoneChanges") {
            // Buffer, don't drop: the engine's token advances past this event when we return.
            deferredFetchedRecordZoneEvents.append((fetched, engineName))
            return
        }
        guard let modelContext else {
            // C-4: el token del engine YA avanzó sobre este batch y no hay dónde aplicarlo — el store no
            // quedó completo y CloudKit no lo re-entrega. Invalida el testigo del ciclo: la migración a
            // backend NO arranca en esta sesión (congelar aquí sembraría de un store mutilado).
            fetchApplyFailedThisSession = true
            GroupsSyncBreadcrumb.groupsCkFetchApplyFailed(reason: "no-context")
            return
        }

        var changeSet = RemoteChangeSet()

        // G6-3 (C2, GUARD SIMÉTRICO de PULL): grupos YA migrados (`isBackendGroup=true`) tienen su verdad en
        // el backend — la zona CloudKit sigue VIVA (deleteZone es opcional) y un miembro rezagado o el eco del
        // propio marcador escribiría records STALE. Aplicarlos PISARÍA las ediciones backend post-migración
        // Y bridgearía datos viejos al store personal. FIX: saltar TODO record/deletion cuyo grupo local sea
        // backend (la zona CloudKit queda como red de SOLO-LECTURA de verdad; el owner adoptado no necesita
        // NADA de CloudKit). Set computado una vez por batch.
        let backendZoneNames = backendGroupZoneNames(context: modelContext)

        // Pre-fetch existing IDs scoped to affected zones (GC-06)
        let batchZoneNames = Set(fetched.modifications.map { $0.record.recordID.zoneID.zoneName })
        var existingExpenseIDs: Set<UUID> = []
        var existingSettlementIDs: Set<UUID> = []
        var existingMemberIDs: Set<UUID> = []
        // C-4 (PIEZA 2): este pre-fetch es BEST-EFFORT — su `catch` deja los sets VACÍOS y sigue, porque
        // clasificar notificaciones de más es inocuo. Para el RESCATE no lo es: sin esta bandera, un
        // fetch fallido haría que TODO el batch pareciera «nunca visto». No es el candado del invariante
        // «solo inserta» (ése vive en `applyRemoteRecordIfAbsent`, re-chequeando por id), es el cinturón:
        // un store que no se ha podido leer no es base para adoptar nada.
        var prefetchFailed = false
        do {
            for zoneName in batchZoneNames {
                let zName = zoneName
                let expDesc = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zName })
                existingExpenseIDs.formUnion(try modelContext.fetch(expDesc).map(\.id))
                let setDesc = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zName })
                existingSettlementIDs.formUnion(try modelContext.fetch(setDesc).map(\.id))
                let memDesc = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zName })
                existingMemberIDs.formUnion(try modelContext.fetch(memDesc).map(\.id))
            }
        } catch {
            prefetchFailed = true
            #if DEBUG
            logger.error("[\(engineName)] Pre-fetch for change classification failed: \(error)")
            #endif
        }

        // C-4 (PIEZA 2): estado del canal backend por ZONA, cacheado dentro del batch — molde de
        // `adminCache`/`baselineCache`. Se consulta SOLO para zonas backend (la rama del guard de abajo),
        // así que con el flag apagado —todo device de producción hoy— `backendZoneNames` viene vacío y
        // esto no añade ni una query al camino caliente del pull.
        let rescueFlagOn = CloudSyncFlags.groupsBackendEnabled
        var backendPullCache: [String: (completed: Bool, hasCursor: Bool)] = [:]
        func backendPullSignal(_ zoneName: String) -> (completed: Bool, hasCursor: Bool) {
            if let cached = backendPullCache[zoneName] { return cached }
            let signal = backendPullSignalProvider(zoneName, modelContext)
            backendPullCache[zoneName] = signal
            return signal
        }
        var rescuedThisBatch = 0

        // cache `isCurrentUserAdmin` por zoneID dentro del batch — evita fetch repetido.
        var adminCache: [String: Bool] = [:]
        // cache del baseline de primer import por zona (misma razón). Seguro por
        // batch: el baseline solo puede moverse hacia initialImport (insert de
        // GroupMeta mid-batch), nunca al revés.
        var baselineCache: [String: MemberChangeNotificationLogic.ZoneBaseline] = [:]
        func zoneBaseline(for zoneName: String) -> MemberChangeNotificationLogic.ZoneBaseline {
            if let cached = baselineCache[zoneName] { return cached }
            let localGroup = group(for: zoneName)
            let baseline = MemberChangeNotificationLogic.zoneBaseline(
                groupExistsLocally: localGroup != nil,
                importStartedAt: localGroup?.initialMemberImportStartedAt,
                now: .now
            )
            baselineCache[zoneName] = baseline
            return baseline
        }

        for modification in fetched.modifications {
            let record = modification.record

            // G6-3 (C2): grupo migrado → red de solo-lectura. Saltar TODO (incl. clasificación de notifs y
            // bridge — un miembro adoptado ya no necesita nada de CloudKit).
            //
            // C-4 (PIEZA 2, RESCATE): con UNA excepción — el record NUNCA VISTO. El guard es correcto
            // para el eco stale, pero descartarlo TODO por igual pierde dinero en silencio: el token del
            // engine ya avanzó y CloudKit no re-entrega. Aquí se separan los dos casos. La adopción es
            // INSERT-ONLY y solo bajo los cuatro gates de `GroupPullRescueGate` (ver su cabecera: son
            // los que impiden pisar el backend y la resurrección en masa).
            if backendZoneNames.contains(record.recordID.zoneID.zoneName) {
                let pull = backendPullSignal(record.recordID.zoneID.zoneName)
                let signal = GroupPullRescueGate.Signal(
                    flagOn: rescueFlagOn,
                    replayingFullCorpus: replayingFullCorpus,
                    prefetchFailed: prefetchFailed,
                    backendPullCompletedThisSession: pull.completed,
                    groupHasBackendCursor: pull.hasCursor,
                    isRescuableType: GroupPullRescueGate.entityName(forRecordType: record.recordType) != nil,
                    // El Set del pre-fetch NO decide: solo cubre 3 de los 5 tipos y su catch lo deja
                    // vacío. La existencia se pregunta por id con el helper concreto — el MISMO que
                    // vuelve a preguntar dentro de `applyRemoteRecordIfAbsent` (candado del invariante
                    // «el rescate jamás actualiza»).
                    existsLocally: recordExistsLocally(record, context: modelContext))
                guard GroupPullRescueGate.decide(signal) == .rescue else {
                    GroupsSyncBreadcrumb.groupsCkPullSkippedBackendGroup(
                        site: "applyRemote", reason: GroupPullRescueGate.skipReason(signal))
                    continue
                }
                if applyRemoteRecordIfAbsent(record, context: modelContext, engineName: engineName) {
                    rescuedThisBatch += 1
                }
                // NO se clasifica para notificaciones ni se bridgea: el grupo vive en el backend y su
                // pull es quien alimenta esas dos superficies. Rescatar es re-inyectar al servidor, no
                // re-abrir el camino CloudKit.
                continue
            }

            // GC-06: Classify changes for notifications
            if let modelID = CKConstants.modelID(from: record.recordID),
               let groupID = CKConstants.groupID(from: record.recordID.zoneID.zoneName) {
                switch record.recordType {
                case CKConstants.RecordType.splitExpense:
                    if existingExpenseIDs.contains(modelID) {
                        changeSet.modifiedExpenses.append((modelID, groupID))
                    } else {
                        changeSet.newExpenses.append((modelID, groupID))
                    }
                case CKConstants.RecordType.splitSettlement:
                    if !existingSettlementIDs.contains(modelID) {
                        changeSet.newSettlements.append((modelID, groupID))
                    }
                case CKConstants.RecordType.splitMember:
                    if !existingMemberIDs.contains(modelID) {
                        // Clasifica el member nuevo. Solo `active` notifica "se unió";
                        // pending solo notifica al admin; un pending recibido por un
                        // no-admin (o un estado terminal) NO dispara notif espuria.
                        // Guards previos (bug "Jür se unió al grupo"): autoexclusión
                        // por identidad + supresión durante el primer import de la zona.
                        let zoneName = record.recordID.zoneID.zoneName
                        let rawStatus = record[CKConstants.MemberField.status] as? String
                        // admin solo importa para pending — compútalo lazy para no fetchear de más.
                        let isPending = rawStatus == SplitMemberStatus.pendingApproval.rawValue
                        let isAdmin = isPending && isCurrentUserAdminOfGroup(zoneName: zoneName, context: modelContext, cache: &adminCache)
                        let baseline = zoneBaseline(for: zoneName)
                        #if DEBUG
                        print("SplitSync[#16-debug]: splitMember zone=\(zoneName) modelID=\(modelID) status=\(rawStatus ?? "nil") isPending=\(isPending) isAdmin=\(isAdmin) baseline=\(baseline)")
                        #endif
                        switch MemberChangeNotificationLogic.classifyNewMember(
                            rawStatus: rawStatus,
                            isCurrentUserAdmin: isAdmin,
                            memberUserRecordID: record[CKConstants.MemberField.memberID] as? String,
                            currentUserRecordID: GroupUserIdentityService.shared.cachedRecordName,
                            zoneBaseline: baseline
                        ) {
                        case .pendingRequestForAdmin:
                            changeSet.newPendingMembers.append((modelID, groupID))
                        case .joined:
                            changeSet.newMembers.append((modelID, groupID))
                        case .ignore:
                            break
                        }
                    }
                default: break
                }
            }

            applyRemoteRecord(record, context: modelContext, engineName: engineName)
        }

        for deletion in fetched.deletions {
            // G6-3 (C2): grupo migrado → no aplicar borrados CloudKit (la verdad vive en el backend).
            // C-4 (PIEZA 2), INVARIANTE 2: el rescate NO se consulta aquí y no debe hacerlo nunca. Una
            // deletion de una zona backend es EXACTAMENTE lo que el guard tiene que descartar: la verdad
            // de las bajas vive en el backend, y aplicarla borraría local lo que el servidor conserva.
            if backendZoneNames.contains(deletion.recordID.zoneID.zoneName) {
                GroupsSyncBreadcrumb.groupsCkPullSkippedBackendGroup(site: "applyRemote", reason: "deletion")
                continue
            }
            applyRemoteDeletion(recordID: deletion.recordID, recordType: deletion.recordType, context: modelContext)
        }

        do {
            // Persist remote records before deferred bridge. Auto-sync overhead is
            // mitigated by state persistence limiting CKSyncEngine to incremental fetches.
            SaveBreadcrumb.willSave("SplitSync.fetchedRecordZoneChanges")
            try modelContext.save()
            SaveBreadcrumb.didSave("SplitSync.fetchedRecordZoneChanges")
            // C-4 (PIEZA 2): el canario va DESPUÉS del save y solo si persistió — un rescate que no
            // llega al store no rescató nada. Una emisión por BATCH (`value` = filas adoptadas), no por
            // fila: el breadcrumb de Console.app ya da el detalle por record.
            if rescuedThisBatch > 0 {
                MetricsService.canary(.groupCkPullRescued, value: Double(rescuedThisBatch))
                pendingRescueDrain = true
            }
        } catch {
            // C-4: el token YA avanzó, lo de este batch no vuelve. Invalida el testigo del ciclo (el
            // gate difiere la migración al próximo boot) y deja breadcrumb FUERA de `#if DEBUG` —
            // excepción consciente del subsistema `SplitSync*`/`GroupsSync*`, sin PII. Diferir NO
            // recupera lo perdido; lo que evita es COMPOUND: congelar un grupo cuyo store se sabe
            // incompleto y sembrar el backend desde él.
            fetchApplyFailedThisSession = true
            GroupsSyncBreadcrumb.groupsCkFetchApplyFailed(reason: "save-failed")
            #if DEBUG
            logger.error("[\(engineName)] Failed to save after remote changes: \(error)")
            #endif
        }

        // Procesar pending freeze (soft-delete flip) + removed-self cleanup post-save.
        // Idempotente — freezeForSoftDelete + performRemovedSelfCleanup no-op si ya está limpio.
        let freezeZones = pendingFreezeZoneIDs
        let removedSelfZones = pendingRemovedSelfZoneNames
        pendingFreezeZoneIDs.removeAll()
        pendingRemovedSelfZoneNames.removeAll()

        for zoneID in freezeZones {
            guard let group = self.group(for: zoneID) else { continue }
            do {
                try GroupTransactionBridge.shared.freezeForSoftDelete(group: group)
            } catch {
                #if DEBUG
                logger.error("[\(engineName)] freezeForSoftDelete failed for \(zoneID): \(error.localizedDescription, privacy: .public)")
                #endif
            }
        }

        let removedSelfCtx = modelContext
        for zoneName in removedSelfZones {
            Task { @MainActor in
                await GroupService.shared.performRemovedSelfCleanup(zoneName: zoneName, context: removedSelfCtx)
            }
        }

        // Accumulate IDs and changeSets, then coalesce into a single deferred Task.
        // Avoids spawning N independent Tasks if N fetch events arrive in rapid succession.
        pendingBridgeExpenseIDs.formUnion(changeSet.newExpenses.map(\.id) + changeSet.modifiedExpenses.map(\.id))
        pendingBridgeSettlementIDs.formUnion(changeSet.newSettlements.map(\.id))
        pendingBridgeChangeSet.newExpenses.append(contentsOf: changeSet.newExpenses)
        pendingBridgeChangeSet.modifiedExpenses.append(contentsOf: changeSet.modifiedExpenses)
        pendingBridgeChangeSet.newSettlements.append(contentsOf: changeSet.newSettlements)
        pendingBridgeChangeSet.newMembers.append(contentsOf: changeSet.newMembers)
        pendingBridgeChangeSet.newPendingMembers.append(contentsOf: changeSet.newPendingMembers)

        // Cancel previous deferred task and restart — coalescing rapid events
        deferredBridgeTask?.cancel()
        deferredBridgeTask = Task { @MainActor [weak self] in
            // Let CKSyncEngine finish its current event batch before triggering more saves
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled, let self else { return }
            await self.processPendingRemoteChanges()
        }
    }

    /// Runs the coalesced post-fetch work: refresh membership flags (group store — always safe),
    /// process notifications, and bridge remote expenses/settlements to PERSONAL models.
    /// The bridge writes to the personal store (`YalaModel`, the one being imported), so it's gated
    /// by import QUIESCENCE (not the first importEvent, which is premature): if the import isn't
    /// quiescent the bridge is deferred (pending IDs kept) and retried after the quiet window.
    private func processPendingRemoteChanges() async {
        guard let modelContext else { return }

        // C-4 (PIEZA 2): drenar EN CALIENTE lo que el rescate acaba de insertar. Es una ACELERACIÓN, no
        // la garantía: la garantía de que la transacción de History sobreviva hasta que el drain la
        // consuma es el suelo del corte de `CloudSyncEngine.deleteHistorySafeCut`, que ya incluye el
        // canal de Grupos. Aquí, 50 ms después del batch y fuera del handler del engine, es donde el
        // subsistema ya hace sus saves; llamarlo dentro del handler sí sería jugar con fuego.
        if pendingRescueDrain {
            pendingRescueDrain = false
            if CloudSyncFlags.groupsBackendEnabled {
                GroupsSyncClient.shared.drainOnce(context: modelContext)
            }
        }

        // Membership flags + notifications: group store / no personal save → always safe; process & clear.
        await GroupService.shared.refreshCurrentUserFlags(context: modelContext)
        let accumulated = pendingBridgeChangeSet
        pendingBridgeChangeSet = RemoteChangeSet()
        if !accumulated.isEmpty {
            GroupNotificationService.shared.processRemoteChanges(accumulated)
        }
        SessionState.shared.markRemoteChangePending()

        // Join intents: si una zona aceptada acaba de materializar (GroupMeta en
        // este batch o en cualquier fetch posterior), asegurar el member del
        // current user. Guard barato: sin intents → una lectura de UserDefaults.
        if !PendingJoinStore.all().isEmpty {
            await GroupJoinReconciler.reconcile(trigger: .remoteInsert, context: modelContext)
        }
        // Con el cover del onboarding abierto en "esperando aprobación", detectar
        // la aprobación del admin sin depender de dataVersion.
        if GroupJoinIntentTracker.shared.phase == .pendingApproval,
           let trackedZone = GroupJoinIntentTracker.shared.zoneName,
           let status = currentMemberStatus(zoneName: trackedZone)
        {
            GroupJoinIntentTracker.shared.noteMemberResolved(zoneName: trackedZone, status: status)
        }

        // Bridge (personal models): gate by import quiescence.
        let expenseIDs = pendingBridgeExpenseIDs
        let settlementIDs = pendingBridgeSettlementIDs
        guard (!expenseIDs.isEmpty || !settlementIDs.isEmpty), GroupTransactionBridge.shared.isReady else { return }

        // Autoridad de quiescencia enrutada por storageMode (endurecimiento Grupos-v1):
        // en `.cloud` el mirror de CloudKit personal está OFF — la señal de
        // iCloudSyncService queda perpetuamente quieta (el gate de abajo pasaba "por
        // accidente afortunado"); la autoridad real es el propio motor
        // (SyncQuiescenceCoordinator, molde awaitPersonalStoreReady). En `.icloud` el
        // bloque vigente queda byte-idéntico.
        switch StorageModeSignalRouter.quiescenceSource(mode: CloudSyncFlags.storageMode) {
        case .cloudEngine:
            guard SyncQuiescenceCoordinator.shared.isQuiescentForEngineSaves else {
                logger.notice("SplitSync bridge deferred (cloud engine apply in flight) — retry in 8s")
                scheduleBridgeRetry(after: 8)
                return
            }
        case .icloudImport:
            // Gate by `isImporting` (not `isSyncing`): only a half-applied IMPORT crashes the personal
            // save; exports don't, so don't block the bridge during the user's normal exports.
            let decision = SubcategoryDedupGate.decide(
                now: .now,
                lastImportDate: iCloudSyncService.shared.lastSuccessfulImportDate,
                isSyncing: iCloudSyncService.shared.status.isImporting,
                lastDedupRunAt: nil
            )
            guard decision == .run else {
                // Import not quiescent → defer the bridge. The pending IDs stay in memory
                // (`pendingBridgeExpenseIDs`/`pendingBridgeSettlementIDs` are cleared only on the success
                // path below), and `scheduleBridgeRetry` re-runs this after the quiet window. We do NOT
                // persist `bridgePending` here: that `save()` would flush the half-imported personal graph
                // on the shared mainContext and trip SwiftData's `_assertionFailure`. (The dedicated group
                // context that once made it safe was removed — its `#Predicate` keypaths crashed record
                // export.) Accepted residual: killing the app during the rare incremental-import window
                // before the retry loses in-session recovery; CKSyncEngine re-delivers the change later.
                let retryAfter: TimeInterval
                if case .waitQuiescence(let t) = decision { retryAfter = max(t, 1) } else { retryAfter = 8 }
                logger.notice("SplitSync bridge deferred (import not quiescent: \(String(describing: decision), privacy: .public)) — retry in \(Int(retryAfter), privacy: .public)s")
                scheduleBridgeRetry(after: retryAfter)
                return
            }
        }

        pendingBridgeExpenseIDs.removeAll()
        pendingBridgeSettlementIDs.removeAll()
        if !expenseIDs.isEmpty {
            do { try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: Array(expenseIDs)) }
            catch {
                #if DEBUG
                logger.error("Failed to bridge remote expenses: \(error)")
                #endif
            }
        }
        if !settlementIDs.isEmpty {
            do { try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: Array(settlementIDs)) }
            catch {
                #if DEBUG
                logger.error("Failed to bridge remote settlements: \(error)")
                #endif
            }
        }
    }

    /// Re-runs the deferred bridge after the import quiet window (reuses `deferredBridgeTask` so a
    /// new fetch coalesces/cancels it). Single-flight via the task slot.
    private func scheduleBridgeRetry(after seconds: TimeInterval) {
        deferredBridgeTask?.cancel()
        deferredBridgeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            await self.processPendingRemoteChanges()
        }
    }

    /// ¿el current user es admin del grupo (o owner) en la zona? Cacheado por batch
    /// para evitar fetch repetido cuando llegan múltiples members de un mismo grupo.
    private func isCurrentUserAdminOfGroup(zoneName: String, context: ModelContext, cache: inout [String: Bool]) -> Bool {
        if let cached = cache[zoneName] { return cached }
        let descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneName && $0.isCurrentUser == true }
        )
        let result: Bool
        do {
            result = try context.fetch(descriptor).first?.isAdmin ?? false
        } catch {
            logger.error("isCurrentUserAdminOfGroup fetch failed for \(zoneName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            result = false
        }
        cache[zoneName] = result
        return result
    }

    private func handleSentDatabaseChanges(_ sent: CKSyncEngine.Event.SentDatabaseChanges, engineName: String) {
        for failure in sent.failedZoneSaves {
            #if DEBUG
            logger.error("[\(engineName)] Zone save failed: \(failure.zone.zoneID.zoneName) — \(failure.error.localizedDescription)")
            #endif
        }
    }

    private func handleSentRecordZoneChanges(_ sent: CKSyncEngine.Event.SentRecordZoneChanges, engineName: String) {
        // Always clean up pending tracking regardless of context availability
        for record in sent.savedRecords {
            pendingRecordSaves.remove(record.recordID)
        }

        // Store system fields from successfully saved records (for conflict-free future uploads).
        // Deferred during the export-only window: don't mutate/save the mainContext (the early
        // return is BEFORE storeSystemFields so the context isn't left dirty). System fields are a
        // conflict-resolution cache — a later upload re-captures them via serverRecordChanged. No
        // data loss; this is what lets the user invite/create during the window without crashing.
        if !sent.savedRecords.isEmpty, let modelContext, !deferMainContextWork("sentRecordZoneChanges.systemFields") {
            for record in sent.savedRecords {
                storeSystemFields(of: record, context: modelContext)
            }
            do {
                SaveBreadcrumb.willSave("SplitSync.sentRecordZoneChanges.systemFields")
                try modelContext.save()
                SaveBreadcrumb.didSave("SplitSync.sentRecordZoneChanges.systemFields")
            } catch {
                #if DEBUG
                logger.error("[\(engineName)] Failed to save system fields after successful upload: \(error)")
                #endif
            }
        }

        for failure in sent.failedRecordSaves {
            let ckError = failure.error as CKError

            // Logging INTENCIONALMENTE fuera de `#if DEBUG` (patrón SplitSync*): el incidente del
            // schema (isOpeningBalance, 27-jun→1-jul) fue invisible 4 días porque el rechazo solo
            // se logueaba en DEBUG. Sin PII — recordType + recordName (UUIDs) + código CKError.
            switch SplitSyncStartGate.classifyFailedSave(code: ckError.code) {
            case .conflict:
                // Conflict: server wins — accept server version and update local model
                handleConflict(failure: failure, engineName: engineName)

            case .zoneNotFound:
                // Group was deleted by owner — clean up local cache
                handleZoneNotFound(recordID: failure.record.recordID, engineName: engineName)

            case .unknownItem:
                // Record was deleted on server — remove local pending
                pendingRecordSaves.remove(failure.record.recordID)

            case .quota:
                syncStatus = .error("iCloud storage full")
                quotaFailedRecordIDs.insert(failure.record.recordID)
                logger.error("[\(engineName, privacy: .public)] Quota exceeded — \(failure.record.recordID.recordName, privacy: .public) queued for retry")

            case .definitiveRejection:
                // The server rejected the record itself (schema mismatch, permissions). CKSyncEngine
                // DROPS it from its pending queue and will NOT retry — and we don't re-enqueue inline
                // (a schema error would loop forever). The record keeps ckSystemFieldsData == nil, so
                // recoverUnsyncedRecordsIfNeeded re-enqueues it on the next launch (bounded retry).
                // The telemetry event is the canary: >0 in prod means a schema/permissions incident.
                logger.error("[\(engineName, privacy: .public)] Record save REJECTED (definitive): \(failure.record.recordType, privacy: .public) \(failure.record.recordID.recordName, privacy: .public) — CKError \(ckError.code.rawValue, privacy: .public) \(ckError.localizedDescription, privacy: .public)")
                MetricsService.canary(.cloudkitGroupRecordSaveRejected, detail: "code=\(ckError.code.rawValue)|\(failure.record.recordType)")

            case .transient:
                // Transport-level failures (network, rate limit, batch): CKSyncEngine retries these
                // on its own schedule.
                logger.error("[\(engineName, privacy: .public)] Record save failed (transient, will retry): \(failure.record.recordID.recordName, privacy: .public) — CKError \(ckError.code.rawValue, privacy: .public)")
            }
        }
    }

    // MARK: - Conflict Resolution (Server Wins)

    private func handleConflict(failure: CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave, engineName: String) {
        // Defer during the export-only window — the fetch after promotion re-applies the server
        // record (handleFetchedRecordZoneChanges) and reconciles the conflict safely.
        if deferMainContextWork("conflict") { return }
        guard let modelContext,
              let serverRecord = failure.error.serverRecord else {
            #if DEBUG
            logger.error("[\(engineName)] Conflict but no server record available")
            #endif
            return
        }

        // G6-3 (C2, GUARD SIMÉTRICO de PULL en la rama de conflicto): si el grupo ya está migrado
        // (`isBackendGroup=true`), NO aplicar el server record — su verdad vive en el backend y aceptarlo
        // (server-wins) pisaría las ediciones backend post-migración. La zona CloudKit es solo-lectura.
        //
        // EXCEPCIÓN QUIRÚRGICA (el MARCADOR): si el record en conflicto es el GroupMeta del propio grupo y el
        // marcador YA está estampado localmente (`movedToBackendAt != nil`), el conflicto significa que el save
        // del marcador PERDIÓ contra un changeTag más nuevo (p.ej. una edición de un member pre-freeze).
        // Dropearlo dejaría el marcador SIN subir para siempre (markerEnqueuedFlag=true → el boot-reconciler no
        // re-encola) → los members jamás sabrían que el grupo se movió. FIX: adoptar SOLO los system fields del
        // server record (changeTag fresco, SIN aplicar sus valores de campo — la verdad backend no se pisa) y
        // RE-ENCOLAR el marcador (el translator re-arma el CKRecord desde los system fields nuevos + los campos
        // locales, incluido el marcador → el próximo send gana).
        if backendGroupZoneNames(context: modelContext).contains(serverRecord.recordID.zoneID.zoneName) {
            if serverRecord.recordType == CKConstants.RecordType.groupMeta,
               let group = group(for: serverRecord.recordID.zoneID.zoneName),
               group.movedToBackendAt != nil,
               CKConstants.modelID(from: serverRecord.recordID) == group.id {
                group.ckSystemFieldsData = CKRecordTranslator.encodeSystemFields(of: serverRecord)
                do {
                    SaveBreadcrumb.willSave("SplitSync.conflict.markerRebase")
                    try modelContext.save()
                    SaveBreadcrumb.didSave("SplitSync.conflict.markerRebase")
                } catch {
                    #if DEBUG
                    logger.error("[\(engineName)] marker rebase save failed: \(error)")
                    #endif
                }
                enqueueMigrationMarker(group: group)
                pendingRecordSaves.remove(failure.record.recordID)
                return
            }
            GroupsSyncBreadcrumb.groupsCkPullSkippedBackendGroup(site: "conflict")
            pendingRecordSaves.remove(failure.record.recordID)
            return
        }

        // Race fix para serverRecordChanged en SplitGroup. Si el local tenía
        // isHiddenForAll/isArchived=true y server retorna stale false (otro device editó
        // metadata simultáneo), el server-wins default revertiría el flag. Mitigación:
        // capturar pre-state, dejar que apply pise, y re-aplicar la transición true.
        var preIsHiddenForAll: Bool = false
        var preIsArchived: Bool = false
        var splitGroupZoneID: String? = nil
        if serverRecord.recordType == CKConstants.RecordType.groupMeta,
           let modelID = CKConstants.modelID(from: serverRecord.recordID) {
            let descriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == modelID })
            let existingGroup: SplitGroup?
            do {
                existingGroup = try modelContext.fetch(descriptor).first
            } catch {
                logger.error("handleConflict: pre-state fetch failed: \(error.localizedDescription, privacy: .public)")
                existingGroup = nil
            }
            if let existing = existingGroup {
                preIsHiddenForAll = existing.isHiddenForAll
                preIsArchived = existing.isArchived
                splitGroupZoneID = existing.cloudKitZoneID
            }
        }

        // Accept server version: update local model from server record
        applyRemoteRecord(serverRecord, context: modelContext, engineName: engineName)
        do {
            SaveBreadcrumb.willSave("SplitSync.conflict")
            try modelContext.save()
            SaveBreadcrumb.didSave("SplitSync.conflict")
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Failed to save after conflict resolution: \(error)")
            #endif
        }

        // Re-aplicar transición si server stale revirtió flag local.
        if let zoneID = splitGroupZoneID,
           let group = self.group(for: zoneID) {
            var needsReSave = false
            if preIsHiddenForAll && !group.isHiddenForAll {
                group.isHiddenForAll = true
                needsReSave = true
                enqueueSave(modelID: group.id, group: group)
                Task { await GroupService.propagateBoolCustomKey(zoneID: zoneID, key: CKShareCustomKey.isHiddenForAll, value: true) }
            }
            if preIsArchived && !group.isArchived {
                group.isArchived = true
                needsReSave = true
                enqueueSave(modelID: group.id, group: group)
                Task { await GroupService.propagateBoolCustomKey(zoneID: zoneID, key: CKShareCustomKey.isArchived, value: true) }
            }
            if needsReSave {
                do {
                    SaveBreadcrumb.willSave("SplitSync.conflict.raceReapply")
                    try modelContext.save()
                    SaveBreadcrumb.didSave("SplitSync.conflict.raceReapply")
                    #if DEBUG
                    logger.info("[\(engineName)] Conflict race fix: re-applied transition for zone \(zoneID, privacy: .public)")
                    #endif
                } catch {
                    #if DEBUG
                    logger.error("[\(engineName)] Failed to save after race fix re-apply: \(error)")
                    #endif
                }
            }
        }

        // Remove from pending — server version is now authoritative
        pendingRecordSaves.remove(failure.record.recordID)

        #if DEBUG
        logger.info("[\(engineName)] Conflict resolved (server wins): \(failure.record.recordID.recordName)")
        #endif
    }

    // MARK: - Zone Not Found Handling

    private func handleZoneNotFound(recordID: CKRecord.ID, engineName: String) {
        // Defer during the export-only window — the fetched database change (zone deletion) after
        // promotion cleans up the local cache safely.
        if deferMainContextWork("zoneNotFound") { return }
        guard let modelContext else { return }

        let zoneName = recordID.zoneID.zoneName
        guard let groupID = CKConstants.groupID(from: zoneName) else { return }

        // G6-3 (C5): un save pendiente que racea con el borrado de la zona de un grupo MIGRADO (owner que
        // borró su copia congelada) NO debe destruir los datos locales — la verdad vive en el backend.
        if let localGroup = group(for: zoneName),
           localGroup.isBackendGroup || localGroup.movedToBackendAt != nil {
            GroupsSyncBreadcrumb.groupsCkPullSkippedBackendGroup(site: "zoneNotFound")
            pendingRecordSaves.remove(recordID)
            return
        }

        // Delete all local data for this group
        deleteGroupCache(groupID: groupID, context: modelContext)
        do {
            SaveBreadcrumb.willSave("SplitSync.zoneNotFound")
            try modelContext.save()
            SaveBreadcrumb.didSave("SplitSync.zoneNotFound")
        } catch {
            #if DEBUG
            logger.error("[\(engineName)] Failed to clean up group \(groupID) after zone not found: \(error)")
            #endif
        }

        pendingRecordSaves.remove(recordID)

        #if DEBUG
        logger.info("[\(engineName)] Zone not found — cleaned up group: \(zoneName)")
        #endif
    }

    /// Remove all local models for a group (zone deleted or participant removed).
    private func deleteGroupCache(groupID: UUID, context: ModelContext) {
        let zoneName = CKConstants.zoneName(for: groupID)

        do {
            // Delete group
            let groupDesc = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == groupID })
            if let group = try context.fetch(groupDesc).first {
                context.delete(group)
            }

            // Delete members by zone
            let memberDesc = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName })
            for member in try context.fetch(memberDesc) { context.delete(member) }

            let shareDesc = FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneName })
            for share in try context.fetch(shareDesc) { context.delete(share) }

            // Delete expenses by zone
            let expenseDesc = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName })
            for expense in try context.fetch(expenseDesc) { context.delete(expense) }

            // Delete settlements by zone
            let settlementDesc = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName })
            for settlement in try context.fetch(settlementDesc) { context.delete(settlement) }
        } catch {
            #if DEBUG
            logger.error("deleteGroupCache: Failed for group \(groupID): \(error)")
            #endif
        }
    }

    // MARK: - Pending Changes Purge

    private func purgePendingChanges(for zoneID: CKRecordZone.ID, engine: CKSyncEngine) {
        let pendingToRemove = engine.state.pendingRecordZoneChanges.filter { change in
            switch change {
            case .saveRecord(let recordID):
                return recordID.zoneID == zoneID
            case .deleteRecord(let recordID):
                return recordID.zoneID == zoneID
            @unknown default:
                return false
            }
        }
        if !pendingToRemove.isEmpty {
            engine.state.remove(pendingRecordZoneChanges: pendingToRemove)
        }

        let pendingDBChanges = engine.state.pendingDatabaseChanges.filter {
            if case .deleteZone(let id) = $0 { return id == zoneID }
            if case .saveZone(let zone) = $0 { return zone.zoneID == zoneID }
            return false
        }
        if !pendingDBChanges.isEmpty {
            engine.state.remove(pendingDatabaseChanges: pendingDBChanges)
        }
    }

    /// Clear system fields and re-enqueue all records for a group (used after encryptedDataReset).
    private func reuploadGroupRecords(groupID: UUID, zoneID: CKRecordZone.ID, engine: CKSyncEngine, context: ModelContext) {
        let zoneName = CKConstants.zoneName(for: groupID)

        do {
            // Clear system fields and re-enqueue each model type
            let groups = try context.fetch(FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == groupID }))
            for group in groups {
                group.ckSystemFieldsData = nil
                let recordID = CKConstants.recordID(for: group.id, in: zoneID)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }

            let members = try context.fetch(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for member in members {
                member.ckSystemFieldsData = nil
                let recordID = CKConstants.recordID(for: member.id, in: zoneID)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }

            let expenses = try context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for expense in expenses {
                expense.ckSystemFieldsData = nil
                let recordID = CKConstants.recordID(for: expense.id, in: zoneID)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }

            let shares = try context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for share in shares {
                share.ckSystemFieldsData = nil
                let recordID = CKConstants.recordID(for: share.id, in: zoneID)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }

            let settlements = try context.fetch(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName }))
            for settlement in settlements {
                settlement.ckSystemFieldsData = nil
                let recordID = CKConstants.recordID(for: settlement.id, in: zoneID)
                engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
            }

            SaveBreadcrumb.willSave("SplitSync.reuploadGroupRecords")
            try context.save()
            SaveBreadcrumb.didSave("SplitSync.reuploadGroupRecords")
        } catch {
            #if DEBUG
            logger.error("reuploadGroupRecords: Failed for group \(groupID): \(error)")
            #endif
        }
    }

    // MARK: - Remote Record Application

    private func applyRemoteRecord(_ record: CKRecord, context: ModelContext, engineName: String) {
        guard let modelID = CKConstants.modelID(from: record.recordID) else { return }

        switch record.recordType {
        case CKConstants.RecordType.groupMeta:
            applyGroupMeta(record, modelID: modelID, context: context, engineName: engineName)
        case CKConstants.RecordType.splitExpense:
            applyExpense(record, modelID: modelID, context: context)
        case CKConstants.RecordType.splitMember:
            applyMember(record, modelID: modelID, context: context)
        case CKConstants.RecordType.splitShare:
            applyShare(record, modelID: modelID, context: context)
        case CKConstants.RecordType.splitSettlement:
            applySettlement(record, modelID: modelID, context: context)
        default:
            break
        }
    }

    // MARK: - Rescate de pull (C-4 PIEZA 2)

    /// ¿Existe ya una fila local para este record? Pregunta por ID con el helper CONCRETO por tipo
    /// (regla inviolable: `#Predicate` concreto, nunca genérico-protocolo).
    ///
    /// Deliberadamente NO consulta los Sets del pre-fetch del batch: cubren 3 de los 5 tipos y su
    /// `catch` los deja vacíos. Un tipo desconocido cuenta como EXISTENTE — la dirección segura, porque
    /// «no sé» nunca debe traducirse en «adóptalo».
    func recordExistsLocally(_ record: CKRecord, context: ModelContext) -> Bool {
        guard let modelID = CKConstants.modelID(from: record.recordID) else { return true }
        switch record.recordType {
        case CKConstants.RecordType.groupMeta: return splitGroup(byID: modelID, in: context) != nil
        case CKConstants.RecordType.splitExpense: return splitExpense(byID: modelID, in: context) != nil
        case CKConstants.RecordType.splitMember: return splitMember(byID: modelID, in: context) != nil
        case CKConstants.RecordType.splitShare: return splitShare(byID: modelID, in: context) != nil
        case CKConstants.RecordType.splitSettlement: return splitSettlement(byID: modelID, in: context) != nil
        default: return true
        }
    }

    /// Adopta un record de una zona YA MIGRADA **solo si la fila no existe**. Es el candado del
    /// invariante 1 de `GroupPullRescueGate`: «el rescate JAMÁS actualiza».
    ///
    /// Por qué no reusa `applyRemoteRecord`: aquél despacha a `applyExpense`/`applyShare`/
    /// `applySettlement`, y los tres hacen `CKRecordTranslator.update(existing, from:)` cuando la fila
    /// existe. Bastaría un Set del pre-fetch desactualizado —o su `catch` vacío— para que ese camino
    /// pisara una edición backend post-migración, que es EXACTAMENTE el agujero que G6-3 (C2) cerró.
    /// Aquí la existencia se vuelve a preguntar contra el store, en el mismo instante de la mutación, y
    /// la rama de update sencillamente no se escribe.
    ///
    /// Los tipos son los de `GroupPullRescueGate.rescuableTypes` y nada más: `GroupMeta` y `SplitMember`
    /// caen al `default` (invariante 3). El `default` es silencioso a propósito — el caller ya emitió el
    /// breadcrumb con el motivo (`notRescuable`) antes de llegar aquí.
    ///
    /// - Returns: `true` si insertó (y por tanto hay algo que drenar al backend).
    @discardableResult
    func applyRemoteRecordIfAbsent(_ record: CKRecord, context: ModelContext, engineName: String) -> Bool {
        guard let modelID = CKConstants.modelID(from: record.recordID),
              let entity = GroupPullRescueGate.entityName(forRecordType: record.recordType),
              !recordExistsLocally(record, context: context)
        else { return false }

        let inserted: Bool
        switch record.recordType {
        case CKConstants.RecordType.splitExpense:
            if let model = CKRecordTranslator.expense(from: record) {
                context.insert(model)
                inserted = true
            } else { inserted = false }
        case CKConstants.RecordType.splitShare:
            if let model = CKRecordTranslator.share(from: record) {
                context.insert(model)
                inserted = true
            } else { inserted = false }
        case CKConstants.RecordType.splitSettlement:
            if let model = CKRecordTranslator.settlement(from: record) {
                context.insert(model)
                inserted = true
            } else { inserted = false }
        default:
            inserted = false
        }

        guard inserted else {
            // El translator rechazó el record (campos obligatorios ausentes/corruptos). No es un rescate
            // y NO se cuenta como tal; se nombra para que no se lea como un descarte del guard.
            GroupsSyncBreadcrumb.groupsCkPullSkippedBackendGroup(site: "applyRemote", reason: "translatorRejected")
            return false
        }

        #if DEBUG
        logger.info("[\(engineName)] C-4 rescate: adoptado \(entity) \(modelID) de zona migrada")
        #endif
        GroupsSyncBreadcrumb.groupsCkPullRescued(entity: entity)
        return true
    }

    private func applyGroupMeta(_ record: CKRecord, modelID: UUID, context: ModelContext, engineName: String) {
        do {
            let descriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == modelID })
            if let existing = try context.fetch(descriptor).first {
                // Capturar previo antes del update para detectar flip a hidden.
                let wasHidden = existing.isHiddenForAll
                CKRecordTranslator.update(existing, from: record)
                existing.isOwner = (engineName == "private")
                if !wasHidden && existing.isHiddenForAll {
                    pendingFreezeZoneIDs.insert(existing.cloudKitZoneID)
                }
            } else if let newGroup = CKRecordTranslator.group(from: record) {
                newGroup.isOwner = (engineName == "private")
                // Baseline de primer import (bug "Jür se unió al grupo"): un
                // SplitGroup que llega por FETCH implica que sus members
                // preexistentes están por llegar — suprimir sus notifs de
                // membership hasta que el ciclo de fetch de la zona complete
                // (didFetchRecordZoneChanges) o venza la ventana de 15 min.
                // Aplica a AMBOS engines: shared = invitado recién unido;
                // private = reinstalación/segundo device del owner.
                newGroup.initialMemberImportStartedAt = .now
                context.insert(newGroup)
                // Initial-fetch del invitado fresh-install POST soft-delete: el SplitGroup llega
                // ya con isHiddenForAll=true → encolar (idempotente, no-op si no hay TX).
                if newGroup.isHiddenForAll {
                    pendingFreezeZoneIDs.insert(newGroup.cloudKitZoneID)
                }
            }
        } catch {
            #if DEBUG
            logger.error("SplitGroup fetch failed for \(modelID): \(error)")
            #endif
        }
    }

    private func applyExpense(_ record: CKRecord, modelID: UUID, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == modelID })
            if let existing = try context.fetch(descriptor).first {
                CKRecordTranslator.update(existing, from: record)
            } else if let newExpense = CKRecordTranslator.expense(from: record) {
                context.insert(newExpense)
            }
        } catch {
            #if DEBUG
            logger.error("SplitExpense fetch failed for \(modelID): \(error)")
            #endif
        }
    }

    private func applyMember(_ record: CKRecord, modelID: UUID, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.id == modelID })
            if let existing = try context.fetch(descriptor).first {
                // Snapshot (active && currentUser) ANTES del update — necesario para detectar
                // que el admin remoto pasó a este device de active a removed.
                let wasActiveAndCurrent = existing.isActive && existing.isCurrentUser
                CKRecordTranslator.update(existing, from: record)
                if SoftDeleteObserverLogic.shouldTriggerRemovedSelfCleanup(
                    wasActiveAndCurrentUser: wasActiveAndCurrent,
                    newStatus: existing.memberStatus
                ) {
                    pendingRemovedSelfZoneNames.insert(existing.groupZoneID)
                }
            } else if let newMember = CKRecordTranslator.member(from: record) {
                context.insert(newMember)
                // Edge case conocido: invitado fresh-install + admin ya lo removió previamente
                // → newMember entra con isCurrentUser=false (default init) y el observer no
                // dispara. `refreshCurrentUserFlags` setea isCurrentUser=true después pero el
                // grupo queda visible hasta retap link. Bug latente documentado (no fix aquí).
            }
        } catch {
            #if DEBUG
            logger.error("SplitMember fetch failed for \(modelID): \(error)")
            #endif
        }
    }

    private func applyShare(_ record: CKRecord, modelID: UUID, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<SplitShare>(predicate: #Predicate { $0.id == modelID })
            if let existing = try context.fetch(descriptor).first {
                CKRecordTranslator.update(existing, from: record)
            } else if let newShare = CKRecordTranslator.share(from: record) {
                context.insert(newShare)
            }
        } catch {
            #if DEBUG
            logger.error("SplitShare fetch failed for \(modelID): \(error)")
            #endif
        }
    }

    private func applySettlement(_ record: CKRecord, modelID: UUID, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.id == modelID })
            if let existing = try context.fetch(descriptor).first {
                CKRecordTranslator.update(existing, from: record)
            } else if let newSettlement = CKRecordTranslator.settlement(from: record) {
                context.insert(newSettlement)
            }
        } catch {
            #if DEBUG
            logger.error("SplitSettlement fetch failed for \(modelID): \(error)")
            #endif
        }
    }

    // MARK: - Remote Deletion

    private func applyRemoteDeletion(recordID: CKRecord.ID, recordType: CKRecord.RecordType, context: ModelContext) {
        guard let modelID = CKConstants.modelID(from: recordID) else { return }

        switch recordType {
        case CKConstants.RecordType.groupMeta:
            if let model = splitGroup(byID: modelID, in: context) { context.delete(model) }
        case CKConstants.RecordType.splitExpense:
            if let model = splitExpense(byID: modelID, in: context) { context.delete(model) }
        case CKConstants.RecordType.splitMember:
            if let model = splitMember(byID: modelID, in: context) { context.delete(model) }
        case CKConstants.RecordType.splitShare:
            if let model = splitShare(byID: modelID, in: context) { context.delete(model) }
        case CKConstants.RecordType.splitSettlement:
            if let model = splitSettlement(byID: modelID, in: context) { context.delete(model) }
        default:
            break
        }
    }

    // MARK: - System Fields Persistence

    /// Store CKRecord system fields on the matching local model so future uploads include the changeTag.
    private func storeSystemFields(of record: CKRecord, context: ModelContext) {
        guard let modelID = CKConstants.modelID(from: record.recordID) else { return }
        let data = CKRecordTranslator.encodeSystemFields(of: record)

        switch record.recordType {
        case CKConstants.RecordType.groupMeta:
            if let model = splitGroup(byID: modelID, in: context) {
                model.ckSystemFieldsData = data
            }
        case CKConstants.RecordType.splitExpense:
            if let model = splitExpense(byID: modelID, in: context) {
                model.ckSystemFieldsData = data
            }
        case CKConstants.RecordType.splitMember:
            if let model = splitMember(byID: modelID, in: context) {
                model.ckSystemFieldsData = data
            }
        case CKConstants.RecordType.splitShare:
            if let model = splitShare(byID: modelID, in: context) {
                model.ckSystemFieldsData = data
            }
        case CKConstants.RecordType.splitSettlement:
            if let model = splitSettlement(byID: modelID, in: context) {
                model.ckSystemFieldsData = data
            }
        default:
            break
        }
    }

    // MARK: - Record Building (for nextRecordZoneChangeBatch)

    func buildRecord(for recordID: CKRecord.ID) -> CKRecord? {
        guard let modelContext,
              let modelID = CKConstants.modelID(from: recordID) else { return nil }

        let zoneID = recordID.zoneID

        // Try each model type to find the one matching this recordID
        if let group = splitGroup(byID: modelID, in: modelContext) {
            return CKRecordTranslator.record(from: group, in: zoneID)
        }
        if let expense = splitExpense(byID: modelID, in: modelContext) {
            return CKRecordTranslator.record(from: expense, in: zoneID)
        }
        if let member = splitMember(byID: modelID, in: modelContext) {
            return CKRecordTranslator.record(from: member, in: zoneID)
        }
        if let share = splitShare(byID: modelID, in: modelContext) {
            return CKRecordTranslator.record(from: share, in: zoneID)
        }
        if let settlement = splitSettlement(byID: modelID, in: modelContext) {
            return CKRecordTranslator.record(from: settlement, in: zoneID)
        }

        return nil
    }

    // MARK: - By-ID fetch (CONCRETE predicates — do NOT genericize)
    //
    // These MUST use a concrete `#Predicate<ConcreteType> { $0.id == id }`. A generic,
    // protocol-constrained `#Predicate<T> { $0.id == id }` (e.g. a `where T: SomeProtocol { var id }`
    // helper — there used to be a `HasUUID` one here, now removed) resolves `$0.id` to the
    // protocol-witness keypath, which SwiftData CANNOT match to the concrete `\SplitGroup.id`
    // registered in the Schema → `DataUtilities.swift:85 Fatal error: Couldn't find \SplitGroup.<…>`
    // when the fetch runs (crashed `buildRecord` during `sendChanges` = generar enlace / forzar
    // sync). Concrete predicates — like every other fetch in this file (`group(for:)`,
    // `handleConflict`, …) — resolve fine on any `ModelContext`.

    private func splitGroup(byID id: UUID, in context: ModelContext) -> SplitGroup? {
        fetchFirst(FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.id == id }), in: context)
    }
    private func splitExpense(byID id: UUID, in context: ModelContext) -> SplitExpense? {
        fetchFirst(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id }), in: context)
    }
    private func splitMember(byID id: UUID, in context: ModelContext) -> SplitMember? {
        fetchFirst(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.id == id }), in: context)
    }
    private func splitShare(byID id: UUID, in context: ModelContext) -> SplitShare? {
        fetchFirst(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.id == id }), in: context)
    }
    private func splitSettlement(byID id: UUID, in context: ModelContext) -> SplitSettlement? {
        fetchFirst(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.id == id }), in: context)
    }

    /// Executes a CONCRETE `FetchDescriptor` and returns the first result. The descriptor's
    /// predicate is built per-type at the call site, so no protocol-witness keypath is involved.
    private func fetchFirst<T: PersistentModel>(_ descriptor: FetchDescriptor<T>, in context: ModelContext) -> T? {
        do {
            return try context.fetch(descriptor).first
        } catch {
            logger.error("fetchFirst(\(String(describing: T.self))) failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

enum SplitSyncError: LocalizedError {
    case engineNotInitialized

    var errorDescription: String? {
        switch self {
        case .engineNotInitialized:
            // Clear, actionable copy (was the opaque "CKSyncEngine not initialized").
            return L10n.Groups.Errors.syncPreparing
        }
    }
}

// MARK: - CKSyncEngine Delegate

/// Routes CKSyncEngine events to SplitSyncManager.
/// State persistence is handled synchronously (nonisolated).
/// Model updates are dispatched to @MainActor.
private final class SplitSyncDelegate: CKSyncEngineDelegate {

    nonisolated(unsafe) private weak var manager: SplitSyncManager?

    init(manager: SplitSyncManager) {
        self.manager = manager
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        // Discard callbacks from an engine that was recreated by `enableAutoSync()`. Crucial for
        // the `.stateUpdate` path below: a stale event would be saved under the wrong file name
        // (its identity no longer matches) and corrupt the live engine's serialized state.
        guard manager?.isCurrentEngine(syncEngine) == true else { return }

        // State updates: persist synchronously (file I/O, nonisolated-safe)
        if case .stateUpdate(let update) = event {
            let name = manager?.isPrivateEngine(syncEngine) == true ? "private" : "shared"
            manager?.saveState(update.stateSerialization, name: name)
            return
        }

        // All other events: await MainActor for model access (proper ordering)
        await MainActor.run {
            self.manager?.processEvent(event, engine: syncEngine)
        }
    }

    func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pendingChanges = syncEngine.state.pendingRecordZoneChanges
        guard !pendingChanges.isEmpty else { return nil }

        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pendingChanges) { recordID in
            await MainActor.run {
                self.manager?.buildRecord(for: recordID)
            }
        }
    }
}
