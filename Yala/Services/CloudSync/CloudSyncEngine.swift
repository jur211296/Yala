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
    /// incompatibilidad de versión) → reconcile: en I3 se re-escanea el History completo (dedup lo
    /// hace seguro); el reconcile real (§d.6) llega en I8.
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

    /// El token del cursor expiró/no decodificó → reconcile (re-escaneo completo en I3).
    static func historyTokenExpired() {
        logger.notice("CloudSync historyTokenExpired — reconcile (full rescan)")
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
    /// su `latest` previo y el apply continúa. Par del canario TelemetryDeck
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

    /// El entityHash local ≠ remoto para `entity` (o `"root"`). Par del canario TelemetryDeck
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

    /// El runtime no arranca cadencia (sin sesión / gate de claim no proceed-like). `reason` sin PII.
    static func runtimeIdle(reason: String) {
        logger.notice("CloudSyncRuntime idle reason=\(reason, privacy: .public)")
    }

    /// El runtime DETUVO la cadencia (401 sesión, 403 cuenta, attest terminal, transporte). `reason` sin PII.
    static func runtimeStopped(reason: String) {
        logger.notice("CloudSyncRuntime stopped reason=\(reason, privacy: .public)")
    }

    /// Teardown de sesión invitada (M1): espejo purgado + identidad limpiada + cadencia detenida.
    static func runtimeTeardown() {
        logger.notice("CloudSyncRuntime teardownGuestSession")
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
    /// De estos 16, SOLO 6 llevan `syncID` y se TRADUCEN a outbox en I3 (ver `SyncEntityType`); los
    /// otros 10 pasan el filtro anti-fuga pero aún no tienen identidad de sync → se ignoran en la
    /// traducción (incrementos posteriores los añaden). Anclado contra `personalSchema` por
    /// `CloudSyncSchemaParityTests`.
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
    ///   • `deleteCategory`/`deleteSubcategory`/`deleteAccount`/`deleteBudget` (los hijos son
    ///     Subcategory/nullify, no deletes de syncables; el propio Category borrado es el delete de nivel
    ///     superior pedido por el usuario, no una cascada).
    ///   • cascada de SCHEMA `CashFlowPlan → CashFlowLine → CashFlowOverride` (ninguna es syncable).
    ///   • `SubcategoryTransferViewModel.deleteTransactions` (borra TX sin borrar un padre en el mismo
    ///     save → bulk del usuario = `user`).
    ///   • `CategoryDeduplicationService` (I9 → `dedup`) / `DataWipeService` (I12 → `wipe`): sin señal de
    ///     call-site hoy → caen en `user`/`cascade`. Comentario-guardia: I9/I12 marcarán un author
    ///     dedicado y esta clasificación se afinará entonces (el reason es metadata de auditoría — la
    ///     clasificación conservadora NO compromete correctness: el backend mantiene `deleted=true` igual).
    static let cascadeParentEntityNames: Set<String> = [
        "ScheduledPayment",
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
            let token = decodeToken(cursor.historyTokenData)

            // 2) Barrido defensivo: asigna syncID a las filas vivas de los 6 tipos que aún no lo tengan
            //    (SIN autor especial → la próxima vuelta captura ese cambio), y construye los índices
            //    persistentID→modelo que usa la traducción. Save con autor por DEFECTO (no es outbox).
            let lookups = try sweepAndBuildLookups(context)

            // 3) History posterior al token (o completo si nil / token expirado).
            let txns = try fetchHistory(after: token, context: context)

            // 4) Pre-siembra del dedup con las filas de outbox YA existentes (kill-replay: absorbe las
            //    filas persistidas en un drain previo cuyo token no llegó a avanzar).
            var seen = try existingOutboxKeys(context)

            // 5) Traducción, transacción a transacción y en orden. `advancedToken` = high-water de la
            //    history EXTERNA consumida (nil = no se consumió nada externo esta vuelta). Las
            //    transacciones que escribió el propio motor (`author == outboxSaveAuthor`: outbox +
            //    cursor) se DESCARTAN y NO avanzan el high-water → convergencia: un drain ocioso re-lee
            //    solo sus propios writes (0 filas) y no vuelve a mover/escribir el cursor. Criterio de
            //    drift: si `clock.send` lanza, NO se consume esa transacción (el high-water se queda
            //    antes de ella) → se reintenta al próximo drain.
            var rows: [PendingOutboxRow] = []
            var advancedToken: DefaultHistoryToken?
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
                    break
                }
                rows.append(contentsOf: txRows)
                // Transacción externa consumida (produzca filas o no — p.ej. anti-fuga, syncID-only,
                // o un gap): avanza el high-water para no re-procesarla (evita recontar gaps).
                advancedToken = tx.token
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
            //    idempotente por el dedup), y SOLO si se consumió history externa (advancedToken != nil).
            //    El save del cursor lleva `outboxSaveAuthor` → no se re-lee. Suprimible en tests (kill).
            //    D-3: el reloj se PERSISTE en el MISMO save que avanza el token (crash → ambos revierten
            //    juntos → replay determinista). Bundling seguro: todo `clock.send` de esta vuelta ocurrió
            //    al traducir una tx externa que también fijó `advancedToken` (advance ⟹ token consumido).
            if !_testSuppressTokenAdvance, let advancedToken {
                try saveWithAuthor(context, Self.outboxSaveAuthor) {
                    cursor.historyTokenData = try encodeToken(advancedToken)
                    cursor.clockLatestHLC = clock.latest?.description
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

    /// Índices persistentID→modelo de los 6 tipos sincronizables (construidos en el barrido).
    private struct Lookups {
        var transactionItem: [PersistentIdentifier: TransactionItem] = [:]
        var inboxDraft: [PersistentIdentifier: InboxDraft] = [:]
        var category: [PersistentIdentifier: Category] = [:]
        var favoritePayment: [PersistentIdentifier: FavoritePayment] = [:]
        var merchantMemory: [PersistentIdentifier: MerchantMemory] = [:]
        var exchangeRate: [PersistentIdentifier: ExchangeRate] = [:]
    }

    /// Despacha el cambio al handler concreto por entity name. Los tipos personales sin `syncID` (los
    /// 10 restantes) caen al `default` y se ignoran (aún sin identidad de sync — incrementos futuros).
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
                                syncIDKeyPath: \.syncID, emission: EntityEmissionMap.transactionItem,
                                lookup: lookups.transactionItem, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.inboxDraft:
            try translateChange(change, type: InboxDraft.self, entityType: entityName,
                                syncIDKeyPath: \.syncID, emission: EntityEmissionMap.inboxDraft,
                                lookup: lookups.inboxDraft, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.category:
            try translateChange(change, type: Category.self, entityType: entityName,
                                syncIDKeyPath: \.syncID, emission: EntityEmissionMap.category,
                                lookup: lookups.category, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.favoritePayment:
            try translateChange(change, type: FavoritePayment.self, entityType: entityName,
                                syncIDKeyPath: \.syncID, emission: EntityEmissionMap.favoritePayment,
                                lookup: lookups.favoritePayment, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.merchantMemory:
            try translateChange(change, type: MerchantMemory.self, entityType: entityName,
                                syncIDKeyPath: \.syncID, emission: EntityEmissionMap.merchantMemory,
                                lookup: lookups.merchantMemory, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        case SyncEntityType.exchangeRate:
            try translateChange(change, type: ExchangeRate.self, entityType: entityName,
                                syncIDKeyPath: \.syncID, emission: EntityEmissionMap.exchangeRate,
                                lookup: lookups.exchangeRate, tx: tx,
                                tombstoneReason: tombstoneReason, rows: &rows, seen: &seen)
        default:
            // Personal-pero-aún-sin-identidad (los 10 restantes de los 16). No se traduce en I3.
            return
        }
    }

    /// Traduce UN cambio de un tipo concreto `T` a (a lo sumo) una fila de outbox. El payload de dominio
    /// (`fields` + `field_hlcs`) lo produce `DeltaEmitter` (proyección `EntityEmissionMap` + codec c1).
    private func translateChange<T: PersistentModel & SyncIdentifiable>(
        _ change: HistoryChange,
        type: T.Type,
        entityType: String,
        syncIDKeyPath: KeyPath<T, UUID?>,
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
            guard let syncID = model[keyPath: syncIDKeyPath] else { return }  // sin identidad → skip
            // INSERT = proyección COMPLETA de dominio (todas las columnas). Todas las unidades reciben
            // el HLC de la transacción. Los grupos de coherencia viajan enteros por construcción.
            try appendUpsert(model: model, emission: emission, syncID: syncID, entityType: entityType,
                             changedColumns: emission.columns, tx: tx, rows: &rows, seen: &seen)

        case .update(let update):
            guard let typed = update as? DefaultHistoryUpdate<T> else { return }
            guard let model = lookup[typed.changedPersistentIdentifier] else { return }
            guard let syncID = model[keyPath: syncIDKeyPath] else { return }
            // PATCH parcial: mapea los keypaths cambiados a columnas Postgres. `syncID` NO está en el
            // mapa (es la PK) → si SOLO cambió syncID (p.ej. el barrido lo acuñó) el set queda vacío →
            // SKIP. Los keypaths sin mapeo (relaciones no-columna, internos) se ignoran.
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
            guard let syncID = typed.tombstone[syncIDKeyPath] as? UUID else {
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
        // Canario TelemetryDeck (no-op en tests: `track` retorna si el servicio no está configurado).
        TelemetryService.cloudSyncIdentityGapObserved(entityType: entityType)
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
            TelemetryService.cloudSyncClockReceiveRejected(reason: "\(error)")
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

    private func decodeToken(_ data: Data?) -> DefaultHistoryToken? {
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(DefaultHistoryToken.self, from: data)
        } catch {
            // Token no decodificable → path expirado (reconcile completo en I3 = escaneo total).
            CloudSyncBreadcrumb.historyTokenExpired()
            return nil
        }
    }

    private func encodeToken(_ token: DefaultHistoryToken) throws -> Data {
        try JSONEncoder().encode(token)
    }

    private func fetchHistory(
        after token: DefaultHistoryToken?, context: ModelContext
    ) throws -> [DefaultHistoryTransaction] {
        guard let token else {
            return try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        }
        do {
            return try context.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(predicate: #Predicate { $0.token > token })
            )
        } catch {
            // Fetch por token falló (token incompatible tras migración) → reconcile: escaneo completo.
            CloudSyncBreadcrumb.historyTokenExpired()
            return try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
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
            TelemetryService.cloudSyncOutboxMirrorDivergence(delta: divergence)
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
        TelemetryService.cloudSyncOutboxMirrorRehydrated(count: missing.count)
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
