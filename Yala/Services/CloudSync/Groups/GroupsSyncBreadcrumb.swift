//
//  GroupsSyncBreadcrumb.swift
//  Yala
//
//  Rastros de diagnóstico del canal de sync de GRUPOS → backend (incremento G4). Molde EXACTO de
//  `CloudSyncBreadcrumb` (CloudSyncEngine.swift): `enum` `@MainActor` con `Logger`, FUERA de `#if DEBUG`
//  a PROPÓSITO (el comportamiento del pipeline solo se valida del todo en device/TestFlight) y SIN PII —
//  solo counts / slugs sanitizados, JAMÁS group_ids, nombres o montos.
//
//  NOTA de subsystem (A7): usa `"com.yala"` fiel al molde `CloudSyncBreadcrumb`, consciente de que el
//  `logger` de instancia de `GroupsSyncClient` usa `"com.yala.app"` — son canales distintos (breadcrumbs
//  de diagnóstico vs. logs de error internos).
//

import Foundation
import OSLog

@MainActor
enum GroupsSyncBreadcrumb {
    private static let logger = Logger(subsystem: "com.yala", category: "GroupsSync")

    /// El guard de validación por timestamp detectó que el `historyTokenData` del cursor NO surfacea
    /// `missed` transacciones externas del mount actual (token no-comparable cross-mount). El drain
    /// re-procesa la unión y re-ancla el token. `> 0` en prod = canario de fila que jamás llega al outbox.
    static func groupsHistoryTokenIncomparable(missed: Int) {
        logger.notice("GroupsSync historyTokenIncomparable missed=\(missed, privacy: .public) — token no-comparable cross-mount; re-procesando unión + re-anclando")
    }

    /// El guard re-ancló el `historyTokenData` a la última tx del mount actual. Par de recuperación del
    /// canario `groupsHistoryTokenIncomparable`.
    static func groupsHistoryTokenRecovered() {
        logger.notice("GroupsSync historyTokenRecovered — token re-anclado al mount actual")
    }

    /// Una fila del outbox de Grupos entró a DEAD-LETTER (rechazo definitivo). `reason` = slug sanitizado
    /// (p.ej. `upstream_400:yala_not_authorized`, `malformed_delta`, `coherence_group_partial:gmoney`).
    static func groupsPushDeadLettered(reason: String) {
        logger.notice("GroupsSync pushDeadLettered reason=\(reason, privacy: .public)")
    }

    /// `count` filas de meta de grupo se PURGARON del outbox por noop `group_not_found` (el grupo no existe
    /// server-side — nace solo vía `create_group`; anti retry-storm de meta legacy). Deja de ser silenciosa.
    static func groupsMetaPurgedGroupNotFound(count: Int) {
        logger.notice("GroupsSync metaPurgedGroupNotFound count=\(count, privacy: .public)")
    }

    /// El pull de una vuelta alcanzó el CAP de iteraciones sin agotar (server que no converge / no devuelve
    /// página vacía). `pages` = páginas no-vacías aplicadas antes del corte. `> 0` en prod = revisar el fan-out.
    static func groupsPullExhaustedCap(pages: Int) {
        logger.notice("GroupsSync pullExhaustedCap pages=\(pages, privacy: .public) — server no convergió; cortando como transitorio")
    }

    /// Al arrancar el loop había `n` filas ya en dead-letter (push fallando permanente). Canario A7.
    static func groupsDeadLetteredCount(_ n: Int) {
        logger.notice("GroupsSync deadLetteredCount n=\(n, privacy: .public) — filas en dead-letter al arrancar el loop")
    }

    /// El apply DESCARTÓ un delta bajado (sync_id no parseable en una entidad de contenido, member_key nil, o
    /// entity_type desconocido). El cursor avanza igual → sin este rastro el delta se perdería INVISIBLEMENTE.
    /// `entity` = slug del `entity_type` (tabla Postgres, sin PII). `> 0` en prod = revisar wire/schema.
    static func groupsApplySkippedDelta(entity: String) {
        logger.notice("GroupsSync applySkippedDelta entity=\(entity, privacy: .public) — delta descartado; cursor avanza sin aplicar")
    }

    // MARK: - Espejo del outbox (endurecimiento B2)

    /// El rehydrate del boot re-insertó `count` filas del espejo App Group que el `GroupSyncOutbox` había
    /// perdido (lightweight migration que recreó la tabla / vaciado parcial). `> 0` esporádico = la red
    /// funcionó; sostenido = investigar la migración. Sin PII (solo el count).
    static func groupsMirrorRehydrated(count: Int) {
        logger.notice("GroupsSync mirrorRehydrated count=\(count, privacy: .public) — filas re-insertadas desde el espejo App Group")
    }

    // MARK: - Merkle (endurecimiento B1)

    /// El fetch de `/groups/merkle` falló (transporte / respuesta no-HTTP / decode / HTTP 5xx). `reason` =
    /// slug sanitizado (`transport`/`non-http`/`decode-200`/`http-<code>`), sin PII. El verificador lo trata
    /// como `.skipped` (jamás canario).
    static func groupsMerkleFetchFailed(reason: String) {
        logger.notice("GroupsSync merkleFetchFailed reason=\(reason, privacy: .public)")
    }

    /// La verificación Merkle de un grupo se SALTÓ por una precondición no satisfecha (outbox vivo, dead-
    /// letters, sin pull completado, canon-mismatch, sin sesión, 401/403). `reason` = slug (puede llevar un
    /// count, `outbox-pending:N`), JAMÁS el group_id. NUNCA canario.
    static func groupsMerkleSkipped(reason: String) {
        logger.notice("GroupsSync merkleSkipped reason=\(reason, privacy: .public)")
    }

    /// [R4] El root remoto de un grupo es el de un corpus VACÍO (todas las entities count 0) mientras el
    /// local NO lo está → firma de REMOCIÓN de membership vía RLS (el server responde tablas vacías al
    /// no-member). NO es divergencia: skip SIN canario ni remediación (la limpieza llega por memberships del
    /// pull). Sin PII.
    static func groupsMerkleEmptyRemote() {
        logger.notice("GroupsSync merkleEmptyRemote — root remoto vacío + local no-vacío; remoción de membership (no divergencia)")
    }

    /// [R6] Una fila `group_members` local NO pudo keyear su leaf Merkle (member_key nil/vacío — CloudKit
    /// preexistente no adoptado). Se SALTA del árbol (jamás crash). `> 0` en born-backend = revisar adopción.
    static func groupsMerkleMemberKeyMissing() {
        logger.notice("GroupsSync merkleMemberKeyMissing — member sin member_key; leaf saltado")
    }

    /// La verificación Merkle de la corrida CONVERGIÓ (`groups` grupos verificados sin divergencia). Sin PII.
    static func groupsMerkleConverged(groups: Int) {
        logger.notice("GroupsSync merkleConverged groups=\(groups, privacy: .public)")
    }

    /// La verificación Merkle detectó DIVERGENCIA en `groups` grupos de la corrida (par del canario
    /// `groupMerkleDivergence`). `groups` = count, JAMÁS los group_ids. Sin PII.
    static func groupsMerkleDivergence(groups: Int) {
        logger.notice("GroupsSync merkleDivergence groups=\(groups, privacy: .public) — infidelidad de sync; remediando una vez por sesión")
    }

    /// La remediación Merkle (reset de cursor + re-pull) corrió sobre `groups` grupos divergentes, UNA vez
    /// por sesión. Par de recuperación del canario. Sin PII.
    static func groupsMerkleRemediated(groups: Int) {
        logger.notice("GroupsSync merkleRemediated groups=\(groups, privacy: .public)")
    }

    // MARK: - Re-join (hueco de cursor, H-2026-07-18-3)

    /// El apply detectó la transición pendingApproval→active del PROPIO usuario en `groups` grupos y reseteó
    /// su cursor por-grupo a 0 → el próximo pull re-visita el contenido que RLS ocultaba mientras estaba
    /// pendiente (el cursor había avanzado sin bajar ese contenido). `> 0` esporádico = re-join sano;
    /// sostenido = revisar aprobaciones. Sin PII (solo el count — JAMÁS el group_id).
    static func groupsRejoinCursorReset(groups: Int) {
        logger.notice("GroupsSync rejoinCursorReset groups=\(groups, privacy: .public) — re-join pendingApproval→active; cursor por-grupo reseteado para re-pull del hueco")
    }

    // MARK: - Partición POR-GRUPO (G5-A)

    /// [C2] Un enqueue a CKSyncEngine se SALTÓ porque el grupo es del canal BACKEND (`isBackendGroup`) — sus
    /// records NUNCA deben ir a CloudKit (sync por el canal backend). `site` = slug del choke point
    /// (`enqueueSave`/`enqueueDeletion`/`createZone`/`createShare`/`zoneRecovery`/`recordRecovery`). Sin PII.
    static func groupsCkEnqueueSkippedBackendGroup(site: String) {
        logger.notice("GroupsSync ckEnqueueSkippedBackendGroup site=\(site, privacy: .public)")
    }

    /// [C2-bis] El drain del canal backend SALTÓ un change porque su `group_id` NO pertenece a un grupo
    /// backend (grupo CloudKit vivo bajo flag ON, o tombstone de un grupo ya borrado localmente) — evita
    /// dead-letters permanentes (`group_id` inexistente server-side) y el doble-sync CKSyncEngine∥backend.
    /// `entity` = slug del `entity_type` (tabla/clase, sin PII). El group_id JAMÁS se loguea.
    static func groupsDrainSkippedNonBackendGroup(entity: String) {
        logger.notice("GroupsSync drainSkippedNonBackendGroup entity=\(entity, privacy: .public)")
    }

    /// [G6-3 C2] El uploader encoló el MARCADOR de migración (`GroupMeta` con `movedToBackendAt` +
    /// `backendReInviteToken`) a CKSyncEngine — la ÚNICA escritura CloudKit legítima sobre un grupo
    /// `isBackendGroup=true`. Sin PII (jamás el group_id ni el token).
    static func groupsCkMigrationMarkerEnqueued() {
        logger.notice("GroupsSync ckMigrationMarkerEnqueued — marcador de migración encolado (única escritura CK legítima post-freeze)")
    }

    /// [G6-3 C2] El GUARD SIMÉTRICO de PULL saltó aplicar un record CloudKit fetcheado cuyo grupo local es
    /// `isBackendGroup=true` (ya migrado) — la zona CloudKit queda como red de SOLO-LECTURA: un miembro
    /// rezagado o el eco del propio marcador NO pisa las ediciones backend post-migración. `site` =
    /// `applyRemote`/`conflict`/`bridge`. Sin PII.
    ///
    /// [C-4 PIEZA 2] `reason` = slug de `GroupPullRescueGate.skipReason` en el sitio de las
    /// MODIFICACIONES; `"backendZone"` (el default) en los sitios donde el descarte es incondicional por
    /// invariante — deletions, conflictos, zona inexistente y borrado de zona. Antes del rescate TODOS
    /// los descartes eran indistinguibles entre sí: el eco stale legítimo y el record nunca visto (=
    /// dinero perdido) emitían la MISMA línea. Éste es el campo que los separa en Console.app.
    static func groupsCkPullSkippedBackendGroup(site: String, reason: String = "backendZone") {
        logger.notice("GroupsSync ckPullSkippedBackendGroup site=\(site, privacy: .public) reason=\(reason, privacy: .public)")
    }

    /// [C-4 PIEZA 2] El RESCATE adoptó un record CloudKit NUNCA VISTO de un grupo ya migrado: la fila se
    /// INSERTA (jamás se actualiza) y el drain del canal backend la empujará al servidor. Es la única
    /// forma de que ese dato sobreviva — el token de CKSyncEngine ya avanzó y CloudKit no lo re-entrega.
    /// `entity` = nombre de clase `@Model` (sin PII: jamás el group_id, el id de la fila ni el importe).
    ///
    /// Se espera CERO en estado estable. Un goteo sostenido significa que hay miembros escribiendo a
    /// CloudKit después del flip — señal accionable para el rollout, no un fallo.
    static func groupsCkPullRescued(entity: String) {
        logger.notice("GroupsSync ckPullRescued entity=\(entity, privacy: .public) — record nunca visto de zona migrada, ADOPTADO (insert-only) y encolado al backend")
    }

    /// [G6-3 C3] El `GroupMigrationUploader` completó la migración de `count` grupos vivos al backend.
    static func groupsMigrationCompleted(count: Int) {
        logger.notice("GroupsSync migrationCompleted count=\(count, privacy: .public)")
    }

    /// [G6-3 C3] Un paso del `GroupMigrationUploader` falló (reintenta en el próximo boot). `step` = slug del
    /// paso (`migrate`/`invite`/`freeze`/`seed`/`push`/`marker`). Sin PII.
    static func groupsMigrationFailed(step: String) {
        logger.notice("GroupsSync migrationFailed step=\(step, privacy: .public)")
    }

    /// [C-4] La pasada de migración se DIFIRIÓ porque el fetch de GRUPOS no se asentó dentro del tope.
    /// NO es un fallo: nada se perdió y los 7 pasos son idempotentes. `waited` = segundos esperados,
    /// `reason` = slug de `GroupFetchQuiescenceGate.deferReason` (o `cancelled`). Sin PII.
    static func groupsMigrationFetchGateDeferred(waited: Int, reason: String) {
        logger.notice("GroupsSync migrationFetchGateDeferred waited=\(waited, privacy: .public)s reason=\(reason, privacy: .public) — fetch de grupos no asentado; reintenta el próximo boot")
    }

    /// [C-4] Un batch de records fetcheados NO llegó a persistir (save fallido / handler sin contexto)
    /// con el token del engine YA avanzado: CloudKit no lo re-entrega. Invalida el testigo del ciclo ⇒
    /// la migración a backend NO arranca en esta sesión. `reason` = `save-failed` | `no-context`.
    /// Sin PII. Fuera de `#if DEBUG` como todo `SplitSync*`/`GroupsSync*` (excepción consciente: el
    /// comportamiento solo se valida del todo en CloudKit Production vía Console.app).
    static func groupsCkFetchApplyFailed(reason: String) {
        logger.notice("GroupsSync ckFetchApplyFailed reason=\(reason, privacy: .public) — token avanzado sin apply; migración diferida")
    }

    /// [G6-3 C2] El boot-reconciler re-encoló el marcador de `count` grupos `movedToBackendAt != nil &&
    /// !markerEnqueuedFlag` (kill entre el save del marcador y el flag). Vacío en estado estable.
    static func groupsMigrationMarkerReconciled(count: Int) {
        logger.notice("GroupsSync migrationMarkerReconciled count=\(count, privacy: .public)")
    }

    // MARK: - Ciclo de vida del loop (H-2026-07-18-4)

    /// El loop de cadencia del canal TERMINÓ (un `break loop` de `runLoop`). `reason` = slug sanitizado
    /// (`session-check-failed` / `session-expired` / `account-unavailable` / `cancelled`). Par del
    /// `groupsLoopRestarted`: un `session-expired` sin su `loopRestarted` posterior = canal muerto que
    /// nadie re-arrancó (el bug H-2026-07-18-4). Sin PII.
    static func groupsLoopStopped(reason: String) {
        logger.notice("GroupsSync loopStopped reason=\(reason, privacy: .public)")
    }

    /// El loop de cadencia se RE-ARRANCÓ efectivamente (se creó un nuevo `loopTask`). `trigger` = slug
    /// (`foreground` / `post-sign-in`). SOLO se emite cuando el re-arranque crea el loop — jamás en los
    /// no-op (flag OFF, loop ya vivo, piggyback, stopUntilRelaunch). Sin PII.
    static func groupsLoopRestarted(trigger: String) {
        logger.notice("GroupsSync loopRestarted trigger=\(trigger, privacy: .public)")
    }

    // MARK: - Cambio de identidad de iCloud (C-3)

    /// [C-3] Un cambio de identidad de iCloud (sign-out o switch de Apple ID) CONSERVÓ zonas del canal
    /// backend porque había SESIÓN de nube viva (D4). Counts POR ZONA (un duplicado de fila no infla el
    /// rastro) y SEPARADOS a propósito: `owned` = zonas con alguna fila `isBackendGroup` (dueño backend),
    /// `frozen` = copias CONGELADAS de miembro. En un device de miembro backend NATIVO
    /// `credentialsRevoked` es 0 SIEMPRE (el token solo lo estampa el paso 6 del uploader del OWNER), así
    /// que un canario sobre el total se dispararía siempre y nadie lo miraría. El accionable es
    /// `frozen > 0 && credentialsRevoked == 0`: el token viaja con `movedToBackendAt`, así que una copia
    /// congelada sin credencial que revocar delata un GroupMeta incompleto. Sin PII — jamás group_ids ni
    /// el token.
    static func groupsIdentityChangeRetained(
        owned: Int, frozen: Int, credentialsRevoked: Int, markersReQueued: Int, pendingJoinsRevoked: Int
    ) {
        logger.notice("GroupsSync identityChangeRetained owned=\(owned, privacy: .public) frozen=\(frozen, privacy: .public) credentialsRevoked=\(credentialsRevoked, privacy: .public) markersReQueued=\(markersReQueued, privacy: .public) pendingJoinsRevoked=\(pendingJoinsRevoked, privacy: .public)")
    }

    /// [C-3] El barrido de identidad no pudo borrar los hijos de `zones` zonas del canal CloudKit (fetch
    /// fallido). Borrado PARCIAL: sus `SplitGroup` sí se borraron (van primero, paridad `deleteGroupCache`)
    /// ⇒ el usuario anterior no queda visible, pero quedan huérfanos por zona. `> 0` en prod = investigar.
    static func groupsIdentityChangePurgeFailed(zones: Int) {
        logger.notice("GroupsSync identityChangePurgeFailed zones=\(zones, privacy: .public)")
    }
}
