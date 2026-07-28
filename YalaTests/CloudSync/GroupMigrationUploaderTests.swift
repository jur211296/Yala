//
//  GroupMigrationUploaderTests.swift
//  YalaTests / CloudSync
//
//  G6-3 (C6): tests del `GroupMigrationUploader` (orden de pasos con mocks + resume por predicados), del seam
//  `GroupsSyncClient.enqueueSnapshotRows` (fila-completa, dedupe, cero eco), y del boot-reconciler del marcador.
//  Infra: container ON-DISK temp con los 3 stores (molde GroupsSyncClientTests).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupMigrationUploader · G6-3", .serialized)
@MainActor
struct GroupMigrationUploaderTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupMig-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GM-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GM-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GM-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Grupo candidato del uploader: isOwner + movedToBackendAt nil + ckSystemFieldsData != nil.
    @discardableResult
    private func makeCandidateGroup(zoneID: String = "SplitGroup-mig", context: ModelContext) -> SplitGroup {
        let g = SplitGroup(name: "Depa", currencyCode: "PEN", isOwner: true)
        g.cloudKitZoneID = zoneID
        g.ckSystemFieldsData = Data([0x01])   // != nil → candidato
        context.insert(g)
        let owner = SplitMember(groupZoneID: zoneID, displayName: "Jur",
                                cloudKitUserRecordID: "_owner_rec", role: "admin",
                                status: .active, isGroupOwner: true, isCurrentUser: true)
        context.insert(owner)
        try? context.save()
        return g
    }

    /// Mocks de las boundary ops del uploader, registrando el orden de invocación.
    @MainActor
    final class Mocks {
        var order: [String] = []
        var migrateResult: MigrateGroupResult = MigrateGroupResult(
            already: false, groupID: "SplitGroup-mig", ownerUserID: "uid", serverSeq: nil)
        var migrateCalls = 0
        var inviteCalls = 0
        var seedCalls = 0
        var pushOutcome: PushOutcome = .completed([])
        /// Secuencia de valores que devuelve `liveOutboxCount` (se consume de a uno; el último se repite).
        /// Default [1, 0]: la primera consulta ve trabajo pendiente → push corre UNA vez → drenado.
        var liveCounts: [Int] = [1, 0]
        var markerCalls = 0

        func nextLiveCount() -> Int {
            liveCounts.count > 1 ? liveCounts.removeFirst() : (liveCounts.first ?? 0)
        }
    }

    /// Señal «sin canal» ⇒ el gate C-4 devuelve `.proceed` en seco. Es la señal por defecto de TODOS los
    /// tests que no ejercitan el gate: sin ella caerían al default de producción, que lee
    /// `SplitSyncManager.shared` — y el host de los unit tests ES la app, con `AppBootstrapper` corriendo
    /// (`SplitSyncManager.shared.initialize()` ⇒ `privateEngine != nil`) y con `iCloudSyncServiceTests`
    /// dejando `_testForceAccountAvailable = true` fugado al proceso. Es decir: el escape «sin canal» NO
    /// se dispararía, la decisión sería `.wait` hasta el tope y estos tests pasarían a rojo quemando
    /// sleeps reales.
    nonisolated static let noChannelSignal = GroupFetchQuiescenceGate.signal(
        accountAvailable: false, privateEngineMounted: false, autoSyncActive: false,
        privateCyclesInFlight: 0, privateCompletedCycle: false,
        deferredRecordZoneEventCount: 0, deferredDatabaseEventCount: 0,
        deferredClearAllRequested: false, applyFailedThisSession: false,
        candidateZoneNames: [], zonesWithFailedFetch: [])

    private func makeUploader(
        context: ModelContext,
        mocks: Mocks,
        signal: (@MainActor (Set<String>) -> GroupFetchQuiescenceGate.Signal)? = nil,
        gatePoll: ((TimeInterval) async -> Bool)? = nil,
        capSeconds: TimeInterval = 4,
        pollSeconds: TimeInterval = 1
    ) -> GroupMigrationUploader {
        GroupMigrationUploader(
            context: context,
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            sessionCheck: { true },
            fetchGateSignal: signal ?? { _ in Self.noChannelSignal },
            // Sondeo INSTANTÁNEO: el paso del tiempo lo simula el contador del gate, no el reloj
            // (regla de tests: nada de `Task.sleep` largo).
            gatePoll: gatePoll ?? { _ in true },
            fetchGateCapSeconds: capSeconds,
            fetchGatePollSeconds: pollSeconds,
            migrate: { _, _, _ in mocks.order.append("migrate"); mocks.migrateCalls += 1; return mocks.migrateResult },
            createInvite: { _ in mocks.order.append("invite"); mocks.inviteCalls += 1; return "tok_\(mocks.inviteCalls)" },
            seedSnapshot: { _ in mocks.order.append("seed"); mocks.seedCalls += 1 },
            drain: { mocks.order.append("drain") },
            push: { mocks.order.append("push"); return mocks.pushOutcome },
            liveOutboxCount: { _ in mocks.nextLiveCount() },
            enqueueMarker: { _ in mocks.order.append("marker"); mocks.markerCalls += 1 })
    }

    private func withFlagAndConsent(_ body: () async -> Void) async {
        let prevFlag = CloudSyncFlags.groupsBackendEnabled
        let prevDefaults = GroupsConsentState.defaults
        let d = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        d.set(Int(Date().timeIntervalSince1970), forKey: PrefSyncKey.groupsConsentAcceptedAt.rawValue)
        CloudSyncFlags.groupsBackendEnabled = true
        GroupsConsentState.defaults = d
        defer {
            CloudSyncFlags.groupsBackendEnabled = prevFlag
            GroupsConsentState.defaults = prevDefaults
        }
        await body()
    }

    // MARK: - Orden de pasos

    @Test func run_stepOrder_migrateInviteFreezeSeedPushMarker() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeCandidateGroup(context: context)
        let mocks = Mocks()

        await withFlagAndConsent {
            await makeUploader(context: context, mocks: mocks).run()
        }

        // migrate → invite → seed → drain → push → marker (freeze es un save, no una boundary op).
        let iMigrate = try #require(mocks.order.firstIndex(of: "migrate"))
        let iInvite = try #require(mocks.order.firstIndex(of: "invite"))
        let iSeed = try #require(mocks.order.firstIndex(of: "seed"))
        let iPush = try #require(mocks.order.firstIndex(of: "push"))
        let iMarker = try #require(mocks.order.firstIndex(of: "marker"))
        #expect(iMigrate < iInvite)
        #expect(iInvite < iSeed)
        #expect(iSeed < iPush)
        #expect(iPush < iMarker)
        // Paso 3 (freeze) + paso 6 (marcador).
        #expect(group.isBackendGroup == true)
        #expect(group.movedToBackendAt != nil)
        #expect(group.backendReInviteToken == "tok_1")
        #expect(group.markerEnqueuedFlag == true)
        #expect(mocks.markerCalls == 1)
    }

    @Test func run_alreadyTrue_stillProceeds() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeCandidateGroup(context: context)
        let mocks = Mocks()
        mocks.migrateResult = MigrateGroupResult(already: true, groupID: "SplitGroup-mig",
                                                 ownerUserID: "uid", serverSeq: 42)

        await withFlagAndConsent { await makeUploader(context: context, mocks: mocks).run() }

        #expect(group.movedToBackendAt != nil)   // already:true no aborta la migración
        #expect(group.markerEnqueuedFlag == true)
    }

    @Test func run_resumeAfterPushFailure_reMintsToken_andStaysCandidate() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeCandidateGroup(context: context)
        let mocks = Mocks()
        mocks.liveCounts = [5]              // el push nunca drena → pushUntilGroupDrained falla
        mocks.pushOutcome = .transient

        await withFlagAndConsent { await makeUploader(context: context, mocks: mocks).run() }

        // Kill simulado ANTES del marcador: isBackendGroup flipeado (paso 3) pero movedToBackendAt nil.
        #expect(group.isBackendGroup == true)
        #expect(group.movedToBackendAt == nil)
        #expect(mocks.markerCalls == 0)
        // CRÍTICO 3: sigue siendo candidato (predicado por movedToBackendAt, NO !isBackendGroup).
        let candidates = try context.fetch(FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.isOwner == true && $0.movedToBackendAt == nil && $0.ckSystemFieldsData != nil }))
        #expect(candidates.count == 1)

        // Re-corrida: migrate se vuelve a llamar (already server-side) e invite MINTA UN TOKEN NUEVO.
        mocks.liveCounts = [1, 0]
        mocks.pushOutcome = .completed([])
        await withFlagAndConsent { await makeUploader(context: context, mocks: mocks).run() }
        #expect(mocks.inviteCalls == 2)          // token re-minteado
        #expect(group.backendReInviteToken == "tok_2")
        #expect(group.markerEnqueuedFlag == true)
    }

    @Test func run_flagOff_noOp() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeCandidateGroup(context: context)
        let mocks = Mocks()
        // Sin togglear el flag → run() retorna sin tocar nada.
        await makeUploader(context: context, mocks: mocks).run()
        #expect(mocks.migrateCalls == 0)
        #expect(group.movedToBackendAt == nil)
        #expect(group.isBackendGroup == false)
    }

    // MARK: - Boot-reconciler (C2)

    @Test func reconcileMarkers_reEnqueuesOnlyPendingMarkers() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        // A: marcador a medio armar (movedToBackendAt set, flag false) → re-encolar.
        let a = SplitGroup(name: "A"); a.cloudKitZoneID = "SplitGroup-A"; a.isOwner = true
        a.movedToBackendAt = .now; a.markerEnqueuedFlag = false
        // B: marcador ya armado → NO re-encolar.
        let b = SplitGroup(name: "B"); b.cloudKitZoneID = "SplitGroup-B"; b.isOwner = true
        b.movedToBackendAt = .now; b.markerEnqueuedFlag = true
        // C: no migrado → NO re-encolar.
        let c = SplitGroup(name: "C"); c.cloudKitZoneID = "SplitGroup-C"; c.isOwner = true
        context.insert(a); context.insert(b); context.insert(c)
        try context.save()

        GroupMigrationUploader.reconcileMarkers(context: context)

        #expect(a.markerEnqueuedFlag == true)   // A quedó armado
        #expect(b.markerEnqueuedFlag == true)   // B intacto
        #expect(c.markerEnqueuedFlag == false)  // C sin tocar
    }

    // MARK: - enqueueSnapshotRows (seam)

    @Test func enqueueSnapshotRows_fullRow_zeroEcho_dedupe() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient(tokenProvider: { nil }, urlSession: StubSession())

        // Grupo NON-backend + contenido (escenario migración: se inserta cuando el grupo aún no es backend).
        let zoneID = "SplitGroup-seed"
        let g = SplitGroup(name: "Depa", currencyCode: "PEN", isOwner: true)
        g.cloudKitZoneID = zoneID
        context.insert(g)
        let e = SplitExpense(groupZoneID: zoneID, amount: 30, currencyCode: "PEN",
                             expenseDescription: "Cena", paidByMemberID: "m1")
        context.insert(e)
        let s = SplitShare(expenseID: e.id, memberID: "m1", amount: 15, groupZoneID: zoneID)
        context.insert(s)
        let st = SplitSettlement(groupZoneID: zoneID, fromMemberID: "m2", toMemberID: "m1",
                                 amount: 15, currencyCode: "PEN")
        context.insert(st)
        try context.save()

        // Drain con el grupo NON-backend: no emite nada (muro por-grupo), pero avanza el cursor.
        client.drainOnce(context: context)
        #expect(try outbox(context).isEmpty)

        // Flip a backend + save; drain otra vez (isBackendGroup no es emitible → sin fila; cursor avanza).
        g.isBackendGroup = true
        try context.save()
        client.drainOnce(context: context)
        #expect(try outbox(context).isEmpty)

        // Seed del historial: meta + expense + share + settlement.
        try client.enqueueSnapshotRows(for: g, context: context)
        let rows = try outbox(context)
        #expect(rows.count == 4)
        #expect(rows.allSatisfy { $0.opRaw == "upsert" })

        // Fila-completa: la del expense trae TODAS las columnas de la emisión.
        let expenseRow = try #require(rows.first { $0.entityType == GroupSyncEntityType.splitExpense })
        for col in GroupEntityEmissionMap.splitExpense.columns {
            #expect(expenseRow.fieldsJSON.contains("\"\(col)\""), "falta la columna \(col) en el seed full-row")
        }

        // Cero eco: un drain posterior NO re-captura (el seed salvó bajo outboxSaveAuthor).
        client.drainOnce(context: context)
        #expect(try outbox(context).count == 4)

        // Dedupe (re-corrida): re-sembrar no duplica (match por syncID).
        try client.enqueueSnapshotRows(for: g, context: context)
        #expect(try outbox(context).count == 4)
    }

    // MARK: - Gate C-4 (fetch de grupos asentado)

    /// Señal con un ciclo de fetch EN VUELO: canal vivo, auto-sync activo, pero CloudKit está a mitad de
    /// entregar. Congelar aquí es exactamente el bug (el guard simétrico de pull descartaría lo que
    /// llegue después del flip).
    nonisolated static func inFlightSignal(zones: Set<String>) -> GroupFetchQuiescenceGate.Signal {
        GroupFetchQuiescenceGate.signal(
            accountAvailable: true, privateEngineMounted: true, autoSyncActive: true,
            privateCyclesInFlight: 1, privateCompletedCycle: false,
            deferredRecordZoneEventCount: 0, deferredDatabaseEventCount: 0,
            deferredClearAllRequested: false, applyFailedThisSession: false,
            candidateZoneNames: zones, zonesWithFailedFetch: [])
    }

    /// Señal ASENTADA con canal vivo (no el escape «sin canal»): el gate debe dejar pasar.
    nonisolated static func settledSignal(zones: Set<String>) -> GroupFetchQuiescenceGate.Signal {
        GroupFetchQuiescenceGate.signal(
            accountAvailable: true, privateEngineMounted: true, autoSyncActive: true,
            privateCyclesInFlight: 0, privateCompletedCycle: true,
            deferredRecordZoneEventCount: 0, deferredDatabaseEventCount: 0,
            deferredClearAllRequested: false, applyFailedThisSession: false,
            candidateZoneNames: zones, zonesWithFailedFetch: [])
    }

    /// EL test del ticket: «el uploader NO arranca con el fetch de grupos en vuelo». Corre el `run()`
    /// REAL contra un store REAL; lo único inyectado es la señal (y el sondeo, para no dormir).
    @Test func run_doesNotStart_whileGroupFetchInFlight() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeCandidateGroup(context: context)
        let mocks = Mocks()

        let uploader = makeUploader(
            context: context, mocks: mocks,
            signal: { zones in Self.inFlightSignal(zones: zones) })

        await withFlagAndConsent { await uploader.run() }

        // Ninguna boundary op corrió: la pasada ni siquiera llegó a `fetchCandidates()`.
        #expect(mocks.migrateCalls == 0)
        #expect(mocks.inviteCalls == 0)
        #expect(mocks.seedCalls == 0)
        #expect(mocks.order.isEmpty)
        // Y sobre todo: el grupo NO quedó congelado (el paso 3 es el punto de no retorno).
        #expect(group.isBackendGroup == false)
        #expect(group.movedToBackendAt == nil)
    }

    /// El diferimiento cierra el banner de progreso: si una pasada previa lo dejó abierto,
    /// `GroupsContainerView` mostraría «moviendo tus grupos…» para siempre.
    @Test func run_deferredByFetchGate_closesProgressBanner() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        makeCandidateGroup(context: context)
        let mocks = Mocks()
        GroupMigrationProgress.shared.begin(total: 3)   // pasada previa abortada
        defer { GroupMigrationProgress.shared.finish() }

        await withFlagAndConsent {
            await makeUploader(context: context, mocks: mocks,
                               signal: { zones in Self.inFlightSignal(zones: zones) }).run()
        }

        #expect(GroupMigrationProgress.shared.isMigrating == false)
        #expect(mocks.migrateCalls == 0)
    }

    /// Re-chequeo por grupo: el gate de pasada pasa (el conjunto de candidatos está asentado), pero
    /// cuando le toca al grupo B su zona ya no lo está. A migra; B espera su cap corto, no se asienta y
    /// se salta — intacto y candidato para el próximo boot.
    @Test func run_perGroupRecheck_skipsOnlyTheGroupWhoseZoneIsUnsettled() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let a = makeCandidateGroup(zoneID: "SplitGroup-A", context: context)
        let b = makeCandidateGroup(zoneID: "SplitGroup-B", context: context)
        let mocks = Mocks()
        mocks.migrateResult = MigrateGroupResult(already: false, groupID: "SplitGroup-A",
                                                 ownerUserID: "uid", serverSeq: nil)

        let uploader = makeUploader(
            context: context, mocks: mocks,
            signal: { zones in
                // El gate de PASADA recibe las dos zonas → asentado. El re-chequeo por grupo recibe una
                // sola: la de B está en vuelo.
                zones == ["SplitGroup-B"] ? Self.inFlightSignal(zones: zones) : Self.settledSignal(zones: zones)
            })

        await withFlagAndConsent { await uploader.run() }

        #expect(mocks.migrateCalls == 1)
        #expect(a.isBackendGroup == true)
        #expect(a.movedToBackendAt != nil)
        // B intacto: ni congelado ni migrado. Sigue siendo candidato para el próximo boot.
        #expect(b.isBackendGroup == false)
        #expect(b.movedToBackendAt == nil)
    }

    /// Sin cuenta iCloud (o sin engine) NADIE puede entregar nada y hoy estos devices migran
    /// perfectamente — es la cohorte de Modo Nube. El gate debe pasar EN SECO: el `gatePoll` hace fallar
    /// el test si llega a llamarse, así que un escape evaluado tarde (después de esperar) también muere.
    @Test func run_withoutICloudAccount_migratesAnyway_evenWithFetchNeverSettled() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeCandidateGroup(context: context)
        let mocks = Mocks()

        let neverSettledNoAccount = GroupFetchQuiescenceGate.signal(
            accountAvailable: false, privateEngineMounted: false, autoSyncActive: false,
            privateCyclesInFlight: 99, privateCompletedCycle: false,
            deferredRecordZoneEventCount: 5, deferredDatabaseEventCount: 5,
            deferredClearAllRequested: true, applyFailedThisSession: true,
            candidateZoneNames: ["SplitGroup-mig"], zonesWithFailedFetch: ["SplitGroup-mig"])

        let uploader = makeUploader(
            context: context, mocks: mocks,
            signal: { _ in neverSettledNoAccount },
            gatePoll: { _ in
                Issue.record("el gate esperó en un device sin canal: bloquearía la migración para siempre")
                return false
            })

        await withFlagAndConsent { await uploader.run() }

        #expect(mocks.migrateCalls == 1)
        #expect(group.isBackendGroup == true)
        #expect(group.movedToBackendAt != nil)
    }

    /// En la ventana export-only el engine EXISTE pero no puede fetchear — `engineMounted` a secas
    /// mentiría. Primera pasada → difiere sin efectos; segunda (ya promovido) → completa. Diferir nunca
    /// pierde trabajo: los pasos son idempotentes.
    @Test func run_exportOnlyThenSettled_defersFirstBootAndCompletesOnSecond() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeCandidateGroup(context: context)
        let mocks = Mocks()

        let exportOnly = GroupFetchQuiescenceGate.signal(
            accountAvailable: true, privateEngineMounted: true, autoSyncActive: false,
            privateCyclesInFlight: 0, privateCompletedCycle: true,   // ciclo cerrado: engineMounted mentiría
            deferredRecordZoneEventCount: 0, deferredDatabaseEventCount: 0,
            deferredClearAllRequested: false, applyFailedThisSession: false,
            candidateZoneNames: ["SplitGroup-mig"], zonesWithFailedFetch: [])

        await withFlagAndConsent {
            await makeUploader(context: context, mocks: mocks, signal: { _ in exportOnly }).run()
        }
        #expect(mocks.migrateCalls == 0)
        #expect(group.isBackendGroup == false)

        await withFlagAndConsent {
            await makeUploader(context: context, mocks: mocks,
                               signal: { zones in Self.settledSignal(zones: zones) }).run()
        }
        #expect(mocks.migrateCalls == 1)
        #expect(group.isBackendGroup == true)
        #expect(group.movedToBackendAt != nil)
        #expect(group.markerEnqueuedFlag == true)
    }

    private func outbox(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try context.fetch(FetchDescriptor<GroupSyncOutbox>())
    }

    final class StubSession: SyncHTTPSession, @unchecked Sendable {
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }
}
