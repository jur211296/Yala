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
//  del import; orquestar los flujos de UI (migrar con consent→sign-in Apple|Google→claim, revertir,
//  retomar, reintentar);
//  reflejar el journal vivo como estado `@Observable` derivado (`CloudMigrationUIState`); y el coordinator
//  de boot (`resumeIfNeeded`, P4) que retoma una migración matada a medias y re-arranca el runtime al
//  quedar la fase estable.
//
//  Solo se instancia si `CloudBackendConfig.isConfigured` — desde D-R1 paso 1 eso incluye producción, así
//  que `shared` ya NO es `nil` ahí. La fila "Almacenamiento" de Ajustes sigue sin aparecer, pero por el
//  flag remoto (percent 0), no por este accessor.
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

    /// R1 (relanzamiento cero): `mountedDecision` sustituye al `StorageMode` colapsado. Las dos preguntas
    /// que esta función le hace al testigo son sobre el MIRROR («¿sigue vivo?» / «¿ya está apagado?»), y un
    /// enum de dos valores no podía responderlas para un mount que no fuera ninguna de las dos decisiones
    /// nube. La tabla de estados de UI no se mueve: `localNoMirror` lleva mirror adjunto (MEDIDO), así que
    /// cae del mismo lado que antes en los dos términos.
    static func derive(
        storageMode: StorageMode,
        phase: MigrationPhase,
        mirrorOffArmed: Bool,
        mountedDecision: SwiftDataConfiguration.PersonalStoreDecision
    ) -> CloudMigrationUIState {
        let mirrorStillAttached = mountedDecision.attachesCloudKitMirror
        // 1) Relanzamiento de IDA/adopt: el mirror-off está ARMADO pero este proceso montó CON mirror (sigue
        //    vivo) → hay que MATAR Y REABRIR para montar sin él. Cubre el cutover (`cutover(.mirrorOff)`) y
        //    el adopt (`notStarted` + `.cloud` armado, #30).
        if mirrorOffArmed && mirrorStillAttached {
            return .needsRelaunch(.toCloud)
        }
        // 2) Relanzamiento de REVERSA: la máquina está en `reverseMountMirror` pero este proceso montó SIN
        //    mirror → hay que MATAR Y REABRIR para re-encender el mirror `.private`.
        if phase == .reverseMountMirror && !mirrorStillAttached {
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
    /// backend. Lo llama `AppBootstrapper` en el paso 14.6.
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

    /// #36 (H1): el resume está esperando a que el import de CloudKit quede quiescente (pre-espera de
    /// 300s), o venció el tope y quedó APARCADO VISIBLE. La card de Almacenamiento muestra el estado
    /// honesto mientras sea `true`; lo limpia cualquier camino de éxito de la pre-espera.
    private(set) var resumeWaitingForImport = false

    /// C-1: último veredicto del canal iCloud journaleado (`ICloudChannelVerdict`). La card de fallo elige
    /// con esto el copy HONESTO ("iCloud se quedó sin espacio" / "no tienes iCloud activo" / "no confirmó el
    /// último paso") en vez del genérico; `nil` = sin veredicto ⇒ copy genérico de siempre.
    private(set) var cutoverBlocker: ICloudChannelVerdict?

    /// C-1: el cutover está en el paso 4 esperando que iCloud confirme el marcador. Es el estado que antes
    /// se mostraba como un 89 % mudo, sin decir a qué se esperaba.
    var isWaitingICloudExport: Bool { journaledPhase == .cutover(.markerWritten) }

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
        // SIN `attestProvider` a propósito: `MigrationWorkExecutor` solo le pide `claim` y
        // `migrationProgress` → `POST /account/claim` y `POST /account/migration`, ambos por `requireUser`
        // (`gateway/src/sync/account.ts:68,132`). Los clients de sync que SÍ lo exigen (`push`/`pull`/
        // `merkle`) reciben `attest` tres líneas más abajo.
        let account = CloudAccountClient()
        let engine = CloudSyncEngine()
        let token: () async -> String? = { await CloudAuthService.shared.accessToken() }
        let attest: () async -> String? = { try? await session.attestToken() }
        let push = SyncPushClient(tokenProvider: token, attestProvider: attest)
        let pull = SyncPullClient(tokenProvider: token, attestProvider: attest)
        let merkle = SyncMerkleClient(tokenProvider: token, attestProvider: attest)
        // Provider REAL de la sesión hacia el claim/faro, leído VIVO en cada uso (I4 CERRADO en la
        // sesión 3 Google Sign-In, ajuste A1): el closure se evalúa EN el momento del claim/faro, no al
        // construir el executor — un runner nacido antes del sign-in ya no congela "apple" para una
        // sesión Google. RESIDUAL que PERSISTE (review adversarial #4 de sesión 1): el fallback
        // `?? "apple"` solo aplica con la key `keyProvider` perdida (población ~0 — se escribe en el
        // mismo sign-in); una sesión Google sin key claimearía "apple" → falso mismatch en la red R9.
        // El default `= { "apple" }` del init se CONSERVA como red para tests y callers legacy.
        return MigrationWorkExecutor(
            engine: engine, pushClient: push, pullClient: pull, merkleClient: merkle,
            accountClient: account, session: session, context: context, deviceID: deviceID,
            provider: { CloudAuthService.shared.storedProvider() ?? "apple" },
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
    ///
    /// ⚠️ El `rawValue` VIAJA (telemetría `cloudConsentAccepted(path:)` y, en los dos primeros, la
    /// máquina de migración): renombrar un case parte la serie histórica del dashboard. Si hiciera
    /// falta cambiar el nombre en Swift, el raw se fija explícito y NO se toca.
    ///
    /// `bornCloud` (A5 de D-A7) lo produce SOLO el Welcome — el alta nube de un usuario nuevo, que no
    /// pasa por la máquina de migración porque no hay nada que migrar. `StorageSettingsView` nunca lo
    /// asigna.
    enum ConsentPath: String { case migration, adopt, bornCloud }

    /// CÓMO se autentica la migración/adopt (C-7, 2026-07-27): `StorageMigrationSignInLogic.Plan`,
    /// explícito y sin default — un `.apple` implícito era el hardcode del hallazgo original, y un
    /// `provider` a secas no sabía expresar «ya hay sesión, no firmes». Lo resuelve la Logic en el
    /// productor; el belt de `startMigration` lo re-afirma para cualquier otra entrada.
    typealias SignInPlan = StorageMigrationSignInLogic.Plan

    /// Migrar a la nube (o ADOPTAR una cuenta ya poblada, #30 — el mismo flujo: consent → sign-in → claim).
    /// El consent + su registro/telemetría ya ocurrieron en `CloudConsentView` y el MÉTODO (Apple|Google)
    /// lo eligió el usuario en `StorageSignInChooserView` SOLO cuando no había sesión (Bloque C
    /// 2026-07-17: la entrada forzaba SIWA; C-7 2026-07-27: con sesión viva ya no se pregunta); aquí se
    /// conduce la máquina: `notStarted → consent → authenticating` (auth real, o reuso de la sesión)
    /// `→ claimingMigration` y drive autónomo.
    /// El sign-in exitoso escribe `keyProvider` ANTES de `.signInSucceeded` ⇒ el claim/faro (que leen
    /// `storedProvider()` VIVO, I4) estampan el método real.
    ///
    /// GUARD R9 (C-7): con `hasSession` la rama de auth NO se ejecuta, **llegue el plan que llegue**.
    /// Es defensa en profundidad, no redundancia: `signIn(with:)` sobrescribe la sesión en silencio
    /// (nuevo `sub`, nuevo `keyProvider`) y el canal de Grupos —que lee `currentUserID` vivo— pasaría a
    /// operar bajo la cuenta entrante sin un solo evento. Los datos personales y los grupos acabarían
    /// en cuentas distintas, contra `groups.signin.accountNote`. La decisión de producto vive en
    /// `StorageMigrationSignInLogic`; esto es el belt de la máquina.
    func startMigration(consentPath: ConsentPath, signIn plan: SignInPlan) async {
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        let r = runner
        await r.startMigration(dryRun: false)   // notStarted → consent
        await r.submit(.consentAccepted)         // consent → authenticating

        // Belt R9. `sessionIsUsable` NO es `hasSession`: pide un access token de verdad, porque una
        // sesión con el refresh token revocado (el usuario quitó «Iniciar sesión con Apple» en
        // Ajustes de iOS, o cerró sesión desde otro device) sigue figurando en el Keychain y
        // avanzaría la máquina hasta un claim que no puede autenticarse.
        let sessionIsUsable: Bool
        if CloudAuthService.shared.hasSession {
            sessionIsUsable = await CloudAuthService.shared.accessToken() != nil
        } else {
            sessionIsUsable = false
        }

        let provider: CloudSignInProvider
        switch StorageMigrationSignInLogic.execution(for: plan, sessionIsUsable: sessionIsUsable) {
        case .useLiveSession:
            await r.submit(.signInSucceeded)     // authenticating → claimingMigration → drive
            refresh()
            return
        case .failNoUsableSession:
            #if DEBUG
            print("CloudMigrationController.startMigration: plan .reuseLiveSession sin sesión usable")
            #endif
            lastError = L10n.Storage.Errors.signIn
            await r.submit(.signInFailed)        // authenticating → notStarted
            refresh()
            return
        case .authenticate(let chosen):
            provider = chosen
        }

        do {
            try await CloudAuthService.shared.signIn(with: provider)
            await r.submit(.signInSucceeded)     // authenticating → claimingMigration → drive
        } catch CloudAuthError.cancelled {
            // Cancel tipado (Google): volver a notStarted SIN alert — un cancel no es fallo
            // (semántica del Welcome). El cancel de SIWA sigue llegando como error genérico
            // (ASAuthorization no distingue) → rama de abajo, byte-idéntico con hoy.
            await r.submit(.signInFailed)        // authenticating → notStarted
        } catch {
            #if DEBUG
            print("CloudMigrationController.startMigration: sign-in \(provider.rawValue) falló: \(error)")
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
            return live == 0 ? .drained : .blocked(pendingCount: live, reason: .permanent)
        }
        for iteration in 1...maxIterations {
            let outcome = await runtime.syncCycle(context: context)
            if let verdict = CloudSignOutFlowLogic.pushAllVerdict(
                livePendingCount: livePendingUploadCount(),
                cycleOutcome: outcome,
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
        // Tope alcanzado con pendientes: transitorio (aún drenando; el consumidor `.cloud`/
        // secundario lo re-mapea a su alert permanente al fijar la fase — byte-idéntico).
        return .blocked(pendingCount: livePendingUploadCount(), reason: .transient)
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

    /// Retomar una migración/reversa journaleada (botón "Retomar" + el coordinator de boot + el
    /// re-kick de foreground, #36). Guard de reentrada a nivel controller (A2 del review): con la
    /// pre-espera de 300s, un boot-resume y el rekick del primer `.active` podrían pre-esperar EN
    /// PARALELO y el `defer` del primero re-habilitaría "Retomar" con el otro aún en vuelo.
    func resume() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        guard await awaitImportQuiescenceForResume() else {
            refresh()
            return
        }
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

    /// Sondear al líder (fase `waitingForLeader`). Mismo guard de reentrada + pre-espera que `resume()`
    /// (#36/A2 — el poll también termina en saves del journal gateados por quiescencia en el runner).
    func pollLeader() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        guard await awaitImportQuiescenceForResume() else {
            refresh()
            return
        }
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

    /// #36 (H1): pre-espera de quiescencia del import ANTES de tocar el runner — el gate interno del
    /// runner (120s) se rendía EN SILENCIO y nada reintentaba (evidencia device: el backfill de ~1.2k
    /// syncIDs post-kill tarda >120s → migración aparcada hasta tocar "Retomar"). Patrón
    /// `awaitPersonalImportForBootSave`: poll 2s, tope 300s. Fast-path y éxito LIMPIAN
    /// `resumeWaitingForImport` (A1 del review: un defer previo lo dejó en true — sin limpiarlo la
    /// card diría "esperando iCloud" con la migración ya corriendo); tope vencido lo DEJA en true
    /// (estado honesto visible) + breadcrumb. El gate del runner se conserva intacto como red
    /// (jamás un save sin quiescencia).
    private func awaitImportQuiescenceForResume() async -> Bool {
        if iCloudSyncService.shared.isImportQuiescent {
            resumeWaitingForImport = false
            return true
        }
        CloudSyncBreadcrumb.migrationResumeAwaitingImport()
        resumeWaitingForImport = true
        var waited: TimeInterval = 0
        let pollInterval: TimeInterval = 2
        let hardCap: TimeInterval = 300
        while waited < hardCap {
            do {
                try await Task.sleep(for: .seconds(pollInterval))
            } catch {
                #if DEBUG
                print("CloudMigrationController: pre-espera de quiescencia cancelada: \(error)")
                #endif
                return false
            }
            waited += pollInterval
            if iCloudSyncService.shared.isImportQuiescent {
                resumeWaitingForImport = false
                return true
            }
        }
        CloudSyncBreadcrumb.migrationResumeDeferredAwaitingImport()
        return false
    }

    /// #36 (H1): re-kick de foreground — si hay una migración/reversa APARCADA (journal transicional o
    /// efectos pendientes, controller ocioso), re-conduce por el MISMO camino del boot. Cubre la
    /// suspensión a mitad de página (push muere transient) y reintenta un defer previo de la
    /// pre-espera. Belt de wipe armado (el freeze de `handleBecameActive` ya corta antes — defensa en
    /// profundidad por si gana otro call-site).
    func rekickIfParked() async {
        guard !StorageModePersistence.isSignOutWipeArmed() else { return }
        let (phase, hasPending) = readJournalDecisionInputs()
        guard MigrationForegroundRekick.shouldRekick(
            phase: phase, hasPendingEffects: hasPending, isWorking: isWorking) else { return }
        CloudSyncBreadcrumb.migrationForegroundRekick(phase: "\(phase)")
        await resumeIfNeeded()
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

        let mountedDecision = SwiftDataConfiguration.personalStoreMountedDecision
        let mirrorOffArmed = StorageModePersistence.isMirrorOffArmed()
        uiState = CloudMigrationUIStateDeriver.derive(
            // M1: modo PERSISTIDO del dueño, no el efectivo — la UI de migración describe la
            // travesía del DEVICE (un `.cloud` efectivo espurio de una sesión secundaria mentiría).
            storageMode: StorageModePersistence.read(),
            phase: phase,
            mirrorOffArmed: mirrorOffArmed,
            mountedDecision: mountedDecision)

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

    /// Re-firma para reanudar el sync detenido (banner S11). El método NO se elige: es determinista —
    /// el de la cuenta (`storedProvider()`, que la expiración de sesión del SDK no borra: vive en el
    /// profileStore propio y solo lo limpia `signOut()`, y un signed-out no ve este banner). Ofrecer
    /// chooser aquí invitaría al mismatch R9. Fallback `.apple` = el MISMO residual documentado del
    /// claim (key perdida, población ~0): una cuenta Google re-firmaría con SIWA y GoTrue linkearía
    /// por email verificado (H4) o el refresh seguiría detenido — jamás datos cruzados.
    func signInToResumeSync() async {
        isWorking = true
        defer { isWorking = false }
        // Belt R9 (C-7, hermano del de `startMigration`): si la sesión revivió por otra entrada
        // mientras el banner seguía en pantalla, re-firmar aquí podría cambiar de cuenta con el
        // outbox del dueño anterior pendiente. Con sesión usable basta con despertar la cadencia.
        if CloudAuthService.shared.hasSession, await CloudAuthService.shared.accessToken() != nil {
            CloudSyncRuntime.shared?.handleBecameActive()
            refresh()
            return
        }
        let provider = CloudSignInProvider(
            rawValue: CloudAuthService.shared.storedProvider() ?? "") ?? .apple
        do {
            try await CloudAuthService.shared.signIn(with: provider)
            CloudSyncRuntime.shared?.handleBecameActive()   // re-evalúa la sesión y despierta la cadencia
        } catch CloudAuthError.cancelled {
            // Cancel tipado (Google): el banner sigue visible, sin alert (un cancel no es fallo).
        } catch {
            #if DEBUG
            print("CloudMigrationController.signInToResumeSync: sign-in \(provider.rawValue) falló: \(error)")
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
            guard let state = try context.fetch(descriptor).first else {
                cutoverBlocker = nil
                return (.notStarted, 0)
            }
            // C-1: el veredicto del canal iCloud viaja con el journal (sobrevive a `failedRollback` justo para
            // esto) → la card de fallo puede nombrar la causa real.
            cutoverBlocker = state.cutoverICloudVerdictRaw.flatMap(ICloudChannelVerdict.init(rawValue:))
            return (state.readPhase().phase, state.readPendingEffects().count)
        } catch {
            #if DEBUG
            print("CloudMigrationController.readJournalSnapshot: fetch(MigrationState) falló: \(error)")
            #endif
            cutoverBlocker = nil
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
