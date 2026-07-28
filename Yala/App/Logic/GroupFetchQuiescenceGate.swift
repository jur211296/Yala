//
//  GroupFetchQuiescenceGate.swift
//  Yala
//
//  Decisión PURA del gate C-4 (PIEZA 1): ¿puede arrancar la pasada de migración de grupos al backend,
//  o el FETCH DE GRUPOS de CloudKit todavía no se ha asentado en esta sesión?
//
//  EL BUG QUE ACOTA. El paso 3 de `GroupMigrationUploader.migrateOne` pone `group.isBackendGroup = true`
//  y a partir de ahí el guard simétrico de pull de `SplitSyncManager.handleFetchedRecordZoneChanges`
//  descarta TODO record de esa zona (recomputa el set del store VIVO en cada batch). Si un miembro subió
//  un gasto que este device aún no había bajado, el paso 4 (`enqueueSnapshotRows`, lectura VIVA del
//  store) no lo siembra y CloudKit ya no lo puede entregar: pérdida silenciosa y permanente de dinero.
//
//  LO QUE ESTE GATE **NO** HACE. No cierra la carrera hacia el futuro: un record subido un milisegundo
//  después de nuestro último fetch se pierde igual. Eso lo cierra el RESCATE de pull (adoptar lo nunca
//  visto en vez de descartarlo), que vive en SU PROPIO TICKET. Aquí solo se cierra la ventana
//  DEMOSTRABLE: hoy el uploader congela grupos mientras el engine sigue en export-only, con batches sin
//  aplicar en el búfer, con un ciclo de fetch en vuelo, o después de que un apply fallara con el token
//  ya avanzado. Todas ésas son situaciones en las que el device SABE que su store no está al día.
//
//  Idioma del repo (`SplitSyncStartGate`, `BootSaveGateLogic`, `MigrationGateLogic`,
//  `SubcategoryDedupGate`): decisión PURA sobre un struct de entradas + adaptador de runtime fino.
//
//  POR QUÉ LA SEÑAL ES PASIVA — jamás forzar `fetchChanges()`: no es por zona, fetchea la base privada
//  ENTERA. En una pasada de N grupos, forzarlo al llegar al #k descartaría (con avance de token) todo lo
//  que CloudKit tuviera para los grupos #1..#k-1, ya congelados por el paso 3 de ESA misma pasada. El
//  gate estaría CAUSANDO la pérdida que viene a evitar. Tampoco puede evaluar la promoción
//  (`SplitSyncManager.evaluateQuiescentPromotion` → `enableAutoSync()` → `Task { fetchChanges() }` que
//  NADIE awaitea): mismo problema por la puerta de atrás. El adaptador SOLO LEE contadores que el
//  delegate ya mantiene.
//
//  POR QUÉ «SIN CANAL ⇒ PASA»: sin cuenta iCloud (`isAccountAvailable` = `ubiquityIdentityToken != nil`)
//  o sin engine privado montado (sesión secundaria, UI tests, simulador) NADIE puede entregar nada, y
//  hoy esos devices migran perfectamente: el store de grupos monta `cloudKitDatabase: .none` y ningún
//  paso del uploader toca CloudKit. Es justo la cohorte de Modo Nube, que no exige iCloud. Un gate que
//  las bloqueara mataría su migración PARA SIEMPRE, en silencio.
//
//  POR QUÉ EL TESTIGO POR ZONA ES **NEGATIVO** (zonas cuyo fetch FALLÓ) Y NO POSITIVO (zonas con fetch
//  limpio): exigir que cada zona candidata aparezca en un set de «fetcheadas limpiamente» deadlockea. El
//  evento `didFetchRecordZoneChanges` solo llega para las zonas que el engine efectivamente fetchea en
//  ese ciclo; una zona SIN cambios —el estado estable, el caso mayoritario— no lo produce nunca, así que
//  el gate diferiría en cada boot y la migración no correría JAMÁS. (Que ese evento no sea una garantía
//  lo asume el propio repo: su otro consumidor, `completeInitialMemberImport`, lleva una ventana de
//  auto-sanado de 15 min.) La formulación negativa captura el mismo fallo sin deadlock: ausencia = sin
//  noticias = no bloquea; presencia = evidencia POSITIVA de que esa zona no se pudo leer.
//
//  NOTA-GUARDIA (enrutado por modo): esta señal es el ciclo de CKSyncEngine del container de GRUPOS, no
//  la quiescencia del store PERSONAL — no depende de `StorageMode` y por eso NO pasa por
//  `StorageModeSignalRouter`. La parte personal ya la enruta el call-site
//  (`AppBootstrapper.awaitPersonalStoreReady()`, que en `.cloud` delega en `SyncQuiescenceCoordinator`,
//  no en `iCloudSyncService`, cuya señal ahí queda perpetuamente quieta). Si algún día se mezcla aquí
//  una señal del store personal, TIENE que pasar por el router.
//

import Foundation

/// Gate PURO «el fetch de grupos está quieto» para la pasada de migración al backend.
nonisolated enum GroupFetchQuiescenceGate {

    /// Instantánea del canal de fetch de Grupos. La ensambla `signal(...)` desde el estado CRUDO de
    /// `SplitSyncManager` + `iCloudSyncService`; el adaptador no deriva nada por su cuenta.
    struct Signal: Equatable, Sendable {
        /// `iCloudSyncService.isAccountAvailable` (= `ubiquityIdentityToken != nil`).
        let accountAvailable: Bool
        /// El engine PRIVADO existe en este proceso. Los candidatos de la migración son SIEMPRE
        /// `isOwner` ⇒ sus zonas viven en la base privada; el engine `shared` no entrega nada suyo.
        let engineMounted: Bool
        /// El engine corre con `automaticallySync = true`. En la ventana export-only el engine EXISTE
        /// pero no fetchea solo y el delegate BUFFEREA todo apply: `engineMounted` por sí solo mentiría.
        let autoSyncActive: Bool
        /// Ciclos de fetch EN VUELO del engine privado (`willFetchChanges` sin su `didFetchChanges`).
        let cyclesInFlight: Int
        /// El engine privado cerró ≥1 ciclo ENTERO en esta sesión. Distingue «quieto porque terminó» de
        /// «quieto porque aún no ha empezado» — mismo motivo por el que `resolveWaitByQuiescence` exige
        /// `hasCompletedFirstImport` además de `isQuiescent`.
        let hasCompletedCycle: Bool
        /// Hay batches fetcheados esperando en los búferes de la ventana export-only: el ciclo pudo
        /// cerrar, pero esos records NO están en el store.
        let hasBufferedFetchEvents: Bool
        /// Alguna zona de los CANDIDATOS tuvo un `didFetchRecordZoneChanges` con error y todavía no ha
        /// vuelto a cerrar limpio. Evidencia positiva de «esta zona no se ha podido leer».
        let candidateZoneFetchFailed: Bool
        /// Un apply de records fetcheados NO llegó a persistir en esta sesión (save fallido, o el
        /// handler entró sin `modelContext`). El ciclo «completó» pero el store NO quedó completo y el
        /// token YA avanzó ⇒ el testigo no vale, y esperar no lo arregla (CloudKit no re-entrega).
        let applyFailedThisSession: Bool
    }

    /// Ensambla la señal desde el estado CRUDO del manager. Vive AQUÍ y no en `SplitSyncManager` para
    /// que las dos derivaciones no triviales —el OR de los tres búferes y la intersección de zonas—
    /// tengan test de comportamiento propio: es donde vive el riesgo real del adaptador. Lo único que
    /// queda sin test de comportamiento es qué campo del manager alimenta cada parámetro, y eso lo
    /// pinnea el source-scan de cableado.
    static func signal(
        accountAvailable: Bool,
        privateEngineMounted: Bool,
        autoSyncActive: Bool,
        privateCyclesInFlight: Int,
        privateCompletedCycle: Bool,
        deferredRecordZoneEventCount: Int,
        deferredDatabaseEventCount: Int,
        deferredClearAllRequested: Bool,
        applyFailedThisSession: Bool,
        candidateZoneNames: Set<String>,
        zonesWithFailedFetch: Set<String>
    ) -> Signal {
        Signal(
            accountAvailable: accountAvailable,
            engineMounted: privateEngineMounted,
            autoSyncActive: autoSyncActive,
            cyclesInFlight: privateCyclesInFlight,
            hasCompletedCycle: privateCompletedCycle,
            // Los tres búferes cuentan igual: cualquiera de ellos significa «hay entregas fetcheadas
            // que NO están en el store». `deferredClearAllRequested` incluido porque un sign-out
            // diferido descarta los búferes al drenarlos: migrar sobre esa base no tiene sentido.
            hasBufferedFetchEvents: deferredRecordZoneEventCount > 0
                || deferredDatabaseEventCount > 0
                || deferredClearAllRequested,
            // Solo importan las zonas que esta pasada va a CONGELAR. El fallo de una zona ajena no
            // bloquea la migración de las demás.
            candidateZoneFetchFailed: !candidateZoneNames.isDisjoint(with: zonesWithFailedFetch),
            applyFailedThisSession: applyFailedThisSession)
    }

    enum Decision: Equatable {
        /// Arrancar la migración ya.
        case proceed
        /// Seguir esperando (hay canal vivo y aún no se ha asentado).
        case wait
        /// No migrar en esta sesión; reintentar en el próximo boot (los 7 pasos son idempotentes, así
        /// que diferir jamás pierde trabajo).
        case deferToNextBoot
    }

    /// - Parameter canWait: `false` en los puntos de re-chequeo SÍNCRONOS (sin `await` disponible): ahí
    ///   «no asentado» se traduce directamente en diferir, nunca en bloquear el main actor.
    static func decide(
        signal: Signal,
        waitedSeconds: TimeInterval,
        capSeconds: TimeInterval,
        canWait: Bool
    ) -> Decision {
        // 1. Sin canal que pueda ENTREGAR no hay nada que esperar (y hoy estos devices migran bien).
        guard signal.accountAvailable, signal.engineMounted else { return .proceed }

        // 2. Evidencia POSITIVA de pérdida que esperar NO arregla: el token ya avanzó sobre un batch
        //    que no llegó a persistir y CloudKit no lo re-entrega. No congelar nada esta sesión.
        if signal.applyFailedThisSession { return .deferToNextBoot }

        // 3. Canal vivo: ¿asentado? Todo lo de aquí es AUTO-SANABLE, así que se espera en vez de diferir.
        let settled = signal.autoSyncActive
            && !signal.hasBufferedFetchEvents
            && !signal.candidateZoneFetchFailed
            && signal.cyclesInFlight == 0
            && signal.hasCompletedCycle
        if settled { return .proceed }

        guard canWait else { return .deferToNextBoot }
        return waitedSeconds >= capSeconds ? .deferToNextBoot : .wait
    }

    /// Slug estable del MOTIVO por el que la señal no está asentada — para el breadcrumb y el `detail`
    /// del canario. Sin PII. Orden de precedencia fijo (determinista) y espejo del de `decide`.
    ///
    /// `"noChannel"` es DIAGNÓSTICO PURO: nunca sale por el canario, porque `decide` devuelve `.proceed`
    /// en ese caso y no hay diferimiento que reportar. Existe para que un caller que llame a
    /// `deferReason` sin pasar por `decide` no lea un motivo falso.
    static func deferReason(signal: Signal) -> String {
        if !signal.accountAvailable || !signal.engineMounted { return "noChannel" }
        if signal.applyFailedThisSession { return "applyFailed" }
        if !signal.autoSyncActive { return "exportOnly" }
        if signal.hasBufferedFetchEvents { return "buffered" }
        if signal.candidateZoneFetchFailed { return "zoneFetchFailed" }
        if signal.cyclesInFlight > 0 { return "inFlight" }
        if !signal.hasCompletedCycle { return "noCycle" }
        return "settled"
    }
}
