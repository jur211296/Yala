//
//  BandejaUnirSyncTests.swift
//  YalaTests
//
//  Bandeja sin duplicados, lote 2 · Modo Nube: lo que se unió viaja en `inbox_drafts.join_record_raw` (manifest v11).
//  Molde de `LimiteTarjetaSyncTests`: con un Worker v10 la columna no sale y se apunta; al subir a v11 se reemite sola;
//  entre dos teléfonos v11 llega y «Separar» (NULL) también; un teléfono v10 no la pisa.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Bandeja sin duplicados · Modo Nube (join_record_raw, v11)", .serialized)
@MainActor
struct BandejaUnirSyncTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BandejaUnir-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("No se pudo crear el directorio: \(error)")
        }
        retireTestStoreDirectoryLater(dir)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "BU-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "BU-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "BU-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
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

    private let record = #"{"holderAfter":{"note":"Starbucks"},"members":[],"version":1}"#

    private func draft(_ context: ModelContext, joined: String? = nil) -> InboxDraft {
        let draft = InboxDraft(note: "Starbucks", amount: -42.5, date: Date(timeIntervalSince1970: 1_700_000_000),
                               sourceType: .applePay)
        draft.syncID = UUID()
        draft.joinRecordRaw = joined
        context.insert(draft)
        return draft
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func fields(_ row: SyncOutbox) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(row.fieldsJSON.utf8)) as? [String: Any] ?? [:]
    }

    @Test func capability_v11_estrenaLaColumna() {
        #expect(SyncCapability.inboxJoinRecordSince == 11)
        #expect(SyncCapability.clientManifestVersion >= SyncCapability.inboxJoinRecordSince)
        #expect(EntityEmissionMap.inboxDraft.columns.contains("join_record_raw"))
    }

    @Test func emission_v11_llevaLoUnido_v10_no() throws {
        let context = try makeContext(freshDir())
        let joined = draft(context, joined: record)
        let emission = EntityEmissionMap.inboxDraft
        let v11 = DeltaEmitter.emit(model: joined, emission: emission, changedColumns: emission.columns,
                                    hlc: hlc(1), capabilityLevel: 11)
        #expect(v11.fields["join_record_raw"] == .string(record))
        let v10 = DeltaEmitter.emit(model: joined, emission: emission, changedColumns: emission.columns,
                                    hlc: hlc(1), capabilityLevel: 10)
        #expect(v10.fields["join_record_raw"] == nil)
        #expect(v10.fields["note"] == .string("Starbucks"), "el resto de la fila sí viaja")
        let plain = DeltaEmitter.emit(model: draft(context), emission: emission, changedColumns: emission.columns,
                                      hlc: hlc(2), capabilityLevel: 11)
        #expect(plain.fields["join_record_raw"] == .null, "Sin nada unido viaja NULL, como la columna nace en el servidor.")
    }

    @Test func drain_v10_apuntaElBorrador_v11_mandaSoloLoUnido() throws {
        let restoreCapability = isolateCapability(backend: 10)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let holder = draft(context)
        let syncID = try #require(holder.syncID)
        try context.save()
        engine.drainOnce(context: context)

        holder.joinRecordRaw = record
        try context.save()
        engine.drainOnce(context: context)
        #expect(try outbox(context).filter { $0.syncID == syncID }.count == 1,
                "con v10, cambiar solo lo unido no saca ninguna fila")
        #expect(SyncCapability.suppressedInboxJoinRecords == [syncID])

        SyncCapability.defaults.set(11, forKey: SyncCapability.backendManifestVersionKey)
        holder.joinRecordRaw = nil
        try context.save()
        engine.drainOnce(context: context)
        let update = try #require(try outbox(context).last { $0.syncID == syncID })
        #expect(Set(try fields(update).keys) == ["join_record_raw"])
    }

    private func page(for draft: InboxDraft, columns: Set<String>, counter: Int, level: Int = 11) throws -> PulledPage {
        let emission = EntityEmissionMap.inboxDraft
        let emitted = DeltaEmitter.emit(model: draft, emission: emission, changedColumns: columns, hlc: hlc(counter),
                                        capabilityLevel: level)
        let fieldsJSON = try Canonc1Codec.encode(emitted.fields, groupedColumns: Set(emission.groupByColumn.keys))
        let hlcs = emitted.fieldHlcs.keys.sorted().map { "\"\($0)\":\"\(hlc(counter))\"" }.joined(separator: ",")
        let syncID = try #require(draft.syncID).uuidString.lowercased()
        let delta = """
        {"entity_type":"inbox_drafts","sync_id":"\(syncID)","op":"upsert",\
        "fields":\(fieldsJSON),"field_hlcs":{\(hlcs)},"hlc":"\(hlc(counter))","server_seq":\(counter),"schema_version":1}
        """
        let json = "{\"deltas\":[\(delta)],\"max_server_seq\":\(counter),\"manifest_version\":\(level)}"
        return try SyncPullClient.decodePage(Data(json.utf8))
    }

    @Test func criterio_loUnidoViajaEntreDosTelefonos_ySepararTambien() throws {
        let restoreCapability = isolateCapability(backend: 11)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let holder = draft(phoneA, joined: record)
        try phoneA.save()

        let phoneB = try makeContext(freshDir())
        let engineB = CloudSyncEngine()
        #expect(engineB.applyPage(try page(for: holder, columns: EntityEmissionMap.inboxDraft.columns, counter: 2),
                                  context: phoneB, now: applyNow))
        let arrived = try #require(try phoneB.fetch(FetchDescriptor<InboxDraft>()).first { $0.syncID == holder.syncID })
        #expect(arrived.joinRecordRaw == record)

        holder.joinRecordRaw = nil
        try phoneA.save()
        #expect(engineB.applyPage(try page(for: holder, columns: ["join_record_raw"], counter: 3),
                                  context: phoneB, now: applyNow))
        #expect(arrived.joinRecordRaw == nil, "separar en un teléfono lo separa en el otro")
        #expect(arrived.note == "Starbucks")
    }

    /// Un Worker o un teléfono que aún hablan v10 no conocen la columna: lo que bajan no borra lo unido aquí.
    @Test func compatibilidad_unaFilaSinLaColumna_noBorraLoUnido() throws {
        let restoreCapability = isolateCapability(backend: 10)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let remote = draft(phoneA)
        remote.note = "Starbucks Larcomar"
        try phoneA.save()

        let phoneB = try makeContext(freshDir())
        let engineB = CloudSyncEngine()
        let local = InboxDraft(note: "Starbucks", amount: -42.5, sourceType: .applePay)
        local.syncID = remote.syncID
        local.joinRecordRaw = record
        phoneB.insert(local)
        try phoneB.save()
        #expect(engineB.applyPage(try page(for: remote, columns: EntityEmissionMap.inboxDraft.columns, counter: 2,
                                           level: 10), context: phoneB, now: applyNow))
        #expect(local.note == "Starbucks Larcomar", "el cambio de la otra versión sí llega")
        #expect(local.joinRecordRaw == record, "y lo unido, que esa versión no conoce, se queda")
    }

    @Test func subirAv11_reemiteElBorradorApuntado_soloConLoUnido() throws {
        let restoreCapability = isolateCapability(backend: 10)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let holder = draft(context)
        let syncID = try #require(holder.syncID)
        try context.save()
        engine.drainOnce(context: context)
        holder.joinRecordRaw = record
        try context.save()
        engine.drainOnce(context: context)
        for row in try outbox(context) { context.delete(row) }
        try context.save()
        #expect(SyncCapability.suppressedInboxJoinRecords == [syncID])

        SyncCapability.defaults.set(10, forKey: SyncCapability.lastDeclaredLevelKey)
        SyncCapability.recordBackendManifestVersion(11)
        #expect(SyncCapability.upgradePending)
        #expect(try engine.applyCapabilityUpgradeIfPending(context: context))

        let reemitted = try #require(try outbox(context).last { $0.syncID == syncID })
        #expect(Set(try fields(reemitted).keys) == ["join_record_raw"])
        #expect(SyncCapability.suppressedInboxJoinRecords.isEmpty)
    }
}
