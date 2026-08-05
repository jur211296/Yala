//
//  MetricsService.swift
//  Yala
//
//  Telemetría propia mínima (2026-07-17, sustituye TelemetryDeck). Tres cosas y nada más:
//   · ping diario (usuarios activos/día — guard local once-per-day, día UTC)
//   · registro (altas/día: onboarding local completado | cuenta nube creada)
//   · canarios (diagnósticos operativos del gate de Modo Nube/Grupos/routing — la
//     condición "canarios en cero" del encendido se lee del dashboard de Analytics Engine)
//
//  Pipeline: evento → MetricsSpool (UserDefaults, kill-tolerante) → MetricsClient →
//  POST /metrics del gateway → Workers Analytics Engine. Sin SDK de terceros.
//  Privacy-first: jamás PII — solo slugs, counts y un install-hash anónimo
//  (SHA-256 truncado del bucketSeed local; el seed crudo nunca sale del device).
//
//  Sin `start()` (tests / release sin bootstrap) TODO es no-op — paridad con el
//  `isConfigured` del viejo TelemetryService. Bajo `-uitest` no se arranca y
//  `-uitest-reset` limpia `metrics.*` (keys pegajosas de `.standard`, lección #34).
//

import CryptoKit
import Foundation

// MARK: - Catálogo de canarios

/// Nombres ESTABLES de los canarios (viajan como `n` del evento `canary` — la query del
/// gate agrupa por este slug; renombrar un case rompe la serie del dashboard).
/// Semántica de cada uno: doc-comments históricos en los call-sites y qa/cloud/README.
enum MetricsCanary: String {
    // CloudKit (store personal espejado + container de grupos)
    case cloudkitExportFailed
    case cloudkitExportSucceeded
    case cloudkitStalledDetected
    case cloudkitDuplicateDetected
    case cloudkitTransferOrphanRepaired
    case cloudkitTransferCollisionDetected
    case cloudkitBudgetCSVMirrorRebuilt
    case budgetFiltersAppearEmpty
    case appEntityShortcutIDsRegenerated
    case tagCatalogRebuilt
    case bridgeVirtualLentTxFailed
    /// El barrido del arranque encontró transacciones puenteadas cuyo gasto/liquidación de grupo ya no
    /// existe y las reparó. Un pico tras un release = la cola de fantasmas que dejó el borrado remoto sin
    /// des-puentear (bug device 2026-08-02), esperada y de una sola vez por usuario. **Sostenido en >0
    /// arranque tras arranque = hay OTRO camino abriendo huérfanas** y el barrido lo está tapando.
    /// `detail` separa liberadas (cuenta real) de borradas (virtuales de sistema).
    case bridgedTxOrphansRepaired
    /// El barrido encontró candidatas —punteros de grupo que no resuelven— pero NO las tocó porque el canal
    /// de su zona no había agotado su entrega (`GroupChannelFreshnessGate`). `detail` lleva el motivo y el
    /// recuento por veredicto, sin PII. **Es la superficie de observación de un gate CLAVADO**: sin él, un
    /// canal apagado durante semanas, un cursor que no lista la zona o un engine de CloudKit que nunca
    /// cierra su ciclo se leerían igual que «no había huérfanas» (`bridgedTxOrphansRepaired` en cero).
    /// Un pico aislado es normal (el barrido corre antes de que el pull termine); SOSTENIDO arranque tras
    /// arranque con el mismo veredicto = el canal de esa cohorte no está entregando.
    case bridgedTxOrphanSweepDeferred
    case iCloudRestoreOutcome
    case cloudkitGroupSyncGateHardCap
    case cloudkitGroupSyncPromotedToAuto
    case cloudkitGroupSyncNoImportPromote
    case cloudkitGroupZoneRecovered
    case cloudkitGroupRecordsRecovered
    case cloudkitGroupRecordSaveRejected
    case cloudkitGroupEnqueueDroppedNoEngine
    case groupsIdentityBootMismatch
    /// El gate de boot-saves del store personal (`awaitPersonalImportForBootSave`) difirió ≥3 veces
    /// CONSECUTIVAS sin que ningún save resolviera entremedio — señal SUAVE: los ~8 boot-tasks
    /// concurrentes comparten el contador (resets intercalados), así que el umbral puede alcanzarse
    /// dentro de UN solo boot. Firma de H-2026-07-18-8 (fresh-start wipe: el store ya está entero en
    /// el server → NSPersistentCloudKit no importa nada → `hasCompletedFirstImport` jamás vuelve a
    /// true → todos los boot-saves diferidos para siempre). `detail` desambigua el sub-modo.
    case cloudBootSaveDeferredRepeatedly

    // Modo Nube (motor personal + cuenta + auth)
    case cloudSyncIdentityGapObserved
    case cloudSyncCoherenceGroupPartial
    case cloudSignInProviderMismatch
    case cloudSyncBlockedByAttestUnavailable
    /// El keyId guardado ya no designaba una key usable y se descartó para re-registrar. >0 sostenido =
    /// algo invalida keys en masa; un pico tras un release = usuarios reinstalando (esperado, se auto-cura).
    case attestKeyDiscardedAfterAssertFailure
    case cloudSyncBlockedByExpiredSession
    case cloudSyncOutboxMirrorRehydrated
    case cloudSyncOutboxMirrorDivergence
    case cloudSyncMutationRejected
    case cloudSyncClockReceiveRejected
    case cloudSyncMerkleDivergence
    case cloudCutoverLeaderOrphanReconciled
    case cloudAdoptOrphanReconciled
    case cloudConsentAccepted
    case cloudAccountUnavailable
    case cloudAccountReverting
    case cloudSecondaryMountMismatchBlocked
    // C-1 — canal iCloud del cutover
    case cloudCutoverICloudBlocked
    case cloudCutoverMarkerWaived
    case cloudCutoverMarkerStalled
    case cloudCutoverAborted
    case cloudStorageModePairViolation
    case accountDeletionCompleted
    case accountDeletionFailed
    case siwaExchangeFailed
    case siwaRevokeFailed
    case googleRevokeFailed
    case relaunchNetExhausted

    // Grupos→backend
    case groupMerkleDivergence
    case groupPushRejected
    case groupPushTokenRegisterFailed
    case groupJoinIntentPersisted
    case groupJoinIntentReconciled
    case groupJoinIntentDeferred
    case groupJoinIntentExpired
    case groupJoinFailed
    case groupLegacyRebindFailed
    /// El barrido del arranque retiró del outbox/espejo tombstones de `split_groups` que un build anterior
    /// al guard del 2026-08-02 dejó ENCOLADOS. Empujar uno borra el grupo para TODOS sus miembros
    /// (server-side la identidad de `split_groups` es la ZONA, no la fila). Un pico tras el release = la
    /// cola real de aquel bug, esperada y de UNA sola vez por device. **Sostenido en >0 = el camino de
    /// emisión volvió a abrirse** y el barrido lo está tapando. `detail` separa filas de archivos del espejo.
    case groupsOutboxGroupTombstonePurged
    /// El pull dejó de listar una zona backend que el device tiene localmente ⇒ al usuario lo sacaron del
    /// grupo (o le rechazaron la solicitud) y se dispara la limpieza local. Es un evento NORMAL y esperado:
    /// lo que se vigila es su ausencia total conviviendo con reportes de «grupo fantasma», y su exceso en un
    /// mismo device (el gateway dejando de listar grupos vivos). Único rastro en la flota de un camino que
    /// BORRA datos locales — `value` = zonas de esa página. Sin PII.
    case groupsMembershipLost

    // Batch "salir de todos mis grupos" (D10)
    case groupBatchLeaveStarted
    case groupBatchLeaveDeferred      // paso diferido por import no-quiescente (resume lo retoma)
    case groupBatchLeaveExpired       // entry .pending vencida (TTL) sin procesar
    case groupBatchLeaveNeedsDecision // grupo que cae a "necesitan tu decisión"
    case groupBatchLeaveFailed        // transfer/leave falló permanente
    case groupBatchLeaveStopped       // el usuario pulsó «Detener» (value = grupos sin procesar)

    // Routing (F9)
    case routingIntentSuperseded
    case routingIntentDeferred
    case routingReadinessBlocked
    case routingDrainHoldSustained
    case routingWelcomeChainSuperseded
    case inviteReEmittedFromStore
    case invitePendingExpired
}

// MARK: - Servicio

@MainActor
enum MetricsService {

    // MARK: Estado

    private static var isStarted = false
    private static var client: MetricsClient?
    private static var defaults: UserDefaults = .standard
    private static var trackedOnceKeys: Set<String> = []
    private static var drainTask: Task<Void, Never>?

    static let lastPingDayKey = "metrics.lastPingDay"
    static let cloudRegisteredKeyPrefix = "metrics.cloudRegistered."

    // MARK: Arranque

    /// Lo llama SOLO AppBootstrapper (cold launch). Sin start, todo el servicio es no-op
    /// (tests jamás tocan `.standard` ni la red). Bajo `-uitest` no arranca.
    static func start(
        client: MetricsClient? = nil,
        defaults: UserDefaults = .standard
    ) {
        guard !UITestHooks.isActive else { return }
        Self.client = client ?? MetricsClient()
        Self.defaults = defaults
        isStarted = true
    }

    /// Higiene de `-uitest-reset` y de tests: limpia TODAS las keys `metrics.*`
    /// (spool + guard del día + one-shots de registro cloud) — la clase exacta de
    /// keys pegajosas de `.standard` del SERIO de #34.
    static func resetLocalState(_ defaults: UserDefaults = .standard) {
        MetricsSpool.clear(defaults)
        defaults.removeObject(forKey: lastPingDayKey)
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(cloudRegisteredKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Solo para tests del servicio (aislar `.standard` y resetear el estado estático).
    static func _testReset() {
        isStarted = false
        client = nil
        defaults = .standard
        trackedOnceKeys = []
        drainTask?.cancel()
        drainTask = nil
    }

    // MARK: KPI 1 — usuarios activos/día

    /// Ping diario dedupeado client-side (día UTC — `MetricsPingLogic`). Se llama en
    /// cold launch (bootstrap) y en cada foreground (`handleBecameActive`); solo el
    /// primero del día encola. El drain corre igual en ambos (recoge canarios pendientes).
    static func dailyActivePingIfNeeded(now: Date = .now) {
        guard isStarted else { return }
        if MetricsPingLogic.shouldPing(lastPingDay: defaults.string(forKey: lastPingDayKey), now: now) {
            defaults.set(MetricsPingLogic.dayString(for: now), forKey: lastPingDayKey)
            MetricsSpool.enqueue(.ping(), defaults: defaults)
        }
        kickDrain()
    }

    // MARK: KPI 2 — registros/día

    /// Alta LOCAL: onboarding completado. `mode` = full | groupsOnly | groupInvite.
    /// Un re-onboarding tras wipe legítimo cuenta de nuevo (semántica aceptada: nuevo alta).
    static func localRegistrationCompleted(mode: String) {
        guard isStarted else { return }
        MetricsSpool.enqueue(.register(kind: "local", detail: mode), defaults: defaults)
        kickDrain()
    }

    /// Alta NUBE: el claim devolvió `created` (cuenta backend NUEVA). One-shot persistido
    /// por userID: el re-claim del MISMO líder colapsa a `created` (AccountClaimDecision)
    /// y una migración reanudada re-emitiría → doble conteo. `detail` = migration | bornCloud.
    static func cloudRegistrationCompletedIfFirst(userID: String, detail: String) {
        guard isStarted else { return }
        let key = cloudRegisteredKeyPrefix + userID
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        MetricsSpool.enqueue(.register(kind: "cloud", detail: detail), defaults: defaults)
        kickDrain()
    }

    // MARK: Canarios — núcleo

    static func canary(_ name: MetricsCanary, detail: String? = nil, value: Double = 1) {
        guard isStarted else { return }
        #if DEBUG
        print("MetricsService: [canary] \(name.rawValue) detail=\(detail ?? "-") value=\(value)")
        #endif
        MetricsSpool.enqueue(.canary(name: name.rawValue, detail: detail, value: value), defaults: defaults)
        kickDrain()
    }

    /// Canario dedupeado por sesión de proceso (clave compuesta) — paridad `trackOnce`.
    static func canaryOnce(_ name: MetricsCanary, key: String, detail: String? = nil, value: Double = 1) {
        let compositeKey = "\(name.rawValue):\(key)"
        guard !trackedOnceKeys.contains(compositeKey) else { return }
        trackedOnceKeys.insert(compositeKey)
        canary(name, detail: detail, value: value)
    }

    // MARK: Drain

    /// Vacía el spool en batches (cap del wire: 25). Un solo drain en vuelo; el loop
    /// re-lee el spool en cada vuelta, así que eventos encolados durante un envío
    /// salen en la siguiente. `.retry` (offline/5xx) corta — el próximo trigger
    /// (foreground/boot/evento nuevo) reintenta. `.dropped` (4xx) TAMBIÉN retira:
    /// reintentar un body que el server rechaza atascaría la cabeza para siempre.
    static func kickDrain() {
        guard isStarted, drainTask == nil, let client else { return }
        let defaults = Self.defaults
        drainTask = Task { @MainActor in
            defer { drainTask = nil }
            while true {
                let batch = Array(MetricsSpool.pending(defaults).prefix(25))
                guard !batch.isEmpty else { return }
                let outcome = await client.send(install: installHash, app: appVersion, events: batch)
                switch outcome {
                case .delivered:
                    MetricsSpool.removeFirst(batch.count, defaults: defaults)
                    MetricsBreadcrumb.drained(count: batch.count)
                case .dropped:
                    MetricsSpool.removeFirst(batch.count, defaults: defaults)
                case .retry:
                    return
                }
            }
        }
    }

    // MARK: Identidad anónima

    /// SHA-256 del bucketSeed local, truncado a 16 hex. El seed crudo (cohortes de
    /// rollout, `cloudSync.remoteConfig.bucketSeed`) JAMÁS sale del device; este hash
    /// no es reversible ni enlazable a cuenta. Sirve para `count(DISTINCT)` del DAU
    /// y como sampling key de Analytics Engine.
    static var installHash: String {
        let seed = CloudRemoteConfigStore.bucketSeed(defaults)
        let digest = SHA256.hash(data: Data(seed.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private static var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// MARK: - Wrappers typed preservados (firmas idénticas al viejo TelemetryService)
// Los doc-comments completos de cada canario viven en el historial de TelemetryService
// (git) y en los call-sites; aquí solo el mapeo a wire (detail/value).

extension MetricsService {

    /// Duplicado CloudKit observado; dedup por (model, context, keySuffix) — el suffix es local-only.
    static func cloudkitDuplicateDetected(
        model: String,
        count: Int,
        context: DuplicateDetectionContext,
        keySuffix: String
    ) {
        canaryOnce(
            .cloudkitDuplicateDetected,
            key: "\(model):\(context.rawValue):\(keySuffix)",
            detail: "\(model)|\(context.rawValue)",
            value: Double(count)
        )
    }

    static func routingIntentSuperseded(droppedID: String, by incomingID: String) {
        canary(.routingIntentSuperseded, detail: "\(droppedID)>\(incomingID)")
    }

    static func routingIntentDeferred(intentID: String, reason: String) {
        canary(.routingIntentDeferred, detail: "\(intentID)|\(reason)")
    }

    static func cloudSecondaryMountMismatchBlocked() {
        canary(.cloudSecondaryMountMismatchBlocked)
    }

    // MARK: C-1 — canal iCloud del cutover

    /// La precondición del canal iCloud impidió entrar al cutover. `detail` = `ICloudChannelVerdict.rawValue`.
    static func cloudCutoverICloudBlocked(verdict: String) {
        canary(.cloudCutoverICloudBlocked, detail: verdict)
    }

    /// Waiver del gate de export del marcador (sin cuenta iCloud y sin huella CloudKit).
    static func cloudCutoverMarkerWaived() {
        canary(.cloudCutoverMarkerWaived)
    }

    /// El marcador del cutover sigue sin exportar. Se emite en CADA observación: un valor sostenido y alto
    /// aquí es la señal de un atasco SISTÉMICO (p.ej. el record type sin desplegar a CloudKit Production),
    /// visible mucho antes de que ningún device agote su presupuesto.
    static func cloudCutoverMarkerStalled(verdict: String) {
        canary(.cloudCutoverMarkerStalled, detail: verdict)
    }

    /// El presupuesto del paso 4 se agotó → el cutover abortó y el device volvió a `.icloud`.
    static func cloudCutoverAborted(verdict: String) {
        canary(.cloudCutoverAborted, detail: verdict)
    }

    /// Par de storage incompleto (`.cloud` + mirror ON) en fase estable ⇒ motor del dominio bloqueado.
    static func cloudStorageModePairViolation() {
        canary(.cloudStorageModePairViolation)
    }

    static func routingReadinessBlocked(blocker: String) {
        canary(.routingReadinessBlocked, detail: blocker)
    }

    static func routingDrainHoldSustained(blocker: String, consumer: String) {
        canary(.routingDrainHoldSustained, detail: "\(blocker)|\(consumer)")
    }

    static func routingWelcomeChainSuperseded(intentID: String) {
        canary(.routingWelcomeChainSuperseded, detail: intentID)
    }

    static func inviteReEmittedFromStore() {
        canary(.inviteReEmittedFromStore)
    }

    static func invitePendingExpired() {
        canary(.invitePendingExpired)
    }

    static func cloudkitTransferOrphanRepaired(orphansCleared: Int, pairedCount: Int) {
        canary(
            .cloudkitTransferOrphanRepaired,
            detail: "\(TransferReconcileContext.bootReconcile.rawValue)|paired=\(pairedCount)",
            value: Double(orphansCleared)
        )
    }

    static func cloudSyncIdentityGapObserved(entityType: String) {
        canary(.cloudSyncIdentityGapObserved, detail: entityType)
    }

    static func cloudSyncCoherenceGroupPartial(entity: String, group: String) {
        canary(.cloudSyncCoherenceGroupPartial, detail: "\(entity)|\(group)")
    }

    static func cloudSignInProviderMismatch() {
        canary(.cloudSignInProviderMismatch)
    }

    static func cloudSyncBlockedByAttestUnavailable(platform: String) {
        canary(.cloudSyncBlockedByAttestUnavailable, detail: platform)
    }

    static func cloudSyncBlockedByExpiredSession(pending: Int) {
        canary(.cloudSyncBlockedByExpiredSession, value: Double(pending))
    }

    static func cloudSyncOutboxMirrorRehydrated(count: Int) {
        canary(.cloudSyncOutboxMirrorRehydrated, value: Double(count))
    }

    static func cloudSyncOutboxMirrorDivergence(delta: Int) {
        canary(.cloudSyncOutboxMirrorDivergence, value: Double(delta))
    }

    static func cloudSyncMutationRejected(reason: String) {
        canary(.cloudSyncMutationRejected, detail: reason)
    }

    static func cloudCutoverLeaderOrphanReconciled(count: Int) {
        canary(.cloudCutoverLeaderOrphanReconciled, value: Double(count))
    }

    static func cloudAdoptOrphanReconciled(count: Int) {
        canary(.cloudAdoptOrphanReconciled, value: Double(count))
    }

    static func cloudConsentAccepted(path: String) {
        canary(.cloudConsentAccepted, detail: path)
    }

    static func cloudAccountUnavailable() {
        canary(.cloudAccountUnavailable)
    }

    static func accountDeletionCompleted(step: String) {
        canary(.accountDeletionCompleted, detail: step)
    }

    static func accountDeletionFailed(step: String) {
        canary(.accountDeletionFailed, detail: step)
    }

    static func siwaExchangeFailed(reason: String) {
        canary(.siwaExchangeFailed, detail: reason)
    }

    static func siwaRevokeFailed(reason: String) {
        canary(.siwaRevokeFailed, detail: reason)
    }

    static func googleRevokeFailed(reason: String) {
        canary(.googleRevokeFailed, detail: reason)
    }

    static func cloudAccountReverting() {
        canary(.cloudAccountReverting)
    }

    static func cloudSyncClockReceiveRejected(reason: String) {
        canary(.cloudSyncClockReceiveRejected, detail: reason)
    }

    static func cloudSyncMerkleDivergence(entity: String) {
        canary(.cloudSyncMerkleDivergence, detail: entity)
    }

    static func groupMerkleDivergence(groupCount: Int) {
        canary(.groupMerkleDivergence, value: Double(groupCount))
    }

    static func cloudkitTransferCollisionDetected(count: Int) {
        canary(
            .cloudkitTransferCollisionDetected,
            detail: TransferReconcileContext.bootCollision.rawValue,
            value: Double(count)
        )
    }
}
