//
//  CloudCapabilityManifestParityTests.swift
//  YalaTests / CloudSync
//
//  Paridad del contrato de schema del Modo Nube (I5). Cruza tres artefactos que DEBEN converger o el
//  "número mal convertido" (d.4bis) reaparece en silencio:
//
//  (a) `capability_manifest.json` parsea y TODA columna declara EXACTAMENTE UNA de
//      {"safe": true (unidad singleton field-level) | "group_key": <money|split|budget> (grupo de
//      coherencia atómico)}. Sin default silencioso safe-by-omission: una columna nueva acoplada
//      olvidada FALLA el build (hardening d.4bis) en vez de volverse unidad independiente.
//  (b) Los 3 grupos de coherencia contienen EXACTAMENTE las columnas CONGELADAS (membresía
//      append-only, verificada en repo) — tanto en las declaraciones por-columna como en el bloque
//      `coherence_groups`. Un frozen set hardcodeado aquí es el árbitro (independiente del manifest).
//  (c) Cruce manifest ↔ `supabase-staging.ddl`: toda columna del manifest existe en su tabla del
//      snapshot; las columnas del snapshot fuera del manifest se permiten SOLO como set conocido
//      (server-authored + identidad).
//
//  Molde: CloudKitGroupsSchemaParityTests (#filePath → raíz del repo; el runner no empaqueta estos
//  archivos como resources). Ambos artefactos son CONTRATOS: se regeneran (qa/cloud/dump-schema.sh)
//  solo cuando el schema real cambia en staging.
//

import Foundation
import Testing

@Suite("CloudSync · capability manifest parity")
struct CloudCapabilityManifestParityTests {

    // MARK: - Frozen coherence groups (árbitro independiente del manifest; d.4bis, membresía CONGELADA)

    private static let frozenGroups: [String: (entity: String, columns: Set<String>)] = [
        "money": ("tx_items", [
            "amount", "amount_in_preferred_currency", "exchange_rate",
            "preferred_currency_code", "is_exchange_rate_provisional",
        ]),
        "split": ("scheduled_payments", [
            "amount", "split_type", "split_total_amount",
            "split_participant_ids_raw", "split_values_raw",
        ]),
        "budget": ("budgets", [
            "limit_amount", "currency_code", "natures",
            "subcategory_ids", "account_ids", "tag_refs",
        ]),
    ]

    /// Columnas server-authored + identidad: legítimas en el snapshot, NUNCA en el manifest.
    private static let allowedNonManifest: Set<String> = [
        "user_id", "sync_id", "server_seq", "hlc", "field_hlcs",
        "deleted", "deleted_hlc", "schema_version", "updated_at",
    ]

    private static let domainEntities: Set<String> = [
        "tx_items", "accounts", "categories", "subcategories", "tags", "budgets",
        "scheduled_payments", "inbox_drafts", "favorite_payments", "merchant_memory",
        "exchange_rates", "notification_items", "cashflow_plans", "cashflow_lines",
        "cashflow_overrides", "group_bridge_prefs",
    ]

    // MARK: - Paths (vía #filePath)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // YalaTests/CloudSync/
            .deletingLastPathComponent()   // YalaTests/
            .deletingLastPathComponent()   // repo root
    }
    private static var manifestURL: URL { repoRoot.appendingPathComponent("capability_manifest.json") }
    private static var ddlURL: URL { repoRoot.appendingPathComponent("supabase-staging.ddl") }

    // MARK: - Loaders / parsers

    private struct Manifest {
        let entities: [String: [String: [String: Any]]]      // entity -> column -> metadata
        let coherenceGroups: [String: (entity: String, columns: [String])]
    }

    private static func loadManifest() throws -> Manifest {
        let data = try Data(contentsOf: manifestURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure("capability_manifest.json no es un objeto JSON")
        }
        guard let entsRaw = root["entities"] as? [String: Any] else {
            throw Failure("manifest sin bloque `entities`")
        }
        var entities: [String: [String: [String: Any]]] = [:]
        for (ent, v) in entsRaw {
            guard let entObj = v as? [String: Any],
                  let cols = entObj["columns"] as? [String: Any] else {
                throw Failure("entidad \(ent) sin `columns`")
            }
            var colMap: [String: [String: Any]] = [:]
            for (col, meta) in cols {
                guard let m = meta as? [String: Any] else {
                    throw Failure("columna \(ent).\(col) sin metadata objeto")
                }
                colMap[col] = m
            }
            entities[ent] = colMap
        }
        var groups: [String: (entity: String, columns: [String])] = [:]
        if let cg = root["coherence_groups"] as? [String: Any] {
            for (g, v) in cg {
                guard let o = v as? [String: Any],
                      let e = o["entity"] as? String,
                      let c = o["columns"] as? [String] else {
                    throw Failure("coherence_groups.\(g) mal formado")
                }
                groups[g] = (e, c)
            }
        }
        return Manifest(entities: entities, coherenceGroups: groups)
    }

    /// Parsea `supabase-staging.ddl` → tabla -> columnas declaradas (en orden de aparición).
    private static func parseDDL() throws -> [String: [String]] {
        let src = try String(contentsOf: ddlURL, encoding: .utf8)
        var tables: [String: [String]] = [:]
        var current: String?
        for rawLine in src.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let m = line.range(of: #"^CREATE TABLE (\w+) \($"#, options: .regularExpression) {
                let name = String(line[m]).replacingOccurrences(of: "CREATE TABLE ", with: "")
                    .replacingOccurrences(of: " (", with: "")
                current = name
                tables[name] = []
                continue
            }
            guard let table = current else { continue }
            if line.hasPrefix(");") { current = nil; continue }
            if line.hasPrefix("PRIMARY KEY") || line.hasPrefix("CONSTRAINT") || line.isEmpty { continue }
            // primer token = nombre de columna
            let token = line.split(whereSeparator: { $0 == " " || $0 == "," }).first.map(String.init) ?? ""
            if !token.isEmpty { tables[table]?.append(token) }
        }
        return tables
    }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ d: String) { description = d }
    }

    // MARK: - (a) toda columna declara EXACTAMENTE una de {safe:true | group_key}

    @Test("(a) cada columna declara safe XOR group_key — sin default silencioso")
    func everyColumnDeclaresExactlyOne() throws {
        let manifest = try Self.loadManifest()
        let validGroups: Set<String> = ["money", "split", "budget"]
        for (ent, cols) in manifest.entities {
            for (col, meta) in cols {
                let hasSafe = (meta["safe"] as? Bool) == true
                let groupKey = meta["group_key"] as? String
                let hasGroup = groupKey != nil
                #expect(hasSafe != hasGroup,
                        "\(ent).\(col) debe declarar EXACTAMENTE una de {safe:true, group_key} (safe=\(hasSafe), group_key=\(groupKey ?? "nil"))")
                if let g = groupKey {
                    #expect(validGroups.contains(g), "\(ent).\(col) group_key inválido: \(g)")
                }
            }
        }
    }

    // MARK: - (b) grupos de coherencia == frozen sets (declaraciones por-columna Y bloque)

    @Test("(b) los 3 grupos de coherencia contienen EXACTAMENTE las columnas congeladas")
    func coherenceGroupsMatchFrozen() throws {
        let manifest = try Self.loadManifest()

        // Derivado de las declaraciones por-columna:
        var derived: [String: Set<String>] = ["money": [], "split": [], "budget": []]
        for (_, cols) in manifest.entities {
            for (col, meta) in cols {
                if let g = meta["group_key"] as? String { derived[g, default: []].insert(col) }
            }
        }
        for (g, frozen) in Self.frozenGroups {
            #expect(derived[g] == frozen.columns,
                    "grupo \(g): declaraciones por-columna \(derived[g] ?? []) != congelado \(frozen.columns)")
            // y todas viven en la entidad correcta
            for col in frozen.columns {
                #expect(manifest.entities[frozen.entity]?[col] != nil,
                        "\(frozen.entity).\(col) del grupo \(g) ausente del manifest")
            }
            // el bloque coherence_groups también coincide
            if let block = manifest.coherenceGroups[g] {
                #expect(Set(block.columns) == frozen.columns,
                        "bloque coherence_groups.\(g) \(Set(block.columns)) != congelado \(frozen.columns)")
                #expect(block.entity == frozen.entity,
                        "bloque coherence_groups.\(g).entity \(block.entity) != \(frozen.entity)")
            } else {
                Issue.record("coherence_groups.\(g) ausente del manifest")
            }
        }
    }

    // MARK: - (c) cruce manifest ↔ snapshot DDL

    @Test("(c) toda columna del manifest existe en el snapshot; extras del snapshot = set conocido")
    func manifestCrossChecksSnapshot() throws {
        let manifest = try Self.loadManifest()
        let ddl = try Self.parseDDL()

        for (ent, cols) in manifest.entities {
            guard let ddlCols = ddl[ent] else {
                Issue.record("entidad \(ent) del manifest ausente del snapshot DDL")
                continue
            }
            let ddlSet = Set(ddlCols)
            // toda columna del manifest existe en el snapshot
            for col in cols.keys {
                #expect(ddlSet.contains(col), "manifest \(ent).\(col) no existe en supabase-staging.ddl")
            }
            // columnas del snapshot fuera del manifest → SOLO server-authored + identidad
            let extras = ddlSet.subtracting(cols.keys)
            let unexpected = extras.subtracting(Self.allowedNonManifest)
            #expect(unexpected.isEmpty,
                    "\(ent): columnas del snapshot fuera del manifest y del set conocido: \(unexpected.sorted())")
        }
    }

    // MARK: - Sanidad: las 16 entidades de dominio están cubiertas por ambos artefactos

    @Test("(sanidad) las 16 entidades de dominio están en manifest y snapshot")
    func allDomainEntitiesCovered() throws {
        let manifest = try Self.loadManifest()
        let ddl = try Self.parseDDL()
        for ent in Self.domainEntities {
            #expect(manifest.entities[ent] != nil, "entidad de dominio \(ent) ausente del manifest")
            #expect(ddl[ent] != nil, "entidad de dominio \(ent) ausente del snapshot DDL")
        }
        #expect(manifest.entities.count == Self.domainEntities.count,
                "el manifest debe cubrir exactamente las 16 entidades de dominio, tiene \(manifest.entities.count)")
    }
}
