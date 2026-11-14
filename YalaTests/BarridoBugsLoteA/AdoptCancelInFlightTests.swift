//
//  AdoptCancelInFlightTests.swift
//  YalaTests
//
//  Barrido del iPhone 14 (14-nov), lote A. Cards l4m0 y 0f7h: «Sí, cancelar» durante «Conectando con tu cuenta» se
//  ignoraba si el intento en vuelo salía bien (terminaba en «¡Tu cuenta está lista!»), y cerrar Yala antes de que
//  aterrizara perdía el «sí» (el arranque retomaba). Aquí se fija:
//   - que el efecto del adopt mira el «sí» DENTRO del intento, en sus puntos seguros, y que el runner lo convierte en la
//     cancelación con su marca (la huella que lee la bienvenida para volver al inicio);
//   - que el «sí» de la bienvenida vive en disco con la marca de la entrada y se honra al arrancar.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

// MARK: - Ejecutor mínimo

/// Solo modela el efecto del adopt. Con `honorsProbe` hace lo que hace el ejecutor real en sus puntos seguros: si el «sí»
/// llegó con el intento en vuelo, sale con `adoptCancelRequested`; si no, el intento termina bien (adopta).
@MainActor
private final class AdoptOnlyExecutor: MigrationWorkExecuting {
    var probe: (@MainActor () -> Bool)?
    var onAdoptAttempt: (() -> Void)?
    var adopted = 0

    func installAdoptCancelProbe(_ probe: @escaping @MainActor () -> Bool) { self.probe = probe }

    func execute(_ effect: MigrationEffect) async throws {
        guard effect == .adoptBackendAccount else { return }
        onAdoptAttempt?()
        if probe?() == true { throw MigrationExecutorError.adoptCancelRequested }
        adopted += 1
    }

    func performClaim(marksMigrationAttempt: Bool) async -> ClaimOutcome { .success(.existingStable) }
    func assignIdentity() async throws {}
    func uploadSnapshot(cursor: String?) async -> SnapshotStepOutcome { .completed }
    func verify(underMigrationLease: Bool) async -> VerifyProbe { .match }
    func canRenewSession() -> Bool { true }
    func confirmCutoverServer() async -> CutoverServerOutcome { .confirmed }
    func persistLocalMode() async -> Bool { true }
    func isMirrorConfirmedOff() -> Bool { false }
    func isMarkerExported() -> Bool { true }
    func performReverseClaim() async -> ReverseClaimOutcome { .transient }
    func reverseDrainOnce() async -> ReverseStepOutcome { .transient }
    func freezeBackendForReverse() async -> ReverseStepOutcome { .transient }
    func isMirrorConfirmedOn() -> Bool { false }
    func sweepZombies(sinceSeq: Int64) async -> ZombieSweepOutcome { .completed(deleted: 0) }
    func verifyRebinds() -> Int? { 0 }
    func healDuplicates() -> Int { 0 }
    func reverseUploadStatus() -> ReverseUploadStatus { .drained }
    func confirmMigrationLease() async -> MigrationLeaseCheck { .held }
}

@Suite("Lote A · el «sí» de cancelar llega al intento en vuelo (l4m0)", .serialized)
@MainActor
struct AdoptCancelInFlightRunnerTests {

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration("LA-Personal", schema: SwiftDataConfiguration.personalSchema,
                                          url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration("LA-Groups", schema: SwiftDataConfiguration.groupsSchema,
                                        url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration("LA-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
                                          url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LoteA-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("no se pudo crear \(dir): \(error)")
        }
        return dir
    }

    private func seedAdoptEffectPending(_ context: ModelContext) throws {
        let state = MigrationState()
        state.setPhase(.notStarted)
        state.setPendingEffects([.adoptBackendAccount])
        context.insert(state)
        try context.save()
    }

    private func journal(_ context: ModelContext) throws -> MigrationState {
        var descriptor = FetchDescriptor<MigrationState>()
        descriptor.fetchLimit = 1
        return try #require(try context.fetch(descriptor).first)
    }

    private func makeRunner(_ context: ModelContext, _ executor: AdoptOnlyExecutor) -> MigrationRunner {
        MigrationRunner(context: context, executor: executor, deviceID: "device-lote-a",
                        quiescenceSignal: { true }, now: { Date(timeIntervalSince1970: 1_700_000_000) },
                        sleeper: { _ in }, wipeDefaults: makeIsolatedDefaults(prefix: "lotea"))
    }

    /// El runner le da al ejecutor la pregunta, y la pregunta contesta lo que la persona confirmó.
    @Test func runnerInstallsTheProbe_andItAnswersTheConfirmation() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let executor = AdoptOnlyExecutor()
        let runner = makeRunner(context, executor)
        let probe = try #require(executor.probe, "sin la pregunta instalada el intento en vuelo no puede parar")
        #expect(probe() == false)
        runner.requestMigrationCancel()
        #expect(probe() == true)
    }

    /// **El caso del barrido**: el «sí» llega con el intento ya dentro del efecto. Antes ese intento seguía hasta adoptar
    /// y la pantalla terminaba en «¡Tu cuenta está lista!». Ahora sale en el punto seguro y la pasada deja la huella que la
    /// bienvenida lee para volver al inicio (`WelcomeAdoptCancel.afterCancel == .back`).
    @Test func confirmationDuringTheAttempt_cancelsInsteadOfAdopting() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        try seedAdoptEffectPending(context)
        let executor = AdoptOnlyExecutor()
        let runner = makeRunner(context, executor)
        executor.onAdoptAttempt = { runner.requestMigrationCancel() }

        await runner.resume()

        let j = try journal(context)
        #expect(executor.adopted == 0, "el intento no adoptó")
        #expect(j.readPhase().phase == .notStarted)
        #expect(j.readPendingEffects().isEmpty)
        #expect(j.adoptClaimExitRaw == AdoptClaimExit.cancelled.rawValue)
        #expect(WelcomeAdoptCancel.afterCancel(
            journaledPhase: j.readPhase().phase,
            adoptEffectJournaled: j.readPendingEffects().contains(.adoptBackendAccount),
            adoptClaimExit: j.adoptClaimExitRaw.flatMap(AdoptClaimExit.init(rawValue:)),
            journalUnreadable: false) == .back)
    }

    /// Control: sin «sí», el mismo intento adopta. Es lo que hace discriminante al caso de arriba.
    @Test func withoutConfirmation_theAttemptAdopts() async throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        try seedAdoptEffectPending(context)
        let executor = AdoptOnlyExecutor()
        await makeRunner(context, executor).resume()
        let j = try journal(context)
        #expect(executor.adopted == 1)
        #expect(j.readPendingEffects().isEmpty)
        #expect(j.adoptClaimExitRaw == nil)
    }
}

// MARK: - El «sí» sobrevive a cerrar Yala (0f7h)

@Suite("Lote A · el «sí» de la bienvenida vive en disco (0f7h)")
struct WelcomeAdoptCancelRequestTests {

    private func armed() -> UserDefaults {
        let defaults = makeIsolatedDefaults(prefix: "lotea-inflight")
        WelcomeAdoptInFlight.arm(
            snapshot: .init(hasCompletedOnboarding: false, hasPrivateSession: false,
                            neutralMountArmed: true, freshInstallOwnsNeutralMount: true),
            provider: .google, defaults)
        return defaults
    }

    @Test func markedWithTheEntry_isReadUntilTheEntryGoes() {
        let defaults = armed()
        #expect(!WelcomeAdoptInFlight.isCancelRequested(defaults))
        WelcomeAdoptInFlight.markCancelRequested(defaults)
        #expect(WelcomeAdoptInFlight.isCancelRequested(defaults))
        WelcomeAdoptInFlight.clear(defaults)
        #expect(!WelcomeAdoptInFlight.isCancelRequested(defaults), "se va con la marca")
        #expect(defaults.object(forKey: WelcomeAdoptInFlight.cancelRequestedKey) == nil)
    }

    /// Sin una entrada en curso no hay nada que cancelar: el «sí» no se apunta suelto.
    @Test func withoutTheEntry_isNotMarked() {
        let defaults = makeIsolatedDefaults(prefix: "lotea-inflight-none")
        WelcomeAdoptInFlight.markCancelRequested(defaults)
        #expect(!WelcomeAdoptInFlight.isCancelRequested(defaults))
        #expect(defaults.object(forKey: WelcomeAdoptInFlight.cancelRequestedKey) == nil)
    }

    /// Un adopt nuevo con la misma marca («Reintentar») no hereda el «sí» del anterior.
    @Test func aNewAdopt_clearsIt() {
        let defaults = armed()
        WelcomeAdoptInFlight.markCancelRequested(defaults)
        WelcomeAdoptInFlight.clearCancelRequest(defaults)
        #expect(!WelcomeAdoptInFlight.isCancelRequested(defaults))
        #expect(WelcomeAdoptInFlight.isArmed(defaults), "la marca de la entrada sigue")
    }
}

// MARK: - Cableado (source-scan)

@Suite("Lote A · cableado de cancelar la activación")
struct AdoptCancelWiringTests {

    private static func source(_ relative: String) throws -> String {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: repo.appendingPathComponent(relative), encoding: .utf8)
    }

    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
            .joined(separator: " ")
    }

    /// Dos puntos seguros: antes del reconcile y después, antes de armar el modo nube (lo que ya no se deshace).
    @Test func adoptFlow_checksTheConfirmationAtItsSafePoints() throws {
        let src = Self.codeOnly(try Self.source("Yala/Services/CloudSync/MigrationWorkExecutor.swift"))
        let flowStart = try #require(src.range(of: "func runAdoptFlow() async throws {"))
        let flow = String(src[flowStart.upperBound...])
        let before = try #require(flow.range(of: "try stopIfAdoptCancelRequested(at: \"beforeReconcile\")"))
        let reconcile = try #require(flow.range(of: "switch await runAdoptOrphanReconcile() {"))
        let after = try #require(flow.range(of: "try stopIfAdoptCancelRequested(at: \"afterReconcile\")"))
        let armCloud = try #require(flow.range(of: "StorageModePersistence.writeCloudArmed(defaults: storageDefaults)"))
        #expect(before.lowerBound < reconcile.lowerBound)
        #expect(reconcile.lowerBound < after.lowerBound)
        #expect(after.lowerBound < armCloud.lowerBound)
        // Entre el último punto seguro y el modo nube no hay ningún `await`: el «sí» no puede llegar en medio.
        let gap = flow[after.upperBound..<armCloud.lowerBound]
        #expect(!gap.contains("await "), "un await entre el punto seguro y el modo nube reabre la ventana")
    }

    /// El arranque honra el «sí» que un cierre dejó sin aterrizar, antes de decidir si retoma.
    @Test func bootResume_honorsTheStoredConfirmationFirst() throws {
        let src = Self.codeOnly(try Self.source("Yala/Services/CloudSync/CloudMigrationController.swift"))
        let start = try #require(src.range(of: "func resumeIfNeeded(clearingError: Bool = true) async {"))
        let body = String(src[start.upperBound...])
        // Solo en las dos ramas que conducen una pasada que lo consume; con `.none` se quedaría en el runner y cancelaría el
        // siguiente intento (review adversarial).
        let honor = "if WelcomeAdoptInFlight.isCancelRequested() { runner.requestMigrationCancel() }"
        #expect(body.contains("case .resume: \(honor) await resume(clearingError: clearingError)"))
        #expect(body.contains("case .pollLeader: \(honor) await pollLeader(clearingError: clearingError)"))
        let decide = try #require(body.range(of: "switch MigrationBootDecision.decide("))
        let firstHonor = try #require(body.range(of: honor))
        #expect(decide.lowerBound < firstHonor.lowerBound, "no antes de decidir")
        let noneCase = try #require(body.range(of: "case .none:"))
        let afterNone = body[noneCase.upperBound...].prefix(80)
        #expect(!afterNone.contains("requestMigrationCancel"))
    }

    /// La pantalla que retoma tras reabrir termina de cancelar en vez de retomar, y el adopt nuevo olvida el «sí».
    @Test func welcomeScreen_resumesTheCancelAndForgetsItOnANewAdopt() throws {
        let src = Self.codeOnly(try Self.source("Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"))
        #expect(src.contains("if WelcomeAdoptInFlight.isCancelRequested() { cancelRequested = true launchFlow { await cancelAdopt() } return } launchFlow { await retryAdoptResume() }"))
        #expect(src.contains("cancelRequested = false WelcomeAdoptInFlight.clearCancelRequest() await driveWhilePolling {"))
        #expect(src.contains("if cancelRequested { Text(L10n.Welcome.Cloud.cancelling)"))
    }
}
