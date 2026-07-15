//
//  GroupsSyncClientTests.swift
//  YalaTests / CloudSync
//
//  Canal de sync de GRUPOS → backend (incremento G2, DARK). Espeja la infra de `CloudSyncEngineTests`:
//  container ON-DISK temp con los 3 stores (personal `.none` + grupos `.none` + sync-meta `.none`), un
//  solo `ModelContext` que los abarca (el History es por-CONTAINER). `.serialized` + containers propios
//  por test.
//
//  Cubre la sección D del brief G2: (1) partición del muro, (2) drain de Grupos aislado del personal,
//  (3) echo-suppression, (4) cursores + URL del pull, (5) flag no-op, (6) emisión canon c1.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupsSyncClient · drain / push / pull (DARK)", .serialized)
@MainActor
struct GroupsSyncClientTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsSync-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "GS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "GS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    private func groupOutbox(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try context.fetch(FetchDescriptor<GroupSyncOutbox>())
    }

    private func makeExpense(
        group: String = "SplitGroup-A", amount: Double = 12.5, currency: String = "USD",
        desc: String = "Dinner", context: ModelContext
    ) -> SplitExpense {
        let e = SplitExpense(groupZoneID: group, amount: amount, currencyCode: currency,
                             expenseDescription: desc, paidByMemberID: "member-1")
        context.insert(e)
        return e
    }

    // MARK: - Stub HTTP session (sin red)

    final class StubHTTPSession: SyncHTTPSession, @unchecked Sendable {
        var lastRequest: URLRequest?
        var callCount = 0
        let responseData: Data
        let statusCode: Int

        init(responseData: Data = Data("{\"deltas\":[],\"cursors\":{},\"memberships\":[]}".utf8),
             statusCode: Int = 200) {
            self.responseData = responseData
            self.statusCode = statusCode
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            callCount += 1
            lastRequest = request
            let response = HTTPURLResponse(
                url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }
    }

    // MARK: - Test 1 · Partición del muro

    @Test func partition_groupEntityNames_matchGroupsSchema_disjointFromPersonal() {
        let groupsSchemaNames = Set(SwiftDataConfiguration.groupsSchema.entities.map(\.name))

        // groupEntityNames == los nombres del groupsSchema (las 5 entidades Split*).
        #expect(GroupsSyncClient.groupEntityNames == groupsSchemaNames)
        #expect(GroupsSyncClient.groupEntityNames.count == 5)

        // Disjunto del muro personal (cada entidad de dominio en EXACTAMENTE un canal).
        #expect(GroupsSyncClient.groupEntityNames.isDisjoint(with: CloudSyncEngine.personalEntityNames))

        // El subconjunto EMISIBLE excluye SplitMember (pull-only) y está contenido en el muro.
        #expect(GroupEntityEmissionMap.emittableGroupEntityNames.isSubset(of: GroupsSyncClient.groupEntityNames))
        #expect(!GroupEntityEmissionMap.emittableGroupEntityNames.contains(GroupSyncEntityType.splitMember))
        #expect(GroupEntityEmissionMap.emittableGroupEntityNames.count == 4)
    }

    // MARK: - Test 2 · Drain de Grupos aislado del personal (los dos muros a la vez)

    @Test func drain_capturesOnlyGroupEntities_personalCapturesOnlyPersonal() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeExpense(context: context)
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: 3, currencyCode: "USD")
        context.insert(tx)
        try context.save()

        // Muro de Grupos: solo el SplitExpense.
        GroupsSyncClient().drainOnce(context: context)
        let gRows = try groupOutbox(context)
        #expect(gRows.count == 1)
        #expect(gRows.first?.entityType == GroupSyncEntityType.splitExpense)
        #expect(!gRows.contains { $0.entityType == "TransactionItem" })

        // Muro personal: solo el TransactionItem (nunca un Split*).
        CloudSyncEngine().drainOnce(context: context)
        let pRows = try context.fetch(FetchDescriptor<SyncOutbox>())
        #expect(pRows.count == 1)
        #expect(pRows.first?.entityType == SyncEntityType.transactionItem)
        #expect(!pRows.contains { GroupsSyncClient.groupEntityNames.contains($0.entityType) })
    }

    // MARK: - Test 3 · Echo-suppression (saves con el autor del canal no re-drenan)

    @Test func drain_ignoresOwnAuthorSaves() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let expense = makeExpense(context: context)
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)
        #expect(try groupOutbox(context).count == 1)

        // Simular un apply remoto: mutar bajo el autor del canal → NO debe re-capturarse.
        let previous = context.author
        context.author = GroupsSyncClient.outboxSaveAuthor
        expense.amount = 99
        try context.save()
        context.author = previous

        client.drainOnce(context: context)
        #expect(try groupOutbox(context).count == 1)  // el cambio bajo el autor propio se suprimió
    }

    // MARK: - Test 4 · Cursores por grupo + URL del pull (assert del request generado, lección d49d2e47)

    @Test func apply_advancesGroupCursors_perGroup() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)

        let shareID = UUID()
        let delta = GroupPulledDelta(
            entityType: "split_shares", groupID: "SplitGroup-A",
            rawSyncID: shareID.uuidString, syncID: shareID, op: .upsert,
            fields: [
                "expense_id": .string(UUID().uuidString),
                "member_key": .string("member-1"),
                "amount": .string("10.0000"),
                "is_paid": .bool(false),
            ],
            fieldHlcs: [:], hlc: "2026-07-15T00:00:00.000Z-0000-00000000000000aa",
            serverSeq: 7, schemaVersion: 1
        )
        let page = GroupPulledPage(deltas: [delta], cursors: ["SplitGroup-A": 7], memberships: ["SplitGroup-A"])
        client.applyPulledPage(page, cursor: cursor, context: context)

        // El cursor del grupo avanzó a 7.
        let json = cursor.groupCursorsJSON
        let map = try JSONDecoder().decode([String: Int64].self, from: Data(json.utf8))
        #expect(map["SplitGroup-A"] == 7)

        // Y el SplitShare se materializó localmente.
        #expect(try context.fetch(FetchDescriptor<SplitShare>()).count == 1)
    }

    @Test func pull_buildsExpectedQuery_withCursorsAndLimit() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // URL directa (buildPullURL).
        let client = GroupsSyncClient(
            tokenProvider: { "jwt-token" }, urlSession: StubHTTPSession())
        let url = client.buildPullURL(cursorsJSON: "{\"SplitGroup-A\":5}", limit: 500)
        #expect(url != nil)
        let comps = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        #expect(url!.absoluteString.contains("groups/pull"))
        #expect(comps?.queryItems?.first { $0.name == "cursors" }?.value == "{\"SplitGroup-A\":5}")
        #expect(comps?.queryItems?.first { $0.name == "limit" }?.value == "500")

        // Request REAL enviado por pullAndApplyOnce (assert del BODY/URL, lección d49d2e47).
        let stub = StubHTTPSession()
        let netClient = GroupsSyncClient(tokenProvider: { "jwt-token" }, urlSession: stub)
        // Sembrar un cursor con contenido para que la query lo lleve.
        let cursor = try netClient.loadOrCreateCursor(context)
        cursor.groupCursorsJSON = "{\"SplitGroup-B\":9}"
        try context.save()

        _ = await netClient.pullAndApplyOnce(context: context, limit: 250)
        #expect(stub.callCount == 1)
        let sent = stub.lastRequest
        #expect(sent?.httpMethod == "GET")
        #expect(sent?.url?.absoluteString.contains("groups/pull") == true)
        let sentComps = URLComponents(url: sent!.url!, resolvingAgainstBaseURL: false)
        #expect(sentComps?.queryItems?.first { $0.name == "cursors" }?.value == "{\"SplitGroup-B\":9}")
        #expect(sentComps?.queryItems?.first { $0.name == "limit" }?.value == "250")
        #expect(sent?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
    }

    // MARK: - Test 5 · Flag DARK: startIfEligible es no-op

    @Test func startIfEligible_isNoOp_whenFlagDisabled() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let prevFlag = CloudSyncFlags.groupsBackendEnabled
        defer { CloudSyncFlags.groupsBackendEnabled = prevFlag }
        CloudSyncFlags.groupsBackendEnabled = false

        // Sesión "viva" y una red que FALLARÍA el test si se tocara.
        let stub = StubHTTPSession()
        let client = GroupsSyncClient(
            tokenProvider: { Issue.record("tokenProvider tocado con flag OFF"); return nil },
            urlSession: stub,
            sessionCheck: { true })

        client.startIfEligible(context: context)

        // Sin red y sin modelos del canal (ni cursor ni outbox).
        #expect(stub.callCount == 0)
        #expect(try context.fetch(FetchDescriptor<GroupSyncCursor>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GroupSyncOutbox>()).isEmpty)
    }

    // MARK: - Test 5b · Apply de group_members (pull-only): userID + born-remote id determinista

    private func memberDelta(
        group: String = "SplitGroup-A", memberKey: String = "member-rec-1",
        userID: WireValue? = .string("auth-uid-1"), op: SyncOutboxOp = .upsert,
        serverSeq: Int64 = 3
    ) -> GroupPulledDelta {
        var fields: [String: WireValue] = [
            "display_name": .string("Alice"),
            "role": .string("admin"),
            "status": .string("active"),
            "joined_at": .string("2026-07-15T00:00:00.000Z"),
        ]
        if let userID { fields["user_id"] = userID }
        return GroupPulledDelta(
            entityType: "group_members", groupID: group, rawSyncID: memberKey, syncID: nil,
            op: op, fields: fields, fieldHlcs: [:],
            hlc: "2026-07-15T00:00:00.000Z-0000-000000000000000b",
            serverSeq: serverSeq, schemaVersion: 1)
    }

    @Test func apply_member_writesUserID_andDeterministicBornRemoteID() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        let page = GroupPulledPage(
            deltas: [memberDelta()], cursors: ["SplitGroup-A": 3], memberships: ["SplitGroup-A"])
        client.applyPulledPage(page, cursor: cursor, context: context)

        let members = try context.fetch(FetchDescriptor<SplitMember>())
        let member = try #require(members.first)
        // El `user_id` del wire aterrizó en la columna LOCAL `userID` (cierra el residual de G2).
        #expect(member.userID == "auth-uid-1")
        #expect(member.cloudKitUserRecordID == "member-rec-1")
        #expect(member.displayName == "Alice")
        // Born-remote: id LOCAL = namespace backend determinista (NO un UUID() aleatorio).
        #expect(member.id == GroupBackendIdentityLogic.deterministicMemberID(
            groupID: "SplitGroup-A", memberKey: "member-rec-1"))
    }

    @Test func apply_member_nullUserID_isAnonymization_nullsColumn() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)

        // Primer apply: llega con user_id.
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: [:], memberships: []),
            cursor: cursor, context: context)
        #expect(try context.fetch(FetchDescriptor<SplitMember>()).first?.userID == "auth-uid-1")

        // Segundo apply del MISMO member con user_id = null (anonimización del server) → NULLea la columna.
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta(userID: .null, serverSeq: 4)], cursors: [:], memberships: []),
            cursor: cursor, context: context)
        let members = try context.fetch(FetchDescriptor<SplitMember>())
        #expect(members.count == 1)  // mismo member (dedup por id determinista), no duplicado
        #expect(members.first?.userID == nil)
    }

    // MARK: - Test 5c · refreshCurrentUserFlags con flag OFF = byte-idéntico (path CloudKit, ignora userID)

    /// Con `groupsBackendEnabled == false` (SIEMPRE en producción hoy), `refreshCurrentUserFlags` deriva
    /// `isCurrentUser` EXCLUSIVAMENTE por el path CloudKit (`cloudKitUserRecordID == recordName`) e IGNORA
    /// `SplitMember.userID`. Toca los singletons `GroupService.shared`/`GroupUserIdentityService.shared`
    /// → suite `.serialized` + restore. No dispara `enqueueSave` (members con record-id no vacío, grupo
    /// no-owner) → sin acoplar `SplitSyncManager`.
    @Test func refreshCurrentUserFlags_flagOff_usesCloudKitPath_ignoresUserID() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let prevFlag = CloudSyncFlags.groupsBackendEnabled
        let prevCache = GroupUserIdentityService.shared.cachedRecordName
        defer {
            CloudSyncFlags.groupsBackendEnabled = prevFlag
            GroupUserIdentityService.shared._testSetCachedRecordName(prevCache)
        }
        CloudSyncFlags.groupsBackendEnabled = false
        GroupUserIdentityService.shared._testSetCachedRecordName("rec-current")

        let group = SplitGroup(name: "Trip")
        group.cloudKitZoneID = "zone-1"
        group.isOwner = false
        context.insert(group)

        // memberA: match por record-name → debe volverse current. Su `userID` apunta a OTRO uid: con flag
        // OFF NO se consulta → no altera la decisión.
        let memberA = SplitMember(groupZoneID: "zone-1", displayName: "Me",
                                  cloudKitUserRecordID: "rec-current")
        memberA.userID = "someone-else-uid"
        // memberB: sin match por record-name, pero su `userID` == "rec-current". Con flag OFF NO debe
        // volverse current (el path backend está apagado).
        let memberB = SplitMember(groupZoneID: "zone-1", displayName: "Other",
                                  cloudKitUserRecordID: "rec-other")
        memberB.userID = "rec-current"
        context.insert(memberA)
        context.insert(memberB)
        try context.save()

        await GroupService.shared.refreshCurrentUserFlags(context: context)

        #expect(memberA.isCurrentUser == true)   // match por record-name (path CloudKit)
        #expect(memberB.isCurrentUser == false)  // userID ignorado con flag OFF
    }

    // MARK: - Test 6 · Emisión canon c1 (gmoney junto; gshare trío)

    @Test func emission_expense_gmoneyTogether_partialUpdateExpandsGroup() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let expense = makeExpense(amount: 12.5, currency: "USD", desc: "Dinner", context: context)
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)

        // INSERT: proyección completa — gmoney (amount + currency_code) presente en el mismo delta.
        let insertRow = try #require(try groupOutbox(context).first)
        #expect(insertRow.entityType == GroupSyncEntityType.splitExpense)
        #expect(insertRow.opRaw == SyncOutboxOp.upsert.rawValue)
        #expect(insertRow.groupID == "SplitGroup-A")
        #expect(insertRow.fieldsJSON.contains("\"amount\":\"12.5000\""))   // money escala 4
        #expect(insertRow.fieldsJSON.contains("\"currency_code\":\"USD\""))
        #expect(insertRow.fieldsJSON.contains("\"expense_description\":\"Dinner\""))
        #expect(insertRow.fieldHlcsJSON?.contains("gmoney") == true)

        // UPDATE PARCIAL de solo `amount`: el invariante de coherencia arrastra `currency_code` (gmoney
        // viaja entero) pero NO `expense_description` (no tocado).
        expense.amount = 20.0
        try context.save()
        client.drainOnce(context: context)

        let updateRow = try #require(
            try groupOutbox(context).first { !$0.fieldsJSON.contains("expense_description") })
        #expect(updateRow.fieldsJSON.contains("\"amount\":\"20.0000\""))
        #expect(updateRow.fieldsJSON.contains("\"currency_code\":\"USD\""))   // gmoney expandido
        #expect(updateRow.fieldsJSON.contains("expense_description") == false)
        #expect(updateRow.fieldHlcsJSON?.contains("gmoney") == true)
    }

    @Test func emission_share_gshareTrioTravelsWhole() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let share = SplitShare(expenseID: UUID(), memberID: "member-1", amount: 6.25,
                               groupZoneID: "SplitGroup-A")
        context.insert(share)
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)

        let row = try #require(try groupOutbox(context).first { $0.entityType == GroupSyncEntityType.splitShare })
        // gshare trío = expense_id + member_key + amount, todos presentes en el mismo delta.
        #expect(row.fieldsJSON.contains("\"expense_id\":"))
        #expect(row.fieldsJSON.contains("\"member_key\":\"member-1\""))
        #expect(row.fieldsJSON.contains("\"amount\":\"6.2500\""))
        #expect(row.fieldsJSON.contains("\"is_paid\":false"))
        #expect(row.fieldHlcsJSON?.contains("gshare") == true)
    }

    // MARK: - Paridad emisión ↔ group_capability_manifest.json (guard del review adversarial G2)

    /// El manifest (raíz del repo, vía #filePath) es el contrato del wire; la emisión debe ser un
    /// SUBCONJUNTO exacto por tabla. La única resta permitida es split_groups.created_at: el manifest la
    /// conserva para la PROYECCIÓN del pull, pero el column-grant del server (supabase-groups-staging.ddl,
    /// hallazgo #1 de G1) la excluye del UPDATE — emitirla rechazaría el delta ENTERO de meta (42501).
    /// Este test es el que faltaba cuando el review cazó esa emisión a mano.
    @Test func emissionParity_catalogMatchesGroupManifest_minusNonGrantable() throws {
        let manifestURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("group_capability_manifest.json")
        let data = try Data(contentsOf: manifestURL)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entities = try #require(root["entities"] as? [String: Any])

        // group_members es pull-only: JAMÁS en el catálogo de emisión.
        #expect(GroupEntityEmissionMap.catalog["group_members"] == nil)

        let nonGrantable: [String: Set<String>] = ["split_groups": ["created_at"]]

        for (table, spec) in GroupEntityEmissionMap.catalog {
            let entity = try #require(entities[table] as? [String: Any], "tabla \(table) ausente del manifest")
            let columnSpecs = try #require(entity["columns"] as? [String: Any])
            let manifestColumns = Set(columnSpecs.keys)
            let expectedEmitted = manifestColumns.subtracting(nonGrantable[table] ?? [])
            #expect(spec.columns == expectedEmitted,
                    "emisión de \(table) difiere del manifest: extra=\(spec.columns.subtracting(expectedEmitted)) faltan=\(expectedEmitted.subtracting(spec.columns))")

            // group_key por columna idéntico en las dos puntas (gmoney/gshare/smoney).
            for (column, colSpec) in columnSpecs {
                guard spec.columns.contains(column) else { continue }
                let manifestGroup = (colSpec as? [String: Any])?["group_key"] as? String
                #expect(spec.groups[column] == manifestGroup,
                        "\(table).\(column): group_key manifest=\(manifestGroup ?? "nil") emisión=\(spec.groups[column] ?? "nil")")
            }
        }
    }
}
