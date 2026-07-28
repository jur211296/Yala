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
