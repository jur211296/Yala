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

    private func makeUploader(context: ModelContext, mocks: Mocks) -> GroupMigrationUploader {
        GroupMigrationUploader(
            context: context,
            now: { Date(timeIntervalSince1970: 1_800_000_000) },
            sessionCheck: { true },
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

    private func outbox(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try context.fetch(FetchDescriptor<GroupSyncOutbox>())
    }

    final class StubSession: SyncHTTPSession, @unchecked Sendable {
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }
}
