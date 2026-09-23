//
//  MigrationJournalUnreadableTests.swift
//  YalaTests
//
//  Ticket `an-unreadable-migration-journal-reads-as-never-started`. Hasta ese ticket, un `fetch` de `MigrationState` que
//  lanzaba se leía `notStarted` —fase ESTABLE, la de un dispositivo adoptado— en los dos lectores del journal
//  (`MigrationPhaseStore` y `CloudMigrationController`), y el del controller además ponía a cero los seis motivos que
//  explican una parada. Esta suite mide las dos mitades: que la lectura fallida tiene su propio valor, y que cada
//  consumidor hace con ella lo que no concede.
//
//  Cada caso va con su CONTROL positivo (la misma pregunta con la lectura buena), porque una aserción de «no concede» se
//  cumple sola si el sistema no concede nunca nada.
//
//  El controller no se puede instanciar en un test (`private init`, singleton con el `mainContext`), así que su lectura
//  se mide en la función pura que la hace (`MigrationJournalRead.read`) y su cableado con scans del cuerpo ENTERO de las
//  ramas que importan: un `contains` dejaría sitio a una sentencia antepuesta que borre el motivo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Lectura pura

@MainActor
@Suite("Journal ilegible · la lectura tiene su propio valor")
struct MigrationJournalUnreadableReadTests {

    private struct FetchFailed: Error {}

    @Test func phaseStore_fetchThatThrows_isUnreadable_notNotStarted() {
        #expect(MigrationPhaseStore.phaseRead { throw FetchFailed() } == .unreadable)
    }

    @Test func phaseStore_control_emptyJournalIsNotStarted_andARowIsItsPhase() {
        #expect(MigrationPhaseStore.phaseRead { nil } == .phase(.notStarted))
        let state = MigrationState()
        state.setPhase(.verifying)
        #expect(MigrationPhaseStore.phaseRead { state } == .phase(.verifying))
    }

    @Test func controller_fetchThatThrows_isUnreadable_andCarriesNoValues() {
        #expect(MigrationJournalRead.read { throw FetchFailed() } == .unreadable)
        #expect(MigrationJournalRead.unreadable.phaseRead == .unreadable)
    }

    /// Control: con una fila, los seis motivos salen de ella — también el freno de la vuelta (`.reverseRollback` pendiente).
    @Test func controller_control_aRowCarriesItsSixReasons() {
        let state = MigrationState()
        state.setPhase(.done)
        state.setPendingEffects([.reverseRollback])
        state.cutoverICloudVerdictRaw = ICloudChannelVerdict.noChannelNoFootprint.rawValue
        state.snapshotExitReasonRaw = SnapshotExitReason.localFailure.rawValue
        state.forwardStepExitReasonRaw = ForwardStepExitReason.otherDevice.rawValue
        state.forwardClaimIntentRaw = ForwardClaimIntent.migrateOnly.rawValue
        state.reverseAbortReasonRaw = ReverseAbortReason.icloudFull.rawValue
        state.adoptClaimExitRaw = AdoptClaimExit.cancelled.rawValue
        state.adoptClaimAccountHash = "cuenta-a"

        let read = MigrationJournalRead.read { state }
        #expect(read == .read(MigrationJournalSnapshot(
            phase: .done, pendingCount: 1, cutoverBlocker: .noChannelNoFootprint, snapshotExitReason: .localFailure,
            forwardStepExitReason: .otherDevice, claimIntent: .migrateOnly, reverseAbortReason: .icloudFull,
            hasPendingReverseExit: true, adoptClaimExit: .cancelled, adoptClaimAccountHash: "cuenta-a")))
        #expect(read.phaseRead == .phase(.done))
    }

    /// Sin fila no hay nada que explicar: el journal vacío es `.empty`, que sí es un «nunca empezó» honesto.
    @Test func controller_control_emptyJournalIsTheEmptySnapshot() {
        #expect(MigrationJournalRead.read { nil } == .read(.empty))
        #expect(MigrationJournalSnapshot.empty == MigrationJournalSnapshot(
            phase: .notStarted, pendingCount: 0, cutoverBlocker: nil, snapshotExitReason: nil, forwardStepExitReason: nil,
            claimIntent: .adoptIfExisting, reverseAbortReason: nil, hasPendingReverseExit: false))
    }
}

// MARK: - MigrationPhaseStore con el journal real

/// `configure(container:)` + el seam `_testJournalFetchThrows`, sobre un container on-disk con los tres stores. Toca
/// `identityCaptureEnabled`, global ⇒ `.serialized` + restaurar.
@MainActor
@Suite("Journal ilegible · MigrationPhaseStore", .serialized)
struct MigrationJournalUnreadablePhaseStoreTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MJU-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("no se pudo crear el directorio del test: \(error)")
        }
        return dir
    }

    private func cleanup(_ dir: URL) {
        do { try FileManager.default.removeItem(at: dir) } catch { print("MJU cleanup: \(error)") }
    }

    private func makeContainer(_ dir: URL) throws -> ModelContainer {
        let personalCfg = ModelConfiguration(
            "MJU-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "MJU-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "MJU-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        return try ModelContainer(for: SwiftDataConfiguration.schema,
                                  configurations: personalCfg, groupsCfg, syncMetaCfg)
    }

    private func seedJournal(_ container: ModelContainer, phase: MigrationPhase) throws {
        let context = ModelContext(container)
        let state = MigrationState()
        state.setPhase(phase)
        context.insert(state)
        try context.save()
    }

    private func makeStore() -> MigrationPhaseStore {
        MigrationPhaseStore(defaults: makeIsolatedDefaults(prefix: "mju.store"))
    }

    /// El caso del ticket: una fase TRANSITORIA journaleada, y un fetch que lanza. Antes salía `.notStarted` (estable).
    @Test func throwingFetch_isUnreadable_andTheControlReadsThePhase() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        try seedJournal(container, phase: .verifying)
        let store = makeStore()
        store.configure(container: container)

        store._testJournalFetchThrows = true
        #expect(store.currentPhaseRead == .unreadable)

        store._testJournalFetchThrows = false
        #expect(store.currentPhaseRead == .phase(.verifying))
    }

    /// La ventana de captura NO se decide con una lectura fallida: ni se enciende al arrancar, ni se pierde. La primera
    /// lectura buena hace la derivación aplazada.
    @Test func identityCapture_isDeferred_thenDerivedByTheFirstGoodRead() throws {
        let original = CloudSyncFlags.identityCaptureEnabled
        defer { CloudSyncFlags.identityCaptureEnabled = original }
        CloudSyncFlags.identityCaptureEnabled = false

        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        try seedJournal(container, phase: .uploadingSnapshot)   // dentro de la ventana
        let store = makeStore()

        store._testJournalFetchThrows = true
        store.configure(container: container)
        #expect(CloudSyncFlags.identityCaptureEnabled == false, "una lectura fallida no enciende la captura")
        #expect(store.identityCaptureDerivationPending)

        // Otra lectura fallida no la consume.
        #expect(store.currentPhaseRead == .unreadable)
        #expect(store.identityCaptureDerivationPending)
        #expect(CloudSyncFlags.identityCaptureEnabled == false)

        store._testJournalFetchThrows = false
        #expect(store.currentPhaseRead == .phase(.uploadingSnapshot))
        #expect(CloudSyncFlags.identityCaptureEnabled, "la primera lectura buena hace la derivación que faltó")
        #expect(store.identityCaptureDerivationPending == false)
    }

    /// Control: la derivación aplazada, fuera de la ventana, no enciende nada — y se consume igual.
    @Test func identityCapture_deferred_outsideTheWindow_staysOff() throws {
        let original = CloudSyncFlags.identityCaptureEnabled
        defer { CloudSyncFlags.identityCaptureEnabled = original }
        CloudSyncFlags.identityCaptureEnabled = false

        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        try seedJournal(container, phase: .done)
        let store = makeStore()

        store._testJournalFetchThrows = true
        store.configure(container: container)
        store._testJournalFetchThrows = false
        #expect(store.currentPhaseRead == .phase(.done))
        #expect(CloudSyncFlags.identityCaptureEnabled == false)
        #expect(store.identityCaptureDerivationPending == false)
    }

    /// Control: con la lectura buena al arrancar, `configure` deriva en el acto y no deja nada aplazado.
    @Test func identityCapture_goodReadAtConfigure_derivesAtOnce() throws {
        let original = CloudSyncFlags.identityCaptureEnabled
        defer { CloudSyncFlags.identityCaptureEnabled = original }
        CloudSyncFlags.identityCaptureEnabled = false

        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        try seedJournal(container, phase: .assigningIdentity)
        let store = makeStore()
        store.configure(container: container)
        #expect(CloudSyncFlags.identityCaptureEnabled)
        #expect(store.identityCaptureDerivationPending == false)
    }

    /// El primer plano consume la derivación aplazada: es la lectura buena que llega aunque en `.icloud` ningún otro
    /// consumidor lea la fase.
    @Test func foregroundRetry_derivesTheDeferredCapture() throws {
        let original = CloudSyncFlags.identityCaptureEnabled
        defer { CloudSyncFlags.identityCaptureEnabled = original }
        CloudSyncFlags.identityCaptureEnabled = false

        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        try seedJournal(container, phase: .verifying)
        let store = makeStore()
        store._testJournalFetchThrows = true
        store.configure(container: container)

        store.deriveDeferredIdentityCaptureIfNeeded()          // sigue ilegible: no enciende nada
        #expect(CloudSyncFlags.identityCaptureEnabled == false)
        #expect(store.identityCaptureDerivationPending)

        store._testJournalFetchThrows = false
        store.deriveDeferredIdentityCaptureIfNeeded()
        #expect(CloudSyncFlags.identityCaptureEnabled)
        #expect(store.identityCaptureDerivationPending == false)
    }

    /// El swap de persona suelta el container, y con él la derivación aplazada: la re-deriva el journal nuevo.
    @Test func releaseContainerForSwap_dropsTheDeferredDerivation() throws {
        let original = CloudSyncFlags.identityCaptureEnabled
        defer { CloudSyncFlags.identityCaptureEnabled = original }

        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        let store = makeStore()
        store._testJournalFetchThrows = true
        store.configure(container: container)
        #expect(store.identityCaptureDerivationPending)
        store.releaseContainerForSwap()
        #expect(store.identityCaptureDerivationPending == false)
    }
}

// MARK: - Los consumidores de la fase (lógica pura)

@MainActor
@Suite("Journal ilegible · cada consumidor decide hacia el lado que no concede")
struct MigrationJournalUnreadableConsumerTests {

    /// Los BGTasks reciben la disciplina TRANSITORIA: el lector suspende, el escritor exige quiescencia.
    @Test func bgTaskGate_unreadable_isTreatedAsTransitional() {
        #expect(BGTaskMigrationGate.decide(read: .unreadable, isImportQuiescent: true, role: .reader)
                == .suspendAndReschedule)
        #expect(BGTaskMigrationGate.decide(read: .unreadable, isImportQuiescent: false, role: .reader)
                == .suspendAndReschedule)
        #expect(BGTaskMigrationGate.decide(read: .unreadable, isImportQuiescent: false, role: .writer)
                == .deferAndReschedule)
        #expect(BGTaskMigrationGate.decide(read: .unreadable, isImportQuiescent: true, role: .writer) == .run)
    }

    /// Control: `.phase` delega en la clasificación de siempre, en las dos direcciones.
    @Test func bgTaskGate_control_phaseDelegates() {
        #expect(BGTaskMigrationGate.decide(read: .phase(.notStarted), isImportQuiescent: false, role: .reader) == .run)
        #expect(BGTaskMigrationGate.decide(read: .phase(.notStarted), isImportQuiescent: false, role: .writer) == .run)
        #expect(BGTaskMigrationGate.decide(read: .phase(.verifying), isImportQuiescent: false, role: .reader)
                == .suspendAndReschedule)
    }

    @Test func runtimeGate_unreadable_doesNotStartTheEngine() {
        #expect(!MigrationRuntimeGate.canRun(read: .unreadable, cloudWithMirrorOn: false, personalMountMismatch: false))
    }

    @Test func runtimeGate_control_stablePhaseStarts_andTheOtherTermsStillBlock() {
        #expect(MigrationRuntimeGate.canRun(read: .phase(.notStarted), cloudWithMirrorOn: false,
                                            personalMountMismatch: false))
        #expect(MigrationRuntimeGate.canRun(read: .phase(.done), cloudWithMirrorOn: false, personalMountMismatch: false))
        #expect(!MigrationRuntimeGate.canRun(read: .phase(.done), cloudWithMirrorOn: true, personalMountMismatch: false))
        #expect(!MigrationRuntimeGate.canRun(read: .phase(.done), cloudWithMirrorOn: false, personalMountMismatch: true))
    }

    @Test func prefsDrain_unreadable_doesNotDrain_andTheControlDoes() {
        #expect(!PrefsCutoverDrain.isLeaderPostRelaunchPhase(JournaledPhaseRead.unreadable))
        #expect(PrefsCutoverDrain.isLeaderPostRelaunchPhase(JournaledPhaseRead.phase(.done)))
        #expect(PrefsCutoverDrain.isLeaderPostRelaunchPhase(JournaledPhaseRead.phase(.cutover(.mirrorOff))))
        #expect(!PrefsCutoverDrain.isLeaderPostRelaunchPhase(JournaledPhaseRead.phase(.notStarted)))
    }

    /// La pantalla dice que no pudo leer, en los dos modos. Antes: `.idle` en iCloud y `.cloudActive` en la nube.
    @Test func uiState_unreadable_isJournalUnreadable_inBothModes() {
        for mode in [StorageMode.icloud, .cloud] {
            #expect(CloudMigrationUIStateDeriver.derive(
                storageMode: mode, read: .unreadable, mirrorOffArmed: false, mountedDecision: .iCloudMirror)
                    == .journalUnreadable, "\(mode)")
        }
    }

    /// Control: la misma derivación con la lectura buena es la de siempre.
    @Test func uiState_control_readPhaseDerivesAsBefore() {
        #expect(CloudMigrationUIStateDeriver.derive(
            storageMode: .icloud, read: .phase(.notStarted), mirrorOffArmed: false, mountedDecision: .iCloudMirror)
                == .idle)
        #expect(CloudMigrationUIStateDeriver.derive(
            storageMode: .cloud, read: .phase(.notStarted), mirrorOffArmed: false, mountedDecision: .cloudMirrorOff)
                == .cloudActive)
    }

    /// El relanzamiento de IDA no depende del journal y sigue ganando; el de vuelta sí depende, y no se afirma.
    @Test func uiState_unreadable_forwardRelaunchStillWins() {
        #expect(CloudMigrationUIStateDeriver.derive(
            storageMode: .cloud, read: .unreadable, mirrorOffArmed: true, mountedDecision: .iCloudMirror)
                == .needsRelaunch(.toCloud))
        // Armado pero ya sin espejo montado: nada que relanzar, así que la pantalla dice que no pudo leer.
        #expect(CloudMigrationUIStateDeriver.derive(
            storageMode: .cloud, read: .unreadable, mirrorOffArmed: true, mountedDecision: .cloudMirrorOff)
                == .journalUnreadable)
    }

    /// En el onboarding no pinta nada (`nil`): ni un adopt al 0 % —lo que parecía un `.idle`— ni un error con salida.
    /// El `claimBlocker` viene del runner, no del journal, y sigue ganando.
    @Test func welcomeAdopt_unreadable_keepsTheScreen_butTheClaimBlockerStillWins() {
        #expect(CloudWelcomeSignInFlow.phase(for: .journalUnreadable) == nil)
        #expect(CloudWelcomeSignInFlow.phase(for: .journalUnreadable, claimBlocker: .accountUnavailable) == .accountBlocked)
        #expect(CloudWelcomeSignInFlow.phase(for: .journalUnreadable, claimBlocker: .sessionExpired)
                == .error(retryable: true))
        #expect(CloudWelcomeSignInFlow.phase(for: .idle) == .adopting(fraction: 0), "control")
    }

    /// `isEngaged` con el journal ilegible es «no se sabe», y no cuenta como dentro: bajo el kill la fila no se abre a quien
    /// nunca empezó, y la re-medición del kill antes de migrar sigue cortando. El modo `.cloud` persistido sí cuenta.
    @Test func isEngaged_unreadableIsNotInside() {
        #expect(!StorageRowGateLogic.isEngaged(persistedMode: .icloud, uiState: .journalUnreadable))
        #expect(StorageRowGateLogic.isEngaged(persistedMode: .cloud, uiState: .journalUnreadable))
        // Control: la tabla de siempre.
        #expect(!StorageRowGateLogic.isEngaged(persistedMode: .icloud, uiState: .idle))
        for state: CloudMigrationUIState in [
            .migrating(MigrationUIStep(fraction: 0.22, phase: .claimingMigration)),
            .reverting(MigrationUIStep(fraction: 0.15, phase: .reverseClaimLeader)),
            .needsRelaunch(.toCloud), .needsRelaunch(.toICloud), .cloudActive, .waitingForLeader,
            .failed(.migration), .failed(.reverse),
        ] {
            #expect(StorageRowGateLogic.isEngaged(persistedMode: .icloud, uiState: state), "\(state)")
        }
    }

    /// La vuelta no se concede con un mapa que no se leyó; el born-cloud de este dispositivo no necesita el mapa.
    @Test func reverseEligibility_unreadableMap() {
        #expect(ReverseEligibility.decide(storageMode: .cloud, hasCKMap: nil, isBornCloud: false,
                                          journaledPhase: .done) == .mapUnreadable)
        #expect(ReverseEligibility.decide(storageMode: .cloud, hasCKMap: nil, isBornCloud: true,
                                          journaledPhase: .done) == .eligible)
        // Los guards de antes siguen delante.
        #expect(ReverseEligibility.decide(storageMode: .icloud, hasCKMap: nil, isBornCloud: false,
                                          journaledPhase: .done) == .notCloudMode)
        #expect(ReverseEligibility.decide(storageMode: .cloud, hasCKMap: nil, isBornCloud: false,
                                          journaledPhase: .icloudActive) == .reverseAlreadyTerminal)
        // Control: un mapa LEÍDO decide como siempre.
        #expect(ReverseEligibility.decide(storageMode: .cloud, hasCKMap: false, isBornCloud: false,
                                          journaledPhase: .done) == .degradedNoMap)
        #expect(ReverseEligibility.decide(storageMode: .cloud, hasCKMap: true, isBornCloud: false,
                                          journaledPhase: .done) == .eligible)
    }
}

// MARK: - Cableado (source-scan)

@Suite("Journal ilegible · cableado del controller y de los consumidores (source-scan)")
struct MigrationJournalUnreadableWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    private static let controllerPath = "Yala/Services/CloudSync/CloudMigrationController.swift"

    /// Cuerpo de lo que abre `marker` (su `{` incluida en el marcador) hasta la llave que lo cierra.
    private static func body(of marker: String, in path: String) throws -> String {
        let text = try source(path)
        let start = try #require(text.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(text[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
    }

    /// Líneas de código, sin comentarios (completos o al final) ni vacías. Ninguno de los cuerpos escaneados tiene `//`
    /// dentro de un literal.
    private static func lines(_ body: String) -> [String] {
        body.split(separator: "\n")
            .map { line -> String in
                var code = String(line)
                if let comment = code.range(of: "//") { code = String(code[..<comment.lowerBound]) }
                return code.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }

    private static func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// El único lector del journal del controller aplica los seis motivos con una lectura buena, y con una ilegible solo
    /// marca el testigo. Es el CUERPO ENTERO del `switch`: una línea antepuesta en la rama ilegible que borre un motivo
    /// es justo el bug del ticket.
    ///
    /// Y es el cuerpo ENTERO de la función, closure incluido (review, lente de mutantes): una sentencia antes del `switch`
    /// que borre un motivo, o un `do { … } catch { return nil }` dentro del closure —que el seam, al lanzar ANTES del
    /// fetch, dejaría verde—, reintroducen el bug con cualquier scan parcial.
    @Test func readJournal_theUnreadableBranchWritesNoReason() throws {
        let body = Self.lines(try Self.body(of: "private func readJournal() -> MigrationJournalRead {",
                                            in: Self.controllerPath))
        #expect(body == [
            "let context = self.context",
            "let read = MigrationJournalRead.read {",
            "#if DEBUG",
            "if UITestHooks.migrationJournalUnreadable { throw MigrationJournalSeamError.fetchFailed }",
            "#endif",
            "var descriptor = FetchDescriptor<MigrationState>()",
            "descriptor.fetchLimit = 1",
            "return try context.fetch(descriptor).first",
            "}",
            "switch read {",
            "case .read(let snapshot):",
            "isJournalUnreadable = false",
            "cutoverBlocker = snapshot.cutoverBlocker",
            "snapshotExitReason = snapshot.snapshotExitReason",
            "forwardStepExitReason = snapshot.forwardStepExitReason",
            "journaledClaimIntent = snapshot.claimIntent",
            "adoptClaimExit = snapshot.adoptClaimExit",
            "adoptClaimAccountHash = snapshot.adoptClaimAccountHash",
            "reverseAbortReason = snapshot.reverseAbortReason",
            "hasPendingReverseExit = snapshot.hasPendingReverseExit",
            "case .unreadable:",
            "if !isJournalUnreadable { CloudSyncBreadcrumb.migrationJournalUnreadable(reader: \"controller\") }",
            "isJournalUnreadable = true",
            "}",
            "return read",
        ])
    }

    /// Un solo lector: si vuelve a haber un segundo `fetch` del journal en el controller, puede volver a tener su propio
    /// `catch`. Y ningún `try?` de los que el ticket retiró.
    @Test func controller_hasOneJournalReader_andNoSilencedFetches() throws {
        let src = try Self.source(Self.controllerPath)
        #expect(Self.occurrences(of: "FetchDescriptor<MigrationState>()", in: src) == 1)
        let reader = try Self.body(of: "private func readJournal() -> MigrationJournalRead {", in: Self.controllerPath)
        #expect(reader.contains("FetchDescriptor<MigrationState>()"))
        let code = Self.lines(src).joined(separator: "\n")
        #expect(Self.occurrences(of: "try?", in: code) == 1, "solo queda el del attest del executor")
        #expect(code.contains("let attest: () async -> String? = { try? await session.attestToken() }"))
    }

    /// El lector de `MigrationPhaseStore`, entero: su seam lanza ANTES del fetch real, así que un `catch` que devolviera
    /// `nil` dentro del closure pasaría los tests de comportamiento (lente de mutantes de la review).
    @Test func phaseStore_readerIsTheRealFetch() throws {
        let body = Self.lines(try Self.body(
            of: "private func journaledPhaseRead(container: ModelContainer) -> JournaledPhaseRead {",
            in: "Yala/Services/CloudSync/MigrationPhaseStore.swift"))
        #expect(body == [
            "let context = ModelContext(container)",
            "return Self.phaseRead {",
            "if _testJournalFetchThrows { throw MigrationJournalSeamError.fetchFailed }",
            "var descriptor = FetchDescriptor<MigrationState>()",
            "descriptor.fetchLimit = 1",
            "return try context.fetch(descriptor).first",
            "}",
        ])
        let getter = Self.lines(try Self.body(of: "var currentPhaseRead: JournaledPhaseRead {",
                                              in: "Yala/Services/CloudSync/MigrationPhaseStore.swift"))
        #expect(getter == [
            "#if DEBUG",
            "if let simulated = simulatedPhase?.migrationPhase { return .phase(simulated) }",
            "#endif",
            "guard let container else { return .phase(.notStarted) }",
            "let read = journaledPhaseRead(container: container)",
            "if identityCaptureDerivationPending { deriveIdentityCapture(from: read) }",
            "return read",
        ])
    }

    /// Las tres decisiones del arranque y el primer plano no deciden nada sin journal.
    @Test func decisions_doNothingWithoutAJournal() throws {
        let resume = Self.lines(try Self.body(of: "func resumeIfNeeded(clearingError: Bool = true) async {",
                                              in: Self.controllerPath))
        #expect(Array(resume.prefix(5)) == [
            "guard let inputs = readJournalDecisionInputs() else {",
            "refresh()",
            "return",
            "}",
            "let (phase, hasPending) = inputs",
        ])

        let start = Self.lines(try Self.body(of: "private func startRuntimeIfStable() {", in: Self.controllerPath))
        #expect(start.first == "guard let inputs = readJournalDecisionInputs() else { return }")

        let decisionInputs = Self.lines(try Self.body(
            of: "private func readJournalDecisionInputs() -> (phase: MigrationPhase, hasPending: Bool)? {",
            in: Self.controllerPath))
        #expect(decisionInputs == [
            "guard case .read(let snapshot) = readJournal() else { return nil }",
            "return (snapshot.phase, snapshot.pendingCount > 0)",
        ])
    }

    /// El re-kick de primer plano no re-kickea sin journal; quita un `.journalUnreadable` viejo cuando vuelve a leer, y
    /// arranca el motor si se quedó `.idle` con la fase estable (sin esto, un arranque ilegible dejaba un teléfono en la
    /// nube sin sincronizar hasta relanzar: lo cazaron dos lentes de la review).
    @Test func rekick_refreshesAStaleScreen_andStartsAnIdleEngine() throws {
        let rekick = Self.lines(try Self.body(of: "func rekickIfParked() async {", in: Self.controllerPath))
        #expect(Array(rekick.prefix(14)) == [
            "guard !StorageModePersistence.isSignOutWipeArmed() else { return }",
            "let wasUnreadable = uiState == .journalUnreadable",
            "guard let inputs = readJournalDecisionInputs() else {",
            "refresh()",
            "return",
            "}",
            "let (phase, hasPending) = inputs",
            "if wasUnreadable { refresh() }",
            "guard MigrationForegroundRekick.shouldRekick(",
            "phase: phase, hasPendingEffects: hasPending, isWorking: isWorking) else {",
            "if CloudSyncRuntime.shared?.state == .idle { startRuntimeIfStable() }",
            "return",
            "}",
            "CloudSyncBreadcrumb.migrationForegroundRekick(phase: \"\\(phase)\")",
        ])
    }

    /// Las dos entradas que mueven datos vuelven a leer antes de empezar: sus confirmaciones cuelgan de la raíz de la
    /// pantalla y sobreviven a un `.journalUnreadable`.
    @Test func dataMovingEntries_readTheJournalFirst() throws {
        for marker in ["func startMigration(consentPath: ConsentPath, signIn plan: SignInPlan) async {",
                       "func startReverse() async {"] {
            let code = Self.lines(try Self.body(of: marker, in: Self.controllerPath))
            #expect(Array(code.prefix(8)) == [
                "isWorking = true",
                "defer { isWorking = false }",
                "lastError = nil",
                "guard readJournalDecisionInputs() != nil else {",
                "lastError = L10n.Storage.journalUnreadableMessage",
                "refresh()",
                "return",
                "}",
            ], "\(marker)")
        }
    }

    /// `refresh()` deriva de la LECTURA, y no pisa la última fase leída con una lectura fallida.
    @Test func refresh_derivesFromTheRead() throws {
        let refresh = Self.lines(try Self.body(of: "func refresh() {", in: Self.controllerPath))
        #expect(refresh == [
            "isQuiescent = iCloudSyncService.shared.isImportQuiescent",
            "let read = readJournal()",
            "if case .read(let snapshot) = read {",
            "journaledPhase = snapshot.phase",
            "pendingEffectCount = snapshot.pendingCount",
            "}",
            "let mountedDecision = SwiftDataConfiguration.personalStoreMountedDecision",
            "let mirrorOffArmed = StorageModePersistence.isMirrorOffArmed()",
            "uiState = CloudMigrationUIStateDeriver.derive(",
            "storageMode: StorageModePersistence.read(),",
            "read: read.phaseRead,",
            "mirrorOffArmed: mirrorOffArmed,",
            "mountedDecision: mountedDecision)",
            "claimBlocker = _runner?.lastClaimBlocker",
            "claimDefinitiveCause = _runner?.lastClaimDefinitiveCause",
            "reverseUploadSample = _runner?.lastReverseUploadSample",
            "reverseSessionExpiry = _runner?.lastReverseSessionExpiry",
            "refreshSyncBanner()",
        ])
    }

    /// Con `journaledPhase` congelado en la última fase leída, los botones de cancelar se apagan: si no, el `.onChange` de
    /// la pantalla no bajaría un diálogo abierto y reaparecería al volver a leer.
    @Test func cancelGetters_areOffWhileUnreadable() throws {
        let migration = Self.lines(try Self.body(of: "var canCancelMigration: Bool {", in: Self.controllerPath))
        #expect(migration == [
            "!isJournalUnreadable && ForwardCancelScope.offersCancel(journaledPhase)"])
        let reverse = Self.lines(try Self.body(of: "var canCancelReverse: Bool {", in: Self.controllerPath))
        #expect(reverse == ["!isJournalUnreadable && (journaledPhase == .reverseUpload || isBeforeReverseMount)"])
    }

    /// Los `try?` de la pantalla, uno a uno: el `catch` entero de cada uno.
    @Test func screenReads_failTowardTheSafeSide() throws {
        let banner = Self.lines(try Self.body(of: "private func refreshSyncBanner() {", in: Self.controllerPath))
        let bannerCatch = try #require(banner.firstIndex(of: "} catch {"))
        #expect(Array(banner[bannerCatch...]) == [
            "} catch {",
            "#if DEBUG",
            "print(\"CloudMigrationController.refreshSyncBanner: fetch(SyncOutbox) falló: \\(error)\")",
            "#endif",
            "syncNeedsSignIn = true",
            "pendingUploadCount = nil",
            "}",
        ])

        let dryRun = Self.lines(try Self.body(of: "func dryRunCounts() -> MigrationDryRunPreview {",
                                              in: Self.controllerPath))
        let dryCatch = try #require(dryRun.firstIndex(of: "} catch {"))
        #expect(Array(dryRun[dryCatch...]) == [
            "} catch {", "#if DEBUG",
            "print(\"CloudMigrationController.dryRunCounts: fetchCount falló: \\(error)\")",
            "#endif", "return .unreadable", "}",
        ])

        let reverse = Self.lines(try Self.body(of: "func reverseEligibility() -> ReverseEligibility.Decision {",
                                               in: Self.controllerPath))
        #expect(reverse.contains("hasCKMap = nil"))
        #expect(reverse.contains("hasCKMap: hasCKMap,"))

        let marker = Self.lines(try Self.body(of: "func markerDecision() -> MarkerDecision {", in: Self.controllerPath))
        let markerCatch = try #require(marker.firstIndex(of: "} catch {"))
        #expect(Array(marker[markerCatch...].prefix(5)) == [
            "} catch {", "#if DEBUG",
            "print(\"CloudMigrationController.markerDecision: fetchCount(CloudMigrationMarker) falló: \\(error)\")",
            "#endif", "markerFound = false",
        ])
    }

    /// Los siete consumidores de `MigrationPhaseStore` pasan la LECTURA a la variante que decide por ella. El tipo ya
    /// obliga a pronunciarse; esto fija QUÉ variante, para que nadie abra un `if case .phase` que falle abierto.
    @Test func phaseStoreConsumers_passTheRead() throws {
        let bg = try Self.source("Yala/App/BackgroundTaskManager.swift")
        #expect(Self.occurrences(of: "read: MigrationPhaseStore.shared.currentPhaseRead,", in: bg) == 4)

        // `canRunDomain`, entero: un `if case .unreadable = read { return true }` antes del `return` pasaría un `contains`.
        let runtime = Self.lines(try Self.body(of: "static func canRunDomain() -> Bool {",
                                               in: "Yala/Services/CloudSync/CloudSyncRuntime.swift"))
        #expect(runtime == [
            "guard CloudSyncFlags.storageMode == .cloud else { return false }",
            "let read = MigrationPhaseStore.shared.currentPhaseRead",
            "let phaseLabel: String",
            "switch read {",
            "case .phase(let phase): phaseLabel = \"\\(phase)\"",
            "case .unreadable: phaseLabel = \"unreadable\"",
            "}",
            "let cloudWithMirrorOn = StorageModePersistence.isCloudWithMirrorOn()",
            "if cloudWithMirrorOn, case .phase(let phase) = read, MigrationRuntimeGate.isDomainStablePhase(phase) {",
            "CloudSyncBreadcrumb.storageModePairViolation(phase: phaseLabel)",
            "if !pairViolationCanaryFired {",
            "pairViolationCanaryFired = true",
            "MetricsService.cloudStorageModePairViolation()",
            "}",
            "}",
            "let personalMountMismatch = MigrationRuntimeGate.isPersonalMountMismatch(",
            "persistedMode: CloudSyncFlags.storageMode,",
            "mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision)",
            "if personalMountMismatch {",
            "CloudSyncBreadcrumb.runtimeBlockedByPersonalMountMismatch(phase: phaseLabel)",
            "}",
            "return MigrationRuntimeGate.canRun(read: read,",
            "cloudWithMirrorOn: cloudWithMirrorOn,",
            "personalMountMismatch: personalMountMismatch)",
        ])

        let engine = Self.lines(try Self.body(of: "var isIdentityRemapBlockedByMigration: Bool {",
                                              in: "Yala/Services/CloudSync/CloudSyncEngine.swift"))
        #expect(engine == [
            "let read = _testMigrationPhaseOverride.map(JournaledPhaseRead.phase) ?? MigrationPhaseStore.shared.currentPhaseRead",
            "return BGTaskMigrationGate.decide(read: read, isImportQuiescent: false, role: .reader) != .run",
        ])

        let prefs = try Self.source("Yala/App/Services/PreferenceSyncService.swift")
        #expect(prefs.contains(
            "guard PrefsCutoverDrain.isLeaderPostRelaunchPhase(MigrationPhaseStore.shared.currentPhaseRead) else { return }"))
    }

    /// El INVENTARIO: siete consumidores de `currentPhaseRead` fuera del store, y la variante `decide(phase:)` del gate de
    /// BGTasks solo la usan él mismo y el panel DEBUG del spike S7. Un octavo consumidor con su propio `if case .phase`
    /// —que concediera en el `else`— no lo vería ningún otro scan.
    @Test func phaseStoreConsumers_inventory() throws {
        let yala = Self.repoRoot.appendingPathComponent("Yala")
        let files = try #require(FileManager.default.enumerator(at: yala, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        var readUses: [String: Int] = [:]
        var phaseDecideUses: [String: Int] = [:]
        for url in files {
            let code = Self.lines(try String(contentsOf: url, encoding: .utf8)).joined(separator: "\n")
            let name = url.lastPathComponent
            let reads = Self.occurrences(of: "currentPhaseRead", in: code)
            if reads > 0, name != "MigrationPhaseStore.swift" { readUses[name] = reads }
            let decides = Self.occurrences(of: "BGTaskMigrationGate.decide(phase:", in: code)
                + Self.occurrences(of: "return decide(phase:", in: code)
            if decides > 0 { phaseDecideUses[name] = decides }
        }
        #expect(readUses == ["BackgroundTaskManager.swift": 4, "CloudSyncRuntime.swift": 1, "CloudSyncEngine.swift": 1,
                             "PreferenceSyncService.swift": 1])
        #expect(phaseDecideUses == ["BGTaskMigrationGate.swift": 1, "CloudSyncDebugView.swift": 1])
    }

    /// Cada primer plano reintenta la derivación aplazada de la captura de identidad.
    @Test func foreground_retriesTheDeferredIdentityCapture() throws {
        let active = try Self.body(of: "func handleBecameActive(context: ModelContext) {",
                                   in: "Yala/App/AppBootstrapper.swift")
        let code = Self.lines(active)
        let call = try #require(code.firstIndex(of: "MigrationPhaseStore.shared.deriveDeferredIdentityCaptureIfNeeded()"))
        let wipeGuard = try #require(code.firstIndex(of: "guard !StorageModePersistence.isSignOutWipeArmed() else { return }"))
        #expect(wipeGuard < call)
        let helper = Self.lines(try Self.body(of: "func deriveDeferredIdentityCaptureIfNeeded() {",
                                              in: "Yala/Services/CloudSync/MigrationPhaseStore.swift"))
        #expect(helper == ["guard identityCaptureDerivationPending else { return }", "_ = currentPhaseRead"])
    }

    /// Las dos ramas nuevas de la pantalla que no inventan cifras.
    @Test func storageScreen_doesNotInventCounts() throws {
        let view = "Yala/App/Views/Settings/StorageSettingsView.swift"
        let migrate = Self.lines(try Self.body(of: "private func migrateCard(_ controller: CloudMigrationController) -> some View {",
                                               in: view))
        let dry = try #require(migrate.firstIndex(of: "switch dryRun {"))
        #expect(Array(migrate[dry..<(dry + 13)]) == [
            "switch dryRun {",
            "case let .counts(transactions, categories, accounts, budgets):",
            "Text(L10n.Storage.Migrate.previewResult(transactions, categories, accounts, budgets))",
            ".font(DS.Typography.caption.monospaced())",
            ".foregroundStyle(.tertiary)",
            "case .unreadable:",
            "Text(L10n.Storage.Migrate.previewUnreadable)",
            ".font(DS.Typography.caption)",
            ".foregroundStyle(.secondary)",
            ".accessibilityIdentifier(\"storage_preview_unreadable\")",
            "case nil:",
            "EmptyView()",
            "}",
        ])
        let sync = Self.lines(try Self.body(of: "private func syncStatusSection(_ controller: CloudMigrationController) -> some View {",
                                            in: view))
        let label = try #require(sync.firstIndex(of: "} else if controller.syncNeedsSignIn {"))
        #expect(Array(sync[label..<(label + 8)]) == [
            "} else if controller.syncNeedsSignIn {",
            "Label {",
            "if let pending = controller.pendingUploadCount {",
            "Text(L10n.Storage.Sync.needsSignIn(pending))",
            "} else {",
            "Text(L10n.Storage.Sync.needsSignInUncounted)",
            "}",
            "} icon: {",
        ])
    }

    /// El poll del adopt del Welcome no pinta nada con `nil` (el journal no se dejó leer en ese tick), y el reintento
    /// manual solo re-arranca el adopt desde `.idle`.
    @Test func welcomeAdopt_pollKeepsTheScreenOnAnUnreadableTick() throws {
        let view = "Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift"
        let poll = Self.lines(try Self.body(of: "private func pollAdoptProgress() async {", in: view))
        let start = try #require(poll.firstIndex(of: "guard let next = CloudWelcomeSignInFlow.phase("))
        #expect(Array(poll[start..<(start + 11)]) == [
            "guard let next = CloudWelcomeSignInFlow.phase(",
            "for: controller.uiState,",
            "claimBlocker: controller.claimBlocker) else {",
            "await evaluateAutoResume(controller: controller, screenPhase: phase)",
            "do {",
            "try await Task.sleep(for: .seconds(1))",
            "} catch {",
            "return",
            "}",
            "continue",
            "}",
        ])
        #expect(poll[start + 11] == "phase = next")
        let retry = Self.lines(try Self.body(of: "private func retryAdoptResume() async {", in: view))
        #expect(retry.contains("if case .idle = controller.uiState {"))
    }

    /// La pantalla con el journal ilegible pinta la tarjeta honesta y la sección de Grupos, y NADA que mueva los datos.
    @Test func storageScreen_unreadableCase_offersNothingThatMovesData() throws {
        let content = try Self.body(of: "private func content(_ controller: CloudMigrationController) -> some View {",
                                    in: "Yala/App/Views/Settings/StorageSettingsView.swift")
        let code = Self.lines(content)
        let start = try #require(code.firstIndex(of: "case .journalUnreadable:"))
        #expect(Array(code[start...]) == [
            "case .journalUnreadable:",
            "journalUnreadableCard()",
            "GroupsAssociationSection(onAssociate: onAssociateGroupsAccount)",
            "}",
        ])
    }

    /// El arg del seam de XCUITest casa en los dos lados: un typo lo dejaría fuera y el caso positivo caería culpando a la
    /// pantalla.
    @Test func uitestSeam_argNameMatchesTheLauncher() throws {
        let arg = "\"-uitest-migration-journal-unreadable\""
        #expect(try Self.source("Yala/App/UITestHooks.swift").contains(arg))
        #expect(try Self.source("YalaUITests/Support/XCUIApplication+Yala.swift").contains(arg))
    }
}
