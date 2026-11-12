//
//  GroupsCapabilityManifestParityTests.swift
//  YalaTests / CloudSync
//
//  Paridad del contrato de columnas del canal de GRUPOS. Gemelo de `CloudCapabilityManifestParityTests` (canal
//  personal), que cruza `capability_manifest.json` con `supabase-staging.ddl`; hasta el 2026-10-24 Grupos no tenía
//  nada parecido y `split_groups.budget_limit_amount` (g14_01) se acertó a mano. Ticket `groups-canal-sin-capability-set`.
//
//  (a) Cruce manifest ↔ `supabase-groups-staging.ddl`: toda columna del manifest de Grupos existe en su tabla del
//      snapshot; lo que el snapshot tiene de más es solo server-authored + identidad. Sin esto, «staging no tiene la
//      columna» llegaba como un dead-letter en un teléfono en vez de como un rojo local.
//  (b) Versiones: `manifest_version` == `GroupsSyncCapability.clientManifestVersion`, ninguna columna posterior a ella,
//      y el `since` de cada columna == `GroupsSyncCapability.since(table:column:)`, que es lo que lee el Merkle local.
//  (c) La trampa de `GroupsSyncCapability`: ningún emisor de Grupos lleva `since` propio, porque el drain los filtra
//      con el nivel del canal PERSONAL.
//  (d) El Merkle local de v1 no hashea `budget_limit_amount`; el de v2 sí, también como `null`.
//
//  Molde: `#filePath` → raíz del repo (el runner no empaqueta estos archivos como resources).
//

import Foundation
import Testing

@testable import Yala

@Suite("CloudSync · capability manifest de Grupos parity")
@MainActor
struct GroupsCapabilityManifestParityTests {

    /// Columnas server-authored + identidad: legítimas en el snapshot, NUNCA en el manifest. Árbitro independiente del
    /// manifest (no se lee su `server_only_columns`). `member_key` es identidad solo en `group_members`: en
    /// `split_shares` y `split_settlements` (`from/to_member_key`) es columna de dominio.
    private static let allowedNonManifest: Set<String> = [
        "group_id", "sync_id", "owner_user_id", "server_seq", "hlc", "field_hlcs",
        "deleted", "deleted_hlc", "schema_version", "updated_at",
    ]
    private static let allowedNonManifestByTable: [String: Set<String>] = ["group_members": ["member_key"]]

    private static let groupTables: Set<String> = [
        "split_groups", "group_members", "split_expenses", "split_shares", "split_settlements",
    ]

    // MARK: - Paths (vía #filePath)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // YalaTests/CloudSync/
            .deletingLastPathComponent()   // YalaTests/
            .deletingLastPathComponent()   // repo root
    }
    private static var manifestURL: URL { repoRoot.appendingPathComponent("group_capability_manifest.json") }
    private static var ddlURL: URL { repoRoot.appendingPathComponent("supabase-groups-staging.ddl") }

    // MARK: - Loaders

    private struct Manifest {
        let version: Int
        /// tabla Postgres → columna → metadata.
        let tables: [String: [String: [String: Any]]]
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ d: String) { description = d }
    }

    private static func loadManifest() throws -> Manifest {
        let data = try Data(contentsOf: manifestURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure("group_capability_manifest.json no es un objeto JSON")
        }
        guard let version = root["manifest_version"] as? Int else { throw Failure("manifest sin `manifest_version`") }
        guard let entities = root["entities"] as? [String: Any] else { throw Failure("manifest sin `entities`") }
        var tables: [String: [String: [String: Any]]] = [:]
        for (entity, raw) in entities {
            guard let obj = raw as? [String: Any],
                  let table = obj["table"] as? String,
                  let cols = obj["columns"] as? [String: Any] else {
                throw Failure("entidad \(entity) sin `table` o sin `columns`")
            }
            var columns: [String: [String: Any]] = [:]
            for (col, meta) in cols {
                guard let m = meta as? [String: Any] else { throw Failure("columna \(table).\(col) sin metadata") }
                columns[col] = m
            }
            tables[table] = columns
        }
        return Manifest(version: version, tables: tables)
    }

    /// Parsea `supabase-groups-staging.ddl` → tabla → columnas. Solo los `create table public.<t> (` … `);`.
    private static func parseDDL() throws -> [String: [String]] {
        let src = try String(contentsOf: ddlURL, encoding: .utf8)
        var tables: [String: [String]] = [:]
        var current: String?
        for rawLine in src.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let m = line.range(of: #"^create table public\.(\w+) \($"#, options: .regularExpression) {
                let name = String(line[m])
                    .replacingOccurrences(of: "create table public.", with: "")
                    .replacingOccurrences(of: " (", with: "")
                current = name
                tables[name] = []
                continue
            }
            guard let table = current else { continue }
            if line.hasPrefix(");") { current = nil; continue }
            let lower = line.lowercased()
            if line.isEmpty || line.hasPrefix("--") || lower.hasPrefix("primary key") || lower.hasPrefix("constraint")
                || lower.hasPrefix("unique") || lower.hasPrefix("foreign key") || lower.hasPrefix("check") {
                continue
            }
            let token = line.split(whereSeparator: { $0 == " " || $0 == "," }).first.map(String.init) ?? ""
            if !token.isEmpty { tables[table]?.append(token) }
        }
        return tables
    }

    // MARK: - (a) manifest ↔ DDL

    @Test("(a) toda columna del manifest de Grupos existe en supabase-groups-staging.ddl; extras = set conocido")
    func manifestCrossChecksGroupsSnapshot() throws {
        let manifest = try Self.loadManifest()
        let ddl = try Self.parseDDL()
        #expect(Set(manifest.tables.keys) == Self.groupTables, "tablas del manifest: \(manifest.tables.keys.sorted())")

        for (table, columns) in manifest.tables {
            guard let ddlColumns = ddl[table] else {
                Issue.record("tabla \(table) del manifest de Grupos ausente de supabase-groups-staging.ddl")
                continue
            }
            let ddlSet = Set(ddlColumns)
            for col in columns.keys {
                #expect(ddlSet.contains(col), "manifest \(table).\(col) no existe en supabase-groups-staging.ddl")
            }
            let allowed = Self.allowedNonManifest.union(Self.allowedNonManifestByTable[table] ?? [])
            let unexpected = ddlSet.subtracting(columns.keys).subtracting(allowed)
            #expect(unexpected.isEmpty,
                    "\(table): columnas del snapshot fuera del manifest y del set conocido: \(unexpected.sorted())")
        }
    }

    /// Control del parser: sin él, un DDL que el parser no supiera leer daría tablas vacías y (a) fallaría por el motivo
    /// equivocado — o, con el `guard` de arriba, por «tabla ausente». Fija que lee las cinco y una columna concreta.
    @Test("(a·control) el parser lee las 5 tablas y la columna del presupuesto")
    func ddlParserReadsTheGroupTables() throws {
        let ddl = try Self.parseDDL()
        for table in Self.groupTables {
            #expect((ddl[table]?.count ?? 0) > 5, "tabla \(table) sin columnas en el parser")
        }
        #expect(ddl["split_groups"]?.contains("budget_limit_amount") == true)
        #expect(ddl["split_groups"]?.contains("primary") == false)
    }

    // MARK: - (b) versiones

    @Test("(b) manifest_version == cliente; ningún since posterior; since del manifest == GroupsSyncCapability")
    func versionsMatchTheClient() throws {
        let manifest = try Self.loadManifest()
        #expect(manifest.version == GroupsSyncCapability.clientManifestVersion,
                "el manifest de Grupos va por v\(manifest.version) y el cliente entiende v\(GroupsSyncCapability.clientManifestVersion)")
        for (table, columns) in manifest.tables {
            for (col, meta) in columns {
                let since = (meta["since"] as? Int) ?? 1
                #expect(since <= manifest.version, "\(table).\(col) since \(since) > manifest_version \(manifest.version)")
                #expect(GroupsSyncCapability.since(table: table, column: col) == since,
                        "\(table).\(col): since \(since) en el manifest, \(GroupsSyncCapability.since(table: table, column: col)) en GroupsSyncCapability.columnSince")
            }
        }
        // Y al revés: `columnSince` no nombra columnas que el manifest no tiene.
        for (table, columns) in GroupsSyncCapability.columnSince {
            for col in columns.keys {
                #expect(manifest.tables[table]?[col] != nil, "columnSince nombra \(table).\(col), que no está en el manifest")
            }
        }
        #expect(GroupsSyncCapability.since(table: "split_groups", column: "budget_limit_amount") == 2)
    }

    // MARK: - (c) la trampa del drain

    @Test("(c) ningún emisor de Grupos lleva since propio: el drain los filtra con el nivel del canal personal")
    func groupEmittersCarryNoOwnSince() {
        let sinces: [(String, [Int])] = [
            (GroupMerkleProjection.splitGroup.table, GroupMerkleProjection.splitGroup.emitters.map(\.since)),
            (GroupMerkleProjection.groupMember.table, GroupMerkleProjection.groupMember.emitters.map(\.since)),
            (GroupMerkleProjection.splitExpense.table, GroupMerkleProjection.splitExpense.emitters.map(\.since)),
            (GroupMerkleProjection.splitShare.table, GroupMerkleProjection.splitShare.emitters.map(\.since)),
            (GroupMerkleProjection.splitSettlement.table, GroupMerkleProjection.splitSettlement.emitters.map(\.since)),
            (GroupEntityEmissionMap.splitGroup.table, GroupEntityEmissionMap.splitGroup.emitters.map(\.since)),
        ]
        for (table, values) in sinces {
            #expect(values.allSatisfy { $0 == 1 },
                    "\(table) tiene un emisor con since ≠ 1: el drain de Grupos llama a DeltaEmitter.emit con el nivel PERSONAL (ver GroupsSyncCapability)")
        }
    }

    // MARK: - (d) Merkle local por nivel

    @Test("(d) el payload Merkle de v1 no lleva budget_limit_amount; el de v2 sí, como null")
    func localMerklePayloadFollowsTheLevel() throws {
        let group = SplitGroup(name: "Viaje")
        group.budgetLimitAmount = nil
        let v1 = try GroupMerkleProjection.channel1Payload(
            model: group, emission: GroupMerkleProjection.splitGroup, capabilityLevel: 1)
        let v2 = try GroupMerkleProjection.channel1Payload(
            model: group, emission: GroupMerkleProjection.splitGroup, capabilityLevel: 2)
        #expect(!v1.contains("budget_limit_amount"))
        #expect(v2.contains("\"budget_limit_amount\":null"))
        // Lo demás no cambia: v1 es v2 sin esa key.
        #expect(v1.contains("\"name\":\"Viaje\""))
        #expect(v2.replacingOccurrences(of: "\"budget_limit_amount\":null,", with: "") == v1)
    }
}
