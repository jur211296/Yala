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

// MARK: - Aviso de la puerta de «Migrar a la nube»

/// Lo que ve la persona cuando «Migrar a la nube» se para (ticket
/// `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`). `id` es nuevo en cada aviso: dos paradas seguidas por
/// el mismo motivo son dos avisos.
struct MigrationIdentityBlock: Identifiable, Equatable {
    let id = UUID()
    let reason: StorageMigrationIdentityGateLogic.Block
    /// «Usar otra cuenta». Solo si la sesión la abrió este intento: con la de antes —la de sus grupos— cambiar de cuenta
    /// exige desasociar primero (Jürgen, 2026-09-09), y esta pantalla no lo hace.
    let offersAnotherAccount: Bool
    /// El correo de la cuenta de grupos asociada, para `.anotherGroupsAccountAssociated`. `nil` si no se guardó.
    let associatedEmail: String?
    /// Con qué método se firmó la cuenta rechazada, cuando la sesión la abrió este intento. `nil` si no se sabe.
    let rejectedProvider: CloudSignInProvider?

    /// ¿La hoja avisa de que con Apple no se puede elegir otra cuenta? Solo junto a «Usar otra cuenta», y solo si la
    /// rechazada era de Apple: elegir Apple otra vez firma con el mismo Apple ID del dispositivo y repite el aviso.
    var showsAppleSameAccountNote: Bool {
        offersAnotherAccount && rejectedProvider == .apple
    }
}

/// Un intento de «Migrar a la nube» que pasó la comprobación.
private struct MigrationAttempt {
    /// La sesión la abrió este intento, así que se cierra si no migra.
    let sessionOpenedByThisAttempt: Bool
    /// Lo que contestó la comprobación. Elige el aviso si el claim devuelve el intento al inicio.
    let checkedDiscovery: CloudIdentityRoutingLogic.Discovery?
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

    /// **R4 · seam del swap de persona in-process.** Suelta la instancia entera, y tiene que ser la
    /// instancia y no una re-inyección: este controller y sus tres piezas hijas (`MigrationRunner`,
    /// `MigrationWorkExecutor`, `MigrationSnapshotUploader`) retienen el `ModelContext` con `let`, así que
    /// **no son re-inyectables por construcción** — el spec §1.11 las cuenta una a una por eso mismo.
    /// Soltar el `shared` es lo único que se lleva las cuatro de golpe.
    ///
    /// Se repone sola: `configureShared` es idempotente por su `if shared == nil`, y el re-bootstrap la
    /// vuelve a crear con el `mainContext` del container nuevo.
    static func releaseSharedForSwap() {
        shared = nil
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

    /// La vuelta a iCloud está en su último paso: esperando a que el mirror suba los datos (`reverseUpload`). Era la
    /// barra clavada al 95 % sin una palabra (ticket `reverse-upload-has-no-ceiling-and-no-exit`).
    var isWaitingReverseUpload: Bool { journaledPhase == .reverseUpload }

    /// La última observación de esa espera en este proceso (`MigrationRunner.lastReverseUploadSample`): cuántas
    /// filas faltan y por qué no drena. `nil` = aún no observada; la pantalla dice entonces solo que está subiendo.
    private(set) var reverseUploadSample: ReverseUploadSample?

    /// Por qué terminó la última vuelta sin llegar a iCloud —la espera, o el claim que el servidor no concedió—
    /// (`MigrationState.reverseAbortReasonRaw`).
    /// Sale del JOURNAL, no del runner, porque la persona puede leerlo después del relanzamiento. `nil` = nada
    /// que explicar.
    private(set) var reverseAbortReason: ReverseAbortReason?

    /// Una salida de esa espera quedó a medias (`ReverseExitPending`): el `reverse_abort` que reactiva la nube sigue
    /// pendiente. Es lo único que impide empezar otra vuelta, y lo único de lo que habla el aviso de `startReverse`.
    private var hasPendingReverseExit = false

    /// La persona confirmó «Cancelar y seguir en la nube» y la pre-espera del import venció antes de poder cancelar.
    /// El siguiente `resume()` que la pase cancela antes de retomar: sin esto el «sí» se perdía, y la espera volvía a
    /// ofrecer «Cancelar» sin decir que el primero no se hizo. En memoria: si Yala se cierra, la espera lo vuelve a
    /// ofrecer.
    private var cancelReverseRequested = false

    /// El claim se aparcó por una causa que NO es la red (`MigrationRunner.lastClaimBlocker`). Mismo
    /// molde que `cutoverBlocker`: la pantalla elige con esto un copy honesto —«tu cuenta no está
    /// disponible»— en vez de dejar puesta la barra «Conectando con tu cuenta…» con un botón de
    /// reintentar que no puede funcionar. `nil` = nada aparcado, o aparcado por red (sí se reintenta).
    private(set) var claimBlocker: ClaimBlocker?

    /// Banner S11 (D5): el runtime del dominio se detuvo por sesión expirada con cambios pendientes.
    private(set) var syncNeedsSignIn = false
    private(set) var pendingUploadCount = 0

    /// El aviso de un «Migrar a la nube» que se paró sin escribir nada (ticket
    /// `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`). Lo consume la pantalla de Almacenamiento, que
    /// lo presenta y lo vacía; si la persona no la tenía delante, sale al volver a ella.
    var migrationIdentityBlock: MigrationIdentityBlock?

    /// La comprobación adelantada al toque está en vuelo (`preflightMigrationIdentity`): el botón enseña que trabaja.
    private(set) var isCheckingMigrationIdentity = false

    /// El intento de «Migrar a la nube» que pasó la comprobación y va hacia el claim. Lo lee el aviso de un claim devuelto
    /// al inicio, que puede llegar en esta llamada o en un `resume()` posterior. **Vive en memoria y la intención no**: la
    /// del runner va en el journal y sobrevive a un relanzamiento, así que tras relanzar el claim se para igual, pero el
    /// aviso ya no sabe qué sesión abrió el intento (ticket `migrate-attempt-session-survives-a-relaunch-mid-attempt`).
    private var migrationAttempt: MigrationAttempt?

    /// La secuencia del último rechazo del claim que se avisó (`ForwardClaimRefusal.sequence`). Un `resume` que empezó antes
    /// del toque y termina después ve el mismo rechazo como nuevo respecto a SU foto, y sin esto lo avisaba otra vez: sin el
    /// intento, con el motivo genérico y encima del aviso bueno.
    private var lastAnnouncedForwardRefusalSequence = 0

    // MARK: Deps

    private let context: ModelContext
    private let deviceID = MigrationWorkExecutor.vendorDeviceID
    private var _runner: MigrationRunner?

    private init(context: ModelContext) {
        self.context = context
        refresh()
        #if DEBUG
        // Seam `-uitest-pending-migration-block`: un aviso ya publicado al abrir la pantalla, con «Usar otra cuenta», para
        // el XCUITest de la cadena hoja → elección de Apple/Google. Es la salida del controller, no su decisión.
        if let fingido = UITestHooks.pendingMigrationBlock {
            migrationIdentityBlock = MigrationIdentityBlock(
                reason: fingido.reason, offersAnotherAccount: true, associatedEmail: nil,
                rejectedProvider: fingido.rejectedProvider)
        }
        #endif
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
        // Sin token, el SDK dice si es caducada o pasajero (ticket
        // `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`). Aquí no cambia lo que hace la máquina —el
        // executor colapsa las dos en la misma parada retomable—, pero el outcome ya no miente.
        let canRenew: @MainActor () -> Bool = { session.canRenewSession }
        let push = SyncPushClient(tokenProvider: token, attestProvider: attest, canRenewSession: canRenew)
        let pull = SyncPullClient(tokenProvider: token, attestProvider: attest, canRenewSession: canRenew)
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
    ///
    /// **«Migrar» pasa por la puerta de identidad entre firmar y el claim** (`continueToClaim`). Sin ella, una cuenta que
    /// ya tenía finanzas personales terminaba adoptada y con el corpus local subido encima.
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
            await continueToClaim(r, consentPath: consentPath, sessionOpenedByThisAttempt: false)
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
            await continueToClaim(r, consentPath: consentPath, sessionOpenedByThisAttempt: true)
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

    // MARK: - La puerta de identidad de «Migrar a la nube»

    /// El paso entre firmar y el claim (ticket `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`).
    ///
    /// El adopt sigue directo: ahí una cuenta que ya tiene datos es lo esperado. «Migrar» pregunta antes, con el runner
    /// aún en `authenticating` —fase no durable—, y si no sigue vuelve a `notStarted` por `.signInFailed`, sin claim y sin
    /// escribir nada. Si sigue, deja en el runner la intención de migrar, que se journalea con el claim: el claim es lo
    /// único que ve una cuenta que volvió a iCloud (`ForwardClaimIntent`).
    ///
    /// Tres detalles que puso la review, y los tres tienen motivo:
    /// · **La sesión rechazada se cierra ANTES de devolver el runner al inicio.** `submit` espera quiescencia (hasta
    ///   120 s), y una sesión viva en un iPhone con sesión privada la registra como cuenta de grupos el arranque siguiente
    ///   (`GroupsAssociationRegistrar`), aunque sea completa.
    /// · **Un `submit(.signInSucceeded)` que no hace nada también es una parada.** Pasa si vence la quiescencia o si otra
    ///   acción del runner normalizó la fase durante la comprobación: sin claim y sin rechazo, la persona se quedaba con la
    ///   sesión abierta y sin ningún aviso.
    /// · **Durante la comprobación y el cierre la tarjeta sigue en «Activando la nube…»**: la fase es `authenticating`, que
    ///   la pantalla pinta como progreso. El botón que enseña que trabaja es el del adelanto al toque, con sesión viva.
    private func continueToClaim(
        _ r: MigrationRunner,
        consentPath: ConsentPath,
        sessionOpenedByThisAttempt openedSession: Bool
    ) async {
        guard consentPath == .migration else {
            migrationAttempt = nil
            r.setForwardClaimIntent(.adoptIfExisting)
            await r.submit(.signInSucceeded)     // authenticating → claimingMigration → drive
            return
        }
        let (check, discovery) = await checkMigrationIdentity()
        guard check == .proceed else {
            let rejectedProvider = await closeSessionIfOpened(openedSession)
            await r.submit(.signInFailed)        // authenticating → notStarted, sin efectos
            announce(check, offersAnotherAccount: openedSession, rejectedProvider: rejectedProvider)
            return
        }
        migrationAttempt = MigrationAttempt(sessionOpenedByThisAttempt: openedSession, checkedDiscovery: discovery)
        r.setForwardClaimIntent(.migrateOnly)
        let refusalBefore = r.lastForwardClaimRefusal
        await r.submit(.signInSucceeded)         // authenticating → claimingMigration → drive
        await announceForwardClaimRefusal(since: refusalBefore)
        refresh()
        guard migrationAttempt != nil,
              [.notStarted, .consent, .authenticating].contains(journaledPhase) else { return }
        migrationAttempt = nil
        _ = await closeSessionIfOpened(openedSession)
        lastError = L10n.Storage.Errors.generic
    }

    /// Con sesión de nube viva —la cuenta de sus grupos—, la comprobación se adelanta al toque de «Activar la nube», antes
    /// del consentimiento y de las dos confirmaciones (decisión de Jürgen, 2026-09-16). Sin sesión no se puede: hay que
    /// firmar, y firmar antes de las confirmaciones dejaría una sesión abierta mientras la persona las lee.
    ///
    /// Solo para en un bloqueo seguro. Si no pudo preguntar sigue al consentimiento, y decide la comprobación de
    /// `continueToClaim`: así una sesión caducada llega al aviso de siempre. Nunca cierra la sesión, que no abrió.
    ///
    /// - Returns: `true` si el flujo sigue al consentimiento.
    func preflightMigrationIdentity() async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        isCheckingMigrationIdentity = true
        defer {
            isWorking = false
            isCheckingMigrationIdentity = false
        }
        lastError = nil
        let (check, _) = await checkMigrationIdentity()
        guard case .blocked = check else { return true }
        announce(check, offersAnotherAccount: false, rejectedProvider: nil)
        return false
    }

    /// Pregunta al backend por la sesión viva y aplica la fila de Ajustes de la tabla [I].
    private func checkMigrationIdentity() async -> (StorageMigrationIdentityGateLogic.Check, CloudIdentityRoutingLogic.Discovery?) {
        #if DEBUG
        // Seam `-uitest-fake-migration-identity`: finge la RESPUESTA de la puerta para el XCUITest de la hoja. La decisión
        // la cubren los unit de `StorageMigrationIdentityGateLogic`.
        if let fingida = UITestHooks.fakeMigrationIdentityCheck { return (fingida, nil) }
        #endif
        let answer: StorageMigrationIdentityGateLogic.Answer
        var discovery: CloudIdentityRoutingLogic.Discovery?
        var userID: String?
        switch await CloudIdentityDiscovery().discover(gate: .settingsMigrateToCloud) {
        case let .discovered(found, id):
            answer = .discovered(found)
            discovery = found
            userID = id
        case .unavailable:
            answer = .unavailable
        }
        let claimedForMigrationHere = userID.map {
            CloudClaimActionStore.shared.action(forUserID: $0) == .proceedMigration
        } ?? false
        let check = StorageMigrationIdentityGateLogic.check(
            answer: answer,
            // La fila de Ajustes no lee el eje (`ejeNoDecideEnLasPuertasQueNoLoUsan`): se pasa el estado desde el que se
            // migra en vez de leer `PrivateSessionMark`, que tiene sus lectores contados y aquí no decidiría nada.
            deviceState: .privateSession,
            isAssociatedGroupsAccount: GroupsAccountAssociation.shared.isAssociated(sub: userID),
            claimedForMigrationHere: claimedForMigrationHere)
        return (check, discovery)
    }

    /// Cierra la sesión si la abrió este intento, y devuelve con qué método se había firmado, que la hoja necesita para su
    /// nota de Apple. La sesión de antes del intento —la de sus grupos— no se toca nunca.
    private func closeSessionIfOpened(_ opened: Bool) async -> CloudSignInProvider? {
        guard opened else { return nil }
        let provider = CloudAuthService.shared.storedProvider().flatMap(CloudSignInProvider.init(rawValue:))
        await CloudAuthService.shared.signOut()
        return provider
    }

    /// Avisa de un claim que la intención de migrar devolvió al inicio en la llamada en curso: `before` es la foto de
    /// `lastForwardClaimRefusal` tomada antes de llamar al runner (molde de `announceReverseClaimExit`). Vale para el toque
    /// y para `resume()`: un claim que se aparcó por la red puede contestar `existing_stable` al retomar. Tras un
    /// relanzamiento ya no se sabe si la sesión la abrió el intento, así que no se cierra y el aviso es el genérico.
    private func announceForwardClaimRefusal(since before: ForwardClaimRefusal?) async {
        guard let refusal = _runner?.lastForwardClaimRefusal, refusal != before,
              refusal.sequence > lastAnnouncedForwardRefusalSequence else { return }
        lastAnnouncedForwardRefusalSequence = refusal.sequence
        let attempt = migrationAttempt
        migrationAttempt = nil
        let openedSession = attempt?.sessionOpenedByThisAttempt ?? false
        let rejectedProvider = await closeSessionIfOpened(openedSession)
        publishBlock(
            StorageMigrationIdentityGateLogic.blockForClaimRefusal(
                checkedDiscovery: attempt?.checkedDiscovery, claimState: refusal.claimState),
            offersAnotherAccount: openedSession,
            rejectedProvider: rejectedProvider,
            stage: "claim")
    }

    /// El aviso de una comprobación que no deja seguir. `couldNotCheck` usa el error de siempre de la pantalla.
    private func announce(
        _ check: StorageMigrationIdentityGateLogic.Check,
        offersAnotherAccount: Bool,
        rejectedProvider: CloudSignInProvider?
    ) {
        switch check {
        case .proceed:
            return
        case .blocked(let reason):
            publishBlock(reason, offersAnotherAccount: offersAnotherAccount, rejectedProvider: rejectedProvider,
                         stage: "gate")
        case .couldNotCheck:
            lastError = L10n.Storage.Errors.identityCheck
            CloudSyncBreadcrumb.migrationIdentityBlocked(reason: "unchecked", stage: "gate")
            MetricsService.cloudMigrationExistingAccountBlocked(reason: "unchecked", stage: "gate")
        }
    }

    private func publishBlock(
        _ reason: StorageMigrationIdentityGateLogic.Block,
        offersAnotherAccount: Bool,
        rejectedProvider: CloudSignInProvider?,
        stage: String
    ) {
        migrationIdentityBlock = MigrationIdentityBlock(
            reason: reason,
            offersAnotherAccount: offersAnotherAccount,
            associatedEmail: reason == .anotherGroupsAccountAssociated
                ? GroupsAccountAssociation.shared.read()?.email : nil,
            rejectedProvider: rejectedProvider)
        CloudSyncBreadcrumb.migrationIdentityBlocked(reason: reason.slug, stage: stage)
        MetricsService.cloudMigrationExistingAccountBlocked(reason: reason.slug, stage: stage)
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
        // Entrar en una cuenta que ya existe ES adoptarla: la intención de «Migrar» no aplica aquí.
        migrationAttempt = nil
        r.setForwardClaimIntent(.adoptIfExisting)
        await r.startMigration(dryRun: false)   // notStarted → consent
        await r.submit(.consentAccepted)         // consent → authenticating
        await r.submit(.signInSucceeded)         // authenticating → claimingMigration → drive
        refresh()
        // Decisión owner (2026-09-06): el motor arranca EN SESIÓN también en la re-entrada, como ya
        // hacía el alta (`BornCloudSignUpService.activateBornCloudStorage`). Dos caminos que montan el
        // mismo store neutro no deberían terminar en pantallas distintas: hasta aquí el adopt dependía
        // del relanzamiento para que algo arrancara el sync, y era el ÚNICO entrypoint del controller
        // que no lo intentaba (`resume`, `pollLeader` y `resumeIfNeeded` ya lo llamaban).
        //
        // **Lo que hace esto seguro es el MOUNT, no el marcador** — la precisión importa porque es la
        // frase de la que se fiará el siguiente. `startShared` → `start()` → `guard canRunDomain()`, y
        // ese gate incluye `personalMountMismatch`: un proceso que montó CON el mirror de CloudKit vivo
        // no arranca el motor aunque el par ya diga `.cloud`, y ahí `derive` sigue dando
        // `.needsRelaunch(.toCloud)` ⇒ esta llamada es no-op y la terminal sigue siendo el
        // relanzamiento. Un device que YA relanzó conserva su fila `CloudMigrationMarker` y monta
        // `.cloudMirrorOff` (sin mirror), así que SÍ pasa el gate — y arrancar ahí es lo correcto.
        // Decir «no-op cuando hay marcador» habría sido falso en ese caso.
        //
        // Y la puerta de Ajustes no llega hasta aquí: los dos únicos call-sites de este método están en
        // `WelcomeCloudSignInView`; Ajustes conduce `startMigration`/`resume`/`resetAfterRollback`. Lo
        // que el AC pedía comprobar de esa puerta es que su recorrido no cambia, y no cambia.
        startRuntimeIfStable()
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
                // El motor PERSONAL no puede ver el kill de Grupos: habla con `/sync/push`, y ahí no hay
                // kill-switch server-side —`CLOUD_MODE_ROLLOUT_PERCENT` se SIRVE como config y el cliente
                // decide, no rechaza peticiones (medido en `gateway/src/`, 2026-09-13)—. Su 403 solo puede
                // ser cuenta no disponible, que es exactamente lo que `.permanent` cuenta.
                channelKilled: false,
                // ¿Paró este ciclo porque el teléfono lleva más de un día sin App Attest? Se pregunta al runtime CON el
                // outcome, como hace el canal de Grupos: la racha sola no dice por qué falló ESTE ciclo. El motor personal
                // nunca manda una subida sin attest, así que el testigo es su propia puerta
                // (`CloudSyncRuntime.stoppedByUnavailableAttest(for:)`, ticket
                // `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`).
                attestUnavailable: runtime.stoppedByUnavailableAttest(for: outcome),
                // El motor personal no tiene ese testigo, y aquí `false` no pierde nada: su ÚNICO consumidor —el paso
                // 1 del cierre en la nube— colapsa a `.permanent` todo motivo que no sea el teléfono sin App Attest,
                // así que lo pasajero acaba igual venga separado o no. Escrito y no heredado por defecto, como
                // `channelKilled`: el día que ese colapso se arregle
                // (`cloud-signout-collapses-the-personal-push-all-reason-into-permanent`), esta línea es donde hay
                // que cablear el testigo del transporte de `SyncPushClient`, y no en `classify`.
                uploadFailed: false,
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

    /// Las filas vivas del outbox, por su `clientMutationID`: lo que el cierre compara con lo que la persona aceptó perder al
    /// cerrar sesión con un teléfono sin App Attest (`CloudSessionSignOut.exitDiscardingUnsyncedPersonalChanges`). Cada
    /// edición encola una fila nueva, así que un cambio hecho después del aviso no está entre las aceptadas. `nil` si el
    /// fetch falla, y eso solo lo cubre una aceptación sin cifra: una fila que no se pudo mirar no se descarta por una cifra.
    func livePendingUploadRowIDs() -> Set<UUID>? {
        do {
            let rows = try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
            return Set(rows.map(\.clientMutationID))
        } catch {
            #if DEBUG
            print("CloudMigrationController: Error leyendo las filas vivas del outbox: \(error)")
            #endif
            return nil
        }
    }

    /// Volver a iCloud (reversa §h). El gate `ReverseEligibility` ya lo validó la vista (diálogos-primero);
    /// se emiten `reverseActivated` + `reverseConfirmed` JUNTOS (un kill entre ambos lo normaliza `resume`).
    func startReverse() async {
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        cancelReverseRequested = false
        let r = runner
        let claimExitBefore = r.lastReverseClaimExit
        await r.submit(.reverseActivated)    // done/notStarted → reverseConfirm(origin)
        await r.submit(.reverseConfirmed)    // → reverseClaimLeader → drive
        refresh()
        // Una salida anterior de la espera dejó `reverse_abort` pendiente y no se pudo completar —sin red, o el re-kick
        // lo está completando ahora mismo—: el runner no empieza la vuelta nueva encima (la dejaría clavada con la nube
        // congelada). Sin este aviso el toque no haría nada visible. Solo con ESA salida pendiente: otro pendiente no
        // frena la vuelta (`ReverseExitPending`), y el aviso hablaría de reactivar una nube que nadie desactivó.
        if hasPendingReverseExit, MigrationRuntimeGate.isDomainStablePhase(journaledPhase) {
            lastError = L10n.Storage.Errors.reversePendingExit
        } else {
            announceReverseClaimExit(since: claimExitBefore)
        }
    }

    /// Avisa de una salida del claim de la vuelta a iCloud que haya producido la llamada en curso (ticket
    /// `reverse-claim-rejection-has-no-way-out-in-the-client`): el servidor no la dejó empezar, u otro dispositivo ya la
    /// lleva, y el runner volvió a la nube. La barra solo parpadea, así que sin alerta el gesto parecería no hacer nada;
    /// la misma frase queda como nota en la tarjeta.
    ///
    /// Solo con una salida NUEVA (`before` es la foto de `lastReverseClaimExit` tomada antes de llamar al runner): la nota
    /// journaleada no distingue un rechazo de ahora de uno de un intento anterior. Vale para el toque, para «Retomar» y
    /// para un re-kick: la alerta vive en la pantalla de Almacenamiento y solo sale con ella delante, así que fuera de
    /// ella queda solo la nota.
    private func announceReverseClaimExit(since before: ReverseClaimExit?) {
        guard let exit = _runner?.lastReverseClaimExit, exit != before else { return }
        lastError = L10n.Storage.ReverseAbort.note(for: exit.reason)
    }

    /// Retomar una migración/reversa journaleada (botón "Retomar" + el coordinator de boot + el
    /// re-kick de foreground, #36). Guard de reentrada a nivel controller (A2 del review): con la
    /// pre-espera de 300s, un boot-resume y el rekick del primer `.active` podrían pre-esperar EN
    /// PARALELO y el `defer` del primero re-habilitaría "Retomar" con el otro aún en vuelo.
    ///
    /// `clearingError: false` es del re-kick en segundo plano: un aviso que la persona aún no ha cerrado no lo borra
    /// nadie más que ella. El de `startReverse` sale justo con un efecto pendiente, que es lo que dispara el re-kick
    /// de 30 s, así que se cerraba solo entre 0 y 30 s después de aparecer.
    func resume(clearingError: Bool = true) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        if clearingError { lastError = nil }
        guard await awaitImportQuiescenceForResume() else {
            refresh()
            return
        }
        let claimExitBefore = runner.lastReverseClaimExit
        let forwardRefusalBefore = runner.lastForwardClaimRefusal
        if cancelReverseRequested {
            // El «sí» de «Cancelar» que la pre-espera no dejó pasar. Si la espera ya terminó, el runner no hace nada.
            cancelReverseRequested = false
            await runner.cancelReverseUpload()
        }
        await runner.resume()
        refresh()
        announceReverseClaimExit(since: claimExitBefore)
        await announceForwardClaimRefusal(since: forwardRefusalBefore)
        startRuntimeIfStable()
    }

    /// «Cancelar y seguir en la nube» en la espera de `reverseUpload`.
    ///
    /// No descarta el gesto si hay trabajo en vuelo: el refresco de la pantalla re-kickea cada 30 s y el runner
    /// ignoraría en silencio una segunda acción (`runGuarded`), así que un «sí» confirmado justo entonces no haría
    /// nada. Espera a que suelte y cancela después. Si mientras tanto la espera ya terminó —drenó, o saltó el
    /// techo—, el runner no hace nada: no hay de dónde salir.
    func cancelReverseUpload() async {
        while isWorking {
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                #if DEBUG
                print("CloudMigrationController.cancelReverseUpload: espera cancelada: \(error)")
                #endif
                return
            }
        }
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        // Misma pre-espera que `resume()` (#36): sin ella, con el import de iCloud activo, el runner se rendiría a
        // los 120 s de su propia espera en silencio y el «sí» no haría nada. Con ella la tarjeta dice que espera a
        // iCloud mientras tanto. Si vence, el «sí» queda apuntado y lo ejecuta el siguiente `resume()` que la pase.
        cancelReverseRequested = true
        guard await awaitImportQuiescenceForResume() else {
            refresh()
            return
        }
        cancelReverseRequested = false
        await runner.cancelReverseUpload()
        refresh()
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
    func pollLeader(clearingError: Bool = true) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        if clearingError { lastError = nil }
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
    func resumeIfNeeded(clearingError: Bool = true) async {
        let (phase, hasPending) = readJournalDecisionInputs()
        journaledPhase = phase
        switch MigrationBootDecision.decide(phase: phase, hasPendingEffects: hasPending) {
        case .resume:
            await resume(clearingError: clearingError)
        case .pollLeader:
            await pollLeader(clearingError: clearingError)
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
        // Sin tocar `lastError`: un re-kick en segundo plano no cierra un aviso que la persona no ha leído
        // (`resume(clearingError:)`).
        await resumeIfNeeded(clearingError: false)
    }

    /// Re-arranca el runtime del dominio si la fase ya es estable (post-resume). Idempotente
    /// (`startShared` es no-op si ya corre).
    ///
    /// **`hasPending` es un término del guard, no un dato que se tira** (2026-09-07). La fase estable no
    /// basta: `notStarted` LO ES —device adoptado, #30— y es también la fase que el adopt journalea
    /// ANTES de ejecutar su efecto, así que un `.adoptBackendAccount` que falló de forma retomable
    /// (quiescencia, red transitoria en el reconcile) deja el par `(notStarted, pendiente)`. Y falla en
    /// SILENCIO: `MigrationRunner.runGuarded` traga `Stop.effectFailed` sin ruido porque «el próximo
    /// resume() retoma». Arrancar el motor ahí es arrancarlo sobre una migración a medias, con el
    /// executor y el runtime compitiendo por el mismo outbox y el mismo cursor de History.
    ///
    /// Es la MISMA regla que `MigrationBootDecision.decide` ya aplica —«un efecto pendiente FUERZA
    /// `.resume` aunque la fase sea estable (AJUSTE review #3)»—, y hasta hoy esta función era el único
    /// consumidor de la fase que no la respetaba. No se notaba porque sus tres call-sites llamaban justo
    /// después de drenar; el cuarto (`startAdoptWithExistingSession`) no tiene esa garantía.
    private func startRuntimeIfStable() {
        let (phase, hasPending) = readJournalDecisionInputs()
        guard CloudSyncFlags.storageMode == .cloud,
              !hasPending,
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

        // `_runner` y NO `runner`: la property lazy CONSTRUIRÍA el runner y su executor (red, sesión,
        // clients) — `refresh()` corre desde el `init` y desde el poll de la pantalla de adopt, y no
        // es sitio para eso. Sin runner vivo no hay claim aparcado que reportar.
        claimBlocker = _runner?.lastClaimBlocker
        reverseUploadSample = _runner?.lastReverseUploadSample

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
                reverseAbortReason = nil
                hasPendingReverseExit = false
                return (.notStarted, 0)
            }
            // C-1: el veredicto del canal iCloud viaja con el journal (sobrevive a `failedRollback` justo para
            // esto) → la card de fallo puede nombrar la causa real.
            cutoverBlocker = state.cutoverICloudVerdictRaw.flatMap(ICloudChannelVerdict.init(rawValue:))
            reverseAbortReason = state.reverseAbortReasonRaw.flatMap(ReverseAbortReason.init(rawValue:))
            let pending = state.readPendingEffects()
            hasPendingReverseExit = ReverseExitPending.isPending(pending)
            return (state.readPhase().phase, pending.count)
        } catch {
            #if DEBUG
            print("CloudMigrationController.readJournalSnapshot: fetch(MigrationState) falló: \(error)")
            #endif
            cutoverBlocker = nil
            reverseAbortReason = nil
            hasPendingReverseExit = false
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
            // Marca POSITIVA escrita por el alta born-cloud de este dispositivo. No se deriva de la
            // ausencia del `CloudMigrationMarker`: ese fetch falla abierto (el marcador falta también en
            // un 2.º device adoptado y lo borra un botón DEBUG). Ver `StorageModePersistence.bornCloudKey`.
            isBornCloud: StorageModePersistence.isBornCloud(),
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
