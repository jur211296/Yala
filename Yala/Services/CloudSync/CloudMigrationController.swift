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
    /// El journal no se deja leer (ticket `an-unreadable-migration-journal-reads-as-never-started`): no se sabe en qué punto
    /// está el paso de los datos, así que la pantalla lo dice y no ofrece nada que lo mueva. Hasta ese ticket esto se
    /// pintaba como `.idle`/`.cloudActive`, las pantallas de «nunca empezó».
    case journalUnreadable

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
    ///
    /// `adoptEffectJournaled` = el journal lleva `.adoptBackendAccount` pendiente (ticket
    /// `adopt-effect-retries-forever-with-no-ceiling`). Con `notStarted` y el modo aún en iCloud es el adopt que se reintenta,
    /// y se pinta como progreso —con «Retomar» y «Cancelar»—, no como `.idle`: hasta ese ticket la pantalla se quedaba como
    /// si nunca hubiera empezado. Default `false`: los llamadores que no lo leen describen el mismo teléfono que antes.
    static func derive(
        storageMode: StorageMode,
        phase: MigrationPhase,
        mirrorOffArmed: Bool,
        mountedDecision: SwiftDataConfiguration.PersonalStoreDecision,
        adoptEffectJournaled: Bool = false
    ) -> CloudMigrationUIState {
        let mirrorStillAttached = mountedDecision.attachesCloudKitMirror
        // 1) Relanzamiento de IDA/adopt: el mirror-off está ARMADO pero este proceso montó CON mirror (sigue
        //    vivo) → hay que MATAR Y REABRIR para montar sin él. Cubre el cutover (`cutover(.mirrorOff)`) y
        //    el adopt (`notStarted` + `.cloud` armado, #30).
        if needsForwardRelaunch(mirrorOffArmed: mirrorOffArmed, mountedDecision: mountedDecision) {
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
            // `.cloud` + notStarted = device ADOPTADO estable (#30) → cloudActive. En iCloud con el efecto del adopt
            // pendiente, el adopt que se reintenta → progreso con la fase journaleada (la tarjeta no la nombra). Si no, idle.
            if storageMode == .cloud { return .cloudActive }
            if AdoptEffectScope.isPending(phase, adoptEffectJournaled: adoptEffectJournaled, persistedCloudMode: false) {
                return .migrating(MigrationUIStep(fraction: adoptEffectFraction, phase: phase))
            }
            return .idle
        }
    }

    /// Dónde va la barra mientras el efecto del adopt se reintenta: después del claim (22 %) y antes del relanzamiento.
    static let adoptEffectFraction = 0.6

    /// La misma derivación con la LECTURA del journal. Un journal ilegible es `.journalUnreadable`, salvo el relanzamiento
    /// de IDA (regla 1 de arriba), que no mira la fase: el mirror-off armado con el espejo aún montado pide relanzar sea
    /// cual sea la fase, y relanzar es además lo que cura una lectura que falla en este proceso. El de REVERSA sí necesita
    /// la fase, así que con el journal ilegible no se puede afirmar.
    static func derive(
        storageMode: StorageMode,
        read: JournaledPhaseRead,
        mirrorOffArmed: Bool,
        mountedDecision: SwiftDataConfiguration.PersonalStoreDecision,
        adoptEffectJournaled: Bool = false
    ) -> CloudMigrationUIState {
        switch read {
        case .phase(let phase):
            return derive(storageMode: storageMode, phase: phase, mirrorOffArmed: mirrorOffArmed,
                          mountedDecision: mountedDecision, adoptEffectJournaled: adoptEffectJournaled)
        case .unreadable:
            if needsForwardRelaunch(mirrorOffArmed: mirrorOffArmed, mountedDecision: mountedDecision) {
                return .needsRelaunch(.toCloud)
            }
            return .journalUnreadable
        }
    }

    /// La regla 1, en un solo sitio para las dos derivaciones: el mirror-off armado con el espejo aún montado.
    private static func needsForwardRelaunch(
        mirrorOffArmed: Bool, mountedDecision: SwiftDataConfiguration.PersonalStoreDecision
    ) -> Bool {
        mirrorOffArmed && mountedDecision.attachesCloudKitMirror
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

// MARK: - Lectura del journal (PURA, testeable)

/// Lo que la pantalla de Almacenamiento lee del journal en una pasada: la fase, los efectos pendientes y los seis motivos
/// que la tarjeta necesita para explicar una parada. Sale de la fila entera o no sale.
nonisolated struct MigrationJournalSnapshot: Equatable {
    let phase: MigrationPhase
    let pendingCount: Int
    let cutoverBlocker: ICloudChannelVerdict?
    let snapshotExitReason: SnapshotExitReason?
    let forwardStepExitReason: ForwardStepExitReason?
    let claimIntent: ForwardClaimIntent
    let reverseAbortReason: ReverseAbortReason?
    let hasPendingReverseExit: Bool
    /// Cómo salió el claim de un adopt (`MigrationState.adoptClaimExitRaw`, ticket `adopt-claim-stays-parked-with-no-ceiling`).
    /// Con default, como el siguiente: las lecturas escritas antes de estos campos no los nombran.
    var adoptClaimExit: AdoptClaimExit? = nil
    /// La cuenta a la que está atada esa marca (`MigrationState.adoptClaimAccountHash`).
    var adoptClaimAccountHash: String? = nil
    /// `.adoptBackendAccount` está entre los pendientes (ticket `adopt-effect-retries-forever-with-no-ceiling`).
    var adoptEffectJournaled: Bool = false

    /// Journal sin fila: el dispositivo nunca empezó. Una fila sin intención se lee `adoptIfExisting`, como en el runner.
    static let empty = MigrationJournalSnapshot(
        phase: .notStarted, pendingCount: 0, cutoverBlocker: nil, snapshotExitReason: nil, forwardStepExitReason: nil,
        claimIntent: .adoptIfExisting, reverseAbortReason: nil, hasPendingReverseExit: false)
}

/// Una lectura del journal para el controller. **`unreadable` no lleva valores a propósito** (ticket
/// `an-unreadable-migration-journal-reads-as-never-started`): hasta ese ticket el `catch` del fetch devolvía `notStarted` Y
/// ponía a cero los seis motivos, así que una lectura fallida borraba la explicación de la parada y, con
/// `hasPendingReverseExit`, el freno de una vuelta nueva encima de una salida a medias. Sin valores que asignar, el
/// controller no tiene nada que escribir cuando no pudo leer.
nonisolated enum MigrationJournalRead: Equatable {
    case read(MigrationJournalSnapshot)
    case unreadable

    /// La fase de esta lectura, para los derivados que solo necesitan eso.
    var phaseRead: JournaledPhaseRead {
        switch self {
        case .read(let snapshot): return .phase(snapshot.phase)
        case .unreadable: return .unreadable
        }
    }

    /// Lee el journal con `fetch`, que en producción es el `fetch` de `MigrationState` del controller. Separado del
    /// `ModelContext` para poder medir su `catch`: `ModelContext` es una `final class` de SwiftData sin protocolo detrás.
    ///
    /// Una fila que no se ENTIENDE (`isJournalUndecodable`: fase o pendientes que este build no decodifica) es
    /// `.unreadable`, igual que un fetch que lanza (ticket `an-undecodable-migration-phase-reads-as-never-started`). Sin
    /// eso salían el `.notStarted` y el `[]` de relleno: la pantalla ofrecía «Migrar» y `hasPendingReverseExit` soltaba
    /// el freno de una vuelta nueva, sobre un journal que no se había entendido.
    @MainActor
    static func read(fetch: () throws -> MigrationState?) -> MigrationJournalRead {
        do {
            guard let state = try fetch() else { return .read(.empty) }
            // El rastro lo deja `readJournal()` en la TRANSICIÓN: esto se lee cada segundo.
            guard !state.isJournalUndecodable else { return .unreadable }
            let pending = state.readPendingEffects()
            return .read(MigrationJournalSnapshot(
                phase: state.readPhase().phase,
                pendingCount: pending.count,
                // C-1: el veredicto del canal iCloud viaja con el journal (sobrevive a `failedRollback` justo para esto) →
                // la card de fallo puede nombrar la causa real.
                cutoverBlocker: state.cutoverICloudVerdictRaw.flatMap(ICloudChannelVerdict.init(rawValue:)),
                snapshotExitReason: state.snapshotExitReasonRaw.flatMap(SnapshotExitReason.init(rawValue:)),
                forwardStepExitReason: state.forwardStepExitReasonRaw.flatMap(ForwardStepExitReason.init(rawValue:)),
                claimIntent: state.forwardClaimIntentRaw.flatMap(ForwardClaimIntent.init(rawValue:)) ?? .adoptIfExisting,
                reverseAbortReason: state.reverseAbortReasonRaw.flatMap(ReverseAbortReason.init(rawValue:)),
                hasPendingReverseExit: ReverseExitPending.isPending(pending),
                adoptClaimExit: state.adoptClaimExitRaw.flatMap(AdoptClaimExit.init(rawValue:)),
                adoptClaimAccountHash: state.adoptClaimAccountHash,
                adoptEffectJournaled: pending.contains(.adoptBackendAccount)))
        } catch {
            #if DEBUG
            print("CloudMigrationController.readJournal: fetch(MigrationState) falló: \(error)")
            #endif
            return .unreadable
        }
    }
}

/// «Ver qué migraría» (dry-run §g.5). `unreadable` si alguno de los cuatro conteos lanzó: la pantalla no enseña ninguna
/// cifra, porque un cero sería inventado (ticket `an-unreadable-migration-journal-reads-as-never-started`).
nonisolated enum MigrationDryRunPreview: Equatable {
    case counts(transactions: Int, categories: Int, accounts: Int, budgets: Int)
    case unreadable
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

    /// Snapshot del journal (para labels/diagnóstico de la vista). Es la ÚLTIMA fase LEÍDA: con el journal ilegible
    /// conserva su valor, y lo que se pinta lo decide `isJournalUnreadable`.
    private(set) var journaledPhase: MigrationPhase = .notStarted
    private(set) var pendingEffectCount = 0

    /// La última lectura del journal falló (ticket `an-unreadable-migration-journal-reads-as-never-started`). Lo pone y lo
    /// quita `readJournal()`, el único lector. Lo que cuelga de él:
    /// · `uiState` pasa a `.journalUnreadable` en el siguiente `refresh()` (salvo el relanzamiento de ida, que no mira la
    ///   fase);
    /// · el arranque, el re-kick y el arranque del motor no deciden nada con esa lectura (`readJournalDecisionInputs()`
    ///   devuelve `nil`), y `startMigration`/`startReverse` vuelven a leer antes de empezar;
    /// · `canCancelMigration` y `canCancelReverse` dan `false`.
    /// Las acciones que ya estaban en vuelo (`resume`, `pollLeader`, los `cancel*`) no lo miran: decide el runner, cuyas
    /// lecturas del journal lanzan y fallan cerradas.
    private(set) var isJournalUnreadable = false
    private(set) var isQuiescent = false

    /// #36 (H1): el resume está esperando a que el import de CloudKit quede quiescente (pre-espera de
    /// 300s), o venció el tope y quedó APARCADO VISIBLE. La card de Almacenamiento muestra el estado
    /// honesto mientras sea `true`; lo limpia cualquier camino de éxito de la pre-espera.
    private(set) var resumeWaitingForImport = false

    /// C-1: último veredicto del canal iCloud journaleado (`ICloudChannelVerdict`). La card de fallo elige
    /// con esto el copy HONESTO ("iCloud se quedó sin espacio" / "no tienes iCloud activo" / "no confirmó el
    /// último paso") en vez del genérico; `nil` = sin veredicto ⇒ copy genérico de siempre.
    private(set) var cutoverBlocker: ICloudChannelVerdict?

    /// Por qué venció el techo de la subida del snapshot (`MigrationState.snapshotExitReasonRaw`, ticket
    /// `snapshot-upload-has-no-ceiling-and-no-way-out`). Sale del JOURNAL, como `cutoverBlocker`, porque la tarjeta de
    /// fallo se lee también tras relanzar. `nil` = el fallo no vino de la subida.
    private(set) var snapshotExitReason: SnapshotExitReason?

    /// Por qué venció el techo de uno de los tres pasos sin cifra que baje —claim, identidad, `cutover(.pending)`—
    /// (`MigrationState.forwardStepExitReasonRaw`, ticket `forward-migration-steps-have-no-ceiling-and-no-exit`). Del
    /// JOURNAL, como `snapshotExitReason`. `nil` = el fallo no vino de esos pasos. También `otherDevice` cuando la subida
    /// o la verificación salen porque otro dispositivo tomó el relevo (`displaced-migration-leader-keeps-uploading-after-a-takeover`).
    private(set) var forwardStepExitReason: ForwardStepExitReason?

    /// ¿Se puede cancelar la activación ahora mismo? En las fases de la ida que lo ofrecen: la subida del snapshot, los tres
    /// pasos sin cifra que baje (decisiones de Jürgen del 2026-09-22) y, desde el 2026-09-23, la espera del seguidor
    /// (`adopt-follower-waits-for-the-leader-with-no-ceiling`). El predicado vive en `ForwardCancelScope`,
    /// que es el mismo que honra un «sí» apuntado en el runner. El botón además se deshabilita con trabajo en vuelo, así que
    /// en la práctica solo se toca con la activación aparcada.
    ///
    /// Con el journal ilegible es `false`: `journaledPhase` es entonces la última fase leída, no la de ahora, y el
    /// `.onChange` de la pantalla usa este getter para bajar un diálogo que ya no aplica.
    var canCancelMigration: Bool {
        !isJournalUnreadable && ForwardCancelScope.offersCancel(journaledPhase, adoptEffectPending: isAdoptEffectPending)
    }

    /// La misma salida en la espera del seguidor, con otro nombre: «Dejar de esperar» (ticket
    /// `adopt-follower-waits-for-the-leader-with-no-ceiling`, texto de Jürgen del 2026-09-23). La pinta la tarjeta de espera
    /// y la usa su `.onChange` para bajar el diálogo si la fase sale de la espera con él abierto —al relevo del líder, a su
    /// adopt o por el techo—: el diálogo habla de un teléfono que espera, y en otra fase no sería verdad.
    var canStopWaitingForLeader: Bool {
        canCancelMigration && journaledPhase == .waitingForLeader
    }

    /// `.adoptBackendAccount` pendiente en el journal (`MigrationJournalSnapshot.adoptEffectJournaled`).
    private(set) var adoptEffectJournaled = false

    /// ¿Se está reintentando el EFECTO del adopt? (ticket `adopt-effect-retries-forever-with-no-ceiling`). El predicado es el
    /// del runner (`AdoptEffectScope`), con el modo PERSISTIDO, que es el que escribe el paso 5 del adopt. Abre «Cancelar»
    /// en la tarjeta de progreso y elige su cuerpo. Con el journal ilegible es `false`, por lo mismo que `canCancelMigration`.
    var isAdoptEffectPending: Bool {
        !isJournalUnreadable && AdoptEffectScope.isPending(
            journaledPhase, adoptEffectJournaled: adoptEffectJournaled,
            persistedCloudMode: StorageModePersistence.read() == .cloud)
    }

    /// La intención journaleada del claim de la ida (`MigrationState.forwardClaimIntentRaw`), la misma que lee
    /// `MigrationRunner.driveClaim`. Una fila sin intención se lee como `adoptIfExisting`, igual que allí.
    private(set) var journaledClaimIntent: ForwardClaimIntent = .adoptIfExisting

    /// El motivo definitivo que vio el último claim de este proceso (`MigrationRunner.lastClaimDefinitiveCause`). Solo lo
    /// lee `adoptClaimNotice`.
    private var claimDefinitiveCause: ForwardStepBlocker?

    /// Cómo salió el último claim de un adopt (`MigrationState.adoptClaimExitRaw`). Del JOURNAL, como
    /// `forwardStepExitReason`: la persona lo lee tras relanzar. `nil` = ningún adopt salió desde el último claim.
    private(set) var adoptClaimExit: AdoptClaimExit?

    /// La cuenta a la que está atada esa marca (`MigrationState.adoptClaimAccountHash`), con el hash del faro.
    private var adoptClaimAccountHash: String?

    /// ¿La activación parada es el claim de un ADOPT? Elige el cuerpo del diálogo de «Cancelar la activación»: el de
    /// «Migrar» dice «tus datos siguen en este dispositivo», que en un teléfono recién instalado es falso (ticket
    /// `adopt-claim-stays-parked-with-no-ceiling`). El predicado es el mismo que usa el runner para dejar la marca.
    var isAdoptClaim: Bool {
        !isJournalUnreadable && AdoptClaimScope.isAdoptClaim(journaledPhase, claimIntent: journaledClaimIntent)
    }

    /// El motivo que esperar no arregla —la sesión borrada, el 403— mientras el claim de un adopt sigue aparcado, para
    /// avisarlo en la tarjeta ANTES de que venza el techo, como hace el Welcome mientras está delante. `nil` = nada que
    /// avisar. Con el journal ilegible, nada: la fase sería la última leída.
    var adoptClaimNotice: AdoptClaimNotice? {
        guard !isJournalUnreadable else { return nil }
        return AdoptClaimScope.notice(
            phase: journaledPhase, claimIntent: journaledClaimIntent, observedCause: claimDefinitiveCause)
    }

    /// ¿Almacenamiento ofrece «Activar la nube en este dispositivo» aunque no haya marcador de CloudKit? Cuando el claim de
    /// un adopt salió —por su techo o por «Cancelar»—, sin sesión o con la de la cuenta de ese intento: la persona quería
    /// ENTRAR en esa cuenta, y «Migrar a la nube» la para la puerta de identidad (ticket
    /// `adopt-claim-stays-parked-with-no-ceiling`). La sesión se lee en vivo, como hace la tarjeta con el faro.
    var offersAdoptReentry: Bool {
        AdoptClaimScope.offersReentry(
            exit: adoptClaimExit, attemptAccountHash: adoptClaimAccountHash,
            hasSession: CloudAuthService.shared.hasSession,
            sessionAccountHash: CloudAuthService.shared.currentUserID.map { CloudBeacon.hash($0) })
    }

    /// C-1: el cutover está en el paso 4 esperando que iCloud confirme el marcador. Es el estado que antes
    /// se mostraba como un 89 % mudo, sin decir a qué se esperaba.
    var isWaitingICloudExport: Bool { journaledPhase == .cutover(.markerWritten) }

    /// La vuelta a iCloud está en su último paso: esperando a que el mirror suba los datos (`reverseUpload`). Era la
    /// barra clavada al 95 % sin una palabra (ticket `reverse-upload-has-no-ceiling-and-no-exit`).
    var isWaitingReverseUpload: Bool { journaledPhase == .reverseUpload }

    /// ¿Se puede abandonar la vuelta a iCloud ahora mismo? En las CINCO fases en las que la salida existe: las cuatro
    /// previas al montaje del espejo (ticket `reverse-before-mount-has-no-way-to-abandon-the-return`) y la espera de
    /// la subida. Antes solo la última, así que al 15/30/50/62 % la tarjeta ofrecía «Retomar» y nada más.
    ///
    /// Va por la FASE journaleada y no por lo que se esté pintando: la tarjeta de progreso sale también en fases
    /// posteriores al montaje, donde el espejo ya está vivo y no hay salida que ofrecer.
    ///
    /// Con el journal ilegible es `false`, por lo mismo que `canCancelMigration`.
    var canCancelReverse: Bool {
        !isJournalUnreadable && (journaledPhase == .reverseUpload || isBeforeReverseMount)
    }

    /// ¿La vuelta está en una de las cuatro fases ANTERIORES al montaje del espejo? Lo lee el cuerpo de la
    /// confirmación, que solo ahí puede prometer que no habrá relanzamiento.
    ///
    /// Va en POSITIVO a propósito. El ternario que pregunta «¿no es la espera de la subida?» falla ABIERTO: le
    /// daría el texto «no hay que relanzar» a cualquier fase POST-montaje que mañana entre en `canCancelReverse`,
    /// y ahí el espejo está vivo y sí hay que relanzar. Es el mismo `else` que fallaba abierto en
    /// `syncStatusSection` y pintaba «Todo sincronizado» con el motor parado.
    var isBeforeReverseMount: Bool { ReversePreMountPhase(phase: journaledPhase) != nil }

    /// La última observación de esa espera en este proceso (`MigrationRunner.lastReverseUploadSample`): cuántas
    /// filas faltan y por qué no drena. `nil` = aún no observada; la pantalla dice entonces solo que está subiendo.
    private(set) var reverseUploadSample: ReverseUploadSample?

    /// La vuelta a iCloud se paró porque la sesión de la nube ya no vale, en una fase anterior al montaje del espejo
    /// (`MigrationRunner.lastReverseSessionExpiry`). `nil` = no se paró por eso.
    ///
    /// Es lo que separa este caso del banner `syncNeedsSignIn` de más abajo, que **no puede salir aquí**: ese exige el
    /// runtime del dominio en `.stoppedUntilSignIn`, y en estas cuatro fases el runtime no corre —ninguna es estable—
    /// así que la persona veía una barra parada sin una palabra (ticket
    /// `reverse-before-mount-stays-stuck-with-an-expired-session`).
    private(set) var reverseSessionExpiry: ReversePreMountPhase?

    /// ¿Hay que pedirle que vuelva a entrar para que la vuelta a iCloud siga? Lo lee la tarjeta de progreso.
    ///
    /// **La fase la decide el runner, no este getter.** Añadir aquí un término de fase sería la misma condición dos
    /// veces, y entonces un mutante en la del runner saldría verde (el pre-filtro tapando al criterio).
    var reverseNeedsSignIn: Bool { reverseSessionExpiry != nil }

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
    /// Cuántos cambios faltan por subir. `nil` = la cola no se dejó contar: la pantalla ofrece firmar sin cifra.
    private(set) var pendingUploadCount: Int? = 0

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
        // `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`). Desde el 2026-09-22 SÍ cambia lo que hace la
        // máquina en la subida del snapshot: la sesión caducada con el SDK sin sesión elige su techo corto, y el mismo
        // testigo separa el 401 con la sesión todavía guardada, que va al largo (`MigrationSnapshotUploader`).
        let canRenew: @MainActor () -> Bool = { session.canRenewSession }
        let push = SyncPushClient(tokenProvider: token, attestProvider: attest, canRenewSession: canRenew)
        let pull = SyncPullClient(tokenProvider: token, attestProvider: attest, canRenewSession: canRenew)
        let merkle = SyncMerkleClient(tokenProvider: token, attestProvider: attest, canRenewSession: canRenew)
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
            adoptQuiescenceSignal: { iCloudSyncService.shared.isImportQuiescent },
            // Ticket `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`: con el espejo adjunto y
            // nada local que pida linaje, el adopt le pregunta a CloudKit si el corpus de iCloud aún no llegó. El testigo es
            // el del MOUNT de este proceso, no «¿hay iCloud?» (`isICloudAvailable` mide Drive y `.localNoMirror` adjunta igual).
            adoptMirrorAttached: { SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror },
            adoptICloudCorpusCheck: { await ICloudPersonalCorpusProbe.adoptRelevantRecords() },
            adoptImportSettled: { iCloudSyncService.shared.hasCompletedFirstImport && iCloudSyncService.shared.isImportQuiescent })
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
        // Las dos confirmaciones y la hoja de consentimiento cuelgan de la RAÍZ de la pantalla, no de la tarjeta, así que
        // sobreviven a un `.journalUnreadable` que llegue con ellas abiertas. Sin journal no se empieza nada: ni se firma
        // ni se toca el runner (ticket `an-unreadable-migration-journal-reads-as-never-started`).
        guard readJournalDecisionInputs() != nil else {
            lastError = L10n.Storage.journalUnreadableMessage
            refresh()
            return
        }
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
            // La tarjeta de adopt que abrió la marca de un adopt anterior solo entra en ESA cuenta (ticket
            // `adopt-claim-stays-parked-with-no-ceiling`): sin sesión, la persona puede haber elegido otra en el chooser, y
            // adoptarla le subiría lo local sin la puerta de «Migrar». Sin claim y sin escribir nada, como la puerta.
            if AdoptClaimScope.blocksReentry(
                exit: adoptClaimExit, attemptAccountHash: adoptClaimAccountHash,
                sessionAccountHash: CloudAuthService.shared.currentUserID.map { CloudBeacon.hash($0) }) {
                _ = await closeSessionIfOpened(openedSession)
                await r.submit(.signInFailed)    // authenticating → notStarted, sin efectos
                lastError = L10n.Storage.Errors.adoptOtherAccount
                CloudSyncBreadcrumb.migrationIdentityBlocked(reason: "adopt_other_account", stage: "gate")
                MetricsService.cloudMigrationExistingAccountBlocked(reason: "adopt_other_account", stage: "gate")
                return
            }
            r.setForwardClaimIntent(.adoptIfExisting)
            recordAdoptSessionOwnership(sessionOpenedByThisAttempt: openedSession)
            await r.submit(.signInSucceeded)     // authenticating → claimingMigration → drive
            guard withdrawAdoptSessionOwnershipIfNotStarted() else { return }
            // No llegó al claim —casi siempre, la espera de iCloud venció—: como «Migrar», se cierra la sesión que abrió este
            // intento (ticket `settings-adopt-stalled-before-the-claim-keeps-the-session`). Ajustes no tiene un «Retomar» que
            // la reuse, y viva la registraría Grupos en el arranque siguiente. La bienvenida no pasa por aquí. La señal del
            // texto se lee ANTES de cerrar: el import que acaba de asentar solo cuenta como «en curso» 8 s más, y `signOut`
            // espera.
            let importIsQuiescent = iCloudSyncService.shared.isImportQuiescent
            _ = await closeSessionIfOpened(openedSession)
            lastError = StorageFailureCopyLogic.settingsAdoptStoppedBeforeTheClaim(importIsQuiescent: importIsQuiescent)
            return
        }
        // «Migrar» nunca abre la sesión de un adopt: una marca vieja no se hereda.
        AdoptSessionOwnership.record(nil)
        let (check, discovery) = await checkMigrationIdentity(sessionOpenedByThisAttempt: openedSession)
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
        let (check, _) = await checkMigrationIdentity(sessionOpenedByThisAttempt: false)
        guard case .blocked = check else { return true }
        announce(check, offersAnotherAccount: false, rejectedProvider: nil)
        return false
    }

    /// Pregunta al backend por la sesión viva y aplica la fila de Ajustes de la tabla [I].
    ///
    /// - Parameter sessionOpenedByThisAttempt: la sesión la abrió este intento. El adelanto al toque pasa `false`: solo corre
    ///   con la sesión que ya había.
    private func checkMigrationIdentity(
        sessionOpenedByThisAttempt: Bool
    ) async -> (StorageMigrationIdentityGateLogic.Check, CloudIdentityRoutingLogic.Discovery?) {
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
        // La marca de un claim de «Migrar» que se quedó sin respuesta (ticket
        // `forward-migration-steps-have-no-ceiling-and-no-exit`): pudo dejar la cuenta `complete` sin sello. Qué abre, y qué
        // no, lo decide `check`, no esta línea.
        let hasUnansweredMigrationClaim = userID.map {
            CloudClaimActionStore.shared.hasMigrationClaimAttempt(forUserID: $0)
        } ?? false
        let check = StorageMigrationIdentityGateLogic.check(
            answer: answer,
            // La fila de Ajustes no lee el eje (`ejeNoDecideEnLasPuertasQueNoLoUsan`): se pasa el estado desde el que se
            // migra en vez de leer `PrivateSessionMark`, que tiene sus lectores contados y aquí no decidiría nada.
            deviceState: .privateSession,
            isAssociatedGroupsAccount: GroupsAccountAssociation.shared.isAssociated(sub: userID),
            claimedForMigrationHere: claimedForMigrationHere,
            hasUnansweredMigrationClaim: hasUnansweredMigrationClaim,
            sessionOpenedByThisAttempt: sessionOpenedByThisAttempt,
            // El sello de «Empezar desde cero», del mismo dominio en el que lo leen `GroupsAccountAssociation` y el bridge.
            deviceSealedForFreshStart: UserDefaults.standard.bool(
                forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart))
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

    // MARK: - La sesión que abrió un adopt

    /// Apunta de quién es la sesión del adopt que EMPIEZA (ticket `adopt-exit-keeps-the-session-it-opened`), antes de
    /// conducir el runner: la primera pasada puede hacer el claim y el efecto dentro de un solo `submit`, y un kill ahí
    /// dejaba el adopt sin marca. Qué se apunta lo decide `AdoptSessionOwnership.markToRecord`.
    private func recordAdoptSessionOwnership(sessionOpenedByThisAttempt openedSession: Bool) {
        AdoptSessionOwnership.record(AdoptSessionOwnership.markToRecord(
            sessionOpenedByThisAttempt: openedSession,
            sessionAccountHash: CloudAuthService.shared.currentUserID.map { CloudBeacon.hash($0) },
            current: AdoptSessionOwnership.read()))
    }

    /// Retira la marca si la llamada volvió sin entrar en el claim: el intento no empezó, y su `authenticating` normalizado
    /// se leería como salida. La sesión se queda, que es lo que reusa el «Retomar» de la bienvenida; el adopt de Ajustes, que
    /// no tiene «Retomar», la cierra con lo que esto devuelve.
    ///
    /// - Returns: `true` si la llamada paró antes del claim. Con el journal ilegible, `false`: no se decide.
    @discardableResult
    private func withdrawAdoptSessionOwnershipIfNotStarted() -> Bool {
        refresh()
        guard !isJournalUnreadable, AdoptSessionOwnership.stoppedBeforeTheClaim(
            phase: journaledPhase, adoptEffectPending: isAdoptEffectPending,
            persistedCloudMode: StorageModePersistence.read() == .cloud) else { return false }
        AdoptSessionOwnership.record(nil)
        return true
    }

    /// Si el adopt que abrió la sesión ya salió —su techo, «Cancelar» o «Dejar de esperar»—, la cierra (decisión A de
    /// Jürgen, 2026-09-23). Se mira por NIVEL tras cada llamada que conduce el runner y al empezar `resumeIfNeeded`, que es el
    /// arranque y el re-kick: así da igual qué pasada produjo la salida, también una que un kill dejó sin cerrar.
    ///
    /// Solo cierra la sesión de ESA cuenta: con otra viva —la persona entró después por Grupos— borra la marca y no toca
    /// nada. Con el journal ilegible no decide.
    private func closeSessionOfExitedAdopt() async {
        guard !isJournalUnreadable else { return }
        let owned = AdoptSessionOwnership.read()
        switch AdoptSessionOwnership.decide(
            ownedAccountHash: owned,
            sessionAccountHash: CloudAuthService.shared.currentUserID.map { CloudBeacon.hash($0) },
            phase: journaledPhase, adoptEffectPending: isAdoptEffectPending,
            persistedCloudMode: StorageModePersistence.read() == .cloud) {
        case .keep:
            return
        case .forget:
            AdoptSessionOwnership.record(nil)
        case .closeSession:
            AdoptSessionOwnership.record(nil)
            CloudSyncBreadcrumb.adoptExitClosedSession()
            _ = await closeSessionIfOpened(true)
        }
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
    ///
    /// - Parameter sessionOpenedByThisAttempt: la sesión la firmó la bienvenida que llama (también en un «Retomar» de esa
    ///   misma pantalla). `false` con la sesión que ya traía la puerta de Grupos: esa no se cierra al salir.
    func startAdoptWithExistingSession(sessionOpenedByThisAttempt: Bool) async {
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
        recordAdoptSessionOwnership(sessionOpenedByThisAttempt: sessionOpenedByThisAttempt)
        await r.startMigration(dryRun: false)   // notStarted → consent
        await r.submit(.consentAccepted)         // consent → authenticating
        await r.submit(.signInSucceeded)         // authenticating → claimingMigration → drive
        withdrawAdoptSessionOwnershipIfNotStarted()
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
    /// paso 5.5 incluido) hasta que el outbox vivo quede en 0 VERIFICADO por fetch —y el History sin ediciones que el drain
    /// no capturó (`CloudSignOutFlowLogic.personalVerdictAfterProbe`)—, o bloquea. Los
    /// pendientes JAMÁS se descartan — `.blocked` aborta el cierre y el usuario reintenta con red.
    /// `.coalesced` cuenta como ciclo sano (sin señal de fallo); el tope corta backends caídos.
    ///
    /// **Respeta el candado del motor** (ticket `sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate`): con el
    /// journal ilegible, una fase transitoria o el espejo de iCloud montado, `CloudSyncRuntime.canRunDomain()` está
    /// cerrado y aquí no se corre ni un ciclo — tampoco su drain, que es parte del motor (asigna identidades y escribe el
    /// outbox). Lo que el motor no capturó se LEE del History sin escribir, y bloquea igual que una fila del outbox. Se
    /// consulta antes de CADA ciclo: entre uno y otro hay una pausa en la que una reversa puede arrancar.
    func pushAllPendingForSignOut(maxIterations: Int = 20) async -> CloudSignOutFlowLogic.PushAllVerdict {
        await Self.pushAllForSignOut(
            runtime: CloudSyncRuntime.shared,
            context: context,
            domainGateOpen: { CloudSyncRuntime.canRunDomain() },
            journalRead: { MigrationPhaseStore.shared.currentPhaseRead },
            livePendingCount: { [self] in livePendingUploadCount() },
            maxIterations: maxIterations)
    }

    /// El cuerpo del push-all del cierre, con el runtime, el candado y el recuento inyectados para poder medirlo: el
    /// controller no se construye en tests. Producción entra SOLO por `pushAllPendingForSignOut`.
    static func pushAllForSignOut(
        runtime: CloudSyncRuntime?,
        context: ModelContext,
        domainGateOpen: () -> Bool,
        journalRead: () -> JournaledPhaseRead,
        livePendingCount: () -> Int,
        maxIterations: Int,
        pause: Duration = .milliseconds(250)
    ) async -> CloudSignOutFlowLogic.PushAllVerdict {
        for iteration in 1...maxIterations {
            // Sin runtime, o con el candado del dominio cerrado, no hay motor que pueda subir: solo es seguro cerrar sin
            // pendientes —en el outbox y en el History sin capturar—, y con ellos se bloquea sin descartar
            // (`pushAllVerdictWithoutEngine`).
            guard let runtime else {
                // Sin runtime no es el candado —es el motor apagado por flag—, y no hay una salida que nombrar: el genérico.
                return CloudSignOutFlowLogic.pushAllVerdictWithoutEngine(
                    livePendingCount: livePendingCount(), uncapturedChanges: false, reason: .permanent)
            }
            guard domainGateOpen() else {
                let live = livePendingCount()
                let uncaptured = runtime.hasUncapturedPersonalChanges(context: context)
                CloudSyncBreadcrumb.signOutPushSkippedByDomainGate(
                    pending: live, uncaptured: uncaptured.map { $0 ? "yes" : "no" } ?? "unknown")
                // El motivo nombra la salida real, no la conexión (ticket
                // `cloud-signout-with-the-engine-stopped-says-check-your-connection`): se clasifica por lo que enseña
                // «Dónde viven tus datos» en ese mismo estado (`engineStoppedReason(read:)`).
                return CloudSignOutFlowLogic.pushAllVerdictWithoutEngine(
                    livePendingCount: live, uncapturedChanges: uncaptured,
                    reason: CloudSignOutFlowLogic.engineStoppedReason(read: journalRead()))
            }
            let outcome = await runtime.syncCycle(context: context)
            if let verdict = CloudSignOutFlowLogic.pushAllVerdict(
                livePendingCount: livePendingCount(),
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
                // ¿Paró este ciclo porque la subida no llegó al servidor? El testigo del motor personal
                // (`CloudSyncRuntime.stoppedByFailedUpload(for:)`, 2026-09-25): separa lo pasajero en sus dos mitades como
                // en Grupos, y el paso 1 del cierre en la nube lo enseña como `.personalUploadRetryLater` en vez del
                // «revisa tu conexión» de antes (ticket `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`).
                uploadFailed: runtime.stoppedByFailedUpload(for: outcome),
                iteration: iteration,
                maxIterations: maxIterations
            ) {
                // **El outbox a 0 no prueba que no quede nada** (ticket
                // `personal-sign-out-reads-an-unfinished-drain-as-nothing-pending`): un drain que aborta deja la edición solo
                // en el History. Se relee aquí, sin escribir, en los dos veredictos que el paso 1 deja seguir.
                let probed = CloudSignOutFlowLogic.personalVerdictAfterProbe(verdict) {
                    runtime.hasUncapturedPersonalChanges(context: context)
                }
                // Lo que la sonda ve puede haber llegado DESPUÉS del drain del ciclo —los reconciliadores del pull, el puente
                // de Grupos del paso 5.6, un ciclo de la cadencia que coalesció—, y eso lo captura el drain de la vuelta
                // siguiente. Otra vuelta, con el tope del bucle: un drain que aborta siempre llega a él y bloquea igual.
                if probed == verdict || iteration >= maxIterations { return probed }
            }
            // S1 del review: un ciclo de la cadencia EN VUELO devuelve `.coalesced`
            // SINCRÓNICO — sin esta pausa el loop quemaría las 20 iteraciones en
            // microsegundos y bloquearía con red sana. La pausa deja terminar el
            // ciclo en vuelo; la siguiente iteración corre un ciclo real.
            do {
                try await Task.sleep(for: pause)
            } catch {
                break  // cancelación del caller
            }
        }
        // Tope alcanzado con pendientes, o el gesto cancelado en la pausa: transitorio (aún drenando). Desde el 2026-09-25
        // el paso 1 del cierre en la nube lo enseña tal cual —«un momento más»— (`personalPushAllShownReason`); hasta ese
        // día lo aplanaba en el aviso de la conexión.
        return .blocked(pendingCount: livePendingCount(), reason: .transient)
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
        // Mismo guard que `startMigration`: su doble confirmación cuelga de la raíz de la pantalla.
        guard readJournalDecisionInputs() != nil else {
            lastError = L10n.Storage.journalUnreadableMessage
            refresh()
            return
        }
        cancelReverseRequested = false
        let r = runner
        let claimExitBefore = r.lastReverseClaimExit
        let preMountExitBefore = r.lastReversePreMountExit
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
            announceReversePreMountExit(since: preMountExitBefore)
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

    /// Avisa de una salida de las cuatro fases previas al montaje que haya producido la llamada en curso (ticket
    /// `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`): el techo de la etapa venció y la
    /// vuelta regresó a su origen. Misma forma y mismo porqué que el helper de arriba —la foto ANTES de llamar al
    /// runner, porque el motivo journaleado no distingue esta salida de la de un intento anterior—, con una
    /// diferencia: aquí la salida puede ser la que pidió la PERSONA («Cancelar y seguir en la nube», que también
    /// vive en estas fases), y esa no se anuncia. Lo decide `ReverseUploadWaitingCopyLogic.abortNote`, el mismo
    /// filtro que decide si la tarjeta pone nota: con dos, la alerta y la nota discreparían.
    ///
    /// Sin este aviso la barra desaparecía de golpe y la pantalla cambiaba sin decir por qué: la salida de esta
    /// etapa no deja NINGÚN efecto, así que no hay tarjeta de relanzar que delate lo ocurrido.
    ///
    /// **Dónde dispara cada uno, MEDIDO y no inferido** (`MigrationRunnerTests
    /// .startReversePair_exitsTheCeilingOnlyWhenTheJournalWasAlreadyInTheStage`). En `resume` es el caso normal: el
    /// re-kick de 30 s y «Retomar» son los que cruzan el techo con la persona mirando. En `startReverse` **no** puede
    /// disparar por el camino del toque —el cruce a `reverseClaimLeader` limpia el reloj, así que la vuelta nueva
    /// holdea aunque el journal trajera un sello de días atrás—, pero **sí** cuando la pantalla pinta la tarjeta con
    /// el journal todavía en una de las cuatro fases: `submit` conduce igual, y ahí la salida ocurre dentro del
    /// toque. No es un camino muerto, y es exactamente el silencio que este ticket cierra.
    ///
    /// **Dos límites que la review acotó y que se aceptan, con ticket cada uno.** (1) Un aviso publicado con esta
    /// pantalla cerrada —una salida que vence en el `resume` del arranque— no sale al abrirla: `StorageSettingsView`
    /// observa `lastError` sin `initial: true`, al revés que el aviso de identidad de quince líneas antes. Se hereda
    /// de la decisión escrita del aviso del claim («la alerta vive en Almacenamiento y solo sale con ella delante»)
    /// y cambiarlo la reabriría para los dos, así que va aparte:
    /// `reverse-exit-alert-published-off-screen-never-shows`. (2) Los demás `submit` del controller —los de la IDA—
    /// conducen `drive()` con el mismo argumento y no anuncian; para llegar ahí haría falta ofrecer «Migrar a la
    /// nube» con el journal en una vuelta, una desincronía más profunda que la de arriba, y también tiene ticket.
    private func announceReversePreMountExit(since before: ReversePreMountExit?) {
        guard let exit = _runner?.lastReversePreMountExit, exit != before,
              let reason = ReverseUploadWaitingCopyLogic.abortNote(exit.reason) else { return }
        lastError = L10n.Storage.ReverseAbort.note(for: reason)
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
        let preMountExitBefore = runner.lastReversePreMountExit
        let forwardRefusalBefore = runner.lastForwardClaimRefusal
        if cancelReverseRequested {
            // El «sí» de «Cancelar» que la pre-espera no dejó pasar. Si la vuelta ya avanzó, el runner no hace nada.
            cancelReverseRequested = false
            await runner.cancelReverse()
        }
        await runner.resume()
        refresh()
        announceReverseClaimExit(since: claimExitBefore)
        announceReversePreMountExit(since: preMountExitBefore)
        await announceForwardClaimRefusal(since: forwardRefusalBefore)
        await closeSessionOfExitedAdopt()
        startRuntimeIfStable()
    }

    /// Volver a entrar para que la vuelta a iCloud siga donde estaba (ticket
    /// `reverse-before-mount-stays-stuck-with-an-expired-session`). Firma y **retoma**: el criterio del ticket es que
    /// entrar baste, sin un segundo gesto que buscar.
    ///
    /// **El rescate va PRIMERO, y es una renovación FORZADA, no un `accessToken()`.** La observación que enciende la
    /// tarjeta la produce sobre todo un **401 del gateway con la sesión del SDK intacta**, y en ese estado
    /// `hasSession` es `true` y `accessToken()` devuelve **el mismo JWT que el servidor acaba de rechazar** (solo
    /// auto-refresca con menos de 30 s de margen). Un belt escrito con ese par —el molde de `signInToResumeSync`—
    /// saltaba la firma, retomaba con el token rechazado y recibía el mismo 401: el botón que ofrece entrar no
    /// entraba, en el caso PRINCIPAL del ticket. `forceRefreshAccessToken()` canjea el refresh token AHORA: si la
    /// sesión seguía viva, rota y la vuelta sigue sin molestar a nadie — es el mismo rescate que el canal de Grupos
    /// usa para su 401 (H-2026-07-18-4); si no vuelve nada, hay que firmar de verdad.
    ///
    /// **El proveedor no se elige**: es el de la cuenta (`storedProvider()`, que la expiración no borra — vive en el
    /// profileStore propio y solo lo limpia `signOut()`).
    ///
    /// **Y la firma va atada al `sub`**, que es lo que este camino NO hereda de su molde: `signInToResumeSync`
    /// ata la firma al dueño del motor (`SyncSignInBannerLogic.afterSignIn`) y `CloudSyncRuntime.handleBecameActive()` no
    /// reanuda con otra cuenta (las dos cosas desde el 2026-09-25; antes de ese día esta frase decía que ese gate existía, y
    /// desde `.stoppedUntilSignIn` no existía); aquí se conduce el runner directo —la fase de la vuelta no es estable, así que ese gate
    /// no corre— y `reverseDrainOnce` sube el outbox entero, que no lleva dueño. Con Google el chooser sale siempre
    /// (`hint: nil`), así que elegir la cuenta de al lado escribía el corpus de una persona bajo el `sub` de otra.
    /// Si el `sub` cambia, **no se retoma**: se avisa y la vuelta se queda donde estaba, intacta.
    ///
    /// El `resume()` va FUERA del tramo con `isWorking` puesto, y no es un detalle de estilo: `resume()` abre con
    /// `guard !isWorking else { return }`, así que llamarlo desde dentro no retomaría nada.
    func signInToResumeReverse() async {
        // ANTES del primer `await`, y con `defer`: el re-kick de foreground de la pantalla mira `isWorking` para
        // decidir si empuja, y con el candado suelto durante la ida y vuelta de red se colaba su propio `resume()`
        // — el de aquí lo soltaba al bajar el flag y los dos pases corrían encima.
        guard !isWorking else { return }
        isWorking = true
        var releasedForResume = false
        defer { if !releasedForResume { isWorking = false } }

        // El `sub` con el que la vuelta empezó. Con la sesión ya borrada es `nil`: entonces no hay nada que comparar
        // y se acepta la cuenta con la que se firme, que es el trato de siempre de esta pantalla.
        let subBefore = CloudAuthService.shared.currentUserID

        if await CloudAuthService.shared.forceRefreshAccessToken() == nil {
            let provider = CloudSignInProvider(
                rawValue: CloudAuthService.shared.storedProvider() ?? "") ?? .apple
            do {
                try await CloudAuthService.shared.signIn(with: provider)
            } catch CloudAuthError.cancelled {
                // Cancel tipado (Google): la tarjeta sigue pidiendo volver a entrar, sin aviso — un cancel no es fallo.
                refresh()
                return
            } catch {
                #if DEBUG
                print("CloudMigrationController.signInToResumeReverse: sign-in \(provider.rawValue) falló: \(error)")
                #endif
                lastError = L10n.Storage.Errors.signIn
                refresh()
                return
            }
            if let subBefore, CloudAuthService.shared.currentUserID != subBefore {
                CloudSyncBreadcrumb.reverseSignInAccountMismatch()
                lastError = L10n.Storage.Errors.reverseSignInOtherAccount
                refresh()
                return
            }
        }

        // Con sesión buena y de la misma cuenta, el camino de siempre: el runner re-intenta la fase journaleada y su
        // primer paso con éxito limpia la observación, así que la tarjeta deja de pedir volver a entrar sola.
        //
        // **Y retira un «Cancelar» que quedara apuntado**, que es lo contrario de lo que este gesto pide. Hasta el
        // 2026-09-21 los dos botones no podían coexistir —«Volver a entrar» solo sale en las cuatro fases previas al
        // montaje y «Cancelar» solo salía en la espera de la subida—, así que la pregunta no se planteaba; con el
        // botón ofrecido también en esas cuatro (`reverse-before-mount-has-no-way-to-abandon-the-return`) sí se
        // planteó: un «sí» que la pre-espera del import no dejó pasar lo ejecutaba el `resume()` de aquí, y la
        // persona que firma para CONTINUAR se encontraba la vuelta abandonada en silencio, sin nota (`cancelled` no
        // la deja a propósito).
        cancelReverseRequested = false
        releasedForResume = true
        isWorking = false
        await resume()
    }

    /// «Cancelar la activación» en cualquiera de las fases de la ida que lo ofrecen (`canCancelMigration`): la
    /// subida del snapshot (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`), los tres pasos sin cifra que baje
    /// (`forward-migration-steps-have-no-ceiling-and-no-exit`) y la espera del seguidor, donde se llama «Dejar de esperar»
    /// (`adopt-follower-waits-for-the-leader-with-no-ceiling`). Vuelve a «Migrar a la nube» sin aviso de fallo.
    ///
    /// **El «sí» se apunta en el runner ANTES de esperar** (`requestMigrationCancel`), y la pasada en vuelo lo ve en su
    /// próxima vuelta. El re-kick de 30 s puede arrancar con el diálogo abierto, y con la red de vuelta esa pasada subía
    /// todo y seguía hasta el cutover: el «sí» llegaba tarde y la persona confirmaba cancelar para encontrarse la migración
    /// terminada (hallazgo de la review). Luego espera a que suelte el trabajo y cancela, que es lo que pasa cuando no había
    /// nada en vuelo. Si la pre-espera del import vence, el «sí» sigue apuntado y lo ejecuta la próxima pasada que llegue a
    /// una fase que lo ofrezca.
    ///
    /// **Y cierra la sesión que abrió ESTE intento**, molde de la parada del claim (`closeSessionIfOpened`): una sesión
    /// viva en un teléfono con sesión privada la registra `GroupsAssociationRegistrar` como cuenta de grupos en el
    /// siguiente arranque, y quien cancela no pidió eso. Tras un relanzamiento ya no se sabe quién la abrió
    /// (`migrationAttempt` vive en memoria), así que no se cierra, igual que allí. **La de un adopt sí**: su marca vive en
    /// `UserDefaults` (`closeSessionOfExitedAdopt`, ticket `adopt-exit-keeps-the-session-it-opened`).
    func cancelMigration() async {
        runner.requestMigrationCancel()
        while isWorking {
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                #if DEBUG
                print("CloudMigrationController.cancelSnapshotUpload: espera cancelada: \(error)")
                #endif
                return
            }
        }
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        guard await awaitImportQuiescenceForResume() else {
            refresh()
            return
        }
        await runner.cancelMigration()
        refresh()
        // `notStarted` solo puede venir de la cancelación en un intento de «Migrar», el único que apunta
        // `migrationAttempt`: la otra arista que lleva ahí, el claim devuelto, cierra la sesión por su cuenta
        // (`announceForwardClaimRefusal`, que limpia `migrationAttempt`). Las de un adopt —`existing_stable`, el líder que
        // termina— no llegan con `migrationAttempt` puesto. Si el toque llegó tarde y la migración avanzó, la sesión es la de una migración que
        // sigue, y no se toca.
        if journaledPhase == .notStarted, let attempt = migrationAttempt {
            migrationAttempt = nil
            _ = await closeSessionIfOpened(attempt.sessionOpenedByThisAttempt)
        }
        // La de un adopt la cierra su propia marca, que sobrevive a relanzar.
        await closeSessionOfExitedAdopt()
    }

    /// «Cancelar y seguir en la nube», en cualquiera de las cinco fases que lo ofrecen (`canCancelReverse`).
    ///
    /// No descarta el gesto si hay trabajo en vuelo: el refresco de la pantalla re-kickea cada 30 s y el runner
    /// ignoraría en silencio una segunda acción (`runGuarded`), así que un «sí» confirmado justo entonces no haría
    /// nada. Espera a que suelte y cancela después. Si mientras tanto la vuelta ya avanzó —drenó, o saltó su
    /// techo—, el runner no hace nada: no hay de dónde salir.
    func cancelReverse() async {
        // El «sí» se apunta ANTES del spin, no después. Un re-kick de 30 s en vuelo puede cruzar las cuatro fases
        // previas al montaje en una sola pasada —cada una es una llamada de red, no una espera—, y con el flag
        // puesto después, el `resume()` que viniera detrás no lo veía: el gesto se perdía en silencio tras haber
        // prometido lo contrario. Lo que queda fuera de alcance es el pase que YA cruzó hasta el montaje: ahí la
        // salida previa no existe y el toque es no-op, con su ticket.
        cancelReverseRequested = true
        while isWorking {
            do {
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                #if DEBUG
                print("CloudMigrationController.cancelReverse: espera cancelada: \(error)")
                #endif
                return
            }
        }
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        // Misma pre-espera que `resume()` (#36): sin ella, con el import de iCloud activo, el runner se rendiría a
        // los 120 s de su propia espera en silencio y el «sí» no haría nada. Con ella la tarjeta dice que espera a
        // iCloud mientras tanto. Si vence, el «sí» sigue apuntado y lo ejecuta el siguiente `resume()` que la pase.
        guard await awaitImportQuiescenceForResume() else {
            refresh()
            return
        }
        cancelReverseRequested = false
        await runner.cancelReverse()
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
        await closeSessionOfExitedAdopt()
        startRuntimeIfStable()
    }

    // MARK: - Boot coordinator (P4)

    /// Coordinator de boot: lee el journal + efectos pendientes (baratos) y decide vía
    /// `MigrationBootDecision`. Retoma (`resume`) una migración transicional / con efectos pendientes,
    /// sondea al líder (`pollLeader`), o no hace nada. Al quedar la fase estable, re-arranca el runtime del
    /// dominio (el paso 14.7 pudo haberse cortado por P0 mientras la fase era transicional).
    ///
    /// **Con el journal ilegible no decide nada** (ticket `an-unreadable-migration-journal-reads-as-never-started`): ni
    /// retoma, ni sondea, ni arranca el motor. Hasta ese ticket la lectura fallida era `(notStarted, sin pendientes)` ⇒
    /// `.none` ⇒ `startRuntimeIfStable`, o sea el motor arrancando sobre un journal que no se había leído. Lo reintenta el
    /// re-kick de cada primer plano —que además arranca el motor si se quedó `.idle`— y el de la pantalla, cada 30 s.
    func resumeIfNeeded(clearingError: Bool = true) async {
        guard let inputs = readJournalDecisionInputs() else {
            refresh()
            return
        }
        let (phase, hasPending) = inputs
        journaledPhase = phase
        // Antes de retomar nada: recoge la salida de un adopt que un kill dejó con la sesión abierta, y en el arranque va por
        // delante del registrador de Grupos, que primero pregunta a la red (`AppBootstrapper`).
        await closeSessionOfExitedAdopt()
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
    ///
    /// Con el journal ilegible no re-kickea. Y si la pantalla se había quedado en `.journalUnreadable` y ahora SÍ lee, la
    /// refresca aunque no haya nada aparcado: este es el único lector que corre en cada primer plano para todo el parque, y
    /// sin él un arranque cuya lectura falló (un prewarm con el store aún protegido) dejaba `.journalUnreadable` puesto todo
    /// el proceso — la fila de Ajustes abierta por `isEngaged` y la comprobación del Apple ID apagada.
    ///
    /// **Y arranca el motor si se quedó `.idle` con la fase estable** (lo cazaron dos lentes de la review). Un arranque que no
    /// pudo leer el journal deja `CloudSyncRuntime` en `.idle` —`canRunDomain` no concede sin fase—, y ni
    /// `CloudSyncRuntime.handleBecameActive` re-evalúa `.idle` ni el boot vuelve a pasar por `startRuntimeIfStable`: sin esto,
    /// un teléfono en la nube se quedaba sin sincronizar hasta relanzar, con «Todo sincronizado» en pantalla. Solo `.idle`:
    /// `startShared` re-arranca cualquier estado que no sea `.running`, y un `.stoppedUntilRelaunch` no se toca. Cubre
    /// también el caso en que falló solo la lectura de `MigrationPhaseStore` y la del controller no.
    func rekickIfParked() async {
        guard !StorageModePersistence.isSignOutWipeArmed() else { return }
        let wasUnreadable = uiState == .journalUnreadable
        guard let inputs = readJournalDecisionInputs() else {
            // Sin journal no se re-kickea; la pantalla sí se entera ya, no en el siguiente `refresh()`.
            refresh()
            return
        }
        let (phase, hasPending) = inputs
        if wasUnreadable { refresh() }
        guard MigrationForegroundRekick.shouldRekick(
            phase: phase, hasPendingEffects: hasPending, isWorking: isWorking) else {
            if CloudSyncRuntime.shared?.state == .idle { startRuntimeIfStable() }
            return
        }
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
    ///
    /// Con el journal ilegible no arranca: no se sabe si la fase es estable.
    private func startRuntimeIfStable() {
        guard let inputs = readJournalDecisionInputs() else { return }
        let (phase, hasPending) = inputs
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
        let read = readJournal()
        if case .read(let snapshot) = read {
            journaledPhase = snapshot.phase
            pendingEffectCount = snapshot.pendingCount
        }

        let mountedDecision = SwiftDataConfiguration.personalStoreMountedDecision
        let mirrorOffArmed = StorageModePersistence.isMirrorOffArmed()
        uiState = CloudMigrationUIStateDeriver.derive(
            // M1: modo PERSISTIDO del dueño, no el efectivo — la UI de migración describe la
            // travesía del DEVICE (un `.cloud` efectivo espurio de una sesión secundaria mentiría).
            storageMode: StorageModePersistence.read(),
            read: read.phaseRead,
            mirrorOffArmed: mirrorOffArmed,
            mountedDecision: mountedDecision,
            // La última lectura buena: con el journal ilegible la fase no se usa (`.journalUnreadable`).
            adoptEffectJournaled: adoptEffectJournaled)

        // `_runner` y NO `runner`: la property lazy CONSTRUIRÍA el runner y su executor (red, sesión,
        // clients) — `refresh()` corre desde el `init` y desde el poll de la pantalla de adopt, y no
        // es sitio para eso. Sin runner vivo no hay claim aparcado que reportar.
        claimBlocker = _runner?.lastClaimBlocker
        claimDefinitiveCause = _runner?.lastClaimDefinitiveCause
        reverseUploadSample = _runner?.lastReverseUploadSample
        reverseSessionExpiry = _runner?.lastReverseSessionExpiry

        refreshSyncBanner()
    }

    /// Banner S11 (D5): runtime detenido por sesión expirada con filas vivas pendientes → CTA sign-in.
    ///
    /// **Cuenta las dos colas desde el 2026-09-25**, la personal y la de grupos (ticket
    /// `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`): con solo cambios de grupos no salía, y el cierre de
    /// sesión mandaba a volver a entrar sin ninguna puerta a la vista. La decisión vive en `SyncSignInBannerLogic.decide`.
    private func refreshSyncBanner() {
        let banner = Self.syncSignInBanner(context: context, isCloud: CloudSyncFlags.storageMode == .cloud,
                                           runtimeState: CloudSyncRuntime.shared?.state,
                                           hasSession: CloudAuthService.shared.hasSession)
        syncNeedsSignIn = banner.needsSignIn
        pendingUploadCount = banner.pendingCount
    }

    /// El cuerpo del banner con el store y el estado del motor inyectados, para medirlo con un store real: el controller no
    /// se construye en tests. Producción entra SOLO por `refreshSyncBanner`.
    static func syncSignInBanner(context: ModelContext, isCloud: Bool, runtimeState: CloudSyncRuntime.RuntimeState?,
                                 hasSession: Bool) -> SyncSignInBannerLogic.Banner {
        let waits = SyncSignInBannerLogic.engineWaitsForSignIn(state: runtimeState, hasSession: hasSession)
        // Sin contar nada fuera de ese estado: la tarjeta no sale, y el fetch es trabajo del hilo principal.
        guard isCloud, waits else {
            return SyncSignInBannerLogic.decide(isCloud: isCloud, engineWaitsForSignIn: waits,
                                                personalLive: 0, groupsLive: 0)
        }
        // **Si una cola no se deja contar, se ofrece firmar SIN cifra** (ticket
        // `an-unreadable-migration-journal-reads-as-never-started`). El motor ya está parado hasta firmar, y firmar es
        // inofensivo; el `try? … ?? 0` de antes daba `syncNeedsSignIn = false` y la sección pintaba «Todo sincronizado»
        // con el motor parado. La cifra no se inventa: `pendingUploadCount` queda en `nil`.
        let personalLive: Int?
        do {
            personalLive = try context.fetch(FetchDescriptor<SyncOutbox>())
                .filter { $0.rejectedReason == nil }.count
        } catch {
            #if DEBUG
            print("CloudMigrationController.refreshSyncBanner: fetch(SyncOutbox) falló: \(error)")
            #endif
            personalLive = nil
        }
        return SyncSignInBannerLogic.decide(
            isCloud: isCloud, engineWaitsForSignIn: waits,
            personalLive: personalLive,
            // El MISMO predicado que sube el canal (`GroupsSyncClient.pushPending`): lo que se cuenta es lo que firmar sube.
            groupsLive: CloudSessionSignOut.liveGroupsPendingRowIDs(context: context)?.count)
    }

    /// Re-firma para reanudar el sync detenido (banner S11). El método NO se elige: es determinista —
    /// el de la cuenta (`storedProvider()`, que la expiración de sesión del SDK no borra: vive en el
    /// profileStore propio y solo lo limpia `signOut()`, y un signed-out no ve este banner). Ofrecer
    /// chooser aquí invitaría al mismatch R9. Fallback `.apple` = el MISMO residual documentado del
    /// claim (key perdida, población ~0): una cuenta Google re-firmaría con SIWA y GoTrue linkearía
    /// por email verificado (H4) o el refresh seguiría detenido — jamás datos cruzados.
    ///
    /// **Desde el 2026-09-25 es la puerta del cierre de sesión en la nube** (ticket
    /// `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`), y por eso cambió en dos sitios:
    ///  · **con la sesión que el SDK guarda, prueba con un ciclo antes de firmar** (`SyncSignInBannerLogic.needsSignIn`). El
    ///    atajo de antes —«hay sesión y hay token ⇒ despierta»— dejaba sin salida el 401 que el servidor da a un JWT que el SDK
    ///    da por bueno: el botón despertaba la cadencia, chocaba otra vez y la tarjeta volvía a salir.
    ///  · **la firma se ata a la cuenta del motor** (`SyncSignInBannerLogic.afterSignIn`). Si entra otra, se cierra esa sesión
    ///    —conservando el proveedor de la cuenta del teléfono—, no se reanuda nada y se avisa. Molde de
    ///    `signInToResumeReverse`, que deja la vuelta intacta con otra cuenta.
    ///  · **(review del mismo día) también desde un motor arrancado SIN sesión tras relanzar** (`.idleSignedOut`): sin dueño
    ///    en memoria el ancla es el sello del claim, y aceptada la firma se arranca el motor en vez de despertarlo. El
    ///    proveedor sale del faro cuando es el de la cuenta dueña (`SyncSignInBannerLogic.provider`).
    func signInToResumeSync() async {
        isWorking = true
        defer { isWorking = false }
        let runtime = CloudSyncRuntime.shared
        // Belt R9 (C-7, hermano del de `startMigration`): si la sesión revivió por otra entrada mientras el banner seguía en
        // pantalla, basta con despertar la cadencia. Pero «revivió» lo contesta el servidor, no el SDK: un ciclo.
        if CloudAuthService.shared.hasSession {
            if let runtime, CloudSyncRuntime.canRunDomain() {
                let outcome = await runtime.syncCycle(context: context)
                if !SyncSignInBannerLogic.needsSignIn(afterProbe: outcome) {
                    runtime.handleBecameActive()
                    refresh()
                    return
                }
            } else if await CloudAuthService.shared.accessToken() != nil {
                // Con el candado del dominio cerrado no se corre ningún ciclo (ticket
                // `sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate`), así que no hay prueba posible: el trato de
                // antes. `handleBecameActive` tampoco reanuda con el candado cerrado.
                runtime?.handleBecameActive()
                refresh()
                return
            }
        }
        let beacon = CloudBeacon()
        let provider = SyncSignInBannerLogic.provider(
            stored: CloudAuthService.shared.storedProvider(), beaconProvider: beacon.linkedProvider,
            beaconHash: beacon.accountHash, ownerUserID: runtime?.ownerUserID)
        do {
            try await CloudAuthService.shared.signIn(with: provider)
            let signedIn = CloudAuthService.shared.currentUserID
            switch SyncSignInBannerLogic.afterSignIn(
                ownerUserID: runtime?.ownerUserID, signedInUserID: signedIn,
                signedInIsClaimed: signedIn.map { CloudClaimActionStore.shared.action(forUserID: $0) != nil } ?? false) {
            case .resume:
                // Parado en este proceso, la cadencia se re-despierta; arrancado sin sesión tras relanzar
                // (`.idleSignedOut`), `handleBecameActive` no hace nada y hay que arrancarlo, por la puerta de siempre
                // (`startRuntimeIfStable` → `start`, con su gate de identidad).
                if runtime?.state == .stoppedUntilSignIn {
                    runtime?.handleBecameActive()
                } else {
                    startRuntimeIfStable()
                }
            case .rejectOtherAccount:
                // Nada se reanuda y la sesión que entró no se queda: con ella viva, el cierre de sesión o cualquier otro
                // ciclo subiría las colas de este teléfono a su nombre.
                CloudSyncBreadcrumb.syncSignInAccountMismatch()
                // La abrió ESTE intento, así que se cierra por el único `signOut` del controller.
                _ = await closeSessionIfOpened(true)
                // El de la cuenta del teléfono cuando el faro lo ancla (`SyncSignInBannerLogic.provider`).
                CloudAuthService.shared.restoreStoredProvider(provider)
                lastError = L10n.Storage.Errors.syncSignInOtherAccount
            }
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

    /// `nil` = el journal no se dejó leer, y quien pregunta no decide nada.
    private func readJournalDecisionInputs() -> (phase: MigrationPhase, hasPending: Bool)? {
        guard case .read(let snapshot) = readJournal() else { return nil }
        return (snapshot.phase, snapshot.pendingCount > 0)
    }

    /// El ÚNICO lector del journal del controller. Con una lectura buena aplica los seis motivos; con una ilegible **no
    /// escribe ninguno** —conservan el último valor leído— y solo marca `isJournalUnreadable`, con rastro en la
    /// TRANSICIÓN: la pantalla lee cada segundo.
    private func readJournal() -> MigrationJournalRead {
        let context = self.context
        let read = MigrationJournalRead.read {
            #if DEBUG
            if UITestHooks.migrationJournalUnreadable { throw MigrationJournalSeamError.fetchFailed }
            #endif
            var descriptor = FetchDescriptor<MigrationState>()
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        }
        switch read {
        case .read(let snapshot):
            isJournalUnreadable = false
            cutoverBlocker = snapshot.cutoverBlocker
            snapshotExitReason = snapshot.snapshotExitReason
            forwardStepExitReason = snapshot.forwardStepExitReason
            journaledClaimIntent = snapshot.claimIntent
            adoptClaimExit = snapshot.adoptClaimExit
            adoptClaimAccountHash = snapshot.adoptClaimAccountHash
            adoptEffectJournaled = snapshot.adoptEffectJournaled
            reverseAbortReason = snapshot.reverseAbortReason
            hasPendingReverseExit = snapshot.hasPendingReverseExit
        case .unreadable:
            if !isJournalUnreadable { CloudSyncBreadcrumb.migrationJournalUnreadable(reader: "controller") }
            isJournalUnreadable = true
        }
        return read
    }

    // MARK: - Elegibilidad de reversa (para la vista)

    /// Veredicto `ReverseEligibility` + conteo de testigos con `ckRecordName` (para el copy). Lectura pura.
    ///
    /// Si los testigos no se dejan contar, `hasCKMap` es `nil` y la decisión es `mapUnreadable`: no se concede la vuelta
    /// con un dato que no se leyó (ticket `an-unreadable-migration-journal-reads-as-never-started`).
    func reverseEligibility() -> ReverseEligibility.Decision {
        let hasCKMap: Bool?
        do {
            hasCKMap = try context.fetchCount(
                FetchDescriptor<SyncIdentity>(predicate: #Predicate { $0.ckRecordName != nil })) > 0
        } catch {
            #if DEBUG
            print("CloudMigrationController.reverseEligibility: fetchCount(SyncIdentity) falló: \(error)")
            #endif
            hasCKMap = nil
        }
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
    ///
    /// **Si el marcador no se deja contar, se lee «no hay»**, y es el lado seguro (ticket
    /// `an-unreadable-migration-journal-reads-as-never-started`): la card dice «Migrar a la nube», y «Migrar» nunca adopta
    /// —lo impiden las dos capas de `StorageMigrationIdentityGateLogic` y `ForwardClaimIntent.migrateOnly`—, así que con
    /// una cuenta que ya tiene datos acaba en el aviso de la puerta. El contrario ofrecería adoptar sin saber si hay algo.
    func markerDecision() -> MarkerDecision {
        let markerFound: Bool
        do {
            markerFound = try context.fetchCount(FetchDescriptor<CloudMigrationMarker>()) > 0
        } catch {
            #if DEBUG
            print("CloudMigrationController.markerDecision: fetchCount(CloudMigrationMarker) falló: \(error)")
            #endif
            markerFound = false
        }
        return MigrationStateMachine.markerReconciliation(
            markerFound: markerFound, journaledPhase: journaledPhase)
    }

    /// Dry-run §g.5: conteos EN MEMORIA de lo que migraría (read-only, para "Ver qué migraría"). Si uno solo de los cuatro
    /// lanza, no se enseña ninguno: el `try? … ?? 0` de antes decía «0 movimientos» de una tabla que no se leyó.
    func dryRunCounts() -> MigrationDryRunPreview {
        do {
            return .counts(
                transactions: try context.fetchCount(FetchDescriptor<TransactionItem>()),
                categories: try context.fetchCount(FetchDescriptor<Category>()),
                accounts: try context.fetchCount(FetchDescriptor<Account>()),
                budgets: try context.fetchCount(FetchDescriptor<Budget>()))
        } catch {
            #if DEBUG
            print("CloudMigrationController.dryRunCounts: fetchCount falló: \(error)")
            #endif
            return .unreadable
        }
    }
}
