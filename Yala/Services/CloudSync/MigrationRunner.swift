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
//   - `ClaimOutcome` no-success (sessionExpired/accountUnavailable/transient) → stop retomable, JAMÁS
//     `fatalError` (un 401 recuperable no debe producir un rollback espurio). Lo que SÍ se registra es
//     la CAUSA, en `lastClaimBlocker` y fuera del journal: sin ella los tres se veían iguales desde la
//     pantalla del adopt, que dejaba «Conectando con tu cuenta…» puesta también ante un 403. Desde el
//     2026-09-22 el stop pasa por el TECHO del paso (`forwardStepStalled`): bajo presupuesto holdea igual.
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
    /// Algo que no es red ni sesión paró el paso, y esperar no lo arregla. **En la VUELTA** elige el techo CORTO de la
    /// etapa previa al montaje (ticket `reverse-before-mount-has-no-way-to-abandon-the-return`); en la IDA el trato
    /// tampoco cambia, `driveVerify` lo mapea a `networkTimeout` como hacía antes de que este caso existiera.
    ///
    /// Nació con el 403 (`.accountUnavailable`) y desde el 2026-09-22 lo produce también la verificación Merkle cuando
    /// la base LOCAL falla al leer (`.localFailure`) o cuando el veredicto trae un motivo que este build no conoce
    /// (`.unknownVerdict`) — ticket `reverse-verify-network-bucket-hides-a-definitive-server-no`. Y ese mismo día,
    /// **la propia `verify()` sin llegar al Merkle**: sus dos lecturas del outbox salen por aquí con
    /// `.localFailure` cuando el `fetch` lanza (`verify-reads-a-failed-local-fetch-as-an-empty-outbox`).
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
///
/// `blocked` corta igual, pero dice que esperar no lo arregla, y elige el techo CORTO de la fase (ticket
/// `snapshot-upload-has-no-ceiling-and-no-way-out`). Hasta ese ticket los tres motivos llegaban aquí como `transient`,
/// y sin separarlos no había techo corto posible.
enum SnapshotStepOutcome: Equatable {
    case completed
    case pageConfirmed(cursor: String)
    case transient
    case blocked(SnapshotStallBlocker)
}

/// Por qué no avanza la subida del snapshot cuando la causa es de las que esperar NO arregla. El `rawValue` es la clave
/// del reloj de causa (`MigrationState.snapshotStallCauseRaw`) y el detalle del canario, así que es WIRE: no se renombra.
///
/// **La sesión caducada es definitiva aquí, y en la vuelta a iCloud no lo es.** Allí la tarjeta ofrece «Iniciar sesión»
/// y la renovación la hace la persona sin salir de la vuelta; en la ida no hay ese botón, y la salida del techo (la
/// tarjeta de fallo con «Reintentar») es justo la que vuelve a pedir la sesión. **Pero solo llega aquí con la sesión
/// BORRADA por el SDK**: un 401 del gateway con la sesión todavía guardada (reloj del teléfono atrasado, una revocación
/// que el SDK aún no ha descubierto) va como `transient`, porque esperar sí lo arregla y el reintento no pediría nada
/// (`MigrationSnapshotUploader.canRenewSession`). Un token que no llega sin red tampoco es esto.
nonisolated enum SnapshotStallBlocker: String, Equatable, Sendable {
    /// El push devolvió `.sessionExpired` y el SDK ya no conserva una sesión que renovar.
    case sessionExpired
    /// El push devolvió `.accountUnavailable`: en `/sync/push` hoy es el 409 `yala_account_reverting` (la cuenta está
    /// congelada porque otro dispositivo la está devolviendo a iCloud), o un 403 si la ruta llega a emitirlo.
    case accountUnavailable
    /// Una lectura o escritura LOCAL lanzó: el `fetch` del outbox, o el encolado de la página (salvo la deriva del
    /// reloj, que va como `transient` porque el reloj puede corregirse solo).
    case localFailure
}

/// Por qué terminó una subida que venció su techo. Lo journalea la salida (`MigrationState.snapshotExitReasonRaw`) y
/// elige el texto de la tarjeta de fallo, así que también es WIRE.
///
/// **Lo elige el techo que VENCIÓ, no la última observación** (`MigrationRunner.snapshotExitReason`): tras 72 h sin red,
/// una pasada que traiga un 403 recién visto no puede decirle a la persona que su cuenta no lo permitió.
nonisolated enum SnapshotExitReason: String, Equatable, Sendable {
    /// Venció el techo LARGO: 72 h sin confirmar una sola página, con la causa que fuera. Su texto dice «lleva días», y
    /// solo aquí es verdad.
    case stalled
    case sessionExpired
    case accountUnavailable
    case localFailure
    /// Venció el techo CORTO con motivos definitivos turnándose, y ninguno llegó SOLO a los 900 s (ticket
    /// `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`, decisión de Jürgen del 2026-09-23:
    /// motivo propio). Ninguno de los textos específicos es verdad entero, y el de `stalled` tampoco: afirma días y esta
    /// salida llega a los 15 min. Su texto no nombra motivo ni plazo.
    case mixedCauses

    init(_ blocker: SnapshotStallBlocker) {
        switch blocker {
        case .sessionExpired:     self = .sessionExpired
        case .accountUnavailable: self = .accountUnavailable
        case .localFailure:       self = .localFailure
        }
    }
}

/// Los pasos de la ida en los que avanzar no es una cifra que baje, sino pasar al paso siguiente (ticket
/// `forward-migration-steps-have-no-ceiling-and-no-exit`). El `rawValue` es el detalle del canario, así que es WIRE.
///
/// La subida del snapshot NO está aquí aunque vaya entre medias: tiene su propio techo, y ahí avanzar sí es una cifra
/// (cada página confirmada). `verifying` tampoco: su salida es el contador de reintentos S9. Y del cutover solo entra
/// `.pending` — desde `.serverConfirmed` el backend ya estampó `migrated_at` y rendirse no puede ser un rollback.
///
/// **El seguidor (`waitingForLeader`) es el cuarto** desde `adopt-follower-waits-for-the-leader-with-no-ceiling`
/// (decisión de Jürgen del 2026-09-23: el techo del 22 %). Su diferencia es qué cuenta como avance: aquí no puede cambiar
/// de paso por su cuenta, así que avanzar es que el servidor vuelva a contestar `claiming_in_progress` —el líder tiene el
/// lease vivo—, y cada una de esas respuestas BORRA los relojes (`noteLeaderAlive`). Como en los otros tres, los sella la
/// primera observación que no avanza: un seguidor que cerró Yala mientras esperaba y la abre días después sin red no sale
/// en ese primer poll (lo cazó la review). Un líder vivo con mucho corpus no echa nunca al seguidor: lo acota el lease,
/// que caduca a los 60 min sin latido y convierte al seguidor en líder (`created`).
nonisolated enum ForwardStepPhase: String, Equatable, Sendable {
    case claim
    case identity
    case cutoverPending
    case waitingForLeader

    /// El paso journaleado, si es uno de los cuatro. `nil` en cualquier otra fase.
    init?(phase: MigrationPhase) {
        switch phase {
        case .claimingMigration:  self = .claim
        case .assigningIdentity:  self = .identity
        case .cutover(.pending):  self = .cutoverPending
        case .waitingForLeader:   self = .waitingForLeader
        default:                  return nil
        }
    }
}

/// ¿En qué fases de la ida se ofrece «Cancelar la activación»? En las cuatro en las que el teléfono sigue intacto en
/// iCloud y la fase puede quedarse parada: la subida del snapshot (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`)
/// y los tres pasos sin cifra que baje (`forward-migration-steps-have-no-ceiling-and-no-exit`). Decisiones de Jürgen del
/// 2026-09-22.
///
/// **El claim, con las DOS intenciones** desde `adopt-claim-stays-parked-with-no-ceiling`. Hasta ese ticket solo con
/// «Migrar»: en un adopt salir era un callejón —la pantalla solo ofrecía «Migrar», que la puerta de identidad para con esa
/// cuenta, y el texto decía «tus datos siguen en este dispositivo» en un teléfono recién instalado—. Ahora la salida del
/// adopt deja `MigrationState.adoptClaimExitRaw`, Almacenamiento ofrece «Activar la nube en este dispositivo» y el
/// diálogo tiene su propio cuerpo (`AdoptClaimScope`). Desde la identidad en adelante el claim ya contestó `created` —una
/// migración de verdad, venga de donde venga—, y la salida vale igual.
///
/// **Y el seguidor (`waitingForLeader`)** desde `adopt-follower-waits-for-the-leader-with-no-ceiling` (decisión de Jürgen
/// del 2026-09-23): espera a otro dispositivo sin haber tocado nada, y sale como el claim del adopt. Sin él, un «sí» dado
/// con el claim en vuelo se PERDÍA si el claim contestaba `claiming_in_progress`: la fase pasaba a la espera, que no lo
/// ofrecía, y la persona que confirmó cancelar aterrizaba en una tarjeta sin botón.
///
/// **Un solo predicado, y en POSITIVO**: lo consultan el runner —para honrar un «sí» apuntado— y el controller —para
/// pintar el botón—, y escrito dos veces un día discrepan. «¿No es el cutover confirmado?» fallaría abierto con cualquier
/// fase nueva.
nonisolated enum ForwardCancelScope {
    static func offersCancel(_ phase: MigrationPhase) -> Bool {
        switch phase {
        case .uploadingSnapshot, .claimingMigration, .assigningIdentity, .cutover(.pending), .waitingForLeader:
            return true
        default:
            return false
        }
    }

    /// Lo mismo, más el EFECTO del adopt que se reintenta (`AdoptEffectScope`, ticket
    /// `adopt-effect-retries-forever-with-no-ceiling`): su fase es `notStarted`, que no puede entrar en el `switch` de arriba
    /// porque es también la del teléfono que nunca empezó y la del adoptado estable. Es la que consultan el runner y el
    /// controller; la de arriba queda como la parte que decide la FASE.
    static func offersCancel(_ phase: MigrationPhase, adoptEffectPending: Bool) -> Bool {
        offersCancel(phase) || adoptEffectPending
    }
}

/// ¿Se está reintentando el EFECTO del adopt? El par `(notStarted, [.adoptBackendAccount])` que deja un claim que ya
/// contestó `existing_stable` cuando el reconcile de huérfanas no termina (ticket `adopt-effect-retries-forever-with-no-ceiling`).
/// Hasta ese ticket Almacenamiento lo pintaba como `.idle` —como si nunca hubiera empezado— y el runner lo reintentaba para
/// siempre, sin techo ni salida.
///
/// **`persistedCloudMode` es un término, no un detalle**: un kill entre el paso 5 del adopt (`writeCloudArmed`) y el save que
/// retira el pendiente relanza con `.cloud` + el pendiente. Ahí el adopt ya hizo lo irreversible, así que ni se cancela ni
/// sale a `failedRollback` (dejaría `.cloud` en un terminal de fallo): se reintenta como siempre.
nonisolated enum AdoptEffectScope {
    /// `adoptEffectJournaled` = `.adoptBackendAccount` está entre los efectos pendientes del journal.
    static func isPending(_ phase: MigrationPhase, adoptEffectJournaled: Bool, persistedCloudMode: Bool) -> Bool {
        phase == .notStarted && adoptEffectJournaled && !persistedCloudMode
    }
}

/// Por qué no termina el efecto del adopt cuando la causa es de las que esperar NO arregla. El `rawValue` es el detalle del
/// canario (`cloudForwardStepWaiting` con `step=adopt`): WIRE, no se renombra. La red, la quiescencia del import y la
/// sesión borrada en la enumeración no llegan aquí: van al plazo largo.
nonisolated enum AdoptEffectBlocker: String, Equatable, Sendable {
    /// El reconcile no pudo leer o escribir la base LOCAL (`MigrationExecutorError.adoptLocalFailure`).
    case localFailure
    /// Había filas que subir y este dispositivo no tiene ni el marcador de la cuenta ni filas suyas
    /// (`MigrationExecutorError.adoptLineageUnproven`, ticket `adopt-uploads-a-foreign-corpus-without-a-lineage-check`): no
    /// demuestra que su corpus sea el de esa cuenta.
    case lineageUnproven

    /// La clasificación del error del efecto. `nil` = lo que esperar sí puede arreglar (red, quiescencia): plazo largo.
    init?(_ error: Error) {
        switch error as? MigrationExecutorError {
        case .adoptLocalFailure:    self = .localFailure
        case .adoptLineageUnproven: self = .lineageUnproven
        default:                    return nil
        }
    }
}

/// ¿Es ESTE el claim de un adopt? La fase `claimingMigration` con la intención journaleada de entrar en una cuenta que ya
/// existe (`ForwardClaimIntent.adoptIfExisting`, también una fila sin intención). Lo preguntan el runner, que en su salida
/// —techo o «Cancelar»— deja `MigrationState.adoptClaimExitRaw`, y el controller, que elige el cuerpo del diálogo de
/// cancelar y el aviso del 22 % (ticket `adopt-claim-stays-parked-with-no-ceiling`).
///
/// **El seguidor (`waitingForLeader`) entra** desde `adopt-follower-waits-for-the-leader-with-no-ceiling`: también reclama
/// para un adopt y sale igual —techo o «Cancelar»—, así que deja la misma marca y lee el mismo cuerpo y el mismo aviso.
/// Con «Migrar» nunca se llega ahí (`ForwardClaimIntent.refuses` devuelve `claiming_in_progress` al inicio), así que el
/// término de la intención vale para los dos igual.
nonisolated enum AdoptClaimScope {
    static func isAdoptClaim(_ phase: MigrationPhase, claimIntent: ForwardClaimIntent) -> Bool {
        (phase == .claimingMigration || phase == .waitingForLeader) && claimIntent == .adoptIfExisting
    }

    /// El aviso de la tarjeta de progreso mientras el claim de un adopt sigue aparcado. `observedCause` es lo que vio el
    /// ÚLTIMO claim de este proceso (`MigrationRunner.lastClaimDefinitiveCause`), no el reloj de causa journaleado: ese
    /// reloj se PAUSA sin borrar la causa cuando una observación no trae motivo, así que un aviso leído de él seguía
    /// diciendo «tu sesión ya no es válida» con la sesión recuperada y la red caída (lo cazaron dos lentes de la review).
    /// El aviso dice lo que se vio; si la última observación no vio nada definitivo, calla.
    static func notice(
        phase: MigrationPhase, claimIntent: ForwardClaimIntent, observedCause: ForwardStepBlocker?
    ) -> AdoptClaimNotice? {
        guard isAdoptClaim(phase, claimIntent: claimIntent) else { return nil }
        switch observedCause {
        case .sessionExpired:     return .sessionExpired
        case .accountUnavailable: return .accountUnavailable
        case .refused, .otherDevice, .localFailure, .lineageUnproven, .leaderRowsNotArrived, nil:
            // Los cuatro primeros no los produce el claim.
            return nil
        }
    }

    /// ¿Ofrece Almacenamiento «Activar la nube en este dispositivo» por la marca de un adopt que salió? La marca es de
    /// UNA cuenta: la del intento (`MigrationState.adoptClaimAccountHash`). Sin atarla, la tarjeta —que no pasa por la
    /// puerta de identidad de «Migrar»— adoptaba con la sesión que hubiera, también la de OTRA cuenta (la de Grupos), y
    /// le subía lo local (lo cazó la lente de consumidores). Tres casos:
    ///  · sin sesión: sí. Es la salida de la sesión borrada, y la cuenta la comprueba `blocksReentry` después de firmar;
    ///  · con la sesión de esa cuenta: sí;
    ///  · con otra sesión, o sin saber de qué cuenta era el intento: no, y la pantalla vuelve a lo de siempre.
    static func offersReentry(
        exit: AdoptClaimExit?, attemptAccountHash: String?, hasSession: Bool, sessionAccountHash: String?
    ) -> Bool {
        guard exit != nil else { return false }
        guard hasSession else { return true }
        guard let attemptAccountHash else { return false }
        return sessionAccountHash == attemptAccountHash
    }

    /// Tras firmar desde esa tarjeta, ¿la cuenta NO es la del intento? Entonces no se adopta: la persona eligió otra en el
    /// chooser, y adoptarla le subiría lo local (el caso que `offersReentry` no puede ver, porque sin sesión no hay cuenta
    /// que comparar). Sin marca, o sin saber de qué cuenta era el intento, no bloquea: es la tarjeta de siempre. La salida
    /// por linaje (`effectLineageUnproven`) deja la marca SIN cuenta a propósito: ahí la cuenta del intento es la sospechosa,
    /// y lo que protege la subida con cualquier otra es la guarda de linaje del reconcile.
    static func blocksReentry(exit: AdoptClaimExit?, attemptAccountHash: String?, sessionAccountHash: String?) -> Bool {
        guard exit != nil, let attemptAccountHash else { return false }
        return sessionAccountHash != attemptAccountHash
    }
}

/// Qué avisa la tarjeta del 22 % en el claim de un adopt (`AdoptClaimScope.notice`). Solo los dos motivos que el claim
/// produce y que esperar no arregla.
nonisolated enum AdoptClaimNotice: Equatable, Sendable {
    case sessionExpired
    case accountUnavailable
}

/// Cómo salió el claim de un ADOPT (`MigrationState.adoptClaimExitRaw`, ticket `adopt-claim-stays-parked-with-no-ceiling`),
/// o desde `adopt-effect-retries-forever-with-no-ceiling` su EFECTO. El nombre se queda —es WIRE y lo leen la tarjeta y la
/// cuenta atada—: los dos son el mismo adopt que sale de la misma pantalla. El `rawValue` va al journal: no se renombra.
nonisolated enum AdoptClaimExit: String, Equatable, Sendable {
    /// 72 h sin avanzar, con la causa que fuera.
    case stalled
    /// El SDK borró la sesión: 15 min acumulados.
    case sessionExpired
    /// El claim contestó 403: 15 min acumulados.
    case accountUnavailable
    /// La persona tocó «Cancelar la activación». No hay tarjeta de fallo: la fase va a `notStarted`. Vale para el claim y
    /// para el efecto.
    case cancelled
    /// El EFECTO del adopt —el reconcile de huérfanas, tras un claim que ya contestó— lleva 72 h sin terminar, con la causa
    /// que fuera (ticket `adopt-effect-retries-forever-with-no-ceiling`).
    case effectStalled
    /// El efecto del adopt no pudo leer la base local durante 15 min acumulados.
    case effectLocalFailure
    /// El efecto del adopt tenía filas de este dispositivo que subir y no pudo comprobar que vinieran de esa cuenta —no están
    /// ni su marcador ni filas suyas en el store local— durante 15 min acumulados (ticket `adopt-uploads-a-foreign-corpus-without-a-lineage-check`).
    /// No subió nada.
    case effectLineageUnproven

    /// El motivo del techo que venció, en el claim. `refused`, `otherDevice` y `localFailure` no los produce el claim (son
    /// del cutover y de la identidad); si uno llegara, la salida se cuenta como el techo largo, que no acusa a nadie.
    init(_ reason: ForwardStepExitReason) {
        switch reason {
        case .sessionExpired:                           self = .sessionExpired
        case .accountUnavailable:                       self = .accountUnavailable
        case .stalled, .refused, .otherDevice, .localFailure, .lineageUnproven, .leaderRowsNotArrived: self = .stalled
        }
    }
}

/// Por qué no avanza uno de esos tres pasos cuando la causa es de las que esperar NO arregla. El `rawValue` es la clave
/// del reloj de causa (`MigrationState.forwardStepStallCauseRaw`) y el detalle del canario: WIRE, no se renombra.
///
/// **La sesión caducada solo llega aquí con la sesión BORRADA por el SDK** (`canRenewSession == false`, leído después
/// de la llamada), igual que en la subida. Un token que no se renueva sin red, o un 401 del gateway con la sesión
/// todavía guardada —el reloj del teléfono atrasado es el caso principal—, esperan el plazo largo: los cura el SDK.
nonisolated enum ForwardStepBlocker: String, Equatable, Sendable {
    /// El claim o el `cutover` no tienen sesión que usar, y el SDK ya no conserva ninguna que renovar.
    case sessionExpired
    /// El claim devolvió 403. `/account/claim` no lo emite hoy; es defensivo, y reintentar no lo despierta.
    case accountUnavailable
    /// `migration_progress('cutover')` contestó `ok:false` con un motivo que no es `other_leader`: `not_in_progress`,
    /// `no_profile` o `bad_action`. Ninguno se arregla esperando.
    case refused
    /// `migration_progress('cutover')` contestó `other_leader`: otro dispositivo de la cuenta tomó el relevo del lease
    /// (este lleva más de 60 min sin latir). Desde aquí no se vuelve a liderar.
    case otherDevice
    /// `assignIdentity()` lanzó: el `context.save()` de la base local o, desde `an-incomplete-inventory-reads-as-the-whole-corpus`,
    /// una tabla del inventario de la captura que no se deja leer. Las dos son la base local.
    case localFailure
    /// La identidad no pudo probar el LINAJE (ticket `migration-takeover-uploads-without-a-lineage-check`): el claim dio el
    /// turno sobre una cuenta que ya tiene filas personales vivas —el relevo de un líder callado— y ninguna está en este
    /// store (`ForwardLineageOutcome.unproven`). Esperar no cambia de quién es el corpus; los 15 min absorben un import que
    /// llega tarde, que la quiescencia de cada pasada ya espera antes.
    ///
    case lineageUnproven
    /// El linaje SÍ está probado —el mismo iCloud— pero faltan aquí filas que el líder callado ya subió
    /// (`ForwardLineageOutcome.accountRowsMissing`, ticket `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived`):
    /// sus identidades no llegaron por iCloud, y subir las duplicaría. Esperar SÍ puede arreglarlo y cada pasada vuelve a
    /// preguntar; va al techo CORTO igual, porque si a los 15 min no llegaron es que la exportación del líder está parada, y
    /// eso lo arregla la persona (abrir Yala en el otro teléfono), no esta espera. Motivo propio y no `lineageUnproven`: el
    /// texto de ése dice que los datos «no coinciden» y pide revisar la cuenta, y aquí es la misma cuenta y coinciden.
    case leaderRowsNotArrived
}

/// Por qué terminó uno de esos tres pasos al vencer su techo. Lo journalea la salida
/// (`MigrationState.forwardStepExitReasonRaw`) y elige el texto de la tarjeta de fallo: WIRE.
///
/// **Lo elige el techo que VENCIÓ** (`MigrationRunner.forwardStepExitReason`), como en la subida: tras 72 h sin avanzar,
/// una pasada con un motivo recién visto sale con `stalled`. **Una excepción sin techo**: `otherDevice` lo journalea también
/// la salida del lease perdido en la subida o la verificación (`leaveOnLostLease`, ticket
/// `displaced-migration-leader-keeps-uploading-after-a-takeover`).
nonisolated enum ForwardStepExitReason: String, Equatable, Sendable {
    /// Venció el techo LARGO: 72 h en el mismo paso, con la causa que fuera.
    case stalled
    case sessionExpired
    case accountUnavailable
    case refused
    case otherDevice
    case localFailure
    case lineageUnproven
    case leaderRowsNotArrived

    init(_ blocker: ForwardStepBlocker) {
        switch blocker {
        case .sessionExpired:     self = .sessionExpired
        case .accountUnavailable: self = .accountUnavailable
        case .refused:            self = .refused
        case .otherDevice:        self = .otherDevice
        case .localFailure:       self = .localFailure
        case .lineageUnproven:    self = .lineageUnproven
        case .leaderRowsNotArrived: self = .leaderRowsNotArrived
        }
    }
}

/// Resultado de `confirmCutoverServer()` (w6 paso 1). Era un `Bool` hasta el ticket
/// `forward-migration-steps-have-no-ceiling-and-no-exit`, y ese `false` único metía en el mismo saco la red, una sesión
/// borrada y un servidor que dice que no: sin separarlos no había techo corto posible.
nonisolated enum CutoverServerOutcome: Equatable {
    /// El backend estampó `migrated_at` (idempotente).
    case confirmed
    /// Red, 5xx, o un 401/token nulo con la sesión todavía guardada: esperar lo puede arreglar.
    case transient
    case blocked(ForwardStepBlocker)
}

/// ¿Sigue este teléfono liderando la migración? Lo contesta `MigrationWorkExecuting.confirmMigrationLease()` justo antes de
/// cada página de la subida y de cada verificación de la ida (ticket `displaced-migration-leader-keeps-uploading-after-a-takeover`).
/// Hasta ese ticket el líder que perdía el lease por 60 min de silencio volvía y seguía subiendo encima de lo que subía
/// quien tomó el relevo: el latido que recibía `other_leader` solo dejaba rastro.
///
/// **Solo `held` deja subir.** Los otros tres paran la pasada sin mover datos; la puerta falla CERRADA, y vuelve a
/// preguntar en la pasada siguiente.
nonisolated enum MigrationLeaseCheck: Equatable, Sendable {
    /// El servidor confirmó el lease hace menos de una ventana (`heartbeatInterval`, 60 s), o acaba de confirmarlo.
    case held
    /// El servidor dijo que lidera OTRO: `other_leader`, o `not_in_progress` —el RPC mira «¿hay migración en curso?» antes
    /// que «¿quién lidera?», así que es lo que ve este teléfono cuando quien tomó el relevo ya terminó—. Definitivo.
    case lost
    /// No se pudo preguntar, o la respuesta no prueba nada: red, 5xx, un token que no llega con la sesión todavía guardada,
    /// o un rechazo que no habla del líder (`no_profile`, `bad_action`). Esperar puede arreglarlo.
    case unconfirmed
    /// Sin token y el SDK ya no conserva una sesión que renovar: lo mismo que el push llama `sessionExpired`.
    case sessionExpired
}

/// Dónde se vio el lease perdido: el detalle del rastro y del canario de la salida. WIRE, no se renombra.
nonisolated enum MigrationLeaseStep: String, Sendable {
    case upload
    case verify
}

/// El reloj por CAUSA de un techo con dos relojes, PURO. Lo comparten las dos etapas que lo tienen: las cuatro fases
/// previas al montaje de la vuelta (ticket `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`) y la
/// subida del snapshot (`snapshot-upload-has-no-ceiling-and-no-way-out`). Está aquí y no copiado en cada una porque es
/// la parte sutil del mecanismo, y dos copias divergen.
///
/// Tres reglas, y las tres son la decisión de fondo:
///  · **Causa distinta ⇒ empieza de cero.** Lo acumulado bajo un motivo no se le regala a otro, y por eso la clave es el
///    `rawValue` del motivo y no el texto que ve la persona: dos motivos que comparten texto sumarían como uno.
///  · **Misma causa ⇒ suma.** Lo acumulado en tramos cerrados más lo que lleva el tramo abierto.
///  · **Sin motivo ⇒ PAUSA, no borra.** Cierra el tramo y conserva la causa. Es lo que impide que el techo corto se
///    vuelva inalcanzable con cobertura intermitente: la pantalla de Almacenamiento re-kickea cada 30 s, así que con una
///    racha consecutiva bastaba un timeout cada quince minutos para que los 900 s no llegaran nunca. Un hueco no es
///    evidencia de que el motivo se fuera: es que no se pudo ni preguntar.
///
/// Un sello del tramo abierto en el FUTURO —el reloj del teléfono iba adelantado y ya se corrigió— re-abre el tramo
/// AHORA en vez de contar un tramo negativo: conservarlo aplazaría el techo hasta que el reloj real alcanzase aquella
/// fecha.
nonisolated enum CauseStallClock {
    /// Lo que la observación cuenta (`stalled`) y lo que hay que volver a sellar en el journal si la fase holdea.
    struct Reading: Equatable {
        /// Lo acumulado bajo el motivo de ESTA observación. 0 sin motivo: su techo es solo el largo.
        let stalled: Double
        let raw: String?
        let accruedFrom: Date?
        let accrued: Double?
    }

    static func observe(
        sealedRaw: String?,
        sealedOpenSince: Date?,
        sealedAccrued: Double?,
        blockerRaw: String?,
        observedAt: Date
    ) -> Reading {
        let openSince: Date? = sealedOpenSince.flatMap { $0 <= observedAt ? $0 : nil }
        let openTramo = openSince.map { observedAt.timeIntervalSince($0) } ?? 0

        guard let blockerRaw else {
            // SIN motivo: se PAUSA. El tramo abierto se cierra sumándose al acumulado, y la causa se conserva.
            guard sealedRaw != nil else { return Reading(stalled: 0, raw: nil, accruedFrom: nil, accrued: nil) }
            return Reading(stalled: 0, raw: sealedRaw, accruedFrom: nil, accrued: (sealedAccrued ?? 0) + openTramo)
        }
        guard sealedRaw == blockerRaw else {
            // Causa DISTINTA (o la primera): empieza de cero.
            return Reading(stalled: 0, raw: blockerRaw, accruedFrom: observedAt, accrued: 0)
        }
        // MISMA causa: el acumulado más el tramo abierto. Si venía pausada, el tramo se abre ahora.
        let carried = sealedAccrued ?? 0
        return Reading(stalled: carried + openTramo, raw: blockerRaw, accruedFrom: openSince ?? observedAt,
                       accrued: carried)
    }

    /// El reloj de «CUALQUIER motivo definitivo»: el mismo reloj con UNA sola clave para todo lo que esperar no
    /// arregla. Así hereda sus reglas menos una —la del cambio de causa no puede darse—: suma, se PAUSA con una
    /// observación sin motivo y re-ancla un tramo abierto en el futuro. Es el que decide el techo CORTO en las dos
    /// etapas (tickets `alternating-definitive-causes-never-reach-the-short-ceiling` en la vuelta y
    /// `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` en la subida): con el de causa,
    /// dos motivos turnándose lo reiniciaban en cada observación y la salida se iba a las 72 h.
    ///
    /// Está aquí, y no en cada etapa, por la misma razón que `observe`: dos copias divergen.
    ///
    /// No se guarda la clave, porque solo hay una: se le pasa siempre como sellada. Con nada acumulado da lo mismo —la
    /// regla de «misma causa» sobre un reloj vacío devuelve lo que devolvería la de «primera vez»—, así que derivarla de
    /// los campos sería una condición que no cambia ningún resultado.
    ///
    /// `isDefinitive` lo decide cada etapa con SU clasificador: una observación sin motivo, o con un motivo que esperar
    /// sí arreglase, pausa.
    static func observeAnyDefinitive(
        sealedOpenSince: Date?,
        sealedAccrued: Double?,
        isDefinitive: Bool,
        observedAt: Date
    ) -> (stalled: Double, accruedFrom: Date?, accrued: Double?) {
        let key = "definitive"
        let reading = observe(
            sealedRaw: key,
            sealedOpenSince: sealedOpenSince,
            sealedAccrued: sealedAccrued,
            blockerRaw: isDefinitive ? key : nil,
            observedAt: observedAt)
        return (reading.stalled, reading.accruedFrom, reading.accrued)
    }
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
///
/// **«El servidor dijo que no» dejó de describirlos a todos el 2026-09-22**
/// (`verify-reads-a-failed-local-fetch-as-an-empty-outbox`): `reverseDrainOnce` devuelve `.blocked(.localFailure)`
/// cuando el `fetch` del outbox lanza, y ahí no ha hablado nadie. El criterio es el mismo de
/// `ReversePreMountBlocker`: no es quién habló, es que esperar no lo arregla.
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
/// round-trip); `pending(count:)` = `count` filas aún sin metadata/export → retomable; `unreadable` = la muestra no pudo
/// leer una tabla → retomable, sin cifra.
nonisolated enum ReverseUploadStatus: Equatable {
    case drained
    case pending(count: Int)
    /// La muestra no pudo leer una de sus tablas (ticket `an-incomplete-inventory-reads-as-the-whole-corpus`). No es
    /// `.drained` —sus filas pueden ser justo las pendientes— ni una cifra: una muestra parcial cuenta MENOS y el techo
    /// lo leería como avance. El runner sigue esperando: no mueve un reloj ya sellado ni el mínimo (si es la primera
    /// observación del intento, sella el reloj como cualquier otra).
    case unreadable
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
    ///
    /// `marksMigrationAttempt`: si este claim es de «Migrar a la nube» (`ForwardClaimIntent.migrateOnly`), deja ANTES del
    /// POST la marca del claim sin respuesta (`CloudClaimActionStore.recordMigrationClaimAttempt`, ticket
    /// `forward-migration-steps-have-no-ceiling-and-no-exit`). Solo ahí: la marca abre la puerta de «Migrar», y la de un adopt
    /// o un seguidor la abriría a teléfonos que nunca lo pidieron (lo cazaron dos lentes de la review).
    func performClaim(marksMigrationAttempt: Bool) async -> ClaimOutcome
    /// Deshace el sello que `performClaim` dejó en `CloudClaimActionStore` en su última llamada, y repone el que hubiera.
    /// Lo pide el runner cuando `ForwardClaimIntent` devuelve el claim al inicio: el sello de `existing_stable` es
    /// `.routeReturningUser`, el mismo que deja el adopt, y sin adopt afirmaría que esa cuenta entró en este dispositivo; el
    /// de `claiming_in_progress` es `.waitForLeader`, de un seguidor que no llegó a serlo. El Welcome lee el sello para
    /// dejar re-entrar libre a «la misma cuenta» (`CrossAccountEntryGuardLogic`). Default no-op en la extension de abajo.
    func discardLastClaimStamp()
    /// `CloudBeacon.hash` de la cuenta de la sesión viva, o `nil` sin sesión. Lo journalea el runner al ENTRAR en
    /// `claimingMigration` (`MigrationState.adoptClaimAccountHash`): es la cuenta a la que queda atada la marca de un adopt
    /// que sale (ticket `adopt-claim-stays-parked-with-no-ceiling`). Se lee al entrar y no al salir porque la salida más
    /// común de las definitivas es justo la sesión borrada. Default `nil` en la extension de abajo.
    func currentAccountHash() -> String?
    /// ¿Está ya persistido `storageMode == .cloud`? Lo pregunta el runner antes de contar un fallo del adopt para su techo
    /// (ticket `adopt-effect-retries-forever-with-no-ceiling`): un adopt que ya escribió el par `.cloud` —un kill entre el
    /// paso 5 y el borrado del pendiente— no puede salir a `failedRollback`, que dejaría `.cloud` persistido en un terminal
    /// de fallo. Default `false` en la extension de abajo.
    func hasPersistedCloudMode() -> Bool
    /// `has_personal_writes` del último `performClaim` que contestó `created` (g16_03, ticket
    /// `migration-takeover-uploads-without-a-lineage-check`): la cuenta ya recibió datos personales. `nil` = no lo dijo (un
    /// servidor sin g16_03, u otro desenlace). Lo lee `handle` al ENTRAR en `assigningIdentity`, para journalearlo en el
    /// save de esa transición, venga del claim de `driveClaim` o del seguidor. Default `nil` en la extension de abajo.
    func lastClaimReportedPersonalWrites() -> Bool?
    /// ¿Comparte este corpus linaje con lo que la cuenta ya tiene? Lo pregunta la identidad antes de tocar nada cuando el
    /// claim dijo —o no dijo— que la cuenta tenía datos personales. Default `.noLivePersonalRows` en la extension de abajo:
    /// un fake que no lo guiona sigue como antes de este ticket.
    func checkForwardLineage() async -> ForwardLineageOutcome
    /// w3: backfill de `syncID` (gate permanente) + captura `(ckRecordName, ckZoneName)` con el mirror vivo.
    func assignIdentity() async throws
    /// w4: sube el snapshot completo en batches idempotentes. `cursor` = última página confirmada (journal).
    func uploadSnapshot(cursor: String?) async -> SnapshotStepOutcome
    /// w5: cuenta + checksum Merkle local vs backend, confirmado server-side. `underMigrationLease` = la ida: el push y el
    /// pull se cortan si la confirmación del lease que dio la puerta ya no vale (ticket
    /// `displaced-migration-leader-keeps-uploading-after-a-takeover`). La vuelta a iCloud pasa `false`.
    func verify(underMigrationLease: Bool) async -> VerifyProbe
    /// ¿Conserva el SDK una sesión que renovar? `false` solo cuando la BORRÓ. Lo lee el runner DESPUÉS de un claim que
    /// contestó `.sessionExpired` (el SDK borra la sesión antes de lanzar), para separar la sesión caducada de verdad del
    /// token que no llega sin red y del 401 con la sesión guardada (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`).
    func canRenewSession() -> Bool
    /// w6 paso 1: escribe `profiles.migrated_at` y espera el ack síncrono del backend. Clasifica el no: `transient` si
    /// esperar lo puede arreglar, `blocked` si no.
    func confirmCutoverServer() async -> CutoverServerOutcome
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
    /// §h `reverseUpload`: muestreo CKIdentityCapture sobre las filas vivas → `.drained` / `.pending(count)` /
    /// `.unreadable` (una tabla no se dejó leer).
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

    /// La PUERTA del lease de la ida (ticket `displaced-migration-leader-keeps-uploading-after-a-takeover`): ¿sigue este
    /// teléfono liderando? El runner la llama antes de cada página de la subida y de cada verificación, y solo sube con
    /// `.held`. A diferencia de `sendLeaseHeartbeatIfDue`, no es best-effort ni tiene throttle de intentos: sin una
    /// confirmación reciente pregunta en el acto. **Sin default a propósito**: un `.held` heredado sería una puerta que
    /// falla abierta en el conformador que se olvidara de implementarla.
    func confirmMigrationLease() async -> MigrationLeaseCheck

    // MARK: Canal iCloud (C-1)

    /// Veredicto del canal por el que el marcador del cutover tiene que viajar. Read-only y SIN red (cuenta
    /// iCloud + huella CloudKit local + último `CKError` observado). El runner lo consulta en la ENTRADA del
    /// cutover (para no empezar lo que no puede cerrar) y en el paso 4 (para clasificar el atasco y elegir el
    /// presupuesto del tope). Default `.healthy` en la extension de abajo → los fakes que no guionan el canal
    /// se comportan EXACTAMENTE como antes de C-1.
    func probeICloudChannel() async -> ICloudChannelVerdict
}

extension MigrationWorkExecuting {
    /// Defaults del linaje de la ida (ticket `migration-takeover-uploads-without-a-lineage-check`): un conformador que no lo
    /// modela —los fakes de las suites de antes— recorre la identidad como antes del ticket. El ejecutor real los override.
    func lastClaimReportedPersonalWrites() -> Bool? { nil }
    func checkForwardLineage() async -> ForwardLineageOutcome { .noLivePersonalRows }

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

    /// Default: sin sesión que describir, no se sabe de qué cuenta es el intento.
    func currentAccountHash() -> String? { nil }

    /// Default: el modo sigue en iCloud, que es lo que un fake que no lo guiona describe.
    func hasPersistedCloudMode() -> Bool { false }
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

    /// El motivo DEFINITIVO que vio el último claim de la ida en este proceso —la sesión borrada por el SDK, el 403—, con
    /// la misma clasificación que el techo (`observeForwardStepStall`). `nil` tras un claim que contestó, que falló por la
    /// red o por un 401 con la sesión guardada. Lo lee el aviso del 22 % (`AdoptClaimScope.notice`): describe la
    /// OBSERVACIÓN, como `lastClaimBlocker`, y por eso no lo sirve el reloj de causa, que al pausar conserva el motivo
    /// (ticket `adopt-claim-stays-parked-with-no-ceiling`).
    private(set) var lastClaimDefinitiveCause: ForwardStepBlocker?

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

    /// El «sí» de «Cancelar la activación», apuntado por el controller ANTES de esperar a que suelte la pasada en vuelo
    /// (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`, hallazgo de la review). `drive()` lo mira en cada vuelta:
    /// sin él, un re-kick que arrancara con el diálogo abierto y la red de vuelta subía todo, pasaba por la verificación y
    /// el cutover, y el «sí» llegaba tarde — la persona confirmaba cancelar y le salía «cierra y vuelve a abrir».
    ///
    /// **Vale para la pasada, no para una fase** (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`): se honra
    /// en la próxima fase que ofrece cancelar (`ForwardCancelScope`) y `drive()` lo retira en la primera que no. Hasta ese
    /// ticket valía solo para la subida, y con el botón también al 22 % un «sí» dado con el claim en vuelo se perdía al
    /// pasar a la identidad, y la pasada seguía hasta el cutover. La vuelta desde `verifying` a la subida por mismatch
    /// sigue sin cancelarse: la verificación no ofrece el botón, así que el «sí» ya se retiró ahí. `cancelMigration()` lo
    /// consume siempre. En memoria a propósito: tras relanzar, el diálogo ya no existe.
    private var migrationCancelRequested = false

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
            // al que otro dispositivo le quitó la lease lanza mientras el otro lidera (desde
            // `leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile` espera sin subir, y se une o vuelve a
            // liderar cuando el otro termina o lo suelta), y drenarlo aquí bloquearía esta vuelta mientras tanto.
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
            state.clearReverseUploadCeiling()
            state.reverseAbortReasonRaw = nil
            state.clearReversePreMountCeiling()
            state.setReverseOriginPendingEffects([])
            state.forwardClaimIntentRaw = nil
            // El motivo de una subida que venció su techo: «Reintentar» es la salida de `failedRollback`, y el intento
            // nuevo no puede nacer con el texto del anterior. Los relojes ya salieron a `nil` al dejar la fase.
            state.snapshotExitReasonRaw = nil
            // Lo mismo para los tres pasos sin cifra que baje (22 %, 35 %, 80 %).
            state.forwardStepExitReasonRaw = nil
            // El reloj del efecto del adopt ya salió a `nil` en el `handle` de la salida; se borra también aquí porque este
            // save escribe la fase sin pasar por `handle`.
            state.clearAdoptEffectStallCeiling()
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

    /// «Cancelar la activación» desde la tarjeta de progreso de la ida. Nació para la subida del snapshot (ticket
    /// `snapshot-upload-has-no-ceiling-and-no-way-out`) y desde `forward-migration-steps-have-no-ceiling-and-no-exit` vale
    /// también en los tres pasos sin cifra que baje (22 %, 35 %, 80 %) — decisiones de Jürgen del 2026-09-22, las dos.
    /// Vuelve a `notStarted` sin efectos y sin motivo journaleado: lo decidió la persona, así que no hay fallo que explicar.
    ///
    /// Desde `adopt-follower-waits-for-the-leader-with-no-ceiling` también en la espera del seguidor, donde el botón se llama
    /// «Dejar de esperar». No-op fuera de las fases de `ForwardCancelScope` (y del efecto del adopt): un toque que llega tarde —el
    /// paso ya avanzó, o ya salió por su techo— no puede sacar a nadie de un sitio en el que ya no está. Y con una pasada en
    /// vuelo, `runGuarded` lo descarta: el botón solo se puede tocar con la activación aparcada.
    ///
    /// **Lo que sí hace, y conviene saberlo:** el controller lo llama cuando la pasada en vuelo suelta el trabajo, así que
    /// cancela en la fase en la que ESA pasada se aparcó si la ofrece, aunque la pasada hubiera retirado su «sí» por el
    /// camino. Un «sí» dado sobre la subida puede acabar cancelando al 80 %: es lo que la persona pidió, y la fase sigue
    /// siendo una de las que dejan el teléfono intacto (lo midió una lente de la review; el comportamiento viene de #212).
    func cancelMigration() async {
        guard await awaitQuiescence() else {
            // Sin quiescencia el «sí» se queda APUNTADO: lo ejecuta la próxima pasada que llegue a una fase cancelable.
            CloudSyncBreadcrumb.migrationQuiescenceTimeout()
            return
        }
        await runGuarded {
            // Aquí se consume pase lo que pase: la salida ocurre ahora, o el toque llegó tarde y no hay de dónde salir.
            defer { self.migrationCancelRequested = false }
            if try self.normalizeCorruptJournalIfNeeded() { return }
            _ = try await self.journalMigrationCancel()
        }
    }

    /// Apunta el «sí» de «Cancelar la activación» para la pasada que esté en vuelo (`migrationCancelRequested`). Síncrono
    /// a propósito: lo llama el controller antes de su primer `await`, y la pasada lo ve en su próxima vuelta.
    func requestMigrationCancel() {
        migrationCancelRequested = true
    }

    /// Journalea la cancelación con el evento de la fase en la que está, y devuelve si canceló. Retira el «sí» apuntado en
    /// los dos casos: se ejecuta ahora, o la fase ya no lo ofrece. El canario va DENTRO del paso (`mutate` solo corre con
    /// una transición válida): solo se cuenta una salida que ocurrió.
    ///
    /// **El alcance lo decide `ForwardCancelScope`, aquí y solo aquí**: la máquina aceptaría `.forwardStepCancelled` desde
    /// el claim de un adopt, que es justo donde salir es un callejón. Este es el único sitio que journalea la cancelación,
    /// así que el toque del controller y el «sí» que honra `drive()` pasan los dos por la misma pregunta.
    private func journalMigrationCancel() async throws -> Bool {
        migrationCancelRequested = false
        let state = try loadState()
        let phase = state.readPhase().phase
        let claimIntent = state.forwardClaimIntentRaw.flatMap(ForwardClaimIntent.init(rawValue:)) ?? .adoptIfExisting
        let adoptEffectPending = AdoptEffectScope.isPending(
            phase, adoptEffectJournaled: state.readPendingEffects().contains(.adoptBackendAccount),
            persistedCloudMode: executor.hasPersistedCloudMode())
        guard ForwardCancelScope.offersCancel(phase, adoptEffectPending: adoptEffectPending) else { return false }
        if adoptEffectPending {
            // El efecto del adopt que se reintenta (ticket `adopt-effect-retries-forever-with-no-ceiling`): sale sin el
            // pendiente y deja la marca del adopt en el MISMO save, como la cancelación del claim. Sin ella Almacenamiento
            // ofrecería «Migrar», que la puerta de identidad para con esa cuenta.
            try await handle(.adoptEffectCancelled) { state, _ in
                state.adoptClaimExitRaw = AdoptClaimExit.cancelled.rawValue
                self.reportAdoptEffectExit(reason: "cancelled")
            }
            return true
        }
        if phase == .uploadingSnapshot {
            try await handle(.snapshotUploadCancelled) { _, _ in
                CloudSyncBreadcrumb.snapshotUploadExited(reason: "cancelled")
                MetricsService.cloudSnapshotUploadAborted(reason: "cancelled")
            }
            return true
        }
        let step = ForwardStepPhase(phase: phase)
        // La intención se lee ANTES del `handle`: el cierre a `notStarted` la borra en el mismo save.
        let isAdoptClaim = AdoptClaimScope.isAdoptClaim(phase, claimIntent: claimIntent)
        try await handle(.forwardStepCancelled) { state, _ in
            // El adopt cancelado deja su marca en el MISMO save: sin ella, Almacenamiento ofrecería «Migrar», que la
            // puerta de identidad para con esa cuenta (ticket `adopt-claim-stays-parked-with-no-ceiling`).
            if isAdoptClaim { state.adoptClaimExitRaw = AdoptClaimExit.cancelled.rawValue }
            guard let step else { return }
            self.reportForwardStepExit(step, reason: "cancelled")
        }
        return true
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
            // Un claim que EMPIEZA —el toque de la persona, o el seguidor que vuelve a reclamar— retira la marca de un adopt
            // que salió antes: desde aquí manda el desenlace de este intento, que dejará la suya si vuelve a salir. Y apunta
            // la cuenta del intento, a la que quedará atada esa marca (ticket `adopt-claim-stays-parked-with-no-ceiling`).
            // Solo al ENTRAR: en el self-hold del techo la sesión puede estar ya borrada, y re-leerla perdería la cuenta.
            // La pista del LINAJE, en el MISMO save que ENTRA en la identidad (ticket
            // `migration-takeover-uploads-without-a-lineage-check`): tras un relanzamiento el claim no se repite y la identidad
            // solo tiene el journal. Aquí y no en `driveClaim`: a la identidad llegan DOS claims —el de `driveClaim` y el del
            // seguidor que recibe el relevo (`pollLeaderInternal`)—, y el caso del ticket es justo el segundo. Solo se entra en
            // la identidad desde un claim `created` de este proceso, así que la pista del último claim es la suya. Sin pista
            // —un servidor sin g16_03— comprueba: falla cerrado.
            if next == .assigningIdentity, current != .assigningIdentity {
                state.forwardLineageUnverified = executor.lastClaimReportedPersonalWrites() != false
            }
            if next == .claimingMigration, current != .claimingMigration {
                state.adoptClaimExitRaw = nil
                state.adoptClaimAccountHash = executor.currentAccountHash()
                lastClaimDefinitiveCause = nil
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
                state.clearReverseUploadCeiling()
                state.reverseAbortReasonRaw = nil
                // Techo de las fases previas al montaje: lo MISMO, y aquí no es higiene sino corrección. El reloj de
                // esta etapa se compara por FASE, así que un sello de un intento anterior en la misma fase daría un
                // `stalled` de días en la primera observación del intento nuevo: techo instantáneo.
                state.clearReversePreMountCeiling()
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
                state.clearReverseUploadCeiling()
                if next == .icloudActive {
                    state.reverseAbortReasonRaw = nil
                    // La nube se usó y se devolvió a iCloud: la salida de un adopt anterior ya no describe este
                    // teléfono, y ofrecer su tarjeta aquí sería adoptar una cuenta que volvió a iCloud, que es lo que
                    // «Migrar» para en su claim (lo cazó la lente de consumidores).
                    state.adoptClaimExitRaw = nil
                    state.adoptClaimAccountHash = nil
                }
                state.clearReversePreMountCeiling()
                // Los pendientes guardados de una vuelta ya se repusieron arriba si tocaba; en un cierre no queda nada
                // que reponer.
                state.setReverseOriginPendingEffects([])
                // La intención es del intento que se cierra. La pista del linaje, también: la escribe el claim siguiente.
                state.forwardClaimIntentRaw = nil
                state.forwardLineageUnverified = nil
            }
            // Techo de las fases previas al montaje: el reloj se compara por FASE, así que cualquier cambio de fase
            // lo invalida — incluido el RETORNO a una ya visitada, que es el que muerde: `reverseVerify` vuelve a
            // `reverseDrainAll` por mismatch, y sin esto la segunda visita heredaba el sello de la primera y el techo
            // saltaba con cero segundos de parada real. El self-hold no entra (ahí `next == current`), así que el
            // sello que escribe la observación sobrevive.
            if ReversePreMountPhase(phase: next) != ReversePreMountPhase(phase: current) {
                state.clearReversePreMountCeiling()
            }
            // Techo de `uploadingSnapshot`: lo MISMO, al ENTRAR y al SALIR de la fase. Al entrar desde `verifying` por
            // mismatch, la visita nueva no puede heredar el reloj de la anterior; al salir, un reloj que sobreviviera
            // estaría ahí para la próxima. El self-hold no entra, así que lo que sella la observación sobrevive.
            if (next == .uploadingSnapshot) != (current == .uploadingSnapshot) {
                state.clearSnapshotStallCeiling()
            }
            // Techo de los tres pasos sin cifra que baje (22 %, 35 %, 80 %): aquí avanzar ES cambiar de paso, así que
            // cualquier cambio de `ForwardStepPhase` —entrar, salir o pasar de uno a otro, incluido el claim que vuelve
            // desde `waitingForLeader`— borra los dos relojes. No hay campo de paso que compararlos después: esta
            // limpieza es la única que impide que la identidad herede el sello del claim y salga con cero segundos de
            // parada real. El self-hold no entra, así que lo que sella la observación sobrevive.
            if ForwardStepPhase(phase: next) != ForwardStepPhase(phase: current) {
                state.clearForwardStepStallCeiling()
            }
            // Techo del EFECTO del adopt: CUALQUIER transición lo invalida (ticket
            // `adopt-effect-retries-forever-with-no-ceiling`). El efecto solo se espera sin evento —la observación que no
            // vence no pasa por aquí—, así que toda transición es un desenlace o un intento nuevo: el claim que vuelve a
            // emitir `.adoptBackendAccount`, la cancelación, la salida, o un «Migrar» que reemplaza el pendiente. Sin esto el
            // adopt siguiente heredaría el sello y saldría con cero segundos de parada real.
            state.clearAdoptEffectStallCeiling()
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
            // Un «Cancelar» apuntado con el efecto del adopt pendiente se honra ANTES de intentarlo otra vez (hallazgo de la
            // review de `adopt-effect-retries-forever-with-no-ceiling`): mirándolo solo al fallar, un intento que saliera
            // bien adoptaba a quien acababa de confirmar que cancelaba. Un intento que ya está dentro del efecto no se para:
            // eso lo recoge el `catch` de abajo si falla.
            if effect == .adoptBackendAccount, migrationCancelRequested, try await journalMigrationCancel() { return }
            do {
                try await executor.execute(effect)
            } catch {
                CloudSyncBreadcrumb.migrationEffectFailed(effect: effect.rawValue, reason: "\(error)")
                // El efecto del adopt tiene techo y salida (ticket `adopt-effect-retries-forever-with-no-ceiling`): si la
                // observación sale —por el techo o por un «Cancelar» apuntado—, la pasada termina sin parada retomable.
                if effect == .adoptBackendAccount, try await observeAdoptEffectFailure(error) { return }
                throw Stop.effectFailed
            }
            removeFirstPending(state)
            // El adopt terminó: su reloj se va en el MISMO save que retira el efecto, para que un kill no deje un sello
            // huérfano que el adopt siguiente heredaría.
            if effect == .adoptBackendAccount { state.clearAdoptEffectStallCeiling() }
            try context.save()
        }
    }

    /// Un intento fallido del EFECTO del adopt (`.adoptBackendAccount` pendiente en `notStarted`). Decide si sigue esperando
    /// —el efecto se queda pendiente y el próximo `resume()` lo reintenta, como siempre— o sale a `failedRollback` con la
    /// marca del adopt (ticket `adopt-effect-retries-forever-with-no-ceiling`, decisiones de Jürgen del 2026-09-23: 15 min
    /// acumulados con la base local que no se deja leer, 72 h con cualquier causa, la misma salida que el claim del adopt).
    ///
    /// **Molde de `observeForwardStepStall`, con dos diferencias.** Una: la espera NO pasa por `handle` —una transición que
    /// repusiera el pendiente lo ejecutaría otra vez dentro del mismo `handle`—, así que la observación bajo presupuesto
    /// sella el reloj con su propio save, y solo la salida es un evento. Dos: el corto usa el reloj de «cualquier motivo
    /// definitivo» (`CauseStallClock.observeAnyDefinitive`) y no el de causa, porque hoy hay un solo motivo y un reloj que
    /// ya suma entre motivos no hace falta rehacerlo el día que haya dos. La red lo PAUSA, no lo borra: el re-kick de
    /// Almacenamiento llega cada 30 s.
    ///
    /// Antes de contar, dos salidas que no son el techo: el «sí» de «Cancelar» apuntado por la pasada en vuelo, y el modo ya
    /// persistido a `.cloud` —un kill tras el paso 5—, que no puede salir a un terminal de fallo y se reintenta como antes.
    ///
    /// Devuelve `true` si la pasada terminó (canceló o salió).
    private func observeAdoptEffectFailure(_ error: Error) async throws -> Bool {
        if migrationCancelRequested, try await journalMigrationCancel() { return true }
        guard !executor.hasPersistedCloudMode() else { return false }
        let blocker = AdoptEffectBlocker(error)
        let state = try loadState()
        let observedAt = now()
        let lastProgressAt: Date
        if let sealed = state.adoptEffectStallProgressAt, sealed <= observedAt {
            lastProgressAt = sealed
        } else {
            lastProgressAt = observedAt                      // sin sello, o con un sello en el FUTURO
        }
        let stalled = observedAt.timeIntervalSince(lastProgressAt)
        let clock = CauseStallClock.observeAnyDefinitive(
            sealedOpenSince: state.adoptEffectStallDefinitiveAt,
            sealedAccrued: state.adoptEffectStallDefinitiveAccruedSeconds,
            isDefinitive: blocker != nil,
            observedAt: observedAt)
        // El rastro y el canario de los pasos de la ida, con `step=adopt`: la misma serie en el dashboard, en CADA
        // observación, para ver un fallo sistémico antes de que ningún teléfono agote su plazo.
        CloudSyncBreadcrumb.forwardStepStalled(
            step: Self.adoptEffectStep, stalledSeconds: stalled, causeStalledSeconds: clock.stalled,
            blocker: blocker?.rawValue)
        MetricsService.cloudForwardStepWaiting(
            step: Self.adoptEffectStep, stalledSeconds: stalled, causeStalledSeconds: clock.stalled,
            blocker: blocker?.rawValue)
        guard policy.adoptEffectCeilingReached(stalledSeconds: stalled, definitiveStalledSeconds: clock.stalled) else {
            // Bajo presupuesto: se sella y se sigue esperando. Los dos del reloj definitivo se escriben SIEMPRE, también a
            // `nil`: una observación sin motivo CIERRA el tramo abierto, y dejar la fecha puesta contaría el hueco.
            state.adoptEffectStallProgressAt = lastProgressAt
            state.adoptEffectStallDefinitiveAt = clock.accruedFrom
            state.adoptEffectStallDefinitiveAccruedSeconds = clock.accrued
            state.updatedAt = observedAt
            try context.save()
            return false
        }
        // Lo elige el techo que VENCIÓ: el corto solo puede vencer en una observación con el motivo (sin él el reloj
        // definitivo devuelve 0), así que tras 72 h de red un fallo local recién visto no se lleva el texto de «este
        // dispositivo no pudo leer tus datos». Y con el corto, el motivo de ESTA observación, que es la que lo venció: el
        // reloj suma las dos causas definitivas juntas (ticket `adopt-uploads-a-foreign-corpus-without-a-lineage-check`).
        let exit: AdoptClaimExit
        if policy.adoptEffectDefinitiveCeilingReached(clock.stalled), let blocker {
            switch blocker {
            case .localFailure:    exit = .effectLocalFailure
            case .lineageUnproven: exit = .effectLineageUnproven
            }
        } else {
            exit = .effectStalled
        }
        try await handle(.adoptEffectStalled(stalledSeconds: stalled, definitiveStalledSeconds: clock.stalled)) { state, _ in
            state.adoptClaimExitRaw = exit.rawValue
            // Por linaje, la marca NO queda atada a la cuenta del intento (hallazgo de la review): aquí la cuenta es la
            // sospechosa —la persona pudo elegir otra en el chooser—, y atarla bloqueaba justo el arreglo, entrar con la
            // buena (`AdoptClaimScope.blocksReentry`). Sin atadura la tarjeta vuelve sin sesión y deja elegir cuenta; lo que
            // protege la subida con cualquiera es la propia guarda de linaje.
            if exit == .effectLineageUnproven { state.adoptClaimAccountHash = nil }
            // Se cuenta AQUÍ, en el save que journalea la salida: lo que venga después puede no llegar a correr.
            self.reportAdoptEffectExit(reason: exit.rawValue)
        }
        return true
    }

    /// El `step` del rastro y del canario de los pasos de la ida para el efecto del adopt. WIRE: no se renombra.
    static let adoptEffectStep = "adopt"

    /// El rastro y el canario de una salida del efecto del adopt: por su techo o porque la persona canceló.
    private func reportAdoptEffectExit(reason: String) {
        CloudSyncBreadcrumb.forwardStepExited(step: Self.adoptEffectStep, reason: reason)
        MetricsService.cloudForwardStepAborted(step: Self.adoptEffectStep, reason: reason)
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
            // El «sí» de «Cancelar la activación» vale para ESTA pasada: se honra en la primera fase que ofrece el botón y
            // se retira en la primera que no, que ya no puede cancelar (la verificación, el cutover confirmado) ni la
            // próxima visita a una que sí (p. ej. la vuelta a la subida desde `verifying` por mismatch). Lo retira
            // `journalMigrationCancel` en los dos casos; aquí solo se corta si canceló.
            if migrationCancelRequested, try await journalMigrationCancel() {
                return                               // notStarted: nada más que conducir
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
                if !(try await driveIdentity()) { return }
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
    /// Los tres no-éxitos pasan por el TECHO del paso (`observeForwardStepStall`, ticket
    /// `forward-migration-steps-have-no-ceiling-and-no-exit`): hasta ese ticket cortaban sin evento y la barra se quedaba al
    /// 22 % para siempre. **Con las DOS intenciones** desde `adopt-claim-stays-parked-with-no-ceiling`: hasta ese ticket el
    /// adopt conservaba su espera sin techo, porque su salida era un callejón (la pantalla solo ofrecía «Migrar», que la
    /// puerta de identidad para con esa cuenta). Ahora la salida del adopt deja `MigrationState.adoptClaimExitRaw` y la
    /// pantalla ofrece volver a entrar en la cuenta. `lastClaimBlocker` no cambia: sigue describiendo el intento para la
    /// pantalla del Welcome.
    ///
    /// Devuelve `false` para cortar el bucle (no-success bajo presupuesto), `true` si avanzó o salió.
    private func driveClaim() async throws -> Bool {
        let state = try loadState()
        if state.leaderDeviceID != deviceID {
            state.leaderDeviceID = deviceID
            state.updatedAt = now()
            try context.save()
        }
        // La intención JOURNALEADA, no la de memoria: tras un relanzamiento es lo único que queda del intento.
        let intent = state.forwardClaimIntentRaw.flatMap(ForwardClaimIntent.init(rawValue:)) ?? .adoptIfExisting
        switch await executor.performClaim(marksMigrationAttempt: intent == .migrateOnly) {
        case let .success(claimState):
            lastClaimBlocker = nil
            lastClaimDefinitiveCause = nil
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
            // Dos productores con el mismo nombre: el token que no llega (sin red, o el SDK sin sesión) y el 401 de
            // `/account/claim`, que no exige App Attest y por eso solo habla del JWT. Definitivo solo con la sesión BORRADA
            // por el SDK, leído DESPUÉS del claim; con la sesión guardada espera el plazo largo, como en la subida.
            let blocker: ForwardStepBlocker? = executor.canRenewSession() ? nil : .sessionExpired
            lastClaimDefinitiveCause = blocker
            return try await observeForwardStepStall(.claim, blocker: blocker)
        case .accountUnavailable:
            lastClaimBlocker = .accountUnavailable
            CloudSyncBreadcrumb.migrationAccountUnavailable()
            lastClaimDefinitiveCause = .accountUnavailable
            return try await observeForwardStepStall(.claim, blocker: .accountUnavailable)
        case .transient:
            // La red SÍ se reintenta: no es un bloqueo de cuenta y no debe apagar la barra de progreso.
            lastClaimBlocker = nil
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "transient")
            lastClaimDefinitiveCause = nil
            return try await observeForwardStepStall(.claim, blocker: nil)
        }
    }

    /// `assigningIdentity`. Los `throw` de `assignIdentity()` son de la base local —el `context.save()` o, desde
    /// `an-incomplete-inventory-reads-as-the-whole-corpus`, un fetch del inventario de la captura—, y esperar no lo arregla: elige el techo CORTO (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`; hasta ese
    /// ticket el `catch` hacía `return` y la barra se quedaba al 35 % para siempre). Devuelve `false` para cortar.
    private func driveIdentity() async throws -> Bool {
        // El LINAJE, antes de tocar nada (ticket `migration-takeover-uploads-without-a-lineage-check`). El claim dio el turno
        // sobre una cuenta que ya recibió datos personales —o no dijo lo contrario—: el caso es el relevo de un líder callado,
        // que hasta este ticket subía su corpus encima de lo que el otro alcanzó a subir. `nil` también comprueba (una fila
        // anterior a la v16). Probado, se journalea `false` y la pasada siguiente no vuelve a enumerar.
        let state = try loadState()
        if state.forwardLineageUnverified != false {
            switch await executor.checkForwardLineage() {
            case .proven, .noLivePersonalRows:
                state.forwardLineageUnverified = false
                state.updatedAt = now()
                try context.save()
            case .unproven:
                return try await observeForwardStepStall(.identity, blocker: .lineageUnproven)
            // Ticket `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived`: el mismo iCloud, pero las
            // identidades del líder aún no llegaron y subir duplicaría su libro. Mientras el techo no vence, cada pasada vuelve
            // a preguntar, así que si iCloud las trae, sigue.
            case .accountRowsMissing:
                return try await observeForwardStepStall(.identity, blocker: .leaderRowsNotArrived)
            case .localFailure:
                return try await observeForwardStepStall(.identity, blocker: .localFailure)
            case .transient:
                return try await observeForwardStepStall(.identity, blocker: nil)
            }
        }
        do {
            try await executor.assignIdentity()
        } catch {
            #if DEBUG
            print("MigrationRunner: assignIdentity falló (retomable): \(error)")
            #endif
            return try await observeForwardStepStall(.identity, blocker: .localFailure)
        }
        try await handle(.identityAssigned)
        return true
    }

    /// Una observación de uno de los TRES pasos sin cifra que baje —claim, identidad, `cutover(.pending)`— en una pasada
    /// que no avanzó, o de la espera del seguidor (`waitingForLeader`, ticket
    /// `adopt-follower-waits-for-the-leader-with-no-ceiling`), cuyo avance re-sella `noteLeaderAlive`. Decide si el paso sigue esperando o sale a `failedRollback` (ticket
    /// `forward-migration-steps-have-no-ceiling-and-no-exit`, decisiones de Jürgen del 2026-09-22: 15 min / 72 h por paso).
    ///
    /// **Molde de `observeSnapshotStall`, con una diferencia: aquí avanzar es cambiar de paso.** No hay página que re-selle
    /// el reloj, así que la primera observación de un paso lo SELLA y el siguiente paso empieza sin él (`handle` borra los
    /// dos relojes en cada cambio de `ForwardStepPhase`). El de AVANCE gobierna las 72 h con cualquier causa; el de CAUSA
    /// (`CauseStallClock`) los 15 min, solo con un motivo que esperar no arregla. Un sello en el FUTURO es un reloj que iba
    /// adelantado y ya se corrigió: se re-sella ahora.
    ///
    /// Devuelve `true` si el paso SALIÓ, para que `drive()` relea la fase y corte en el terminal.
    private func observeForwardStepStall(_ step: ForwardStepPhase, blocker: ForwardStepBlocker?) async throws -> Bool {
        let state = try loadState()
        let observedAt = now()
        let lastProgressAt: Date
        if let sealed = state.forwardStepStallProgressAt, sealed <= observedAt {
            lastProgressAt = sealed
        } else {
            lastProgressAt = observedAt                      // sin sello, o con un sello en el FUTURO
        }
        let stalled = observedAt.timeIntervalSince(lastProgressAt)
        let cause: MarkerExportStall = blocker == nil ? .unknown : .definitive
        let clock = CauseStallClock.observe(
            sealedRaw: state.forwardStepStallCauseRaw,
            sealedOpenSince: state.forwardStepStallCauseAt,
            sealedAccrued: state.forwardStepStallCauseAccruedSeconds,
            blockerRaw: blocker?.rawValue,
            observedAt: observedAt)
        CloudSyncBreadcrumb.forwardStepStalled(
            step: step.rawValue, stalledSeconds: stalled, causeStalledSeconds: clock.stalled, blocker: blocker?.rawValue)
        // En CADA observación, no solo al salir: un fallo sistémico —un gateway que rechaza el claim en toda la flota— se
        // ve así mucho antes de que ningún teléfono agote sus 15 min o sus 72 h.
        MetricsService.cloudForwardStepWaiting(
            step: step.rawValue, stalledSeconds: stalled, causeStalledSeconds: clock.stalled,
            blocker: blocker?.rawValue)
        let reason = forwardStepExitReason(blocker: blocker, causeStalledSeconds: clock.stalled, cause: cause)
        let current = state.readPhase().phase
        // La intención se lee ANTES del `handle`: el cierre a `failedRollback` la borra en el mismo save.
        let isAdoptClaim = AdoptClaimScope.isAdoptClaim(
            current, claimIntent: state.forwardClaimIntentRaw.flatMap(ForwardClaimIntent.init(rawValue:)) ?? .adoptIfExisting)
        var left = false
        try await handle(.forwardStepStalled(
            stalledSeconds: stalled, causeStalledSeconds: clock.stalled, cause: cause)) { state, next in
            guard next != current else {
                state.forwardStepStallProgressAt = lastProgressAt
                // Los tres del reloj de causa se escriben SIEMPRE, también a `nil`: una observación sin motivo CIERRA el
                // tramo abierto, y dejar la fecha puesta contaría el hueco como parada por una causa no observada.
                state.forwardStepStallCauseRaw = clock.raw
                state.forwardStepStallCauseAt = clock.accruedFrom
                state.forwardStepStallCauseAccruedSeconds = clock.accrued
                return
            }
            left = true
            state.forwardStepExitReasonRaw = reason.rawValue
            // El adopt que se rinde deja su marca en el MISMO save (ticket `adopt-claim-stays-parked-with-no-ceiling`):
            // elige el texto de la tarjeta y hace que «Reintentar» lleve a «Activar la nube en este dispositivo».
            if isAdoptClaim { state.adoptClaimExitRaw = AdoptClaimExit(reason).rawValue }
            // Se cuenta AQUÍ, en el save que journalea la salida: lo que venga después puede no llegar a correr.
            self.reportForwardStepExit(step, reason: reason.rawValue)
        }
        return left
    }

    /// El motivo que se journalea al salir de uno de los tres pasos, y **lo elige el techo que VENCIÓ**, no la última
    /// observación (la regla de `snapshotExitReason` y de `reversePreMountExitReason`): tras 72 h en el claim sin red, un
    /// 403 recién visto no puede decirle a la persona que su cuenta no lo permitió.
    private func forwardStepExitReason(
        blocker: ForwardStepBlocker?, causeStalledSeconds: Double, cause: MarkerExportStall
    ) -> ForwardStepExitReason {
        guard let blocker, policy.forwardStepCauseCeilingReached(
            causeStalledSeconds: causeStalledSeconds, cause: cause) else {
            return .stalled
        }
        return ForwardStepExitReason(blocker)
    }

    /// El rastro y el canario de una salida de los tres pasos: por su techo (`reason` = `ForwardStepExitReason.rawValue`) o
    /// porque la persona canceló (`cancelled`).
    private func reportForwardStepExit(_ step: ForwardStepPhase, reason: String) {
        CloudSyncBreadcrumb.forwardStepExited(step: step.rawValue, reason: reason)
        MetricsService.cloudForwardStepAborted(step: step.rawValue, reason: reason)
    }

    /// `uploadingSnapshot`. `pageConfirmed` journalea el cursor (no cambia de fase, re-loop); `completed`
    /// avanza; `transient` y `blocked` pasan por el TECHO de la fase y cortan retomables mientras no venza (ticket
    /// `snapshot-upload-has-no-ceiling-and-no-way-out`: hasta ese ticket cortaban sin evento y la fase no salía nunca).
    private func driveUpload() async throws -> Bool {
        // La PUERTA del lease, antes de CADA página y no solo de cada pasada (ticket
        // `displaced-migration-leader-keeps-uploading-after-a-takeover`): una pasada suspendida más de 60 min se reanuda a
        // mitad, y la página siguiente saldría sin que nadie volviera a preguntar. Lo que no es `held` no sube.
        switch await executor.confirmMigrationLease() {
        case .held:
            break
        case .lost:
            return try await leaveOnLostLease(step: .upload)
        case .unconfirmed:
            return try await observeSnapshotStall(blocker: nil)
        case .sessionExpired:
            return try await observeSnapshotStall(blocker: .sessionExpired)
        }
        let cursor = try loadState().snapshotCursorJSON
        switch await executor.uploadSnapshot(cursor: cursor) {
        case .completed:
            try await handle(.snapshotUploaded)
            return true
        case let .pageConfirmed(newCursor):
            let state = try loadState()
            state.snapshotCursorJSON = newCursor
            // AVANCE: la página subió, así que los dos relojes del techo vuelven a empezar. El de causa también: una
            // página confirmada prueba que la sesión, la cuenta y la lectura local funcionaron. En el MISMO save que el
            // cursor, para que un kill no deje el cursor avanzado con el reloj viejo.
            state.clearSnapshotStallCeiling()
            state.snapshotStallProgressAt = now()
            state.updatedAt = now()
            try context.save()
            // Aquí latía `sendLeaseHeartbeatIfDue` (I14-pre) para que un corpus 10k+ no dejara caducar el lease. Lo hace
            // ahora la puerta de arriba (≤ 1 por minuto) y leyendo la respuesta. Late también en las pasadas que NO
            // confirman página, así que el lease dice «el líder está vivo», no «el líder avanza» (regla del área).
            return true                       // re-loop: sigue subiendo desde el cursor confirmado
        case .transient:
            // Sin retry-loop de red aquí: bajo presupuesto se corta y el reintento llega por el próximo resume. Si el
            // techo venció, `true` hace que `drive()` relea la fase y salga por el terminal.
            return try await observeSnapshotStall(blocker: nil)
        case let .blocked(blocker):
            return try await observeSnapshotStall(blocker: blocker)
        }
    }

    /// La salida del líder DESPLAZADO (ticket `displaced-migration-leader-keeps-uploading-after-a-takeover`): el latido
    /// dijo que lidera otro. Sale en el acto a `failedRollback` y apunta `otherDevice`, el motivo que el `cutover` ya
    /// journaleaba para la misma respuesta, así que la tarjeta dice «otro dispositivo con tu cuenta tomó el relevo». Rastro y
    /// canario en el MISMO save, como las otras salidas. Devuelve `true` para que `drive()` relea la fase y salga por el
    /// terminal: la máquina solo acepta el evento en las dos fases que llaman aquí.
    private func leaveOnLostLease(step: MigrationLeaseStep) async throws -> Bool {
        try await handle(.migrationLeaseLost) { state, next in
            guard next == .failedRollback else { return }
            state.forwardStepExitReasonRaw = ForwardStepExitReason.otherDevice.rawValue
            CloudSyncBreadcrumb.migrationLeaseLost(step: step.rawValue)
            MetricsService.cloudForwardStepAborted(step: step.rawValue, reason: ForwardStepExitReason.otherDevice.rawValue)
        }
        return true
    }

    /// Una observación de `uploadingSnapshot` en una pasada que no confirmó ninguna página. Decide si la subida sigue
    /// esperando o sale a `failedRollback` (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`).
    ///
    /// **Tres relojes, molde de `observeReversePreMountStall`.** El de AVANCE mide desde la última página confirmada
    /// (`snapshotStallProgressAt`) y gobierna las 72 h con cualquier causa. El de «CUALQUIER motivo DEFINITIVO» mide lo
    /// acumulado bajo motivos que esperar no arregla desde el último avance, sean el mismo o se turnen
    /// (`CauseStallClock.observeAnyDefinitive`), y gobierna los 15 min. El de CAUSA mide lo acumulado bajo UN motivo
    /// (`CauseStallClock.observe`) y solo elige el copy de la salida (`snapshotExitReason`). Con uno solo de avance, un
    /// fallo local aislado tras horas sin red se cobraría las horas contra sus 15 min; los dos acumulados lo evitan
    /// porque la red no trae motivo y los PAUSA.
    ///
    /// **Hasta `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` los 15 min los medía el de
    /// CAUSA**, y dos motivos turnándose lo reiniciaban en cada observación: los productores de `localFailure`
    /// (`nextPage`, el encolado, el drenaje, el `fetch` del outbox) saltan ANTES del push y `accountUnavailable` sale DEL
    /// push, así que una pasada falla al leer y la siguiente lee bien y recibe el 409. Con el re-kick de 30 s el reloj de
    /// causa no pasaba de cero y la salida se iba a las 72 h. Lo que suma el reloj nuevo entre motivos es a propósito:
    /// los dos eran esperas que esperar no arregla — incluido un hueco SIN observaciones entre dos motivos distintos, la
    /// misma regla que el de causa ya aplicaba a uno solo.
    ///
    /// La primera observación de una visita a la fase SELLA el reloj de avance sin contarla como parada, y nunca lo sella
    /// hacia atrás: un sello en el FUTURO es un reloj que iba adelantado y ya se corrigió, y conservarlo aplazaría el
    /// techo. Devuelve `true` si la subida SALIÓ.
    private func observeSnapshotStall(blocker: SnapshotStallBlocker?) async throws -> Bool {
        let state = try loadState()
        let observedAt = now()
        let lastProgressAt: Date
        if let sealed = state.snapshotStallProgressAt, sealed <= observedAt {
            lastProgressAt = sealed
        } else {
            lastProgressAt = observedAt                      // sin sello, o con un sello en el FUTURO
        }
        let stalled = observedAt.timeIntervalSince(lastProgressAt)
        let cause: MarkerExportStall = blocker == nil ? .unknown : .definitive
        let clock = CauseStallClock.observe(
            sealedRaw: state.snapshotStallCauseRaw,
            sealedOpenSince: state.snapshotStallCauseAt,
            sealedAccrued: state.snapshotStallCauseAccruedSeconds,
            blockerRaw: blocker?.rawValue,
            observedAt: observedAt)
        // El filtro es el MISMO `cause` que recibe la máquina, no «hay blocker» escrito otra vez: hoy coinciden (los tres
        // `SnapshotStallBlocker` son definitivos), y derivarlos de la misma variable impide que diverjan el día que no.
        let definitive = CauseStallClock.observeAnyDefinitive(
            sealedOpenSince: state.snapshotStallDefinitiveAt,
            sealedAccrued: state.snapshotStallDefinitiveAccruedSeconds,
            isDefinitive: cause == .definitive,
            observedAt: observedAt)
        CloudSyncBreadcrumb.snapshotUploadStalled(
            stalledSeconds: stalled, causeStalledSeconds: clock.stalled,
            definitiveStalledSeconds: definitive.stalled, blocker: blocker?.rawValue)
        // En CADA observación, no solo al salir: un fallo sistémico —un 403 en toda la flota, un build que rompe el
        // push— se ve así mucho antes de que ningún teléfono agote sus 15 min o sus 72 h. Sigue publicando el tramo de
        // CAUSA aunque los 15 min ya no corran contra él, a propósito y como en la vuelta: es el que deja reconocer la
        // alternancia en la flota (avance creciendo, causa siempre en el tramo bajo).
        MetricsService.cloudSnapshotUploadWaiting(
            stalledSeconds: stalled, causeStalledSeconds: clock.stalled, blocker: blocker?.rawValue)
        let reason = snapshotExitReason(
            blocker: blocker, causeStalledSeconds: clock.stalled, progressStalledSeconds: stalled, cause: cause)
        var left = false
        try await handle(.snapshotUploadStalled(
            stalledSeconds: stalled, definitiveStalledSeconds: definitive.stalled, cause: cause)) { state, next in
            guard next != .uploadingSnapshot else {
                state.snapshotStallProgressAt = lastProgressAt
                // Los tres del reloj de causa se escriben SIEMPRE, también a `nil`: una observación sin motivo CIERRA
                // el tramo abierto, y dejar la fecha puesta contaría el hueco como parada por una causa no observada.
                state.snapshotStallCauseRaw = clock.raw
                state.snapshotStallCauseAt = clock.accruedFrom
                state.snapshotStallCauseAccruedSeconds = clock.accrued
                // Los dos del reloj de lo definitivo, igual: SIEMPRE, también a `nil`, por la misma razón.
                state.snapshotStallDefinitiveAt = definitive.accruedFrom
                state.snapshotStallDefinitiveAccruedSeconds = definitive.accrued
                return
            }
            left = true
            state.snapshotExitReasonRaw = reason.rawValue
            // Se cuenta AQUÍ, en el save que journalea la salida: lo que venga después puede no llegar a correr.
            CloudSyncBreadcrumb.snapshotUploadExited(reason: reason.rawValue)
            MetricsService.cloudSnapshotUploadAborted(reason: reason.rawValue)
        }
        return left
    }

    /// El motivo que se journalea al salir de la subida, y **lo elige el techo que VENCIÓ**, no la última observación
    /// (la misma regla que `reversePreMountExitReason`). Tras 72 h sin avanzar, una pasada que traiga un 403 recién
    /// visto sale con «dejó de avanzar»: decirle «tu cuenta no lo permitió» a quien llevaba tres días sin red la
    /// mandaría a soporte por nada. Si el 403 es real, el reintento sale a los 15 min con el motivo bueno.
    ///
    /// **Se mide contra el reloj de la CAUSA, no contra el de «cualquier motivo definitivo» que saca de la subida**
    /// (ticket `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`), la regla de la vuelta:
    /// si el corto venció con motivos mezclados —diez minutos de 409 y cinco de un store que falla—, ninguno de los
    /// textos específicos es verdad entero, y sale `mixedCauses`. **No `stalled`**, que era el primer diseño y lo cazaron
    /// dos lentes de la review: su texto dice «lleva días sin avanzar», y esta salida llega a los 15 min. Así que, si
    /// ningún motivo llegó solo, el techo que venció decide entre los dos genéricos: las 72 h de avance dan `stalled`, y
    /// si no fueron ellas, lo que sacó de la subida fue el corto —la máquina no sale por otra cosa—. El específico sale cuando UN motivo solo
    /// agotó el plazo, y entonces los dos relojes vencen en la misma observación: abren tramo con la misma observación
    /// y solo el de causa se reinicia al cambiar de motivo. **Con una excepción, y de una vez**: una fila de un build
    /// anterior a la v13 parada a mitad de la subida trae el de causa acumulado y el definitivo a `nil`; la salida
    /// llega hasta un plazo corto después, con el texto específico, que entonces es verdad.
    ///
    /// Se calcula en cada observación y solo se journalea si la máquina saca de la fase; por eso la última rama no mira
    /// el reloj de lo definitivo: en una pasada que HOLDEA el valor se tira.
    private func snapshotExitReason(
        blocker: SnapshotStallBlocker?, causeStalledSeconds: Double, progressStalledSeconds: Double,
        cause: MarkerExportStall
    ) -> SnapshotExitReason {
        if let blocker, policy.snapshotCauseCeilingReached(stalledSeconds: causeStalledSeconds, cause: cause) {
            return SnapshotExitReason(blocker)
        }
        return progressStalledSeconds >= policy.snapshotProgressBudgetSeconds ? .stalled : .mixedCauses
    }

    /// `verifying` (S9). Inyecta el `retriesSoFar` desde el journal; incrementa el contador correcto en el
    /// MISMO `save()` que journalea la transición, y SOLO cuando la transición realmente reintenta.
    /// Devuelve `false` para CORTAR el bucle retomable: tras un `networkTimeout` que reintenta, drive()
    /// NO re-verifica inmediatamente — un tight-loop quemaría el presupuesto global de 8 retries en
    /// segundos ante un túnel/ascensor (S9: "no pude verificar por red" es un fallo LENTO, el retry
    /// llega por el próximo resume()/submit externo, que da el pacing natural). `newDeltaDetected` SÍ
    /// re-verifica inmediato (hay trabajo real que empujar; acotado por actividad del usuario).
    private func driveVerify() async throws -> Bool {
        // La misma PUERTA que la subida: `verify()` empuja el outbox y trae el corpus de la cuenta, así que el líder
        // desplazado que vuelve con el journal aquí subiría y mezclaría igual. Sin lease confirmado no se llama; la red y la
        // sesión siguen el trato que `verify()` les daría a las suyas.
        let probe: VerifyProbe
        switch await executor.confirmMigrationLease() {
        case .held:
            probe = await executor.verify(underMigrationLease: true)
        case .lost:
            return try await leaveOnLostLease(step: .verify)
        case .unconfirmed:
            probe = .networkTimeout
        case .sessionExpired:
            probe = .sessionExpired
        }
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
        //
        // El 2026-09-22 empezaron a llegar por esta misma rama TRES desenlaces más, los del Merkle: su 401, su 403 y
        // los dos `blocked` nuevos (`localFailure`, `unknownVerdict`) del ticket
        // `reverse-verify-network-bucket-hides-a-definitive-server-no`. **En la ida tampoco cambian nada**, y por eso
        // ese ticket no toca esta función: los cinco ya caían aquí cuando `SyncMerkle` los aplanaba en
        // `.networkTimeout`. Lo fija `MigrationRunnerTests.forwardVerify_typedMerkleOutcomes_stillSpendTheNetworkBudget`.
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
            // El no del servidor pasa por el TECHO del paso (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`:
            // hasta ese ticket era un `Bool` y su `false` cortaba sin evento, con la barra al 80 % para siempre). La
            // puerta de arriba va primero en cada pasada, así que su salida y la del techo no se pisan.
            switch await executor.confirmCutoverServer() {
            case .confirmed:
                try await handle(.serverConfirmedAck)
                return true
            case .transient:
                return try await observeForwardStepStall(.cutoverPending, blocker: nil)
            case let .blocked(blocker):
                return try await observeForwardStepStall(.cutoverPending, blocker: blocker)
            }
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
        switch await executor.verify(underMigrationLease: false) {
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
            // Esperar no lo cambia, así que NO gasta `verifyNetworkRetries` —el camino que lo gastaba acababa en
            // `reverseFailedRollback` con el abort pendiente— y va derecho al techo CORTO de la etapa.
            //
            // **Nació siendo solo el 403 y desde el 2026-09-22 son tres** (ticket
            // `reverse-verify-network-bucket-hides-a-definitive-server-no`): el 403 del servidor, el `fetch` de la
            // base LOCAL que lanzó y el veredicto con un motivo que este build no sabe leer. Lo que los junta no es
            // quién habló —dos de los tres no son una respuesta de nadie— sino que ninguno mejora esperando tres
            // días. `blocker.stallCause` lo dice caso por caso.
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
            // **Y desde el 2026-09-22 `.networkTimeout` ES solo «no hay red»**, que es lo que hace legítimo mandarlo
            // aquí. Entre el 21 y el 22 fue un cajón —deuda que este `case` expuso—: `SyncMerkle` aplanaba el 401 y el
            // 403 de `/sync/merkle` en un `fetch-failed`, y con ellos caían aquí los `fetch` de SwiftData que
            // lanzan y el `default` de un `reason` desconocido; para esa mitad el techo largo era generoso —no se
            // resuelve sola en 72 h— y la persona esperaba tres días delante de un «no» definitivo. Lo cerró
            // `reverse-verify-network-bucket-hides-a-definitive-server-no`: el Merkle propaga tipado y esos cuatro
            // salen por `.sessionExpired` y por `.blocked`, arriba. Lo que queda aquí es el transporte caído, el
            // `non-http`, un 5xx, un 200 indecodificable y el `no-completed-pull`.
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

    /// `reverseUpload`. `drained` → cierra a `icloudActive` (con el cuarteto de efectos); `unreadable` → observa la espera
    /// sin cifra ni avance; `pending(count)` →
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
        case .unreadable:
            // Ni se cierra ni se cuenta: una muestra que no leyó una tabla cuenta menos pendientes, y como cifra valía
            // un avance falso que reiniciaba el reloj del techo (ticket `an-incomplete-inventory-reads-as-the-whole-corpus`).
            // Se sigue esperando con el reloj que había; si la avería persiste, el techo saca la vuelta al origen en modo
            // nube, con los datos a salvo en el backend. El rastro, con la tabla, ya lo dejó el executor.
            await executor.sendLeaseHeartbeatIfDue()
            return try await observeReverseUploadWait(pending: nil)
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
    ///
    /// `count == nil` es una muestra ILEGIBLE (`ReverseUploadStatus.unreadable`): nunca avanza, no toca la cifra más
    /// baja y la pantalla conserva la última observación buena.
    ///
    /// **Tres relojes, molde de `observeReversePreMountStall` y `observeSnapshotStall`** (ticket
    /// `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`). El de AVANCE —el de arriba— gobierna las 72 h
    /// con cualquier motivo. El de «CUALQUIER motivo DEFINITIVO» acumula desde el último avance lo que la espera lleva
    /// bajo `icloudFull` o `icloudUnusable`, sean el mismo o se turnen, y gobierna los 15 min. El de CAUSA acumula bajo
    /// UN motivo y solo elige el texto de la salida (`reverseUploadExitReason`). Con uno solo de avance —lo que había—,
    /// tres horas sin cuenta de iCloud y el `notAuthenticated` de una pasada que CloudKit suelta justo al entrar sacaban
    /// de la vuelta en ese mismo instante: se cobraban las tres horas contra los 15 min del motivo de la última pasada.
    ///
    /// **`icloudOff` y `unknown` PAUSAN los dos acumulados**, no los borran: son la «red» de esta espera —esperar sí
    /// puede arreglarlas— y un hueco así no prueba que el motivo definitivo se fuera. El filtro es `stallCause`, el mismo
    /// que elige el presupuesto, para que los dos no diverjan el día que entre un motivo nuevo.
    ///
    /// **Un AVANCE reinicia los dos acumulados**: la cifra bajó, así que algo subió, y lo acumulado antes describía una
    /// espera que ya no es la de ahora. La misma observación abre el tramo nuevo desde cero si trae motivo definitivo.
    private func observeReverseUploadWait(pending count: Int?) async throws -> Bool {
        let blocker = executor.reverseUploadBlocker()
        if let count {
            lastReverseUploadSample = ReverseUploadSample(pending: count, blocker: blocker)
        } else if let last = lastReverseUploadSample {
            // Sin cifra nueva, la pantalla conserva la última buena; el motivo sí es el de AHORA (lente de la review:
            // congelado, seguía diciendo «iCloud lleno» después de liberar espacio).
            lastReverseUploadSample = ReverseUploadSample(pending: last.pending, blocker: blocker)
        }
        let state = try loadState()
        let observedAt = now()
        let lowest = state.reverseUploadLowestPending
        let advanced: Bool
        if let count, let lowest {
            advanced = count < lowest
        } else {
            advanced = false
        }
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
        let cause = blocker.stallCause
        // Solo un motivo DEFINITIVO entra en los dos acumulados; el resto pausa. Derivado del MISMO `cause` que recibe la
        // máquina, no de una lista de casos escrita otra vez aquí.
        let definitiveRaw: String? = cause == .definitive ? blocker.rawValue : nil
        // Tras un AVANCE los dos acumulados empiezan de cero: se leen como si el journal no trajera nada.
        let clock = CauseStallClock.observe(
            sealedRaw: advanced ? nil : state.reverseUploadCauseRaw,
            sealedOpenSince: advanced ? nil : state.reverseUploadCauseAt,
            sealedAccrued: advanced ? nil : state.reverseUploadCauseAccruedSeconds,
            blockerRaw: definitiveRaw,
            observedAt: observedAt)
        let definitive = CauseStallClock.observeAnyDefinitive(
            sealedOpenSince: advanced ? nil : state.reverseUploadDefinitiveAt,
            sealedAccrued: advanced ? nil : state.reverseUploadDefinitiveAccruedSeconds,
            isDefinitive: cause == .definitive,
            observedAt: observedAt)
        CloudSyncBreadcrumb.reverseUploadObserved(
            pending: count ?? -1, stalledSeconds: stalled, causeStalledSeconds: clock.stalled,
            definitiveStalledSeconds: definitive.stalled, advanced: advanced, blocker: blocker.rawValue)
        // El canario se emite en CADA observación (dedupe por proceso dentro del helper): un atasco SISTÉMICO —un
        // mirror que no exporta para nadie— se ve en la flota mucho antes de que ningún teléfono agote el techo. Publica
        // el tramo de CAUSA aunque los 15 min ya no corran contra él, como la vuelta previa al montaje y la subida: es el
        // que deja reconocer en la flota un motivo recién visto tras horas de espera por otra cosa.
        MetricsService.cloudReverseUploadWaiting(
            advancing: advanced, stalledSeconds: stalled,
            causeStalledSeconds: definitiveRaw == nil ? nil : clock.stalled, blocker: blocker.rawValue)
        let origin = try originFromJournal()
        let exitReason = reverseUploadExitReason(blocker: blocker, causeStalledSeconds: clock.stalled)
        return try await journalReverseUploadStep(
            .reverseUploadStalled(stalledSeconds: stalled, definitiveStalledSeconds: definitive.stalled,
                                  cause: cause, returnTo: origin),
            exitReason: exitReason,
            exitDetail: Self.reverseUploadExitDetail(
                reason: exitReason, progressStalledSeconds: stalled, policy: policy),
            hold: ReverseUploadHold(
                lowest: count.map { min(lowest ?? $0, $0) } ?? lowest, progressAt: lastProgressAt,
                causeRaw: clock.raw, causeAccruedFrom: clock.accruedFrom, causeAccrued: clock.accrued,
                definitiveAccruedFrom: definitive.accruedFrom, definitiveAccrued: definitive.accrued))
    }

    /// Lo que se re-sella en el journal cuando una observación de la espera HOLDEA: la cifra más baja y el reloj de
    /// avance, los tres del reloj de causa y los dos del de «cualquier motivo definitivo». Struct y no tupla por lo mismo
    /// que `ReversePreMountHold`: son siete y seis opcionales.
    private struct ReverseUploadHold {
        let lowest: Int?
        let progressAt: Date
        let causeRaw: String?
        let causeAccruedFrom: Date?
        let causeAccrued: Double?
        let definitiveAccruedFrom: Date?
        let definitiveAccrued: Double?
    }

    /// El motivo que se journalea si la espera sale, y **lo elige el techo que VENCIÓ, no la última observación**
    /// (la regla de `reversePreMountExitReason` y `snapshotExitReason`).
    ///
    /// El específico —`icloudFull`, `icloudUnavailable`— solo sale cuando UN motivo agotó SOLO el plazo corto, medido
    /// contra su reloj de CAUSA. Si no, `stalled`, en los dos casos que quedan: las 72 h de avance vencidas en una pasada
    /// que casualmente trae un motivo recién visto —decirle «iCloud está lleno» a quien llevaba tres días sin red sería
    /// contarle una causa que no terminó nada—, y el corto vencido con los dos motivos turnándose, donde ninguno de los
    /// dos textos es verdad entero. **`stalled` vale para los dos sin texto nuevo**, y está medido: dice «iCloud no
    /// recibió todos tus datos» y pide revisar iCloud y la conexión, sin afirmar días ni motivo (a diferencia del
    /// `stalled` de la subida del snapshot, que dice «días» y por eso allí hizo falta `mixedCauses`).
    ///
    /// Si el motivo es real no se pierde nada: la persona lo reintenta y, sostenido 15 min, sale con su texto.
    ///
    /// Se calcula en cada observación y solo se journalea si la máquina saca de la espera.
    private func reverseUploadExitReason(
        blocker: ReverseUploadBlocker, causeStalledSeconds: Double
    ) -> ReverseAbortReason {
        guard policy.reverseUploadDefinitiveCeilingReached(
            stalledSeconds: causeStalledSeconds, cause: blocker.stallCause) else {
            return .stalled
        }
        return blocker.abortReason
    }

    /// El detalle del rastro y del canario de una salida de la espera, que NO siempre es el motivo journaleado (lente de
    /// telemetría de la review de `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`). Desde ese ticket
    /// `stalled` cubre dos salidas distintas: las 72 h sin avanzar y los 15 min con motivos definitivos turnándose. A la
    /// persona le vale el mismo texto para las dos, y por eso se journalea uno solo; a la flota no, porque un pico de
    /// `stalled` tiene que decir si es un mirror que no exporta en días o dos motivos que se turnan. La segunda sale
    /// como `mixedCauses`, el nombre que la subida del snapshot ya usa para lo mismo.
    ///
    /// Se distingue por el reloj de avance: con `stalled` y sin haber llegado a las 72 h, lo único que puede haber sacado
    /// de la espera es el corto, y si el motivo journaleado no es el específico es que ninguno lo agotó solo.
    nonisolated static func reverseUploadExitDetail(
        reason: ReverseAbortReason, progressStalledSeconds: Double, policy: MigrationPolicy
    ) -> String {
        guard reason == .stalled, progressStalledSeconds < policy.reverseUploadProgressBudgetSeconds else {
            return reason.rawValue
        }
        return "mixedCauses"
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
        exitDetail: String? = nil,
        hold: ReverseUploadHold?
    ) async throws -> Bool {
        var leftTheWait = false
        try await handle(event) { state, next in
            guard next != .reverseUpload else {
                if let hold {
                    state.reverseUploadLowestPending = hold.lowest
                    state.reverseUploadProgressAt = hold.progressAt
                    // Los cinco de los dos acumulados se escriben SIEMPRE, también a `nil`: una observación sin motivo
                    // definitivo CIERRA el tramo abierto, y dejar la fecha puesta contaría el hueco como espera bajo un
                    // motivo que en ese rato nadie observó.
                    state.reverseUploadCauseRaw = hold.causeRaw
                    state.reverseUploadCauseAt = hold.causeAccruedFrom
                    state.reverseUploadCauseAccruedSeconds = hold.causeAccrued
                    state.reverseUploadDefinitiveAt = hold.definitiveAccruedFrom
                    state.reverseUploadDefinitiveAccruedSeconds = hold.definitiveAccrued
                }
                return
            }
            leftTheWait = true
            state.reverseAbortReasonRaw = exitReason.rawValue
            state.clearReverseUploadCeiling()
            state.reverseOriginRaw = nil
            // Se cuenta AQUÍ, en el paso que journalea la salida y antes de drenar sus efectos: la tarjeta de relanzar
            // aparece en cuanto `.rearmMirrorOff` arma el par, `reverse_abort` puede tardar, y quien obedece y cierra
            // Yala mataría el proceso antes de contarla.
            self.reportReverseUploadExit(detail: exitDetail ?? exitReason.rawValue)
        }
        return leftTheWait
    }

    private func reportReverseUploadExit(detail: String) {
        lastReverseUploadSample = nil
        CloudSyncBreadcrumb.reverseUploadExited(reason: detail)
        MetricsService.cloudReverseUploadAborted(reason: detail)
    }

    // MARK: - Techo y salida de las CUATRO fases previas al montaje
    // (ticket `reverse-before-mount-has-no-way-to-abandon-the-return`)

    /// Lo que se re-sella en el journal cuando una observación HOLDEA: el reloj de fase con su sello, los tres
    /// campos del reloj por causa y los dos del de «cualquier motivo definitivo». Struct y no tupla porque son siete
    /// y cinco opcionales — una tupla así se lee al revés con una facilidad que no compensa lo que ahorra.
    private struct ReversePreMountHold {
        /// La fase en la que se sella el reloj de fase.
        let phase: ReversePreMountPhase
        /// El instante del último avance (= del último cambio de fase).
        let progressAt: Date
        /// La causa que se está midiendo. **Sobrevive a una observación SIN motivo**: el reloj se pausa, no se
        /// borra. Solo lo cambia una causa distinta.
        let causeRaw: String?
        /// Desde cuándo corre el tramo ABIERTO de esa causa. `nil` = tramo cerrado (la observación no traía
        /// motivo), con la causa todavía puesta.
        let causeAccruedFrom: Date?
        /// Lo que esa causa lleva acumulado en tramos ya CERRADOS.
        let causeAccrued: Double?
        /// El tramo ABIERTO del reloj de «cualquier motivo definitivo». Mismas reglas que el de causa, salvo que un
        /// cambio de motivo no lo reinicia.
        let definitiveAccruedFrom: Date?
        /// Lo que ese reloj lleva acumulado en tramos CERRADOS.
        let definitiveAccrued: Double?
    }

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
    /// `blocker` es lo que paró el paso cuando no fue la red ni la sesión —y solo entonces entra en juego el
    /// presupuesto CORTO—. Sin él (red, sesión caducada) solo queda el largo: la red vuelve sola y la sesión la
    /// renueva la persona, que además tiene su aviso y su botón mucho antes de que esto venza.
    ///
    /// **Hasta el 2026-09-22 la frase decía «la palabra del servidor», y desde ese día es falsa**: dos de los cinco
    /// motivos de `ReversePreMountBlocker` no son una respuesta de nadie. Al añadir uno, el criterio es «¿esperar lo
    /// arregla?», no «¿contestó el servidor?».
    ///
    /// **Son DOS relojes y no uno** (ticket `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`).
    /// El de FASE mide lo que lleva parada la fase, venga de donde venga, y es el del techo largo. El de CAUSA mide
    /// lo que lleva parada bajo la causa de ESTA observación, y es el del corto. Juntarlos —que es lo que había
    /// hasta este ticket— hacía que un `fetch` local que falla UNA vez tras tres horas sin cobertura cobrase las
    /// tres horas contra sus 15 minutos: la vuelta se abandonaba en ese mismo instante, sin un solo reintento.
    ///
    /// El reloj de causa es un ACUMULADO con pausa (`CauseStallClock`): lo reinicia un cambio de causa, y una
    /// observación SIN causa (la red llega así) lo pausa en vez de borrarlo. Esta frase decía «racha» hasta el
    /// 2026-09-22, que es lo que se descartó en la review de #210.
    ///
    /// **Y hay un TERCER reloj, y es el que decide el techo corto** (ticket
    /// `alternating-definitive-causes-never-reach-the-short-ceiling`): el de «cualquier motivo definitivo», el mismo
    /// `CauseStallClock` con una clave única para todo lo definitivo. Con el de causa, dos motivos turnándose —una
    /// cuenta suspendida y un store que falla a ratos, que desde `verify-reads-a-failed-local-fetch-as-an-empty-outbox`
    /// es alcanzable en el drenaje— reiniciaban el corto en cada observación, y la persona esperaba 72 h en vez de
    /// 15 min. Éste suma entre motivos, y **conserva el criterio del de causa por la pausa**: la red no trae motivo,
    /// así que las horas de red no las acumula ninguno de los dos, y un `localFailure` aislado tras ellas empieza en
    /// cero igual que antes. Lo que SÍ cuenta es el tiempo bajo otro motivo definitivo, y es a propósito: los dos
    /// eran esperas que esperar no arregla. El de causa se queda para elegir el copy de la salida
    /// (`reversePreMountExitReason`).
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
        let clock = reversePreMountCauseClock(state, blocker: blocker, observedAt: observedAt)
        let definitive = reversePreMountDefinitiveClock(state, blocker: blocker, observedAt: observedAt)
        CloudSyncBreadcrumb.reversePreMountStalled(
            phase: phase.rawValue, stalledSeconds: stalled,
            causeStalledSeconds: clock.stalled, definitiveStalledSeconds: definitive.stalled,
            blocker: blocker?.rawValue)
        // En CADA observación, no solo al salir: es lo que deja ver un atasco sistémico —un 403 en toda la flota—
        // antes de que ningún teléfono agote sus 15 min o sus 72 h. Es la regla de la familia
        // (`.claude/rules/swiftdata-cloudkit.md`, el canario del marcador) y esta etapa era la única sin cumplirla.
        MetricsService.cloudReversePreMountWaiting(
            phase: phase.rawValue, stalledSeconds: stalled,
            causeStalledSeconds: clock.stalled, blocker: blocker?.rawValue)
        let origin = try originFromJournal()
        return try await leaveReversePreMount(
            .reversePreMountStalled(stalledSeconds: stalled, definitiveStalledSeconds: definitive.stalled,
                                    cause: cause, returnTo: origin),
            phase: phase,
            exitReason: reversePreMountExitReason(
                blocker: blocker, causeStalledSeconds: clock.stalled, cause: cause),
            hold: ReversePreMountHold(
                phase: phase, progressAt: lastProgressAt,
                causeRaw: clock.raw, causeAccruedFrom: clock.accruedFrom, causeAccrued: clock.accrued,
                definitiveAccruedFrom: definitive.accruedFrom, definitiveAccrued: definitive.accrued))
    }

    /// El reloj por CAUSA, leído del journal y devuelto con lo que hay que volver a sellar
    /// (ticket `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`). Las reglas viven en
    /// `CauseStallClock`, que comparte con el techo de la subida del snapshot.
    private func reversePreMountCauseClock(
        _ state: MigrationState,
        blocker: ReversePreMountBlocker?,
        observedAt: Date
    ) -> (stalled: Double, raw: String?, accruedFrom: Date?, accrued: Double?) {
        let reading = CauseStallClock.observe(
            sealedRaw: state.reversePreMountCauseRaw,
            sealedOpenSince: state.reversePreMountCauseAt,
            sealedAccrued: state.reversePreMountCauseAccruedSeconds,
            blockerRaw: blocker?.rawValue,
            observedAt: observedAt)
        return (reading.stalled, reading.raw, reading.accruedFrom, reading.accrued)
    }

    /// El reloj de «CUALQUIER motivo definitivo» (ticket `alternating-definitive-causes-never-reach-the-short-ceiling`),
    /// leído del journal. Las reglas viven en `CauseStallClock.observeAnyDefinitive`, que comparte con la subida del
    /// snapshot.
    ///
    /// El filtro es por `stallCause` y no por «hay blocker»: hoy los cinco motivos son definitivos y da lo mismo, pero
    /// un motivo nuevo que esperar SÍ arreglase no debe sumar aquí, y ese `switch` exhaustivo es donde el compilador
    /// obliga a decidirlo.
    private func reversePreMountDefinitiveClock(
        _ state: MigrationState,
        blocker: ReversePreMountBlocker?,
        observedAt: Date
    ) -> (stalled: Double, accruedFrom: Date?, accrued: Double?) {
        CauseStallClock.observeAnyDefinitive(
            sealedOpenSince: state.reversePreMountDefinitiveAt,
            sealedAccrued: state.reversePreMountDefinitiveAccruedSeconds,
            isDefinitive: blocker?.stallCause == .definitive,
            observedAt: observedAt)
    }

    /// El motivo que se journalea al salir, y **lo elige el techo que VENCIÓ, no la última observación**.
    ///
    /// Con el reloj por causa la vuelta puede salir por el techo de la FASE —72 h sin cobertura— en una pasada que
    /// casualmente traiga un motivo recién visto. Journalear el motivo de ese blocker le contaría a la persona una
    /// causa que no terminó nada: con `accountUnavailable` o `refused` el copy dice «tu cuenta en la nube no lo
    /// permitió» y da el correo de soporte, así que tres días sin red acabarían mandando a soporte a quien no
    /// tiene nada que consultar. Es el mismo criterio que `ReversePreMountBlocker.abortReason` ya aplica al
    /// elegir el copy, un paso más arriba.
    ///
    /// Si el 403 es real, no se pierde nada: la vuelta sale con `preMountStalled` («no llegó a completarse»), la
    /// persona lo reintenta, y a los 15 min de 403 sostenido sale con `preMountRefused` y su correo, que entonces
    /// sí es verdad.
    ///
    /// **Se mide contra el reloj de la CAUSA, no contra el de «cualquier motivo definitivo» que saca de la vuelta**
    /// (ticket `alternating-definitive-causes-never-reach-the-short-ceiling`), y es la misma regla aplicada a un reloj
    /// más: si el corto venció con motivos mezclados —diez minutos de 403 y cinco de un store que falla—, ninguno de
    /// los dos textos específicos es verdad entero, y el genérico sí. El texto específico sale cuando UN motivo solo
    /// agotó el plazo, y entonces los dos relojes vencen en la misma observación: el definitivo no va por detrás del de
    /// causa, porque abren tramo con la misma observación y solo el de causa se reinicia al cambiar de motivo. **Con
    /// una excepción, y de una vez**: una fila de un build anterior a la v12 parada a mitad de fase trae el de causa
    /// acumulado y el definitivo a `nil`. Ahí el de causa llega antes, la máquina todavía no sale (la decide el
    /// definitivo), y la salida llega hasta un plazo corto después, con el texto específico, que entonces es verdad.
    ///
    /// **Límite aceptado**: la clave del de causa es el `rawValue`, no el texto, así que `accountUnavailable` y
    /// `refused` turnándose salen con el genérico aunque los dos digan lo mismo. No miente, solo es menos concreto, y
    /// cambiar la clave le cambiaría el significado al tramo que publica el canario.
    private func reversePreMountExitReason(
        blocker: ReversePreMountBlocker?,
        causeStalledSeconds: Double,
        cause: MarkerExportStall
    ) -> ReverseAbortReason {
        guard let blocker, policy.reversePreMountCauseCeilingReached(
            stalledSeconds: causeStalledSeconds, cause: cause) else {
            return .preMountStalled
        }
        return blocker.abortReason
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
        hold: ReversePreMountHold?
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
        hold: ReversePreMountHold?
    ) async throws -> Bool {
        var leftTheStage = false
        try await handle(event) { state, next in
            guard ReversePreMountPhase(phase: next) == nil else {
                if let hold {
                    state.reversePreMountPhaseRaw = hold.phase.rawValue
                    state.reversePreMountProgressAt = hold.progressAt
                    // Los tres del reloj de causa se escriben SIEMPRE, también cuando vienen a `nil`: una
                    // observación sin motivo CIERRA el tramo abierto, y dejar la fecha puesta haría que el hueco
                    // contase como tiempo parado por una causa que en ese rato nadie observó.
                    state.reversePreMountCauseRaw = hold.causeRaw
                    state.reversePreMountCauseAt = hold.causeAccruedFrom
                    state.reversePreMountCauseAccruedSeconds = hold.causeAccrued
                    // Los dos del reloj de lo definitivo, igual: SIEMPRE, también a `nil`, por la misma razón.
                    state.reversePreMountDefinitiveAt = hold.definitiveAccruedFrom
                    state.reversePreMountDefinitiveAccruedSeconds = hold.definitiveAccrued
                }
                return
            }
            leftTheStage = true
            state.reverseAbortReasonRaw = exitReason.rawValue
            state.clearReversePreMountCeiling()
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

    /// `CloudMigrationMarker.serverSeqCut` del marcador del CUTOVER. Lectura pura; `nil` si no hay marcador o el fetch
    /// falla. Un marcador RELEVADO (`isRelay`, ticket `markerless-adopt-stays-blocked-while-another-device-writes-to-the-account`)
    /// no cuenta: lleva corte 0 porque el adoptador no sabe el del líder, y con un `fetchLimit = 1` sin orden tapaba el bueno
    /// y mandaba barrer desde 0 (correcto, pero todo el corpus y con el rastro de avería del fallback).
    private func markerSeqCut() -> Int64? {
        do {
            return try context.fetch(FetchDescriptor<CloudMigrationMarker>()).first { !$0.isRelay }?.serverSeqCut
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
        state.clearReverseUploadCeiling()
        state.reverseAbortReasonRaw = nil
        state.clearReversePreMountCeiling()
        state.clearSnapshotStallCeiling()
        state.snapshotExitReasonRaw = nil
        state.clearForwardStepStallCeiling()
        state.forwardStepExitReasonRaw = nil
        state.clearAdoptEffectStallCeiling()
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

    /// El poll del seguidor. **Tiene techo y «Cancelar» desde `adopt-follower-waits-for-the-leader-with-no-ceiling`**
    /// (decisiones de Jürgen del 2026-09-23): hasta ese ticket la sesión borrada, el 403 y la red solo apuntaban
    /// `lastClaimBlocker` y devolvían sin evento, y el teléfono se quedaba en «esperando a otro dispositivo» para siempre.
    /// Ahora los tres no-éxitos pasan por el techo de los pasos (`observeForwardStepStall`) con la misma clasificación que
    /// `driveClaim`, y `claiming_in_progress` —el líder sigue vivo— re-sella los relojes: es el avance de esta fase.
    private func pollLeaderInternal() async throws {
        guard try loadState().readPhase().phase == .waitingForLeader else { return }
        // Un «sí» apuntado se honra ANTES de volver a reclamar, como hace `drive()` en cada vuelta: la pasada que lo vio
        // llegar pudo acabar sin evento (el líder seguía trabajando), y reclamar otra vez podría adoptar a quien ya dijo que
        // cancelaba.
        if migrationCancelRequested, try await journalMigrationCancel() { return }
        // El seguidor es el de un adopt (ver `ForwardClaimIntent`): su claim no es de «Migrar» y no deja marca.
        switch await executor.performClaim(marksMigrationAttempt: false) {
        case .success(.existingStable):
            lastClaimBlocker = nil
            lastClaimDefinitiveCause = nil
            try await handle(.leaderCompleted)             // → notStarted + adoptBackendAccount
        case .success(.claimingInProgress):
            lastClaimBlocker = nil
            lastClaimDefinitiveCause = nil
            // Sigue esperando, sin evento. Pero es AVANCE: el líder tiene el lease vivo, y la sesión y la cuenta de este
            // teléfono acaban de funcionar. Los dos relojes se borran aquí, en su propio save.
            try noteLeaderAlive()
            // Un «sí» que llegó con este claim en vuelo se honra ya, sin esperar al próximo poll.
            if migrationCancelRequested { _ = try await journalMigrationCancel() }
            return
        case .success(.created):
            lastClaimBlocker = nil
            lastClaimDefinitiveCause = nil
            // Un «sí» que llegó con este claim en vuelo se honra AQUÍ, desde la espera y con la marca del adopt: traducido
            // primero, el relevo escribía el faro y `drive()` cancelaba ya en la identidad, sin marca, y Almacenamiento
            // ofrecía «Migrar» a quien confirmó dejar de esperar (lo cazaron dos lentes de la review). El lease que el
            // servidor acaba de dar caduca solo a los 60 min.
            if migrationCancelRequested, try await journalMigrationCancel() { return }
            // El líder se esfumó → re-claim. TRADUCIR a leaderVanished y REUSAR el resultado ya obtenido
            // (sin 2º POST). `sameDeviceReclaim: false` — ver doc de `driveClaim` (para `.created` la
            // máquina lo ignora de todas formas).
            try await handle(.leaderVanished)              // → claimingMigration
            try await handle(.claimResult(.created, sameDeviceReclaim: false))
        case .sessionExpired:
            lastClaimBlocker = .sessionExpired
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "sessionExpired")
            // La misma clasificación que `driveClaim`: definitivo solo con la sesión BORRADA por el SDK, leída DESPUÉS del
            // claim. Con la sesión guardada espera el plazo largo.
            let blocker: ForwardStepBlocker? = executor.canRenewSession() ? nil : .sessionExpired
            lastClaimDefinitiveCause = blocker
            _ = try await observeForwardStepStall(.waitingForLeader, blocker: blocker)
            return
        case .accountUnavailable:
            lastClaimBlocker = .accountUnavailable
            CloudSyncBreadcrumb.migrationAccountUnavailable()
            lastClaimDefinitiveCause = .accountUnavailable
            _ = try await observeForwardStepStall(.waitingForLeader, blocker: .accountUnavailable)
            return
        case .transient:
            lastClaimBlocker = nil
            CloudSyncBreadcrumb.migrationClaimNoSuccess(reason: "transient")
            lastClaimDefinitiveCause = nil
            _ = try await observeForwardStepStall(.waitingForLeader, blocker: nil)
            return                                         // red del poll: techo largo, reintento posterior
        }
        try await drive()
    }

    /// El avance del seguidor: el servidor volvió a contestar `claiming_in_progress`. Borra los dos relojes —una respuesta
    /// del claim prueba que el líder vive y que la sesión y la cuenta funcionaron—, en un save propio, porque la fase no
    /// cambia y `handle` no pasa por aquí. No los re-sella: los sella la próxima observación que no avance, como en los otros
    /// tres pasos. Sellarlos aquí contaba como espera los días con Yala cerrada tras una respuesta buena, y el primer poll
    /// sin red al volver sacaba de la espera con «lleva días sin avanzar» a un seguidor cuyo líder ya había terminado.
    private func noteLeaderAlive() throws {
        let state = try loadState()
        state.clearForwardStepStallCeiling()
        state.updatedAt = now()
        try context.save()
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
