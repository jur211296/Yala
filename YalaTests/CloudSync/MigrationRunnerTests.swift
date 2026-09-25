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
    /// Cuántas veces sondeó el runner. Lo pide el techo de la etapa previa al montaje: sus tres cortes devuelven
    /// `false` para no hacer tight-loop de red, y ESO no lo puede cazar el journal — con `return true` el bucle de
    /// `drive()` re-sondea hasta su tope de iteraciones y acaba dejando el journal exactamente igual. Hallazgo de la
    /// review del 2026-09-21.
    var verifyCallCount = 0

    /// El desenlace de `confirmCutoverServer()`. Era un `Bool` hasta `forward-migration-steps-have-no-ceiling-and-no-exit`.
    var confirmCutoverOutcome: CutoverServerOutcome = .confirmed
    /// `canRenewSession()`: `false` = el SDK borró la sesión. Lo lee el runner tras un claim `.sessionExpired`.
    var canRenewSessionResult = false
    func canRenewSession() -> Bool { canRenewSessionResult }
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
    var sweptSinceSeqs: [Int64] = []
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

    /// La cuenta de la sesión viva, con el hash del faro. `nil` = sin sesión.
    var accountHash: String?
    func currentAccountHash() -> String? { accountHash }

    /// `hasPersistedCloudMode()`: `true` = el paso 5 del adopt ya escribió `.cloud` (ticket
    /// `adopt-effect-retries-forever-with-no-ceiling`).
    var persistedCloudMode = false
    func hasPersistedCloudMode() -> Bool { persistedCloudMode }

    /// Se llama dentro de cada `execute`, antes de lanzar o no. Monta el «Cancelar» que llega con el efecto del adopt en
    /// vuelo.
    var onExecute: ((MigrationEffect) -> Void)?

    /// Se llama DENTRO de cada `performClaim`, antes de devolver el outcome. Lo pide el techo de los tres pasos: monta la
    /// sesión que el SDK borra durante el claim, y el «sí» de «Cancelar» que llega con el claim en vuelo.
    var onPerformClaim: (() -> Void)?

    /// Con qué `marksMigrationAttempt` pidió el runner cada claim. Solo «Migrar» marca.
    var claimMarksSeen: [Bool] = []

    func performClaim(marksMigrationAttempt: Bool) async -> ClaimOutcome {
        claimCallCount += 1
        claimMarksSeen.append(marksMigrationAttempt)
        onPerformClaim?()
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

    // Linaje de la ida (ticket `migration-takeover-uploads-without-a-lineage-check`).
    /// `has_personal_writes` del último claim. `false` por defecto: las suites de antes no pagan la comprobación y su
    /// camino no cambia. Los tests del linaje lo guionan.
    var claimPersonalWrites: Bool? = false
    func lastClaimReportedPersonalWrites() -> Bool? { claimPersonalWrites }
    /// Cola de desenlaces de `checkForwardLineage` (el último se repite).
    var lineageOutcomes: [ForwardLineageOutcome] = [.noLivePersonalRows]
    private var lineageIndex = 0
    var lineageCallCount = 0
    func checkForwardLineage() async -> ForwardLineageOutcome {
        lineageCallCount += 1
        let outcome = lineageOutcomes[min(lineageIndex, lineageOutcomes.count - 1)]
        lineageIndex += 1
        return outcome
    }


    /// Se llama al EMPEZAR cada `uploadSnapshot`, con el índice de la llamada (0-based). Lo pide el techo de la subida
    /// para que pase tiempo DENTRO de una pasada —entre una página confirmada y el intento siguiente—, que con un reloj
    /// fijo por `resume` no se puede montar.
    var onUploadSnapshot: ((Int) -> Void)?

    func uploadSnapshot(cursor: String?) async -> SnapshotStepOutcome {
        onUploadSnapshot?(uploadIndex)
        uploadCursorsSeen.append(cursor)
        leaseCallLog.append("upload")
        guard !uploadOutcomes.isEmpty else { return .transient }   // M3: guion vacío no trapea
        let outcome = uploadOutcomes[min(uploadIndex, uploadOutcomes.count - 1)]
        uploadIndex += 1
        return outcome
    }

    /// Con qué bandera pidió el runner cada verificación: la ida `true`, la vuelta `false`.
    var verifyLeaseFlags: [Bool] = []
    func verify(underMigrationLease: Bool) async -> VerifyProbe {
        verifyCallCount += 1
        verifyLeaseFlags.append(underMigrationLease)
        leaseCallLog.append("verify")
        guard !verifyProbes.isEmpty else { return .networkTimeout }   // M3: guion vacío no trapea
        let probe = verifyProbes[min(verifyIndex, verifyProbes.count - 1)]
        verifyIndex += 1
        return probe
    }

    /// Se llama DENTRO de cada `confirmCutoverServer`: el «sí» de «Cancelar» que llega con el cutover en vuelo.
    var onConfirmCutover: (() -> Void)?
    func confirmCutoverServer() async -> CutoverServerOutcome {
        confirmCutoverCallCount += 1
        onConfirmCutover?()
        return confirmCutoverOutcome
    }
    func persistLocalMode() async -> Bool { persistLocalModeCallCount += 1; return persistLocalModeResult }

    func execute(_ effect: MigrationEffect) async throws {
        executeAttempts.append(effect)                        // se INTENTÓ, lance o no
        onExecute?(effect)
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
    func sweepZombies(sinceSeq: Int64) async -> ZombieSweepOutcome {
        sweepCallCount += 1; sweptSinceSeqs.append(sinceSeq); return sweepOutcome
    }
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

    // Puerta del lease de la ida (ticket `displaced-migration-leader-keeps-uploading-after-a-takeover`): cola, el último se
    // repite. `leaseCallLog` apunta cada pregunta y cada llamada de trabajo en ORDEN, para probar que la puerta va DELANTE.
    var leaseChecks: [MigrationLeaseCheck] = [.held]
    private var leaseIndex = 0
    var leaseCheckCallCount = 0
    var leaseCallLog: [String] = []
    func confirmMigrationLease() async -> MigrationLeaseCheck {
        leaseCheckCallCount += 1
        leaseCallLog.append("lease")
        guard !leaseChecks.isEmpty else { return .held }
        let check = leaseChecks[min(leaseIndex, leaseChecks.count - 1)]
        leaseIndex += 1
        return check
    }

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
        // Y los dos acumulados de la espera: el de causa y el de «cualquier motivo definitivo» (ticket
        // `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`).
        reverseUploadCauseRaw: String? = nil, reverseUploadCauseAt: Date? = nil,
        reverseUploadCauseAccruedSeconds: Double? = nil,
        reverseUploadDefinitiveAt: Date? = nil, reverseUploadDefinitiveAccruedSeconds: Double? = nil,
        reverseAbortReasonRaw: String? = nil,
        // Techo de las cuatro fases previas al montaje: el reloj de FASE con la fase en la que se selló, y los
        // tres del reloj de CAUSA (ticket `…charges-a-stall-to-whoever-stops-it-last`).
        reversePreMountProgressAt: Date? = nil, reversePreMountPhaseRaw: String? = nil,
        reversePreMountCauseRaw: String? = nil, reversePreMountCauseAt: Date? = nil,
        reversePreMountCauseAccruedSeconds: Double? = nil,
        // Y los dos del reloj de «cualquier motivo definitivo» (ticket
        // `alternating-definitive-causes-never-reach-the-short-ceiling`).
        reversePreMountDefinitiveAt: Date? = nil, reversePreMountDefinitiveAccruedSeconds: Double? = nil,
        // La intención del claim de la ida (ticket `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`).
        forwardClaimIntentRaw: String? = nil,
        // Techo de `uploadingSnapshot`: los dos relojes y el motivo de la salida
        // (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`).
        snapshotStallProgressAt: Date? = nil, snapshotStallCauseRaw: String? = nil,
        snapshotStallCauseAt: Date? = nil, snapshotStallCauseAccruedSeconds: Double? = nil,
        // Y los dos del reloj de «cualquier motivo definitivo» de la subida (ticket
        // `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`).
        snapshotStallDefinitiveAt: Date? = nil, snapshotStallDefinitiveAccruedSeconds: Double? = nil,
        snapshotExitReasonRaw: String? = nil,
        // Techo de los tres pasos sin cifra que baje (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`).
        forwardStepStallProgressAt: Date? = nil, forwardStepStallCauseRaw: String? = nil,
        forwardStepStallCauseAt: Date? = nil, forwardStepStallCauseAccruedSeconds: Double? = nil,
        forwardStepExitReasonRaw: String? = nil,
        // La salida del claim de un adopt (ticket `adopt-claim-stays-parked-with-no-ceiling`).
        adoptClaimExitRaw: String? = nil, adoptClaimAccountHash: String? = nil,
        // Techo del efecto del adopt (ticket `adopt-effect-retries-forever-with-no-ceiling`).
        adoptEffectStallProgressAt: Date? = nil, adoptEffectStallDefinitiveAt: Date? = nil,
        adoptEffectStallDefinitiveAccruedSeconds: Double? = nil
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
        state.reverseUploadCauseRaw = reverseUploadCauseRaw
        state.reverseUploadCauseAt = reverseUploadCauseAt
        state.reverseUploadCauseAccruedSeconds = reverseUploadCauseAccruedSeconds
        state.reverseUploadDefinitiveAt = reverseUploadDefinitiveAt
        state.reverseUploadDefinitiveAccruedSeconds = reverseUploadDefinitiveAccruedSeconds
        state.reverseAbortReasonRaw = reverseAbortReasonRaw
        state.reversePreMountProgressAt = reversePreMountProgressAt
        state.reversePreMountPhaseRaw = reversePreMountPhaseRaw
        state.reversePreMountCauseRaw = reversePreMountCauseRaw
        state.reversePreMountCauseAt = reversePreMountCauseAt
        state.reversePreMountCauseAccruedSeconds = reversePreMountCauseAccruedSeconds
        state.reversePreMountDefinitiveAt = reversePreMountDefinitiveAt
        state.reversePreMountDefinitiveAccruedSeconds = reversePreMountDefinitiveAccruedSeconds
        state.forwardClaimIntentRaw = forwardClaimIntentRaw
        state.snapshotStallProgressAt = snapshotStallProgressAt
        state.snapshotStallCauseRaw = snapshotStallCauseRaw
        state.snapshotStallCauseAt = snapshotStallCauseAt
        state.snapshotStallCauseAccruedSeconds = snapshotStallCauseAccruedSeconds
        state.snapshotStallDefinitiveAt = snapshotStallDefinitiveAt
        state.snapshotStallDefinitiveAccruedSeconds = snapshotStallDefinitiveAccruedSeconds
        state.snapshotExitReasonRaw = snapshotExitReasonRaw
        state.forwardStepStallProgressAt = forwardStepStallProgressAt
        state.forwardStepStallCauseRaw = forwardStepStallCauseRaw
        state.forwardStepStallCauseAt = forwardStepStallCauseAt
        state.forwardStepStallCauseAccruedSeconds = forwardStepStallCauseAccruedSeconds
        state.forwardStepExitReasonRaw = forwardStepExitReasonRaw
        state.adoptClaimExitRaw = adoptClaimExitRaw
        state.adoptClaimAccountHash = adoptClaimAccountHash
        state.adoptEffectStallProgressAt = adoptEffectStallProgressAt
        state.adoptEffectStallDefinitiveAt = adoptEffectStallDefinitiveAt
        state.adoptEffectStallDefinitiveAccruedSeconds = adoptEffectStallDefinitiveAccruedSeconds
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
        fake.confirmCutoverOutcome = .transient  // corta en cutover(.pending)
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
        #expect(fake.executedEffects == [.persistICloudMode, .deleteCutoverCloudKitMarkers, .rollback],
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
        #expect(fake.executedEffects == [.persistICloudMode, .deleteCutoverCloudKitMarkers, .rollback])
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
        #expect(fake.executedEffects == [.persistICloudMode, .deleteCutoverCloudKitMarkers, .rollback])
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
        try seedJournal(context, phase: .done, adoptClaimExitRaw: "cancelled", adoptClaimAccountHash: "cuenta-a")

        await runner(context, fake).submit(.reverseActivated)
        #expect(try journal(context).readPhase().phase == .reverseConfirm(.done))

        await runner(context, fake).submit(.reverseConfirmed)   // → drive autónomo hasta icloudActive
        let final = try journal(context)
        #expect(final.readPhase().phase == .icloudActive)
        #expect(final.readPendingEffects().isEmpty)
        #expect(final.reverseOriginRaw == nil, "icloudActive limpia reverseOriginRaw (S2-cleanup extendido)")
        #expect(final.adoptClaimExitRaw == nil && final.adoptClaimAccountHash == nil,
                "de vuelta en iCloud, la salida de un adopt anterior ya no abre su tarjeta (adopt-claim-stays-parked-with-no-ceiling)")
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

    /// El barrido de zombies de la vuelta corta en el `serverSeqCut` del marcador del CUTOVER, no en el 0 de un marcador
    /// RELEVADO (ticket `markerless-adopt-stays-blocked-while-another-device-writes-to-the-account`): el relevo se inserta
    /// primero para que un `fetchLimit = 1` sin filtro lo devolviera a él.
    @Test func reverse_zombieSweep_cutsAtTheCutoverMarker_notAtARelayedOne() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.sweepOutcome = .transient               // corta en deletingZombies tras la llamada
        context.insert(CloudMigrationMarker(accountHash: "h", serverSeqCut: 0,
                                            writerDeviceID: CloudMigrationMarker.relayWriterPrefix + "ipad"))
        try context.save()
        context.insert(CloudMigrationMarker(accountHash: "h", serverSeqCut: 42, writerDeviceID: "leader"))
        try context.save()
        try seedJournal(context, phase: .reverseReconcile(.deletingZombies), reverseOriginRaw: "done")

        await runner(context, fake).resume()

        #expect(fake.sweptSinceSeqs == [42])
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

    /// La subida ya no late a ciegas tras cada página: pregunta por el lease ANTES de cada una y lee la respuesta (ticket
    /// `displaced-migration-leader-keeps-uploading-after-a-takeover`). Hasta ese ticket este test fijaba el latido tras
    /// cada `pageConfirmed`, cuya respuesta se tiraba. Tres pasadas de subida y una verificación: cuatro preguntas.
    @Test func heartbeat_uploadAsksForTheLeaseBeforeEveryPage_insteadOfABlindHeartbeat() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.pageConfirmed(cursor: "c1"), .pageConfirmed(cursor: "c2"), .completed]
        fake.verifyProbes = [.match]
        fake.confirmCutoverOutcome = .transient      // corta en cutover(.pending) tras el upload
        try seedJournal(context, phase: .uploadingSnapshot, leaderDeviceID: deviceID)

        await runner(context, fake).resume()

        #expect(fake.heartbeatCallCount == 0, "la subida ya no late a ciegas: la puerta la sustituye")
        #expect(fake.leaseCheckCallCount == 4, "una pregunta por pasada de subida (3) y otra por la verificación")
        #expect(fake.uploadCursorsSeen == [nil, "c1", "c2"])
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
        // Los dos acumulados sellados con el reloj de avance: iCloud lleno desde el principio.
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done",
                        reverseUploadLowestPending: 10, reverseUploadProgressAt: fixedNow,
                        reverseUploadCauseRaw: "icloudFull", reverseUploadCauseAt: fixedNow,
                        reverseUploadDefinitiveAt: fixedNow)

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

    /// La muestra ilegible como PRIMERA observación del intento: sella el reloj como cualquier primera observación, pero no
    /// inventa un mínimo. Con un mínimo de 0, ninguna cifra posterior contaría nunca como avance y el techo vencería
    /// sobre una subida sana. Y cuando el motivo cambia entre observaciones, la pantalla dice el de ahora.
    @Test func reverseUploadCeiling_unreadableFirstObservation_sealsClockButNoLowest() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseBlocker = .icloudFull
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")
        let r = makeRunner(context, fake, now: { clock.value })

        fake.reverseUploadStatuses = [.unreadable]
        await r.resume()
        var j = try journal(context)
        #expect(j.readPhase().phase == .reverseUpload)
        #expect(j.reverseUploadLowestPending == nil, "sin cifra no hay mínimo que inventar")
        #expect(j.reverseUploadProgressAt == fixedNow, "el reloj se sella como en cualquier primera observación")
        #expect(r.lastReverseUploadSample == nil, "sin observación buena, la pantalla dice «subiendo»")

        fake.reverseUploadStatuses = [.pending(count: 5)]
        clock.value = fixedNow.addingTimeInterval(300)
        await r.resume()
        j = try journal(context)
        #expect(j.reverseUploadLowestPending == 5, "la primera cifra buena fija el mínimo")
        #expect(r.lastReverseUploadSample == ReverseUploadSample(pending: 5, blocker: .icloudFull))

        fake.reverseBlocker = .unknown                          // la persona liberó espacio
        fake.reverseUploadStatuses = [.unreadable]
        clock.value = fixedNow.addingTimeInterval(400)
        await r.resume()
        #expect(r.lastReverseUploadSample == ReverseUploadSample(pending: 5, blocker: .unknown),
                "la cifra es la última buena; el motivo, el de ahora")
    }

    /// Una muestra que no pudo leer una tabla (ticket `an-incomplete-inventory-reads-as-the-whole-corpus`). No cierra la
    /// vuelta —sus filas pueden ser justo las pendientes— y NO es una cifra: una muestra parcial cuenta menos, y como
    /// `.pending` más baja reiniciaba el reloj del techo. Se sigue esperando con el reloj y el mínimo que había, la
    /// pantalla conserva la última observación buena, y el techo sigue venciendo: la avería no deja la vuelta colgada.
    @Test func reverseUploadCeiling_unreadableSample_neitherClosesNorAdvances_ceilingStillApplies() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseBlocker = .icloudFull                       // 900 s
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")
        let r = makeRunner(context, fake, now: { clock.value })

        fake.reverseUploadStatuses = [.pending(count: 10)]      // la observación buena: sella el reloj y la cifra
        await r.resume()
        #expect(r.lastReverseUploadSample == ReverseUploadSample(pending: 10, blocker: .icloudFull))

        fake.reverseUploadStatuses = [.unreadable]
        clock.value = fixedNow.addingTimeInterval(600)
        await r.resume()
        var j = try journal(context)
        #expect(j.readPhase().phase == .reverseUpload, "ilegible no es drenado: la vuelta NO se cierra")
        #expect(fake.executedEffects.isEmpty, "ni el cuarteto de cierre ni la salida")
        #expect(j.reverseUploadLowestPending == 10, "no toca el mínimo: una muestra parcial no es una cifra")
        #expect(j.reverseUploadProgressAt == fixedNow, "no es avance: el reloj del techo sigue donde estaba")
        #expect(r.lastReverseUploadSample == ReverseUploadSample(pending: 10, blocker: .icloudFull),
                "la pantalla conserva la última observación buena")
        #expect(fake.heartbeatCallCount == 2, "sigue latiendo: la espera sigue viva")

        // Y el techo no se suspende: con la avería persistente, a los 900 s del último avance la vuelta sale al origen.
        clock.value = fixedNow.addingTimeInterval(900)
        await r.resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .done, "la avería persistente no deja la vuelta colgada")
        #expect(fake.executedEffects == [.rearmMirrorOff, .reverseRollback])
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
                            reverseUploadLowestPending: 5, reverseUploadProgressAt: fixedNow,
                            reverseUploadCauseRaw: "icloudFull", reverseUploadCauseAt: fixedNow,
                            reverseUploadDefinitiveAt: fixedNow)

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
            #expect(j.reverseUploadCauseRaw == nil, "los dos acumulados se van con el intento (\(originRaw))")
            #expect(j.reverseUploadCauseAt == nil)
            #expect(j.reverseUploadCauseAccruedSeconds == nil)
            #expect(j.reverseUploadDefinitiveAt == nil)
            #expect(j.reverseUploadDefinitiveAccruedSeconds == nil)
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
                        reverseUploadLowestPending: 3, reverseUploadProgressAt: fixedNow,
                        reverseUploadCauseRaw: "icloudFull", reverseUploadCauseAt: fixedNow,
                        reverseUploadDefinitiveAt: fixedNow)

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
    /// re-sella con la observación, y el techo cuenta desde ahí. **Lo mide la primera aserción**: desde
    /// `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last` la salida a los 900 s la decide el reloj de lo
    /// definitivo, que se abre en la primera observación; el re-sellado del de avance lo fija `progressAt == fixedNow`.
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

    // MARK: - 13-bis. Los tres relojes de la espera (ticket `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`)

    /// Una observación de la espera en el segundo `at` desde `fixedNow`, con su motivo y su cifra. Cada una en un runner
    /// NUEVO: es lo que pasa en la realidad (un resume por re-kick o arranque) y obliga a que todo reloj viva en el
    /// journal, no en memoria.
    private func observeUpload(
        _ context: ModelContext, _ fake: FakeExecutor, at seconds: Double,
        _ blocker: ReverseUploadBlocker, pending: Int = 10
    ) async throws -> MigrationState {
        fake.reverseBlocker = blocker
        fake.reverseUploadStatuses = [.pending(count: pending)]
        let at = fixedNow.addingTimeInterval(seconds)
        await makeRunner(context, fake, now: { at }).resume()
        return try journal(context)
    }

    /// **EL test del ticket.** Tres horas esperando sin cuenta de iCloud —la espera observada, no sembrada— y el
    /// `notAuthenticated` que CloudKit suelta en la primera pasada al entrar. Hasta este ticket, la vuelta se cancelaba en
    /// ESA pasada: los 900 s del motivo nuevo se medían contra las tres horas sin avanzar. Ahora reintenta, y si el motivo
    /// sigue, sale a los 900 s de ESE motivo, con su texto.
    @Test func reverseUploadClocks_anIsolatedUnusableAfterHoursWithoutAccount_retriesInsteadOfLeaving() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        _ = try await observeUpload(context, fake, at: 0, .icloudOff)
        _ = try await observeUpload(context, fake, at: 5_400, .icloudOff)
        var j = try await observeUpload(context, fake, at: 10_800, .icloudUnusable)
        #expect(j.readPhase().phase == .reverseUpload, "el primer fallo tras tres horas sin cuenta NO saca de la vuelta")
        #expect(fake.executedEffects.isEmpty)
        #expect(j.reverseUploadProgressAt == fixedNow, "el reloj de avance sigue contando las tres horas: son del largo")
        #expect(j.reverseUploadDefinitiveAt == fixedNow.addingTimeInterval(10_800),
                "el de lo definitivo empieza AHORA: las horas sin cuenta no las acumuló")

        j = try await observeUpload(context, fake, at: 10_800 + 899, .icloudUnusable)
        #expect(j.readPhase().phase == .reverseUpload, "reintenta: 899 s de cuenta inutilizable no son 900")
        #expect(fake.executedEffects.isEmpty)

        j = try await observeUpload(context, fake, at: 10_800 + 900, .icloudUnusable)
        #expect(j.readPhase().phase == .done, "sostenido 900 s, sale")
        #expect(fake.executedEffects == [.rearmMirrorOff, .reverseRollback])
        #expect(j.reverseAbortReasonRaw == "icloudUnavailable", "un solo motivo agotó el plazo: lleva su texto")
    }

    /// El otro lado del criterio: iCloud lleno, observado desde el principio con la cadencia del re-kick, sigue saliendo
    /// a los 900 s de espera REAL con ese motivo. Si el reloj de lo definitivo no persistiera entre pasadas, esto no
    /// terminaría nunca por el corto.
    @Test func reverseUploadClocks_aRepeatedFullStillLeavesAt900SecondsOfItsOwn() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        for at in stride(from: 0.0, through: 870, by: 30) {
            let j = try await observeUpload(context, fake, at: at, .icloudFull)
            #expect(j.readPhase().phase == .reverseUpload, "\(at) s: espera")
        }
        var j = try await observeUpload(context, fake, at: 899, .icloudFull)
        #expect(j.readPhase().phase == .reverseUpload)
        #expect(j.reverseUploadDefinitiveAt == fixedNow, "el tramo sigue abierto desde la primera observación")

        j = try await observeUpload(context, fake, at: 900, .icloudFull)
        #expect(j.readPhase().phase == .done)
        #expect(j.reverseAbortReasonRaw == "icloudFull")
    }

    /// Un rato sin cuenta de iCloud entre dos tramos de iCloud lleno PAUSA los dos acumulados, no los borra: 610 s
    /// antes, tres horas sin cuenta que no cuentan, y 290 s después hacen los 900. El texto sigue siendo el de iCloud
    /// lleno: el reloj de causa también pausó, porque `icloudOff` no es otro motivo definitivo sino la ausencia de uno.
    @Test func reverseUploadClocks_aWaitWithoutAccount_pausesInsteadOfResetting() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        _ = try await observeUpload(context, fake, at: 0, .icloudFull)
        _ = try await observeUpload(context, fake, at: 600, .icloudFull)
        var j = try await observeUpload(context, fake, at: 610, .icloudOff)
        #expect(j.reverseUploadDefinitiveAt == nil, "sin motivo definitivo el tramo se CIERRA")
        #expect(j.reverseUploadDefinitiveAccruedSeconds == 610, "y lo acumulado se conserva")
        #expect(j.reverseUploadCauseRaw == "icloudFull", "la causa sigue puesta: pausada, no borrada")

        j = try await observeUpload(context, fake, at: 10_800, .icloudOff)
        #expect(j.readPhase().phase == .reverseUpload)
        #expect(j.reverseUploadDefinitiveAccruedSeconds == 610, "tres horas sin cuenta no suman nada")

        j = try await observeUpload(context, fake, at: 10_810, .icloudFull)
        #expect(j.readPhase().phase == .reverseUpload, "vuelve el motivo: reabre el tramo con 610 s")
        j = try await observeUpload(context, fake, at: 10_810 + 289, .icloudFull)
        #expect(j.readPhase().phase == .reverseUpload, "610 + 289 = 899")
        j = try await observeUpload(context, fake, at: 10_810 + 290, .icloudFull)
        #expect(j.readPhase().phase == .done, "610 + 290 = 900")
        #expect(j.reverseAbortReasonRaw == "icloudFull", "el de causa también sumó a través de la pausa")
    }

    /// Un AVANCE reinicia los dos acumulados: si la cifra bajó, algo subió, y lo acumulado antes describía otra espera.
    /// 800 s de iCloud lleno, la cifra baja, y hacen falta otros 900 s para salir.
    @Test func reverseUploadClocks_anAdvance_resetsBothAccruedClocks() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        _ = try await observeUpload(context, fake, at: 0, .icloudFull, pending: 10)
        _ = try await observeUpload(context, fake, at: 800, .icloudFull, pending: 10)
        var j = try await observeUpload(context, fake, at: 850, .icloudFull, pending: 9)
        #expect(j.reverseUploadProgressAt == fixedNow.addingTimeInterval(850), "avanzó: re-sella el de avance")
        #expect(j.reverseUploadDefinitiveAt == fixedNow.addingTimeInterval(850), "y el definitivo empieza de cero")
        #expect(j.reverseUploadDefinitiveAccruedSeconds == 0)

        j = try await observeUpload(context, fake, at: 850 + 899, .icloudFull, pending: 9)
        #expect(j.readPhase().phase == .reverseUpload, "con lo de antes serían 1749 s y habría salido")
        j = try await observeUpload(context, fake, at: 850 + 900, .icloudFull, pending: 9)
        #expect(j.readPhase().phase == .done)
    }

    /// El reloj de CAUSA también se reinicia con el avance, y se ve en el TEXTO: 900 s de iCloud lleno repartidos a los dos
    /// lados de un avance no son un motivo que agotó solo su plazo. La salida llega después por las 72 h, y tiene que
    /// decir `stalled`: arrastrar lo de antes del avance le diría «iCloud está lleno» a quien lleva tres días sin cuenta.
    @Test func reverseUploadClocks_anAdvance_resetsTheCauseClockToo_theTextSaysStalled() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        _ = try await observeUpload(context, fake, at: 0, .icloudFull, pending: 10)
        _ = try await observeUpload(context, fake, at: 899, .icloudFull, pending: 10)
        _ = try await observeUpload(context, fake, at: 900, .icloudFull, pending: 9)       // avance
        var j = try await observeUpload(context, fake, at: 910, .icloudOff, pending: 9)
        #expect(j.reverseUploadCauseAccruedSeconds == 10, "tras el avance la causa lleva 10 s, no 910")

        j = try await observeUpload(context, fake, at: 900 + 259_200, .icloudFull, pending: 9)
        #expect(j.readPhase().phase == .done, "las 72 h sin avanzar vencen")
        #expect(j.reverseAbortReasonRaw == "stalled")
    }

    /// Los dos motivos definitivos turnándose SUMAN en el reloj de lo definitivo: sin eso, cada cambio lo reiniciaría y,
    /// con el re-kick de 30 s, la salida se iría a las 72 h (el agujero de
    /// `alternating-definitive-causes-never-reach-the-short-ceiling`). Salen a los 900 s, y con `stalled`: ninguno de los
    /// dos textos es verdad entero.
    @Test func reverseUploadClocks_alternatingDefinitiveCauses_leaveAtTheShortCeiling_withTheGenericText() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        var at = 0.0
        var full = true
        while at < 899 {
            let j = try await observeUpload(context, fake, at: at, full ? .icloudFull : .icloudUnusable)
            #expect(j.readPhase().phase == .reverseUpload, "\(at) s: espera")
            at += 30
            full.toggle()
        }
        var j = try await observeUpload(context, fake, at: 899, .icloudFull)
        #expect(j.readPhase().phase == .reverseUpload)
        j = try await observeUpload(context, fake, at: 900, .icloudUnusable)
        #expect(j.readPhase().phase == .done, "900 s bajo motivos definitivos, aunque turnándose")
        #expect(j.reverseAbortReasonRaw == "stalled", "ninguno de los dos motivos agotó SOLO el plazo")
    }

    /// El techo LARGO sigue por encima con cualquier motivo, y el texto lo elige el techo que VENCIÓ: 72 h sin avanzar,
    /// casi todas sin cuenta, y la pasada que las cruza trae un iCloud lleno recién visto. Sale —el largo no depende del
    /// motivo— y con `stalled`, no con «iCloud está lleno».
    @Test func reverseUploadClocks_theLongCeiling_leavesWithAnyCause_andTheTextIsStalled() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        _ = try await observeUpload(context, fake, at: 0, .icloudFull)
        _ = try await observeUpload(context, fake, at: 600, .icloudOff)
        var j = try await observeUpload(context, fake, at: 259_199, .icloudFull)
        #expect(j.readPhase().phase == .reverseUpload, "un segundo antes de las 72 h, y con 600 s definitivos: espera")
        j = try await observeUpload(context, fake, at: 259_200, .icloudFull)
        #expect(j.readPhase().phase == .done, "a las 72 h sale, traiga el motivo que traiga")
        #expect(fake.executedEffects == [.rearmMirrorOff, .reverseRollback])
        #expect(j.reverseAbortReasonRaw == "stalled", "venció el largo: el texto no acusa a iCloud")
    }

    /// **Un solo cambio de motivo, y luego sostenido** (lente de tests de la review): 600 s de iCloud lleno y 300 s de
    /// cuenta inutilizable hacen los 900 s del reloj de lo definitivo, pero NINGUNO de los dos agotó solo el plazo. La
    /// salida lleva `stalled`. Es el único caso que separa el reloj de causa del de lo definitivo cuando el motivo no
    /// cambia en cada pasada: con los dos relojes confundidos, la salida diría «cuenta no disponible».
    @Test func reverseUploadClocks_oneSwitchOfCause_thenSustained_leavesWithTheGenericText() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        for at in stride(from: 0.0, through: 600, by: 30) {
            _ = try await observeUpload(context, fake, at: at, .icloudFull)
        }
        for at in stride(from: 630.0, through: 870, by: 30) {
            _ = try await observeUpload(context, fake, at: at, .icloudUnusable)
        }
        var j = try await observeUpload(context, fake, at: 899, .icloudUnusable)
        #expect(j.readPhase().phase == .reverseUpload)
        #expect(j.reverseUploadCauseAt == fixedNow.addingTimeInterval(630), "el de causa empezó con el cambio de motivo")
        #expect(j.reverseUploadDefinitiveAt == fixedNow, "el de lo definitivo no se reinició")

        j = try await observeUpload(context, fake, at: 900, .icloudUnusable)
        #expect(j.readPhase().phase == .done, "900 s bajo motivos definitivos")
        #expect(j.reverseAbortReasonRaw == "stalled", "la cuenta solo llevaba 270 s: su texto no sería verdad")
    }

    /// Un avance reinicia también lo acumulado en tramos CERRADOS, no solo el tramo abierto: 610 s de iCloud lleno, una
    /// pausa, y un avance a los 700. Lo correcto es salir a los 900 s del avance (1600); arrastrar los 610 s haría salir a
    /// los 990.
    @Test func reverseUploadClocks_anAdvanceAfterAPause_dropsWhatWasAccrued() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        _ = try await observeUpload(context, fake, at: 0, .icloudFull, pending: 10)
        _ = try await observeUpload(context, fake, at: 610, .icloudOff, pending: 10)
        var j = try await observeUpload(context, fake, at: 700, .icloudFull, pending: 9)     // avance
        #expect(j.reverseUploadDefinitiveAccruedSeconds == 0, "lo cerrado antes del avance no se arrastra")
        #expect(j.reverseUploadCauseAccruedSeconds == 0)

        j = try await observeUpload(context, fake, at: 990, .icloudFull, pending: 9)
        #expect(j.readPhase().phase == .reverseUpload, "con los 610 s arrastrados habría salido aquí")
        j = try await observeUpload(context, fake, at: 1_599, .icloudFull, pending: 9)
        #expect(j.readPhase().phase == .reverseUpload)
        j = try await observeUpload(context, fake, at: 1_600, .icloudFull, pending: 9)
        #expect(j.readPhase().phase == .done)
        #expect(j.reverseAbortReasonRaw == "icloudFull")
    }

    /// Una muestra ILEGIBLE no es avance, y el motivo definitivo que trae SÍ acumula: la avería de la muestra no puede
    /// suspender el techo corto. Sin cifra buena desde el principio, los 900 s de iCloud lleno siguen sacando.
    @Test func reverseUploadClocks_anUnreadableSample_stillAccruesItsDefinitiveCause() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")
        fake.reverseBlocker = .icloudFull
        fake.reverseUploadStatuses = [.unreadable]

        await makeRunner(context, fake, now: { self.fixedNow }).resume()
        await makeRunner(context, fake, now: { self.fixedNow.addingTimeInterval(899) }).resume()
        var j = try journal(context)
        #expect(j.readPhase().phase == .reverseUpload)
        #expect(j.reverseUploadDefinitiveAt == fixedNow)
        #expect(j.reverseUploadLowestPending == nil, "sin cifra no hay mínimo")

        await makeRunner(context, fake, now: { self.fixedNow.addingTimeInterval(900) }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .done)
        #expect(j.reverseAbortReasonRaw == "icloudFull")
    }

    /// **Una fila de un build anterior (v14) a mitad de espera**, SEMBRADA como la deja ese build: tres horas de reloj de
    /// avance y ningún campo de los acumulados. La primera pasada con iCloud lleno no sale: el corto le cuenta desde que
    /// este build la mira. Y el largo conserva sus tres horas.
    @Test func reverseUploadClocks_aV14RowMidWait_startsTheShortCeilingNow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done",
                        reverseUploadLowestPending: 10, reverseUploadProgressAt: fixedNow)

        var j = try await observeUpload(context, fake, at: 10_800, .icloudFull)
        #expect(j.readPhase().phase == .reverseUpload, "tres horas de avance no son tres horas de iCloud lleno")
        #expect(j.reverseUploadProgressAt == fixedNow, "el largo sigue contando desde su sello")
        #expect(j.reverseUploadDefinitiveAt == fixedNow.addingTimeInterval(10_800))
        j = try await observeUpload(context, fake, at: 10_800 + 900, .icloudFull)
        #expect(j.readPhase().phase == .done)
    }

    /// Un tramo definitivo sellado en el FUTURO —el reloj iba adelantado y ya se corrigió— se re-ancla AHORA en vez de
    /// aplazar el techo corto diez días, y conserva lo acumulado en tramos cerrados.
    @Test func reverseUploadClocks_aFutureOpenTramo_isReAnchoredKeepingWhatWasAccrued() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        let future = fixedNow.addingTimeInterval(10 * 86_400)
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done",
                        reverseUploadLowestPending: 10, reverseUploadProgressAt: fixedNow,
                        reverseUploadCauseRaw: "icloudFull", reverseUploadCauseAt: future,
                        reverseUploadCauseAccruedSeconds: 300,
                        reverseUploadDefinitiveAt: future, reverseUploadDefinitiveAccruedSeconds: 300)

        var j = try await observeUpload(context, fake, at: 100, .icloudFull)
        #expect(j.readPhase().phase == .reverseUpload)
        #expect(j.reverseUploadDefinitiveAt == fixedNow.addingTimeInterval(100), "re-anclado a la observación")
        #expect(j.reverseUploadDefinitiveAccruedSeconds == 300, "lo cerrado se conserva")
        j = try await observeUpload(context, fake, at: 699, .icloudFull)
        #expect(j.readPhase().phase == .reverseUpload, "300 + 599")
        j = try await observeUpload(context, fake, at: 700, .icloudFull)
        #expect(j.readPhase().phase == .done, "300 + 600 = 900, no diez días después")
        #expect(j.reverseAbortReasonRaw == "icloudFull")
    }

    /// **El hueco SIN observaciones cuenta**, la regla de la familia (`reversePreMountDefinitiveClock_anUnobservedGapBetweenTwoCauses_counts`):
    /// un tramo abierto sigue abierto con la app cerrada, porque no se pudo preguntar si el motivo se fue. Fijado aquí
    /// también para que cambiarlo sea una decisión de las cinco etapas a la vez, con su ticket
    /// (`stall-clock-charges-a-closed-app-gap-to-a-one-off-cause`), y no un efecto lateral.
    @Test func reverseUploadClocks_anUnobservedGap_counts() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseUpload, reverseOriginRaw: "done")

        _ = try await observeUpload(context, fake, at: 0, .icloudFull)
        // Yala cerrada 20 min; al volver, el mismo motivo.
        let j = try await observeUpload(context, fake, at: 1_200, .icloudFull)
        #expect(j.readPhase().phase == .done, "el tramo siguió abierto los 1200 s")
        #expect(j.reverseAbortReasonRaw == "icloudFull")
    }

    /// Los dos sitios de limpieza que ningún otro test recorría (lente de tests): el reset tras un rollback y la
    /// normalización de un journal ilegible. Sembrados a mano, o «nil al final» no mediría nada.
    @Test func reverseUploadCeiling_resetAfterRollback_andACorruptJournal_clearTheWholeFamily() async throws {
        for corrupt in [false, true] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            let state = try seedJournal(
                context, phase: corrupt ? .reverseUpload : .failedRollback, reverseOriginRaw: "done",
                reverseUploadLowestPending: 4, reverseUploadProgressAt: fixedNow,
                reverseUploadCauseRaw: "icloudFull", reverseUploadCauseAt: fixedNow,
                reverseUploadCauseAccruedSeconds: 800, reverseUploadDefinitiveAt: fixedNow,
                reverseUploadDefinitiveAccruedSeconds: 800)
            if corrupt {
                state.phaseData = Data("no-es-una-fase".utf8)
                try context.save()
                await makeRunner(context, fake).resume()
            } else {
                await makeRunner(context, fake).resetAfterRollback()
            }
            let j = try journal(context)
            #expect(j.readPhase().phase == .notStarted, "corrupt=\(corrupt)")
            #expect(j.reverseUploadLowestPending == nil, "corrupt=\(corrupt)")
            #expect(j.reverseUploadProgressAt == nil, "corrupt=\(corrupt)")
            #expect(j.reverseUploadCauseRaw == nil, "corrupt=\(corrupt)")
            #expect(j.reverseUploadCauseAt == nil, "corrupt=\(corrupt)")
            #expect(j.reverseUploadCauseAccruedSeconds == nil, "corrupt=\(corrupt)")
            #expect(j.reverseUploadDefinitiveAt == nil, "corrupt=\(corrupt)")
            #expect(j.reverseUploadDefinitiveAccruedSeconds == nil, "corrupt=\(corrupt)")
        }
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
        // Los relojes de la espera sembrados a mano, como el motivo: sin ellos, «nil al final» no mediría la limpieza.
        try seedJournal(context, phase: .reverseConfirm(.done),
                        reverseUploadLowestPending: 4, reverseUploadProgressAt: fixedNow,
                        reverseUploadCauseRaw: "icloudFull", reverseUploadCauseAt: fixedNow,
                        reverseUploadCauseAccruedSeconds: 800, reverseUploadDefinitiveAt: fixedNow,
                        reverseUploadDefinitiveAccruedSeconds: 800, reverseAbortReasonRaw: "stalled")

        await runner(context, fake).submit(.reverseConfirmed)

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseClaimLeader)
        #expect(j.reverseAbortReasonRaw == nil)
        // Una vuelta nueva no hereda lo acumulado por la anterior: con 800 s heredados, el techo corto de la espera
        // nueva vencería a los 100 s.
        #expect(j.reverseUploadCauseRaw == nil)
        #expect(j.reverseUploadCauseAt == nil)
        #expect(j.reverseUploadCauseAccruedSeconds == nil)
        #expect(j.reverseUploadDefinitiveAt == nil)
        #expect(j.reverseUploadDefinitiveAccruedSeconds == nil)
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
                        reverseUploadCauseRaw: "icloudUnusable", reverseUploadCauseAt: fixedNow,
                        reverseUploadCauseAccruedSeconds: 30, reverseUploadDefinitiveAt: fixedNow,
                        reverseUploadDefinitiveAccruedSeconds: 30, reverseAbortReasonRaw: "stalled")

        let r = runner(context, fake)
        await r.resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .icloudActive)
        #expect(j.reverseUploadLowestPending == nil)
        #expect(j.reverseUploadProgressAt == nil)
        #expect(j.reverseUploadCauseRaw == nil)
        #expect(j.reverseUploadCauseAt == nil)
        #expect(j.reverseUploadCauseAccruedSeconds == nil)
        #expect(j.reverseUploadDefinitiveAt == nil)
        #expect(j.reverseUploadDefinitiveAccruedSeconds == nil)
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
            let clock = MutableClock(fixedNow)
            try seedJournal(context, phase: phase, reverseOriginRaw: "done",
                            reversePreMountProgressAt: fixedNow,
                            reversePreMountPhaseRaw: ReversePreMountPhase(phase: phase)?.rawValue)

            // Dos pasadas, y la primera NO saca a nadie: desde el ticket
            // `…charges-a-stall-to-whoever-stops-it-last` el techo corto cuenta desde que este motivo apareció, no
            // desde que la fase se paró. La primera observación sella su reloj; la segunda, 900 s después, lo agota.
            await makeRunner(context, fake, now: { clock.value }).resume()
            #expect(try journal(context).readPhase().phase == phase,
                    "\(label): la primera vez que se ve el motivo no saca de la vuelta")
            clock.value = fixedNow.addingTimeInterval(900)
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
            // La red PURA del verify entra a la tabla el 2026-09-21 (ticket
            // `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`). Era la única de las OCHO
            // combinaciones fase × causa que se quedaba fuera del techo.
            (.reverseVerify, "verify/red", { $0.verifyProbes = [.networkTimeout] }),
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

    // MARK: - El RELOJ POR CAUSA del techo previo al montaje
    // (ticket `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`)

    /// **EL caso del ticket.** Tres horas volviendo a iCloud sin cobertura —correcto: la red vuelve sola— y en la
    /// pasada en la que vuelve el wifi, un `fetch` de la base local falla UNA vez. Hasta este ticket el techo corto
    /// de ese motivo se cobraba contra el reloj de la FASE: `10 800 >= 900` salía a la primera y la vuelta se
    /// abandonaba en ese instante, sin un solo reintento. Ahora holdea, y el mismo fallo a los dos minutos de
    /// empezar se comporta igual que a las tres horas.
    ///
    /// Las dos aserciones del journal son las que hacen el caso discriminante, y no adornan: el reloj de FASE
    /// **no se toca** (ese sigue midiendo las tres horas, y es el que a las 72 h saca de la vuelta pase lo que
    /// pase) y el de CAUSA se sella AHORA. Un mutante que sellara el de causa con `lastProgressAt` —la línea de al
    /// lado— dejaría el hold en verde y el bug intacto.
    @Test func reversePreMountCauseClock_anIsolatedLocalFailureAfterALongWait_retriesInsteadOfLeaving() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.blocked(.localFailure)]
        let threeHours = fixedNow.addingTimeInterval(10_800)
        let clock = MutableClock(threeHours)
        // Tres horas paradas en `verify` SIN causa sellada: así es como llega una espera por red, que no trae motivo.
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify")

        await makeRunner(context, fake, now: { clock.value }).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseVerify,
                "el fallo local es de ESTA pasada: las tres horas eran de otra cosa y no se le cobran")
        #expect(j.reverseAbortReasonRaw == nil, "no salió, así que no hay nada que explicarle a nadie")
        #expect(fake.count(.reverseRollback) == 0, "y no se des-reservó el servidor")
        #expect(j.reversePreMountProgressAt == fixedNow, "el reloj de la FASE sigue midiendo las tres horas")
        #expect(j.reversePreMountCauseAt == threeHours, "y el de la CAUSA empieza AHORA, que es cuando apareció")
        #expect(j.reversePreMountCauseRaw == "localFailure")
        // Y el de lo DEFINITIVO, que es el que hoy decide el techo corto, también: las tres horas de red no traían
        // motivo, así que no las acumuló (ticket `alternating-definitive-causes-never-reach-the-short-ceiling`).
        #expect(j.reversePreMountDefinitiveAt == threeHours, "el reloj de lo definitivo también empieza AHORA")
        #expect(j.reversePreMountDefinitiveAccruedSeconds == 0, "sin nada cerrado que cobrarle")

        // Y REINTENTA de verdad: la pasada siguiente vuelve a llamar al verify, que es lo que el ticket pide.
        let callsAfterFirst = fake.verifyCallCount
        clock.value = threeHours.addingTimeInterval(30)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(fake.verifyCallCount > callsAfterFirst, "la vuelta sigue viva y lo intenta otra vez")
        #expect(try journal(context).readPhase().phase == .reverseVerify)
    }

    /// El otro lado del trato, y el que impide «arreglar» el ticket holdeando siempre: **un motivo REPETIDO sí
    /// vence su techo, a los 900 s de parada real con él**. El reloj de fase aquí no llega ni de lejos al largo, así
    /// que la salida solo puede venir del de causa.
    ///
    /// Se clava con sus dos vecinos —899 s holdea, 900 s sale— porque un `>=` cambiado por `>` no se ve de otra
    /// forma, y porque el número es una decisión de producto que ya estaba escrita.
    @Test func reversePreMountCauseClock_aRepeatedRefusalStillLeavesAt900SecondsOfItsOwn() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.blocked(.accountUnavailable)]
        let threeHours = fixedNow.addingTimeInterval(10_800)
        let clock = MutableClock(threeHours)
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify")

        await makeRunner(context, fake, now: { clock.value }).resume()          // sella la racha
        clock.value = threeHours.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .reverseVerify, "a 899 s de racha todavía no")

        clock.value = threeHours.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .done, "a 900 s de parada REAL con ese motivo, sale")
        #expect(j.reverseAbortReasonRaw == "preMountRefused")
        #expect(fake.count(.reverseRollback) == 1, "el abort best-effort, una vez")
    }

    /// **Una observación SIN motivo PAUSA el reloj de la causa; no lo borra.** La distinción es todo el
    /// mecanismo, y la cazó la review: con una racha consecutiva, la pantalla de Almacenamiento re-kickea cada
    /// 30 s, así que una cuenta suspendida con cobertura intermitente bastaba con un timeout cada quince minutos
    /// para que los 900 s no llegaran NUNCA — el techo corto se volvía inalcanzable justo cuando más se mira, y el
    /// desenlace pasaba de 15 min a 72 h. Con el acumulado, el hueco no cuenta ni a favor ni en contra.
    ///
    /// El guion mide las dos mitades en la misma corrida: 840 s de 403 · una pasada sin cobertura · 60 s más de
    /// 403. Son 900 s ACUMULADOS bajo el 403 y la vuelta sale; el hueco de la red no se los regaló ni se los
    /// quitó.
    @Test func reversePreMountCauseClock_anObservationWithoutACause_pausesInsteadOfResetting() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        // 403 · 403 · red · 403 — el tercero PAUSA y el cuarto reanuda desde lo acumulado.
        fake.verifyProbes = [.blocked(.accountUnavailable), .blocked(.accountUnavailable),
                             .networkTimeout, .blocked(.accountUnavailable)]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify")

        await makeRunner(context, fake, now: { clock.value }).resume()          // t=0    abre el tramo del 403
        clock.value = fixedNow.addingTimeInterval(840)                          // t=840  14 min bajo el 403
        await makeRunner(context, fake, now: { clock.value }).resume()
        let midRun = try journal(context)
        #expect(midRun.readPhase().phase == .reverseVerify, "14 min todavía no son 15")
        #expect(midRun.reversePreMountCauseAt == fixedNow, "el tramo sigue ABIERTO desde el principio")
        #expect(midRun.reversePreMountCauseAccruedSeconds == 0, "y nada cerrado todavía")

        clock.value = fixedNow.addingTimeInterval(870)                          // t=870  se cae la red
        await makeRunner(context, fake, now: { clock.value }).resume()
        let paused = try journal(context)
        #expect(paused.readPhase().phase == .reverseVerify)
        #expect(paused.reversePreMountCauseRaw == "accountUnavailable",
                "la causa se CONSERVA: el hueco no prueba que el 403 se fuera, solo que no se pudo preguntar")
        #expect(paused.reversePreMountCauseAt == nil, "pero el tramo se cierra")
        #expect(paused.reversePreMountCauseAccruedSeconds == 870, "y lo corrido queda acumulado")

        // t=1_200: el hueco duró 330 s y NO cuenta. El 403 vuelve y reabre el tramo con 870 s en la mochila.
        clock.value = fixedNow.addingTimeInterval(1_200)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let resumed = try journal(context)
        #expect(resumed.readPhase().phase == .reverseVerify,
                "al reanudar lleva 870 s acumulados, no los 1 200 de fase parada")
        #expect(resumed.reversePreMountCauseAt == fixedNow.addingTimeInterval(1_200), "tramo nuevo, desde ahora")
        #expect(resumed.reversePreMountCauseAccruedSeconds == 870)

        // t=1_230: 870 acumulados + 30 del tramo abierto = 900. Sale.
        clock.value = fixedNow.addingTimeInterval(1_230)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .done,
                "900 s ACUMULADOS bajo el 403 sí agotan su techo, aunque vinieran en dos tramos")
    }

    /// **La clave del reloj de CAUSA es su `rawValue`, no el texto que se le enseña a la persona.**
    /// `accountUnavailable` y `refused` COMPARTEN `abortReason` (`preMountRefused`), así que un mecanismo que
    /// sellara por el motivo journaleado fundiría sus dos relojes y sumaría dos causas como si fueran una. Desde
    /// `alternating-definitive-causes-never-reach-the-short-ceiling` eso ya no decide CUÁNDO se sale —lo decide el
    /// reloj de lo definitivo, que suma los dos a propósito— sino QUÉ se le dice a la persona y qué publica el
    /// canario. Por eso el caso mide las dos cosas: sale a los 900 s de la suma, y con el copy genérico, porque
    /// ninguna de las dos causas llegó sola.
    @Test func reversePreMountCauseClock_twoCausesSharingTheirCopy_keepSeparateClocks() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        // 403 (drain) y rechazo (freeze) no comparten fase, así que los dos se observan en `verify` desde el
        // mismo sitio.
        fake.verifyProbes = [.blocked(.accountUnavailable), .blocked(.refused), .blocked(.accountUnavailable)]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify")

        for offset in [0.0, 450] {
            clock.value = fixedNow.addingTimeInterval(offset)
            await makeRunner(context, fake, now: { clock.value }).resume()
            let j = try journal(context)
            #expect(j.readPhase().phase == .reverseVerify, "en \(offset)s: todavía no son 900 s de nada")
            #expect(j.reversePreMountCauseAt == clock.value,
                    "en \(offset)s: dos motivos con el MISMO copy siguen siendo dos relojes de causa — el tramo se reabre")
        }

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .done, "900 s bajo motivos definitivos, aunque se turnen, sacan de la vuelta")
        #expect(j.reverseAbortReasonRaw == "preMountStalled",
                "el reloj de causa se reinició en cada cambio, así que ninguno de los dos se ganó su texto")
    }

    /// **El cambio de fase reinicia el reloj de causa**, y quien lo garantiza es el `clearReversePreMountCeiling()`
    /// del `handle` — no la lectura, que a propósito no comprueba la fase. Este caso es el que mata al mutante que
    /// devuelva ese call site a limpiar solo los dos campos del reloj de FASE: sin él, la segunda visita a una fase
    /// heredaría lo acumulado de la primera y el techo saltaría con cero segundos de parada real en ella.
    ///
    /// El camino es el que la regla de área señala como el que muerde: `reverseVerify` vuelve a `reverseDrainAll`
    /// por mismatch, con la MISMA causa a los dos lados.
    @Test func reversePreMountCauseClock_changingPhase_resetsTheAccumulatedCause() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.mismatch]                     // manda la vuelta de `verify` a `drain`
        fake.reverseDrainOutcomes = [.blocked(.accountUnavailable)]
        let clock = MutableClock(fixedNow)
        // Se siembra `verify` con 880 s YA acumulados bajo el 403: a 20 s de su techo.
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify",
                        reversePreMountCauseRaw: "accountUnavailable",
                        reversePreMountCauseAt: nil, reversePreMountCauseAccruedSeconds: 880,
                        reversePreMountDefinitiveAt: nil, reversePreMountDefinitiveAccruedSeconds: 880)

        await makeRunner(context, fake, now: { clock.value }).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseDrainAll, "el mismatch la devuelve al drenaje")
        #expect(j.reversePreMountCauseAccruedSeconds == 0,
                "y los 880 s del 403 en `verify` NO viajan con ella: en el drenaje empieza de cero")
        #expect(j.reversePreMountDefinitiveAccruedSeconds == 0,
                "tampoco en el reloj de lo definitivo, que es el que decide la salida")

        // 30 s después, con el mismo 403 en la fase nueva: si hubiera heredado los 880, ya habría salido.
        clock.value = fixedNow.addingTimeInterval(30)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .reverseDrainAll,
                "30 s de 403 en el drenaje no son 910: sigue esperando")
    }

    /// El sello del tramo abierto en el FUTURO —el reloj del teléfono iba adelantado durante la espera y luego se
    /// corrigió— se descarta y el tramo se re-abre AHORA, igual que hace el reloj de FASE con el suyo. Sin esto el
    /// tramo contaría negativo y el techo corto quedaría aplazado hasta que el reloj real alcanzara esa fecha.
    ///
    /// Va con lo ACUMULADO puesto a la vez, que es lo que separa «re-abrir el tramo» de «tirar el reloj entero»:
    /// los 400 s ya cerrados sobreviven al salto de reloj.
    @Test func reversePreMountCauseClock_aFutureOpenTramo_isReAnchoredKeepingWhatWasAccrued() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.blocked(.accountUnavailable)]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify",
                        reversePreMountCauseRaw: "accountUnavailable",
                        reversePreMountCauseAt: fixedNow.addingTimeInterval(100_000),
                        reversePreMountCauseAccruedSeconds: 400,
                        reversePreMountDefinitiveAt: fixedNow.addingTimeInterval(100_000),
                        reversePreMountDefinitiveAccruedSeconds: 400)

        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseVerify, "el sello futuro no saca a nadie, ni aplaza el techo")
        #expect(j.reversePreMountCauseAt == fixedNow, "el tramo se re-ancla AHORA")
        #expect(j.reversePreMountCauseAccruedSeconds == 400, "y lo ya acumulado se conserva")
        #expect(j.reversePreMountDefinitiveAt == fixedNow, "el reloj de lo definitivo se re-ancla igual")
        #expect(j.reversePreMountDefinitiveAccruedSeconds == 400)

        // 500 s después: 400 acumulados + 500 del tramo re-anclado = 900. Sale.
        clock.value = fixedNow.addingTimeInterval(500)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .done,
                "y desde el re-anclaje el techo vence cuando toca, no cien mil segundos después")
    }

    /// **El motivo journaleado lo elige el techo que VENCIÓ, no la última observación.** Con el reloj por causa la
    /// vuelta puede salir por el techo de la FASE en una pasada que casualmente traiga un motivo recién visto:
    /// 72 h sin cobertura y, en la pasada que cruza el plazo, el servidor contesta 403 por primera vez. Journalear
    /// `preMountRefused` ahí le diría a la persona «tu cuenta en la nube no lo permitió» y le daría el correo de
    /// soporte por tres días sin red. Lo cazaron dos lentes de la review.
    ///
    /// El control en la dirección contraria está en `aRepeatedRefusalStillLeavesAt900SecondsOfItsOwn`: cuando el
    /// que vence es el techo de la causa, el motivo SÍ es el del blocker. Sin esa mitad, mandar todo a
    /// `preMountStalled` dejaría este caso verde.
    @Test func reversePreMountExitReason_whenThePhaseCeilingFires_neverBlamesTheAccount() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        // Las 72 h de espera fueron de red; el 403 aparece justo en la pasada que cruza el plazo.
        fake.verifyProbes = [.blocked(.accountUnavailable)]
        let clock = MutableClock(fixedNow.addingTimeInterval(259_200))
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify")

        await makeRunner(context, fake, now: { clock.value }).resume()

        let j = try journal(context)
        #expect(j.readPhase().phase == .done, "a las 72 h de fase parada sale, con la causa que sea")
        #expect(j.reverseAbortReasonRaw == "preMountStalled",
                "y lo que terminó la vuelta fue la espera, no un 403 de cero segundos")
        #expect(j.reverseAbortReasonRaw != "preMountRefused",
                "ese copy acusa a la cuenta y da el correo de soporte a quien llevaba tres días sin red")
    }


    // MARK: - El reloj de «CUALQUIER motivo definitivo»
    // (ticket `alternating-definitive-causes-never-reach-the-short-ceiling`)

    /// **EL caso del ticket.** Una cuenta suspendida (403 del push) y un store que falla a ratos (el `fetch` del
    /// outbox lanza) se turnan en el DRENAJE, que desde `verify-reads-a-failed-local-fetch-as-an-empty-outbox` tiene
    /// los dos motivos. Con el reloj por causa, cada cambio reiniciaba el corto y la salida se iba a las 72 h. La
    /// cadencia es la real: la pantalla de Almacenamiento re-kickea cada 30 s, así que el motivo cambia en CADA
    /// observación y el reloj de causa no pasa nunca de cero.
    ///
    /// Se clava con sus dos vecinos —899 s holdea, 900 s sale— porque es un plazo y un `>=` cambiado por `>` no se
    /// ve de otra forma. Y el motivo es el genérico: ninguno de los dos llegó solo a los 900 s.
    @Test func reversePreMountDefinitiveClock_alternatingCauses_leaveAtTheShortCeiling() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        let offsets = Array(stride(from: 0.0, through: 870, by: 30)) + [899, 900]
        fake.reverseDrainOutcomes = offsets.indices.map {
            // Empieza por el fallo local para que la pasada que cruza el plazo traiga el 403: es la que tentaría a
            // journalear «tu cuenta en la nube no lo permitió» por un plazo que solo fue suyo a medias.
            $0.isMultiple(of: 2) ? .blocked(.localFailure) : .blocked(.accountUnavailable)
        }
        #expect(fake.reverseDrainOutcomes.last == .blocked(.accountUnavailable), "control del guion")
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseDrainAll, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "drain")

        for offset in offsets.dropLast() {
            clock.value = fixedNow.addingTimeInterval(offset)
            await makeRunner(context, fake, now: { clock.value }).resume()
            let j = try journal(context)
            #expect(j.readPhase().phase == .reverseDrainAll, "en \(offset)s todavía no son 900 s")
            #expect(j.reversePreMountCauseAt == clock.value,
                    "en \(offset)s: el reloj de CAUSA se reinicia en cada observación — por sí solo no vencería nunca")
        }
        #expect(fake.reverseDrainCallCount == offsets.count - 1, "una observación por pasada, alternando")
        #expect(fake.count(.reverseRollback) == 0)

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .done, "a los 15 min bajo motivos definitivos sale, no a las 72 h")
        #expect(j.reverseAbortReasonRaw == "preMountStalled",
                "con motivos mezclados ningún texto específico es verdad entero: «no llegó a completarse»")
        #expect(j.reverseAbortReasonRaw != "preMountRefused",
                "aunque la pasada que cruzó el plazo trajera el 403")
        #expect(fake.count(.reverseRollback) == 1, "el abort best-effort, una vez")
    }

    /// **La otra mitad del ticket: el reloj nuevo no reintroduce lo que el de causa cerró.** Diez minutos de 403,
    /// tres horas sin cobertura y, al volver el wifi, un `fetch` local que falla (y luego el 403 otra vez). El reloj
    /// de lo definitivo SUMA los diez minutos del 403 a lo que venga después —los dos eran esperas que esperar no
    /// arregla— pero NO las tres horas de red: la red no trae motivo y lo pausa. Así que quedan cinco minutos, no cero
    /// ni tres horas.
    ///
    /// Los dos mutantes que este caso mata: uno que no pausara (las tres horas contarían y saldría al volver el
    /// wifi, en la misma pasada del fallo) y uno que reiniciara con la red o con el cambio de causa (a 600 + 300
    /// seguiría esperando).
    @Test func reversePreMountDefinitiveClock_networkHoursBetweenTwoCauses_areNotCharged() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        // 403 · 403 · red · (tres horas) · fallo local · 403 · 403. Las dos últimas son 403 a propósito: la pasada
        // que cruza el plazo trae el motivo cuyo texto acusa a la cuenta, y el copy tiene que seguir siendo el
        // genérico porque el 403 no llegó solo a los 900 s. Con un fallo local al final esa aserción no podría fallar
        // (su texto ya es el genérico).
        fake.verifyProbes = [.blocked(.accountUnavailable), .blocked(.accountUnavailable), .networkTimeout,
                             .blocked(.localFailure), .blocked(.accountUnavailable)]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify")

        await makeRunner(context, fake, now: { clock.value }).resume()          // t=0    abre el 403
        clock.value = fixedNow.addingTimeInterval(570)
        await makeRunner(context, fake, now: { clock.value }).resume()          // t=570  sigue el 403
        clock.value = fixedNow.addingTimeInterval(600)
        await makeRunner(context, fake, now: { clock.value }).resume()          // t=600  se cae la red: pausa
        let paused = try journal(context)
        #expect(paused.reversePreMountDefinitiveAt == nil, "la red cierra el tramo")
        #expect(paused.reversePreMountDefinitiveAccruedSeconds == 600, "con los diez minutos del 403 dentro")

        let back = fixedNow.addingTimeInterval(600 + 10_800)                    // tres horas después, vuelve el wifi
        clock.value = back
        await makeRunner(context, fake, now: { clock.value }).resume()
        let first = try journal(context)
        #expect(first.readPhase().phase == .reverseVerify,
                "el primer fallo local tras tres horas de red no sale: las horas de red no se le cobran")
        #expect(first.reversePreMountCauseAccruedSeconds == 0, "y para su reloj de causa es la primera vez")

        clock.value = back.addingTimeInterval(299)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .reverseVerify, "600 + 299: todavía no")

        clock.value = back.addingTimeInterval(300)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .done, "600 del 403 + 299 del fallo local + 1 del 403 = 900 bajo motivos definitivos")
        #expect(j.reverseAbortReasonRaw == "preMountStalled",
                "el 403 de esta pasada lleva 1 s en su reloj de causa: no se ganó «tu cuenta en la nube no lo permitió»")
    }

    /// **Decisión, no accidente: un hueco SIN observaciones entre dos motivos definitivos distintos cuenta.** Un 403,
    /// la app cerrada veinte minutos (nadie observa nada: el tramo sigue abierto) y, al volver, un fallo local. El
    /// reloj de lo definitivo lleva 1 200 s y la vuelta sale en esa pasada, con el copy genérico. Es la regla que el
    /// reloj por causa ya aplicaba a un solo motivo —un 403, veinte minutos cerrada y otro 403 salen igual—, ahora
    /// entre motivos: lo último que se vio antes del hueco y lo primero que se ve después son esperas que esperar no
    /// arregla. Lo que NO cuenta es un hueco en el que se observó red (`networkHoursBetweenTwoCauses_areNotCharged`).
    /// Lo sacaron dos lentes de la review del 2026-09-23; queda fijado para que cambiarlo sea deliberado.
    @Test func reversePreMountDefinitiveClock_anUnobservedGapBetweenTwoCauses_counts() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.blocked(.accountUnavailable), .blocked(.localFailure)]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify")

        await makeRunner(context, fake, now: { clock.value }).resume()          // t=0: 403, y la app se cierra
        #expect(try journal(context).readPhase().phase == .reverseVerify)

        clock.value = fixedNow.addingTimeInterval(1_200)                        // t=20 min: vuelve, fallo local
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .done, "veinte minutos entre dos motivos definitivos, sin nada observado en medio")
        #expect(j.reverseAbortReasonRaw == "preMountStalled", "ninguno de los dos llegó solo al plazo")
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

    // MARK: - Los desenlaces del MERKLE en la vuelta
    // (ticket `reverse-verify-network-bucket-hides-a-definitive-server-no`)

    /// **Los dos motivos que el Merkle estrenó el 2026-09-22 eligen el techo CORTO.** Antes de ese día llegaban
    /// aquí como `.networkTimeout` —`SyncMerkle` aplanaba su fetch y el mapping los leía como red— y la vuelta los
    /// esperaba **72 h** en silencio: un `fetch` de SwiftData que lanza y un veredicto que este build no sabe leer
    /// no mejoran por esperar tres días.
    ///
    /// El caso mide el TECHO y no solo el motivo journaleado, que es lo que lo hace discriminante: a los 900 s ya
    /// tiene que haber salido. Si solo mirase `reverseAbortReasonRaw`, un mutante que les devolviera el presupuesto
    /// largo dejaría verde la mitad que importa —`localFailure` sale con `preMountStalled`, el mismo motivo que la
    /// red—, y eso es exactamente el bug del ticket.
    @Test func reverseVerify_merkleBlockers_useTheShortBudget() async throws {
        let cases: [(ReversePreMountBlocker, String)] = [
            (.localFailure, "preMountStalled"),
            (.unknownVerdict, "preMountStalled"),
        ]
        for (blocker, expectedReason) in cases {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.verifyProbes = [.blocked(blocker)]
            let clock = MutableClock(fixedNow)
            try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done",
                            reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify")

            // La primera observación sella el reloj de ESTE motivo; la segunda, 900 s después, lo agota.
            await makeRunner(context, fake, now: { clock.value }).resume()
            clock.value = fixedNow.addingTimeInterval(900)
            await makeRunner(context, fake, now: { clock.value }).resume()

            let j = try journal(context)
            #expect(j.readPhase().phase == .done, "\(blocker): a los 900 s sale, no espera las 72 h de la red")
            #expect(j.reverseAbortReasonRaw == expectedReason, "\(blocker)")
            #expect(j.reverseAbortReasonRaw != "preMountRefused",
                    "\(blocker): ese copy acusa a la cuenta en la nube y manda a soporte, y aquí no habló el servidor")
            #expect(j.readPendingEffects().isEmpty, "\(blocker): ningún efecto journaleado")
            #expect(fake.count(.reverseRollback) == 1, "\(blocker): el abort se intenta una vez, best-effort")
            #expect(j.verifyNetworkRetries == 0, "\(blocker): el presupuesto de RED no se toca")

            // El control en la dirección contraria, con el MISMO seed y el mismo reloj: la red pura sigue con el
            // presupuesto largo. Es lo que impide «arreglar» el ticket mandando todo al techo corto, y va aquí
            // dentro y no en un caso propio porque `reversePreMountCeiling_networkAndExpiredSession_useTheLongBudget`
            // ya recorre esa fila entera —duplicarla no añadía ni un mutante—.
            let dirRed = freshDir(); defer { cleanup(dirRed) }
            let contextRed = try makeContext(dirRed)
            let fakeRed = FakeExecutor()
            fakeRed.verifyProbes = [.networkTimeout]
            try seedJournal(contextRed, phase: .reverseVerify, reverseOriginRaw: "done",
                            reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify")
            await makeRunner(contextRed, fakeRed, now: { clock.value }).resume()   // clock = fixedNow + 900
            #expect(try journal(contextRed).readPhase().phase == .reverseVerify,
                    "\(blocker): a los 900 s la red PURA sigue esperando — el techo corto no es de todos")
        }
    }

    /// **La IDA no cambia, y eso es una decisión del Paso 0.** `verify()` lo comparten las dos direcciones, así que
    /// los tres desenlaces que el Merkle empezó a tipar llegan también a `driveVerify` — donde ya caían cuando
    /// venían aplanados en `.networkTimeout`. Los tres siguen gastando el presupuesto de RED de la ida y degradando
    /// al tope, exactamente como antes.
    ///
    /// Cada desenlace se mide DOS veces —con el presupuesto a cero y con el presupuesto agotado— porque una sola
    /// mitad no discrimina: con el contador a cero un mutante que le diera rama propia solo movería un número, y
    /// con el tope puesto el contador ya no sube (la transición degrada sin escribirlo). Juntas fijan las dos
    /// mitades del trato de la ida: gasta, y al tope revierte.
    @Test func forwardVerify_typedMerkleOutcomes_stillSpendTheNetworkBudget() async throws {
        let probes: [(VerifyProbe, String)] = [
            (.sessionExpired, "401 del Merkle"),
            (.blocked(.accountUnavailable), "403 del Merkle"),
            (.blocked(.localFailure), "fetch local que lanzó"),
            (.blocked(.unknownVerdict), "veredicto desconocido"),
        ]
        for (probe, label) in probes {
            // (a) Con presupuesto: gasta uno y se queda reintentando en `verifying`.
            let dirA = freshDir(); defer { cleanup(dirA) }
            let contextA = try makeContext(dirA)
            let fakeA = FakeExecutor()
            fakeA.verifyProbes = [probe]
            try seedJournal(contextA, phase: .verifying, networkRetries: 0)

            let rA = runner(contextA, fakeA)
            await rA.resume()

            let jA = try journal(contextA)
            #expect(jA.verifyNetworkRetries == 1, "\(label): en la IDA gasta red, como antes del ticket")
            #expect(jA.readPhase().phase == .verifying, "\(label): y reintenta, no corta")
            #expect(rA.lastReverseSessionExpiry == nil, "\(label): no anota nada de la vuelta")

            // (b) Con el presupuesto AGOTADO: degrada a `failedRollback` con su rollback pendiente, que es lo que
            // separa el trato de la ida del de la vuelta —allí ninguno de los cuatro degrada—.
            let dirB = freshDir(); defer { cleanup(dirB) }
            let contextB = try makeContext(dirB)
            let fakeB = FakeExecutor()
            fakeB.verifyProbes = [probe]
            let spent = MigrationPolicy.default.maxNetworkRetries
            try seedJournal(contextB, phase: .verifying, networkRetries: spent)

            await runner(contextB, fakeB).resume()

            #expect(try journal(contextB).readPhase().phase == .failedRollback,
                    "\(label): al tope degrada, como antes del ticket")
            #expect(fakeB.count(.rollback) == 1,
                    "\(label): y con su rollback, que es lo que la vuelta NO hace con estos cuatro")
            // El contador NO se comprueba aquí: el `.rollback` de la degradación reinicia el journal, así que
            // leerlo después mide el reset y no el trato de la red. Esa mitad la mide el bloque (a).
        }
    }

    /// **Dónde es alcanzable el aviso del toque, MEDIDO el 2026-09-21** (ticket
    /// `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`). `CloudMigrationController.startReverse`
    /// hace exactamente este par de `submit`, y el aviso que lleva detrás solo vale si el par puede producir una
    /// salida. Se midió porque la respuesta no es obvia en ninguna de las dos direcciones:
    ///
    /// - **Desde una fase ESTABLE, que es el camino del toque, NO puede.** El cruce
    ///   `reverseConfirm(origin) → reverseClaimLeader` limpia el reloj y la fase sellados, así que la primera
    ///   observación del intento nuevo da `stalled = 0` y holdea aunque el journal trajera un sello de días atrás.
    ///   Esa limpieza es del ticket padre y este caso la fija desde fuera: quitarla haría salir la vuelta nueva **en
    ///   el acto**, con techo instantáneo, y aquí se vería.
    /// - **Con el journal YA en una fase previa al montaje y el techo vencido, SÍ puede**, y por eso el aviso de
    ///   `startReverse` no es un camino muerto: `submit` llama a `drive()` aunque el `handle` del evento sea
    ///   inválido en esa fase, así que el toque conduce la fase que había. Es el desincronizado —la pantalla pinta
    ///   la tarjeta con el journal aún en pre-montaje—, y es justo el caso que el ticket describe: la barra
    ///   desaparece y la pantalla cambia sin decir por qué.
    @Test func startReversePair_exitsTheCeilingOnlyWhenTheJournalWasAlreadyInTheStage() async throws {
        // A · el camino del toque, desde una fase estable: el cruce limpia el reloj ⇒ holdea, no sale.
        let dirA = freshDir(); defer { cleanup(dirA) }
        let ctxA = try makeContext(dirA)
        let fakeA = FakeExecutor()
        fakeA.reverseClaimOutcomes = [.transient]
        let clockA = MutableClock(fixedNow.addingTimeInterval(259_200))
        try seedJournal(ctxA, phase: .done, reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "claim")

        let rA = makeRunner(ctxA, fakeA, now: { clockA.value })
        await rA.submit(.reverseActivated)
        await rA.submit(.reverseConfirmed)

        #expect(try journal(ctxA).readPhase().phase == .reverseClaimLeader,
                "la vuelta nueva empieza y espera: un sello viejo no la puede echar en el acto")
        #expect(rA.lastReversePreMountExit == nil, "sin salida no hay nada que anunciar")

        // B · el desincronizado: el journal ya estaba en la etapa y el techo vencido ⇒ el toque la saca, y lo dice.
        let dirB = freshDir(); defer { cleanup(dirB) }
        let ctxB = try makeContext(dirB)
        let fakeB = FakeExecutor()
        fakeB.reverseClaimOutcomes = [.transient]
        let clockB = MutableClock(fixedNow.addingTimeInterval(259_200))
        try seedJournal(ctxB, phase: .reverseClaimLeader, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "claim")

        let rB = makeRunner(ctxB, fakeB, now: { clockB.value })
        await rB.submit(.reverseActivated)
        await rB.submit(.reverseConfirmed)

        #expect(try journal(ctxB).readPhase().phase == .done, "sale a su origen")
        #expect(rB.lastReversePreMountExit == ReversePreMountExit(sequence: 1, reason: .preMountStalled),
                "y deja el testigo que el aviso de `startReverse` compara")
    }

    // MARK: - §12c · La red pura del verify, dentro del techo
    // (ticket `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`, decisión de Jürgen)

    /// El gemelo del caso del 403, para la RED. **Reescrito tras la review, que cazó que tres de sus cuatro
    /// aserciones no podían fallar** — dos lentes por separado, y con el mismo análisis.
    ///
    /// La primera versión sembraba el presupuesto de red **agotado** creyendo que así el mutante caía por tres
    /// sitios. Medido, hacía lo contrario: con el tope ya alcanzado, el código viejo iba a `reverseFailedRollback`,
    /// que **no incrementa** el contador (`if next == .reverseVerify`) ni escribe `reverseAbortReasonRaw`, y el
    /// `.reverseRollback` que dejaba pendiente lo consumía el drenaje porque el fake no lanza. O sea: sembrar en el
    /// tope es justo lo que volvía inocuas las aserciones. Es la familia de «el número sustituto lo cumple otra cosa».
    ///
    /// Ahora siembra **0**, que es donde el trato viejo y el nuevo difieren en TODO: el viejo gastaría un reintento
    /// y seguiría en `reverseVerify` sin sellar reloj; el nuevo no gasta nada y **sella**. Y añade la aserción que
    /// mata el mutante PARCIAL que las otras cuatro dejaban vivo —revertir solo este `case` y dejar el `.invalid` en
    /// la máquina—: ahí `handle` hace breadcrumb y no-op, no hay observación, no hay sello, y el journal queda igual
    /// que en el camino bueno salvo por esto. Sin el reloj sellado, esa mutación reabre el limbo del ticket padre.
    ///
    /// `verifyCallCount == 1` cierra el otro mutante que sobrevivía a todo lo demás: `return true` en vez de
    /// `return false`. No cuelga —`drive()` tiene tope de iteraciones— y deja el journal donde los tests lo esperan,
    /// así que solo lo caza contar las llamadas.
    @Test func reverse_verifyNetworkTimeout_spendsNoNetworkRetry_sealsTheClock_andNeverDegrades() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.networkTimeout]
        try seedJournal(context, phase: .reverseVerify, networkRetries: 0, reverseOriginRaw: "done")

        await runner(context, fake).resume()

        let j = try journal(context)
        #expect(j.verifyNetworkRetries == 0,
                "la red de la VUELTA ya no gasta presupuesto: el trato viejo habría dejado 1")
        #expect(j.readPhase().phase == .reverseVerify, "no degrada: espera a su propio techo")
        #expect(j.reversePreMountProgressAt != nil,
                "y SÍ pasó por el techo: sin sello, revertir solo el runner reabriría el limbo sin que nada lo cazara")
        #expect(j.reversePreMountPhaseRaw == "verify", "sellado en SU fase, que es con la que se compara el reloj")
        #expect(!j.readPendingEffects().contains(.reverseRollback),
                "sin abort pendiente, que sin red lanzaría en cada resume")
        #expect(fake.verifyCallCount == 1, "corta retomable: un resume = UN sondeo, sin tight-loop de red")
    }

    /// **La IDA no cambia**, y esta es la mitad del criterio que el ticket pide fijar: `verify()` lo comparten las
    /// dos direcciones, así que sacar la red del verify de la VUELTA podría llevarse por delante el de la ida sin
    /// que nadie lo notara. En `verifying` sigue gastando reintento bajo el tope y degradando al llegar, exactamente
    /// como antes de este ticket. Su residual sigue siendo `forward-verify-reads-an-expired-session-as-network`.
    @Test func forwardVerify_networkTimeout_stillSpendsTheBudget_andDegradesAtTheCap() async throws {
        let cap = MigrationPolicy.default.maxNetworkRetries

        let underDir = freshDir(); defer { cleanup(underDir) }
        let underContext = try makeContext(underDir)
        let underFake = FakeExecutor()
        underFake.verifyProbes = [.networkTimeout]
        try seedJournal(underContext, phase: .verifying, networkRetries: 0)
        await runner(underContext, underFake).resume()
        let under = try journal(underContext)
        #expect(under.verifyNetworkRetries == 1, "la ida sigue gastando presupuesto de red")
        #expect(under.readPhase().phase == .verifying, "y sigue reintentando bajo el tope")

        let capDir = freshDir(); defer { cleanup(capDir) }
        let capContext = try makeContext(capDir)
        let capFake = FakeExecutor()
        capFake.verifyProbes = [.networkTimeout]
        try seedJournal(capContext, phase: .verifying, networkRetries: cap)
        await runner(capContext, capFake).resume()
        #expect(try journal(capContext).readPhase().phase == .failedRollback,
                "y al tope sigue degradando: la ida revierte, que es su trato de siempre")
        #expect(capFake.count(.rollback) == 1)
    }

    // MARK: - §12d · La salida del techo AVISA en el momento
    // (mismo ticket: hasta hoy la barra desaparecía y la pantalla cambiaba sin decir por qué)

    /// El testigo en memoria que deja al controller saber que la salida es de AHORA. Sin `sequence`, la alerta
    /// saldría también por la nota journaleada de un intento de hace días — que es justo el bug que el ticket
    /// hermano cerró para el claim y que el techo reintrodujo.
    ///
    /// Barre las CUATRO fases con su motivo, y comprueba que cada salida nueva es distinta de la anterior aunque el
    /// motivo se repita: un testigo que solo llevara el motivo no distinguiría dos salidas iguales seguidas.
    @Test func reversePreMountExit_isRecordedWithARisingSequence_perExit() async throws {
        let cases: [(Phase, String, (FakeExecutor) -> Void, ReverseAbortReason)] = [
            (.reverseClaimLeader, "claim/red", { $0.reverseClaimOutcomes = [.transient] }, .preMountStalled),
            (.reverseDrainAll, "drain/403",
             { $0.reverseDrainOutcomes = [.blocked(.accountUnavailable)] }, .preMountRefused),
            (.reverseVerify, "verify/red", { $0.verifyProbes = [.networkTimeout] }, .preMountStalled),
            (.reverseFreezeBackend, "freeze/otherLeader",
             { $0.freezeBackendOutcomes = [.blocked(.otherLeader)] }, .preMountOtherDevice),
        ]
        for (phase, label, arrange, expected) in cases {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            arrange(fake)
            let clock = MutableClock(fixedNow)
            try seedJournal(context, phase: phase, reverseOriginRaw: "done",
                            reversePreMountProgressAt: fixedNow,
                            reversePreMountPhaseRaw: ReversePreMountPhase(phase: phase)?.rawValue)

            let r = makeRunner(context, fake, now: { clock.value })
            #expect(r.lastReversePreMountExit == nil, "\(label): un runner recién creado no ha visto ninguna salida")
            // Cada caso se lleva a la salida por SU propio techo, y por eso los relojes son distintos: los dos con
            // motivo salen a los 900 s de su causa —la primera pasada la sella—, y los dos de red a las 72 h de
            // fase parada. Llevarlos a todos a las 72 h, como hacía este caso hasta el ticket
            // `…charges-a-stall-to-whoever-stops-it-last`, hacía que los dos con motivo salieran por el techo de
            // FASE y journalearan `preMountStalled`: el propio test habría afirmado que la nota no es la del
            // blocker.
            if expected == .preMountStalled {
                clock.value = fixedNow.addingTimeInterval(259_200)
                await r.resume()
            } else {
                await r.resume()
                clock.value = fixedNow.addingTimeInterval(900)
                await r.resume()
            }
            #expect(r.lastReversePreMountExit == ReversePreMountExit(sequence: 1, reason: expected), "\(label)")
            #expect(try journal(context).reverseAbortReasonRaw == expected.rawValue,
                    "\(label): el testigo y la nota journaleada dicen lo MISMO")
        }
    }

    /// Dos salidas seguidas con el mismo motivo son DISTINTAS: es lo único que deja al controller avisar la segunda
    /// vez sin repetir la primera. Con un testigo que solo llevara el motivo, este caso pasaría en verde con la
    /// alerta muda.
    @Test func reversePreMountExit_twoExitsWithTheSameReason_areNotEqual() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.reverseClaimOutcomes = [.transient]
        let clock = MutableClock(fixedNow.addingTimeInterval(259_200))
        let r = makeRunner(context, fake, now: { clock.value })

        try seedJournal(context, phase: .reverseClaimLeader, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "claim")
        await r.resume()
        #expect(r.lastReversePreMountExit == ReversePreMountExit(sequence: 1, reason: .preMountStalled))

        // Segunda vuelta: el journal se repone a la misma fase parada, como si la persona lo hubiera intentado otra
        // vez y el techo hubiera vuelto a vencer. Mismo motivo, mismo runner.
        let st = try journal(context)
        st.setPhase(.reverseClaimLeader)
        st.reverseOriginRaw = "done"
        st.reversePreMountProgressAt = fixedNow
        st.reversePreMountPhaseRaw = "claim"
        st.reverseAbortReasonRaw = nil
        try context.save()

        await r.resume()
        #expect(r.lastReversePreMountExit == ReversePreMountExit(sequence: 2, reason: .preMountStalled))
        #expect(ReversePreMountExit(sequence: 1, reason: .preMountStalled)
                != ReversePreMountExit(sequence: 2, reason: .preMountStalled))
    }

    /// «Cancelar y seguir en la nube» TAMBIÉN deja testigo —es una salida de la etapa como cualquier otra— pero con
    /// `cancelled`, que es el motivo que `ReverseUploadWaitingCopyLogic.abortNote` filtra. El runner no decide el
    /// copy: registra el hecho, y quién lo enseña lo decide un solo sitio.
    @Test func reversePreMountExit_cancelling_recordsTheReasonThatIsNeverAnnounced() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .reverseDrainAll, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "drain")

        let r = runner(context, fake)
        await r.cancelReverse()

        #expect(r.lastReversePreMountExit == ReversePreMountExit(sequence: 1, reason: .cancelled))
        #expect(ReverseUploadWaitingCopyLogic.abortNote(.cancelled) == nil,
                "y ese motivo no se anuncia: lo decidió la persona")
    }

    /// Una pasada que NO sale de la etapa no deja testigo. Sin esto, la alerta saldría en cada re-kick de 30 s
    /// mientras la vuelta sigue esperando, que es lo contrario de lo que el techo existe para hacer.
    @Test func reversePreMountExit_holdingUnderBudget_recordsNothing() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.networkTimeout]
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "verify")

        let r = makeRunner(context, fake, now: { self.fixedNow.addingTimeInterval(900) })
        await r.resume()
        await r.resume()

        #expect(try journal(context).readPhase().phase == .reverseVerify, "sigue esperando: 900 s < el techo largo")
        #expect(r.lastReversePreMountExit == nil, "y sin salida no hay nada que anunciar")
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
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .reverseFreezeBackend, reverseOriginRaw: "notStarted",
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "freeze")

        // La primera observación sella el reloj de ese motivo (ticket `…charges-a-stall-to-whoever-stops-it-last`);
        // la segunda, 900 s después, agota su techo y es la que sale.
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(fake.attempts(.reverseRollback) == 0, "la que holdea no des-reserva nada")
        clock.value = fixedNow.addingTimeInterval(900)
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
        // Un intento anterior dejó su reloj parado en `drain`, hace once días, y con un 403 casi agotado.
        try seedJournal(context, phase: .done,
                        reversePreMountProgressAt: fixedNow, reversePreMountPhaseRaw: "drain",
                        reversePreMountCauseRaw: "accountUnavailable", reversePreMountCauseAt: fixedNow,
                        reversePreMountCauseAccruedSeconds: 880)

        let r = makeRunner(context, fake, now: { clock.value })
        await r.submit(.reverseActivated)
        await r.submit(.reverseConfirmed)

        let j = try journal(context)
        #expect(j.readPhase().phase == .reverseDrainAll, "la vuelta nueva llega al drenaje y se para ahí")
        #expect(j.reversePreMountProgressAt == clock.value, "con el reloj sellado AHORA, no hace once días")
        #expect(j.reversePreMountPhaseRaw == "drain")
        // Y el reloj por CAUSA igual: los 880 s del 403 del intento anterior no se le cobran a éste, o la vuelta
        // nueva saldría a los 20 s de empezar (ticket `…charges-a-stall-to-whoever-stops-it-last`).
        #expect(j.reversePreMountCauseRaw == nil,
                "el 403 del intento viejo no sobrevive, y esta pasada se paró por red, que no trae motivo")
        #expect(j.reversePreMountCauseAccruedSeconds == nil,
                "sin los 880 s heredados: con ellos, la vuelta nueva saldría a los 20 s de empezar")
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
        // Lo MISMO con el reloj por causa: la primera visita al drenaje selló `accountUnavailable`, y esa cuenta
        // no viaja con la segunda visita (ticket `…charges-a-stall-to-whoever-stops-it-last`).
        #expect(j.reversePreMountCauseRaw == nil,
                "el 403 de la PRIMERA visita al drenaje no viaja con la segunda: ahí se paró por red, sin motivo")
        #expect(j.reversePreMountCauseAccruedSeconds == nil,
                "y sin nada acumulado heredado — con los 890 s de la primera, esta salía en su primera observación")
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


    // MARK: - §14 · Techo y salida de `uploadingSnapshot` (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`)
    //
    // Hasta este ticket la subida del snapshot de la ida cortaba sin evento ante cualquier fallo, y la barra se quedaba
    // en «Activando la nube…» 55 % para siempre. Cada caso de abajo mide que la FASE CAMBIA —o que no cambia cuando no
    // debe—, que es el criterio del ticket: un reloj que se sella bien y una fase que no sale no arreglan nada.

    /// **EL caso del ticket, por su causa vieja: la red.** Un push que devuelve `.transient` sin fin. A las 72 h sin
    /// confirmar una página la fase sale a `failedRollback`, clavado con sus dos vecinos, y con el motivo del techo LARGO.
    @Test func snapshotCeiling_persistentNetworkFailure_leavesAt72hWithoutProgress() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.transient]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .uploadingSnapshot)

        await makeRunner(context, fake, now: { clock.value }).resume()        // sella
        var j = try journal(context)
        #expect(j.readPhase().phase == .uploadingSnapshot)
        #expect(j.snapshotStallProgressAt == fixedNow, "la primera observación sella el reloj de avance")
        #expect(j.snapshotStallCauseRaw == nil, "la red no trae motivo: no hay reloj de causa")

        clock.value = fixedNow.addingTimeInterval(259_199)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .uploadingSnapshot, "a 259 199 s todavía no")

        clock.value = fixedNow.addingTimeInterval(259_200)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "a las 72 h sin avanzar, la subida se rinde")
        #expect(j.snapshotExitReasonRaw == "stalled")
        #expect(fake.count(.rollback) == 1)
        #expect(j.snapshotStallProgressAt == nil, "el reloj se va con la fase")
    }

    /// **La causa nueva del 2026-09-22: el `fetch` local que lanza siempre.** Llega como `.blocked(.localFailure)` y
    /// sale a los 900 s ACUMULADOS de ese motivo, clavado con sus dos vecinos, con su propio motivo.
    @Test func snapshotCeiling_persistentLocalFailure_leavesAt900SecondsOfItsOwn() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.blocked(.localFailure)]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .uploadingSnapshot)

        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).snapshotStallCauseRaw == "localFailure")
        clock.value = fixedNow.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .uploadingSnapshot, "a 899 s todavía no")

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "a 900 s de ese mismo motivo, sale")
        #expect(j.snapshotExitReasonRaw == "localFailure")
        #expect(fake.count(.rollback) == 1)
    }

    /// Los otros dos motivos definitivos salen igual y con su nombre: el texto de la tarjeta depende de esto.
    @Test func snapshotCeiling_sessionExpiredAndAccountUnavailable_leaveWithTheirOwnReason() async throws {
        for (blocker, raw) in [(SnapshotStallBlocker.sessionExpired, "sessionExpired"),
                               (.accountUnavailable, "accountUnavailable")] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.uploadOutcomes = [.blocked(blocker)]
            let clock = MutableClock(fixedNow)
            try seedJournal(context, phase: .uploadingSnapshot)

            await makeRunner(context, fake, now: { clock.value }).resume()
            clock.value = fixedNow.addingTimeInterval(900)
            await makeRunner(context, fake, now: { clock.value }).resume()
            let j = try journal(context)
            #expect(j.readPhase().phase == .failedRollback, "\(blocker)")
            #expect(j.snapshotExitReasonRaw == raw)
        }
    }

    /// **Una página confirmada reinicia LOS relojes.** Sin esto, un corpus grande que sube despacio agotaría el
    /// techo mientras avanza. El guion: 71 h 58 min sin avanzar y 800 s de fallo local acumulados; en la pasada, una
    /// página sube y la siguiente choca con el mismo fallo. La fase no sale, y los relojes empiezan AHORA — también el
    /// de lo definitivo, que es el que decide los 15 min (ticket
    /// `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`).
    @Test func snapshotCeiling_aConfirmedPageRestartsBothClocks() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.pageConfirmed(cursor: "c9"), .blocked(.localFailure)]
        let now = fixedNow.addingTimeInterval(259_080)
        let clock = MutableClock(now)
        try seedJournal(context, phase: .uploadingSnapshot,
                        snapshotStallProgressAt: fixedNow, snapshotStallCauseRaw: "localFailure",
                        snapshotStallCauseAt: fixedNow.addingTimeInterval(258_280), snapshotStallCauseAccruedSeconds: 0,
                        snapshotStallDefinitiveAt: fixedNow.addingTimeInterval(258_280),
                        snapshotStallDefinitiveAccruedSeconds: 0)

        await makeRunner(context, fake, now: { clock.value }).resume()
        var j = try journal(context)
        #expect(j.readPhase().phase == .uploadingSnapshot, "subió una página: la subida está viva")
        #expect(j.snapshotCursorJSON == "c9")
        #expect(j.snapshotStallProgressAt == now, "el reloj de avance empieza en la página confirmada")
        #expect(j.snapshotStallCauseAt == now, "y el de causa empieza de cero en el fallo de después")
        #expect(j.snapshotStallCauseAccruedSeconds == 0)
        #expect(j.snapshotStallDefinitiveAt == now, "y el de lo definitivo, igual")
        #expect(j.snapshotStallDefinitiveAccruedSeconds == 0)

        // Y de verdad empieza de cero: a 899 s del fallo nuevo sigue esperando.
        clock.value = now.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .uploadingSnapshot)
    }

    /// **El reloj de avance cuenta desde la PÁGINA confirmada, no desde la siguiente vez que se mira.** La página sube
    /// a t0 y el intento siguiente de la misma pasada falla dos minutos después: esos dos minutos ya son parada. Sin el
    /// sello de la página, la limpieza de delante deja el reloj a `nil` y la observación lo sellaría a t0+120 — el techo
    /// se aplazaría todo lo que tarde el siguiente vistazo (un cierre de la app entre medias, por ejemplo). Lo cazó el
    /// mutante M1, que sobrevivía a toda la suite.
    @Test func snapshotCeiling_theProgressClockStartsAtTheConfirmedPage() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.pageConfirmed(cursor: "c1"), .transient]
        let clock = MutableClock(fixedNow)
        fake.onUploadSnapshot = { index in if index == 1 { clock.value = self.fixedNow.addingTimeInterval(120) } }
        try seedJournal(context, phase: .uploadingSnapshot)

        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .uploadingSnapshot)
        #expect(fake.uploadCursorsSeen == [nil, "c1"], "control del escenario: la página subió y se volvió a intentar")
        #expect(j.snapshotStallProgressAt == fixedNow, "el reloj arranca en la página, no dos minutos después")
    }

    /// **Un fallo local aislado tras horas sin red NO se cobra las horas** (la lección de #210). Tres horas sin avanzar
    /// por red, y en la pasada un fallo local: holdea, y el reloj de causa se sella ahora.
    @Test func snapshotCeiling_anIsolatedLocalFailureAfterALongWait_retries() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.blocked(.localFailure)]
        let threeHours = fixedNow.addingTimeInterval(10_800)
        try seedJournal(context, phase: .uploadingSnapshot, snapshotStallProgressAt: fixedNow)

        await makeRunner(context, fake, now: { threeHours }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .uploadingSnapshot, "las tres horas eran de otra cosa y no se le cobran")
        #expect(j.snapshotExitReasonRaw == nil)
        #expect(j.snapshotStallProgressAt == fixedNow, "el reloj de avance sigue midiendo las tres horas")
        #expect(j.snapshotStallCauseAt == threeHours, "y el de causa empieza ahora, que es cuando apareció")
        // Y el de lo DEFINITIVO, que es el que hoy decide el techo corto, también: las tres horas de red no traían
        // motivo, así que no las acumuló (ticket `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`).
        #expect(j.snapshotStallDefinitiveAt == threeHours, "el reloj de lo definitivo también empieza AHORA")
        #expect(j.snapshotStallDefinitiveAccruedSeconds == 0, "sin nada cerrado que cobrarle")
    }

    /// **Una observación SIN motivo PAUSA el reloj de causa; no lo borra ni lo cuenta.** Con el re-kick de 30 s, una
    /// racha consecutiva no llegaría a 900 s con un timeout intercalado cada quince minutos. El guion: 403 a t0 y a
    /// 840 s · red a 850 s (cierra el tramo: 850 acumulados) · 403 a 1000 s (reanuda: 850, el hueco no cuenta) · 403 a
    /// 1050 s (900: sale). Con racha, a 1050 s llevaría 50; contando el hueco, habría salido a 1000 s.
    @Test func snapshotCeiling_anObservationWithoutACause_pausesInsteadOfResetting() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.blocked(.accountUnavailable), .blocked(.accountUnavailable), .transient,
                               .blocked(.accountUnavailable), .blocked(.accountUnavailable)]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .uploadingSnapshot)

        for offset in [0.0, 840, 850, 1000] {
            clock.value = fixedNow.addingTimeInterval(offset)
            await makeRunner(context, fake, now: { clock.value }).resume()
            #expect(try journal(context).readPhase().phase == .uploadingSnapshot, "a \(offset) s todavía no")
        }
        #expect(try journal(context).snapshotStallCauseAccruedSeconds == 850, "el hueco de la red no sumó")
        #expect(try journal(context).snapshotStallDefinitiveAccruedSeconds == 850,
                "tampoco en el reloj de lo definitivo, que es el que decide la salida")

        clock.value = fixedNow.addingTimeInterval(1050)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "900 s acumulados bajo el 403")
        #expect(j.snapshotExitReasonRaw == "accountUnavailable")
    }

    /// **Una causa DISTINTA empieza de cero en el reloj de CAUSA**: lo acumulado bajo un motivo no se le regala a otro.
    /// Desde `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` eso ya no decide CUÁNDO se
    /// sale —lo decide el reloj de lo definitivo, que suma los dos a propósito— sino QUÉ se le dice a la persona. Por eso
    /// el caso mide las dos cosas: 800 s de 409 y luego la sesión caducada salen a los 900 s de la SUMA, y con el
    /// motivo de los mezclados (`mixedCauses`), porque la sesión solo lleva 90 s en su reloj. Hasta ese ticket esperaba a 1 710 s y salía con
    /// «la sesión caducó».
    @Test func snapshotCeiling_aDifferentCause_startsItsOwnClock() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.blocked(.accountUnavailable), .blocked(.accountUnavailable),
                               .blocked(.sessionExpired), .blocked(.sessionExpired), .blocked(.sessionExpired)]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .uploadingSnapshot)

        for offset in [0.0, 800, 810, 899] {
            clock.value = fixedNow.addingTimeInterval(offset)
            await makeRunner(context, fake, now: { clock.value }).resume()
            #expect(try journal(context).readPhase().phase == .uploadingSnapshot, "a \(offset) s todavía no")
        }
        #expect(try journal(context).snapshotStallCauseAt == fixedNow.addingTimeInterval(810),
                "el reloj de CAUSA de la sesión empezó cuando apareció")
        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "900 s bajo motivos definitivos, aunque fueran dos")
        #expect(j.snapshotExitReasonRaw == "mixedCauses",
                "la sesión lleva 90 s en su reloj: no se ganó «la sesión caducó», ni el 409 «tu cuenta no lo permitió»")
    }

    /// **El motivo lo elige el techo que VENCIÓ.** A las 72 h sin avanzar, una pasada que trae un 403 recién visto sale
    /// con «dejó de avanzar»: decirle «tu cuenta no lo permitió» a quien llevaba tres días sin red sería falso.
    @Test func snapshotCeiling_theLongCeilingWithAFreshBlocker_leavesAsStalled() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.blocked(.accountUnavailable)]
        try seedJournal(context, phase: .uploadingSnapshot, snapshotStallProgressAt: fixedNow)

        await makeRunner(context, fake, now: { self.fixedNow.addingTimeInterval(259_200) }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.snapshotExitReasonRaw == "stalled", "el 403 tiene cero segundos: no fue él quien terminó esto")
    }

    // MARK: §14-bis · El reloj de «CUALQUIER motivo definitivo» de la subida
    // (ticket `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`)

    /// **EL caso del ticket.** Un store que falla a ratos al leer —`localFailure` salta ANTES del push— y una cuenta
    /// congelada —el 409 `yala_account_reverting` sale DEL push como `accountUnavailable`— se turnan pasada a pasada.
    /// Con el reloj por causa, cada cambio reiniciaba el corto y la salida se iba a las 72 h. La cadencia es la real: la
    /// pantalla de Almacenamiento re-kickea cada 30 s, así que el motivo cambia en CADA observación y el reloj de causa
    /// no pasa nunca de cero.
    ///
    /// Se clava con sus dos vecinos —899 s holdea, 900 s sale— porque es un plazo y un `>=` cambiado por `>` no se ve de
    /// otra forma. Y el motivo es `mixedCauses`: ninguno de los dos llegó solo a los 900 s, y `stalled` diría «lleva
    /// días» a los quince minutos (lo cazaron dos lentes de la review).
    @Test func snapshotDefinitiveClock_alternatingCauses_leaveAtTheShortCeiling() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        let offsets = Array(stride(from: 0.0, through: 870, by: 30)) + [899, 900]
        fake.uploadOutcomes = offsets.indices.map {
            // Empieza por el fallo local para que la pasada que cruza el plazo traiga el 409: es la que tentaría a
            // journalear «tu cuenta no lo permitió» por un plazo que solo fue suyo a medias.
            $0.isMultiple(of: 2) ? .blocked(.localFailure) : .blocked(.accountUnavailable)
        }
        #expect(fake.uploadOutcomes.last == .blocked(.accountUnavailable), "control del guion")
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .uploadingSnapshot)

        for offset in offsets.dropLast() {
            clock.value = fixedNow.addingTimeInterval(offset)
            await makeRunner(context, fake, now: { clock.value }).resume()
            let j = try journal(context)
            #expect(j.readPhase().phase == .uploadingSnapshot, "en \(offset)s todavía no son 900 s")
            #expect(j.snapshotStallCauseAt == clock.value,
                    "en \(offset)s: el reloj de CAUSA se reinicia en cada observación — por sí solo no vencería nunca")
        }
        #expect(fake.uploadCursorsSeen.count == offsets.count - 1, "una observación por pasada, alternando")
        #expect(fake.count(.rollback) == 0)

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "a los 15 min bajo motivos definitivos sale, no a las 72 h")
        #expect(j.snapshotExitReasonRaw == "mixedCauses",
                "con motivos mezclados ningún texto específico es verdad entero, aunque la pasada que cruzó el plazo trajera el 409; y `stalled` diría «días»")
        #expect(fake.count(.rollback) == 1)
    }

    /// **La otra mitad del ticket: el reloj nuevo no reintroduce lo que el de causa cerró.** Diez minutos de 409, tres
    /// horas sin cobertura y, al volver el wifi, un fallo local al leer (y luego el 409 otra vez). El reloj de lo
    /// definitivo SUMA los diez minutos del 409 a lo que venga después —los dos eran esperas que esperar no arregla—
    /// pero NO las tres horas de red: la red no trae motivo y lo pausa. Así que quedan cinco minutos, no cero ni tres
    /// horas.
    ///
    /// Los dos mutantes que este caso mata: uno que no pausara (las tres horas contarían y saldría al volver el wifi, en
    /// la misma pasada del fallo) y uno que reiniciara con la red o con el cambio de causa (a 600 + 300 seguiría
    /// esperando).
    @Test func snapshotDefinitiveClock_networkHoursBetweenTwoCauses_areNotCharged() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        // 409 · 409 · red · (tres horas) · fallo local · 409 · 409. Las dos últimas son 409 a propósito: la pasada que
        // cruza el plazo trae el motivo cuyo texto acusa a la cuenta, y el copy tiene que seguir siendo el genérico
        // porque el 409 no llegó solo a los 900 s. Con un fallo local al final esa aserción seguiría pudiendo fallar,
        // pero con el motivo que más duele equivocarse.
        fake.uploadOutcomes = [.blocked(.accountUnavailable), .blocked(.accountUnavailable), .transient,
                               .blocked(.localFailure), .blocked(.accountUnavailable)]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .uploadingSnapshot)

        await makeRunner(context, fake, now: { clock.value }).resume()          // t=0    abre el 409
        clock.value = fixedNow.addingTimeInterval(570)
        await makeRunner(context, fake, now: { clock.value }).resume()          // t=570  sigue el 409
        clock.value = fixedNow.addingTimeInterval(600)
        await makeRunner(context, fake, now: { clock.value }).resume()          // t=600  se cae la red: pausa
        let paused = try journal(context)
        #expect(paused.snapshotStallDefinitiveAt == nil, "la red cierra el tramo")
        #expect(paused.snapshotStallDefinitiveAccruedSeconds == 600, "con los diez minutos del 409 dentro")

        let back = fixedNow.addingTimeInterval(600 + 10_800)                    // tres horas después, vuelve el wifi
        clock.value = back
        await makeRunner(context, fake, now: { clock.value }).resume()
        let first = try journal(context)
        #expect(first.readPhase().phase == .uploadingSnapshot,
                "el primer fallo local tras tres horas de red no sale: las horas de red no se le cobran")
        #expect(first.snapshotStallCauseAccruedSeconds == 0, "y para su reloj de causa es la primera vez")

        clock.value = back.addingTimeInterval(299)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .uploadingSnapshot, "600 + 299: todavía no")

        clock.value = back.addingTimeInterval(300)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback,
                "600 del 409 + 299 del fallo local + 1 del 409 = 900 bajo motivos definitivos")
        #expect(j.snapshotExitReasonRaw == "mixedCauses",
                "el 409 de esta pasada lleva 1 s en su reloj de causa: no se ganó «tu cuenta no lo permitió»")
    }

    /// **Decisión, no accidente: un hueco SIN observaciones entre dos motivos definitivos distintos cuenta.** La sesión
    /// borrada, la app cerrada veinte minutos (nadie observa nada: el tramo sigue abierto) y, al volver, un fallo local.
    /// El reloj de lo definitivo lleva 1 200 s y la subida sale en esa pasada, con `mixedCauses`. Es la regla que el
    /// reloj por causa ya aplicaba a un solo motivo, y la que la vuelta decidió el mismo día
    /// (`reversePreMountDefinitiveClock_anUnobservedGapBetweenTwoCauses_counts`). Lo que NO cuenta es un hueco en el
    /// que se observó red (`networkHoursBetweenTwoCauses_areNotCharged`).
    @Test func snapshotDefinitiveClock_anUnobservedGapBetweenTwoCauses_counts() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.blocked(.sessionExpired), .blocked(.localFailure)]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .uploadingSnapshot)

        await makeRunner(context, fake, now: { clock.value }).resume()          // t=0: sesión borrada, y se cierra
        #expect(try journal(context).readPhase().phase == .uploadingSnapshot)

        clock.value = fixedNow.addingTimeInterval(1_200)                        // t=20 min: vuelve, fallo local
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback,
                "veinte minutos entre dos motivos definitivos, sin nada observado en medio")
        #expect(j.snapshotExitReasonRaw == "mixedCauses", "ninguno de los dos llegó solo al plazo")
    }

    /// **La excepción de una vez que dicen los docblocks, medida**: una fila de un build anterior a la v13 parada a
    /// mitad de la subida trae el reloj de CAUSA lleno y el de lo definitivo a `nil`. No sale en el acto aunque la causa
    /// ya pase de 900 s —la salida la decide el reloj nuevo, que empieza ahora—, y sale un plazo corto después con el
    /// texto específico, que entonces es verdad: el mismo motivo lleva más de 900 s él solo. El acumulado sembrado
    /// (950) ya pasa del plazo, así que la primera pasada prueba el «no en el acto» al pie de la letra.
    @Test func snapshotDefinitiveClock_aRowFromBeforeV13_leavesOneShortCeilingLater() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.blocked(.accountUnavailable)]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .uploadingSnapshot,
                        snapshotStallProgressAt: fixedNow, snapshotStallCauseRaw: "accountUnavailable",
                        snapshotStallCauseAt: nil, snapshotStallCauseAccruedSeconds: 950)

        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .uploadingSnapshot,
                "la causa ya trae 950 s, pero el reloj que decide empieza con este build: no sale en el acto")
        clock.value = fixedNow.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        var j = try journal(context)
        #expect(j.readPhase().phase == .uploadingSnapshot,
                "la causa ya lleva 1 849 s, pero el reloj que decide lleva 899 s")
        #expect(j.snapshotStallCauseAccruedSeconds == 950, "control: el de causa sí traía lo suyo")

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.snapshotExitReasonRaw == "accountUnavailable", "un solo motivo, y llegó solo al plazo")
    }

    /// **Volver a la fase desde `verifying` por mismatch empieza sin reloj.** Journal con un reloj de hace más de 72 h:
    /// la subida termina, el verify diverge, la fase vuelve, y la primera observación de la visita nueva holdea. Sin la
    /// limpieza al cruzar la fase, heredaría el sello viejo y saldría en el acto.
    @Test func snapshotCeiling_reenteringThePhaseAfterAMismatch_startsWithoutAClock() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.completed, .transient]
        fake.verifyProbes = [.mismatch]
        let now = fixedNow.addingTimeInterval(259_300)
        try seedJournal(context, phase: .uploadingSnapshot,
                        snapshotStallProgressAt: fixedNow, snapshotStallCauseRaw: "localFailure",
                        snapshotStallCauseAt: fixedNow, snapshotStallCauseAccruedSeconds: 0)

        await makeRunner(context, fake, now: { now }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .uploadingSnapshot, "la visita nueva no hereda las 72 h de la anterior")
        #expect(j.verifyMismatchRetries == 1, "control del escenario: pasó por el mismatch")
        #expect(j.snapshotStallProgressAt == now, "la primera observación de la visita nueva sella ahora")
        #expect(j.snapshotStallCauseRaw == nil, "y el motivo de la visita anterior se fue con ella")
    }

    /// Un sello en el FUTURO —el reloj iba adelantado y ya se corrigió— se re-sella ahora. Conservarlo aplazaría el
    /// techo hasta que el reloj real alcanzara aquella fecha.
    @Test func snapshotCeiling_aSealInTheFuture_isResealedNow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.transient]
        try seedJournal(context, phase: .uploadingSnapshot,
                        snapshotStallProgressAt: fixedNow.addingTimeInterval(86_400))

        await makeRunner(context, fake).resume()
        #expect(try journal(context).snapshotStallProgressAt == fixedNow)
    }

    /// «Cancelar la activación»: a `notStarted`, sin efectos, sin motivo y sin relojes. Es lo que la persona pidió.
    @Test func snapshotCancel_returnsToNotStarted_withNothingToExplain() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .uploadingSnapshot, leaderDeviceID: deviceID, snapshotCursor: "c3",
                        snapshotStallProgressAt: fixedNow, snapshotStallCauseRaw: "localFailure",
                        snapshotStallCauseAt: fixedNow, snapshotStallCauseAccruedSeconds: 10)

        await makeRunner(context, fake).cancelMigration()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects().isEmpty)
        #expect(fake.executedEffects.isEmpty, "no hay nada que deshacer: el teléfono sigue intacto")
        #expect(j.snapshotExitReasonRaw == nil, "lo decidió la persona: no hay fallo que explicar")
        #expect(j.snapshotStallProgressAt == nil)
        #expect(j.snapshotStallCauseRaw == nil)
        #expect(j.snapshotCursorJSON == nil, "el intento se cierra entero")
        #expect(j.startedAt == nil)
    }

    /// **El «sí» apuntado para la pasada en vuelo en la página siguiente** (hallazgo de la review). Sin el apunte, un
    /// re-kick que arrancara con el diálogo abierto y la red de vuelta subía todo y seguía hasta el cutover, y el «sí»
    /// llegaba tarde. El guion: la pasada confirma c1; durante el segundo intento la persona confirma; la segunda página
    /// termina y la pasada se para ANTES de pedir la tercera.
    @Test func snapshotCancel_requestedDuringAPass_stopsAtTheNextPage() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.pageConfirmed(cursor: "c1"), .pageConfirmed(cursor: "c2"), .completed]
        try seedJournal(context, phase: .uploadingSnapshot)
        let runner = makeRunner(context, fake)
        fake.onUploadSnapshot = { index in if index == 1 { runner.requestMigrationCancel() } }

        await runner.resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted, "la persona dijo que sí: la subida se para")
        #expect(fake.uploadCursorsSeen == [nil, "c1"], "y se para en la página siguiente, sin pedir la tercera")
        #expect(fake.verifyCallCount == 0, "no llega a verificar ni al cutover")
    }

    /// El «sí» vale para ESTA visita a la subida. Apuntado con la fase en otra parte, no cancela la visita siguiente —aquí,
    /// la vuelta desde `verifying` por mismatch—: la persona no dijo que sí a esa.
    @Test func snapshotCancel_requestedOutsideThePhase_doesNotCancelTheNextVisit() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.mismatch]
        fake.uploadOutcomes = [.transient]
        try seedJournal(context, phase: .verifying)
        let runner = makeRunner(context, fake)
        runner.requestMigrationCancel()

        await runner.resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .uploadingSnapshot, "la visita nueva sigue: nadie la canceló")
        #expect(fake.uploadCursorsSeen == [nil], "control: se llegó a intentar la subida")
    }

    /// Si la pasada que tenía que ejecutarlo no llegó a correr (sin quiescencia), el «sí» se queda apuntado y lo ejecuta
    /// la próxima pasada que llegue a la subida, sin volver a preguntar.
    @Test func snapshotCancel_withoutQuiescence_staysPendingForTheNextPass() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.uploadOutcomes = [.transient]
        try seedJournal(context, phase: .uploadingSnapshot)
        var quiescent = false
        let runner = makeRunner(context, fake, quiescence: { quiescent }, timeout: 0)
        runner.requestMigrationCancel()

        await runner.cancelMigration()
        #expect(try journal(context).readPhase().phase == .uploadingSnapshot, "sin quiescencia no se toca el journal")

        quiescent = true
        await runner.resume()
        #expect(try journal(context).readPhase().phase == .notStarted, "la próxima pasada ejecuta el «sí» apuntado")
        #expect(fake.uploadCursorsSeen.isEmpty, "sin subir nada antes")
    }

    /// Un «Cancelar» que llega tarde no saca a nadie de la fase en la que está.
    @Test func snapshotCancel_outsideThePhase_isANoOp() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .verifying)

        await makeRunner(context, fake).cancelMigration()
        #expect(try journal(context).readPhase().phase == .verifying)
        #expect(fake.uploadCursorsSeen.isEmpty && fake.verifyCallCount == 0, "y no arranca trabajo")
    }

    /// «Reintentar» tras una subida que venció su techo: el intento nuevo no puede nacer con el texto del anterior.
    @Test func snapshotExitReason_isClearedByTheRetry() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .failedRollback, snapshotExitReasonRaw: "localFailure")

        await makeRunner(context, fake).resetAfterRollback()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.snapshotExitReasonRaw == nil)
    }

    /// Un journal ilegible se normaliza entero, también los campos del techo de la subida.
    @Test func snapshotCeiling_aCorruptJournal_isNormalizedWithTheWholeFamily() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        let state = try seedJournal(context, phase: .uploadingSnapshot,
                                    snapshotStallProgressAt: fixedNow, snapshotStallCauseRaw: "localFailure",
                                    snapshotStallCauseAt: fixedNow, snapshotStallCauseAccruedSeconds: 10,
                                    snapshotExitReasonRaw: "stalled")
        state.phaseData = Data("no-es-una-fase".utf8)
        try context.save()

        await makeRunner(context, fake).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.snapshotStallProgressAt == nil)
        #expect(j.snapshotStallCauseRaw == nil)
        #expect(j.snapshotStallCauseAt == nil)
        #expect(j.snapshotStallCauseAccruedSeconds == nil)
        #expect(j.snapshotExitReasonRaw == nil)
    }

    // MARK: - §15 · Techo y salida de los tres pasos sin cifra que baje (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`)
    //
    // `claimingMigration` (22 %), `assigningIdentity` (35 %) y `cutover(.pending)` (80 %) cortaban sin evento ante un fallo
    // persistente y la barra se quedaba quieta para siempre. Cada caso mide que la FASE CAMBIA —o que no cambia cuando no
    // debe—, que es el criterio del ticket.

    /// **El claim, por su causa más común: la red.** Un claim que devuelve `.transient` sin fin sale a las 72 h, clavado con
    /// sus dos vecinos y con el motivo del techo LARGO.
    @Test func forwardStepCeiling_claim_persistentNetwork_leavesAt72h() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.transient(detail: "5xx")]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID, forwardClaimIntentRaw: "migrateOnly")

        await makeRunner(context, fake, now: { clock.value }).resume()        // sella
        var j = try journal(context)
        #expect(j.readPhase().phase == .claimingMigration)
        #expect(j.forwardStepStallProgressAt == fixedNow, "la primera observación sella el reloj de avance")
        #expect(j.forwardStepStallCauseRaw == nil, "la red no trae motivo: no hay reloj de causa")

        clock.value = fixedNow.addingTimeInterval(259_199)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .claimingMigration, "a 259 199 s todavía no")

        clock.value = fixedNow.addingTimeInterval(259_200)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "a las 72 h en el claim, se rinde")
        #expect(j.forwardStepExitReasonRaw == "stalled")
        #expect(fake.count(.rollback) == 1)
        #expect(j.forwardStepStallProgressAt == nil, "el reloj se va con la fase")
        #expect(j.snapshotExitReasonRaw == nil, "no es la subida: el motivo va en su propio campo")
        #expect(fake.claimMarksSeen == [true, true, true], "el claim de «Migrar» pide la marca del claim sin respuesta")
        #expect(j.adoptClaimExitRaw == nil, "la salida de «Migrar» no es la de un adopt: la pantalla vuelve a «Migrar»")
    }

    /// **La sesión que el SDK BORRA durante el claim** es definitiva: 900 s acumulados y sale con su nombre. El testigo se
    /// lee DESPUÉS del claim: el fake lo apaga dentro de la llamada, como hace el SDK antes de lanzar.
    @Test func forwardStepCeiling_claim_sessionGone_leavesAt900Seconds() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.sessionExpired(detail: "401")]
        fake.canRenewSessionResult = true
        fake.onPerformClaim = { fake.canRenewSessionResult = false }
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID, forwardClaimIntentRaw: "migrateOnly")

        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).forwardStepStallCauseRaw == "sessionExpired")
        clock.value = fixedNow.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .claimingMigration, "a 899 s todavía no")

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "sessionExpired")
    }

    /// **Un 401 con la sesión todavía GUARDADA no es definitivo**: el reloj atrasado del teléfono, o el token que no se
    /// renueva sin red. Espera el plazo LARGO, como en la subida.
    @Test func forwardStepCeiling_claim_sessionStillSaved_waitsTheLongCeiling() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.sessionExpired(detail: "401")]
        fake.canRenewSessionResult = true
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID, forwardClaimIntentRaw: "migrateOnly")

        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).forwardStepStallCauseRaw == nil)
        clock.value = fixedNow.addingTimeInterval(10_800)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .claimingMigration, "tres horas y sigue esperando")

        clock.value = fixedNow.addingTimeInterval(259_200)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "stalled")
    }

    /// El 403 del claim sale a los 900 s con `accountUnavailable`, y `lastClaimBlocker` sigue diciéndoselo al adopt.
    @Test func forwardStepCeiling_claim_accountUnavailable_leavesAt900Seconds() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.accountUnavailable(detail: "403")]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID, forwardClaimIntentRaw: "migrateOnly")

        await makeRunner(context, fake, now: { clock.value }).resume()
        clock.value = fixedNow.addingTimeInterval(900)
        let runner = makeRunner(context, fake, now: { clock.value })
        await runner.resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "accountUnavailable")
        #expect(runner.lastClaimBlocker == .accountUnavailable)
    }

    /// **La identidad, con su única causa: el `save()` local que lanza.** Sale a los 900 s con `localFailure`, clavado con
    /// sus dos vecinos. Hasta el ticket el `catch` hacía `return` y la barra se quedaba al 35 %.
    @Test func forwardStepCeiling_identity_persistentLocalFailure_leavesAt900Seconds() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.assignIdentityError = FakeError()
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .assigningIdentity, leaderDeviceID: deviceID)

        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).forwardStepStallCauseRaw == "localFailure")
        clock.value = fixedNow.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .assigningIdentity, "a 899 s todavía no")

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "a 900 s del mismo fallo local, sale")
        #expect(j.forwardStepExitReasonRaw == "localFailure")
        #expect(fake.count(.rollback) == 1)
        #expect(fake.uploadCursorsSeen.isEmpty, "control: no llegó a subir nada")
    }

    /// **El cutover `.pending`, por sus tres motivos definitivos.** Cada uno sale a los 900 s con su nombre: el texto de la
    /// tarjeta depende de esto. Ninguno llega al paso 2 (`persistLocalMode`): el teléfono sigue en `.icloud`.
    @Test func forwardStepCeiling_cutoverPending_definitiveAnswers_leaveWithTheirOwnReason() async throws {
        for (blocker, raw) in [(ForwardStepBlocker.otherDevice, "otherDevice"), (.refused, "refused"),
                               (.sessionExpired, "sessionExpired")] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.confirmCutoverOutcome = .blocked(blocker)
            let clock = MutableClock(fixedNow)
            try seedJournal(context, phase: .cutover(.pending), leaderDeviceID: deviceID)

            await makeRunner(context, fake, now: { clock.value }).resume()
            #expect(try journal(context).readPhase().phase == .cutover(.pending), "\(blocker): la primera observación holdea")
            clock.value = fixedNow.addingTimeInterval(900)
            await makeRunner(context, fake, now: { clock.value }).resume()
            let j = try journal(context)
            #expect(j.readPhase().phase == .failedRollback, "\(blocker)")
            #expect(j.forwardStepExitReasonRaw == raw)
            #expect(fake.executedEffects == [.rollback], "\(blocker): solo `.rollback`, sin tocar el modo ni el marcador")
            #expect(fake.persistLocalModeCallCount == 0)
        }
    }

    /// El cutover `.pending` con la red caída sale a las 72 h con `stalled`.
    @Test func forwardStepCeiling_cutoverPending_persistentNetwork_leavesAt72h() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.confirmCutoverOutcome = .transient
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .cutover(.pending), leaderDeviceID: deviceID)

        await makeRunner(context, fake, now: { clock.value }).resume()
        clock.value = fixedNow.addingTimeInterval(259_199)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .cutover(.pending))
        clock.value = fixedNow.addingTimeInterval(259_200)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "stalled")
    }

    /// **La salida del canal iCloud sigue yendo primero y no se pisa con el techo.** Con un reloj del paso de hace días y el
    /// canal sabido-roto, la pasada sale por la precondición: con su veredicto, sin motivo del techo y sin llamar al servidor.
    @Test func forwardStepCeiling_cutoverPending_theICloudPreconditionStillGoesFirst() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.icloudVerdict = .quotaExceeded
        fake.confirmCutoverOutcome = .transient
        try seedJournal(context, phase: .cutover(.pending), leaderDeviceID: deviceID,
                        forwardStepStallProgressAt: fixedNow.addingTimeInterval(-300_000))

        await makeRunner(context, fake).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.cutoverICloudVerdictRaw == ICloudChannelVerdict.quotaExceeded.rawValue)
        #expect(j.forwardStepExitReasonRaw == nil, "salió por la puerta del canal, no por el techo")
        #expect(fake.confirmCutoverCallCount == 0)
    }

    /// **Pasar de paso ES el avance, y la identidad no hereda el reloj del claim.** Journal en el claim con 72 h + 100 s de
    /// parada y 950 s acumulados bajo `localFailure` (en pausa): el claim sale bien, la identidad falla en la misma pasada, y
    /// su primera observación holdea con un reloj nuevo. Sin la limpieza de `handle` en el cambio de paso saldría en el acto,
    /// por cualquiera de los dos relojes.
    @Test func forwardStepCeiling_changingStep_restartsBothClocks() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.created)]
        fake.assignIdentityError = FakeError()
        let now = fixedNow.addingTimeInterval(259_300)
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID,
                        forwardClaimIntentRaw: "migrateOnly",
                        forwardStepStallProgressAt: fixedNow, forwardStepStallCauseRaw: "localFailure",
                        forwardStepStallCauseAt: nil, forwardStepStallCauseAccruedSeconds: 950)

        await makeRunner(context, fake, now: { now }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .assigningIdentity, "el paso nuevo no hereda la parada del anterior")
        #expect(fake.assignIdentityCallCount == 1, "control del escenario: el claim avanzó y la identidad se intentó")
        #expect(j.forwardStepStallProgressAt == now, "el reloj de avance empieza en el paso nuevo")
        #expect(j.forwardStepStallCauseAt == now)
        #expect(j.forwardStepStallCauseAccruedSeconds == 0, "y el de causa empieza de cero")
    }

    /// **Una observación SIN motivo PAUSA el reloj de causa del paso.** Mismo guion que la subida, sobre el claim: 403 a t0 y
    /// a 840 s · red a 850 s · 403 a 1000 s y a 1050 s (900 acumulados: sale). Mide los tres campos del reloj de causa.
    @Test func forwardStepCeiling_anObservationWithoutACause_pausesInsteadOfResetting() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.accountUnavailable(detail: "403"), .accountUnavailable(detail: "403"),
                              .transient(detail: "5xx"), .accountUnavailable(detail: "403"),
                              .accountUnavailable(detail: "403")]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID, forwardClaimIntentRaw: "migrateOnly")

        for offset in [0.0, 840, 850, 1000] {
            clock.value = fixedNow.addingTimeInterval(offset)
            await makeRunner(context, fake, now: { clock.value }).resume()
            #expect(try journal(context).readPhase().phase == .claimingMigration, "a \(offset) s todavía no")
        }
        #expect(try journal(context).forwardStepStallCauseAccruedSeconds == 850, "el hueco de la red no sumó")

        clock.value = fixedNow.addingTimeInterval(1050)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "900 s acumulados bajo el 403")
        #expect(j.forwardStepExitReasonRaw == "accountUnavailable")
    }

    /// **El motivo lo elige el techo que VENCIÓ.** A las 72 h en el claim, una pasada con un 403 recién visto sale con
    /// `stalled`: el 403 tiene cero segundos.
    @Test func forwardStepCeiling_theLongCeilingWithAFreshBlocker_leavesAsStalled() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.accountUnavailable(detail: "403")]
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID,
                        forwardClaimIntentRaw: "migrateOnly", forwardStepStallProgressAt: fixedNow)

        await makeRunner(context, fake, now: { self.fixedNow.addingTimeInterval(259_200) }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "stalled")
    }

    /// Un sello en el FUTURO —el reloj iba adelantado y ya se corrigió— se re-sella ahora.
    @Test func forwardStepCeiling_aSealInTheFuture_isResealedNow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.confirmCutoverOutcome = .transient
        try seedJournal(context, phase: .cutover(.pending), leaderDeviceID: deviceID,
                        forwardStepStallProgressAt: fixedNow.addingTimeInterval(86_400))

        await makeRunner(context, fake).resume()
        #expect(try journal(context).forwardStepStallProgressAt == fixedNow)
    }

    /// «Cancelar la activación» desde los tres pasos: a `notStarted`, sin efectos, sin motivo y sin relojes.
    @Test func forwardStepCancel_fromEachStep_returnsToNotStarted_withNothingToExplain() async throws {
        for phase in [Phase.claimingMigration, .assigningIdentity, .cutover(.pending)] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            try seedJournal(context, phase: phase, leaderDeviceID: deviceID, forwardClaimIntentRaw: "migrateOnly",
                            forwardStepStallProgressAt: fixedNow, forwardStepStallCauseRaw: "localFailure",
                            forwardStepStallCauseAt: fixedNow, forwardStepStallCauseAccruedSeconds: 10)

            await makeRunner(context, fake).cancelMigration()
            let j = try journal(context)
            #expect(j.readPhase().phase == .notStarted, "\(phase)")
            #expect(j.readPendingEffects().isEmpty)
            #expect(fake.executedEffects.isEmpty, "\(phase): no hay nada que deshacer")
            #expect(j.forwardStepExitReasonRaw == nil, "lo decidió la persona: no hay fallo que explicar")
            #expect(j.forwardStepStallProgressAt == nil)
            #expect(j.forwardStepStallCauseRaw == nil)
            #expect(j.leaderDeviceID == nil, "el intento se cierra entero")
            #expect(fake.claimCallCount == 0 && fake.assignIdentityCallCount == 0 && fake.confirmCutoverCallCount == 0,
                    "\(phase): cancelar no arranca trabajo")
        }
    }

    /// **El «sí» vale para la PASADA.** Llega con el claim en vuelo; el claim sale bien y la pasada se para en la identidad,
    /// que también ofrece cancelar, antes de intentarla. Hasta el ticket el «sí» se tiraba al salir de la subida, y dado al
    /// 22 % se habría perdido: la pasada seguía hasta el cutover.
    @Test func forwardStepCancel_requestedDuringTheClaim_stopsAtTheNextStep() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.created)]
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID, forwardClaimIntentRaw: "migrateOnly")
        let runner = makeRunner(context, fake)
        fake.onPerformClaim = { runner.requestMigrationCancel() }

        await runner.resume()
        #expect(try journal(context).readPhase().phase == .notStarted, "la persona dijo que sí: la activación se para")
        #expect(fake.claimCallCount == 1, "control: el claim estaba en vuelo y salió bien")
        #expect(fake.assignIdentityCallCount == 0, "y la pasada se paró antes de la identidad")
        #expect(fake.uploadCursorsSeen.isEmpty)
    }

    /// **Y se retira en la primera fase que no lo ofrece.** Un «sí» que llega con el cutover confirmándose en el servidor no
    /// puede deshacer un cutover que ya pasó: desde `.serverConfirmed` manda «el cutover jamás hace rollback», y la pasada
    /// sigue hasta el final.
    @Test func forwardStepCancel_requestedWhileTheCutoverIsConfirmed_doesNotRollBackAConfirmedCutover() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.confirmCutoverOutcome = .confirmed
        try seedJournal(context, phase: .cutover(.pending), leaderDeviceID: deviceID)
        let runner = makeRunner(context, fake)
        fake.onConfirmCutover = { runner.requestMigrationCancel() }

        await runner.resume()
        #expect(try journal(context).readPhase().phase == .done, "el cutover confirmado sigue hasta el final")
        #expect(fake.persistLocalModeCallCount == 1, "control: pasó por el paso 2")
        #expect(fake.count(.rollback) == 0)
    }

    /// «Reintentar» tras un paso que venció su techo: el intento nuevo no nace con el texto del anterior.
    @Test func forwardStepExitReason_isClearedByTheRetry() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .failedRollback, forwardStepExitReasonRaw: "otherDevice")

        await makeRunner(context, fake).resetAfterRollback()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.forwardStepExitReasonRaw == nil)
    }

    /// Un journal ilegible se normaliza entero, también los campos del techo de los tres pasos.
    @Test func forwardStepCeiling_aCorruptJournal_isNormalizedWithTheWholeFamily() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        let state = try seedJournal(context, phase: .claimingMigration,
                                    forwardStepStallProgressAt: fixedNow, forwardStepStallCauseRaw: "localFailure",
                                    forwardStepStallCauseAt: fixedNow, forwardStepStallCauseAccruedSeconds: 10,
                                    forwardStepExitReasonRaw: "stalled")
        state.phaseData = Data("no-es-una-fase".utf8)
        try context.save()

        await makeRunner(context, fake).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.forwardStepStallProgressAt == nil)
        #expect(j.forwardStepStallCauseRaw == nil)
        #expect(j.forwardStepStallCauseAt == nil)
        #expect(j.forwardStepStallCauseAccruedSeconds == nil)
        #expect(j.forwardStepExitReasonRaw == nil)
    }

    // MARK: - §16 · El claim de un ADOPT también tiene techo y salida (ticket `adopt-claim-stays-parked-with-no-ceiling`)
    //
    // Hasta este ticket el claim de «Ya tengo una cuenta» / «Activar la nube en este dispositivo» cortaba sin evento y la
    // barra se quedaba al 22 % para siempre con una sesión borrada o un 403. Cada caso mide que la FASE cambia y que la
    // salida deja la marca que hace que la pantalla ofrezca volver a entrar en la cuenta.

    /// **El 403 de un adopt**, con la intención journaleada y con una fila sin intención (anterior a la v6, que se lee como
    /// adopt): a 899 s sigue, a 900 s sale con su motivo y deja la marca. Sin marca de «Migrar»: su claim no la pide.
    @Test func adoptClaimCeiling_accountUnavailable_leavesAt900Seconds_withTheMark() async throws {
        for intentRaw in ["adoptIfExisting", nil] as [String?] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.claimOutcomes = [.accountUnavailable(detail: "403")]
            let clock = MutableClock(fixedNow)
            try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID, forwardClaimIntentRaw: intentRaw)
            let label = String(describing: intentRaw)

            await makeRunner(context, fake, now: { clock.value }).resume()
            var j = try journal(context)
            #expect(j.forwardStepStallCauseRaw == "accountUnavailable", "\(label): el reloj de causa arranca")
            #expect(j.adoptClaimExitRaw == nil, "\(label): esperar todavía no es salir")
            clock.value = fixedNow.addingTimeInterval(899)
            await makeRunner(context, fake, now: { clock.value }).resume()
            #expect(try journal(context).readPhase().phase == .claimingMigration, "\(label): a 899 s todavía no")

            clock.value = fixedNow.addingTimeInterval(900)
            let runner = makeRunner(context, fake, now: { clock.value })
            await runner.resume()
            j = try journal(context)
            #expect(j.readPhase().phase == .failedRollback, "\(label): a los 900 s sale")
            #expect(j.forwardStepExitReasonRaw == "accountUnavailable")
            #expect(j.adoptClaimExitRaw == "accountUnavailable", "\(label): la salida de un adopt deja su marca")
            #expect(fake.count(.rollback) == 1)
            #expect(fake.claimMarksSeen.allSatisfy { !$0 }, "\(label): la marca de «Migrar» sigue siendo solo de «Migrar»")
            #expect(runner.lastClaimBlocker == .accountUnavailable, "el Welcome lo sigue leyendo")
        }
    }

    /// **La sesión que el SDK borra durante el claim de un adopt**: 900 s y sale como `sessionExpired`, que pide volver a
    /// entrar.
    @Test func adoptClaimCeiling_sessionGone_leavesAt900Seconds() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.sessionExpired(detail: "401")]
        fake.canRenewSessionResult = true
        fake.onPerformClaim = { fake.canRenewSessionResult = false }
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID,
                        forwardClaimIntentRaw: "adoptIfExisting")

        await makeRunner(context, fake, now: { clock.value }).resume()
        clock.value = fixedNow.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .claimingMigration)
        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.adoptClaimExitRaw == "sessionExpired")
    }

    /// **La red en un adopt espera el plazo LARGO**: su espera suele curarse sola, así que tres horas no son nada. A las
    /// 72 h sin avanzar sale con `stalled`, que no acusa a nadie.
    @Test func adoptClaimCeiling_persistentNetwork_leavesAt72h() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.transient(detail: "5xx")]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID,
                        forwardClaimIntentRaw: "adoptIfExisting")

        await makeRunner(context, fake, now: { clock.value }).resume()
        clock.value = fixedNow.addingTimeInterval(259_199)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .claimingMigration, "a 259 199 s todavía no")
        clock.value = fixedNow.addingTimeInterval(259_200)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "stalled")
        #expect(j.adoptClaimExitRaw == "stalled")
    }

    /// **«Cancelar la activación» en el claim de un adopt**: va a `notStarted`, sin efectos, con la marca `cancelled`. Es
    /// lo que hace que Almacenamiento ofrezca «Activar la nube en este dispositivo» en vez de «Migrar».
    @Test func adoptClaimCancel_goesToNotStarted_withTheMark() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID,
                        forwardClaimIntentRaw: "adoptIfExisting")

        await makeRunner(context, fake).cancelMigration()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects().isEmpty)
        #expect(j.adoptClaimExitRaw == "cancelled")
        #expect(j.forwardClaimIntentRaw == nil, "la intención es del intento que se cierra")
    }

    /// «Cancelar» en el claim de «Migrar» no deja la marca del adopt: su pantalla sigue siendo «Migrar».
    @Test func migrateClaimCancel_doesNotLeaveTheAdoptMark() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID, forwardClaimIntentRaw: "migrateOnly")

        await makeRunner(context, fake).cancelMigration()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.adoptClaimExitRaw == nil)
    }

    /// **La marca sobrevive a «Reintentar»** —es la salida hacia delante de la tarjeta de fallo— **y se va cuando otro claim
    /// empieza**: desde ahí manda el desenlace del intento nuevo.
    @Test func adoptClaimMark_survivesTheRetry_andGoesWhenTheNextClaimStarts() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.transient(detail: "5xx")]
        try seedJournal(context, phase: .failedRollback, forwardStepExitReasonRaw: "accountUnavailable",
                        adoptClaimExitRaw: "accountUnavailable")

        let runner = makeRunner(context, fake)
        await runner.resetAfterRollback()
        var j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.forwardStepExitReasonRaw == nil, "el motivo de la tarjeta se va con «Reintentar»")
        #expect(j.adoptClaimExitRaw == "accountUnavailable", "la marca no: es lo que abre la tarjeta de adopt")

        // Un intento que no llega al claim —la persona cancela el inicio de sesión— tampoco la toca.
        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        await runner.submit(.signInFailed)
        j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.adoptClaimExitRaw == "accountUnavailable", "sin claim, la salida hacia delante sigue abierta")

        fake.accountHash = "cuenta-b"
        runner.setForwardClaimIntent(.adoptIfExisting)
        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        j = try journal(context)
        #expect(j.adoptClaimExitRaw == "accountUnavailable", "antes del claim todavía no ha empezado nada")
        await runner.submit(.signInSucceeded)
        j = try journal(context)
        #expect(j.readPhase().phase == .claimingMigration, "el claim nuevo se aparca por la red")
        #expect(j.adoptClaimExitRaw == nil, "y la marca del intento anterior ya no manda")
        #expect(j.adoptClaimAccountHash == "cuenta-b", "la cuenta del intento se apunta al entrar en el claim")
    }

    /// **La cuenta del intento se lee al ENTRAR, no al salir**: la salida definitiva más común es la sesión borrada, y
    /// re-leerla en cada observación dejaría la marca sin cuenta. El claim aparcado con la sesión ya sin cuenta conserva la
    /// que tenía al entrar, y la salida la deja junto a la marca.
    @Test func adoptClaimAccount_isTheOneAtEntry_notReReadWhileParked() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.sessionExpired(detail: "401")]
        fake.canRenewSessionResult = false
        fake.accountHash = "cuenta-a"
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .notStarted)
        let runner = makeRunner(context, fake, now: { clock.value })
        runner.setForwardClaimIntent(.adoptIfExisting)
        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        await runner.submit(.signInSucceeded)
        #expect(try journal(context).adoptClaimAccountHash == "cuenta-a")

        fake.accountHash = nil                       // el SDK borró la sesión
        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.adoptClaimExitRaw == "sessionExpired")
        #expect(j.adoptClaimAccountHash == "cuenta-a", "la marca queda atada a la cuenta del intento")
    }

    /// **Lo que vio el último claim**, para el aviso del 22 %: el 403 y la sesión borrada se ven; la red y el 401 con la
    /// sesión guardada, no, y un claim que falla por la red DESPUÉS de un 403 deja de decirlo (el reloj journaleado lo
    /// conservaría: por eso el aviso no lo lee).
    @Test func lastClaimDefinitiveCause_isWhatTheLastClaimSaw() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID,
                        forwardClaimIntentRaw: "adoptIfExisting")
        let runner = makeRunner(context, fake)

        fake.claimOutcomes = [.accountUnavailable(detail: "403")]
        await runner.resume()
        #expect(runner.lastClaimDefinitiveCause == .accountUnavailable)
        #expect(try journal(context).forwardStepStallCauseRaw == "accountUnavailable", "control: el reloj también lo vio")

        fake.claimOutcomes = [.transient(detail: "5xx")]
        await runner.resume()
        #expect(runner.lastClaimDefinitiveCause == nil, "la red no confirma el 403: el aviso calla")
        #expect(try journal(context).forwardStepStallCauseRaw == "accountUnavailable", "y el reloj lo conserva, pausado")

        fake.claimOutcomes = [.sessionExpired(detail: "401")]
        fake.canRenewSessionResult = true
        await runner.resume()
        #expect(runner.lastClaimDefinitiveCause == nil, "un 401 con la sesión guardada no es definitivo")

        fake.canRenewSessionResult = false
        await runner.resume()
        #expect(runner.lastClaimDefinitiveCause == .sessionExpired)
    }

    /// **El «sí» apuntado en el claim de un adopt** se honra en la próxima pasada y deja la marca, igual que el toque.
    @Test func adoptClaimCancel_requestedDuringTheClaim_isHonoredWithTheMark() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.transient(detail: "5xx")]
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID,
                        forwardClaimIntentRaw: "adoptIfExisting")
        let runner = makeRunner(context, fake)
        fake.onPerformClaim = { runner.requestMigrationCancel() }

        await runner.resume()
        #expect(try journal(context).readPhase().phase == .claimingMigration, "la pasada en vuelo se aparca")
        fake.onPerformClaim = nil
        await runner.resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted, "la pasada siguiente honra el «sí» antes de volver a reclamar")
        #expect(fake.claimCallCount == 1, "sin un segundo claim")
        #expect(j.adoptClaimExitRaw == "cancelled")
    }

    // MARK: - §16-bis · La espera del SEGUIDOR también tiene techo y salida (ticket `adopt-follower-waits-for-the-leader-with-no-ceiling`)
    //
    // Hasta este ticket `pollLeaderInternal` solo apuntaba `lastClaimBlocker` con la sesión borrada o un 403 y devolvía sin
    // evento: «esperando a otro dispositivo» para siempre. Decisiones de Jürgen del 2026-09-23: el techo del 22 % (15 min
    // acumulados con un motivo definitivo, 72 h sin noticias del líder), cada `claiming_in_progress` es avance, y
    // «Cancelar la activación» con la salida del adopt. Cada caso mide que la FASE cambia, o que no cambia cuando no toca.

    /// **El 403 persistente en la espera**, con la intención journaleada y con una fila sin intención: a 899 s sigue
    /// esperando, a 900 s sale con su motivo y la marca del adopt.
    @Test func followerCeiling_accountUnavailable_leavesAt900Seconds_withTheMark() async throws {
        for intentRaw in ["adoptIfExisting", nil] as [String?] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.claimOutcomes = [.accountUnavailable(detail: "403")]
            let clock = MutableClock(fixedNow)
            try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: intentRaw)
            let label = String(describing: intentRaw)

            await makeRunner(context, fake, now: { clock.value }).pollLeader()
            var j = try journal(context)
            #expect(j.readPhase().phase == .waitingForLeader, "\(label)")
            #expect(j.forwardStepStallCauseRaw == "accountUnavailable", "\(label): el reloj de causa arranca")
            clock.value = fixedNow.addingTimeInterval(899)
            await makeRunner(context, fake, now: { clock.value }).pollLeader()
            #expect(try journal(context).readPhase().phase == .waitingForLeader, "\(label): a 899 s todavía no")

            clock.value = fixedNow.addingTimeInterval(900)
            await makeRunner(context, fake, now: { clock.value }).pollLeader()
            j = try journal(context)
            #expect(j.readPhase().phase == .failedRollback, "\(label): a los 900 s sale")
            #expect(j.forwardStepExitReasonRaw == "accountUnavailable")
            #expect(j.adoptClaimExitRaw == "accountUnavailable", "\(label): la salida del seguidor deja la marca del adopt")
            #expect(fake.count(.rollback) == 1)
            #expect(fake.claimMarksSeen.allSatisfy { !$0 }, "el seguidor no pide la marca de «Migrar»")
        }
    }

    /// **La sesión que el SDK BORRA durante la espera**: 900 s y sale como `sessionExpired`. Con la sesión todavía guardada
    /// (un 401 que el SDK puede curar) no hay techo corto: sigue hasta el largo.
    @Test func followerCeiling_sessionGone_leavesAt900Seconds_butAStoredSessionWaitsTheLongOne() async throws {
        for renewable in [false, true] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.claimOutcomes = [.sessionExpired(detail: "401")]
            fake.canRenewSessionResult = renewable
            let clock = MutableClock(fixedNow)
            try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: "adoptIfExisting")

            await makeRunner(context, fake, now: { clock.value }).pollLeader()
            clock.value = fixedNow.addingTimeInterval(900)
            await makeRunner(context, fake, now: { clock.value }).pollLeader()
            let j = try journal(context)
            if renewable {
                #expect(j.readPhase().phase == .waitingForLeader, "con la sesión guardada, 15 min no bastan")
                #expect(j.forwardStepStallCauseRaw == nil, "y el reloj de causa ni arranca")
            } else {
                #expect(j.readPhase().phase == .failedRollback)
                #expect(j.forwardStepExitReasonRaw == "sessionExpired")
                #expect(j.adoptClaimExitRaw == "sessionExpired")
            }
        }
    }

    /// **La red en la espera**: plazo largo. A las 72 h sin noticias del líder sale con `stalled`, que no acusa a nadie.
    @Test func followerCeiling_persistentNetwork_leavesAt72h() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.transient(detail: "5xx")]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: "adoptIfExisting")

        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        #expect(try journal(context).forwardStepStallProgressAt == fixedNow, "la primera observación sella el reloj")
        clock.value = fixedNow.addingTimeInterval(259_199)
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        #expect(try journal(context).readPhase().phase == .waitingForLeader, "a 259 199 s todavía no")
        clock.value = fixedNow.addingTimeInterval(259_200)
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "stalled")
        #expect(j.adoptClaimExitRaw == "stalled")
    }

    /// **Cada `claiming_in_progress` es AVANCE** (decisión de Jürgen): el líder latió en la última hora, así que las 72 h
    /// vuelven a empezar. Borra los relojes y los sella la siguiente observación que no avanza, como en los otros tres pasos.
    @Test func followerCeiling_leaderAlive_restartsTheLongClock() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: "adoptIfExisting")

        fake.claimOutcomes = [.transient(detail: "5xx")]
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        #expect(try journal(context).forwardStepStallProgressAt == fixedNow)
        clock.value = fixedNow.addingTimeInterval(200_000)
        fake.claimOutcomes = [.success(.claimingInProgress)]
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        #expect(try journal(context).forwardStepStallProgressAt == nil, "el líder vivo borra el reloj")

        fake.claimOutcomes = [.transient(detail: "5xx")]
        let resealedAt = fixedNow.addingTimeInterval(259_200)
        clock.value = resealedAt
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        var j = try journal(context)
        #expect(j.readPhase().phase == .waitingForLeader,
                "72 h desde la primera observación, pero el líder contestó en medio")
        #expect(j.forwardStepStallProgressAt == resealedAt, "la primera observación sin noticias vuelve a sellar")
        clock.value = resealedAt.addingTimeInterval(259_199)
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        #expect(try journal(context).readPhase().phase == .waitingForLeader)
        clock.value = resealedAt.addingTimeInterval(259_200)
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "72 h seguidas sin noticias del líder")
        #expect(j.adoptClaimExitRaw == "stalled")
    }

    /// **El avance borra también el reloj de CAUSA**: una respuesta del claim prueba que la sesión y la cuenta funcionaron,
    /// así que un 403 anterior no se le suma al siguiente.
    @Test func followerCeiling_leaderAlive_restartsTheCauseClock() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: "adoptIfExisting")

        fake.claimOutcomes = [.accountUnavailable(detail: "403")]
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        clock.value = fixedNow.addingTimeInterval(800)
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        clock.value = fixedNow.addingTimeInterval(850)
        fake.claimOutcomes = [.success(.claimingInProgress)]
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        var j = try journal(context)
        #expect(j.forwardStepStallCauseRaw == nil && j.forwardStepStallCauseAccruedSeconds == nil)

        fake.claimOutcomes = [.accountUnavailable(detail: "403")]
        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        clock.value = fixedNow.addingTimeInterval(1_799)
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        #expect(try journal(context).readPhase().phase == .waitingForLeader, "899 s desde que el 403 volvió")
        clock.value = fixedNow.addingTimeInterval(1_800)
        await makeRunner(context, fake, now: { clock.value }).pollLeader()
        j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.adoptClaimExitRaw == "accountUnavailable")
    }

    /// **Ni entrar en la espera ni una respuesta del líder sellan el reloj** (hallazgo de la review): el seguidor es quien
    /// cierra Yala mientras espera. Si vuelve días después sin red, el primer poll SELLA, no sale: su líder pudo terminar, y
    /// un solo poll con red lo adoptaría. Con el sello en la entrada salía aquí con «lleva días sin avanzar».
    @Test func followerClock_isNotSealedByGoodNews_soAFirstOfflinePollDaysLaterWaits() async throws {
        for entersByTheClaim in [true, false] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.claimOutcomes = [.success(.claimingInProgress)]
            let clock = MutableClock(fixedNow)
            if entersByTheClaim {
                try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID,
                                forwardClaimIntentRaw: "adoptIfExisting")
                await makeRunner(context, fake, now: { clock.value }).resume()
            } else {
                try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: "adoptIfExisting",
                                forwardStepStallProgressAt: fixedNow.addingTimeInterval(-100))
                await makeRunner(context, fake, now: { clock.value }).pollLeader()
            }
            let label = entersByTheClaim ? "al entrar" : "tras un líder vivo"
            var j = try journal(context)
            #expect(j.readPhase().phase == .waitingForLeader, "\(label)")
            #expect(j.forwardStepStallProgressAt == nil, "\(label): la buena noticia no sella")

            fake.claimOutcomes = [.transient(detail: "sin red")]
            clock.value = fixedNow.addingTimeInterval(4 * 86_400)
            await makeRunner(context, fake, now: { clock.value }).pollLeader()
            j = try journal(context)
            #expect(j.readPhase().phase == .waitingForLeader, "\(label): cuatro días después, el primer poll sin red espera")
            #expect(j.forwardStepStallProgressAt == clock.value, "\(label): y sella")
        }
    }

    /// **«Cancelar la activación» en la espera**: a `notStarted`, sin efectos, con la marca `cancelled`, que hace que
    /// Almacenamiento ofrezca «Activar la nube en este dispositivo».
    @Test func followerCancel_goesToNotStarted_withTheMark() async throws {
        for intentRaw in ["adoptIfExisting", nil] as [String?] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: intentRaw)

            await makeRunner(context, fake).cancelMigration()
            let j = try journal(context)
            #expect(j.readPhase().phase == .notStarted, "\(String(describing: intentRaw))")
            #expect(j.readPendingEffects().isEmpty)
            #expect(j.adoptClaimExitRaw == "cancelled")
            #expect(fake.claimCallCount == 0, "cancelar no pregunta al servidor")
        }
    }

    /// **El «sí» que se perdía** (el hallazgo de la review de #221): confirmado con el claim del adopt en vuelo, y el claim
    /// contesta `claiming_in_progress`. Antes la fase pasaba a la espera, que no ofrecía cancelar, y el «sí» se retiraba: la
    /// persona aterrizaba en la tarjeta sin botón. Ahora la misma pasada cancela.
    @Test func adoptClaimCancel_requestedDuringAClaimThatAnswersInProgress_cancels() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.claimingInProgress)]
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID,
                        forwardClaimIntentRaw: "adoptIfExisting")
        let runner = makeRunner(context, fake)
        fake.onPerformClaim = { runner.requestMigrationCancel() }

        await runner.resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted, "no aterriza en la espera")
        #expect(j.adoptClaimExitRaw == "cancelled")
        #expect(fake.claimCallCount == 1)
    }

    /// El «sí» dado con el POLL en vuelo, cuando el líder sigue trabajando: se honra en esa misma pasada, sin otro claim.
    @Test func followerCancel_requestedDuringThePoll_isHonoredInThatPass() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.claimingInProgress)]
        try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: "adoptIfExisting")
        let runner = makeRunner(context, fake)
        fake.onPerformClaim = { runner.requestMigrationCancel() }

        await runner.pollLeader()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.adoptClaimExitRaw == "cancelled")
        #expect(fake.claimCallCount == 1)
    }

    /// El «sí» dado con el poll en vuelo cuando el líder se ESFUMÓ (`created`): se honra desde la espera, con la marca del
    /// adopt y sin tomar el relevo. Traducido primero, el relevo escribía el faro y cancelaba ya en la identidad, sin marca:
    /// Almacenamiento ofrecía «Migrar» a quien confirmó dejar de esperar (lo cazaron dos lentes de la review).
    @Test func followerCancel_requestedWhenTheLeaderVanished_doesNotTakeOver() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.created)]
        try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: "adoptIfExisting")
        let runner = makeRunner(context, fake)
        fake.onPerformClaim = { runner.requestMigrationCancel() }

        await runner.pollLeader()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.adoptClaimExitRaw == "cancelled", "sale con la marca del adopt")
        #expect(fake.count(.writeBeacon) == 0, "sin faro: no tomó el relevo")
        #expect(fake.assignIdentityCallCount == 0)
    }

    /// Un «sí» que ya estaba apuntado se honra ANTES de volver a reclamar: reclamar otra vez podría adoptar a quien ya dijo
    /// que cancelaba.
    @Test func followerCancel_pendingYes_isHonoredBeforeClaimingAgain() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.existingStable)]
        try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: "adoptIfExisting")
        let runner = makeRunner(context, fake)
        runner.requestMigrationCancel()

        await runner.pollLeader()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.adoptClaimExitRaw == "cancelled")
        #expect(fake.claimCallCount == 0, "sin claim: el líder podía haber terminado y se habría adoptado")
        #expect(fake.count(.adoptBackendAccount) == 0)
    }

    /// El «sí» dado con el poll en vuelo cuando el líder TERMINA: el adopt no corre (lo para la comprobación previa al
    /// efecto, `adopt-effect-retries-forever-with-no-ceiling`) y sale con la marca.
    @Test func followerCancel_requestedWhenTheLeaderFinishes_doesNotAdopt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.existingStable)]
        try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: "adoptIfExisting")
        let runner = makeRunner(context, fake)
        fake.onPerformClaim = { runner.requestMigrationCancel() }

        await runner.pollLeader()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects().isEmpty)
        #expect(fake.attempts(.adoptBackendAccount) == 0)
        #expect(j.adoptClaimExitRaw == "cancelled")
    }

    /// **Lo que vio el último poll**, para el aviso de la tarjeta de espera: el 403 y la sesión borrada se ven; la red y el
    /// líder vivo lo apagan.
    @Test func follower_lastClaimDefinitiveCause_isWhatTheLastPollSaw() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .waitingForLeader, forwardClaimIntentRaw: "adoptIfExisting")
        let runner = makeRunner(context, fake)

        fake.claimOutcomes = [.accountUnavailable(detail: "403")]
        await runner.pollLeader()
        #expect(runner.lastClaimDefinitiveCause == .accountUnavailable)
        fake.claimOutcomes = [.success(.claimingInProgress)]
        await runner.pollLeader()
        #expect(runner.lastClaimDefinitiveCause == nil, "el líder vivo: la cuenta contestó")
        fake.claimOutcomes = [.sessionExpired(detail: "401")]
        fake.canRenewSessionResult = false
        await runner.pollLeader()
        #expect(runner.lastClaimDefinitiveCause == .sessionExpired)
        fake.claimOutcomes = [.transient(detail: "5xx")]
        await runner.pollLeader()
        #expect(runner.lastClaimDefinitiveCause == nil, "la red no confirma nada")
        #expect(try journal(context).readPhase().phase == .waitingForLeader, "control: nada de esto salió")
    }

    // MARK: - §16 · Techo y salida del EFECTO del adopt (ticket `adopt-effect-retries-forever-with-no-ceiling`)
    //
    // El par `(notStarted, [.adoptBackendAccount])`: el claim ya contestó `existing_stable` y el reconcile de huérfanas no
    // termina. Hasta ese ticket el runner lo reintentaba para siempre. Decisiones de Jürgen del 2026-09-23: 15 min
    // acumulados con la base local que no se deja leer, 72 h con cualquier causa, la salida del claim del adopt.

    private var adoptLocal: any Error { MigrationExecutorError.adoptLocalFailure }
    private var adoptNetwork: any Error { MigrationExecutorError.adoptRetry(reason: "reconcileTransient") }

    /// **La base local que no se deja leer** sale a los 900 s acumulados, clavado con sus dos vecinos, con la marca del
    /// adopt que elige el texto de «este dispositivo no pudo leer tus datos».
    @Test func adoptEffectCeiling_localFailure_leavesAt900Seconds_withTheMark() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.effectErrors[.adoptBackendAccount] = adoptLocal
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount])

        await makeRunner(context, fake, now: { clock.value }).resume()
        var j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects() == [.adoptBackendAccount], "bajo presupuesto el efecto sigue pendiente")
        #expect(j.adoptEffectStallProgressAt == fixedNow, "la primera observación sella el reloj largo")
        #expect(j.adoptEffectStallDefinitiveAt == fixedNow, "y abre el tramo del corto")

        clock.value = fixedNow.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .notStarted, "a 899 s todavía no")
        #expect(j.readPendingEffects() == [.adoptBackendAccount])

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "a los 900 s acumulados, se rinde")
        #expect(j.readPendingEffects().isEmpty, "el adopt ya no está pendiente: no se reintenta más")
        #expect(fake.count(.rollback) == 1)
        #expect(j.adoptClaimExitRaw == "effectLocalFailure")
        #expect(j.adoptEffectStallProgressAt == nil && j.adoptEffectStallDefinitiveAt == nil
                && j.adoptEffectStallDefinitiveAccruedSeconds == nil, "el reloj se va con la salida")
        #expect(j.forwardStepExitReasonRaw == nil && j.snapshotExitReasonRaw == nil, "el motivo va en la marca del adopt")
    }

    /// **La red PAUSA el reloj corto, no lo borra.** Con el re-kick de 30 s una racha consecutiva no llegaría nunca con
    /// cobertura intermitente. 600 s de avería, una observación de red, y 300 s más de avería salen a los 900 acumulados;
    /// con un reinicio harían falta 900 desde la última observación de red.
    @Test func adoptEffectCeiling_networkPausesTheShortClock_doesNotResetIt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount])

        fake.effectErrors[.adoptBackendAccount] = adoptLocal
        await makeRunner(context, fake, now: { clock.value }).resume()                     // abre el tramo
        clock.value = fixedNow.addingTimeInterval(600)
        fake.effectErrors[.adoptBackendAccount] = adoptNetwork
        await makeRunner(context, fake, now: { clock.value }).resume()                     // cierra: 600 acumulados
        var j = try journal(context)
        #expect(j.adoptEffectStallDefinitiveAccruedSeconds == 600)
        #expect(j.adoptEffectStallDefinitiveAt == nil, "tramo cerrado")

        fake.effectErrors[.adoptBackendAccount] = adoptLocal
        clock.value = fixedNow.addingTimeInterval(1000)
        await makeRunner(context, fake, now: { clock.value }).resume()                     // reabre sin sumar el hueco
        clock.value = fixedNow.addingTimeInterval(1299)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .notStarted, "600 + 299 = 899: todavía no")

        clock.value = fixedNow.addingTimeInterval(1300)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "600 + 300 = 900 acumulados")
        #expect(j.adoptClaimExitRaw == "effectLocalFailure")
    }

    /// **La red que no vuelve** sale a las 72 h con el texto de «lleva días», clavado con sus dos vecinos. La pasada que
    /// cruza el plazo trae la avería LOCAL a propósito: su texto sería el equivocado, y el motivo lo elige el techo que
    /// venció, no la última observación.
    @Test func adoptEffectCeiling_persistentNetwork_leavesAt72h_withTheStalledText() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.effectErrors[.adoptBackendAccount] = adoptNetwork
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount])

        await makeRunner(context, fake, now: { clock.value }).resume()
        var j = try journal(context)
        #expect(j.adoptEffectStallProgressAt == fixedNow)
        #expect(j.adoptEffectStallDefinitiveAt == nil && (j.adoptEffectStallDefinitiveAccruedSeconds ?? 0) == 0,
                "la red no abre el reloj corto: sin tramo abierto y nada acumulado")

        clock.value = fixedNow.addingTimeInterval(259_199)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .notStarted, "a 259 199 s todavía no")

        clock.value = fixedNow.addingTimeInterval(259_200)
        fake.effectErrors[.adoptBackendAccount] = adoptLocal
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "a las 72 h, se rinde")
        #expect(j.adoptClaimExitRaw == "effectStalled", "venció el largo: la avería recién vista no se lleva el texto")
        #expect(fake.count(.rollback) == 1)
    }

    // MARK: §16-bis · La guarda de linaje del adopt (ticket `adopt-uploads-a-foreign-corpus-without-a-lineage-check`)

    private var adoptLineage: any Error { MigrationExecutorError.adoptLineageUnproven }

    /// **Un corpus que no demuestra venir de la cuenta** es causa DEFINITIVA: sale a los 900 s acumulados, clavado con sus dos
    /// vecinos, con SU marca —no la de la base local—, que elige el texto de «no pudimos comprobar que vengan de ella».
    @Test func adoptEffectCeiling_lineageUnproven_leavesAt900Seconds_withItsOwnMark() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.effectErrors[.adoptBackendAccount] = adoptLineage
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount], adoptClaimAccountHash: "cuenta-x")

        await makeRunner(context, fake, now: { clock.value }).resume()
        var j = try journal(context)
        #expect(j.readPendingEffects() == [.adoptBackendAccount], "bajo presupuesto el efecto sigue pendiente")
        #expect(j.adoptEffectStallDefinitiveAt == fixedNow, "el linaje abre el tramo del corto, como la base local")

        clock.value = fixedNow.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .notStarted, "a 899 s todavía no")

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback, "a los 900 s acumulados, se rinde")
        #expect(j.readPendingEffects().isEmpty, "el adopt ya no se reintenta")
        #expect(fake.count(.rollback) == 1)
        #expect(j.adoptClaimExitRaw == "effectLineageUnproven")
        #expect(j.adoptClaimAccountHash == nil,
                "por linaje la marca no queda atada a la cuenta: es la sospechosa, y atarla bloquea entrar con la buena")
    }

    /// **Las dos causas definitivas comparten el reloj corto, y la salida la nombra la observación que lo vence** (Paso 0,
    /// D5). 600 s de base local ilegible y 300 s de linaje sin probar salen a los 900 acumulados con el texto del linaje;
    /// al revés, con el de la base local. Si cada causa tuviera su reloj, ninguna de las dos pasadas saldría.
    @Test func adoptEffectCeiling_definitiveCausesShareTheShortClock_theLastOneNamesTheExit() async throws {
        for (first, last, expected) in [(adoptLocal, adoptLineage, "effectLineageUnproven"),
                                         (adoptLineage, adoptLocal, "effectLocalFailure")] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            let clock = MutableClock(fixedNow)
            try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount], adoptClaimAccountHash: "cuenta-x")

            fake.effectErrors[.adoptBackendAccount] = first
            await makeRunner(context, fake, now: { clock.value }).resume()
            clock.value = fixedNow.addingTimeInterval(600)
            fake.effectErrors[.adoptBackendAccount] = last
            await makeRunner(context, fake, now: { clock.value }).resume()
            #expect(try journal(context).readPhase().phase == .notStarted, "600 s: todavía no")

            clock.value = fixedNow.addingTimeInterval(900)
            await makeRunner(context, fake, now: { clock.value }).resume()
            let j = try journal(context)
            #expect(j.readPhase().phase == .failedRollback, "900 s acumulados entre las dos causas")
            #expect(j.adoptClaimExitRaw == expected)
            #expect(j.adoptClaimAccountHash == (expected == "effectLineageUnproven" ? nil : "cuenta-x"),
                    "solo la salida por linaje suelta la cuenta; la de la base local la conserva")
        }
    }

    /// **El camino real: el claim que contesta `existing_stable` y el efecto que falla dentro del mismo `handle`.** La
    /// observación corre ahí también, no solo en el `resume` del arranque.
    @Test func adoptEffectCeiling_observesTheFailureRightAfterTheClaim() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.existingStable)]
        fake.effectErrors[.adoptBackendAccount] = adoptLocal
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID,
                        forwardClaimIntentRaw: "adoptIfExisting")

        await makeRunner(context, fake).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects() == [.adoptBackendAccount])
        #expect(j.adoptEffectStallProgressAt == fixedNow, "el primer fallo del efecto ya sella el reloj")
    }

    /// **Un adopt nuevo no hereda el reloj del anterior.** Con un sello de hace 72 h y sin la limpieza de `handle`, el
    /// primer fallo del intento nuevo saldría con cero segundos de parada real.
    @Test func adoptEffectCeiling_aNewClaimRestartsTheClock() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.existingStable)]
        fake.effectErrors[.adoptBackendAccount] = adoptLocal
        try seedJournal(context, phase: .claimingMigration, leaderDeviceID: deviceID,
                        forwardClaimIntentRaw: "adoptIfExisting",
                        adoptEffectStallProgressAt: fixedNow.addingTimeInterval(-259_200),
                        adoptEffectStallDefinitiveAt: fixedNow.addingTimeInterval(-900),
                        adoptEffectStallDefinitiveAccruedSeconds: 0)

        await makeRunner(context, fake).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted, "el intento nuevo espera: el sello viejo no cuenta")
        #expect(j.adoptEffectStallProgressAt == fixedNow)
        #expect(j.adoptEffectStallDefinitiveAccruedSeconds == 0)
        #expect(j.adoptClaimExitRaw == nil)
    }

    /// **El adopt que termina se lleva su reloj** en el mismo save que retira el efecto.
    @Test func adoptEffectCeiling_success_clearsTheClock() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.effectErrors[.adoptBackendAccount] = adoptLocal
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount])
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).adoptEffectStallProgressAt == fixedNow, "control: el fallo selló")

        fake.effectErrors[.adoptBackendAccount] = nil
        clock.value = fixedNow.addingTimeInterval(100)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects().isEmpty)
        #expect(fake.count(.adoptBackendAccount) == 1)
        #expect(j.adoptEffectStallProgressAt == nil && j.adoptEffectStallDefinitiveAt == nil
                && j.adoptEffectStallDefinitiveAccruedSeconds == nil)
        #expect(j.adoptClaimExitRaw == nil, "terminar no es una salida")
    }

    /// **Con `.cloud` ya persistido no hay techo.** Un kill tras el paso 5 relanza con el pendiente; salir de ahí a
    /// `failedRollback` dejaría `.cloud` en un terminal de fallo. Se reintenta como antes y no se sella nada.
    @Test func adoptEffectCeiling_withTheCloudModePersisted_neverLeaves() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.persistedCloudMode = true
        fake.effectErrors[.adoptBackendAccount] = adoptLocal
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount],
                        adoptEffectStallProgressAt: fixedNow, adoptEffectStallDefinitiveAt: fixedNow,
                        adoptEffectStallDefinitiveAccruedSeconds: 0)

        clock.value = fixedNow.addingTimeInterval(259_200)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects() == [.adoptBackendAccount])
        #expect(fake.count(.rollback) == 0)
        #expect(j.adoptClaimExitRaw == nil)

        // Y tampoco se cancela: el adopt ya hizo lo irreversible.
        await makeRunner(context, fake, now: { clock.value }).cancelMigration()
        #expect(try journal(context).readPendingEffects() == [.adoptBackendAccount])
    }

    /// **«Cancelar la activación» con el efecto del adopt pendiente**: a `notStarted` sin el pendiente, sin `.rollback` y
    /// con la marca del adopt, que hace que Almacenamiento ofrezca «Activar la nube en este dispositivo».
    @Test func adoptEffectCancel_dropsThePending_withTheMark() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount],
                        adoptEffectStallProgressAt: fixedNow, adoptEffectStallDefinitiveAt: fixedNow,
                        adoptEffectStallDefinitiveAccruedSeconds: 0)

        await makeRunner(context, fake).cancelMigration()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects().isEmpty)
        #expect(j.adoptClaimExitRaw == "cancelled")
        #expect(fake.executeAttempts.isEmpty, "cancelar no ejecuta el adopt ni un rollback")
        #expect(j.adoptEffectStallProgressAt == nil, "el reloj se va con la cancelación")
    }

    /// **Sin el pendiente no hay nada que cancelar**: `notStarted` a secas es el teléfono que nunca empezó.
    @Test func adoptEffectCancel_withoutThePending_isANoOp() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .notStarted)

        await makeRunner(context, fake).cancelMigration()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.adoptClaimExitRaw == nil, "no deja la marca: nadie estaba entrando en una cuenta")
    }

    /// **El «sí» que llega con el efecto en vuelo** se honra en la misma pasada, en cuanto el intento falla, en vez de
    /// esperar al siguiente re-kick.
    @Test func adoptEffectCancel_requestedDuringTheEffect_isHonoredInThePass() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.effectErrors[.adoptBackendAccount] = adoptNetwork
        try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount])
        let runner = makeRunner(context, fake)
        fake.onExecute = { effect in if effect == .adoptBackendAccount { runner.requestMigrationCancel() } }

        await runner.resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects().isEmpty, "la pasada canceló en vez de dejarlo pendiente")
        #expect(j.adoptClaimExitRaw == "cancelled")
        #expect(fake.count(.rollback) == 0)
    }

    /// **Un sello del reloj largo en el FUTURO se re-sella ahora**: el reloj del teléfono iba adelantado y ya se corrigió.
    /// Conservarlo aplazaría las 72 h hasta que el reloj real alcanzase aquella fecha.
    @Test func adoptEffectCeiling_aFutureSeal_isResealedNow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.effectErrors[.adoptBackendAccount] = adoptNetwork
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount],
                        adoptEffectStallProgressAt: fixedNow.addingTimeInterval(86_400))

        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).adoptEffectStallProgressAt == fixedNow, "re-sellado a ahora")

        clock.value = fixedNow.addingTimeInterval(259_200)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .failedRollback, "las 72 h cuentan desde el re-sellado")
    }

    /// **El «sí» apuntado ANTES de un intento que saldría bien** se honra antes de intentarlo: mirándolo solo al fallar, la
    /// persona que confirmó «Cancelar» acababa adoptada (hallazgo de la review).
    @Test func adoptEffectCancel_requestedBeforeASuccessfulAttempt_isHonoredFirst() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        try seedJournal(context, phase: .notStarted, pending: [.adoptBackendAccount])
        let runner = makeRunner(context, fake)
        runner.requestMigrationCancel()

        await runner.resume()
        let j = try journal(context)
        #expect(fake.attempts(.adoptBackendAccount) == 0, "no se vuelve a intentar")
        #expect(j.readPendingEffects().isEmpty)
        #expect(j.adoptClaimExitRaw == "cancelled")

        // Control: sin el «sí», el mismo resume adopta.
        let dir2 = freshDir(); defer { cleanup(dir2) }
        let context2 = try makeContext(dir2)
        let fake2 = FakeExecutor()
        try seedJournal(context2, phase: .notStarted, pending: [.adoptBackendAccount])
        await makeRunner(context2, fake2).resume()
        #expect(fake2.count(.adoptBackendAccount) == 1)
    }

    // MARK: - El linaje de la ida (ticket `migration-takeover-uploads-without-a-lineage-check`)

    /// Conduce «Migrar» de `notStarted` a donde llegue con un claim `created`.
    private func driveMigration(_ runner: MigrationRunner) async {
        await runner.startMigration(dryRun: false)
        await runner.submit(.consentAccepted)
        await runner.submit(.signInSucceeded)
    }

    /// **Criterio 3: el alta normal no paga nada.** Con el servidor diciendo que la cuenta no recibió datos personales
    /// (`has_personal_writes: false`, la cuenta nueva o solo de grupos), la identidad no pregunta y la migración llega al
    /// final como antes del ticket.
    @Test func forwardLineage_claimWithoutPersonalWrites_skipsTheCheck() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimPersonalWrites = false
        fake.lineageOutcomes = [.unproven(liveRows: 9)]   // si preguntara, bloquearía: el test lo vería
        await driveMigration(makeRunner(context, fake))
        #expect(fake.lineageCallCount == 0, "sin datos en la cuenta no hay enumeración")
        #expect(try journal(context).readPhase().phase == .done)
    }

    /// **Criterio 2: el relevo legítimo termina.** Con datos en la cuenta —y también sin pista, un servidor sin g16_03: falla
    /// cerrado— la identidad pregunta UNA vez, lo prueba y la migración llega al final.
    @Test(arguments: [true as Bool?, nil as Bool?])
    func forwardLineage_claimOnAnAccountWithData_checksOnceAndFinishes(hint: Bool?) async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimPersonalWrites = hint
        fake.lineageOutcomes = [.proven(sharedRows: 3)]
        await driveMigration(makeRunner(context, fake))
        #expect(fake.lineageCallCount == 1)
        #expect(try journal(context).readPhase().phase == .done)
    }

    /// Sin filas vivas en la cuenta (el líder callado murió antes de subir) no hay nada que mezclar: sigue.
    @Test func forwardLineage_noLivePersonalRows_finishes() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimPersonalWrites = true
        fake.lineageOutcomes = [.noLivePersonalRows]
        await driveMigration(makeRunner(context, fake))
        #expect(try journal(context).readPhase().phase == .done)
    }

    /// **Criterio 1: el relevo con otro corpus no sube nada y sale.** La identidad no llega a asignar ni la subida a
    /// empezar; a 899 s sigue esperando y a 900 s sale a `failedRollback` con su motivo propio, que elige el texto.
    @Test func forwardLineage_unproven_uploadsNothing_andLeavesAt900Seconds() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimPersonalWrites = true
        fake.lineageOutcomes = [.unproven(liveRows: 42)]
        let clock = MutableClock(fixedNow)
        let runner = makeRunner(context, fake, now: { clock.value })
        await driveMigration(runner)
        var j = try journal(context)
        #expect(j.readPhase().phase == .assigningIdentity)
        #expect(j.forwardLineageUnverified == true, "la pista se journaleó con la transición del claim")
        #expect(j.forwardStepStallCauseRaw == "lineageUnproven")
        #expect(fake.assignIdentityCallCount == 0, "ni la identidad toca nada")
        #expect(fake.uploadCursorsSeen.isEmpty, "ni se sube nada")

        clock.value = fixedNow.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .assigningIdentity, "a 899 s todavía no")

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "lineageUnproven")
        #expect(j.forwardLineageUnverified == nil, "la pista es del intento que se cierra")
        #expect(fake.count(.rollback) == 1)
        #expect(fake.assignIdentityCallCount == 0)
        #expect(fake.uploadCursorsSeen.isEmpty)
    }

    /// **Ticket `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived`.** El relevo del mismo iCloud
    /// al que aún no le llegaron las identidades del líder no asigna identidad ni sube: subir duplicaría su libro. Espera con
    /// el techo corto y, si en ese tiempo iCloud las trae, la pasada siguiente vuelve a preguntar y termina.
    @Test func forwardLineage_accountRowsMissing_uploadsNothing_andFinishesWhenTheyArrive() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimPersonalWrites = true
        fake.lineageOutcomes = [.accountRowsMissing(table: "transaction_items", missing: 7), .proven(sharedRows: 12)]
        let clock = MutableClock(fixedNow)
        await driveMigration(makeRunner(context, fake, now: { clock.value }))
        var j = try journal(context)
        #expect(j.readPhase().phase == .assigningIdentity)
        #expect(j.forwardStepStallCauseRaw == "leaderRowsNotArrived", "su motivo, no el del corpus ajeno")
        #expect(j.forwardLineageUnverified == true, "sin prueba no se journalea «probado»")
        #expect(fake.assignIdentityCallCount == 0, "ni la identidad toca nada")
        #expect(fake.uploadCursorsSeen.isEmpty, "ni se sube nada")

        clock.value = fixedNow.addingTimeInterval(600)
        await makeRunner(context, fake, now: { clock.value }).resume()
        j = try journal(context)
        #expect(fake.lineageCallCount == 2, "vuelve a preguntar: la espera es la recuperación")
        #expect(j.readPhase().phase == .done)
    }

    /// Y si a los 15 min siguen sin llegar, sale con su motivo propio, que elige el texto de «abre Yala en el otro dispositivo,
    /// espera a iCloud y reintenta».
    @Test func forwardLineage_accountRowsMissing_leavesAt900SecondsWithItsOwnReason() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimPersonalWrites = true
        fake.lineageOutcomes = [.accountRowsMissing(table: "categories", missing: 1)]
        let clock = MutableClock(fixedNow)
        await driveMigration(makeRunner(context, fake, now: { clock.value }))

        clock.value = fixedNow.addingTimeInterval(899)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .assigningIdentity, "a 899 s todavía no")

        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "leaderRowsNotArrived")
        #expect(fake.assignIdentityCallCount == 0)
        #expect(fake.uploadCursorsSeen.isEmpty)
    }

    /// **El relevo del SEGUIDOR** —el caso del ticket: espera a un líder que calla, y su re-claim recibe el turno— también
    /// journalea la pista y comprueba. La pista se escribe en `handle`, al entrar en la identidad, y no en `driveClaim`: el
    /// seguidor entra por `pollLeader`, que es otro claim (lo cazaron dos lentes de la review). Y una pista `false` de un
    /// intento anterior no se hereda: cada entrada en la identidad la reescribe.
    @Test func forwardLineage_followerTakeover_checksToo() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.claimOutcomes = [.success(.created)]
        fake.claimPersonalWrites = true
        fake.lineageOutcomes = [.unproven(liveRows: 5)]
        let state = try seedJournal(context, phase: .waitingForLeader)
        state.forwardLineageUnverified = false            // lo que quedara de un intento anterior
        try context.save()
        let runner = makeRunner(context, fake)
        await runner.pollLeader()
        let j = try journal(context)
        #expect(j.readPhase().phase == .assigningIdentity)
        #expect(j.forwardLineageUnverified == true)
        #expect(fake.lineageCallCount == 1)
        #expect(j.forwardStepStallCauseRaw == "lineageUnproven")
        #expect(fake.uploadCursorsSeen.isEmpty)
    }

    /// La red —o una enumeración que el Merkle no da por completa— no es definitiva: pausa el reloj corto y espera el
    /// largo. A 900 s sigue en la identidad.
    @Test func forwardLineage_transient_waitsTheLongCeiling() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.lineageOutcomes = [.transient]
        let clock = MutableClock(fixedNow)
        try seedJournal(context, phase: .assigningIdentity, leaderDeviceID: deviceID)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).forwardStepStallCauseRaw == nil)
        clock.value = fixedNow.addingTimeInterval(900)
        await makeRunner(context, fake, now: { clock.value }).resume()
        #expect(try journal(context).readPhase().phase == .assigningIdentity)
        #expect(fake.assignIdentityCallCount == 0)
    }

    /// El inventario local ilegible en la comprobación cuenta como la base local de la identidad: el mismo motivo y la
    /// misma salida, no «probado».
    @Test func forwardLineage_localFailure_isTheIdentityLocalFailure() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.lineageOutcomes = [.localFailure]
        try seedJournal(context, phase: .assigningIdentity, leaderDeviceID: deviceID)
        await makeRunner(context, fake).resume()
        #expect(try journal(context).forwardStepStallCauseRaw == "localFailure")
        #expect(fake.assignIdentityCallCount == 0)
    }

    /// **Una fila de antes de la v16 parada en la identidad COMPRUEBA** (`nil` falla cerrado), y la prueba se journalea:
    /// la pasada siguiente —aquí, tras un `save()` local que falla— no vuelve a enumerar.
    @Test func forwardLineage_preV16Row_checks_andTheProofIsJournaled() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.lineageOutcomes = [.proven(sharedRows: 1)]
        fake.assignIdentityError = FakeError()
        try seedJournal(context, phase: .assigningIdentity, leaderDeviceID: deviceID)
        #expect(try journal(context).forwardLineageUnverified == nil)

        await makeRunner(context, fake).resume()
        #expect(fake.lineageCallCount == 1)
        #expect(try journal(context).forwardLineageUnverified == false)

        fake.assignIdentityError = nil
        await makeRunner(context, fake).resume()
        #expect(fake.lineageCallCount == 1, "probado una vez, no se vuelve a enumerar")
        #expect(fake.assignIdentityCallCount == 2)
        #expect(try journal(context).readPhase().phase == .done)
    }

    // MARK: - El líder DESPLAZADO no sube nada más (ticket `displaced-migration-leader-keeps-uploading-after-a-takeover`)

    /// El teléfono vuelve tras más de 60 min sin latir y otro ya lidera: no sube ni una página, y sale en el acto con el
    /// motivo que elige «otro dispositivo con tu cuenta tomó el relevo». Sin techo: la primera pasada ya sale.
    @Test func displacedLeader_upload_lostLease_uploadsNothingAndLeavesAtOnce() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.leaseChecks = [.lost]
        fake.uploadOutcomes = [.pageConfirmed(cursor: "c2")]
        try seedJournal(context, phase: .uploadingSnapshot, leaderDeviceID: deviceID, snapshotCursor: "c1")

        await runner(context, fake).resume()

        let j = try journal(context)
        #expect(fake.uploadCursorsSeen.isEmpty, "ni una página más")
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "otherDevice")
        #expect(j.snapshotExitReasonRaw == nil, "no es el techo de la subida: su texto taparía el del relevo")
        #expect(fake.count(.rollback) == 1)
        #expect(fake.verifyCallCount == 0)
    }

    /// La puerta va delante de CADA página, no de cada pasada: una pasada suspendida más de 60 min se reanuda a mitad. La
    /// primera página sube con el lease confirmado; la segunda pregunta, recibe «otro lidera» y no sale.
    @Test func displacedLeader_upload_losesTheLeaseMidUpload_stopsBeforeTheNextPage() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.leaseChecks = [.held, .lost]
        fake.uploadOutcomes = [.pageConfirmed(cursor: "c1"), .pageConfirmed(cursor: "c2"), .completed]
        try seedJournal(context, phase: .uploadingSnapshot, leaderDeviceID: deviceID)

        await runner(context, fake).resume()

        #expect(fake.leaseCallLog == ["lease", "upload", "lease"], "la pregunta va DELANTE de cada página")
        #expect(fake.uploadCursorsSeen == [nil])
        let j = try journal(context)
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "otherDevice")
    }

    /// Sin poder preguntar —red, 5xx— no sube, pero tampoco sale: la pasada cuenta como una espera de red de la subida,
    /// con su reloj largo y sin motivo. La siguiente pasada vuelve a preguntar.
    @Test func displacedLeader_upload_unconfirmed_uploadsNothingAndWaitsLikeTheNetwork() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.leaseChecks = [.unconfirmed]
        try seedJournal(context, phase: .uploadingSnapshot, leaderDeviceID: deviceID, snapshotCursor: "c1")
        let r = runner(context, fake)

        await r.resume()
        var j = try journal(context)
        #expect(fake.uploadCursorsSeen.isEmpty)
        #expect(j.readPhase().phase == .uploadingSnapshot)
        #expect(j.snapshotStallProgressAt == fixedNow, "la observación sella el reloj de la subida")
        #expect(j.snapshotStallCauseRaw == nil, "sin motivo: es una espera de red")
        #expect(j.snapshotCursorJSON == "c1", "el cursor no se toca")
        #expect(j.forwardStepExitReasonRaw == nil)

        fake.leaseChecks = [.held]
        await r.resume()
        j = try journal(context)
        #expect(fake.leaseCheckCallCount == 3, "no se cachea: la pasada siguiente vuelve a preguntar (y otra vez al verificar)")
        #expect(fake.uploadCursorsSeen.first == "c1", "con el lease confirmado sigue desde su cursor")
    }

    /// Sin token y sin sesión que renovar: el mismo motivo que el push le daría a esa página.
    @Test func displacedLeader_upload_sessionExpired_waitsWithTheSessionMotive() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.leaseChecks = [.sessionExpired]
        try seedJournal(context, phase: .uploadingSnapshot, leaderDeviceID: deviceID)

        await runner(context, fake).resume()

        let j = try journal(context)
        #expect(fake.uploadCursorsSeen.isEmpty)
        #expect(j.readPhase().phase == .uploadingSnapshot)
        #expect(j.snapshotStallCauseRaw == "sessionExpired")
    }

    /// La verificación empuja el outbox y trae el corpus de la cuenta: el líder desplazado que vuelve con el journal aquí
    /// tampoco la corre, y sale con el mismo motivo.
    @Test func displacedLeader_verify_lostLease_neitherPushesNorPulls_andLeavesAtOnce() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.leaseChecks = [.lost]
        try seedJournal(context, phase: .verifying, leaderDeviceID: deviceID)

        await runner(context, fake).resume()

        let j = try journal(context)
        #expect(fake.verifyCallCount == 0, "ni push ni pull")
        #expect(j.readPhase().phase == .failedRollback)
        #expect(j.forwardStepExitReasonRaw == "otherDevice")
        #expect(fake.count(.rollback) == 1)
        #expect(fake.confirmCutoverCallCount == 0)
    }

    /// Sin poder confirmar el lease, la verificación no corre y la pasada gasta un reintento de red, lo que `verify()`
    /// haría con su propia red. La sesión borrada, igual: en la ida se lee como red.
    @Test func displacedLeader_verify_unconfirmedOrSessionExpired_spendsANetworkRetryWithoutVerifying() async throws {
        for check in [MigrationLeaseCheck.unconfirmed, .sessionExpired] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let fake = FakeExecutor()
            fake.leaseChecks = [check]
            try seedJournal(context, phase: .verifying, leaderDeviceID: deviceID, networkRetries: 2)

            await runner(context, fake).resume()

            let j = try journal(context)
            #expect(fake.verifyCallCount == 0, "\(check)")
            #expect(j.readPhase().phase == .verifying, "\(check)")
            #expect(j.verifyNetworkRetries == 3, "\(check)")
            #expect(j.forwardStepExitReasonRaw == nil, "\(check)")
        }
    }

    /// Con el lease confirmado la verificación corre como siempre, y la pregunta va delante.
    @Test func displacedLeader_verify_heldLease_verifiesAfterAsking() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.verifyProbes = [.match]
        fake.confirmCutoverOutcome = .transient
        try seedJournal(context, phase: .verifying, leaderDeviceID: deviceID)

        await runner(context, fake).resume()

        #expect(Array(fake.leaseCallLog.prefix(2)) == ["lease", "verify"])
        #expect(fake.verifyLeaseFlags == [true], "la ida verifica bajo el lease")
        #expect(try journal(context).readPhase().phase == .cutover(.pending))
    }

    /// La salida del relevo se lee en la tarjeta como el relevo, y «Reintentar» la limpia: el intento siguiente vuelve a
    /// reclamar y el claim decide si este teléfono sigue o lidera.
    @Test func displacedLeader_exitReadsAsTheTakeover_andTheRetryClearsIt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.leaseChecks = [.lost]
        try seedJournal(context, phase: .uploadingSnapshot, leaderDeviceID: deviceID)
        let r = runner(context, fake)

        await r.resume()
        var j = try journal(context)
        let text = StorageFailureCopyLogic.message(
            kind: .migration,
            snapshotExit: j.snapshotExitReasonRaw.flatMap(SnapshotExitReason.init(rawValue:)),
            forwardStepExit: j.forwardStepExitReasonRaw.flatMap(ForwardStepExitReason.init(rawValue:)),
            cutoverBlocker: nil)
        #expect(text == L10n.Storage.Failed.stepOtherDevice)

        await r.resetAfterRollback()
        j = try journal(context)
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.forwardStepExitReasonRaw == nil)
    }

    /// La vuelta a iCloud no pasa por la puerta de la ida: ni pregunta por su lease ni verifica bajo él.
    @Test func displacedLeader_reverseVerify_neitherAsksNorVerifiesUnderTheForwardLease() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fake = FakeExecutor()
        fake.leaseChecks = [.lost]
        fake.verifyProbes = [.networkTimeout]
        try seedJournal(context, phase: .reverseVerify, reverseOriginRaw: "done")

        await runner(context, fake).resume()

        #expect(fake.leaseCheckCallCount == 0)
        #expect(fake.verifyLeaseFlags == [false])
        #expect(try journal(context).readPhase().phase == .reverseVerify)
    }
}
