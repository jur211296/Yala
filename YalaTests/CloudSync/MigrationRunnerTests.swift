//
//  MigrationRunnerTests.swift
//  YalaTests / CloudSync
//
//  Orquestador JOURNAL-THEN-EXECUTE de la migración (I10-wiring, ciclo A / w2). Fake executor
//  guionizado + container ON-DISK temp con los 3 stores (patrón CloudSyncRuntimeTests, `.serialized`).
//  Cubre: camino feliz completo, kill-resume por fase durable, re-claim same-device, las 3 traducciones
//  del follower, S9 (contadores independientes / mismatch limpia cursor / topes → rollback / newDelta no
//  consume), par inválido, gate de quiescencia, efecto que lanza → journaled → resume lo re-ejecuta,
//  el contrato especial `.disableMirrorAndRelaunch` (ambas ramas), y claim no-success (los 3 outcomes).
//
//  C-1 (sección 9c): precondición de ENTRADA del canal iCloud en sus dos puertas, tope por TIEMPO del paso 4
//  (iCloud lleno / sin cuenta → abort a `.icloud` sin apagar el mirror), waiver `noChannelNoFootprint`, sello
//  ÚNICO del reloj del tope, y el drenaje de `resetAfterRollback` (ambas mitades del contrato).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Fake executor guionizado

@MainActor
private final class FakeExecutor: MigrationWorkExecuting {

    // Claim: cola de outcomes (el último se repite si se agota).
    var claimOutcomes: [ClaimOutcome] = [.success(.created)]
    private var claimIndex = 0
    var claimCallCount = 0

    // Identity.
    var assignIdentityError: (any Error)?
    var assignIdentityCallCount = 0

    // Snapshot: cola de outcomes.
    var uploadOutcomes: [SnapshotStepOutcome] = [.completed]
    private var uploadIndex = 0
    var uploadCursorsSeen: [String?] = []

    // Verify: cola de probes.
    var verifyProbes: [VerifyProbe] = [.match]
    private var verifyIndex = 0

    var confirmCutoverResult = true
    var persistLocalModeResult = true
    /// C-1: los pasos 1 y 2 del cutover son los ÚNICOS que dejan huella durable antes del marcador
    /// (`migrated_at` en el backend y `storageMode = .cloud` en el device). Contarlos es lo que prueba que la
    /// precondición de entrada aborta ANTES de tocarlos — es decir, que el bug ya no puede ni empezar.
    var confirmCutoverCallCount = 0
    var persistLocalModeCallCount = 0

    /// C-1: veredicto guionizado del canal iCloud. `.healthy` es el default de la extension del protocolo, así
    /// que un fake que no lo toca se comporta EXACTAMENTE como antes de C-1.
    var icloudVerdict: ICloudChannelVerdict = .healthy
    var icloudProbeCallCount = 0

    // Reversa (§h, I11-2).
    var reverseClaimOutcomes: [ReverseClaimOutcome] = [.accepted]
    private var reverseClaimIndex = 0
    var reverseClaimCallCount = 0
    /// Cola, no un valor único: el test de «vuelve a entrar y la vuelta sigue» necesita que el MISMO paso conteste
    /// distinto en el segundo resume (ticket `reverse-before-mount-stays-stuck-with-an-expired-session`).
    var reverseDrainOutcomes: [ReverseStepOutcome] = [.completed]
    private var reverseDrainIndex = 0
    var reverseDrainCallCount = 0
    var freezeBackendOutcomes: [ReverseStepOutcome] = [.completed]
    private var freezeBackendIndex = 0
    var freezeBackendCallCount = 0
    /// `isMirrorConfirmedOn()` — fake-able (el real reporta `.icloud` SIEMPRE en tests = false green).
    var mirrorOn = false
    /// Ejecutar `.mountMirrorAndRelaunch` monta el mirror (simula el relaunch surtiendo efecto).
    var setMirrorOnOnMount = true
    var sweepOutcome: ZombieSweepOutcome = .completed(deleted: 0)
    var sweepCallCount = 0
    var verifyRebindsResult = 0
    var healDuplicatesResult = 0
    var reverseUploadStatuses: [ReverseUploadStatus] = [.drained]
    private var reverseUploadIndex = 0
    /// Techo de `reverseUpload`: causa guionizada. `.unknown` es el default de la extension del protocolo.
    var reverseBlocker: ReverseUploadBlocker = .unknown

    // Efectos.
    var executedEffects: [MigrationEffect] = []
    /// Todo `execute` que se INTENTÓ, incluidos los que lanzaron. Lo pide la salida previa al montaje: ahí el
    /// `reverse_abort` es best-effort y lo que hay que medir es que se intentó UNA vez, no que saliera bien.
    var executeAttempts: [MigrationEffect] = []
    var effectErrors: [MigrationEffect: any Error] = [:]
    /// Ejecutar `.disableMirrorAndRelaunch` pone el mirror OFF (simula el relaunch surtiendo efecto).
    var setMirrorOffOnDisable = true
    var mirrorOff = false
    /// Ejecutar `.writeCloudKitMarker` marca el marcador EXPORTADO (simula el export async completando) →
    /// el gate `isMarkerExported()` deja avanzar. Ponerlo `false` prueba que el gate CORTA retomable.
    var setMarkerExportedOnWrite = true
    var markerExported = false

    /// Cuántas veces pidió el runner deshacer el sello del último claim (`ForwardClaimIntent.migrateOnly`).
    var discardStampCallCount = 0
    func discardLastClaimStamp() { discardStampCallCount += 1 }

    func performClaim() async -> ClaimOutcome {
        claimCallCount += 1
        // Suspensión REAL: fuerza el interleaving que el guard de reentrada (S1) debe cortar — sin
        // esto, en MainActor la primera invocación correría a término antes de que arranque la segunda
        // y el test de reentrada pasaría trivialmente aun sin guard.
        await Task.yield()
        guard !claimOutcomes.isEmpty else { return .transient(detail: "fake sin guion") }
        let outcome = claimOutcomes[min(claimIndex, claimOutcomes.count - 1)]
        claimIndex += 1
        return outcome
    }

    func assignIdentity() async throws {
        assignIdentityCallCount += 1
        if let error = assignIdentityError { throw error }
    }

    func uploadSnapshot(cursor: String?) async -> SnapshotStepOutcome {
        uploadCursorsSeen.append(cursor)
        guard !uploadOutcomes.isEmpty else { return .transient }   // M3: guion vacío no trapea
        let outcome = uploadOutcomes[min(uploadIndex, uploadOutcomes.count - 1)]
        uploadIndex += 1
        return outcome
    }

    func verify() async -> VerifyProbe {
        guard !verifyProbes.isEmpty else { return .networkTimeout }   // M3: guion vacío no trapea
        let probe = verifyProbes[min(verifyIndex, verifyProbes.count - 1)]
        verifyIndex += 1
        return probe
    }

    func confirmCutoverServer() async -> Bool { confirmCutoverCallCount += 1; return confirmCutoverResult }
    func persistLocalMode() async -> Bool { persistLocalModeCallCount += 1; return persistLocalModeResult }

    func execute(_ effect: MigrationEffect) async throws {
        executeAttempts.append(effect)                        // se INTENTÓ, lance o no
        if let error = effectErrors[effect] { throw error }   // NO se marca ejecutado si lanza
        executedEffects.append(effect)
        if effect == .disableMirrorAndRelaunch, setMirrorOffOnDisable { mirrorOff = true }
        if effect == .writeCloudKitMarker, setMarkerExportedOnWrite { markerExported = true }
        if effect == .mountMirrorAndRelaunch, setMirrorOnOnMount { mirrorOn = true }
    }

    func isMirrorConfirmedOff() -> Bool { mirrorOff }
    func isMarkerExported() -> Bool { markerExported }

    // MARK: Canal iCloud (C-1)
    func probeICloudChannel() async -> ICloudChannelVerdict {
        icloudProbeCallCount += 1
        return icloudVerdict
    }

    // MARK: Reversa (§h)
    func performReverseClaim() async -> ReverseClaimOutcome {
        reverseClaimCallCount += 1
        await Task.yield()
        guard !reverseClaimOutcomes.isEmpty else { return .transient }
        let outcome = reverseClaimOutcomes[min(reverseClaimIndex, reverseClaimOutcomes.count - 1)]
        reverseClaimIndex += 1
        return outcome
    }
    func reverseDrainOnce() async -> ReverseStepOutcome {
        reverseDrainCallCount += 1
        guard !reverseDrainOutcomes.isEmpty else { return .transient }
        let outcome = reverseDrainOutcomes[min(reverseDrainIndex, reverseDrainOutcomes.count - 1)]
        reverseDrainIndex += 1
        return outcome
    }
    func freezeBackendForReverse() async -> ReverseStepOutcome {
        freezeBackendCallCount += 1
        guard !freezeBackendOutcomes.isEmpty else { return .transient }
        let outcome = freezeBackendOutcomes[min(freezeBackendIndex, freezeBackendOutcomes.count - 1)]
        freezeBackendIndex += 1
        return outcome
    }
    func isMirrorConfirmedOn() -> Bool { mirrorOn }
    func sweepZombies(sinceSeq: Int64) async -> ZombieSweepOutcome { sweepCallCount += 1; return sweepOutcome }
    func verifyRebinds() -> Int { verifyRebindsResult }
    func healDuplicates() -> Int { healDuplicatesResult }
    func reverseUploadStatus() -> ReverseUploadStatus {
        guard !reverseUploadStatuses.isEmpty else { return .drained }
        let status = reverseUploadStatuses[min(reverseUploadIndex, reverseUploadStatuses.count - 1)]
        reverseUploadIndex += 1
        return status
    }
    func reverseUploadBlocker() -> ReverseUploadBlocker { reverseBlocker }

    // Heartbeat del lease (I14-pre): registra las llamadas del runner. El throttle vive en el executor REAL
    // (MigrationWorkExecutorTests), así que aquí cada invocación cuenta 1:1 (el runner es el dueño del pacing).
    var heartbeatCallCount = 0
    func sendLeaseHeartbeatIfDue() async { heartbeatCallCount += 1 }

    func count(_ effect: MigrationEffect) -> Int { executedEffects.filter { $0 == effect }.count }
    func attempts(_ effect: MigrationEffect) -> Int { executeAttempts.filter { $0 == effect }.count }
}

private struct FakeError: Error {}

/// Reloj MUTABLE (molde de `MigrationWorkExecutorTests`): permite AVANZAR el tiempo entre resumes sin recrear
/// nada. Es lo único con lo que se puede vencer el presupuesto por TIEMPO del paso 4 (C-1) de forma
/// determinista — el `fixedNow` de los demás tests deja el `elapsed` clavado en 0 para siempre.
@MainActor
private final class MutableClock {
    var value: Date
    init(_ start: Date) { value = start }
}

// MARK: - Suite

@Suite("MigrationRunner · orquestador (I10-wiring w2)", .serialized)
@MainActor
struct MigrationRunnerTests {

    typealias Phase = MigrationPhase
    typealias Sub = CutoverSubstate
    typealias Effect = MigrationEffect

    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)
    private let deviceID = "device-1"

    // MARK: Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MRunner-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "MR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "MR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "MR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func makeRunner(
        _ context: ModelContext,
        _ executor: FakeExecutor,
        quiescence: @escaping () -> Bool = { true },
        policy: MigrationPolicy = .default,
        timeout: Double = 120,
        tick: Double = 0.5,
        // C-1: reloj inyectable (default = `fixedNow`, idéntico a antes). Solo los tests del tope del paso 4
        // pasan un `MutableClock` para poder avanzar el tiempo.
        now: (() -> Date)? = nil
    ) -> MigrationRunner {
        MigrationRunner(
            context: context, executor: executor, deviceID: deviceID, policy: policy,
            quiescenceSignal: quiescence, now: now ?? { self.fixedNow }, sleeper: { _ in },
            quiescenceTimeoutSeconds: timeout, quiescenceTickSeconds: tick)
    }

    @discardableResult
    private func seedJournal(
        _ context: ModelContext, phase: Phase, pending: [Effect] = [],
        leaderDeviceID: String? = nil, mismatchRetries: Int = 0, networkRetries: Int = 0,
        snapshotCursor: String? = nil, reverseOriginRaw: String? = nil,
        // C-1: los 2 campos aditivos del journal (reloj del tope del paso 4 + veredicto del canal iCloud).
        markerWrittenSince: Date? = nil, cutoverICloudVerdictRaw: String? = nil,
        // Techo de `reverseUpload`: cifra más baja, reloj del último avance y motivo de la última salida.
        reverseUploadLowestPending: Int? = nil, reverseUploadProgressAt: Date? = nil,
        reverseAbortReasonRaw: String? = nil,
        // Techo de las cuatro fases previas al montaje: el reloj y la fase en la que se selló.
        reversePreMountProgressAt: Date? = nil, reversePreMountPhaseRaw: String? = nil,
        // La intención del claim de la ida (ticket `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`).
        forwardClaimIntentRaw: String? = nil
    ) throws -> MigrationState {
        let state = MigrationState()
        state.setPhase(phase)
        state.setPendingEffects(pending)
        state.leaderDeviceID = leaderDeviceID
        state.verifyMismatchRetries = mismatchRetries
        state.verifyNetworkRetries = networkRetries
        state.snapshotCursorJSON = snapshotCursor
        state.reverseOriginRaw = reverseOriginRaw
        state.markerWrittenSince = markerWrittenSince
        state.cutoverICloudVerdictRaw = cutoverICloudVerdictRaw
        state.reverseUploadLowestPending = reverseUploadLowestPending
        state.reverseUploadProgressAt = reverseUploadProgressAt
        state.reverseAbortReasonRaw = reverseAbortReasonRaw
        state.reversePreMountProgressAt = reversePreMountProgressAt
        state.reversePreMountPhaseRaw = reversePreMountPhaseRaw
        state.forwardClaimIntentRaw = forwardClaimIntentRaw
        state.startedAt = fixedNow
        state.updatedAt = fixedNow
        context.insert(state)
        try context.save()
        return state
    }

    private func journal(_ context: ModelContext) throws -> MigrationState {
        var descriptor = FetchDescriptor<MigrationState>()
        descriptor.fetchLimit = 1
        return try #require(try context.fetch(descriptor).first)
    }

    // MARK: - 1. Camino feliz notStarted → done

    @Test func happyPath_reachesDone_withExactEffectSequence() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.created)]
        fake.uploadOutcomes = [.completed]
        fake.verifyProbes = [.match]
        let runner = makeRunner(context, fake)

        await runner.startMigration(dryRun: false)
        #expect(try journal(context).readPhase().phase == .consent)

        await runner.submit(.consentAccepted)
        #expect(try journal(context).readPhase().phase == .authenticating)

        await runner.submit(.signInSucceeded)   // → drive autónomo hasta done
        let final = try journal(context)
        #expect(final.readPhase().phase == .done)
        #expect(final.readPendingEffects().isEmpty)
        #expect(fake.executedEffects == [
            .writeBeacon, .startParallelHistoryCapture, .writeCloudKitMarker,
            .disableMirrorAndRelaunch, .runLeaderReconcileFromFrozenCloudKit,
        ], "orden estricto de efectos observables del §g.4")
    }

    // MARK: - 2. Kill-resume: efecto residual journaled se ejecuta EXACTAMENTE una vez

    @Test func killResume_residualPendingEffect_executesExactlyOnce() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.transient]      // corta el drive justo tras el drenaje del residual

        // Kill simulado: journal en assigningIdentity con writeBeacon pendiente sin ejecutar.
        try seedJournal(context, phase: .assigningIdentity, pending: [.writeBeacon],
                        leaderDeviceID: deviceID)

        let runner = makeRunner(context, fake)
        await runner.resume()

        #expect(fake.count(.writeBeacon) == 1, "el efecto residual se ejecuta exactamente una vez")
        #expect(fake.assignIdentityCallCount == 1)
        let j = try journal(context)
        #expect(j.readPhase().phase == .uploadingSnapshot)
        #expect(j.readPendingEffects().isEmpty)
    }

    // MARK: - 3. Re-claim same-device tras kill (B1: el backend colapsa; el cliente JAMÁS auto-promueve)

    /// El backend colapsa el re-claim del MISMO líder a `created` (golden 4 de account.goldens.test.ts)
    /// → el camino feliz del re-claim tras kill es un `created` que avanza como líder.
    @Test func reclaimSameDevice_backendCollapsesToCreated_advancesAsLeader() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.created)]   // colapso del backend (reclaim idempotente)
        fake.uploadOutcomes = [.transient]          // corta en uploadingSnapshot

        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID)

        let runner = makeRunner(context, fake)
        await runner.resume()

        #expect(fake.claimCallCount == 1)
        #expect(fake.count(.writeBeacon) == 1, "el re-claim colapsado a created avanza como líder")
        #expect(try journal(context).readPhase().phase == .uploadingSnapshot)
    }

    /// B1 (review adversarial): `claiming_in_progress` recibido significa SIEMPRE "otro device lidera"
    /// — aunque el journal local tenga `leaderDeviceID == deviceID` (intent pre-POST de un intento cuyo
    /// POST falló transient ANTES de crear la fila, y otro device reclamó en medio). El runner JAMÁS
    /// se auto-promueve: va a `waitingForLeader` (nunca 2º líder / doble beacon).
    @Test func staleLeaderIntent_claimingInProgress_becomesFollower_neverSecondLeader() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.claimingInProgress)]

        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID)

        let runner = makeRunner(context, fake)
        await runner.resume()

        #expect(fake.count(.writeBeacon) == 0, "JAMÁS beacon de líder con otro device liderando")
        #expect(try journal(context).readPhase().phase == .waitingForLeader)
    }

    // MARK: - 4. Follower: las 3 traducciones del poll

    @Test func follower_existingStable_adoptsAndBowsOut() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.existingStable)]
        try seedJournal(context, phase: .waitingForLeader)

        let runner = makeRunner(context, fake)
        await runner.pollLeader()

        #expect(fake.claimCallCount == 1)
        #expect(fake.executedEffects == [.adoptBackendAccount])
        #expect(try journal(context).readPhase().phase == .notStarted)
    }

    @Test func follower_claimingInProgress_keepsWaiting_noEvent() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.claimingInProgress)]
        try seedJournal(context, phase: .waitingForLeader)

        let runner = makeRunner(context, fake)
        await runner.pollLeader()

        #expect(fake.claimCallCount == 1)
        #expect(fake.executedEffects.isEmpty)
        #expect(try journal(context).readPhase().phase == .waitingForLeader)
    }

    @Test func follower_created_reclaimsLeadership_withoutSecondPost() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.created)]
        fake.uploadOutcomes = [.transient]
        try seedJournal(context, phase: .waitingForLeader)

        let runner = makeRunner(context, fake)
        await runner.pollLeader()

        #expect(fake.claimCallCount == 1, "created NO re-postea: reusa el resultado ya obtenido")
        #expect(fake.count(.writeBeacon) == 1, "leaderVanished → claimResult(.created) → líder")
        let phase = try journal(context).readPhase().phase
        #expect(phase == .uploadingSnapshot || phase == .assigningIdentity)
    }

    // MARK: - 5. S9 (contadores independientes / cursor / topes / newDelta)

    @Test func s9_networkTimeouts_incrementOnlyNetworkCounter_thenRollbackAtCap() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.networkTimeout, .networkTimeout, .networkTimeout]
        try seedJournal(context, phase: .verifying)

        let runner = makeRunner(context, fake, policy: MigrationPolicy(maxMismatchRetries: 3, maxNetworkRetries: 2))

        // ANTI tight-loop: cada resume gasta A LO SUMO un retry de red y CORTA retomable (el pacing lo
        // da el próximo resume externo — S9: un túnel no debe quemar el presupuesto en segundos).
        await runner.resume()
        var j = try journal(context)
        #expect(j.verifyNetworkRetries == 1, "un resume = a lo sumo UN retry de red")
        #expect(j.readPhase().phase == .verifying)

        await runner.resume()
        j = try journal(context)
        #expect(j.verifyNetworkRetries == 2)
        #expect(j.readPhase().phase == .verifying)

        await runner.resume()   // tope alcanzado → failedRollback
        j = try journal(context)
        #expect(j.verifyMismatchRetries == 0, "el contador de mismatch NO se toca")
        #expect(j.readPhase().phase == .failedRollback)
        #expect(fake.executedEffects.contains(.rollback))
        // S2: al entrar a failedRollback se limpian los campos scoped (contadores incluidos).
        #expect(j.verifyNetworkRetries == 0, "failedRollback limpia los campos scoped en el mismo save")
        #expect(j.leaderDeviceID == nil)
    }

    // MARK: - 5-bis. Reset explícito tras rollback (S2) + guard de reentrada (S1)

    @Test func resetAfterRollback_clearsJournal_andEnablesFreshStart() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .failedRollback, leaderDeviceID: "otro-intento",
                        mismatchRetries: 3, networkRetries: 8, snapshotCursor: "stale")

        let runner = makeRunner(context, fake)
        // startMigration desde failedRollback es .invalid (la máquina no tiene esa arista) → no-op.
        await runner.startMigration(dryRun: false)
        #expect(try journal(context).readPhase().phase == .failedRollback)

        await runner.resetAfterRollback()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.leaderDeviceID == nil)
        #expect(j.verifyMismatchRetries == 0)
        #expect(j.verifyNetworkRetries == 0)
        #expect(j.snapshotCursorJSON == nil)
        #expect(j.startedAt == nil)

        // Y una migración fresca arranca limpia.
        await runner.startMigration(dryRun: false)
        #expect(try journal(context).readPhase().phase == .consent)
    }

    @Test func resetAfterRollback_outsideFailedRollback_isNoOp() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .verifying, networkRetries: 3)

        let runner = makeRunner(context, fake)
        await runner.resetAfterRollback()

        let j = try journal(context)
        #expect(j.readPhase().phase == .verifying, "reset SOLO desde failedRollback")
        #expect(j.verifyNetworkRetries == 3)
    }

    @Test func reentrancy_concurrentSubmit_secondInvocationIsNoOp() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.created)]
        fake.uploadOutcomes = [.transient]
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID)

        let runner = makeRunner(context, fake)
        // Doble invocación concurrente (double-tap del panel): a lo sumo UNA corre; cero doble POST.
        async let first: Void = runner.resume()
        async let second: Void = runner.resume()
        _ = await (first, second)

        #expect(fake.claimCallCount == 1, "guard de reentrada: un solo POST de claim")
        #expect(fake.count(.writeBeacon) == 1, "un solo beacon")
    }

    @Test func s9_mismatch_goesToUpload_andClearsCursor() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.mismatch]
        fake.uploadOutcomes = [.transient]      // corta en uploadingSnapshot para inspeccionar
        try seedJournal(context, phase: .verifying, snapshotCursor: "stale-cursor")

        let runner = makeRunner(context, fake)
        await runner.resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .uploadingSnapshot)
        #expect(j.verifyMismatchRetries == 1)
        #expect(j.snapshotCursorJSON == nil, "mismatch limpia el cursor (re-upload fresco)")
    }

    @Test func s9_mismatchAtCap_rollsBack() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.mismatch]
        try seedJournal(context, phase: .verifying, mismatchRetries: 1)

        let runner = makeRunner(context, fake, policy: MigrationPolicy(maxMismatchRetries: 1, maxNetworkRetries: 8))
        await runner.resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(fake.executedEffects.contains(.rollback))
    }

    @Test func s9_newDelta_doesNotConsumeRetry() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.newDeltaDetected, .match]
        fake.confirmCutoverResult = false       // corta en cutover(.pending)
        try seedJournal(context, phase: .verifying)

        let runner = makeRunner(context, fake)
        await runner.resume()

        let j = try journal(context)
        #expect(j.verifyMismatchRetries == 0)
        #expect(j.verifyNetworkRetries == 0)
        #expect(j.readPhase().phase == .cutover(.pending), "newDelta re-corre verify sin gastar retry")
    }

    // MARK: - 6. Par inválido → breadcrumb + no-op, journal intacto

    @Test func invalidPair_isNoOp_journalUntouched() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        let runner = makeRunner(context, fake)

        // notStarted + snapshotUploaded es un par ilegal → invalid; drive vuelve enseguida (notStarted).
        await runner.submit(.snapshotUploaded)

        #expect(try journal(context).readPhase().phase == .notStarted)
        #expect(try journal(context).readPendingEffects().isEmpty)
        #expect(fake.claimCallCount == 0)
        #expect(fake.executedEffects.isEmpty)
    }

    // MARK: - 7. Gate de quiescencia

    @Test func quiescenceGate_blocksAllWork_untilSignalTrue() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()

        var quiescent = false
        let runner = makeRunner(context, fake, quiescence: { quiescent }, timeout: 1, tick: 0.5)

        // Señal false: ni una fila de journal, ni una llamada al executor (tope alcanzado → retomable).
        await runner.startMigration(dryRun: false)
        #expect(try context.fetchCount(FetchDescriptor<MigrationState>()) == 0, "sin quiescencia NO se escribe el journal")
        #expect(fake.claimCallCount == 0)

        // Señal true: procede.
        quiescent = true
        await runner.startMigration(dryRun: false)
        #expect(try journal(context).readPhase().phase == .consent)
    }

    // MARK: - 8. Efecto que lanza → journaled; resume lo re-ejecuta

    @Test func effectThrows_staysJournaled_resumeReExecutesOnce() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.created)]
        fake.effectErrors[.writeBeacon] = FakeError()      // el primer intento lanza
        fake.uploadOutcomes = [.transient]
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID)

        let runner1 = makeRunner(context, fake)
        await runner1.resume()

        // Journaled + stop: fase assigningIdentity, writeBeacon pendiente y NO ejecutado.
        var j = try journal(context)
        #expect(j.readPhase().phase == .assigningIdentity)
        #expect(j.readPendingEffects() == [.writeBeacon])
        #expect(fake.count(.writeBeacon) == 0)

        // Resume tras "arreglar" el efecto (nueva instancia de runner sobre el mismo store).
        fake.effectErrors.removeValue(forKey: .writeBeacon)
        let runner2 = makeRunner(context, fake)
        await runner2.resume()

        #expect(fake.count(.writeBeacon) == 1, "resume re-ejecuta el efecto exactamente una vez")
        j = try journal(context)
        #expect(j.readPendingEffects().isEmpty)
        #expect(j.readPhase().phase == .uploadingSnapshot)
    }

    // MARK: - 9. Contrato especial .disableMirrorAndRelaunch en resume (ambas ramas)

    @Test func resumeRelaunch_mirrorConfirmedOff_completesWithoutReExecuting() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.mirrorOff = true                    // el relaunch YA surtió efecto
        try seedJournal(context, phase: .cutover(.mirrorOff), pending: [.disableMirrorAndRelaunch],
                        leaderDeviceID: deviceID)

        let runner = makeRunner(context, fake)
        await runner.resume()

        #expect(fake.count(.disableMirrorAndRelaunch) == 0, "NO se re-ejecuta el relaunch (resuelto por observación)")
        #expect(fake.executedEffects.contains(.runLeaderReconcileFromFrozenCloudKit))
        let j = try journal(context)
        #expect(j.readPhase().phase == .done)
        #expect(j.readPendingEffects().isEmpty)
    }

    @Test func resumeRelaunch_mirrorStillOn_reExecutesOnce_noLoop() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.mirrorOff = false                   // kill antes de que el relaunch surtiera efecto
        fake.setMirrorOffOnDisable = true        // re-ejecutar el efecto lo apaga (relaunch funciona ahora)
        try seedJournal(context, phase: .cutover(.mirrorOff), pending: [.disableMirrorAndRelaunch],
                        leaderDeviceID: deviceID)

        let runner = makeRunner(context, fake)
        await runner.resume()

        #expect(fake.count(.disableMirrorAndRelaunch) == 1, "re-ejecuta el relaunch EXACTAMENTE una vez, sin loop")
        #expect(try journal(context).readPhase().phase == .done)
    }

    // MARK: - 9b. Gate de EXPORT del marcador (§g.4, entre paso 3 y 4)

    @Test func markerExportGate_holdsBeforeMirrorOff_untilExported() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.setMarkerExportedOnWrite = false     // el marcador se escribe pero AÚN no llega a CloudKit
        try seedJournal(context, phase: .cutover(.localModeSet), leaderDeviceID: deviceID)

        let runner = makeRunner(context, fake)
        await runner.resume()

        // El marcador se escribió, pero el mirror NO se apaga hasta que el export confirme.
        #expect(fake.count(.writeCloudKitMarker) == 1)
        #expect(fake.count(.disableMirrorAndRelaunch) == 0, "el gate corta ANTES de apagar el mirror")
        #expect(try journal(context).readPhase().phase == .cutover(.markerWritten), "se queda retomable en markerWritten")

        // Confirmado el export → un resume posterior avanza sin re-escribir el marcador.
        fake.markerExported = true
        let runner2 = makeRunner(context, fake)
        await runner2.resume()

        #expect(fake.count(.writeCloudKitMarker) == 1, "el marcador NO se re-escribe")
        #expect(fake.count(.disableMirrorAndRelaunch) == 1)
        #expect(try journal(context).readPhase().phase == .done)
    }

    // MARK: - 9c. C-1 · canal iCloud del cutover (precondición de entrada + tope por TIEMPO del paso 4)

    /// iCloud LLENO en el paso 4. El marcador no exporta y CloudKit ya dictó que el write no entra
    /// (`quotaExceeded` ⇒ presupuesto `.definitive` de 15 min): pasado el presupuesto el cutover ABORTA en
    /// local y el device vuelve a iCloud. Pinnea las 4 cosas que impiden la doble escritura indefinida:
    /// el terminal, el ORDEN de la tripleta (el `.persistICloudMode` PRIMERO es lo que deshace la mitad
    /// peligrosa —`.cloud` + mirror-off desarmado— antes de que nada más pueda fallar), que el mirror NUNCA se
    /// apagó, y que el veredicto SOBREVIVE al terminal (sin él la UI del fallo solo podría decir un genérico
    /// en vez de "iCloud se quedó sin espacio").
    @Test func markerBudget_quotaExceeded_abortsToICloud_withoutTurningMirrorOff() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.markerExported = false                  // el marcador se escribió pero jamás llega a CloudKit
        fake.icloudVerdict = .quotaExceeded
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .cutover(.markerWritten), leaderDeviceID: deviceID,
                        markerWrittenSince: fixedNow)

        clock.value = fixedNow.addingTimeInterval(901)          // presupuesto `.definitive` (900 s) agotado
        await makeRunner(context, fake, now: { clock.value }).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(fake.executedEffects == [.persistICloudMode, .deleteCloudKitMarker, .rollback],
                "orden OBLIGATORIO: devolver el device a .icloud, borrar el marcador que ya miente, y rollback")
        #expect(fake.count(.disableMirrorAndRelaunch) == 0,
                "el mirror JAMÁS se apagó — el abort deja el device igual que estaba en iCloud")
        #expect(j.readPendingEffects().isEmpty, "la tripleta drenó completa")
        #expect(j.cutoverICloudVerdictRaw == "quotaExceeded",
                "el veredicto sobrevive a failedRollback: es lo único que le permite al fallo decir la verdad")
        #expect(j.markerWrittenSince == nil, "el reloj es SCOPED al intento y se limpia al cerrarlo")
    }

    /// SIN cuenta iCloud pero CON huella CloudKit en el paso 4 (`noAccountWithFootprint`): hay una copia viva
    /// del corpus a la que no podemos avisar del cutover y el canal para avisarle no existe ⇒ mismo abort
    /// definitivo. Se pinnea aparte del caso de cuota porque es el otro veredicto que el copy del fallo tiene
    /// que distinguir, y porque aquí la precondición de ENTRADA ya no se consulta: en el paso 4 quien manda es
    /// el tope por tiempo (del sub-estado `.serverConfirmed` en adelante el cutover no vuelve atrás por
    /// precondición).
    @Test func markerBudget_noAccountWithFootprint_abortsToICloud_sameOrderedTriple() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.markerExported = false
        fake.icloudVerdict = .noAccountWithFootprint
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .cutover(.markerWritten), leaderDeviceID: deviceID,
                        markerWrittenSince: fixedNow)

        clock.value = fixedNow.addingTimeInterval(901)
        await makeRunner(context, fake, now: { clock.value }).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(fake.executedEffects == [.persistICloudMode, .deleteCloudKitMarker, .rollback])
        #expect(fake.count(.disableMirrorAndRelaunch) == 0, "el mirror nunca se apagó")
        #expect(j.cutoverICloudVerdictRaw == "noAccountWithFootprint")
    }

    /// EL test del bug: la precondición de ENTRADA impide que el cutover EMPIECE cuando el canal está
    /// sabido-roto. `persistLocalMode` es quien escribía `storageMode = .cloud` y `confirmCutoverServer` quien
    /// estampaba `migrated_at`: CERO llamadas a ambos ⇒ no hay nada durable que deshacer y el limbo
    /// «`.cloud` persistido + mirror vivo» no puede nacer.
    @Test func cutoverEntry_channelBroken_neverPersistsCloudMode_norStampsServer() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.match]                 // el verify converge: el cutover iba a arrancar
        fake.icloudVerdict = .noAccountWithFootprint
        try seedJournal(context, phase: .verifying, leaderDeviceID: deviceID)

        await makeRunner(context, fake).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(fake.persistLocalModeCallCount == 0, "NUNCA se persiste storageMode = .cloud")
        #expect(fake.confirmCutoverCallCount == 0, "NUNCA se estampa migrated_at en el backend")
        #expect(fake.executedEffects == [.rollback],
                "abort de entrada = rollback pelado: no hay marcador ni modo que revertir")
        #expect(fake.count(.writeCloudKitMarker) == 0)
        #expect(j.markerWrittenSince == nil, "el paso 4 no se alcanzó: no hay reloj que sellar")
        #expect(j.cutoverICloudVerdictRaw == "noAccountWithFootprint")
    }

    /// La SEGUNDA puerta de la precondición: un kill entre el verify y el cutover deja el journal en
    /// `cutover(.pending)` y el resume entraría por ahí SIN pasar por la rama `.match` del verify. Sin esta
    /// puerta ese resume seguiría adelante y escribiría `.cloud`.
    @Test func cutoverEntry_secondDoorAtPending_afterKill_stillAborts() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.icloudVerdict = .quotaExceeded
        try seedJournal(context, phase: .cutover(.pending), leaderDeviceID: deviceID)

        await makeRunner(context, fake).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(fake.confirmCutoverCallCount == 0, "aborta ANTES del ack del server")
        #expect(fake.persistLocalModeCallCount == 0)
        #expect(fake.executedEffects == [.rollback])
        #expect(j.cutoverICloudVerdictRaw == "quotaExceeded")
    }

    /// WAIVER `noChannelNoFootprint` (sin cuenta iCloud Y sin huella CloudKit): no existe copia del corpus en
    /// CloudKit, así que el marcador es *indeliverable* Y *prescindible* ⇒ el cutover CONTINÚA. Es el caso que
    /// NO se puede degradar: la condición es PERMANENTE, así que abortar vetaría el modo nube para siempre a
    /// quien no usa iCloud ("necesitas iCloud para dejar de usar iCloud") y ningún reintento lo arreglaría.
    /// Se corre desde `verifying` a propósito: prueba a la vez que este veredicto NO bloquea la ENTRADA
    /// (fail-open) y que relaja el gate de EXPORT sin saltarse ninguna fase de la cadena.
    @Test func markerExportWaiver_noChannelNoFootprint_cutoverCompletesToDone() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.match]
        fake.setMarkerExportedOnWrite = false        // el marcador se escribe y NUNCA exporta
        fake.icloudVerdict = .noChannelNoFootprint
        try seedJournal(context, phase: .verifying, leaderDeviceID: deviceID)

        await makeRunner(context, fake).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .done, "el waiver no bloquea la entrada ni acorta la cadena de fases")
        #expect(fake.confirmCutoverCallCount == 1)
        #expect(fake.persistLocalModeCallCount == 1)
        #expect(fake.count(.disableMirrorAndRelaunch) == 1,
                "el mirror se apaga UNA vez pese a que el marcador nunca exportó")
        #expect(fake.executedEffects == [
            .startParallelHistoryCapture, .writeCloudKitMarker,
            .disableMirrorAndRelaunch, .runLeaderReconcileFromFrozenCloudKit,
        ], "misma secuencia del §g.4 desde el cutover, sin efectos extra")
        #expect(j.cutoverICloudVerdictRaw == "noChannelNoFootprint", "queda rastro del waiver en el journal")
    }

    /// BAJO presupuesto el paso 4 HOLDEA retomable (molde del `networkTimeout` del verify: cortar sin
    /// tight-loop y volver a observar en el próximo resume). Dos casos porque el presupuesto lo elige la CAUSA:
    /// `quotaExceeded` es `.definitive` (15 min) y a los 60 s aún espera; un atasco de causa DESCONOCIDA
    /// (`healthy` ⇒ `.unknown`, 72 h) a los 1000 s TAMBIÉN espera, aunque ya habría vencido el presupuesto
    /// corto — un snapshot subido y verificado no se tira por un túnel largo.
    @Test func markerBudget_underBudget_holdsResumable_perCause() async throws {
        for (verdict, elapsed): (ICloudChannelVerdict, Double) in [(.quotaExceeded, 60), (.healthy, 1000)] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.markerExported = false
            fake.icloudVerdict = verdict
            let clock = MutableClock(fixedNow)
            try seedJournal(context, phase: .cutover(.markerWritten), leaderDeviceID: deviceID,
                            markerWrittenSince: fixedNow)

            clock.value = fixedNow.addingTimeInterval(elapsed)
            await makeRunner(context, fake, now: { clock.value }).resume()

            let j = try journal(context)
            #expect(j.readPhase().phase == .cutover(.markerWritten),
                    "\(verdict.rawValue) a los \(elapsed)s sigue esperando (retomable)")
            #expect(fake.executedEffects.isEmpty, "holdear no ejecuta NADA: ni mirror-off ni rollback")
            #expect(j.markerWrittenSince == fixedNow, "observar no re-sella el reloj")
        }
    }

    /// TEST CRÍTICO del arreglo: el reloj del tope se sella UNA sola vez. Tres resumes consecutivos NO
    /// re-escriben `markerWrittenSince` — si lo re-sellaran, el `elapsed` volvería a 0 en cada vuelta, el
    /// presupuesto no vencería nunca y el limbo seguiría siendo eterno (= el bug intacto). La prueba de que el
    /// sello manda: con el reloj pasado el presupuesto, el resume siguiente SÍ aborta.
    @Test func markerBudget_clockSealedOnce_acrossResumes_thenExpires() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.setMarkerExportedOnWrite = false        // se escribe el marcador y nunca exporta
        fake.icloudVerdict = .quotaExceeded
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .cutover(.localModeSet), leaderDeviceID: deviceID)

        // Resume 1: escribe el marcador y SELLA el reloj al entrar al paso 4.
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).markerWrittenSince == fixedNow, "sello en la PRIMERA entrada al paso 4")
        #expect(try journal(context).readPhase().phase == .cutover(.markerWritten))

        // Resumes 2 y 3 con el reloj avanzando, siempre bajo el presupuesto de 900 s.
        for offset in [100.0, 200.0] {
            clock.value = fixedNow.addingTimeInterval(offset)
            await makeRunner(context, fake, now: { clock.value }).resume()
            let j = try journal(context)
            #expect(j.markerWrittenSince == fixedNow, "el resume a +\(offset)s NO re-sella el reloj")
            #expect(j.readPhase().phase == .cutover(.markerWritten))
        }
        #expect(fake.count(.writeCloudKitMarker) == 1, "el marcador no se re-escribe en los resumes")

        // Y el presupuesto SÍ vence — exactamente lo que un re-sello habría hecho imposible.
        clock.value = fixedNow.addingTimeInterval(901)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .failedRollback)
        #expect(fake.count(.disableMirrorAndRelaunch) == 0)
    }

    /// Journal escrito por un build ANTERIOR a C-1 (devices de dev): en el paso 4 sin `markerWrittenSince` el
    /// runner sella el reloj PEREZOSAMENTE en la primera observación y corta retomable. El presupuesto cuenta
    /// desde ese instante, NUNCA retroactivo — un sello retroactivo abortaría de golpe un cutover sano cuyo
    /// journal simplemente venía de la versión vieja.
    @Test func markerBudget_legacyJournalWithoutClock_sealsLazily_neverRetroactive() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.markerExported = false
        fake.icloudVerdict = .quotaExceeded
        let clock = MutableClock(fixedNow.addingTimeInterval(5_000))   // "tarde", pero sin desde-cuándo medir
        try seedJournal(context, phase: .cutover(.markerWritten), leaderDeviceID: deviceID)  // sin reloj

        await makeRunner(context, fake, now: { clock.value }).resume()

        var j = try journal(context)
        #expect(j.readPhase().phase == .cutover(.markerWritten), "la observación que sella NO degrada")
        #expect(j.markerWrittenSince == fixedNow.addingTimeInterval(5_000),
                "el reloj arranca AHORA, no retroactivo")
        #expect(fake.executedEffects.isEmpty)

        clock.value = clock.value.addingTimeInterval(901)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "desde el sello perezoso el presupuesto sí corre")
        #expect(fake.executedEffects == [.persistICloudMode, .deleteCloudKitMarker, .rollback])
    }

    /// C-1 en `resetAfterRollback`: el "Reintentar" de la UI DRENA los efectos pendientes ANTES de limpiar el
    /// journal. Si tirara el `.persistICloudMode` que dejó pendiente el abort, quedaría `notStarted` (fase
    /// ESTABLE, que pasa el gate del dominio) + `.cloud` persistido con el mirror vivo = exactamente la doble
    /// escritura que este arreglo mata.
    @Test func resetAfterRollback_drainsPendingEffects_beforeClearingJournal() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .failedRollback, pending: [.persistICloudMode, .rollback],
                        leaderDeviceID: deviceID, markerWrittenSince: fixedNow,
                        cutoverICloudVerdictRaw: "quotaExceeded")

        await makeRunner(context, fake).resetAfterRollback()

        let j = try journal(context)
        #expect(fake.executedEffects == [.persistICloudMode, .rollback],
                "los pendientes se EJECUTAN en orden, no se tiran")
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects().isEmpty)
        #expect(j.markerWrittenSince == nil, "el reset limpia el reloj del paso 4")
        #expect(j.cutoverICloudVerdictRaw == nil, "y el veredicto: tras el reset ya no hay nada que explicar")
    }

    /// La mitad dura del contrato anterior: si el drenaje LANZA, el journal queda INTACTO (fase, pendientes y
    /// campos sin tocar) y el tap se convierte en un REINTENTO del abort. Un reset que limpiara "de todas
    /// formas" perdería el `.persistICloudMode` para siempre y dejaría el device en `.cloud`.
    @Test func resetAfterRollback_drainThrows_leavesJournalIntact_tapRetriesTheAbort() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.effectErrors[.persistICloudMode] = FakeError()
        try seedJournal(context, phase: .failedRollback, pending: [.persistICloudMode, .rollback],
                        leaderDeviceID: deviceID, cutoverICloudVerdictRaw: "quotaExceeded")

        await makeRunner(context, fake).resetAfterRollback()

        var j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "el reset NO avanzó: sigue en el terminal del abort")
        #expect(j.readPendingEffects() == [.persistICloudMode, .rollback], "los pendientes siguen enteros")
        #expect(j.leaderDeviceID == deviceID, "nada del journal se limpió")
        #expect(j.cutoverICloudVerdictRaw == "quotaExceeded")
        #expect(fake.count(.persistICloudMode) == 0)
        #expect(fake.count(.rollback) == 0, "el drenaje corta en el primero: el orden se respeta")

        // El siguiente tap, ya sin el fallo, completa el abort y ENTONCES sí limpia.
        fake.effectErrors.removeValue(forKey: .persistICloudMode)
        await makeRunner(context, fake).resetAfterRollback()

        j = try journal(context)
        #expect(fake.executedEffects == [.persistICloudMode, .rollback])
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects().isEmpty)
        #expect(j.cutoverICloudVerdictRaw == nil)
    }

    // MARK: - 10. Claim no-success (los 3 outcomes) → journal intacto, sin evento, sin rollback

    @Test func claimNoSuccess_holdsInClaimingMigration_thenResumeReclaims() async throws {
        let outcomes: [ClaimOutcome] = [
            .sessionExpired(detail: "401"),
            .accountUnavailable(detail: "403"),
            .transient(detail: "5xx"),
        ]
        for noSuccess in outcomes {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.claimOutcomes = [noSuccess]
            try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID)

            let runner = makeRunner(context, fake)
            await runner.resume()

            let j = try journal(context)
            #expect(j.readPhase().phase == .claimingMigration, "no-success mantiene la fase (\(noSuccess))")
            #expect(j.readPhase().phase != .failedRollback, "JAMÁS rollback por un no-success recuperable")
            #expect(fake.executedEffects.isEmpty)

            // Un resume posterior re-claima idempotente.
            fake.claimOutcomes = [.success(.created)]
            fake.uploadOutcomes = [.transient]
            let runner2 = makeRunner(context, fake)
            await runner2.resume()
            #expect(fake.count(.writeBeacon) == 1, "el resume re-claima y avanza (\(noSuccess))")
        }
    }

    // MARK: - 10b. …pero la CAUSA no se pierde (ticket `reentry-counts-as-fresh-install` §3)

    /// El journal se queda igual en los tres casos (test de arriba), y por eso la pantalla del adopt
    /// no podía distinguirlos: los tres se veían como «Conectando con tu cuenta…». `lastClaimBlocker`
    /// es lo que separa «no te llega la red» (se reintenta) de «tu cuenta no está disponible» (no).
    @Test func claimNoSuccess_recordsTheBlocker_onlyWhenItIsNotTheNetwork() async throws {
        let cases: [(ClaimOutcome, ClaimBlocker?)] = [
            (.accountUnavailable(detail: "403"), .accountUnavailable),
            (.sessionExpired(detail: "401"), .sessionExpired),
            (.transient(detail: "5xx"), nil),        // la red NO bloquea: sigue el progreso y el auto-resume
        ]
        for (outcome, expected) in cases {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.claimOutcomes = [outcome]
            try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID)

            let runner = makeRunner(context, fake)
            await runner.resume()

            #expect(runner.lastClaimBlocker == expected, "blocker esperado para \(outcome)")
            // Y el journal sigue intacto: esto NO es un terminal de fallo, solo una causa registrada.
            #expect(try journal(context).readPhase().phase == .claimingMigration)
        }
    }

    /// Un claim que sale bien LIMPIA el bloqueo del intento anterior — misma instancia de runner, que
    /// es lo que hay en producción (el controller lo crea una vez, lazy).
    @Test func claimSuccess_clearsAPreviousBlocker() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.accountUnavailable(detail: "403")]
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID)

        let runner = makeRunner(context, fake)
        await runner.resume()
        #expect(runner.lastClaimBlocker == .accountUnavailable)

        // La cuenta se reactiva y el usuario reintenta: el mismo runner vuelve a claimear.
        fake.claimOutcomes = [.success(.created)]
        fake.uploadOutcomes = [.transient]
        await runner.resume()
        #expect(runner.lastClaimBlocker == nil, "un claim otorgado deja de bloquear la pantalla")
    }

    // MARK: - 10c. «Migrar» sobre una cuenta que ya tiene lo personal (ticket settings-migrate-to-cloud-adopts-silently-instead-of-migrating)

    /// Con la intención de migrar, `existing_stable` vuelve al inicio: sin adopt —que sube el corpus local a la cuenta—,
    /// sin efectos y sin el sello del claim. Queda anotado para el aviso de la pantalla.
    @Test func migrateOnly_existingStable_returnsToNotStarted_withoutAdopt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.existingStable)]
        let runner = makeRunner(context, fake)

        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        runner.setForwardClaimIntent(.migrateOnly)
        await runner.submit(.signInSucceeded)

        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects().isEmpty)
        #expect(fake.executedEffects.isEmpty, "ni `.adoptBackendAccount` ni ningún otro efecto")
        #expect(fake.claimCallCount == 1)
        #expect(fake.discardStampCallCount == 1, "el sello `.routeReturningUser` no se queda sin adopt")
        #expect(runner.lastForwardClaimRefusal == ForwardClaimRefusal(sequence: 1, claimState: .existingStable))
        #expect(j.leaderDeviceID == nil, "el cierre del intento limpia lo que el claim journaleó")
        #expect(j.forwardClaimIntentRaw == nil, "la intención es del intento que se cierra")
    }

    /// CONTROL de la de arriba: sin la intención —Welcome, tarjeta de adopt, y el default tras relanzar— `existing_stable`
    /// adopta como siempre. Sin este caso, un runner que rechazara todo `existing_stable` pasaría la de arriba.
    @Test func adoptIfExisting_existingStable_adoptsAsAlways() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.existingStable)]
        let runner = makeRunner(context, fake)
        #expect(runner.forwardClaimIntent == .adoptIfExisting, "el default conserva el comportamiento de siempre")

        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        await runner.submit(.signInSucceeded)

        #expect(try journal(context).readPhase().phase == .notStarted)
        #expect(fake.executedEffects == [.adoptBackendAccount])
        #expect(fake.discardStampCallCount == 0)
        #expect(runner.lastForwardClaimRefusal == nil)
    }

    /// La intención solo para `existing_stable`: una cuenta nueva, o solo-grupos que el claim promueve (`created`), migra.
    @Test func migrateOnly_created_migratesNormally() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.created)]
        fake.uploadOutcomes = [.transient]
        let runner = makeRunner(context, fake)

        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        runner.setForwardClaimIntent(.migrateOnly)
        await runner.submit(.signInSucceeded)

        #expect(fake.count(.writeBeacon) == 1, "created lidera como siempre")
        #expect(try journal(context).readPhase().phase == .uploadingSnapshot)
        #expect(fake.discardStampCallCount == 0)
        #expect(runner.lastForwardClaimRefusal == nil)
    }

    /// La intención se escribe en el MISMO save que lleva a `claimingMigration`. Con el claim aparcado por la red, la fila
    /// ya la tiene: es lo que leerá el `resume` de un relanzamiento.
    @Test func migrateOnly_isJournaledWithTheClaimTransition() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.transient(detail: "5xx")]
        let runner = makeRunner(context, fake)

        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        runner.setForwardClaimIntent(.migrateOnly)
        #expect(try journal(context).forwardClaimIntentRaw == nil, "fijarla no escribe nada: se journalea con la transición")
        await runner.submit(.signInSucceeded)

        let j = try journal(context)
        #expect(j.readPhase().phase == .claimingMigration, "control: la red aparca el claim")
        #expect(j.forwardClaimIntentRaw == "migrateOnly")
    }

    /// Con «Migrar», un `claiming_in_progress` —otro dispositivo migrando esa cuenta— también vuelve al inicio, sin hacerse
    /// seguidor (Jürgen, 2026-09-16: parar y avisar). Seguirle acababa en un adopt, o en un relevo a los 60 min, que con otro
    /// iCloud mezcla los dos corpus.
    @Test func migrateOnly_claimingInProgress_returnsToNotStarted_withoutFollowing() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.claimingInProgress)]
        let runner = makeRunner(context, fake)

        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        runner.setForwardClaimIntent(.migrateOnly)
        await runner.submit(.signInSucceeded)

        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted, "sin `waitingForLeader`")
        #expect(j.readPendingEffects().isEmpty)
        #expect(fake.executedEffects.isEmpty)
        #expect(fake.discardStampCallCount == 1, "el sello `.waitForLeader` no se queda")
        #expect(runner.lastForwardClaimRefusal == ForwardClaimRefusal(sequence: 1, claimState: .claimingInProgress))
        #expect(j.forwardClaimIntentRaw == nil)
    }

    /// CONTROL de la de arriba: sin la intención —Welcome, tarjeta de adopt— `claiming_in_progress` sigue haciéndose
    /// seguidor como siempre.
    @Test func adoptIfExisting_claimingInProgress_followsAsAlways() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.claimingInProgress)]
        let runner = makeRunner(context, fake)

        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        await runner.submit(.signInSucceeded)

        #expect(try journal(context).readPhase().phase == .waitingForLeader)
        #expect(fake.executedEffects.isEmpty)
        #expect(fake.discardStampCallCount == 0)
        #expect(runner.lastForwardClaimRefusal == nil)
    }

    /// Un claim aparcado por la red y retomado en el MISMO proceso conserva la intención: si al retomar contesta
    /// `existing_stable`, también vuelve al inicio. Cada rechazo es uno nuevo para el aviso.
    @Test func migrateOnly_survivesAParkedClaim_andEachRefusalIsNew() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.transient(detail: "5xx"), .success(.existingStable)]
        let runner = makeRunner(context, fake)

        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        runner.setForwardClaimIntent(.migrateOnly)
        await runner.submit(.signInSucceeded)
        #expect(try journal(context).readPhase().phase == .claimingMigration, "control: la red aparca el claim")
        #expect(runner.lastForwardClaimRefusal == nil)

        await runner.resume()
        #expect(try journal(context).readPhase().phase == .notStarted)
        #expect(fake.executedEffects.isEmpty)
        #expect(runner.lastForwardClaimRefusal == ForwardClaimRefusal(sequence: 1, claimState: .existingStable))

        // Segundo intento en el mismo proceso: otro rechazo, otra secuencia.
        fake.claimOutcomes = [.success(.existingStable)]
        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        await runner.submit(.signInSucceeded)
        #expect(runner.lastForwardClaimRefusal == ForwardClaimRefusal(sequence: 2, claimState: .existingStable))
        #expect(fake.discardStampCallCount == 2)
    }

    /// **El relanzamiento con el claim aparcado** (hallazgo de la review): un runner nuevo no tiene la intención en memoria,
    /// pero la fila sí. Un `existing_stable` al retomar vuelve al inicio. Antes adoptaba, y en una cuenta que volvió a iCloud
    /// eso dejaba el dispositivo en modo nube sobre un backend congelado.
    @Test func afterRelaunch_theJournaledIntentStillRefuses() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.existingStable)]
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID, forwardClaimIntentRaw: "migrateOnly")

        let relaunched = makeRunner(context, fake)
        #expect(relaunched.forwardClaimIntent == .adoptIfExisting, "control: la memoria no sabe nada del intento")
        await relaunched.resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(fake.executedEffects.isEmpty, "sin adopt")
        #expect(fake.discardStampCallCount == 1)
        #expect(relaunched.lastForwardClaimRefusal == ForwardClaimRefusal(sequence: 1, claimState: .existingStable))
        #expect(j.forwardClaimIntentRaw == nil)
    }

    /// CONTROL del de arriba, y dos cosas a la vez: una fila sin intención (anterior a la v6, o de un adopt) adopta como
    /// siempre, y lo que decide es la FILA, no la memoria. Un `driveClaim` que leyera la intención de memoria rechazaría
    /// aquí.
    @Test func journalWithoutMigrateIntent_adopts_evenIfMemorySaysMigrate() async throws {
        for raw in [nil, "adoptIfExisting"] as [String?] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.claimOutcomes = [.success(.existingStable)]
            try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID, forwardClaimIntentRaw: raw)

            let runner = makeRunner(context, fake)
            runner.setForwardClaimIntent(.migrateOnly)
            await runner.resume()

            #expect(fake.executedEffects == [.adoptBackendAccount], "fila con \(String(describing: raw))")
            #expect(runner.lastForwardClaimRefusal == nil)
        }
    }

    /// El seguidor no lee la intención. Con «Migrar» ya no se llega aquí —`claiming_in_progress` vuelve al inicio, lo fija
    /// `migrateOnly_claimingInProgress_returnsToNotStarted_withoutFollowing`—, así que el seguidor que queda es el de un
    /// adopt, que adopta lo que el líder migró. Residual declarado en `adopt-uploads-a-foreign-corpus-without-a-lineage-check`.
    @Test func follower_ignoresTheIntent() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.existingStable)]
        try seedJournal(context, phase: .waitingForLeader)

        let runner = makeRunner(context, fake)
        runner.setForwardClaimIntent(.migrateOnly)
        await runner.pollLeader()

        #expect(fake.executedEffects == [.adoptBackendAccount])
        #expect(fake.discardStampCallCount == 0)
        #expect(runner.lastForwardClaimRefusal == nil)
    }

    // MARK: - 11. Reversa (§h, I11-2) — driving del runner

    /// Camino feliz completo de la reversa desde `done`: secuencia exacta de efectos + reverseOriginRaw
    /// escrito en el claim y LIMPIADO al llegar a icloudActive.
    @Test func reverse_happyPath_fromDone_reachesICloudActive_withExactEffects() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.accepted]
        fake.reverseDrainOutcomes = [.completed]
        fake.verifyProbes = [.match]                 // reverse verify reusa executor.verify()
        fake.freezeBackendOutcomes = [.completed]
        fake.setMirrorOnOnMount = true               // ejecutar el efecto monta el mirror → drive avanza
        fake.sweepOutcome = .completed(deleted: 0)
        fake.reverseUploadStatuses = [.drained]
        try seedJournal(context, phase: .done)

        await runner(context, fake).submit(.reverseActivated)
        #expect(try journal(context).readPhase().phase == .reverseConfirm(.done))

        await runner(context, fake).submit(.reverseConfirmed)   // → drive autónomo hasta icloudActive
        let final = try journal(context)
        #expect(final.readPhase().phase == .icloudActive)
        #expect(final.readPendingEffects().isEmpty)
        #expect(final.reverseOriginRaw == nil, "icloudActive limpia reverseOriginRaw (S2-cleanup extendido)")
        #expect(fake.executedEffects == [
            .mountMirrorAndRelaunch,
            .deleteCloudKitMarker, .clearCloudBeacon, .persistICloudMode, .completeReverseServer,
        ], "efecto de mount al entrar a reverseMountMirror + cuarteto de cierre EN ORDEN")
    }

    /// El origin + el reset S9 se journalean en el MISMO save del claim (reverseConfirm→reverseClaimLeader).
    @Test func reverse_originAndS9Reset_writtenOnClaimTransition() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.transient]     // corta en reverseClaimLeader para inspeccionar
        // Contadores S9 con gasto del verify forward previo.
        try seedJournal(context, phase: .reverseConfirm(.done), mismatchRetries: 3, networkRetries: 5,
                        snapshotCursor: "stale")

        await runner(context, fake).submit(.reverseConfirmed)

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseClaimLeader)
        #expect(j.reverseOriginRaw == "done", "el origin se journalea en la transición del claim")
        #expect(j.verifyMismatchRetries == 0, "S9 reset en el claim de la reversa")
        #expect(j.verifyNetworkRetries == 0)
        #expect(j.snapshotCursorJSON == nil)
    }

    /// Desatascador: otro device es reverse-líder → vuelve al ORIGIN journaleado (ambos origins + fallback).
    @Test func reverse_otherLeader_returnsToJournaledOrigin() async throws {
        for (originRaw, expected): (String?, Phase) in [("done", .done), ("notStarted", .notStarted), (nil, .done)] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.reverseClaimOutcomes = [.otherLeader]
            try seedJournal(context, phase: .reverseClaimLeader, reverseOriginRaw: originRaw)

            await runner(context, fake).resume()

            #expect(try journal(context).readPhase().phase == expected,
                    "otherLeader con origin=\(originRaw ?? "nil") → \(expected)")
        }
    }

    /// REGRESIÓN (review I11-2, gap de la lente A): la TRANSICIÓN REAL a `reverseFailedRollback` (tope de
    /// mismatch del reverseVerify) debe CONSERVAR `reverseOriginRaw` — está deliberadamente FUERA del
    /// S2-cleanup. Si alguien lo añadiera al set de limpieza, `resetAfterRollback` caería al fallback `.done`
    /// y un ADOPTADOR (origin notStarted) quedaría con journal `done` mintiendo para siempre. Los demás tests
    /// de reset seedean el journal directo y NO cazarían esa regresión.
    @Test func reverse_fatalTransition_preservesOrigin_resetRestoresNotStarted() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.mismatch]              // reverse verify reusa executor.verify()
        try seedJournal(context, phase: .reverseVerify, mismatchRetries: 3, reverseOriginRaw: "notStarted")

        let r = makeRunner(context, fake, policy: MigrationPolicy(maxMismatchRetries: 3, maxNetworkRetries: 8))
        await r.resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseFailedRollback, "tope de mismatch → reverseFailedRollback")
        #expect(j.reverseOriginRaw == "notStarted",
                "la transición a reverseFailedRollback CONSERVA el origin (fuera del S2-cleanup)")

        await r.resetAfterRollback()
        let after = try journal(context)
        #expect(after.readPhase().phase == .notStarted, "el reset repone el ORIGEN journaleado, no .done")
        #expect(after.reverseOriginRaw == nil, "el reset limpia el origin")
    }

    /// Kill-resume: el efecto `.mountMirrorAndRelaunch` pendiente + mirror YA montado (observación) → consume
    /// el pendiente y avanza SIN re-ejecutar el efecto (cruza el process boundary).
    @Test func reverse_killResume_mountEffectPending_mirrorMounted_advancesByObservation() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.mirrorOn = true                         // el relaunch ya remontó el mirror
        fake.sweepOutcome = .transient               // corta en deletingZombies para inspeccionar
        try seedJournal(context, phase: .reverseMountMirror, pending: [.mountMirrorAndRelaunch],
                        reverseOriginRaw: "done")

        await runner(context, fake).resume()

        #expect(fake.count(.mountMirrorAndRelaunch) == 0, "NO se re-ejecuta el mount (resuelto por observación)")
        #expect(try journal(context).readPhase().phase == .reverseReconcile(.deletingZombies))
    }

    /// Kill-resume en un sub-estado de reconcile → retoma EXACTO (no re-ejecuta los completados).
    @Test func reverse_killResume_reconcileSubstate_retakesExact_noReRun() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyRebindsResult = 2
        fake.healDuplicatesResult = 0
        fake.reverseUploadStatuses = [.pending(count: 1)]   // corta en reverseUpload
        try seedJournal(context, phase: .reverseReconcile(.rebindingUUIDs), reverseOriginRaw: "done")

        await runner(context, fake).resume()

        #expect(fake.sweepCallCount == 0, "deletingZombies ya estaba hecho → NO se re-barre")
        #expect(try journal(context).readPhase().phase == .reverseUpload)
    }

    /// reverseUpload pending → stop retomable → drained → icloudActive.
    @Test func reverse_reverseUpload_pendingThenDrained_reachesICloudActive() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseUploadStatuses = [.pending(count: 4)]
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        await runner(context, fake).resume()
        #expect(try journal(context).readPhase().phase == .reverseUpload, "pending → stop retomable")

        fake.reverseUploadStatuses = [.drained]
        await runner(context, fake).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .icloudActive)
        #expect(j.readPendingEffects().isEmpty)
    }

    /// completeReverseServer notWired → journaled-pendiente; el resume lo reintenta (los otros 3 ya corrieron).
    @Test func reverse_completeServerNotWired_journaledPending_resumeRetries() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseUploadStatuses = [.drained]
        fake.effectErrors[.completeReverseServer] = FakeError()   // simula el notWired del executor
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        await runner(context, fake).resume()
        var j = try journal(context)
        #expect(j.readPhase().phase == .icloudActive)
        #expect(j.readPendingEffects() == [.completeReverseServer], "los 3 primeros corrieron; el server queda pendiente")
        #expect(fake.count(.deleteCloudKitMarker) == 1)
        #expect(fake.count(.clearCloudBeacon) == 1)
        #expect(fake.count(.persistICloudMode) == 1)
        #expect(fake.count(.completeReverseServer) == 0)

        fake.effectErrors.removeValue(forKey: .completeReverseServer)
        await runner(context, fake).resume()
        j = try journal(context)
        #expect(fake.count(.completeReverseServer) == 1, "el resume reintenta el efecto pendiente")
        #expect(j.readPendingEffects().isEmpty)
    }

    /// reverseVerify mismatch RE-DRENA (pull), gasta un retry de MISMATCH, NUNCA re-sube.
    @Test func reverse_verifyMismatch_reDrains_spendsMismatchRetry() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.mismatch]
        fake.reverseDrainOutcomes = [.transient]        // corta en reverseDrainAll para inspeccionar
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done")

        await runner(context, fake).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseDrainAll, "mismatch de la reversa RE-DRENA (pull), no re-sube")
        #expect(j.verifyMismatchRetries == 1)
        #expect(j.verifyNetworkRetries == 0, "el contador de red NO se toca")
    }

    // MARK: - 11b. Sesión caducada antes del montaje (ticket `reverse-before-mount-stays-stuck-with-an-expired-session`)

    /// **La tabla del ticket, fase por fase.** Las cuatro son anteriores al montaje del espejo, así que ninguna es
    /// estable: sin este rastro el motor de la nube no corre, el aviso de Ajustes no sale y la barra se queda parada
    /// al 15/30/50/62 % sin decir que hay que volver a entrar.
    ///
    /// **Lo que hace discriminante a cada caso es la pareja de aserciones**: la fase NO avanza (eso ya pasaba antes)
    /// **y** queda anotado DÓNDE. Con el bug dentro, `lastReverseSessionExpiry` es `nil` en las cuatro.
    @Test func reverse_sessionExpired_beforeMount_isRecordedPerPhase() async throws {
        let cases: [(Phase, ReversePreMountPhase, (FakeExecutor) -> Void)] = [
            (.reverseClaimLeader, .claim, { $0.reverseClaimOutcomes = [.sessionExpired] }),
            (.reverseDrainAll, .drain, { $0.reverseDrainOutcomes = [.sessionExpired] }),
            (.reverseVerify, .verify, { $0.verifyProbes = [.sessionExpired] }),
            (.reverseFreezeBackend, .freeze, { $0.freezeBackendOutcomes = [.sessionExpired] }),
        ]
        for (phase, expected, script) in cases {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            script(fake)
            try seedJournal(context, phase: phase, reverseOriginRaw: "done")

            let r = runner(context, fake)
            await r.resume()

            #expect(r.lastReverseSessionExpiry == expected, "\(phase) debe anotar .\(expected)")
            #expect(try journal(context).readPhase().phase == phase, "\(phase): la fase NO avanza, queda retomable")
            // NO se comprueba aquí que no haya efectos pendientes: con el bug dentro tampoco los había (las cuatro
            // transiciones de entrada llevan `effects: []` y el verify reintentaba sin degradar), así que sería una
            // aserción que no puede fallar. El caso que SÍ lo mide, con el presupuesto agotado, es
            // `reverse_verifySessionExpired_spendsNoNetworkRetry_andNeverDegrades`.
        }
    }

    /// Criterio 3 del ticket. `reverseVerify` leía la sesión caducada como `.networkTimeout`: gastaba el presupuesto
    /// de RED y al agotarlo degradaba a `reverseFailedRollback` **con `.reverseRollback` pendiente** — un efecto que
    /// con la sesión caducada lanza en cada resume, así que la fase de fallo se quedaba con su abort sin ejecutar.
    ///
    /// El caso arranca con el presupuesto de red **agotado** (`networkRetries: 8` == `MigrationPolicy
    /// .maxNetworkRetries`): así el mutante que devuelva este `case` al trato de `networkTimeout` no solo suma un
    /// contador — **degrada a `reverseFailedRollback` con `.reverseRollback` pendiente**, y las tres aserciones caen
    /// a la vez en vez de una sola.
    ///
    /// **El número sale de la política, no de un literal.** La primera versión de este caso sembraba `2` diciendo que
    /// el tope era `3`: con el tope real, el mutante solo movía el contador y **dos de las tres aserciones no podían
    /// fallar** — pasaban con el bug dentro y con el bug fuera. Lo cazó una lente adversarial.
    @Test func reverse_verifySessionExpired_spendsNoNetworkRetry_andNeverDegrades() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.sessionExpired]
        let spent = MigrationPolicy.default.maxNetworkRetries
        try seedJournal(context, phase: .reverseVerify, networkRetries: spent, reverseOriginRaw: "done")

        await runner(context, fake).resume()

        let j = try journal(context)
        #expect(j.verifyNetworkRetries == spent,
                "la sesión caducada NO gasta presupuesto de red: esperar no la renueva")
        #expect(j.readPhase().phase == .reverseVerify, "no degrada a reverseFailedRollback")
        #expect(!j.readPendingEffects().contains(.reverseRollback),
                "y por tanto no deja el abort pendiente, que con la sesión caducada lanzaría en cada resume")
    }

    /// Criterio 2 del ticket: tras volver a entrar, la vuelta sigue DONDE ESTABA. El segundo `resume()` es lo que
    /// hace `CloudMigrationController.signInToResumeReverse` después de firmar.
    ///
    /// Y fija la otra mitad, que es la que se olvida: **la observación se LIMPIA sola** con el primer paso que avanza.
    /// Sin eso la tarjeta seguiría pidiendo volver a entrar con la vuelta ya corriendo.
    @Test func reverse_afterSigningInAgain_resumesAndClearsTheNotice() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.sessionExpired, .accepted]
        fake.reverseDrainOutcomes = [.transient]        // corta en reverseDrainAll para inspeccionar
        try seedJournal(context, phase: .reverseClaimLeader, reverseOriginRaw: "done")

        let r = runner(context, fake)
        await r.resume()
        #expect(r.lastReverseSessionExpiry == .claim)
        #expect(try journal(context).readPhase().phase == .reverseClaimLeader)

        await r.resume()                                 // ← lo que corre tras volver a entrar

        #expect(try journal(context).readPhase().phase == .reverseDrainAll, "la vuelta sigue desde donde estaba")
        #expect(r.lastReverseSessionExpiry == nil, "el paso que avanza borra el aviso: ya no hay que volver a entrar")
        #expect(fake.reverseClaimCallCount == 2)
    }

    /// Un corte por RED no puede pedir volver a entrar — es el falso positivo que cerró
    /// `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`, y sin este caso el mutante que anota la
    /// observación en `.transient` saldría verde: la fase tampoco avanza ahí.
    @Test func reverse_transientNetwork_neverAsksToSignInAgain() async throws {
        let cases: [(Phase, (FakeExecutor) -> Void)] = [
            (.reverseClaimLeader, { $0.reverseClaimOutcomes = [.transient] }),
            (.reverseDrainAll, { $0.reverseDrainOutcomes = [.transient] }),
            (.reverseVerify, { $0.verifyProbes = [.networkTimeout] }),
            (.reverseFreezeBackend, { $0.freezeBackendOutcomes = [.transient] }),
        ]
        for (phase, script) in cases {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            script(fake)
            try seedJournal(context, phase: phase, reverseOriginRaw: "done")

            let r = runner(context, fake)
            await r.resume()

            #expect(r.lastReverseSessionExpiry == nil, "\(phase): la red se reintenta sola, no se pide firmar")
        }
    }

    /// La observación se BORRA también cuando lo siguiente que pasa es red, no solo cuando avanza. Sin esto, un
    /// «vuelve a entrar» de hace una hora seguiría en pantalla mientras la vuelta espera cobertura.
    @Test func reverse_sessionExpiry_isClearedByALaterTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.sessionExpired, .transient]
        try seedJournal(context, phase: .reverseClaimLeader, reverseOriginRaw: "done")

        let r = runner(context, fake)
        await r.resume()
        #expect(r.lastReverseSessionExpiry == .claim)

        await r.resume()
        #expect(r.lastReverseSessionExpiry == nil)
    }

    /// **La IDA no cambia** (D6 del Paso 0): `verify()` lo comparten las dos direcciones, y en `verifying` el caso
    /// nuevo se trata como la red — exactamente como antes de que existiera. Sin este caso, mover el `.sessionExpired`
    /// de `driveVerify` a su propia rama pasaría inadvertido y la ida dejaría de degradar.
    @Test func forwardVerify_sessionExpired_spendsNetworkRetry() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.sessionExpired]
        try seedJournal(context, phase: .verifying, networkRetries: 0)

        let r = runner(context, fake)
        await r.resume()

        let j = try journal(context)
        #expect(j.verifyNetworkRetries == 1, "en la IDA sigue gastando presupuesto de red, como antes del ticket")
        #expect(j.readPhase().phase == .verifying)
        #expect(r.lastReverseSessionExpiry == nil, "y no anota nada de la vuelta")
    }

    /// resetAfterRollback desde reverseFailedRollback → repone la fase ORIGEN journaleada (no notStarted ciego).
    @Test func reverse_resetAfterRollback_restoresJournaledOrigin() async throws {
        for (originRaw, expected): (String?, Phase) in [("done", .done), ("notStarted", .notStarted), (nil, .done)] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            try seedJournal(context, phase: .reverseFailedRollback, leaderDeviceID: "stale",
                            mismatchRetries: 2, reverseOriginRaw: originRaw)

            await runner(context, fake).resetAfterRollback()

            let j = try journal(context)
            #expect(j.readPhase().phase == expected, "origin=\(originRaw ?? "nil") → \(expected)")
            #expect(j.reverseOriginRaw == nil)
            #expect(j.leaderDeviceID == nil)
            #expect(j.verifyMismatchRetries == 0)
        }
    }

    // MARK: - 12. Heartbeat del lease (I14-pre, residual pendiente #3) — pacing del runner

    /// El runner late tras CADA página confirmada del snapshot (el throttle vive en el executor real, no aquí).
    @Test func heartbeat_uploadPageConfirmed_ticksPerPage() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.pageConfirmed(cursor: "c1"), .pageConfirmed(cursor: "c2"), .completed]
        fake.verifyProbes = [.match]
        fake.confirmCutoverResult = false            // corta en cutover(.pending) tras el upload
        try seedJournal(context, phase: .uploadingSnapshot, leaderDeviceID: deviceID)

        await runner(context, fake).resume()

        #expect(fake.heartbeatCallCount == 2, "heartbeat tras CADA pageConfirmed; NUNCA en .completed")
    }

    /// El runner late en `reverseUpload` pendiente (cada re-poll mantiene la lease viva mientras exporta el mirror).
    @Test func heartbeat_reverseUploadPending_ticks() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseUploadStatuses = [.pending(count: 1)]
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        await runner(context, fake).resume()

        #expect(fake.heartbeatCallCount == 1, "reverseUpload pending late para mantener la lease viva")
        #expect(try journal(context).readPhase().phase == .reverseUpload, "pending → stop retomable")
    }

    // MARK: - 13. Techo y salida de `reverseUpload` (ticket `reverse-upload-has-no-ceiling-and-no-exit`)

    /// La primera observación SELLA el reloj y la cifra más baja, sin contarla como avance y sin sellar hacia
    /// atrás: un journal escrito antes de estos campos, observado «tarde», empieza a contar ahora. Y holdea: ni un
    /// efecto. La pantalla recibe la cifra.
    @Test func reverseUploadCeiling_firstObservation_sealsClockAndLowest_holds() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseUploadStatuses = [.pending(count: 10)]
        fake.reverseBlocker = .icloudFull                       // presupuesto corto: aun así no sale en la 1.ª
        let clock = MutableClock(fixedNow.addingTimeInterval(5_000))
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        let r = makeRunner(context, fake, now: { clock.value })
        await r.resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseUpload)
        #expect(j.reverseUploadLowestPending == 10)
        #expect(j.reverseUploadProgressAt == clock.value, "el reloj arranca AHORA, nunca retroactivo")
        #expect(fake.executedEffects.isEmpty)
        #expect(r.lastReverseUploadSample == ReverseUploadSample(pending: 10, blocker: .icloudFull))
    }

    /// EL test de la decisión D2: el techo mide tiempo SIN AVANZAR. Un corpus que baja poco a poco, con más de
    /// 15 min entre observaciones pero menos de 15 min desde el último avance, pasa horas en la espera sin salir —
    /// aun con la causa del presupuesto corto—. Medir desde el INICIO lo echaría a la segunda observación. Cuando
    /// deja de bajar, el techo sí vence, contado desde el último avance.
    @Test func reverseUploadCeiling_slowButAdvancingCorpus_neverHitsTheCeiling_stuckOneDoes() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseBlocker = .icloudFull                       // 900 s: el techo más corto que existe
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        var pending = 1_000
        for step in 0..<10 {                                    // 10 × 800 s = 8000 s en la espera
            clock.value = fixedNow.addingTimeInterval(Double(step) * 800)
            fake.reverseUploadStatuses = [.pending(count: pending)]
            await makeRunner(context, fake, now: { clock.value }).resume()
            let j = try journal(context)
            #expect(j.readPhase().phase == .reverseUpload, "observación \(step): avanza, así que sigue esperando")
            #expect(j.reverseUploadProgressAt == clock.value, "cada avance re-sella el reloj")
            pending -= 50
        }
        #expect(fake.executedEffects.isEmpty, "8000 s sin un solo efecto: nunca estuvo 900 s sin avanzar")

        // Se clava: misma cifra. A 899 s del último avance espera; a 900 s sale.
        let lastProgress = clock.value
        fake.reverseUploadStatuses = [.pending(count: pending + 50)]
        clock.value = lastProgress.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .reverseUpload)
        #expect(try journal(context).reverseUploadProgressAt == lastProgress, "sin avance NO se re-sella")

        clock.value = lastProgress.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .done)
        #expect(fake.executedEffects == [.rearmMirrorOff, .reverseRollback])
    }

    /// La cifra SUBE cuando la persona escribe durante la espera. Eso no es avance —si lo fuera, escribir
    /// reiniciaría el techo para siempre— y tampoco baja el listón: el mínimo sigue siendo el que era.
    @Test func reverseUploadCeiling_countGoingUp_isNotProgress_lowestIsKept() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseBlocker = .icloudFull
        let clock = MutableClock(fixedNow.addingTimeInterval(600))
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done",
                        reverseUploadLowestPending: 10, reverseUploadProgressAt: fixedNow)

        fake.reverseUploadStatuses = [.pending(count: 12)]        // la persona anotó dos gastos
        await makeRunner(context, fake, now: { clock.value }).resume()
        var j = try journal(context)
        #expect(j.readPhase().phase == .reverseUpload)
        #expect(j.reverseUploadLowestPending == 10, "subir no cambia el mínimo")
        #expect(j.reverseUploadProgressAt == fixedNow, "subir no es avance")

        fake.reverseUploadStatuses = [.pending(count: 11)]        // baja, pero no por debajo de 10
        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .done, "11 no es avance sobre un mínimo de 10: el techo vence")
    }

    /// Techo agotado con la palabra de CloudKit: vuelta al ORIGEN, los dos efectos en orden, el motivo journaleado
    /// y el reloj, la cifra y el origen limpiados. Desde los dos orígenes: `notStarted` es la fase del adoptador y
    /// pasa por el bloque de limpieza de `handle`, así que su pata es la que caza que ese bloque borre también el
    /// motivo (hoy solo lo borra al llegar a `icloudActive`).
    @Test func reverseUploadCeiling_definitiveExpired_returnsToOrigin_rearmThenAbort_reasonJournaled() async throws {
        for (originRaw, expected): (String, Phase) in [("done", .done), ("notStarted", .notStarted)] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.reverseUploadStatuses = [.pending(count: 5)]
            fake.reverseBlocker = .icloudFull
            let clock = MutableClock(fixedNow.addingTimeInterval(900))
            try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: originRaw,
                            reverseUploadLowestPending: 5, reverseUploadProgressAt: fixedNow)

            let r = makeRunner(context, fake, now: { clock.value })
            await r.resume()

            let j = try journal(context)
            #expect(j.readPhase().phase == expected, "origin \(originRaw)")
            #expect(fake.executedEffects == [.rearmMirrorOff, .reverseRollback],
                    "orden OBLIGATORIO: lo local primero, la red después")
            #expect(j.readPendingEffects().isEmpty)
            #expect(j.reverseAbortReasonRaw == "icloudFull", "el porqué sobrevive a la vuelta (\(originRaw))")
            #expect(j.reverseUploadLowestPending == nil)
            #expect(j.reverseUploadProgressAt == nil)
            #expect(j.reverseOriginRaw == nil)
            #expect(fake.count(.persistICloudMode) == 0, "la salida NO completa la vuelta a iCloud")
            #expect(fake.count(.completeReverseServer) == 0)
            #expect(r.lastReverseUploadSample == nil, "la pantalla deja de hablar de una espera que ya no existe")
        }
    }

    /// Sin palabra de CloudKit el techo es el LARGO: a 1000 s sin avanzar (pasado el corto) sigue esperando; a las
    /// 72 h sale, con el motivo `stalled`.
    @Test func reverseUploadCeiling_unknownCause_usesTheLongBudget() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseUploadStatuses = [.pending(count: 7)]
        fake.reverseBlocker = .icloudOff                        // sin token: se dice, pero no acorta la espera
        let clock = MutableClock(fixedNow.addingTimeInterval(1_000))
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done",
                        reverseUploadLowestPending: 7, reverseUploadProgressAt: fixedNow)

        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .reverseUpload)
        #expect(fake.executedEffects.isEmpty)

        clock.value = fixedNow.addingTimeInterval(259_200)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .done)
        #expect(j.reverseAbortReasonRaw == "stalled",
                "sin token de Drive no se afirma que iCloud faltara: la nota sobrevive al relanzamiento")
    }

    /// Sin red al salir: `reverse_abort` lanza, pero la salida NO se deshace. La fase origen y el re-armado ya
    /// están hechos, el aborto queda pendiente y el siguiente resume lo completa.
    @Test func reverseUploadCeiling_abortWithoutNetwork_exitStands_rollbackRetriedOnResume() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseUploadStatuses = [.pending(count: 3)]
        fake.reverseBlocker = .icloudFull
        fake.effectErrors[.reverseRollback] = FakeError()
        let clock = MutableClock(fixedNow.addingTimeInterval(900))
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done",
                        reverseUploadLowestPending: 3, reverseUploadProgressAt: fixedNow)

        let offline = makeRunner(context, fake, now: { clock.value })
        await offline.resume()
        var j = try journal(context)
        #expect(j.readPhase().phase == .done)
        #expect(fake.executedEffects == [.rearmMirrorOff], "lo local ya está hecho aunque la red falle")
        #expect(j.readPendingEffects() == [.reverseRollback])
        #expect(j.reverseAbortReasonRaw == "icloudFull")
        #expect(offline.lastReverseUploadSample == nil,
                "la salida se cuenta al journalearla: la pantalla deja la espera aunque el abort no llegue")

        fake.effectErrors.removeValue(forKey: .reverseRollback)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(fake.executedEffects == [.rearmMirrorOff, .reverseRollback])
        #expect(j.readPendingEffects().isEmpty)
        #expect(j.readPhase().phase == .done)
    }

    /// Un reloj ADELANTADO al sellar y corregido después dejaba un sello en el futuro: cada observación daba 0 s sin
    /// avanzar y el techo quedaba aplazado hasta que el reloj real alcanzara aquella fecha. Ahora un sello futuro se
    /// re-sella con la observación, y el techo cuenta desde ahí.
    @Test func reverseUploadCeiling_clockSetBack_resealsInsteadOfPostponingTheCeiling() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseUploadStatuses = [.pending(count: 9)]
        fake.reverseBlocker = .icloudFull                      // 900 s
        let future = fixedNow.addingTimeInterval(10 * 86_400) // sellado con el reloj 10 días adelantado
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done",
                        reverseUploadLowestPending: 9, reverseUploadProgressAt: future)

        await makeRunner(context, fake, now: { clock.value }).resume()
        var j = try journal(context)
        #expect(j.readPhase().phase == .reverseUpload)
        #expect(j.reverseUploadProgressAt == fixedNow, "el sello futuro se re-sella con la observación")

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .done, "el techo cuenta desde el re-sellado, no desde la fecha futura")
    }

    /// EL test del hallazgo de la review: tras una salida sin red el journal queda `done` + `[.reverseRollback]`, y
    /// `handle` REEMPLAZA los pendientes al journalear el evento siguiente. Empezar otra vuelta encima borraba el
    /// `reverse_abort` sin ejecutarlo y la nueva chocaba con la nube congelada en `reverseDrainAll`, para siempre.
    /// Ahora `reverseActivated` drena antes: sin red no empieza nada y el pendiente sigue; con red lo completa y entra.
    @Test func reverseActivated_withAPendingAbort_completesItFirst_orDoesNotStart() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.effectErrors[.reverseRollback] = FakeError()        // sigue sin red
        try seedJournal(context, phase: .done, pending: [.reverseRollback], reverseAbortReasonRaw: "stalled")

        await runner(context, fake).submit(.reverseActivated)
        var j = try journal(context)
        #expect(j.readPhase().phase == .done, "sin completar el abort no empieza otra vuelta")
        #expect(j.readPendingEffects() == [.reverseRollback], "el abort pendiente NO se borra")
        #expect(fake.count(.reverseRollback) == 0)

        fake.effectErrors.removeValue(forKey: .reverseRollback)  // vuelve la red
        await runner(context, fake).submit(.reverseActivated)
        j = try journal(context)
        #expect(fake.count(.reverseRollback) == 1, "primero se descongela la nube")
        #expect(j.readPendingEffects().isEmpty)
        #expect(j.readPhase().phase == .reverseConfirm(.done), "y después empieza la vuelta nueva")
    }

    /// El drenaje previo es SOLO para la salida. Otro pendiente en fase estable se reemplaza como antes de este
    /// ticket: el reconcile de un líder al que otro dispositivo le quitó la lease lanza `other_leader` en cada intento,
    /// y drenarlo dejaba «Volver a iCloud» cerrado para siempre, que era la única salida de ese estado. Los dos
    /// orígenes, con el pendiente que falla (lo delata la fase) y con el que no falla (lo delata que no se ejecutó).
    @Test func reverseActivated_withAPendingEffectThatIsNotTheExit_replacesItAsBefore() async throws {
        let cases: [(Phase, Effect, Phase)] = [
            (.done, .runLeaderReconcileFromFrozenCloudKit, .reverseConfirm(.done)),
            (.notStarted, .adoptBackendAccount, .reverseConfirm(.notStarted)),
        ]
        for (origin, effect, expected) in cases {
            for fails in [true, false] {
                let dir = freshDir(); defer { cleanup(dir) }
                let context = try makeContext(dir)
                let fake = FakeExecutor()
                if fails { fake.effectErrors[effect] = FakeError() }
                try seedJournal(context, phase: origin, pending: [effect])

                await runner(context, fake).submit(.reverseActivated)

                let j = try journal(context)
                #expect(j.readPhase().phase == expected, "\(effect) fails=\(fails): la vuelta empieza")
                #expect(j.readPendingEffects().isEmpty, "\(effect) fails=\(fails): el pendiente se reemplaza")
                #expect(fake.count(effect) == 0, "\(effect) fails=\(fails): no se ejecuta antes de la vuelta")
                #expect(j.readReverseOriginPendingEffects() == [effect],
                        "\(effect) fails=\(fails): y se guarda, por si el servidor no concede la reserva")
            }
        }
    }

    /// «Cancelar y seguir en la nube»: la misma vuelta que el techo, desde los dos orígenes, con motivo
    /// `cancelled` (la pantalla no le pone nota).
    @Test func reverseUploadCancel_fromTheWait_returnsToOrigin_reasonCancelled() async throws {
        for (originRaw, expected): (String, Phase) in [("done", .done), ("notStarted", .notStarted)] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: originRaw,
                            reverseUploadLowestPending: 40, reverseUploadProgressAt: fixedNow)

            await runner(context, fake).cancelReverse()

            let j = try journal(context)
            #expect(j.readPhase().phase == expected)
            #expect(fake.executedEffects == [.rearmMirrorOff, .reverseRollback])
            #expect(j.reverseAbortReasonRaw == "cancelled")
            #expect(j.reverseUploadLowestPending == nil)
            #expect(j.reverseUploadProgressAt == nil)
        }
    }

    /// Un toque que llega tarde —la espera ya drenó, ya salió o todavía no empezó— no saca a nadie de ningún sitio.
    @Test func reverseUploadCancel_outsideTheWait_isNoOp() async throws {
        let phases: [Phase] = [.done, .notStarted, .icloudActive, .reverseReconcile(.dedupHealed), .reverseMountMirror]
        for phase in phases {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            try seedJournal(context, phase: phase, reverseOriginRaw: "done")

            await runner(context, fake).cancelReverse()

            let j = try journal(context)
            #expect(j.readPhase().phase == phase, "\(phase) no se mueve")
            #expect(fake.executedEffects.isEmpty)
            #expect(j.reverseAbortReasonRaw == nil)
        }
    }

    /// El porqué de la salida anterior deja de ser verdad cuando empieza otra vuelta: se limpia en la reserva.
    @Test func reverseUpload_newAttempt_clearsTheLastExitReason() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.transient]                 // corta en reverseClaimLeader
        try seedJournal(context, phase: .reverseConfirm(.done), reverseAbortReasonRaw: "stalled")

        await runner(context, fake).submit(.reverseConfirmed)

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseClaimLeader)
        #expect(j.reverseAbortReasonRaw == nil)
    }

    /// Una vuelta que SÍ drena cierra en `icloudActive` sin reloj, sin cifra y sin nota.
    @Test func reverseUpload_drained_clearsTheCeilingFields() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseUploadStatuses = [.drained]
        // Un motivo sembrado a mano (no se puede llegar aquí con uno: la reserva lo limpia) para que la aserción
        // de abajo pueda fallar: sin él, «nil al final» se cumpliría sin limpiar nada.
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done",
                        reverseUploadLowestPending: 2, reverseUploadProgressAt: fixedNow,
                        reverseAbortReasonRaw: "stalled")

        let r = runner(context, fake)
        await r.resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .icloudActive)
        #expect(j.reverseUploadLowestPending == nil)
        #expect(j.reverseUploadProgressAt == nil)
        #expect(j.reverseAbortReasonRaw == nil)
        #expect(r.lastReverseUploadSample == nil)
    }

    // MARK: - Salida del claim de la reversa (ticket reverse-claim-rejection-has-no-way-out-in-the-client)

    /// Un rechazo del claim vuelve al ORIGEN, sin efectos y con el porqué journaleado, por cada motivo medido en el RPC
    /// vivo y por uno desconocido. Antes cortaba sin evento y `reverseClaimLeader` —fase TRANSITORIA— no salía nunca:
    /// barra al 15 %, motor de la nube sin arrancar tras relanzar y BGTasks diferidos. La pata `notStarted` pasa por el bloque de limpieza
    /// de `handle`, así que es la que caza que ese bloque borre la nota; la pata sin origen, el fallback `.done`.
    @Test func reverseClaimRejected_eachReason_returnsToOrigin_noEffects_reasonJournaled() async throws {
        let cases: [(server: String, origin: String?, phase: Phase, note: ReverseAbortReason)] = [
            ("not_complete", "done", .done, .claimRefused),
            ("not_complete", "notStarted", .notStarted, .claimRefused),
            ("migration_in_progress", "done", .done, .claimRetryLater),
            ("migration_in_progress", "notStarted", .notStarted, .claimRetryLater),
            ("no_profile", "done", .done, .claimRefused),
            ("some_future_reason", nil, .done, .claimRefused),
        ]
        for c in cases {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.reverseClaimOutcomes = [.rejected(reason: c.server)]
            try seedJournal(context, phase: .reverseClaimLeader, reverseOriginRaw: c.origin)

            let r = runner(context, fake)
            await r.resume()

            let label = "\(c.server) desde \(c.origin ?? "nil")"
            let j = try journal(context)
            let phase = j.readPhase().phase
            #expect(phase == c.phase, "\(label)")
            #expect(j.reverseAbortReasonRaw == c.note.rawValue, "\(label): la nota sobrevive a la vuelta")
            #expect(j.readPendingEffects().isEmpty, "\(label): el claim rechazado no reservó nada")
            #expect(fake.executedEffects.isEmpty, "\(label)")
            #expect(j.reverseOriginRaw == nil, "\(label): el origen se va con el intento")
            #expect(MigrationRuntimeGate.isDomainStablePhase(phase), "\(label): el motor de la nube puede volver")
            #expect(BGTaskMigrationGate.decide(phase: phase, isImportQuiescent: false, role: .writer) == .run,
                    "\(label): los BGTasks dejan de estar diferidos")
            #expect(r.lastReverseClaimExit == ReverseClaimExit(sequence: 1, reason: c.note), "\(label)")
            #expect(fake.reverseClaimCallCount == 1, "\(label)")
        }
    }

    /// El recorrido del TOQUE: «Volver a iCloud» desde la nube, rechazo, y otra vez. La nota de un intento anterior se
    /// reemplaza, y cada salida sube la secuencia aunque el motivo se repita: es lo que deja a la pantalla enseñar la
    /// alerta en el segundo toque, con la misma nota ya puesta.
    @Test func reverseClaimRejected_fromTheTap_eachAttemptIsANewExit() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.rejected(reason: "not_complete")]
        try seedJournal(context, phase: .done, reverseAbortReasonRaw: "stalled")

        let r = runner(context, fake)
        await r.submit(.reverseActivated)
        await r.submit(.reverseConfirmed)
        var j = try journal(context)
        #expect(j.readPhase().phase == .done)
        #expect(j.reverseAbortReasonRaw == "claimRefused", "la nota de la espera anterior deja de ser verdad")
        #expect(r.lastReverseClaimExit == ReverseClaimExit(sequence: 1, reason: .claimRefused))

        await r.submit(.reverseActivated)
        await r.submit(.reverseConfirmed)
        j = try journal(context)
        #expect(j.readPhase().phase == .done)
        #expect(j.reverseAbortReasonRaw == "claimRefused")
        #expect(r.lastReverseClaimExit == ReverseClaimExit(sequence: 2, reason: .claimRefused),
                "mismo motivo, salida nueva")
        // Aparte, y no solo por `==`: la pantalla decide la alerta comparando salidas, y un `==` que ignorara la
        // secuencia dejaría sin alerta el segundo toque con el mismo motivo, con la comparación de arriba en verde.
        #expect(r.lastReverseClaimExit?.sequence == 2)
        #expect(ReverseClaimExit(sequence: 1, reason: .claimRefused) != ReverseClaimExit(sequence: 2, reason: .claimRefused))
        #expect(fake.reverseClaimCallCount == 2)
        #expect(fake.executedEffects.isEmpty)
    }

    /// Tras salir no hay bucle: el re-kick y el arranque ya no re-claiman solos. Volver a intentarlo es un toque.
    @Test func reverseClaimRejected_resumeAfterTheExit_doesNotClaimAgain() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.rejected(reason: "migration_in_progress")]
        try seedJournal(context, phase: .reverseClaimLeader, reverseOriginRaw: "done")

        await runner(context, fake).resume()
        await runner(context, fake).resume()
        await runner(context, fake).resume()

        #expect(fake.reverseClaimCallCount == 1)
        #expect(try journal(context).readPhase().phase == .done)
    }

    /// `other_leader` ya salía, pero en silencio (decisión D4 de Jürgen, 2026-09-16): ahora deja su propia nota, y la
    /// deja también desde `done`, donde el bloque de limpieza de `handle` no borra el origen.
    @Test func reverse_otherLeader_journalsItsNote() async throws {
        for (originRaw, expected): (String, Phase) in [("done", .done), ("notStarted", .notStarted)] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.reverseClaimOutcomes = [.otherLeader]
            try seedJournal(context, phase: .reverseClaimLeader, reverseOriginRaw: originRaw)

            let r = runner(context, fake)
            await r.resume()

            let j = try journal(context)
            #expect(j.readPhase().phase == expected)
            #expect(j.reverseAbortReasonRaw == "otherDeviceReverting", "\(originRaw)")
            #expect(j.reverseOriginRaw == nil, "\(originRaw)")
            #expect(j.readPendingEffects().isEmpty)
            #expect(r.lastReverseClaimExit == ReverseClaimExit(sequence: 1, reason: .otherDeviceReverting))
        }
    }

    /// Hallazgo de la review adversarial (dos lentes por separado): `reverseActivated` REEMPLAZA los pendientes del
    /// origen, y el reconcile de un líder es lo único que manda `complete`. Si el servidor no concede la reserva, la vuelta
    /// no empezó y esos pendientes vuelven: sin eso `migration_in_progress` se quedaba puesto en el backend para siempre
    /// (antes lo curaba el takeover de la reversa a los 60 min). Por los dos orígenes y las dos salidas del claim, con el
    /// pendiente que se ejecuta en el acto.
    @Test func reverseClaimExit_restoresTheOriginPendingEffects_andRunsThem() async throws {
        let cases: [(outcome: ReverseClaimOutcome, origin: Phase, effect: Effect, note: ReverseAbortReason)] = [
            (.rejected(reason: "migration_in_progress"), .done, .runLeaderReconcileFromFrozenCloudKit, .claimRetryLater),
            (.rejected(reason: "not_complete"), .notStarted, .adoptBackendAccount, .claimRefused),
            (.otherLeader, .done, .runLeaderReconcileFromFrozenCloudKit, .otherDeviceReverting),
        ]
        for c in cases {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.reverseClaimOutcomes = [c.outcome]
            try seedJournal(context, phase: c.origin, pending: [c.effect])

            let r = runner(context, fake)
            await r.submit(.reverseActivated)
            #expect(fake.count(c.effect) == 0, "\(c.outcome): la vuelta no lo ejecuta al empezar")
            await r.submit(.reverseConfirmed)

            let j = try journal(context)
            #expect(j.readPhase().phase == c.origin, "\(c.outcome)")
            #expect(fake.count(c.effect) == 1, "\(c.outcome): repuesto y ejecutado al volver al origen")
            #expect(j.readPendingEffects().isEmpty, "\(c.outcome)")
            #expect(j.reverseOriginPendingEffectsData == nil, "\(c.outcome): lo guardado se consume")
            #expect(j.reverseAbortReasonRaw == c.note.rawValue, "\(c.outcome)")
            #expect(r.lastReverseClaimExit?.sequence == 1, "\(c.outcome)")
        }
    }

    /// Si el pendiente repuesto LANZA (el reconcile sin red), la salida ya está journaleada: se queda en el origen con el
    /// pendiente para el siguiente resume, y la salida se anota igual para que la pantalla avise.
    @Test func reverseClaimExit_restoredEffectThrows_exitStandsAndIsRecorded() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.rejected(reason: "migration_in_progress")]
        fake.effectErrors[.runLeaderReconcileFromFrozenCloudKit] = FakeError()
        try seedJournal(context, phase: .done, pending: [.runLeaderReconcileFromFrozenCloudKit])

        let r = runner(context, fake)
        await r.submit(.reverseActivated)
        await r.submit(.reverseConfirmed)

        var j = try journal(context)
        #expect(j.readPhase().phase == .done)
        #expect(j.readPendingEffects() == [.runLeaderReconcileFromFrozenCloudKit], "repuesto, a la espera del resume")
        #expect(j.reverseOriginPendingEffectsData == nil)
        #expect(j.reverseAbortReasonRaw == "claimRetryLater")
        #expect(r.lastReverseClaimExit == ReverseClaimExit(sequence: 1, reason: .claimRetryLater),
                "la salida se anota aunque el pendiente repuesto falle")

        fake.effectErrors.removeValue(forKey: .runLeaderReconcileFromFrozenCloudKit)
        await runner(context, fake).resume()
        j = try journal(context)
        #expect(fake.count(.runLeaderReconcileFromFrozenCloudKit) == 1, "el resume lo completa: `complete` llega")
        #expect(j.readPendingEffects().isEmpty)
        #expect(fake.reverseClaimCallCount == 1, "y no vuelve a pedir la reserva")
    }

    /// Con la reserva CONCEDIDA la vuelta empezó de verdad: lo guardado deja de aplicar (si la reserva tomó el lease de
    /// la ida, `migration_in_progress` ya es false) y no se ejecuta.
    @Test func reverseClaimAccepted_dropsTheOriginPendingEffects() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.accepted]
        fake.reverseDrainOutcomes = [.transient]                    // corta en reverseDrainAll para inspeccionar
        try seedJournal(context, phase: .done, pending: [.runLeaderReconcileFromFrozenCloudKit])

        let r = runner(context, fake)
        await r.submit(.reverseActivated)
        #expect(try journal(context).reverseOriginPendingEffectsData != nil, "control: se guardó al empezar")
        await r.submit(.reverseConfirmed)

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseDrainAll)
        #expect(j.reverseOriginPendingEffectsData == nil)
        #expect(j.readPendingEffects().isEmpty)
        #expect(fake.count(.runLeaderReconcileFromFrozenCloudKit) == 0)
        #expect(r.lastReverseClaimExit == nil)
    }

    /// Las otras dos vueltas al origen antes de la reserva también reponen: declinar en la confirmación (por `handle`) y
    /// un kill ahí (por la normalización del resume). Mismo predicado, `ReverseOriginPendingEffects`.
    @Test func reverseConfirm_declineOrKill_restoresTheOriginPendingEffects() async throws {
        for viaKill in [false, true] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount])

            await runner(context, fake).submit(.reverseActivated)
            #expect(try journal(context).readPhase().phase == .reverseConfirm(.notStarted))
            // El kill va con un CONTEXTO nuevo sobre el mismo container, no solo con un runner nuevo: con el mismo
            // contexto, lo guardado que no llegó a `save()` seguiría a la vista y esta pata no cazaría un guardado sin
            // persistir (segunda pasada de review).
            let after = viaKill ? ModelContext(context.container) : context
            if viaKill {
                await makeRunner(after, fake).resume()
            } else {
                await runner(context, fake).submit(.reverseDeclined)
            }

            let j = try journal(after)
            #expect(j.readPhase().phase == .notStarted, "kill=\(viaKill)")
            #expect(fake.count(.adoptBackendAccount) == 1, "kill=\(viaKill): repuesto y ejecutado")
            #expect(j.readPendingEffects().isEmpty, "kill=\(viaKill)")
            #expect(j.reverseOriginPendingEffectsData == nil, "kill=\(viaKill)")
        }
    }

    /// Lo que NO sale: la red y la sesión caducada siguen siendo retomables, sin nota y sin salida anotada. Un mutante
    /// que sacara a la nube todo lo que no es `accepted` convertiría un túnel en «tu cuenta no lo permite».
    @Test func reverseClaim_transientAndSessionExpired_stayRetakeable_withoutANote() async throws {
        for outcome: ReverseClaimOutcome in [.transient, .sessionExpired] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.reverseClaimOutcomes = [outcome]
            try seedJournal(context, phase: .reverseClaimLeader, reverseOriginRaw: "done")

            let r = runner(context, fake)
            await r.resume()

            let j = try journal(context)
            #expect(j.readPhase().phase == .reverseClaimLeader, "\(outcome)")
            #expect(j.reverseAbortReasonRaw == nil, "\(outcome)")
            #expect(j.reverseOriginRaw == "done", "\(outcome): el origen sigue para el siguiente intento")
            #expect(r.lastReverseClaimExit == nil, "\(outcome)")
        }
    }

    /// Un NUEVO runner por acción (espeja el patrón de kill: instancia nueva re-lee el store).
    private func runner(_ context: ModelContext, _ fake: FakeExecutor) -> MigrationRunner {
        makeRunner(context, fake)
    }
    // MARK: - §12 · Techo y salida de las CUATRO fases previas al montaje
    // (ticket `reverse-before-mount-has-no-way-to-abandon-the-return`)

    /// Cómo se para cada fase con cada motivo, y qué motivo journalea al salir. La tabla recorre los tres que el
    /// SERVIDOR tipa —el `other_leader` y el `rechazo` del congelado, el 403 del drenaje y de la verificación— más
    /// la red y la sesión, que eligen el techo largo. Con el reloj ya vencido, la vuelta sale a su origen.
    ///
    /// **Este test NO caza el colapso del executor**, y conviene decirlo: aquí el fake devuelve el outcome ya
    /// tipado, así que devolver los tres a `.transient` —como estaban hasta este ticket— lo cazan los casos de
    /// `MigrationWorkExecutorTests` (medido: el mutante del `other_leader` del congelado deja este verde). Lo que
    /// sí muere aquí es cambiar el motivo journaleado, quitar el abort best-effort, o journalearlo como efecto.
    @Test func reversePreMountCeiling_eachServerWord_exitsWithItsOwnReason() async throws {
        let cases: [(Phase, String, (FakeExecutor) -> Void, String)] = [
            (.reverseFreezeBackend, "freeze/otherLeader",
             { $0.freezeBackendOutcomes = [.blocked(.otherLeader)] }, "preMountOtherDevice"),
            (.reverseFreezeBackend, "freeze/refused",
             { $0.freezeBackendOutcomes = [.blocked(.refused)] }, "preMountRefused"),
            (.reverseDrainAll, "drain/403",
             { $0.reverseDrainOutcomes = [.blocked(.accountUnavailable)] }, "preMountRefused"),
            (.reverseVerify, "verify/403",
             { $0.verifyProbes = [.blocked(.accountUnavailable)] }, "preMountRefused"),
        ]
        for (phase, label, arrange, expectedReason) in cases {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            arrange(fake)
            let clock = MutableClock(fixedNow.addingTimeInterval(900))
            try seedJournal(context, phase: phase, reverseOriginRaw: "done",
                            reversePreMountProgressAt: fixedNow,
                            reversePreMountPhaseRaw: ReversePreMountPhase(phase: phase)?.rawValue)

            await makeRunner(context, fake, now: { clock.value }).resume()

            let j = try journal(context)
            #expect(j.readPhase().phase == .done, "\(label): vuelve al origen en modo nube")
            #expect(j.reverseAbortReasonRaw == expectedReason, "\(label)")
            #expect(j.readPendingEffects().isEmpty,
                    "\(label): NINGÚN efecto journaleado — un abort pendiente relanzaría en cada arranque")
            #expect(fake.count(.reverseRollback) == 1, "\(label): el abort se intenta, best-effort, una vez")
            #expect(fake.count(.rearmMirrorOff) == 0, "\(label): pre-montaje no hay espejo que re-armar")
            #expect(j.reversePreMountProgressAt == nil, "\(label)")
            #expect(j.reversePreMountPhaseRaw == nil, "\(label)")
            #expect(j.reverseOriginRaw == nil, "\(label)")
        }
    }

    /// La red y la sesión caducada eligen el techo LARGO: a los 900 s —donde el servidor ya habría hecho salir—
    /// siguen esperando, y a las 72 h salen con `preMountStalled`. Esta es la mitad que cubre «una cuenta a la que
    /// ya no se puede entrar»: el aviso de volver a entrar sigue delante, pero la espera no es eterna.
    @Test func reversePreMountCeiling_networkAndExpiredSession_useTheLongBudget() async throws {
        let cases: [(Phase, String, (FakeExecutor) -> Void)] = [
            (.reverseClaimLeader, "claim/transient", { $0.reverseClaimOutcomes = [.transient] }),
            (.reverseClaimLeader, "claim/sessionExpired", { $0.reverseClaimOutcomes = [.sessionExpired] }),
            (.reverseDrainAll, "drain/transient", { $0.reverseDrainOutcomes = [.transient] }),
            (.reverseDrainAll, "drain/sessionExpired", { $0.reverseDrainOutcomes = [.sessionExpired] }),
            (.reverseVerify, "verify/sessionExpired", { $0.verifyProbes = [.sessionExpired] }),
            (.reverseFreezeBackend, "freeze/transient", { $0.freezeBackendOutcomes = [.transient] }),
            (.reverseFreezeBackend, "freeze/sessionExpired", { $0.freezeBackendOutcomes = [.sessionExpired] }),
        ]
        for (phase, label, arrange) in cases {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            arrange(fake)
            let clock = MutableClock(fixedNow.addingTimeInterval(900))
            try seedJournal(context, phase: phase, reverseOriginRaw: "done",
                            reversePreMountProgressAt: fixedNow,
                            reversePreMountPhaseRaw: ReversePreMountPhase(phase: phase)?.rawValue)

            await makeRunner(context, fake, now: { clock.value }).resume()
            #expect(try journal(context).readPhase().phase == phase, "\(label): a los 900 s sigue esperando")
            #expect(fake.count(.reverseRollback) == 0, "\(label): nada que des-reservar todavía")

            clock.value = fixedNow.addingTimeInterval(259_200)
            await makeRunner(context, fake, now: { clock.value }).resume()
            let j = try journal(context)
            #expect(j.readPhase().phase == .done, "\(label): a las 72 h sale sola")
            #expect(j.reverseAbortReasonRaw == "preMountStalled", "\(label)")
            #expect(j.readPendingEffects().isEmpty, "\(label)")
        }
    }

    /// El reloj mide el tiempo SIN CAMBIAR DE FASE, no el total de la etapa. Un drenaje que tardó casi todo el
    /// presupuesto y luego pasó a la verificación llega ahí con el reloj a cero: sin esto, una vuelta lenta pero
    /// sana se cancelaría sola a mitad de camino.
    @Test func reversePreMountCeiling_changingPhaseIsProgress_theClockRestarts() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseDrainOutcomes = [.completed]                    // avanza a reverseVerify
        fake.verifyProbes = [.blocked(.accountUnavailable)]         // y ahí se para con la palabra del servidor
        let clock = MutableClock(fixedNow.addingTimeInterval(890))
        try seedJournal(context, phase: .reverseDrainAll, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "drain")

        await makeRunner(context, fake, now: { clock.value }).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseVerify, "avanzó de fase, así que no salió por el techo")
        #expect(j.reversePreMountPhaseRaw == "verify", "el reloj se re-sella en la fase nueva")
        #expect(j.reversePreMountProgressAt == clock.value, "y desde AHORA, no desde que empezó la etapa")
        #expect(j.reverseAbortReasonRaw == nil)

        // 890 s más en la fase nueva: el total de la etapa pasa de 1 780 s, pero en `verify` solo lleva 890.
        clock.value = fixedNow.addingTimeInterval(1_780)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .reverseVerify,
                "el presupuesto es por fase: el tiempo del drenaje no cuenta aquí")

        clock.value = fixedNow.addingTimeInterval(890 + 900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .done, "900 s parada EN verify sí la sacan")
    }

    /// La primera observación de una fase sella el reloj sin contarla como parada, y un sello en el FUTURO —el
    /// reloj del teléfono iba adelantado y ya se corrigió— se re-sella en vez de aplazar el techo hasta que el
    /// reloj real alcance aquella fecha.
    @Test func reversePreMountCeiling_firstObservationSeals_futureSealIsReSealed() async throws {
        for (label, seeded): (String, Date?) in [("sin sello", nil),
                                                 ("sello futuro", fixedNow.addingTimeInterval(100_000))] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.freezeBackendOutcomes = [.blocked(.refused)]
            let clock = MutableClock(fixedNow)
            try seedJournal(context, phase: .reverseFreezeBackend, reverseOriginRaw: "done",
                            reversePreMountProgressAt: seeded, reversePreMountPhaseRaw: "freeze")

            await makeRunner(context, fake, now: { clock.value }).resume()
            let j = try journal(context)
            #expect(j.readPhase().phase == .reverseFreezeBackend, "\(label): la primera observación no saca a nadie")
            #expect(j.reversePreMountProgressAt == fixedNow, "\(label): se sella AHORA")

            clock.value = fixedNow.addingTimeInterval(900)
            await makeRunner(context, fake, now: { clock.value }).resume()
            #expect(try journal(context).readPhase().phase == .done, "\(label): y desde ese sello sí vence")
        }
    }

    /// El 403 de la verificación NO gasta `verifyNetworkRetries`. Ese camino acaba en `reverseFailedRollback` con
    /// `.reverseRollback` pendiente, que es justo el efecto que con la cuenta no disponible vuelve a lanzar en cada
    /// resume: el bug-class que este ticket cierra, alcanzado por la puerta de al lado.
    @Test func reversePreMountCeiling_verifyBlocked_spendsNoNetworkRetry_andNeverDegrades() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.blocked(.accountUnavailable)]
        try seedJournal(context, phase: .reverseVerify, networkRetries: 7, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify")

        for _ in 0..<3 {
            await makeRunner(context, fake, now: { self.fixedNow }).resume()
        }

        let j = try journal(context)
        #expect(j.verifyNetworkRetries == 7, "el presupuesto de RED no se toca")
        #expect(j.readPhase().phase == .reverseVerify, "y no degrada: espera a su propio techo")
        #expect(j.readPendingEffects().isEmpty)
    }

    /// El `reverse_abort` best-effort que LANZA no deshace la salida ni deja nada pendiente. Es la diferencia con
    /// la salida de la espera de subida, donde el abort SÍ es un efecto journaleado: aquí un pendiente se relanzaría
    /// en cada arranque, porque `MigrationBootDecision` fuerza `.resume` mientras los haya.
    @Test func reversePreMountCeiling_abortThrows_exitStands_andNothingIsLeftPending() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.freezeBackendOutcomes = [.blocked(.otherLeader)]
        fake.effectErrors[.reverseRollback] = FakeError()
        let clock = MutableClock(fixedNow.addingTimeInterval(900))
        try seedJournal(context, phase: .reverseFreezeBackend, reverseOriginRaw: "notStarted",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "freeze")

        await makeRunner(context, fake, now: { clock.value }).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted, "la salida está journaleada: no depende del servidor")
        #expect(j.reverseAbortReasonRaw == "preMountOtherDevice")
        #expect(j.readPendingEffects().isEmpty, "NADA pendiente, aunque el abort haya fallado")
        #expect(fake.attempts(.reverseRollback) == 1, "se intentó una vez, y una sola")
        #expect(fake.count(.reverseRollback) == 0, "y lanzó: el servidor sigue con la reserva puesta")

        // Y el siguiente resume tampoco lo reintenta: ya no hay nada que drenar.
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(fake.attempts(.reverseRollback) == 1, "un abort que falló NO se relanza en cada arranque")
    }

    /// El botón «Cancelar y seguir en la nube» funciona en las cuatro fases, con el motivo de la persona —que no
    /// deja nota— y sin esperar a ningún techo.
    @Test func cancelReverse_fromAnyPreMountPhase_returnsToOrigin_reasonCancelled() async throws {
        for phase: Phase in [.reverseClaimLeader, .reverseDrainAll, .reverseVerify, .reverseFreezeBackend] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            try seedJournal(context, phase: phase, reverseOriginRaw: "done")

            await makeRunner(context, fake).cancelReverse()

            let j = try journal(context)
            #expect(j.readPhase().phase == .done, "\(phase)")
            #expect(j.reverseAbortReasonRaw == "cancelled", "\(phase): lo decidió la persona, así que no deja nota")
            #expect(j.readPendingEffects().isEmpty, "\(phase)")
            #expect(fake.count(.reverseRollback) == 1, "\(phase): des-reserva el servidor, best-effort")
            #expect(fake.count(.rearmMirrorOff) == 0, "\(phase): pre-montaje no hay espejo que re-armar")
        }
    }

    /// Y es no-op donde la salida no existe: un toque que llega tarde —la vuelta ya montó el espejo, o ya salió—
    /// no puede sacar a nadie de un sitio en el que ya no está.
    @Test func cancelReverse_outsideTheFivePhasesThatOfferIt_isANoOp() async throws {
        for phase: Phase in [.reverseMountMirror, .reverseReconcile(.awaitingQuiescence), .icloudActive,
                             .done, .notStarted, .reverseFailedRollback] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.mirrorOn = true                                   // que `reverseMountMirror` no avance por su cuenta
            try seedJournal(context, phase: phase, reverseOriginRaw: "done")

            await makeRunner(context, fake).cancelReverse()

            let j = try journal(context)
            // La fase no se mueve. Sin esta aserción, el `mirrorOn` del setup protege algo que nadie mira.
            #expect(j.readPhase().phase == phase, "\(phase): la fase no se mueve")
            #expect(j.reverseAbortReasonRaw == nil, "\(phase): no journalea una salida que no ocurrió")
            #expect(fake.count(.reverseRollback) == 0, "\(phase): ni des-reserva nada")
        }
    }

    /// Una vuelta NUEVA empieza con el reloj a cero. Sin esto, el sello de un intento anterior en la misma fase
    /// daría un `stalled` de días en la primera observación y la vuelta se cancelaría sola nada más empezar.
    @Test func reversePreMountCeiling_aNewAttemptClearsTheClock() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.accepted]
        fake.reverseDrainOutcomes = [.transient]                   // corta en reverseDrainAll para inspeccionar
        let clock = MutableClock(fixedNow.addingTimeInterval(1_000_000))
        // Un intento anterior dejó su reloj parado en `drain`, hace once días.
        try seedJournal(context, phase: .done,
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "drain")

        let r = makeRunner(context, fake, now: { clock.value })
        await r.submit(.reverseActivated)
        await r.submit(.reverseConfirmed)

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseDrainAll, "la vuelta nueva llega al drenaje y se para ahí")
        #expect(j.reversePreMountProgressAt == clock.value, "con el reloj sellado AHORA, no hace once días")
        #expect(j.reversePreMountPhaseRaw == "drain")
    }

    // MARK: - §12b · Lo que cazó la review adversarial

    /// **Un claim que se para bajo presupuesto NO puede tirar los pendientes del origen.** El techo de la etapa le
    /// dio a `reverseClaimLeader` su primer SELF-HOLD, y el brazo que descarta lo guardado («la vuelta empezó de
    /// verdad») cazaba ese hold: un corte de red durante el claim borraba el `runLeaderReconcileFromFrozenCloudKit`
    /// del líder —lo ÚNICO que manda `complete`— y el rechazo que llegara después reponía una lista vacía. Es el bug
    /// que cerró `reverse-claim-rejection-has-no-way-out-in-the-client`, reabierto por la puerta de al lado.
    ///
    /// El mutante: quitarle el `next != .reverseClaimLeader` al brazo del descarte.
    @Test func reversePreMountCeiling_holdingTheClaim_keepsTheOriginPendingEffects() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.transient, .rejected(reason: "migration_in_progress")]
        try seedJournal(context, phase: .done, pending: [.runLeaderReconcileFromFrozenCloudKit])

        let r = makeRunner(context, fake, now: { self.fixedNow })
        await r.submit(.reverseActivated)
        await r.submit(.reverseConfirmed)                      // claim sin cobertura → holdea bajo presupuesto

        let held = try journal(context)
        #expect(held.readPhase().phase == .reverseClaimLeader, "se queda esperando, no sale")
        #expect(held.readReverseOriginPendingEffects() == [.runLeaderReconcileFromFrozenCloudKit],
                "lo guardado del origen sigue guardado: la vuelta NO ha empezado de verdad")

        await r.resume()                                       // ahora el servidor rechaza → salida al origen

        let j = try journal(context)
        #expect(j.readPhase().phase == .done)
        #expect(fake.count(.runLeaderReconcileFromFrozenCloudKit) == 1,
                "repuesto y ejecutado: sin él, `migration_in_progress` se queda puesto en el backend para siempre")
        #expect(j.reverseOriginPendingEffectsData == nil, "y consumido")
    }

    /// **El reloj se re-sella al VOLVER a una fase ya visitada**, no solo al pisar una nueva. El bucle
    /// `reverseVerify → reverseDrainAll` por mismatch es progreso real, y sin esto la segunda visita al drenaje
    /// heredaba el sello de la primera: el techo saltaba con cero segundos de parada en esa visita.
    ///
    /// El mutante: quitar la limpieza del par cuando la fase cambia.
    @Test func reversePreMountCeiling_returningToAVisitedPhase_restartsTheClock() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        // drenaje parado → se recupera y avanza → la verificación discrepa y vuelve al drenaje.
        fake.reverseDrainOutcomes = [.blocked(.accountUnavailable), .completed, .transient]
        fake.verifyProbes = [.mismatch]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseDrainAll, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "drain")

        clock.value = fixedNow.addingTimeInterval(890)
        await makeRunner(context, fake, now: { clock.value }).resume()   // observa parado, holdea
        #expect(try journal(context).readPhase().phase == .reverseDrainAll)

        clock.value = fixedNow.addingTimeInterval(895)
        await makeRunner(context, fake, now: { clock.value }).resume()   // drena → verify → mismatch → drain

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseDrainAll, "volvió al drenaje por el mismatch")
        #expect(j.verifyMismatchRetries == 1, "control del escenario: el rebote ocurrió de verdad")
        #expect(j.reverseAbortReasonRaw == nil,
                "895 s de reloj heredado NO pueden sacar a la vuelta en su primera observación de esta visita")
        #expect(j.reversePreMountProgressAt == clock.value,
                "el sello de la visita anterior se retiró al cambiar de fase, y esta observación lo puso de nuevo")
    }

    /// **El `reverse_abort` se intenta también cuando el paso que journalea LANZA.** La salida se salva antes de
    /// drenar los pendientes que `handle` repone, así que un reconcile que falla siempre dejaba la salida hecha y el
    /// aviso al servidor sin intentar NUNCA: no es un efecto journaleado y la fase ya no vuelve a pasar por ahí.
    ///
    /// El mutante: quitar el `catch` que dispara el abort antes de re-lanzar.
    @Test func reversePreMountCancel_restoredEffectThrows_theAbortIsStillAttempted() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.effectErrors[.runLeaderReconcileFromFrozenCloudKit] = FakeError()
        try seedJournal(context, phase: .reverseClaimLeader, reverseOriginRaw: "done")
        let state = try journal(context)
        state.setReverseOriginPendingEffects([.runLeaderReconcileFromFrozenCloudKit])
        try context.save()

        let r = makeRunner(context, fake, now: { self.fixedNow })
        await r.cancelReverse()

        let j = try journal(context)
        #expect(j.readPhase().phase == .done, "la salida está journaleada: el pendiente que falla no la deshace")
        #expect(j.reverseAbortReasonRaw == "cancelled")
        #expect(fake.attempts(.runLeaderReconcileFromFrozenCloudKit) == 1, "control: el repuesto SÍ se intentó")
        #expect(fake.attempts(.reverseRollback) == 1,
                "y el aviso al servidor también, pese a que el anterior lanzó")
    }

}
