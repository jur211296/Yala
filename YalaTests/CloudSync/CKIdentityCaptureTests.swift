//
//  CKIdentityCaptureTests.swift
//  YalaTests / CloudSync
//
//  Captura de coordenadas CloudKit (Estrategia B columnas, I10-wiring w3). Fixture SQLite FABRICADO a mano
//  (CREATE TABLE ANSCKRECORDMETADATA / ANSCKRECORDZONEMETADATA / Z_PRIMARYKEY con el schema observado en
//  device) en dir temporal. Cubre el tri-estado (captured / exportPending / noMetadata / failed), la zona
//  por FK EXACTO (con una zona SplitGroup DELANTE de la default), y el parse del URI. La verificación
//  contra el store REAL es device-only (ya la dio el spike S5).
//
//  `.serialized` + container on-disk propio para las filas `SyncIdentity`.
//

import Foundation
import SQLite3
import SwiftData
import Testing

@testable import Yala

@Suite("CKIdentityCapture · captura CloudKit (I10-wiring w3)", .serialized)
@MainActor
struct CKIdentityCaptureTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CKCapture-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CKC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "CKC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "CKC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Fabrica el fixture SQLite con el schema de las side-tables CK (device-observado). Zona Z_PK=1 es una
    /// SplitGroup (DELANTE), Z_PK=2 es la default personal — el FK exacto debe elegir la 2.
    private func makeFixture(_ dir: URL) -> URL {
        let url = dir.appendingPathComponent("ckfixture.sqlite")
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        let statements = [
            "CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER, Z_NAME TEXT)",
            "INSERT INTO Z_PRIMARYKEY (Z_ENT, Z_NAME) VALUES (5, 'TransactionItem')",
            "INSERT INTO Z_PRIMARYKEY (Z_ENT, Z_NAME) VALUES (7, 'Account')",
            """
            CREATE TABLE ANSCKRECORDMETADATA
            (Z_PK INTEGER, ZENTITYPK INTEGER, ZENTITYID INTEGER, ZCKRECORDNAME TEXT, ZRECORDZONE INTEGER)
            """,
            // happy: TransactionItem (zent=5) zpk=10 → recordName + zone FK=2 (default).
            "INSERT INTO ANSCKRECORDMETADATA VALUES (1, 10, 5, 'rec-tx-10', 2)",
            // exportPending: zpk=11 zent=5 → recordName NULL, zone FK=2.
            "INSERT INTO ANSCKRECORDMETADATA VALUES (2, 11, 5, NULL, 2)",
            "CREATE TABLE ANSCKRECORDZONEMETADATA (Z_PK INTEGER, ZCKRECORDZONENAME TEXT, ZCKOWNERNAME TEXT)",
            "INSERT INTO ANSCKRECORDZONEMETADATA VALUES (1, 'SplitGroup-ZZZ', 'owner-split')",
            "INSERT INTO ANSCKRECORDZONEMETADATA VALUES (2, 'com.apple.coredata.cloudkit.zone', '__defaultOwner__')",
        ]
        for sql in statements {
            #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK, "SQL: \(sql)")
        }
        sqlite3_close(db)
        return url
    }

    private func makeIdentityRow(_ context: ModelContext, entityType: String) -> SyncIdentity {
        let row = SyncIdentity(syncID: UUID(), entityType: entityType, localAnchor: "anchor")
        context.insert(row)
        return row
    }

    // MARK: - Tri-estado

    @Test("captured: recordName + zona por FK EXACTO (salta la SplitGroup delante)")
    func captured_zoneByExactFK() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fixture = makeFixture(dir)

        let row = makeIdentityRow(context, entityType: SyncEntityType.transactionItem)
        let req = CKIdentityCapture.ResolvedRequest(entityName: "TransactionItem", zpk: 10, row: row)
        let report = CKIdentityCapture.captureResolved([req], storeURL: fixture)

        #expect(report.captured == 1)
        #expect(report.exportPending == 0 && report.noMetadata == 0 && report.failed == 0)
        #expect(row.ckRecordName == "rec-tx-10")
        // Zona por FK EXACTO = la default (Z_PK=2), NUNCA la SplitGroup (Z_PK=1) que va delante.
        #expect(row.ckZoneName == "com.apple.coredata.cloudkit.zone")
        #expect(row.ckOwnerName == "__defaultOwner__")
    }

    @Test("exportPending: metadata presente con ZCKRECORDNAME=NULL (≠ sin fila)")
    func exportPending_recordNameNull() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fixture = makeFixture(dir)

        let row = makeIdentityRow(context, entityType: SyncEntityType.transactionItem)
        let req = CKIdentityCapture.ResolvedRequest(entityName: "TransactionItem", zpk: 11, row: row)
        let report = CKIdentityCapture.captureResolved([req], storeURL: fixture)

        #expect(report.exportPending == 1)
        #expect(report.captured == 0)
        #expect(row.ckRecordName == nil)  // NO se muta la fila (no pisar con NULLs)
    }

    @Test("noMetadata: sin fila de metadata para (Z_ENT, Z_PK)")
    func noMetadata_missingRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fixture = makeFixture(dir)

        let row = makeIdentityRow(context, entityType: SyncEntityType.transactionItem)
        let req = CKIdentityCapture.ResolvedRequest(entityName: "TransactionItem", zpk: 999, row: row)
        let report = CKIdentityCapture.captureResolved([req], storeURL: fixture)

        #expect(report.noMetadata == 1)
        #expect(row.ckRecordName == nil)
    }

    @Test("failed: entidad sin fila en Z_PRIMARYKEY → no-zent")
    func failed_noZent() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fixture = makeFixture(dir)

        let row = makeIdentityRow(context, entityType: SyncEntityType.budget)
        // "Budget" no está en Z_PRIMARYKEY del fixture → no-zent.
        let req = CKIdentityCapture.ResolvedRequest(entityName: "Budget", zpk: 10, row: row)
        let report = CKIdentityCapture.captureResolved([req], storeURL: fixture)

        #expect(report.failed == 1)
        #expect(row.ckRecordName == nil)
        #expect(report.failedReasons == ["no-zent": 1], "el motivo se agrupa para medirlo en device")
        #expect(report.structuralFailure == nil,
                "con el mapa de entidades leído, una entidad que no está es un motivo POR FILA, no estructural")
    }

    @Test("batch tri-estado: 1 captured + 1 exportPending + 1 noMetadata + 1 failed en UNA corrida")
    func batch_allFourOutcomes() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fixture = makeFixture(dir)

        let captured = makeIdentityRow(context, entityType: SyncEntityType.transactionItem)
        let pending = makeIdentityRow(context, entityType: SyncEntityType.transactionItem)
        let missing = makeIdentityRow(context, entityType: SyncEntityType.transactionItem)
        let failed = makeIdentityRow(context, entityType: SyncEntityType.budget)
        let requests = [
            CKIdentityCapture.ResolvedRequest(entityName: "TransactionItem", zpk: 10, row: captured),
            CKIdentityCapture.ResolvedRequest(entityName: "TransactionItem", zpk: 11, row: pending),
            CKIdentityCapture.ResolvedRequest(entityName: "TransactionItem", zpk: 999, row: missing),
            CKIdentityCapture.ResolvedRequest(entityName: "Budget", zpk: 10, row: failed),
        ]
        let report = CKIdentityCapture.captureResolved(requests, storeURL: fixture)

        #expect(report.captured == 1)
        #expect(report.exportPending == 1)
        #expect(report.noMetadata == 1)
        #expect(report.failed == 1)
        #expect(report.total == 4)
        #expect(report.structuralFailure == nil, "tres filas se miraron: el fallo de la cuarta es suyo")
        #expect(report.failedReasons == ["no-zent": 1])
        #expect(captured.ckRecordName == "rec-tx-10")
        #expect(pending.ckRecordName == nil && missing.ckRecordName == nil && failed.ckRecordName == nil)
    }

    @Test("sqlite-open falla → todas las peticiones failed (store inexistente)")
    func openFailure_allFailed() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let row = makeIdentityRow(context, entityType: SyncEntityType.transactionItem)
        let missingURL = dir.appendingPathComponent("does-not-exist.sqlite")
        let req = CKIdentityCapture.ResolvedRequest(entityName: "TransactionItem", zpk: 10, row: row)
        let report = CKIdentityCapture.captureResolved([req], storeURL: missingURL)
        #expect(report.failed == 1)
        #expect(report.captured == 0)
        #expect(report.structuralFailure?.hasPrefix("sqlite-open-") == true, "no se miró ninguna fila")
    }

    // MARK: - Fallo ESTRUCTURAL: la corrida no pudo mirar ninguna fila
    // (ticket `reverse-upload-sample-reads-unreadable-rows-as-drained`)
    //
    // Cada fixture rompe UNA pieza del SQLite. El control es `makeFixture(_:)`: con las mismas peticiones, se miran.

    private func makeFixture(_ dir: URL, statements: [String]) -> URL {
        let url = dir.appendingPathComponent("ckfixture-\(UUID().uuidString).sqlite")
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        for sql in statements {
            #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK, "SQL: \(sql)")
        }
        sqlite3_close(db)
        return url
    }

    private static let zoneTable = [
        "CREATE TABLE ANSCKRECORDZONEMETADATA (Z_PK INTEGER, ZCKRECORDZONENAME TEXT, ZCKOWNERNAME TEXT)",
        "INSERT INTO ANSCKRECORDZONEMETADATA VALUES (2, 'com.apple.coredata.cloudkit.zone', '__defaultOwner__')",
    ]
    private static let primaryKeys = [
        "CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER, Z_NAME TEXT)",
        "INSERT INTO Z_PRIMARYKEY (Z_ENT, Z_NAME) VALUES (5, 'TransactionItem')",
    ]
    private static let metaTable =
        "CREATE TABLE ANSCKRECORDMETADATA (Z_PK INTEGER, ZENTITYPK INTEGER, ZENTITYID INTEGER, ZCKRECORDNAME TEXT, ZRECORDZONE INTEGER)"
    /// La tabla está pero no se deja consultar: la columna de la entidad lleva un espacio y el SELECT sin comillas es SQL
    /// inválido, así que la consulta no prepara en ninguna fila.
    private static let unqueryableMetaTable =
        "CREATE TABLE ANSCKRECORDMETADATA (Z_PK INTEGER, \"X ZENTITYPK\" INTEGER, ZENTITYID INTEGER, ZCKRECORDNAME TEXT, ZRECORDZONE INTEGER)"

    static let structuralCases: [(expected: String, statements: [String])] = [
        ("no-record-metadata-table", primaryKeys + zoneTable),
        ("meta-columns-missing", primaryKeys + zoneTable + [
            "CREATE TABLE ANSCKRECORDMETADATA (Z_PK INTEGER, ZENTITYPK INTEGER, ZRECORDZONE INTEGER)",
        ]),
        ("primary-key-map-unreadable", zoneTable + [metaTable]),
        ("primary-key-map-unreadable", ["CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER, Z_NAME TEXT)"] + zoneTable + [metaTable]),
        ("meta-query", primaryKeys + zoneTable + [unqueryableMetaTable]),
    ]

    @Test("estructural: cada pieza del SQLite que falta deja la corrida sin mirar ninguna fila",
          arguments: 0..<5)
    func structural_eachMissingPiece(caseIndex: Int) throws {
        let (expected, statements) = Self.structuralCases[caseIndex]
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let requests = (0..<2).map {
            CKIdentityCapture.ResolvedRequest(
                entityName: "TransactionItem", zpk: Int64(900 + $0),
                row: makeIdentityRow(context, entityType: SyncEntityType.transactionItem))
        }

        let control = CKIdentityCapture.captureResolved(requests, storeURL: makeFixture(dir))
        #expect(control.structuralFailure == nil && control.noMetadata == 2, "control: con el SQLite entero se miran")

        let report = CKIdentityCapture.captureResolved(requests, storeURL: makeFixture(dir, statements: statements))
        #expect(report.structuralFailure == expected)
        #expect(report.failed == 2 && report.total == 2, "todas las filas son failed")
        #expect(report.failedReasons[expected] == 2)
    }

    @Test("la consulta de metadata que falla en TODAS las que la intentan es estructural aunque haya no-zent")
    func structural_metaQueryFailsForEveryAttempt_evenWithNoZentRows() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fixture = makeFixture(dir, statements: Self.primaryKeys + Self.zoneTable + [Self.unqueryableMetaTable])
        let tx = CKIdentityCapture.ResolvedRequest(
            entityName: "TransactionItem", zpk: 1, row: makeIdentityRow(context, entityType: SyncEntityType.transactionItem))
        let budget = CKIdentityCapture.ResolvedRequest(
            entityName: "Budget", zpk: 1, row: makeIdentityRow(context, entityType: SyncEntityType.budget))

        let report = CKIdentityCapture.captureResolved([tx, budget], storeURL: fixture)
        #expect(report.structuralFailure == "meta-query", "la única fila que llegó a la tabla no la pudo leer")
        #expect(report.failedReasons == ["meta-query": 1, "no-zent": 1])
    }

    /// Una fila capturada junto a una `no-zent`: la corrida miró algo, así que no es estructural. El caso «la consulta de
    /// metadata falla en UNAS filas y no en otras» no tiene test: la SQL solo cambia en dos enteros, así que ese fallo solo
    /// sale con un error transitorio de SQLite (base ocupada), que un fixture no reproduce.
    @Test("una fila capturada junto a una no-zent es un motivo por fila, no estructural")
    func capturedBesideNoZent_isPerRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fixture = makeFixture(dir)
        let good = CKIdentityCapture.ResolvedRequest(
            entityName: "TransactionItem", zpk: 10, row: makeIdentityRow(context, entityType: SyncEntityType.transactionItem))
        let noZent = CKIdentityCapture.ResolvedRequest(
            entityName: "Budget", zpk: 1, row: makeIdentityRow(context, entityType: SyncEntityType.budget))
        let report = CKIdentityCapture.captureResolved([good, noZent], storeURL: fixture)
        #expect(report.captured == 1 && report.failed == 1)
        #expect(report.structuralFailure == nil)
    }

    @Test("todas no-zent con el mapa leído NO es estructural: es el motivo por fila que el ticket manda medir")
    func allNoZent_withAReadableMap_isPerRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let requests = (0..<3).map { _ in
            CKIdentityCapture.ResolvedRequest(
                entityName: "Budget", zpk: 1, row: makeIdentityRow(context, entityType: SyncEntityType.budget))
        }
        let report = CKIdentityCapture.captureResolved(requests, storeURL: makeFixture(dir))
        #expect(report.failed == 3)
        #expect(report.structuralFailure == nil)
        #expect(report.failedReasons == ["no-zent": 3])
    }

    @Test("failureBucket: quita el detalle variable del motivo")
    func failureBucket_dropsTheVariableDetail() {
        #expect(CKIdentityCapture.failureBucket("meta-query:no such column: ZFOO") == "meta-query")
        #expect(CKIdentityCapture.failureBucket("zone-query:x") == "zone-query")
        #expect(CKIdentityCapture.failureBucket("sqlite-open-14") == "sqlite-open-14")
        #expect(CKIdentityCapture.failureBucket("no-zent") == "no-zent")
    }

    // MARK: - URI parsing

    @Test("parseCoreDataURI: x-coredata://STORE/Entity/pNNN → (entity, Z_PK)")
    func parseURI_happy() {
        let uri = URL(string: "x-coredata://ABC-123/TransactionItem/p42")!
        let parsed = CKIdentityCapture.parseCoreDataURI(uri)
        #expect(parsed?.entityName == "TransactionItem")
        #expect(parsed?.zpk == 42)
    }

    @Test("parseCoreDataURI: URI sin componente numérico → nil")
    func parseURI_noNumber() {
        let uri = URL(string: "x-coredata://ABC-123/TransactionItem")!
        // Sin /pNNN el drop(while:) deja vacío → Int64 nil → parse nil (o entidad ausente).
        let parsed = CKIdentityCapture.parseCoreDataURI(uri)
        #expect(parsed == nil)
    }

    // MARK: - Scan de metadata HUÉRFANA (canario reverseOrphanMetadata)

    /// Fixture con un zombie: TransactionItem (zent=5) zpk 10/11 VIVOS + zpk 999 HUÉRFANO; Account (zent=7)
    /// zpk 50 (para probar que una entidad AUSENTE del mapa de vivos se ignora). Fila con NULLs → ignorada.
    private func makeOrphanFixture(_ dir: URL) -> URL {
        let url = dir.appendingPathComponent("orphanfixture.sqlite")
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        let statements = [
            "CREATE TABLE Z_PRIMARYKEY (Z_ENT INTEGER, Z_NAME TEXT)",
            "INSERT INTO Z_PRIMARYKEY (Z_ENT, Z_NAME) VALUES (5, 'TransactionItem')",
            "INSERT INTO Z_PRIMARYKEY (Z_ENT, Z_NAME) VALUES (7, 'Account')",
            """
            CREATE TABLE ANSCKRECORDMETADATA
            (Z_PK INTEGER, ZENTITYPK INTEGER, ZENTITYID INTEGER, ZCKRECORDNAME TEXT, ZRECORDZONE INTEGER)
            """,
            "INSERT INTO ANSCKRECORDMETADATA VALUES (1, 10, 5, 'rec-tx-10', 2)",   // vivo
            "INSERT INTO ANSCKRECORDMETADATA VALUES (2, 11, 5, 'rec-tx-11', 2)",   // vivo
            "INSERT INTO ANSCKRECORDMETADATA VALUES (3, 999, 5, 'rec-zombie', 2)", // HUÉRFANO
            "INSERT INTO ANSCKRECORDMETADATA VALUES (4, 50, 7, 'rec-acc-50', 2)",  // Account (ignorada si no es key)
            "INSERT INTO ANSCKRECORDMETADATA VALUES (5, NULL, NULL, 'bookkeeping', 2)",  // NULLs → ignorada
        ]
        for sql in statements {
            #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK, "SQL: \(sql)")
        }
        sqlite3_close(db)
        return url
    }

    @Test("orphan scan: 1 huérfano (zpk 999) contra vivos {TransactionItem: {10,11}}; Account ignorada")
    func orphanScan_countsZombie_ignoresAbsentEntity() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let fixture = makeOrphanFixture(dir)
        // Account NO está en las keys → sus filas de metadata se ignoran (no huérfanas).
        let report = CKIdentityCapture.scanOrphanMetadata(
            liveByEntityName: ["TransactionItem": [10, 11]], storeURL: fixture)
        #expect(report.orphans == 1)   // solo zpk 999
        #expect(report.scanned == 3)   // 10, 11, 999 (Account y la fila NULL no cuentan)
        #expect(report.failed == 0)
    }

    @Test("orphan scan: entidad sin filas vivas (key con Set vacío) → su metadata ES huérfana")
    func orphanScan_emptyLiveSet_metadataIsOrphan() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let fixture = makeOrphanFixture(dir)
        // TransactionItem presente como key pero Set VACÍO → las 3 filas TX son huérfanas reales (RP-4).
        let report = CKIdentityCapture.scanOrphanMetadata(
            liveByEntityName: ["TransactionItem": []], storeURL: fixture)
        #expect(report.orphans == 3)
        #expect(report.scanned == 3)
        #expect(report.failed == 0)
    }

    @Test("orphan scan: entidad fuera de las keys → sus filas se ignoran (0 huérfanos)")
    func orphanScan_entityNotAKey_ignored() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let fixture = makeOrphanFixture(dir)
        // Solo "Budget" como key (sin filas de Budget en el fixture) → TX/Account ignoradas.
        let report = CKIdentityCapture.scanOrphanMetadata(
            liveByEntityName: ["Budget": [1]], storeURL: fixture)
        #expect(report.orphans == 0)
        #expect(report.scanned == 0)
        #expect(report.failed == 0)
    }

    @Test("orphan scan: liveByEntityName VACÍO → sin señal (0/0/0, failed=0)")
    func orphanScan_emptyMap_noSignal() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let fixture = makeOrphanFixture(dir)
        let report = CKIdentityCapture.scanOrphanMetadata(liveByEntityName: [:], storeURL: fixture)
        #expect(report == .init(orphans: 0, scanned: 0, failed: 0))
    }

    @Test("orphan scan: store sin side-tables CK → failed sin crash")
    func orphanScan_noCKTables_failed() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)   // store personal `.none` → sin ANSCKRECORDMETADATA
        let tx = TransactionItem(date: .now, amount: 1, currencyCode: "USD")
        context.insert(tx)
        try context.save()
        let personalURL = dir.appendingPathComponent("personal.sqlite")
        let report = CKIdentityCapture.scanOrphanMetadata(
            liveByEntityName: ["TransactionItem": [1]], storeURL: personalURL)
        #expect(report.failed == 1)
        #expect(report.orphans == 0)
    }

    @Test("capture (PersistentIdentifier real): resuelve el URI y abre el store; sin side-tables CK → failed")
    func capture_realPersistentIdentifier_noCKTables() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        // TX real en el store personal temp (cloudKitDatabase: .none → sin side-tables CK).
        let tx = TransactionItem(date: .now, amount: 1, currencyCode: "USD")
        tx.syncID = UUID()
        context.insert(tx)
        try context.save()
        let row = makeIdentityRow(context, entityType: SyncEntityType.transactionItem)

        let personalURL = dir.appendingPathComponent("personal.sqlite")
        let report = CKIdentityCapture.capture([(id: tx.persistentModelID, row: row)], storeURL: personalURL)
        // URI extraído + parseado + SQLite abierto OK; el store `.none` no tiene ANSCKRECORDMETADATA →
        // no-record-metadata-table → failed. Prueba el camino público end-to-end sin device.
        #expect(report.total == 1)
        #expect(report.failed == 1)
        #expect(report.structuralFailure == "no-record-metadata-table", "el estructural viaja por la entrada pública")
    }
}
