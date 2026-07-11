//
//  CKIdentityCapture.swift
//  Yala
//
//  Captura las coordenadas CloudKit `(recordName, zoneName, ownerName)` de cada fila `SyncIdentity`
//  MIENTRAS el mirror `NSPersistentCloudKitContainer` sigue vivo (Modo Nube Fase 4, I10-wiring w3).
//  Promoción a PRODUCCIÓN de la **Estrategia B (columnas)** device-verificada por `SpikeS5Harness`
//  (2026-07-09):
//
//   - SQLite READ-ONLY (`sqlite3_open_v2` + `SQLITE_OPEN_READONLY`) sobre el store personal → cero
//     interferencia con el mirror vivo (el 2º NSPersistentCloudKitContainer `record(for:)` fue REFUTADO;
//     el asset `ZSYSTEMFIELDSASSET` B2 no está disponible — NULL en device → NO se consulta).
//   - Correlación EXACTA del spike: URI `x-coredata://` del `PersistentIdentifier` → `(entityName, Z_PK)`;
//     `Z_PRIMARYKEY` (Z_NAME==entityName) → `Z_ENT`; `ANSCKRECORDMETADATA WHERE ZENTITYPK=zpk AND
//     ZENTITYID=zent` → `ZCKRECORDNAME` + FK `ZRECORDZONE` → zona por FK EXACTO (hay zonas SplitGroup-*
//     residuales delante de la default en las side-tables del store personal — hallazgo S5 punto 7).
//   - **`NULL ≠ sin-fila` (veredicto S5)**: metadata presente con `ZCKRECORDNAME=NULL` = export PENDIENTE
//     (distinguible de "sin metadata"). Resultado tri-estado por fila:
//     `captured` / `exportPending` / `noMetadata` / `failed`.
//   - Descubrimiento de tablas por `sqlite_master` (el schema interno es de Apple — no se hardcodean).
//   - Batch: UNA conexión por corrida, N lookups (no abrir/cerrar por fila).
//
//  Filas sin captura (exportPending/noMetadata/failed) NO bloquean la fase: `assigningIdentity` es
//  idempotente/re-ejecutable; una fila jamás exportada no tiene record que borrar en la reversa (nil
//  honesto, §b.5 born-cloud analogía). El save de las filas casadas lo hace el CALLER (mismo save del
//  backfill-step). La verificación contra el store REAL es device-only (ya la dio S5).
//
//  REGLA DEL REPO: NUNCA `try?` que silencia. Cada fila que no casa se clasifica tri-estado con motivo.
//

import CloudKit
import Foundation
import SQLite3
import SwiftData

@MainActor
enum CKIdentityCapture {

    // MARK: - Tri-estado por fila

    /// Resultado de la captura de UNA fila (tri-estado + fallo con motivo). `captured` lleva las 3
    /// coordenadas listas para reconstruir el `CKRecord.ID` en la reversa.
    enum RowOutcome: Equatable {
        case captured(recordName: String, zoneName: String, ownerName: String)
        /// Metadata PRESENTE pero `ZCKRECORDNAME=NULL` — export aún pendiente (≠ sin metadata).
        case exportPending
        /// No hay fila de metadata para `(Z_ENT, Z_PK)` — el mirror aún no creó metadata para este objeto.
        case noMetadata
        /// No se pudo resolver (URI no parseable / Z_ENT no encontrado / zona no resoluble). `reason` sin PII.
        case failed(reason: String)
    }

    /// Conteos agregados de una corrida (breadcrumb + panel).
    struct Report: Equatable {
        var captured = 0
        var exportPending = 0
        var noMetadata = 0
        var failed = 0

        var total: Int { captured + exportPending + noMetadata + failed }

        mutating func record(_ outcome: RowOutcome) {
            switch outcome {
            case .captured: captured += 1
            case .exportPending: exportPending += 1
            case .noMetadata: noMetadata += 1
            case .failed: failed += 1
            }
        }
    }

    // MARK: - Entrada pública (PersistentIdentifier → captura)

    /// Captura sobre `pairs` `(PersistentIdentifier de la fila de negocio, su fila testigo SyncIdentity)`.
    /// Extrae `(entityName, Z_PK)` del URI de cada `PersistentIdentifier`, abre UNA conexión SQLite
    /// READ-ONLY al `storeURL` y hace N lookups, escribiendo `ckRecordName/ckZoneName/ckOwnerName` en las
    /// filas CASADAS (el `save()` lo hace el caller). Devuelve el `Report` agregado.
    @discardableResult
    static func capture(
        _ pairs: [(id: PersistentIdentifier, row: SyncIdentity)],
        storeURL: URL? = nil
    ) -> Report {
        // Default MainActor-aislado resuelto en el cuerpo (no en el default arg, que es nonisolated).
        let resolvedStoreURL = storeURL ?? SwiftDataConfiguration.personalConfiguration.url
        // Resolver el URI → (entityName, Z_PK) por par; los no parseables se marcan failed sin abrir SQLite.
        var resolved: [ResolvedRequest] = []
        var report = Report()
        for pair in pairs {
            guard let uri = objectURI(for: pair.id), let parsed = parseCoreDataURI(uri) else {
                report.failed += 1
                continue
            }
            resolved.append(ResolvedRequest(entityName: parsed.entityName, zpk: parsed.zpk, row: pair.row))
        }
        guard !resolved.isEmpty else { return report }
        let batch = captureResolved(resolved, storeURL: resolvedStoreURL)
        report.captured += batch.captured
        report.exportPending += batch.exportPending
        report.noMetadata += batch.noMetadata
        report.failed += batch.failed
        return report
    }

    // MARK: - Núcleo (resuelto: entityName + Z_PK ya conocidos)

    /// Petición resuelta: la fila de negocio ya se localizó como `(entityName, Z_PK)` y trae su testigo.
    /// `internal` para que los tests fabriquen peticiones sin depender de un `PersistentIdentifier` real.
    struct ResolvedRequest {
        let entityName: String
        let zpk: Int64
        let row: SyncIdentity
    }

    /// Abre UNA conexión SQLite READ-ONLY, descubre las side-tables por `sqlite_master`, cachea el mapa
    /// `Z_NAME → Z_ENT` de `Z_PRIMARYKEY` UNA vez, y resuelve N peticiones. Escribe las coordenadas en las
    /// filas casadas (el caller saveea). Un fallo de apertura marca TODAS las peticiones `failed`.
    /// `internal` para tests (fixture SQLite fabricado a mano).
    @discardableResult
    static func captureResolved(_ requests: [ResolvedRequest], storeURL: URL) -> Report {
        var report = Report()
        guard !requests.isEmpty else { return report }

        var db: OpaquePointer?
        let openRC = sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil)
        guard openRC == SQLITE_OK, let db else {
            if let db { sqlite3_close(db) }
            for req in requests { req.row.applyOutcome(.failed(reason: "sqlite-open-\(openRC)")); report.failed += 1 }
            return report
        }
        defer { sqlite3_close(db) }

        // Descubrimiento de tablas (nombres exactos en runtime; el schema interno es de Apple).
        let ckTables = queryColumn(db, sql:
            "SELECT name FROM sqlite_master WHERE type='table' AND upper(name) LIKE '%CK%' ORDER BY name")
        guard let metaTable = ckTables.first(where: {
            let u = $0.uppercased()
            return u.contains("RECORDMETADATA") && !u.contains("ZONE") && !u.contains("SYSTEMFIELDS")
        }) else {
            for req in requests { req.row.applyOutcome(.failed(reason: "no-record-metadata-table")); report.failed += 1 }
            return report
        }
        let zoneTable = ckTables.first { $0.uppercased().contains("ZONEMETADATA") }

        // Columnas de la meta table (case-insensitive, exact-first).
        let metaCols = tableColumns(db, table: metaTable)
        func metaCol(_ needle: String) -> String? {
            metaCols.first { $0.uppercased() == needle } ?? metaCols.first { $0.uppercased().contains(needle) }
        }
        guard let entityPKCol = metaCol("ZENTITYPK"),
              let entityIDCol = metaCol("ZENTITYID"),
              let recNameCol = metaCol("ZCKRECORDNAME") else {
            for req in requests { req.row.applyOutcome(.failed(reason: "meta-columns-missing")); report.failed += 1 }
            return report
        }
        let zoneFKCol = metaCol("ZRECORDZONE")

        // Mapa Z_NAME → Z_ENT (Z_PRIMARYKEY) UNA vez. Vacío/no legible → cada lookup fallará por zent.
        let zentByEntity = loadPrimaryKeyMap(db)

        // Zona: columnas resueltas UNA vez (solo si hay tabla de zonas).
        var zoneNameCol: String?
        var zoneOwnerCol: String?
        if let zoneTable {
            let zoneCols = tableColumns(db, table: zoneTable)
            zoneNameCol = zoneCols.first { $0.uppercased().contains("ZONENAME") }
            zoneOwnerCol = zoneCols.first { $0.uppercased().contains("OWNER") }
        }

        for req in requests {
            let outcome = lookup(
                db, request: req, metaTable: metaTable,
                entityPKCol: entityPKCol, entityIDCol: entityIDCol, recNameCol: recNameCol,
                zoneFKCol: zoneFKCol, zoneTable: zoneTable, zoneNameCol: zoneNameCol, zoneOwnerCol: zoneOwnerCol,
                zentByEntity: zentByEntity)
            req.row.applyOutcome(outcome)
            report.record(outcome)
        }
        return report
    }

    /// Resuelve UNA petición contra la conexión abierta. Zona SIEMPRE por FK EXACTO (nunca la primera fila
    /// — había zonas SplitGroup delante de la default, S5 punto 7).
    private static func lookup(
        _ db: OpaquePointer, request: ResolvedRequest, metaTable: String,
        entityPKCol: String, entityIDCol: String, recNameCol: String,
        zoneFKCol: String?, zoneTable: String?, zoneNameCol: String?, zoneOwnerCol: String?,
        zentByEntity: [String: Int64]
    ) -> RowOutcome {
        // Match exacto primero; fallback case-insensitive (fidelidad al spike round 2 — una discrepancia
        // de caso entre el entityName del URI y Z_NAME no debe degradar a `failed`).
        guard let zent = zentByEntity[request.entityName]
            ?? zentByEntity.first(where: {
                $0.key.caseInsensitiveCompare(request.entityName) == .orderedSame
            })?.value
        else {
            return .failed(reason: "no-zent")
        }
        let zoneSel = zoneFKCol ?? "NULL"
        let sql = """
        SELECT \(recNameCol), \(zoneSel) FROM \(metaTable) \
        WHERE \(entityPKCol) = \(request.zpk) AND \(entityIDCol) = \(zent) LIMIT 1
        """
        let rows: [[SQLiteValue]]
        switch queryTypedRows(db, sql: sql) {
        case .failure(let msg):
            return .failed(reason: "meta-query:\(msg)")
        case .success(let r):
            rows = r
        }
        guard let row = rows.first, row.count >= 2 else {
            return .noMetadata  // no hay fila de metadata (≠ "sin recordName")
        }
        guard let recordName = row[0].textValue else {
            return .exportPending  // metadata PRESENTE pero recordName NULL → export pendiente
        }
        // Zona por FK exacto.
        guard let zoneFK = row[1].int64Value, let zoneTable, let zoneNameCol else {
            return .failed(reason: "zone-fk-missing")
        }
        let zoneSQL = "SELECT \(zoneNameCol)\(zoneOwnerCol.map { ", \($0)" } ?? "") FROM \(zoneTable) WHERE Z_PK = \(zoneFK)"
        switch queryTypedRows(db, sql: zoneSQL) {
        case .failure(let msg):
            return .failed(reason: "zone-query:\(msg)")
        case .success(let zoneRows):
            guard let zoneRow = zoneRows.first, let zoneName = zoneRow.first?.textValue else {
                return .failed(reason: "zone-unresolved")
            }
            let ownerName = (zoneRow.count > 1 ? zoneRow[1].textValue : nil) ?? CKCurrentUserDefaultName
            return .captured(recordName: recordName, zoneName: zoneName, ownerName: ownerName)
        }
    }

    /// Mapa `Z_NAME → Z_ENT` de `Z_PRIMARYKEY`. Vacío si la tabla no es legible.
    private static func loadPrimaryKeyMap(_ db: OpaquePointer) -> [String: Int64] {
        var map: [String: Int64] = [:]
        switch queryTypedRows(db, sql: "SELECT Z_ENT, Z_NAME FROM Z_PRIMARYKEY") {
        case .failure:
            return map
        case .success(let rows):
            for row in rows where row.count >= 2 {
                if let ent = row[0].int64Value, let name = row[1].textValue {
                    map[name] = ent
                }
            }
            return map
        }
    }

    // MARK: - Scan de metadata HUÉRFANA (§h residual, canario v1 SIN reparación)

    /// Conteos de un barrido read-only de la side-table de metadata: filas de metadata cuyo `(Z_ENT, Z_PK)`
    /// NO tiene fila viva en el store (zombie por History purgada con token vivo → ni tombstone en backend ni
    /// evento re-entregable). `scanned` ⊇ `orphans` (solo entidades presentes en `liveByEntityName`).
    struct OrphanScanReport: Equatable {
        var orphans = 0
        var scanned = 0
        var failed = 0
    }

    /// Barrido READ-ONLY de la side-table `ANSCKRECORDMETADATA` contra el set de filas VIVAS que aporta el
    /// caller (`liveByEntityName: [entityName: Set<Z_PK vivos>]`). Huérfano = fila de metadata de una entidad
    /// PRESENTE como key (las 16 entidades sync) cuyo `Z_PK` no está en su set de vivos. Metadata de entidades
    /// AUSENTES de las keys (modelos no cableados, p.ej. `CloudMigrationMarker`) se IGNORA (no es huérfana).
    /// `liveByEntityName` vacío = SIN SEÑAL (0/0/0, no "todo huérfano" — política explícita). NUNCA muta el
    /// store ni el SQLite; jamás `try?` silencioso (tri-estado con `failed`).
    static func scanOrphanMetadata(liveByEntityName: [String: Set<Int64>], storeURL: URL) -> OrphanScanReport {
        var report = OrphanScanReport()
        guard !liveByEntityName.isEmpty else { return report }  // sin señal → sin veredicto

        var db: OpaquePointer?
        let openRC = sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil)
        guard openRC == SQLITE_OK, let db else {
            if let db { sqlite3_close(db) }
            report.failed = 1
            return report
        }
        defer { sqlite3_close(db) }

        let ckTables = queryColumn(db, sql:
            "SELECT name FROM sqlite_master WHERE type='table' AND upper(name) LIKE '%CK%' ORDER BY name")
        guard let metaTable = ckTables.first(where: {
            let u = $0.uppercased()
            return u.contains("RECORDMETADATA") && !u.contains("ZONE") && !u.contains("SYSTEMFIELDS")
        }) else {
            report.failed = 1
            return report
        }
        let metaCols = tableColumns(db, table: metaTable)
        func metaCol(_ needle: String) -> String? {
            metaCols.first { $0.uppercased() == needle } ?? metaCols.first { $0.uppercased().contains(needle) }
        }
        guard let entityPKCol = metaCol("ZENTITYPK"), let entityIDCol = metaCol("ZENTITYID") else {
            report.failed = 1
            return report
        }

        // Z_ENT → entityName (invertido de `Z_PRIMARYKEY`). Vacío → cada fila cae a "sin nombre" → ignorada.
        var entityByZent: [Int64: String] = [:]
        for (name, ent) in loadPrimaryKeyMap(db) { entityByZent[ent] = name }

        switch queryTypedRows(db, sql: "SELECT \(entityIDCol), \(entityPKCol) FROM \(metaTable)") {
        case .failure:
            report.failed = 1
            return report
        case .success(let rows):
            for row in rows where row.count >= 2 {
                // NULL en Z_ENT/Z_PK (filas de bookkeeping de CloudKit) → no clasificable → ignorar.
                guard let zent = row[0].int64Value, let zpk = row[1].int64Value else { continue }
                guard let entityName = entityByZent[zent],
                      let liveSet = liveByEntityName[entityName] else { continue }  // fuera de las 16 → ignorar
                report.scanned += 1
                if !liveSet.contains(zpk) { report.orphans += 1 }
            }
            return report
        }
    }

    // MARK: - URI parsing

    /// Resuelve `(entityName, Z_PK)` de un `PersistentIdentifier` (URI `x-coredata://…` → parse). `internal`
    /// para que el caller construya el `liveByEntityName` de `scanOrphanMetadata` sin duplicar la extracción.
    static func entityAndPK(for id: PersistentIdentifier) -> (entityName: String, zpk: Int64)? {
        guard let uri = objectURI(for: id) else { return nil }
        return parseCoreDataURI(uri)
    }

    /// Parsea el URI `x-coredata://STORE-UUID/EntityName/pNNN` → `(entityName, Z_PK)`. `nil` = no parseable.
    /// `internal` para tests.
    static func parseCoreDataURI(_ uri: URL) -> (entityName: String, zpk: Int64)? {
        let comps = uri.pathComponents.filter { $0 != "/" }
        guard let lastComp = comps.last,
              let zpk = Int64(lastComp.drop(while: { !$0.isNumber })),
              let entityName = comps.dropLast().last else {
            return nil
        }
        return (entityName, zpk)
    }

    /// Extrae el URI `x-coredata://…` de un `PersistentIdentifier` vía JSON encode (búsqueda robusta del
    /// primer string que empiece por `x-coredata://`, tolerante a cambios de nombres de key — mismo patrón
    /// que `SpikeS5Harness.objectURI`).
    private static func objectURI(for id: PersistentIdentifier) -> URL? {
        guard let data = try? JSONEncoder().encode(id),
              let json = try? JSONSerialization.jsonObject(with: data),
              let uriString = findCoreDataURI(in: json) else { return nil }
        return URL(string: uriString)
    }

    private static func findCoreDataURI(in any: Any) -> String? {
        if let s = any as? String, s.hasPrefix("x-coredata://") { return s }
        if let dict = any as? [String: Any] {
            for value in dict.values { if let found = findCoreDataURI(in: value) { return found } }
        }
        if let arr = any as? [Any] {
            for value in arr { if let found = findCoreDataURI(in: value) { return found } }
        }
        return nil
    }

    // MARK: - SQLite helpers (promovidos de SpikeS5Harness — producción, no #if DEBUG)

    /// Valor tipado de una celda SQLite — NULL/int/text/blob distinguibles (clave: "recordName NULL" ≠
    /// "no hay fila").
    enum SQLiteValue: Equatable {
        case null
        case integer(Int64)
        case real(Double)
        case text(String)
        case blob(Data)

        var int64Value: Int64? { if case .integer(let i) = self { return i }; return nil }
        var textValue: String? { if case .text(let s) = self { return s }; return nil }
    }

    private struct SQLiteQueryError: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }

    /// Devuelve los valores de la PRIMERA columna de cada fila de un SELECT.
    private static func queryColumn(_ db: OpaquePointer, sql: String) -> [String] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) { out.append(String(cString: c)) }
        }
        return out
    }

    /// Todas las filas de un SELECT con valores tipados. `.failure` = errmsg de sqlite.
    private static func queryTypedRows(_ db: OpaquePointer, sql: String) -> Result<[[SQLiteValue]], SQLiteQueryError> {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return .failure(SQLiteQueryError(message: String(cString: sqlite3_errmsg(db))))
        }
        defer { sqlite3_finalize(stmt) }
        var out: [[SQLiteValue]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [SQLiteValue] = []
            for i in 0..<sqlite3_column_count(stmt) {
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_NULL:
                    row.append(.null)
                case SQLITE_INTEGER:
                    row.append(.integer(sqlite3_column_int64(stmt, i)))
                case SQLITE_FLOAT:
                    row.append(.real(sqlite3_column_double(stmt, i)))
                case SQLITE_BLOB:
                    if let ptr = sqlite3_column_blob(stmt, i) {
                        row.append(.blob(Data(bytes: ptr, count: Int(sqlite3_column_bytes(stmt, i)))))
                    } else {
                        row.append(.blob(Data()))
                    }
                default:
                    if let c = sqlite3_column_text(stmt, i) {
                        row.append(.text(String(cString: c)))
                    } else {
                        row.append(.null)
                    }
                }
            }
            out.append(row)
        }
        return .success(out)
    }

    /// Nombres de columna de una tabla vía PRAGMA table_info (el nombre viene de `sqlite_master`, no user input).
    private static func tableColumns(_ db: OpaquePointer, table: String) -> [String] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 1) { out.append(String(cString: c)) }
        }
        return out
    }
}

// MARK: - SyncIdentity write helper

private extension SyncIdentity {
    /// Escribe las coordenadas capturadas en la fila (solo `captured` muta; el resto NO toca la fila para no
    /// pisar una captura previa con NULLs). El caller saveea.
    func applyOutcome(_ outcome: CKIdentityCapture.RowOutcome) {
        guard case let .captured(recordName, zoneName, ownerName) = outcome else { return }
        ckRecordName = recordName
        ckZoneName = zoneName
        ckOwnerName = ownerName
    }
}
