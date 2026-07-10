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
    }
}
