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
}
