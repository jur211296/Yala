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
    /// La sesión de la nube ya no vale (el SDK borró la sesión, o el gateway rechazó el JWT). Esperar no lo arregla,
    /// así que **en la VUELTA** corta sin gastar reintento de red (ticket
    /// `reverse-before-mount-stays-stuck-with-an-expired-session`). En la IDA el trato no cambia: `driveVerify` lo
    /// mapea a `networkTimeout`, que es lo que hacía antes de que este caso existiera, y hay un test que lo fija.
    /// Un token que no llega sin red NO llega aquí: lo separan los clientes con `canRenewSession`.
    case sessionExpired
    /// El servidor dijo que no, y no es red ni sesión (hoy: 403, la cuenta en la nube no está disponible). **En la
    /// VUELTA** elige el techo CORTO de la etapa previa al montaje (ticket
    /// `reverse-before-mount-has-no-way-to-abandon-the-return`); en la IDA el trato tampoco cambia, `driveVerify` lo
    /// mapea a `networkTimeout` como hacía antes de que este caso existiera.
    case blocked(ReversePreMountBlocker)
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
/// reverse-líder y `rejected` = el servidor no la concede: las dos vuelven al origen con su porqué journaleado
/// (ticket `reverse-claim-rejection-has-no-way-out-in-the-client`). `sessionExpired`/`transient` = stop retomable.
nonisolated enum ReverseClaimOutcome: Equatable {
    case accepted
    case otherLeader
    case sessionExpired
    case transient
    case rejected(reason: String)
}

/// Resultado de un paso genérico de la reversa (drain final / freeze). `completed` avanza; `transient` corta;
/// `sessionExpired` corta igual pero DEJA RASTRO para la pantalla (ticket
/// `reverse-before-mount-stays-stuck-with-an-expired-session`): esperar no lo arregla, y hasta ese ticket las dos
/// eran el mismo corte mudo. Un token que no llega sin red NO es esto: lo separa `canRenewSession` aguas arriba.
///
/// `blocked` es el tercero de esa familia y lo añade `reverse-before-mount-has-no-way-to-abandon-the-return`: el
/// servidor dijo que no y esperar tampoco lo arregla, así que elige el techo CORTO. Hasta ese ticket sus tres motivos
/// —el `other_leader` y el `rejected` del congelado, el 403 del drenaje— llegaban aquí como `transient`, y esa es la
/// razón de que la vuelta se quedara parada en esas fases sin salida.
nonisolated enum ReverseStepOutcome: Equatable {
    case completed
    case transient
    case sessionExpired
    case blocked(ReversePreMountBlocker)
}

/// Las CUATRO fases de la vuelta a iCloud anteriores al montaje del espejo. Ninguna es estable: el motor de la nube
/// no corre con ellas journaleadas (`MigrationRuntimeGate.isDomainStablePhase`) y el aviso de «vuelve a entrar» de
/// Ajustes (`syncNeedsSignIn`) no sale, porque ese solo se enciende con el runtime en `.stoppedUntilSignIn` y lo que
/// se pinta es la tarjeta de progreso.
///
/// Dos consumidores, y el `rawValue` es el mismo para los dos (WIRE del canario `cloudReverseBlockedByExpiredSession`,
/// que no cambia de serie con el renombrado del tipo):
///
/// 1. **La sesión caducada** (ticket `reverse-before-mount-stays-stuck-with-an-expired-session`), en memoria y molde
///    de `lastClaimBlocker`: describe la OBSERVACIÓN, no el estado durable —el journal sigue en su fase, retomable— y
///    cada paso que avanza la limpia. La repone el resume del arranque y el re-kick de 30 s de la pantalla, que para
///    las cuatro fases decide `.resume` (`MigrationBootDecision.decide`).
/// 2. **El techo de la etapa** (ticket `reverse-before-mount-has-no-way-to-abandon-the-return`), journaleado en
///    `MigrationState.reversePreMountPhaseRaw`: cambiar de fase es lo que cuenta como AVANCE, así que el reloj
///    necesita saber en cuál se selló.
nonisolated enum ReversePreMountPhase: String, Equatable, Sendable {
    case claim
    case drain
    case verify
    case freeze

    /// La fase journaleada, si es una de las cuatro. `nil` en cualquier otra —incluidas las POST-montaje de la propia
    /// vuelta—: el techo de esta etapa no las cubre, porque ahí el espejo ya está vivo y la salida es otra.
    init?(phase: MigrationPhase) {
        switch phase {
        case .reverseClaimLeader:   self = .claim
        case .reverseDrainAll:      self = .drain
        case .reverseVerify:        self = .verify
        case .reverseFreezeBackend: self = .freeze
        default:                    return nil
        }
    }
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

/// Lo último que se vio de la espera de `reverseUpload` en ESTE proceso: cuántas filas faltan y por qué no drena.
/// En memoria, molde de `lastClaimBlocker`: describe la observación, no el estado durable, y la pantalla lo lee
/// para decir algo verdadero mientras espera (ticket `reverse-upload-has-no-ceiling-and-no-exit`).
nonisolated struct ReverseUploadSample: Equatable {
    let pending: Int
    let blocker: ReverseUploadBlocker
}

/// Una salida del claim de la reversa observada en ESTE proceso: el servidor no concedió la reserva, u otro dispositivo
/// ya era el líder (ticket `reverse-claim-rejection-has-no-way-out-in-the-client`). `sequence` crece con cada salida, y
/// es lo que deja a `CloudMigrationController.startReverse` saber si la produjo SU toque: el porqué journaleado no
/// distingue un rechazo de ahora de la nota de un intento anterior.
nonisolated struct ReverseClaimExit: Equatable {
    let sequence: Int
    let reason: ReverseAbortReason
}

/// Una salida de las CUATRO fases previas al montaje observada en ESTE proceso: el techo de la etapa venció, o la
/// persona tocó «Cancelar y seguir en la nube» desde una de ellas (ticket
/// `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`). Molde de `ReverseClaimExit`, y por la
/// MISMA razón: el porqué journaleado (`reverseAbortReasonRaw`) no distingue una salida de ahora de la nota de un
/// intento de hace días, así que sin `sequence` la alerta saldría también por la nota vieja.
///
/// **Aparte de `ReverseClaimExit`, no fusionado con él**, igual que `ForwardClaimRefusal`: cada salida lleva su
/// testigo y su comparación. Dos no pueden coincidir en una pasada —la primera devuelve `false` y `drive()` corta—,
/// así que no compiten por el mismo aviso.
///
/// `reason` incluye `.cancelled`, que NO se anuncia. Ese filtro es `ReverseUploadWaitingCopyLogic.abortNote`, el
/// mismo que decide si la tarjeta pone nota: el testigo dice qué pasó, y qué se enseña lo decide un solo sitio.
nonisolated struct ReversePreMountExit: Equatable {
    let sequence: Int
    let reason: ReverseAbortReason
}

/// Qué pidió la persona al llegar al claim de la IDA. Lo pone `CloudMigrationController` en cada entrada que conduce el
/// claim, y el runner lo journalea (`MigrationState.forwardClaimIntentRaw`) en el mismo save que lleva a `claimingMigration`.
///
/// `existing_stable` le dice lo mismo al servidor en los dos casos —la cuenta ya tiene lo personal reclamado—, pero no a
/// la persona. Quien entra en su cuenta (Welcome «Ya tengo cuenta», la tarjeta de adopt de Ajustes) quiere adoptarla. Quien
/// toca «Migrar a la nube» quiere llevar SUS datos a una cuenta que no los tenga, y adoptar ahí sube el corpus local a esa
/// cuenta (`MigrationWorkExecutor.runAdoptOrphanReconcile`): la fusión que el ADR del 2026-09-09 descartó. Ticket
/// `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`.
///
/// La comprobación previa (`StorageMigrationIdentityGateLogic.check`) para casi todo eso antes del claim. Esto es lo que ve
/// solo el claim: una cuenta que volvió a iCloud (`/account/exists` la da como `groups_only`), una que se completa entre
/// la comprobación y el claim, y una que otro dispositivo empezó a migrar en ese rato (`claiming_in_progress`).
///
/// **Journaleada, no en memoria, y lo decidió la review.** La primera versión la guardaba en memoria creyendo que la ventana
/// de un relanzamiento era una petición. No lo es: el claim se queda aparcado en `claimingMigration` todo lo que dure sin red
/// o con la sesión caducada, y un `resume` tras relanzar adoptaba. En una cuenta que volvió a iCloud eso dejaba el
/// dispositivo en modo nube sobre un backend congelado que rechaza todo push. Una fila anterior a la v6 no trae intención y
/// se lee como `.adoptIfExisting`.
///
/// **Con «Migrar» tampoco se sigue a otro líder** (Jürgen, 2026-09-16): `claiming_in_progress` vuelve al inicio igual que
/// `existing_stable`. Seguirle acaba en un adopt cuando el líder termina, y relevarle a los 60 min sube lo local encima de lo
/// que él dejó; con el mismo iCloud es lo correcto, con otro mezcla dos corpus, y el teléfono no puede distinguirlos. El
/// seguidor que queda (`pollLeader`) es el de un adopt, que no lee la intención (ticket
/// `adopt-uploads-a-foreign-corpus-without-a-lineage-check`).
nonisolated enum ForwardClaimIntent: String, Equatable {
    /// Si la cuenta ya existe, adoptarla. El comportamiento de siempre, y el default del runner.
    case adoptIfExisting
    /// «Migrar a la nube»: la cuenta tiene que nacer, o promoverse, en este claim.
    case migrateOnly

    /// ¿Este desenlace del claim vuelve al inicio en vez de llegar a la máquina como `claimResult`? Con «Migrar», todo lo
    /// que no sea que la cuenta nazca o se promueva en ESTE claim (`created`).
    func refuses(_ state: AccountClaimDecision.ClaimState) -> Bool {
        switch state {
        case .created:                             return false
        case .existingStable, .claimingInProgress: return self == .migrateOnly
        }
    }
}

/// Un claim de la ida que `ForwardClaimIntent.migrateOnly` devolvió al inicio en ESTE proceso. `sequence` crece con cada
/// uno, y es lo que deja a `CloudMigrationController` saber si lo produjo la llamada en curso (molde de `ReverseClaimExit`).
/// `claimState` es lo que contestó el servidor, que decide el motivo del aviso.
nonisolated struct ForwardClaimRefusal: Equatable {
    let sequence: Int
    let claimState: AccountClaimDecision.ClaimState
}

/// ¿Este regreso al origen repone los pendientes que la vuelta a iCloud reemplazó? Sí cuando la vuelta vuelve al origen
/// ANTES de que el servidor conceda la reserva: desde la confirmación (`reverseDeclined`, un `fatalError` o un kill ahí)
/// o desde `reverseClaimLeader` (rechazo u otro líder). La vuelta no empezó, así que el dispositivo tiene que quedar como
/// estaba. Lo preguntan `handle` y la normalización del resume, y tienen que contestar lo mismo (ticket
/// `reverse-claim-rejection-has-no-way-out-in-the-client`, hallazgo de la review adversarial).
///
/// Se repone lo que YA estaba pendiente, nunca un efecto que el dispositivo no tenía: un reconcile que lanza para siempre
/// (líder desplazado) vuelve al callejón en el que ya estaba antes del toque. Queda fuera, y lo dice su ticket, que tras
/// un arranque con la vuelta a medias ese pendiente impida arrancar el motor en esa sesión
/// (`reverse-claim-exit-with-a-restored-failing-effect-keeps-the-engine-off`). Y un `fatalError` en `reverseClaimLeader`
/// va a `reverseFailedRollback`, no al origen, así que no repone: hoy nadie lo emite en esa fase.
nonisolated enum ReverseOriginPendingEffects {
    static func restoresOnReturn(from current: MigrationPhase, to next: MigrationPhase) -> Bool {
        switch current {
        case .reverseConfirm, .reverseClaimLeader:
            return next == .done || next == .notStarted
        default:
            return false
        }
    }
}

/// ¿Quedó a medias una salida de la espera de `reverseUpload`? Lo preguntan dos sitios que tienen que contestar lo
/// mismo: el runner, que solo drena antes de otra vuelta si es así, y la pantalla, que solo entonces dice que falta
/// terminar de reactivar la nube. `.reverseRollback` es el último efecto de las dos salidas
/// (`[.rearmMirrorOff, .reverseRollback]`), así que sigue pendiente hasta que la salida termina entera.
nonisolated enum ReverseExitPending {
    static func isPending(_ pendingEffects: [MigrationEffect]) -> Bool {
        pendingEffects.contains(.reverseRollback)
    }
}

/// Seam del trabajo REAL por fase (los ejecutores reales llegan en w3-w6; aquí solo el fake de tests).
/// `@MainActor`: manipula red/identidad/ModelContext en prod.
@MainActor
protocol MigrationWorkExecuting: AnyObject {
    /// `POST /account/claim` (§f.1) — reusa `ClaimOutcome` de `CloudAccountClient`.
    func performClaim() async -> ClaimOutcome
    /// Deshace el sello que `performClaim` dejó en `CloudClaimActionStore` en su última llamada, y repone el que hubiera.
    /// Lo pide el runner cuando `ForwardClaimIntent` devuelve el claim al inicio: el sello de `existing_stable` es
    /// `.routeReturningUser`, el mismo que deja el adopt, y sin adopt afirmaría que esa cuenta entró en este dispositivo; el
    /// de `claiming_in_progress` es `.waitForLeader`, de un seguidor que no llegó a serlo. El Welcome lee el sello para
    /// dejar re-entrar libre a «la misma cuenta» (`CrossAccountEntryGuardLogic`). Default no-op en la extension de abajo.
    func discardLastClaimStamp()
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
    /// `reverseFreezeBackend` (§h): marca la cuenta backend "reverting". `completed` avanza; `transient` corta
    /// retomable; `sessionExpired` corta dejando rastro para la pantalla. Devolvía `Bool` hasta el ticket
    /// `reverse-before-mount-stays-stuck-with-an-expired-session`, y ese `false` único metía en el mismo saco la red y
    /// una sesión que hay que renovar a mano.
    func freezeBackendForReverse() async -> ReverseStepOutcome
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
    /// Techo de `reverseUpload`: por qué no drena la subida, hasta donde se sabe. Read-only y SIN red. Elige el
    /// presupuesto (`stallCause`) y el copy de la espera. Default `.unknown` en la extension de abajo: un fake
    /// que no lo guiona espera el presupuesto largo.
    func reverseUploadBlocker() -> ReverseUploadBlocker

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

    /// Default del techo de `reverseUpload`: causa desconocida ⇒ presupuesto largo. Fail-open, como el canal.
    func reverseUploadBlocker() -> ReverseUploadBlocker { .unknown }

    /// Default: un conformador que no sella nada no tiene nada que deshacer.
    func discardLastClaimStamp() {}
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

    /// La última observación de la espera de `reverseUpload` (`nil` = ninguna en este proceso, o la espera ya
    /// terminó). La lee `CloudMigrationController.refresh()` para decir cuántas filas faltan, o que iCloud no
    /// está, en vez de una barra al 95 % muda.
    private(set) var lastReverseUploadSample: ReverseUploadSample?

    /// La última salida del claim de la reversa en este proceso (`nil` = ninguna). En memoria, molde de
    /// `lastClaimBlocker`: la nota que dura vive en el journal (`reverseAbortReasonRaw`); esto solo decide la alerta.
    private(set) var lastReverseClaimExit: ReverseClaimExit?

    /// La última salida de las cuatro fases previas al montaje en este proceso (`nil` = ninguna). Mismo molde y misma
    /// razón que el de arriba: la nota que dura vive en el journal, y esto es lo único que sabe si la salida la
    /// produjo la llamada en curso. La lee `CloudMigrationController.announceReversePreMountExit`.
    private(set) var lastReversePreMountExit: ReversePreMountExit?

    /// Dónde se paró la vuelta a iCloud porque la sesión de la nube ya no vale (`nil` = no se paró por eso). La lee
    /// `CloudMigrationController.refresh()` para que la tarjeta diga que hay que volver a entrar y lo ofrezca, en vez
    /// de una barra parada al 15/30/50/62 % con un «Retomar» que recibe lo mismo.
    ///
    /// **La escribe UN solo sitio** (`noteReverseSessionExpiry`), y los cuatro pasos la ponen o la limpian con su
    /// outcome: un paso que avanza, o que corta por red, la borra — si no, un «vuelve a entrar» de hace un rato
    /// seguiría en pantalla mientras la vuelta ya progresa.
    private(set) var lastReverseSessionExpiry: ReversePreMountPhase?

    /// La intención que se journaleará al llegar a `claimingMigration` (`ForwardClaimIntent`). La ponen las entradas de
    /// `CloudMigrationController`; el default conserva el comportamiento de siempre. `driveClaim` NO lee esto: lee lo
    /// journaleado, que es lo que sobrevive a un relanzamiento.
    private(set) var forwardClaimIntent: ForwardClaimIntent = .adoptIfExisting

    /// El último claim de la ida que esa intención devolvió al inicio en este proceso (`nil` = ninguno). Solo decide el
    /// aviso: el journal ya está en `notStarted`.
    private(set) var lastForwardClaimRefusal: ForwardClaimRefusal?

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

    /// Fija qué pidió la persona antes de conducir el claim de la ida (`ForwardClaimIntent`). Sin espera ni `save()`: se
    /// journalea con la transición `authenticating → claimingMigration`, no antes.
    func setForwardClaimIntent(_ intent: ForwardClaimIntent) {
        forwardClaimIntent = intent
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
            // Una salida de la espera de `reverseUpload` sin red deja la fase ORIGEN con `.reverseRollback`
            // pendiente, y `handle` REEMPLAZA los pendientes al journalear el evento siguiente: empezar otra vuelta
            // encima borraría el `reverse_abort` sin ejecutarlo, y la vuelta nueva chocaría con la nube aún
            // congelada (409 en `reverseDrainAll`, al 30 % para siempre). Se drenan antes, como hace
            // `resetAfterRollback`; si lanzan, el toque no empieza nada y el journal queda intacto.
            //
            // SOLO si lo pendiente es esa salida. Otro pendiente en fase estable (`.runLeaderReconcileFromFrozenCloudKit`
            // en `done`, `.adoptBackendAccount` en `notStarted`) se reemplaza como siempre: el reconcile de un líder
            // al que otro dispositivo le quitó la lease lanza `other_leader` en cada intento, y drenarlo cerraba la
            // única salida de ese estado, que es justo esta vuelta.
            if event == .reverseActivated, try ReverseExitPending.isPending(self.loadState().readPendingEffects()) {
                try await self.drainPendingEffects(isResume: true)
            }
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
            state.reverseUploadLowestPending = nil
            state.reverseUploadProgressAt = nil
            state.reverseAbortReasonRaw = nil
            state.reversePreMountProgressAt = nil
            state.reversePreMountPhaseRaw = nil
            state.setReverseOriginPendingEffects([])
            state.forwardClaimIntentRaw = nil
            if target == .notStarted { state.startedAt = nil }
            state.updatedAt = self.now()
            try self.context.save()
            CloudSyncBreadcrumb.migrationJournaled(phase: "\(target) (reset tras rollback)")
        }
    }

    /// «Cancelar y seguir en la nube». **Un solo gesto para las CINCO fases en las que se ofrece**, y por eso una
    /// sola entrada: la espera de `reverseUpload` (ticket `reverse-upload-has-no-ceiling-and-no-exit`) y las cuatro
    /// previas al montaje (`reverse-before-mount-has-no-way-to-abandon-the-return`). La máquina vuelve al origen
    /// journaleado con la salida que le toque a cada una, y el motivo journaleado es `cancelled` en las cinco: lo
    /// decidió la persona, así que no deja nota.
    ///
    /// No-op en cualquier otra fase: un toque que llega tarde —la vuelta ya avanzó, o ya salió por su techo— no
    /// puede sacar a nadie de un sitio en el que ya no está.
    func cancelReverse() async {
        guard await awaitQuiescence() else {
            CloudSyncBreadcrumb.migrationQuiescenceTimeout()
            return
        }
        await runGuarded {
            if try self.normalizeCorruptJournalIfNeeded() { return }
            let phase = try self.loadState().readPhase().phase
            let origin = try self.originFromJournal()
            if phase == .reverseUpload {
                _ = try await self.journalReverseUploadStep(
                    .reverseUploadCancelled(returnTo: origin), exitReason: .cancelled, hold: nil)
            } else if let preMount = ReversePreMountPhase(phase: phase) {
                _ = try await self.leaveReversePreMount(
                    .reversePreMountCancelled(returnTo: origin),
                    phase: preMount, exitReason: .cancelled, hold: nil)
            } else {
                return
            }
            try await self.drive()
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
            // La vuelta a iCloud REEMPLAZA los pendientes del origen: se guardan, y un regreso al origen antes de que el
            // servidor conceda la reserva los repone (`ReverseOriginPendingEffects`). Al conceder la reserva la vuelta
            // empezó de verdad y lo guardado deja de aplicar.
            var nextPending = effects
            if event == .reverseActivated {
                state.setReverseOriginPendingEffects(state.readPendingEffects())
            } else if ReverseOriginPendingEffects.restoresOnReturn(from: current, to: next) {
                nextPending += state.readReverseOriginPendingEffects()
                state.setReverseOriginPendingEffects([])
            } else if current == .reverseClaimLeader, next != .reverseClaimLeader {
                // El término `next !=` no es cosmético: desde el techo de las fases previas al montaje
                // (`reverse-before-mount-has-no-way-to-abandon-the-return`) esta fase tiene un SELF-HOLD, que es la
                // primera arista que la deja en sí misma. Sin él, una observación bajo presupuesto —un claim sin
                // cobertura— tiraba los pendientes guardados del origen, y el rechazo que llegara después los reponía
                // vacíos: el `.runLeaderReconcileFromFrozenCloudKit` del líder, que es lo ÚNICO que manda `complete`,
                // se perdía para siempre. Es el bug que cerró `reverse-claim-rejection-has-no-way-out-in-the-client`,
                // reabierto por un corte de red.
                state.setReverseOriginPendingEffects([])
            }
            state.setPhase(next)
            state.setPendingEffects(nextPending)
            // La intención del claim de la ida, en el MISMO save que lleva a `claimingMigration`: lo que la lee es
            // `driveClaim`, también tras un relanzamiento.
            if event == .signInSucceeded, next == .claimingMigration {
                state.forwardClaimIntentRaw = forwardClaimIntent.rawValue
            }
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
                // Techo de `reverseUpload`: una vuelta nueva empieza sin reloj ni cifra, y el porqué de la salida
                // anterior deja de ser verdad.
                state.reverseUploadLowestPending = nil
                state.reverseUploadProgressAt = nil
                state.reverseAbortReasonRaw = nil
                // Techo de las fases previas al montaje: lo MISMO, y aquí no es higiene sino corrección. El reloj de
                // esta etapa se compara por FASE, así que un sello de un intento anterior en la misma fase daría un
                // `stalled` de días en la primera observación del intento nuevo: techo instantáneo.
                state.reversePreMountProgressAt = nil
                state.reversePreMountPhaseRaw = nil
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
                // Techo de `reverseUpload`: el reloj y la cifra son del intento. El porqué de una salida de la
                // espera, en cambio, SOBREVIVE a `notStarted` —es la fase origen de un adoptador y la persona lo
                // lee tras relanzar— y solo se va cuando la vuelta SÍ llegó a iCloud.
                state.reverseUploadLowestPending = nil
                state.reverseUploadProgressAt = nil
                if next == .icloudActive { state.reverseAbortReasonRaw = nil }
                state.reversePreMountProgressAt = nil
                state.reversePreMountPhaseRaw = nil
                // Los pendientes guardados de una vuelta ya se repusieron arriba si tocaba; en un cierre no queda nada
                // que reponer.
                state.setReverseOriginPendingEffects([])
                // La intención es del intento que se cierra.
                state.forwardClaimIntentRaw = nil
            }
            // Techo de las fases previas al montaje: el reloj se compara por FASE, así que cualquier cambio de fase
            // lo invalida — incluido el RETORNO a una ya visitada, que es el que muerde: `reverseVerify` vuelve a
            // `reverseDrainAll` por mismatch, y sin esto la segunda visita heredaba el sello de la primera y el techo
            // saltaba con cero segundos de parada real. El self-hold no entra (ahí `next == current`), así que el
            // sello que escribe la observación sobrevive.
            if ReversePreMountPhase(phase: next) != ReversePreMountPhase(phase: current) {
                state.reversePreMountProgressAt = nil
                state.reversePreMountPhaseRaw = nil
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
        // La observación de «la sesión ya no vale» se RE-OBSERVA en cada pasada de trabajo: aquí se borra y solo
        // sobrevive si esta misma pasada vuelve a chocar con ella (ticket
        // `reverse-before-mount-stays-stuck-with-an-expired-session`).
        //
        // **Un solo borrador, y por eso está aquí y no repartido por los pasos.** Ponerlo en cada outcome que avanza
        // o corta por red deja líneas que se cumplen solas: desde un claim aceptado toda continuación pasa por otro
        // paso que también borraría, así que quitar la de ahí no cambia nada observable y ningún test puede cazarlo.
        lastReverseSessionExpiry = nil
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
                // icloudActive/reverseFailedRollback son terminales estables.
                //
                // **Esto ya NO es DARK, y decía que sí hasta el 2026-09-21.** El comentario venía de cuando solo el
                // panel DEBUG emitía `reverseActivated`; desde que «Volver a iCloud» existe en Ajustes lo emite
                // `CloudMigrationController.startReverse`, o sea producción. Se corrigió porque una lente de review
                // se lo creyó y rebajó por eso la gravedad de un hallazgo: un «no mires aquí» que ya no era verdad.
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
                case .transient:
                    try await observeReversePreMountStall(.drain, blocker: nil)
                    return
                case .sessionExpired:
                    noteReverseSessionExpiry(.drain)
                    try await observeReversePreMountStall(.drain, blocker: nil)
                    return
                case let .blocked(blocker):
                    try await observeReversePreMountStall(.drain, blocker: blocker)
                    return
                }
            case .reverseVerify:
                if !(try await driveReverseVerify()) { return }
            case .reverseFreezeBackend:
                // `reverse_freeze` server-side (I11-3): la red corta retomable SIN evento; la sesión caducada corta
                // igual, pero deja rastro para la pantalla. Los dos, y también el rechazo del servidor, pasan por el
                // techo de la etapa antes de cortar.
                switch await executor.freezeBackendForReverse() {
                case .completed:
                            try await handle(.reverseBackendFrozen)    // efecto: mountMirrorAndRelaunch
                case .transient:
                    try await observeReversePreMountStall(.freeze, blocker: nil)
                    return
                case .sessionExpired:
                    noteReverseSessionExpiry(.freeze)
                    try await observeReversePreMountStall(.freeze, blocker: nil)
                    return
                case let .blocked(blocker):
                    try await observeReversePreMountStall(.freeze, blocker: blocker)
                    return
                }
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
        // La intención JOURNALEADA, no la de memoria: tras un relanzamiento es lo único que queda del intento.
        let intent = state.forwardClaimIntentRaw.flatMap(ForwardClaimIntent.init(rawValue:)) ?? .adoptIfExisting
        switch await executor.performClaim() {
        case let .success(claimState):
            lastClaimBlocker = nil
            if intent.refuses(claimState) {
                // «Migrar a la nube» sobre una cuenta que ya tiene lo personal, o que otro dispositivo está migrando: al
                // inicio, sin adopt ni seguidor, y sin el sello que el claim acaba de dejar. Primero el sello: si Yala muere
                // entre los dos, el journal sigue en `claimingMigration` y el claim se repite.
                executor.discardLastClaimStamp()
                CloudSyncBreadcrumb.migrationClaimRefusedExistingAccount()
                try await handle(.claimRefusedExistingAccount)
                lastForwardClaimRefusal = ForwardClaimRefusal(
                    sequence: (lastForwardClaimRefusal?.sequence ?? 0) + 1, claimState: claimState)
                return true                                // notStarted: `drive` sale en la siguiente vuelta
            }
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
        // `sessionExpired` DELIBERADAMENTE junto a `networkTimeout`: `verify()` lo comparten la ida y la vuelta, y el
        // caso nuevo se abrió para la VUELTA (ticket `reverse-before-mount-stays-stuck-with-an-expired-session`). En la
        // ida el trato se queda EXACTO al de antes de que el caso existiera —gasta reintento de red y al tope degrada
        // a `failedRollback`— porque su superficie es otra (`lastClaimBlocker`, la pantalla de adopt) y su terminal SÍ
        // revierte: separarlo ahí es otro ticket, con su propia QA (`forward-verify-reads-an-expired-session-as-network`).
        // Sin este `case` explícito el compilador exigiría uno igual, y quien lo escribiera sin este porqué diría
        // «ya estaba así». Lo fija `MigrationRunnerTests.forwardVerify_sessionExpired_spendsNetworkRetry`.
        //
        // `blocked` entra aquí por lo MISMO y el 2026-09-21 (ticket
        // `reverse-before-mount-has-no-way-to-abandon-the-return`): el 403 lo tipa ahora `verify()`, que sigue siendo
        // compartida, y en la ida se lee como red igual que antes. Su residual es el mismo
        // (`forward-verify-reads-an-expired-session-as-network`).
        case .networkTimeout, .sessionExpired, .blocked:
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

    /// `reverseClaimLeader`. `accepted` → avanza; `otherLeader` y `rejected` → vuelven al origin journaleado con su
    /// porqué (ticket `reverse-claim-rejection-has-no-way-out-in-the-client`: antes un rechazo cortaba sin evento y la
    /// fase, que es TRANSITORIA, no salía nunca); `sessionExpired`/`transient` → stop retomable, **observando el techo
    /// de la etapa** (`reverse-before-mount-has-no-way-to-abandon-the-return`: hasta el 2026-09-21 cortaban sin
    /// evento, y bajo presupuesto la observación holdea en la misma fase y sin efectos). Devuelve `false` para cortar
    /// el bucle.
    private func driveReverseClaim() async throws -> Bool {
        switch await executor.performReverseClaim() {
        case .accepted:
            try await handle(.reverseLeaderClaimed)
            return true
        case .otherLeader:
            CloudSyncBreadcrumb.reverseOtherLeader()
            try await journalReverseClaimExit(
                .reverseOtherLeader(returnTo: try originFromJournal()),
                reason: .otherDeviceReverting, serverReason: "other_leader")
            return false                                   // la máquina ya movió al origin (terminal/forward)
        case .sessionExpired:
            noteReverseSessionExpiry(.claim)
            try await observeReversePreMountStall(.claim, blocker: nil)
            return false
        case .transient:
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "reverse: transient")
            try await observeReversePreMountStall(.claim, blocker: nil)
            return false
        case let .rejected(reason):
            CloudSyncBreadcrumb.reverseClaimRejected(reason: reason)
            try await journalReverseClaimExit(
                .reverseClaimRejected(returnTo: try originFromJournal()),
                reason: .forClaimRejection(serverReason: reason), serverReason: reason)
            return false                                   // la máquina ya movió al origin
        }
    }

    /// Anota dónde se paró la vuelta porque la sesión ya no vale (ticket
    /// `reverse-before-mount-stays-stuck-with-an-expired-session`). Lo BORRA `drive()` al empezar cada pasada.
    ///
    /// **El canario va por `canaryOnce`, con la fase en la clave.** El re-kick de 30 s de la pantalla vuelve a
    /// chocar con la misma sesión caducada cada medio minuto, y una tarde mirando la barra llenaría el spool con un
    /// único hecho; dedupear a mano aquí pediría un segundo testigo que `drive()` no borra, y ese testigo no lo
    /// puede cazar ningún test. El breadcrumb SÍ sale cada vez: es un log, y ver que el atasco sigue ayuda.
    private func noteReverseSessionExpiry(_ phase: ReversePreMountPhase) {
        lastReverseSessionExpiry = phase
        CloudSyncBreadcrumb.reverseBlockedByExpiredSession(phase: phase.rawValue)
        MetricsService.cloudReverseBlockedByExpiredSession(phase: phase.rawValue)
    }

    /// Journalea una salida del claim de la reversa: la vuelta al origen y, en el MISMO save, el porqué que lee la
    /// tarjeta de «Volver a iCloud». El origen se va con el intento, como en la salida de la espera. La máquina no pone
    /// efectos —el claim no reservó nada—, pero `handle` repone los pendientes que la vuelta había reemplazado
    /// (`ReverseOriginPendingEffects`) y los drena en el acto.
    ///
    /// La salida se anota en el paso que la journalea, ANTES de drenar lo repuesto (molde de
    /// `journalReverseUploadStep`): el drenaje puede tardar —el reconcile de un líder sube su residual y manda
    /// `complete`— y quien cierra Yala entretanto perdería el canario. Si un pendiente repuesto lanza, la salida ya está
    /// anotada y el pendiente queda para el siguiente resume.
    private func journalReverseClaimExit(
        _ event: MigrationEvent,
        reason: ReverseAbortReason,
        serverReason: String
    ) async throws {
        try await handle(event) { state, next in
            guard next != .reverseClaimLeader else { return }
            state.reverseAbortReasonRaw = reason.rawValue
            state.reverseOriginRaw = nil
            self.recordReverseClaimExit(reason: reason, serverReason: serverReason)
        }
    }

    private func recordReverseClaimExit(reason: ReverseAbortReason, serverReason: String) {
        let sequence = (lastReverseClaimExit?.sequence ?? 0) + 1
        lastReverseClaimExit = ReverseClaimExit(sequence: sequence, reason: reason)
        MetricsService.cloudReverseClaimRejected(reason: serverReason)
    }

    /// `reverseVerify` (S9 REUSADO; autoridad backend→local → un mismatch RE-DRENA, no re-sube). Inyecta el
    /// `retriesSoFar` desde el journal e incrementa el contador correcto en el MISMO save.
    ///
    /// **De los cinco desenlaces, solo el mismatch sigue usando los contadores S9.** Los otros dos que no avanzan
    /// —la sesión caducada, el `blocked` del servidor y, desde el 2026-09-21, la red pura— pasan por el techo de la
    /// etapa (`observeReversePreMountStall`) y cortan retomable sin tight-loop, que es el trato de las otras tres
    /// fases previas al montaje. `verifyNetworkRetries` ya NO se gasta en la vuelta, y por eso
    /// `reverseVerifyOutcome(.networkTimeout)` dejó de ser un par legal de la máquina desde `reverseVerify`.
    private func driveReverseVerify() async throws -> Bool {
        switch await executor.verify() {
        case .sessionExpired:
            // NO gasta `verifyNetworkRetries` ni degrada, que es lo que cumple el criterio del ticket hermano: el
            // `networkTimeout` que este caso tenía antes acababa en `reverseFailedRollback` con `.reverseRollback`
            // pendiente — un efecto que con la sesión caducada LANZA en cada resume, así que la fase de fallo se
            // quedaba con su abort sin ejecutar. Esperar no renueva una sesión: la renueva la persona.
            //
            // Hasta el 2026-09-21 cortaba SIN evento; desde el techo de la etapa emite `reversePreMountStalled`, que
            // bajo presupuesto holdea en la misma fase y sin efectos.
            noteReverseSessionExpiry(.verify)
            try await observeReversePreMountStall(.verify, blocker: nil)
            return false
        case let .blocked(blocker):
            // El servidor dijo que no y esperar no lo cambia, así que NO gasta `verifyNetworkRetries` —el camino que
            // lo gastaba acababa en `reverseFailedRollback` con el abort pendiente— y va derecho al techo CORTO de
            // la etapa. Es el único de los tres que elige el corto: los otros dos no son una respuesta del servidor.
            try await observeReversePreMountStall(.verify, blocker: blocker)
            return false
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
            // La red PURA también va al techo de la etapa desde el 2026-09-21 (ticket
            // `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`, decisión de Jürgen). Hasta ese
            // día era la única de las ocho combinaciones fase × causa que se quedaba fuera: gastaba
            // `verifyNetworkRetries` y al octavo degradaba a `reverseFailedRollback` con `.reverseRollback`
            // pendiente. Salida tenía —no era el limbo del ticket padre—, pero la PEOR de las dos: un terminal que
            // exige un toque, en vez de devolver el teléfono a sincronizar solo en su origen. Ahora es la hermana
            // exacta de la red del drenaje y del congelado, que ya pasaban por aquí.
            //
            // `blocker: nil` ⇒ techo LARGO (72 h): la red vuelve sola, y quien está sin cobertura una tarde no
            // pierde la vuelta por eso.
            //
            // **`.networkTimeout` NO es solo «no hay red», y eso es deuda heredada que este `case` ahora expone**
            // (medido el 2026-09-21, hallazgo de la review). `VerifyProbeMapping` lo usa de cajón: el `fetch-failed`
            // del Merkle —que aplana el 401 y el 403 de `/sync/merkle`, porque `SyncMerkle` colapsa todo lo que no
            // sea `.snapshot`—, los dos `fetch` de SwiftData que lanzan, y el `default` de un `reason` que este build
            // no conozca. Para esa mitad el techo largo es GENEROSO: no se va a resolver sola en 72 h. El push y el
            // pull, que corren ANTES en `verify()`, sí tipan su 401/403, así que la ventana es la del 403 que empieza
            // justo entre el pull y el Merkle. Antes de este ticket esa mitad degradaba a `reverseFailedRollback` en
            // minutos, con tarjeta y botón; hoy espera. Se aceptó para no tocar `SyncMerkle`, que comparten la ida y
            // el motor, y tiene ticket propio: `reverse-verify-network-bucket-hides-a-definitive-server-no`.
            //
            // **La IDA no cambia**: `driveVerify` es otra función y agrupa este caso con `.sessionExpired` y
            // `.blocked` en su rama de red, como antes de que ninguno de los dos existiera. Lo fija
            // `MigrationRunnerTests.forwardVerify_networkTimeout_stillSpendsTheBudget_andDegradesAtTheCap`, y su
            // residual sigue siendo `forward-verify-reads-an-expired-session-as-network`.
            try await observeReversePreMountStall(.verify, blocker: nil)
            return false
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
    /// observa la espera contra su TECHO (ticket `reverse-upload-has-no-ceiling-and-no-exit`): bajo presupuesto
    /// corta retomable (el resume, el re-kick y el refresco de la pantalla re-sondean); agotado, la máquina vuelve
    /// al origen en modo nube y `drive()` sale por ahí.
    private func driveReverseUpload() async throws -> Bool {
        switch executor.reverseUploadStatus() {
        case .drained:
            lastReverseUploadSample = nil
            try await handle(.reverseUploadCompleted)      // → icloudActive [marker, beacon, mode, server]
            return true
        case let .pending(count):
            CloudSyncBreadcrumb.reverseUploadPending(count: count)
            // Heartbeat (I14-pre): cada re-poll del panel/resume mientras el mirror aún exporta mantiene la
            // lease viva (el drenaje a CloudKit puede tardar).
            await executor.sendLeaseHeartbeatIfDue()
            return try await observeReverseUploadWait(pending: count)
        }
    }

    /// Una observación de la espera de `reverseUpload`. El reloj del techo es el del ÚLTIMO AVANCE, y avanzar es que
    /// la cifra de pendientes baje de la más baja vista en este intento: un corpus grande que sube despacio avanza y
    /// no agota nunca el presupuesto; el que se clava, sí. Escribir durante la espera SUBE la cifra, así que con el
    /// mínimo no cuenta ni como avance ni como retroceso.
    ///
    /// La primera observación —o la de un journal escrito antes de este campo— SELLA el reloj sin contarla como
    /// avance, y nunca lo sella hacia atrás: el presupuesto cuenta desde que se empezó a mirar. Devuelve `true` si
    /// la espera terminó (para que `drive()` relea la fase).
    private func observeReverseUploadWait(pending count: Int) async throws -> Bool {
        let blocker = executor.reverseUploadBlocker()
        lastReverseUploadSample = ReverseUploadSample(pending: count, blocker: blocker)
        let state = try loadState()
        let observedAt = now()
        let lowest = state.reverseUploadLowestPending
        let advanced = lowest.map { count < $0 } ?? false
        let lastProgressAt: Date
        if advanced {
            lastProgressAt = observedAt
        } else if let sealed = state.reverseUploadProgressAt, sealed <= observedAt {
            lastProgressAt = sealed
        } else {
            // Sin sello, o con un sello en el FUTURO: el reloj iba adelantado cuando se selló y ya se corrigió. Se
            // re-sella ahora. Conservarlo aplazaría el techo hasta que el reloj real alcanzara aquella fecha.
            lastProgressAt = observedAt
        }
        let stalled = observedAt.timeIntervalSince(lastProgressAt)
        CloudSyncBreadcrumb.reverseUploadObserved(
            pending: count, stalledSeconds: stalled, advanced: advanced, blocker: blocker.rawValue)
        // El canario se emite en CADA observación (dedupe por proceso dentro del helper): un atasco SISTÉMICO —un
        // mirror que no exporta para nadie— se ve en la flota mucho antes de que ningún teléfono agote el techo.
        MetricsService.cloudReverseUploadWaiting(
            advancing: advanced, stalledSeconds: stalled, blocker: blocker.rawValue)
        let origin = try originFromJournal()
        return try await journalReverseUploadStep(
            .reverseUploadStalled(stalledSeconds: stalled, cause: blocker.stallCause, returnTo: origin),
            exitReason: blocker.abortReason,
            hold: (lowest: min(lowest ?? count, count), progressAt: lastProgressAt))
    }

    /// Journalea un paso de la espera de `reverseUpload` —una observación o la cancelación— y devuelve si la
    /// máquina la dejó. Si la DEJA: el motivo sobrevive a la vuelta al origen (la persona puede leerlo tras
    /// relanzar) y el reloj, la cifra y el origen se van con el intento. Si HOLDEA: se guarda el reloj y la cifra
    /// de `hold`.
    ///
    /// Un efecto de la salida que lanza —`reverse_abort` sin red— NO deshace la salida: la fase origen ya está
    /// journaleada y el efecto queda pendiente para el próximo resume.
    private func journalReverseUploadStep(
        _ event: MigrationEvent,
        exitReason: ReverseAbortReason,
        hold: (lowest: Int, progressAt: Date)?
    ) async throws -> Bool {
        var leftTheWait = false
        try await handle(event) { state, next in
            guard next != .reverseUpload else {
                if let hold {
                    state.reverseUploadLowestPending = hold.lowest
                    state.reverseUploadProgressAt = hold.progressAt
                }
                return
            }
            leftTheWait = true
            state.reverseAbortReasonRaw = exitReason.rawValue
            state.reverseUploadLowestPending = nil
            state.reverseUploadProgressAt = nil
            state.reverseOriginRaw = nil
            // Se cuenta AQUÍ, en el paso que journalea la salida y antes de drenar sus efectos: la tarjeta de relanzar
            // aparece en cuanto `.rearmMirrorOff` arma el par, `reverse_abort` puede tardar, y quien obedece y cierra
            // Yala mataría el proceso antes de contarla.
            self.reportReverseUploadExit(exitReason)
        }
        return leftTheWait
    }

    private func reportReverseUploadExit(_ reason: ReverseAbortReason) {
        lastReverseUploadSample = nil
        CloudSyncBreadcrumb.reverseUploadExited(reason: reason.rawValue)
        MetricsService.cloudReverseUploadAborted(reason: reason.rawValue)
    }

    // MARK: - Techo y salida de las CUATRO fases previas al montaje
    // (ticket `reverse-before-mount-has-no-way-to-abandon-the-return`)

    /// Una observación de una fase PREVIA al montaje que no avanzó en esta pasada. Se llama desde los cortes de las
    /// cuatro, y decide si la vuelta se queda esperando o sale a su origen.
    ///
    /// **El reloj es el del último CAMBIO DE FASE**, no el del inicio de la etapa: aquí no hay una cifra que baje
    /// —el drenaje no expone un pendiente comparable, la verificación es un veredicto y el congelado es una sola
    /// llamada—, así que avanzar es pasar a la fase siguiente. Un drenaje largo y sano no agota el presupuesto
    /// porque cuando termina cambia de fase y el reloj vuelve a cero; el único bucle posible
    /// (`reverseVerify ⇄ reverseDrainAll` por mismatch) lo acota `maxMismatchRetries`.
    ///
    /// La primera observación de una fase SELLA el reloj sin contarla como parada, y nunca lo sella hacia atrás: un
    /// sello en el futuro es un reloj que iba adelantado y ya se corrigió, y conservarlo aplazaría el techo hasta
    /// que el reloj real alcanzara aquella fecha (molde del techo de la espera de subida).
    ///
    /// `blocker` es la palabra del servidor cuando la hay —y solo entonces el presupuesto es el CORTO—. Sin ella
    /// (red, sesión caducada) el presupuesto es el largo: la red vuelve sola y la sesión la renueva la persona, que
    /// además tiene su aviso y su botón mucho antes de que esto venza.
    ///
    /// Devuelve `true` si la vuelta SALIÓ. Los llamadores lo DESCARTAN y cortan la pasada, como hace la salida del
    /// claim: el origen es `.done` o `.notStarted`, donde `drive()` corta igual, así que releer la fase no ganaría
    /// nada y el próximo resume retoma desde el origen.
    @discardableResult
    private func observeReversePreMountStall(
        _ phase: ReversePreMountPhase,
        blocker: ReversePreMountBlocker?
    ) async throws -> Bool {
        let state = try loadState()
        let observedAt = now()
        let sealedPhase = state.reversePreMountPhaseRaw.flatMap(ReversePreMountPhase.init(rawValue:))
        let lastProgressAt: Date
        if sealedPhase != phase {
            lastProgressAt = observedAt                      // cambió de fase: eso ES el avance
        } else if let sealed = state.reversePreMountProgressAt, sealed <= observedAt {
            lastProgressAt = sealed
        } else {
            lastProgressAt = observedAt                      // sin sello, o con un sello en el FUTURO
        }
        let stalled = observedAt.timeIntervalSince(lastProgressAt)
        let cause = blocker?.stallCause ?? .unknown
        CloudSyncBreadcrumb.reversePreMountStalled(
            phase: phase.rawValue, stalledSeconds: stalled, blocker: blocker?.rawValue)
        // En CADA observación, no solo al salir: es lo que deja ver un atasco sistémico —un 403 en toda la flota—
        // antes de que ningún teléfono agote sus 15 min o sus 72 h. Es la regla de la familia
        // (`.claude/rules/swiftdata-cloudkit.md`, el canario del marcador) y esta etapa era la única sin cumplirla.
        MetricsService.cloudReversePreMountWaiting(
            phase: phase.rawValue, stalledSeconds: stalled, blocker: blocker?.rawValue)
        let origin = try originFromJournal()
        return try await leaveReversePreMount(
            .reversePreMountStalled(stalledSeconds: stalled, cause: cause, returnTo: origin),
            phase: phase,
            exitReason: blocker?.abortReason ?? .preMountStalled,
            hold: (phase: phase, progressAt: lastProgressAt))
    }

    /// Journalea el paso y, si dejó la etapa, des-reserva el servidor. **El abort se intenta también cuando el paso
    /// LANZA**, y ese `catch` es el hallazgo de una lente: la salida se journalea y se salva ANTES de drenar los
    /// pendientes del origen que `handle` repone, así que un reconcile que falla siempre —el residual
    /// `reverse-claim-exit-with-a-restored-failing-effect-keeps-the-engine-off`— dejaba la salida hecha y el aviso al
    /// servidor sin intentar **nunca**: no es un efecto journaleado, y la fase ya no vuelve a pasar por aquí. El
    /// error sigue su camino después, para que `runGuarded` corte la pasada como siempre.
    private func leaveReversePreMount(
        _ event: MigrationEvent,
        phase: ReversePreMountPhase,
        exitReason: ReverseAbortReason,
        hold: (phase: ReversePreMountPhase, progressAt: Date)?
    ) async throws -> Bool {
        do {
            let left = try await journalReversePreMountStep(
                event, phase: phase, exitReason: exitReason, hold: hold)
            if left { await abortReverseServerBestEffort() }
            return left
        } catch {
            if try leftThePreMountStage() { await abortReverseServerBestEffort() }
            throw error
        }
    }

    /// ¿El journal ya salió de las cuatro fases previas al montaje? Se relee del journal y no de un flag en memoria:
    /// el paso que lanzó puede haberlo dejado escrito antes de fallar.
    private func leftThePreMountStage() throws -> Bool {
        ReversePreMountPhase(phase: try loadState().readPhase().phase) == nil
    }

    /// Journalea un paso del techo de las fases previas al montaje —una observación o la cancelación— y devuelve si
    /// la máquina dejó la etapa. Si la DEJA: el motivo sobrevive a la vuelta al origen (la persona puede leerlo
    /// días después, en la tarjeta de «Volver a iCloud») y el reloj y el origen se van con el intento. Si HOLDEA:
    /// se sella el reloj de `hold`.
    ///
    /// La máquina no pone efectos en esta salida, así que aquí no hay nada que drenar: el `reverse_abort` lo
    /// intenta el llamador DESPUÉS, y que no salga no deshace la salida.
    private func journalReversePreMountStep(
        _ event: MigrationEvent,
        phase: ReversePreMountPhase,
        exitReason: ReverseAbortReason,
        hold: (phase: ReversePreMountPhase, progressAt: Date)?
    ) async throws -> Bool {
        var leftTheStage = false
        try await handle(event) { state, next in
            guard ReversePreMountPhase(phase: next) == nil else {
                if let hold {
                    state.reversePreMountPhaseRaw = hold.phase.rawValue
                    state.reversePreMountProgressAt = hold.progressAt
                }
                return
            }
            leftTheStage = true
            state.reverseAbortReasonRaw = exitReason.rawValue
            state.reversePreMountProgressAt = nil
            state.reversePreMountPhaseRaw = nil
            state.reverseOriginRaw = nil
            // Se cuenta AQUÍ, en el paso que journalea la salida y antes de intentar el `reverse_abort`: ese aviso al
            // servidor puede tardar o no salir, y perder el canario por eso dejaría la salida sin medir.
            self.reportReversePreMountExit(phase: phase, reason: exitReason)
        }
        return leftTheStage
    }

    /// **No borra `lastReverseSessionExpiry`**, y esa ausencia es deliberada: `drive()` es su ÚNICO borrador
    /// (`.claude/rules/swiftdata-cloudkit.md`, «un escritor y UN borrador»), y añadir aquí un segundo sería una línea
    /// que se cumple sola — lo único que lee ese testigo es `reverseNeedsSignIn`, que solo consume la tarjeta de
    /// progreso, y esa tarjeta no se pinta en `.done` ni en `.notStarted`. Ningún test podría cazar su borrado.
    ///
    /// **Y anota la salida en memoria** (`lastReversePreMountExit`, ticket
    /// `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`). Hasta ese ticket este paso escribía
    /// `reverseAbortReasonRaw` y nada más: con la pantalla delante la tarjeta cambiaba sin decir por qué, y la nota
    /// que quedaba no se distinguía de la de un intento anterior. La `sequence` es lo que sí lo distingue.
    private func reportReversePreMountExit(phase: ReversePreMountPhase, reason: ReverseAbortReason) {
        lastReversePreMountExit = ReversePreMountExit(
            sequence: (lastReversePreMountExit?.sequence ?? 0) + 1, reason: reason)
        CloudSyncBreadcrumb.reversePreMountExited(phase: phase.rawValue, reason: reason.rawValue)
        MetricsService.cloudReversePreMountAborted(phase: phase.rawValue, reason: reason.rawValue)
    }

    /// Des-reserva el servidor (`reverse_abort`) tras una salida PREVIA al montaje, **una vez y tragándose el
    /// fallo**. No es un efecto journaleado a propósito, y el criterio 3 del ticket es exactamente eso:
    /// `execute(.reverseRollback)` LANZA con el token ausente, con la sesión caducada y con cualquier `.transient`
    /// —ahí cae el 403—, un efecto que lanza no se consume, y `MigrationBootDecision.decide` devuelve `.resume`
    /// mientras haya pendientes ⇒ volvería a lanzar en cada arranque y en cada vuelta a la app, que es el bug-class
    /// que esta salida existe para cerrar.
    ///
    /// **Va DESPUÉS de journalear la salida**, no antes: si el proceso muere entre las dos cosas, el estado que
    /// queda es «en el origen, con la reserva puesta», que se cura solo. Al revés quedaría «en una fase
    /// pre-montaje, con la reserva ya quitada», reintentando un paso cuya reserva no existe.
    ///
    /// **Y que no salga cuesta poco, medido:** el re-claim del MISMO dispositivo es idempotente-ok y no mira la
    /// edad del lease (`gateway/test/account.goldens.test.ts`, golden 14), así que este teléfono puede volver a
    /// intentarlo cuando quiera; para los demás dispositivos de la cuenta el lease caduca a los 60 min.
    ///
    /// **Con UNA excepción, que hay que decir entera:** desde `reverseFreezeBackend` el congelado puede haberse
    /// estampado y haberse perdido la respuesta. Ahí el backend SÍ responde 409 `yala_account_reverting` a los
    /// pushes, y un abort que no sale deja el motor parado contra su propia nube. Es el residual
    /// `reverse-abort-rejected-leaves-a-frozen-cloud-saying-up-to-date`; desde las otras tres fases no hay congelado
    /// que deshacer y el motor arranca igual en el origen.
    private func abortReverseServerBestEffort() async {
        do {
            try await executor.execute(.reverseRollback)
        } catch {
            // El TIPO del error, no su descripción: `reverse_abort` viaja por red y un error arbitrario interpolado
            // con `privacy: .public` puede arrastrar cuerpo de respuesta. Molde de `MetricsClient` y
            // `CloudRemoteConfig`, que ya lo hacen así cuando el error no es del propio build.
            CloudSyncBreadcrumb.reverseAbortBestEffortFailed(reason: String(describing: type(of: error)))
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
        state.reverseUploadLowestPending = nil
        state.reverseUploadProgressAt = nil
        state.reverseAbortReasonRaw = nil
        state.reversePreMountProgressAt = nil
        state.reversePreMountPhaseRaw = nil
        state.setReverseOriginPendingEffects([])
        state.forwardClaimIntentRaw = nil
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
            // Estados no-durables (dryRun/consent/authenticating) reingresan desde notStarted. Un kill en la
            // confirmación de la vuelta a iCloud la devuelve al origen sin haber empezado: se reponen los pendientes que
            // había reemplazado, igual que en `handle`.
            state.setPhase(resumed)
            if ReverseOriginPendingEffects.restoresOnReturn(from: journaled, to: resumed) {
                state.setPendingEffects(state.readReverseOriginPendingEffects())
                state.setReverseOriginPendingEffects([])
            } else {
                state.setPendingEffects([])
            }
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
