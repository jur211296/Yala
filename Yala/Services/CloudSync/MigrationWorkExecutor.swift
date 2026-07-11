//
//  MigrationWorkExecutor.swift
//  Yala
//
//  Ejecutor REAL del seam `MigrationWorkExecuting` (Modo Nube Fase 4, I10-wiring ciclo B). Implementa el
//  trabajo por fase que el `MigrationRunner` orquesta: claim / identidad / snapshot / verify + el faro KV,
//  reusando los componentes ya probados del motor (engine, push/pull/merkle clients, account client). w6
//  cableó el CUTOVER (§g.4): `confirmCutoverServer`/`persistLocalMode` + los efectos
//  `startParallelHistoryCapture`/`writeCloudKitMarker`/`disableMirrorAndRelaunch`/
//  `runLeaderReconcileFromFrozenCloudKit` + los testigos `isMirrorConfirmedOff`/`isMarkerExported`. El
//  BACKSTOP corre en `runLeaderReconcileFromFrozenCloudKit`. I11-2 cableó los efectos LOCALES de la
//  reversa (§h); I11-3 cableó su server-side (`performReverseClaim`/`freezeBackendForReverse`/
//  `completeReverseServer`/`reverseRollback` → acciones `reverse_*` del RPC `migration_progress`). Solo
//  `adoptBackendAccount` (§k.4) sigue `notWired` (el runner lo deja journaled, retomable).
//
//  DARK: nada de producción instancia este executor (el runner no se instancia; la UI de migración es I14,
//  el panel DEBUG w7). Solo lo ejercitan los tests del ciclo + el e2e staging.
//
//  `@MainActor`: manipula red/identidad/ModelContext (regla inviolable del repo).
//

import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Error del executor cuando un efecto/paso aún no está cableado (w6/w8). El runner lo trata como un efecto
/// que lanza → lo deja journaled (retomable). `nonisolated` (lo compara la lógica pura de tests).
nonisolated enum MigrationExecutorError: Error, Equatable {
    case notWired(effect: String)
}

// MARK: - AdoptReconcileOutcome (DIFERIDOS #30, mecanismo v1 DARK)

/// Resultado de `runAdoptOrphanReconcile()`. `nonisolated` (lo compara la lógica de tests). Idempotente:
/// una 2ª pasada encuentra las ex-huérfanas ya en el backend → `completed(0, 0)`.
nonisolated enum AdoptReconcileOutcome: Equatable {
    /// El diff corrió y (si había) subió las huérfanas. `uploaded` = filas aplicadas server-side;
    /// `identityAssigned` = filas sin syncID a las que el backfill acuñó identidad fresca.
    case completed(uploaded: Int, identityAssigned: Int)
    /// Guard defensivo anti mass-upload: la enumeración del backend llegó VACÍA teniendo huérfanas locales
    /// → NO se sube nada (un adopt legítimo implica backend POBLADO; enumeración vacía = página espuria/bug).
    case abortedEmptyBackend
    /// Red caída en la enumeración o el push → retomable (el re-run re-diffea; lo ya aplicado sale del diff).
    case transient
}

// MARK: - ReverseTombstoneSource (§h.3, I11-2)

/// Fuente GENÉRICA de páginas de deltas en LECTURA PURA: NO aplica (`applyPage`), NO avanza `SyncCursor`, NO
/// toca testigos `SyncIdentity` — el apply normal BORRA el testigo al aplicar un tombstone y aquí NO queremos
/// ese side-effect. Consumida por el barrido de zombies de la reversa (§h.3 — enumera tombstones) Y por la
/// reconciliación de huérfanas del adopt (DIFERIDOS #30 — enumera TODAS las identidades que el backend
/// conoce, upserts Y tombstones). Default = wrapper del `pullClient`; los tests la fakean para el golden §h.5
/// (no se protocoliza `SyncPullClient` entero).
@MainActor
protocol ReverseTombstoneSource: AnyObject {
    /// Baja UNA página de deltas desde `since` (reusa el `PullOutcome` del pull).
    func pullPage(since: Int64, limit: Int) async -> PullOutcome
}

extension SyncPullClient: ReverseTombstoneSource {
    func pullPage(since: Int64, limit: Int) async -> PullOutcome { await pull(since: since, limit: limit) }
}

// MARK: - ReverseEligibility (guardarraíl §h.6-A1, obligación 1 del review)

/// Guardarraíl PURO que el panel (I11-5) consulta ANTES de emitir `reverseActivated`. `nonisolated`: lógica
/// pura sin `ModelContext`/red/`Date`. `hasCKMap` = existe ≥1 `SyncIdentity` con `ckRecordName != nil` (el
/// mapa de coordenadas CloudKit que la reversa NECESITA para borrar los records — un born-cloud §h.6 con
/// map-nil-por-diseño queda EXCLUIDO en v1; el panel targetea al migrado). `degradedNoMap` dispara el canario
/// `cloudReverseDegradedNoMap`.
nonisolated enum ReverseEligibility {
    enum Decision: Equatable {
        case eligible
        /// El device NO está en modo nube (`storageMode != .cloud`) → la reversa no aplica.
        case notCloudMode
        /// Modo nube PERO sin mapa de coordenadas CloudKit (born-cloud sin captura) → NO elegible en v1.
        case degradedNoMap
        /// Ya en un terminal de la reversa (`icloudActive`/`reverseFailedRollback`) → nada que revertir.
        case reverseAlreadyTerminal
    }

    static func decide(storageMode: StorageMode, hasCKMap: Bool, journaledPhase: MigrationPhase) -> Decision {
        guard storageMode == .cloud else { return .notCloudMode }
        switch journaledPhase {
        case .icloudActive, .reverseFailedRollback:
            return .reverseAlreadyTerminal
        default:
            break
        }
        guard hasCKMap else { return .degradedNoMap }
        return .eligible
    }
}

@MainActor
final class MigrationWorkExecutor: MigrationWorkExecuting {

    private let engine: CloudSyncEngine
    private let pushClient: SyncPushClient
    private let pullClient: SyncPullClient
    private let merkleClient: SyncMerkleClient
    private let accountClient: CloudAccountClient
    private let session: CloudSyncSessionProviding
    private let context: ModelContext
    private let calendar: Calendar
    private let now: () -> Date
    private let deviceID: String
    private let provider: String
    private let beacon: CloudBeacon
    private let personalStoreURL: URL
    private let uploader: MigrationSnapshotUploader
    /// Fuente de tombstones para el barrido de zombies (§h.3). Default = `pullClient`; inyectable para el
    /// golden §h.5 (enumeración PURA, sin applyPage/cursor/testigos).
    private let tombstoneSource: ReverseTombstoneSource
    /// UserDefaults para persistir `storageMode=.cloud` (paso 2) y el flag `relaunchRequested` (paso 4).
    /// Inyectable para tests (nunca `.standard` directo en tests — regla del repo).
    private let storageDefaults: UserDefaults
    /// Ventana mínima entre heartbeats del lease (I14-pre). El runner llama `sendLeaseHeartbeatIfDue()` por
    /// PROGRESO (por página del snapshot, por drain de la reversa); este throttle lo capa a 1 request/ventana.
    private let heartbeatInterval: TimeInterval
    /// Instante del último heartbeat EMITIDO (I14-pre). IN-MEMORY, NO journaled: un kill+resume lo resetea →
    /// a lo sumo UN heartbeat extra por relanzamiento (idempotente, 1 request). Se arma también en rechazo/red
    /// para no martillar el endpoint por-página cuando el server rechaza o la red está caída.
    private var lastHeartbeatAt: Date?

    /// Key del flag `relaunchRequested` (§g.4 paso 4). iOS no se auto-relanza; el relaunch asistido es
    /// I14. ALIAS de `StorageModePersistence.mirrorOffArmedKey` (SERIO 1): este flag es TAMBIÉN el
    /// armado del montaje mirror-OFF — `personalStoreDecision` lo exige junto a `.cloud`; escribirlo
    /// solo tras `isMarkerExported()` (el runner lo garantiza) cierra la ventana de kill que enclavaba
    /// la migración con el marcador sin exportar.
    static let relaunchRequestedKey = StorageModePersistence.mirrorOffArmedKey

    /// `identifierForVendor` (o un UUID fresco si UIKit no está disponible / es nil). El faro/claim lo usan
    /// como `device_id` estable del dispositivo.
    static var vendorDeviceID: String {
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        return UUID().uuidString
        #endif
    }

    init(
        engine: CloudSyncEngine,
        pushClient: SyncPushClient,
        pullClient: SyncPullClient,
        merkleClient: SyncMerkleClient,
        accountClient: CloudAccountClient,
        session: CloudSyncSessionProviding,
        context: ModelContext,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { .now },
        deviceID: String? = nil,
        provider: String = "apple",
        beacon: CloudBeacon? = nil,
        personalStoreURL: URL? = nil,
        storageDefaults: UserDefaults = .standard,
        snapshotPageSize: Int = 200,
        heartbeatInterval: TimeInterval = 60,
        reverseTombstoneSource: ReverseTombstoneSource? = nil
    ) {
        self.engine = engine
        self.pushClient = pushClient
        self.pullClient = pullClient
        self.merkleClient = merkleClient
        self.accountClient = accountClient
        self.session = session
        self.context = context
        self.calendar = calendar
        self.now = now
        // Defaults MainActor-aislados resueltos en el cuerpo (no en los default args, que son nonisolated).
        self.deviceID = deviceID ?? MigrationWorkExecutor.vendorDeviceID
        self.provider = provider
        self.beacon = beacon ?? CloudBeacon()
        self.personalStoreURL = personalStoreURL ?? SwiftDataConfiguration.personalConfiguration.url
        self.storageDefaults = storageDefaults
        self.heartbeatInterval = heartbeatInterval
        self.uploader = MigrationSnapshotUploader(
            engine: engine, pushClient: pushClient, context: context,
            calendar: calendar, now: now, pageSize: snapshotPageSize)
        self.tombstoneSource = reverseTombstoneSource ?? pullClient
    }

    // MARK: - Claim (§f.1)

    /// `POST /account/claim` con el JWT vigente + el `device_id` del dispositivo + `provider`. Sin JWT →
    /// `.sessionExpired` (el runner corta SIN evento, retomable; un re-login lo despierta). NUNCA lanza.
    func performClaim() async -> ClaimOutcome {
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            return .sessionExpired(detail: "no access token")
        }
        // `migration: true` ES OBLIGATORIO (bug device 2026-07-10): arma `migration_in_progress=true` en
        // el INSERT atómico → el guard de `migration_progress('cutover')` (exige mip) pasa. Sin él, el
        // claim crea la fila con mip=false y el cutover se clava en `not_in_progress` para siempre.
        return await accountClient.claim(jwt: jwt, deviceID: deviceID, provider: provider, migration: true)
    }

    // MARK: - Identidad (w3)

    /// Backfill de `syncID` + testigos `SyncIdentity` (la quiescencia la GARANTIZÓ el runner a la entrada —
    /// §b.3), flip del gate PERMANENTE `identityCaptureEnabled`, y captura de las coordenadas CloudKit con el
    /// mirror VIVO sobre las 16 entidades (las 10 de UUID estable TAMBIÉN — §b.5: no se asume que el UUID de
    /// dominio sea el recordName). El save de las filas casadas + testigos va en UN `context.save()`.
    ///
    /// **Contrato del flag (doc, w6)**: encender `identityCaptureEnabled` aquí es SOLO in-memory; la
    /// derivación persistente al boot (journal ≥ `assigningIdentity` → flag ON) llega en w6 con
    /// `MigrationPhaseStore`. HOY el runner lo re-flipea en cada `assignIdentity` (idempotente/re-ejecutable).
    func assignIdentity() async throws {
        // 1. Backfill (la quiescencia ya la garantizó el runner).
        SyncIdentityService.backfillIdentities(context: context, now: now())

        // 2. Gate PERMANENTE (§g.3): todo save nuevo acuña syncID. In-memory hoy (persistencia en w6).
        CloudSyncFlags.identityCaptureEnabled = true

        // 3. Captura CloudKit sobre las 16 entidades (mirror vivo).
        let pairs = collectIdentityPairs()
        let report = CKIdentityCapture.capture(pairs, storeURL: personalStoreURL)

        // 4. Save (la captura escribió las coordenadas en las filas testigo; aquí se persisten).
        if context.hasChanges {
            try context.save()
        }
        CloudSyncBreadcrumb.migrationIdentityCaptured(
            captured: report.captured, exportPending: report.exportPending,
            noMetadata: report.noMetadata, failed: report.failed)
    }

    /// Correlaciona cada fila de negocio (por su identidad de sync) con su testigo `SyncIdentity` → pares
    /// `(PersistentIdentifier, SyncIdentity)` para `CKIdentityCapture`. Las 16 entidades.
    private func collectIdentityPairs() -> [(id: PersistentIdentifier, row: SyncIdentity)] {
        var rowsBySyncID: [UUID: SyncIdentity] = [:]
        do {
            for row in try context.fetch(FetchDescriptor<SyncIdentity>()) {
                rowsBySyncID[row.syncID] = row
            }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: fetch(SyncIdentity) falló: \(error)")
            #endif
            return []
        }

        var pairs: [(id: PersistentIdentifier, row: SyncIdentity)] = []
        addPairs(TransactionItem.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(InboxDraft.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(Category.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(FavoritePayment.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(MerchantMemory.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(ExchangeRate.self, identity: { $0.syncID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(Budget.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(ScheduledPayment.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(Account.self, identity: { $0.shortcutID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(Subcategory.self, identity: { $0.shortcutID }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(Tag.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(NotificationItem.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(CashFlowPlan.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(CashFlowLine.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(CashFlowOverride.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        addPairs(GroupBridgePreference.self, identity: { $0.id }, into: &pairs, rowsBySyncID: rowsBySyncID)
        return pairs
    }

    /// Fetch CONCRETO por tipo (regla inviolable de `#Predicate`). Empareja cada modelo con identidad con su
    /// testigo (una fila jamás exportada/no-backfilleada sin testigo se salta — no bloquea).
    private func addPairs<M: PersistentModel>(
        _ type: M.Type, identity: (M) -> UUID?,
        into pairs: inout [(id: PersistentIdentifier, row: SyncIdentity)],
        rowsBySyncID: [UUID: SyncIdentity]
    ) {
        do {
            for model in try context.fetch(FetchDescriptor<M>()) {
                guard let sid = identity(model), let row = rowsBySyncID[sid] else { continue }
                pairs.append((model.persistentModelID, row))
            }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: fetch(\(M.self)) para captura falló: \(error)")
            #endif
        }
    }

    // MARK: - Snapshot (w4)

    /// Sube el snapshot completo en batches idempotentes/resumibles (delega en `MigrationSnapshotUploader`).
    func uploadSnapshot(cursor: String?) async -> SnapshotStepOutcome {
        await uploader.uploadPage(cursor: cursor)
    }

    // MARK: - Verify (w5)

    /// Verifica cuenta+checksum Merkle local vs backend, con el pre-check TOCTOU (§g.3) y el `pullAndApplyOnce`
    /// OBLIGATORIO antes de `verifyIntegrity` (el guard `lastPullCycleCompleted` jamás se pone durante la
    /// migración porque el runtime no corre → sin el pull, `verifyIntegrity` skippearía SIEMPRE).
    func verify() async -> VerifyProbe {
        // Pre-check TOCTOU: drenar + subir si hay filas vivas ANTES de verificar. Partición poison (#26,
        // fix del review adversarial — simetría con el uploader): una fila no-construible se AÍSLA como
        // dead-letter (el mismatch que provoca consume presupuesto de MISMATCH → degrada honesto a
        // failedRollback) en vez de hacer fallar el push entero consumiendo presupuesto de RED.
        engine.drainOnce(context: context)
        let allLive = liveOutboxRows()
        let (live, poison) = pushClient.partitionBuildable(allLive)
        engine.deadLetterPoison(poison, context: context, now: now())
        if !live.isEmpty {
            switch await pushClient.push(live) {
            case .completed(let results):
                await pushClient.applyResults(results, rows: live, engine: engine, context: context)
                // Si tras el push quedan filas VIVAS → red (transient); si el outbox quedó limpio → un delta
                // aterrizó y se subió → re-run barato (NO consume retry).
                return liveOutboxRows().isEmpty ? .newDeltaDetected : .networkTimeout
            case .sessionExpired, .accountUnavailable, .transient:
                return .networkTimeout
            }
        }

        // pullAndApplyOnce ANTES de verifyIntegrity: marca `lastPullCycleCompleted` (cuenta fresca = pull
        // vacío; re-verify = trae de vuelta nuestras propias filas, LWW no-op material). Pull transient → red.
        switch await engine.pullAndApplyOnce(using: pullClient, context: context, now: now()) {
        case .completed:
            break
        case .busy, .transient, .sessionExpired, .accountUnavailable:
            return .networkTimeout
        }

        let verdict = await engine.verifyIntegrity(using: merkleClient, context: context)
        if VerifyProbeMapping.isUnknownSkip(verdict) {
            if case .skipped(let reason) = verdict {
                CloudSyncBreadcrumb.migrationVerifyUnknownReason(reason: reason)
            }
        }
        return VerifyProbeMapping.map(verdict: verdict)
    }

    private func liveOutboxRows() -> [SyncOutbox] {
        do {
            return try context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: fetch(SyncOutbox) falló: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Cutover (w6, §g.4)

    /// w6 paso 1: `migration_progress('cutover')` — estampa `profiles.migrated_at` (guard líder). `.ok`
    /// → `true`; `.otherLeader` (usurpado) → `false` + breadcrumb (el runner corta retomable → follower);
    /// cualquier otro (rejected/transient/sessionExpired) → `false` + breadcrumb (stop retomable). Sin JWT
    /// → `false` (`.sessionExpired`; un re-login lo despierta). NUNCA lanza.
    func confirmCutoverServer() async -> Bool {
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            CloudSyncBreadcrumb.migrationCutoverRejected(reason: "sessionExpired")
            return false
        }
        switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "cutover") {
        case .ok:
            CloudSyncBreadcrumb.migrationCutoverConfirmed()
            return true
        case .otherLeader:
            CloudSyncBreadcrumb.migrationCutoverOtherLeader()
            return false
        case .rejected(let reason):
            CloudSyncBreadcrumb.migrationCutoverRejected(reason: reason)
            return false
        case .sessionExpired:
            CloudSyncBreadcrumb.migrationCutoverRejected(reason: "sessionExpired")
            return false
        case .transient:
            CloudSyncBreadcrumb.migrationCutoverRejected(reason: "transient")
            return false
        }
    }

    /// w6 paso 2: persiste `storageMode=.cloud` (`StorageModePersistence`). El próximo relanzamiento montará
    /// el store personal con el mirror OFF (`personalConfiguration` rama `.cloud`). Devuelve `true`.
    func persistLocalMode() async -> Bool {
        StorageModePersistence.write(.cloud, defaults: storageDefaults)
        CloudSyncBreadcrumb.migrationLocalModePersisted()
        return true
    }

    // MARK: - Efectos declarativos

    /// Ejecuta un efecto declarativo. Cableados en w6: `.writeBeacon` (§g.4-faro, al claim),
    /// `.startParallelHistoryCapture`, `.writeCloudKitMarker`, `.disableMirrorAndRelaunch`,
    /// `.runLeaderReconcileFromFrozenCloudKit`; en I11-2 los efectos locales de la reversa; en I11-3
    /// `.completeReverseServer`/`.reverseRollback` (server-side, acciones `reverse_*` del RPC).
    /// `.adoptBackendAccount` → `notWired` (§k.4, fuera de este ciclo; el runner lo deja journaled retomable).
    func execute(_ effect: MigrationEffect) async throws {
        switch effect {
        case .writeBeacon:
            beacon.writeCloudAccountLinked(provider: provider, accountSub: session.currentUserID, now: now())

        case .startParallelHistoryCapture:
            // La CAPTURA continua ES el History (token-based): cualquier write de la ventana
            // localModeSet→mirrorOff queda en History tras el token y lo drena el próximo `drainOnce`
            // (post-relaunch). Un `drainOnce` aquí ancla el baseline al momento del cutover — no hace falta
            // un loop de captura dedicado.
            engine.drainOnce(context: context)

        case .writeCloudKitMarker:
            // Último efecto OBSERVABLE: insertar el marcador en el store PERSONAL (el mirror VIVO lo exporta).
            // `serverSeqCut` = `SyncCursor.serverSeqCursor` actual (corte para `reconcileFromFrozenCloudKit`).
            let marker = CloudMigrationMarker(
                accountHash: session.currentUserID.map { CloudBeacon.hash($0) } ?? "",
                migratedAtStamp: now(),
                serverSeqCut: currentServerSeqCut(),
                writerDeviceID: deviceID)
            context.insert(marker)
            if context.hasChanges {
                try context.save()
            }
            CloudSyncBreadcrumb.migrationMarkerWritten(serverSeqCut: marker.serverSeqCut)

        case .disableMirrorAndRelaunch:
            // iOS no puede auto-relanzarse: persistimos el flag; el relanzamiento asistido con UI es I14
            // (en DEBUG el panel indica MATAR Y RELANZAR). El proceso NO se mata solo. El forward a
            // `done` lo resuelve por OBSERVACIÓN `isMirrorConfirmedOff()` (post-relaunch).
            storageDefaults.set(true, forKey: Self.relaunchRequestedKey)
            CloudSyncBreadcrumb.migrationRelaunchRequested()

        case .runLeaderReconcileFromFrozenCloudKit:
            // w8 — CAPA DE RED del líder (§g.4 SERIO 1 v3), ANTES del 'complete'. DECISIÓN documentada
            // (invariante PRECISADO por el review adversarial): el líder solo responde por SUS PROPIOS
            // writes — y TODOS sus writes de la ventana de cutover están en su History LOCAL (durable)
            // tras el baseline → el barrido correcto para el líder es drain(History) + push del residual.
            // Una fila que el CloudKit congelado tenga y el local NO (un 2º device del mismo Apple ID,
            // aún .icloud, escribiendo a la base compartida durante la ventana — el device puede no
            // haberla importado antes del mirror-off) NO es responsabilidad de este barrido: la sube el
            // PROPIO device que la escribió por su camino de adopt. CERRADO por `runAdoptOrphanReconcile()`
            // (DIFERIDOS #30, DARK): el adoptador diffea su store local contra `/sync/pull` read-only y sube
            // fila-completa cualquier identidad ∉ backend. I14 DEBE invocarlo en el flujo de adopt tras
            // quiescencia del import + fast-forward del baseline (contrato en el doc del método). RESIDUAL v1
            // irreducible: un device que escribió post-cutover y JAMÁS adopta deja esa fila huérfana en
            // CloudKit congelado (auto-bloqueado por `secondaryDeviceCloudLogin`; la fila no se pierde
            // físicamente y una adopción tardía la rescata — el diff no caduca). También v1: borrados de
            // ventana (resurrección benigna) + import-lag (duplicado curable). Candidato v2 (device que jamás
            // adopta) = lectura directa del CloudKit congelado por el líder (opción C, descartada v1).
            engine.drainOnce(context: context)
            let residual = liveOutboxRows()
            let (buildable, poison) = pushClient.partitionBuildable(residual)
            engine.deadLetterPoison(poison, context: context, now: now())
            if !buildable.isEmpty {
                guard case .completed(let results) = await pushClient.push(buildable) else {
                    // Red → retomable: el 'complete' NO se marca; el resume re-corre este efecto entero
                    // (drain/push idempotentes por LWW + confirmUploaded).
                    throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: sweepTransient")
                }
                await pushClient.applyResults(results, rows: buildable, engine: engine, context: context)
                let rescued = results.filter { $0.status == .applied }.count
                if rescued > 0 {
                    CloudSyncBreadcrumb.migrationLeaderOrphanReconciled(count: rescued)
                    TelemetryService.cloudCutoverLeaderOrphanReconciled(count: rescued)
                }
            }
            // `migration_progress('complete')` (líder) — SOLO tras el barrido (un kill entre ambos re-corre
            // el barrido, no-op, y reintenta el complete; idempotente).
            guard let jwt = await session.accessToken(), !jwt.isEmpty else {
                CloudSyncBreadcrumb.migrationCutoverRejected(reason: "complete: sessionExpired")
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: sessionExpired")
            }
            switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "complete") {
            case .ok:
                CloudSyncBreadcrumb.migrationReconcileDeferred()
            case .otherLeader:
                CloudSyncBreadcrumb.migrationCutoverOtherLeader()
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: otherLeader")
            case .rejected(let reason):
                CloudSyncBreadcrumb.migrationCutoverRejected(reason: "complete: \(reason)")
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: \(reason)")
            case .sessionExpired:
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: sessionExpired")
            case .transient:
                throw MigrationExecutorError.notWired(effect: "runLeaderReconcile: transient")
            }

        case .rollback:
            // Pre-cutover el device YA está intacto (el mirror nunca se apagó; el runner limpia los
            // campos scoped al entrar a failedRollback). El "rollback" ES un no-op observable — dejarlo
            // notWired (bug device 2026-07-10) lo dejaba journaled-pendiente para siempre y cada resume
            // re-lanzaba. Defensivo: desarmar mirror-off (no puede estar armado pre-cutover, pero barato).
            storageDefaults.removeObject(forKey: Self.relaunchRequestedKey)
            CloudSyncBreadcrumb.migrationRollbackCompleted()

        case .adoptBackendAccount:
            // §k.4 — el flujo COMPLETO de adopt (consent + sign-in + claim `existing_stable` + pull del
            // corpus + fast-forward del baseline + switch a `.cloud`) ES I14; este efecto sigue `notWired`
            // (el runner lo deja journaled retomable). La PIEZA de reconciliación de huérfanas de la ventana
            // ya existe DARK: `runAdoptOrphanReconcile()` — I14 la invoca tras la quiescencia del import y
            // ANTES de arrancar el runtime (ver el contrato en su doc-comment).
            CloudSyncBreadcrumb.migrationExecutorNotWired(step: effect.rawValue)
            throw MigrationExecutorError.notWired(effect: effect.rawValue)

        // Reversa (§h, I11-2) — efectos LOCALES cableados. mountMirrorAndRelaunch cruza el process boundary
        // (espeja disableMirrorAndRelaunch): DESARMA el flag manteniendo `.cloud` → `personalStoreDecision`
        // monta el mirror `.private` al RELANZAR; el forward a reverseMountMirror lo resuelve el runner por
        // OBSERVACIÓN (`isMirrorConfirmedOn`). NO mata el proceso (relaunch asistido = I14).
        case .mountMirrorAndRelaunch:
            storageDefaults.removeObject(forKey: Self.relaunchRequestedKey)
            CloudSyncBreadcrumb.reverseRelaunchRequested()

        case .deleteCloudKitMarker:
            // Borra el `CloudMigrationMarker` del store PERSONAL (el mirror VIVO exporta el delete). Sin él
            // un re-migrate futuro dispararía falso `secondaryDeviceCloudLogin`. Idempotente (0 si no había).
            // Save por DEFECTO (como el insert del marcador en el cutover): el marcador no es entidad de sync
            // (sin syncID) → no ecoa al backend; el mirror sí lo exporta.
            // El fetch RELANZA en fallo (review I11-2): un `try?` aquí saltaba el borrado PERMANENTEMENTE
            // (el efecto no throweaba → se removía del pending → jamás retomado). Throwear lo deja
            // journaled-pendiente y el próximo resume() lo reintenta.
            let markers = try context.fetch(FetchDescriptor<CloudMigrationMarker>())
            for marker in markers { context.delete(marker) }
            if context.hasChanges { try context.save() }
            CloudSyncBreadcrumb.reverseMarkerDeleted(count: markers.count)

        case .clearCloudBeacon:
            beacon.clearCloudAccountLinked()
            CloudSyncBreadcrumb.reverseBeaconCleared()

        case .persistICloudMode:
            // Invariante SERIO 1: `storageMode=.icloud` + `mirrorOffArmed=false` se mueven JUNTOS (dejar
            // `.cloud`+mirror ON, o `.icloud`+armado, sería dual-write). Ambos en el mismo efecto.
            StorageModePersistence.write(.icloud, defaults: storageDefaults)
            storageDefaults.removeObject(forKey: Self.relaunchRequestedKey)
            CloudSyncBreadcrumb.reverseModePersisted()

        // D1 DIFERIDO (review I11-2): la higiene de sync-meta al entrar a `icloudActive`
        // (SyncOutbox/SyncCursor/unit-clocks/quarantine/danglers con estado de la época nube) es inerte en
        // `.icloud` (runtime gateado por `storageMode == .cloud`), pero un re-cutover futuro con
        // cursor/clocks stale podría envenenarse — el diseño de re-cutover (I14+) DEBE decidir purga-vs-reuso.
        case .completeReverseServer:
            // `reverse_complete` (§h, I11-3): `reverse_in_progress=false` + `reverted_at=now()` server-side.
            // `migrated_at` NO se toca (§h.4 — el backend queda congelado como red; `reverted_at` es la
            // señal para el diseño futuro de re-cutover). `.ok` → breadcrumb; el resto THROWEA → queda
            // journaled-pendiente retomable (patrón del complete de la ida en runLeaderReconcile).
            guard let jwt = await session.accessToken(), !jwt.isEmpty else {
                CloudSyncBreadcrumb.reverseCompleteRejected(reason: "sessionExpired")
                throw MigrationExecutorError.notWired(effect: "completeReverseServer: sessionExpired")
            }
            switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "reverse_complete") {
            case .ok:
                CloudSyncBreadcrumb.reverseCompleteConfirmed()
            case .otherLeader:
                CloudSyncBreadcrumb.reverseCompleteRejected(reason: "otherLeader")
                throw MigrationExecutorError.notWired(effect: "completeReverseServer: otherLeader")
            case .rejected(let reason):
                CloudSyncBreadcrumb.reverseCompleteRejected(reason: reason)
                throw MigrationExecutorError.notWired(effect: "completeReverseServer: \(reason)")
            case .sessionExpired:
                CloudSyncBreadcrumb.reverseCompleteRejected(reason: "sessionExpired")
                throw MigrationExecutorError.notWired(effect: "completeReverseServer: sessionExpired")
            case .transient:
                CloudSyncBreadcrumb.reverseCompleteRejected(reason: "transient")
                throw MigrationExecutorError.notWired(effect: "completeReverseServer: transient")
            }

        case .reverseRollback:
            // `reverse_abort` (§h, I11-3): DES-congela el backend (`reverse_in_progress=false` +
            // `reverse_frozen_at=null`; `reverted_at` queda null — la reversa NO ocurrió). El RPC acepta
            // lease expirado (abort de emergencia post-crash largo) y es idempotente con rip ya false.
            // sessionExpired/transient → THROW (journaled, retomable — la red/el re-login lo despiertan).
            // rejected/otherLeader → NO throw perpetuo (decisión I11-3, documentada en el plan): el estado
            // local ya es TERMINAL estable (reverseFailedRollback); un abort rechazado por lease usurpado
            // dejaría el efecto journaled-pendiente PARA SIEMPRE re-lanzando en cada resume (el mismo
            // bug-class del rollback de la ida, device 2026-07-10) → breadcrumb RUIDOSO + completar. El
            // backend puede quedar rip=true: un `reverse_claim` posterior es idempotente-ok (o el nuevo
            // líder sigue su propia reversa — su estado manda).
            guard let jwt = await session.accessToken(), !jwt.isEmpty else {
                throw MigrationExecutorError.notWired(effect: "reverseRollback: sessionExpired")
            }
            switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "reverse_abort") {
            case .ok:
                CloudSyncBreadcrumb.reverseAborted()
            case .sessionExpired:
                throw MigrationExecutorError.notWired(effect: "reverseRollback: sessionExpired")
            case .transient:
                throw MigrationExecutorError.notWired(effect: "reverseRollback: transient")
            case .otherLeader:
                CloudSyncBreadcrumb.reverseAbortRejectedButCompleted(reason: "otherLeader")
            case .rejected(let reason):
                CloudSyncBreadcrumb.reverseAbortRejectedButCompleted(reason: reason)
            }
        }
    }

    /// Observación post-relaunch (§g.4): ¿ESTE proceso montó el store personal en modo `.cloud` (mirror
    /// OFF)? Testigo de arranque (`SwiftDataConfiguration.personalStoreMountedMode`), NO lo persistido: en
    /// la misma sesión, tras `persistLocalMode`, el mirror SIGUE vivo (se montó al arrancar) → esto queda
    /// `false` hasta el RELANZAMIENTO, cuando un proceso nuevo monta `.none` y captura `.cloud`.
    func isMirrorConfirmedOff() -> Bool {
        SwiftDataConfiguration.personalStoreMountedMode == .cloud
    }

    /// Gate de EXPORT del marcador (§g.4 ajuste, entre paso 3 y 4): ¿el `CloudMigrationMarker` LLEGÓ a
    /// CloudKit? Reusa `CKIdentityCapture` sobre la fila del marcador (`ZCKRECORDNAME` non-NULL = exportado).
    /// El save del marcador exporta ASYNC — apagar el mirror antes lo perdería para siempre (los 2º devices
    /// jamás se auto-bloquearían = divergencia silenciosa). Señal S5-validada, necesaria-no-suficiente
    /// (residual documentado; el guion device lo re-verifica en CloudKit Console). `false` si no hay
    /// marcador o su recordName sigue NULL.
    func isMarkerExported() -> Bool {
        let markers: [CloudMigrationMarker]
        do {
            markers = try context.fetch(FetchDescriptor<CloudMigrationMarker>())
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: fetch(CloudMigrationMarker) falló: \(error)")
            #endif
            return false
        }
        guard !markers.isEmpty else { return false }
        // Testigo SCRATCH por fila (NUNCA insertado): `capture` solo muta la fila en `.captured` y devuelve
        // el Report agregado — `captured >= 1` ⇒ al menos un marcador con recordName non-NULL (exportado).
        let pairs = markers.map {
            (id: $0.persistentModelID,
             row: SyncIdentity(syncID: UUID(), entityType: "CloudMigrationMarker", localAnchor: ""))
        }
        let report = CKIdentityCapture.capture(pairs, storeURL: personalStoreURL)
        return report.captured >= 1
    }

    /// `SyncCursor.serverSeqCursor` actual (corte del marcador). Sin fila aún → 0. Lectura pura (no crea).
    private func currentServerSeqCut() -> Int64 {
        do {
            var descriptor = FetchDescriptor<SyncCursor>()
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first?.serverSeqCursor ?? 0
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor: fetch(SyncCursor) para serverSeqCut falló: \(error)")
            #endif
            return 0
        }
    }

    // MARK: - Reversa (§h, I11-2)

    /// `reverse_claim` (§h, I11-3): reserva del liderazgo de la REVERSA server-side (RPC
    /// `migration_progress`, action `reverse_claim`). Guards server-side: `migrated_at` set (born-cloud v1
    /// → `rejected("not_migrated")`), takeover de migración ABANDONADA o reversa ajena con lease expirado
    /// >60min, re-claim idempotente del MISMO líder sin chequear edad. Sin JWT → `.sessionExpired`
    /// (patrón `performClaim`: el runner corta SIN evento, retomable). NUNCA lanza — los breadcrumbs de
    /// outcome los emite el runner (`driveReverseClaim`).
    func performReverseClaim() async -> ReverseClaimOutcome {
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            return .sessionExpired
        }
        switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "reverse_claim") {
        case .ok:
            return .accepted
        case .otherLeader:
            return .otherLeader
        case .rejected(let reason):
            return .rejected(reason: reason)
        case .sessionExpired:
            return .sessionExpired
        case .transient:
            return .transient
        }
    }

    /// `reverseDrainAll` (§h): drain de la History local → outbox, push del residual, y `pullAndApplyOnce`
    /// (pull FINAL). Reusa las piezas de `verify()` (partición poison + push + apply). Red → `.transient`.
    func reverseDrainOnce() async -> ReverseStepOutcome {
        engine.drainOnce(context: context)
        let allLive = liveOutboxRows()
        let (live, poison) = pushClient.partitionBuildable(allLive)
        engine.deadLetterPoison(poison, context: context, now: now())
        if !live.isEmpty {
            switch await pushClient.push(live) {
            case .completed(let results):
                await pushClient.applyResults(results, rows: live, engine: engine, context: context)
            case .sessionExpired, .accountUnavailable, .transient:
                return .transient
            }
        }
        switch await engine.pullAndApplyOnce(using: pullClient, context: context, now: now()) {
        case .completed:
            return .completed
        case .busy, .transient, .sessionExpired, .accountUnavailable:
            return .transient
        }
    }

    /// `reverseFreezeBackend` (§h, I11-3): `reverse_freeze` server-side — estampa `reverse_frozen_at`
    /// (guard reverse-líder SIN edad de lease: el MISMO líder lento siempre puede continuar; idempotente).
    /// `.ok` → `true`; el resto → breadcrumb + `false` (el runner corta retomable SIN evento). El
    /// ENFORCEMENT del freeze en `/sync/push` está ACTIVO (cerrado 2026-07-11): el gateway rechaza 409
    /// `yala_account_reverting` los pushes con `reverse_frozen_at` set. NO afecta a esta reversa: todos
    /// sus pushes (`reverseDrainOnce`) ocurren ANTES de este freeze (ver qa/cloud/README.md). NUNCA lanza.
    func freezeBackendForReverse() async -> Bool {
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            CloudSyncBreadcrumb.reverseFreezeRejected(reason: "sessionExpired")
            return false
        }
        switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "reverse_freeze") {
        case .ok:
            CloudSyncBreadcrumb.reverseBackendFrozen()
            return true
        case .otherLeader:
            CloudSyncBreadcrumb.reverseFreezeRejected(reason: "otherLeader")
            return false
        case .rejected(let reason):
            CloudSyncBreadcrumb.reverseFreezeRejected(reason: reason)
            return false
        case .sessionExpired:
            CloudSyncBreadcrumb.reverseFreezeRejected(reason: "sessionExpired")
            return false
        case .transient:
            CloudSyncBreadcrumb.reverseFreezeRejected(reason: "transient")
            return false
        }
    }

    /// Observación post-relaunch (§h): ¿ESTE proceso montó el store personal en modo `.icloud` (mirror ON)?
    /// Testigo de arranque (`personalStoreMountedMode`), NO lo persistido — análogo INVERSO de
    /// `isMirrorConfirmedOff`. CONTRATO I11-2 (machine doc): el default del testigo es `.icloud` → un read
    /// real reportaría "montado SIEMPRE" = false green → los tests FAKEAN esta observación (no usan el real).
    func isMirrorConfirmedOn() -> Bool {
        SwiftDataConfiguration.personalStoreMountedMode == .icloud
    }

    /// §h.3 `deletingZombies` — EL NÚCLEO. Enumera tombstones del backend en LECTURA PURA (`pullPage`, SIN
    /// applyPage/cursor/testigos), los agrupa por TABLA, y para cada tabla afectada BORRA en UN fetch + match
    /// en memoria las filas VIVAS que los porten (nunca un fetch por tombstone; reusa `EntityApplyMap`). El
    /// `save()` va bajo `outboxSaveAuthor` (AUTOR ANTI-ECO): el barrido ES un apply de tombstones del backend
    /// → sin él un `drainOnce` futuro re-emitiría los deletes como tombstones al backend congelado. El mirror
    /// exporta el delete igual (NSPersistentCloudKitContainer no filtra por autor; solo nuestro drain).
    /// Caso normal (token vigente): 0 filas vivas tombstoneadas → no-op idempotente. Red del pull → `.transient`.
    func sweepZombies(sinceSeq: Int64) async -> ZombieSweepOutcome {
        var tombstonesByTable: [String: Set<UUID>] = [:]
        var cursor = sinceSeq
        pageLoop: while true {
            switch await tombstoneSource.pullPage(since: cursor, limit: 500) {
            case let .page(page):
                for delta in page.deltas where delta.op == .tombstone {
                    tombstonesByTable[delta.entityType, default: []].insert(delta.syncID)
                }
                let next = max(page.maxServerSeq, cursor)
                if page.deltas.isEmpty || next <= cursor { break pageLoop }  // agotado / sin progreso
                cursor = next
            case .sessionExpired, .accountUnavailable, .transient:
                return .transient
            }
        }
        guard !tombstonesByTable.isEmpty else { return .completed(deleted: 0) }
        var totalDeleted = 0
        do {
            try engine.saveWithAuthor(context, CloudSyncEngine.outboxSaveAuthor) {
                for (table, ids) in tombstonesByTable {
                    totalDeleted += EntityApplyMap.deleteLiveRows(table: table, syncIDs: ids, context: context)
                }
            }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor.sweepZombies: save del barrido falló: \(error)")
            #endif
            return .transient
        }
        return .completed(deleted: totalDeleted)
    }

    /// §h.3 `rebindingUUIDs`: VERIFICACIÓN (v1, sin deletes — recordName≠UUID de dominio, S5: el rebind es un
    /// update de campo `CD_syncID` sobre el MISMO CKRecord que el replay del mirror exporta). Cuenta las
    /// identidades con `lastReboundAt != nil` cuya fila viva sigue portando su `syncID` (regla `899c1c25` ya
    /// reconstruyó los mirrors). Si una fila rebound NO existe viva, la cubre el barrido de zombies (tombstone).
    func verifyRebinds() -> Int {
        do {
            let rebound = try context.fetch(FetchDescriptor<SyncIdentity>()).filter { $0.lastReboundAt != nil }
            return rebound.reduce(0) { acc, row in
                EntityApplyMap.liveRowExists(entityTypeName: row.entityType, syncID: row.syncID, context: context)
                    ? acc + 1 : acc
            }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor.verifyRebinds: fetch(SyncIdentity) falló: \(error)")
            #endif
            return 0
        }
    }

    /// §h.3 `dedupHealed`: AUTO-CURA (I11-4) de copias idénticas de Account/Tag por identidad de contenido —
    /// el mismo detonante que duplicó subcategorías (regeneración masiva de `shortcutID`/`id`). Fusiona cada
    /// grupo duplicado en un ganador determinista, re-apunta las referencias del perdedor y lo borra
    /// (`AccountTagMergeService`, autor DEFECTO → el tombstone del perdedor viaja al backend/mirror). Devuelve
    /// el nº total de filas PERDEDORAS curadas. La quiescencia la GARANTIZÓ el runner (`dedupHealed` corre
    /// post-`awaitingQuiescence`). Idempotente: una 2ª pasada devuelve 0. I11-2 era DETECCIÓN read-only; I11-4
    /// promueve a cura (el sub-estado ya era journaled).
    func healDuplicates() -> Int {
        // `AccountTagMergeService` EXCLUYE `isSystemAccount` (mergearlas tocaría Grupos) y no cubre
        // subcategorías → el pase de política v1 las complementa por otra vía (cuentas `Grupos [moneda]` +
        // balanceAdjustment cross-idioma; autor DEFAULT → el tombstone viaja). Ambos son idempotentes.
        let system = CloudSyncReconciler.reconcileSystemEntities(context: context)
        return AccountTagMergeService.mergeDuplicateAccounts(in: context)
            + AccountTagMergeService.mergeDuplicateTags(in: context)
            + system.accountsMerged + system.subcategoriesMerged
    }

    /// §h `reverseUpload`: muestreo CKIdentityCapture sobre TODAS las filas vivas. `exportPending + noMetadata
    /// == 0` ⇒ `.drained` (`noMetadata` cuenta como pendiente: un insert del replay que el mirror aún no
    /// procesó); si no, `.pending(count)`. §h.6 pto 3: `capture` MUTA los testigos `.captured` con las
    /// coordenadas frescas — eso ES "los SyncIdentity se ACTUALIZAN durante reverseUpload" (una futura 2ª
    /// reversa ya es variante migrado con mapa poblado) → se PERSISTE (quiescencia garantizada por el runner).
    func reverseUploadStatus() -> ReverseUploadStatus {
        let pairs = collectIdentityPairs()
        let report = CKIdentityCapture.capture(pairs, storeURL: personalStoreURL)
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                #if DEBUG
                print("MigrationWorkExecutor.reverseUploadStatus: save de captura falló: \(error)")
                #endif
            }
        }
        // Canario v1 SIN reparación (§h residual): scan read-only de metadata HUÉRFANA (zombie por History
        // purgada). SOLO informativo — NO altera `.drained`/`.pending`. Abre una 2ª conexión SQLite read-only
        // (aceptable en la reversa; NO se refactoriza la conexión compartida en este incremento).
        let orphanReport = CKIdentityCapture.scanOrphanMetadata(
            liveByEntityName: Self.collectLiveByEntityName(context: context), storeURL: personalStoreURL)
        CloudSyncBreadcrumb.reverseOrphanMetadata(count: orphanReport.orphans)
        let pending = report.exportPending + report.noMetadata
        return pending == 0 ? .drained : .pending(count: pending)
    }

    /// `[entityName: Set<Z_PK vivos>]` de las 16 entidades sync para `CKIdentityCapture.scanOrphanMetadata`.
    /// CONTRATO (RP-4): las 16 keys SIEMPRE presentes (Set vacío si 0 filas vivas) — sin filas vivas de `Tag`,
    /// una metadata de Tag post-purga ES huérfana real y debe contarse; y metadata de entidades NO cableadas
    /// (p.ej. `CloudMigrationMarker`) se ignora por key AUSENTE. VIVOS = TODAS las filas vivas del store (NO se
    /// reusa `collectIdentityPairs`: ese empareja por testigo `SyncIdentity` y una fila viva sin syncID contaría
    /// como huérfana → falso positivo R6). `static` para que el panel DEBUG (I11-5) lo reuse.
    static func collectLiveByEntityName(context: ModelContext) -> [String: Set<Int64>] {
        var out: [String: Set<Int64>] = [:]
        addLiveRows(TransactionItem.self, into: &out, context: context)
        addLiveRows(InboxDraft.self, into: &out, context: context)
        addLiveRows(Category.self, into: &out, context: context)
        addLiveRows(FavoritePayment.self, into: &out, context: context)
        addLiveRows(MerchantMemory.self, into: &out, context: context)
        addLiveRows(ExchangeRate.self, into: &out, context: context)
        addLiveRows(Budget.self, into: &out, context: context)
        addLiveRows(ScheduledPayment.self, into: &out, context: context)
        addLiveRows(Account.self, into: &out, context: context)
        addLiveRows(Subcategory.self, into: &out, context: context)
        addLiveRows(Tag.self, into: &out, context: context)
        addLiveRows(NotificationItem.self, into: &out, context: context)
        addLiveRows(CashFlowPlan.self, into: &out, context: context)
        addLiveRows(CashFlowLine.self, into: &out, context: context)
        addLiveRows(CashFlowOverride.self, into: &out, context: context)
        addLiveRows(GroupBridgePreference.self, into: &out, context: context)
        return out
    }

    /// Fetch CONCRETO por tipo (regla `#Predicate`). La key es el nombre de entidad Core Data (= nombre de
    /// clase `@Model`) y SIEMPRE se inserta (Set vacío si 0 filas) para honrar el contrato de RP-4. El `Z_PK`
    /// se extrae del `PersistentIdentifier` (URI → parse), consistente con el camino de captura.
    private static func addLiveRows<M: PersistentModel>(
        _ type: M.Type, into out: inout [String: Set<Int64>], context: ModelContext
    ) {
        let name = String(describing: M.self)
        var set = out[name] ?? []
        do {
            for model in try context.fetch(FetchDescriptor<M>()) {
                if let zpk = CKIdentityCapture.entityAndPK(for: model.persistentModelID)?.zpk {
                    set.insert(zpk)
                }
            }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor.collectLiveByEntityName: fetch(\(M.self)) falló: \(error)")
            #endif
        }
        out[name] = set  // key SIEMPRE presente (contrato RP-4)
    }

    // MARK: - Heartbeat del lease (I14-pre, residual pendiente #3)

    /// `migration_progress('heartbeat')` — refresca `profiles.migration_updated_at` (lease de 60 min) MIENTRAS
    /// un paso largo progresa (upload de corpus grande; drain de la reversa sobre una época nube grande) para
    /// que el líder NO quede usurpable a mitad de trabajo. Sirve a la ida Y a la reversa (una sola acción; el
    /// RPC decide por `migration_in_progress OR reverse_in_progress`, guard SIN edad de lease — el mismo líder
    /// lento siempre puede latir).
    ///
    /// BEST-EFFORT ABSOLUTO — la firma NO lanza (garantía de compilador) y NUNCA altera el outcome del paso
    /// que lo invoca: esa propiedad es lo que hace SEGURO commitear el cliente ANTES de desplegar la acción al
    /// RPC (pre-deploy el Worker devuelve 400/el RPC no la entiende → breadcrumb y sigue). Un `other_leader`
    /// aquí NO corta el paso: el guard REAL del lease vive en cutover/freeze/complete (cortar aquí duplicaría
    /// la lógica de usurpación con una señal débil).
    ///
    /// Throttle: el runner llama por-página, pero solo se emite a lo sumo un request por `heartbeatInterval`.
    /// El throttle se arma para CUALQUIER outcome (incluida red caída) — evita martillar el endpoint cuando el
    /// server rechaza o no responde.
    func sendLeaseHeartbeatIfDue() async {
        if let last = lastHeartbeatAt, now().timeIntervalSince(last) < heartbeatInterval { return }
        // Sin JWT → sin request (ni arma el throttle): el paso que sigue reportará sessionExpired por su
        // propio camino; un re-login despierta el heartbeat en el próximo tick.
        guard let jwt = await session.accessToken(), !jwt.isEmpty else { return }
        lastHeartbeatAt = now()
        switch await accountClient.migrationProgress(jwt: jwt, deviceID: deviceID, action: "heartbeat") {
        case .ok:
            CloudSyncBreadcrumb.migrationLeaseHeartbeat()
        case .otherLeader:
            CloudSyncBreadcrumb.migrationLeaseHeartbeatRejected(reason: "otherLeader")
        case .rejected(let reason):
            CloudSyncBreadcrumb.migrationLeaseHeartbeatRejected(reason: reason)
        case .sessionExpired:
            CloudSyncBreadcrumb.migrationLeaseHeartbeatRejected(reason: "sessionExpired")
        case .transient:
            CloudSyncBreadcrumb.migrationLeaseHeartbeatRejected(reason: "transient")
        }
    }

    // MARK: - Adopt-reconcile (DIFERIDOS #30, mecanismo v1 DARK)

    /// Rescata al backend las filas HUÉRFANAS de la ventana de cutover (identidad local ∉ backend) cuando un
    /// 2º device del mismo Apple ID adopta (`.icloud`→`.cloud`). Cierra el hueco multi-device de §g.4 que
    /// `runLeaderReconcileFromFrozenCloudKit` dejaba explícito: el device que ESCRIBIÓ la fila la ve barato
    /// (está en su store local) y la sube por `/sync/push`; sin ella, TODO adopt con writes de ventana termina
    /// en divergencia Merkle local-ahead PERPETUA (autoridad backend→local en el pull).
    ///
    /// **CONTRATO I14** (el flujo de adopt COMPLETO — §k.4 — es I14; este método es su seam): I14 DEBE
    /// (i) correr este método tras la QUIESCENCIA del import CloudKit y ANTES de arrancar el runtime de sync,
    /// (ii) hacer FAST-FORWARD del History baseline (molde `fastForwardHistoryBaseline` de w4) ANTES de
    /// habilitar el drain del runtime — sin (ii), el primer drain del adoptador re-emitiría el corpus ENTERO
    /// importado de CloudKit como deltas. Este método NO drena la History (emite las huérfanas por el seam
    /// `enqueueSnapshotRows` full-row, no por captura) → es SEGURO respecto al eco del corpus por construcción;
    /// el punto (ii) protege al RUNTIME posterior, no a este método. Y (iii) tras el reconcile, garantizar un
    /// pull con `runPostPullReconcilers` (`SystemEntityMergePolicy`): una ENTIDAD DE SISTEMA huérfana que este
    /// diff suba legítimamente puede duplicar server-side la acuñada por el líder (identidad distinta,
    /// contenido lógico idéntico) — el merge determinista-global del pull la cura (residual (c) de abajo).
    ///
    /// **Completitud de la enumeración VERIFICADA POSITIVAMENTE (SERIO 1 del review):** el set del backend se
    /// cruza contra los counts de filas VIVAS por tabla de `/sync/merkle` (cero endpoints nuevos). Una
    /// enumeración PARCIAL sin error (página vacía prematura / `maxServerSeq` no-monótono con 200 OK) haría
    /// lucir huérfanas filas que el backend SÍ tiene → su re-upload con HLC fresco PISARÍA contenido más nuevo
    /// (riesgo INVERTIDO respecto a `sweepZombies`, donde un set parcial solo encoge el barrido = benigno).
    /// merkle.count > enumerado → `.transient` retomable (sesgo a abortar, jamás a proceder; un push
    /// concurrente entre enumeración y merkle da un spurious-abort conservador — mismo espíritu que
    /// `newDeltaDetected` del verify). El sentido inverso (enumerado > merkle) PASA: deletes concurrentes
    /// solo encogen el diff.
    ///
    /// **Residuales v1** (documentados, DIFERIDOS #30): (a) un device que JAMÁS adopta deja su fila huérfana en
    /// el CloudKit congelado (auto-bloqueado por `secondaryDeviceCloudLogin`; sin pérdida física, rescatable por
    /// una adopción tardía — el diff no caduca; candidato v2 = opción C, lectura directa del CloudKit congelado);
    /// (b) los BORRADOS de la ventana no se propagan (el pull del adopt re-materializa la fila = resurrección
    /// benigna; el diff inverso backend∉local tombstonearía filas reales bajo import-lag → asimetría de riesgo
    /// inaceptable); (c) import-lag = una fila PRE-cutover cuyo `CD_syncID` aún no llegó luce nil → identidad
    /// fresca → DUPLICADO content-idéntico curable (clase I11-4; para system entities cura `SystemEntityMergePolicy`);
    /// mitigado por la PRECONDICIÓN (i) de correr solo tras quiescencia del import.
    ///
    /// Idempotente/retomable: red → `.transient` sin marcar nada; una 2ª pasada re-diffea (lo aplicado sale
    /// del diff → `completed(0, 0)`).
    func runAdoptOrphanReconcile() async -> AdoptReconcileOutcome {
        // Paso 1: enumerar el set de identidades del backend (upserts + tombstones) — read-only, idiom
        // `sweepZombies` (SIN applyPage, SIN avance de `SyncCursor`, SIN tocar testigos). Red → `.transient`.
        guard let enumeration = await enumerateBackendSyncIDs() else { return .transient }
        // Verificación POSITIVA de completitud contra los counts del Merkle (SERIO 1 — ver doc del método).
        // El merkle se consulta DESPUÉS de la enumeración: sesgo a abortar, jamás a proceder.
        guard await verifyEnumerationComplete(enumeration) else { return .transient }
        let backendSyncIDs = enumeration.known

        // Guard anti mass-upload ANTES de toda mutación (MENOR 2 del review): diff PRELIMINAR pre-backfill.
        // Backend enumerado VACÍO + (huérfanas ∨ filas sin identidad) = página espuria/bug/cuenta equivocada;
        // el costo del falso positivo sería subir el corpus entero → `abortedEmptyBackend` SIN mutar nada
        // (el backfill de abajo NO corre). NOTA: un backend REALMENTE vacío (merkle en 0s pasa la completitud)
        // sigue abortando A PROPÓSITO — un adopt legítimo (`existing_stable`) implica backend poblado; mergear
        // un local poblado contra una cuenta nube VACÍA es decisión de producto de I14, no de esta pieza.
        // Residual documentado: un líder con corpus 0 filas + huérfana real del 2º device queda excluido de la
        // auto-cura (sin datos en riesgo).
        let prePlan = AdoptOrphanDiff.compute(inventory: collectAdoptInventory(), backendSyncIDs: backendSyncIDs)
        if backendSyncIDs.isEmpty && (prePlan.uploadCount > 0 || prePlan.identityCount > 0) {
            CloudSyncBreadcrumb.adoptReconcileAbortedEmptyBackend(orphans: prePlan.uploadCount + prePlan.identityCount)
            return .abortedEmptyBackend
        }

        // Paso 2 (identityAssigned): en el adoptador la tabla de testigos arranca vacía → cada fila SIN
        // identidad recibe UUID FRESCO (rebind no-op) y CAE a huérfana (un UUID fresco jamás está en el
        // backend). El conteo sale del plan preliminar; el backfill las materializa (syncID + testigo
        // SyncIdentity). El eco del drain lo previene el contrato de baseline de I14 (punto ii) — igual que
        // en el líder.
        let identityAssigned = prePlan.identityCount
        SyncIdentityService.backfillIdentities(context: context, now: now())

        // Pasos 3-4: inventario local POST-backfill (sin nils) → diff definitivo.
        let inventory = collectAdoptInventory()
        let plan = AdoptOrphanDiff.compute(inventory: inventory, backendSyncIDs: backendSyncIDs)
        guard !plan.orphans.isEmpty else { return .completed(uploaded: 0, identityAssigned: identityAssigned) }

        // Paso 6: fetch dirigido de EXACTAMENTE las huérfanas del plan → emisión fila-COMPLETA por el seam del
        // snapshot (reusa `MigrationSnapshotUploader.makeSnapshotRowInput` — misma emisión DeltaEmitter→codec).
        let inputs = buildOrphanRowInputs(plan.orphans)
        do {
            try engine.enqueueSnapshotRows(inputs, context: context, now: now())
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor.runAdoptOrphanReconcile: enqueueSnapshotRows lanzó (drift): \(error)")
            #endif
            return .transient
        }
        // Push con el idiom EXACTO del leader-reconcile: liveOutboxRows + partitionBuildable + deadLetterPoison
        // + push + applyResults. NO se drena la History (las huérfanas ya están en el outbox por el enqueue;
        // drenar re-emitiría el corpus importado — ver contrato).
        let residual = liveOutboxRows()
        let (buildable, poison) = pushClient.partitionBuildable(residual)
        engine.deadLetterPoison(poison, context: context, now: now())
        guard !buildable.isEmpty else { return .completed(uploaded: 0, identityAssigned: identityAssigned) }
        guard case .completed(let results) = await pushClient.push(buildable) else { return .transient }
        await pushClient.applyResults(results, rows: buildable, engine: engine, context: context)
        let uploaded = results.filter { $0.status == .applied }.count

        // Paso 7: canario (espejo del par del líder). `identityAssigned` viaja en el breadcrumb (sin PII).
        if uploaded > 0 {
            CloudSyncBreadcrumb.adoptOrphanReconciled(count: uploaded, identityAssigned: identityAssigned)
            TelemetryService.cloudAdoptOrphanReconciled(count: uploaded)
        }
        return .completed(uploaded: uploaded, identityAssigned: identityAssigned)
    }

    /// DRY-RUN read-only (panel DEBUG, §3.4): pasos 1,3,4 SIN backfill (paso 2) NI upload (paso 6). Enumera el
    /// backend (MISMO camino verificado contra merkle que el reconcile — SERIO 1), inventario local (con nils
    /// visibles — sin backfill materializa `needsIdentity` por tabla) y diffea. NO muta nada (molde
    /// `scanOrphanMetadata`/`computeDryRun`). `nil` = red (transient) al enumerar O enumeración incompleta.
    func adoptOrphanDryRun() async -> AdoptOrphanDiff.Plan? {
        guard let enumeration = await enumerateBackendSyncIDs() else { return nil }
        guard await verifyEnumerationComplete(enumeration) else { return nil }
        return AdoptOrphanDiff.compute(inventory: collectAdoptInventory(), backendSyncIDs: enumeration.known)
    }

    /// Enumeración del backend: `known` = TODAS las identidades (upserts Y tombstones — para el diff);
    /// `liveByTable` = solo las VIVAS por tabla (para cruzar contra los counts del Merkle, SERIO 1).
    private struct BackendEnumeration {
        let known: Set<UUID>
        let liveByTable: [String: Set<UUID>]
    }

    /// Enumera TODAS las identidades que el backend conoce (upserts Y tombstones) por páginas read-only (idiom
    /// `sweepZombies`). `nil` = red (transient). El loop copia el shape de `sweepZombies`: cursor, high-water,
    /// break si página vacía o sin progreso.
    private func enumerateBackendSyncIDs() async -> BackendEnumeration? {
        var known: Set<UUID> = []
        var liveByTable: [String: Set<UUID>] = [:]
        var cursor: Int64 = 0
        while true {
            switch await tombstoneSource.pullPage(since: cursor, limit: 500) {
            case let .page(page):
                for delta in page.deltas {
                    known.insert(delta.syncID)
                    if delta.op == .tombstone {
                        // El wire es materialized-rows (cada fila aparece con su ESTADO final), pero el
                        // remove es defensivo por si un upsert previo de la misma identidad ya la contó viva.
                        liveByTable[delta.entityType]?.remove(delta.syncID)
                    } else {
                        liveByTable[delta.entityType, default: []].insert(delta.syncID)
                    }
                }
                let next = max(page.maxServerSeq, cursor)
                if page.deltas.isEmpty || next <= cursor {   // agotado / sin progreso
                    return BackendEnumeration(known: known, liveByTable: liveByTable)
                }
                cursor = next
            case .sessionExpired, .accountUnavailable, .transient:
                return nil
            }
        }
    }

    /// SERIO 1 del review: verificación POSITIVA de completitud de la enumeración contra los counts de filas
    /// VIVAS por tabla de `/sync/merkle` (cero endpoints nuevos — `RemoteMerkle.entities` ya los trae). Para
    /// cada tabla del merkle: `count > enumerado` → enumeración INCOMPLETA (página vacía prematura /
    /// paginación no-monótona con 200 OK) → breadcrumb + `false` (el llamador devuelve `.transient`
    /// retomable). El sentido inverso (enumerado > merkle) PASA: deletes concurrentes solo encogen el diff =
    /// conservador. Cualquier outcome no-snapshot del fetch → `false` (transient).
    private func verifyEnumerationComplete(_ enumeration: BackendEnumeration) async -> Bool {
        guard case .snapshot(let merkle) = await merkleClient.fetchMerkle() else { return false }
        for (table, entity) in merkle.entities {
            let got = enumeration.liveByTable[table]?.count ?? 0
            if entity.count > got {
                CloudSyncBreadcrumb.adoptReconcileEnumerationIncomplete(
                    table: table, expected: entity.count, got: got)
                return false
            }
        }
        return true
    }

    /// Inventario `(table, syncID?)` de TODAS las filas VIVAS de las 16 entidades (manifest I12), por los
    /// accessors de identidad existentes. La `table` es el nombre Postgres (`EntityEmission.table`), la clave
    /// del diff contra `PulledDelta.entityType`. Fetch CONCRETO por tipo (regla `#Predicate`).
    private func collectAdoptInventory() -> [(table: String, syncID: UUID?)] {
        var out: [(table: String, syncID: UUID?)] = []
        addAdoptInventory(TransactionItem.self, emission: EntityEmissionMap.transactionItem, identity: { $0.syncID }, into: &out)
        addAdoptInventory(InboxDraft.self, emission: EntityEmissionMap.inboxDraft, identity: { $0.syncID }, into: &out)
        addAdoptInventory(Category.self, emission: EntityEmissionMap.category, identity: { $0.syncID }, into: &out)
        addAdoptInventory(FavoritePayment.self, emission: EntityEmissionMap.favoritePayment, identity: { $0.syncID }, into: &out)
        addAdoptInventory(MerchantMemory.self, emission: EntityEmissionMap.merchantMemory, identity: { $0.syncID }, into: &out)
        addAdoptInventory(ExchangeRate.self, emission: EntityEmissionMap.exchangeRate, identity: { $0.syncID }, into: &out)
        addAdoptInventory(Budget.self, emission: EntityEmissionMap.budget, identity: { $0.id }, into: &out)
        addAdoptInventory(ScheduledPayment.self, emission: EntityEmissionMap.scheduledPayment, identity: { $0.id }, into: &out)
        addAdoptInventory(Account.self, emission: EntityEmissionMap.account, identity: { $0.shortcutID }, into: &out)
        addAdoptInventory(Subcategory.self, emission: EntityEmissionMap.subcategory, identity: { $0.shortcutID }, into: &out)
        addAdoptInventory(Tag.self, emission: EntityEmissionMap.tag, identity: { $0.id }, into: &out)
        addAdoptInventory(NotificationItem.self, emission: EntityEmissionMap.notificationItem, identity: { $0.id }, into: &out)
        addAdoptInventory(CashFlowPlan.self, emission: EntityEmissionMap.cashFlowPlan, identity: { $0.id }, into: &out)
        addAdoptInventory(CashFlowLine.self, emission: EntityEmissionMap.cashFlowLine, identity: { $0.id }, into: &out)
        addAdoptInventory(CashFlowOverride.self, emission: EntityEmissionMap.cashFlowOverride, identity: { $0.id }, into: &out)
        addAdoptInventory(GroupBridgePreference.self, emission: EntityEmissionMap.groupBridgePreference, identity: { $0.id }, into: &out)
        return out
    }

    private func addAdoptInventory<M: PersistentModel>(
        _ type: M.Type, emission: EntityEmission<M>, identity: (M) -> UUID?,
        into out: inout [(table: String, syncID: UUID?)]
    ) {
        do {
            for model in try context.fetch(FetchDescriptor<M>()) {
                out.append((emission.table, identity(model)))
            }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor.collectAdoptInventory: fetch(\(M.self)) falló: \(error)")
            #endif
        }
    }

    /// Construye los `SnapshotRowInput` full-row de EXACTAMENTE las filas huérfanas del plan (fetch dirigido +
    /// filtro por el set de identidades objetivo, por tabla). Reusa el builder per-row del uploader (misma
    /// emisión). Fetch CONCRETO por tipo (regla `#Predicate`).
    private func buildOrphanRowInputs(_ orphans: [String: [UUID]]) -> [SnapshotRowInput] {
        var inputs: [SnapshotRowInput] = []
        addOrphanInputs(TransactionItem.self, emission: EntityEmissionMap.transactionItem, className: SyncEntityType.transactionItem, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        addOrphanInputs(InboxDraft.self, emission: EntityEmissionMap.inboxDraft, className: SyncEntityType.inboxDraft, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        addOrphanInputs(Category.self, emission: EntityEmissionMap.category, className: SyncEntityType.category, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        addOrphanInputs(FavoritePayment.self, emission: EntityEmissionMap.favoritePayment, className: SyncEntityType.favoritePayment, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        addOrphanInputs(MerchantMemory.self, emission: EntityEmissionMap.merchantMemory, className: SyncEntityType.merchantMemory, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        addOrphanInputs(ExchangeRate.self, emission: EntityEmissionMap.exchangeRate, className: SyncEntityType.exchangeRate, identity: { $0.syncID }, orphans: orphans, into: &inputs)
        addOrphanInputs(Budget.self, emission: EntityEmissionMap.budget, className: SyncEntityType.budget, identity: { $0.id }, orphans: orphans, into: &inputs)
        addOrphanInputs(ScheduledPayment.self, emission: EntityEmissionMap.scheduledPayment, className: SyncEntityType.scheduledPayment, identity: { $0.id }, orphans: orphans, into: &inputs)
        addOrphanInputs(Account.self, emission: EntityEmissionMap.account, className: SyncEntityType.account, identity: { $0.shortcutID }, orphans: orphans, into: &inputs)
        addOrphanInputs(Subcategory.self, emission: EntityEmissionMap.subcategory, className: SyncEntityType.subcategory, identity: { $0.shortcutID }, orphans: orphans, into: &inputs)
        addOrphanInputs(Tag.self, emission: EntityEmissionMap.tag, className: SyncEntityType.tag, identity: { $0.id }, orphans: orphans, into: &inputs)
        addOrphanInputs(NotificationItem.self, emission: EntityEmissionMap.notificationItem, className: SyncEntityType.notificationItem, identity: { $0.id }, orphans: orphans, into: &inputs)
        addOrphanInputs(CashFlowPlan.self, emission: EntityEmissionMap.cashFlowPlan, className: SyncEntityType.cashFlowPlan, identity: { $0.id }, orphans: orphans, into: &inputs)
        addOrphanInputs(CashFlowLine.self, emission: EntityEmissionMap.cashFlowLine, className: SyncEntityType.cashFlowLine, identity: { $0.id }, orphans: orphans, into: &inputs)
        addOrphanInputs(CashFlowOverride.self, emission: EntityEmissionMap.cashFlowOverride, className: SyncEntityType.cashFlowOverride, identity: { $0.id }, orphans: orphans, into: &inputs)
        addOrphanInputs(GroupBridgePreference.self, emission: EntityEmissionMap.groupBridgePreference, className: SyncEntityType.groupBridgePreference, identity: { $0.id }, orphans: orphans, into: &inputs)
        return inputs
    }

    private func addOrphanInputs<M: PersistentModel>(
        _ type: M.Type, emission: EntityEmission<M>, className: String, identity: (M) -> UUID?,
        orphans: [String: [UUID]], into inputs: inout [SnapshotRowInput]
    ) {
        guard let ids = orphans[emission.table], !ids.isEmpty else { return }
        let targetSet = Set(ids)
        do {
            for model in try context.fetch(FetchDescriptor<M>()) {
                guard let sid = identity(model), targetSet.contains(sid) else { continue }
                inputs.append(MigrationSnapshotUploader.makeSnapshotRowInput(
                    model: model, syncID: sid, emission: emission, className: className, calendar: calendar))
            }
        } catch {
            #if DEBUG
            print("MigrationWorkExecutor.buildOrphanRowInputs: fetch(\(M.self)) falló: \(error)")
            #endif
        }
    }
}
