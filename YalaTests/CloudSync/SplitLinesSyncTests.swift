//
//  SplitLinesSyncTests.swift
//  YalaTests / CloudSync
//
//  Grupos B, card 1, por el Modo Nube: la columna `tx_items.split_lines_raw` (la receta de tu parte de un gasto de grupo
//  en líneas) con `since: 6`. Lo que fija, con el molde de `CashFlowAmountChangeSyncTests`:
//   - con `v5` la columna ni se emite (un Worker v5 rechazaría la fila entera) y lo cambiado se APUNTA, también al
//     vaciarla; con `v6`, sí;
//   - ida y vuelta: lo que un teléfono emite en v6, otro lo aplica intacto, y vaciarla también viaja;
//   - al subir de v5 a v6 se reemiten los movimientos apuntados, con SOLO esa columna, y se re-baja desde 0.
//  La ida y vuelta contra el Worker de staging desplegado la mide `qa/cloud/g28_01-staging-probe.sh`.
//
//  Container ON-DISK temp con los 3 stores + `.serialized`. `SyncCapability.defaults` se aísla en cada caso.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · Grupos B: receta de líneas de tu parte (split_lines_raw, v6)", .serialized)
@MainActor
struct SplitLinesSyncTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SplitLines-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "SL-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "SL-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "SL-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
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

    /// Una pata de grupo como la del Caso B de Pía: −510 en «Grupos», con su `splitExpenseID`.
    private func groupLeg(_ context: ModelContext, note: String = "Recarga Sip") -> TransactionItem {
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: -510, currencyCode: "PEN",
                                 note: note)
        tx.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        tx.splitExpenseID = UUID().uuidString
        context.insert(tx)
        return tx
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func fields(_ row: SyncOutbox) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(row.fieldsJSON.utf8)) as? [String: Any] ?? [:]
    }

    /// Lo que guarda `GroupSplitLinesRecipe` para el caso de Pía: recarga 500 a Sip + comisión 10.
    private let recipe: String = GroupSplitLinesRecipe.encode([
        .transfer(amount: 500, destinationAccountID: UUID()),
        .expense(amount: 10, subcategoryID: UUID()),
    ]) ?? "<encode falló>"


    // MARK: - Emisión

    @Test func emission_v6_carriesTheRecipe_v5_doesNot() throws {
        let context = try makeContext(freshDir())
        let leg = groupLeg(context)
        leg.syncID = UUID()
        leg.splitLinesRaw = recipe
        let emission = EntityEmissionMap.transactionItem

        let v6 = DeltaEmitter.emit(model: leg, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 6)
        #expect(v6.fields["split_lines_raw"] == .string(recipe))
        #expect(v6.fieldHlcs["split_lines_raw"] == hlc(1))

        let v5 = DeltaEmitter.emit(model: leg, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 5)
        #expect(v5.fields["split_lines_raw"] == nil)
        #expect(v5.fields["note"] == .string("Recarga Sip"), "el resto de la fila sí viaja")

        let onlyRecipe = DeltaEmitter.emit(model: leg, emission: emission, changedColumns: ["split_lines_raw"],
                                           hlc: hlc(1), capabilityLevel: 5)
        #expect(onlyRecipe.fields.isEmpty && onlyRecipe.fieldHlcs.isEmpty)
    }

    /// Un movimiento sin receta en v6 la manda como `null`: es lo que tiene el servidor en toda fila de antes, y el
    /// Merkle de las dos orillas tiene que decir lo mismo.
    @Test func emission_v6_withoutARecipe_sendsNull() throws {
        let context = try makeContext(freshDir())
        let leg = groupLeg(context)
        leg.syncID = UUID()
        let emission = EntityEmissionMap.transactionItem
        let v6 = DeltaEmitter.emit(model: leg, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 6)
        #expect(v6.fields["split_lines_raw"] == .null)
    }

    // MARK: - Drain

    @Test func drain_v5_neverSendsTheColumn_andNotesTheRow_alsoWhenEmptied() throws {
        let restoreCapability = isolateCapability(backend: 5)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let leg = groupLeg(context)
        let plain = groupLeg(context, note: "Súper")
        try context.save()
        engine.drainOnce(context: context)
        #expect(SyncCapability.suppressedSplitLines.isEmpty, "sin receta no hay nada que apuntar")

        leg.splitLinesRaw = recipe
        try context.save()
        engine.drainOnce(context: context)

        let rows = try outbox(context).filter { $0.entityType == SyncEntityType.transactionItem }
        #expect(rows.count == 2, "cambiar solo la receta con v5 no saca ninguna fila")
        for row in rows { #expect(try fields(row)["split_lines_raw"] == nil) }
        let legID = try #require(leg.syncID)
        #expect(SyncCapability.suppressedSplitLines == [legID])

        // Vaciarla también se apunta: el servidor tiene que acabar sin la receta que este teléfono quitó.
        SyncCapability.clearSuppressedSplitLines([legID])
        leg.splitLinesRaw = nil
        try context.save()
        engine.drainOnce(context: context)
        #expect(SyncCapability.suppressedSplitLines == [legID])
        _ = plain
    }

    @Test func drain_v6_sendsTheRecipe_onAnEditOfOnlyIt() throws {
        let restoreCapability = isolateCapability(backend: 6)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let leg = groupLeg(context)
        try context.save()
        engine.drainOnce(context: context)

        leg.splitLinesRaw = recipe
        try context.save()
        engine.drainOnce(context: context)

        let legID = try #require(leg.syncID)
        let rows = try outbox(context).filter { $0.syncID == legID }
        #expect(rows.count == 2)
        let update = try #require(rows.last)
        let updateFields = try fields(update)
        #expect(Set(updateFields.keys) == ["split_lines_raw"])
        #expect(updateFields["split_lines_raw"] as? String == recipe)
        #expect(SyncCapability.suppressedSplitLines.isEmpty)
    }

    // MARK: - Ida y vuelta

    private func page(for leg: TransactionItem, columns: Set<String>, counter: Int) throws -> PulledPage {
        let emission = EntityEmissionMap.transactionItem
        let emitted = DeltaEmitter.emit(model: leg, emission: emission, changedColumns: columns, hlc: hlc(counter))
        let fieldsJSON = try Canonc1Codec.encode(emitted.fields, groupedColumns: Set(emission.groupByColumn.keys))
        let hlcs = emitted.fieldHlcs.keys.sorted().map { "\"\($0)\":\"\(hlc(counter))\"" }.joined(separator: ",")
        let syncID = try #require(leg.syncID).uuidString.lowercased()
        let delta = """
        {"entity_type":"tx_items","sync_id":"\(syncID)","op":"upsert",\
        "fields":\(fieldsJSON),"field_hlcs":{\(hlcs)},"hlc":"\(hlc(counter))","server_seq":\(counter),"schema_version":1}
        """
        let json = "{\"deltas\":[\(delta)],\"max_server_seq\":\(counter),\"manifest_version\":6}"
        return try SyncPullClient.decodePage(Data(json.utf8))
    }

    @Test func roundTrip_recipeEmittedOnOnePhone_arrivesIntactOnTheOther_andEmptyingItTravelsToo() throws {
        let restoreCapability = isolateCapability(backend: 6)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let leg = groupLeg(phoneA)
        leg.syncID = UUID()
        leg.splitLinesRaw = recipe
        try phoneA.save()

        let phoneB = try makeContext(freshDir())
        let engineB = CloudSyncEngine()
        #expect(engineB.applyPage(try page(for: leg, columns: EntityEmissionMap.transactionItem.columns, counter: 2),
                                  context: phoneB, now: applyNow))
        let legID = try #require(leg.syncID)
        let arrived = try #require(try phoneB.fetch(FetchDescriptor<TransactionItem>()).first { $0.syncID == legID })
        #expect(arrived.splitLinesRaw == recipe)
        guard case .recipe(let lines) = GroupSplitLinesRecipe.parse(arrived.splitLinesRaw) else {
            Issue.record("la receta llegó y no se lee: \(String(describing: arrived.splitLinesRaw))")
            return
        }
        #expect(lines.count == 2)

        leg.splitLinesRaw = nil
        try phoneA.save()
        #expect(engineB.applyPage(try page(for: leg, columns: ["split_lines_raw"], counter: 3),
                                  context: phoneB, now: applyNow))
        let emptied = try #require(try phoneB.fetch(FetchDescriptor<TransactionItem>()).first { $0.syncID == legID })
        #expect(emptied.splitLinesRaw == nil, "vaciar la receta en un teléfono la vacía en el otro")
        #expect(emptied.note == "Recarga Sip")
    }

    // MARK: - La subida de v5 a v6

    @Test func upgradeFromV5ToV6_asksForTheUpgrade() {
        let restoreCapability = isolateCapability(backend: 5)
        defer { restoreCapability() }
        SyncCapability.defaults.set(5, forKey: SyncCapability.lastDeclaredLevelKey)
        #expect(SyncCapability.declaredLevel == 5)
        SyncCapability.recordBackendManifestVersion(6)
        #expect(SyncCapability.declaredLevel == 6)
        #expect(SyncCapability.upgradePending)
    }

    @Test func pull_upgradeToV6_reemitsTheNotedRow_withOnlyTheRecipe() async throws {
        let restoreCapability = isolateCapability(backend: 5)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let leg = groupLeg(context)
        try context.save()
        engine.drainOnce(context: context)
        leg.splitLinesRaw = recipe
        try context.save()
        engine.drainOnce(context: context)
        for row in try outbox(context) { context.delete(row) }   // lo demás ya subió
        try context.save()
        let legID = try #require(leg.syncID)
        #expect(SyncCapability.suppressedSplitLines == [legID])

        let announce = "{\"deltas\":[],\"max_server_seq\":0,\"manifest_version\":6}"
        let session = SplitLinesCapabilitySession(bodies: [Data(announce.utf8)])
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!, tokenProvider: { "jwt" },
                                    urlSession: session)
        _ = await engine.pullAndApplyOnce(using: client, context: context)

        #expect(session.capabilityHeaders.first == "v5")
        #expect(session.capabilityHeaders.contains("v6"))
        let reemitted = try #require(try outbox(context).last { $0.syncID == legID })
        #expect(Set(try fields(reemitted).keys) == ["split_lines_raw"], "solo la columna, no la fila entera")
        #expect(try fields(reemitted)["split_lines_raw"] as? String == recipe)
        #expect(!SyncCapability.upgradePending)
        #expect(SyncCapability.suppressedSplitLines.isEmpty)
    }

    @Test func upgradeWithTheWorkerBackAtV5_keepsTheNotedRows() throws {
        let restoreCapability = isolateCapability(backend: 5)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let leg = groupLeg(context)
        leg.syncID = UUID()
        try context.save()
        let legID = try #require(leg.syncID)
        SyncCapability.noteSuppressedSplitLines(legID)
        SyncCapability.upgradePending = true   // pedida y el Worker volvió a la v5 antes de cumplirse

        #expect(try engine.applyCapabilityUpgradeIfPending(context: context))

        #expect(try outbox(context).filter { $0.syncID == legID }.isEmpty, "con v5 la columna no viajaría")
        #expect(SyncCapability.suppressedSplitLines == [legID], "se queda para la subida a v6")
    }
}

// MARK: - Stub

private final class SplitLinesCapabilitySession: SyncHTTPSession, @unchecked Sendable {
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
