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

    // Efectos.
    var executedEffects: [MigrationEffect] = []
    var effectErrors: [MigrationEffect: any Error] = [:]
    /// Ejecutar `.disableMirrorAndRelaunch` pone el mirror OFF (simula el relaunch surtiendo efecto).
    var setMirrorOffOnDisable = true
    var mirrorOff = false

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

    func confirmCutoverServer() async -> Bool { confirmCutoverResult }
    func persistLocalMode() async -> Bool { persistLocalModeResult }

    func execute(_ effect: MigrationEffect) async throws {
        if let error = effectErrors[effect] { throw error }   // NO se marca ejecutado si lanza
        executedEffects.append(effect)
        if effect == .disableMirrorAndRelaunch, setMirrorOffOnDisable { mirrorOff = true }
    }

    func isMirrorConfirmedOff() -> Bool { mirrorOff }

    func count(_ effect: MigrationEffect) -> Int { executedEffects.filter { $0 == effect }.count }
}

private struct FakeError: Error {}

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
        tick: Double = 0.5
    ) -> MigrationRunner {
        MigrationRunner(
            context: context, executor: executor, deviceID: deviceID, policy: policy,
            quiescenceSignal: quiescence, now: { self.fixedNow }, sleeper: { _ in },
            quiescenceTimeoutSeconds: timeout, quiescenceTickSeconds: tick)
    }

    @discardableResult
    private func seedJournal(
        _ context: ModelContext, phase: Phase, pending: [Effect] = [],
        leaderDeviceID: String? = nil, mismatchRetries: Int = 0, networkRetries: Int = 0,
        snapshotCursor: String? = nil
    ) throws -> MigrationState {
        let state = MigrationState()
        state.setPhase(phase)
        state.setPendingEffects(pending)
        state.leaderDeviceID = leaderDeviceID
        state.verifyMismatchRetries = mismatchRetries
        state.verifyNetworkRetries = networkRetries
        state.snapshotCursorJSON = snapshotCursor
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
}
