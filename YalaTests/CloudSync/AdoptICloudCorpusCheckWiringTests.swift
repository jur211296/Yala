//
//  AdoptICloudCorpusCheckWiringTests.swift
//  YalaTests / CloudSync
//
//  Ticket `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`. El comportamiento del paso
//  0-bis del reconcile lo prueban los tests del ejecutor (`MigrationWorkExecutorTests`, sección del store sin corpus) con
//  los dos seams inyectados. Aquí va lo que ellos no pueden ver:
//
//  - que PRODUCCIÓN inyecta los dos seams, y con el testigo del MOUNT: sus defaults son la verdad del host de test
//    (sin espejo, sonda sin cablear), así que sin la inyección el paso 0-bis no correría nunca en un teléfono y todos los
//    tests seguirían en verde;
//  - que los tipos que la sonda busca en CloudKit son exactamente los que la guarda de linaje contaría si llegaran.
//

import Foundation
import Testing

@testable import Yala

@Suite("Adopt con el store sin corpus: cableado y tipos de la sonda")
@MainActor
struct AdoptICloudCorpusCheckWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Cuerpo de `makeExecutor`, de su llave de apertura a la de cierre, sin líneas de comentario: nombrar un seam en un
    /// comentario no puede pintar el test de verde.
    private static func makeExecutorBody() throws -> String {
        let source = try String(
            contentsOf: repoRoot.appendingPathComponent("Yala/Services/CloudSync/CloudMigrationController.swift"),
            encoding: .utf8)
        let marker = "static func makeExecutor(context: ModelContext, deviceID: String) -> MigrationWorkExecutor {"
        let start = try #require(source.range(of: marker), "la firma de `makeExecutor` cambió")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El testigo es el del MOUNT de este proceso (`attachesCloudKitMirror`), no «¿hay iCloud?»: `isICloudAvailable` mide
    /// Drive, y `.localNoMirror` adjunta el espejo aunque no haya cuenta. Y la sonda es la de CloudKit sin espejo.
    @Test func productionExecutor_injectsTheMountWitnessAndTheCloudKitCheck() throws {
        let body = try Self.makeExecutorBody()
        #expect(body.contains(
            "adoptMirrorAttached: { SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror },"))
        #expect(body.contains("adoptICloudCorpusCheck: { await ICloudPersonalCorpusProbe.adoptRelevantRecords() },"))
        #expect(body.contains(
            "adoptImportSettled: { iCloudSyncService.shared.hasCompletedFirstImport && iCloudSyncService.shared.isImportQuiescent })"))
        for seam in ["adoptMirrorAttached:", "adoptICloudCorpusCheck:", "adoptImportSettled:"] {
            #expect(body.components(separatedBy: seam).count - 1 == 1, "\(seam) una sola vez")
        }
    }

    /// Cada entidad del canal personal con la tabla de su emisión. Si el canal gana una entidad, el primer `#expect` de abajo
    /// obliga a añadirla aquí, y con ella a decidir si está exenta en los dos sitios.
    private static let entityTables: [(entity: String, table: String)] = [
        (SyncEntityType.transactionItem, EntityEmissionMap.transactionItem.table),
        (SyncEntityType.inboxDraft, EntityEmissionMap.inboxDraft.table),
        (SyncEntityType.category, EntityEmissionMap.category.table),
        (SyncEntityType.favoritePayment, EntityEmissionMap.favoritePayment.table),
        (SyncEntityType.merchantMemory, EntityEmissionMap.merchantMemory.table),
        (SyncEntityType.exchangeRate, EntityEmissionMap.exchangeRate.table),
        (SyncEntityType.budget, EntityEmissionMap.budget.table),
        (SyncEntityType.scheduledPayment, EntityEmissionMap.scheduledPayment.table),
        (SyncEntityType.account, EntityEmissionMap.account.table),
        (SyncEntityType.subcategory, EntityEmissionMap.subcategory.table),
        (SyncEntityType.tag, EntityEmissionMap.tag.table),
        (SyncEntityType.notificationItem, EntityEmissionMap.notificationItem.table),
        (SyncEntityType.cashFlowPlan, EntityEmissionMap.cashFlowPlan.table),
        (SyncEntityType.cashFlowLine, EntityEmissionMap.cashFlowLine.table),
        (SyncEntityType.cashFlowOverride, EntityEmissionMap.cashFlowOverride.table),
        (SyncEntityType.groupBridgePreference, EntityEmissionMap.groupBridgePreference.table),
    ]

    /// La exención de la sonda (por ENTIDAD) y la de la guarda (por TABLA) son la misma, entidad a entidad. Si una cambia sin
    /// la otra, la guarda esperaría filas que nunca pedirán prueba —y el adopt no terminaría— o dejaría pasar las que sí. Y los
    /// tipos que busca la sonda son exactamente los de las entidades no exentas.
    @Test func probeExemption_isTheLineageGateExemption_entityByEntity() {
        #expect(Set(Self.entityTables.map(\.entity)) == CloudSyncEngine.personalEntityNames, "la tabla cubre el canal entero")
        for (entity, table) in Self.entityTables {
            #expect(ICloudPersonalCorpusProbe.adoptExemptEntityNames.contains(entity)
                    == MigrationWorkExecutor.adoptLineageExemptTables.contains(table), "\(entity) ↔ \(table)")
            #expect(ICloudPersonalCorpusProbe.adoptRelevantRecordTypes.contains("CD_" + entity)
                    == !MigrationWorkExecutor.adoptLineageExemptTables.contains(table), "la sonda busca \(entity) si la guarda lo cuenta")
        }
        #expect(ICloudPersonalCorpusProbe.adoptRelevantRecordTypes.count == Self.entityTables.count - 1,
                "control: hoy solo los tipos de cambio están exentos")
        #expect(!ICloudPersonalCorpusProbe.adoptRelevantRecordTypes.contains("CD_CloudMigrationMarker"),
                "el marcador no sube al backend")
    }

    /// El detalle del canario no lleva el tipo de registro (una serie por desenlace) y sí el motivo del fallo.
    /// (El tipo sí va en el rastro del dispositivo, `adoptReconcileAwaitingICloudCorpus`.)
    @Test func canaryDetail() {
        #expect(ICloudAdoptCorpusCheck.found(recordType: "CD_Category").canaryDetail == "found")
        #expect(ICloudAdoptCorpusCheck.none.canaryDetail == "none")
        #expect(ICloudAdoptCorpusCheck.noAccount.canaryDetail == "noAccount")
        #expect(ICloudAdoptCorpusCheck.failed("CKError.4").canaryDetail == "failed:CKError.4")
    }
}
