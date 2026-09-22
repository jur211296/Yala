//
//  ICloudCutoverGateLogic.swift
//  Yala
//
//  Veredicto PURO del canal iCloud para el cutover de migración (§g.4, bug C-1).
//
//  Por qué existe: el `CloudMigrationMarker` solo puede llegar a CloudKit por el mirror VIVO del store
//  personal. El paso 4 del cutover NO apaga el mirror hasta que el marcador exportó
//  (`MigrationWorkExecutor.isMarkerExported()`), y ese gate es correcto — apagarlo antes perdería el
//  marcador para siempre. Pero si el canal NO EXISTE (sin cuenta iCloud) o CloudKit ya dictó que el write
//  no entra (`CKError.quotaExceeded`), el gate NUNCA se satisface: `storageMode` queda en `.cloud` con
//  `mirrorOffArmed == false` ⇒ `personalStoreDecision` monta el mirror EN MODO NUBE = doble escritura
//  indefinida. Determinista, no accidente.
//
//  NECESARIO-NO-SUFICIENTE por construcción: iOS NO expone la cuota de iCloud (no hay API de espacio
//  disponible; la única señal real de "lleno" es el `CKError` post-hoc). Esto es una MUESTRA que evita
//  entrar al cutover cuando ya se sabe que no puede cerrar; la autoridad final es el TOPE POR TIEMPO del
//  paso 4 (`MigrationPolicy.markerExport*BudgetSeconds`). Corolario: el único probe de escritura real ES
//  el paso 4, así que el tope no es opcional.
//
//  FAIL-OPEN: la ambigüedad nunca aborta una migración. Solo bloquea lo que ya es sabido-imposible.
//

import CloudKit
import Foundation

/// Veredicto del canal iCloud (C-1). `String`/`rawValue` porque se JOURNALEA en
/// `MigrationState.cutoverICloudVerdictRaw` para el copy del fallo y para el rastro del waiver — los
/// rawValues son WIRE-ESTABLES (renombrarlos rompería la lectura de un journal en vuelo).
nonisolated enum ICloudChannelVerdict: String, Equatable, Sendable {
    /// Canal aparentemente sano, o ambigüedad. FAIL-OPEN: jamás abortamos por no saber.
    case healthy
    /// Sin cuenta iCloud Y sin metadata CloudKit local ⇒ NO existe copia del corpus en CloudKit, así que
    /// el marcador es *indeliverable* Y *prescindible*: nadie puede divergir de una copia que no existe.
    /// El cutover SIGUE (waiver del gate de export, no de la cadena de fases). Sin este caso, el usuario
    /// que no usa iCloud tendría el modo nube vetado PARA SIEMPRE ("necesitas iCloud para dejar de
    /// usar iCloud") y ningún reintento lo arreglaría — la condición es permanente.
    case noChannelNoFootprint
    /// Sin cuenta iCloud pero CON metadata CloudKit local ⇒ hay una copia viva del corpus a la que no
    /// podemos avisar del cutover. Bloquea la ENTRADA (nada durable ha cambiado todavía).
    case noAccountWithFootprint
    /// iCloud sin espacio (`CKError.quotaExceeded`, código 25).
    case quotaExceeded
    /// Cuenta presente pero CloudKit inutilizable (no autenticado / restringido / zona borrada).
    case accountUnusable

    /// ¿Abortar ANTES de tocar nada durable? Se consulta en `verifying` (rama `.match`) y en
    /// `cutover(.pending)`: ahí no hay `migrated_at`, ni `.cloud` persistido, ni marcador ⇒ el rollback es
    /// limpio y el device queda idéntico a como empezó.
    var blocksCutoverEntry: Bool {
        switch self {
        case .healthy, .noChannelNoFootprint:
            return false
        case .noAccountWithFootprint, .quotaExceeded, .accountUnusable:
            return true
        }
    }

    /// Clasificación del atasco del paso 4, que elige el PRESUPUESTO del tope: `.definitive` = CloudKit ya
    /// dictó que el write no entra (presupuesto CORTO, no tiene sentido esperar); `.unknown` = aún no
    /// sabemos por qué no exporta (offline, mirror encolado) ⇒ presupuesto LARGO, porque un snapshot
    /// completo ya subido y verificado no se tira por un túnel largo.
    var stallCause: MarkerExportStall {
        switch self {
        case .healthy, .noChannelNoFootprint:
            return .unknown
        case .noAccountWithFootprint, .quotaExceeded, .accountUnusable:
            return .definitive
        }
    }
}

nonisolated enum ICloudCutoverGateLogic {

    /// Decisión PURA (sin I/O, sin red, sin `Date.now`) — el executor le pasa las tres señales.
    ///
    /// - Parameters:
    ///   - accountPresent: `SwiftDataConfiguration.isICloudAvailable()`, el MISMO predicado que decide el
    ///     montaje del store. Deliberadamente no se introduce `CKContainer.accountStatus()` (0 usos en el
    ///     repo): una segunda verdad podría discrepar del predicado que realmente gobierna si existe mirror.
    ///     Ojo: mide iCloud **Drive**, así que NUNCA bloquea solo — solo combinado con `hasCloudKitFootprint`.
    ///   - hasCloudKitFootprint: ≥1 `SyncIdentity.ckRecordName != nil`. Señal DURABLE (SQLite local, sobrevive
    ///     al sign-out de iCloud) de que este corpus ya tiene copia en CloudKit.
    ///   - lastExportErrorCode: `iCloudSyncService.lastExportError?.code` — post-hoc y EN MEMORIA (`nil` tras
    ///     un boot fresco, así que el tope por tiempo es la red de seguridad, no esto).
    static func decide(
        accountPresent: Bool,
        hasCloudKitFootprint: Bool,
        lastExportErrorCode: CKError.Code?
    ) -> ICloudChannelVerdict {
        if !accountPresent {
            return hasCloudKitFootprint ? .noAccountWithFootprint : .noChannelNoFootprint
        }
        switch lastExportErrorCode {
        case .quotaExceeded:
            return .quotaExceeded
        case .notAuthenticated, .managedAccountRestricted, .userDeletedZone:
            return .accountUnusable
        default:
            // `nil` o retriable (red / rate-limit / zoneBusy / serviceUnavailable) ⇒ FAIL-OPEN. Espeja la
            // clasificación de `iCloudSyncService.isRetriable` SIN tocarla (esa tabla gobierna el banner de
            // TODOS los usuarios 2.x y está pinneada celda a celda).
            return .healthy
        }
    }
}

// MARK: - Reversa: por qué no drena la subida a iCloud

/// Por qué la espera de `reverseUpload` no drena, hasta donde se sabe (ticket
/// `reverse-upload-has-no-ceiling-and-no-exit`). Elige el presupuesto del techo (`stallCause`) y el copy de la
/// espera. `String`/`rawValue` porque viaja como detalle del canario: WIRE-ESTABLE.
nonisolated enum ReverseUploadBlocker: String, Equatable, Sendable {
    /// CloudKit dijo que iCloud no tiene espacio (`CKError.quotaExceeded`).
    case icloudFull
    /// CloudKit dijo que la cuenta no sirve: no autenticada, restringida o con la zona borrada.
    case icloudUnusable
    /// Este dispositivo no tiene token de iCloud y CloudKit no ha dicho nada. Ojo: el token mide iCloud DRIVE
    /// (`.claude/rules/swiftdata-cloudkit.md`), y con Drive apagado CloudKit puede estar subiendo igual. Por eso
    /// solo elige un copy CONDICIONAL, nunca el presupuesto corto ni un motivo que afirme que iCloud faltaba.
    case icloudOff
    /// No se sabe: red, un mirror lento o un mirror que no exporta sin decir por qué.
    case unknown

    /// FAIL-OPEN: solo la palabra de CloudKit acorta la espera. Es MÁS permisiva que la ida, no igual: allí,
    /// sin token y con huella CloudKit local (`noAccountWithFootprint`), el paso 4 sí baja a 900 s sin que
    /// CloudKit diga nada. Aquí, sin Drive y sin error, la persona lee el aviso condicional y tiene «Cancelar» a
    /// mano; el techo sigue siendo el largo.
    var stallCause: MarkerExportStall {
        switch self {
        case .icloudFull, .icloudUnusable:
            return .definitive
        case .icloudOff, .unknown:
            return .unknown
        }
    }

    /// El motivo que se journalea si la espera agota su techo con esta causa. `icloudOff` cae en `stalled`, no en
    /// `icloudUnavailable`: la nota sobrevive al relanzamiento, y «iCloud no estaba disponible» sería falso para
    /// quien tenía iCloud y solo Drive apagado.
    var abortReason: ReverseAbortReason {
        switch self {
        case .icloudFull:
            return .icloudFull
        case .icloudUnusable:
            return .icloudUnavailable
        case .icloudOff, .unknown:
            return .stalled
        }
    }
}

/// Por qué terminó la vuelta a iCloud sin llegar, en cualquiera de sus dos salidas: la espera de `reverseUpload`
/// (ticket `reverse-upload-has-no-ceiling-and-no-exit`) y el claim que el servidor no concede
/// (`reverse-claim-rejection-has-no-way-out-in-the-client`). Se journalea (`MigrationState.reverseAbortReasonRaw`)
/// porque la persona puede no estar mirando cuando pasa: lo lee después, en la tarjeta de «Volver a iCloud».
/// `rawValue` WIRE-ESTABLE (un journal en vuelo lo tiene que poder leer); el nombre del tipo no viaja, y por eso se
/// pudo renombrar al sumarse las salidas del claim.
nonisolated enum ReverseAbortReason: String, Equatable, Sendable {
    // MARK: Salidas de la espera de `reverseUpload`

    /// La persona tocó «Cancelar y seguir en la nube». No lleva nota: lo decidió ella.
    case cancelled
    /// iCloud sin espacio.
    case icloudFull
    /// CloudKit dijo que la cuenta de iCloud no sirve en este dispositivo.
    case icloudUnavailable
    /// El techo largo sin avanzar, sin que CloudKit dijera por qué (también sin token de iCloud Drive).
    case stalled

    // MARK: Salidas del claim (`reverseClaimLeader`)

    /// El servidor no la deja empezar TODAVÍA: la migración a la nube de esta cuenta aún tiene su lease
    /// (`migration_in_progress`). Pasajero: se va a los 60 min sin latido, o antes si esa migración termina.
    case claimRetryLater
    /// El servidor no la deja empezar y esperar no lo cambia: `not_complete`, `no_profile` o un motivo que este build
    /// no conoce. Un motivo desconocido cae aquí a propósito: quedarse al 15 % es el bug que esta salida quita.
    case claimRefused
    /// Otro dispositivo de la cuenta ya es el líder de su propia vuelta a iCloud (`other_leader`).
    case otherDeviceReverting

    // MARK: Salidas de las fases previas al montaje (`reverse-before-mount-has-no-way-to-abandon-the-return`)

    /// La vuelta ya había empezado —el servidor concedió la reserva— y luego no dejó continuar: el drenaje o la
    /// verificación chocaron con la cuenta no disponible, o el congelado salió rechazado. Esperar no lo cambia, así
    /// que el texto da el correo de soporte. NO se reusa `claimRefused`: ese dice «ese intento no cambió nada», y
    /// aquí la reserva sí llegó a existir.
    case preMountRefused
    /// El techo de las fases previas al montaje venció sin que el servidor dijera por qué. Casi siempre es el LARGO:
    /// red que no vuelve, o una sesión que nadie renovó en 72 h. Desde el 2026-09-22 también lo produce el CORTO con
    /// `.localFailure` —una lectura de la base local que falló—, y por el mismo motivo: sin correo de soporte, porque
    /// volver a intentarlo sí puede funcionar.
    case preMountStalled
    /// Otro dispositivo de la cuenta tomó el relevo de la vuelta MIENTRAS esta ya había empezado (el `other_leader`
    /// del congelado). No se reusa `otherDeviceReverting` por lo mismo que no se reusa `claimRefused`: ese dice «no
    /// pudimos EMPEZAR», y aquí la reserva ya existía. El mismo argumento, aplicado dos veces.
    case preMountOtherDevice

    /// El porqué que se journalea cuando el servidor rechaza el claim con `serverReason` (el `reason` del RPC tal
    /// cual). Solo `migration_in_progress` es pasajero; cualquier otro motivo es permanente.
    static func forClaimRejection(serverReason: String) -> ReverseAbortReason {
        serverReason == "migration_in_progress" ? .claimRetryLater : .claimRefused
    }
}

/// Qué paró una fase PREVIA al montaje del espejo cuando no fue la red ni la sesión, y esperar no lo arregla
/// (ticket `reverse-before-mount-has-no-way-to-abandon-the-return`). Hasta ese ticket los tres primeros llegaban al
/// runner colapsados en `.transient`, y por eso la vuelta se quedaba parada ahí sin salida: sin distinguirlos no hay
/// forma de elegir el techo corto.
///
/// **Los tres primeros son la palabra del servidor; los dos últimos no, y entraron el 2026-09-22**
/// (`reverse-verify-network-bucket-hides-a-definitive-server-no`). Lo que los junta a todos no es quién habló, sino
/// que ninguno se resuelve solo: un `fetch` de SwiftData que lanza y un veredicto que este build no sabe leer tampoco
/// mejoran por esperar tres días. El criterio de este tipo es ése, y por eso el techo corto es de los cinco.
///
/// `String`/`rawValue` porque viaja como mitad del detalle del canario: WIRE-ESTABLE.
nonisolated enum ReversePreMountBlocker: String, Equatable, Sendable {
    /// 403: la cuenta en la nube no está disponible (suspendida). Lo tipan `SyncPushClient` y `SyncPullClient`, así
    /// que llega en el drenaje y en la verificación; el claim y el congelado no lo ven (`/account/migration` no
    /// devuelve 403 y el cliente lee todo lo que no sea 200/401 como red).
    case accountUnavailable
    /// Otro dispositivo de la cuenta tomó el relevo de la vuelta mientras esta fase estaba parada. El lease dura
    /// 60 min y ninguna de las cuatro fases paradas late, así que es alcanzable sin más que volver dos horas después.
    case otherLeader
    /// El servidor rechazó el paso por un motivo que no es ni red ni sesión.
    case refused
    /// La base de datos LOCAL del teléfono falló al leer durante la verificación (los dos `fetch` que `verifyIntegrity`
    /// puede ver lanzar: el del outbox y el de la cuarentena). No es red ni es el servidor, y hasta el 2026-09-22 se
    /// leía como red: la persona esperaba 72 h delante de una avería de su propio teléfono.
    case localFailure
    /// El verificador contestó con un motivo que este build no sabe leer. Antes se presumía pasajero —«conservador»—,
    /// y con el techo largo detrás eso dejó de ser lo conservador: esperar tres días por algo que nadie sabe leer no
    /// es prudencia, es silencio.
    case unknownVerdict

    /// Los cinco eligen el presupuesto CORTO, y el criterio NO es quién habló: es que ninguno se arregla esperando.
    /// Nada que ver con el fail-open de `ReverseUploadBlocker`: allí la ambigüedad —un token de Drive ausente— no
    /// acortaba porque no era un desenlace, y aquí los cinco lo son.
    ///
    /// `switch` exhaustivo y no un `.definitive` a secas: con la constante, un motivo NUEVO heredaría el techo corto
    /// sin que nadie lo decidiera, y ningún test podría cazarlo —una aserción por caso sobre una constante no puede
    /// fallar—. Así el compilador obliga a contestar la pregunta.
    var stallCause: MarkerExportStall {
        switch self {
        case .accountUnavailable, .otherLeader, .refused, .localFailure, .unknownVerdict:
            return .definitive
        }
    }

    /// El motivo que se journalea si el techo vence con esta causa.
    ///
    /// **Los dos motivos del 2026-09-22 salen con `preMountStalled`, no con `preMountRefused`**, y la diferencia la
    /// decide el COPY, no el techo: el texto de `refused` dice «tu cuenta en la nube no lo permitió» y da el correo de
    /// soporte, y eso solo es verdad cuando el servidor contestó. Una lectura de la base local que falló no es la
    /// cuenta, y un veredicto que este build no sabe leer es un desajuste de contrato del propio cliente — acusar a la
    /// cuenta ahí manda a soporte a quien no tiene nada que consultar, y le cuenta a la persona una causa inventada.
    /// **No es el molde del claim**: allí `claimRefused` acoge el motivo desconocido porque ese motivo lo escribe el
    /// SERVIDOR; aquí lo escribe una función local. Lo cazaron dos lentes de la review por separado.
    ///
    /// Que los dos compartan `abortReason` no los hace redundantes: lo que los separa es el `rawValue`, que viaja en
    /// el canario `cloudReversePreMountWaiting` y es lo único que deja distinguir en la flota una avería local de un
    /// contrato roto.
    var abortReason: ReverseAbortReason {
        switch self {
        case .otherLeader:
            return .preMountOtherDevice
        case .accountUnavailable, .refused:
            return .preMountRefused
        case .localFailure, .unknownVerdict:
            return .preMountStalled
        }
    }
}

nonisolated enum ReverseUploadBlockerLogic {

    /// Decisión PURA (sin I/O ni `Date.now`); el executor le pasa las señales.
    ///
    /// - Parameters:
    ///   - icloudAvailable: `SwiftDataConfiguration.isICloudAvailable()`, el mismo predicado que decide el mount.
    ///   - lastExportErrorCode: `iCloudSyncService.lastExportError?.code`, en memoria. La falta de cuenta llega
    ///     como `NSCocoaErrorDomain 134400` y NO pasa por aquí: por eso existe el término de arriba.
    ///   - lastExportErrorAt / lastSuccessfulExportAt: las fechas de ese error y del último export con éxito.
    ///     `lastExportError` NO se limpia con un éxito posterior, así que sin comparar fechas un «iCloud lleno» ya
    ///     resuelto seguiría acortando la espera y diciendo en pantalla que no hay espacio a quien acaba de
    ///     liberarlo. Un error sin fecha no cuenta: la ambigüedad nunca acorta.
    ///   - mirrorReportedNotAuthenticated: `iCloudSyncService.mirrorReportedNotAuthenticated`. Es la única vía por
    ///     la que un `CKError.notAuthenticated` llega a leerse: `iCloudSyncService.apply` sale antes de guardarlo
    ///     en `lastExportError`. Este sí se apaga con cualquier evento con éxito.
    static func decide(
        icloudAvailable: Bool,
        lastExportErrorCode: CKError.Code?,
        lastExportErrorAt: Date?,
        lastSuccessfulExportAt: Date?,
        mirrorReportedNotAuthenticated: Bool
    ) -> ReverseUploadBlocker {
        let errorIsCurrent: Bool = {
            guard let errorAt = lastExportErrorAt else { return false }
            guard let successAt = lastSuccessfulExportAt else { return true }
            return errorAt > successAt
        }()
        // La palabra de CloudKit, con la MISMA tabla de `CKError` que la ida: dos tablas acabarían diciendo cosas
        // distintas del mismo error. `accountPresent: true` deja fuera la rama de la cuenta, que en la reversa
        // se decide abajo y no acorta la espera.
        switch ICloudCutoverGateLogic.decide(
            accountPresent: true, hasCloudKitFootprint: true,
            lastExportErrorCode: errorIsCurrent ? lastExportErrorCode : nil) {
        case .quotaExceeded:
            return .icloudFull
        case .accountUnusable:
            return .icloudUnusable
        case .healthy, .noChannelNoFootprint, .noAccountWithFootprint:
            break
        }
        if mirrorReportedNotAuthenticated { return .icloudUnusable }
        return icloudAvailable ? .unknown : .icloudOff
    }
}
