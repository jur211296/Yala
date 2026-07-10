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
//  BACKSTOP `reconcileFromFrozenCloudKit` (capa de RED) y `rollback`/`adoptBackendAccount` (I11/§k.4)
//  siguen `notWired` (el runner los deja journaled, retomable).
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
        snapshotPageSize: Int = 200
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
    }

    // MARK: - Claim (§f.1)

    /// `POST /account/claim` con el JWT vigente + el `device_id` del dispositivo + `provider`. Sin JWT →
    /// `.sessionExpired` (el runner corta SIN evento, retomable; un re-login lo despierta). NUNCA lanza.
    func performClaim() async -> ClaimOutcome {
        guard let jwt = await session.accessToken(), !jwt.isEmpty else {
            return .sessionExpired(detail: "no access token")
        }
        return await accountClient.claim(jwt: jwt, deviceID: deviceID, provider: provider)
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
    /// `.runLeaderReconcileFromFrozenCloudKit`. `.rollback`/`.adoptBackendAccount` → `notWired` (I11/§k.4,
    /// fuera de este ciclo; el runner los deja journaled retomable).
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
            // `migration_progress('complete')` (líder). La capa PRIMARIA (captura por History desde
            // localModeSet) ya está activa; el BACKSTOP `reconcileFromFrozenCloudKit` (capa de RED) llega
            // en w8 (residual documentado — DEBE existir antes de migrar usuarios reales).
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

        case .rollback, .adoptBackendAccount:
            CloudSyncBreadcrumb.migrationExecutorNotWired(step: effect.rawValue)
            throw MigrationExecutorError.notWired(effect: effect.rawValue)
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
}
