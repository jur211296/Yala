//
//  CloudSyncEngine.swift
//  Yala
//
//  Motor de CAPTURA del Modo Nube (incremento I3). Lee el SwiftData History del ModelContainer
//  (write→drain) y traduce cada cambio de las 6 entidades sincronizables en una fila de `SyncOutbox`
//  (upsert / tombstone) lista para reenviarse al backend (el sender llega en I8). DARK: nada de
//  producción lo instancia todavía — el wiring del ciclo de vida llega en I9/I12.
//
//  Una instancia por proceso (NO un singleton global; el owner del ciclo de vida llega en I9/I12).
//  Patrón "one in-flight, one queued" (§a.4): `drainOnce` re-entrante coalescea a lo sumo una vuelta
//  pendiente. Todo `@MainActor` (manipula `ModelContext` / `@Model`, regla inviolable del repo).
//
//  Reloj HLC EN-MEMORIA por instancia: se acuña un `NodeID` nuevo por instancia y el `HLCClock` parte
//  fresco (`latest = nil`). La persistencia del reloj y `receive()` (integrar HLCs remotos) llegan en
//  I8. Consecuencia CLAVE de resumibilidad: con reloj fresco, RE-procesar el mismo History en el
//  mismo orden produce HLCs IDÉNTICOS (los timestamps de las transacciones y el orden son estables)
//  → tras un kill (proceso reiniciado = instancia+reloj frescos), el re-drain reproduce las mismas
//  filas y la deduplicación por (syncID, hlc, op) las absorbe sin duplicar.
//
//  I4: el tombstone lleva op + syncID preservado + `reason` clasificado 100% DRAIN-SIDE
//  (`classifyTombstoneReason`, taxonomía §c.1: user | cascade | dedup | migration | wipe). La
//  clasificación NO toca los ~30 call-sites de delete de producción (cero cambios en
//  `EntityDeletionService` ni vistas). `dedup`/`wipe` se afinan en I9/I12 (comentario-guardia).
//
//  Frontera I3/I8: `fieldsJSON` es un STUB estructurado (JSON `{prop: descripción}` sin `syncID`);
//  el espejo App Group `.atomic` previo al insert; el sender; el `serverSeqCursor` del pull; y el
//  reconcile real del token expirado llegan en I8. Comentarios-guardia marcan cada punto de enganche.
//

import Foundation
import OSLog
import SwiftData

// MARK: - Errores nombrados

/// Errores del cursor de captura. Nombrados (nunca silenciados) para el path §d.6.
nonisolated enum CloudSyncCursorError: Error, Equatable {
    /// El token persistido no se pudo decodificar o el fetch por token falló (migración destructiva,
    /// incompatibilidad de versión). DIFERIDOS #33: desde el cierre, ese caso re-escanea ACOTADO por
    /// `lastDrainedTxAt` (`HistoryTokenFallbackLogic`) en vez del History completo; el full-rescan
    /// queda solo para cursor sin ancla (pre-schema) o fetch acotado que también lanza.
    case historyTokenExpired
}

// MARK: - Breadcrumb (Console.app, fuera de #if DEBUG, sin PII)

/// Rastros de diagnóstico del motor de captura. Fuera de `#if DEBUG` a PROPÓSITO (espeja `SaveBreadcrumb`
/// / `SplitSync*`): el comportamiento del pipeline solo se valida del todo en device/TestFlight. Sin PII
/// (solo tipos de entidad, counts, seq — nunca valores de usuario).
@MainActor
enum CloudSyncBreadcrumb {
    private static let logger = Logger(subsystem: "com.yala", category: "CloudSync")

    /// Una vuelta de drain terminó: número de secuencia + filas de outbox pendientes tras la vuelta.
    static func drain(seq: Int, pending: Int) {
        logger.notice("CloudSync drain seq=\(seq, privacy: .public) pending=\(pending, privacy: .public)")
    }

    /// Un delete llegó sin `syncID` preservado en el tombstone → no se pudo emitir el tombstone.
    static func identityGap(entityType: String, reason: String) {
        logger.notice("CloudSyncIdentityGap \(entityType, privacy: .public) reason=\(reason, privacy: .public)")
    }

    /// DIFERIDOS #33: el token del cursor está ROTO (in-decodificable o su fetch por token lanzó) pero hay
    /// ancla (`lastDrainedTxAt`) → re-escaneo ACOTADO a la ventana `> ancla − slack` en vez del full-rescan
    /// (el corpus por debajo del cutoff NO se re-emite). `window` = txs en la ventana (0 = History purgada
    /// por debajo del ancla — el token roto persiste y se cura con el primer write nuevo). Sin PII.
    static func historyTokenBrokenBoundedRescan(window: Int) {
        logger.notice("CloudSync historyTokenBrokenBoundedRescan window=\(window, privacy: .public) — token roto; re-escaneo acotado por lastDrainedTxAt")
    }

    /// DIFERIDOS #33: el token está ROTO y el drain degradó a re-escaneo COMPLETO — `reason` distingue la
    /// rama: `no-anchor` (cursor pre-schema sin `lastDrainedTxAt`, semántica (a) — comportamiento pre-fix
    /// conservado) o `bounded-fetch-failed` (semántica (b): el fetch acotado por timestamp TAMBIÉN lanzó;
    /// degradar preserva la convergencia — abortar sería stall = divergencia local-ahead). `txs` MIDE el
    /// tamaño de la re-emisión (el hazard de #33 ocurriendo pese al fix): en producción cloud, `reason=
    /// bounded-fetch-failed` con `txs` alto = canario. Sin PII (solo counts).
    static func historyTokenBrokenFullRescan(reason: String, txs: Int) {
        logger.notice("CloudSync historyTokenBrokenFullRescan reason=\(reason, privacy: .public) txs=\(txs, privacy: .public) — token roto; full-rescan degradado")
    }

    /// DIFERIDOS #33: tras un re-escaneo acotado con ventana NO vacía, el token se re-ancló a la última tx
    /// del mount actual. Par de recuperación de `historyTokenBrokenBoundedRescan`. Sin PII.
    static func historyTokenBrokenReanchored() {
        logger.notice("CloudSync historyTokenBrokenReanchored — token re-anclado tras re-escaneo acotado")
    }

    /// HALLAZGO 2 (corrida device reversa 2026-07-11): el guard de validación por timestamp detectó que el
    /// `historyTokenData` del cursor NO surfacea `missed` transacciones externas del mount actual (token
    /// acuñado en un mount previo → no-comparable cross-mount, la MISMA clase que `fastForwardHistoryBaseline`
    /// documenta). El drain re-procesa la unión y re-ancla el token. En producción cloud, `> 0` = canario de
    /// esta clase de bug (fila que jamás llega al outbox → divergencia Merkle local-ahead). Sin PII (solo count).
    static func historyTokenIncomparable(missed: Int) {
        logger.notice("CloudSync historyTokenIncomparable missed=\(missed, privacy: .public) — token no-comparable cross-mount; re-procesando unión + re-anclando")
    }

    /// HALLAZGO 2: el guard re-ancló el `historyTokenData` a la última tx del mount actual tras un
    /// `historyTokenIncomparable`. Par de recuperación del canario. Sin PII.
    static func historyTokenRecovered() {
        logger.notice("CloudSync historyTokenRecovered — token re-anclado al mount actual")
    }

    /// D4 (I12): un UPDATE de History mutó el keypath de IDENTIDAD de una entidad cuya identidad de sync
    /// es su UUID persistido (p.ej. `Tag.id`/`Account.shortcutID` regenerado). El drain, ante ese UPDATE
    /// identity-only, SIGUE haciendo SKIP (el sync_id es la PK, no una columna del mapa → `changedColumns`
    /// vacío) — POR DISEÑO: el remap NO se emite desde el drain, sino desde `emitIdentityRemap` en la MISMA
    /// transacción del reparador (`repairCollapsedIdentityUUIDs`), que además tombstonea el sync_id viejo y
    /// re-emite las filas referenciantes. DIFERIDOS #29 (§b.4) cerró el gap; este canario pasó de "delator del
    /// gap" a RED DE SEGURIDAD: si suena SIN el par `identityRemapEmitted` en la misma ventana, hay un sitio
    /// de mutación de identidad NO cableado al remap (bug). Sin PII (solo el tipo de entidad).
    static func identityMutationObserved(entity: String) {
        logger.notice("CloudSyncIdentityMutation entity=\(entity, privacy: .public)")
    }

    /// DIFERIDOS #29 (§b.4): `emitIdentityRemap` encoló el trío {tombstone(oldID), upsert-FULL(newID),
    /// re-emisión de referenciantes} para `count` re-keys de una entidad. Co-ocurre con `identityMutationObserved`
    /// (el mismo save que regenera el id) → juntos = remap SANO; `identityMutationObserved` a solas = sitio de
    /// mutación no cableado. Sin PII (solo el tipo de entidad y el conteo).
    static func identityRemapEmitted(entity: String, count: Int) {
        logger.notice("CloudSyncIdentityRemap emitted entity=\(entity, privacy: .public) count=\(count, privacy: .public)")
    }

    /// DIFERIDOS #29 (§5): en `storageMode == .cloud` el one-shot `migrateShortcutIDsAndRebuildCSVMirrors`
    /// SALTÓ la regeneración masiva de UUIDs de identidad (`tags` presentes) — el applier asigna ids explícitos
    /// del backend; el backstop repetible es `repairCollapsedIdentityUUIDs` (con emisión de remap). Sin PII.
    static func identityRemapRegenSkippedInCloud(tags: Int) {
        logger.notice("CloudSyncIdentityRemap regenSkippedInCloud tags=\(tags, privacy: .public) — one-shot regen saltado en .cloud (backstop repairCollapsedIdentityUUIDs)")
    }

    /// DIFERIDOS #29 (SERIO 1 del review) — RUIDOSO (error-level): el remap NO pudo emitirse (motor caído,
    /// ClockDrift, migración/reversa en curso, etc.) → el reparador hizo ROLLBACK de la regeneración entera y
    /// difirió al próximo run del dedup. Comitear la regeneración SIN su outbox sería divergencia PERPETUA (el
    /// drain SKIPea updates identity-only — la premisa de #29), por eso se aborta. `reason` sin PII.
    static func identityRemapAborted(reason: String) {
        logger.error("CloudSyncIdentityRemap aborted reason=\(reason, privacy: .public) — rollback de la regeneración; se difiere al próximo run del dedup")
    }

    /// RED (I8c): el emisor produjo un grupo de coherencia incompleto tras la expansión. No debe ocurrir.
    static func coherenceGroupPartial(entity: String, group: String) {
        logger.notice("CloudSyncCoherenceGroupPartial \(entity, privacy: .public) group=\(group, privacy: .public)")
    }

    /// RED (I8c): el codec c1 rechazó los `fields` de una fila (número no-finito / fuera de rango / blob
    /// malformado). La fila se DESCARTA (no se puede serializar canónicamente) — canario del codec.
    static func encodeRejected(entity: String, reason: String) {
        logger.notice("CloudSyncEncodeRejected \(entity, privacy: .public) reason=\(reason, privacy: .public)")
    }

    // MARK: Push (I8e) — sin PII (status HTTP, counts, motivos de transporte; nunca valores de usuario)

    /// No hay sesión (token ausente) o el backend devolvió 401 → `pending` deltas quedan sin subir.
    static func pushBlockedNoSession(pending: Int) {
        logger.notice("CloudSyncPush blocked=no-session pending=\(pending, privacy: .public)")
    }

    /// El backend devolvió 403 → cuenta suspendida/deshabilitada (≠401).
    static func pushAccountUnavailable() {
        logger.notice("CloudSyncPush blocked=account-unavailable (403)")
    }

    /// El backend devolvió 409 `yala_account_reverting` → cuenta congelada por la reversa (§h.1): el
    /// backend ya no es fuente de verdad. Stop (mismo trato que 403); los deltas quedan en el outbox.
    static func pushAccountReverting() {
        logger.notice("CloudSyncPush blocked=account-reverting (409)")
    }

    /// Fallo de transporte (red caída / timeout / respuesta no-HTTP / 200 no decodificable) → reintentar.
    static func pushTransport(reason: String) {
        logger.notice("CloudSyncPush transient transport reason=\(reason, privacy: .public)")
    }

    /// El Worker respondió con un status inesperado (5xx / 429 / 4xx) → reintentar.
    static func pushHTTP(status: Int) {
        logger.notice("CloudSyncPush transient http=\(status, privacy: .public)")
    }

    /// Una fila de outbox no pudo traducirse a delta (clase no cableada al wire). No debe ocurrir.
    static func pushBuildFailed(reason: String) {
        logger.notice("CloudSyncPush buildFailed reason=\(reason, privacy: .public)")
    }

    /// Un `SyncDeltaResult` llegó sin `client_mutation_id` correlacionable → no se aplicó (ni purga ni
    /// dead-letter). No debe ocurrir (el Worker siempre lo ecoa).
    static func applyResultUnmatched(syncID: String) {
        logger.notice("CloudSyncPush applyResult unmatched sync_id=\(syncID, privacy: .public)")
    }

    /// Un `rejected` con reason `upstream_*` = error de infraestructura TRANSITORIO del Worker (no un
    /// rechazo definitivo del delta). La fila NO se dead-letterea ni dispara el canario; se reintenta.
    static func pushTransientUpstream(syncID: String, reason: String) {
        logger.notice("CloudSyncPush transientUpstream sync_id=\(syncID, privacy: .public) reason=\(reason, privacy: .public)")
    }

    // MARK: Pull (I8f-1) — sin PII (status HTTP, counts, seq; nunca valores de usuario)

    /// Una página del pull llegó: número de deltas + high-water del `server_seq`.
    static func pull(count: Int, maxSeq: Int64) {
        logger.notice("CloudSyncPull page count=\(count, privacy: .public) maxSeq=\(maxSeq, privacy: .public)")
    }

    /// No hay sesión (token ausente) o el backend devolvió 401 → no se puede bajar.
    static func pullBlockedNoSession() {
        logger.notice("CloudSyncPull blocked=no-session")
    }

    /// El backend devolvió 403 → cuenta suspendida/deshabilitada (≠401).
    static func pullAccountUnavailable() {
        logger.notice("CloudSyncPull blocked=account-unavailable (403)")
    }

    /// Fallo de transporte (red caída / timeout / no-HTTP / 200 no decodificable) → reintentar.
    static func pullTransport(reason: String) {
        logger.notice("CloudSyncPull transient transport reason=\(reason, privacy: .public)")
    }

    /// El Worker respondió con un status inesperado (5xx / 429 / 4xx) → reintentar.
    static func pullHTTP(status: Int) {
        logger.notice("CloudSyncPull transient http=\(status, privacy: .public)")
    }

    // MARK: Apply (I8f-1)

    /// Un `_ref` remoto no resolvió a una fila local (destino aún no sincronizado / no cableado en v1).
    /// NO es canario de incidente: con 6 entidades cableadas es esperable; el CSV mirror preserva los
    /// UUIDs para auto-cura cuando el destino llegue.
    static func applyDanglingRef(entity: String, column: String) {
        logger.notice("CloudSyncApply danglingRef \(entity, privacy: .public).\(column, privacy: .public)")
    }

    /// Un delta remoto se cuarentenó (entity_type aún no materializable / identidad no resoluble).
    static func applyQuarantined(entity: String, serverSeq: Int64) {
        logger.notice("CloudSyncApply quarantined \(entity, privacy: .public) serverSeq=\(serverSeq, privacy: .public)")
    }

    /// F-3: el `save()` de una página del apply FALLÓ → rollback ejecutado, cursor NO avanzó, el ciclo
    /// corta con `.transient`. Producción (fuera de #if DEBUG): un fallo repetido aquí = pull atascado.
    static func applyPageFailed(reason: String) {
        logger.notice("CloudSyncApply pageFailed reason=\(reason, privacy: .public)")
    }

    /// F-6c: un HLC del pipeline del apply (wire u outbox) NO parsea — no debe ocurrir desde nuestro
    /// server/drain. `site` nombra el punto exacto (sin PII). El caller toma la rama conservadora.
    static func hlcUnparseable(site: String) {
        logger.notice("CloudSyncApply hlcUnparseable site=\(site, privacy: .public)")
    }

    /// F-5: `clock.receive` RECHAZÓ un HLC remoto (drift >5min / counter overflow) → el reloj conserva
    /// su `latest` previo y el apply continúa. Par del canario MetricsService
    /// `cloudSyncClockReceiveRejected`.
    static func clockReceiveRejected(reason: String) {
        logger.notice("CloudSyncApply clockReceiveRejected reason=\(reason, privacy: .public)")
    }

    // MARK: Reconciliadores (I8f-2) — sin PII (ids de par/expense y counts; NUNCA montos)

    /// El reconciler del transfer-pair REPARÓ el lado perdedor de un par divergente (LWW por
    /// `SyncUnitClock['money']`).
    static func reconcilerRepairedPair(pairID: String) {
        logger.notice("CloudSyncReconciler repairedPair id=\(pairID, privacy: .public)")
    }

    /// El reconciler del split PODÓ `count` TXs virtuales negativas de un `splitExpenseID` con ambas
    /// formas presentes (regla interina real-gana; ver CloudSyncReconciler).
    static func reconcilerPrunedSplit(splitExpenseID: String, count: Int) {
        logger.notice("CloudSyncReconciler prunedSplit id=\(splitExpenseID, privacy: .public) count=\(count, privacy: .public)")
    }

    /// Un par divergente NO se tocó por falta de señal (`SyncUnitClock['money']` ausente/no parseable
    /// en algún lado, o empate exacto). Rama conservadora — nunca se adivina con un monto.
    static func reconcilerNoSignal(pairID: String) {
        logger.notice("CloudSyncReconciler noSignal id=\(pairID, privacy: .public)")
    }

    /// El pase de entidades de SISTEMA (política v1) colapsó `count` filas PERDEDORAS de una identidad lógica
    /// duplicada cross-device a su ganador determinista-global (`account` = cuentas `Grupos [moneda]`;
    /// `balanceAdjustment` = subcategoría de ajuste de saldo). Sin PII (kind + conteo).
    static func systemEntityMerged(kind: String, count: Int) {
        logger.notice("CloudSyncReconciler systemEntityMerged kind=\(kind, privacy: .public) count=\(count, privacy: .public)")
    }

    // MARK: Merkle (I8f-3) — sin PII (tablas, counts, motivos; nunca hashes de datos de usuario)

    /// La verificación se SALTÓ por la precondición A-3 (outbox pendiente / pull incompleto / fetch).
    /// NUNCA canario: la divergencia con trabajo en vuelo es ESPERADA.
    static func merkleSkippedNotQuiescent(reason: String) {
        logger.notice("CloudSyncMerkle skipped reason=\(reason, privacy: .public)")
    }

    /// Una tabla con cuarentena local se EXCLUYE de la comparación (el cliente no la materializa —
    /// compararla sería divergencia falsa; límite v1, regla 5).
    static func merkleEntitySkippedQuarantined(entity: String) {
        logger.notice("CloudSyncMerkle entitySkipped=quarantined \(entity, privacy: .public)")
    }

    /// El entityHash local ≠ remoto para `entity` (o `"root"`). Par del canario MetricsService
    /// `cloudSyncMerkleDivergence`.
    static func merkleDivergence(entity: String) {
        logger.notice("CloudSyncMerkle divergence entity=\(entity, privacy: .public)")
    }

    /// Verificación completa sin divergencias (las `entities` tablas cableadas comparadas).
    static func merkleConverged(entities: Int) {
        logger.notice("CloudSyncMerkle converged entities=\(entities, privacy: .public)")
    }

    // MARK: Runtime (I9) — transiciones de estado del orquestador (sin PII)

    /// El runtime arrancó su cadencia para la sesión actual.
    static func runtimeStarted() {
        logger.notice("CloudSyncRuntime started")
    }

    /// El runtime no arranca cadencia (sin sesión / gate de claim no proceed-like / gate del dominio).
    /// `reason` sin PII.
    static func runtimeIdle(reason: String) {
        logger.notice("CloudSyncRuntime idle reason=\(reason, privacy: .public)")
    }

    /// CANARIO (I14, P6): en `.cloud` el `currentUserID` NO tiene registro de claim → el runtime queda
    /// `.idle` (identidad no-claimeada: un Apple ID distinto en un device migrado no debe pushear el
    /// corpus del dueño). En producción cloud >0 = user-switch cross-cuenta a vigilar. Sin PII.
    static func runtimeBlockedByUnclaimedIdentity() {
        logger.notice("CloudSyncRuntime idle reason=unclaimed-identity")
    }

    /// El runtime DETUVO la cadencia (401 sesión, 403 cuenta, attest terminal, transporte). `reason` sin PII.
    static func runtimeStopped(reason: String) {
        logger.notice("CloudSyncRuntime stopped reason=\(reason, privacy: .public)")
    }

    /// Teardown de sesión invitada (M1): espejo purgado + identidad limpiada + cadencia detenida.
    static func runtimeTeardown() {
        logger.notice("CloudSyncRuntime teardownGuestSession")
    }

    // MARK: Cierre de sesión (H4) — sin PII

    /// El usuario inició el cierre de sesión. `path` = "private-reset" | "cloud-secure" |
    /// "secondary" | "icloud-groups-session" | "account-delete-cloud" |
    /// "account-delete-groups-only" (valores reales de los call-sites en `CloudSessionSignOut`).
    static func signOutStarted(path: String) {
        logger.notice("CloudSignOut started path=\(path, privacy: .public)")
    }

    /// El push-all previo al cierre en `.cloud` NO logró vaciar el outbox → cierre ABORTADO
    /// (jamás se descartan pendientes). `pending` = filas vivas restantes.
    static func signOutPushBlocked(pending: Int) {
        logger.notice("CloudSignOut push blocked pending=\(pending, privacy: .public)")
    }

    /// Camino privado (`.icloud`): sesión cerrada + reset a Welcome SIN tocar datos.
    static func signOutPrivateReset() {
        logger.notice("CloudSignOut private reset completed")
    }

    /// Camino `.cloud`: outbox vacío verificado + sesión cerrada + wipe ARMADO → esperando relaunch.
    static func signOutWipeArmed() {
        logger.notice("CloudSignOut wipe armed — awaiting relaunch")
    }

    /// BOOT: el wipe armado se ejecutó (archivos personal+sync-meta borrados, device `.icloud` fresh).
    static func signOutWipeExecuted() {
        logger.notice("CloudSignOut wipe executed at boot — device fresh")
    }

    /// G5-B: cierre de sesión SOLO-GRUPOS — outbox de grupos drenado, canal en teardown, consent
    /// limpiado, sesión cerrada + wipe del store de grupos ARMADO → esperando relaunch.
    static func signOutGroupsOnlyWipeArmed() {
        logger.notice("CloudSignOut groups-only wipe armed — awaiting relaunch (personal intact)")
    }

    /// BOOT (G5-B): el wipe solo-grupos armado se ejecutó (archivos del store de grupos borrados; el
    /// personal, sync-meta, onboarding, prefs y storageMode NO se tocaron — device sigue en `.icloud`).
    static func signOutGroupsOnlyWipeExecuted() {
        logger.notice("CloudSignOut groups-only wipe executed at boot — groups store cleared, personal intact")
    }

    /// BOOT (G5-B): el wipe solo-grupos ABORTÓ (borrado del archivo base del store de grupos falló ≠
    /// no-existe). El arm persiste → reintento en el próximo boot; el personal jamás corrió riesgo.
    static func signOutGroupsOnlyWipeAborted(reason: String) {
        logger.error("CloudSignOut groups-only wipe ABORTED reason=\(reason, privacy: .public)")
    }

    /// BOOT: el wipe armado ABORTÓ (borrado de archivo base falló ≠ no-existe). El arm
    /// persiste → reintento en el próximo boot; el par storageMode/mirrorOffArmed queda
    /// intacto (mount mirror-OFF, sin riesgo de replay hacia iCloud). >0 sostenido = disco/
    /// permisos — investigar.
    static func signOutWipeAborted(reason: String) {
        logger.error("CloudSignOut wipe ABORTED reason=\(reason, privacy: .public)")
    }

    /// Fix carrera 2026-07-14: la red del cover terminal reintentó presentar (el intento
    /// anterior no confirmó onAppear — p.ej. la sheet de Profile aún se cerraba).
    /// `net` = "signout" | "secondaryEntry". attempt=1 ocasional es NORMAL (timing del dismiss).
    static func relaunchNetRetried(net: String, attempt: Int) {
        logger.notice("CloudSignOut relaunchNet retried net=\(net, privacy: .public) attempt=\(attempt, privacy: .public)")
    }

    /// Fix carrera 2026-07-14 — RUIDOSO (error-level): la red agotó el cap del ciclo sin
    /// confirmar presentación (algo tapa el anchor perpetuamente). El blocker vivo de la
    /// matriz sigue conteniendo el router y el exit-on-background es la red final.
    /// Par MetricsService: `.relaunchNetExhausted` (canario de prod).
    static func relaunchNetExhausted(net: String) {
        logger.error("CloudSignOut relaunchNet EXHAUSTED net=\(net, privacy: .public) — cover terminal sin presentar tras el cap del ciclo")
    }

    /// Decisión owner UX 2026-07-14: la app fue a background con un relaunch terminal
    /// pendiente → el proceso termina limpio (`exit(0)`); el próximo launch corre el
    /// cleanup pre-mount. Último rastro del proceso — se emite ANTES del exit.
    static func relaunchExitOnBackground() {
        logger.notice("CloudSignOut relaunch exit-on-background — proceso terminado limpio; el próximo launch corre el cleanup")
    }

    // MARK: Sesión secundaria (M1) — sin PII

    /// BOOT: el wipe secundario armado se ejecutó (archivos `-Secondary` borrados, descriptor
    /// limpiado, flags de onboarding reseteados → Welcome; los archivos del DUEÑO intactos).
    static func secondaryWipeExecuted() {
        logger.notice("CloudSecondary wipe executed at boot — secondary files deleted, owner intact")
    }

    /// BOOT: el wipe secundario ABORTÓ (borrado del archivo base `-Secondary` falló ≠ no-existe).
    /// El arm y el descriptor persisten → reintento en el próximo boot (mientras tanto el mount
    /// sigue siendo el secundario — sin riesgo para el dueño). >0 sostenido = disco/permisos.
    static func secondaryWipeAborted(reason: String) {
        logger.error("CloudSecondary wipe ABORTED reason=\(reason, privacy: .public)")
    }

    /// BOOT: la purga de ENTRADA de la sesión secundaria corrió (superficies App Group limpiadas,
    /// notificaciones del dueño canceladas, healing de flags si un kill se comió la ventana 2→3).
    static func secondaryEntryPurged() {
        logger.notice("CloudSecondary entry purge executed — App Group surfaces cleared")
    }

    /// ENTRADA armada (M1): claim + descriptor + flags escritos en orden — la sesión secundaria
    /// queda pendiente del relaunch (el boot siguiente monta el store `-Secondary`).
    static func secondaryEntryArmed() {
        logger.notice("CloudSecondary entry ARMED — descriptor persisted, awaiting relaunch")
    }

    /// BELT (M1): el efecto `.writeBeacon` se SUPRIMIÓ porque hay sesión secundaria activa —
    /// el faro vive en el iCloud KV del DUEÑO. Inalcanzable por diseño; si suena, un path de
    /// claim de migración corrió bajo la secundaria (bug — investigar).
    static func secondaryBeaconWriteSuppressed() {
        logger.error("CloudSecondary beacon write SUPPRESSED — migration claim path ran under secondary session (bug)")
    }

    /// GUARD de mount-mismatch (M1, crítico): el runtime intentó arrancar con el descriptor
    /// secundario activo pero el proceso montó el store del DUEÑO (ventana de entrada pre-relaunch)
    /// → bloqueado. Sin el guard, el drain pushearía la History del dueño a la cuenta entrante.
    /// Par del canario MetricsService `cloudSecondaryMountMismatchBlocked` (dedupeado por proceso).
    static func runtimeBlockedByMountMismatch() {
        logger.error("CloudSecondary runtime BLOCKED by mount-mismatch — descriptor active, owner store mounted (awaiting relaunch)")
    }

    /// Guard de recreación (§d.5 A1): la tabla `SyncQuarantine` se recreó vacía (testigo>0, count==0) →
    /// serverSeqCursor forzado a 0 (re-pull completo).
    static func quarantineTableRecreated() {
        logger.notice("CloudSyncQuarantine tableRecreated — forcing full re-pull (serverSeq=0)")
    }

    /// Drenaje del upgrade path: `count` filas de cuarentena se re-aplicaron (entidad recién cableada).
    static func quarantineDrained(count: Int) {
        logger.notice("CloudSyncQuarantine drained count=\(count, privacy: .public)")
    }

    /// Remediación Merkle (E-bis): tras `.diverged`, se reseteó el cursor + re-pull (una vez por sesión).
    static func merkleRemediated() {
        logger.notice("CloudSyncMerkle remediated — reset cursor + re-pull (once per session)")
    }

    /// Purga de History (§i.6, doble-DARK): `count` transacciones borradas por delante del corte seguro.
    /// También lo emite el trigger del spike device S2 (`-spike-s2-purge-history`).
    static func historyPurged(count: Int) {
        logger.notice("CloudSync historyPurged count=\(count, privacy: .public)")
    }

    // MARK: Auth (I7c) — transiciones de la sesión real (sin PII: jamás token/email/sub)

    /// Sign in with Apple → `signInWithIdToken` exitoso: sesión de Supabase creada.
    static func authSignedIn() {
        logger.notice("CloudSyncAuth signedIn")
    }

    /// El sign-in falló. `reason` sin PII (`apple-authorization` / `idtoken-exchange`).
    static func authSignInFailed(reason: String) {
        logger.notice("CloudSyncAuth signInFailed reason=\(reason, privacy: .public)")
    }

    /// Sign-out local. `reason` sin PII (`user` / `credential-revoked`).
    static func authSignedOut(reason: String) {
        logger.notice("CloudSyncAuth signedOut reason=\(reason, privacy: .public)")
    }

    /// El sign-out del SDK lanzó (no debería) — la sesión local podría seguir presente.
    static func authSignOutFailed() {
        logger.notice("CloudSyncAuth signOutFailed")
    }

    /// La credencial de Apple fue revocada (#23 mitigación cliente) → se cierra la sesión local.
    static func authCredentialRevoked() {
        logger.notice("CloudSyncAuth credentialRevoked — signing out locally")
    }

    /// No se pudo obtener un access token vigente (refresh falló / sin sesión) para una llamada de sync.
    static func authAccessTokenUnavailable() {
        logger.notice("CloudSyncAuth accessTokenUnavailable")
    }

    // MARK: SIWA revoke 5.1.1(v) (B1) — canje/custodia/revocación del refresh token de Apple (sin PII:
    // JAMÁS el code/token — solo motivos)

    /// El canje post-sign-in quedó custodiado (par token+appleUserID en el Keychain).
    static func siwaExchangeStored() {
        logger.notice("CloudSyncAuth siwaExchangeStored")
    }

    /// El canje falló (`no-code` / `no-jwt` / `exchange` / `keychain`) → este sign-in queda sin token
    /// revocable (best-effort; re-sign-in lo cura). Par del canario MetricsService `siwaExchangeFailed`.
    static func siwaExchangeFailed(reason: String) {
        logger.notice("CloudSyncAuth siwaExchangeFailed reason=\(reason, privacy: .public)")
    }

    /// Google Sign-In (sesión 1): el PAR (googleUserID, sub) NO se escribió tras un sign-in exitoso.
    /// `reason` sin PII (`no-google-user-id` / `no-sub` / `keychain`) — AJUSTE #1 del plan: jamás un
    /// par incompleto; sin par, el `disconnect()` de sesión 3 hace skip natural (población ~0).
    static func googlePairCaptureSkipped(reason: String) {
        logger.notice("CloudSyncAuth googlePairCaptureSkipped reason=\(reason, privacy: .public)")
    }

    /// El claim devolvió `profile.provider` DISTINTO del provider de la sesión que claimeó.
    /// Por H4 (GoTrue linkea identidades con mismo email al MISMO sub) esto es identity-linking
    /// LEGÍTIMO — observabilidad pura: JAMÁS alerta ni canario. Sin PII (solo el nombre del provider).
    static func claimProfileProviderDiffers(profileProvider: String) {
        logger.notice("CloudSyncAuth claimProfileProviderDiffers profileProvider=\(profileProvider, privacy: .public)")
    }

    /// Revoke saltado: no hay par custodiado (sesión previa al capture — población cero — o canje fallido).
    static func siwaRevokeSkippedNoToken() {
        logger.notice("CloudSyncAuth siwaRevokeSkippedNoToken")
    }

    /// Revoke saltado: el par pertenece a OTRO appleUserID (AJUSTE #1 — hazard cross-cuenta M1). Ni POST
    /// ni limpieza: el par sigue siendo válido para su dueño.
    static func siwaRevokeSkippedStaleToken() {
        logger.notice("CloudSyncAuth siwaRevokeSkippedStaleToken")
    }

    /// Revocación 5.1.1(v) completada (Apple 200) + par limpiado del Keychain.
    static func siwaRevoked() {
        logger.notice("CloudSyncAuth siwaRevoked")
    }

    /// El revoke falló (`no-jwt` / `revoke` [timeout/red/502]) — best-effort: el borrado NO se bloquea;
    /// el par NO se limpia (un retry del borrado lo reintenta). Par del canario `siwaRevokeFailed`.
    static func siwaRevokeFailed(reason: String) {
        logger.notice("CloudSyncAuth siwaRevokeFailed reason=\(reason, privacy: .public)")
    }

    // MARK: Google revoke (sesión 3 Google Sign-In — simetría 5.1.1(v); sin PII: JAMÁS googleUserID/sub
    // en claro — solo motivos)

    /// Revoke de Google saltado — estado LEGÍTIMO (sin canario, SIN limpiar el par). `reason`:
    /// `no-pair` (sin par custodiado — cuenta que jamás firmó con Google, el caso masivo) /
    /// `stale-pair` (par de OTRA cuenta Supabase — hazard cross-cuenta M1, match #1 del §0) /
    /// `no-sdk-session` (sin sesión SDK restaurable, p.ej. post-reinstalación — grant vivo, token inerte) /
    /// `stale-sdk-session` (la sesión del SDK es de OTRO humano que el par — match #2 del §0).
    static func googleRevokeSkipped(reason: String) {
        logger.notice("CloudSyncAuth googleRevokeSkipped reason=\(reason, privacy: .public)")
    }

    /// `disconnect()` completado (grant OAuth de Google revocado + SDK firmado out) + par limpiado.
    static func googleDisconnected() {
        logger.notice("CloudSyncAuth googleDisconnected")
    }

    /// El disconnect falló (`disconnect` [rechazo del SDK o timeout, colapsados]) — best-effort: el
    /// borrado NO se bloquea; el par NO se limpia. Par del canario `googleRevokeFailed`.
    static func googleRevokeFailed(reason: String) {
        logger.notice("CloudSyncAuth googleRevokeFailed reason=\(reason, privacy: .public)")
    }

    // MARK: Migración (I10-wiring) — journal + orquestador (sin PII: solo fases, motivos, contadores)

    /// Una transición se journaleó (fase + efectos pendientes). `phase` es el `MigrationPhase` (sin PII).
    static func migrationJournaled(phase: String) {
        logger.notice("CloudSyncMigration journaled phase=\(phase, privacy: .public)")
    }

    /// La máquina rechazó el par (fase, evento) → no-op, journal intacto. Delata un bug de secuenciación.
    static func migrationInvalidTransition(from: String, event: String) {
        logger.notice("CloudSyncMigration invalidTransition from=\(from, privacy: .public) event=\(event, privacy: .public)")
    }

    /// RUIDOSO a propósito (fuera de #if DEBUG, patrón SaveBreadcrumb): el `phaseData` journaleado NO
    /// decodifica (rot del enum `MigrationPhase`) → fallback `.notStarted`. Si dispara en mid-cutover real,
    /// el gate §i.9 leería "estable" — este rastro lo nombra sin dSYM.
    static func migrationPhaseDecodeFailed() {
        logger.notice("CloudSyncMigration phaseDecodeFailed — journal ilegible, fallback notStarted (gate §i.9 leería estable)")
    }

    /// El `POST /account/claim` devolvió un outcome NO-success recuperable (sessionExpired/transient) →
    /// stop SIN evento (journal en `claimingMigration`); un `resume()` re-claima idempotente. JAMÁS rollback.
    static func migrationClaimNoSuccess(reason: String) {
        logger.notice("CloudSyncMigration claimNoSuccess reason=\(reason, privacy: .public) — stop sin evento (retomable)")
    }

    /// El claim devolvió 403 (cuenta suspendida) → stop SIN evento (breadcrumb dedicado, ≠401).
    static func migrationAccountUnavailable() {
        logger.notice("CloudSyncMigration accountUnavailable (403) — stop sin evento (retomable)")
    }

    /// Un efecto declarativo lanzó al ejecutarse → queda journaled en `pendingEffectsData` + stop; un
    /// `resume()` lo re-ejecuta. `effect` = raw value del `MigrationEffect` (sin PII).
    static func migrationEffectFailed(effect: String, reason: String) {
        logger.notice("CloudSyncMigration effectFailed effect=\(effect, privacy: .public) reason=\(reason, privacy: .public) — journaled, retomable")
    }

    /// El gate de quiescencia del import no se cumplió en el tope → el runner NO procede (retomable, sin
    /// tocar el journal — ni un solo `save()`).
    static func migrationQuiescenceTimeout() {
        logger.notice("CloudSyncMigration quiescenceTimeout — no procede (retomable)")
    }

    /// #36 (H1): la pre-espera de quiescencia del resume arrancó (import no quiescente al boot/rekick) —
    /// el controller pollea hasta 300s ANTES de tocar el runner; la card de Almacenamiento lo muestra.
    static func migrationResumeAwaitingImport() {
        logger.notice("CloudSyncMigration resumeAwaitingImport — pre-espera de quiescencia (tope 300s, estado visible)")
    }

    /// #36 (H1): la pre-espera venció el tope de 300s → el resume queda aparcado VISIBLE (card con
    /// estado honesto + Retomar); lo reintentan el re-kick de foreground y el próximo boot.
    static func migrationResumeDeferredAwaitingImport() {
        logger.notice("CloudSyncMigration resumeDeferredAwaitingImport — tope 300s vencido, aparcado visible (foreground/boot reintentan)")
    }

    /// #36 (H1): el foreground re-kickeó una migración/reversa APARCADA (journal transicional o efectos
    /// pendientes con el controller ocioso). `phase` = fase journaleada (sin PII).
    static func migrationForegroundRekick(phase: String) {
        logger.notice("CloudSyncMigration foregroundRekick phase=\(phase, privacy: .public) — re-kick del resume aparcado")
    }

    /// H-2026-07-17-5: el poll de la pantalla de adopt del Welcome detectó el drive APARCADO
    /// (fase transicional con el controller ocioso N ticks) y re-condujo solo por el camino del
    /// boot (`resumeIfNeeded`). `attempt` = intento auto (1…max) desde el último avance; sin PII.
    static func welcomeAdoptAutoResume(attempt: Int, phase: String) {
        logger.notice("CloudSyncMigration welcomeAdoptAutoResume attempt=\(attempt, privacy: .public) phase=\(phase, privacy: .public) — auto-resume del adopt aparcado en Welcome")
    }

    /// H-2026-07-17-5: los autos se agotaron sin avance → el botón Retomar manual queda visible
    /// (canario: si aparece seguido, el auto-resume no basta — investigar la causa del park).
    static func welcomeAdoptAutoResumeExhausted(phase: String) {
        logger.notice("CloudSyncMigration welcomeAdoptAutoResumeExhausted phase=\(phase, privacy: .public) — autos agotados, Retomar manual visible")
    }

    /// w3: la captura de coordenadas CloudKit `(recordName, zoneName, ownerName)` terminó. Conteos
    /// tri-estado (captured/exportPending/noMetadata/failed). Sin PII (solo counts). Filas sin captura NO
    /// bloquean la fase (`assigningIdentity` es idempotente/re-ejecutable; una fila jamás exportada no
    /// tiene record que borrar en la reversa — §b.5 born-cloud analogía).
    static func migrationIdentityCaptured(captured: Int, exportPending: Int, noMetadata: Int, failed: Int) {
        logger.notice("CloudSyncMigration identityCaptured captured=\(captured, privacy: .public) exportPending=\(exportPending, privacy: .public) noMetadata=\(noMetadata, privacy: .public) failed=\(failed, privacy: .public)")
    }

    /// w4: una página del snapshot quedó CONFIRMADA (todas sus filas + incrementales subidas y purgadas).
    /// `table` = la tabla actual del cursor; `rows` = filas enqueuadas en la página. Sin PII.
    static func migrationSnapshotPageConfirmed(table: String, rows: Int) {
        logger.notice("CloudSyncMigration snapshotPageConfirmed table=\(table, privacy: .public) rows=\(rows, privacy: .public)")
    }

    /// w5/w6/w8: un efecto/paso de la migración aún NO está cableado (cutover/reconcile/rollback/adopt) →
    /// el runner lo deja journaled (retomable). `step` = nombre del efecto/paso (sin PII).
    static func migrationExecutorNotWired(step: String) {
        logger.notice("CloudSyncMigration executorNotWired step=\(step, privacy: .public) — journaled, retomable")
    }

    /// w5: `verifyIntegrity` devolvió un `skipped` con un reason DESCONOCIDO (contrato futuro) → el mapping
    /// toma la rama conservadora `networkTimeout` (nunca crashea ni consume un retry de mismatch). Canario.
    static func migrationVerifyUnknownReason(reason: String) {
        logger.notice("CloudSyncMigration verifyUnknownReason reason=\(reason, privacy: .public) — networkTimeout conservador")
    }

    // MARK: Cutover (I10-wiring w6, §g.4)

    /// w6 paso 1: `migration_progress('cutover')` confirmó `profiles.migrated_at` (guard líder OK).
    static func migrationCutoverConfirmed() {
        logger.notice("CloudSyncMigration cutoverConfirmed — profiles.migrated_at estampado (guard líder OK)")
    }

    /// w6 paso 1: el guard líder rechazó (`other_leader`) → este device fue USURPADO (lease-takeover) →
    /// el runner corta retomable y converge a follower.
    static func migrationCutoverOtherLeader() {
        logger.notice("CloudSyncMigration cutoverOtherLeader — usurpado, corta retomable → follower")
    }

    /// w6 paso 1: `migration_progress` devolvió otro `ok:false` (no_profile/not_in_progress/bad_action) o
    /// transient/401 → stop retomable. `reason` sin PII.
    static func migrationCutoverRejected(reason: String) {
        logger.notice("CloudSyncMigration cutoverRejected reason=\(reason, privacy: .public) — stop retomable")
    }

    /// w6 paso 2: `storageMode=.cloud` persistido (`persistLocalMode`). El próximo relanzamiento montará el
    /// store personal con el mirror OFF.
    static func migrationLocalModePersisted() {
        logger.notice("CloudSyncMigration localModePersisted — storageMode=.cloud (mirror OFF tras relaunch)")
    }

    /// w6 paso 3: marcador `CloudMigrationMarker` insertado + guardado (el mirror vivo lo exporta ASYNC).
    static func migrationMarkerWritten(serverSeqCut: Int64) {
        logger.notice("CloudSyncMigration markerWritten serverSeqCut=\(serverSeqCut, privacy: .public) — export ASYNC pendiente")
    }

    /// w6 paso 3→4: el gate de EXPORT del marcador cortó — el marcador aún NO llegó a CloudKit
    /// (`ZCKRECORDNAME` NULL). Apagar el mirror ahora lo perdería → se espera al próximo resume/poll.
    static func migrationMarkerExportPending() {
        logger.notice("CloudSyncMigration markerExportPending — marcador sin exportar aún, mirror NO se apaga (retomable)")
    }

    /// w6 paso 4: flag `relaunchRequested` persistido. iOS no se auto-relanza — el relanzamiento asistido
    /// con UI es I14; en DEBUG el panel indica MATAR Y RELANZAR. El proceso NO se mata solo.
    static func migrationRelaunchRequested() {
        logger.notice("CloudSyncMigration relaunchRequested — persiste flag; el proceso NO se mata solo (relaunch asistido = I14)")
    }

    /// w6/w8 (efecto de `done`): `migration_progress('complete')` OK. La capa de RED del líder (w8: drain
    /// de History + push del residual) corrió ANTES de este complete; si rescató algo lo delata
    /// `leaderOrphanReconciled` + su canario.
    static func migrationReconcileDeferred() {
        logger.notice("CloudSyncMigration cutoverComplete — complete OK (barrido de red del líder corrió antes)")
    }

    /// w8 (capa de RED del líder, §g.4 SERIO 1 v3): el barrido residual al entrar a `done` rescató writes
    /// huérfanos de la ventana de cutover (drain de History + push). `count` > 0 = la ventana existió en la
    /// práctica (el canario de telemetría acompaña). Sin PII (solo el conteo).
    static func migrationLeaderOrphanReconciled(count: Int) {
        logger.notice("CloudSyncMigration leaderOrphanReconciled count=\(count, privacy: .public) — la capa de red rescató writes de la ventana de cutover")
    }

    /// El efecto `.rollback` completó (pre-cutover el device ya estaba intacto — no-op observable; el
    /// journal en `failedRollback` + los campos scoped limpiados por el runner son el estado final).
    static func migrationRollbackCompleted() {
        logger.notice("CloudSyncMigration rollbackCompleted — device intacto (el mirror nunca se apagó)")
    }

    /// Auto-cura del backfill (bug device 2026-07-10, residual A3 materializado): N filas VIVAS
    /// compartían syncID (rebind viejo sobre anclas idénticas) y se re-acuñaron. >0 en un corpus real =
    /// el residual A3 NO era tan raro como se asumió. Sin PII (solo el conteo).
    static func identityCollisionHealed(count: Int) {
        logger.notice("CloudSyncMigration identityCollisionHealed count=\(count, privacy: .public) — filas vivas con syncID compartido re-acuñadas")
    }

    /// w8 (DIFERIDOS #30 / §g.4 S8): el drenaje único iKV→outbox del cutover corrió en el device LÍDER.
    /// `failures` > 0 = I/O del outbox falló para algunas keys → el sentinel NO se estampó y el próximo
    /// boot reintenta (LWW absorbe el re-enqueue). Sin PII (solo conteos).
    static func prefsCutoverDrained(count: Int, failures: Int) {
        logger.notice("CloudSyncMigration prefsCutoverDrained count=\(count, privacy: .public) failures=\(failures, privacy: .public)")
    }

    /// #37 (H3): la reversa retiró los sentinels del drenaje iKV→outbox al persistir `.icloud`
    /// (`.persistICloudMode`) — una RE-migración futura vuelve a drenar. Sin PII (solo el conteo).
    static func reversePrefsDrainSentinelCleared(count: Int) {
        logger.notice("CloudSyncReverse prefsDrainSentinelCleared count=\(count, privacy: .public) — re-migración futura re-drena iKV")
    }

    // MARK: Reversa (I11-2, §h nube→CloudKit) — sin PII (solo fases, conteos, motivos de transporte)

    /// §h desatascador: `performReverseClaim` encontró OTRO device ya reverse-líder → el runner emite
    /// `reverseOtherLeader(returnTo:)` y vuelve al origin (done/notStarted). v1 single-device.
    static func reverseOtherLeader() {
        logger.notice("CloudSyncReverse otherLeader — otro device es reverse-líder, vuelve al origin")
    }

    /// §h.3 `deletingZombies`: el barrido tombstones-del-backend-vs-filas-vivas borró `count` filas vivas
    /// que un re-import de CloudKit congelado había RESUCITADO (0 en el caso normal, token vigente → replay
    /// del mirror cubre todo; load-bearing solo en el edge de token inválido). Sin PII (solo el conteo).
    static func reverseZombiesSwept(count: Int) {
        logger.notice("CloudSyncReverse zombiesSwept count=\(count, privacy: .public)")
    }

    /// §h.3 `rebindingUUIDs`: verificación (v1, sin deletes — el recordName≠UUID de dominio, S5) de las
    /// identidades con `lastReboundAt` que aún portan una fila viva. `count` = rebinds verificados.
    static func reverseRebindsVerified(count: Int) {
        logger.notice("CloudSyncReverse rebindsVerified count=\(count, privacy: .public)")
    }

    /// §h.3 `dedupHealed`: AUTO-CURA (I11-4) de copias idénticas de Account/Tag. `count` = filas PERDEDORAS
    /// fusionadas+borradas (0 = nada que curar, idempotente). Sin PII (solo el conteo).
    static func reverseDuplicatesHealed(count: Int) {
        logger.notice("CloudSyncReverse duplicatesHealed count=\(count, privacy: .public)")
    }

    /// §h `reverseUpload`: el muestreo CKIdentityCapture ve `count` filas aún sin drenar a CloudKit
    /// (exportPending + noMetadata) → la reversa espera retomable. Diagnóstico para el panel si se atasca.
    static func reverseUploadPending(count: Int) {
        logger.notice("CloudSyncReverse uploadPending count=\(count, privacy: .public) — filas sin exportar aún, retomable")
    }

    /// §h efecto de cierre: `count` `CloudMigrationMarker` borrados del store personal (el mirror VIVO
    /// exporta el delete). Idempotente (0 si ya no había marcador).
    static func reverseMarkerDeleted(count: Int) {
        logger.notice("CloudSyncReverse markerDeleted count=\(count, privacy: .public)")
    }

    /// §h efecto de cierre: el faro `cloudAccountLinked` se limpió del iCloud KV (device revirtió a iCloud).
    static func reverseBeaconCleared() {
        logger.notice("CloudSyncReverse beaconCleared")
    }

    /// §h efecto de cierre: `storageMode=.icloud` + `mirrorOffArmed=false` persistidos JUNTOS (invariante SERIO 1).
    static func reverseModePersisted() {
        logger.notice("CloudSyncReverse modePersisted — storageMode=.icloud + mirrorOffArmed=false (par)")
    }

    /// §h `mountMirrorAndRelaunch`: se DESARMÓ `mirrorOffArmed` (manteniendo `.cloud` → decisión iCloudMirror
    /// al próximo launch) + se pidió relaunch asistido. iOS no se auto-relanza — el proceso NO se mata solo.
    static func reverseRelaunchRequested() {
        logger.notice("CloudSyncReverse relaunchRequested — mirror-off desarmado; el proceso NO se mata solo (relaunch asistido = I14)")
    }

    /// §h `deletingZombies`: no había fuente de `serverSeqCut` (ni marcador ni journal) → el barrido enumera
    /// desde `since 0` (correcto, solo más caro). Canario de configuración, no de error.
    static func reverseSeqCutFallbackZero() {
        logger.notice("CloudSyncReverse seqCutFallbackZero — barrido desde since 0 (correcto, más caro)")
    }

    /// §h `reverseFreezeBackend` (I11-3): `reverse_freeze` OK — `profiles.reverse_frozen_at` estampado
    /// (guard reverse-líder, idempotente). El backend dejó de ser fuente de verdad para este device.
    static func reverseBackendFrozen() {
        logger.notice("CloudSyncReverse backendFrozen — reverse_frozen_at estampado (guard líder OK)")
    }

    /// §h `reverseFreezeBackend` (I11-3): `reverse_freeze` NO aplicó (otherLeader/rejected/401/red) →
    /// el runner corta retomable SIN evento. `reason` sin PII.
    static func reverseFreezeRejected(reason: String) {
        logger.notice("CloudSyncReverse freezeRejected reason=\(reason, privacy: .public) — corta retomable")
    }

    /// §h cuarteto de cierre (I11-3): `reverse_complete` OK — `reverse_in_progress=false` +
    /// `reverted_at` estampado server-side (`migrated_at` INTACTO, §h.4). La reversa cerró en el backend.
    static func reverseCompleteConfirmed() {
        logger.notice("CloudSyncReverse completeConfirmed — rip=false + reverted_at estampado (migrated_at intacto)")
    }

    /// §h cuarteto de cierre (I11-3): `reverse_complete` NO aplicó → el efecto THROWEA y queda
    /// journaled-pendiente retomable (patrón del complete de la ida). `reason` sin PII.
    static func reverseCompleteRejected(reason: String) {
        logger.notice("CloudSyncReverse completeRejected reason=\(reason, privacy: .public) — journaled, retomable")
    }

    /// §h `reverseRollback` (I11-3): `reverse_abort` OK — backend DES-congelado (`rip=false` +
    /// `reverse_frozen_at=null`; `reverted_at` queda null). El estado local ya era terminal estable.
    static func reverseAborted() {
        logger.notice("CloudSyncReverse aborted — backend des-congelado (rip=false, frozen_at=null)")
    }

    /// §h `reverseRollback` (I11-3) — RUIDOSO: el `reverse_abort` fue RECHAZADO (lease usurpado /
    /// rejected) pero el efecto se COMPLETA igual (decisión I11-3: el estado local ya es terminal estable;
    /// re-lanzar perpetuo repetiría el bug-class del rollback de la ida, device 2026-07-10). El backend
    /// puede quedar `rip=true` — un `reverse_claim` posterior es idempotente-ok. `reason` sin PII.
    static func reverseAbortRejectedButCompleted(reason: String) {
        logger.error("CloudSyncReverse abortRejectedButCompleted reason=\(reason, privacy: .public) — efecto completado igual; el backend puede quedar rip=true")
    }

    /// §h residual (canario v1 SIN reparación): metadata CloudKit huérfana (record cuyo delete se perdió del
    /// History por purga + token que no expiró) → zombie invisible localmente. HOY inalcanzable (la purga
    /// jamás corrió en `.cloud`, flags DARK). El SCAN de side-table YA está cableado
    /// (`CKIdentityCapture.scanOrphanMetadata`, read-only); la REPARACIÓN queda diferida al diseño
    /// multi-device (¿re-subir tombstone? ¿delete CKRecord dirigido? — D4). Sin PII (solo el conteo).
    static func reverseOrphanMetadata(count: Int) {
        logger.notice("CloudSyncReverse orphanMetadata count=\(count, privacy: .public) — canario sin reparación v1 (scan cableado)")
    }

    // MARK: Heartbeat del lease (I14-pre, residual pendiente #3) — best-effort, sin PII

    /// I14-pre: `migration_progress('heartbeat')` OK — `profiles.migration_updated_at` refrescado durante un
    /// paso largo (upload/drain) → el lease de 60 min sigue vivo, el líder no queda usurpable a mitad.
    static func migrationLeaseHeartbeat() {
        logger.notice("CloudSyncMigration leaseHeartbeat — migration_updated_at refrescado (lease vivo)")
    }

    /// I14-pre: el heartbeat NO aplicó (otherLeader/rejected/401/red) — BEST-EFFORT, NO corta el paso (el
    /// guard real del lease vive en cutover/freeze/complete). `reason` sin PII. Pre-deploy del RPC un
    /// `bad_action`/400 cae aquí como ruido esperado (documentado en qa/cloud/README).
    static func migrationLeaseHeartbeatRejected(reason: String) {
        logger.notice("CloudSyncMigration leaseHeartbeatRejected reason=\(reason, privacy: .public) — best-effort, no corta el paso")
    }

    // MARK: Adopt-reconcile (DIFERIDOS #30, mecanismo v1 DARK) — sin PII (solo conteos)

    /// DIFERIDOS #30: el adopt de un device `.icloud`→`.cloud` rescató `count` filas huérfanas de la ventana
    /// de cutover (identidad local ∉ backend → upload full-row). `identityAssigned` = filas sin syncID a las
    /// que el backfill acuñó identidad fresca (todas caen a huérfanas). >0 = la ventana multi-device existió
    /// en la práctica (esperado raro; el canario de telemetría acompaña). Sin PII (solo conteos).
    static func adoptOrphanReconciled(count: Int, identityAssigned: Int) {
        logger.notice("CloudSyncAdopt orphanReconciled count=\(count, privacy: .public) identityAssigned=\(identityAssigned, privacy: .public) — el adoptador rescató writes de la ventana de cutover")
    }

    /// DIFERIDOS #30 (guard anti mass-upload): la enumeración del backend llegó VACÍA (verificada completa
    /// contra merkle) teniendo el device huérfanas locales y/o filas sin identidad → NO se sube ni se muta
    /// nada — el guard corre ANTES del backfill (un adopt legítimo `existing_stable` implica backend POBLADO;
    /// backend realmente vacío = decisión de producto de I14, y el costo del falso positivo sería subir el
    /// corpus entero). >0 = revisar sesión/pull. Sin PII (solo el conteo de filas descartadas).
    static func adoptReconcileAbortedEmptyBackend(orphans: Int) {
        logger.notice("CloudSyncAdopt reconcileAbortedEmptyBackend orphans=\(orphans, privacy: .public) — enumeración del backend vacía; upload abortado (anti mass-upload)")
    }

    /// DIFERIDOS #30 (SERIO 1 del review): la enumeración del backend resultó INCOMPLETA — el count de filas
    /// VIVAS del Merkle (`/sync/merkle`) para una tabla es MAYOR que lo enumerado por el pull read-only
    /// (página vacía prematura / paginación no-monótona con 200 OK). Sin esta verificación positiva, filas
    /// no-enumeradas lucirían huérfanas y su re-upload con HLC fresco PISARÍA contenido más nuevo del
    /// backend. → `.transient` retomable (sesgo a abortar, jamás a proceder). Sin PII (tabla + conteos).
    static func adoptReconcileEnumerationIncomplete(table: String, expected: Int, got: Int) {
        logger.notice("CloudSyncAdopt enumerationIncomplete table=\(table, privacy: .public) expected=\(expected, privacy: .public) got=\(got, privacy: .public) — merkle declara más vivas que lo enumerado; transient retomable")
    }
}

// MARK: - CloudSyncEngine

@MainActor
final class CloudSyncEngine {

    // MARK: Constantes de captura

    /// Autor del CONTEXTO con el que el motor persiste sus propias filas de outbox. La captura DESCARTA
    /// las transacciones de History con este autor → anti-auto-captura (echo suppression): cuando el
    /// apply de cambios remotos (I8) escriba entidades personales bajo este autor, no se re-capturarán.
    static let outboxSaveAuthor = "CloudSyncOutbox"

    /// Los 16 entity names del store PERSONAL. La captura DESCARTA todo cambio cuyo entity name NO esté
    /// aquí — anti-fuga de Grupos. El History token es por-CONTAINER (personal + grupos + sync-meta en
    /// un solo ModelContainer), así que este filtro es PERMANENTE (no una optimización): sin él, los
    /// cambios de los `Split*` (store de grupos) se colarían al backend personal.
    ///
    /// Las 16 tienen identidad de sync y se TRADUCEN a outbox (I12 cableó las 10 restantes sobre las
    /// 6 originales de I3 — ver `SyncEntityType` y `EntityEmissionMap`). Anclado contra
    /// `personalSchema` por `CloudSyncSchemaParityTests`.
    static let personalEntityNames: Set<String> = [
        "Category",
        "Subcategory",
        "Tag",
        "Account",
        "TransactionItem",
        "Budget",
        "ExchangeRate",
        "FavoritePayment",
        "ScheduledPayment",
        "InboxDraft",
        "MerchantMemory",
        "NotificationItem",
        "CashFlowPlan",
        "CashFlowLine",
        "CashFlowOverride",
        "GroupBridgePreference",
    ]

    // MARK: Clasificación del reason de tombstone (§c.1) — 100% DRAIN-SIDE

    /// Entity names PADRE de una cascada MANUAL cuyos hijos syncables se borran en el MISMO `save()`
    /// (= misma transacción de History). Si una transacción borra uno de estos, los tombstones de las
    /// 6 entidades syncables producidos en ESA transacción se clasifican `cascade`.
    ///
    /// Inventario VERIFICADO contra `EntityDeletionService.swift` (2026-07-07):
    ///   • `ScheduledPayment` — `deleteScheduledPayment` borra `InboxDraft` (línea 253) y
    ///     `TransactionItem` (línea 274) y luego el pago (línea 285) en UN solo `save()`. Ambos hijos
    ///     SON syncables → `cascade`. ÚNICO padre verificado.
    /// EXCLUIDOS (no borran hijos syncables o no son deletes):
    ///   • `deleteTag` (Tag NO es syncable; los TX/drafts/favoritos se ACTUALIZAN, no se borran → upsert).
    ///   • `deleteCategory`/`deleteSubcategory`/`deleteAccount`/`deleteBudget` (los hijos de Account/
    ///     Subcategory son `.nullify`, no deletes de syncables; el propio Category/Account/Subcategory
    ///     borrado es el delete de nivel superior pedido por el usuario, no una cascada).
    ///   • `SubcategoryTransferViewModel.deleteTransactions` (borra TX sin borrar un padre en el mismo
    ///     save → bulk del usuario = `user`).
    ///   • `CategoryDeduplicationService` (I9 → `dedup`) / `DataWipeService` (I12 → `wipe`): sin señal de
    ///     call-site hoy → caen en `user`/`cascade`. Comentario-guardia: I9/I12 marcarán un author
    ///     dedicado y esta clasificación se afinará entonces (el reason es metadata de auditoría — la
    ///     clasificación conservadora NO compromete correctness: el backend mantiene `deleted=true` igual).
    ///
    /// I12 commit B: `CashFlowPlan` y `CashFlowLine` AHORA son syncables (identidad = `id`) y cascadean
    /// deletes a syncables (`CashFlowPlan .cascade→ CashFlowLine .cascade→ CashFlowOverride`) → se añaden
    /// como cascade-parents (mismo trato conservador que `ScheduledPayment`; audit-only, correctness-neutral).
    static let cascadeParentEntityNames: Set<String> = [
        "ScheduledPayment",
        "CashFlowPlan",
        "CashFlowLine",
    ]

    /// Authors cuyas transacciones se clasifican `migration`. Bucket por COMPLETITUD (§c.1): hoy solo
    /// `outboxSaveAuthor` caería aquí, pero sus transacciones ya se DESCARTAN por echo-suppression
    /// antes de clasificar → de facto inalcanzable. Reservado para el author dedicado de la migración
    /// (I10). El delete-vs-cascade se decide DESPUÉS de este gate.
    static let migrationAuthors: Set<String> = [
        outboxSaveAuthor,
    ]

    // MARK: Estado

    /// Reloj HLC en-memoria de esta instancia (fresco; persistencia + `receive()` en I8).
    private var clock: HLCClock

    /// Contador de vueltas de drain (para el breadcrumb).
    private var drainSeq = 0

    /// Número de gaps de identidad observados (delete sin syncID preservado). Expuesto para tests
    /// (el logger no es asertable). Acumula a lo largo de la vida de la instancia.
    private(set) var identityGapCount = 0

    /// D4 (I12): nº de UPDATEs que mutaron el keypath de IDENTIDAD de una entidad con identidad = UUID
    /// persistido (regeneración detectada; §b.4/DIFERIDOS #29). Expuesto para tests (el logger no es
    /// asertable). Acumula a lo largo de la vida de la instancia.
    private(set) var identityMutationObservedCount = 0

    // MARK: Guard del token de History (HALLAZGO 2, corrida device reversa 2026-07-11)

    /// El token del cursor ya se validó (o recuperó) contra el mount ACTUAL en esta sesión (instancia). Una
    /// vez `true`, el guard de validación NO vuelve a correr (cero coste en steady-state). Empieza `false` en
    /// cada instancia fresca (relaunch) → re-valida en el PRIMER drain de la sesión, que es cuando puede
    /// detectarse un token acuñado en un mount previo. No se persiste (es estado de sesión).
    /// `private(set)` para que los tests asserten la "no-validación única" (T5). Solo el motor lo escribe.
    private(set) var historyTokenValidated = false

    /// Slack fijo (segundos) del fetch por timestamp del guard: re-lee la frontera `[lastDrainedTxAt-60s, …]`
    /// para no perder txs de la ventana del último drain. Opera sobre `cursor.lastDrainedTxAt` (dato
    /// PERSISTIDO) — NUNCA sobre `Date()`/`Calendar.current`. La frontera re-leída la absorbe el dedup por
    /// `(syncID,hlc,op)` + LWW HLC-idempotente en el backend (documentado en `recoverIfHistoryTokenIncomparable`).
    /// SUPUESTO documentado (M1 del review adversarial): las txs del mount NUEVO llevan timestamps del
    /// wall-clock del device ≥ `lastDrainedTxAt` (History es append-only y el drain estampa el ancla con la
    /// última tx consumida) — una tx nueva >60s MÁS ANTIGUA que el ancla solo podría existir con un rewind
    /// de reloj mayor al slack durante la ventana del remount; fuera del alcance de esta red (residual
    /// aceptado, mismo orden de improbabilidad que N1 timestamp-exacto).
    private static let historyTokenSlack: TimeInterval = 60

    /// HALLAZGO 2: nº de veces que el guard detectó un token no-comparable cross-mount (par del breadcrumb
    /// `historyTokenIncomparable`). Expuesto para tests (el logger no es asertable).
    private(set) var historyTokenIncomparableCount = 0

    /// HALLAZGO 2: nº de veces que el guard re-ancló el token al mount actual (par del breadcrumb
    /// `historyTokenRecovered`). Expuesto para tests.
    private(set) var historyTokenRecoveredCount = 0

    /// DIFERIDOS #33: nº de re-escaneos ACOTADOS por token roto (par del breadcrumb
    /// `historyTokenBrokenBoundedRescan`, incluye ventana vacía). Expuesto para tests.
    private(set) var historyTokenBrokenBoundedCount = 0

    /// DIFERIDOS #33: nº de full-rescans DEGRADADOS por token roto (par del breadcrumb
    /// `historyTokenBrokenFullRescan` — reasons no-anchor / bounded-fetch-failed). Expuesto para tests.
    private(set) var historyTokenBrokenFullRescanCount = 0

    /// DIFERIDOS #33: nº de re-anclajes tras un re-escaneo acotado (par del breadcrumb
    /// `historyTokenBrokenReanchored`). Expuesto para tests.
    private(set) var historyTokenBrokenReanchoredCount = 0

    // MARK: Espejo del outbox (A1, §d.5)

    /// Espejo App Group del `SyncOutbox` (durabilidad ante lightweight migration). `nil` = mirroring
    /// desactivado (I8d DARK / tests que no lo ejercitan). El wiring de producción —resolverlo del App
    /// Group + inyectar `currentUserID`— llega en I9.
    var outboxMirror: SyncOutboxMirror?

    /// El `sub` de la sesión actual — sella cada entry del espejo (owner-scoping M1). Con `outboxMirror`
    /// puesto pero `currentUserID` nil, NO se espeja (no se puede owner-scopear una entry sin identidad).
    var currentUserID: String?

    // MARK: Coalescing "one in-flight, one queued"

    private var isDraining = false
    private var pendingDrain = false

    /// Expuesto para el guard D-2 de `pullAndApplyOnce` (extensión `SyncApplyEngine`): nunca aplicar
    /// deltas remotos con un drain EN CURSO (History sin drenar → laundering en el re-drain).
    var isDrainInProgress: Bool { isDraining }

    /// I8f-3 (guard A-3 de la verificación Merkle): `true` solo si el ÚLTIMO `pullAndApplyOnce` terminó
    /// `.completed` (cola agotada). Un pull incompleto → divergencia ESPERADA → el verificador se salta.
    /// Lo escribe SOLO `pullAndApplyOnce` (internal para que los tests puedan simular el estado).
    var lastPullCycleCompleted = false

    // MARK: Gate de quiescencia de reconcilers (I9, §G)

    /// Gate opcional para los saves de autor NORMAL de `runPostPullReconcilers` (REQUISITO I9 anotado en
    /// `pullAndApplyOnce`). `nil` = comportamiento actual (corren siempre — tests intactos). Cuando el
    /// runtime lo instala (`{ coordinator.isImportQuiescent }`), un ciclo con `pagesApplied > 0` pero
    /// import NO quieto DIFIERE los reconcilers (`pendingReconcile = true`) en vez de saveear sobre un
    /// grafo a medio importar → los reintenta al inicio de un ciclo futuro cuando el gate abra (no se
    /// pierde el repair). `internal`: lo lee/escribe la extensión `SyncApplyEngine` (otro archivo).
    var reconcilerQuiescenceGate: (() -> Bool)?

    /// Bandera en memoria: hay un `runPostPullReconcilers` diferido por quiescencia esperando reintento.
    /// La consume `pullAndApplyOnce` al inicio del pase de reconcilers. Un kill pierde esta bandera (los
    /// reconcilers son idempotentes) → el AJUSTE review corre `runStartupReconcilersIfQuiescent` en el
    /// arranque del runtime para cerrar ese hueco. `internal` (cross-file con `SyncApplyEngine`).
    var pendingReconcile = false

    // MARK: Seams de test

    /// Cuando `true`, `drainOnce` NO avanza el token del cursor tras persistir el outbox — simula un
    /// kill entre el save del outbox y el avance del token. SOLO para tests.
    var _testSuppressTokenAdvance = false

    /// Cuando `true`, `applyPage` LANZA al final del `saveWithAuthor` (tras las mutaciones, antes del
    /// commit) → simula un crash: nada se persiste, el cursor NO avanza (D-5, atomicidad). SOLO tests.
    var _testThrowOnApplySave = false

    /// DIFERIDOS #33 (T13): cuando `true`, el fetch por TOKEN del drain lanza — simula el token
    /// decodable cuyo `fetchHistory(predicate: token >)` revienta (migración destructiva). SOLO tests.
    var _testThrowOnTokenHistoryFetch = false

    /// DIFERIDOS #33 (T12): cuando `true`, el fetch ACOTADO por timestamp del fallback lanza — fuerza
    /// la semántica (b) (degradación a full-rescan). SOLO tests.
    var _testThrowOnBoundedHistoryFetch = false

    /// DIFERIDOS #29 (SERIO 3): override de la fase de migración que consulta el guard de `emitIdentityRemap`
    /// (default `nil` → `MigrationPhaseStore.shared.currentPhase`, el SSOT real). SOLO para tests (simular una
    /// migración/reversa EN CURSO sin journal real).
    var _testMigrationPhaseOverride: MigrationPhase?

    // MARK: Init

    init(nodeID: NodeID = NodeID.generate()) {
        self.clock = HLCClock(nodeID: nodeID)
    }

    // MARK: - API pública (coalescing)

    /// Ejecuta UNA vuelta de captura. Re-entrante: si ya hay una vuelta en curso, marca una pendiente
    /// (a lo sumo una) y retorna; la vuelta en curso la ejecuta al terminar (§a.4). Bajo `@MainActor`
    /// síncrono la re-entrada real no ocurre hoy, pero el patrón queda listo para el wiring de I9/I12.
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

    // MARK: - Núcleo del drain

    private func performDrain(context: ModelContext) {
        drainSeq += 1
        do {
            // 1) Cursor + token persistido. D-3: cargar el reloj persistido (send parte del estado
            //    durable — necesario para el lockstep de resumibilidad tras integrar remotos vía apply).
            let cursor = try loadOrCreateCursor(context)
            loadClock(from: cursor)
            let tokenState = decodeToken(cursor.historyTokenData)

            // 2) Barrido defensivo: asigna syncID a las filas vivas de los 6 tipos que aún no lo tengan
            //    (SIN autor especial → la próxima vuelta captura ese cambio), y construye los índices
            //    persistentID→modelo que usa la traducción. Save con autor por DEFECTO (no es outbox).
            let lookups = try sweepAndBuildLookups(context)

            // 3) History posterior al token — o, con token ROTO (in-decodificable / fetch que lanza),
            //    el fallback ACOTADO por `lastDrainedTxAt` de DIFERIDOS #33 (rama decidida por
            //    `HistoryTokenFallbackLogic`; ver doc-comment de `fetchHistoryResolvingToken`).
            let fetchOutcome = try fetchHistoryResolvingToken(
                tokenState, cursor: cursor, context: context)
            let tokenTxns = fetchOutcome.txns

            // 3-bis) HALLAZGO 2 — guard de validación del token por TIMESTAMP con revalidación continua.
            //    Red redundante barata: si el token del cursor (acuñado en un mount previo) dejó de
            //    surfacear txs nuevas del mount actual (no-comparabilidad cross-mount), re-procesa la
            //    UNIÓN de ambos fetches y re-ancla. `guard.txns` = tokenTxns en steady-state; la unión al
            //    recuperar. `guard.reanchor` != nil ⇒ recovery (se re-ancla SIEMPRE a la última tx de la
            //    unión en el paso 7). Ver doc-comment de `recoverIfHistoryTokenIncomparable`.
            //    DIFERIDOS #33: con token ROTO el guard se SALTA — "comparabilidad" de un token que ni
            //    decodifica no significa nada, y su fetch por timestamp sería idéntico al que la rama
            //    acotada acaba de hacer (doble fetch inútil); el re-anclaje lo trae `fetchOutcome`.
            let tokenGuard: TokenGuardResult
            if fetchOutcome.tokenWasBroken {
                tokenGuard = TokenGuardResult(txns: tokenTxns)
            } else {
                tokenGuard = recoverIfHistoryTokenIncomparable(
                    cursor: cursor, tokenTxns: tokenTxns, context: context)
            }
            if tokenGuard.validatedByCompare { historyTokenValidated = true }
            let txns = tokenGuard.txns

            // 4) Pre-siembra del dedup con las filas de outbox YA existentes (kill-replay: absorbe las
            //    filas persistidas en un drain previo cuyo token no llegó a avanzar).
            var seen = try existingOutboxKeys(context)

            // 5) Traducción, transacción a transacción y en orden. `advancedToken` = high-water de la
            //    history EXTERNA consumida (nil = no se consumió nada externo esta vuelta). Las
            //    transacciones que escribió el propio motor (`author == outboxSaveAuthor`: outbox +
            //    cursor) se DESCARTAN y NO avanzan el high-water → convergencia: un drain ocioso re-lee
            //    solo sus propios writes (0 filas) y no vuelve a mover/escribir el cursor. Criterio de
            //    drift: si `clock.send` lanza, NO se consume esa transacción (el high-water se queda
            //    antes de ella) → se reintenta al próximo drain. `advancedTxAt` = timestamp de esa última
            //    tx externa (HALLAZGO 2: ancla comparable cross-mount, persistida junto al token en 7).
            var rows: [PendingOutboxRow] = []
            var advancedToken: DefaultHistoryToken?
            var advancedTxAt: Date?
            // SERIO 1 del review adversarial #33: si la traducción ABORTA a mitad (clock.send lanza),
            // NINGÚN re-anclaje (ni el del guard ni el de token roto) puede saltar por encima de las
            // txs externas no consumidas — el paso 7 los suprime y cae al avance normal (`advancedToken`
            // = última tx consumida, el punto de retry seguro del invariante de drift).
            var translationAborted = false
            for tx in txns {
                // Anti-auto-captura (echo suppression): descartar los writes del propio motor. NO
                // avanzan el high-water (si lo hicieran, cada avance escribiría el cursor → loop).
                if tx.author == Self.outboxSaveAuthor { continue }
                // Clasificación del reason de tombstone: UNA vez por transacción (el reason depende del
                // CONJUNTO de deletes de la transacción, no del change individual). §c.1.
                let tombstoneReason = Self.classifyTombstoneReason(tx)
                var txRows: [PendingOutboxRow] = []
                do {
                    for change in tx.changes {
                        let entityName = change.changedPersistentIdentifier.entityName
                        // Anti-fuga de Grupos: solo entidades del store personal.
                        guard Self.personalEntityNames.contains(entityName) else { continue }
                        try translate(change, entityName: entityName, tx: tx,
                                      tombstoneReason: tombstoneReason,
                                      lookups: lookups, rows: &txRows, seen: &seen)
                    }
                } catch {
                    // `clock.send` lanzó (drift/overflow): abortar en la FRONTERA de esta transacción.
                    // No consumimos `tx` (advancedToken se queda antes de ella) ni sus filas parciales.
                    #if DEBUG
                    print("CloudSyncEngine: clock drift/overflow al traducir tx \(tx.token): \(error)")
                    #endif
                    translationAborted = true
                    break
                }
                rows.append(contentsOf: txRows)
                // Transacción externa consumida (produzca filas o no — p.ej. anti-fuga, syncID-only,
                // o un gap): avanza el high-water para no re-procesarla (evita recontar gaps).
                advancedToken = tx.token
                advancedTxAt = tx.timestamp
            }

            // 6) Persistir las filas del outbox (autor del motor → anti-auto-captura + no re-lectura).
            //    A1 (§d.5): el espejo App Group `.atomic` va AQUÍ, ANTES del insert+save, en el MISMO
            //    cuerpo síncrono sin `await` (regla Q3 del spike S-A1) — así autosave no puede invertir
            //    el orden fila-durable-sin-espejo.
            if !rows.isEmpty {
                // (1) ESPEJO PRIMERO (best-effort, per-fila, síncrono): si falla, la History es backup
                //     redundante y el canario de divergencia lo delata → NO abortamos el drain. Requiere
                //     `outboxMirror` + `currentUserID` (nil en I8d DARK → no-op).
                writeMirror(rows: rows)
                // (2) insertar (3) save. I8f-2 (D-A): el `SyncUnitClock` se actualiza en el MISMO save
                //     que la fila de outbox (upsert = unidades emitidas → HLC acuñado; tombstone =
                //     borrar la fila de clock — higiene) → crash-atómico con la cola.
                try saveWithAuthor(context, Self.outboxSaveAuthor) {
                    for row in rows {
                        context.insert(row.makeModel())
                        updateUnitClock(for: row, context: context)
                    }
                }
            }

            // 7) Avanzar el token SOLO tras persistir el outbox (crash entre 6 y 7 → el re-drain re-crea
            //    idempotente por el dedup). El save del cursor lleva `outboxSaveAuthor` → no se re-lee.
            //    Suprimible en tests (kill). D-3: el reloj se PERSISTE en el MISMO save que avanza el token
            //    (crash → ambos revierten juntos → replay determinista). HALLAZGO 2: `lastDrainedTxAt` se
            //    persiste ATÓMICAMENTE con el token (misma transacción) → el ancla comparable cross-mount
            //    nunca queda desincronizada del token.
            //    SERIO 1 del review adversarial #33 (aplica a AMBOS re-anclajes — el gemelo del guard
            //    tenía el mismo defecto latente): los reanchor apuntan a la última tx de la ventana/unión
            //    CRUDA, calculada ANTES de traducir — con `translationAborted` (clock.send lanzó a mitad),
            //    re-anclar saltaría las txs externas entre el break y el final SIN haberlas emitido →
            //    quedarían con timestamp ≤ ancla nueva, invisibles para siempre (token-fetch, fallback Y
            //    guard) = pérdida silenciosa. En abort se cae al avance normal (última tx CONSUMIDA — el
            //    punto de retry del invariante de drift); si nada se consumió, no se guarda nada y el
            //    próximo drain reintenta entero.
            if !_testSuppressTokenAdvance {
                if let reanchor = tokenGuard.reanchor, !translationAborted {
                    // RECOVERY: el token era no-comparable cross-mount → re-anclar SIEMPRE a la última tx de
                    //    la UNIÓN, AUNQUE sea del motor (`author == outboxSaveAuthor`). Difiere del invariante
                    //    normal —que solo avanza con history EXTERNA— a propósito: para re-anclar basta un
                    //    token del mount ACTUAL (el filtro de emisión, que sí descarta el motor, es
                    //    independiente del avance del cursor). Sin esto el token quedaría en el mount viejo.
                    try saveWithAuthor(context, Self.outboxSaveAuthor) {
                        cursor.historyTokenData = try encodeToken(reanchor.token)
                        cursor.lastDrainedTxAt = reanchor.txAt
                        cursor.clockLatestHLC = clock.latest?.description
                    }
                    historyTokenValidated = true
                    historyTokenRecoveredCount += 1
                    CloudSyncBreadcrumb.historyTokenRecovered()
                } else if let reanchor = fetchOutcome.brokenReanchor, !translationAborted {
                    // DIFERIDOS #33: el token estaba ROTO y la rama acotada trajo ventana no vacía →
                    //    re-anclar a la ÚLTIMA tx de la ventana (motor incluido — misma justificación
                    //    que el reanchor del guard: para sanar basta un token del mount actual; el
                    //    filtro de emisión del paso 5 es independiente). Precede a `advancedToken` a
                    //    propósito: el avance normal solo apunta a la última tx EXTERNA — anclar más
                    //    atrás dejaría txs del motor por delante que cada drain re-leería. Atomicidad
                    //    token+ancla+reloj idéntica a las otras dos ramas.
                    try saveWithAuthor(context, Self.outboxSaveAuthor) {
                        cursor.historyTokenData = try encodeToken(reanchor.token)
                        cursor.lastDrainedTxAt = reanchor.txAt
                        cursor.clockLatestHLC = clock.latest?.description
                    }
                    historyTokenValidated = true
                    historyTokenBrokenReanchoredCount += 1
                    CloudSyncBreadcrumb.historyTokenBrokenReanchored()
                } else if let advancedToken {
                    //    Avance normal: SOLO si se consumió history externa. Bundling seguro: todo `clock.send`
                    //    de esta vuelta ocurrió al traducir una tx externa que también fijó `advancedToken`.
                    try saveWithAuthor(context, Self.outboxSaveAuthor) {
                        cursor.historyTokenData = try encodeToken(advancedToken)
                        cursor.lastDrainedTxAt = advancedTxAt
                        cursor.clockLatestHLC = clock.latest?.description
                    }
                    // Outcome (b): consumir ≥1 tx externa re-ancla el token al mount actual → validado.
                    historyTokenValidated = true
                }
            }

            // Count SOLO para el breadcrumb de diagnóstico. Sin `try?` que silencie (regla inviolable):
            // do/catch con fallback a `rows.count` (nunca aborta el drain por un fallo de conteo).
            let pending: Int
            do {
                pending = try context.fetchCount(FetchDescriptor<SyncOutbox>())
            } catch {
                #if DEBUG
                print("CloudSyncEngine: fetchCount(SyncOutbox) para breadcrumb falló: \(error)")
                #endif
                pending = rows.count
            }
            CloudSyncBreadcrumb.drain(seq: drainSeq, pending: pending)
        } catch {
            #if DEBUG
            print("CloudSyncEngine: drain error: \(error)")
            #endif
        }
    }

    // MARK: - Guard de validación del token de History (HALLAZGO 2, corrida device reversa 2026-07-11)

    /// Resultado del guard: qué transacciones procesa el drain esta vuelta y, si hubo recuperación, a qué
    /// tx re-anclar el token.
    private struct TokenGuardResult {
        /// Transacciones a procesar: `tokenTxns` en steady-state; la UNIÓN de ambos fetches al recuperar.
        var txns: [DefaultHistoryTransaction]
        /// El guard comparó y el token surfacea BIEN las txs del mount actual → marcar validado de inmediato
        /// (validación de solo-lectura, sin persistir). Falso en recovery (validar tras persistir el re-ancla).
        var validatedByCompare = false
        /// Recovery: la última tx de la unión a la que el drain debe RE-ANCLAR el token (+ su timestamp).
        /// `nil` = no hubo recuperación. Al persistir con éxito, el caller marca validado + emite el par.
        var reanchor: (token: DefaultHistoryToken, txAt: Date)?
    }

    /// Detecta y recupera un `historyTokenData` que dejó de surfacear transacciones nuevas del mount ACTUAL
    /// (no-comparabilidad cross-mount de `DefaultHistoryToken`) usando los TIMESTAMPS de History (SÍ
    /// comparables cross-mount) como red redundante. Root cause (corrida device 2026-07-11): la fila
    /// `ExchangeRate` del boot post-cutover obtuvo syncID y tx de History, pero el token del cursor —acuñado
    /// en el mount `.icloud` (mirror ON) previo al remontaje `.cloud` (mirror OFF) sobre el MISMO archivo—
    /// hizo que el predicado `$0.token > staleToken` EXCLUYERA silenciosamente esa tx (una exclusión por
    /// predicado NO lanza → cero breadcrumb → `pending=0` perpetuo → divergencia Merkle local-ahead
    /// inconvergible → `reverseVerify mismatch ×3 → reverseFailedRollback`). Es la MISMA clase que
    /// `fastForwardHistoryBaseline` (~50% no-comparable bajo carga), pero el predicado idéntico del drain
    /// quedó sin blindar. Este guard es agnóstico al mecanismo: recupera CUALQUIER token que deje de
    /// surfacear txs nuevas (el remount probado Y una eventual no-comparabilidad en relaunch normal).
    ///
    /// Corre SOLO mientras `!historyTokenValidated` (una vez validado/recuperado en la sesión, coste cero) y
    /// SOLO con `historyTokenData != nil && lastDrainedTxAt != nil`. `lastDrainedTxAt == nil` (cursor
    /// pre-schema) → SKIP (residual documentado: un token YA roto en un cursor pre-schema no se auto-cura
    /// —nunca consume → nunca puebla el campo—; benigno: 0 devices `.cloud` en producción, flags DARK; el
    /// flujo NUEVO puebla el campo antes del remount vía el `drainOnce` de `startParallelHistoryCapture`).
    ///
    /// **Outcomes:**
    /// - Faltantes > 0 (txs externas de entidad personal en la ventana de timestamp AUSENTES del token-fetch)
    ///   → token ROTO: breadcrumb `historyTokenIncomparable`, procesar la UNIÓN, re-anclar SIEMPRE a la
    ///   última tx de la unión (paso 7) → `historyTokenRecovered` al persistir.
    /// - Faltantes == 0 con timestamp-fetch NO vacío → el token compara bien → `validatedByCompare`.
    /// - timestamp-fetch vacío (nada contra qué validar) → NO valida → revalida en el próximo drain (coste:
    ///   un fetch acotado). También valida (b): si el camino normal consume ≥1 tx externa, el avance del
    ///   paso 7 re-ancla al mount actual → validado.
    ///
    /// Frontera del slack (`historyTokenSlack`): re-lee la ventana `[lastDrainedTxAt-60s, …]` → txs ya
    /// drenadas se re-emiten con HLC fresco (el reloj de la instancia ya avanzó), pero el dedup por
    /// `(syncID,hlc,op)` no las absorbe → filas de outbox redundantes que el backend colapsa por LWW
    /// HLC-idempotente (mismo syncID+contenido, converge). Coste aceptado (recovery es one-shot por sesión).
    ///
    /// **Candidatos DESCARTADOS:**
    /// - *Reset token→nil en `persistLocalMode`/`persistICloudMode`*: full-rescan de una History que puede
    ///   contener el corpus completo (purga doble-DARK) → re-emisión masiva; y no cubre el relaunch normal.
    /// - *Re-anclar baseline en boot temprano (pre-paso-2)*: pierde la cola del mount viejo (ventana
    ///   último-drain→kill) y crea una dependencia frágil del orden de bootstrap.
    /// - *Timestamp como cursor PRIMARIO*: wall-clock no-monótono como mecanismo primario es peor que
    ///   token + red redundante barata.
    ///
    /// Sin `Date()`/`Calendar.current`: el cutoff se deriva de `cursor.lastDrainedTxAt` (dato persistido).
    private func recoverIfHistoryTokenIncomparable(
        cursor: SyncCursor,
        tokenTxns: [DefaultHistoryTransaction],
        context: ModelContext
    ) -> TokenGuardResult {
        // Gate: solo hasta la primera validación de la sesión, y solo con ancla poblada (cursor pre-schema → skip).
        guard !historyTokenValidated,
              cursor.historyTokenData != nil,
              let lastDrainedTxAt = cursor.lastDrainedTxAt else {
            return TokenGuardResult(txns: tokenTxns)
        }
        // Fetch por timestamp con slack fijo — opera sobre dato PERSISTIDO (sin Date()/Calendar.current).
        let cutoff = lastDrainedTxAt.addingTimeInterval(-Self.historyTokenSlack)
        let timestampTxns: [DefaultHistoryTransaction]
        do {
            timestampTxns = try context.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.timestamp > cutoff }))
        } catch {
            #if DEBUG
            print("CloudSyncEngine: guard token — fetch por timestamp falló: \(error)")
            #endif
            return TokenGuardResult(txns: tokenTxns)
        }
        // Nada en la ventana → nada contra qué validar → revalidar en el próximo drain.
        guard !timestampTxns.isEmpty else { return TokenGuardResult(txns: tokenTxns) }

        // Faltantes = txs NUEVAS del timestamp-fetch AUSENTES del token-fetch, que el drain NO filtraría
        // igual (externas + con ≥1 change de entidad personal — espejo del filtro del paso 5). Ambos
        // fetches son del MISMO mount → sus tokens son mutuamente comparables (identidad por token, 0c).
        //
        // AJUSTE de implementación (premisa del plan corregida): "ausente del token-fetch" a secas produce
        // un FALSO POSITIVO en steady-state — la ÚLTIMA tx ya drenada (timestamp == `lastDrainedTxAt`) cae
        // en la ventana de slack (`-60s`) pero el token VÁLIDO la excluye correctamente (`after(token)` no
        // la incluye) → aparecería como "faltante" y dispararía recovery en CADA primer drain de sesión.
        // El discriminante real de un token ROTO es una tx NUEVA (`timestamp > lastDrainedTxAt`) que el
        // token no surfacea — la frontera ya drenada (`<= lastDrainedTxAt`) NO cuenta. El slack `-60s` solo
        // ensancha el FETCH (completitud de la unión); la determinación de faltantes es estricta.
        let tokenTokens = tokenTxns.map(\.token)
        func tokenPresent(_ tx: DefaultHistoryTransaction) -> Bool {
            tokenTokens.contains { $0 == tx.token }
        }
        let missing = timestampTxns.filter { tx in
            guard tx.timestamp > lastDrainedTxAt else { return false }  // NUEVA, no la frontera ya drenada
            guard tx.author != Self.outboxSaveAuthor else { return false }
            guard tx.changes.contains(where: {
                Self.personalEntityNames.contains($0.changedPersistentIdentifier.entityName)
            }) else { return false }
            return !tokenPresent(tx)
        }
        guard !missing.isEmpty else {
            // El token surfacea bien las txs del mount actual → validado (solo-lectura).
            return TokenGuardResult(txns: tokenTxns, validatedByCompare: true)
        }

        // Token ROTO. UNIÓN de ambos fetches (dedup por igualdad de token), ordenada por (timestamp, índice
        // original) → determinista para el lockstep del replay SIN depender de `Comparable` sobre el token.
        historyTokenIncomparableCount += 1
        CloudSyncBreadcrumb.historyTokenIncomparable(missed: missing.count)
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
            // Inalcanzable (missing no vacío ⇒ unión no vacía), defensivo.
            return TokenGuardResult(txns: orderedUnion)
        }
        return TokenGuardResult(txns: orderedUnion, reanchor: (token: last.token, txAt: last.timestamp))
    }

    // MARK: - Clasificación del reason de tombstone (§c.1, drain-side)

    /// Deriva el `reason` de los tombstones de UNA transacción (§c.1). Precedencia: `migration` (author
    /// del motor/migración) → `cascade` (la transacción borra un tipo padre de cascada conocida) →
    /// `user` (default). `dedup`/`wipe` NO son clasificables hoy sin señal de call-site (I9/I12) → caen
    /// en `user`/`cascade`. Es metadata de auditoría: una clasificación conservadora no compromete la
    /// correctness (el backend mantiene `deleted=true` igual). Estático + puro → testeable en aislamiento
    /// del ciclo del drain no es trivial (requiere `DefaultHistoryTransaction`), así que los goldens lo
    /// ejercitan end-to-end vía el drain real.
    private static func classifyTombstoneReason(_ tx: DefaultHistoryTransaction) -> SyncTombstoneReason {
        // migration: author dedicado del motor/migración (bucket por completitud; ver `migrationAuthors`).
        if let author = tx.author, migrationAuthors.contains(author) {
            return .migration
        }
        // cascade: la transacción TAMBIÉN borra un tipo padre de cascada conocida.
        for change in tx.changes {
            guard case .delete = change else { continue }
            if cascadeParentEntityNames.contains(change.changedPersistentIdentifier.entityName) {
                return .cascade
            }
        }
        return .user
    }

    // MARK: - Traducción de un cambio (dispatch por tipo concreto)

    /// Índices persistentID→modelo de los tipos sincronizables cableados (construidos en el barrido).
    private struct Lookups {
        var transactionItem: [PersistentIdentifier: TransactionItem] = [:]
        var inboxDraft: [PersistentIdentifier: InboxDraft] = [:]
        var category: [PersistentIdentifier: Category] = [:]
        var favoritePayment: [PersistentIdentifier: FavoritePayment] = [:]
        var merchantMemory: [PersistentIdentifier: MerchantMemory] = [:]
        var exchangeRate: [PersistentIdentifier: ExchangeRate] = [:]
        // I12: identidad = UUID persistido (`id`), nunca nil → el barrido NO las acuña, solo indexa.
        var budget: [PersistentIdentifier: Budget] = [:]
        var scheduledPayment: [PersistentIdentifier: ScheduledPayment] = [:]
        // I12 commit B: las 8 restantes (identidad = `shortcutID` en Account/Subcategory; `id` en el resto).
        var account: [PersistentIdentifier: Account] = [:]
        var subcategory: [PersistentIdentifier: Subcategory] = [:]
        var tag: [PersistentIdentifier: Tag] = [:]
        var notificationItem: [PersistentIdentifier: NotificationItem] = [:]
        var cashFlowPlan: [PersistentIdentifier: CashFlowPlan] = [:]
        var cashFlowLine: [PersistentIdentifier: CashFlowLine] = [:]
        var cashFlowOverride: [PersistentIdentifier: CashFlowOverride] = [:]
        var groupBridgePreference: [PersistentIdentifier: GroupBridgePreference] = [:]
    }

    /// Despacha el cambio al handler concreto por entity name. Los tipos personales aún NO cableados
    /// caen al `default` y se ignoran (identidad de sync pendiente — incrementos futuros).
    ///
    /// D1: las 6 originales usan `syncID: UUID?` sintético (mismo accessor para live y tombstone; sin
    /// canario de mutación de identidad — el `syncID` no se regenera). Las cableadas en I12 usan su UUID
    /// EXISTENTE (`id`, NO-opcional): `liveSyncID` lo lee directo, `tombstoneSyncID` lo lee del atributo
    /// real preservado, y `identityKeyPath` arma el canario D4 (regeneración de identidad detectable).
    private func translate(
        _ change: HistoryChange,
        entityName: String,
        tx: DefaultHistoryTransaction,
        tombstoneReason: SyncTombstoneReason,
        lookups: Lookups,
        rows: inout [PendingOutboxRow],
        seen: inout Set<String>
    ) throws {
        switch entityName {
        case SyncEntityType.transactionItem:
            try translateChange(change, type: TransactionItem.self, entityType: entityName,
                                liveSyncID: { $0.syncID }, tombstoneSyncID: { $0.tombstone[\.syncID] as? UUID },
                                identityKeyPath: nil, emission: EntityEmissionMap.transactionItem,
                                lookup: lookups.transactionItem, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.inboxDraft:
            try translateChange(change, type: InboxDraft.self, entityType: entityName,
                                liveSyncID: { $0.syncID }, tombstoneSyncID: { $0.tombstone[\.syncID] as? UUID },
                                identityKeyPath: nil, emission: EntityEmissionMap.inboxDraft,
                                lookup: lookups.inboxDraft, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.category:
            try translateChange(change, type: Category.self, entityType: entityName,
                                liveSyncID: { $0.syncID }, tombstoneSyncID: { $0.tombstone[\.syncID] as? UUID },
                                identityKeyPath: nil, emission: EntityEmissionMap.category,
                                lookup: lookups.category, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.favoritePayment:
            try translateChange(change, type: FavoritePayment.self, entityType: entityName,
                                liveSyncID: { $0.syncID }, tombstoneSyncID: { $0.tombstone[\.syncID] as? UUID },
                                identityKeyPath: nil, emission: EntityEmissionMap.favoritePayment,
                                lookup: lookups.favoritePayment, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.merchantMemory:
            try translateChange(change, type: MerchantMemory.self, entityType: entityName,
                                liveSyncID: { $0.syncID }, tombstoneSyncID: { $0.tombstone[\.syncID] as? UUID },
                                identityKeyPath: nil, emission: EntityEmissionMap.merchantMemory,
                                lookup: lookups.merchantMemory, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.exchangeRate:
            try translateChange(change, type: ExchangeRate.self, entityType: entityName,
                                liveSyncID: { $0.syncID }, tombstoneSyncID: { $0.tombstone[\.syncID] as? UUID },
                                identityKeyPath: nil, emission: EntityEmissionMap.exchangeRate,
                                lookup: lookups.exchangeRate, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.budget:
            try translateChange(change, type: Budget.self, entityType: entityName,
                                liveSyncID: { $0.id }, tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                identityKeyPath: \Budget.id, emission: EntityEmissionMap.budget,
                                lookup: lookups.budget, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.scheduledPayment:
            try translateChange(change, type: ScheduledPayment.self, entityType: entityName,
                                liveSyncID: { $0.id }, tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                identityKeyPath: \ScheduledPayment.id, emission: EntityEmissionMap.scheduledPayment,
                                lookup: lookups.scheduledPayment, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.account:
            try translateChange(change, type: Account.self, entityType: entityName,
                                liveSyncID: { $0.shortcutID }, tombstoneSyncID: { $0.tombstone[\.shortcutID] as? UUID },
                                identityKeyPath: \Account.shortcutID, emission: EntityEmissionMap.account,
                                lookup: lookups.account, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.subcategory:
            try translateChange(change, type: Subcategory.self, entityType: entityName,
                                liveSyncID: { $0.shortcutID }, tombstoneSyncID: { $0.tombstone[\.shortcutID] as? UUID },
                                identityKeyPath: \Subcategory.shortcutID, emission: EntityEmissionMap.subcategory,
                                lookup: lookups.subcategory, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.tag:
            try translateChange(change, type: Tag.self, entityType: entityName,
                                liveSyncID: { $0.id }, tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                identityKeyPath: \Tag.id, emission: EntityEmissionMap.tag,
                                lookup: lookups.tag, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.notificationItem:
            try translateChange(change, type: NotificationItem.self, entityType: entityName,
                                liveSyncID: { $0.id }, tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                identityKeyPath: \NotificationItem.id, emission: EntityEmissionMap.notificationItem,
                                lookup: lookups.notificationItem, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.cashFlowPlan:
            try translateChange(change, type: CashFlowPlan.self, entityType: entityName,
                                liveSyncID: { $0.id }, tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                identityKeyPath: \CashFlowPlan.id, emission: EntityEmissionMap.cashFlowPlan,
                                lookup: lookups.cashFlowPlan, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.cashFlowLine:
            try translateChange(change, type: CashFlowLine.self, entityType: entityName,
                                liveSyncID: { $0.id }, tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                identityKeyPath: \CashFlowLine.id, emission: EntityEmissionMap.cashFlowLine,
                                lookup: lookups.cashFlowLine, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.cashFlowOverride:
            try translateChange(change, type: CashFlowOverride.self, entityType: entityName,
                                liveSyncID: { $0.id }, tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                identityKeyPath: \CashFlowOverride.id, emission: EntityEmissionMap.cashFlowOverride,
                                lookup: lookups.cashFlowOverride, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.groupBridgePreference:
            try translateChange(change, type: GroupBridgePreference.self, entityType: entityName,
                                liveSyncID: { $0.id }, tombstoneSyncID: { $0.tombstone[\.id] as? UUID },
                                identityKeyPath: \GroupBridgePreference.id, emission: EntityEmissionMap.groupBridgePreference,
                                lookup: lookups.groupBridgePreference, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        default:
            // Personal-pero-aún-sin-identidad (las restantes de los 16). No se traduce todavía.
            return
        }
    }

    /// Traduce UN cambio de un tipo concreto `T` a (a lo sumo) una fila de outbox. El payload de dominio
    /// (`fields` + `field_hlcs`) lo produce `DeltaEmitter` (proyección `EntityEmissionMap` + codec c1).
    ///
    /// D1: la identidad de sync se lee vía dos accessors en lugar de un keypath único, para acoplar
    /// `UUID?` (sintético) y `UUID` (existente): `liveSyncID` de la fila viva (insert/update) y
    /// `tombstoneSyncID` del atributo preservado (delete). `identityKeyPath` (nil = identidad sintética
    /// que no se regenera) arma el canario D4 en el path de UPDATE.
    private func translateChange<T: PersistentModel>(
        _ change: HistoryChange,
        type: T.Type,
        entityType: String,
        liveSyncID: (T) -> UUID?,
        tombstoneSyncID: (DefaultHistoryDelete<T>) -> UUID?,
        identityKeyPath: PartialKeyPath<T>?,
        emission: EntityEmission<T>,
        lookup: [PersistentIdentifier: T],
        tx: DefaultHistoryTransaction,
        tombstoneReason: SyncTombstoneReason,
        rows: inout [PendingOutboxRow],
        seen: inout Set<String>
    ) throws {
        switch change {
        case .insert(let insert):
            // El entityName ya coincide; el `is` confirma el tipo concreto (defensivo).
            guard insert is DefaultHistoryInsert<T> else { return }
            guard let model = lookup[insert.changedPersistentIdentifier] else { return }  // borrada → skip
            guard let syncID = liveSyncID(model) else { return }  // sin identidad → skip
            // INSERT = proyección COMPLETA de dominio (todas las columnas). Todas las unidades reciben
            // el HLC de la transacción. Los grupos de coherencia viajan enteros por construcción.
            try appendUpsert(model: model, emission: emission, syncID: syncID, entityType: entityType,
                             changedColumns: emission.columns, tx: tx, rows: &rows, seen: &seen)

        case .update(let update):
            guard let typed = update as? DefaultHistoryUpdate<T> else { return }
            guard let model = lookup[typed.changedPersistentIdentifier] else { return }
            guard let syncID = liveSyncID(model) else { return }
            // Canario D4 (RED DE SEGURIDAD tras DIFERIDOS #29): el UPDATE mutó el keypath de IDENTIDAD (solo
            // entidades con identidad = UUID persistido). El drain lo SKIPea abajo por diseño (el remap lo emite
            // `emitIdentityRemap` en la transacción del reparador). Este canario delata AHORA una mutación de
            // identidad desde un sitio NO cableado al remap: sin el par `identityRemapEmitted` en la misma
            // ventana → bug (fila nueva server-side + huérfana; §b.4).
            if let identityKeyPath, typed.updatedAttributes.contains(identityKeyPath) {
                identityMutationObservedCount += 1
                CloudSyncBreadcrumb.identityMutationObserved(entity: entityType)
            }
            // PATCH parcial: mapea los keypaths cambiados a columnas Postgres. La identidad NO está en el
            // mapa (es la PK) → si SOLO cambió la identidad el set queda vacío → SKIP. Los keypaths sin
            // mapeo (relaciones no-columna, internos) se ignoran.
            var changedColumns: Set<String> = []
            for keyPath in typed.updatedAttributes {
                if let columns = emission.columnKeyPaths[keyPath as PartialKeyPath<T>] {
                    changedColumns.formUnion(columns)
                }
            }
            guard !changedColumns.isEmpty else { return }
            try appendUpsert(model: model, emission: emission, syncID: syncID, entityType: entityType,
                             changedColumns: changedColumns, tx: tx, rows: &rows, seen: &seen)

        case .delete(let delete):
            guard let typed = delete as? DefaultHistoryDelete<T> else { return }
            // Identidad preservada vía `.preserveValueOnDeletion` (spike S1/S4).
            guard let syncID = tombstoneSyncID(typed) else {
                recordIdentityGap(entityType: entityType, reason: "tombstoneSyncIDNil")
                return
            }
            // Tombstone (I4): op + syncID + `reason` clasificado drain-side (§c.1), sin payload de campos.
            try appendRow(op: .tombstone, syncID: syncID, entityType: entityType,
                          tombstoneReason: tombstoneReason, tx: tx, rows: &rows, seen: &seen) { _ in
                ("{}", nil)  // tombstone: sin fields ni field_hlcs
            }

        @unknown default:
            // `HistoryChange` puede ganar casos nuevos (Swift 6): ignorar defensivamente.
            return
        }
    }

    /// Emite una fila `upsert`: acuña el HLC, arma el delta (`DeltaEmitter`) y lo serializa por el codec
    /// c1. Si el codec rechaza los `fields` (número no-finito / fuera de rango / blob malformado) la fila
    /// se DESCARTA con canario (no puede viajar canónicamente) — no aborta el resto de la transacción.
    private func appendUpsert<T: AnyObject>(
        model: T,
        emission: EntityEmission<T>,
        syncID: UUID,
        entityType: String,
        changedColumns: Set<String>,
        tx: DefaultHistoryTransaction,
        rows: inout [PendingOutboxRow],
        seen: inout Set<String>
    ) throws {
        try appendRow(op: .upsert, syncID: syncID, entityType: entityType,
                      tombstoneReason: nil, tx: tx, rows: &rows, seen: &seen) { hlc in
            let result = DeltaEmitter.emit(model: model, emission: emission,
                                           changedColumns: changedColumns, hlc: hlc)
            let fieldsJSON: String
            do {
                // `groupedColumns`: las columnas agrupadas de la entidad — una `.uuidArray` vacía DENTRO
                // de un grupo se encodea `[]` explícito (DIFERIDOS #25 opción 1), no se omite.
                fieldsJSON = try Canonc1Codec.encode(result.fields,
                                                     groupedColumns: Set(emission.groupByColumn.keys))
            } catch {
                #if DEBUG
                print("CloudSyncEngine: codec c1 rechazó \(entityType): \(error)")
                #endif
                CloudSyncBreadcrumb.encodeRejected(entity: entityType, reason: "\(error)")
                return nil  // fila descartada (clock ya avanzó → lockstep preservado)
            }
            return (fieldsJSON, encodeFieldHlcs(result.fieldHlcs))
        }
    }

    /// Acuña el HLC (ÚNICO punto que llama `clock.send` → advance determinista y en orden), deduplica
    /// por (syncID, hlc, op) y encola una fila pendiente. `makePayload(hlc)` construye
    /// `(fieldsJSON, fieldHlcsJSON)`; si devuelve `nil` la fila se descarta SIN deshacer el advance del
    /// reloj (lockstep de resumibilidad intacto). `clock.send` puede lanzar `ClockDriftError` → se
    /// propaga al llamador (criterio de drift del drain).
    private func appendRow(
        op: SyncOutboxOp,
        syncID: UUID,
        entityType: String,
        tombstoneReason: SyncTombstoneReason?,
        tx: DefaultHistoryTransaction,
        rows: inout [PendingOutboxRow],
        seen: inout Set<String>,
        makePayload: (String) -> (fieldsJSON: String, fieldHlcsJSON: String?)?
    ) throws {
        // Advance del reloj: SIEMPRE tras pasar los guards estructurales y ANTES del dedup, de modo que
        // dos instancias frescas procesando el mismo History avanzan el reloj en lockstep → HLCs
        // idénticos (invariante de resumibilidad). El HLC queda FIJADO en la fila (§d.5).
        let hlc = try clock.send(now: tx.timestamp).description
        let key = dedupKey(syncID: syncID, hlc: hlc, op: op)
        guard !seen.contains(key) else { return }
        seen.insert(key)
        guard let payload = makePayload(hlc) else { return }  // codec rechazó → fila descartada
        rows.append(PendingOutboxRow(
            syncID: syncID,
            entityType: entityType,
            op: op,
            hlc: hlc,
            clientMutationID: UUID(),
            fieldsJSON: payload.fieldsJSON,
            fieldHlcsJSON: payload.fieldHlcsJSON,
            author: tx.author ?? "",
            // Solo los tombstones llevan reason (upsert → nil). Defensivo: aunque el llamador pasara un
            // reason con op:upsert, se descarta (el reason es semántica exclusiva del tombstone).
            tombstoneReason: op == .tombstone ? tombstoneReason?.rawValue : nil,
            createdAt: .now
        ))
    }

    private func recordIdentityGap(entityType: String, reason: String) {
        identityGapCount += 1
        CloudSyncBreadcrumb.identityGap(entityType: entityType, reason: reason)
        // Canario MetricsService (no-op en tests: sin start() todo es no-op).
        MetricsService.cloudSyncIdentityGapObserved(entityType: entityType)
    }

    // MARK: - Barrido defensivo + índices

    private func sweepAndBuildLookups(_ context: ModelContext) throws -> Lookups {
        var lookups = Lookups()
        lookups.transactionItem = try sweepType(TransactionItem.self, context: context)
        lookups.inboxDraft = try sweepType(InboxDraft.self, context: context)
        lookups.category = try sweepType(Category.self, context: context)
        lookups.favoritePayment = try sweepType(FavoritePayment.self, context: context)
        lookups.merchantMemory = try sweepType(MerchantMemory.self, context: context)
        lookups.exchangeRate = try sweepType(ExchangeRate.self, context: context)
        // I12: identidad = UUID persistido (nunca nil) → solo indexar, NUNCA acuñar (regenerarla sería
        // un incidente D4, no una asignación defensiva). Fetch CONCRETO por tipo.
        lookups.budget = try indexType(Budget.self, context: context)
        lookups.scheduledPayment = try indexType(ScheduledPayment.self, context: context)
        // I12 commit B: las 8 restantes — identidad = UUID persistido (`shortcutID`/`id`) → solo indexar.
        lookups.account = try indexType(Account.self, context: context)
        lookups.subcategory = try indexType(Subcategory.self, context: context)
        lookups.tag = try indexType(Tag.self, context: context)
        lookups.notificationItem = try indexType(NotificationItem.self, context: context)
        lookups.cashFlowPlan = try indexType(CashFlowPlan.self, context: context)
        lookups.cashFlowLine = try indexType(CashFlowLine.self, context: context)
        lookups.cashFlowOverride = try indexType(CashFlowOverride.self, context: context)
        lookups.groupBridgePreference = try indexType(GroupBridgePreference.self, context: context)
        if context.hasChanges {
            // Autor por DEFECTO (no `outboxSaveAuthor`): el cambio de syncID DEBE quedar en el History
            // para que la próxima vuelta lo procese (y lo salte por ser syncID-only), no ocultarse.
            try context.save()
        }
        return lookups
    }

    /// Fetch CONCRETO por tipo (nunca genérico sobre keypath de protocolo — regla inviolable de
    /// `#Predicate`; patrón `SyncIdentityService`). Asigna syncID a los nil y devuelve el índice.
    private func sweepType<T: PersistentModel & SyncIdentifiable>(
        _ type: T.Type, context: ModelContext
    ) throws -> [PersistentIdentifier: T] {
        let models = try context.fetch(FetchDescriptor<T>())
        var map: [PersistentIdentifier: T] = [:]
        for model in models {
            if model.syncID == nil {
                model.syncID = UUID()
            }
            map[model.persistentModelID] = model
        }
        return map
    }

    /// I12: barrido SIN acuñar para las entidades cuya identidad de sync es su UUID persistido (nunca
    /// nil). Solo construye el índice persistentID→modelo (fetch CONCRETO por tipo). Regenerar ese UUID
    /// es un incidente (canario D4), no una asignación defensiva → aquí jamás se toca.
    private func indexType<T: PersistentModel>(
        _ type: T.Type, context: ModelContext
    ) throws -> [PersistentIdentifier: T] {
        let models = try context.fetch(FetchDescriptor<T>())
        var map: [PersistentIdentifier: T] = [:]
        for model in models {
            map[model.persistentModelID] = model
        }
        return map
    }

    // MARK: - Cursor / token

    /// `internal` (no `private`): lo consume también `SyncApplyEngine` (extensión en otro archivo).
    func loadOrCreateCursor(_ context: ModelContext) throws -> SyncCursor {
        var descriptor = FetchDescriptor<SyncCursor>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let cursor = SyncCursor()
        context.insert(cursor)
        // Persistir de inmediato para no crear un segundo single-row si el drain no avanza el token.
        // Autor del motor → esta creación NO se re-lee como history externa.
        try saveWithAuthor(context, Self.outboxSaveAuthor) { }
        return cursor
    }

    // MARK: - Reloj (D-3): carga/persistencia + receive de remotos (apply)

    /// D-3: carga el `HLCClock` desde el estado durable del cursor (`clockLatestHLC`). Send y receive
    /// parten de aquí → un crash revierte reloj y cursor juntos. `nil`/malformado → conserva el reloj
    /// en memoria (fresco en el primer arranque). Preserva el `nodeID` de esta instancia.
    func loadClock(from cursor: SyncCursor) {
        guard let raw = cursor.clockLatestHLC else { return }
        do {
            let hlc = try HLC.parse(raw)
            clock = HLCClock(nodeID: clock.nodeID, latest: hlc)
        } catch {
            #if DEBUG
            print("CloudSyncEngine: loadClock parse falló para \(raw): \(error)")
            #endif
        }
    }

    /// D-3: integra un HLC remoto en el reloj (apply). No propaga el error (drift/overflow del remoto no
    /// debe abortar el apply de una página): breadcrumb + canario y sigue — el reloj conserva su `latest`
    /// previo. SEMÁNTICA INTENCIONAL (F-5): el guard de drift existe para NO envenenar el reloj local con
    /// un remoto insano (>5min en el futuro); la pérdida de causalidad bajo skew extremo es un residual
    /// DOCUMENTADO vigilado server-side por `cloudSyncSuspectClockWin` — aquí solo se hace visible.
    func receiveRemoteClock(_ remote: HLC, now: Date) {
        do {
            _ = try clock.receive(remote: remote, now: now)
        } catch {
            CloudSyncBreadcrumb.clockReceiveRejected(reason: "\(error)")
            MetricsService.cloudSyncClockReceiveRejected(reason: "\(error)")
            #if DEBUG
            print("CloudSyncEngine: receiveRemoteClock falló para \(remote): \(error)")
            #endif
        }
    }

    /// El `latest` del reloj como string c1 (para persistir en `clockLatestHLC`). `nil` = reloj fresco.
    var clockLatestString: String? { clock.latest?.description }

    /// §d.5 A1 (D-6): fuerza `serverSeqCursor = 0` (re-pull completo). Lo invocará el guard de
    /// recuperación de I9 si `SyncQuarantine` se recreó por lightweight migration. Hook aquí + test.
    func resetServerSeqCursor(context: ModelContext) {
        do {
            let cursor = try loadOrCreateCursor(context)
            guard cursor.serverSeqCursor != 0 else { return }
            try saveWithAuthor(context, Self.outboxSaveAuthor) {
                cursor.serverSeqCursor = 0
            }
        } catch {
            #if DEBUG
            print("CloudSyncEngine: resetServerSeqCursor falló: \(error)")
            #endif
        }
    }

    /// §d.5 A1 (guard de recreación de cuarentena, I9): al arrancar, si el testigo lockstep dice que
    /// HABÍA filas de cuarentena (`quarantinePendingCount > 0`) pero la tabla `SyncQuarantine` está
    /// VACÍA (`COUNT == 0`), una lightweight migration recreó la tabla → los deltas cuarentenados se
    /// perdieron. Fuerza `serverSeqCursor = 0` (re-pull completo reconstruye lo perdido) + resetea el
    /// testigo, ambos en UN save. No-op si el testigo y la tabla son coherentes. Lo invoca `start()` del
    /// runtime ANTES del rehydrate/primer pull.
    func recoverIfQuarantineRecreated(context: ModelContext) {
        do {
            let cursor = try loadOrCreateCursor(context)
            guard cursor.quarantinePendingCount > 0 else { return }
            let liveCount = try context.fetchCount(FetchDescriptor<SyncQuarantine>())
            guard liveCount == 0 else { return }  // testigo y tabla coherentes → nada que recuperar
            try saveWithAuthor(context, Self.outboxSaveAuthor) {
                cursor.serverSeqCursor = 0
                cursor.quarantinePendingCount = 0
            }
            CloudSyncBreadcrumb.quarantineTableRecreated()
        } catch {
            #if DEBUG
            print("CloudSyncEngine: recoverIfQuarantineRecreated falló: \(error)")
            #endif
        }
    }

    /// Ejecuta `body` y hace `context.save()` bajo un `author` dado, restaurando el autor previo.
    /// Centraliza el manejo de `context.author` para los saves internos del motor. `internal` (no
    /// `private`): lo comparte `SyncApplyEngine`.
    func saveWithAuthor(
        _ context: ModelContext, _ author: String, _ body: () throws -> Void
    ) throws {
        let previous = context.author
        context.author = author
        defer { context.author = previous }
        try body()
        try context.save()
    }

    /// Resultado tri-estado del decode del token persistido (DIFERIDOS #33): distinguir `absent`
    /// (bootstrap legítimo) de `broken` (la clase del hazard) es lo que permite acotar el fallback.
    private enum TokenDecodeResult {
        case absent
        case valid(DefaultHistoryToken)
        case broken

        var logicState: HistoryTokenFallbackLogic.TokenState {
            switch self {
            case .absent: .absent
            case .valid: .valid
            case .broken: .broken
            }
        }
    }

    private func decodeToken(_ data: Data?) -> TokenDecodeResult {
        guard let data else { return .absent }
        do {
            return .valid(try JSONDecoder().decode(DefaultHistoryToken.self, from: data))
        } catch {
            // Token in-decodificable (migración destructiva de schema) → DIFERIDOS #33: la rama la
            // decide `HistoryTokenFallbackLogic` (acotado por ancla en vez del full-rescan de I3);
            // el breadcrumb con nombre de rama lo emite `executeBrokenTokenBranch`.
            #if DEBUG
            print("CloudSyncEngine: decodeToken falló: \(error)")
            #endif
            return .broken
        }
    }

    private func encodeToken(_ token: DefaultHistoryToken) throws -> Data {
        try JSONEncoder().encode(token)
    }

    /// Resultado del paso 3 del drain: las transacciones a procesar + el estado del fallback de
    /// token roto (DIFERIDOS #33) que el resto del drain consume (saltar el guard 3-bis; re-anclar
    /// en el paso 7).
    private struct HistoryFetchOutcome {
        var txns: [DefaultHistoryTransaction]
        /// El token estaba ROTO (in-decodificable o fetch por token que lanzó) → el guard del
        /// Hallazgo 2 se salta (nada que validar) y, sin reanchor, el token roto persiste.
        var tokenWasBroken = false
        /// Rama acotada con ventana NO vacía: última tx de la ventana a la que el paso 7 re-ancla
        /// el token (motor incluido — misma justificación que el reanchor del guard).
        var brokenReanchor: (token: DefaultHistoryToken, txAt: Date)?
    }

    /// Paso 3 del drain (DIFERIDOS #33). Rama por `HistoryTokenFallbackLogic.decide`:
    /// - token válido → fetch por token (normal); si LANZA (token incompatible tras migración
    ///   destructiva) → re-decide con `.broken` — misma clase que in-decodificable.
    /// - token ausente → escaneo completo LEGÍTIMO de bootstrap (comportamiento de siempre).
    /// - token roto → `executeBrokenTokenBranch` (acotado por ancla / full-rescan medido).
    private func fetchHistoryResolvingToken(
        _ tokenState: TokenDecodeResult, cursor: SyncCursor, context: ModelContext
    ) throws -> HistoryFetchOutcome {
        let branch = HistoryTokenFallbackLogic.decide(
            tokenState: tokenState.logicState,
            lastDrainedTxAt: cursor.lastDrainedTxAt,
            slack: Self.historyTokenSlack)
        switch branch {
        case .tokenFetch:
            guard case .valid(let token) = tokenState else {
                // Inalcanzable (`decide` solo devuelve .tokenFetch con .valid), defensivo.
                return HistoryFetchOutcome(
                    txns: try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()))
            }
            do {
                if _testThrowOnTokenHistoryFetch { throw CloudSyncCursorError.historyTokenExpired }
                return HistoryFetchOutcome(txns: try context.fetchHistory(
                    HistoryDescriptor<DefaultHistoryTransaction>(
                        predicate: #Predicate { $0.token > token })))
            } catch {
                #if DEBUG
                print("CloudSyncEngine: fetch por token lanzó (\(error)) → fallback de token roto")
                #endif
                return try executeBrokenTokenBranch(
                    HistoryTokenFallbackLogic.decide(
                        tokenState: .broken,
                        lastDrainedTxAt: cursor.lastDrainedTxAt,
                        slack: Self.historyTokenSlack),
                    context: context)
            }
        case .fullRescanBootstrap:
            return HistoryFetchOutcome(
                txns: try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()))
        case .boundedRescan, .fullRescanNoAnchor:
            return try executeBrokenTokenBranch(branch, context: context)
        }
    }

    /// Ejecuta la rama de token ROTO (DIFERIDOS #33). Ver el doc-comment de la rama acotada en
    /// `HistoryTokenFallbackLogic.Branch`; aquí las semánticas resueltas del cierre:
    /// - **(acotada)** fetch por timestamp `> cutoff` (= ancla − slack): todo lo ≤ cutoff ya fue
    ///   drenado (invariante del ancla) → NO se re-emite el corpus. La frontera del slack se re-lee y
    ///   re-emite con HLC fresco → outbox redundante que el backend colapsa por LWW (coste acotado,
    ///   mismo residual T3 del guard). Ventana NO vacía → `brokenReanchor` a su última tx (el paso 7
    ///   persiste y emite el par `historyTokenBrokenReanchored`). Ventana VACÍA (History purgada por
    ///   debajo del ancla) → sin reanchor: el token roto persiste y cada drain repite este fallback
    ///   (un decode fallido + un fetch acotado vacío — barato) hasta que un write nuevo entre en la
    ///   ventana y sane. Nota de orden: el reanchor usa `txns.last` en el ORDEN del fetch (orden de
    ///   token/inserción, sin re-ordenar por timestamp como hace la unión del guard) — bajo reloj
    ///   monótono coinciden; bajo rewind el `txAt` del re-ancla puede quedar por debajo del máximo
    ///   visto, dirección SEGURA (ventana más ancha después → coste de re-lectura, no pérdida).
    ///   **Residual REWIND (cita M1 del guard):** un ancla ADELANTADA al wall-clock
    ///   (solo posible por rewind de reloj > slack durante la ventana del último drain) deja writes
    ///   nuevos con `timestamp < cutoff` fuera de la ventana — con token roto este fallback es
    ///   load-bearing (única fuente de captura) y esos writes del gap se pierden de la captura hasta
    ///   que el wall-clock re-pase el cutoff (sana hacia adelante; el gap no se recupera). Misma
    ///   improbabilidad que M1 y además exige el token roto SIMULTÁNEO; no se resuelve con wall-clock
    ///   (`Date()`) — el guard lo descartó por diseño y se mantiene la coherencia.
    /// - **(b — degradación)** el fetch acotado TAMBIÉN lanza → full-rescan MEDIDO en vez de abortar:
    ///   abortar convertiría un fallo persistente del predicate-fetch en stall permanente del sync =
    ///   divergencia local-ahead (la clase inconvergible del Hallazgo 2) = riesgo de pérdida de datos
    ///   si el device muere; el daño del full-rescan es de COSTO y converge (LWW).
    /// - **(a — sin ancla)** cursor pre-schema → full-rescan CONSERVADO (sin ancla no hay forma de
    ///   acotar sin arriesgar pérdida de writes). Residual conservado: si la History no tiene NINGUNA
    ///   tx externa, `advancedToken` queda nil → el token roto persiste → full-rescan repetido por
    ///   drain (exactamente el comportamiento pre-#33; no se empeora ni se arregla).
    private func executeBrokenTokenBranch(
        _ branch: HistoryTokenFallbackLogic.Branch, context: ModelContext
    ) throws -> HistoryFetchOutcome {
        switch branch {
        case .boundedRescan(let cutoff):
            do {
                if _testThrowOnBoundedHistoryFetch { throw CloudSyncCursorError.historyTokenExpired }
                let txns = try context.fetchHistory(
                    HistoryDescriptor<DefaultHistoryTransaction>(
                        predicate: #Predicate { $0.timestamp > cutoff }))
                historyTokenBrokenBoundedCount += 1
                CloudSyncBreadcrumb.historyTokenBrokenBoundedRescan(window: txns.count)
                let reanchor = txns.last.map { (token: $0.token, txAt: $0.timestamp) }
                return HistoryFetchOutcome(
                    txns: txns, tokenWasBroken: true, brokenReanchor: reanchor)
            } catch {
                // Semántica (b): degradar al full-rescan medido (ver doc-comment).
                #if DEBUG
                print("CloudSyncEngine: fetch acotado del fallback lanzó (\(error)) → full-rescan degradado")
                #endif
                let txns = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
                historyTokenBrokenFullRescanCount += 1
                CloudSyncBreadcrumb.historyTokenBrokenFullRescan(
                    reason: "bounded-fetch-failed", txs: txns.count)
                return HistoryFetchOutcome(txns: txns, tokenWasBroken: true)
            }
        case .fullRescanNoAnchor:
            let txns = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
            historyTokenBrokenFullRescanCount += 1
            CloudSyncBreadcrumb.historyTokenBrokenFullRescan(reason: "no-anchor", txs: txns.count)
            return HistoryFetchOutcome(txns: txns, tokenWasBroken: true)
        case .tokenFetch, .fullRescanBootstrap:
            // Inalcanzable (solo se invoca con ramas de token roto), defensivo.
            return HistoryFetchOutcome(
                txns: try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()),
                tokenWasBroken: true)
        }
    }

    // MARK: - Dedup / encoding

    private func existingOutboxKeys(_ context: ModelContext) throws -> Set<String> {
        let existing = try context.fetch(FetchDescriptor<SyncOutbox>())
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

    /// Serializa el `field_hlcs` (mapa unidad-de-coherencia → HLC) como JSON plano `{unit:hlc}` con
    /// claves ordenadas (determinista). Vacío → `"{}"` (no ocurre en upserts: siempre hay ≥1 unidad).
    private func encodeFieldHlcs(_ fieldHlcs: [String: String]) -> String {
        guard !fieldHlcs.isEmpty else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(fieldHlcs)
            return String(decoding: data, as: UTF8.self)
        } catch {
            #if DEBUG
            print("CloudSyncEngine: encodeFieldHlcs error: \(error)")
            #endif
            return "{}"
        }
    }

    // MARK: - SyncUnitClock (I8f-2, D-A) — hook del drain

    /// Actualiza el `SyncUnitClock` para UNA fila nueva de outbox, DENTRO del save del outbox (el
    /// caller garantiza la atomicidad). Upsert → merge MAX de las unidades emitidas (el `fieldHlcsJSON`
    /// de la fila ES la verdad de qué unidades viajaron con qué HLC). Tombstone → borrar la fila de
    /// clock (higiene del review; si el modelo resucita, drain/apply la re-pueblan).
    private func updateUnitClock(for row: PendingOutboxRow, context: ModelContext) {
        switch row.op {
        case .tombstone:
            SyncUnitClockStore.delete(syncID: row.syncID, context: context)
        case .upsert:
            // `entityType` de la fila es NOMBRE DE CLASE; el clock coordina por TABLA (como el wire).
            guard let table = EntityEmissionMap.table(forClass: row.entityType) else {
                #if DEBUG
                print("CloudSyncEngine.updateUnitClock: clase sin tabla \(row.entityType) — clock omitido")
                #endif
                return
            }
            guard let json = row.fieldHlcsJSON else { return }  // sin unidades (no ocurre en upserts)
            let units = SyncUnitClockStore.decodeMap(json)
            SyncUnitClockStore.upsert(syncID: row.syncID, entityTable: table,
                                      unitHlcs: units, context: context)
        }
    }

    // MARK: - Espejo del outbox (A1, §d.5)

    /// Escribe el espejo `.atomic` de cada fila NUEVA de un drain, ANTES del insert+save (mismo cuerpo
    /// síncrono). Best-effort: un fallo se loguea y NO aborta el drain (la History es backup redundante
    /// y el canario de divergencia lo delata). No-op sin `outboxMirror` + `currentUserID` (I8d DARK).
    private func writeMirror(rows: [PendingOutboxRow]) {
        guard let mirror = outboxMirror, let userID = currentUserID else { return }
        for row in rows {
            do {
                try mirror.write(row.mirrorEntry(userID: userID))
            } catch {
                #if DEBUG
                print("CloudSyncEngine: espejo write falló para \(row.entityType): \(error)")
                #endif
            }
        }
    }

    /// Re-hidrata el outbox desde el espejo App Group tras una lightweight migration que recreó la tabla
    /// (§d.5 A1). Se llama en `startEngines` ANTES del primer drain/pull (el wiring es I9); aquí solo el
    /// método + tests.
    ///
    /// **DIFF INCONDICIONAL con owner-scoping DURO**: solo procesa `entriesForUser(userID)` (las de otra
    /// identidad se IGNORAN — no se re-insertan ni se borran, red M1(b)); por cada entry cuyo
    /// `(syncID,hlc,op)` NO tiene fila viva en `SyncOutbox` (fetch CONCRETO), re-inserta con
    /// `author`/`clientMutationID`/`hlc`/`op` ORIGINALES. **SIN gate `count==0`** → cubre el vaciado
    /// PARCIAL. Idempotente (guard "fila viva ya presente"). El SAVE va bajo `outboxSaveAuthor` → el drain
    /// NO re-captura las filas re-insertadas (self-echo). Un archivo huérfano (crash entre purga y remove)
    /// es benigno: se re-inserta, el drain lo re-sube, el backend deduplica por `client_mutation_id`.
    /// Emite `cloudSyncOutboxMirrorRehydrated(n>0)` y `cloudSyncOutboxMirrorDivergence(delta≠0)`.
    func rehydrateOutboxFromMirror(userID: String, context: ModelContext) {
        guard let mirror = outboxMirror else { return }
        let entries = mirror.entriesForUser(userID)

        // Filas vivas actuales (fetch concreto) → keys de dedup + conteo para divergencia.
        let liveKeys: Set<String>
        let liveCount: Int
        do {
            let live = try context.fetch(FetchDescriptor<SyncOutbox>())
            liveCount = live.count
            liveKeys = try existingOutboxKeys(context)
        } catch {
            #if DEBUG
            print("CloudSyncEngine: rehydrate fetch(SyncOutbox) falló: \(error)")
            #endif
            return
        }

        // Divergencia = |espejo del userID| − |store| (medida ANTES de re-insertar). >0 = archivo huérfano
        // o vaciado parcial → el modo de fallo que ni el Merkle ve.
        let divergence = entries.count - liveCount
        if divergence != 0 {
            MetricsService.cloudSyncOutboxMirrorDivergence(delta: divergence)
        }

        // Seleccionar las entries faltantes (idempotente: guard "fila viva ya presente").
        var missing: [OutboxMirrorEntry] = []
        for entry in entries {
            guard let op = SyncOutboxOp(rawValue: entry.op) else { continue }
            let key = dedupKey(syncID: entry.syncID, hlc: entry.hlc, op: op)
            if !liveKeys.contains(key) { missing.append(entry) }
        }
        guard !missing.isEmpty else { return }

        // Re-insertar bajo el autor del motor (echo-suppression) con los valores ORIGINALES.
        do {
            try saveWithAuthor(context, Self.outboxSaveAuthor) {
                for entry in missing {
                    guard let op = SyncOutboxOp(rawValue: entry.op) else { continue }
                    context.insert(SyncOutbox(
                        syncID: entry.syncID,
                        entityType: entry.entityType,
                        op: op,
                        hlc: entry.hlc,
                        clientMutationID: entry.clientMutationID,
                        fieldsJSON: entry.fieldsJSON,
                        fieldHlcsJSON: entry.fieldHlcsJSON,
                        author: entry.author,
                        tombstoneReason: entry.tombstoneReason,
                        createdAt: entry.createdAt
                    ))
                }
            }
        } catch {
            #if DEBUG
            print("CloudSyncEngine: rehydrate save falló: \(error)")
            #endif
            return
        }
        MetricsService.cloudSyncOutboxMirrorRehydrated(count: missing.count)
    }

    /// HOOK I8e (2xx): purga la fila del outbox subida con éxito + borra su archivo espejo, y SOLO
    /// ENTONCES el corte de `deleteHistory` puede avanzar sobre ella (invariante §d.5 —
    /// `deleteHistorySafeCut`). En I8d el drain NO lo llama solo (no hay upload todavía); lo invocará el
    /// cliente HTTP de I8e al recibir el 2xx. Idempotente (fila/archivo ya ausentes → no-op).
    func confirmUploaded(syncID: UUID, hlc: String, context: ModelContext) {
        do {
            let rows = try context.fetch(FetchDescriptor<SyncOutbox>(
                predicate: #Predicate { $0.syncID == syncID && $0.hlc == hlc }
            ))
            if !rows.isEmpty {
                try saveWithAuthor(context, Self.outboxSaveAuthor) {
                    for row in rows { context.delete(row) }
                }
            }
        } catch {
            #if DEBUG
            print("CloudSyncEngine: confirmUploaded purge falló: \(error)")
            #endif
        }
        // El espejo se borra DESPUÉS del purge de la fila (orden espeja el write: fila-primero al subir).
        outboxMirror?.remove(syncID: syncID, hlc: hlc)
    }

    /// Corte SEGURO para `deleteHistory(before:)` (invariante §d.5): NUNCA por delante de la fila de
    /// outbox sin-2xx más vieja. `drainedBoundary` = hasta dónde consumió el drain la History (nil = sin
    /// restricción por ese lado). Retorna `min(drainedBoundary, createdAt de la fila outbox presente más
    /// vieja)`; `nil` = ni fila sin-confirmar ni boundary → sin restricción. En I8d NO hay un
    /// `deleteHistory` real todavía (I8e/I9 lo cablean): esto EXPRESA el invariante testeable —
    /// `confirmUploaded` purga la fila, y solo entonces el corte avanza sobre ella.
    func deleteHistorySafeCut(drainedBoundary: Date?, context: ModelContext) throws -> Date? {
        let oldestUnconfirmed = try oldestUnconfirmedOutboxDate(context)
        switch (drainedBoundary, oldestUnconfirmed) {
        case (nil, nil): return nil
        case (let d?, nil): return d
        case (nil, let o?): return o
        case (let d?, let o?): return min(d, o)
        }
    }

    /// `createdAt` de la fila de outbox presente (= sin-2xx) más vieja, o `nil` si el outbox está vacío.
    private func oldestUnconfirmedOutboxDate(_ context: ModelContext) throws -> Date? {
        var descriptor = FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.createdAt
    }

    /// Purga el SwiftData History por delante del corte SEGURO (I9 ampliado, §i.6 purga conservadora).
    /// El corte lo calcula `deleteHistorySafeCut(drainedBoundary: now)` — invariante §d.5: NUNCA por
    /// delante de la fila de outbox sin-2xx más vieja (su transacción de History es el backup del delta
    /// hasta el 2xx; el espejo App Group es la red redundante, no la primaria). Se llama SOLO tras un
    /// ciclo del runtime con pull `.completed` (drain ya consumió toda la history externa → `now` es un
    /// boundary honesto) y bajo DOBLE flag (`syncRuntimeEnabled` + `historyPurgeEnabled` — el riesgo
    /// device-only del token del mirror de NSPersistentCloudKitContainer se resuelve en el spike S2).
    ///
    /// - Returns: nº de transacciones purgadas; `nil` si no había corte, no había nada que purgar, o el
    ///   fetch/delete falló (con log — un fallo NUNCA rompe el ciclo).
    @discardableResult
    func purgeHistoryOnce(context: ModelContext, now: Date = .now) -> Int? {
        do {
            guard let cut = try deleteHistorySafeCut(drainedBoundary: now, context: context) else {
                return nil  // sin restricción calculable → conservador: no purgar nada
            }
            // Contar ANTES de borrar (deleteHistory devuelve Void). Mismo predicate en fetch y delete.
            let descriptor = HistoryDescriptor<DefaultHistoryTransaction>(
                predicate: #Predicate { $0.timestamp < cut }
            )
            let count = try context.fetchHistory(descriptor).count
            guard count > 0 else { return nil }
            try context.deleteHistory(descriptor)
            CloudSyncBreadcrumb.historyPurged(count: count)
            return count
        } catch {
            #if DEBUG
            print("CloudSyncEngine: purgeHistoryOnce falló (el ciclo continúa): \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Snapshot upload seam (I10-wiring w4)

    /// Avanza el token del `SyncCursor` al ÚLTIMO de History SIN emitir (baseline del snapshot, §g).
    /// Corre ANTES de enumerar el snapshot para CERRAR la ventana de escrituras concurrentes: todo write
    /// posterior al baseline aparece en History y lo captura el drain normal como delta INCREMENTAL
    /// (idempotente aunque el snapshot ya lo hubiera incluido: LWW por unidad converge). Save con el autor
    /// del motor (anti-auto-captura, lockstep D-3 intacto: no se emite ninguna fila). No-op si no hay
    /// History todavía. Un fallo se loguea (DEBUG) y NUNCA rompe la fase (el snapshot re-enumerará full-row).
    func fastForwardHistoryBaseline(context: ModelContext) {
        do {
            let cursor = try loadOrCreateCursor(context)
            let txns = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
            // Anclar el baseline al último token de una transacción NO-motor (autor ≠ outboxSaveAuthor).
            // Lo que este filtro garantiza (ajuste del review adversarial — la versión previa del comentario
            // sobre-vendía "dominio/store personal"): excluye las transacciones RECIÉN escritas por el
            // propio motor (creación del cursor / este mismo save), cuyo token bajo carga resultó
            // intermitentemente NO-comparable con writes futuros del store personal (bug real cazado por
            // test: `token > baseline` cross-store fallaba ~50% → el drain se saltaba writes concurrentes
            // post-baseline = pérdida silenciosa). La tx anclada PUEDE seguir siendo del store sync-meta
            // (p.ej. el save de captura de SyncIdentity, autor default) — eso es SEGURO por la misma
            // monotonía global de tokens en la que el drain ya se apoya a diario (avanza su cursor con
            // tokens de SyncIdentity de forma rutinaria, device-probado); lo que NO era seguro es anclar a
            // la tx del PROPIO save del motor. Sin tx no-motor todavía (born-cloud), no hay ventana que
            // cerrar → return (token queda como estaba).
            guard let lastTx = txns.last(where: { $0.author != Self.outboxSaveAuthor }) else { return }
            try saveWithAuthor(context, Self.outboxSaveAuthor) {
                cursor.historyTokenData = try encodeToken(lastTx.token)
                // Estampar el ancla temporal JUNTO al token (S1 del review adversarial): un fast-forward
                // deja a propósito txs jamás drenadas por debajo del token (el snapshot las cubre full-row);
                // sin mover `lastDrainedTxAt`, el guard de validación del primer drain (re-migración sobre
                // la misma instalación, token viejo semanas atrás) las vería TODAS como "faltantes" →
                // recovery masiva del corpus + canario `historyTokenIncomparable` FALSO. Token y ancla
                // deben avanzar SIEMPRE en el mismo save.
                cursor.lastDrainedTxAt = lastTx.timestamp
            }
        } catch {
            #if DEBUG
            print("CloudSyncEngine: fastForwardHistoryBaseline falló: \(error)")
            #endif
        }
    }

    /// Encola una página de filas de snapshot (op `.upsert` full-row) reusando la disciplina PRIVADA del
    /// drain (`PendingOutboxRow` + `updateUnitClock` + persistencia del reloj) sin duplicarla (seam w4).
    ///
    /// El motor acuña el HLC por fila (`clock.send`, ÚNICO punto de advance) y llama `input.makePayload(hlc)`
    /// — que construye `(fieldsJSON, fieldHlcsJSON)` con ese HLC en `field_hlcs`; `nil` = el codec c1 rechazó
    /// la fila (poison) → se SALTA y la página CONTINÚA (el builder ya emitió el canario; el mismatch
    /// permanente que esto provoca en verify degradará a `failedRollback` tras los topes — CORRECTO por
    /// diseño: jamás cutover con pérdida silenciosa de una fila).
    ///
    /// **INVARIANTE lockstep D-3**: el HLC consumido se persiste (`clockLatestHLC`) en el MISMO `save()` que
    /// inserta las filas de la página. Autor del motor (echo-suppression). `SyncUnitClock` SÍ se escribe por
    /// fila (los reconcilers lo necesitan; volumen aceptado). El dedup por `(syncID,hlc,op)` protege el
    /// replay dentro de una misma corrida; un kill entre enqueue y confirm re-emite con HLC NUEVO al resumir
    /// (el reloj persistido avanza) → el RPC lo resuelve por LWW (mismo contenido, converge) — H5: jamás
    /// resumir por contador. Las filas de snapshot NO se espejan al App Group (decisión de /review-plan): son
    /// RE-DERIVABLES (kill → el cursor no avanzó → la página se re-emite); el espejo A1 protege ediciones
    /// pendientes no re-derivables. `confirmUploaded` sobre una fila sin entrada de espejo es no-op benigno
    /// (`outboxMirror?.remove` sobre una key ausente no hace nada).
    func enqueueSnapshotRows(_ inputs: [SnapshotRowInput], context: ModelContext, now: Date) throws {
        guard !inputs.isEmpty else { return }
        let cursor = try loadOrCreateCursor(context)
        loadClock(from: cursor)
        var seen = try existingOutboxKeys(context)
        var rows: [PendingOutboxRow] = []
        for input in inputs {
            let hlc = try clock.send(now: now).description
            let key = dedupKey(syncID: input.syncID, hlc: hlc, op: .upsert)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            guard let payload = input.makePayload(hlc) else { continue }  // codec rechazó → skip (canario en el builder)
            rows.append(PendingOutboxRow(
                syncID: input.syncID, entityType: input.entityType, op: .upsert, hlc: hlc,
                clientMutationID: UUID(), fieldsJSON: payload.fieldsJSON, fieldHlcsJSON: payload.fieldHlcsJSON,
                author: Self.outboxSaveAuthor, tombstoneReason: nil, createdAt: now))
        }
        // Filas + SyncUnitClock + reloj en UN save (lockstep D-3). Aunque `rows` quede vacío (todo
        // deduplicado), persistir el avance del reloj es benigno e idempotente.
        try saveWithAuthor(context, Self.outboxSaveAuthor) {
            for row in rows {
                context.insert(row.makeModel())
                updateUnitClock(for: row, context: context)
            }
            cursor.clockLatestHLC = clock.latest?.description
        }
    }

    /// Dead-letterea filas poison (#26) fuera del camino del runtime (que conserva su copia privada ya
    /// probada). Consumido por el uploader del snapshot y el verify del executor (I10-wiring w4/w5, fix del
    /// review adversarial del ciclo B): sin esto, una fila poison quedaría VIVA para siempre → el uploader
    /// jamás confirma su página (migración ATASCADA en uploadingSnapshot, transient perpetuo) y el guard
    /// `outbox-pending` de `verifyIntegrity` produce `newDeltaDetected` en LIVELOCK. Dead-letterearla la saca
    /// de las filas vivas; el mismatch resultante degrada honesto a `failedRollback` por topes (jamás cutover
    /// con pérdida silenciosa). Imposible hoy (16/16 cableadas ⇒ sin poison); protege el futuro.
    func deadLetterPoison(_ poison: [SyncPushClient.PoisonRow], context: ModelContext, now: Date) {
        guard !poison.isEmpty else { return }
        do {
            try saveWithAuthor(context, Self.outboxSaveAuthor) {
                for p in poison {
                    p.row.rejectedReason = p.reason
                    p.row.rejectedAt = now
                }
            }
        } catch {
            #if DEBUG
            print("CloudSyncEngine.deadLetterPoison: save falló: \(error)")
            #endif
            return
        }
        for p in poison { MetricsService.cloudSyncMutationRejected(reason: p.reason) }
    }
}

// MARK: - IdentityRemap (DIFERIDOS #29, §b.4)

/// Descriptor de UN re-key de identidad: la entidad, su sync_id VIEJO y el NUEVO. UUID-only (el emisor
/// resuelve el modelo VIVO desde el contexto por `newID`). `entityType` = `SyncEntityType.tag/account/subcategory`
/// (las 3 identidades regenerables hoy — `Tag.id`/`Account.shortcutID`/`Subcategory.shortcutID`, vía
/// `CategoryDeduplicationService.repairCollapsedIdentityUUIDs`). Si un futuro sitio regenerara otra identidad
/// cableada (Budget/ScheduledPayment/CashFlow*/NotificationItem/GroupBridgePreference), DEBE pasar por
/// `emitIdentityRemap` (añadir su rama de dispatch) — el canario D4 queda como red hasta entonces.
struct IdentityRemapPair {
    let entityType: String
    let oldID: UUID
    let newID: UUID
}

/// Errores del emisor de IdentityRemap. Nombrados (nunca silenciados): el reparador los convierte en
/// ROLLBACK + breadcrumb `identityRemapAborted` + defer (SERIO 1 del review).
nonisolated enum IdentityRemapError: Error, Equatable {
    /// SERIO 3 (R4 del plan): una migración/reversa §g/§h está EN CURSO (fase transitoria journaleada) —
    /// el journal/lease posee el outbox en esa ventana; inyectar filas de remap corrompería el snapshot/verify.
    /// El reparador difiere al próximo run del dedup (fase estable).
    case migrationInProgress
}

/// Resultado de `emitIdentityRemap`: el conteo + las filas pendientes de ESPEJO (opacas al llamador — el
/// contenido es `fileprivate`). SERIO 2 del review: el espejo App Group NO se escribe en la emisión sino
/// POST-save del llamador (`mirrorRemapRows`) — espejar antes del save envenenaba el App Group si el save
/// fallaba (dominio revertido pero entries vivas → `rehydrateOutboxFromMirror` re-insertaría y pushearía un
/// tombstone de un id VIVO + un upsert huérfano).
struct IdentityRemapEmission {
    /// nº de filas de outbox encoladas (0 = gate cerrado o nada que emitir).
    let rowCount: Int
    fileprivate let rows: [PendingOutboxRow]

    fileprivate init(rowCount: Int, rows: [PendingOutboxRow]) {
        self.rowCount = rowCount
        self.rows = rows
    }

    /// Emisión vacía (gate cerrado / sin pares).
    static var empty: IdentityRemapEmission { IdentityRemapEmission(rowCount: 0, rows: []) }
}

extension CloudSyncEngine {

    /// SERIO 3 (R4 del plan): `true` si hay una migración/reversa §g/§h EN CURSO (fase TRANSITORIA journaleada)
    /// → el remap NO debe emitirse (el journal/lease posee el outbox en esa ventana). Predicado CANÓNICO
    /// reusado, NO inventado: la clasificación estable/transitoria EXHAUSTIVA de `BGTaskMigrationGate.decide`
    /// (rol `.reader`, quiescencia irrelevante — las fases estables devuelven `.run` incondicional) sobre la
    /// fase SSOT (`MigrationPhaseStore.shared.currentPhase`, el mismo journal que consultan los BGTasks §i.9).
    /// El reparador lo PRE-consulta antes de mutar dominio (así el defer no necesita rollback); `emitIdentityRemap`
    /// lo re-verifica como defensa en profundidad.
    var isIdentityRemapBlockedByMigration: Bool {
        let phase = _testMigrationPhaseOverride ?? MigrationPhaseStore.shared.currentPhase
        return BGTaskMigrationGate.decide(phase: phase, isImportQuiescent: false, role: .reader) != .run
    }

    /// Emite el trío de identidad de §b.4 para cada `pair` regenerado, ENCOLÁNDOLO en `context` **SIN save** (el
    /// llamador — `repairCollapsedIdentityUUIDs` — comitea dominio + outbox en UNA transacción de History, §b.4
    /// crítica #6):
    ///   a) `tombstone(oldID)` con reason `.remap` — **DEDUP por `oldID`**: un grupo colisionado (X→A, X→B, …)
    ///      emite UN solo `tombstone(X)`;
    ///   b) `upsert` FILA-COMPLETA (proyección INSERT = `emission.columns`) de la fila con `newID`;
    ///   c) `upsert` FILA-COMPLETA de cada fila REFERENCIANTE — sus `*_ref`/`tag_refs` se derivan de la relación
    ///      VIVA en la emisión → sin re-emitirlas divergen para SIEMPRE (misma clase que el bug FX del device run
    ///      2026-07-11: la proyección cambia sin write → History no captura → jamás push). Enumeradas por TRAVESÍA
    ///      de relaciones INVERSAS del modelo remapeado (dispatch CONCRETO por tipo, jamás `#Predicate` genérico).
    ///      Cobertura por el manifest: `account_ref` en tx_items/scheduled/inbox/favorites; `subcategory_ref` en
    ///      esos 4 + merchant_memory + cashflow_lines; `tag_refs` en tx_items/scheduled/inbox/favorites/budgets
    ///      (los CSV de Budget account_ids/subcategory_ids y los tagIDs los rehace el reparador → drain posterior).
    ///
    /// + HLCs acuñados vía la MISMA `clock.send` (lockstep §d.5) + persistencia del reloj (`clockLatestHLC`) EN
    ///   el contexto (lo comitea el save del llamador). La limpieza de los `SyncUnitClock` del `oldID` la hace
    ///   `updateUnitClock` al insertar el tombstone (higiene; espeja el applier de un tombstone remoto).
    ///
    /// ESPEJO App Group **DIFERIDO** (SERIO 2 del review): esta función NO espeja — devuelve las filas en el
    /// `IdentityRemapEmission` y el llamador invoca `mirrorRemapRows(_:)` DESPUÉS de su `try context.save()`
    /// exitoso. Espejar antes del save envenenaba el App Group si el save fallaba (ver doc de la struct).
    ///
    /// El drain POSTERIOR verá el UPDATE identity-only → SKIP (D4) + re-emitirá los patches CSV del reparador
    /// (redundante con (c), inofensivo: HLC distinto ⇒ el dedup `(syncID,hlc,op)` no los colisiona, backend LWW converge).
    ///
    /// GATES: (1) `storageMode == .cloud` (el motor solo sincroniza el store personal en `.cloud`; en `.icloud`
    /// está DARK) → gate cerrado = no-op que devuelve `.empty`. (2) SERIO 3 (R4): fase de migración/reversa
    /// TRANSITORIA journaleada → `throw IdentityRemapError.migrationInProgress` (el outbox pertenece al runner en
    /// esa ventana). `now` inyectable para HLCs deterministas en tests.
    ///
    /// - Returns: la emisión (conteo + filas pendientes de espejo). `throws`: `IdentityRemapError`, errores del
    ///   fetch o `ClockDriftError` — el reparador los convierte TODOS en rollback + defer (SERIO 1).
    @discardableResult
    func emitIdentityRemap(pairs: [IdentityRemapPair], in context: ModelContext, now: Date = .now) throws -> IdentityRemapEmission {
        guard CloudSyncFlags.storageMode == .cloud else { return .empty }
        guard !pairs.isEmpty else { return .empty }

        // SERIO 3 (R4): JAMÁS inyectar filas al outbox con una migración/reversa §g/§h EN CURSO — el
        // journal/lease posee el outbox en esa ventana (el snapshot/verify enumeran filas vivas; un remap
        // concurrente les cambiaría el corpus debajo). El reparador PRE-consulta el mismo predicado
        // (`isIdentityRemapBlockedByMigration`) ANTES de mutar dominio; este guard es la defensa en
        // profundidad para cualquier llamador futuro.
        guard !isIdentityRemapBlockedByMigration else {
            throw IdentityRemapError.migrationInProgress
        }

        // Cursor SIN save: `loadOrCreateCursor` SALVA (bajo `outboxSaveAuthor`) al crear uno fresco — eso
        // comitearía las mutaciones de dominio PENDIENTES del reparador bajo el autor del motor → el drain las
        // descartaría por echo-suppression (los patches CSV JAMÁS se capturarían). Aquí solo fetch/insert EN
        // MEMORIA; el `save()` del llamador (autor DEFAULT, §b.4) comitea cursor + dominio + outbox juntos.
        // En prod el cursor ya existe (el drain de arranque lo creó); este insert es la red del edge sin-drain.
        var cursorDescriptor = FetchDescriptor<SyncCursor>()
        cursorDescriptor.fetchLimit = 1
        let cursor: SyncCursor
        if let existing = try context.fetch(cursorDescriptor).first {
            cursor = existing
        } else {
            let fresh = SyncCursor()
            context.insert(fresh)
            cursor = fresh
        }
        loadClock(from: cursor)
        var seen = try existingOutboxKeys(context)
        var rows: [PendingOutboxRow] = []
        var tombstonedOldIDs: Set<UUID> = []
        var emittedUpsertSyncIDs: Set<UUID> = []
        var perEntityCount: [String: Int] = [:]

        // Fetch-all + match EN MEMORIA por `newID` (NUNCA un `#Predicate` sobre el id NUEVO: la reasignación del
        // reparador está sin-save en memoria → un predicado SQL la fallaría; además es la regla inviolable de
        // `#Predicate`). Solo los tipos presentes en `pairs` (fetch concreto por tipo).
        let needTag = pairs.contains { $0.entityType == SyncEntityType.tag }
        let needAccount = pairs.contains { $0.entityType == SyncEntityType.account }
        let needSub = pairs.contains { $0.entityType == SyncEntityType.subcategory }
        let tags = needTag ? try context.fetch(FetchDescriptor<Tag>()) : []
        let accounts = needAccount ? try context.fetch(FetchDescriptor<Account>()) : []
        let subcategories = needSub ? try context.fetch(FetchDescriptor<Subcategory>()) : []

        for pair in pairs {
            switch pair.entityType {
            case SyncEntityType.tag:
                guard let tag = tags.first(where: { $0.id == pair.newID }) else { continue }
                try appendRemapTombstoneIfNeeded(oldID: pair.oldID, entityType: SyncEntityType.tag, now: now,
                                                 tombstoned: &tombstonedOldIDs, seen: &seen, rows: &rows)
                try appendRemapFullUpsert(model: tag, emission: EntityEmissionMap.tag, syncID: pair.newID,
                                          entityType: SyncEntityType.tag, now: now,
                                          emitted: &emittedUpsertSyncIDs, seen: &seen, rows: &rows)
                try appendReferencing(tag.transactions, SyncEntityType.transactionItem, EntityEmissionMap.transactionItem, { $0.syncID }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(tag.scheduledPayments, SyncEntityType.scheduledPayment, EntityEmissionMap.scheduledPayment, { $0.id }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(tag.inboxDrafts, SyncEntityType.inboxDraft, EntityEmissionMap.inboxDraft, { $0.syncID }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(tag.favoritePayments, SyncEntityType.favoritePayment, EntityEmissionMap.favoritePayment, { $0.syncID }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(tag.budgets, SyncEntityType.budget, EntityEmissionMap.budget, { $0.id }, now, &emittedUpsertSyncIDs, &seen, &rows)
                perEntityCount[SyncEntityType.tag, default: 0] += 1

            case SyncEntityType.account:
                guard let account = accounts.first(where: { $0.shortcutID == pair.newID }) else { continue }
                try appendRemapTombstoneIfNeeded(oldID: pair.oldID, entityType: SyncEntityType.account, now: now,
                                                 tombstoned: &tombstonedOldIDs, seen: &seen, rows: &rows)
                try appendRemapFullUpsert(model: account, emission: EntityEmissionMap.account, syncID: pair.newID,
                                          entityType: SyncEntityType.account, now: now,
                                          emitted: &emittedUpsertSyncIDs, seen: &seen, rows: &rows)
                try appendReferencing(account.transactions, SyncEntityType.transactionItem, EntityEmissionMap.transactionItem, { $0.syncID }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(account.scheduledPayments, SyncEntityType.scheduledPayment, EntityEmissionMap.scheduledPayment, { $0.id }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(account.inboxDrafts, SyncEntityType.inboxDraft, EntityEmissionMap.inboxDraft, { $0.syncID }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(account.favoritePayments, SyncEntityType.favoritePayment, EntityEmissionMap.favoritePayment, { $0.syncID }, now, &emittedUpsertSyncIDs, &seen, &rows)
                perEntityCount[SyncEntityType.account, default: 0] += 1

            case SyncEntityType.subcategory:
                guard let sub = subcategories.first(where: { $0.shortcutID == pair.newID }) else { continue }
                try appendRemapTombstoneIfNeeded(oldID: pair.oldID, entityType: SyncEntityType.subcategory, now: now,
                                                 tombstoned: &tombstonedOldIDs, seen: &seen, rows: &rows)
                try appendRemapFullUpsert(model: sub, emission: EntityEmissionMap.subcategory, syncID: pair.newID,
                                          entityType: SyncEntityType.subcategory, now: now,
                                          emitted: &emittedUpsertSyncIDs, seen: &seen, rows: &rows)
                try appendReferencing(sub.transactions, SyncEntityType.transactionItem, EntityEmissionMap.transactionItem, { $0.syncID }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(sub.scheduledPayments, SyncEntityType.scheduledPayment, EntityEmissionMap.scheduledPayment, { $0.id }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(sub.inboxDrafts, SyncEntityType.inboxDraft, EntityEmissionMap.inboxDraft, { $0.syncID }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(sub.favoritePayments, SyncEntityType.favoritePayment, EntityEmissionMap.favoritePayment, { $0.syncID }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(sub.merchantMemories, SyncEntityType.merchantMemory, EntityEmissionMap.merchantMemory, { $0.syncID }, now, &emittedUpsertSyncIDs, &seen, &rows)
                try appendReferencing(sub.cashFlowLines, SyncEntityType.cashFlowLine, EntityEmissionMap.cashFlowLine, { $0.id }, now, &emittedUpsertSyncIDs, &seen, &rows)
                perEntityCount[SyncEntityType.subcategory, default: 0] += 1

            default:
                // entityType desconocido (no regenerable hoy) → no se emite (defensivo).
                continue
            }
        }

        guard !rows.isEmpty else { return .empty }

        // Insertar + `SyncUnitClock`, SIN save (el llamador comitea en la MISMA transacción) y SIN espejo
        // (SERIO 2: diferido a `mirrorRemapRows` post-save). El tombstone borra el `SyncUnitClock` del `oldID`
        // vía `updateUnitClock` (higiene — espeja el applier de un tombstone remoto).
        for row in rows {
            context.insert(row.makeModel())
            updateUnitClock(for: row, context: context)
        }
        cursor.clockLatestHLC = clock.latest?.description

        for (entity, count) in perEntityCount {
            CloudSyncBreadcrumb.identityRemapEmitted(entity: entity, count: count)
        }
        return IdentityRemapEmission(rowCount: rows.count, rows: rows)
    }

    /// SERIO 2: escribe el espejo App Group de las filas de un remap — invocado por el reparador DESPUÉS de su
    /// `try context.save()` exitoso (jamás antes: envenenaría el espejo si el save fallara). Best-effort, patrón
    /// `writeMirror` del drain (un fallo se loguea y no aborta; no-op sin `outboxMirror`+`currentUserID`).
    /// RESIDUAL ACEPTADO (inverso del envenenamiento, estrictamente mejor): un kill entre el save y este espejo
    /// deja filas de outbox durables SIN entry en el espejo — solo importa si el store sync-meta se RECREA
    /// (lightweight migration) antes del push (ventana epsilon²); el canario `cloudSyncOutboxMirrorDivergence`
    /// lo delataría.
    func mirrorRemapRows(_ emission: IdentityRemapEmission) {
        writeMirror(rows: emission.rows)
    }

    /// Encola el `tombstone(oldID)` reason `.remap`, DEDUP por `oldID` (grupo colisionado ⇒ UN tombstone). Acuña
    /// el HLC (advance del reloj) tras el dedup de `oldID` y ANTES del dedup `(syncID,hlc,op)` — espeja `appendRow`.
    private func appendRemapTombstoneIfNeeded(
        oldID: UUID, entityType: String, now: Date,
        tombstoned: inout Set<UUID>, seen: inout Set<String>, rows: inout [PendingOutboxRow]
    ) throws {
        guard !tombstoned.contains(oldID) else { return }
        tombstoned.insert(oldID)
        let hlc = try clock.send(now: now).description
        let key = dedupKey(syncID: oldID, hlc: hlc, op: .tombstone)
        guard !seen.contains(key) else { return }
        seen.insert(key)
        rows.append(PendingOutboxRow(
            syncID: oldID, entityType: entityType, op: .tombstone, hlc: hlc,
            clientMutationID: UUID(), fieldsJSON: "{}", fieldHlcsJSON: nil,
            author: "", tombstoneReason: SyncTombstoneReason.remap.rawValue, createdAt: now))
    }

    /// Encola un `upsert` FILA-COMPLETA (proyección INSERT = todas las columnas) de `model`. Dedup por `syncID`
    /// (una fila referenciada por 2 remaps se re-emite UNA vez) ANTES del advance del reloj. Codec rechaza →
    /// canario + fila descartada (clock ya avanzó → lockstep preservado, patrón `appendUpsert`).
    private func appendRemapFullUpsert<M: AnyObject>(
        model: M, emission: EntityEmission<M>, syncID: UUID, entityType: String, now: Date,
        emitted: inout Set<UUID>, seen: inout Set<String>, rows: inout [PendingOutboxRow]
    ) throws {
        guard !emitted.contains(syncID) else { return }
        emitted.insert(syncID)
        let hlc = try clock.send(now: now).description
        let key = dedupKey(syncID: syncID, hlc: hlc, op: .upsert)
        guard !seen.contains(key) else { return }
        seen.insert(key)
        let result = DeltaEmitter.emit(model: model, emission: emission, changedColumns: emission.columns, hlc: hlc)
        let fieldsJSON: String
        do {
            fieldsJSON = try Canonc1Codec.encode(result.fields, groupedColumns: Set(emission.groupByColumn.keys))
        } catch {
            #if DEBUG
            print("CloudSyncEngine.emitIdentityRemap: codec c1 rechazó \(entityType): \(error)")
            #endif
            CloudSyncBreadcrumb.encodeRejected(entity: entityType, reason: "\(error)")
            return
        }
        rows.append(PendingOutboxRow(
            syncID: syncID, entityType: entityType, op: .upsert, hlc: hlc,
            clientMutationID: UUID(), fieldsJSON: fieldsJSON, fieldHlcsJSON: encodeFieldHlcs(result.fieldHlcs),
            author: "", tombstoneReason: nil, createdAt: now))
    }

    /// Re-emite (upsert FULL) cada fila referenciante de un modelo remapeado, saltando las que aún NO tienen
    /// identidad de sync (nunca subidas → no divergen). Travesía por relación INVERSA (dispatch concreto por tipo).
    private func appendReferencing<M: PersistentModel>(
        _ models: [M]?, _ entityType: String, _ emission: EntityEmission<M>,
        _ syncID: (M) -> UUID?, _ now: Date,
        _ emitted: inout Set<UUID>, _ seen: inout Set<String>, _ rows: inout [PendingOutboxRow]
    ) throws {
        guard let models else { return }
        for model in models {
            guard let sid = syncID(model) else { continue }
            try appendRemapFullUpsert(model: model, emission: emission, syncID: sid, entityType: entityType,
                                      now: now, emitted: &emitted, seen: &seen, rows: &rows)
        }
    }
}

// MARK: - SnapshotRowInput (seam w4)

/// Insumo de UNA fila de snapshot para `CloudSyncEngine.enqueueSnapshotRows`. El motor acuña el HLC y llama
/// `makePayload(hlc)` — que construye `(fieldsJSON, fieldHlcsJSON)` con ese HLC en `field_hlcs`; `nil` = el
/// codec c1 rechazó la fila (poison) → el motor la SALTA (el builder ya emitió el canario). `entityType` =
/// NOMBRE DE CLASE (`SyncEntityType.*`), como el resto del outbox. El closure captura `@Model`/emisión → se
/// construye y consume SIEMPRE bajo el main actor (no cruza fronteras de actor).
struct SnapshotRowInput {
    let syncID: UUID
    let entityType: String
    let makePayload: (String) -> (fieldsJSON: String, fieldHlcsJSON: String?)?
}

// MARK: - PendingOutboxRow

/// Fila de outbox acumulada en memoria durante un drain, materializada a `@Model` al persistir.
/// Struct simple (no `@Model`) para separar la fase de traducción de la de inserción.
///
/// `clientMutationID` y `createdAt` se ACUÑAN al armar la fila (no en `SyncOutbox.init`) para que el
/// `@Model` persistido Y su entry en el espejo App Group compartan EXACTAMENTE los mismos valores
/// (idempotencia end-to-end + re-hidratación byte-idéntica, §d.5). La regeneración por drain no duplica:
/// el dedup por `(syncID,hlc,op)` (pre-sembrado con las filas existentes) evita re-crear una fila viva,
/// así que el `clientMutationID` original sobrevive a un kill-replay.
private struct PendingOutboxRow {
    let syncID: UUID
    let entityType: String
    let op: SyncOutboxOp
    let hlc: String
    let clientMutationID: UUID
    let fieldsJSON: String
    let fieldHlcsJSON: String?
    let author: String
    let tombstoneReason: String?
    let createdAt: Date

    @MainActor
    func makeModel() -> SyncOutbox {
        SyncOutbox(
            syncID: syncID,
            entityType: entityType,
            op: op,
            hlc: hlc,
            clientMutationID: clientMutationID,
            fieldsJSON: fieldsJSON,
            fieldHlcsJSON: fieldHlcsJSON,
            author: author,
            tombstoneReason: tombstoneReason,
            createdAt: createdAt
        )
    }

    /// La entry del espejo App Group. `author` = el CONSTANTE del motor de recovery (`CloudSyncOutbox`),
    /// NO el `author` de la transacción de origen (diagnóstico; la re-hidratación re-inserta bajo el
    /// autor de echo-suppression). `userID` sella la entry para el owner-scoping M1.
    func mirrorEntry(userID: String) -> OutboxMirrorEntry {
        OutboxMirrorEntry(
            userID: userID,
            syncID: syncID,
            entityType: entityType,
            op: op.rawValue,
            hlc: hlc,
            clientMutationID: clientMutationID,
            fieldsJSON: fieldsJSON,
            fieldHlcsJSON: fieldHlcsJSON,
            tombstoneReason: tombstoneReason,
            author: SyncOutboxMirror.author,
            createdAt: createdAt
        )
    }
}
