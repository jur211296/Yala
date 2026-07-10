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

        // Reversa (§h) — DARK en I11-1: la máquina/journal ya modelan los efectos pero el executor NO los
        // cablea. I11-2/3 los implementan (mountMirrorAndRelaunch cruza el process boundary como
        // disableMirrorAndRelaunch; el cuarteto de cierre borra marker+beacon, persiste .icloud y cierra
        // el server). El runner los deja journaled → retomable. CONTRATO I11-2: la observación
        // `reverseMirrorMounted` (análoga a `isMirrorConfirmedOff`) debe ser inyectable/fake-able en tests.
        case .reverseRollback, .mountMirrorAndRelaunch, .deleteCloudKitMarker,
             .clearCloudBeacon, .persistICloudMode, .completeReverseServer:
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
