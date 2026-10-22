//
//  EntityEmissionParityTests.swift
//  YalaTests / CloudSync
//
//  Paridad del EMISOR (I8c): `EntityEmissionMap` ↔ `capability_manifest.json` ↔ `supabase-staging.ddl`.
//  Si el emisor y el manifest divergen, el delta subiría con columnas equivocadas (o se olvidaría una) en
//  silencio → "número mal convertido" (§d.4bis). Ancla, por tabla:
//
//  (a) el set de columnas EMITIDAS == el set de columnas del manifest (ni de más ni de menos) — salvo
//      server-authored/identidad, que el manifest ya excluye.
//  (b) el `group_key` de cada columna emitida == el del manifest (money/split/budget/tx_split).
//  (c) toda columna emitida existe en el snapshot DDL (nunca se emite una columna inexistente).
//  (d) el emisor cubre EXACTAMENTE las 16 entidades de dominio.
//
//  Molde: CloudCapabilityManifestParityTests (#filePath → raíz del repo; el runner no empaqueta los
//  artefactos como resources).
//

import Foundation
import Testing

@testable import Yala

@Suite("CloudSync · EntityEmissionMap parity (I8c)")
@MainActor
struct EntityEmissionParityTests {

    // MARK: - Paths / loaders (espejo del molde)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // YalaTests/CloudSync/
            .deletingLastPathComponent()   // YalaTests/
            .deletingLastPathComponent()   // repo root
    }
    private static var manifestURL: URL { repoRoot.appendingPathComponent("capability_manifest.json") }
    private static var ddlURL: URL { repoRoot.appendingPathComponent("supabase-staging.ddl") }

    private struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ d: String) { description = d }
    }

    /// table -> (column -> group_key?) del manifest.
    private static func loadManifestColumns() throws -> [String: [String: String?]] {
        let data = try Data(contentsOf: manifestURL)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ents = root["entities"] as? [String: Any] else {
            throw Failure("capability_manifest.json mal formado")
        }
        var out: [String: [String: String?]] = [:]
        for (table, v) in ents {
            guard let obj = v as? [String: Any], let cols = obj["columns"] as? [String: Any] else {
                throw Failure("entidad \(table) sin columns")
            }
            var colMap: [String: String?] = [:]
            for (col, meta) in cols {
                let m = meta as? [String: Any]
                colMap[col] = m?["group_key"] as? String
            }
            out[table] = colMap
        }
        return out
    }

    /// table -> [columnas] del snapshot DDL (mismo parser que el molde).
    private static func parseDDL() throws -> [String: Set<String>] {
        let src = try String(contentsOf: ddlURL, encoding: .utf8)
        var tables: [String: Set<String>] = [:]
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
            let token = line.split(whereSeparator: { $0 == " " || $0 == "," }).first.map(String.init) ?? ""
            if !token.isEmpty { tables[table, default: []].insert(token) }
        }
        return tables
    }

    // MARK: - (a) columnas emitidas == columnas del manifest, por tabla

    @Test("(a) el emisor emite EXACTAMENTE las columnas del manifest, por tabla")
    func emittedColumns_matchManifest() throws {
        let manifest = try Self.loadManifestColumns()
        let catalog = EntityEmissionMap.catalog
        for (table, cols) in manifest {
            guard let emitted = catalog[table]?.columns else {
                Issue.record("tabla \(table) del manifest SIN emisor en EntityEmissionMap")
                continue
            }
            let manifestCols = Set(cols.keys)
            #expect(emitted == manifestCols,
                    "\(table): emitidas \(emitted.sorted()) != manifest \(manifestCols.sorted())")
        }
    }

    // MARK: - (b) group_key de cada columna emitida == manifest

    @Test("(b) el group_key de cada columna emitida coincide con el manifest")
    func emittedGroups_matchManifest() throws {
        let manifest = try Self.loadManifestColumns()
        let catalog = EntityEmissionMap.catalog
        for (table, cols) in manifest {
            let emittedGroups = catalog[table]?.groups ?? [:]
            for (col, manifestGroup) in cols {
                let emittedGroup = emittedGroups[col]
                #expect(emittedGroup == manifestGroup,
                        "\(table).\(col): group emitido \(emittedGroup ?? "nil") != manifest \(manifestGroup ?? "nil")")
            }
        }
    }

    // MARK: - (c) ninguna columna emitida está fuera del snapshot DDL

    @Test("(c) toda columna emitida existe en supabase-staging.ddl")
    func emittedColumns_existInDDL() throws {
        let ddl = try Self.parseDDL()
        for (table, entry) in EntityEmissionMap.catalog {
            guard let ddlCols = ddl[table] else {
                Issue.record("tabla \(table) del emisor ausente del snapshot DDL")
                continue
            }
            for col in entry.columns {
                #expect(ddlCols.contains(col), "columna emitida \(table).\(col) no existe en la DDL")
            }
        }
    }

    // MARK: - (d) cobertura EXACTA de las 16 entidades de dominio

    @Test("(d) el emisor cubre exactamente las 16 tablas del manifest")
    func catalog_coversAllDomainEntities() throws {
        let manifest = try Self.loadManifestColumns()
        let catalog = EntityEmissionMap.catalog
        #expect(Set(catalog.keys) == Set(manifest.keys),
                "emisor \(catalog.keys.sorted()) != manifest \(manifest.keys.sorted())")
        #expect(catalog.count == 16, "el emisor debe cubrir 16 entidades, tiene \(catalog.count)")
    }
}
