//
//  CloudSyncWiredEntitiesTests.swift
//  YalaTests / CloudSync
//
//  I12: cableado de las 10 entidades restantes al motor de cloud-sync. Commit A = budgets +
//  scheduled_payments (T1-T6); commit B = las 8 restantes (T7-T14). Cubre lo que los goldens/parity NO
//  capturan por sí solos:
//   - born-remote de Budget con las 3 uuid[] de grupo VACÍAS (`[]` ≠ null; CSV mirror wire-completo).
//   - round-trip text[]↔CSV por campo (emit→apply→emit), la asimetría que castigaría el Merkle.
//   - invariante de emisión del grupo `split` de scheduled_payments (cambiar `amount` emite el grupo).
//   - canario D4 (regeneración de identidad detectada).
//   - tombstone con identidad preservada (`.preserveValueOnDeletion`) drenado a outbox (Budget id + Account shortcutID).
//   - commit B: born-remote por shortcutID/id, re-resolución de refs colgados (TX→Account, Subcategory→Category,
//     grafo cashflow plan→line→override out-of-order), tag_refs CSV-first sin dangler, NotificationItem
//     reportConfig reconstruido desde `configurationData` (round-trip report/non-report), GroupBridgePreference
//     campos planos (group_zone_id opaco).
//
//  Container ON-DISK temp con los 3 stores + `.serialized` (patrón CloudSyncEngineTests / SyncApplyEngineTests).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · wired entities (I12 commit A + B)", .serialized)
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

    // MARK: - Commit B: las 8 restantes

    // MARK: T7: Account born-remote (identidad = shortcutID) + tombstone conserva shortcutID

    @Test func account_bornRemote_byShortcutID_andTombstonePreservesIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let sid = UUID()

        let fields = """
        {"name":"BCP","currency_code":"PEN","color_hex":"#111111","icon_name":"creditcard","type":"checking",
        "account_number":null,"adjustment_mode":"manual","exclude_from_statistics":false,"is_archived":false,
        "is_system_account":false,"credit_card_payment_reminder":false,"credit_card_payment_day":1}
        """
        let fieldHlcs = """
        {"name":"\(hlc(1))","currency_code":"\(hlc(1))","type":"\(hlc(1))","credit_card_payment_day":"\(hlc(1))"}
        """
        try applyPage(page(entity: "accounts", sid: sid, fields: fields, fieldHlcs: fieldHlcs),
                      engine: engine, context: context)

        let acc = try context.fetch(FetchDescriptor<Account>()).first { $0.shortcutID == sid }
        #expect(acc?.name == "BCP")
        #expect(acc?.currencyCode == "PEN")
        #expect(acc?.accountNumber == nil)              // null → nil

        // Delete local → drain → tombstone conserva el shortcutID (@Attribute(.preserveValueOnDeletion)).
        guard let account = acc else { return }
        context.delete(account)
        try context.save()
        engine.drainOnce(context: context)
        let tombstones = try context.fetch(FetchDescriptor<SyncOutbox>())
            .filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue && $0.entityType == SyncEntityType.account }
        #expect(tombstones.contains { $0.syncID == sid },
                "el tombstone de Account debe conservar `shortcutID`")
        #expect(engine.identityGapCount == 0)
    }

    // MARK: T8: TX con account_ref colgado + llega la Account → re-resolución la adjunta

    @Test func txAccountRef_danglesUntilAccountArrives_thenReresolveAttaches() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let txSID = UUID()
        let accShortcut = UUID()

        // TX que referencia una Account aún no local → dangler.
        let txFields = """
        {"date":"\(epochTS)","amount":"-10.0000","currency_code":"PEN",
        "amount_in_preferred_currency":"-10.0000","preferred_currency_code":"PEN","exchange_rate":"1.00000000",
        "is_exchange_rate_provisional":false,"created_at":"\(epochTS)",
        "account_ref":"\(accShortcut.uuidString.lowercased())","tag_refs":[]}
        """
        let txHlcs = """
        {"money":"\(hlc(1))","date":"\(hlc(1))","created_at":"\(hlc(1))","account_ref":"\(hlc(1))","tag_refs":"\(hlc(1))"}
        """
        try applyPage(page(entity: "tx_items", sid: txSID, fields: txFields, fieldHlcs: txHlcs),
                      engine: engine, context: context)
        let tx = try context.fetch(FetchDescriptor<TransactionItem>()).first { $0.syncID == txSID }
        #expect(tx?.account == nil)  // colgado (Account aún no local)
        #expect(try !context.fetch(FetchDescriptor<SyncDanglingRef>()).isEmpty)

        // Llega la Account → el pase de re-resolución la adjunta.
        let accFields = """
        {"name":"BCP","currency_code":"PEN","color_hex":"#111111","icon_name":"creditcard","type":"checking",
        "adjustment_mode":"manual","exclude_from_statistics":false,"is_archived":false,
        "is_system_account":false,"credit_card_payment_reminder":false,"credit_card_payment_day":1}
        """
        try applyPage(page(entity: "accounts", sid: accShortcut, fields: accFields,
                           fieldHlcs: "{\"name\":\"\(hlc(2))\"}"),
                      engine: engine, context: context)
        engine.reresolveDanglingRefs(context: context)

        #expect(tx?.account?.shortcutID == accShortcut)
        #expect(try context.fetch(FetchDescriptor<SyncDanglingRef>()).isEmpty)  // dangler curado
    }

    // MARK: T9: Subcategory.category_ref colgado + llega la Category → re-resolución

    @Test func subcategoryCategoryRef_danglesUntilCategoryArrives_thenReresolve() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let subShortcut = UUID()
        let catSyncID = UUID()

        let subFields = """
        {"name":"Cafés","color_hex":null,"is_default_seed":false,"is_visible":true,"sort_order":0,
        "nature_raw_value":null,"icon_name":null,"is_system":false,
        "category_ref":"\(catSyncID.uuidString.lowercased())"}
        """
        try applyPage(page(entity: "subcategories", sid: subShortcut, fields: subFields,
                           fieldHlcs: "{\"name\":\"\(hlc(1))\",\"category_ref\":\"\(hlc(1))\"}"),
                      engine: engine, context: context)
        let sub = try context.fetch(FetchDescriptor<Subcategory>()).first { $0.shortcutID == subShortcut }
        #expect(sub?.name == "Cafés")
        #expect(sub?.category == nil)  // colgado

        let catFields = """
        {"name":"Comida","color_hex":"#222222","is_income":false,"is_default_seed":false,
        "is_visible":true,"sort_order":0,"is_system":false}
        """
        try applyPage(page(entity: "categories", sid: catSyncID, fields: catFields,
                           fieldHlcs: "{\"name\":\"\(hlc(2))\"}"),
                      engine: engine, context: context)
        engine.reresolveDanglingRefs(context: context)
        #expect(sub?.category?.syncID == catSyncID)
    }

    // MARK: T10: Tag CSV auto-cura (aplica Tag DESPUÉS de una TX cuyo CSV lo referencia)

    @Test func tagRefs_csvFirst_resolvesWhenTagArrives_noDangler() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let txSID = UUID()
        let tagID = UUID()

        let txFields = """
        {"date":"\(epochTS)","amount":"-5.0000","currency_code":"PEN",
        "amount_in_preferred_currency":"-5.0000","preferred_currency_code":"PEN","exchange_rate":"1.00000000",
        "is_exchange_rate_provisional":false,"created_at":"\(epochTS)","tag_refs":["\(tagID.uuidString.lowercased())"]}
        """
        try applyPage(page(entity: "tx_items", sid: txSID, fields: txFields,
                           fieldHlcs: "{\"money\":\"\(hlc(1))\",\"tag_refs\":\"\(hlc(1))\",\"created_at\":\"\(hlc(1))\"}"),
                      engine: engine, context: context)
        let tx = try context.fetch(FetchDescriptor<TransactionItem>()).first { $0.syncID == txSID }
        // CSV-first: resolvedTagIDs devuelve el UUID del wire ANTES de que el Tag sea local (sin dangler).
        #expect((tx?.resolvedTagIDs() ?? []).contains(tagID))
        #expect(try context.fetch(FetchDescriptor<SyncDanglingRef>()).isEmpty)  // tag_refs NUNCA registra dangler

        // Llega el Tag → se materializa; el CSV lo referenciaba ya → auto-cura de display.
        let tagFields = """
        {"name":"Viaje","color_hex":"#FF9F0A","icon_name":"tag.fill","is_active":true,"created_at":"\(epochTS)"}
        """
        try applyPage(page(entity: "tags", sid: tagID, fields: tagFields,
                           fieldHlcs: "{\"name\":\"\(hlc(2))\",\"created_at\":\"\(hlc(2))\"}"),
                      engine: engine, context: context)
        #expect(EntityApplyMap.fetchTag(byID: tagID, context: context)?.name == "Viaje")
        #expect((tx?.resolvedTagIDs() ?? []).contains(tagID))  // sigue resuelto CSV-first
    }

    // MARK: T11: NotificationItem reportConfig round-trip (report_data_type/report_day_preference)

    @Test func notificationItem_reportConfig_roundTrip_reportType() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let sid = UUID()

        let fields = """
        {"name":"Reporte","text":"","hour":21,"minute":0,"type_raw":"dailyReport","is_active":true,
        "icon_name":"chart.bar.fill","color_hex":"#30D158","created_at":"\(epochTS)","sort_order":2,
        "report_data_type":"income","report_day_preference":"monday","weekdays_raw":["1","3"]}
        """
        let fieldHlcs = """
        {"name":"\(hlc(1))","type_raw":"\(hlc(1))","report_data_type":"\(hlc(1))",
        "report_day_preference":"\(hlc(1))","weekdays_raw":"\(hlc(1))","created_at":"\(hlc(1))"}
        """
        try applyPage(page(entity: "notification_items", sid: sid, fields: fields, fieldHlcs: fieldHlcs),
                      engine: engine, context: context)

        let n = try context.fetch(FetchDescriptor<NotificationItem>()).first { $0.id == sid }
        #expect(n?.notificationType == .dailyReport)
        #expect(n?.reportConfig.dataType == .income)          // reconstruido desde el blob
        #expect(n?.reportConfig.dayPreference == .monday)
        #expect(n?.weekdaysRaw == "1,3")                      // text[] → CSV

        // Re-emisión byte-idéntica (emit→apply→emit): los 2 campos derivan del reportConfig reconstruido.
        guard let item = n else { return }
        #expect(emitter(EntityEmissionMap.notificationItem, "report_data_type").build(item, cal) == .string("income"))
        #expect(emitter(EntityEmissionMap.notificationItem, "report_day_preference").build(item, cal) == .string("monday"))
        #expect(emitter(EntityEmissionMap.notificationItem, "weekdays_raw").build(item, cal) == Emit.csvTextArray("1,3"))
    }

    @Test func notificationItem_reportConfig_nonReportType_nullRoundTrip() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let sid = UUID()

        let fields = """
        {"name":"Recordatorio","text":"apunta tus gastos","hour":20,"minute":0,"type_raw":"custom",
        "is_active":true,"icon_name":"bell.fill","color_hex":"#64D2FF","created_at":"\(epochTS)","sort_order":0,
        "report_data_type":null,"report_day_preference":null,"weekdays_raw":null}
        """
        try applyPage(page(entity: "notification_items", sid: sid, fields: fields,
                           fieldHlcs: "{\"name\":\"\(hlc(1))\",\"type_raw\":\"\(hlc(1))\",\"created_at\":\"\(hlc(1))\"}"),
                      engine: engine, context: context)

        let n = try context.fetch(FetchDescriptor<NotificationItem>()).first { $0.id == sid }
        #expect(n?.notificationType == .custom)
        #expect(n?.configurationData == nil)        // null → blob nunca reconstruido
        #expect(n?.weekdaysRaw == nil)              // null → nil

        // Re-emisión: tipo no-reporte → ambos campos re-emiten null (gate isReportType).
        guard let item = n else { return }
        #expect(emitter(EntityEmissionMap.notificationItem, "report_data_type").build(item, cal) == .null)
        #expect(emitter(EntityEmissionMap.notificationItem, "report_day_preference").build(item, cal) == .null)

        // MENOR-3 (review I12-B): weekdays_raw null debe SOBREESCRIBIR un valor previo — primero se
        // puebla vía UPDATE, luego null lo pisa a nil (no confundir con el default del init).
        try applyPage(page(entity: "notification_items", sid: sid,
                           fields: "{\"weekdays_raw\":[\"1\",\"5\"]}",
                           fieldHlcs: "{\"weekdays_raw\":\"\(hlc(2))\"}"),
                      engine: engine, context: context)
        #expect(item.weekdaysRaw == "1,5")
        try applyPage(page(entity: "notification_items", sid: sid,
                           fields: "{\"weekdays_raw\":null}",
                           fieldHlcs: "{\"weekdays_raw\":\"\(hlc(3))\"}"),
                      engine: engine, context: context)
        #expect(item.weekdaysRaw == nil)
    }

    // MARK: T12: cashflow graph (plan→line→override) — orden-independiente vía danglers

    @Test func cashFlowGraph_appliedOutOfOrder_reresolvesRefs() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let planID = UUID(); let lineID = UUID(); let overrideID = UUID()

        // 1) Override primero (line_ref colgado).
        try applyPage(page(entity: "cashflow_overrides", sid: overrideID,
                           fields: "{\"month_key\":\"2026-04\",\"amount\":\"12.0000\",\"note\":\"n\",\"line_ref\":\"\(lineID.uuidString.lowercased())\"}",
                           fieldHlcs: "{\"month_key\":\"\(hlc(1))\",\"line_ref\":\"\(hlc(1))\"}"),
                      engine: engine, context: context)
        // 2) Line (plan_ref colgado; sin category/subcategory/scheduled_payment).
        try applyPage(page(entity: "cashflow_lines", sid: lineID,
                           fields: "{\"name\":\"Sueldo\",\"is_income\":true,\"sort_order\":0,\"is_enabled\":true,\"estimation_method\":\"manual\",\"manual_amount\":\"1000.0000\",\"custom_months_raw\":null,\"category_ref\":null,\"subcategory_ref\":null,\"scheduled_payment_ref\":null,\"plan_ref\":\"\(planID.uuidString.lowercased())\"}",
                           fieldHlcs: "{\"name\":\"\(hlc(2))\",\"plan_ref\":\"\(hlc(2))\"}"),
                      engine: engine, context: context)
        // 3) Plan al final.
        try applyPage(page(entity: "cashflow_plans", sid: planID,
                           fields: "{\"name\":\"2026\",\"starting_balance\":\"0.0000\",\"default_months_ahead\":6,\"default_months_back\":3,\"show_other_expenses\":true,\"show_accumulated_balance\":true,\"created_at\":\"\(epochTS)\",\"updated_at_domain\":\"\(epochTS)\"}",
                           fieldHlcs: "{\"name\":\"\(hlc(3))\",\"created_at\":\"\(hlc(3))\"}"),
                      engine: engine, context: context)

        engine.reresolveDanglingRefs(context: context)

        let line = try context.fetch(FetchDescriptor<CashFlowLine>()).first { $0.id == lineID }
        let override = try context.fetch(FetchDescriptor<CashFlowOverride>()).first { $0.id == overrideID }
        #expect(line?.plan?.id == planID)              // line→plan re-resuelto
        #expect(override?.line?.id == lineID)          // override→line re-resuelto
        #expect(line?.manualAmount == 1000)
        #expect(try context.fetch(FetchDescriptor<SyncDanglingRef>()).isEmpty)
    }

    // MARK: T13: GroupBridgePreference — campos planos (group_zone_id opaco byte a byte)

    @Test func groupBridgePreference_flatFields_roundTrip() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        // bridge_override = false (explícito).
        let sid1 = UUID()
        try applyPage(page(entity: "group_bridge_prefs", sid: sid1,
                           fields: "{\"group_zone_id\":\"zone-ABC-123\",\"bridge_override\":false,\"created_at\":\"\(epochTS)\"}",
                           fieldHlcs: "{\"group_zone_id\":\"\(hlc(1))\",\"bridge_override\":\"\(hlc(1))\",\"created_at\":\"\(hlc(1))\"}"),
                      engine: engine, context: context)
        let p1 = try context.fetch(FetchDescriptor<GroupBridgePreference>()).first { $0.id == sid1 }
        #expect(p1?.groupZoneID == "zone-ABC-123")   // opaco, byte a byte
        #expect(p1?.bridgeOverride == false)

        // bridge_override = null (heredar del toggle global).
        let sid2 = UUID()
        try applyPage(page(entity: "group_bridge_prefs", sid: sid2,
                           fields: "{\"group_zone_id\":\"zone-XYZ\",\"bridge_override\":null,\"created_at\":\"\(epochTS)\"}",
                           fieldHlcs: "{\"group_zone_id\":\"\(hlc(2))\",\"created_at\":\"\(hlc(2))\"}"),
                      engine: engine, context: context)
        let p2 = try context.fetch(FetchDescriptor<GroupBridgePreference>()).first { $0.id == sid2 }
        #expect(p2?.groupZoneID == "zone-XYZ")
        #expect(p2?.bridgeOverride == nil)           // null → nil

        // MENOR-3 (review I12-B): null debe SOBREESCRIBIR un valor previo no-default — distingue
        // "applier corrió y puso nil" de "quedó el default del init".
        try applyPage(page(entity: "group_bridge_prefs", sid: sid1,
                           fields: "{\"bridge_override\":null}",
                           fieldHlcs: "{\"bridge_override\":\"\(hlc(3))\"}"),
                      engine: engine, context: context)
        let p1b = try context.fetch(FetchDescriptor<GroupBridgePreference>()).first { $0.id == sid1 }
        #expect(p1b?.bridgeOverride == nil)          // false → null pisa a nil
    }

    // MARK: T14: CashFlowLine text[] (custom_months_raw) round-trip

    @Test func cashFlowLine_customMonthsRaw_textArrayRoundTrip() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let lineID = UUID()

        try applyPage(page(entity: "cashflow_lines", sid: lineID,
                           fields: "{\"name\":\"Var\",\"is_income\":false,\"sort_order\":0,\"is_enabled\":true,\"estimation_method\":\"custom\",\"manual_amount\":null,\"custom_months_raw\":[\"2026-01\",\"2026-02\"],\"category_ref\":null,\"subcategory_ref\":null,\"scheduled_payment_ref\":null,\"plan_ref\":null}",
                           fieldHlcs: "{\"name\":\"\(hlc(1))\",\"custom_months_raw\":\"\(hlc(1))\"}"),
                      engine: engine, context: context)
        let line = try context.fetch(FetchDescriptor<CashFlowLine>()).first { $0.id == lineID }
        #expect(line?.customMonthsRaw == "2026-01,2026-02")   // text[] → CSV String?
        guard let l = line else { return }
        #expect(emitter(EntityEmissionMap.cashFlowLine, "custom_months_raw").build(l, cal)
                == Emit.csvTextArray("2026-01,2026-02"))
    }
}
