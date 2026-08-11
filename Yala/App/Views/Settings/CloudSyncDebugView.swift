//
//  CloudSyncDebugView.swift
//  Yala
//
//  Panel de diagnóstico del Modo Nube — SOLO `DEV_BUILD` (tooling interno). Vehículo del e2e de device
//  del I7c (primer `signInWithIdToken` real contra staging) y semilla del A2 del roadmap.
//
//  ALCANCE EXPLÍCITO: Sign in with Apple · Claim account · Sign out. NO incluye "run sync cycle" — un
//  ciclo sobre el `mainContext` real subiría/drenaría datos reales del owner a staging y asignaría
//  syncIDs al store de producción; eso es el dogfooding de I10, no I7c.
//
//  Strings HARDCODED a propósito: es tooling `DEV_BUILD`, NO copy de usuario → fuera del pipeline de
//  l10n (no hay keys que mantener en 16 locales). Reglas UI del repo igualmente respetadas: DS tokens,
//  `.yalaScreenBackground(.subtle)` (stack de Settings), Button + contentShape.
//

#if DEV_BUILD
import DeviceCheck
import SwiftData
import SwiftUI
import UIKit

@MainActor
@Observable
final class CloudSyncDebugModel {
    var isWorking = false
    var lastMessage: String?
    var lastClaimState: String?
    var attestStatus: String?
    var credentialStatus: String?

    private let auth = CloudAuthService.shared
    /// SIN `attestProvider` a propósito: el único método que usa es `claim` → `POST /account/claim`, que
    /// va por `requireUser` (`gateway/src/sync/account.ts:68`) y NO exige App Attest.
    private let accountClient = CloudAccountClient()

    var isConfigured: Bool { CloudBackendConfig.isConfigured }
    var configLabel: String {
        guard let url = CloudBackendConfig.supabaseURL else { return "unconfigured" }
        return "staging · \(url.host ?? url.absoluteString)"
    }
    var sessionLabel: String {
        guard let sub = auth.currentUserID else { return "signed out" }
        let short = String(sub.prefix(8))
        if let expiry = auth.sessionExpiry {
            return "user \(short)… · exp \(expiry.formatted(date: .omitted, time: .standard))"
        }
        return "user \(short)…"
    }
    var attestSupportedLabel: String {
        DCAppAttestService.shared.isSupported ? "supported" : "unsupported (sim → dev bypass)"
    }

    func signIn() async {
        isWorking = true; defer { isWorking = false }
        do {
            try await auth.signInWithApple()
            lastMessage = "Sign in OK — \(sessionLabel)"
        } catch {
            lastMessage = "Sign in failed: \(error.localizedDescription)"
        }
        await refreshCredential()
    }

    func signInGoogle() async {
        isWorking = true; defer { isWorking = false }
        do {
            try await auth.signInWithGoogle()
            lastMessage = "Sign in (Google) OK — \(sessionLabel)"
        } catch {
            lastMessage = "Google sign in failed: \(error.localizedDescription)"
        }
        await refreshCredential()
    }

    func claim() async {
        isWorking = true; defer { isWorking = false }
        guard let jwt = await auth.accessToken() else {
            lastMessage = "Claim skipped: no session (sign in first)"
            return
        }
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "yala-debug-device"
        // Provider REAL de la sesión. RESIDUAL (ajuste #5): el fallback `?? "apple"` solo aplica si
        // la key se perdió (población ~0 — se escribe en el mismo sign-in); una sesión Google con
        // key perdida claimearía "apple". Preferible a fallar el claim del panel. OJO (review
        // adversarial #4): en rama `created` el fallback queda VERBATIM en `profiles.provider`
        // server-side → la red post-claim de R9 (sesión 2: `existing_stable.profile.provider` vs
        // provider real) daría falso mismatch PERPETUO para ese usuario. Pre-flags y población ~0.
        let provider = auth.storedProvider() ?? "apple"
        let outcome = await accountClient.claim(jwt: jwt, deviceID: deviceID, provider: provider)
        switch outcome {
        case .success(let state):
            lastClaimState = "\(state)"
            lastMessage = "Claim OK → \(state)"
        case .sessionExpired(let detail):
            lastMessage = "Claim 401 (re-sign): \(detail)"
        case .accountUnavailable(let detail):
            lastMessage = "Claim 403: \(detail)"
        case .transient(let detail):
            lastMessage = "Claim transient: \(detail)"
        }
    }

    func signOut() async {
        isWorking = true; defer { isWorking = false }
        await auth.signOut()
        lastClaimState = nil
        lastMessage = "Signed out — \(sessionLabel)"
        await refreshCredential()
    }

    func refreshAttest() async {
        isWorking = true; defer { isWorking = false }
        do {
            // `ignoringBackoff`: el trabajo de este botón es intentarlo AHORA. Con la caché negativa
            // por defecto, un fallo de hace 40 s se re-lanzaría sin tocar la red y el panel reportaría
            // un error viejo como si fuera de este intento — la respuesta falsa más cara posible en el
            // único sitio desde el que se diagnostica attest en device.
            _ = try await AppAttestClient.shared.currentSessionToken(ignoringBackoff: true)
            attestStatus = "token OK"
        } catch {
            attestStatus = "token failed: \(error)"
        }
    }

    /// Estado de la credencial de Apple (mitigación #23) — visible en el e2e del owner. En sim el
    /// query puede fallar (SIWA es device-only); el label lo refleja sin romper nada.
    func refreshCredential() async {
        credentialStatus = await auth.credentialStateDescription() ?? "no apple user captured"
    }

    // MARK: - Push (spike G0 Grupos→backend)

    /// Token APNs capturado por `YalaAppDelegate` (key DEBUG-only; en device real por Xcode).
    var deviceTokenHex: String? {
        UserDefaults.standard.string(forKey: YalaAppDelegate.debugDeviceTokenKey)
    }

    /// Llama `/v1/debug/push` del gateway staging. URLRequest inline A PROPÓSITO: es tooling
    /// DEV_BUILD de un solo endpoint — NO sienta precedente para código de producción (el
    /// registro real de tokens es G8 y tendrá su cliente propio).
    func sendTestPush() async {
        guard let token = deviceTokenHex else {
            lastMessage = "Push: sin device token (corre en device real para registrarlo)"
            return
        }
        let secret = ProxyConfig.devSharedSecret
        guard !secret.isEmpty else {
            lastMessage = "Push: define YALA_DEV_SHARED_SECRET en el scheme (Xcode) o usa curl con el token copiado"
            return
        }
        isWorking = true; defer { isWorking = false }
        var request = URLRequest(url: ProxyConfig.baseURL.appending(path: "v1/debug/push"))
        request.httpMethod = "POST"
        request.setValue(secret, forHTTPHeaderField: "X-Yala-Dev-Secret")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: ["deviceToken": token, "sandbox": true])
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "<binario>"
            lastMessage = "Push → HTTP \(status): \(body)"
        } catch {
            lastMessage = "Push: request falló — \(error.localizedDescription)"
        }
    }
}

// MARK: - Migración I10 (panel DEBUG A2 §m.6)

/// Conduce el `MigrationRunner` REAL (staging) sobre el `mainContext` + refleja el journal vivo. DEV_BUILD.
/// JAMÁS ofrece "forzar done" — el único atajo de salida es el escape hatch (storageMode=.icloud + limpiar
/// journal) mientras no exista la reversa (I11).
@MainActor
@Observable
final class CloudSyncMigrationPanelModel {
    var isWorking = false
    var lastMessage: String?

    // Snapshot del estado vivo.
    var phaseLabel = "—"
    var pendingEffectsLabel = "—"
    var countersLabel = "—"
    var cursorLabel = "—"
    var startedAtLabel = "—"
    /// C-1: reloj del tope del paso 4 (elapsed desde el sello) y veredicto del canal iCloud journaleado —
    /// para que el device-QA vea POR QUÉ el cutover espera y cuánto lleva esperando.
    var markerClockLabel = "—"
    var icloudVerdictLabel = "—"
    var outboxDiagLabel = "—"
    var quiescent = false
    var mountedModeLabel = "—"
    var persistedModeLabel = "—"
    var relaunchRequested = false
    var dryRunSummary: String?

    // Reversa I11 (I11-5): veredicto del guardarraíl + origin journaleado. `reverseEligible` gatea el botón
    // "Iniciar REVERSA" (gate DURO pre-diálogo, obligaciones 1-2 del review I11-1).
    var reverseEligibilityLabel = "—"
    var reverseOriginLabel = "—"
    var reverseEligible = false
    var orphanScanLabel = "—"
    var adoptDiffLabel = "—"
    var rebindsLabel = "—"

    private let context: ModelContext
    private var runner: MigrationRunner?
    private let deviceID = MigrationWorkExecutor.vendorDeviceID

    init(context: ModelContext) {
        self.context = context
    }

    /// Construye el executor REAL (staging) vía el factory COMPARTIDO con producción (I14 P2) — para el
    /// dry-run de huérfanas del adopt (#30), read-only.
    private func makeExecutor() -> MigrationWorkExecutor {
        CloudMigrationController.makeExecutor(context: context, deviceID: deviceID)
    }

    /// El runner de producción (I14 P2): consume el runner ÚNICO de `CloudMigrationController` — evita DOS
    /// runners vivos sobre el mismo journal single-row (doble ejecución de efectos). Fallback local solo si
    /// el controller aún no se configuró — improbable en DEV_BUILD: `isConfigured` es `true` ahí, así que
    /// solo pasaría si el paso 14.6 del bootstrap no hubiera corrido todavía.
    private func makeRunner() -> MigrationRunner {
        if let shared = CloudMigrationController.shared { return shared.runner }
        if let runner { return runner }
        let r = MigrationRunner(
            context: context, executor: makeExecutor(), deviceID: deviceID,
            quiescenceSignal: { iCloudSyncService.shared.isImportQuiescent })
        runner = r
        return r
    }

    // MARK: - Acciones (todas idempotentes; ninguna fuerza `done`)

    func simulate() async {
        isWorking = true; defer { isWorking = false }
        await makeRunner().startMigration(dryRun: true)
        lastMessage = "Simulación (dry-run) enviada — el journal NO cambia de forma durable"
        refresh()
    }

    func startReal() async {
        isWorking = true; defer { isWorking = false }
        await makeRunner().startMigration(dryRun: false)
        lastMessage = "Migración REAL iniciada — persiste storageMode=.cloud al llegar al cutover"
        refresh()
    }

    /// Avanza `consent` → `authenticating` → `claimingMigration` (los 2 eventos de UI que la máquina §g
    /// espera y que la UI real de migración — I14 — emitirá). En el panel DEBUG el sign-in ya ocurrió
    /// (I7c) → `signInSucceeded` es confirmatorio; tras él la máquina drive-a sola hasta el cutover.
    func acceptConsentAndSignIn() async {
        isWorking = true; defer { isWorking = false }
        let r = makeRunner()
        await r.submit(.consentAccepted)     // consent → authenticating
        await r.submit(.signInSucceeded)     // authenticating → claimingMigration → drive autónomo
        lastMessage = "consent aceptado + sign-in → la máquina avanza a claimingMigration y sigue sola"
        refresh()
    }

    func resume() async {
        isWorking = true; defer { isWorking = false }
        await makeRunner().resume()
        lastMessage = "resume() ejecutado"
        refresh()
    }

    func pollLeader() async {
        isWorking = true; defer { isWorking = false }
        await makeRunner().pollLeader()
        lastMessage = "pollLeader() ejecutado"
        refresh()
    }

    /// El runner ya repone la fase ORIGEN de una reversa journaleada (`reverseFailedRollback` →
    /// `reverseOriginRaw`, fallback `.done`); el forward (`failedRollback`) resetea a `notStarted`. No-op
    /// fuera de esos dos terminales.
    func resetAfterRollback() async {
        isWorking = true; defer { isWorking = false }
        await makeRunner().resetAfterRollback()
        lastMessage = "resetAfterRollback() ejecutado (no-op fuera de failedRollback/reverseFailedRollback)"
        refresh()
    }

    // MARK: - Reversa I11 (I11-5)

    /// Recalcula SOLO el veredicto de elegibilidad (`ReverseEligibility.decide`) + el conteo de testigos con
    /// `ckRecordName != nil` (el `hasCKMap`) + el origin journaleado. No muta nada.
    func verifyReverseEligibility() {
        refreshReverse()
        lastMessage = "Elegibilidad reversa: \(reverseEligibilityLabel)"
    }

    /// Scan READ-ONLY de metadata CloudKit HUÉRFANA (canario v1 SIN reparación, §h residual): filas de
    /// `ANSCKRECORDMETADATA` cuyo `(Z_ENT, Z_PK)` no tiene fila viva (zombie por History purgada). NO muta
    /// nada (molde `computeDryRun`, sin confirmationDialog). Emite el breadcrumb informativo.
    func scanOrphanMetadata() {
        let live = MigrationWorkExecutor.collectLiveByEntityName(context: context)
        let report = CKIdentityCapture.scanOrphanMetadata(
            liveByEntityName: live, storeURL: SwiftDataConfiguration.personalConfiguration.url)
        CloudSyncBreadcrumb.reverseOrphanMetadata(count: report.orphans)
        let liveCount = live.values.reduce(0) { $0 + $1.count }
        orphanScanLabel = "huérfanos \(report.orphans) · escaneados \(report.scanned) · failed \(report.failed) · vivos \(liveCount)"
        lastMessage = "Scan metadata huérfana (read-only): \(orphanScanLabel)"
    }

    /// HALLAZGO 4 (corrida device reversa 2026-07-11, D1 del review): listado READ-ONLY de testigos
    /// `SyncIdentity` con `lastReboundAt != nil` (rebind-por-ancla del backfill / re-key del IdentityRemap
    /// #29). Convierte en 1 tap la checklist del veredicto BENIGNO de `rebindsVerified` (`entityType` +
    /// `lastReboundAt` corto, sin PII). Molde de `scanOrphanMetadata`: NO muta nada. `#Predicate` CONCRETO
    /// sobre `SyncIdentity.lastReboundAt` (barato). El owner confirma: `entityType == inboxDraft` y
    /// `lastReboundAt` anterior al cutover ⇒ los 2 pares byte-idénticos pre-`00439727` (benigno).
    func listRebinds() {
        do {
            let rebinds = try context.fetch(
                FetchDescriptor<SyncIdentity>(predicate: #Predicate { $0.lastReboundAt != nil }))
            guard !rebinds.isEmpty else {
                rebindsLabel = "0 testigos con lastReboundAt (sin rebinds)"
                lastMessage = "Testigos rebindeados (read-only): ninguno"
                return
            }
            // Cota del label (M2 del review adversarial): tras un remap masivo el listado crecería sin
            // límite; 20 entradas bastan para la checklist del owner y el count total va delante.
            let maxShown = 20
            let sorted = rebinds
                .sorted { ($0.lastReboundAt ?? .distantPast) < ($1.lastReboundAt ?? .distantPast) }
            let lines = sorted.prefix(maxShown)
                .map { id -> String in
                    let when = id.lastReboundAt.map { $0.formatted(date: .abbreviated, time: .standard) } ?? "—"
                    return "\(id.entityType) @ \(when)"
                }
                .joined(separator: " · ")
            let suffix = sorted.count > maxShown ? " · …(+\(sorted.count - maxShown))" : ""
            rebindsLabel = "\(rebinds.count): \(lines)\(suffix)"
            lastMessage = "Testigos rebindeados (read-only): \(rebinds.count)"
        } catch {
            rebindsLabel = "error: \(error)"
            lastMessage = "Testigos rebindeados falló: \(error)"
        }
    }

    /// DIFERIDOS #30: diff READ-ONLY de filas huérfanas del adopt (§3.4). Pasos 1,3,4 del reconcile SIN
    /// backfill NI upload — enumera el backend (staging), inventario local, diff. NO muta nada (molde
    /// `scanOrphanMetadata`/`computeDryRun`). El upload real lo cablea I14 en el flujo de adopt.
    func diffOrphansAdopt() async {
        isWorking = true; defer { isWorking = false }
        guard let plan = await makeExecutor().adoptOrphanDryRun() else {
            adoptDiffLabel = "transient (red) — reintenta"
            lastMessage = "Diff huérfanas (adopt): red caída al enumerar el backend"
            return
        }
        let orphanLines = plan.orphans.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.count)" }.joined(separator: " ")
        let needLines = plan.needsIdentity.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        adoptDiffLabel = "huérfanas \(plan.uploadCount) [\(orphanLines.isEmpty ? "—" : orphanLines)] · needsIdentity \(plan.identityCount) [\(needLines.isEmpty ? "—" : needLines)]"
        lastMessage = "Diff huérfanas (adopt) READ-ONLY: \(adoptDiffLabel)"
    }

    /// Diálogos-primero (obligación 5 del review POR CONSTRUCCIÓN): SOLO se invoca tras la 2ª confirmación
    /// del panel. Re-valida el gate DURO (elegibilidad, obligaciones 1-2) y, si pasa, emite
    /// `.reverseActivated` seguido de `.reverseConfirmed` en la MISMA acción async → `reverseConfirm` jamás
    /// persiste esperando UI (un kill entre ambos submits lo normaliza `resume()` → origin). NUNCA fuerza
    /// `icloudActive`: la única vía a un terminal es la máquina. Si NO es elegible, no se emite nada.
    func startReverse() async {
        isWorking = true; defer { isWorking = false }
        refreshReverse()
        guard reverseEligible else {
            lastMessage = "Reversa NO iniciada — no elegible: \(reverseEligibilityLabel)"
            return
        }
        let r = makeRunner()
        await r.submit(.reverseActivated)   // done/notStarted → reverseConfirm(origin)
        await r.submit(.reverseConfirmed)   // reverseConfirm → reverseClaimLeader → drive autónomo
        lastMessage = "Reversa iniciada — reverseActivated + reverseConfirmed emitidos. El driving avanza; HOY corta retomable en reverseClaimLeader (performReverseClaim notWired → transient) hasta que aterrice I11-3."
        refresh()
    }

    /// Veredicto + origin de la reversa (sin mutar). `hasCKMap` = ≥1 `SyncIdentity` con `ckRecordName != nil`
    /// (el mapa de coordenadas CloudKit que la reversa necesita para borrar los records) — vía `fetchCount`
    /// con `#Predicate<SyncIdentity>` CONCRETO (barato, no carga filas).
    private func refreshReverse() {
        let ckMapCount = (try? context.fetchCount(
            FetchDescriptor<SyncIdentity>(predicate: #Predicate { $0.ckRecordName != nil }))) ?? -1
        let hasCKMap = ckMapCount > 0
        var journaledPhase: MigrationPhase = .notStarted
        var descriptor = FetchDescriptor<MigrationState>()
        descriptor.fetchLimit = 1
        if let state = try? context.fetch(descriptor).first {
            journaledPhase = state.readPhase().phase
            reverseOriginLabel = state.reverseOriginRaw ?? "—"
        } else {
            reverseOriginLabel = "—"
        }
        let decision = ReverseEligibility.decide(
            // M1: modo PERSISTIDO (diagnóstico de la travesía del device, no el efectivo).
            storageMode: StorageModePersistence.read(), hasCKMap: hasCKMap, journaledPhase: journaledPhase)
        reverseEligible = decision == .eligible
        switch decision {
        case .eligible:
            reverseEligibilityLabel = "eligible ✅ · \(ckMapCount) testigos con ckRecordName"
        case .notCloudMode:
            reverseEligibilityLabel = "notCloudMode · storageMode != .cloud (nada que revertir)"
        case .degradedNoMap:
            reverseEligibilityLabel = "degradedNoMap ⚠️ · \(ckMapCount) testigos con ckRecordName (born-cloud sin mapa → EXCLUIDO en v1, §h.6-A1)"
        case .reverseAlreadyTerminal:
            reverseEligibilityLabel = "reverseAlreadyTerminal · ya en icloudActive/reverseFailedRollback (nada que revertir)"
        }
    }

    /// Escape hatch DEBUG (salida de EMERGENCIA): storageMode=.icloud + DESARMA el mirror-off + borra el
    /// journal + apaga el gate de identidad. NO es "forzar done" — devuelve el device al estado iCloud. El par
    /// (storageMode, mirrorOffArmed) se limpia JUNTO (invariante SERIO 1). También ABORTA una reversa en
    /// vuelo: borra su journal (incl. `reverseOriginRaw`) y devuelve el device a `.icloud`; post-mount de una
    /// reversa es aún más benigno (el mirror ya está encendido). El backend puede quedar con
    /// `reverse_in_progress=true` → un `reverse_claim` posterior del mismo device es idempotente-ok.
    func forceRollbackEscapeHatch() {
        // Suelta el runner en vuelo (su Task muere en el próximo relaunch; su próximo loadState sobre el
        // journal borrado daría notStarted → drive corta) y destraba el panel: `isWorking` puede haber
        // quedado `true` porque una corrida autónoma (subida de snapshot, 10-25 min) mantiene el `await`
        // vivo — es EXACTAMENTE cuando el escape hatch hace falta.
        runner = nil
        isWorking = false
        StorageModePersistence.write(.icloud)
        UserDefaults.standard.removeObject(forKey: StorageModePersistence.mirrorOffArmedKey)
        CloudSyncFlags.identityCaptureEnabled = false
        do {
            for state in try context.fetch(FetchDescriptor<MigrationState>()) { context.delete(state) }
            if context.hasChanges { try context.save() }
            lastMessage = "Escape hatch: storageMode=.icloud + journal limpiado. RELANZA para remontar el mirror."
        } catch {
            lastMessage = "Escape hatch falló: \(error)"
        }
        refresh()
    }

    /// Borra el marcador `CD_CloudMigrationMarker` del store personal (higiene DEBUG). Con el mirror
    /// MONTADO el delete se exporta a CloudKit de forma nativa — mismo mecanismo que el efecto
    /// `deleteCloudKitMarker` de la reversa (I11-2), expuesto aquí para limpiar un marcador STALE:
    /// el escape hatch post-cutover borra el journal pero el marcador SOBREVIVE (local + CloudKit) →
    /// una migración fresca dispararía falso `secondaryDeviceCloudLogin` (markerReconciliation con
    /// journal notStarted). Idempotente (0 si no había). Corrida device 2026-07-10.
    func deleteStaleCloudKitMarker() {
        do {
            let markers = try context.fetch(FetchDescriptor<CloudMigrationMarker>())
            for marker in markers { context.delete(marker) }
            if context.hasChanges { try context.save() }
            CloudSyncBreadcrumb.reverseMarkerDeleted(count: markers.count)
            lastMessage = markers.isEmpty
                ? "Sin marcador local — nada que borrar (si existe en CloudKit sin fila local, espera el import y reintenta)."
                : "Marcador borrado (\(markers.count)). El mirror exporta el delete a CloudKit (mount actual: \(mountedModeLabel))."
        } catch {
            lastMessage = "Borrar marcador falló: \(error)"
        }
        refresh()
    }

    /// Dry-run (§g.5): conteos EN MEMORIA por entidad clave + outbox vivo. NO escribe nada.
    func computeDryRun() {
        func count<M: PersistentModel>(_ type: M.Type) -> Int {
            (try? context.fetchCount(FetchDescriptor<M>())) ?? -1
        }
        let liveOutbox = (try? context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }.count) ?? -1
        // Diagnóstico FX (hallazgo corrida reversa 2026-07-11): una fila local de ExchangeRate CON syncID
        // que el server no conoce diverge el Merkle PARA SIEMPRE (collectLeaves salta sin-syncID; el drain
        // no re-captura una History tx ya consumida). Esta línea muestra cada fila con [syncID/testigo]
        // para cazarla a ojo. try? = patrón local del panel (degradación visible a "—").
        let fxRows = (try? context.fetch(FetchDescriptor<ExchangeRate>())) ?? []
        let witnessIDs = Set(((try? context.fetch(FetchDescriptor<SyncIdentity>())) ?? []).map(\.syncID))
        let fxDiag = fxRows.isEmpty ? "—" : fxRows
            .sorted { $0.dateKey < $1.dateKey }
            .map { row in
                let hasWitness = row.syncID.map { witnessIDs.contains($0) } == true
                return "\(row.dateKey)[sid \(row.syncID != nil ? "sí" : "NO")·w \(hasWitness ? "sí" : "no")]"
            }
            .joined(separator: " ")
        dryRunSummary = """
        TX \(count(TransactionItem.self)) · Cat \(count(Category.self)) · Sub \(count(Subcategory.self)) · \
        Acc \(count(Account.self)) · Budget \(count(Budget.self)) · Sched \(count(ScheduledPayment.self))
        Identidades \(count(SyncIdentity.self)) · Outbox vivo \(liveOutbox)
        FX \(fxRows.count): \(fxDiag)
        """
    }

    /// Purga TODAS las filas locales de `ExchangeRate` (caché re-derivable — la app re-fetchea a demanda;
    /// cada TX guarda su propio `exchange_rate`). Higiene DEBUG de la reversa (corrida 2026-07-11): una
    /// fila FX local con syncID que el server no conoce bloquea `reverseVerify` con mismatch perpetuo.
    /// El delete va con autor por DEFECTO → el drain lo captura como tombstone y lo pushea (las filas ya
    /// tombstoneadas server-side son noop idempotente).
    func purgeLocalExchangeRates() {
        do {
            let rows = try context.fetch(FetchDescriptor<ExchangeRate>())
            for row in rows { context.delete(row) }
            if context.hasChanges { try context.save() }
            lastMessage = "ExchangeRate purgadas: \(rows.count) filas locales. La caché se re-fetchea a demanda."
        } catch {
            lastMessage = "Purga ExchangeRate falló: \(error)"
        }
        refresh()
    }

    /// Lee el journal + testigos vivos (sin mutar nada).
    func refresh() {
        quiescent = iCloudSyncService.shared.isImportQuiescent
        refreshReverse()
        // Diagnóstico del verify (bug-hunting device): outbox vivo + dead-letters CON MOTIVOS + cuarentena.
        // Un dead-letter = el server RECHAZÓ esa fila (verify skippea `dead-letters` → mismatch → rollback).
        do {
            let outbox = try context.fetch(FetchDescriptor<SyncOutbox>())
            let live = outbox.filter { $0.rejectedReason == nil }.count
            let dead = outbox.filter { $0.rejectedReason != nil }
            let quarantine = try context.fetchCount(FetchDescriptor<SyncQuarantine>())
            if dead.isEmpty {
                outboxDiagLabel = "vivo \(live) · dead-letters 0 · cuarentena \(quarantine)"
            } else {
                var reasonCounts: [String: Int] = [:]
                var tables: Set<String> = []
                for row in dead {
                    reasonCounts[row.rejectedReason ?? "?", default: 0] += 1
                    tables.insert(row.entityType)
                }
                let reasons = reasonCounts.sorted { $0.value > $1.value }
                    .map { "\($0.key)×\($0.value)" }.joined(separator: " · ")
                outboxDiagLabel = "vivo \(live) · DEAD \(dead.count) [\(tables.sorted().joined(separator: ","))] → \(reasons) · cuarentena \(quarantine)"
            }
        } catch {
            outboxDiagLabel = "diag falló: \(error.localizedDescription)"
        }
        // R1: el testigo es la DECISIÓN de mount (4 valores) — el panel enseña la decisión y, entre
        // paréntesis, el eje que consumen los gates: si el mirror de CloudKit está adjunto o no.
        let mountedDecision = SwiftDataConfiguration.personalStoreMountedDecision
        mountedModeLabel = "\(mountedDecision.rawValue) (mirror "
            + (mountedDecision.attachesCloudKitMirror ? "adjunto" : "off") + ")"
        persistedModeLabel = StorageModePersistence.read().rawValue
        relaunchRequested = UserDefaults.standard.bool(forKey: MigrationWorkExecutor.relaunchRequestedKey)
        var descriptor = FetchDescriptor<MigrationState>()
        descriptor.fetchLimit = 1
        guard let state = try? context.fetch(descriptor).first else {
            phaseLabel = "notStarted (sin journal)"
            pendingEffectsLabel = "—"; countersLabel = "—"; cursorLabel = "—"; startedAtLabel = "—"
            markerClockLabel = "—"; icloudVerdictLabel = "—"
            return
        }
        phaseLabel = "\(state.readPhase().phase)"
        let pending = state.readPendingEffects().map(\.rawValue)
        pendingEffectsLabel = pending.isEmpty ? "—" : pending.joined(separator: ", ")
        countersLabel = "mismatch \(state.verifyMismatchRetries) · red \(state.verifyNetworkRetries) · leader \(state.leaderDeviceID ?? "—") · seqCut \(state.serverSeqCut)"
        cursorLabel = state.snapshotCursorJSON ?? "—"
        startedAtLabel = state.startedAt.map { $0.formatted(date: .omitted, time: .standard) } ?? "—"
        markerClockLabel = state.markerWrittenSince.map {
            "\(Int(Date.now.timeIntervalSince($0)))s (desde \($0.formatted(date: .omitted, time: .standard)))"
        } ?? "—"
        icloudVerdictLabel = state.cutoverICloudVerdictRaw ?? "—"
    }
}

struct CloudSyncDebugView: View {
    @State private var model = CloudSyncDebugModel()
    @State private var migration: CloudSyncMigrationPanelModel?
    @State private var confirmStartReal = false
    @State private var confirmStartReal2 = false
    @State private var confirmStartReverse = false
    @State private var confirmStartReverse2 = false
    @State private var confirmEscapeHatch = false
    @State private var confirmDeleteMarker = false
    @State private var confirmPurgeFX = false
    // Spike S7: override de fase simulada (nil = sin override = producción `.notStarted`) + quiescencia
    // viva (refrescada cada 1s) para mostrar en vivo la decisión del gate §i.9.
    @State private var selectedS7Phase: MigrationPhaseStore.SimulatedPhase?
    @State private var s7Quiescent = false
    // DIFERIDOS #34: espejo del toggle de simulación del kill-switch (se hidrata en .task).
    @State private var simulateRemoteOff = false
    #if DEBUG
    // SPIKE R3 — quitar al cerrar R4 (deuda explícita anotada en el chip R3 y en el header del harness).
    // Solo se instancia en DEBUG (el harness entero vive ahí).
    @State private var spikeR3 = SpikeR3Harness()
    #endif
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                stateCard
                remoteConfigCard
                actionsCard
                pushCard
                migrationCard
                reverseCard
                secondarySessionCard
                spikeS7Card
                #if DEBUG
                // SPIKE R3 — quitar al cerrar R4. Gateado por el launch arg: sin `-spike-r3` el panel
                // queda EXACTAMENTE como estaba.
                if SpikeR3Harness.isEnabled { spikeR3Card }
                #endif
                if let message = model.lastMessage {
                    Text(message)
                        .font(DS.Typography.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.lg)
                }
                Text("DEV_BUILD only · staging. No incluye ‘run sync cycle’ (eso toca datos reales — es I10).")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, DS.Spacing.lg)
            }
            .padding(.vertical, DS.Spacing.xxl)
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle("Modo Nube · Auth")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            simulateRemoteOff = UserDefaults.standard.bool(forKey: CloudRemoteFlags.debugForceOffKey)
            await model.refreshAttest()
            await model.refreshCredential()
        }
        .task {
            // Spike S7: refleja el override persistido al abrir + refresca la quiescencia viva (1s) para
            // que la decisión del gate se muestre en vivo.
            selectedS7Phase = MigrationPhaseStore.shared.simulatedPhase
            while !Task.isCancelled {
                s7Quiescent = iCloudSyncService.shared.isImportQuiescent
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
            }
        }
        .task {
            // Migración I10: crea el modelo con el mainContext + refresca el estado vivo cada 1s.
            if migration == nil { migration = CloudSyncMigrationPanelModel(context: modelContext) }
            while !Task.isCancelled {
                migration?.refresh()
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
            }
        }
        .confirmationDialog("Iniciar migración REAL contra staging",
                            isPresented: $confirmStartReal, titleVisibility: .visible) {
            Button("Continuar (1/2)", role: .destructive) { confirmStartReal2 = true }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Arranca el cutover REAL. Al llegar al cutover PERSISTE storageMode=.cloud en ESTE device: el próximo relanzamiento montará el store personal con el mirror OFF. Solo en un device de pruebas.")
        }
        .confirmationDialog("¿Seguro? Persiste storageMode=.cloud",
                            isPresented: $confirmStartReal2, titleVisibility: .visible) {
            Button("SÍ, iniciar migración REAL (2/2)", role: .destructive) {
                Task { await migration?.startReal() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Segunda confirmación. Esto NO es reversible sin el escape hatch (I11 aún no existe).")
        }
        .confirmationDialog("Forzar storageMode=.icloud + limpiar journal",
                            isPresented: $confirmEscapeHatch, titleVisibility: .visible) {
            Button("Forzar salida (escape hatch)", role: .destructive) {
                migration?.forceRollbackEscapeHatch()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Salida de EMERGENCIA: devuelve el device a iCloud y borra el journal (aborta también una reversa en vuelo). RELANZA después. NO es 'forzar done'.")
        }
        // Reversa I11 — doble confirmación DIÁLOGOS-PRIMERO: cero eventos hasta la 2ª confirmación. Cancelar
        // cualquiera = no-op total (nada emitido). Solo tras confirmStartReverse2 se llama startReverse(),
        // que emite reverseActivated + reverseConfirmed JUNTOS.
        .confirmationDialog("Iniciar REVERSA a iCloud (staging)",
                            isPresented: $confirmStartReverse, titleVisibility: .visible) {
            Button("Continuar (1/2)", role: .destructive) { confirmStartReverse2 = true }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Arranca la reversa REAL a iCloud: drena/verifica el backend, congela, borra los records de CloudKit y remonta el mirror. Al remontar el mirror pedirá MATAR Y RELANZAR. Solo en un device de pruebas.")
        }
        .confirmationDialog("¿Seguro? Inicia la reversa a iCloud",
                            isPresented: $confirmStartReverse2, titleVisibility: .visible) {
            Button("SÍ, iniciar REVERSA (2/2)", role: .destructive) {
                Task { await migration?.startReverse() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Segunda confirmación. Emite reverseActivated + reverseConfirmed. HOY el flujo corta retomable en reverseClaimLeader (server I11-3 aún no desplegado a staging) — usa ‘Retomar’ para reanudar.")
        }
        .confirmationDialog("Borrar marcador CloudKit (stale)",
                            isPresented: $confirmDeleteMarker, titleVisibility: .visible) {
            Button("Borrar marcador", role: .destructive) {
                migration?.deleteStaleCloudKitMarker()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Borra CD_CloudMigrationMarker del store personal; con el mirror MONTADO el delete se exporta a CloudKit. Úsalo SOLO para limpiar un marcador stale (p.ej. tras escape hatch post-cutover) antes de re-migrar.")
        }
        .confirmationDialog("Purgar ExchangeRate locales",
                            isPresented: $confirmPurgeFX, titleVisibility: .visible) {
            Button("Purgar caché FX", role: .destructive) {
                migration?.purgeLocalExchangeRates()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Borra TODAS las filas locales de ExchangeRate (caché re-derivable, se re-fetchea a demanda). Úsalo cuando una fila FX huérfana bloquea reverseVerify con mismatch perpetuo (hallazgo 2026-07-11).")
        }
    }

    private var migrationCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Migración I10 · cutover (staging)")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Conduce el MigrationRunner REAL sobre el mainContext contra staging. Idempotente/retomable. JAMÁS ofrece 'forzar done'.")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)

            if let migration {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    row("Fase", migration.phaseLabel)
                    row("Pending fx", migration.pendingEffectsLabel)
                    row("Contadores", migration.countersLabel)
                    row("Cursor", migration.cursorLabel)
                    row("startedAt", migration.startedAtLabel)
                    row("Quiescent", migration.quiescent ? "SÍ" : "NO")
                    row("Mount (proc)", migration.mountedModeLabel)
                    row("Mode persist", migration.persistedModeLabel)
                    row("Relaunch req", migration.relaunchRequested ? "SÍ" : "NO")
                    row("Marker clock", migration.markerClockLabel)
                    row("iCloud verdict", migration.icloudVerdictLabel)
                    if let dry = migration.dryRunSummary { row("Dry-run", dry) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.sm)
                .background(.thBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

                VStack(spacing: DS.Spacing.sm) {
                    migrationButton("Simular migración (dry-run)") { await migration.simulate() }
                    migrationButton("Conteos dry-run (§g.5, no escribe)") { migration.computeDryRun() }
                    migrationButton("Aceptar consent + sign-in (continuar)") { await migration.acceptConsentAndSignIn() }
                    migrationButton("Retomar (resume)") { await migration.resume() }
                    migrationButton("Poll líder") { await migration.pollLeader() }
                    migrationButton("Reset tras rollback") { await migration.resetAfterRollback() }
                }

                Button {
                    confirmStartReal = true
                } label: {
                    Label("Iniciar migración REAL (staging)", systemImage: "exclamationmark.triangle.fill")
                        .font(DS.Typography.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(migration.isWorking)

                Button {
                    confirmEscapeHatch = true
                } label: {
                    Label("Forzar salida (escape hatch) — detiene y limpia", systemImage: "arrow.uturn.backward")
                        .font(DS.Typography.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(.red)
                // NUNCA deshabilitado: es el botón de EMERGENCIA — debe funcionar precisamente durante una
                // corrida autónoma (isWorking=true por los ~20 min de subida). Bug device 2026-07-10.

                if let message = migration.lastMessage {
                    Text(message)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("Inicializando…").font(DS.Typography.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func migrationButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(DS.Typography.caption.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xs)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .disabled(migration?.isWorking ?? true)
    }

    // MARK: - Reversa I11 (I11-5)

    private var reverseCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Reversa I11 · volver a iCloud (staging)")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Revierte el Modo Nube a iCloud sobre el mainContext. La Fase / Pending fx / sub-estado reconcile viven en la card de arriba. HOY el driving corta retomable en reverseClaimLeader (server I11-3 sin desplegar a staging) — usa ‘Retomar’ de la card de migración para reanudar.")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)

            if let migration {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    row("Elegible", migration.reverseEligibilityLabel)
                    row("Origin", migration.reverseOriginLabel)
                    row("Orphan scan", migration.orphanScanLabel)
                    row("Adopt diff", migration.adoptDiffLabel)
                    row("Rebinds", migration.rebindsLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.sm)
                .background(.thBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

                migrationButton("Verificar elegibilidad reversa") { migration.verifyReverseEligibility() }
                migrationButton("Scan metadata huérfana (read-only)") { migration.scanOrphanMetadata() }
                migrationButton("Testigos rebindeados (read-only)") { migration.listRebinds() }
                migrationButton("Diff huérfanas (adopt) (read-only)") { await migration.diffOrphansAdopt() }
                migrationButton("Borrar marcador CloudKit (stale)") { confirmDeleteMarker = true }
                migrationButton("Purgar ExchangeRate locales (caché)") { confirmPurgeFX = true }

                Button {
                    confirmStartReverse = true
                } label: {
                    Label("Iniciar REVERSA (staging)", systemImage: "arrow.uturn.backward.circle.fill")
                        .font(DS.Typography.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                // Gate DURO: solo elegible (obligaciones 1-2 del review). startReverse() re-valida por si el
                // estado cambió entre el refresh y el tap. Deshabilitado durante isWorking (patrón existente);
                // el escape hatch de la card de migración sigue siendo la única salida SIEMPRE habilitada.
                .disabled(migration.isWorking || !migration.reverseEligible)
            } else {
                Text("Inicializando…").font(DS.Typography.caption).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var stateCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            row("Config", model.configLabel)
            row("Session", model.sessionLabel)
            row("Attest", model.attestSupportedLabel)
            if let attestStatus = model.attestStatus {
                row("Attest token", attestStatus)
            }
            if let credentialStatus = model.credentialStatus {
                row("Credential", credentialStatus)
            }
            if let claim = model.lastClaimState {
                row("Last claim", claim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    /// DIFERIDOS #34: snapshot del remote-config + simulación del kill-switch (QA del gate de
    /// entradas sin tocar staging). El toggle escribe `cloudSync.debug.remoteFlagsForceOff`
    /// (solo DEV_BUILD — producción la ignora).
    private var remoteConfigCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            let snapshot = CloudRemoteConfigStore.readSnapshot()
            row("Remote cfg", snapshot.map {
                "cloud=\($0.cloudModeRolloutPercent.map(String.init) ?? "nil") · choice=\($0.cloudOnboardingChoiceRolloutPercent.map(String.init) ?? "nil") · groups=\($0.groupsBackendRolloutPercent.map(String.init) ?? "nil")"
            } ?? "sin snapshot (default DEV=ON)")
            row("Fetched", snapshot.map { $0.fetchedAt.formatted(date: .abbreviated, time: .standard) } ?? "—")
            row("Bucket", "\(RemoteFlagDecisionLogic.stableBucket(seed: CloudRemoteConfigStore.bucketSeed()))")
            row("Efectivos", "cloudMode=\(CloudRemoteFlags.cloudModeEnabled) · groups=\(CloudRemoteFlags.groupsBackendEnabled)")
            // Regla del repo (no Binding(get:set:) en body): @State + onChange escribe la key.
            Toggle("Simular remote OFF (kill-switch)", isOn: $simulateRemoteOff)
                .font(DS.Typography.caption)
                .onChange(of: simulateRemoteOff) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: CloudRemoteFlags.debugForceOffKey)
                }
            actionButton("Fetch /config ahora", disabled: !model.isConfigured) {
                await RemoteConfigClient.shared.refreshIfDue(force: true)
                model.lastMessage = "Remote config: \(CloudRemoteConfigStore.readSnapshot().map { "cloud=\($0.cloudModeRolloutPercent ?? -1)" } ?? "fetch falló (ver Console)")"
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var actionsCard: some View {
        VStack(spacing: DS.Spacing.sm) {
            actionButton("Sign in with Apple", disabled: !model.isConfigured) {
                await model.signIn()
            }
            actionButton("Sign in with Google", disabled: !model.isConfigured) {
                await model.signInGoogle()
            }
            actionButton("Claim account", disabled: !model.isConfigured) {
                await model.claim()
            }
            actionButton("Sign out", disabled: !model.isConfigured) {
                await model.signOut()
            }
            // H4: arma el boot-cleanup del sign-out SIN pasar por SIWA/push-all — única forma de
            // verificar `performSignOutWipeIfArmed` en sim (SIWA no funciona ahí). RELANZA después.
            actionButton("Arm sign-out wipe (borra stores al relanzar)", disabled: false) {
                StorageModePersistence.armSignOutWipe()
                model.lastMessage = "signOutWipeArmed=true. RELANZA: el boot borra YalaModel+YalaSyncMeta y resetea a .icloud fresh."
            }
            // Fix carrera 2026-07-14: fuerza la fase terminal SIN armar el wipe ni tocar
            // credenciales — verifica en sim el cover de dueño único (esta sheet debe
            // cerrarse sola, el cover del root presentar) y el exit(0) al ir a background.
            actionButton("Force awaitingRelaunch (solo fase, sin wipe)", disabled: false) {
                CloudSessionSignOut.shared._debugForceAwaitingRelaunch()
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Push (spike G0)

    /// Spike G0: token APNs del device + push de prueba vía el gateway staging. La entrega
    /// real solo se observa en device físico (Console.app, `category:Push`).
    private var pushCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let token = model.deviceTokenHex {
                row("APNs token", "\(token.prefix(8))… (\(token.count) chars)")
                Button {
                    UIPasteboard.general.string = token
                    model.lastMessage = "Push: token copiado al portapapeles"
                } label: {
                    Text("Copiar token")
                        .font(DS.Typography.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .disabled(model.isWorking)
            } else {
                row("APNs token", "sin registrar (device real requerido)")
            }
            actionButton("Enviar push de prueba (staging)", disabled: model.deviceTokenHex == nil) {
                await model.sendTestPush()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Sesión secundaria (M1)

    /// Única vía de verificación EN SIM del mount/wipe/purga de la sesión secundaria (SIWA no corre
    /// en sim — la entrada real es device-only). Botones idempotentes; JAMÁS un forzado destructivo
    /// sobre los archivos del dueño (el wipe secundario solo borra `-Secondary`).
    private var secondarySessionCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Sesión secundaria (M1)")
                .font(DS.Typography.body.weight(.semibold))
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                row("Descriptor", SecondarySessionStore.activeUserID().map { "\($0.prefix(12))…" } ?? "inactivo")
                row("Modo persistido (dueño)", StorageModePersistence.read().rawValue)
                row("Modo efectivo", CloudSyncFlags.storageMode.rawValue)
                row("Mount secundario (testigo)", SwiftDataConfiguration.secondaryStoreMounted ? "SÍ" : "no")
                row("Entry purge done", SecondarySessionStore.isEntryPurgeDone() ? "sí" : "no")
                row("Wipe secundario armado", SecondarySessionStore.isWipeArmed() ? "SÍ" : "no")
                row("Flag entrada (debug)", UserDefaults.standard.bool(
                    forKey: CloudSyncFlags.debugSecondarySessionEnabledKey) ? "ON" : "off (DARK)")
            }
            actionButton("Toggle flag de entrada (QA device sin recompilar)", disabled: false) {
                let key = CloudSyncFlags.debugSecondarySessionEnabledKey
                let next = !UserDefaults.standard.bool(forKey: key)
                UserDefaults.standard.set(next, forKey: key)
                model.lastMessage = "secondarySessionEnabled(debug)=\(next). Solo builds Dev; prod sigue DARK."
            }
            actionButton("Activar descriptor FAKE (guest-debug) — relanzar monta -Secondary", disabled: false) {
                SecondarySessionStore.activate(userID: "guest-debug")
                model.lastMessage = "Descriptor=guest-debug. RELANZA: el boot monta YalaModel-Secondary "
                    + "(testigo secundario=SÍ) y corre la purga de entrada. Mientras tanto: runtime "
                    + "bloqueado por mount-mismatch + blocker secondaryEntryRelaunch."
            }
            actionButton("Limpiar descriptor (deshace el fake SIN wipe)", disabled: false) {
                SecondarySessionStore.clear()
                SecondarySessionStore.clearEntryPurgeMark()
                model.lastMessage = "Descriptor limpiado. RELANZA para volver al mount del dueño "
                    + "(los archivos -Secondary quedan huérfanos inertes; usa el wipe para borrarlos)."
            }
            actionButton("Armar wipe secundario (borra -Secondary al relanzar)", disabled: false) {
                SecondarySessionStore.armWipe()
                model.lastMessage = "secondaryWipeArmed=true. RELANZA: el boot borra los archivos "
                    + "-Secondary + purga + resetea flags de onboarding → Welcome. El YalaModel del "
                    + "dueño y storageMode NO se tocan."
            }
            actionButton("Re-correr purga de entrada (limpia el marker)", disabled: false) {
                SecondarySessionStore.clearEntryPurgeMark()
                model.lastMessage = "entryPurgeDone limpiado — el próximo boot con descriptor re-purga."
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Spike S7 (gate §i.9 de los 3 BGTasks + fase simulada)

    /// La `MigrationPhase` que el gate verá (= exactamente lo que `MigrationPhaseStore.currentPhase`
    /// devuelve con este override; nil = producción `.notStarted`).
    private var s7CurrentPhase: MigrationPhase {
        selectedS7Phase?.migrationPhase ?? .notStarted
    }

    private func s7Decision(_ role: BGTaskMigrationGate.Role) -> BGTaskMigrationGate.Decision {
        BGTaskMigrationGate.decide(phase: s7CurrentPhase, isImportQuiescent: s7Quiescent, role: role)
    }

    private func s7DecisionLabel(_ decision: BGTaskMigrationGate.Decision) -> String {
        switch decision {
        case .run:                  return "RUN ✅ · corre el flujo normal"
        case .suspendAndReschedule: return "SUSPEND ⏸ · setTaskCompleted(false) + re-programa"
        case .deferAndReschedule:   return "DEFER ⏳ · difiere save() + re-programa"
        }
    }

    /// Comandos lldb con los IDs REALES (referencian las constantes del manager → sin drift).
    private var s7LldbCommands: [(role: String, command: String)] {
        func cmd(_ id: String) -> String {
            "e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@\"\(id)\"]"
        }
        return [
            ("widget-refresh · lector", cmd(BackgroundTaskManager.widgetRefreshTaskID)),
            ("report-notification · escritor", cmd(BackgroundTaskManager.reportNotificationTaskID)),
            ("report-backup · escritor", cmd(BackgroundTaskManager.reportBackupTaskID)),
        ]
    }

    private var spikeS7Card: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Spike S7 · gate §i.9 de los BGTasks")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Gate REAL de producción (BackgroundTaskManager) + simulador de fase. SIN override la fase real es SIEMPRE .notStarted → los 3 corren normal (mitad POSITIVA). Simula una fase transitoria para ver SUSPEND (lector) / DEFER (escritor sin quiescencia).")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)

            Picker("Fase simulada", selection: $selectedS7Phase) {
                Text("sin override · producción (.notStarted)")
                    .tag(MigrationPhaseStore.SimulatedPhase?.none)
                ForEach(MigrationPhaseStore.SimulatedPhase.allCases, id: \.self) { phase in
                    Text(phase.label).tag(MigrationPhaseStore.SimulatedPhase?.some(phase))
                }
            }
            .pickerStyle(.menu)
            .font(DS.Typography.caption)
            .onChange(of: selectedS7Phase) { _, newValue in
                MigrationPhaseStore.shared.setSimulatedPhase(newValue)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                row("Quiescent", s7Quiescent ? "SÍ · isImportQuiescent" : "NO")
                row("widget · lector", s7DecisionLabel(s7Decision(.reader)))
                row("report · escritor", s7DecisionLabel(s7Decision(.writer)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.sm)
            .background(.thBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

            // Siembra los 3 requests en la cola de BGTaskScheduler — `_simulateLaunchForTaskWithIdentifier`
            // SOLO dispara requests PENDIENTES ("No task request … has been scheduled" si la cola está
            // vacía; cazado en la corrida device del spike: widget-refresh no tenía siembra de boot —
            // ya arreglado en AppBootstrapper paso 11, pero este botón sigue siendo necesario para
            // quitar el earliestBeginDate futuro de los 3 requests).
            // Ejecución DIRECTA del camino del handler (gate + trabajo sobre el store real) — el
            // simulate del daemon resultó NO CONFIABLE en iOS 26 device (hallazgo del spike).
            HStack(spacing: DS.Spacing.sm) {
                Button {
                    BackgroundTaskManager.shared.spikeS7RunWidgetPath()
                } label: {
                    Label("Ejecutar widget (directo)", systemImage: "play.circle")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.bordered)
                Button {
                    BackgroundTaskManager.shared.spikeS7RunReportPath()
                } label: {
                    Label("Ejecutar reports (directo)", systemImage: "play.circle.fill")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.bordered)
            }
            Text("Ejecutan el MISMO camino gate+trabajo del handler real, sin pasar por BGTaskScheduler (su _simulateLaunch… es no-confiable en iOS 26 device — hallazgo del spike). El resultado sale en la consola de Xcode con prefijo [S7-directo].")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
            Button {
                BackgroundTaskManager.shared.seedImmediateForSpikeS7()
            } label: {
                Label("(Opcional) Sembrar los 3 BGTasks sin fecha", systemImage: "calendar.badge.clock")
                    .font(DS.Typography.caption)
            }
            .buttonStyle(.bordered)

            Text("Disparar un BGTask (pausa en el debugger → pega el comando → continue):")
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(s7LldbCommands, id: \.role) { entry in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(entry.role)
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(.tertiary)
                    Text(entry.command)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(DS.Spacing.sm)
                .background(.thBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }

            Text("⚠️ Quita el override (‘sin override’) al terminar — deja la fase en producción .notStarted.")
                .font(DS.Typography.caption.weight(.medium))
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func actionButton(
        _ title: String, disabled: Bool, action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(DS.Typography.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .disabled(disabled || model.isWorking)
    }

    // MARK: - Spike R3 (DEBUG · launch arg `-spike-r3`) — ¿muere el container al soltarlo?

    #if DEBUG
    /// SPIKE R3 — quitar al cerrar R4 (deuda explícita, ver el header de `SpikeR3Harness`).
    /// Conduce `SpikeR3Harness`: los ejes locales (1·2·4) corren en
    /// cualquier sitio; el eje 3 (mirror `.private` VIVO) es DEVICE-ONLY y aborta con un mensaje claro
    /// si no hay cuenta iCloud. Cero contacto con el store real: el harness monta el suyo (`YalaSpikeR3`).
    private var spikeR3Card: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Spike R3 · ¿muere el container al soltarlo?")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Store PROPIO (YalaSpikeR3) y modelo propio — NO toca los datos de la app. El eje 3 monta con mirror .private y NO inserta ni una fila (sin export no se crea nada en el schema de CloudKit ni se sube nada a tu cuenta).")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                row("store", SpikeR3Harness.storeURL.lastPathComponent)
                row("archivos", SpikeR3Harness.fileTrio().description)
                row("iCloud", SwiftDataConfiguration.isICloudAvailable() ? "cuenta presente ✅" : "SIN cuenta ❌ (eje 3 no medible)")
                row("container", SwiftDataConfiguration.cloudKitContainerIdentifier)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.sm)
            .background(.thBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

            HStack(spacing: DS.Spacing.sm) {
                Button {
                    Task { await spikeR3.runLocalAxes() }
                } label: {
                    Label("Ejes 1·2·4 (locales)", systemImage: "play.circle")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.bordered)
                .disabled(spikeR3.isWorking)

                Button {
                    Task { await spikeR3.runMirrorAxis() }
                } label: {
                    Label("Eje 3 · mirror (device)", systemImage: "icloud.circle")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.bordered)
                .disabled(spikeR3.isWorking)
            }

            HStack(spacing: DS.Spacing.sm) {
                Button {
                    UIPasteboard.general.string = spikeR3.log
                } label: {
                    Label("Copiar log", systemImage: "doc.on.doc")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.bordered)
                .disabled(spikeR3.log.isEmpty)

                Button {
                    spikeR3.clearLog()
                } label: {
                    Label("Limpiar", systemImage: "trash")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.bordered)
                .disabled(spikeR3.log.isEmpty)

                Button {
                    // R4 (herencia de R3): el botón era MUDO — llamaba al estático y descartaba su
                    // `[String]` de problemas, así que no se distinguía «ya no estaba» de «no se pudo
                    // borrar». Ahora escribe su resultado en el mismo log que el resto del harness.
                    spikeR3.deleteSpikeStoreAndLog()
                } label: {
                    Label("Borrar store del spike", systemImage: "xmark.bin")
                        .font(DS.Typography.caption)
                }
                .buttonStyle(.bordered)
            }

            if spikeR3.isWorking {
                Text("Corriendo… (el eje 3 puede tardar ~1 min: espera eventos del mirror y luego observa 10 s de silencio)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            if !spikeR3.log.isEmpty {
                ScrollView {
                    Text(spikeR3.log)
                        .font(DS.Typography.caption.monospaced())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 320)
                .padding(DS.Spacing.sm)
                .background(.thBackground)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }
    #endif

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(DS.Typography.caption.monospaced())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
