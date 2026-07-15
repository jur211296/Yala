//
//  GroupMerkleTests.swift
//  YalaTests / CloudSync
//
//  Merkle client-side del canal de GRUPOS (endurecimiento B1, DARK). Cubre:
//   (1) PROYECCIÓN byte a byte contra `groups_merkle_fixtures.json` (EL gate load-bearing — el mini-golden
//       cross-lenguaje generado por gateway/scripts/generate-groups-merkle-fixtures.mjs con el canon del
//       server como oráculo: si la proyección del cliente diverge un byte, el test lo ve);
//   (2) proyección-merkle == columnas del manifest COMPLETAS por entidad (las 5, sin restas);
//   (3) decode del wire real de `/groups/merkle` (`GroupsMerkleClient`, channel2_root no-opcional);
//   (4) `computeLocalMerkle` (store vacío → root vacío, identidad lowercased, member_key nil → skip);
//   (5) guards EN ORDEN de `verifyGroupIntegrity` (outbox/dead-letter/no-pull/remoto-vacío → skip);
//   (6) remediación una-vez-por-sesión (reset cursor + re-pull) + verdict diverged;
//   (7) wiring de cadencia (`SyncCadencePolicy.shouldRunMerkle` → verifica tras N pulls completos).
//  Container ON-DISK temp con los 3 stores (`.none`). `.serialized` + containers propios por test.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupMerkle · B1 (DARK)", .serialized)
@MainActor
struct GroupMerkleTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupMerkle-\(UUID().uuidString)", isDirectory: true)
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
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Stub HTTP con respuesta fija (para el merkle / pull).
    private final class StubSession: SyncHTTPSession, @unchecked Sendable {
        let data: Data
        let status: Int
        var callCount = 0
        var lastURL: URL?
        init(_ json: String, status: Int = 200) { self.data = Data(json.utf8); self.status = status }
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            callCount += 1
            lastURL = request.url
            return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }

    private let emptyPageJSON = "{\"deltas\":[],\"cursors\":{},\"memberships\":[]}"

    /// Construye el JSON de una respuesta `/groups/merkle`.
    private func merkleJSON(root: String, channel2: String = "cc",
                            entities: [String: (Int, String)]) -> String {
        let ents = entities.map { "\"\($0.key)\":{\"count\":\($0.value.0),\"hash\":\"\($0.value.1)\"}" }
            .joined(separator: ",")
        return "{\"canon_version\":\"c1\",\"group_id\":\"g\",\"root\":\"\(root)\",\"entities\":{\(ents)},\"channel2_root\":\"\(channel2)\"}"
    }

    // MARK: - Fixtures (groups_merkle_fixtures.json — oráculo del server)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private func loadFixture() throws -> [String: Any] {
        let data = try Data(contentsOf: Self.repoRoot.appendingPathComponent("groups_merkle_fixtures.json"))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func dateForMillis(_ ms: Int64) -> Date {
        // +0.5 ms sub-cuanto: `physicalMillis` hace FLOOR(t*1000) → recupera `ms` exacto sin riesgo de −1 ms.
        Date(timeIntervalSince1970: Double(ms) / 1000.0 + 0.0005)
    }

    // Builders @Model desde el `model` lógico del fixture (typed casts sobre JSONSerialization).
    private func str(_ m: [String: Any], _ k: String) -> String? { m[k] as? String }
    private func dbl(_ m: [String: Any], _ k: String) -> Double { (m[k] as? NSNumber)?.doubleValue ?? 0 }
    private func bool(_ m: [String: Any], _ k: String) -> Bool { (m[k] as? NSNumber)?.boolValue ?? false }
    private func ms(_ m: [String: Any], _ k: String) -> Int64 { (m[k] as? NSNumber)?.int64Value ?? 0 }

    private func buildExpense(_ m: [String: Any]) -> SplitExpense {
        let e = SplitExpense()
        e.amount = dbl(m, "amount")
        e.currencyCode = str(m, "currency_code") ?? ""
        e.expenseDescription = str(m, "expense_description") ?? ""
        e.note = str(m, "note")
        e.date = dateForMillis(ms(m, "date_ms"))
        e.createdAt = dateForMillis(ms(m, "created_at_ms"))
        e.paidByMemberID = str(m, "paid_by_member_key") ?? ""
        e.splitType = str(m, "split_type") ?? ""
        e.isSettled = bool(m, "is_settled")
        e.isOpeningBalance = bool(m, "is_opening_balance")
        e.subcategoryName = str(m, "subcategory_name")
        return e
    }
    private func buildShare(_ m: [String: Any]) -> SplitShare {
        let s = SplitShare()
        s.expenseID = UUID(uuidString: str(m, "expense_id") ?? "") ?? UUID()
        s.memberID = str(m, "member_key") ?? ""
        s.amount = dbl(m, "amount")
        s.isPaid = bool(m, "is_paid")
        return s
    }
    private func buildSettlement(_ m: [String: Any]) -> SplitSettlement {
        let s = SplitSettlement()
        s.fromMemberID = str(m, "from_member_key") ?? ""
        s.toMemberID = str(m, "to_member_key") ?? ""
        s.amount = dbl(m, "amount")
        s.currencyCode = str(m, "currency_code") ?? ""
        s.note = str(m, "note")
        s.date = dateForMillis(ms(m, "date_ms"))
        s.isConfirmed = bool(m, "is_confirmed")
        return s
    }
    private func buildGroup(_ m: [String: Any]) -> SplitGroup {
        let g = SplitGroup()
        g.name = str(m, "name") ?? ""
        g.iconName = str(m, "icon_name") ?? ""
        g.colorHex = str(m, "color_hex") ?? ""
        g.currencyCode = str(m, "currency_code") ?? ""
        g.simplifyDebts = bool(m, "simplify_debts")
        g.showDebtsInSingleCurrency = bool(m, "show_debts_in_single_currency")
        g.membersCanInvite = bool(m, "members_can_invite")
        g.defaultSplitType = str(m, "default_split_type") ?? ""
        g.isArchived = bool(m, "is_archived")
        g.isHiddenForAll = bool(m, "is_hidden_for_all")
        g.createdAt = dateForMillis(ms(m, "created_at_ms"))
        return g
    }
    private func buildMember(_ m: [String: Any]) -> SplitMember {
        let mem = SplitMember()
        mem.userID = str(m, "user_id")
        mem.displayName = str(m, "display_name") ?? ""
        mem.role = str(m, "role") ?? ""
        mem.status = str(m, "status") ?? ""
        mem.joinedAt = dateForMillis(ms(m, "joined_at_ms"))
        return mem
    }

    /// Proyecta el `model` del sample con la emisión Merkle correcta y devuelve el payload c1.
    private func projectPayload(entity: String, model: [String: Any]) throws -> String {
        switch entity {
        case "split_expenses":
            return try GroupMerkleProjection.channel1Payload(
                model: buildExpense(model), emission: GroupMerkleProjection.splitExpense)
        case "split_shares":
            return try GroupMerkleProjection.channel1Payload(
                model: buildShare(model), emission: GroupMerkleProjection.splitShare)
        case "split_settlements":
            return try GroupMerkleProjection.channel1Payload(
                model: buildSettlement(model), emission: GroupMerkleProjection.splitSettlement)
        case "split_groups":
            return try GroupMerkleProjection.channel1Payload(
                model: buildGroup(model), emission: GroupMerkleProjection.splitGroup)
        case "group_members":
            return try GroupMerkleProjection.channel1Payload(
                model: buildMember(model), emission: GroupMerkleProjection.groupMember)
        default:
            Issue.record("entidad desconocida \(entity)"); return ""
        }
    }

    // MARK: - (1) PROYECCIÓN byte a byte (EL gate load-bearing)

    @Test func fixtureProjection_payloadLeafEntityRoot_byteExact_allFiveEntities() throws {
        let fixture = try loadFixture()
        let entities = try #require(fixture["entities"] as? [String: Any])

        var entityDigests: [String: Data] = [:]
        for (entity, raw) in entities {
            let entityFixture = try #require(raw as? [String: Any])
            let samples = try #require(entityFixture["samples"] as? [[String: Any]])

            var leaves: [(String, Data)] = []
            for sample in samples {
                let identity = try #require(sample["identity"] as? String)
                let expectedPayload = try #require(sample["payload_c1"] as? String)
                let expectedLeaf = try #require(sample["leaf_hex"] as? String)
                let model = try #require(sample["model"] as? [String: Any])

                let payload = try projectPayload(entity: entity, model: model)
                #expect(payload == expectedPayload,
                        "\(entity) payload divergente\nesperado=\(expectedPayload)\nobtenido=\(payload)")

                let leaf = SyncMerkle.leafDigest(syncID: identity, payload: payload)
                #expect(SyncMerkle.hexString(leaf) == expectedLeaf, "\(entity) leaf \(identity)")
                leaves.append((identity, leaf))
            }
            // entityHash sobre las muestras (ordenadas por identidad UTF-8 asc por el ensamblado).
            let digest = SyncMerkle.entityDigest(leaves)
            entityDigests[entity] = digest
            let expectedEH = try #require(entityFixture["entity_hash_hex"] as? String)
            #expect(SyncMerkle.hexString(digest) == expectedEH, "\(entity) entityHash")
        }

        // Root sobre las 5 entidades.
        let root = SyncMerkle.rootDigest(entityDigests: entityDigests)
        let expectedRoot = try #require(fixture["root_hex"] as? String)
        #expect(SyncMerkle.hexString(root) == expectedRoot, "root")
    }

    @Test func fixtureEmpty_entityAndRootHash_matchFixture() throws {
        let fixture = try loadFixture()
        let expectedEmptyEH = try #require(fixture["empty_entity_hash_hex"] as? String)
        let expectedEmptyRoot = try #require(fixture["empty_root_hex"] as? String)

        #expect(SyncMerkle.hexString(SyncMerkle.entityDigest([])) == expectedEmptyEH)
        // Root de las 5 tablas con hash-vacío.
        var digests: [String: Data] = [:]
        for table in GroupMerkleProjection.entityTables { digests[table] = SyncMerkle.emptyDigest }
        #expect(SyncMerkle.hexString(SyncMerkle.rootDigest(entityDigests: digests)) == expectedEmptyRoot)
    }

    // MARK: - (2) Proyección Merkle == columnas del manifest COMPLETAS (twin del emissionParity)

    @Test func merkleProjection_catalogMatchesGroupManifest_completeColumns() throws {
        let manifestURL = Self.repoRoot.appendingPathComponent("group_capability_manifest.json")
        let data = try Data(contentsOf: manifestURL)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entities = try #require(root["entities"] as? [String: Any])

        // Las 5 tablas (incl. group_members y split_groups CON created_at) — sin restas.
        #expect(Set(GroupMerkleProjection.catalog.keys) == Set(entities.keys))

        for (table, spec) in GroupMerkleProjection.catalog {
            let entity = try #require(entities[table] as? [String: Any], "tabla \(table) ausente del manifest")
            let columnSpecs = try #require(entity["columns"] as? [String: Any])
            let manifestColumns = Set(columnSpecs.keys)
            #expect(spec.columns == manifestColumns,
                    "proyección merkle de \(table) ≠ manifest COMPLETO: extra=\(spec.columns.subtracting(manifestColumns)) faltan=\(manifestColumns.subtracting(spec.columns))")
        }
    }

    // MARK: - (3) GroupsMerkleClient · decode del wire real

    @Test func merkleClient_decodes200_channel2RootNonOptional() async throws {
        let json = merkleJSON(root: "abc", channel2: "def", entities: ["split_groups": (0, "00")])
        let client = GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: StubSession(json))
        let outcome = await client.fetchMerkle(groupID: "SplitGroup-A")
        guard case .snapshot(let remote) = outcome else { Issue.record("esperaba snapshot, got \(outcome)"); return }
        #expect(remote.canonVersion == "c1")
        #expect(remote.root == "abc")
        #expect(remote.channel2Root == "def")
        #expect(remote.entities["split_groups"]?.count == 0)
    }

    @Test func merkleClient_maps401_403_decodeFail() async throws {
        let ok = merkleJSON(root: "a", entities: [:])
        let c401 = GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: StubSession(ok, status: 401))
        #expect(await c401.fetchMerkle(groupID: "g") == .sessionExpired)
        let c403 = GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: StubSession(ok, status: 403))
        #expect(await c403.fetchMerkle(groupID: "g") == .accountUnavailable)
        let cBad = GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: StubSession("not-json", status: 200))
        #expect(await cBad.fetchMerkle(groupID: "g") == .transient)
        // Token nil → sessionExpired sin request.
        let stub = StubSession(ok)
        let cNil = GroupsMerkleClient(tokenProvider: { nil }, urlSession: stub)
        #expect(await cNil.fetchMerkle(groupID: "g") == .sessionExpired)
        #expect(stub.callCount == 0)
    }

    @Test func merkleClient_requestOmitsCapabilitySetHeader_carriesGroupID() async throws {
        let stub = StubSession(merkleJSON(root: "a", entities: [:]))
        let client = GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: stub)
        _ = await client.fetchMerkle(groupID: "SplitGroup-Zébra")
        let req = try #require(stub.lastURL)
        #expect(req.absoluteString.contains("groups/merkle"))
        let comps = URLComponents(url: req, resolvingAgainstBaseURL: false)
        #expect(comps?.queryItems?.first(where: { $0.name == "group_id" })?.value == "SplitGroup-Zébra")
    }

    // MARK: - (4) computeLocalMerkle

    @Test func computeLocalMerkle_emptyGroup_rootIsEmptyCorpus() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fixture = try loadFixture()
        let expectedEmptyRoot = try #require(fixture["empty_root_hex"] as? String)

        let local = GroupMerkleProjection.computeLocalMerkle(groupID: "SplitGroup-Empty", context: context)
        #expect(local.entities.count == 5)
        for (_, s) in local.entities { #expect(s.count == 0) }
        #expect(local.rootHex == expectedEmptyRoot)
    }

    @Test func computeLocalMerkle_identityLowercased_andMemberKeyNilSkipped() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let gid = "SplitGroup-UPPER"

        // Un member CON memberKey (participa) + uno SIN (skip).
        let m1 = SplitMember(groupZoneID: gid, displayName: "A")
        m1.memberKey = "KEY-MixedCase"
        let m2 = SplitMember(groupZoneID: gid, displayName: "B")  // memberKey nil → skip
        context.insert(m1); context.insert(m2)
        try context.save()

        let local = GroupMerkleProjection.computeLocalMerkle(groupID: gid, context: context)
        #expect(local.entities["group_members"]?.count == 1)  // solo el que tiene memberKey

        // El leaf usa la identidad LOWERCASED — reproducir el árbol con la identidad en minúsculas.
        let payload = try GroupMerkleProjection.channel1Payload(model: m1, emission: GroupMerkleProjection.groupMember)
        let leaf = SyncMerkle.leafDigest(syncID: "key-mixedcase", payload: payload)
        #expect(local.entities["group_members"]?.hashHex == SyncMerkle.hexString(SyncMerkle.entityDigest([("key-mixedcase", leaf)])))
    }

    // MARK: - (5) Guards EN ORDEN de verifyGroupIntegrity

    @Test func verify_skipsOnLiveOutbox_thenDeadLetter_thenNoPull() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let gid = "SplitGroup-A"
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: StubSession(emptyPageJSON))

        // (1) outbox VIVO del grupo → skip antes de cualquier fetch.
        let live = GroupSyncOutbox(syncID: UUID(), groupID: gid, entityType: GroupSyncEntityType.splitExpense,
                                   op: .upsert, hlc: "h", fieldsJSON: "{}", author: "x")
        context.insert(live); try context.save()
        var v = await client.verifyGroupIntegrity(groupID: gid, context: context)
        #expect(v == .skipped(reason: "outbox-pending"))

        // (2) sin vivo pero con dead-letter → skip [R7].
        live.rejectedReason = "upstream_400:yala_bad_request"
        try context.save()
        v = await client.verifyGroupIntegrity(groupID: gid, context: context)
        #expect(v == .skipped(reason: "dead-letters"))

        // (3) sin outbox y sin pull completado → skip.
        context.delete(live); try context.save()
        v = await client.verifyGroupIntegrity(groupID: gid, context: context)
        #expect(v == .skipped(reason: "no-completed-pull"))
    }

    @Test func verify_emptyRemote_localNotEmpty_skipsWithoutCanary() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let gid = "SplitGroup-A"

        // Local NO vacío: una expense en el grupo.
        let e = makeExpense(gid, context: context); try context.save()
        _ = e

        // Remoto: corpus vacío (todas las entities count 0). Firma de remoción de membership vía RLS.
        let emptyRemote = merkleJSON(root: "deadbeef", entities: [
            "split_groups": (0, "00"), "group_members": (0, "00"), "split_expenses": (0, "00"),
            "split_shares": (0, "00"), "split_settlements": (0, "00"),
        ])
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: StubSession(emptyPageJSON),
            merkleClient: GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: StubSession(emptyRemote)))
        client._testMarkPullCompleted()

        let v = await client.verifyGroupIntegrity(groupID: gid, context: context)
        #expect(v == .skipped(reason: "empty-remote"))  // NUNCA .diverged
    }

    @Test func verify_convergesWhenLocalMatchesRemote() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let gid = "SplitGroup-A"  // store vacío → local = corpus vacío

        let local = GroupMerkleProjection.computeLocalMerkle(groupID: gid, context: context)
        let emptyHash = try #require(local.entities["split_groups"]?.hashHex)
        let remote = merkleJSON(root: local.rootHex, entities: [
            "split_groups": (0, emptyHash), "group_members": (0, emptyHash), "split_expenses": (0, emptyHash),
            "split_shares": (0, emptyHash), "split_settlements": (0, emptyHash),
        ])
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: StubSession(emptyPageJSON),
            merkleClient: GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: StubSession(remote)))
        client._testMarkPullCompleted()

        // Local vacío + remoto vacío-idéntico → converge (NO cae en la rama remoto-vacío: exige local no vacío).
        let v = await client.verifyGroupIntegrity(groupID: gid, context: context)
        #expect(v == .converged)
    }

    // MARK: - (6) Remediación una-vez-por-sesión + verdict diverged

    @Test func runVerification_diverged_remediatesOncePerSession() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let gid = "SplitGroup-A"

        // Local: una expense (no vacío). Cursor con el grupo en seq 5.
        _ = makeExpense(gid, context: context)
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: StubSession(emptyPageJSON),
            merkleClient: GroupsMerkleClient(
                tokenProvider: { "jwt" },
                // Remoto NO vacío (split_expenses count 1) pero hash BOGUS → diverge (no cae en remoto-vacío).
                urlSession: StubSession(merkleJSON(root: "bb", entities: [
                    "split_groups": (0, "00"), "group_members": (0, "00"),
                    "split_expenses": (1, "aaaaaaaa"), "split_shares": (0, "00"), "split_settlements": (0, "00"),
                ]))))
        let cursor = try client.loadOrCreateCursor(context)
        cursor.groupCursorsJSON = "{\"\(gid)\":5}"
        try context.save()
        client._testMarkPullCompleted()

        // Verdict directo: diverged.
        let v = await client.verifyGroupIntegrity(groupID: gid, context: context)
        guard case .diverged = v else { Issue.record("esperaba diverged, got \(v)"); return }

        // Corrida completa: remedia (reset cursor a 0 + re-pull) UNA vez.
        client._testMarkPullCompleted()
        await client.runGroupMerkleVerification(context: context, now: .now)
        #expect(client.didRemediateGroupMerkleThisSession)
        let map1 = try JSONDecoder().decode([String: Int64].self, from: Data(client.loadOrCreateCursor(context).groupCursorsJSON.utf8))
        #expect(map1[gid] == 0)  // cursor reseteado por la remediación

        // Segunda corrida: sigue divergiendo pero NO re-remedia (flag de sesión). Volvemos a poner el cursor
        // en 5 para detectar si la remediación lo re-resetea (no debe).
        let c2 = try client.loadOrCreateCursor(context)
        c2.groupCursorsJSON = "{\"\(gid)\":5}"
        try context.save()
        client._testMarkPullCompleted()
        await client.runGroupMerkleVerification(context: context, now: .now)
        let map2 = try JSONDecoder().decode([String: Int64].self, from: Data(client.loadOrCreateCursor(context).groupCursorsJSON.utf8))
        #expect(map2[gid] == 5)  // NO re-reseteado (remediación una-vez-por-sesión)
    }

    @Test func resetMerkleSessionState_rearmsRemediation() async throws {
        let client = GroupsSyncClient()
        client.stopLoop()  // llama resetMerkleSessionState
        #expect(!client.didRemediateGroupMerkleThisSession)
        #expect(client.completedPullsSinceMerkle == 0)
        #expect(client.lastMerkleAt == nil)
        #expect(!client.lastPullCycleCompleted)
    }

    // MARK: - (7) Wiring de cadencia (SyncCadencePolicy.shouldRunMerkle tal cual)

    @Test func cadence_verifiesAfterNCompletedPulls_thenResetsCounter() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let gid = "SplitGroup-A"

        // Merkle stub: corpus vacío-idéntico al local (converge). Cuenta las llamadas al endpoint merkle.
        let localEmpty = GroupMerkleProjection.computeLocalMerkle(groupID: gid, context: context)
        let emptyHash = try #require(localEmpty.entities["split_groups"]?.hashHex)
        let merkleStub = StubSession(merkleJSON(root: localEmpty.rootHex, entities: [
            "split_groups": (0, emptyHash), "group_members": (0, emptyHash), "split_expenses": (0, emptyHash),
            "split_shares": (0, emptyHash), "split_settlements": (0, emptyHash),
        ]))
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: StubSession(emptyPageJSON),
            merkleClient: GroupsMerkleClient(tokenProvider: { "jwt" }, urlSession: merkleStub))

        // Cursor con el grupo (para que runGroupMerkleVerification tenga algo que verificar).
        let cursor = try client.loadOrCreateCursor(context)
        cursor.groupCursorsJSON = "{\"\(gid)\":5}"
        try context.save()

        // 19 ciclos: cada pull completa (página vacía) → contador sube, merkle NO corre aún.
        for _ in 0..<(SyncCadencePolicy.merkleEveryNPulls - 1) {
            _ = await client.syncCycleOnce(context: context)
        }
        #expect(client.completedPullsSinceMerkle == SyncCadencePolicy.merkleEveryNPulls - 1)
        #expect(merkleStub.callCount == 0)  // aún no

        // Ciclo Nº20: dispara la verificación (una llamada al endpoint merkle) y resetea el contador.
        _ = await client.syncCycleOnce(context: context)
        #expect(merkleStub.callCount == 1)
        #expect(client.completedPullsSinceMerkle == 0)
        #expect(client.lastMerkleAt != nil)
    }

    // MARK: - Helpers

    private func makeExpense(_ gid: String, context: ModelContext) -> SplitExpense {
        let e = SplitExpense(groupZoneID: gid, amount: 12.5, currencyCode: "USD",
                             expenseDescription: "x", paidByMemberID: "m1")
        context.insert(e)
        return e
    }
}
