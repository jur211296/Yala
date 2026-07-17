//
//  CloudMigrationController.swift
//  Yala
//
//  Dueño ÚNICO del `MigrationRunner` de producción (I14, P2). Antes de I14 el único conductor del runner
//  era el panel DEBUG (`CloudSyncMigrationPanelModel`); tener DOS runners vivos sobre el mismo journal
//  single-row duplicaría la ejecución de efectos (journal-then-execute N1). Este controller es la SSOT:
//  la UI real (`StorageSettingsView`) y el panel DEBUG consumen ESTE runner.
//
//  Responsabilidades: construir (perezosamente) el executor real + el runner con la señal de quiescencia
//  del import; orquestar los flujos de UI (migrar con consent→SIWA→claim, revertir, retomar, reintentar);
//  reflejar el journal vivo como estado `@Observable` derivado (`CloudMigrationUIState`); y el coordinator
//  de boot (`resumeIfNeeded`, P4) que retoma una migración matada a medias y re-arranca el runtime al
//  quedar la fase estable.
//
//  Solo se instancia si `CloudBackendConfig.isConfigured` (staging/DEV) — en producción placeholder el
//  accessor `shared` queda `nil` y la fila "Almacenamiento" de Ajustes no aparece.
//
//  `@MainActor @Observable`: muta `ModelContext`/`@Model` y coordina la UI (regla inviolable).
//

import Foundation
import SwiftData

// MARK: - Estado derivado para la UI (PURO, testeable)

/// El estado que la UI de almacenamiento pinta, derivado del journal + `storageMode` + testigos de mount.
/// `nonisolated`: función pura de sus entradas (sin `ModelContext`/red/`Date`) → testeable directamente.
nonisolated enum CloudMigrationUIState: Equatable {
    /// Modo iCloud privado, sin migración en vuelo → ofrecer "Migrar a la nube".
    case idle
    /// Migración (ida) en vuelo → progreso.
    case migrating(MigrationUIStep)
    /// Reversa en vuelo → progreso.
    case reverting(MigrationUIStep)
    /// Relanzamiento asistido pendiente (cruzó el process boundary): el usuario debe cerrar y reabrir Yala.
    case needsRelaunch(RelaunchDirection)
    /// Modo Nube estable → ofrecer "Volver a iCloud" + estado de sync.
    case cloudActive
    /// Seguidor: otro device lidera la migración de esta cuenta.
    case waitingForLeader
    /// Un terminal de FALLO (rollback) — ofrecer "Reintentar" con mensaje honesto.
    case failed(FailureKind)

    enum RelaunchDirection: Equatable {
        /// Ida/adopt: apagar el mirror (montar el store en modo `.cloud`).
        case toCloud
        /// Reversa: re-encender el mirror `.private` (volver a iCloud).
        case toICloud
    }

    enum FailureKind: Equatable { case migration, reverse }
}

/// Progreso legible de una fase transicional. `fraction` alimenta la barra; `phase` el label localizado.
nonisolated struct MigrationUIStep: Equatable {
    let fraction: Double
    let phase: MigrationPhase
}

/// La derivación PURA del estado de UI. Aislada como `enum` estático para testearla sin el controller.
nonisolated enum CloudMigrationUIStateDeriver {

    static func derive(
        storageMode: StorageMode,
        phase: MigrationPhase,
        mirrorOffArmed: Bool,
        mountedMode: StorageMode
    ) -> CloudMigrationUIState {
        // 1) Relanzamiento de IDA/adopt: el mirror-off está ARMADO pero este proceso aún montó `.icloud`
        //    (el mirror sigue vivo) → hay que MATAR Y REABRIR para montarlo en `.cloud`. Cubre el cutover
        //    (`cutover(.mirrorOff)`) y el adopt (`notStarted` + `.cloud` armado, #30).
        if mirrorOffArmed && mountedMode == .icloud {
            return .needsRelaunch(.toCloud)
        }
        // 2) Relanzamiento de REVERSA: la máquina está en `reverseMountMirror` pero este proceso aún montó
        //    `.cloud` (mirror OFF) → hay que MATAR Y REABRIR para re-encender el mirror `.private`.
        if phase == .reverseMountMirror && mountedMode == .cloud {
            return .needsRelaunch(.toICloud)
        }
        switch phase {
        case .failedRollback:
            return .failed(.migration)
        case .reverseFailedRollback:
            return .failed(.reverse)
        case .waitingForLeader:
            return .waitingForLeader
        case .reverseConfirm, .reverseClaimLeader, .reverseDrainAll, .reverseVerify,
             .reverseFreezeBackend, .reverseMountMirror, .reverseReconcile, .reverseUpload:
            return .reverting(MigrationUIStep(fraction: fraction(for: phase), phase: phase))
        case .consent, .authenticating, .claimingMigration, .assigningIdentity,
             .uploadingSnapshot, .verifying, .cutover:
            return .migrating(MigrationUIStep(fraction: fraction(for: phase), phase: phase))
        case .dryRun:
            // No-durable → normaliza según el modo real (la máquina la repone a su origen en resume).
            return storageMode == .cloud ? .cloudActive : .idle
        case .done:
            return .cloudActive
        case .icloudActive:
            // Terminal de la reversa: el device volvió a iCloud → ofrecer migrar de nuevo.
            return .idle
        case .notStarted:
            // `.cloud` + notStarted = device ADOPTADO estable (#30) → cloudActive; si no, iCloud idle.
            return storageMode == .cloud ? .cloudActive : .idle
        }
    }

    /// Fracción de progreso (0…1) por fase, para la barra. Aproximada (no lineal en el tiempo real).
    static func fraction(for phase: MigrationPhase) -> Double {
        switch phase {
        // Ida
        case .notStarted, .dryRun:      return 0
        case .consent:                  return 0.08
        case .authenticating:           return 0.15
        case .claimingMigration:        return 0.22
        case .assigningIdentity:        return 0.35
        case .uploadingSnapshot:        return 0.55
        case .verifying:                return 0.75
        case let .cutover(sub):         return 0.80 + 0.03 * Double(sub.rawValue)  // .pending…mirrorOff
        case .done:                     return 1.0
        case .failedRollback:           return 0
        // Reversa
        case .reverseConfirm:           return 0.05
        case .reverseClaimLeader:       return 0.15
        case .reverseDrainAll:          return 0.30
        case .reverseVerify:            return 0.50
        case .reverseFreezeBackend:     return 0.62
        case .reverseMountMirror:       return 0.70
        case let .reverseReconcile(sub): return 0.78 + 0.04 * Double(sub.rawValue)
        case .reverseUpload:            return 0.95
        case .icloudActive:             return 1.0
        case .waitingForLeader:         return 0.20
        case .reverseFailedRollback:    return 0
        }
    }
}

// MARK: - Controller

@MainActor
@Observable
final class CloudMigrationController {

    /// Instancia de producción. `nil` hasta que `configureShared(context:)` la crea (solo si
    /// `CloudBackendConfig.isConfigured`).
    static private(set) var shared: CloudMigrationController?

    /// Crea la instancia `shared` con el `mainContext` (idempotente). No-op si no está configurado el
    /// backend (producción placeholder). Lo llama `AppBootstrapper` en el paso 14.6.
    static func configureShared(context: ModelContext) {
        guard CloudBackendConfig.isConfigured else { return }
        if shared == nil { shared = CloudMigrationController(context: context) }
    }

    // MARK: Estado observable (derivado del journal)

    var uiState: CloudMigrationUIState = .idle
    var isWorking = false
    /// Mensaje de error localizado (para el `.alert` de la vista). `nil` = sin error.
    var lastError: String?

    /// Snapshot del journal (para labels/diagnóstico de la vista).
    private(set) var journaledPhase: MigrationPhase = .notStarted
    private(set) var pendingEffectCount = 0
    private(set) var isQuiescent = false

    /// Banner S11 (D5): el runtime del dominio se detuvo por sesión expirada con cambios pendientes.
    private(set) var syncNeedsSignIn = false
    private(set) var pendingUploadCount = 0

    // MARK: Deps

    private let context: ModelContext
    private let deviceID = MigrationWorkExecutor.vendorDeviceID
    private var _runner: MigrationRunner?

    private init(context: ModelContext) {
        self.context = context
        refresh()
    }

    // MARK: - Factory compartido (P2) — mismo ensamblado que el panel DEBUG

    /// Construye el executor REAL (staging/prod) con la sesión viva, el motor, los clients y la señal de
    /// quiescencia del import para el flujo de adopt (#30). Extraído para que el panel DEBUG lo reuse
    /// (dry-run de huérfanas) sin duplicar la construcción — evita DOS runners vivos.
    static func makeExecutor(context: ModelContext, deviceID: String) -> MigrationWorkExecutor {
        let session = LiveCloudSessionProvider()
        let account = CloudAccountClient()
        let engine = CloudSyncEngine()
        let token: () async -> String? = { await CloudAuthService.shared.accessToken() }
        let attest: () async -> String? = { try? await session.attestToken() }
        let push = SyncPushClient(tokenProvider: token, attestProvider: attest)
        let pull = SyncPullClient(tokenProvider: token, attestProvider: attest)
        let merkle = SyncMerkleClient(tokenProvider: token, attestProvider: attest)
        // Provider REAL de la sesión hacia el claim/faro. RESIDUAL (ajuste #5): el fallback
        // `?? "apple"` solo aplica con la key perdida (población ~0 — se escribe en el mismo
        // sign-in); una sesión Google sin key claimearía "apple". El default `= "apple"` del init
        // se CONSERVA como red para tests y callers legacy.
        return MigrationWorkExecutor(
            engine: engine, pushClient: push, pullClient: pull, merkleClient: merkle,
            accountClient: account, session: session, context: context, deviceID: deviceID,
            // Fallback residual (review adversarial #4): key perdida ⇒ "apple" VERBATIM en
            // `profiles.provider` si el claim crea la fila → falso mismatch perpetuo en la red R9
            // post-claim de sesión 2. Población ~0 (la key se escribe en el propio sign-in).
            provider: CloudAuthService.shared.storedProvider() ?? "apple",
            adoptQuiescenceSignal: { iCloudSyncService.shared.isImportQuiescent })
    }

    /// El runner de producción (lazy, único). El panel DEBUG delega en este mismo runner.
    var runner: MigrationRunner {
        if let _runner { return _runner }
        let r = MigrationRunner(
            context: context,
            executor: Self.makeExecutor(context: context, deviceID: deviceID),
            deviceID: deviceID,
            quiescenceSignal: { iCloudSyncService.shared.isImportQuiescent })
        _runner = r
        return r
    }

    // MARK: - Flujos de UI

    /// Ruta del consent (para la telemetría §j.4).
    enum ConsentPath: String { case migration, adopt }

    /// Migrar a la nube (o ADOPTAR una cuenta ya poblada, #30 — el mismo flujo: consent → SIWA → claim).
    /// El consent + su registro/telemetría ya ocurrieron en `CloudConsentView`; aquí se conduce la máquina:
    /// `notStarted → consent → authenticating` (SIWA real) `→ claimingMigration` y drive autónomo.
    func startMigration(consentPath: ConsentPath) async {
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        let r = runner
        await r.startMigration(dryRun: false)   // notStarted → consent
        await r.submit(.consentAccepted)         // consent → authenticating
        do {
            try await CloudAuthService.shared.signInWithApple()
            await r.submit(.signInSucceeded)     // authenticating → claimingMigration → drive
        } catch {
            #if DEBUG
            print("CloudMigrationController.startMigration: SIWA falló: \(error)")
            #endif
            lastError = L10n.Storage.Errors.signIn
            await r.submit(.signInFailed)        // authenticating → notStarted
        }
        refresh()
    }

    /// Adopt desde el Welcome (H4/pieza 2): conduce la máquina asumiendo una sesión SIWA YA viva —
    /// el Welcome corrió `signInWithApple()` + `GET /account/exists` (read-only) ANTES de llamar aquí,
    /// así que NO se re-lanza SIWA (evita el doble Face ID). Las fases `consent`/`authenticating` son
    /// no-durables: un kill entre submits normaliza a `notStarted` vía `resume` sin riesgo.
    /// Precondición: `CloudAuthService.shared.hasSession`.
    func startAdoptWithExistingSession() async {
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        let r = runner
        // S4 del review: un journal en failedRollback IGNORA startMigration → el retry
        // del Welcome sería un loop muerto (SIWA repetido sin progreso). Reset explícito
        // primero — espejo del botón "Reintentar" de Ajustes.
        refresh()
        if case .failed = uiState {
            await r.resetAfterRollback()
        }
        await r.startMigration(dryRun: false)   // notStarted → consent
        await r.submit(.consentAccepted)         // consent → authenticating
        await r.submit(.signInSucceeded)         // authenticating → claimingMigration → drive
        refresh()
    }

    /// Push-all del cierre de sesión (H4, camino `.cloud`): cicla el runtime (drain + push + prefs,
    /// paso 5.5 incluido) hasta que el outbox vivo quede en 0 VERIFICADO por fetch, o bloquea. Los
    /// pendientes JAMÁS se descartan — `.blocked` aborta el cierre y el usuario reintenta con red.
    /// `.coalesced` cuenta como ciclo sano (sin señal de fallo); el tope corta backends caídos.
    func pushAllPendingForSignOut(maxIterations: Int = 20) async -> CloudSignOutFlowLogic.PushAllVerdict {
        guard let runtime = CloudSyncRuntime.shared else {
            // Sin runtime en `.cloud` solo es seguro cerrar si no hay nada pendiente.
            let live = livePendingUploadCount()
            return live == 0 ? .drained : .blocked(pendingCount: live)
        }
        for iteration in 1...maxIterations {
            let outcome = await runtime.syncCycle(context: context)
            let succeeded = outcome == .completed || outcome == .coalesced
            if let verdict = CloudSignOutFlowLogic.pushAllVerdict(
                livePendingCount: livePendingUploadCount(),
                cycleSucceeded: succeeded,
                iteration: iteration,
                maxIterations: maxIterations
            ) {
                return verdict
            }
            // S1 del review: un ciclo de la cadencia EN VUELO devuelve `.coalesced`
            // SINCRÓNICO — sin esta pausa el loop quemaría las 20 iteraciones en
            // microsegundos y bloquearía con red sana. La pausa deja terminar el
            // ciclo en vuelo; la siguiente iteración corre un ciclo real.
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                break  // cancelación del caller
            }
        }
        return .blocked(pendingCount: livePendingUploadCount())
    }

    /// Filas vivas del outbox (`rejectedReason == nil`) — mismo criterio que el banner S11.
    /// Interno (no private): el coordinador de sign-out re-verifica JUSTO antes de armar
    /// el wipe (S2 — ventana post-drain).
    func livePendingUploadCount() -> Int {
        do {
            return try context.fetch(FetchDescriptor<SyncOutbox>())
                .filter { $0.rejectedReason == nil }.count
        } catch {
            #if DEBUG
            print("CloudMigrationController: Error contando outbox vivo: \(error)")
            #endif
            // Conservador: un conteo ilegible jamás debe habilitar un cierre con pendientes.
            return Int.max
        }
    }

    /// Volver a iCloud (reversa §h). El gate `ReverseEligibility` ya lo validó la vista (diálogos-primero);
    /// se emiten `reverseActivated` + `reverseConfirmed` JUNTOS (un kill entre ambos lo normaliza `resume`).
    func startReverse() async {
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        let r = runner
        await r.submit(.reverseActivated)    // done/notStarted → reverseConfirm(origin)
        await r.submit(.reverseConfirmed)    // → reverseClaimLeader → drive
        refresh()
    }

    /// Retomar una migración/reversa journaleada (botón "Retomar" + el coordinator de boot).
    func resume() async {
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        await runner.resume()
        refresh()
        startRuntimeIfStable()
    }

    /// Reintentar tras un rollback (SOLO en `failedRollback`/`reverseFailedRollback`).
    func resetAfterRollback() async {
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        await runner.resetAfterRollback()
        refresh()
    }

    /// Sondear al líder (fase `waitingForLeader`).
    func pollLeader() async {
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        await runner.pollLeader()
        refresh()
        startRuntimeIfStable()
    }

    // MARK: - Boot coordinator (P4)

    /// Coordinator de boot: lee el journal + efectos pendientes (baratos) y decide vía
    /// `MigrationBootDecision`. Retoma (`resume`) una migración transicional / con efectos pendientes,
    /// sondea al líder (`pollLeader`), o no hace nada. Al quedar la fase estable, re-arranca el runtime del
    /// dominio (el paso 14.7 pudo haberse cortado por P0 mientras la fase era transicional).
    func resumeIfNeeded() async {
        let (phase, hasPending) = readJournalDecisionInputs()
        journaledPhase = phase
        switch MigrationBootDecision.decide(phase: phase, hasPendingEffects: hasPending) {
        case .resume:
            await resume()
        case .pollLeader:
            await pollLeader()
        case .none:
            refresh()
            startRuntimeIfStable()
        }
    }

    /// Re-arranca el runtime del dominio si la fase ya es estable (post-resume). Idempotente
    /// (`startShared` es no-op si ya corre).
    private func startRuntimeIfStable() {
        let phase = readJournalDecisionInputs().phase
        guard CloudSyncFlags.storageMode == .cloud,
              MigrationRuntimeGate.isDomainStablePhase(phase) else { return }
        let ctx = context
        Task { await CloudSyncRuntime.startShared(context: ctx) }
    }

    // MARK: - Refresh (journal vivo → estado derivado)

    /// Re-lee el journal + testigos de mount (sin mutar) y recalcula `uiState`. Molde del panel DEBUG.
    func refresh() {
        isQuiescent = iCloudSyncService.shared.isImportQuiescent
        let (phase, pendingCount) = readJournalSnapshot()
        journaledPhase = phase
        pendingEffectCount = pendingCount

        let mountedMode = SwiftDataConfiguration.personalStoreMountedMode
        let mirrorOffArmed = StorageModePersistence.isMirrorOffArmed()
        uiState = CloudMigrationUIStateDeriver.derive(
            // M1: modo PERSISTIDO del dueño, no el efectivo — la UI de migración describe la
            // travesía del DEVICE (un `.cloud` efectivo espurio de una sesión secundaria mentiría).
            storageMode: StorageModePersistence.read(),
            phase: phase,
            mirrorOffArmed: mirrorOffArmed,
            mountedMode: mountedMode)

        refreshSyncBanner()
    }

    /// Banner S11 (D5): runtime detenido por sesión expirada con filas vivas pendientes → CTA sign-in.
    private func refreshSyncBanner() {
        guard CloudSyncFlags.storageMode == .cloud,
              CloudSyncRuntime.shared?.state == .stoppedUntilSignIn else {
            syncNeedsSignIn = false
            pendingUploadCount = 0
            return
        }
        let live = (try? context.fetch(FetchDescriptor<SyncOutbox>())
            .filter { $0.rejectedReason == nil }.count) ?? 0
        syncNeedsSignIn = live > 0
        pendingUploadCount = live
    }

    /// Re-firma para reanudar el sync detenido (banner S11).
    func signInToResumeSync() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await CloudAuthService.shared.signInWithApple()
            CloudSyncRuntime.shared?.handleBecameActive()   // re-evalúa la sesión y despierta la cadencia
        } catch {
            #if DEBUG
            print("CloudMigrationController.signInToResumeSync: SIWA falló: \(error)")
            #endif
            lastError = L10n.Storage.Errors.signIn
        }
        refresh()
    }

    // MARK: - Journal helpers (lectura pura, NO crean la fila)

    private func readJournalDecisionInputs() -> (phase: MigrationPhase, hasPending: Bool) {
        let (phase, count) = readJournalSnapshot()
        return (phase, count > 0)
    }

    private func readJournalSnapshot() -> (phase: MigrationPhase, pendingCount: Int) {
        var descriptor = FetchDescriptor<MigrationState>()
        descriptor.fetchLimit = 1
        do {
            guard let state = try context.fetch(descriptor).first else { return (.notStarted, 0) }
            return (state.readPhase().phase, state.readPendingEffects().count)
        } catch {
            #if DEBUG
            print("CloudMigrationController.readJournalSnapshot: fetch(MigrationState) falló: \(error)")
            #endif
            return (.notStarted, 0)
        }
    }

    // MARK: - Elegibilidad de reversa (para la vista)

    /// Veredicto `ReverseEligibility` + conteo de testigos con `ckRecordName` (para el copy). Lectura pura.
    func reverseEligibility() -> ReverseEligibility.Decision {
        let hasCKMap = ((try? context.fetchCount(
            FetchDescriptor<SyncIdentity>(predicate: #Predicate { $0.ckRecordName != nil }))) ?? 0) > 0
        return ReverseEligibility.decide(
            // M1: modo PERSISTIDO del dueño — la reversa es SU travesía; una sesión secundaria
            // jamás debe volverse elegible por el `.cloud` efectivo derivado del descriptor.
            storageMode: StorageModePersistence.read(),
            hasCKMap: hasCKMap,
            journaledPhase: journaledPhase)
    }

    /// ¿El mirror local trae el marcador del líder? (P6: la card de `.icloud`+notStarted cambia a copy de
    /// adopt vía `markerReconciliation` cuando hay marcador). Lectura pura.
    func markerDecision() -> MarkerDecision {
        let markerFound = ((try? context.fetchCount(FetchDescriptor<CloudMigrationMarker>())) ?? 0) > 0
        return MigrationStateMachine.markerReconciliation(
            markerFound: markerFound, journaledPhase: journaledPhase)
    }

    /// Dry-run §g.5: conteos EN MEMORIA de lo que migraría (read-only, para "Ver qué migraría").
    func dryRunCounts() -> (transactions: Int, categories: Int, accounts: Int, budgets: Int) {
        func count<M: PersistentModel>(_ type: M.Type) -> Int {
            (try? context.fetchCount(FetchDescriptor<M>())) ?? 0
        }
        return (count(TransactionItem.self), count(Category.self), count(Account.self), count(Budget.self))
    }
}
