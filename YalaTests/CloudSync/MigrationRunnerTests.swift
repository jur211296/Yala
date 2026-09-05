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
    var reverseDrainOutcome: ReverseStepOutcome = .completed
    var freezeBackendResult = true
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

    // Efectos.
    var executedEffects: [MigrationEffect] = []
    var effectErrors: [MigrationEffect: any Error] = [:]
    /// Ejecutar `.disableMirrorAndRelaunch` pone el mirror OFF (simula el relaunch surtiendo efecto).
    var setMirrorOffOnDisable = true
    var mirrorOff = false
    /// Ejecutar `.writeCloudKitMarker` marca el marcador EXPORTADO (simula el export async completando) →
    /// el gate `isMarkerExported()` deja avanzar. Ponerlo `false` prueba que el gate CORTA retomable.
    var setMarkerExportedOnWrite = true
    var markerExported = false

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
    func reverseDrainOnce() async -> ReverseStepOutcome { reverseDrainOutcome }
    func freezeBackendForReverse() async -> Bool { freezeBackendResult }
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

    // Heartbeat del lease (I14-pre): registra las llamadas del runner. El throttle vive en el executor REAL
    // (MigrationWorkExecutorTests), así que aquí cada invocación cuenta 1:1 (el runner es el dueño del pacing).
    var heartbeatCallCount = 0
    func sendLeaseHeartbeatIfDue() async { heartbeatCallCount += 1 }

    func count(_ effect: MigrationEffect) -> Int { executedEffects.filter { $0 == effect }.count }
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
        markerWrittenSince: Date? = nil, cutoverICloudVerdictRaw: String? = nil
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

    // MARK: - 11. Reversa (§h, I11-2) — driving del runner

    /// Camino feliz completo de la reversa desde `done`: secuencia exacta de efectos + reverseOriginRaw
    /// escrito en el claim y LIMPIADO al llegar a icloudActive.
    @Test func reverse_happyPath_fromDone_reachesICloudActive_withExactEffects() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.accepted]
        fake.reverseDrainOutcome = .completed
        fake.verifyProbes = [.match]                 // reverse verify reusa executor.verify()
        fake.freezeBackendResult = true
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
        fake.reverseDrainOutcome = .transient        // corta en reverseDrainAll para inspeccionar
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done")

        await runner(context, fake).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseDrainAll, "mismatch de la reversa RE-DRENA (pull), no re-sube")
        #expect(j.verifyMismatchRetries == 1)
        #expect(j.verifyNetworkRetries == 0, "el contador de red NO se toca")
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

    /// Un NUEVO runner por acción (espeja el patrón de kill: instancia nueva re-lee el store).
    private func runner(_ context: ModelContext, _ fake: FakeExecutor) -> MigrationRunner {
        makeRunner(context, fake)
    }
}
