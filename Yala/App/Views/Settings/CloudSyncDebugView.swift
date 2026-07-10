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
    private let accountClient = CloudAccountClient()

    var isConfigured: Bool { CloudBackendConfig.isConfigured }
    var configLabel: String {
        guard let url = CloudBackendConfig.supabaseURL else { return "unconfigured (prod placeholder)" }
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

    func claim() async {
        isWorking = true; defer { isWorking = false }
        guard let jwt = await auth.accessToken() else {
            lastMessage = "Claim skipped: no session (sign in first)"
            return
        }
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "yala-debug-device"
        let outcome = await accountClient.claim(jwt: jwt, deviceID: deviceID, provider: "apple")
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
            _ = try await AppAttestClient.shared.currentSessionToken()
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
    var quiescent = false
    var mountedModeLabel = "—"
    var persistedModeLabel = "—"
    var relaunchRequested = false
    var dryRunSummary: String?

    private let context: ModelContext
    private var runner: MigrationRunner?
    private let deviceID = MigrationWorkExecutor.vendorDeviceID

    init(context: ModelContext) {
        self.context = context
    }

    /// Construye (una vez) el runner con el executor REAL (staging) + la señal de quiescencia de producción.
    private func makeRunner() -> MigrationRunner {
        if let runner { return runner }
        let session = LiveCloudSessionProvider()
        let account = CloudAccountClient()
        let engine = CloudSyncEngine()
        let token: () async -> String? = { await CloudAuthService.shared.accessToken() }
        let push = SyncPushClient(baseURL: ProxyConfig.baseURL, tokenProvider: token)
        let pull = SyncPullClient(baseURL: ProxyConfig.baseURL, tokenProvider: token)
        let merkle = SyncMerkleClient(baseURL: ProxyConfig.baseURL, tokenProvider: token)
        let executor = MigrationWorkExecutor(
            engine: engine, pushClient: push, pullClient: pull, merkleClient: merkle,
            accountClient: account, session: session, context: context, deviceID: deviceID)
        let r = MigrationRunner(
            context: context, executor: executor, deviceID: deviceID,
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

    func resetAfterRollback() async {
        isWorking = true; defer { isWorking = false }
        await makeRunner().resetAfterRollback()
        lastMessage = "resetAfterRollback() ejecutado (no-op fuera de failedRollback)"
        refresh()
    }

    /// Escape hatch DEBUG (salida manual mientras no exista la reversa I11): storageMode=.icloud + DESARMA
    /// el mirror-off + borra el journal + apaga el gate de identidad. NO es "forzar done" — devuelve el
    /// device al estado iCloud. El par (storageMode, mirrorOffArmed) se limpia JUNTO (invariante SERIO 1).
    func forceRollbackEscapeHatch() {
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
        runner = nil
        refresh()
    }

    /// Dry-run (§g.5): conteos EN MEMORIA por entidad clave + outbox vivo. NO escribe nada.
    func computeDryRun() {
        func count<M: PersistentModel>(_ type: M.Type) -> Int {
            (try? context.fetchCount(FetchDescriptor<M>())) ?? -1
        }
        let liveOutbox = (try? context.fetch(FetchDescriptor<SyncOutbox>()).filter { $0.rejectedReason == nil }.count) ?? -1
        dryRunSummary = """
        TX \(count(TransactionItem.self)) · Cat \(count(Category.self)) · Sub \(count(Subcategory.self)) · \
        Acc \(count(Account.self)) · Budget \(count(Budget.self)) · Sched \(count(ScheduledPayment.self))
        Identidades \(count(SyncIdentity.self)) · Outbox vivo \(liveOutbox)
        """
    }

    /// Lee el journal + testigos vivos (sin mutar nada).
    func refresh() {
        quiescent = iCloudSyncService.shared.isImportQuiescent
        mountedModeLabel = SwiftDataConfiguration.personalStoreMountedMode.rawValue
        persistedModeLabel = StorageModePersistence.read().rawValue
        relaunchRequested = UserDefaults.standard.bool(forKey: MigrationWorkExecutor.relaunchRequestedKey)
        var descriptor = FetchDescriptor<MigrationState>()
        descriptor.fetchLimit = 1
        guard let state = try? context.fetch(descriptor).first else {
            phaseLabel = "notStarted (sin journal)"
            pendingEffectsLabel = "—"; countersLabel = "—"; cursorLabel = "—"; startedAtLabel = "—"
            return
        }
        phaseLabel = "\(state.readPhase().phase)"
        let pending = state.readPendingEffects().map(\.rawValue)
        pendingEffectsLabel = pending.isEmpty ? "—" : pending.joined(separator: ", ")
        countersLabel = "mismatch \(state.verifyMismatchRetries) · red \(state.verifyNetworkRetries) · leader \(state.leaderDeviceID ?? "—") · seqCut \(state.serverSeqCut)"
        cursorLabel = state.snapshotCursorJSON ?? "—"
        startedAtLabel = state.startedAt.map { $0.formatted(date: .omitted, time: .standard) } ?? "—"
    }
}

struct CloudSyncDebugView: View {
    @State private var model = CloudSyncDebugModel()
    @State private var spike = SpikeS5Harness()
    @State private var spike6 = SpikeS6Harness()
    @State private var migration: CloudSyncMigrationPanelModel?
    @State private var confirmStartReal = false
    @State private var confirmStartReal2 = false
    @State private var confirmEscapeHatch = false
    // Spike S7: override de fase simulada (nil = sin override = producción `.notStarted`) + quiescencia
    // viva (refrescada cada 1s) para mostrar en vivo la decisión del gate §i.9.
    @State private var selectedS7Phase: MigrationPhaseStore.SimulatedPhase?
    @State private var s7Quiescent = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                stateCard
                actionsCard
                migrationCard
                spikeS5Card
                spikeS6Card
                spikeS7Card
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
            // Spike S5: re-encuentra la TX desechable de un run anterior (el estado del harness
            // no sobrevive al relaunch, pero la TX sí) → habilita ir directo al paso 2.
            spike.recoverDisposableIfNeeded(context: modelContext)
            await model.refreshAttest()
            await model.refreshCredential()
        }
        .task {
            // Spike S6: cabecera de estado viva (quiescencia + conteo de 🧟/🧪 + sub-estado). Refresco
            // cada 1s — aceptable para tooling DEBUG. Se detiene al cancelarse el .task de la vista.
            while !Task.isCancelled {
                spike6.refreshHeader(context: modelContext)
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
            }
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
            Text("Salida MANUAL mientras no exista la reversa (I11): devuelve el device a iCloud y borra el journal. RELANZA después. NO es 'forzar done'.")
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
                    Label("Forzar storageMode=.icloud + limpiar journal", systemImage: "arrow.uturn.backward")
                        .font(DS.Typography.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(migration.isWorking)

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

    private var actionsCard: some View {
        VStack(spacing: DS.Spacing.sm) {
            actionButton("Sign in with Apple", disabled: !model.isConfigured) {
                await model.signIn()
            }
            actionButton("Claim account", disabled: !model.isConfigured) {
                await model.claim()
            }
            actionButton("Sign out", disabled: !model.isConfigured) {
                await model.signOut()
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Spike S5 (captura de CKRecord.ID + delete dirigido)

    private var spikeS5Card: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Spike S5 · captura de CKRecord.ID + delete")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Harness DEBUG device-only. Corre los pasos EN ORDEN. Espera 30-60s tras el paso 1 (export del mirror) antes del paso 2.")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)

            VStack(spacing: DS.Spacing.sm) {
                spikeButton("1 · Crear TX desechable", disabled: false) {
                    spike.createDisposable(context: modelContext)
                }
                spikeButton("2 · Capturar IDs (A y B)", disabled: !spike.hasDisposable) {
                    await spike.captureDisposable(context: modelContext)
                }
                spikeButton("3 · Borrar de CloudKit", disabled: !spike.hasCapture) {
                    await spike.deleteFromCloudKit()
                }
                spikeButton("4 · Verificar gone", disabled: !spike.deleteAttempted) {
                    await spike.verifyGone()
                }
            }

            Divider()

            VStack(spacing: DS.Spacing.sm) {
                spikeButton("Capturar sobre TX existente (solo lectura)", disabled: false) {
                    await spike.captureOldestExisting(context: modelContext)
                }
                spikeButton("Limpiar TX local", disabled: !spike.hasDisposable) {
                    spike.clearLocalDisposable(context: modelContext)
                }
            }

            HStack {
                Text("Log")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Limpiar log") { spike.clearLog() }
                    .font(DS.Typography.caption)
                    .disabled(spike.isWorking)
            }

            ScrollView {
                Text(spike.log.isEmpty ? "— sin resultados aún —" : spike.log)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 280)
            .padding(DS.Spacing.sm)
            .background(.thBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Spike S6 (remontaje del mirror + reverseReconcile gateado, resumible)

    private var spikeS6Card: some View {
        @Bindable var spike6 = spike6
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Spike S6 · remontaje del mirror")
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Harness DEBUG device-only. El arg -spike-s6-mirror-off monta el store PERSONAL sin mirror (mismo archivo). Sigue el guion: [0] con mirror ON → añade el arg → [A] → quita el arg (REMONTAJE) → [B].")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)

            spikeS6Header

            VStack(spacing: DS.Spacing.sm) {
                spike6Button("0 · Preparar zombies (mirror ON)", disabled: spike6.mirrorOff) {
                    spike6.prepareZombies(context: modelContext)
                }
                spike6Button("A · Divergencia offline (mirror OFF)", disabled: !spike6.mirrorOff) {
                    spike6.divergeOffline(context: modelContext)
                }
                spike6Button("B · reverseReconcile simulado (gateado)", disabled: spike6.mirrorOff) {
                    await spike6.runReverseReconcile(context: modelContext)
                }
            }

            Toggle(isOn: $spike6.killAfterNextJournal) {
                Text("Parar tras journalear el siguiente sub-estado (simula kill)")
                    .font(DS.Typography.caption.weight(.medium))
            }
            .disabled(spike6.isWorking)

            Divider()

            VStack(spacing: DS.Spacing.sm) {
                spike6Button("Verificar invariantes", disabled: false) {
                    spike6.verifyInvariants(context: modelContext)
                }
                spike6Button("Reset spike", disabled: false) {
                    spike6.resetSpike(context: modelContext)
                }
            }

            HStack {
                Text("Log")
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Limpiar log") { spike6.clearLog() }
                    .font(DS.Typography.caption)
                    .disabled(spike6.isWorking)
            }

            ScrollView {
                Text(spike6.log.isEmpty ? "— sin resultados aún —" : spike6.log)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 280)
            .padding(DS.Spacing.sm)
            .background(.thBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var spikeS6Header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            row("Mirror", spike6.mirrorOff ? "OFF (-spike-s6-mirror-off)" : "ON (normal)")
            row("Quiescent", spike6.quiescentNow ? "SÍ · isImportQuiescent" : "NO")
            row("Sub-estado", spike6.journaledSubState)
            row("🧟 zombies", "\(spike6.zombieCount)")
            row("🧪 markers", "\(spike6.markerCount)")
            if let e = spike6.headerError {
                row("Error", e)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.sm)
        .background(.thBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
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

    private func spike6Button(
        _ title: String, disabled: Bool, action: @escaping () async -> Void
    ) -> some View {
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
        .disabled(disabled || spike6.isWorking)
    }

    private func spikeButton(
        _ title: String, disabled: Bool, action: @escaping () async -> Void
    ) -> some View {
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
        .disabled(disabled || spike.isWorking)
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
