//
//  SpikeS5Harness.swift
//  Yala
//
//  Harness DEBUG device-only del spike S5 (Modo Nube Fase 4). NO es código de producción:
//  vive entero bajo `#if DEBUG`, no se cablea a ningún path de la app ni al motor CloudSync, y
//  se invoca EXCLUSIVAMENTE desde la sección "Spike S5" del panel `CloudSyncDebugView` (DEV_BUILD).
//
//  Qué responde S5 (§b.5, cierre FATAL 1):
//   1. ¿Se puede obtener el `CKRecord.ID` COMPLETO (recordName + zoneName + ownerName) de una fila
//      SwiftData del store personal MIENTRAS el mirror `NSPersistentCloudKitContainer` está vivo?
//   2. ¿Ese `CKRecord.ID` RECONSTRUIDO (desde strings) localiza y BORRA el record en CloudKit?
//   3. ¿El zoneName es estable/predecible?
//
//  Dos estrategias, el harness prueba AMBAS y reporta cuál funciona (eso ES el veredicto):
//   A — 2º `NSPersistentCloudKitContainer` READ-ONLY sobre el MISMO sqlite personal + `record(for:)`.
//   B — conexión SQLite READ-ONLY (sqlite3 C API) leyendo las side-tables CK del store.
//
//  REGLA DEL REPO (harness): NUNCA `try?` que silencia. Aquí CADA error se CAPTURA y se DEVUELVE
//  como texto en el log del panel — mostrar el error verbatim ES el punto del spike.
//

#if DEBUG
import CloudKit
import CoreData
import Foundation
import SQLite3
import SwiftData

@MainActor
@Observable
final class SpikeS5Harness {

    // MARK: - Log

    /// Log acumulado que el panel muestra (monoespaciado, scrolleable). Cada línea con timestamp.
    private(set) var log: String = ""
    var isWorking = false

    // MARK: - Estado secuencial (gating de botones)

    /// PersistentIdentifier de la TX desechable creada en el paso 1. `nil` = no creada aún.
    private(set) var disposableID: PersistentIdentifier?
    /// CKRecord.ID capturado (de la estrategia que haya funcionado). Alimenta el delete del paso 3.
    private(set) var capturedRecordName: String?
    private(set) var capturedZoneName: String?
    private(set) var capturedOwnerName: String?
    /// Se marca tras intentar el delete (habilita el paso 4).
    private(set) var deleteAttempted = false

    var hasDisposable: Bool { disposableID != nil }
    var hasCapture: Bool { capturedRecordName != nil }

    // MARK: - Log helpers

    private func line(_ text: String) {
        let ts = Self.timestampFormatter.string(from: Date())
        log += "[\(ts)] \(text)\n"
    }

    private func section(_ title: String) {
        log += "\n──────── \(title) ────────\n"
    }

    func clearLog() {
        log = ""
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    // MARK: - Paso 1 · Crear TX desechable

    /// Crea una TX inequívoca (note "🧪 SPIKE-S5 — borrar", amount 0.01) sobre la PRIMERA cuenta
    /// disponible (o sin cuenta si no hay). Guarda su `persistentModelID`. El objeto real del owner
    /// jamás se toca.
    func createDisposable(context: ModelContext) {
        isWorking = true; defer { isWorking = false }
        section("PASO 1 · Crear TX desechable")
        do {
            let firstAccount = try context.fetch(FetchDescriptor<Account>()).first
            let tx = TransactionItem(
                date: .now,
                amount: 0.01,
                currencyCode: firstAccount?.currencyCode ?? "USD",
                note: "🧪 SPIKE-S5 — borrar",
                account: firstAccount
            )
            context.insert(tx)
            try context.save()
            disposableID = tx.persistentModelID
            // Reset captura previa: es una TX nueva.
            capturedRecordName = nil
            capturedZoneName = nil
            capturedOwnerName = nil
            deleteAttempted = false
            line("✅ TX creada y guardada. amount=0.01 cuenta=\(firstAccount?.name ?? "«sin cuenta»")")
            line("   persistentModelID capturado.")
            line("⏳ El mirror exporta en segundo plano. ESPERA 30-60s antes del paso 2 (el record")
            line("   no existe en CloudKit hasta que el export termine).")
        } catch {
            line("❌ Error creando la TX: \(error)")
        }
    }

    // MARK: - Paso 2 · Capturar IDs (A y B)

    /// Corre AMBAS estrategias sobre la TX desechable y reporta cuál devuelve el CKRecord.ID.
    func captureDisposable(context: ModelContext) async {
        guard let id = disposableID else {
            section("PASO 2 · Capturar IDs")
            line("⚠️ No hay TX desechable. Corre el paso 1 primero.")
            return
        }
        await capture(id: id, context: context, label: "TX desechable (paso 1)")
    }

    /// Captura sobre la TX MÁS ANTIGUA del store (corpus histórico). SOLO captura, jamás borra.
    func captureOldestExisting(context: ModelContext) async {
        section("EXTRA · Capturar sobre TX EXISTENTE (la más antigua)")
        isWorking = true
        var oldestID: PersistentIdentifier?
        do {
            var descriptor = FetchDescriptor<TransactionItem>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            descriptor.fetchLimit = 1
            oldestID = try context.fetch(descriptor).first?.persistentModelID
        } catch {
            line("❌ Error buscando la TX más antigua: \(error)")
        }
        isWorking = false
        guard let oldestID else {
            line("⚠️ No hay ninguna TX en el store para capturar.")
            return
        }
        line("ℹ️ Esta captura NO habilita el delete (protege datos reales). Solo lectura.")
        // Captura sin promover a `captured*` (para no armar un delete sobre una TX real).
        await capture(id: oldestID, context: context, label: "TX existente más antigua", promote: false)
    }

    /// Núcleo compartido: corre A y B, loguea todo y (si `promote`) guarda el resultado para el delete.
    private func capture(id: PersistentIdentifier, context: ModelContext, label: String, promote: Bool = true) async {
        isWorking = true; defer { isWorking = false }
        section("PASO 2 · Capturar IDs — \(label)")

        // El URI x-coredata:// del PersistentIdentifier alimenta AMBAS estrategias.
        guard let uri = Self.objectURI(for: id) else {
            line("❌ No pude extraer el URI x-coredata:// del PersistentIdentifier (JSON encode falló o")
            line("   sin campo uriRepresentation). Ambas estrategias dependen de este URI. Abortando captura.")
            return
        }
        line("🔗 objectID URI: \(uri.absoluteString)")

        // --- Estrategia A ---
        let resultA = captureViaSecondContainer(uri: uri)
        line("── Estrategia A (2º NSPersistentCloudKitContainer READ-ONLY) ──")
        for l in resultA.logLines { line("   \(l)") }

        // --- Estrategia B ---
        let resultB = captureViaRawSQLite(uri: uri)
        line("── Estrategia B (SQLite READ-ONLY, side-tables CK) ──")
        for l in resultB.logLines { line("   \(l)") }

        // --- Elegir ganador ---
        let winner = resultA.recordID ?? resultB.recordID
        if let winner {
            line("🎯 CAPTURA OK vía \(resultA.recordID != nil ? "A" : "B"): recordName=\(winner.recordName)")
            line("   zoneName=\(winner.zoneID.zoneName) ownerName=\(winner.zoneID.ownerName)")
            if promote {
                capturedRecordName = winner.recordName
                capturedZoneName = winner.zoneID.zoneName
                capturedOwnerName = winner.zoneID.ownerName
                deleteAttempted = false
                line("   → guardado para el delete del paso 3.")
            }
        } else {
            line("🔴 Ninguna estrategia obtuvo el CKRecord.ID con el mirror vivo.")
            if promote { line("   (paso 3 queda deshabilitado)") }
        }
    }

    // MARK: - Estrategia A · 2º NSPersistentCloudKitContainer read-only

    private struct CaptureResult {
        var recordID: CKRecord.ID?
        var logLines: [String]
    }

    /// Monta un `NSPersistentCloudKitContainer` propio sobre el MISMO sqlite personal con
    /// `NSReadOnlyPersistentStoreOption` + el containerIdentifier CloudKit personal, resuelve el
    /// `NSManagedObjectID` desde el URI y llama `recordID(for:)`/`record(for:)`.
    ///
    /// RIESGO CONOCIDO: un 2º container sobre el mismo store fue la causa del incidente Apple Pay
    /// (134410) — pero aquello era ESCRITOR; read-only es la hipótesis a validar. Si el load falla o
    /// avisa → veredicto negativo de la estrategia, capturado como texto (NO se fuerza, NO crashea).
    private func captureViaSecondContainer(uri: URL) -> CaptureResult {
        var lines: [String] = []
        let storeURL = SwiftDataConfiguration.personalConfiguration.url
        let ckID = SwiftDataConfiguration.cloudKitContainerIdentifier
        lines.append("store: \(storeURL.lastPathComponent)")
        lines.append("ckContainer: \(ckID)")

        // 1) Obtener un NSManagedObjectModel. SwiftData NO expone el suyo → mergedModel del bundle.
        //    Si el bundle no trae un .momd (esperado con SwiftData), el modelo sale vacío/nil y el
        //    load del store fallará → eso ES el hallazgo de la estrategia A.
        guard let model = NSManagedObjectModel.mergedModel(from: Bundle.allBundles), !model.entities.isEmpty else {
            lines.append("⛔️ No hay NSManagedObjectModel accesible (mergedModel vacío). SwiftData no")
            lines.append("    expone su modelo → un 2º NSPersistentCloudKitContainer no puede montar el")
            lines.append("    store. Estrategia A BLOQUEADA en esta plataforma (esperado con SwiftData).")
            return CaptureResult(recordID: nil, logLines: lines)
        }
        lines.append("modelo mergeado: \(model.entities.count) entidades")

        // 2) Montar el container read-only.
        let container = NSPersistentCloudKitContainer(name: "SpikeS5ReadOnly", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.setOption(true as NSNumber, forKey: NSReadOnlyPersistentStoreOption)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: ckID)
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            lines.append("⛔️ loadPersistentStores falló: \(loadError)")
            return CaptureResult(recordID: nil, logLines: lines)
        }
        lines.append("store cargado read-only OK")

        // 3) URI → NSManagedObjectID.
        let coordinator = container.persistentStoreCoordinator
        guard let objectID = coordinator.managedObjectID(forURIRepresentation: uri) else {
            lines.append("⛔️ managedObjectID(forURIRepresentation:) devolvió nil (store UUID / entidad no")
            lines.append("    casan con el modelo mergeado).")
            return CaptureResult(recordID: nil, logLines: lines)
        }
        lines.append("objectID resuelto")

        // 4) recordID(for:) y record(for:) — no lanzan, devuelven opcional.
        if let recordID = container.recordID(for: objectID) {
            lines.append("✅ recordID(for:) → \(recordID.recordName) @ \(recordID.zoneID.zoneName)")
            return CaptureResult(recordID: recordID, logLines: lines)
        }
        lines.append("recordID(for:) devolvió nil")
        if let record = container.record(for: objectID) {
            lines.append("✅ record(for:) → \(record.recordID.recordName) @ \(record.recordID.zoneID.zoneName)")
            return CaptureResult(recordID: record.recordID, logLines: lines)
        }
        lines.append("🔴 record(for:) también nil — el mirror read-only no tiene metadata para esta fila")
        return CaptureResult(recordID: nil, logLines: lines)
    }

    // MARK: - Estrategia B · SQLite read-only sobre las side-tables CK

    /// Abre el sqlite personal con `SQLITE_OPEN_READONLY`, lista tablas de `sqlite_master` que
    /// contengan "CK", vuelca zoneName/ownerName y trata de correlacionar el recordName de la fila
    /// vía Z_PK/entidad. Si el schema interno de Apple no lo permite limpio, reporta hasta dónde
    /// llegó — el reporte parcial ES un resultado del spike.
    private func captureViaRawSQLite(uri: URL) -> CaptureResult {
        var lines: [String] = []
        let storeURL = SwiftDataConfiguration.personalConfiguration.url

        // Parsear el URI: x-coredata://STORE-UUID/EntityName/pNNN
        let comps = uri.pathComponents.filter { $0 != "/" }
        let entityName = comps.dropLast().last // penúltimo componente
        let lastComp = comps.last ?? ""
        let zpk: Int64? = {
            let digits = lastComp.drop(while: { !$0.isNumber })
            return Int64(digits)
        }()
        lines.append("URI → entidad=\(entityName ?? "?") Z_PK=\(zpk.map(String.init) ?? "?")")

        var db: OpaquePointer?
        let openRC = sqlite3_open_v2(storeURL.path, &db, SQLITE_OPEN_READONLY, nil)
        guard openRC == SQLITE_OK, let db else {
            let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "rc \(openRC)"
            lines.append("⛔️ sqlite3_open_v2 READONLY falló: \(msg)")
            if let db { sqlite3_close(db) }
            return CaptureResult(recordID: nil, logLines: lines)
        }
        defer { sqlite3_close(db) }
        lines.append("sqlite abierto READONLY OK")

        // 1) Tablas que contengan "CK" (las side-tables del mirror).
        let ckTables = Self.queryColumn(db, sql:
            "SELECT name FROM sqlite_master WHERE type='table' AND upper(name) LIKE '%CK%' ORDER BY name")
        lines.append("tablas con 'CK': \(ckTables.isEmpty ? "«ninguna»" : ckTables.joined(separator: ", "))")

        // 2) Zone metadata: zoneName + ownerName (responde Q3 estabilidad del zoneName).
        //    El nombre exacto de la tabla se descubre en runtime; se prueban candidatos conocidos.
        var zoneName: String?
        var ownerName: String?
        for table in ckTables where table.uppercased().contains("ZONE") {
            let cols = Self.tableColumns(db, table: table)
            let zoneCol = cols.first { $0.uppercased().contains("ZONENAME") }
            let ownerCol = cols.first { $0.uppercased().contains("OWNER") }
            if let zoneCol {
                let sql = "SELECT \(zoneCol)\(ownerCol.map { ", \($0)" } ?? "") FROM \(table) LIMIT 8"
                let rows = Self.queryRows(db, sql: sql)
                lines.append("\(table): \(rows.count) fila(s) → \(rows.map { $0.joined(separator: "/") }.joined(separator: " | "))")
                if let first = rows.first {
                    zoneName = zoneName ?? first.first ?? nil
                    if ownerCol != nil, first.count > 1 { ownerName = ownerName ?? first[1] }
                }
            }
        }

        // 3) Record metadata: dump del schema + intento de correlación por Z_PK/entidad.
        var recordName: String?
        for table in ckTables where table.uppercased().contains("RECORDMETADATA") || table.uppercased().contains("METADATA") {
            if table.uppercased().contains("ZONE") { continue }
            let cols = Self.tableColumns(db, table: table)
            lines.append("\(table) columnas: \(cols.joined(separator: ", "))")
            let recNameCol = cols.first { $0.uppercased().contains("RECORDNAME") || $0.uppercased() == "ZCKRECORDNAME" }
            guard let recNameCol else { continue }

            // Correlación: buscar una columna entera que apunte al Z_PK de la fila fuente.
            if let zpk {
                // Candidatas: cualquier columna que no sea Z_PK/Z_ENT/Z_OPT y sea entera con el valor.
                for candidate in cols where candidate.hasPrefix("Z") && !["Z_PK", "Z_ENT", "Z_OPT"].contains(candidate) {
                    let sql = "SELECT \(recNameCol) FROM \(table) WHERE \(candidate) = \(zpk) LIMIT 4"
                    let hits = Self.queryColumn(db, sql: sql)
                    if let hit = hits.first, !hit.isEmpty {
                        recordName = hit
                        lines.append("✅ correlación por \(candidate)=\(zpk) → recordName=\(hit)")
                        break
                    }
                }
            }
            if recordName == nil {
                // Sin correlación limpia: muestra unas muestras para inspección manual.
                let samples = Self.queryColumn(db, sql: "SELECT \(recNameCol) FROM \(table) LIMIT 5")
                lines.append("sin correlación por Z_PK; muestras \(recNameCol): \(samples.joined(separator: ", "))")
            }
        }

        // 4) Veredicto de B.
        let resolvedOwner = ownerName ?? CKCurrentUserDefaultName
        if let recordName, let zoneName {
            let recordID = CKRecord.ID(
                recordName: recordName,
                zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: resolvedOwner)
            )
            lines.append("✅ B reconstruyó CKRecord.ID: \(recordName) @ \(zoneName) (owner \(resolvedOwner))")
            return CaptureResult(recordID: recordID, logLines: lines)
        }
        lines.append("🔴 B no reconstruyó el CKRecord.ID (recordName=\(recordName ?? "nil") zoneName=\(zoneName ?? "nil")).")
        return CaptureResult(recordID: nil, logLines: lines)
    }

    // MARK: - Paso 3 · Borrar de CloudKit (CKRecord.ID reconstruido desde strings)

    func deleteFromCloudKit() async {
        section("PASO 3 · Borrar de CloudKit")
        guard let recordName = capturedRecordName,
              let zoneName = capturedZoneName,
              let ownerName = capturedOwnerName else {
            line("⚠️ No hay CKRecord.ID capturado. Corre el paso 2 primero.")
            return
        }
        isWorking = true; defer { isWorking = false }

        // RECONSTRUCCIÓN desde strings (esto es lo que la reversa hará: no se usa el objeto capturado).
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let container = CKContainer(identifier: SwiftDataConfiguration.cloudKitContainerIdentifier)
        let db = container.privateCloudDatabase
        line("Reconstruido CKRecord.ID: \(recordName) @ \(zoneName) (owner \(ownerName))")

        do {
            let result = try await db.modifyRecords(saving: [], deleting: [recordID])
            deleteAttempted = true
            for (rid, res) in result.deleteResults {
                switch res {
                case .success:
                    line("✅ delete OK: \(rid.recordName)")
                case .failure(let error):
                    line("❌ delete falló para \(rid.recordName): \(error)")
                }
            }
            if result.deleteResults.isEmpty {
                line("⚠️ modifyRecords no reportó resultados de delete.")
            }
        } catch {
            deleteAttempted = true
            line("❌ modifyRecords lanzó: \(error)")
        }
    }

    // MARK: - Paso 4 · Verificar que el record ya no existe

    func verifyGone() async {
        section("PASO 4 · Verificar gone")
        guard let recordName = capturedRecordName,
              let zoneName = capturedZoneName,
              let ownerName = capturedOwnerName else {
            line("⚠️ No hay CKRecord.ID capturado.")
            return
        }
        isWorking = true; defer { isWorking = false }
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        let db = CKContainer(identifier: SwiftDataConfiguration.cloudKitContainerIdentifier).privateCloudDatabase
        do {
            let record = try await db.record(for: recordID)
            line("🔴 El record TODAVÍA existe: \(record.recordID.recordName). El delete no surtió efecto")
            line("   (o el server aún no lo propagó — reintenta en unos segundos).")
        } catch let ckError as CKError where ckError.code == .unknownItem {
            line("✅ CKError.unknownItem — el record fue borrado. VERIFICADO.")
        } catch {
            line("⚠️ fetch lanzó un error distinto de unknownItem: \(error)")
        }
    }

    // MARK: - Extra · Limpiar la TX local

    /// Borra la TX desechable del contexto LOCAL. Anota en el log si seguía viva (= el import del
    /// delete server-side no la propagó al store local — hallazgo del spike).
    func clearLocalDisposable(context: ModelContext) {
        section("EXTRA · Limpiar TX local")
        guard let id = disposableID else {
            line("⚠️ No hay TX desechable registrada.")
            return
        }
        isWorking = true; defer { isWorking = false }
        do {
            if let tx = context.model(for: id) as? TransactionItem {
                line("ℹ️ La TX local SEGUÍA viva (el import del delete no la quitó). La borro yo.")
                context.delete(tx)
                try context.save()
                line("✅ TX local borrada.")
            } else {
                line("✅ La TX local YA no existe (el import del delete la propagó, o nunca estuvo).")
            }
            disposableID = nil
        } catch {
            line("❌ Error borrando la TX local: \(error)")
        }
    }

    // MARK: - Helpers estáticos

    /// Extrae el URI `x-coredata://…` de un `PersistentIdentifier` vía JSON encode (búsqueda robusta
    /// del primer string que empiece por `x-coredata://`, tolerante a cambios de nombres de key).
    private static func objectURI(for id: PersistentIdentifier) -> URL? {
        guard let data = try? JSONEncoder().encode(id),
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        guard let uriString = findCoreDataURI(in: json) else { return nil }
        return URL(string: uriString)
    }

    private static func findCoreDataURI(in any: Any) -> String? {
        if let s = any as? String, s.hasPrefix("x-coredata://") { return s }
        if let dict = any as? [String: Any] {
            for value in dict.values {
                if let found = findCoreDataURI(in: value) { return found }
            }
        }
        if let arr = any as? [Any] {
            for value in arr {
                if let found = findCoreDataURI(in: value) { return found }
            }
        }
        return nil
    }

    /// Devuelve los valores de la PRIMERA columna de cada fila de un SELECT.
    private static func queryColumn(_ db: OpaquePointer, sql: String) -> [String] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) {
                out.append(String(cString: c))
            } else {
                out.append("")
            }
        }
        return out
    }

    /// Devuelve todas las filas (todas las columnas como String) de un SELECT.
    private static func queryRows(_ db: OpaquePointer, sql: String) -> [[String]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [[String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let count = sqlite3_column_count(stmt)
            var row: [String] = []
            for i in 0..<count {
                if let c = sqlite3_column_text(stmt, i) {
                    row.append(String(cString: c))
                } else {
                    row.append("∅")
                }
            }
            out.append(row)
        }
        return out
    }

    /// Nombres de columna de una tabla vía PRAGMA table_info.
    private static func tableColumns(_ db: OpaquePointer, table: String) -> [String] {
        // PRAGMA no acepta binding; el nombre viene de sqlite_master (no user input).
        queryColumnAt(db, sql: "PRAGMA table_info(\(table))", columnIndex: 1)
    }

    private static func queryColumnAt(_ db: OpaquePointer, sql: String, columnIndex: Int32) -> [String] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, columnIndex) {
                out.append(String(cString: c))
            }
        }
        return out
    }
}
#endif
