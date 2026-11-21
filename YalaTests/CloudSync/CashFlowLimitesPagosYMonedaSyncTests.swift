//
//  CashFlowLimitesPagosYMonedaSyncTests.swift
//  YalaTests / CloudSync
//
//  Límites del flujo de caja con varios pagos y en otra moneda (encargo del 2026-11-20) por el Modo Nube: las cuatro
//  columnas de `cashflow_lines` con `since: 8`, con el molde de `CashFlowAmountChangeSyncTests`:
//   - con `v7` no se emiten (un Worker v7 rechazaría la fila entera) y lo cambiado se APUNTA, por columna; con `v8`, sí;
//   - ida y vuelta: lo que un teléfono emite en v8, otro lo aplica intacto;
//   - al subir de v7 a v8 se reemiten las líneas apuntadas con SOLO sus columnas apuntadas, y se re-baja desde 0.
//
//  Container ON-DISK temp con los 3 stores + `.serialized`. `SyncCapability.defaults` se aísla en cada caso.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · flujo de caja: pagos de la línea y monto en otra moneda (v8)", .serialized)
@MainActor
struct CashFlowLimitesPagosYMonedaSyncTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CFLimits-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        retireTestStoreDirectoryLater(dir)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CFL-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "CFL-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "CFL-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func isolateCapability(backend level: Int?) -> () -> Void {
        let previous = SyncCapability.defaults
        let suite = "test.syncCapability.\(UUID().uuidString)"
        let isolated = testDefaults(suiteName: suite) ?? previous
        SyncCapability.defaults = isolated
        if let level { isolated.set(level, forKey: SyncCapability.backendManifestVersionKey) }
        return {
            isolated.removePersistentDomain(forName: suite)
            SyncCapability.defaults = previous
        }
    }

    private let node = "0123456789abcdef"
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }

    private let ids = "0A1B2C3D-1111-4222-8333-944455556666,1B2C3D4E-2222-4333-8444-A55566667777"

    private func line(_ context: ModelContext, _ name: String) -> CashFlowLine {
        let l = CashFlowLine(name: name, estimationMethod: .manual, manualAmount: 1850)
        context.insert(l)
        return l
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func fields(_ row: SyncOutbox) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(row.fieldsJSON.utf8)) as? [String: Any] ?? [:]
    }

    // MARK: - Emisión

    @Test func emission_v8_carriesTheFourColumns_v7_doesNot() throws {
        let context = try makeContext(freshDir())
        let rent = line(context, "Renta")
        rent.scheduledPaymentIDsRaw = ids
        rent.limitExtraAmount = 30
        rent.limitCurrencyCode = "USD"
        rent.limitForeignAmount = 500
        let emission = EntityEmissionMap.cashFlowLine

        let v8 = DeltaEmitter.emit(model: rent, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 8)
        #expect(v8.fields["scheduled_payment_ids_raw"] == .string(ids))
        #expect(v8.fields["limit_currency_code"] == .string("USD"))
        #expect(v8.fields["limit_extra_amount"] != nil)
        #expect(v8.fields["limit_foreign_amount"] != nil)
        #expect(v8.fieldHlcs["limit_foreign_amount"] == hlc(1))

        let v7 = DeltaEmitter.emit(model: rent, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 7)
        for column in SyncCapability.cashFlowLimitColumns { #expect(v7.fields[column] == nil) }
        #expect(v7.fields["name"] == .string("Renta"), "el resto de la fila sí viaja")
    }

    // MARK: - Drain

    @Test func drain_v7_neverSendsTheColumns_andNotesOnlyTheChangedOnes() throws {
        let restoreCapability = isolateCapability(backend: 7)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let rent = line(context, "Renta")
        try context.save()
        engine.drainOnce(context: context)
        #expect(SyncCapability.suppressedCashFlowLimits.isEmpty, "sin valores no hay nada que apuntar")

        rent.limitCurrencyCode = "USD"
        rent.limitForeignAmount = 500
        try context.save()
        engine.drainOnce(context: context)

        let rows = try outbox(context).filter { $0.entityType == SyncEntityType.cashFlowLine }
        for row in rows {
            for column in SyncCapability.cashFlowLimitColumns { #expect(try fields(row)[column] == nil) }
        }
        #expect(SyncCapability.suppressedCashFlowLimits == [rent.id: ["limit_currency_code", "limit_foreign_amount"]],
                "por columna: los pagos y el extra no se tocaron y no se apuntan")
    }

    @Test func drain_v8_sendsTheChangedColumns() throws {
        let restoreCapability = isolateCapability(backend: 8)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let subs = line(context, "Suscripciones")
        try context.save()
        engine.drainOnce(context: context)

        subs.scheduledPaymentIDsRaw = ids
        subs.limitExtraAmount = 30
        try context.save()
        engine.drainOnce(context: context)

        let subsID = subs.id
        let update = try #require(try outbox(context).last { $0.syncID == subsID })
        let updateFields = try fields(update)
        #expect(Set(updateFields.keys) == ["scheduled_payment_ids_raw", "limit_extra_amount"])
        #expect(updateFields["scheduled_payment_ids_raw"] as? String == ids)
        #expect(SyncCapability.suppressedCashFlowLimits.isEmpty)
    }

    // MARK: - Ida y vuelta

    @Test func roundTrip_theFourColumnsArriveIntactOnTheOtherPhone() throws {
        let restoreCapability = isolateCapability(backend: 8)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let rent = line(phoneA, "Renta")
        rent.scheduledPaymentIDsRaw = ids
        rent.limitExtraAmount = 30
        rent.limitCurrencyCode = "USD"
        rent.limitForeignAmount = 500
        try phoneA.save()
        let emission = EntityEmissionMap.cashFlowLine
        let emitted = DeltaEmitter.emit(model: rent, emission: emission, changedColumns: emission.columns, hlc: hlc(2))
        let fieldsJSON = try Canonc1Codec.encode(emitted.fields, groupedColumns: Set(emission.groupByColumn.keys))
        let hlcs = emitted.fieldHlcs.keys.sorted().map { "\"\($0)\":\"\(hlc(2))\"" }.joined(separator: ",")
        let delta = """
        {"entity_type":"cashflow_lines","sync_id":"\(rent.id.uuidString.lowercased())","op":"upsert",\
        "fields":\(fieldsJSON),"field_hlcs":{\(hlcs)},"hlc":"\(hlc(2))","server_seq":2,"schema_version":1}
        """
        let json = "{\"deltas\":[\(delta)],\"max_server_seq\":2,\"manifest_version\":8}"
        let page = try SyncPullClient.decodePage(Data(json.utf8))

        let phoneB = try makeContext(freshDir())
        #expect(CloudSyncEngine().applyPage(page, context: phoneB, now: applyNow))
        let rentID = rent.id
        let arrived = try #require(try phoneB.fetch(FetchDescriptor<CashFlowLine>()).first { $0.id == rentID })
        #expect(arrived.scheduledPaymentIDsRaw == ids)
        #expect(arrived.limitExtraAmount == 30)
        #expect(arrived.limitCurrencyCode == "USD")
        #expect(arrived.limitForeignAmount == 500)
        #expect(arrived.scheduledPaymentIDs.count == 2)
    }

    // MARK: - La subida de v7 a v8

    @Test func upgradeFromV7ToV8_asksForTheUpgrade() {
        let restoreCapability = isolateCapability(backend: 7)
        defer { restoreCapability() }
        SyncCapability.defaults.set(7, forKey: SyncCapability.lastDeclaredLevelKey)
        #expect(SyncCapability.declaredLevel == 7)
        SyncCapability.recordBackendManifestVersion(8)
        #expect(SyncCapability.declaredLevel == 8)
        #expect(SyncCapability.upgradePending)
    }

    @Test func pull_upgradeToV8_reemitsTheNotedLine_withOnlyItsNotedColumns() async throws {
        let restoreCapability = isolateCapability(backend: 7)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let rent = line(context, "Renta")
        try context.save()
        engine.drainOnce(context: context)
        rent.limitCurrencyCode = "USD"
        rent.limitForeignAmount = 500
        try context.save()
        engine.drainOnce(context: context)
        for row in try outbox(context) { context.delete(row) }   // lo demás ya subió
        try context.save()
        #expect(SyncCapability.suppressedCashFlowLimits[rent.id] == ["limit_currency_code", "limit_foreign_amount"])

        let announce = "{\"deltas\":[],\"max_server_seq\":0,\"manifest_version\":8}"
        let session = CashFlowLimitsCapabilitySession(bodies: [Data(announce.utf8)])
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!, tokenProvider: { "jwt" },
                                    urlSession: session)
        _ = await engine.pullAndApplyOnce(using: client, context: context)

        #expect(session.capabilityHeaders.first == "v7")
        #expect(session.capabilityHeaders.contains("v8"))
        let rentID = rent.id
        let reemitted = try #require(try outbox(context).last { $0.syncID == rentID })
        #expect(Set(try fields(reemitted).keys) == ["limit_currency_code", "limit_foreign_amount"],
                "solo las columnas apuntadas, no la fila entera ni las otras dos")
        #expect(try fields(reemitted)["limit_currency_code"] as? String == "USD")
        #expect(!SyncCapability.upgradePending)
        #expect(SyncCapability.suppressedCashFlowLimits.isEmpty)
    }

    @Test func upgradeWithTheWorkerBackAtV7_keepsTheNotedColumns() throws {
        let restoreCapability = isolateCapability(backend: 7)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let rent = line(context, "Renta")
        try context.save()
        SyncCapability.noteSuppressedCashFlowLimits(rent.id, columns: ["scheduled_payment_ids_raw"])
        SyncCapability.upgradePending = true

        #expect(try engine.applyCapabilityUpgradeIfPending(context: context))

        #expect(try outbox(context).filter { $0.syncID == rent.id }.isEmpty, "con v7 la columna no viajaría")
        #expect(SyncCapability.suppressedCashFlowLimits == [rent.id: ["scheduled_payment_ids_raw"]])
    }
}

// MARK: - Stub

private final class CashFlowLimitsCapabilitySession: SyncHTTPSession, @unchecked Sendable {
    /// Respuestas en orden; la última se repite.
    let bodies: [Data]
    private(set) var capabilityHeaders: [String] = []
    init(bodies: [Data]) { self.bodies = bodies }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capabilityHeaders.append(request.value(forHTTPHeaderField: "X-Yala-Capability-Set") ?? "-")
        let body = bodies[min(capabilityHeaders.count - 1, bodies.count - 1)]
        let response = HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"), statusCode: 200,
                                       httpVersion: nil, headerFields: nil)
        return (body, response ?? URLResponse())
    }
}
