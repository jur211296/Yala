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

    /// Note inequívoca de la TX desechable — también es la LLAVE para re-encontrarla tras relaunch.
    static let disposableNote = "🧪 SPIKE-S5 — borrar"

    /// Re-encuentra la TX desechable de un run anterior (el estado @Observable no sobrevive al
    /// relaunch de la app, pero la TX sigue viva en el store). Permite ir DIRECTO al paso 2.
    /// Llamado desde el `.task` del panel; no-op si ya hay una registrada en esta sesión.
    func recoverDisposableIfNeeded(context: ModelContext) {
        guard disposableID == nil else { return }
        do {
            let note = Self.disposableNote
            var descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { $0.note == note },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            if let tx = try context.fetch(descriptor).first {
                disposableID = tx.persistentModelID
                line("♻️ TX desechable re-encontrada de un run anterior (note \(note)).")
                line("   Puedes ir DIRECTO al paso 2 — o crear otra con el paso 1, sin romper el estado.")
            }
        } catch {
            line("❌ Error re-buscando la TX desechable: \(error)")
        }
    }

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
                note: Self.disposableNote,
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
            let source = resultA.recordID != nil ? (resultA.source ?? "A") : (resultB.source ?? "B")
            line("🎯 CAPTURA OK vía \(source): recordName=\(winner.recordName)")
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
        /// Etiqueta de la fuente ganadora ("A", "B2 (CKRecord desarchivado)", "B (columnas)").
        var source: String?
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
            return CaptureResult(recordID: recordID, logLines: lines, source: "A")
        }
        lines.append("recordID(for:) devolvió nil")
        if let record = container.record(for: objectID) {
            lines.append("✅ record(for:) → \(record.recordID.recordName) @ \(record.recordID.zoneID.zoneName)")
            return CaptureResult(recordID: record.recordID, logLines: lines, source: "A")
        }
        lines.append("🔴 record(for:) también nil — el mirror read-only no tiene metadata para esta fila")
        return CaptureResult(recordID: nil, logLines: lines)
    }

    // MARK: - Estrategia B · SQLite read-only sobre las side-tables CK (round 2)

    /// Round 2 (post primer run en device — los datos ESTÁN en `ANSCKRECORDMETADATA`):
    ///  1. Correlación correcta: `WHERE ZENTITYPK = <Z_PK del URI> AND ZENTITYID = <Z_ENT de
    ///     Z_PRIMARYKEY por nombre de entidad>` (nunca más el barrido ciego de columnas).
    ///  2. Zona por FK (`ZRECORDZONE` → fila exacta de la tabla de zonas). NUNCA la primera fila
    ///     (el primer run demostró que hay zonas SplitGroup delante de la default).
    ///  3. **B2**: de la fila casada, seguir `ZSYSTEMFIELDSASSET` → blob NSKeyedArchiver → `CKRecord`
    ///     desarchivado (mismo patrón que `CKRecordTranslator.recordFromSystemFields` de Grupos) →
    ///     `record.recordID` COMPLETO sin reconstruir nada. B2 es la fuente PREFERIDA.
    /// Si el schema interno no lo permite limpio, reporta hasta dónde llegó (diagnóstico incondicional
    /// del mapeo ZENTITYPK incluido) — el reporte parcial ES un resultado del spike.
    private func captureViaRawSQLite(uri: URL) -> CaptureResult {
        var lines: [String] = []
        let storeURL = SwiftDataConfiguration.personalConfiguration.url

        // Parsear el URI: x-coredata://STORE-UUID/EntityName/pNNN
        let comps = uri.pathComponents.filter { $0 != "/" }
        let lastComp = comps.last ?? ""
        let parsedZPK = Int64(lastComp.drop(while: { !$0.isNumber }))
        guard let entityName = comps.dropLast().last, let zpk = parsedZPK else {
            lines.append("⛔️ URI no parseable (entidad/Z_PK): \(uri.absoluteString)")
            return CaptureResult(recordID: nil, logLines: lines)
        }
        lines.append("URI → entidad=\(entityName) Z_PK=\(zpk)")

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

        // 1) Descubrir las 3 side-tables (nombres exactos en runtime).
        let ckTables = Self.queryColumn(db, sql:
            "SELECT name FROM sqlite_master WHERE type='table' AND upper(name) LIKE '%CK%' ORDER BY name")
        lines.append("tablas con 'CK': \(ckTables.isEmpty ? "«ninguna»" : ckTables.joined(separator: ", "))")
        guard let metaTable = ckTables.first(where: {
            let u = $0.uppercased()
            return u.contains("RECORDMETADATA") && !u.contains("ZONE") && !u.contains("SYSTEMFIELDS")
        }) else {
            lines.append("⛔️ No encontré la tabla de record-metadata (…RECORDMETADATA). B no puede seguir.")
            return CaptureResult(recordID: nil, logLines: lines)
        }
        let zoneTable = ckTables.first { $0.uppercased().contains("ZONEMETADATA") }
        let assetTable = ckTables.first { $0.uppercased().contains("SYSTEMFIELDS") }
        lines.append("meta=\(metaTable) zona=\(zoneTable ?? "«no encontrada»") asset=\(assetTable ?? "«no encontrada»")")

        // 2) Columnas de la meta table (case-insensitive, exact-first).
        let metaCols = Self.tableColumns(db, table: metaTable)
        lines.append("\(metaTable) columnas: \(metaCols.joined(separator: ", "))")
        func metaCol(_ needle: String) -> String? {
            metaCols.first { $0.uppercased() == needle } ?? metaCols.first { $0.uppercased().contains(needle) }
        }
        guard let entityPKCol = metaCol("ZENTITYPK"),
              let entityIDCol = metaCol("ZENTITYID"),
              let recNameCol = metaCol("ZCKRECORDNAME") else {
            lines.append("⛔️ Faltan columnas esperadas (ZENTITYPK/ZENTITYID/ZCKRECORDNAME) — schema distinto.")
            return CaptureResult(recordID: nil, logLines: lines)
        }
        let zoneFKCol = metaCol("ZRECORDZONE")
        let assetFKCol = metaCol("ZSYSTEMFIELDSASSET")

        // 3) Z_ENT de la entidad vía Z_PRIMARYKEY (exact → case-insensitive → dump).
        var zent: Int64?
        switch Self.queryTypedRows(db, sql: "SELECT Z_ENT, Z_NAME FROM Z_PRIMARYKEY") {
        case .failure(let msg):
            lines.append("⚠️ Z_PRIMARYKEY no legible: \(msg)")
        case .success(let rows):
            if let exact = rows.first(where: { $0.count >= 2 && $0[1].textValue == entityName }) {
                zent = exact[0].int64Value
                lines.append("Z_PRIMARYKEY: '\(entityName)' → Z_ENT=\(zent.map(String.init) ?? "?")")
            } else {
                lines.append("Z_PRIMARYKEY sin match EXACTO para '\(entityName)'. Dump (Z_ENT=Z_NAME):")
                lines.append("   " + rows.map { "\($0.first?.describe ?? "?")=\($0.count > 1 ? $0[1].describe : "?")" }
                    .joined(separator: ", "))
                if let ci = rows.first(where: {
                    $0.count >= 2 && $0[1].textValue?.caseInsensitiveCompare(entityName) == .orderedSame
                }) {
                    zent = ci[0].int64Value
                    lines.append("match case-insensitive → Z_ENT=\(zent.map(String.init) ?? "?")")
                }
            }
        }

        // 4) DIAGNÓSTICO incondicional: qué hay en la meta table para este ZENTITYPK (sin filtro de
        //    entidad) — muestra el mapeo real aunque la query principal no case.
        switch Self.queryTypedRows(db, sql:
            "SELECT \(entityIDCol), \(recNameCol) FROM \(metaTable) WHERE \(entityPKCol) = \(zpk)") {
        case .failure(let msg):
            lines.append("⚠️ diagnóstico ZENTITYPK falló: \(msg)")
        case .success(let rows):
            lines.append("diagnóstico: \(rows.count) fila(s) en \(metaTable) con \(entityPKCol)=\(zpk) (sin filtro de entidad):")
            for r in rows {
                lines.append("   (\(entityIDCol)=\(r.first?.describe ?? "?"), \(recNameCol)=\(r.count > 1 ? r[1].describe : "?"))")
            }
        }

        guard let zent else {
            lines.append("🔴 Sin Z_ENT para '\(entityName)' — no puedo filtrar por entidad (mira el diagnóstico de arriba).")
            return CaptureResult(recordID: nil, logLines: lines)
        }

        // 5) Fila casada: la query principal.
        let zoneSel = zoneFKCol ?? "NULL"
        let assetSel = assetFKCol ?? "NULL"
        let mainSQL = """
        SELECT Z_PK, \(recNameCol), \(zoneSel), \(assetSel) FROM \(metaTable) \
        WHERE \(entityPKCol) = \(zpk) AND \(entityIDCol) = \(zent) LIMIT 4
        """
        var metaPK: Int64?
        var recordName: String?
        var zoneFK: Int64?
        var assetFK: Int64?
        switch Self.queryTypedRows(db, sql: mainSQL) {
        case .failure(let msg):
            lines.append("⛔️ query principal falló: \(msg)")
            return CaptureResult(recordID: nil, logLines: lines)
        case .success(let rows):
            guard let row = rows.first, row.count >= 4 else {
                lines.append("🔴 NO hay fila de metadata para (Z_ENT=\(zent), Z_PK=\(zpk)) — el mirror aún no")
                lines.append("   creó metadata para este objeto (distinto de 'sin recordName').")
                return CaptureResult(recordID: nil, logLines: lines)
            }
            if rows.count > 1 { lines.append("⚠️ \(rows.count) filas casaron — uso la primera.") }
            metaPK = row[0].int64Value
            recordName = row[1].textValue
            zoneFK = row[2].int64Value
            assetFK = row[3].int64Value
            if recordName == nil {
                lines.append("⚠️ metadata EXISTE pero sin recordName (\(recNameCol)=NULL) — export PENDIENTE.")
                lines.append("   Espera 30-60s más y reintenta el paso 2.")
            } else {
                lines.append("✅ fila casada: metaZ_PK=\(metaPK.map(String.init) ?? "?") recordName=\(recordName ?? "?")")
            }
            lines.append("   \(zoneSel)=\(zoneFK.map(String.init) ?? "NULL") \(assetSel)=\(assetFK.map(String.init) ?? "NULL")")
        }

        // 6) Zona por FK — fila EXACTA, nunca la primera (había zonas SplitGroup delante).
        var zoneName: String?
        var ownerName: String?
        if let zoneTable, let zoneFK {
            let zoneCols = Self.tableColumns(db, table: zoneTable)
            lines.append("\(zoneTable) columnas: \(zoneCols.joined(separator: ", "))")
            let zNameCol = zoneCols.first { $0.uppercased().contains("ZONENAME") }
            let zOwnerCol = zoneCols.first { $0.uppercased().contains("OWNER") }
            if let zNameCol {
                let sql = "SELECT \(zNameCol)\(zOwnerCol.map { ", \($0)" } ?? "") FROM \(zoneTable) WHERE Z_PK = \(zoneFK)"
                switch Self.queryTypedRows(db, sql: sql) {
                case .failure(let msg):
                    lines.append("⚠️ lookup de zona falló: \(msg)")
                case .success(let rows):
                    if let row = rows.first {
                        zoneName = row.first?.textValue
                        if row.count > 1 { ownerName = row[1].textValue }
                        lines.append("zona por FK Z_PK=\(zoneFK): zoneName=\(zoneName ?? "NULL") owner=\(ownerName ?? "NULL")")
                    } else {
                        lines.append("⚠️ no hay fila de zona con Z_PK=\(zoneFK) en \(zoneTable).")
                    }
                }
            } else {
                lines.append("⚠️ \(zoneTable) sin columna *ZONENAME* — no puedo resolver la zona por columnas.")
            }
        } else if zoneFK == nil {
            lines.append("⚠️ FK de zona NULL (o columna \(zoneSel) inexistente) — sin zona por columnas.")
            lines.append("   (NO se usa el fallback a la primera fila — eso borró la señal en el round 1.)")
        }

        // 7) B2 — la fuente MÁS robusta: CKRecord desarchivado del system-fields asset.
        var b2RecordID: CKRecord.ID?
        if let assetTable, let assetFK {
            b2RecordID = Self.unarchiveSystemFieldsRecord(
                db, assetTable: assetTable, assetFK: assetFK, metaPK: metaPK,
                storeURL: storeURL, lines: &lines
            )
        } else if assetFK == nil {
            lines.append("B2: \(assetSel)=NULL — sin system-fields asset todavía (export pendiente probable).")
        } else {
            lines.append("B2: tabla de system-fields asset no encontrada entre las tablas CK.")
        }

        // 8) Veredicto de B: preferir B2 (CKRecord desarchivado), caer a columnas.
        if let b2RecordID {
            lines.append("✅ B2 (preferido) → recordName=\(b2RecordID.recordName) zoneName=\(b2RecordID.zoneID.zoneName) owner=\(b2RecordID.zoneID.ownerName)")
            return CaptureResult(recordID: b2RecordID, logLines: lines, source: "B2 (CKRecord desarchivado)")
        }
        if let recordName, let zoneName {
            let resolvedOwner = ownerName ?? CKCurrentUserDefaultName
            let recordID = CKRecord.ID(
                recordName: recordName,
                zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: resolvedOwner)
            )
            lines.append("✅ B (columnas) reconstruyó: \(recordName) @ \(zoneName) (owner \(resolvedOwner))")
            return CaptureResult(recordID: recordID, logLines: lines, source: "B (columnas)")
        }
        lines.append("🔴 B no reconstruyó el CKRecord.ID (recordName=\(recordName ?? "nil") zoneName=\(zoneName ?? "nil")).")
        return CaptureResult(recordID: nil, logLines: lines)
    }

    /// B2: sigue el FK `ZSYSTEMFIELDSASSET` a la tabla de assets, toma `ZBINARYDATA` (o reporta el
    /// asset externo) y desarchiva un `CKRecord` con NSKeyedUnarchiver — mismo patrón que
    /// `CKRecordTranslator.recordFromSystemFields` (Grupos), pero con cada error VERBATIM al log.
    private static func unarchiveSystemFieldsRecord(
        _ db: OpaquePointer, assetTable: String, assetFK: Int64, metaPK: Int64?,
        storeURL: URL, lines: inout [String]
    ) -> CKRecord.ID? {
        let assetCols = tableColumns(db, table: assetTable)
        lines.append("B2: \(assetTable) columnas: \(assetCols.joined(separator: ", "))")
        let binCol = assetCols.first { $0.uppercased() == "ZBINARYDATA" }
            ?? assetCols.first { $0.uppercased().contains("BINARYDATA") && !$0.uppercased().contains("EXTERNAL") }
        let extCol = assetCols.first { $0.uppercased().contains("EXTERNALBINARYDATA") }
        let recFKCol = assetCols.first { $0.uppercased() == "ZRECORD" }
        guard binCol != nil || extCol != nil else {
            lines.append("B2 ⛔️: sin columnas ZBINARYDATA/ZEXTERNALBINARYDATA — schema distinto.")
            return nil
        }

        // Fila del asset: primero por Z_PK = FK; fallback por ZRECORD = Z_PK de la meta row.
        let selCols = [binCol ?? "NULL", extCol ?? "NULL"].joined(separator: ", ")
        var assetRow: [SQLiteValue]?
        switch queryTypedRows(db, sql: "SELECT \(selCols) FROM \(assetTable) WHERE Z_PK = \(assetFK)") {
        case .failure(let msg): lines.append("B2 ⚠️: query por Z_PK=\(assetFK) falló: \(msg)")
        case .success(let rows):
            assetRow = rows.first
            if assetRow != nil { lines.append("B2: fila del asset por Z_PK=\(assetFK)") }
        }
        if assetRow == nil, let recFKCol, let metaPK {
            switch queryTypedRows(db, sql: "SELECT \(selCols) FROM \(assetTable) WHERE \(recFKCol) = \(metaPK)") {
            case .failure(let msg): lines.append("B2 ⚠️: query por \(recFKCol)=\(metaPK) falló: \(msg)")
            case .success(let rows):
                assetRow = rows.first
                if assetRow != nil { lines.append("B2: fila del asset por \(recFKCol)=\(metaPK)") }
            }
        }
        guard let assetRow, assetRow.count >= 2 else {
            lines.append("B2 🔴: no encontré la fila del asset (ni por Z_PK ni por ZRECORD).")
            return nil
        }

        // Blob: inline (ZBINARYDATA) o externo en disco (ZEXTERNALBINARYDATA).
        var blob = assetRow[0].blobValue
        if blob == nil || blob?.isEmpty == true {
            let extValue = assetRow[1]
            lines.append("B2: ZBINARYDATA=NULL/vacío; ZEXTERNALBINARYDATA=\(extValue.describe)")
            // Core Data guarda assets externos en <dir>/.<storeBase>_SUPPORT/_EXTERNAL_DATA/<ref>.
            let base = storeURL.deletingPathExtension().lastPathComponent
            let externalDir = storeURL.deletingLastPathComponent()
                .appendingPathComponent(".\(base)_SUPPORT/_EXTERNAL_DATA", isDirectory: true)
            lines.append("B2: patrón esperado del asset externo: \(externalDir.path)/<ref>")
            let ref: String? = extValue.textValue
                ?? extValue.blobValue.map { $0.map { String(format: "%02x", $0) }.joined() }
            if let ref {
                let fileURL = externalDir.appendingPathComponent(ref)
                do {
                    blob = try Data(contentsOf: fileURL)
                    lines.append("B2: asset externo LEÍDO (\(blob?.count ?? 0) bytes) desde \(fileURL.lastPathComponent)")
                } catch {
                    lines.append("B2 ⚠️: no pude leer el asset externo en \(fileURL.path): \(error)")
                }
            }
        }
        guard let blob, !blob.isEmpty else {
            lines.append("B2 🔴: sin blob que desarchivar.")
            return nil
        }
        lines.append("B2: blob de \(blob.count) bytes")

        // Desarchivar como CKRecord (system fields). Si falla: magic number en hex para diagnóstico.
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: blob)
            unarchiver.requiresSecureCoding = true
            if let record = CKRecord(coder: unarchiver) {
                unarchiver.finishDecoding()
                lines.append("B2 ✅: CKRecord desarchivado — recordType=\(record.recordType)")
                return record.recordID
            }
            unarchiver.finishDecoding()
            lines.append("B2 🔴: CKRecord(coder:) devolvió nil. Primeros bytes: \(hexPrefix(blob))")
        } catch {
            lines.append("B2 🔴: NSKeyedUnarchiver lanzó: \(error)")
            lines.append("B2: primeros bytes (magic): \(hexPrefix(blob)) — bplist00=NSKeyedArchiver directo;")
            lines.append("    78 9C/78 DA=zlib; 1F 8B=gzip; 62 76 78 32=lzfse → necesitaría descompresión previa.")
        }
        return nil
    }

    private static func hexPrefix(_ data: Data, count: Int = 16) -> String {
        data.prefix(count).map { String(format: "%02X", $0) }.joined(separator: " ")
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

    /// Valor tipado de una celda SQLite — NULL/int/text/blob distinguibles (clave para el round 2:
    /// "recordName NULL" ≠ "no hay fila", y los blobs de system fields no son texto).
    private enum SQLiteValue {
        case null
        case integer(Int64)
        case real(Double)
        case text(String)
        case blob(Data)

        var describe: String {
            switch self {
            case .null: return "NULL"
            case .integer(let i): return String(i)
            case .real(let d): return String(d)
            case .text(let s): return s
            case .blob(let d): return "<blob \(d.count) bytes>"
            }
        }

        var int64Value: Int64? { if case .integer(let i) = self { return i }; return nil }
        var textValue: String? { if case .text(let s) = self { return s }; return nil }
        var blobValue: Data? { if case .blob(let d) = self { return d }; return nil }
    }

    /// Error de sqlite envuelto para `Result` — interpola como el errmsg crudo.
    private struct SQLiteQueryError: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }

    /// Todas las filas de un SELECT con valores tipados. `.failure` = errmsg de sqlite (verbatim al log).
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
