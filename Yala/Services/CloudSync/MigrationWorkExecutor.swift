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

// MARK: - ReverseTombstoneSource (§h.3, I11-2)

/// Fuente de tombstones del backend para el barrido de zombies de la reversa (§h.3). Enumeración de LECTURA
/// PURA: NO aplica (`applyPage`), NO avanza `SyncCursor`, NO toca testigos `SyncIdentity` — el apply normal
/// BORRA el testigo al aplicar un tombstone y aquí NO queremos ese side-effect. Default = wrapper del
/// `pullClient`; los tests la fakean para el golden §h.5 (no se protocoliza `SyncPullClient` entero).
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
            // PROPIO device que la escribió por su camino de migración/adopt (I11). RESIDUAL EXPLÍCITO
            // de I11: un device que escribió post-cutover y JAMÁS adopta deja esa fila huérfana en
            // CloudKit congelado — registrar en el gate de encendido de flags (cruza con #29/#30).
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
    /// ENFORCEMENT del freeze en `/sync/push` (rechazar pushes con `reverse_frozen_at` set) está DIFERIDO
    /// al gate de encendido de flags — v1 single-device DARK (ver qa/cloud/README.md). NUNCA lanza.
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
        AccountTagMergeService.mergeDuplicateAccounts(in: context)
            + AccountTagMergeService.mergeDuplicateTags(in: context)
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
        let pending = report.exportPending + report.noMetadata
        return pending == 0 ? .drained : .pending(count: pending)
    }
}
