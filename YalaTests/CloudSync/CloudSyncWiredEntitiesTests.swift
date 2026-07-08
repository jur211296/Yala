//
//  CloudSyncWiredEntitiesTests.swift
//  YalaTests / CloudSync
//
//  Commit A de I12: cableado de `budgets` y `scheduled_payments` al motor de cloud-sync. Cubre lo que
//  los goldens/parity NO capturan por sí solos:
//   - born-remote de Budget con las 3 uuid[] de grupo VACÍAS (`[]` ≠ null; CSV mirror wire-completo).
//   - round-trip text[]↔CSV por campo (emit→apply→emit), la asimetría que castigaría el Merkle.
//   - invariante de emisión del grupo `split` de scheduled_payments (cambiar `amount` emite el grupo).
//   - canario D4 (regeneración de identidad detectada).
//   - tombstone con `id` preservado (`.preserveValueOnDeletion`) drenado a outbox.
//
//  Container ON-DISK temp con los 3 stores + `.serialized` (patrón CloudSyncEngineTests / SyncApplyEngineTests).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · budgets + scheduled_payments (I12 commit A)", .serialized)
@MainActor
struct CloudSyncWiredEntitiesTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CSWired-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CSW-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "CSW-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "CSW-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private let node = "0123456789abcdef"
    private let epochTS = "2023-11-14T22:13:20.000Z"
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }
    private let cal = Calendar(identifier: .gregorian)

    /// Arma una página del pull con UN upsert de `entity`, dado el fragmento `fields` y `field_hlcs`.
    private func page(entity: String, sid: UUID, fields: String, fieldHlcs: String, serverSeq: Int = 1) -> String {
        let h = hlc(1)
        return """
        {"deltas":[{"entity_type":"\(entity)","sync_id":"\(sid.uuidString.lowercased())","op":"upsert",
        "fields":\(fields),"field_hlcs":\(fieldHlcs),
        "hlc":"\(h)","server_seq":\(serverSeq),"schema_version":1}],"max_server_seq":\(serverSeq)}
        """
    }

    private func applyPage(_ json: String, engine: CloudSyncEngine, context: ModelContext) throws {
        let p = try SyncPullClient.decodePage(Data(json.utf8))
        #expect(engine.applyPage(p, context: context, now: applyNow))
    }

    private func emitter<M>(_ emission: EntityEmission<M>, _ column: String) -> ColumnEmitter<M> {
        emission.emitters.first { $0.column == column }!
    }

    // MARK: - T1: born-remote de Budget con uuid[] de grupo VACÍAS

    @Test func budget_bornRemote_emptyUUIDGroups_materializeEmpty_reEmitAsEmptyArray() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let sid = UUID()

        let fields = """
        {"name":"Ocio","currency_code":"USD","limit_amount":"250.0000","period_type":"monthly",
        "category_id":null,"is_active":true,"created_at":"\(epochTS)","is_favorite":false,
        "favorite_order":0,"alert_enabled":false,"include_shared_expenses":true,
        "subcategory_ids":[],"account_ids":[],"tag_refs":[]}
        """
        let fieldHlcs = """
        {"budget":"\(hlc(1))","name":"\(hlc(1))","period_type":"\(hlc(1))","is_active":"\(hlc(1))",
        "created_at":"\(hlc(1))","is_favorite":"\(hlc(1))","favorite_order":"\(hlc(1))",
        "alert_enabled":"\(hlc(1))","include_shared_expenses":"\(hlc(1))"}
        """
        try applyPage(page(entity: "budgets", sid: sid, fields: fields, fieldHlcs: fieldHlcs),
                      engine: engine, context: context)

        let budget = try context.fetch(FetchDescriptor<Budget>()).first { $0.id == sid }
        #expect(budget != nil)
        #expect(budget?.name == "Ocio")
        #expect(budget?.limitAmount == 250)
        #expect(budget?.category == nil)                 // category_id null → nil
        // uuid[] VACÍAS: M2M vacía + CSV mirror nil (CSVMirrorCodec.encode([]) == nil = "sin filtro").
        #expect(budget?.subcategories?.isEmpty ?? true)
        #expect(budget?.accounts?.isEmpty ?? true)
        #expect(budget?.tags?.isEmpty ?? true)
        #expect(budget?.subcategoryIDs == nil)
        #expect(budget?.accountIDs == nil)
        #expect(budget?.tagIDs == nil)

        // Re-emisión: una uuid[] de grupo vacía viaja `[]` explícita (DIFERIDOS #25) → wire-completo.
        guard let b = budget else { return }
        #expect(emitter(EntityEmissionMap.budget, "subcategory_ids").build(b, cal) == .uuidArray([]))
        #expect(emitter(EntityEmissionMap.budget, "account_ids").build(b, cal) == .uuidArray([]))
        #expect(emitter(EntityEmissionMap.budget, "tag_refs").build(b, cal) == .uuidArray([]))
    }

    // MARK: - T2: Budget text[] (natures / alert_thresholds) round-trip por campo

    @Test func budget_textArrayColumns_roundTrip_csv() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let sid = UUID()

        let fields = """
        {"name":"B","currency_code":"USD","limit_amount":"10.0000","period_type":"monthly",
        "is_active":true,"created_at":"\(epochTS)","is_favorite":false,"favorite_order":0,
        "alert_enabled":true,"include_shared_expenses":true,
        "natures":["essential","priority"],"alert_thresholds":["50","75","100"],
        "subcategory_ids":[],"account_ids":[],"tag_refs":[]}
        """
        let fieldHlcs = """
        {"budget":"\(hlc(1))","name":"\(hlc(1))","period_type":"\(hlc(1))","is_active":"\(hlc(1))",
        "created_at":"\(hlc(1))","is_favorite":"\(hlc(1))","favorite_order":"\(hlc(1))",
        "alert_enabled":"\(hlc(1))","include_shared_expenses":"\(hlc(1))","alert_thresholds":"\(hlc(1))"}
        """
        try applyPage(page(entity: "budgets", sid: sid, fields: fields, fieldHlcs: fieldHlcs),
                      engine: engine, context: context)

        let budget = try context.fetch(FetchDescriptor<Budget>()).first { $0.id == sid }
        // apply: text[] → CSV local (join ","). natures está en el grupo `budget`.
        #expect(budget?.natures == "essential,priority")
        #expect(budget?.alertThresholds == "50,75,100")

        // emit(B) == valor canónico esperado (byte-idéntico vía CanonValue Equatable).
        guard let b = budget else { return }
        #expect(emitter(EntityEmissionMap.budget, "natures").build(b, cal) == Emit.csvTextArray("essential,priority"))
        #expect(emitter(EntityEmissionMap.budget, "alert_thresholds").build(b, cal) == Emit.csvTextArray("50,75,100"))
    }

    @Test func budget_textArrayColumns_null_mapsToNil() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let sid = UUID()
        // natures/alert_thresholds ausentes en el init (nil) → tras aplicar null siguen nil.
        let fields = """
        {"name":"B","currency_code":"USD","limit_amount":"10.0000","period_type":"monthly",
        "is_active":true,"created_at":"\(epochTS)","is_favorite":false,"favorite_order":0,
        "alert_enabled":false,"include_shared_expenses":true,
        "natures":null,"alert_thresholds":null,"subcategory_ids":[],"account_ids":[],"tag_refs":[]}
        """
        let fieldHlcs = """
        {"budget":"\(hlc(1))","name":"\(hlc(1))","period_type":"\(hlc(1))","is_active":"\(hlc(1))",
        "created_at":"\(hlc(1))","is_favorite":"\(hlc(1))","favorite_order":"\(hlc(1))",
        "alert_enabled":"\(hlc(1))","include_shared_expenses":"\(hlc(1))"}
        """
        try applyPage(page(entity: "budgets", sid: sid, fields: fields, fieldHlcs: fieldHlcs),
                      engine: engine, context: context)
        let budget = try context.fetch(FetchDescriptor<Budget>()).first { $0.id == sid }
        #expect(budget?.natures == nil)         // null → nil (columna opcional)
        #expect(budget?.alertThresholds == nil)
    }

    // MARK: - T3: ScheduledPayment text[] (selected_weekdays / skipped_dates_raw)

    @Test func scheduledPayment_textArrayColumns_roundTrip() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let sid = UUID()

        let fields = """
        {"name":"Luz","currency_code":"USD","amount":"30.0000","transaction_type":"expense",
        "is_variable_amount":false,"is_recurring":true,"recurrence_type":"weekly","recurrence_interval":1,
        "next_due_date":"\(epochTS)","payment_category":"recurring","notify_on_due_date":true,
        "notify_days_before":0,"is_active":true,"created_at":"\(epochTS)",
        "selected_weekdays":["1","3","5"],"skipped_dates_raw":["2026-01-01","2026-02-02"]}
        """
        let fieldHlcs = """
        {"split":"\(hlc(1))","name":"\(hlc(1))","currency_code":"\(hlc(1))","transaction_type":"\(hlc(1))",
        "is_recurring":"\(hlc(1))","recurrence_type":"\(hlc(1))","next_due_date":"\(hlc(1))",
        "is_active":"\(hlc(1))","created_at":"\(hlc(1))","selected_weekdays":"\(hlc(1))",
        "skipped_dates_raw":"\(hlc(1))"}
        """
        try applyPage(page(entity: "scheduled_payments", sid: sid, fields: fields, fieldHlcs: fieldHlcs),
                      engine: engine, context: context)

        let sp = try context.fetch(FetchDescriptor<ScheduledPayment>()).first { $0.id == sid }
        #expect(sp?.selectedWeekdays == "1,3,5")                    // text[] → CSV String?
        #expect(sp?.skippedDatesRaw == "2026-01-01,2026-02-02")     // text[] → CSV String (non-opt)

        guard let s = sp else { return }
        #expect(emitter(EntityEmissionMap.scheduledPayment, "selected_weekdays").build(s, cal)
                == Emit.csvTextArray("1,3,5"))
        #expect(emitter(EntityEmissionMap.scheduledPayment, "skipped_dates_raw").build(s, cal)
                == Emit.csvTextArray("2026-01-01,2026-02-02"))
    }

    @Test func scheduledPayment_textArray_null_semantics() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let sid = UUID()
        // selected_weekdays (String?) null → nil; skipped_dates_raw (String non-opt) null → "".
        let fields = """
        {"name":"Luz","currency_code":"USD","amount":"30.0000","transaction_type":"expense",
        "is_variable_amount":false,"is_recurring":true,"recurrence_type":"monthly","recurrence_interval":1,
        "next_due_date":"\(epochTS)","payment_category":"recurring","notify_on_due_date":true,
        "notify_days_before":0,"is_active":true,"created_at":"\(epochTS)",
        "selected_weekdays":null,"skipped_dates_raw":null}
        """
        let fieldHlcs = """
        {"split":"\(hlc(1))","name":"\(hlc(1))","currency_code":"\(hlc(1))","transaction_type":"\(hlc(1))",
        "is_recurring":"\(hlc(1))","recurrence_type":"\(hlc(1))","next_due_date":"\(hlc(1))",
        "is_active":"\(hlc(1))","created_at":"\(hlc(1))"}
        """
        try applyPage(page(entity: "scheduled_payments", sid: sid, fields: fields, fieldHlcs: fieldHlcs),
                      engine: engine, context: context)
        let sp = try context.fetch(FetchDescriptor<ScheduledPayment>()).first { $0.id == sid }
        #expect(sp?.selectedWeekdays == nil)     // null → nil
        #expect(sp?.skippedDatesRaw == "")       // null → "" (default no-opcional)
    }

    // MARK: - T4: invariante de emisión del grupo `split` (cambiar amount emite el grupo entero)

    @Test func scheduledPayment_changingAmount_emitsWholeSplitGroup() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        let sp = ScheduledPayment(name: "Cena", amount: 100, currencyCode: "USD", nextDueDate: applyNow)
        sp.groupZoneID = "zone-1"
        sp.splitTotalAmount = 200            // total; amount=100 es MI-PARTE (lo que leen los consumidores)
        sp.splitType = "equal"
        sp.splitParticipantIDsRaw = "\(UUID().uuidString):1"
        sp.splitValuesRaw = "\(UUID().uuidString):1"
        context.insert(sp)
        try context.save()
        engine.drainOnce(context: context)   // captura el INSERT

        // Editar SOLO amount → el emisor expande al grupo `split` completo.
        sp.amount = 120
        try context.save()
        engine.drainOnce(context: context)

        // La fila de outbox más nueva (el update) debe llevar TODO el grupo split en `fields`.
        let rows = try context.fetch(FetchDescriptor<SyncOutbox>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))
        guard let update = rows.first(where: { $0.entityType == SyncEntityType.scheduledPayment }) else {
            Issue.record("no hay fila de outbox de scheduled_payments"); return
        }
        let fields = try JSONSerialization.jsonObject(with: Data(update.fieldsJSON.utf8)) as? [String: Any] ?? [:]
        for column in ["amount", "split_total_amount", "split_type", "split_participant_ids_raw", "split_values_raw"] {
            #expect(fields.keys.contains(column), "el grupo split debe emitirse entero; falta \(column)")
        }
        // Y el amount emitido es MI-PARTE (120), no el total.
        #expect((update.fieldHlcsJSON ?? "").contains("split"))
    }

    // MARK: - T5: canario D4 (regeneración de identidad)

    @Test func budget_identityRegeneration_firesCanaryD4() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        let budget = Budget(currencyCode: "USD", limitAmount: 50)
        context.insert(budget)
        try context.save()
        engine.drainOnce(context: context)
        #expect(engine.identityMutationObservedCount == 0)

        // Regenerar `id` + tocar un campo real (repairCollapsedIdentityUUIDs-like).
        let newID = UUID()
        budget.id = newID
        budget.limitAmount = 999
        try context.save()
        engine.drainOnce(context: context)

        #expect(engine.identityMutationObservedCount == 1)   // canario D4 se disparó
        // El upsert emitido lleva la identidad NUEVA (fila nueva server-side; la vieja quedaría huérfana
        // hasta IdentityRemap — DIFERIDOS #29).
        let rows = try context.fetch(FetchDescriptor<SyncOutbox>())
            .filter { $0.entityType == SyncEntityType.budget && $0.opRaw == SyncOutboxOp.upsert.rawValue }
        #expect(rows.contains { $0.syncID == newID })
    }

    // MARK: - T6: tombstone con `id` preservado drenado a outbox

    @Test func budget_delete_emitsTombstone_withPreservedID() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        let budget = Budget(currencyCode: "USD", limitAmount: 50)
        let budgetID = budget.id
        context.insert(budget)
        try context.save()
        engine.drainOnce(context: context)     // INSERT capturado

        context.delete(budget)
        try context.save()
        engine.drainOnce(context: context)     // DELETE → tombstone

        let tombstones = try context.fetch(FetchDescriptor<SyncOutbox>())
            .filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue && $0.entityType == SyncEntityType.budget }
        #expect(tombstones.contains { $0.syncID == budgetID },
                "el tombstone debe conservar el `id` del Budget (@Attribute(.preserveValueOnDeletion))")
        #expect(engine.identityGapCount == 0)  // el id preservado NO produjo un gap de identidad
    }
}
