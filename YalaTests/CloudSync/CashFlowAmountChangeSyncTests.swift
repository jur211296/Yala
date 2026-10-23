//
//  CashFlowAmountChangeSyncTests.swift
//  YalaTests / CloudSync
//
//  Auditoría UX 2.2 · L18-8 por el Modo Nube: la columna `cashflow_lines.amount_changes_raw` (los cambios de monto
//  «desde este mes» de una línea del flujo de caja) con `since: 3`. Lo que fija, con el molde de `AccountLineSyncTests`:
//   - con `v2` la columna ni se emite (un Worker v2 rechazaría la fila entera) y lo cambiado se APUNTA; con `v3`, sí;
//   - ida y vuelta: lo que un teléfono emite en v3, otro lo aplica intacto;
//   - al subir de v2 a v3 —un salto que hasta ahora no pedía subida: solo la pedía cruzar a v2— se reemiten las líneas
//     apuntadas, con SOLO esa columna, y se re-baja desde 0.
//
//  Container ON-DISK temp con los 3 stores + `.serialized`. `SyncCapability.defaults` se aísla en cada caso.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · flujo de caja: cambios «desde este mes» (amount_changes_raw, v3)", .serialized)
@MainActor
struct CashFlowAmountChangeSyncTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CFAmount-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CFA-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "CFA-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "CFA-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func isolateCapability(backend level: Int?) -> () -> Void {
        let previous = SyncCapability.defaults
        let suite = "test.syncCapability.\(UUID().uuidString)"
        let isolated = UserDefaults(suiteName: suite) ?? previous
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

    private func line(_ context: ModelContext, _ name: String) -> CashFlowLine {
        let l = CashFlowLine(name: name, isIncome: true, estimationMethod: .manual, manualAmount: 8500)
        context.insert(l)
        return l
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func fields(_ row: SyncOutbox) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(row.fieldsJSON.utf8)) as? [String: Any] ?? [:]
    }

    private let changes = "2026-11=9000.0,2027-02=9500.0"

    // MARK: - Emisión

    @Test func emission_v3_carriesTheChanges_v2_doesNot() throws {
        let dir = freshDir()
        let context = try makeContext(dir)
        let salary = line(context, "Salario")
        salary.amountChangesRaw = changes
        let emission = EntityEmissionMap.cashFlowLine

        let v3 = DeltaEmitter.emit(model: salary, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 3)
        #expect(v3.fields["amount_changes_raw"] == .string(changes))
        #expect(v3.fieldHlcs["amount_changes_raw"] == hlc(1))

        let v2 = DeltaEmitter.emit(model: salary, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 2)
        #expect(v2.fields["amount_changes_raw"] == nil)
        #expect(v2.fields["name"] == .string("Salario"), "el resto de la fila sí viaja")

        let onlyChanges = DeltaEmitter.emit(model: salary, emission: emission, changedColumns: ["amount_changes_raw"],
                                            hlc: hlc(1), capabilityLevel: 2)
        #expect(onlyChanges.fields.isEmpty && onlyChanges.fieldHlcs.isEmpty)
    }

    // MARK: - Drain

    @Test func drain_v2_neverSendsTheColumn_andNotesTheLine() throws {
        let restoreCapability = isolateCapability(backend: 2)
        defer { restoreCapability() }
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let salary = line(context, "Salario")
        let plain = line(context, "Bono")
        try context.save()
        engine.drainOnce(context: context)
        #expect(SyncCapability.suppressedCashFlowAmountChanges.isEmpty, "sin cambios no hay nada que apuntar")

        salary.amountChangesRaw = changes
        try context.save()
        engine.drainOnce(context: context)

        let rows = try outbox(context).filter { $0.entityType == SyncEntityType.cashFlowLine }
        #expect(rows.count == 2, "cambiar solo los cambios con v2 no saca ninguna fila")
        for row in rows { #expect(try fields(row)["amount_changes_raw"] == nil) }
        #expect(SyncCapability.suppressedCashFlowAmountChanges == [salary.id])
        _ = plain
    }

    @Test func drain_v3_sendsTheChanges_onAnEditOfOnlyThem() throws {
        let restoreCapability = isolateCapability(backend: 3)
        defer { restoreCapability() }
        let dir = freshDir()
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let salary = line(context, "Salario")
        try context.save()
        engine.drainOnce(context: context)

        salary.amountChangesRaw = changes
        try context.save()
        engine.drainOnce(context: context)

        let salaryID = salary.id
        let rows = try outbox(context).filter { $0.syncID == salaryID }
        #expect(rows.count == 2)
        let update = try #require(rows.last)
        let updateFields = try fields(update)
        #expect(Set(updateFields.keys) == ["amount_changes_raw"])
        #expect(updateFields["amount_changes_raw"] as? String == changes)
        #expect(SyncCapability.suppressedCashFlowAmountChanges.isEmpty)
    }

    // MARK: - Ida y vuelta

    @Test func roundTrip_changesEmittedOnOnePhone_arriveIntactOnTheOther() throws {
        let restoreCapability = isolateCapability(backend: 3)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let salary = line(phoneA, "Salario")
        salary.amountChangesRaw = changes
        try phoneA.save()
        let emission = EntityEmissionMap.cashFlowLine
        let emitted = DeltaEmitter.emit(model: salary, emission: emission, changedColumns: emission.columns, hlc: hlc(2))
        let fieldsJSON = try Canonc1Codec.encode(emitted.fields, groupedColumns: Set(emission.groupByColumn.keys))
        let hlcs = emitted.fieldHlcs.keys.sorted().map { "\"\($0)\":\"\(hlc(2))\"" }.joined(separator: ",")
        let delta = """
        {"entity_type":"cashflow_lines","sync_id":"\(salary.id.uuidString.lowercased())","op":"upsert",\
        "fields":\(fieldsJSON),"field_hlcs":{\(hlcs)},"hlc":"\(hlc(2))","server_seq":2,"schema_version":1}
        """
        let json = "{\"deltas\":[\(delta)],\"max_server_seq\":2,\"manifest_version\":3}"
        let page = try SyncPullClient.decodePage(Data(json.utf8))

        let phoneB = try makeContext(freshDir())
        let engineB = CloudSyncEngine()
        #expect(engineB.applyPage(page, context: phoneB, now: applyNow))
        let salaryID = salary.id
        let arrived = try #require(try phoneB.fetch(FetchDescriptor<CashFlowLine>()).first { $0.id == salaryID })
        #expect(arrived.amountChangesRaw == changes)
        #expect(arrived.amountChanges.count == 2)
    }

    // MARK: - La subida de v2 a v3

    @Test func upgradeFromV2ToV3_asksForTheUpgrade() {
        let restoreCapability = isolateCapability(backend: 2)
        defer { restoreCapability() }
        #expect(SyncCapability.declaredLevel == 2)
        #expect(!SyncCapability.upgradePending)
        SyncCapability.recordBackendManifestVersion(3)
        #expect(SyncCapability.declaredLevel == 3)
        #expect(SyncCapability.upgradePending, "hasta la v3, solo cruzar a la v2 pedía la subida")
    }

    /// La v3 también llega al actualizar la app: un build v2 ya había apuntado que el Worker anuncia la 3 y seguía
    /// declarando la 2. Con el build nuevo, el siguiente apunte tiene que pedir la subida aunque el backend no cambie.
    @Test func upgradeByUpdatingTheApp_asksForTheUpgrade() {
        let restoreCapability = isolateCapability(backend: 3)
        defer { restoreCapability() }
        SyncCapability.defaults.set(2, forKey: SyncCapability.lastDeclaredLevelKey)   // lo que declaró el build v2
        #expect(SyncCapability.declaredLevel == 3)
        SyncCapability.recordBackendManifestVersion(3)
        #expect(SyncCapability.upgradePending, "la v3 llegó con la app y nadie pidió volver a bajar")
    }

    /// Sin apunte (el build de antes no lo escribía) se supone una versión menos.
    @Test func upgradeByUpdatingTheApp_withoutTheNote_alsoAsks() {
        let restoreCapability = isolateCapability(backend: 3)
        defer { restoreCapability() }
        SyncCapability.recordBackendManifestVersion(3)
        #expect(SyncCapability.upgradePending)
        SyncCapability.upgradePending = false
        SyncCapability.recordBackendManifestVersion(3)
        #expect(!SyncCapability.upgradePending, "con el apunte ya escrito, el mismo nivel no vuelve a pedirla")
    }

    @Test func pull_upgradeToV3_reemitsTheNotedLine_withOnlyTheChanges() async throws {
        let restoreCapability = isolateCapability(backend: 2)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let salary = line(context, "Salario")
        try context.save()
        engine.drainOnce(context: context)
        salary.amountChangesRaw = changes
        try context.save()
        engine.drainOnce(context: context)
        for row in try outbox(context) { context.delete(row) }   // lo demás ya subió
        try context.save()
        #expect(SyncCapability.suppressedCashFlowAmountChanges == [salary.id])

        let announce = "{\"deltas\":[],\"max_server_seq\":0,\"manifest_version\":3}"
        let session = CashFlowCapabilitySession(bodies: [Data(announce.utf8)])
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!, tokenProvider: { "jwt" },
                                    urlSession: session)
        _ = await engine.pullAndApplyOnce(using: client, context: context)

        #expect(session.capabilityHeaders.first == "v2")
        #expect(session.capabilityHeaders.contains("v3"))
        let salaryID = salary.id
        let reemitted = try #require(try outbox(context).last { $0.syncID == salaryID })
        #expect(Set(try fields(reemitted).keys) == ["amount_changes_raw"], "solo la columna, no la fila entera")
        #expect(try fields(reemitted)["amount_changes_raw"] as? String == changes)
        #expect(!SyncCapability.upgradePending)
        #expect(SyncCapability.suppressedCashFlowAmountChanges.isEmpty)
    }

    @Test func upgradeWithTheWorkerBackAtV2_keepsTheNotedLines() throws {
        let restoreCapability = isolateCapability(backend: 2)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let salary = line(context, "Salario")
        try context.save()
        SyncCapability.noteSuppressedCashFlowAmountChange(salary.id)
        SyncCapability.upgradePending = true   // pedida y el Worker volvió a la v2 antes de cumplirse

        #expect(try engine.applyCapabilityUpgradeIfPending(context: context))

        #expect(try outbox(context).filter { $0.syncID == salary.id }.isEmpty, "con v2 la columna no viajaría")
        #expect(SyncCapability.suppressedCashFlowAmountChanges == [salary.id], "se queda para la subida a v3")
    }
}

// MARK: - Stub

private final class CashFlowCapabilitySession: SyncHTTPSession, @unchecked Sendable {
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
