//
//  GroupsSyncClient.swift
//  Yala
//
//  Cliente del canal de sync de GRUPOS → backend (incremento G2). CLASE NUEVA, DARK detrás de
//  `CloudSyncFlags.groupsBackendEnabled` (SIEMPRE `false` esta fase): captura los cambios del store de
//  Grupos del SwiftData History (drain), los sube al gateway (`POST /groups/push`), baja los deltas
//  remotos (`GET /groups/pull`) y los aplica a los `@Model` `Split*` locales — todo con anclas/token/
//  reloj PROPIOS del canal, sin tocar el motor personal (`CloudSyncEngine`) ni su `personalEntityNames`.
//
//  El muro anti-fuga es BIDIRECCIONAL: el drain de Grupos filtra por `GroupEntityEmissionMap.
//  groupEntityNames` (disjunto de `personalEntityNames`) → NUNCA emite entidades personales, y el drain
//  personal NUNCA emite `Split*`. El History es por-CONTAINER, así que ambos canales lo leen con cursores
//  independientes (`GroupSyncCursor` vs `SyncCursor`).
//
//  Echo-suppression: el drain DESCARTA las transacciones cuyo author sea `Self.outboxSaveAuthor` — el
//  MISMO autor con el que persiste su outbox Y aplica los deltas remotos (así el apply no se re-drena).
//  El bridge a modelos personales (`GroupTransactionBridge`) escribe bajo autor por DEFECTO (que el drain
//  PERSONAL sí captura → las TX puenteadas se sincronizan por el canal personal) — nunca bajo este autor.
//
//  DUPLICACIÓN CONSCIENTE (G2, decisión de la sesión): el patrón de drain (token + `lastDrainedTxAt` +
//  `recoverIfHistoryTokenIncomparable` + dedup `(syncID,hlc,op)` + HLC monótono persistido) se DUPLICA
//  del motor personal en vez de factorizarse, para NO tocar `CloudSyncEngine` esta noche. La refactor a
//  un core compartido queda diferida.
//
//  SIMPLIFICACIONES DARK (documentadas): el apply es full-row last-pulled-wins (el server ya hace el
//  merge por-unidad; el LWW por-campo client-side de Grupos se difiere), sin cuarentena / unit-clock /
//  espejo App Group / clasificación de reason (audit-only del personal). El ciclo de vida (cadencia,
//  backoff, observadores de remote-change) se cablea cuando el canal encienda (G4+).
//

import Foundation
import OSLog
import SwiftData

@MainActor
final class GroupsSyncClient {

    // MARK: Singleton (DARK)

    // COMPOSICIÓN de producción (AJUSTE review #7): inyecta el provider registrar-backed del device token para
    // el header `X-Yala-Device-Token` del push (G8-3). El init designado tiene default `{ nil }` (los tests no
    // se acoplan al singleton); solo aquí, en el `.shared`, se ata a `PushTokenRegistrar.shared.storedToken`.
    static let shared = GroupsSyncClient(
        deviceTokenProvider: { PushTokenRegistrar.shared.storedToken })

    // MARK: Constantes

    /// Autor del CONTEXTO con el que el canal de Grupos persiste su outbox Y aplica deltas remotos. El
    /// drain DESCARTA las transacciones con este autor (anti-auto-captura / echo suppression).
    static let outboxSaveAuthor = "GroupsSyncOutbox"

    /// Los 5 nombres de clase del store de Grupos (muro anti-fuga). Delegado al mapa de emisión (SSOT).
    static var groupEntityNames: Set<String> { GroupEntityEmissionMap.groupEntityNames }

    private let logger = Logger(subsystem: "com.yala.app", category: "GroupsSync")

    // MARK: Dependencias inyectables

    private let baseURL: URL
    // Providers `@MainActor`: leen singletons main-actor-isolados (`CloudAuthService`). El cliente es
    // `@MainActor` → invocarlos no cruza actor.
    private let tokenProvider: @MainActor () async -> String?
    /// H-2026-07-18-4: FUERZA el refresh del access token para el retry-once del 401 (el auto-refresh del
    /// SDK solo dispara con <30s de margen → un `tokenProvider()` normal en la ventana de expiry devolvería
    /// el MISMO token vencido). Inyectable (default = `CloudAuthService.shared.forceRefreshAccessToken`;
    /// los tests inyectan uno hermético). `@MainActor` (el cliente ya lo es → no cruza actor).
    private let forceRefreshTokenProvider: @MainActor () async -> String?
    private let attestProvider: @MainActor () async -> String?
    private let urlSession: SyncHTTPSession
    private let sessionCheck: @MainActor () -> Bool
    /// El `sub` de la sesión (auth uid). Inyectable para el RE-DRIVE del dead-letter (A2). Default: el
    /// singleton de sesión. `@MainActor` (el cliente ya lo es → no cruza actor).
    private let currentUserIDProvider: @MainActor () -> String?
    /// G8-3: el device token APNs local para el header `X-Yala-Device-Token` del push (el server excluye SOLO
    /// este device del autor del fan-out → el 2º device del autor SÍ recibe el silent push). Provider inyectado;
    /// el DEFAULT del init es `{ nil }` (AJUSTE review #7 — NO acoplar los tests existentes a
    /// `PushTokenRegistrar.shared`/UserDefaults, que viola la regla de singletons). La COMPOSICIÓN de producción
    /// (`.shared`) inyecta el provider registrar-backed. El header solo se añade si non-nil.
    private let deviceTokenProvider: @MainActor () -> String?
    private let now: () -> Date
    /// H-2026-07-18-5: bump VIVO del refresh de UI tras un ciclo de pull que aplicó deltas que CAMBIAN
    /// contenido (`deltasApplied > 0`). Con la vista de DETALLE montada, `markRemoteChangePending` (por-
    /// página) solo setea el flag diferido — nadie bumpea `dataVersion` en vivo, así que la lista/balance
    /// no refrescaban hasta salir/entrar o pull-to-refresh. Este closure bumpea `dataVersion` POR-CICLO (no
    /// por-página: un ciclo puede aplicar N páginas → un solo bump; los VMs de Grupos ya debouncan 150ms).
    /// DEFAULT = `SessionState.shared.incrementDataVersion()`. El `markRemoteChangePending` por-página se
    /// CONSERVA como red del caso background/vista-no-montada (redundancia aceptada: 1 reload extra en la
    /// próxima navegación, coalescido por el debounce). Inyectable para tests (contar llamadas). `@MainActor`
    /// (el cliente ya lo es → no cruza actor). NO se gatea por `applicationState`: el archivo no importa
    /// UIKit y un reload en background es inofensivo (una vista no montada no recomputa su body).
    private let onRemoteChangesApplied: @MainActor () -> Void
    /// Fase 2 (2.1): consumidor de las notificaciones locales de grupo. El canal CloudKit clasificaba los
    /// records del fetch en un `RemoteChangeSet` y se lo pasaba a `GroupNotificationService` desde
    /// `SplitSyncManager.processPendingRemoteChanges`; con el transporte camino de la Fase 3, el apply del
    /// canal backend es quien tiene que emitirlo. DEFAULT = `GroupNotificationService.shared`. Inyectable
    /// para tests (capturar el set sin montar el singleton ni `NotificationService`). `@MainActor` (el
    /// cliente ya lo es → no cruza actor).
    private let onRemoteChanges: @MainActor (RemoteChangeSet) -> Void
    /// Cliente del snapshot Merkle de Grupos (`GET /groups/merkle`) — endurecimiento B1. Inyectable para
    /// tests (stub HTTP). Solo se usa con el flag ON (la verificación se cablea en `syncCycleOnce`).
    private let merkleClient: GroupsMerkleClient
    /// Espejo App Group del `GroupSyncOutbox` (durabilidad ante lightweight migration — B2, molde
    /// `SyncOutboxMirror` del personal). `nil` = mirroring deshabilitado (App Group no disponible /
    /// tests que no lo ejercitan). SOLO espeja filas PENDIENTES (dead-letters excluidas).
    private let outboxMirror: GroupsOutboxMirror?

    // MARK: Estado

    private var clock: HLCClock
    private var isDraining = false
    private var pendingDrain = false
    private var bridgeRetryTask: Task<Void, Never>?

    /// G8-2 (AJUSTE review #3): el `mainContext` compartido retenido en `startIfEligible` para que
    /// `syncNowFromPush` (invocado desde el AppDelegate SIN un `ModelContext` del caller) pueda ciclar el
    /// canal. STRONG (molde `SplitSyncManager.swift:54` / `CloudSyncRuntime.swift:122` — es el contexto de
    /// vida de proceso; `weak` arriesgaría un nil espurio). `nil` = el canal no arrancó en este proceso.
    private var context: ModelContext?

    /// B2: anti-solape del CICLO "one in-flight, one queued" (molde `CloudSyncRuntime.
    /// performCycleCoalesced`). Con el piggyback 5.6 hay DOS callers posibles de un ciclo (el loop
    /// propio y el runtime personal) — sin este guard, dos ciclos concurrentes drenarían/pushearían
    /// el mismo outbox en paralelo.
    private var isCycling = false
    private var pendingCycle = false

    /// B2 (MEDIA del review adversarial — guardia de GENERACIÓN, molde `sessionEpoch` del runtime
    /// personal): la cancelación del loop es COOPERATIVA (solo se chequea al tope y post-sleep) — un
    /// ciclo suspendido en el `await` del push/pull RESUME después de `teardownForSignOut` y, sin esta
    /// guardia, su vuelta encolada correría `drainOnce → writeMirror → save` REPOBLANDO el espejo recién
    /// purgado (archivos con montos sobreviven la purga de sign-out — el boot-wipe NO borra el dir del
    /// espejo → minaría la garantía M1). `teardownForSignOut` lo incrementa; el ciclo lo captura al
    /// entrar y lo RE-VERIFICA tras cada await mayor (post-push, post-pull, pre-apply de cada request)
    /// — generación cambiada ⇒ abortar SIN escribir.
    private(set) var teardownGeneration = 0

    // MARK: Ciclo de vida del loop (G4)

    /// Tarea del loop de cadencia (single-instance: `startIfEligible` no re-arranca si vive). `nil` fuera
    /// del loop (se limpia en el `defer` de `runLoop`).
    private var loopTask: Task<Void, Never>?
    /// A5: un 403 (cuenta no disponible) → `stopUntilRelaunch`. Este flag impide re-arrancar el loop en el
    /// MISMO proceso (mirror de la semántica del personal `SyncCadencePolicy.stopUntilRelaunch`).
    private var stoppedUntilRelaunch = false
    /// Contador de transitorios consecutivos para el backoff exponencial (reset al `.completed`/stop).
    private var consecutiveTransients = 0
    /// Sleep INYECTABLE entre vueltas del loop (default `Task.sleep`) — los tests inyectan uno que no
    /// duerme de verdad (regla: jamás `Task.sleep > 0.5s` en tests).
    var sleeper: (TimeInterval) async -> Void = { seconds in
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Tope de iteraciones del pull de una vuelta (server que no converge → breadcrumb + transitorio).
    private static let pullMaxIterations = 20

    // MARK: Merkle (endurecimiento B1)

    /// `true` cuando la ÚLTIMA vuelta de `pullUntilExhausted` terminó `.completed` (guard A-3 del Merkle:
    /// molde `CloudSyncEngine.lastPullCycleCompleted`). Un pull transitorio/expirado lo deja `false`.
    private(set) var lastPullCycleCompleted = false
    /// Pulls COMPLETOS desde la última verificación Merkle (avanza SOLO en ciclos `.completed`, como el
    /// personal). La cadencia usa `SyncCadencePolicy.shouldRunMerkle` TAL CUAL.
    private(set) var completedPullsSinceMerkle = 0
    /// Reloj de la última verificación Merkle (condición temporal de la cadencia). `nil` = nunca verificado.
    private(set) var lastMerkleAt: Date?
    /// La remediación (reset de cursor + re-pull) corre UNA vez por sesión — molde
    /// `CloudSyncRuntime.didRemediateMerkleThisSession`. Se resetea en `resetMerkleSessionState` (teardown).
    private(set) var didRemediateGroupMerkleThisSession = false

    // MARK: Guard del token de History (molde HALLAZGO 2)

    private(set) var historyTokenValidated = false
    private static let historyTokenSlack: TimeInterval = 60
    private(set) var historyTokenIncomparableCount = 0
    private(set) var historyTokenRecoveredCount = 0

    // MARK: Seams de test

    /// Cuando `true`, `drainOnce` NO avanza el token del cursor tras persistir el outbox (simula un kill
    /// entre el save del outbox y el avance del token). SOLO tests.
    var _testSuppressTokenAdvance = false

    /// Fija el `context` retenido sin correr el gate/loop de `startIfEligible` (para probar
    /// `syncNowFromPush` aislado). SOLO tests.
    func _testSetContext(_ ctx: ModelContext) { self.context = ctx }

    // MARK: Init

    init(
        baseURL: URL = ProxyConfig.baseURL,
        tokenProvider: @escaping @MainActor () async -> String? = { await CloudAuthService.shared.accessToken() },
        attestProvider: @escaping @MainActor () async -> String? = { nil },
        urlSession: SyncHTTPSession = URLSession.shared,
        sessionCheck: @escaping @MainActor () -> Bool = { CloudAuthService.shared.hasSession },
        currentUserIDProvider: @escaping @MainActor () -> String? = { CloudAuthService.shared.currentUserID },
        now: @escaping () -> Date = { .now },
        nodeID: NodeID = NodeID.generate(),
        merkleClient: GroupsMerkleClient? = nil,
        outboxMirror: GroupsOutboxMirror? = GroupsOutboxMirror(),
        deviceTokenProvider: @escaping @MainActor () -> String? = { nil },
        forceRefreshTokenProvider: @escaping @MainActor () async -> String? =
            { await CloudAuthService.shared.forceRefreshAccessToken() },
        onRemoteChangesApplied: @escaping @MainActor () -> Void = { SessionState.shared.incrementDataVersion() },
        onRemoteChanges: @escaping @MainActor (RemoteChangeSet) -> Void =
            { GroupNotificationService.shared.processRemoteChanges($0) }
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.forceRefreshTokenProvider = forceRefreshTokenProvider
        self.attestProvider = attestProvider
        self.urlSession = urlSession
        self.sessionCheck = sessionCheck
        self.currentUserIDProvider = currentUserIDProvider
        self.deviceTokenProvider = deviceTokenProvider
        self.now = now
        self.onRemoteChangesApplied = onRemoteChangesApplied
        self.onRemoteChanges = onRemoteChanges
        self.clock = HLCClock(nodeID: nodeID)
        // Default: mismo baseURL + los providers de sesión del canal (el Merkle de Grupos NO manda
        // capability-set). Los tests inyectan uno con `StubHTTPSession`.
        self.merkleClient = merkleClient ?? GroupsMerkleClient(
            baseURL: baseURL, tokenProvider: tokenProvider, attestProvider: attestProvider,
            urlSession: urlSession)
        self.outboxMirror = outboxMirror
    }

    // MARK: - Arranque (DARK)

    /// Arranca el LOOP de cadencia del canal de Grupos SOLO si `groupsBackendEnabled && hasSession`
    /// (SESIÓN VIVA, no storageMode — la persona solo-grupos). Con el flag `false` (SIEMPRE esta fase) es
    /// un NO-OP TOTAL: retorna ANTES de tocar la red o crear modelos. Call-sites DARK en `AppBootstrapper`
    /// (cold boot `trigger: nil`; foreground resume `trigger: "foreground"`) y en el modifier de invite
    /// backend (post-sign-in `trigger: "post-sign-in"`). Single-instance (no re-arranca si el loop vive);
    /// un 403 previo (`stoppedUntilRelaunch`) tampoco re-arranca en este proceso (A5).
    ///
    /// **La decisión de (re)arranque del loop propio vive en `GroupsLoopRestartLogic.shouldStart`** (pura,
    /// testeada) — SSOT de flag/sesión/stop/single-instance/D8, para no partir la verdad entre guards
    /// dispersos. `trigger` NO-nil emite `groupsLoopRestarted` SOLO si el loop se crea de verdad.
    ///
    /// **D8 (H-2026-07-18-4): AHORA es SEGURO llamarlo MID-SESSION** (foreground / post-sign-in), a
    /// diferencia de antes (que exigía SOLO cold boot): `shouldStart` incorpora el guard de mount-mismatch
    /// (`secondaryActive && !secondaryMounted`, idéntico a `CloudSyncRuntime.canRunDomain`) — en la ventana
    /// de entrada de la sesión secundaria (store del DUEÑO montado + descriptor secundario ya persistido)
    /// bloquea ANTES del rehydrate, así ni el rehydrate ni el loop drenan la History del dueño a la cuenta
    /// entrante. El re-arranque en foreground/post-sign-in resucita un loop que murió en silencio (401
    /// transitorio en la ventana de expiry → `sessionExpired` → `break loop`; el retry-once del 401 de
    /// abajo cubre el caso común, este re-arranque es la red del residual).
    ///
    /// **[R3] Coordinación anti-doble-loop (B2):** si el runtime PERSONAL va a cadenciar
    /// (`syncRuntimeEnabled && CloudSyncRuntime.canRunDomain()`), Grupos NO arranca loop propio — el
    /// ciclo de Grupos corre como paso 5.6 (piggyback) de `CloudSyncRuntime.performCycle` (un solo
    /// `fetchHistory` cadenciado del container, sin dos loops de 60s sin coordinación). NO es `.cloud`
    /// a secas: `canRunDomain()` exige además fase de migración ESTABLE + sin mount-mismatch — en
    /// `.cloud` con fase TRANSICIONAL el personal NO cadencia y Grupos DEBE correr su loop propio o
    /// quedaría sin sync toda la migración. Residual documentado: las TRANSICIONES (sign-out, cambio
    /// de modo, fin de migración) las media el relaunch en v1 — el modo elegido aquí no se re-evalúa
    /// en caliente. El rehydrate del espejo (B2) corre en AMBOS modos (es red de boot, no de loop).
    func startIfEligible(context: ModelContext, trigger: String? = nil) {
        guard CloudSyncFlags.groupsBackendEnabled, sessionCheck() else { return }
        // G8-2 (AJUSTE review #3): retener el context AQUÍ — DESPUÉS del guard flag+sesión, ANTES del
        // return del piggyback. Sin esto, en modo piggyback (personal cadencia) el context quedaría
        // sin fijar y `syncNowFromPush` devolvería siempre false.
        self.context = context
        // B2 (cinturón del call-site de AppBootstrapper G2) — M1/D8 (G5-C): con el flag ON la sesión
        // SECUNDARIA SÍ corre el canal de Grupos (loop + rehydrate) sobre SU store `YalaGroups-Secondary`
        // y su `sub`; el rehydrate del espejo App Group filtra DURO por `userID` (owner-scoping) → las
        // entries del dueño se ignoran. Con el flag OFF esta condición reproduce el guard de secundaria
        // de antes (byte-idéntico: por el guard flag+sesión ya retornó, se conserva por simetría).
        guard CloudSyncFlags.groupsBackendEnabled || !SecondarySessionStore.isActive() else { return }

        // SSOT del (re)arranque del loop propio (incluye el guard D8 de mount-mismatch — hace seguro el
        // call mid-session). El piggyback NO lo modela: `loopAlive==false` ⇒ shouldStart==true ⇒ el
        // rehydrate corre y el early-return del piggyback decide después.
        guard GroupsLoopRestartLogic.shouldStart(
            flagOn: CloudSyncFlags.groupsBackendEnabled,
            hasSession: sessionCheck(),
            stoppedUntilRelaunch: stoppedUntilRelaunch,
            loopAlive: loopTask != nil,
            secondaryActive: SecondarySessionStore.isActive(),
            secondaryMounted: SwiftDataConfiguration.secondaryStoreMounted
        ) else { return }

        // B2: red de boot — re-insertar del espejo App Group lo que una lightweight migration se llevó.
        rehydrateOutboxFromMirror(context: context)
        // [R3] Personal cadencia ⇒ grupos piggyback (paso 5.6); si no ⇒ loop propio.
        if CloudSyncFlags.syncRuntimeEnabled && CloudSyncRuntime.canRunDomain() { return }
        // A7: canario de push fallando permanente (filas ya en dead-letter al arrancar el loop).
        let deadLettered = (try? deadLetteredCount(context)) ?? 0
        if deadLettered > 0 { GroupsSyncBreadcrumb.groupsDeadLetteredCount(deadLettered) }
        loopTask = Task { @MainActor in await self.runLoop(context: context) }
        // Solo cuando el loop se creó de verdad (no en piggyback / no-op): breadcrumb de re-arranque.
        if let trigger { GroupsSyncBreadcrumb.groupsLoopRestarted(trigger: trigger) }
    }

    /// El loop de cadencia: cada vuelta = `syncCycleOnce` → delay por `SyncCadencePolicy` → repetir.
    /// `sessionExpired` (401) TERMINA el loop (re-arrancable por el próximo `startIfEligible`);
    /// `accountUnavailable` (403) TERMINA + arma `stoppedUntilRelaunch` (no re-arranca en este proceso).
    private func runLoop(context: ModelContext) async {
        defer { loopTask = nil }                        // A6: liberar el single-instance al salir
        loop: while true {
            // A6: cinturón contra store muerto en la ventana wipe→token-nil (sesión caída entre vueltas).
            guard sessionCheck() else {
                GroupsSyncBreadcrumb.groupsLoopStopped(reason: "session-check-failed")
                break loop
            }

            let outcome = await syncCycleOnceCoalesced(context: context)
            switch outcome {
            case .transient: consecutiveTransients += 1
            case .coalesced: break  // sin señal de red — contador INTACTO (molde runtime personal)
            default: consecutiveTransients = 0
            }

            let action = SyncCadencePolicy.nextAction(
                outcome: outcome, consecutiveTransients: consecutiveTransients)
            let delay: TimeInterval
            switch action {
            case .scheduleNext(let t), .backoff(let t):
                delay = t
            case .stopUntilSignIn:
                GroupsSyncBreadcrumb.groupsLoopStopped(reason: "session-expired")
                break loop                               // A5: re-arrancable por próximo startIfEligible
            case .stopUntilRelaunch:
                stoppedUntilRelaunch = true              // A5: no re-arranca este proceso
                GroupsSyncBreadcrumb.groupsLoopStopped(reason: "account-unavailable")
                break loop
            }

            await sleeper(delay)
            guard !Task.isCancelled else {               // A6: cancelado durante el sleep → salir
                GroupsSyncBreadcrumb.groupsLoopStopped(reason: "cancelled")
                break loop
            }
        }
    }

    /// Cancela el loop. B2: cableado a los 3 paths de `CloudSessionSignOut` vía `teardownForSignOut()`.
    func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
        resetMerkleSessionState()  // B1: frontera de sesión → re-armar la remediación (una-vez-por-sesión)
    }

    /// Teardown del canal de Grupos en el sign-out (B2): detiene el loop + purga el espejo App Group
    /// (contiene MONTOS — red M1(a), espejo del `mirror?.purgeAll()` de `teardownGuestSession` del
    /// personal). Lo llaman los 3 paths de `CloudSessionSignOut` EXPLÍCITAMENTE junto a cada
    /// `teardownGuestSession()` — decisión B2 documentada: NO va dentro de `teardownGuestSession` para
    /// no acoplar el runtime personal al canal de Grupos (el runtime no debe conocer grupos).
    /// Idempotente; seguro con el flag OFF (loop nil + espejo vacío → no-ops).
    func teardownForSignOut() {
        teardownGeneration += 1  // aborta el ciclo EN VUELO en su próximo re-chequeo post-await (MEDIA)
        stopLoop()
        outboxMirror?.purgeAll()
    }

    /// Anti-solape del ciclo "one in-flight, one queued" (B2, molde `performCycleCoalesced` del runtime):
    /// si ya hay un ciclo en vuelo, encola a lo sumo UNO y devuelve `.coalesced` (sin señal de red — el
    /// caller no lo cuenta como transitorio). Con el piggyback 5.6 este es el punto de entrada de AMBOS
    /// callers (loop propio Y runtime personal). La vuelta ENCOLADA re-verifica la generación: un
    /// teardown durante el ciclo en vuelo la descarta (arrancarla drenaría → writeMirror sobre el espejo
    /// recién purgado).
    @discardableResult
    func syncCycleOnceCoalesced(context: ModelContext) async -> SyncCadencePolicy.CadenceOutcome {
        if isCycling {
            pendingCycle = true
            return .coalesced
        }
        isCycling = true
        defer { isCycling = false }
        let generation = teardownGeneration
        var last: SyncCadencePolicy.CadenceOutcome = .coalesced
        repeat {
            pendingCycle = false
            guard generation == teardownGeneration else { return .coalesced }  // teardown → ni la encolada
            last = await syncCycleOnce(context: context)
        } while pendingCycle
        return last
    }

    /// G8-2: dispara UN ciclo del canal desde un silent push (`didReceiveRemoteNotification`, rama `yala`),
    /// carreado contra `timeout` (iOS da ~30s de background; el caller pasa 20s de margen). SIN `ModelContext`
    /// del caller — usa el `context` retenido en `startIfEligible`. Devuelve `true` si el ciclo COMPLETÓ
    /// dentro del timeout (→ `.newData`), `false` en cualquier gate no satisfecho / timeout / ciclo
    /// no-completado (→ `.noData`). Gates SIN red: flag OFF, sin sesión, `stoppedUntilRelaunch`, o `context`
    /// nil (el canal no arrancó en este proceso). Idempotente con la doble fuente CloudKit (§16d): el
    /// coalescing anti-solape de `syncCycleOnceCoalesced` ya lo garantiza.
    ///
    /// Residual documentado (AJUSTE review #5): un launch puramente en BACKGROUND por silent push puede no
    /// ejecutar el `.task` del bootstrap (YalaApp) ⇒ el canal no arranca en ese proceso, `context` es nil y
    /// esto devuelve false (.noData); el pull real ocurre al próximo foreground (consistencia eventual v1).
    @discardableResult
    func syncNowFromPush(timeout: Duration) async -> Bool {
        guard CloudSyncFlags.groupsBackendEnabled, sessionCheck(), !stoppedUntilRelaunch,
              context != nil else { return false }
        // Lanza AMBOS hijos ANTES del primer `next()` (AJUSTE review #7). El hijo del ciclo puede sobrevivir
        // al timeout tras `cancelAll` — benigno: el push es chunked con dedupe por `client_mutation_id` y el
        // próximo ciclo re-emite. `self` (clase @MainActor) es Sendable; el hijo lee `self.context` en el
        // MainActor (NO captura el `ModelContext` no-Sendable a través de la frontera del task).
        return await withTaskGroup(of: Bool.self) { group in
            group.addTask { @MainActor [weak self] in
                guard let self, let ctx = self.context else { return false }
                return await self.syncCycleOnceCoalesced(context: ctx) == .completed
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    /// UNA vuelta del ciclo: captura local → push → pull-hasta-agotar → apply. Devuelve el
    /// `CadenceOutcome` NORMALIZADO que consume el loop. DARK (solo corre con el flag ON).
    @discardableResult
    func syncCycleOnce(context: ModelContext) async -> SyncCadencePolicy.CadenceOutcome {
        // Guardia de generación (MEDIA): capturada al entrar (el drain de abajo es SÍNCRONO — la
        // generación no puede cambiar entre la captura y su writeMirror), re-verificada tras cada await.
        let generation = teardownGeneration
        drainOnce(context: context)
        let push = await pushPending(context: context)
        guard generation == teardownGeneration else { return .coalesced }  // teardown durante el push
        if let stop = GroupsSyncCadence.stopOutcome(push: push) { return stop }
        let pull = await pullUntilExhausted(context: context)
        guard generation == teardownGeneration else { return .coalesced }  // teardown durante el pull

        // B1: cadencia Merkle — tras un pull COMPLETO (guard A-3), avanza el contador y, si
        // `SyncCadencePolicy.shouldRunMerkle` (reusada TAL CUAL) lo pide, verifica TODOS los grupos con cursor.
        // Un ciclo INCOMPLETO (transient/401/403) deja el flag en false → la verificación se salta (molde
        // `SyncApplyEngine`: divergencia esperada, no incidente).
        if case .completed = pull {
            lastPullCycleCompleted = true
            completedPullsSinceMerkle += 1
            if SyncCadencePolicy.shouldRunMerkle(
                completedPullsSinceMerkle: completedPullsSinceMerkle, lastMerkleAt: lastMerkleAt, now: now()) {
                await runGroupMerkleVerification(context: context, now: now())
            }
        } else {
            lastPullCycleCompleted = false
        }
        return GroupsSyncCadence.outcome(pull: pull)
    }

    /// Nº de filas de outbox en dead-letter (rechazo permanente). Canario A7 al arrancar el loop.
    private func deadLetteredCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(
            FetchDescriptor<GroupSyncOutbox>(predicate: #Predicate { $0.rejectedReason != nil }))
    }

    // MARK: - Seams de test del loop

    /// La tarea del loop en vuelo (para que los tests la aguarden sin dormir). SOLO tests.
    var _testLoopTask: Task<Void, Never>? { loopTask }

    /// Marca el gate A-3 del Merkle "último pull completado" (que en producción solo setea un pull
    /// `.completed`) para probar `verifyGroupIntegrity` sin correr un ciclo entero. SOLO tests.
    func _testMarkPullCompleted() { lastPullCycleCompleted = true }

    // MARK: - Drain (captura del History → GroupSyncOutbox)

    /// Ejecuta UNA vuelta de captura. Re-entrante (coalescing one-in-flight/one-queued, molde personal).
    func drainOnce(context: ModelContext) {
        guard !isDraining else {
            pendingDrain = true
            return
        }
        isDraining = true
        defer { isDraining = false }
        repeat {
            pendingDrain = false
            performDrain(context: context)
        } while pendingDrain
    }

    private func performDrain(context: ModelContext) {
        do {
            let cursor = try loadOrCreateCursor(context)
            loadClock(from: cursor)
            let token = decodeToken(cursor.historyTokenData)

            let lookups = try buildLookups(context)
            // C2-bis (CRÍTICO #1): partición POR-GRUPO simétrica del push. Solo los grupos del canal BACKEND
            // (`isBackendGroup`) drenan al outbox — sin este muro, editar un grupo CloudKit bajo flag ON
            // drenaría sus filas al backend (`group_id` inexistente server-side → dead-letters permanentes +
            // doble-sync CKSyncEngine∥backend). El PULL ya está scoped por cursores/memberships; la asimetría
            // era solo del push.
            let backendZoneIDs = try backendGroupZoneIDs(context)
            let tokenTxns = try fetchHistory(after: token, context: context)

            let tokenGuard = recoverIfHistoryTokenIncomparable(
                cursor: cursor, tokenTxns: tokenTxns, context: context)
            if tokenGuard.validatedByCompare { historyTokenValidated = true }
            let txns = tokenGuard.txns

            var seen = try existingOutboxKeys(context)

            var rows: [PendingGroupRow] = []
            var advancedToken: DefaultHistoryToken?
            var advancedTxAt: Date?
            for tx in txns {
                // Anti-auto-captura (echo suppression): descartar los writes del propio canal SIN avanzar
                // el high-water (si avanzaran, cada avance escribiría el cursor → loop).
                if tx.author == Self.outboxSaveAuthor { continue }
                do {
                    for change in tx.changes {
                        let entityName = change.changedPersistentIdentifier.entityName
                        // Muro anti-fuga: solo entidades del store de Grupos (personal lo captura el otro canal).
                        guard Self.groupEntityNames.contains(entityName) else { continue }
                        try translate(change, entityName: entityName, tx: tx, lookups: lookups,
                                      backendZoneIDs: backendZoneIDs, rows: &rows, seen: &seen)
                    }
                } catch {
                    // `clock.send` lanzó (drift/overflow): abortar en la FRONTERA de esta transacción.
                    #if DEBUG
                    logger.error("GroupsSync: clock drift/overflow al traducir tx: \(error)")
                    #endif
                    break
                }
                advancedToken = tx.token
                advancedTxAt = tx.timestamp
            }

            if !rows.isEmpty {
                // B2 (regla Q3): espejo App Group ANTES del insert+save, en la MISMA vuelta síncrona
                // (sin `await` entremedias — autosave no puede invertir el orden fila-durable-sin-espejo).
                writeMirror(rows: rows)
                try saveWithAuthor(context) {
                    for row in rows { context.insert(row.makeModel()) }
                }
            }

            if !_testSuppressTokenAdvance {
                if let reanchor = tokenGuard.reanchor {
                    try saveWithAuthor(context) {
                        cursor.historyTokenData = try encodeToken(reanchor.token)
                        cursor.lastDrainedTxAt = reanchor.txAt
                        cursor.clockLatestHLC = clock.latest?.description
                    }
                    historyTokenValidated = true
                    historyTokenRecoveredCount += 1
                    GroupsSyncBreadcrumb.groupsHistoryTokenRecovered()
                } else if let advancedToken {
                    try saveWithAuthor(context) {
                        cursor.historyTokenData = try encodeToken(advancedToken)
                        cursor.lastDrainedTxAt = advancedTxAt
                        cursor.clockLatestHLC = clock.latest?.description
                    }
                    historyTokenValidated = true
                }
            }
        } catch {
            #if DEBUG
            logger.error("GroupsSync: drain error: \(error)")
            #endif
        }
    }

    // MARK: - Traducción de un cambio (dispatch por tipo concreto)

    private struct Lookups {
        var splitGroup: [PersistentIdentifier: SplitGroup] = [:]
        var splitExpense: [PersistentIdentifier: SplitExpense] = [:]
        var splitShare: [PersistentIdentifier: SplitShare] = [:]
        var splitSettlement: [PersistentIdentifier: SplitSettlement] = [:]
    }

    /// C2-bis: conjunto de `group_id` (= `cloudKitZoneID`) de los grupos del canal BACKEND. `#Predicate`
    /// CONCRETO por tipo (regla del repo — nada de genéricos-protocolo).
    private func backendGroupZoneIDs(_ context: ModelContext) throws -> Set<String> {
        let descriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.isBackendGroup == true })
        return Set(try context.fetch(descriptor).map(\.cloudKitZoneID))
    }

    private func translate(
        _ change: HistoryChange,
        entityName: String,
        tx: DefaultHistoryTransaction,
        lookups: Lookups,
        backendZoneIDs: Set<String>,
        rows: inout [PendingGroupRow],
        seen: inout Set<String>
    ) throws {
        switch entityName {
        case GroupSyncEntityType.splitExpense:
            try translateChange(change, type: SplitExpense.self, entityType: entityName,
                                emission: GroupEntityEmissionMap.splitExpense,
                                liveSyncID: { $0.id }, liveGroupID: { $0.groupZoneID },
                                tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                tombstoneGroupID: { $0.tombstone[\.groupZoneID] as? String },
                                updateOnly: false, lookup: lookups.splitExpense, tx: tx,
                                backendZoneIDs: backendZoneIDs, rows: &rows, seen: &seen)
        case GroupSyncEntityType.splitShare:
            try translateChange(change, type: SplitShare.self, entityType: entityName,
                                emission: GroupEntityEmissionMap.splitShare,
                                liveSyncID: { $0.id }, liveGroupID: { $0.groupZoneID },
                                tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                tombstoneGroupID: { $0.tombstone[\.groupZoneID] as? String },
                                updateOnly: false, lookup: lookups.splitShare, tx: tx,
                                backendZoneIDs: backendZoneIDs, rows: &rows, seen: &seen)
        case GroupSyncEntityType.splitSettlement:
            try translateChange(change, type: SplitSettlement.self, entityType: entityName,
                                emission: GroupEntityEmissionMap.splitSettlement,
                                liveSyncID: { $0.id }, liveGroupID: { $0.groupZoneID },
                                tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                tombstoneGroupID: { $0.tombstone[\.groupZoneID] as? String },
                                updateOnly: false, lookup: lookups.splitSettlement, tx: tx,
                                backendZoneIDs: backendZoneIDs, rows: &rows, seen: &seen)
        case GroupSyncEntityType.splitGroup:
            // UPDATE-only: el grupo nace vía RPC create_group (G3+) → NO se emite su INSERT. `group_id` del
            // wire = `cloudKitZoneID` (la identidad server-side); `syncID` local = `id` (dedup).
            try translateChange(change, type: SplitGroup.self, entityType: entityName,
                                emission: GroupEntityEmissionMap.splitGroup,
                                liveSyncID: { $0.id }, liveGroupID: { $0.cloudKitZoneID },
                                tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                tombstoneGroupID: { $0.tombstone[\.cloudKitZoneID] as? String },
                                updateOnly: true, lookup: lookups.splitGroup, tx: tx,
                                backendZoneIDs: backendZoneIDs, rows: &rows, seen: &seen)
        default:
            // SplitMember (pull-only) y cualquier otro: sin emisión.
            return
        }
    }

    private func translateChange<T: PersistentModel>(
        _ change: HistoryChange,
        type: T.Type,
        entityType: String,
        emission: EntityEmission<T>,
        liveSyncID: (T) -> UUID,
        liveGroupID: (T) -> String,
        tombstoneSyncID: (DefaultHistoryDelete<T>) -> UUID?,
        tombstoneGroupID: (DefaultHistoryDelete<T>) -> String?,
        updateOnly: Bool,
        lookup: [PersistentIdentifier: T],
        tx: DefaultHistoryTransaction,
        backendZoneIDs: Set<String>,
        rows: inout [PendingGroupRow],
        seen: inout Set<String>
    ) throws {
        switch change {
        case .insert(let insert):
            guard !updateOnly else { return }  // split_groups: el INSERT nace vía RPC → no emitir
            guard insert is DefaultHistoryInsert<T> else { return }
            guard let model = lookup[insert.changedPersistentIdentifier] else { return }
            let groupID = liveGroupID(model)
            // C2-bis: solo drena si el grupo es del canal backend (el push de grupos CloudKit iría a un
            // `group_id` inexistente server-side → dead-letter permanente).
            guard backendZoneIDs.contains(groupID) else {
                GroupsSyncBreadcrumb.groupsDrainSkippedNonBackendGroup(entity: entityType)
                return
            }
            try appendUpsert(model: model, emission: emission, syncID: liveSyncID(model),
                             groupID: groupID, entityType: entityType,
                             changedColumns: emission.columns, tx: tx, rows: &rows, seen: &seen)

        case .update(let update):
            guard let typed = update as? DefaultHistoryUpdate<T> else { return }
            guard let model = lookup[typed.changedPersistentIdentifier] else { return }
            let groupID = liveGroupID(model)
            guard backendZoneIDs.contains(groupID) else {
                GroupsSyncBreadcrumb.groupsDrainSkippedNonBackendGroup(entity: entityType)
                return
            }
            var changedColumns: Set<String> = []
            for keyPath in typed.updatedAttributes {
                if let columns = emission.columnKeyPaths[keyPath as PartialKeyPath<T>] {
                    changedColumns.formUnion(columns)
                }
            }
            guard !changedColumns.isEmpty else { return }
            try appendUpsert(model: model, emission: emission, syncID: liveSyncID(model),
                             groupID: groupID, entityType: entityType,
                             changedColumns: changedColumns, tx: tx, rows: &rows, seen: &seen)

        case .delete(let delete):
            guard let typed = delete as? DefaultHistoryDelete<T> else { return }
            guard let syncID = tombstoneSyncID(typed), let groupID = tombstoneGroupID(typed) else {
                #if DEBUG
                logger.error("GroupsSync: tombstone sin identidad preservada para \(entityType, privacy: .public)")
                #endif
                return
            }
            // C2-bis: un tombstone cuyo grupo NO está en el set backend se salta. Incluye el cascade de leave
            // de un grupo backend (`performLocalCleanupAndDelete` ya borró el SplitGroup → su zona salió del
            // set): CORRECTO — el server aplica el leave vía RPC y RLS rechazaría esos tombstones igual.
            // H3 (review): el mismo skip también salta UPSERTS previos aún no drenados de ese grupo
            // (crear→gastar→salir antes del primer drain) — correcto igual: tras el leave, RLS rechazaría
            // esas filas (`not_authorized`), solo se ahorra el round-trip al dead-letter.
            guard backendZoneIDs.contains(groupID) else {
                GroupsSyncBreadcrumb.groupsDrainSkippedNonBackendGroup(entity: entityType)
                return
            }
            try appendRow(op: .tombstone, syncID: syncID, groupID: groupID, entityType: entityType,
                          tx: tx, rows: &rows, seen: &seen) { _ in ("{}", nil) }

        @unknown default:
            return
        }
    }

    private func appendUpsert<T: AnyObject>(
        model: T,
        emission: EntityEmission<T>,
        syncID: UUID,
        groupID: String,
        entityType: String,
        changedColumns: Set<String>,
        tx: DefaultHistoryTransaction,
        rows: inout [PendingGroupRow],
        seen: inout Set<String>
    ) throws {
        try appendRow(op: .upsert, syncID: syncID, groupID: groupID, entityType: entityType,
                      tx: tx, rows: &rows, seen: &seen) { hlc in
            let result = DeltaEmitter.emit(model: model, emission: emission,
                                           changedColumns: changedColumns, hlc: hlc)
            let fieldsJSON: String
            do {
                fieldsJSON = try Canonc1Codec.encode(result.fields,
                                                     groupedColumns: Set(emission.groupByColumn.keys))
            } catch {
                #if DEBUG
                logger.error("GroupsSync: codec c1 rechazó \(entityType, privacy: .public): \(error)")
                #endif
                return nil
            }
            return (fieldsJSON, encodeFieldHlcs(result.fieldHlcs))
        }
    }

    private func appendRow(
        op: SyncOutboxOp,
        syncID: UUID,
        groupID: String,
        entityType: String,
        tx: DefaultHistoryTransaction,
        rows: inout [PendingGroupRow],
        seen: inout Set<String>,
        makePayload: (String) -> (fieldsJSON: String, fieldHlcsJSON: String?)?
    ) throws {
        let hlc = try clock.send(now: tx.timestamp).description
        let key = dedupKey(syncID: syncID, hlc: hlc, op: op)
        guard !seen.contains(key) else { return }
        seen.insert(key)
        guard let payload = makePayload(hlc) else { return }
        rows.append(PendingGroupRow(
            syncID: syncID,
            groupID: groupID,
            entityType: entityType,
            op: op,
            hlc: hlc,
            clientMutationID: UUID(),
            fieldsJSON: payload.fieldsJSON,
            fieldHlcsJSON: payload.fieldHlcsJSON,
            author: tx.author ?? "",
            createdAt: now()
        ))
    }

    // MARK: - Lookups

    private func buildLookups(_ context: ModelContext) throws -> Lookups {
        var lookups = Lookups()
        lookups.splitGroup = try index(SplitGroup.self, context: context)
        lookups.splitExpense = try index(SplitExpense.self, context: context)
        lookups.splitShare = try index(SplitShare.self, context: context)
        lookups.splitSettlement = try index(SplitSettlement.self, context: context)
        return lookups
    }

    private func index<T: PersistentModel>(
        _ type: T.Type, context: ModelContext
    ) throws -> [PersistentIdentifier: T] {
        let models = try context.fetch(FetchDescriptor<T>())
        var map: [PersistentIdentifier: T] = [:]
        for model in models { map[model.persistentModelID] = model }
        return map
    }

    // MARK: - Cursor / token / reloj

    func loadOrCreateCursor(_ context: ModelContext) throws -> GroupSyncCursor {
        var descriptor = FetchDescriptor<GroupSyncCursor>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first { return existing }
        let cursor = GroupSyncCursor()
        context.insert(cursor)
        try saveWithAuthor(context) { }
        return cursor
    }

    private func loadClock(from cursor: GroupSyncCursor) {
        guard let raw = cursor.clockLatestHLC else { return }
        do {
            let hlc = try HLC.parse(raw)
            clock = HLCClock(nodeID: clock.nodeID, latest: hlc)
        } catch {
            #if DEBUG
            logger.error("GroupsSync: loadClock parse falló para \(raw, privacy: .public): \(error)")
            #endif
        }
    }

    /// Ejecuta `body` y hace `context.save()` bajo `Self.outboxSaveAuthor`, restaurando el autor previo.
    private func saveWithAuthor(_ context: ModelContext, _ body: () throws -> Void) throws {
        let previous = context.author
        context.author = Self.outboxSaveAuthor
        defer { context.author = previous }
        try body()
        try context.save()
    }

    private func decodeToken(_ data: Data?) -> DefaultHistoryToken? {
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(DefaultHistoryToken.self, from: data)
        } catch {
            return nil
        }
    }

    private func encodeToken(_ token: DefaultHistoryToken) throws -> Data {
        try JSONEncoder().encode(token)
    }

    private func fetchHistory(
        after token: DefaultHistoryToken?, context: ModelContext
    ) throws -> [DefaultHistoryTransaction] {
        guard let token else {
            return try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        }
        do {
            return try context.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token > token }))
        } catch {
            return try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        }
    }

    private func existingOutboxKeys(_ context: ModelContext) throws -> Set<String> {
        let existing = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
        var keys: Set<String> = []
        for row in existing {
            guard let op = SyncOutboxOp(rawValue: row.opRaw) else { continue }
            keys.insert(dedupKey(syncID: row.syncID, hlc: row.hlc, op: op))
        }
        return keys
    }

    private func dedupKey(syncID: UUID, hlc: String, op: SyncOutboxOp) -> String {
        "\(syncID.uuidString)\u{1}\(hlc)\u{1}\(op.rawValue)"
    }

    private func encodeFieldHlcs(_ fieldHlcs: [String: String]) -> String {
        guard !fieldHlcs.isEmpty else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return String(decoding: try encoder.encode(fieldHlcs), as: UTF8.self)
        } catch {
            return "{}"
        }
    }

    // MARK: - Espejo del outbox (B2, molde CloudSyncEngine A1/§d.5)

    /// Escribe el espejo `.atomic` de cada fila NUEVA de un drain, ANTES del insert+save (mismo cuerpo
    /// síncrono, regla Q3). Best-effort: un fallo se loguea y NO aborta el drain (la History es backup
    /// redundante). No-op sin espejo o sin `sub` de sesión (owner-scoping M1: sin identidad no se sella).
    private func writeMirror(rows: [PendingGroupRow]) {
        guard let mirror = outboxMirror, let userID = currentUserIDProvider() else { return }
        for row in rows {
            do {
                try mirror.write(row.mirrorEntry(userID: userID))
            } catch {
                #if DEBUG
                logger.error("GroupsSync: espejo write falló para \(row.entityType, privacy: .public): \(error)")
                #endif
            }
        }
    }

    /// Espeja una fila de outbox YA materializada (`@Model`) — para el RE-DRIVE (una dead-letter revivida
    /// vuelve a ser pendiente y re-entra al espejo). Mismo best-effort que `writeMirror(rows:)`.
    private func writeMirrorEntry(for row: GroupSyncOutbox) {
        guard let mirror = outboxMirror, let userID = currentUserIDProvider() else { return }
        do {
            try mirror.write(GroupsOutboxMirrorEntry(
                userID: userID, syncID: row.syncID, groupID: row.groupID, entityType: row.entityType,
                op: row.opRaw, hlc: row.hlc, clientMutationID: row.clientMutationID,
                fieldsJSON: row.fieldsJSON, fieldHlcsJSON: row.fieldHlcsJSON,
                tombstoneReason: row.tombstoneReason, author: GroupsOutboxMirror.author,
                createdAt: row.createdAt))
        } catch {
            #if DEBUG
            logger.error("GroupsSync: espejo write (revive) falló: \(error)")
            #endif
        }
    }

    /// Re-hidrata el `GroupSyncOutbox` desde el espejo App Group tras una lightweight migration que
    /// recreó la tabla (B2, molde `CloudSyncEngine.rehydrateOutboxFromMirror`). DIFF INCONDICIONAL con
    /// owner-scoping DURO: solo procesa `entriesForUser(sub actual)` (las de otra identidad se IGNORAN);
    /// por cada entry cuyo `(syncID, hlc, op)` NO tiene fila en el outbox (vivas Y dead-letter — una
    /// dead-letter presente NO se revive por esta vía), re-inserta con los valores ORIGINALES bajo
    /// `outboxSaveAuthor` (el drain no re-captura el save). Idempotente. Un archivo huérfano (crash entre
    /// purga y remove) es benigno: se re-sube y el backend deduplica por `client_mutation_id`.
    func rehydrateOutboxFromMirror(context: ModelContext) {
        guard let mirror = outboxMirror, let userID = currentUserIDProvider() else { return }
        let entries = mirror.entriesForUser(userID)
        guard !entries.isEmpty else { return }

        let liveKeys: Set<String>
        do { liveKeys = try existingOutboxKeys(context) } catch {
            #if DEBUG
            logger.error("GroupsSync: rehydrate fetch(GroupSyncOutbox) falló: \(error)")
            #endif
            return
        }

        var missing: [GroupsOutboxMirrorEntry] = []
        for entry in entries {
            guard let op = SyncOutboxOp(rawValue: entry.op) else { continue }
            if !liveKeys.contains(dedupKey(syncID: entry.syncID, hlc: entry.hlc, op: op)) {
                missing.append(entry)
            }
        }
        guard !missing.isEmpty else { return }

        do {
            try saveWithAuthor(context) {
                for entry in missing {
                    guard let op = SyncOutboxOp(rawValue: entry.op) else { continue }
                    context.insert(GroupSyncOutbox(
                        syncID: entry.syncID, groupID: entry.groupID, entityType: entry.entityType,
                        op: op, hlc: entry.hlc, clientMutationID: entry.clientMutationID,
                        fieldsJSON: entry.fieldsJSON, fieldHlcsJSON: entry.fieldHlcsJSON,
                        author: entry.author, tombstoneReason: entry.tombstoneReason,
                        createdAt: entry.createdAt))
                }
            }
        } catch {
            #if DEBUG
            logger.error("GroupsSync: rehydrate save falló: \(error)")
            #endif
            return
        }
        GroupsSyncBreadcrumb.groupsMirrorRehydrated(count: missing.count)
    }

    // MARK: - Guard del token de History (molde HALLAZGO 2)

    private struct TokenGuardResult {
        var txns: [DefaultHistoryTransaction]
        var validatedByCompare = false
        var reanchor: (token: DefaultHistoryToken, txAt: Date)?
    }

    /// Detecta y recupera un token que dejó de surfacear transacciones nuevas del mount ACTUAL usando los
    /// TIMESTAMPS de History (comparables cross-mount). Molde byte-a-byte de
    /// `CloudSyncEngine.recoverIfHistoryTokenIncomparable`, acotado a las entidades de Grupos.
    private func recoverIfHistoryTokenIncomparable(
        cursor: GroupSyncCursor,
        tokenTxns: [DefaultHistoryTransaction],
        context: ModelContext
    ) -> TokenGuardResult {
        guard !historyTokenValidated,
              cursor.historyTokenData != nil,
              let lastDrainedTxAt = cursor.lastDrainedTxAt else {
            return TokenGuardResult(txns: tokenTxns)
        }
        let cutoff = lastDrainedTxAt.addingTimeInterval(-Self.historyTokenSlack)
        let timestampTxns: [DefaultHistoryTransaction]
        do {
            timestampTxns = try context.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.timestamp > cutoff }))
        } catch {
            return TokenGuardResult(txns: tokenTxns)
        }
        guard !timestampTxns.isEmpty else { return TokenGuardResult(txns: tokenTxns) }

        let tokenTokens = tokenTxns.map(\.token)
        func tokenPresent(_ tx: DefaultHistoryTransaction) -> Bool {
            tokenTokens.contains { $0 == tx.token }
        }
        let missing = timestampTxns.filter { tx in
            guard tx.timestamp > lastDrainedTxAt else { return false }
            guard tx.author != Self.outboxSaveAuthor else { return false }
            guard tx.changes.contains(where: {
                Self.groupEntityNames.contains($0.changedPersistentIdentifier.entityName)
            }) else { return false }
            return !tokenPresent(tx)
        }
        guard !missing.isEmpty else {
            return TokenGuardResult(txns: tokenTxns, validatedByCompare: true)
        }

        historyTokenIncomparableCount += 1
        GroupsSyncBreadcrumb.groupsHistoryTokenIncomparable(missed: missing.count)
        var union = tokenTxns
        for tx in timestampTxns where !tokenPresent(tx) { union.append(tx) }
        let orderedUnion = union.enumerated()
            .sorted { a, b in
                a.element.timestamp != b.element.timestamp
                    ? a.element.timestamp < b.element.timestamp
                    : a.offset < b.offset
            }
            .map(\.element)
        guard let last = orderedUnion.last else {
            return TokenGuardResult(txns: orderedUnion)
        }
        return TokenGuardResult(txns: orderedUnion, reanchor: (token: last.token, txAt: last.timestamp))
    }

    // MARK: - Push (POST /groups/push)

    /// Máximo de deltas por REQUEST (B2, molde `SyncPushClient.pushChunkSize` / anti-patrón I14-H2 del
    /// personal): el Worker aplica los `apply_group_delta` SECUENCIALMENTE — un batch sin cap (backlog
    /// grande tras un kill/offline) excede el timeout del URLSession → `.transient` → nada se purga →
    /// loop sin progreso. 50 deltas deja margen 4× bajo el timeout.
    static let pushChunkSize = 50

    /// Sube el outbox pendiente (filas sin dead-letter) al gateway en CHUNKS de `pushChunkSize` con
    /// PROGRESO INCREMENTAL (molde `SyncPushClient.push` I14-H2): cada chunk confirmado se purga/marca
    /// vía `applyResults` **POR CHUNK con las filas de ESE chunk** ([R8] — la correlación por
    /// `client_mutation_id` es chunk-independiente) ANTES de pedir el siguiente. Un chunk fallido tras
    /// confirmados → `.completed(parciales)` (lo confirmado ya se aplicó; el próximo ciclo re-emite solo
    /// el resto — un outcome TERMINAL 401/403 resurfacea en el PRIMER chunk del próximo intento).
    /// NO purga si la sesión está caída.
    func pushPending(context: ModelContext) async -> PushOutcome {
        let rows: [GroupSyncOutbox]
        do {
            var descriptor = FetchDescriptor<GroupSyncOutbox>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)])
            descriptor.predicate = #Predicate { $0.rejectedReason == nil }
            rows = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            logger.error("GroupsSync: fetch outbox para push falló: \(error)")
            #endif
            return .transient
        }
        guard !rows.isEmpty else { return .completed([]) }

        guard var token = await tokenProvider(), !token.isEmpty else {
            return .sessionExpired(pending: rows.count)
        }
        // Attest UNA vez para todos los chunks (TTL de sesión ≫ duración del push, molde personal).
        let attest = await attestProvider()

        var confirmed: [SyncDeltaResult] = []
        var index = 0
        while index < rows.count {
            let upper = min(index + Self.pushChunkSize, rows.count)
            let chunk = Array(rows[index..<upper])
            // `token` es inout: si un chunk rescata un 401 con refresh forzado, el token FRESCO se
            // propaga a los chunks siguientes (sin él, cada chunk posterior forzaría su propio refresh).
            let outcome = await pushChunk(chunk, token: &token, attest: attest,
                                          totalPending: rows.count, context: context)
            switch outcome {
            case .completed(let results):
                confirmed.append(contentsOf: results)
                index = upper
            case .sessionExpired, .accountUnavailable, .transient:
                // Progreso parcial: lo confirmado YA se aplicó por chunk; sin nada confirmado, el outcome
                // del chunk fallido sube tal cual (conserva la clasificación 401/403/transitorio).
                return confirmed.isEmpty ? outcome : .completed(confirmed)
            }
        }
        return .completed(confirmed)
    }

    /// UN request `POST /groups/push` con un chunk de filas. Mapeo de status EXACTAMENTE el previo al
    /// chunking; al 200 aplica los resultados DEL CHUNK ([R8]) antes de devolver. `token` es `inout`:
    /// un 401 rescatado con refresh forzado ESCRIBE el token fresco de vuelta (los chunks siguientes de
    /// `pushPending` lo reusan sin re-forzar el refresh por chunk).
    private func pushChunk(
        _ chunk: [GroupSyncOutbox], token: inout String, attest: String?,
        totalPending: Int, context: ModelContext
    ) async -> PushOutcome {
        let generation = teardownGeneration  // guardia MEDIA: no aplicar resultados post-teardown
        let deltas: [GroupSyncDelta]
        do {
            deltas = try chunk.map { try buildDelta(from: $0) }
        } catch {
            // LOW aceptado (review adversarial, follow-up): una fila poison hace transitorio el CHUNK
            // entero en vez de aislarse con un `partitionBuildable` como el personal (DIFERIDOS #26).
            // NO-REGRESIÓN vs pre-B2: antes del chunking, la misma fila hacía transitorio el batch
            // COMPLETO. El canal de Grupos solo emite las 4 clases cableadas → poison requiere drift.
            #if DEBUG
            logger.error("GroupsSync: buildDelta falló: \(error)")
            #endif
            return .transient
        }

        let body = wireBody(deltas)

        // Cierre interno con la request YA construida (body/attest/deviceToken idénticos): solo cambia el
        // bearer, para poder RE-EMITIR el chunk con un token fresco tras un 401. Mapeo de status EXACTO.
        func send(bearer: String) async -> PushOutcome {
            var request = URLRequest(url: baseURL.appendingPathComponent("groups/push"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
            if let attest, !attest.isEmpty {
                request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
            }
            // G8-3: el device token local (header opcional) → el server excluye SOLO este device del autor del
            // fan-out. Solo se añade si el provider da un token non-nil/no-vacío (default `{ nil }` → header AUSENTE,
            // byte-idéntico al pre-G8-3). Flag OFF: pushChunk solo corre con el canal activo — sin divergencia.
            if let deviceToken = deviceTokenProvider(), !deviceToken.isEmpty {
                request.setValue(deviceToken, forHTTPHeaderField: "X-Yala-Device-Token")
            }
            request.httpBody = body

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await urlSession.data(for: request)
            } catch {
                return .transient
            }
            guard let http = response as? HTTPURLResponse else { return .transient }

            switch http.statusCode {
            case 200:
                // Guardia MEDIA: un teardown durante el request suspendido → NO aplicar resultados (ni purga
                // ni dead-letter ni removals del espejo bajo una sesión que ya no existe). `.transient` es
                // seguro: nada se confirmó localmente; el server deduplica por client_mutation_id.
                guard generation == teardownGeneration else { return .transient }
                do {
                    let decoded = try JSONDecoder().decode(GroupPushResponse.self, from: data)
                    // El `SyncDeltaResult` local descarta `outcome`; se decodifica APARTE para leer el código
                    // SANITIZADO (`outcome.message` = yala_*) del rechazo y el `reason` del noop group_not_found
                    // — SIN tocar el `SyncPushClient` del personal (A2).
                    let outcomeInfo = Self.decodeOutcomeInfo(data)
                    applyResults(decoded.results, outcomeInfo: outcomeInfo, rows: chunk, context: context)
                    return .completed(decoded.results)
                } catch {
                    return .transient
                }
            case 401:
                return .sessionExpired(pending: totalPending)
            case 403:
                return .accountUnavailable
            case 409:
                return GatewayErrorEnvelope.isAccountReverting(data) ? .accountUnavailable : .transient
            default:
                return .transient
            }
        }

        let outcome = await send(bearer: token)
        // Retry-once del 401 (H-2026-07-18-4): fuerza el refresh del token y RE-EMITE el chunk UNA vez si el
        // token nuevo DIFIERE del usado. nil o idéntico → sessionExpired como hoy (jamás recursión: solo un
        // reintento). Solo el 401 se rescata — el resto de códigos suben tal cual. El token fresco se escribe
        // de vuelta (inout) para que los chunks SIGUIENTES lo reusen.
        if case .sessionExpired = outcome,
           let fresh = await forceRefreshTokenProvider(), fresh != token {
            token = fresh
            return await send(bearer: fresh)
        }
        return outcome
    }

    /// Traduce UNA fila de outbox de Grupos a su `GroupSyncDelta` de wire. `entity_type` = tabla Postgres.
    func buildDelta(from row: GroupSyncOutbox) throws -> GroupSyncDelta {
        guard let table = GroupEntityEmissionMap.table(forClass: row.entityType) else {
            throw SyncPushError.unknownEntity(row.entityType)
        }
        let op = SyncOutboxOp(rawValue: row.opRaw) ?? .upsert
        let isTombstone = (op == .tombstone)
        // split_groups: el wire lleva `sync_id = null` (la identidad es `group_id`, §A.2 rama especial).
        let isSplitGroup = (row.entityType == GroupSyncEntityType.splitGroup)
        return GroupSyncDelta(
            entityType: table,
            groupID: row.groupID,
            syncID: isSplitGroup ? nil : row.syncID,
            op: op,
            fieldsRawJSON: isTombstone ? nil : row.fieldsJSON,
            fieldHlcsRawJSON: isTombstone ? nil : row.fieldHlcsJSON,
            hlc: row.hlc,
            clientMutationID: row.clientMutationID,
            schemaVersion: row.schemaVersion
        )
    }

    /// `outcome` decodificado APARTE por `client_mutation_id`: `message` = código SANITIZADO del rechazo
    /// upstream (yala_*); `reason` = motivo del noop (group_not_found). Ambos sin PII (constantes del RPC).
    struct OutcomeInfo: Equatable {
        let message: String?
        let reason: String?
    }

    /// Aplica los resultados del push: `applied` → purga; `noop` → purga (con breadcrumb agregado para el
    /// noop group_not_found, anti retry-storm de meta legacy); `rejected` → dead-letter con el código
    /// sanitizado, salvo `upstream_5xx/429` que sigue transitorio (reintento). Correlación por
    /// `client_mutation_id` (unívoco por mutación).
    private func applyResults(
        _ results: [SyncDeltaResult], outcomeInfo: [String: OutcomeInfo],
        rows: [GroupSyncOutbox], context: ModelContext
    ) {
        guard !results.isEmpty else { return }
        var byMutation: [String: GroupSyncOutbox] = [:]
        for row in rows { byMutation[row.clientMutationID.uuidString.lowercased()] = row }

        var groupNotFoundPurged = 0
        // B2: pares (syncID, hlc) cuyo archivo espejo debe borrarse — purgas (applied/noop) Y dead-letters
        // (excluidas del espejo). Se borra DESPUÉS del save exitoso (orden fila-primero, molde
        // `confirmUploaded` del personal); si el save falla, el espejo queda consistente con el store.
        // LOW aceptado (review adversarial): una dead-letter REVIVIBLE (`upstream_400:yala_not_authorized`
        // — member en pendingApproval) queda SIN red de espejo durante esa ventana: si una lightweight
        // migration recrea la tabla ANTES de la aprobación, ese delta se pierde. Consecuencia asumida de
        // la decisión dead-letters-excluidas (el espejo es red de PENDIENTES); el contenido es recuperable
        // re-escribiéndolo tras el re-join/aprobación, y el re-drive re-espeja las que sobreviven.
        var mirrorRemovals: [(syncID: UUID, hlc: String)] = []
        do {
            try saveWithAuthor(context) {
                for result in results {
                    guard let mutationID = result.clientMutationID?.lowercased(),
                          let row = byMutation[mutationID] else { continue }
                    let info = outcomeInfo[mutationID]
                    switch result.status {
                    case .applied:
                        mirrorRemovals.append((row.syncID, row.hlc))
                        context.delete(row)
                    case .noop:
                        // La PURGA del noop group_not_found SE MANTIENE (decisión G3: anti retry-storm de
                        // meta de grupos legacy no migrados) — deja de ser silenciosa (breadcrumb al final).
                        if info?.reason == "group_not_found" { groupNotFoundPurged += 1 }
                        mirrorRemovals.append((row.syncID, row.hlc))
                        context.delete(row)
                    case .rejected:
                        let reason = result.reason ?? "rejected"
                        if reason == "upstream_400" {
                            // P0001 de los RPCs (yala_*): dead-letter con el código SANITIZADO. El server NO
                            // garantiza que un 400 sea un slug yala_* — el bloque exception de apply_group_delta
                            // solo captura insufficient_privilege; una data-exception (22P02) propagaría un
                            // mensaje que ECOA el valor del cliente → PII a telemetría/persistencia. Solo se
                            // acepta si matchea el patrón slug del gateway (^yala_[a-z_]+$); si no, "upstream_400"
                            // pelado en AMBOS. El re-drive de `applyMember` revive `upstream_400:yala_not_authorized`.
                            let slug = Self.sanitizedYalaSlug(info?.message)
                            let stored = slug.map { "upstream_400:\($0)" } ?? "upstream_400"
                            markDeadLetter(row, reason: stored, telemetryReason: slug ?? "upstream_400")
                            mirrorRemovals.append((row.syncID, row.hlc))
                        } else if reason.hasPrefix("upstream_") {
                            // 5xx / 429: transitorio (reintento en el próximo push). El espejo se conserva.
                            continue
                        } else {
                            // Rechazos locales del gateway (malformed_delta, unknown_entity, coherence_*,
                            // pull_only…): dead-letter (ya era el comportamiento).
                            markDeadLetter(row, reason: reason, telemetryReason: reason)
                            mirrorRemovals.append((row.syncID, row.hlc))
                        }
                    }
                }
            }
        } catch {
            #if DEBUG
            logger.error("GroupsSync: applyResults save falló: \(error)")
            #endif
            return  // save fallido → NO tocar el espejo (queda consistente con el store)
        }
        for removal in mirrorRemovals {
            outboxMirror?.remove(syncID: removal.syncID, hlc: removal.hlc)
        }
        if groupNotFoundPurged > 0 {
            GroupsSyncBreadcrumb.groupsMetaPurgedGroupNotFound(count: groupNotFoundPurged)
        }
    }

    /// Sanitiza el `message` del outcome upstream: SOLO acepta un slug `yala_*` (réplica exacta del regex
    /// del gateway `^yala_[a-z_]+$`) — cualquier otro contenido puede ECOAR el valor del cliente (data-
    /// exception que el RPC no captura) y NO debe persistirse ni llegar a telemetría. `nil` si no matchea.
    static func sanitizedYalaSlug(_ message: String?) -> String? {
        guard let message, message.hasPrefix("yala_"), message.count > 5 else { return nil }
        guard message.allSatisfy({ $0 == "_" || ($0 >= "a" && $0 <= "z") }) else { return nil }
        return message
    }

    /// Marca una fila como dead-letter + breadcrumb + telemetría (canario `groupPushRejected`). El `reason`
    /// persistido puede portar el código sanitizado (`upstream_400:yala_*`); `telemetryReason` es un slug
    /// sin PII para el canario.
    private func markDeadLetter(_ row: GroupSyncOutbox, reason: String, telemetryReason: String) {
        row.rejectedReason = reason
        row.rejectedAt = now()
        GroupsSyncBreadcrumb.groupsPushDeadLettered(reason: reason)
        MetricsService.canary(.groupPushRejected, detail: telemetryReason)
    }

    /// Decodifica el `outcome` de cada resultado del push APARTE (el `SyncDeltaResult` local lo descarta),
    /// indexado por `client_mutation_id` lowercased. Tolerante a bodies sin `outcome`.
    static func decodeOutcomeInfo(_ data: Data) -> [String: OutcomeInfo] {
        guard let decoded = try? JSONDecoder().decode(RawOutcomeResponse.self, from: data) else { return [:] }
        var map: [String: OutcomeInfo] = [:]
        for r in decoded.results {
            guard let mid = r.clientMutationID?.lowercased() else { continue }
            map[mid] = OutcomeInfo(message: r.outcome?.message, reason: r.outcome?.reason)
        }
        return map
    }

    // MARK: - Wire body (RawJSON crudo, molde SyncPushClient)

    private func wireBody(_ deltas: [GroupSyncDelta]) -> Data {
        let joined = deltas.map(Self.encodeDelta).joined(separator: ",")
        return Data("{\"deltas\":[\(joined)]}".utf8)
    }

    static func encodeDelta(_ d: GroupSyncDelta) -> String {
        var parts: [String] = [
            "\"entity_type\":\(SyncPushClient.jsonString(d.entityType))",
            "\"group_id\":\(SyncPushClient.jsonString(d.groupID))",
        ]
        // split_groups → sync_id null; el resto → uuid lowercased.
        if let syncID = d.syncID {
            parts.append("\"sync_id\":\(SyncPushClient.jsonString(syncID.uuidString.lowercased()))")
        } else {
            parts.append("\"sync_id\":null")
        }
        parts.append("\"op\":\(SyncPushClient.jsonString(d.op.rawValue))")
        if let fields = d.fieldsRawJSON { parts.append("\"fields\":\(fields)") }
        if let fieldHlcs = d.fieldHlcsRawJSON { parts.append("\"field_hlcs\":\(fieldHlcs)") }
        parts.append("\"hlc\":\(SyncPushClient.jsonString(d.hlc))")
        parts.append("\"client_mutation_id\":\(SyncPushClient.jsonString(d.clientMutationID.uuidString.lowercased()))")
        parts.append("\"schema_version\":\(d.schemaVersion)")
        return "{\(parts.joined(separator: ","))}"
    }

    // MARK: - Pull (GET /groups/pull) + apply

    /// Itera `pullAndApplyOnce` hasta AGOTAR la cola. TERMINA cuando la página aplicada trae 0 deltas (única
    /// señal válida — el `limit` del gateway es POR GRUPO, así que el atajo `deltas.count < limit → done`
    /// del canal personal NO aplica). Cap duro de `pullMaxIterations` (server que no converge) → breadcrumb
    /// `groupsPullExhaustedCap` + `.transient`. A1: si el save de una página FALLÓ (cursor no avanzó), corta
    /// como `.transient` INMEDIATAMENTE — jamás re-pide el mismo `since` en el mismo ciclo (evitando 20
    /// round-trips por un save atascado). Acumula pages/deltas.
    func pullUntilExhausted(context: ModelContext, limit: Int = 500) async -> GroupsPullOutcome {
        var pages = 0
        var totalDeltas = 0
        for _ in 0..<Self.pullMaxIterations {
            let page = await pullAndApplyOnce(context: context, limit: limit)
            switch page {
            case .applied(let deltas, let saved):
                guard saved else { return .transient }             // A1: cursor no avanzó → cortar
                if deltas == 0 {
                    // H-2026-07-18-5: bump VIVO de refresh POR-CICLO (no por-página) — solo si el ciclo
                    // aplicó deltas que cambian contenido. `markRemoteChangePending` (por-página, en
                    // `applyPulledPage`) se CONSERVA como red del caso background/vista-no-montada.
                    if totalDeltas > 0 {
                        // 2.2: el pull se AGOTÓ ⇒ el contenido de las zonas recién descubiertas ya bajó, así
                        // que las notificaciones de membership pueden reanudarse sin esperar los 15 min.
                        // Mismo gate que el bump de refresh: un ciclo ocioso no paga el fetch.
                        completeInitialMemberImport(context: context)
                        onRemoteChangesApplied()
                    }
                    return .completed(pages: pages, deltasApplied: totalDeltas)
                }
                pages += 1
                totalDeltas += deltas
            case .sessionExpired: return .sessionExpired
            case .accountUnavailable: return .accountUnavailable
            case .transient: return .transient
            }
        }
        GroupsSyncBreadcrumb.groupsPullExhaustedCap(pages: pages)
        return .transient
    }

    /// Baja UNA página de deltas remotos y la aplica. Devuelve el resultado POR-PÁGINA (`deltas` bajados +
    /// si el save de la página tuvo éxito) que `pullUntilExhausted` agrega.
    func pullAndApplyOnce(context: ModelContext, limit: Int = 500) async -> GroupsPullPageOutcome {
        let generation = teardownGeneration  // guardia MEDIA: no aplicar una página post-teardown
        let cursor: GroupSyncCursor
        do { cursor = try loadOrCreateCursor(context) } catch { return .transient }

        guard let token = await tokenProvider(), !token.isEmpty else { return .sessionExpired }

        guard let url = buildPullURL(cursorsJSON: cursor.groupCursorsJSON, limit: limit) else {
            return .transient
        }
        let attest = await attestProvider()

        // Cierre interno con la URL/attest ya resueltos: solo cambia el bearer, para RE-EMITIR la página
        // con un token fresco tras un 401. Mapeo de status EXACTO al previo.
        func send(bearer: String) async -> GroupsPullPageOutcome {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
            if let attest, !attest.isEmpty {
                request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
            }

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await urlSession.data(for: request)
            } catch {
                return .transient
            }
            guard let http = response as? HTTPURLResponse else { return .transient }

            switch http.statusCode {
            case 200:
                // Guardia MEDIA: un teardown durante el request suspendido → NO aplicar la página (el apply
                // escribe Split*/cursor y el re-drive haría `writeMirrorEntry` sobre el espejo recién
                // purgado). `.transient` corta el pull sin avanzar cursor.
                guard generation == teardownGeneration else { return .transient }
                do {
                    let page = try Self.decodePage(data)
                    let saved = applyPulledPage(page, cursor: cursor, context: context)
                    return .applied(deltas: page.deltas.count, saved: saved)
                } catch {
                    return .transient
                }
            case 401: return .sessionExpired
            case 403: return .accountUnavailable
            default: return .transient
            }
        }

        let outcome = await send(bearer: token)
        // Retry-once del 401 (H-2026-07-18-4): fuerza el refresh y RE-EMITE la página UNA vez si el token
        // nuevo DIFIERE del usado. nil o idéntico → sessionExpired como hoy (sin recursión).
        if case .sessionExpired = outcome,
           let fresh = await forceRefreshTokenProvider(), fresh != token {
            return await send(bearer: fresh)
        }
        return outcome
    }

    /// Construye la URL del pull con `cursors` (JSON URL-encoded) + `limit`. `internal` para test #4.
    func buildPullURL(cursorsJSON: String, limit: Int) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent("groups/pull"),
                                       resolvingAgainstBaseURL: false)
        let clampedLimit = min(max(limit, 1), 1000)
        components?.queryItems = [
            URLQueryItem(name: "cursors", value: cursorsJSON),
            URLQueryItem(name: "limit", value: String(clampedLimit)),
        ]
        return components?.url
    }

    // MARK: - Apply de una página → Split*

    /// Aplica una `GroupPulledPage` a los `@Model` `Split*` bajo `Self.outboxSaveAuthor`, avanza los
    /// cursores por grupo, y al cierre dispara `markRemoteChangePending` + el gate 5/5 del bridge remoto.
    /// Devuelve `true` si el `saveWithAuthor` tuvo éxito (mirror de `SyncApplyEngine.applyPage`, A1): un
    /// `false` = el cursor NO avanzó → `pullUntilExhausted` corta. `internal` para tests (cursores).
    @discardableResult
    func applyPulledPage(_ page: GroupPulledPage, cursor: GroupSyncCursor, context: ModelContext) -> Bool {
        var bridgeExpenseIDs: [UUID] = []
        var bridgeSettlementIDs: [UUID] = []
        var notify = PendingNotificationChanges()
        var freezeZones: Set<String> = []
        var maxSeqByGroup = decodeCursors(cursor.groupCursorsJSON)
        // H-2026-07-18-3: grupos cuyo cursor hay que RESETEAR a 0 tras esta página (re-join del propio user:
        // pendingApproval→active). Lo llena `applyMember`; se aplica DESPUÉS del merge de `page.cursors`.
        var cursorResetGroupIDs: Set<String> = []

        // Ciclo idle (60s): página SIN deltas Y sin cursor que avance → NO escribir (evita una transacción
        // de History no-op por vuelta, que re-drenaría groupCursorsJSON/clockLatestHLC idénticos). Si
        // `page.cursors` trae un avance (grupo nuevo descubierto por memberships con cursor pero sin deltas
        // en esta página) SÍ hay que persistir → no cortar.
        let cursorsAdvance = page.cursors.contains { gid, seq in seq > (maxSeqByGroup[gid] ?? 0) }
        if page.deltas.isEmpty, !cursorsAdvance { return true }

        do {
            try saveWithAuthor(context) {
                for delta in page.deltas {
                    try applyDelta(delta, context: context,
                                   bridgeExpenseIDs: &bridgeExpenseIDs,
                                   bridgeSettlementIDs: &bridgeSettlementIDs,
                                   cursorResetGroupIDs: &cursorResetGroupIDs,
                                   notify: &notify, freezeZones: &freezeZones)
                    // Avanzar el cursor del grupo al server_seq máximo aplicado.
                    let prev = maxSeqByGroup[delta.groupID] ?? 0
                    if delta.serverSeq > prev { maxSeqByGroup[delta.groupID] = delta.serverSeq }
                }
                // Cursores autoritativos del server (por si vienen por delante del delta máximo aplicado).
                for (gid, seq) in page.cursors {
                    let prev = maxSeqByGroup[gid] ?? 0
                    if seq > prev { maxSeqByGroup[gid] = seq }
                }
                // H-2026-07-18-3: reset por re-join. DESPUÉS del merge de `page.cursors` → gana sobre
                // cualquier avance de ESTA página; el próximo pull re-pide ese grupo desde 0 y re-visita el
                // contenido que RLS ocultaba mientras el member estaba pendingApproval.
                for gid in cursorResetGroupIDs { maxSeqByGroup[gid] = 0 }
                cursor.groupCursorsJSON = encodeCursors(maxSeqByGroup)
                cursor.clockLatestHLC = clock.latest?.description
            }
        } catch {
            #if DEBUG
            logger.error("GroupsSync: applyPulledPage save falló: \(error)")
            #endif
            return false
        }

        // H-2026-07-18-3: canario del reset por re-join (solo tras un save exitoso — el catch retornó arriba).
        if !cursorResetGroupIDs.isEmpty {
            GroupsSyncBreadcrumb.groupsRejoinCursorReset(groups: cursorResetGroupIDs.count)
        }
        SessionState.shared.markRemoteChangePending()
        // 2.1: notificaciones locales de grupo. Post-save (como el canal CloudKit, que las procesaba en
        // `processPendingRemoteChanges` tras persistir): un save fallido retornó arriba y no notifica nada
        // que el usuario no tenga en el store.
        let changes = resolveNotificationChanges(notify, context: context)
        if !changes.isEmpty { onRemoteChanges(changes) }
        drainSoftDeleteFreeze(freezeZones, context: context)
        scheduleBridge(expenseIDs: bridgeExpenseIDs, settlementIDs: bridgeSettlementIDs)
        return true
    }

    /// 2.3: congela el bridge personal de las zonas que acaban de pasar a soft-delete. Post-save, como en el
    /// canal CloudKit (que lo drenaba tras persistir el batch del fetch), e idempotente: `freezeForSoftDelete`
    /// es no-op si ya no queda nada colgando de la zona.
    private func drainSoftDeleteFreeze(_ zones: Set<String>, context: ModelContext) {
        guard !zones.isEmpty else { return }
        for zone in zones {
            let group: SplitGroup?
            do {
                group = try fetchSplitGroup(zoneID: zone, context: context)
            } catch {
                #if DEBUG
                logger.error("GroupsSync: freeze fetch falló para \(zone): \(error)")
                #endif
                continue
            }
            guard let group else { continue }
            do {
                try GroupTransactionBridge.shared.freezeForSoftDelete(group: group)
            } catch {
                #if DEBUG
                logger.error("GroupsSync: freezeForSoftDelete falló para \(zone): \(error)")
                #endif
            }
        }
    }

    /// Acumulador por-página de lo que puede notificar (2.1). Guarda el `group_id` del wire (==
    /// `cloudKitZoneID`); la traducción a `SplitGroup.id` —que es por lo que indexa `RemoteChangeSet`— se
    /// hace al CIERRE de la página, cuando todo `GroupMeta` de ESTA página ya está insertado.
    private struct PendingNotificationChanges {
        var newExpenses: [(id: UUID, zone: String)] = []
        var modifiedExpenses: [(id: UUID, zone: String)] = []
        var newSettlements: [(id: UUID, zone: String)] = []
        var newMembers: [(id: UUID, zone: String)] = []
        var newPendingMembers: [(id: UUID, zone: String)] = []
        /// Caches por-página de la clasificación de membership (2.2) — evitan re-fetchear por cada miembro
        /// del mismo grupo. Seguros por página: el baseline solo puede moverse HACIA `initialImport` (un
        /// `GroupMeta` insertado a media página), nunca al revés.
        var baselines: [String: MemberChangeNotificationLogic.ZoneBaseline] = [:]
        var isAdminByZone: [String: Bool] = [:]
    }

    /// 2.2: clasifica un `SplitMember` que el pull acaba de insertar. Preserva las DOS condiciones que la
    /// regla de área exige (bug «Jür se unió al grupo»): baseline de primer import de la zona **y**
    /// autoexclusión por identidad. Sin la segunda, el invitado recibe «X se unió al grupo» por el miembro
    /// del owner en cuanto baja la zona. La identidad de ESTE canal es el `sub` de la cuenta Yala
    /// (`SplitMember.userID`), nunca `isCurrentUser` — `applyMember` jamás setea ese flag.
    private func classifyNewMemberForNotification(
        _ model: SplitMember, zone: String, context: ModelContext,
        notify: inout PendingNotificationChanges
    ) {
        // `isCurrentUserAdmin` solo decide el caso pending → no se paga su fetch para los demás.
        let isPending = model.memberStatus == .pendingApproval
        let isAdmin = isPending && isCurrentUserAdminOfZone(zone, context: context,
                                                           cache: &notify.isAdminByZone)
        switch MemberChangeNotificationLogic.classifyNewMember(
            rawStatus: model.status,
            isCurrentUserAdmin: isAdmin,
            // La comparación de la lógica pura es exacta; el canal backend normaliza el `sub` en TODAS sus
            // comparaciones de identidad (`GroupBackendIdentityLogic.isCurrentUser`), así que se pasan ya
            // normalizados: una diferencia de caso no puede convertirse en un «se unió» sobre uno mismo.
            memberUserRecordID: model.userID?.lowercased(),
            currentUserRecordID: currentUserIDProvider()?.lowercased(),
            zoneBaseline: zoneBaseline(zone, context: context, cache: &notify.baselines)
        ) {
        case .pendingRequestForAdmin:
            notify.newPendingMembers.append((id: model.id, zone: zone))
        case .joined:
            notify.newMembers.append((id: model.id, zone: zone))
        case .ignore:
            break
        }
    }

    /// Baseline de primer import de la zona. Un fetch fallido devuelve `.initialImport` (dirección segura:
    /// callar, jamás notificar de más) y NO se cachea.
    private func zoneBaseline(
        _ zone: String, context: ModelContext,
        cache: inout [String: MemberChangeNotificationLogic.ZoneBaseline]
    ) -> MemberChangeNotificationLogic.ZoneBaseline {
        if let cached = cache[zone] { return cached }
        let group: SplitGroup?
        do {
            group = try fetchSplitGroup(zoneID: zone, context: context)
        } catch {
            #if DEBUG
            logger.error("GroupsSync: zoneBaseline fetch falló para \(zone): \(error)")
            #endif
            return .initialImport
        }
        let baseline = MemberChangeNotificationLogic.zoneBaseline(
            groupExistsLocally: group != nil,
            importStartedAt: group?.initialMemberImportStartedAt,
            now: now())
        cache[zone] = baseline
        return baseline
    }

    /// ¿El usuario de la sesión es admin de esta zona? Resuelto por el `sub` (`SplitMember.userID`), que es
    /// la identidad del canal backend. Un fetch fallido devuelve `false` (una solicitud pendiente no
    /// notificada es mejor que notificarla a quien no la puede aprobar) y NO se cachea.
    private func isCurrentUserAdminOfZone(
        _ zone: String, context: ModelContext, cache: inout [String: Bool]
    ) -> Bool {
        if let cached = cache[zone] { return cached }
        guard let uid = currentUserIDProvider(), !uid.isEmpty else { return false }
        let members: [SplitMember]
        do {
            members = try context.fetch(FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.groupZoneID == zone }))
        } catch {
            #if DEBUG
            logger.error("GroupsSync: isCurrentUserAdminOfZone fetch falló para \(zone): \(error)")
            #endif
            return false
        }
        let result = members.contains {
            $0.isAdmin && GroupBackendIdentityLogic.isCurrentUser(memberUserID: $0.userID, currentUserID: uid)
        }
        cache[zone] = result
        return result
    }

    /// Cierra el baseline de primer import de las zonas que lo tuvieran abierto — gemelo de
    /// `completeInitialMemberImport` del canal CloudKit, que lo hacía por zona al cerrar su ciclo de fetch.
    /// Aquí el pull es global, así que agotarlo las cierra todas. El filtro va EN MEMORIA a propósito (un
    /// `#Predicate` sobre un opcional es el gotcha documentado) y la escritura bajo el autor del outbox: es
    /// una marca LOCAL que no debe re-emitirse.
    private func completeInitialMemberImport(context: ModelContext) {
        do {
            let backendGroups = try context.fetch(FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.isBackendGroup == true }))
            let pending = backendGroups.filter { $0.initialMemberImportStartedAt != nil }
            guard !pending.isEmpty else { return }
            try saveWithAuthor(context) {
                for group in pending { group.initialMemberImportStartedAt = nil }
            }
        } catch {
            #if DEBUG
            logger.error("GroupsSync: completeInitialMemberImport falló: \(error)")
            #endif
        }
    }

    /// Traduce el acumulador por-zona al `RemoteChangeSet` que consume `GroupNotificationService`. Una zona
    /// sin `SplitGroup` local se DESCARTA: sin grupo no hay nombre ni deep-link que ofrecer, y el filtro de
    /// participación del consumidor tampoco podría resolver al miembro.
    private func resolveNotificationChanges(
        _ pending: PendingNotificationChanges, context: ModelContext
    ) -> RemoteChangeSet {
        var cache: [String: UUID?] = [:]
        func groupID(_ zone: String) -> UUID? {
            if let cached = cache[zone] { return cached }
            do {
                let resolved = try fetchSplitGroup(zoneID: zone, context: context)?.id
                cache[zone] = resolved   // cachea solo el resultado de un fetch EXITOSO (incl. nil legítimo)
                return resolved
            } catch {
                // Fetch fallido: no se cachea (envenenaría toda la zona en esta página) y no se notifica.
                #if DEBUG
                logger.error("GroupsSync: resolveNotificationChanges fetch falló para \(zone): \(error)")
                #endif
                return nil
            }
        }
        func mapped(_ entries: [(id: UUID, zone: String)]) -> [(id: UUID, groupID: UUID)] {
            entries.compactMap { entry in groupID(entry.zone).map { (id: entry.id, groupID: $0) } }
        }
        var set = RemoteChangeSet()
        set.newExpenses = mapped(pending.newExpenses)
        set.modifiedExpenses = mapped(pending.modifiedExpenses)
        set.newSettlements = mapped(pending.newSettlements)
        set.newMembers = mapped(pending.newMembers)
        set.newPendingMembers = mapped(pending.newPendingMembers)
        return set
    }

    private func applyDelta(
        _ delta: GroupPulledDelta,
        context: ModelContext,
        bridgeExpenseIDs: inout [UUID],
        bridgeSettlementIDs: inout [UUID],
        cursorResetGroupIDs: inout Set<String>,
        notify: inout PendingNotificationChanges,
        freezeZones: inout Set<String>
    ) throws {
        switch delta.entityType {
        case GroupEntityEmissionMap.splitExpense.table:
            guard let id = delta.syncID else {
                GroupsSyncBreadcrumb.groupsApplySkippedDelta(entity: delta.entityType); return
            }
            try applyExpense(delta, id: id, context: context, bridgeExpenseIDs: &bridgeExpenseIDs,
                             notify: &notify)
        case GroupEntityEmissionMap.splitShare.table:
            guard let id = delta.syncID else {
                GroupsSyncBreadcrumb.groupsApplySkippedDelta(entity: delta.entityType); return
            }
            try applyShare(delta, id: id, context: context)
        case GroupEntityEmissionMap.splitSettlement.table:
            guard let id = delta.syncID else {
                GroupsSyncBreadcrumb.groupsApplySkippedDelta(entity: delta.entityType); return
            }
            try applySettlement(delta, id: id, context: context, bridgeSettlementIDs: &bridgeSettlementIDs,
                                notify: &notify)
        case GroupEntityEmissionMap.splitGroup.table:
            try applyGroupMeta(delta, context: context, freezeZones: &freezeZones)
        case "group_members":
            try applyMember(delta, context: context, cursorResetGroupIDs: &cursorResetGroupIDs,
                            notify: &notify)
        default:
            GroupsSyncBreadcrumb.groupsApplySkippedDelta(entity: delta.entityType)
            return  // entidad no cableada al apply
        }
    }

    private func applyExpense(
        _ delta: GroupPulledDelta, id: UUID, context: ModelContext, bridgeExpenseIDs: inout [UUID],
        notify: inout PendingNotificationChanges
    ) throws {
        let existing = try fetchSplitExpense(id: id, context: context)
        if delta.op == .tombstone {
            if let existing { context.delete(existing) }
            return
        }
        // 2.1: nuevo vs modificado, igual que la clasificación del fetch CloudKit (que lo decidía con el
        // pre-fetch de IDs del batch). El filtro de participación —y la exclusión de los opening balances
        // y de lo que escribió el propio usuario— vive en el consumidor, que también alimenta al bridge.
        if existing == nil {
            notify.newExpenses.append((id: id, zone: delta.groupID))
        } else {
            notify.modifiedExpenses.append((id: id, zone: delta.groupID))
        }
        let model = existing ?? SplitExpense()
        model.id = id
        model.groupZoneID = delta.groupID
        let f = delta.fields
        if let v = wireString(f["expense_description"]) { model.expenseDescription = v }
        if let v = wireDouble(f["amount"]) { model.amount = v }
        if let v = wireString(f["currency_code"]) { model.currencyCode = v }
        if let v = f["note"] { model.note = wireString(v) }
        if let v = wireDate(f["date"]) { model.date = v }
        if let v = wireDate(f["created_at"]) { model.createdAt = v }
        if let v = wireString(f["paid_by_member_key"]) { model.paidByMemberID = v }
        if let v = wireString(f["split_type"]) { model.splitType = v }
        if let v = wireBool(f["is_settled"]) { model.isSettled = v }
        if let v = wireBool(f["is_opening_balance"]) { model.isOpeningBalance = v }
        if let v = f["subcategory_name"] { model.subcategoryName = wireString(v) }
        if existing == nil { context.insert(model) }
        bridgeExpenseIDs.append(id)
    }

    private func applyShare(_ delta: GroupPulledDelta, id: UUID, context: ModelContext) throws {
        let existing = try fetchSplitShare(id: id, context: context)
        if delta.op == .tombstone {
            if let existing { context.delete(existing) }
            return
        }
        let model = existing ?? SplitShare()
        model.id = id
        model.groupZoneID = delta.groupID
        let f = delta.fields
        if let v = wireUUID(f["expense_id"]) { model.expenseID = v }
        if let v = wireString(f["member_key"]) { model.memberID = v }
        if let v = wireDouble(f["amount"]) { model.amount = v }
        if let v = wireBool(f["is_paid"]) { model.isPaid = v }
        if existing == nil { context.insert(model) }
    }

    private func applySettlement(
        _ delta: GroupPulledDelta, id: UUID, context: ModelContext, bridgeSettlementIDs: inout [UUID],
        notify: inout PendingNotificationChanges
    ) throws {
        let existing = try fetchSplitSettlement(id: id, context: context)
        if delta.op == .tombstone {
            if let existing { context.delete(existing) }
            return
        }
        // 2.1: solo las liquidaciones NUEVAS notifican (el canal CloudKit tampoco clasificaba las
        // modificaciones de settlement).
        if existing == nil { notify.newSettlements.append((id: id, zone: delta.groupID)) }
        let model = existing ?? SplitSettlement()
        model.id = id
        model.groupZoneID = delta.groupID
        let f = delta.fields
        if let v = wireString(f["from_member_key"]) { model.fromMemberID = v }
        if let v = wireString(f["to_member_key"]) { model.toMemberID = v }
        if let v = wireDouble(f["amount"]) { model.amount = v }
        if let v = wireString(f["currency_code"]) { model.currencyCode = v }
        if let v = f["note"] { model.note = wireString(v) }
        if let v = wireDate(f["date"]) { model.date = v }
        if let v = wireBool(f["is_confirmed"]) { model.isConfirmed = v }
        if existing == nil { context.insert(model) }
        bridgeSettlementIDs.append(id)
    }

    private func applyGroupMeta(
        _ delta: GroupPulledDelta, context: ModelContext, freezeZones: inout Set<String>
    ) throws {
        // Identidad = group_id (cloudKitZoneID). UPDATE-only en push; en apply se crea si falta (el grupo
        // nace vía RPC/CKSyncEngine, pero el pull es autoritativo para un member — idempotente).
        let existing = try fetchSplitGroup(zoneID: delta.groupID, context: context)
        if delta.op == .tombstone {
            if let existing { context.delete(existing) }
            return
        }
        // 2.3: estado ANTES del update, para detectar el flip a soft-delete. Un grupo que nace ya oculto
        // (invitado con fresh-install POSTERIOR al soft-delete) cuenta como flip: `false` es el valor previo.
        let wasHidden = existing?.isHiddenForAll ?? false
        let model = existing ?? SplitGroup()
        model.cloudKitZoneID = delta.groupID
        let f = delta.fields
        if let v = wireString(f["name"]) { model.name = v }
        if let v = wireString(f["icon_name"]) { model.iconName = v }
        if let v = wireString(f["color_hex"]) { model.colorHex = v }
        if let v = wireString(f["currency_code"]) { model.currencyCode = v }
        if let v = wireBool(f["simplify_debts"]) { model.simplifyDebts = v }
        if let v = wireBool(f["show_debts_in_single_currency"]) { model.showDebtsInSingleCurrency = v }
        if let v = wireBool(f["members_can_invite"]) { model.membersCanInvite = v }
        if let v = wireString(f["default_split_type"]) { model.defaultSplitType = v }
        if let v = wireBool(f["is_archived"]) { model.isArchived = v }
        if let v = wireBool(f["is_hidden_for_all"]) { model.isHiddenForAll = v }
        if let v = wireDate(f["created_at"]) { model.createdAt = v }
        if existing == nil {
            // C1 write-site (2): born-remote del pull backend → marca el grupo como del canal backend.
            model.isBackendGroup = true
            // 2.2 (baseline de primer import, bug «Jür se unió al grupo»): un SplitGroup que NACE del pull
            // implica que sus miembros preexistentes vienen detrás — suprimir sus notificaciones de
            // membership hasta que el pull se agote (`completeInitialMemberImport`) o venza la ventana de
            // 15 min, que auto-sana. El grupo que crea el propio usuario no pasa por aquí (lo materializa
            // `GroupBackendMembershipService` server-first) ⇒ el creador no sufre la supresión.
            model.initialMemberImportStartedAt = now()
            context.insert(model)
        } else if !model.isBackendGroup {
            // C3 (G6-2) ADOPCIÓN ATÓMICA: un SplitGroup CloudKit PREEXISTENTE que aparece en el pull backend
            // (mismo `group_id`) = grupo MIGRADO cuyo member local re-entró por el backend. Flipear a backend
            // DENTRO del mismo `saveWithAuthor` del apply (sin save extra, molde del re-drive A2) es el
            // interruptor que congela CloudKit (choke-points de G5-A) y activa el drain backend en UN commit;
            // sin atomicidad habría una ventana de doble-verdad. Un grupo born-backend (`isBackendGroup` ya
            // `true`) permanece intacto (guard `!isBackendGroup` → sin write espurio).
            model.isBackendGroup = true
        }
        // 2.3: soft-delete remoto (`is_hidden_for_all` de false a true) → hay que soltar las transacciones
        // y los borradores personales que colgaban de esa zona. El drenaje va fuera del `saveWithAuthor`,
        // porque `freezeForSoftDelete` escribe en el store PERSONAL y hace su propio save.
        if !wasHidden, model.isHiddenForAll { freezeZones.insert(delta.groupID) }
    }

    private func applyMember(
        _ delta: GroupPulledDelta, context: ModelContext, cursorResetGroupIDs: inout Set<String>,
        notify: inout PendingNotificationChanges
    ) throws {
        // PULL-ONLY: identidad server-side = member_key (string, en el `sync_id` del wire; el
        // `cloudKitUserRecordID` es su ESPACIO paralelo solo para members preexistentes del mundo CloudKit).
        // El sentinel '__deleted_user__' NO se traduce aquí (l10n de UI, G4+).
        guard let memberKey = delta.rawSyncID else {
            GroupsSyncBreadcrumb.groupsApplySkippedDelta(entity: delta.entityType)
            return
        }
        let existing = try fetchSplitMember(zoneID: delta.groupID, memberKey: memberKey, context: context)
        if delta.op == .tombstone {
            if let existing { context.delete(existing) }
            return
        }
        let model = existing ?? SplitMember()
        let priorStatus = existing?.status
        if existing == nil {
            // Born-remote: id LOCAL determinista. R10 (G6-2, namespace-aware): un `member_key` LEGACY
            // (recordName de CloudKit — el member de un grupo MIGRADO que re-entró por el backend) deriva en
            // el namespace CloudKit-era `"SplitMember"` con `delta.groupID` (== `cloudKitZoneID` == `zoneID` de
            // la derivación CloudKit-era) → BYTE-IDÉNTICO al id que ya usa el owner (`GroupService`), preservando
            // la identidad del mundo CloudKit sin remap. Un `sub` UUID nacido del backend deriva en el namespace
            // PROPIO del canal. El discriminador es puro (parseabilidad de UUID). Dedup estable cross-device en
            // ambos casos, sin depender del path CloudKit (G3).
            model.id = GroupBackendIdentityLogic.isLegacyMemberKey(memberKey)
                ? GroupUserIdentityService.deterministicUUID(
                    namespace: "SplitMember", name: "\(delta.groupID):\(memberKey)")
                : GroupBackendIdentityLogic.deterministicMemberID(
                    groupID: delta.groupID, memberKey: memberKey)
        }
        model.groupZoneID = delta.groupID
        // Separación de canales (G3): el `member_key` del backend aterriza en `SplitMember.memberKey`, NUNCA
        // en `cloudKitUserRecordID` (el `sub` no debe contaminar el campo CloudKit). Al ADOPTAR una fila
        // CloudKit preexistente por fallback (member_key == su `cloudKitUserRecordID`) también se escribe el
        // `memberKey` — a partir de ahí matchea por el path directo. En born-remote `cloudKitUserRecordID`
        // se queda "" (nunca lo tocamos aquí).
        model.memberKey = memberKey
        let f = delta.fields
        if let v = wireString(f["display_name"]) { model.displayName = v }
        if let v = wireString(f["role"]) { model.role = v }
        if let v = wireString(f["status"]) { model.status = v }
        if let v = wireDate(f["joined_at"]) { model.joinedAt = v }
        // `user_id` = auth uid del wire → `SplitMember.userID` (LOCAL-only del canal backend; nunca CKRecord).
        // Presente-y-null (anonimización del server) NULLea el campo (`wireString(.null) == nil`), igual que
        // `note`; ausente = no tocar (PATCH parcial). Cierra el residual documentado del commit G2.
        if let v = f["user_id"] { model.userID = wireString(v) }
        if existing == nil {
            context.insert(model)
            classifyNewMemberForNotification(model, zone: delta.groupID, context: context, notify: &notify)
        }

        // A2 RE-DRIVE: si el member aplicado es el PROPIO usuario (userID == auth uid) y su status
        // TRANSICIONA a "active", revivir las filas dead-lettered por "upstream_400:yala_not_authorized"
        // de ESTE grupo. RATIONALE: un member `pendingApproval` que escribió contenido fue rechazado por
        // WITH CHECK (yala_not_authorized transitorio-DE-ESTADO) — al ser APROBADO el MISMO delta aplicaría.
        // Otros códigos permanentes (yala_bad_request) NO se re-driven. Corre DENTRO del `saveWithAuthor`
        // de `applyPulledPage` → sin save extra.
        if model.status == "active", priorStatus != "active",
           let uid = model.userID, let current = currentUserIDProvider(),
           uid.lowercased() == current.lowercased() {
            reviveDeadLetteredNotAuthorized(groupID: delta.groupID, context: context)
            // H-2026-07-18-3: re-join hueco de cursor. Mientras el PROPIO user estuvo `pendingApproval`, RLS
            // ocultó el contenido del grupo PERO el cursor por-grupo avanzó igual → al pasar a `active` el
            // pull incremental jamás re-visita ese hueco. Resetear el cursor de ESTE grupo a 0 (en
            // `applyPulledPage`, tras el merge de cursores) fuerza un re-pull completo. Rama MÁS ESTRECHA que
            // el re-drive: SOLO la transición pendingApproval→active — un born-remote `nil`→active trae el
            // contenido de una vez (priorStatus nil NO matchea) y NO debe resetear.
            if priorStatus == SplitMemberStatus.pendingApproval.rawValue {
                cursorResetGroupIDs.insert(delta.groupID)
            }
        }
    }

    /// Revive (dead-letter → pendiente) las filas de outbox de un grupo rechazadas por
    /// `upstream_400:yala_not_authorized` — el próximo push las reintenta (A2). Sin save propio (corre
    /// dentro del `saveWithAuthor` del apply). `#Predicate` concreto + igualdad exacta sobre el opcional.
    private func reviveDeadLetteredNotAuthorized(groupID: String, context: ModelContext) {
        let target = "upstream_400:yala_not_authorized"
        let descriptor = FetchDescriptor<GroupSyncOutbox>(
            predicate: #Predicate { $0.groupID == groupID && $0.rejectedReason == target })
        do {
            for row in try context.fetch(descriptor) {
                row.rejectedReason = nil
                row.rejectedAt = nil
                // B2: la fila vuelve a ser PENDIENTE → re-entra al espejo (las dead-letter están
                // excluidas; el dead-letter borró su archivo). Misma vuelta síncrona del save del apply.
                writeMirrorEntry(for: row)
            }
        } catch {
            #if DEBUG
            logger.error("GroupsSync: revive dead-lettered falló: \(error)")
            #endif
        }
    }

    // MARK: fetch por identidad (concreto por tipo — regla `#Predicate`)

    private func fetchSplitExpense(id: UUID, context: ModelContext) throws -> SplitExpense? {
        var d = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
        return try context.fetch(d).first
    }
    private func fetchSplitShare(id: UUID, context: ModelContext) throws -> SplitShare? {
        var d = FetchDescriptor<SplitShare>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
        return try context.fetch(d).first
    }
    private func fetchSplitSettlement(id: UUID, context: ModelContext) throws -> SplitSettlement? {
        var d = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.id == id }); d.fetchLimit = 1
        return try context.fetch(d).first
    }
    private func fetchSplitGroup(zoneID: String, context: ModelContext) throws -> SplitGroup? {
        var d = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneID }); d.fetchLimit = 1
        return try context.fetch(d).first
    }
    /// Dual-match del `member_key` (G3): PRIMERO por el campo directo `SplitMember.memberKey` (members del
    /// canal backend — born-remote y ya-adoptados); si no matchea, FALLBACK por `cloudKitUserRecordID` para
    /// una fila preexistente del mundo CloudKit (grupos migrados G6-era, cuyo `member_key` server-side ES su
    /// viejo record-name). El caller (applyMember) escribe `memberKey` al adoptar → el próximo apply matchea
    /// por el path directo y no re-cae al fallback. `#Predicate` CONCRETO por tipo + igualdad exacta sobre el
    /// opcional (patrón seguro, regla inviolable — nada de `localizedStandardContains`/coalesce sobre opcional).
    private func fetchSplitMember(zoneID: String, memberKey: String, context: ModelContext) throws -> SplitMember? {
        var direct = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.memberKey == memberKey })
        direct.fetchLimit = 1
        if let hit = try context.fetch(direct).first { return hit }

        var legacy = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.cloudKitUserRecordID == memberKey })
        legacy.fetchLimit = 1
        return try context.fetch(legacy).first
    }

    // MARK: - Gate 5/5 del bridge remoto (molde SplitSyncManager.processPendingRemoteChanges)

    private func scheduleBridge(expenseIDs: [UUID], settlementIDs: [UUID]) {
        guard !expenseIDs.isEmpty || !settlementIDs.isEmpty, GroupTransactionBridge.shared.isReady else { return }

        // Autoridad de quiescencia enrutada por storageMode (byte-idéntico al gate del canal CKSyncEngine).
        switch StorageModeSignalRouter.quiescenceSource(mode: CloudSyncFlags.storageMode) {
        case .cloudEngine:
            guard SyncQuiescenceCoordinator.shared.isQuiescentForEngineSaves else {
                scheduleBridgeRetry(expenseIDs: expenseIDs, settlementIDs: settlementIDs, after: 8)
                return
            }
        case .icloudImport:
            let decision = SubcategoryDedupGate.decide(
                now: now(),
                lastImportDate: iCloudSyncService.shared.lastSuccessfulImportDate,
                isSyncing: iCloudSyncService.shared.status.isImporting,
                lastDedupRunAt: nil
            )
            guard decision == .run else {
                let retryAfter: TimeInterval
                if case .waitQuiescence(let t) = decision { retryAfter = max(t, 1) } else { retryAfter = 8 }
                scheduleBridgeRetry(expenseIDs: expenseIDs, settlementIDs: settlementIDs, after: retryAfter)
                return
            }
        }

        runBridge(expenseIDs: expenseIDs, settlementIDs: settlementIDs)
    }

    private func runBridge(expenseIDs: [UUID], settlementIDs: [UUID]) {
        if !expenseIDs.isEmpty {
            do { try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: expenseIDs) }
            catch {
                #if DEBUG
                logger.error("GroupsSync: bridgeRemoteExpenses falló: \(error)")
                #endif
            }
        }
        if !settlementIDs.isEmpty {
            do { try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: settlementIDs) }
            catch {
                #if DEBUG
                logger.error("GroupsSync: bridgeRemoteSettlements falló: \(error)")
                #endif
            }
        }
    }

    private func scheduleBridgeRetry(expenseIDs: [UUID], settlementIDs: [UUID], after seconds: TimeInterval) {
        bridgeRetryTask?.cancel()
        bridgeRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            self.scheduleBridge(expenseIDs: expenseIDs, settlementIDs: settlementIDs)
        }
    }

    // MARK: - Decode del pull (envelope de wire)

    /// Decodifica el envelope `{ deltas, cursors, memberships }` de `GET /groups/pull` a `GroupPulledPage`.
    static func decodePage(_ data: Data) throws -> GroupPulledPage {
        let decoded = try JSONDecoder().decode(RawGroupPullResponse.self, from: data)
        let deltas: [GroupPulledDelta] = decoded.deltas.map { raw in
            GroupPulledDelta(
                entityType: raw.entityType,
                groupID: raw.groupID,
                rawSyncID: raw.syncID,
                syncID: raw.syncID.flatMap { UUID(uuidString: $0) },
                op: SyncOutboxOp(rawValue: raw.op) ?? .upsert,
                fields: raw.fields ?? [:],
                fieldHlcs: raw.fieldHlcs ?? [:],
                hlc: raw.hlc,
                serverSeq: raw.serverSeq,
                schemaVersion: raw.schemaVersion ?? 1
            )
        }
        return GroupPulledPage(
            deltas: deltas,
            cursors: decoded.cursors ?? [:],
            memberships: decoded.memberships ?? []
        )
    }

    // MARK: - cursors JSON

    private func decodeCursors(_ json: String) -> [String: Int64] {
        guard let data = json.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: Int64].self, from: data) else { return [:] }
        return map
    }

    private func encodeCursors(_ map: [String: Int64]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(map) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Decodificadores de valor de wire (reusan WireValueDecoder)

    private func wireString(_ v: WireValue?) -> String? {
        guard let v else { return nil }
        if case .string(let s) = v { return s }
        return nil
    }
    private func wireDouble(_ v: WireValue?) -> Double? { v.flatMap(WireValueDecoder.double) }
    private func wireBool(_ v: WireValue?) -> Bool? {
        guard let v else { return nil }
        if case .bool(let b) = v { return b }
        return nil
    }
    private func wireUUID(_ v: WireValue?) -> UUID? {
        guard let s = wireString(v) else { return nil }
        return UUID(uuidString: s)
    }
    private func wireDate(_ v: WireValue?) -> Date? {
        guard let s = wireString(v) else { return nil }
        return WireValueDecoder.date(.string(s))
    }
}

// MARK: - Merkle client-side (endurecimiento B1)

extension GroupsSyncClient {

    /// Verifica la integridad Merkle de TODOS los grupos con cursor y, si hay divergencia, emite UNA señal
    /// de canario por corrida (`groupMerkleDivergence` con el COUNT) + remedia UNA vez por sesión (reset del
    /// cursor de cada grupo divergente + re-pull). `now` inyectado (cadencia). O(grupos): un fetch Merkle por
    /// grupo, secuencial — el corpus real es pequeño; residual documentado ~200 grupos.
    func runGroupMerkleVerification(context: ModelContext, now: Date) async {
        let cursor: GroupSyncCursor
        do {
            cursor = try loadOrCreateCursor(context)
        } catch {
            GroupsSyncBreadcrumb.groupsMerkleSkipped(reason: "cursor-load-failed")
            return
        }
        let groupIDs = decodeCursors(cursor.groupCursorsJSON).keys.sorted()

        var divergentGroups: [String] = []
        var verifiedGroups = 0
        for gid in groupIDs {
            switch await verifyGroupIntegrity(groupID: gid, context: context) {
            case .converged:
                verifiedGroups += 1
            case .diverged:
                verifiedGroups += 1
                divergentGroups.append(gid)
            case .skipped:
                continue  // precondición no satisfecha (breadcrumb ya emitido); no cuenta ni remedia
            }
        }

        // La cadencia se re-arma tras CUALQUIER verificación intentada (molde personal: reset del contador +
        // sello temporal aunque todos hayan sido skip — evita reintentar cada 60s).
        lastMerkleAt = now
        completedPullsSinceMerkle = 0

        guard !divergentGroups.isEmpty else {
            if verifiedGroups > 0 { GroupsSyncBreadcrumb.groupsMerkleConverged(groups: verifiedGroups) }
            return
        }

        // UNA señal por corrida (params: count de grupos divergentes) — jamás por-grupo (evita PII y ruido).
        MetricsService.groupMerkleDivergence(groupCount: divergentGroups.count)
        GroupsSyncBreadcrumb.groupsMerkleDivergence(groups: divergentGroups.count)

        // Remediación UNA vez por sesión: reset del cursor de cada grupo divergente + un re-pull.
        guard !didRemediateGroupMerkleThisSession else { return }
        didRemediateGroupMerkleThisSession = true
        resetGroupCursors(divergentGroups, context: context)
        _ = await pullUntilExhausted(context: context)
        GroupsSyncBreadcrumb.groupsMerkleRemediated(groups: divergentGroups.count)
    }

    /// Verifica la integridad Merkle de UN grupo. Guards EN ORDEN (molde `CloudSyncEngine.verifyIntegrity`,
    /// adaptado por-grupo): (1) outbox VIVO del grupo == 0; (2) dead-letters del grupo == 0 ([R7]: un
    /// dead-letter PERMANENTE deshabilita el Merkle de ESE grupo para siempre — aceptado; solo
    /// `yala_not_authorized` revive vía re-drive al aprobar al member); (3) último pull del canal completado;
    /// (4) canon `c1`; ([R4]) corpus-vacío-remoto + local no-vacío → remoción de membership (skip, sin
    /// canario). Divergencia real → `.diverged` (el canario/remediación los agrega el caller).
    func verifyGroupIntegrity(groupID gid: String, context: ModelContext) async -> MerkleVerdict {
        // (1) outbox VIVO del grupo.
        let liveOutbox: Int
        do { liveOutbox = try liveOutboxCount(groupID: gid, context: context) }
        catch { return .skipped(reason: "outbox-fetch-failed") }
        guard liveOutbox == 0 else {
            GroupsSyncBreadcrumb.groupsMerkleSkipped(reason: "outbox-pending:\(liveOutbox)")
            return .skipped(reason: "outbox-pending")
        }
        // (2) dead-letters del grupo ([R7]).
        let deadLetters: Int
        do { deadLetters = try groupDeadLetteredCount(groupID: gid, context: context) }
        catch { return .skipped(reason: "dead-letter-fetch-failed") }
        guard deadLetters == 0 else {
            GroupsSyncBreadcrumb.groupsMerkleSkipped(reason: "dead-letters:\(deadLetters)")
            return .skipped(reason: "dead-letters")
        }
        // (3) último pull del canal completado.
        guard lastPullCycleCompleted else {
            GroupsSyncBreadcrumb.groupsMerkleSkipped(reason: "no-completed-pull")
            return .skipped(reason: "no-completed-pull")
        }

        // Snapshot remoto.
        let outcome = await merkleClient.fetchMerkle(groupID: gid)
        guard case .snapshot(let remote) = outcome else {
            GroupsSyncBreadcrumb.groupsMerkleSkipped(reason: "fetch:\(outcome)")
            return .skipped(reason: "fetch-failed")
        }
        // (4) canon (nunca comparar contratos distintos — divergencia FALSA permanente).
        guard remote.canonVersion == "c1" else {
            GroupsSyncBreadcrumb.groupsMerkleSkipped(reason: "canon:\(remote.canonVersion)")
            return .skipped(reason: "canon-version-mismatch")
        }

        let local = GroupMerkleProjection.computeLocalMerkle(groupID: gid, context: context)

        // [R4] Política remoto-vacío: root remoto de corpus VACÍO (todas las entities count 0) + local no
        // vacío → NO es divergencia, es la firma de remoción de membership vía RLS (el server responde tablas
        // vacías al no-member). Skip SIN canario ni remediación; la limpieza llega por memberships del pull.
        let remoteEmpty = remote.entities.values.allSatisfy { $0.count == 0 }
        let localEmpty = local.entities.values.allSatisfy { $0.count == 0 }
        if remoteEmpty && !localEmpty {
            GroupsSyncBreadcrumb.groupsMerkleEmptyRemote()
            return .skipped(reason: "empty-remote")
        }

        // Comparación por entidad (las 5 SIEMPRE — grupos no tiene cuarentena ni tablas sin cablear) + root.
        var diverged: [String] = []
        for table in GroupMerkleProjection.entityTables.sorted() {
            guard let localEntity = local.entities[table] else { continue }
            if remote.entities[table]?.hash != localEntity.hashHex { diverged.append(table) }
        }
        if diverged.isEmpty, remote.root != local.rootHex { diverged.append("root") }

        return diverged.isEmpty ? .converged : .diverged(entities: diverged)
    }

    /// Filas de outbox VIVAS (no dead-letter) de un grupo. Cero → el grupo está quiescente para el Merkle.
    private func liveOutboxCount(groupID gid: String, context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<GroupSyncOutbox>(
            predicate: #Predicate { $0.groupID == gid && $0.rejectedReason == nil }))
    }

    /// Filas de outbox en DEAD-LETTER de un grupo ([R7]). Cero → sin rechazo permanente pendiente.
    private func groupDeadLetteredCount(groupID gid: String, context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<GroupSyncOutbox>(
            predicate: #Predicate { $0.groupID == gid && $0.rejectedReason != nil }))
    }

    /// Resetea a 0 el cursor de pull de los grupos dados (remediación: fuerza re-pull completo del grupo).
    /// Los que no estén en el mapa se dejan intactos. Persiste bajo `outboxSaveAuthor`.
    private func resetGroupCursors(_ gids: [String], context: ModelContext) {
        do {
            let cursor = try loadOrCreateCursor(context)
            var map = decodeCursors(cursor.groupCursorsJSON)
            for gid in gids { map[gid] = 0 }
            try saveWithAuthor(context) { cursor.groupCursorsJSON = encodeCursors(map) }
        } catch {
            #if DEBUG
            logger.error("GroupsSync: resetGroupCursors falló: \(error)")
            #endif
        }
    }

    /// Re-arma el estado Merkle POR SESIÓN (una nueva sesión debe poder remediar de nuevo). Lo llama
    /// `stopLoop()` (frontera de sesión). No toca cursores persistidos — solo el estado en-memoria.
    func resetMerkleSessionState() {
        completedPullsSinceMerkle = 0
        lastMerkleAt = nil
        lastPullCycleCompleted = false
        didRemediateGroupMerkleThisSession = false
    }
}

// MARK: - PendingGroupRow

/// Fila de outbox de Grupos acumulada en memoria durante un drain, materializada a `@Model` al persistir.
private struct PendingGroupRow {
    let syncID: UUID
    let groupID: String
    let entityType: String
    let op: SyncOutboxOp
    let hlc: String
    let clientMutationID: UUID
    let fieldsJSON: String
    let fieldHlcsJSON: String?
    let author: String
    let createdAt: Date

    @MainActor
    func makeModel() -> GroupSyncOutbox {
        GroupSyncOutbox(
            syncID: syncID, groupID: groupID, entityType: entityType, op: op, hlc: hlc,
            clientMutationID: clientMutationID, fieldsJSON: fieldsJSON, fieldHlcsJSON: fieldHlcsJSON,
            author: author, tombstoneReason: op == .tombstone ? SyncTombstoneReason.user.rawValue : nil,
            createdAt: createdAt
        )
    }

    /// DTO del espejo App Group (B2). `author` = la CONSTANTE de re-inserción del canal (echo-suppression),
    /// NO el autor de la transacción de origen (diagnóstico que no viaja en la identidad — molde personal).
    func mirrorEntry(userID: String) -> GroupsOutboxMirrorEntry {
        GroupsOutboxMirrorEntry(
            userID: userID, syncID: syncID, groupID: groupID, entityType: entityType,
            op: op.rawValue, hlc: hlc, clientMutationID: clientMutationID,
            fieldsJSON: fieldsJSON, fieldHlcsJSON: fieldHlcsJSON,
            tombstoneReason: op == .tombstone ? SyncTombstoneReason.user.rawValue : nil,
            author: GroupsOutboxMirror.author, createdAt: createdAt
        )
    }
}

// MARK: - Outcomes del ciclo de vida (G4)

/// Resultado de UNA página del pull (lo agrega `pullUntilExhausted`). `saved == false` = el save de la
/// página falló → el cursor NO avanzó (A1).
enum GroupsPullPageOutcome: Equatable {
    case applied(deltas: Int, saved: Bool)
    case sessionExpired
    case accountUnavailable
    case transient
}

/// Resultado de una vuelta COMPLETA del pull (hasta agotar). El loop lo mapea a `CadenceOutcome`.
enum GroupsPullOutcome: Equatable {
    case completed(pages: Int, deltasApplied: Int)
    case sessionExpired
    case accountUnavailable
    case transient
}

/// Mapeo PURO de los outcomes del canal de Grupos al `CadenceOutcome` común de `SyncCadencePolicy` (A4:
/// se REUTILIZA la política del personal — sin `GroupsSyncCadencePolicy` propio; esto solo traduce el eje).
nonisolated enum GroupsSyncCadence {
    /// `PushOutcome` → `CadenceOutcome` de STOP/transitorio. `nil` = push OK (`.completed`): seguir al pull.
    static func stopOutcome(push: PushOutcome) -> SyncCadencePolicy.CadenceOutcome? {
        switch push {
        case .completed: return nil
        case .sessionExpired: return .sessionExpired
        case .accountUnavailable: return .accountUnavailable
        case .transient: return .transient
        }
    }

    /// `GroupsPullOutcome` → `CadenceOutcome`.
    static func outcome(pull: GroupsPullOutcome) -> SyncCadencePolicy.CadenceOutcome {
        switch pull {
        case .completed: return .completed
        case .sessionExpired: return .sessionExpired
        case .accountUnavailable: return .accountUnavailable
        case .transient: return .transient
        }
    }
}

// MARK: - Wire types (Grupos)

/// Delta de wire de Grupos (espeja `SyncDelta` + `group_id`; `sync_id` nullable para `split_groups`).
struct GroupSyncDelta: Equatable {
    let entityType: String          // TABLA Postgres (split_expenses, …)
    let groupID: String
    let syncID: UUID?               // nil ⇒ split_groups (wire emite sync_id=null)
    let op: SyncOutboxOp
    let fieldsRawJSON: String?
    let fieldHlcsRawJSON: String?
    let hlc: String
    let clientMutationID: UUID
    let schemaVersion: Int
}

/// Respuesta de `POST /groups/push`.
private struct GroupPushResponse: Decodable {
    let results: [SyncDeltaResult]
}

/// Vista PARALELA de la respuesta del push SOLO para el `outcome` (el `SyncDeltaResult` local lo descarta).
/// `outcome.message` = código sanitizado del rechazo upstream (yala_*); `outcome.reason` = motivo del noop
/// (group_not_found). Ambos son constantes del RPC (sin PII).
private struct RawOutcomeResponse: Decodable {
    let results: [RawOutcomeResult]
}

private struct RawOutcomeResult: Decodable {
    let clientMutationID: String?
    let outcome: RawOutcome?

    struct RawOutcome: Decodable {
        let message: String?
        let reason: String?
    }

    enum CodingKeys: String, CodingKey {
        case clientMutationID = "client_mutation_id"
        case outcome
    }
}

/// Delta bajado del pull de Grupos (ya decodificado). `rawSyncID` = el `sync_id` crudo del wire (member_key
/// para group_members; UUID-string para las entidades de contenido; `null` para split_groups).
struct GroupPulledDelta: Equatable {
    let entityType: String          // TABLA Postgres
    let groupID: String
    let rawSyncID: String?
    let syncID: UUID?
    let op: SyncOutboxOp
    let fields: [String: WireValue]
    let fieldHlcs: [String: String]
    let hlc: String
    let serverSeq: Int64
    let schemaVersion: Int
}

/// Página del pull de Grupos: deltas + cursores autoritativos por grupo + memberships descubiertas.
struct GroupPulledPage: Equatable {
    let deltas: [GroupPulledDelta]
    let cursors: [String: Int64]
    let memberships: [String]
}

private struct RawGroupPullResponse: Decodable {
    let deltas: [RawGroupPulledDelta]
    let cursors: [String: Int64]?
    let memberships: [String]?
}

private struct RawGroupPulledDelta: Decodable {
    let entityType: String
    let groupID: String
    let syncID: String?
    let op: String
    let fields: [String: WireValue]?
    let fieldHlcs: [String: String]?
    let hlc: String
    let serverSeq: Int64
    let schemaVersion: Int?

    enum CodingKeys: String, CodingKey {
        case entityType = "entity_type"
        case groupID = "group_id"
        case syncID = "sync_id"
        case op
        case fields
        case fieldHlcs = "field_hlcs"
        case hlc
        case serverSeq = "server_seq"
        case schemaVersion = "schema_version"
    }
}
