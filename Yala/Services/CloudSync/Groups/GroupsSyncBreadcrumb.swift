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
}
