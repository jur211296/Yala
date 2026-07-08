//
//  SyncMerkleTests.swift
//  YalaTests / CloudSync
//
//  Verificación Merkle del Canal 1 (I8f-3): (1) el ENSAMBLADO A-4 contra `merkle_fixtures.json`
//  (raíz del repo — el mini-golden cross-lenguaje compartido con merkle.unit.test.ts: si el ensamblado
//  diverge un byte, ambos lados lo ven); (2) `computeLocalMerkle` (counts, determinismo, filas sin
//  syncID excluidas, exclusión de `local_day` — A-2b); (3) el guard de quiescencia A-3 de
//  `verifyIntegrity` y los verdicts converged/diverged. Container ON-DISK temp. `.serialized`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("SyncMerkle · Canal 1 I8f-3", .serialized)
@MainActor
struct SyncMerkleTests {

    // MARK: - Fixtures compartidos (ensamblado A-4)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private struct Fixture: Decodable {
        struct Leaf: Decodable {
            let sync_id: String
            let payload: String
            let leaf_hex: String
        }
        struct EntityCase: Decodable { let entity_hash_hex: String }
        struct RootCase: Decodable {
            let entity_hashes_hex: [String: String]
            let root_hex: String
        }
        let empty_entity_hash_hex: String
        let leaves: [Leaf]
        let entity_case: EntityCase
        let root_case: RootCase
    }

    private static func loadFixture() throws -> Fixture {
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("merkle_fixtures.json"))
        return try JSONDecoder().decode(Fixture.self, from: data)
    }

    private static func dataFromHex(_ hex: String) -> Data {
        var out = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            out.append(UInt8(hex[index..<next], radix: 16)!)
            index = next
        }
        return out
    }

    @Test func fixture_leafDigests_matchByteExact() throws {
        let fixture = try Self.loadFixture()
        for leaf in fixture.leaves {
            let computed = SyncMerkle.leafDigest(syncID: leaf.sync_id, payload: leaf.payload)
            #expect(SyncMerkle.hexString(computed) == leaf.leaf_hex, "leaf \(leaf.sync_id)")
        }
    }

    @Test func fixture_entityHash_sortsBySyncIDBytes() throws {
        let fixture = try Self.loadFixture()
        // Input en el orden DESORDENADO del fixture — el ensamblado debe ordenar por sync_id UTF-8 asc.
        let leaves = fixture.leaves.map {
            ($0.sync_id, SyncMerkle.leafDigest(syncID: $0.sync_id, payload: $0.payload))
        }
        #expect(SyncMerkle.hexString(SyncMerkle.entityDigest(leaves)) == fixture.entity_case.entity_hash_hex)
    }

    @Test func fixture_emptyEntity_isSHA256OfEmptyString() throws {
        let fixture = try Self.loadFixture()
        #expect(SyncMerkle.hexString(SyncMerkle.entityDigest([])) == fixture.empty_entity_hash_hex)
        #expect(SyncMerkle.hexString(SyncMerkle.emptyDigest) == fixture.empty_entity_hash_hex)
    }

    @Test func fixture_root_ordersTablesByUTF8Name() throws {
        let fixture = try Self.loadFixture()
        var digests: [String: Data] = [:]
        for (table, hex) in fixture.root_case.entity_hashes_hex {
            digests[table] = Self.dataFromHex(hex)
        }
        #expect(SyncMerkle.hexString(SyncMerkle.rootDigest(entityDigests: digests)) == fixture.root_case.root_hex)
    }

    // MARK: - computeLocalMerkle

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncMerkle-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "SM-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "SM-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "SM-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private let epochDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeTx(_ amount: Double, note: String? = nil, context: ModelContext) -> TransactionItem {
        let tx = TransactionItem(date: epochDate, amount: amount, currencyCode: "USD", note: note)
        tx.createdAt = epochDate
        tx.syncID = UUID()
        context.insert(tx)
        return tx
    }

    @Test func localMerkle_emptyStore_all16TablesEmptyHash() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fixture = try Self.loadFixture()

        let local = SyncMerkle.computeLocalMerkle(context: context)
        #expect(local.entities.count == 16)  // SIEMPRE las 16 (root independiente de qué tablas tienen datos)
        for (table, summary) in local.entities {
            #expect(summary.count == 0, Comment(rawValue: table))
            #expect(summary.hashHex == fixture.empty_entity_hash_hex, Comment(rawValue: table))
        }
        // Root reproducible por el ensamblado puro con 16 hashes-vacíos.
        var digests: [String: Data] = [:]
        for table in local.entities.keys { digests[table] = SyncMerkle.emptyDigest }
        #expect(local.rootHex == SyncMerkle.hexString(SyncMerkle.rootDigest(entityDigests: digests)))
    }

    @Test func localMerkle_countsRows_excludesRowsWithoutSyncID_deterministic() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        _ = makeTx(-10, note: "a", context: context)
        _ = makeTx(20, note: "b", context: context)
        // Fila SIN syncID → no participa (aún sin identidad de sync).
        let noID = TransactionItem(date: epochDate, amount: 5, currencyCode: "USD")
        context.insert(noID)
        let cat = Category(name: "Casa", colorHex: "#111111", isIncome: false, isDefaultSeed: false)
        cat.syncID = UUID()
        context.insert(cat)
        try context.save()

        let local = SyncMerkle.computeLocalMerkle(context: context)
        #expect(local.entities["tx_items"]?.count == 2)
        #expect(local.entities["categories"]?.count == 1)
        #expect(local.entities["budgets"]?.count == 0)

        // Determinismo: recomputar produce EXACTAMENTE los mismos hashes.
        let again = SyncMerkle.computeLocalMerkle(context: context)
        #expect(again == local)

        // Coherencia con el ensamblado puro: el hash de tx_items == leaves recomputados a mano.
        let txs = try context.fetch(FetchDescriptor<TransactionItem>()).filter { $0.syncID != nil }
        let leaves = try txs.map { tx -> (String, Data) in
            let payload = try SyncMerkle.channel1Payload(model: tx, emission: EntityEmissionMap.transactionItem)
            let sid = tx.syncID!.uuidString.lowercased()
            return (sid, SyncMerkle.leafDigest(syncID: sid, payload: payload))
        }
        #expect(local.entities["tx_items"]?.hashHex == SyncMerkle.hexString(SyncMerkle.entityDigest(leaves)))
    }

    @Test func danglerOverride_leafUsesWireKnowledge_notLocalNil() throws {
        // LOAD-BEARING v1: un `_ref` a un target NO sincronizado (subcategory/account no viajan) queda
        // nil localmente pero el server almacena el UUID — el leaf DEBE usar el conocimiento del wire
        // (SyncDanglingRef) o el Merkle divergiría PERMANENTEMENTE en cualquier multi-device.
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let tx = makeTx(-5, note: "d", context: context)
        let target = UUID()
        context.insert(SyncDanglingRef(entityTable: "tx_items", rowSyncID: tx.syncID!,
                                       column: "subcategory_ref", targetUUID: target))
        try context.save()

        // Sin override el payload emitiría null; con el dangler emite el UUID del wire.
        let payload = try SyncMerkle.channel1Payload(
            model: tx, emission: EntityEmissionMap.transactionItem,
            overrides: ["subcategory_ref": target])
        #expect(payload.contains("\"subcategory_ref\":\"\(target.uuidString.lowercased())\""))

        // computeLocalMerkle consume el registro automáticamente (hash == ensamblado con el override).
        let local = SyncMerkle.computeLocalMerkle(context: context)
        let sid = tx.syncID!.uuidString.lowercased()
        let expected = SyncMerkle.entityDigest([(sid, SyncMerkle.leafDigest(syncID: sid, payload: payload))])
        #expect(local.entities["tx_items"]?.hashHex == SyncMerkle.hexString(expected))
    }

    @Test func channel1Payload_excludesLocalDay_calendarIndependent() throws {
        // A-2b: `local_day` FUERA del leaf → el payload no la contiene y el hash es independiente del
        // calendario/huso del device (el único builder que usa el calendario es local_day).
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let tx = makeTx(-37.25, note: "café", context: context)
        try context.save()

        let payload = try SyncMerkle.channel1Payload(model: tx, emission: EntityEmissionMap.transactionItem)
        #expect(!payload.contains("local_day"))
        #expect(payload.contains("\"date\":"))
        #expect(payload.contains("\"amount\":\"-37.2500\""))  // canon c1 (money string escala 4)
        #expect(payload.contains("\"note\":\"café\""))
    }

    // MARK: - verifyIntegrity: guard A-3 + verdicts

    private func remoteJSON(root: String, entities: [String: (Int, String)],
                            canonVersion: String = "c1", capabilitySet: String = "v1") -> Data {
        let entitiesJSON = entities.map { "\"\($0.key)\":{\"count\":\($0.value.0),\"hash\":\"\($0.value.1)\"}" }
            .joined(separator: ",")
        return Data("""
        {"canon_version":"\(canonVersion)","capability_set":"\(capabilitySet)","root":"\(root)","entities":{\(entitiesJSON)},"channel2_root":"x"}
        """.utf8)
    }

    private func stubMerkleClient(_ body: Data) -> SyncMerkleClient {
        SyncMerkleClient(baseURL: URL(string: "https://example.test")!,
                         tokenProvider: { "jwt" },
                         urlSession: FixedMerkleSession(body))
    }

    @Test func verify_outboxPending_skipsWithoutCanary() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        engine.lastPullCycleCompleted = true

        // Un delta local VIVO pendiente → divergencia esperada → skip (A-3).
        context.insert(SyncOutbox(syncID: UUID(), entityType: SyncEntityType.transactionItem,
                                  op: .upsert, hlc: "x", fieldsJSON: "{}", author: ""))
        try context.save()

        let verdict = await engine.verifyIntegrity(using: stubMerkleClient(remoteJSON(root: "r", entities: [:])),
                                                   context: context)
        #expect(verdict == .skipped(reason: "outbox-pending"))
    }

    @Test func verify_noCompletedPull_skips() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()  // lastPullCycleCompleted == false

        let verdict = await engine.verifyIntegrity(using: stubMerkleClient(remoteJSON(root: "r", entities: [:])),
                                                   context: context)
        #expect(verdict == .skipped(reason: "no-completed-pull"))
    }

    @Test func verify_convergedAndDiverged() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        engine.lastPullCycleCompleted = true

        _ = makeTx(-10, note: "x", context: context)
        try context.save()

        // Stub que ECOA el árbol local → converged (root incluido: sin cuarentena se compara).
        let local = SyncMerkle.computeLocalMerkle(context: context)
        var entities: [String: (Int, String)] = [:]
        for (table, s) in local.entities { entities[table] = (s.count, s.hashHex) }
        let convergedVerdict = await engine.verifyIntegrity(
            using: stubMerkleClient(remoteJSON(root: local.rootHex, entities: entities)),
            context: context)
        #expect(convergedVerdict == .converged)

        // Stub con el hash de tx_items CORROMPIDO → diverged(["tx_items"]) (dispara el canario).
        entities["tx_items"] = (1, "deadbeef")
        let divergedVerdict = await engine.verifyIntegrity(
            using: stubMerkleClient(remoteJSON(root: local.rootHex, entities: entities)),
            context: context)
        #expect(divergedVerdict == .diverged(entities: ["tx_items"]))
    }

    @Test func verify_quarantine_skipsRootComparison() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        engine.lastPullCycleCompleted = true

        // Cuarentena local (tabla no cableada con filas server-side) → el root NO se compara aunque
        // difiera; las 6 cableadas sí (aquí coinciden → converged).
        context.insert(SyncQuarantine(serverSeq: 1, entityType: "budgets", syncID: UUID(),
                                      rawDelta: "{}", hlc: "h"))
        try context.save()

        let local = SyncMerkle.computeLocalMerkle(context: context)
        var entities: [String: (Int, String)] = [:]
        for (table, s) in local.entities { entities[table] = (s.count, s.hashHex) }
        // Root remoto DISTINTO (los budgets server-side lo mueven) — no debe contar como divergencia.
        let verdict = await engine.verifyIntegrity(
            using: stubMerkleClient(remoteJSON(root: "distinto", entities: entities)),
            context: context)
        #expect(verdict == .converged)
    }

    // MARK: - Fix #3 review: dead-letters bloquean el verify (skip, nunca canario)

    @Test func verify_deadLetters_skips() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        engine.lastPullCycleCompleted = true

        // Solo un DEAD-LETTER (rejected): el server nunca lo materializará → divergencia explicada y
        // permanente → skip (su propio canario `cloudSyncMutationRejected` ya la reporta).
        let dead = SyncOutbox(syncID: UUID(), entityType: SyncEntityType.transactionItem,
                              op: .upsert, hlc: "x", fieldsJSON: "{}", author: "")
        dead.rejectedReason = "coherence_group_partial:money"
        context.insert(dead)
        try context.save()

        let verdict = await engine.verifyIntegrity(using: stubMerkleClient(remoteJSON(root: "r", entities: [:])),
                                                   context: context)
        #expect(verdict == .skipped(reason: "dead-letters"))
    }

    // MARK: - Fix #1 review: canon_version / capability_set distintos → skip, nunca comparar

    @Test func verify_contractMismatch_skipsCleanly() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        engine.lastPullCycleCompleted = true

        // Un server en un canon futuro (c2) → skip limpio, JAMÁS divergencia falsa permanente.
        let c2 = await engine.verifyIntegrity(
            using: stubMerkleClient(remoteJSON(root: "r", entities: [:], canonVersion: "c2")),
            context: context)
        #expect(c2 == .skipped(reason: "canon-version-mismatch"))

        // Respuesta a OTRO capability-set (proyección distinta → árboles no comparables).
        let otherCap = await engine.verifyIntegrity(
            using: stubMerkleClient(remoteJSON(root: "r", entities: [:], capabilitySet: "full")),
            context: context)
        #expect(otherCap == .skipped(reason: "capability-set-mismatch"))
    }

    // MARK: - Fix #4 review: la exclusión de local_day atada a UNA regla (formato del manifest)

    @Test func channel1ExcludedColumns_matchManifestYYYYMMDDFormat() throws {
        // El TS excluye por FORMATO (`yyyy_mm_dd` en canon.ts/merkleColumns); el Swift por NOMBRE
        // (`channel1ExcludedColumns`). Este assert los ata: una columna futura de ese formato con otro
        // nombre debe añadirse a la lista Swift o este test la delata (divergencia falsa evitada).
        struct Manifest: Decodable {
            struct Column: Decodable { let format: String }
            struct Entity: Decodable { let columns: [String: Column] }
            let entities: [String: Entity]
        }
        let data = try Data(contentsOf: Self.repoRoot.appendingPathComponent("capability_manifest.json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        var yyyymmdd: Set<String> = []
        for entity in manifest.entities.values {
            for (column, spec) in entity.columns where spec.format == "yyyy_mm_dd" {
                yyyymmdd.insert(column)
            }
        }
        #expect(SyncMerkle.channel1ExcludedColumns == yyyymmdd)
    }
}

// MARK: - Stub

private final class FixedMerkleSession: SyncHTTPSession, @unchecked Sendable {
    let body: Data
    init(_ body: Data) { self.body = body }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
