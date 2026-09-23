//
//  SyncApplyEngineTests.swift
//  YalaTests / CloudSync
//
//  El grueso del apply del pull (I8f-1): materialización full-row con skip por-unidad (D-0/D-1), born-
//  remote (D-8), tombstones (D-9), cursor atómico (D-5), reloj (D-3), anti-laundering (D-2), paginación
//  (D-2b), echo idempotente. Los deltas se construyen DECODIFICANDO JSON de wire (`SyncPullClient.
//  decodePage`) → se testea también el decoder end-to-end. Container ON-DISK temp con los 3 stores
//  (patrón CloudSyncEngineTests). `.serialized` (≥2 containers por proceso).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("SyncApplyEngine · apply del pull I8f-1", .serialized)
@MainActor
struct SyncApplyEngineTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SyncApplyEngine-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContainer(_ dir: URL) throws -> ModelContainer {
        let personalCfg = ModelConfiguration(
            "SAE-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "SAE-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "SAE-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        return try ModelContainer(for: SwiftDataConfiguration.schema,
                                  configurations: personalCfg, groupsCfg, syncMetaCfg)
    }

    private func decodePage(_ json: String) throws -> PulledPage {
        try SyncPullClient.decodePage(Data(json.utf8))
    }

    private let node = "0123456789abcdef"
    /// HLC c1 con physicalMs = 1_700_000_000_000 (2023-11-14T22:13:20Z), counter variable.
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }
    /// `now` inyectado al `receive` del reloj — 100 s tras las HLC (past remote → sin drift).
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)
    private let epochTS = "2023-11-14T22:13:20.000Z"
    private let epochDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func txItems(_ context: ModelContext) -> [TransactionItem] {
        (try? context.fetch(FetchDescriptor<TransactionItem>())) ?? []
    }
    private func outbox(_ context: ModelContext) -> [SyncOutbox] {
        (try? context.fetch(FetchDescriptor<SyncOutbox>())) ?? []
    }
    private func cursor(_ context: ModelContext) -> SyncCursor? {
        try? context.fetch(FetchDescriptor<SyncCursor>()).first
    }
    private func identity(bySyncID id: UUID, _ context: ModelContext) -> SyncIdentity? {
        EntityApplyMap.fetchSyncIdentity(bySyncID: id, context: context)
    }

    /// JSON de una página con UN upsert de tx_items full-row.
    private func txPage(sid: UUID, serverSeq: Int, h: String,
                        amount: String = "10.5000", aip: String = "38.0000", rate: String = "3.62000000",
                        note: String = "hola", tagUUID: UUID? = nil) -> String {
        let tagJSON = tagUUID.map { "[\"\($0.uuidString.lowercased())\"]" } ?? "[]"
        return #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"date":"\#(epochTS)","amount":"\#(amount)","currency_code":"USD","note":"\#(note)",
        "amount_in_preferred_currency":"\#(aip)","preferred_currency_code":"PEN","exchange_rate":"\#(rate)",
        "is_exchange_rate_provisional":false,"created_at":"\#(epochTS)","tag_refs":\#(tagJSON)},
        "field_hlcs":{"money":"\#(h)","date":"\#(h)","note":"\#(h)","currency_code":"\#(h)",
        "tag_refs":"\#(h)","created_at":"\#(h)"},
        "hlc":"\#(h)","server_seq":\#(serverSeq),"schema_version":1}],"max_server_seq":\#(serverSeq)}
        """#
    }

    // MARK: - 1. Upsert born-remote

    @Test func apply_upsertBornRemote_createsWithFixedSyncID_moneyVerbatim() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let tagUUID = UUID()  // tag NO local
        let page = try decodePage(txPage(sid: sid, serverSeq: 5, h: hlc(1), tagUUID: tagUUID))
        engine.applyPage(page, context: context, now: applyNow)

        let all = txItems(context)
        #expect(all.count == 1)
        let tx = try #require(all.first)
        #expect(tx.syncID == sid)                         // syncID FIJADO (sweep no re-acuña)
        #expect(tx.amount == 10.5)                        // money verbatim
        #expect(tx.amountInPreferredCurrency == 38.0)     // NO recomputado (verbatim)
        #expect(tx.exchangeRate == 3.62)
        #expect(tx.date == epochDate)
        #expect(tx.note == "hola")
        #expect(tx.currencyCode == "USD")
        // tag_refs: CSV = wire COMPLETO (tag no local → M2M vacío, CSV conserva el UUID).
        #expect(tx.tagIDsSet == [tagUUID])
        #expect((tx.tags ?? []).isEmpty)
        // Fila testigo SyncIdentity born-remote.
        #expect(identity(bySyncID: sid, context) != nil)
        // Cursor avanzó.
        #expect(cursor(context)?.serverSeqCursor == 5)
    }

    // MARK: - 2. Full-row preserva la unidad pendiente local

    @Test func apply_fullRow_preservesPendingUnit_materializesRest() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        // Fila local existente, ya sincronizada (syncID), money=100, note viejo.
        let sid = UUID()
        let tx = TransactionItem(date: epochDate, amount: 100, currencyCode: "USD", note: "old")
        tx.syncID = sid
        tx.amountInPreferredCurrency = 300
        context.insert(tx)
        try context.save()

        // Outbox pendiente: money@H3 (más nuevo que el remoto H2).
        let row = SyncOutbox(syncID: sid, entityType: SyncEntityType.transactionItem, op: .upsert,
                             hlc: hlc(3), fieldsJSON: "{}", fieldHlcsJSON: #"{"money":"\#(hlc(3))"}"#, author: "")
        context.insert(row)
        try context.save()

        // Full-row remoto: money@H2 (más viejo → SKIP), note@H4 (aplica).
        let json = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"amount":"55.0000","amount_in_preferred_currency":"200.0000","preferred_currency_code":"PEN",
        "exchange_rate":"3.62000000","is_exchange_rate_provisional":false,"note":"new"},
        "field_hlcs":{"money":"\#(hlc(2))","note":"\#(hlc(4))"},"hlc":"\#(hlc(4))","server_seq":8,"schema_version":1}],
        "max_server_seq":8}
        """#
        engine.applyPage(try decodePage(json), context: context, now: applyNow)

        #expect(tx.amount == 100)                       // money local INTACTO (H3 >= H2 → skip)
        #expect(tx.amountInPreferredCurrency == 300)    // resto del grupo money también intacto
        #expect(tx.note == "new")                       // note materializado (sin guard local)
    }

    // MARK: - 2b. Echo del propio push → estado idéntico, 0 filas outbox nuevas

    @Test func apply_echoOfOwnPush_isIdempotent_noNewOutbox() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        // Escritura local + drain → 1 fila outbox con el HLC del drain.
        let tx = TransactionItem(date: epochDate, amount: 10, currencyCode: "USD")
        tx.createdAt = epochDate
        context.insert(tx)
        try context.save()
        engine.drainOnce(context: context)
        let pushed = try #require(outbox(context).first)
        let sid = try #require(tx.syncID)
        let Hd = pushed.hlc
        #expect(outbox(context).count == 1)

        // Echo: full-row remoto con el MISMO HLC (>= → skip todas las unidades) y mismos valores.
        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 3, h: Hd, amount: "10.0000")),
                         context: context, now: applyNow)

        #expect(tx.amount == 10)                 // estado idéntico
        #expect(outbox(context).count == 1)      // 0 filas outbox nuevas
        // Nota honesta (F-10b): este assert de drain es por VACUIDAD — el guard D-1 saltó todas las
        // unidades, así que el apply no escribió nada que capturar. El D-4 real (writes del apply bajo
        // outboxSaveAuthor → el drain NO los captura) lo cubre apply_thenDrain_producesNoOutboxRows.
        engine.drainOnce(context: context)
        #expect(outbox(context).count == 1)
    }

    // MARK: - 2c. Dead-letter NO bloquea la unidad remota

    @Test func apply_deadLetterRow_doesNotBlockRemoteUnit() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let tx = TransactionItem(date: epochDate, amount: 100, currencyCode: "USD")
        tx.syncID = sid
        context.insert(tx)
        try context.save()

        // Fila outbox DEAD-LETTER (rejected) money@H4 — NO debe contar en el guard.
        let row = SyncOutbox(syncID: sid, entityType: SyncEntityType.transactionItem, op: .upsert,
                             hlc: hlc(4), fieldsJSON: "{}", fieldHlcsJSON: #"{"money":"\#(hlc(4))"}"#, author: "")
        row.rejectedReason = "coherence_group_partial:money"
        context.insert(row)
        try context.save()

        // Remoto money@H2 → debe APLICARSE (el dead-letter no bloquea).
        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 6, h: hlc(2), amount: "55.0000")),
                         context: context, now: applyNow)
        #expect(tx.amount == 55)
    }

    // MARK: - 3. LWW por-unidad: money NO, note SÍ

    @Test func apply_lwwPerUnit_skipsMoney_appliesNote() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let tx = TransactionItem(date: epochDate, amount: 100, currencyCode: "USD", note: "old")
        tx.syncID = sid
        context.insert(tx)
        try context.save()

        let row = SyncOutbox(syncID: sid, entityType: SyncEntityType.transactionItem, op: .upsert,
                             hlc: hlc(3), fieldsJSON: "{}", fieldHlcsJSON: #"{"money":"\#(hlc(3))"}"#, author: "")
        context.insert(row)
        try context.save()

        let json = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"amount":"55.0000","amount_in_preferred_currency":"1.0000","preferred_currency_code":"PEN",
        "exchange_rate":"1.00000000","is_exchange_rate_provisional":false,"note":"new"},
        "field_hlcs":{"money":"\#(hlc(2))","note":"\#(hlc(4))"},"hlc":"\#(hlc(4))","server_seq":7,"schema_version":1}],
        "max_server_seq":7}
        """#
        engine.applyPage(try decodePage(json), context: context, now: applyNow)
        #expect(tx.amount == 100)   // money NO
        #expect(tx.note == "new")   // note SÍ
    }

    // MARK: - 4. Tombstones

    @Test func apply_tombstone_noPending_deletesModelAndIdentity() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 1, h: hlc(1))), context: context, now: applyNow)
        #expect(txItems(context).count == 1)
        #expect(identity(bySyncID: sid, context) != nil)

        let tomb = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"tombstone",
        "fields":{},"field_hlcs":{},"hlc":"\#(hlc(5))","server_seq":2,"schema_version":1}],"max_server_seq":2}
        """#
        engine.applyPage(try decodePage(tomb), context: context, now: applyNow)
        #expect(txItems(context).isEmpty)                    // modelo borrado
        #expect(identity(bySyncID: sid, context) == nil)     // identidad muerta
    }

    @Test func apply_tombstone_pendingNewerUpsert_doesNotDelete() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let tx = TransactionItem(date: epochDate, amount: 10, currencyCode: "USD")
        tx.syncID = sid
        context.insert(tx)
        try context.save()

        // Upsert local pendiente @H4 (más nuevo que el deleted_hlc H2).
        let row = SyncOutbox(syncID: sid, entityType: SyncEntityType.transactionItem, op: .upsert,
                             hlc: hlc(4), fieldsJSON: "{}", fieldHlcsJSON: #"{"money":"\#(hlc(4))"}"#, author: "")
        context.insert(row)
        try context.save()

        let tomb = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"tombstone",
        "fields":{},"field_hlcs":{},"hlc":"\#(hlc(2))","server_seq":9,"schema_version":1}],"max_server_seq":9}
        """#
        engine.applyPage(try decodePage(tomb), context: context, now: applyNow)
        #expect(txItems(context).count == 1)  // NO borrado (edición local ganará al pushear)
    }

    @Test func apply_tombstone_nonexistent_isNoOp_cursorAdvances() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let tomb = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(UUID().uuidString.lowercased())","op":"tombstone",
        "fields":{},"field_hlcs":{},"hlc":"\#(hlc(1))","server_seq":4,"schema_version":1}],"max_server_seq":4}
        """#
        engine.applyPage(try decodePage(tomb), context: context, now: applyNow)
        #expect(txItems(context).isEmpty)
        #expect(cursor(context)?.serverSeqCursor == 4)  // cursor avanza igual
    }

    // MARK: - 6. Cursor atómico: crash → cursor NO avanza → re-apply idempotente

    @Test func apply_crashBeforeCommit_cursorDoesNotAdvance_reapplyIdempotent() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        let context = ModelContext(container)
        let engine = CloudSyncEngine()

        let sid = UUID()
        let page = try decodePage(txPage(sid: sid, serverSeq: 5, h: hlc(1)))

        // Crash simulado: el save de la página LANZA → rollback (F-3) y `false`.
        engine._testThrowOnApplySave = true
        let ok = engine.applyPage(page, context: context, now: applyNow)
        #expect(ok == false)
        // F-3: el contexto queda LIMPIO tras el rollback (sin grafo remoto dirty que un autosave
        // posterior flushearía bajo autor no-motor → laundering).
        #expect(context.hasChanges == false)

        // Contexto FRESCO sobre el mismo store (= proceso reiniciado): estado pre-apply.
        let fresh = ModelContext(container)
        #expect(txItems(fresh).isEmpty)
        #expect((cursor(fresh)?.serverSeqCursor ?? 0) == 0)

        // Re-apply (sin crash) → aplica; y una TERCERA vez → idempotente (sin duplicar).
        let engine2 = CloudSyncEngine()
        engine2.applyPage(page, context: fresh, now: applyNow)
        #expect(txItems(fresh).count == 1)
        #expect(cursor(fresh)?.serverSeqCursor == 5)
        engine2.applyPage(page, context: fresh, now: applyNow)
        #expect(txItems(fresh).count == 1)              // sin duplicar
        #expect(cursor(fresh)?.serverSeqCursor == 5)
    }

    // MARK: - 7. Echo del drain (D-4): apply escribe bajo outboxSaveAuthor → drain no lo captura

    @Test func apply_thenDrain_producesNoOutboxRows() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        engine.applyPage(try decodePage(txPage(sid: UUID(), serverSeq: 1, h: hlc(1))), context: context, now: applyNow)
        #expect(txItems(context).count == 1)
        #expect(outbox(context).isEmpty)  // el apply NO crea outbox
        engine.drainOnce(context: context)
        #expect(outbox(context).isEmpty)  // el drain no re-captura (author = outboxSaveAuthor)
    }

    // MARK: - 8. Anti-laundering (D-2): drain ANTES de apply → el push lleva el valor del USUARIO

    @Test func pullAndApply_drainsFirst_userValueSurvives() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        // TX ya sincronizada (syncID), drenada y "subida" (outbox purgado).
        let sid = UUID()
        let tx = TransactionItem(date: epochDate, amount: 10, currencyCode: "USD")
        tx.syncID = sid
        tx.createdAt = epochDate
        context.insert(tx)
        try context.save()
        engine.drainOnce(context: context)
        for row in outbox(context) { context.delete(row) }
        try context.save()

        // El usuario EDITA localmente (amount 10 → 99) SIN drenar.
        tx.amount = 99
        try context.save()

        // Remoto (más viejo) intenta poner amount = 50.
        let page = txPage(sid: sid, serverSeq: 7, h: hlc(2), amount: "50.0000")
        let client = SyncPullClient(
            baseURL: URL(string: "https://example.test")!,
            tokenProvider: { "jwt" },
            urlSession: OneShotSession(body: Data(page.utf8))
        )
        _ = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow)

        // pullAndApplyOnce DRENA primero → la edición del usuario se captura al outbox con su valor (99)
        // y un HLC fresco (2026) → el remoto viejo se SALTA. El push llevará 99, no 50.
        #expect(tx.amount == 99)
        let pushed = try #require(outbox(context).first { $0.syncID == sid })
        #expect(pushed.fieldsJSON.contains("99"))     // el outbox lleva el valor del USUARIO
        #expect(!pushed.fieldsJSON.contains("50"))    // NO el remoto (no hubo laundering)
    }

    // MARK: - 9. Reloj (D-3): receive persiste; engine nuevo acuña HLC > al remoto

    @Test func apply_receivesRemoteClock_persistsAndAdvancesBeyondRemote() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        let context = ModelContext(container)
        let engine = CloudSyncEngine()

        let remoteHLC = hlc(5)
        engine.applyPage(try decodePage(txPage(sid: UUID(), serverSeq: 5, h: remoteHLC)),
                         context: context, now: applyNow)

        // El reloj recibido se PERSISTIÓ y es >= al remoto.
        let persisted = try #require(cursor(context)?.clockLatestHLC)
        #expect(try HLC.parse(persisted) >= HLC.parse(remoteHLC))

        // Engine FRESCO (nodeID nuevo): al drenar un write local acuña un HLC > al remoto (cargó el reloj).
        let engine2 = CloudSyncEngine()
        let local = TransactionItem(date: epochDate, amount: 1, currencyCode: "USD")
        context.insert(local)
        try context.save()
        engine2.drainOnce(context: context)
        let localRow = try #require(outbox(context).first { $0.syncID == local.syncID })
        #expect(try HLC.parse(localRow.hlc) > HLC.parse(remoteHLC))
    }

    // MARK: - 10. null explícito vs key ausente

    @Test func apply_nullExplicit_setsNil_absentKey_untouched() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let tx = TransactionItem(date: epochDate, amount: 5, currencyCode: "USD", note: "hello")
        tx.syncID = sid
        context.insert(tx)
        try context.save()

        // null explícito en `note` → nil.
        let nullNote = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"note":null},"field_hlcs":{"note":"\#(hlc(1))"},"hlc":"\#(hlc(1))","server_seq":2,"schema_version":1}],
        "max_server_seq":2}
        """#
        engine.applyPage(try decodePage(nullNote), context: context, now: applyNow)
        #expect(tx.note == nil)

        // key AUSENTE (`note` no viene) → no se toca (sigue nil), amount sí cambia.
        let noNote = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"amount":"9.0000","amount_in_preferred_currency":"9.0000","preferred_currency_code":"USD",
        "exchange_rate":"1.00000000","is_exchange_rate_provisional":false},
        "field_hlcs":{"money":"\#(hlc(2))"},"hlc":"\#(hlc(2))","server_seq":3,"schema_version":1}],"max_server_seq":3}
        """#
        engine.applyPage(try decodePage(noNote), context: context, now: applyNow)
        #expect(tx.note == nil)
        #expect(tx.amount == 9)
    }

    // MARK: - 11. Ref dangling → nil; tag no-local → CSV conserva el UUID del wire

    @Test func apply_danglingRef_nilAndTagCSVPreserved() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let tagUUID = UUID()
        let danglingCat = UUID()
        let json = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"amount":"5.0000","amount_in_preferred_currency":"5.0000","preferred_currency_code":"USD",
        "exchange_rate":"1.00000000","is_exchange_rate_provisional":false,
        "category_ref":"\#(danglingCat.uuidString.lowercased())","tag_refs":["\#(tagUUID.uuidString.lowercased())"]},
        "field_hlcs":{"money":"\#(hlc(1))","category_ref":"\#(hlc(1))","tag_refs":"\#(hlc(1))"},
        "hlc":"\#(hlc(1))","server_seq":1,"schema_version":1}],"max_server_seq":1}
        """#
        engine.applyPage(try decodePage(json), context: context, now: applyNow)
        let tx = try #require(txItems(context).first)
        #expect(tx.category == nil)              // ref no resuelve → nil (dangling)
        #expect(tx.tagIDsSet == [tagUUID])       // CSV conserva el UUID del wire (no-local)
    }

    // MARK: - 2d. Paginación (D-2b): 2+ páginas → cursor por página

    @Test func pullAndApply_paginatesMultiplePages() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        func catDelta(_ sid: UUID, _ seq: Int, _ name: String) -> String {
            #"""
            {"entity_type":"categories","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
            "fields":{"name":"\#(name)","color_hex":"#111111","is_income":false,"is_default_seed":false,
            "is_visible":true,"sort_order":0,"is_system":false},
            "field_hlcs":{"name":"\#(hlc(seq))"},"hlc":"\#(hlc(seq))","server_seq":\#(seq),"schema_version":1}
            """#
        }
        // Página 1: 2 deltas (== limit → hay más). Página 2: 1 delta (< limit → agotado).
        let page1 = "{\"deltas\":[\(catDelta(UUID(), 1, "A")),\(catDelta(UUID(), 2, "B"))],\"max_server_seq\":2}"
        let page2 = "{\"deltas\":[\(catDelta(UUID(), 3, "C"))],\"max_server_seq\":3}"
        let session = SequencedStubSession([Data(page1.utf8), Data(page2.utf8),
                                            Data(#"{"deltas":[],"max_server_seq":3}"#.utf8)])
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                    tokenProvider: { "jwt" }, urlSession: session)

        let outcome = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow,
                                                    pageLimit: 2, maxPages: 10)
        #expect(outcome == .completed(pagesApplied: 2))
        let cats = (try? context.fetch(FetchDescriptor<Yala.Category>())) ?? []
        #expect(cats.count == 3)
        #expect(cursor(context)?.serverSeqCursor == 3)
    }
    // MARK: - F-1. Laundering en la ventana del `await pull`: edición DURANTE la suspensión sobrevive

    @Test func pullAndApply_editDuringPullSuspension_userValueSurvives() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        // TX ya sincronizada, drenada y "subida" (outbox purgado).
        let sid = UUID()
        let tx = TransactionItem(date: epochDate, amount: 10, currencyCode: "USD")
        tx.syncID = sid
        tx.createdAt = epochDate
        context.insert(tx)
        try context.save()
        engine.drainOnce(context: context)
        for row in outbox(context) { context.delete(row) }
        try context.save()

        // Stub que simula el interleaving REAL: la edición del usuario aterriza DENTRO de la suspensión
        // del `await pull` (después del drain de entrada, antes de que la página llegue).
        let page = txPage(sid: sid, serverSeq: 7, h: hlc(2), amount: "50.0000")
        let session = EditingStubSession(body: Data(page.utf8)) { @MainActor in
            tx.amount = 99
            do { try context.save() } catch {
                Issue.record("save de la edición falló: \(error)")
            }
        }
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                    tokenProvider: { "jwt" }, urlSession: session)
        _ = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow)

        // F-1: el re-drain síncrono antes de applyPage capturó la edición → guard D-1 la protege.
        #expect(tx.amount == 99)
        let pushed = try #require(outbox(context).first { $0.syncID == sid })
        #expect(pushed.fieldsJSON.contains("99"))
        #expect(!pushed.fieldsJSON.contains("50"))
    }

    /// Gemelo del anterior con el re-drain ABORTADO (ticket `drain-duplicates-the-unit-clock-when-its-row-cannot-be-
    /// read`): su rollback deja la edición fuera del outbox, así que aplicar la página la pisaría con el guard D-1
    /// vacío. El pull corta sin aplicar y el cursor no avanza. Control positivo: el caso de arriba.
    @Test func pullAndApply_editDuringPullSuspension_drainAborts_pageIsNotApplied() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let tx = TransactionItem(date: epochDate, amount: 10, currencyCode: "USD")
        tx.syncID = sid
        tx.createdAt = epochDate
        context.insert(tx)
        try context.save()
        engine.drainOnce(context: context)
        for row in outbox(context) { context.delete(row) }
        try context.save()

        let page = txPage(sid: sid, serverSeq: 7, h: hlc(2), amount: "50.0000")
        let session = EditingStubSession(body: Data(page.utf8)) { @MainActor in
            tx.amount = 99
            do { try context.save() } catch {
                Issue.record("save de la edición falló: \(error)")
            }
            engine._testThrowOnDrainOutboxSave = true  // el re-drain previo al apply aborta
        }
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                    tokenProvider: { "jwt" }, urlSession: session)
        let outcome = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow)

        #expect(outcome == .transient(pagesApplied: 0))
        let stored = try ModelContext(context.container).fetch(FetchDescriptor<TransactionItem>())
        #expect(stored.first { $0.syncID == sid }?.amount == 99)
        #expect(cursor(context)?.serverSeqCursor == 0)

        // Y la vuelta siguiente, con el drain sano, sube la edición (no la pierde).
        engine._testThrowOnDrainOutboxSave = false
        #expect(engine.drainOnce(context: context))
        #expect(outbox(context).first { $0.syncID == sid }?.fieldsJSON.contains("99") == true)
    }

    // MARK: - F-3. Save de página falla → outcome .transient con conteo real

    @Test func pullAndApply_pageSaveFails_returnsTransientWithRealCount() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        engine._testThrowOnApplySave = true

        let page = txPage(sid: UUID(), serverSeq: 3, h: hlc(1))
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                    tokenProvider: { "jwt" },
                                    urlSession: OneShotSession(body: Data(page.utf8)))
        let outcome = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow)
        #expect(outcome == .transient(pagesApplied: 0))  // NO cuenta la página fallida; corta el loop
        #expect(context.hasChanges == false)             // rollback: sin grafo remoto dirty
        #expect(txItems(context).isEmpty)
    }

    // MARK: - Lecturas ilegibles: la página NO se aplica (ticket apply-overwrites-a-pending-local-write-without-its-guards)

    /// Fila local sincronizada (money=100, note "old") + outbox pendiente money@H3, y una página remota
    /// money@H2 / note@H4. Con el guard, money se salta y note se aplica.
    private func seedPendingMoneyAndRemotePage(_ context: ModelContext) throws -> (UUID, PulledPage) {
        let sid = UUID()
        let tx = TransactionItem(date: epochDate, amount: 100, currencyCode: "USD", note: "old")
        tx.syncID = sid
        tx.amountInPreferredCurrency = 300
        context.insert(tx)
        context.insert(SyncOutbox(syncID: sid, entityType: SyncEntityType.transactionItem, op: .upsert,
                                  hlc: hlc(3), fieldsJSON: "{}", fieldHlcsJSON: #"{"money":"\#(hlc(3))"}"#, author: ""))
        try context.save()
        let json = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"amount":"55.0000","amount_in_preferred_currency":"200.0000","preferred_currency_code":"PEN",
        "exchange_rate":"3.62000000","is_exchange_rate_provisional":false,"note":"new"},
        "field_hlcs":{"money":"\#(hlc(2))","note":"\#(hlc(4))"},"hlc":"\#(hlc(4))","server_seq":8,"schema_version":1}],
        "max_server_seq":8}
        """#
        return (sid, try decodePage(json))
    }

    @Test func apply_pendingGuardsUnreadable_pageNotApplied_localWriteSurvives_thenGuardedApply() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let container = try makeContainer(dir)
        let context = ModelContext(container)
        let engine = CloudSyncEngine()
        let (sid, page) = try seedPendingMoneyAndRemotePage(context)

        engine._testThrowOnApplyRead = .pendingGuards
        #expect(engine.applyPage(page, context: context, now: applyNow) == false)
        #expect(context.hasChanges == false)
        let fresh = ModelContext(container)
        let tx = try #require(txItems(fresh).first { $0.syncID == sid })
        #expect(tx.amount == 100)                          // el remoto NO pisó la escritura pendiente
        #expect(tx.note == "old")                          // ni siquiera la unidad sin guard: página entera fuera
        #expect((cursor(fresh)?.serverSeqCursor ?? 0) == 0) // cursor quieto → re-pull

        // Control positivo: la lectura vuelve → apply con guard (money se salta, note entra).
        engine._testThrowOnApplyRead = nil
        #expect(engine.applyPage(page, context: fresh, now: applyNow))
        #expect(tx.amount == 100)
        #expect(tx.amountInPreferredCurrency == 300)
        #expect(tx.note == "new")
        #expect(cursor(fresh)?.serverSeqCursor == 8)
    }

    @Test func pullAndApply_pendingGuardsUnreadable_returnsTransient_cursorStays() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        engine._testThrowOnApplyRead = .pendingGuards

        let page = txPage(sid: UUID(), serverSeq: 3, h: hlc(1))
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                    tokenProvider: { "jwt" },
                                    urlSession: OneShotSession(body: Data(page.utf8)))
        let outcome = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow)
        #expect(outcome == .transient(pagesApplied: 0))
        #expect(txItems(context).isEmpty)
        #expect((cursor(context)?.serverSeqCursor ?? 0) == 0)

        // Control positivo: MISMO cliente/fake, lectura de vuelta → la página entra (el fake no era el que fallaba).
        engine._testThrowOnApplyRead = nil
        let retry = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow)
        #expect(retry == .completed(pagesApplied: 1))
        #expect(txItems(context).count == 1)
        #expect(cursor(context)?.serverSeqCursor == 3)
    }

    @Test func apply_tombstone_rowLookupUnreadable_notCountedApplied_thenDeletes() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        #expect(engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 1, h: hlc(1))), context: context, now: applyNow))
        let tomb = try decodePage(#"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"tombstone",
        "fields":{},"field_hlcs":{},"hlc":"\#(hlc(5))","server_seq":2,"schema_version":1}],"max_server_seq":2}
        """#)

        EntityApplyMap._testThrowOnFetchOf = ["TransactionItem"]
        #expect(engine.applyPage(tomb, context: context, now: applyNow) == false)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(txItems(context).count == 1)                 // no se borró…
        #expect(cursor(context)?.serverSeqCursor == 1)       // …y el cursor NO lo da por hecho

        #expect(engine.applyPage(tomb, context: context, now: applyNow))   // control positivo
        #expect(txItems(context).isEmpty)
        #expect(identity(bySyncID: sid, context) == nil)
        #expect(cursor(context)?.serverSeqCursor == 2)
    }

    @Test func apply_tombstone_identityLookupUnreadable_pageNotApplied() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        #expect(engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 1, h: hlc(1))), context: context, now: applyNow))
        let tomb = try decodePage(#"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"tombstone",
        "fields":{},"field_hlcs":{},"hlc":"\#(hlc(5))","server_seq":2,"schema_version":1}],"max_server_seq":2}
        """#)

        EntityApplyMap._testThrowOnFetchOf = ["SyncIdentity"]
        #expect(engine.applyPage(tomb, context: context, now: applyNow) == false)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(txItems(context).count == 1)                 // ni la fila ni…
        #expect(identity(bySyncID: sid, context) != nil)     // …su identidad quedan a medias
        #expect(cursor(context)?.serverSeqCursor == 1)

        #expect(engine.applyPage(tomb, context: context, now: applyNow))   // control positivo
        #expect(txItems(context).isEmpty)
        #expect(identity(bySyncID: sid, context) == nil)
    }

    private func unitClocks(_ sid: UUID, _ context: ModelContext) -> [SyncUnitClock] {
        ((try? context.fetch(FetchDescriptor<SyncUnitClock>())) ?? []).filter { $0.syncID == sid }
    }

    @Test func apply_upsert_unitClockUnreadable_noSecondClock_thenMerges() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        #expect(engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 1, h: hlc(1))), context: context, now: applyNow))
        #expect(unitClocks(sid, context).count == 1)
        let update = try decodePage(txPage(sid: sid, serverSeq: 2, h: hlc(2), note: "editada"))

        EntityApplyMap._testThrowOnFetchOf = ["SyncUnitClock"]
        #expect(engine.applyPage(update, context: context, now: applyNow) == false)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(unitClocks(sid, context).count == 1)         // sin segundo reloj para el mismo syncID
        #expect(txItems(context).first?.note == "hola")
        #expect(cursor(context)?.serverSeqCursor == 1)

        #expect(engine.applyPage(update, context: context, now: applyNow))  // control positivo
        #expect(unitClocks(sid, context).count == 1)
        #expect(txItems(context).first?.note == "editada")
    }

    @Test func apply_tombstone_unitClockUnreadable_pageNotApplied_thenCleansClock() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        #expect(engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 1, h: hlc(1))), context: context, now: applyNow))
        let tomb = try decodePage(#"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"tombstone",
        "fields":{},"field_hlcs":{},"hlc":"\#(hlc(5))","server_seq":2,"schema_version":1}],"max_server_seq":2}
        """#)

        EntityApplyMap._testThrowOnFetchOf = ["SyncUnitClock"]
        #expect(engine.applyPage(tomb, context: context, now: applyNow) == false)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(txItems(context).count == 1)
        #expect(unitClocks(sid, context).count == 1)
        #expect(cursor(context)?.serverSeqCursor == 1)

        #expect(engine.applyPage(tomb, context: context, now: applyNow))   // control positivo
        #expect(txItems(context).isEmpty)
        #expect(unitClocks(sid, context).isEmpty)
    }

    /// El dedupe de cuarentena solo se lee si la página trae algo que cuarentenar: una cuarentena ilegible
    /// no frena una página de tablas cableadas.
    @Test func apply_wiredOnlyPage_quarantineUnreadable_stillApplies() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        engine._testThrowOnApplyRead = .quarantineSeqs

        #expect(engine.applyPage(try decodePage(txPage(sid: UUID(), serverSeq: 4, h: hlc(1))), context: context, now: applyNow))
        #expect(txItems(context).count == 1)
        #expect(cursor(context)?.serverSeqCursor == 4)
    }

    @Test func apply_upsert_rowLookupUnreadable_noDuplicateBornRemote_thenUpdatesInPlace() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        #expect(engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 1, h: hlc(1))), context: context, now: applyNow))
        let update = try decodePage(txPage(sid: sid, serverSeq: 2, h: hlc(2), note: "editada"))

        EntityApplyMap._testThrowOnFetchOf = ["TransactionItem"]
        #expect(engine.applyPage(update, context: context, now: applyNow) == false)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(txItems(context).count == 1)                 // sin born-remote duplicado
        #expect(txItems(context).first?.note == "hola")
        #expect(cursor(context)?.serverSeqCursor == 1)

        #expect(engine.applyPage(update, context: context, now: applyNow))  // control positivo
        #expect(txItems(context).count == 1)
        #expect(txItems(context).first?.note == "editada")
    }

    @Test func apply_bornRemote_identityLookupUnreadable_pageNotApplied() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        let page = try decodePage(txPage(sid: sid, serverSeq: 1, h: hlc(1)))
        EntityApplyMap._testThrowOnFetchOf = ["SyncIdentity"]
        #expect(engine.applyPage(page, context: context, now: applyNow) == false)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(txItems(context).isEmpty)
        #expect((cursor(context)?.serverSeqCursor ?? 0) == 0)

        #expect(engine.applyPage(page, context: context, now: applyNow))    // control positivo
        #expect(txItems(context).count == 1)
        let identities = try context.fetch(FetchDescriptor<SyncIdentity>()).filter { $0.syncID == sid }
        #expect(identities.count == 1)
    }

    // MARK: - F-4. Born-remote con fila outbox HUÉRFANA → full-row remoto ÍNTEGRO (skip no aplica)

    @Test func apply_bornRemote_orphanOutboxRow_materializesFullRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        // Fila outbox viva HUÉRFANA: upsert pendiente de un syncID SIN modelo local (p.ej. el modelo se
        // borró tras encolar), con money@H9 (más nuevo que el remoto H2).
        let sid = UUID()
        let orphan = SyncOutbox(syncID: sid, entityType: SyncEntityType.transactionItem, op: .upsert,
                                hlc: hlc(9), fieldsJSON: "{}",
                                fieldHlcsJSON: #"{"money":"\#(hlc(9))"}"#, author: "")
        context.insert(orphan)
        try context.save()

        // Upsert remoto → born-remote. F-4: el skip por-unidad NO aplica en born-remote — saltarse el
        // grupo money dejaría la fila con los defaults del init ($0) = incoherente.
        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 4, h: hlc(2), amount: "55.0000",
                                               aip: "200.0000")),
                         context: context, now: applyNow)
        let tx = try #require(txItems(context).first)
        #expect(tx.amount == 55)                        // full-row remoto ÍNTEGRO
        #expect(tx.amountInPreferredCurrency == 200)
        #expect(tx.note == "hola")
    }

    // MARK: - F-6d. Tombstone con HLC malformado → NO borrar (skip conservador)

    @Test func apply_tombstone_malformedHLC_doesNotDelete() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let tx = TransactionItem(date: epochDate, amount: 10, currencyCode: "USD")
        tx.syncID = sid
        context.insert(tx)
        try context.save()

        let tomb = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"tombstone",
        "fields":{},"field_hlcs":{},"hlc":"NOT-A-VALID-HLC","server_seq":8,"schema_version":1}],"max_server_seq":8}
        """#
        engine.applyPage(try decodePage(tomb), context: context, now: applyNow)
        #expect(txItems(context).count == 1)                        // NO borrado (borrar es irreversible)
        #expect(cursor(context)?.serverSeqCursor == 8)              // el cursor avanza igual
    }

    // MARK: - F-2. Refs colgadas: registro durable + re-resolución al final del ciclo

    private func txWithCategoryPage(sid: UUID, catUUID: UUID, serverSeq: Int, h: String) -> String {
        #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"date":"\#(epochTS)","amount":"5.0000","currency_code":"USD",
        "amount_in_preferred_currency":"5.0000","preferred_currency_code":"USD","exchange_rate":"1.00000000",
        "is_exchange_rate_provisional":false,"created_at":"\#(epochTS)",
        "category_ref":"\#(catUUID.uuidString.lowercased())"},
        "field_hlcs":{"money":"\#(h)","category_ref":"\#(h)"},
        "hlc":"\#(h)","server_seq":\#(serverSeq),"schema_version":1}],"max_server_seq":\#(serverSeq)}
        """#
    }

    private func catDeltaJSON(_ catUUID: UUID, seq: Int, name: String) -> String {
        #"""
        {"entity_type":"categories","sync_id":"\#(catUUID.uuidString.lowercased())","op":"upsert",
        "fields":{"name":"\#(name)","color_hex":"#111111","is_income":false,"is_default_seed":false,
        "is_visible":true,"sort_order":0,"is_system":false},
        "field_hlcs":{"name":"\#(hlc(seq))"},"hlc":"\#(hlc(seq))","server_seq":\#(seq),"schema_version":1}
        """#
    }

    private func danglers(_ context: ModelContext) -> [SyncDanglingRef] {
        (try? context.fetch(FetchDescriptor<SyncDanglingRef>())) ?? []
    }

    @Test func danglingRef_targetInLaterPage_resolvedAtEndOfCycle() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let catUUID = UUID()
        // Página 1: la TX referencia una Category que aún no existe. Página 2: llega la Category.
        let page1 = txWithCategoryPage(sid: sid, catUUID: catUUID, serverSeq: 1, h: hlc(1))
        let page2 = "{\"deltas\":[\(catDeltaJSON(catUUID, seq: 2, name: "Travel"))],\"max_server_seq\":2}"
        let session = SequencedStubSession([Data(page1.utf8), Data(page2.utf8),
                                            Data(#"{"deltas":[],"max_server_seq":2}"#.utf8)])
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                    tokenProvider: { "jwt" }, urlSession: session)
        _ = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow, pageLimit: 1)

        // El pase final re-resolvió: relación seteada + dangler borrado.
        let tx = try #require(txItems(context).first)
        #expect(tx.category?.syncID == catUUID)
        #expect(danglers(context).isEmpty)
    }

    @Test func danglingRef_targetInSamePage_resolvedAtEndOfCycle() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let catUUID = UUID()
        // MISMA página: TX (seq 1) ANTES que su Category (seq 2) — orden server_seq no causal.
        let txDelta = #"""
        {"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"date":"\#(epochTS)","amount":"5.0000","currency_code":"USD",
        "amount_in_preferred_currency":"5.0000","preferred_currency_code":"USD","exchange_rate":"1.00000000",
        "is_exchange_rate_provisional":false,"created_at":"\#(epochTS)",
        "category_ref":"\#(catUUID.uuidString.lowercased())"},
        "field_hlcs":{"money":"\#(hlc(1))","category_ref":"\#(hlc(1))"},
        "hlc":"\#(hlc(1))","server_seq":1,"schema_version":1}
        """#
        let page = "{\"deltas\":[\(txDelta),\(catDeltaJSON(catUUID, seq: 2, name: "Food"))],\"max_server_seq\":2}"
        let session = SequencedStubSession([Data(page.utf8),
                                            Data(#"{"deltas":[],"max_server_seq":2}"#.utf8)])
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                    tokenProvider: { "jwt" }, urlSession: session)
        _ = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow)

        let tx = try #require(txItems(context).first)
        #expect(tx.category?.syncID == catUUID)
        #expect(danglers(context).isEmpty)
    }

    @Test func danglingRef_targetNeverArrives_danglerPersists() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let catUUID = UUID()  // nunca llega
        let page = txWithCategoryPage(sid: sid, catUUID: catUUID, serverSeq: 1, h: hlc(1))
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                    tokenProvider: { "jwt" },
                                    urlSession: OneShotSession(body: Data(page.utf8)))
        _ = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow)

        let tx = try #require(txItems(context).first)
        #expect(tx.category == nil)
        // El dangler PERSISTE (durable) para el reintento del próximo ciclo.
        let d = try #require(danglers(context).first)
        #expect(d.entityTable == "tx_items")
        #expect(d.rowSyncID == sid)
        #expect(d.column == "category_ref")
        #expect(d.targetUUID == catUUID)
    }

    // MARK: - I8f-3: un NULL del wire deja OBSOLETO el dangler previo de esa (fila, columna)

    @Test func danglingRef_nulledByWire_clearsStaleDangler() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        // Delta 1: TX con category_ref colgada → dangler registrado.
        let sid = UUID()
        let catUUID = UUID()
        let page1 = txWithCategoryPage(sid: sid, catUUID: catUUID, serverSeq: 1, h: hlc(1))
        engine.applyPage(try decodePage(page1), context: context, now: applyNow)
        #expect(danglers(context).count == 1)

        // Delta 2: el wire pone category_ref a NULL → el dangler queda obsoleto y se BORRA (sin esto,
        // la re-resolución re-adjuntaría una relación stale y el Merkle usaría un target inexistente).
        let page2 = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"category_ref":null},"field_hlcs":{"category_ref":"\#(hlc(2))"},
        "hlc":"\#(hlc(2))","server_seq":2,"schema_version":1}],"max_server_seq":2}
        """#
        engine.applyPage(try decodePage(page2), context: context, now: applyNow)
        #expect(danglers(context).isEmpty)
        #expect(txItems(context).first?.category == nil)
    }

    @Test func danglingRef_reresolution_producesNoDrainEcho() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let catUUID = UUID()
        let page1 = txWithCategoryPage(sid: sid, catUUID: catUUID, serverSeq: 1, h: hlc(1))
        let page2 = "{\"deltas\":[\(catDeltaJSON(catUUID, seq: 2, name: "Casa"))],\"max_server_seq\":2}"
        let session = SequencedStubSession([Data(page1.utf8), Data(page2.utf8),
                                            Data(#"{"deltas":[],"max_server_seq":2}"#.utf8)])
        let client = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                    tokenProvider: { "jwt" }, urlSession: session)
        _ = await engine.pullAndApplyOnce(using: client, context: context, now: applyNow, pageLimit: 1)
        #expect(danglers(context).isEmpty)  // resuelto

        // F-2c: el set de la relación en la re-resolución fue bajo outboxSaveAuthor → el drain NO lo
        // re-captura como cambio local (cero filas de outbox nuevas).
        #expect(outbox(context).isEmpty)
        engine.drainOnce(context: context)
        #expect(outbox(context).isEmpty)
    }

    // MARK: - Refs colgadas con la base ILEGIBLE (ticket dangling-ref-repair-is-lost-when-its-row-cannot-be-read)
    //
    // «No pude leer» nunca es «no hay»: ni la fila origen del pase final (`.rowGone` borraba la única nota del
    // destino), ni el registro `SyncDanglingRef` (tragado, perdía la nota nueva o dejaba viva la vieja), ni el
    // destino de una ref (leído `nil`, pisaba una ref local buena). Cada caso lleva su control positivo con la
    // lectura de vuelta: sin él, un fake roto pasaría por comportamiento correcto.

    private func pageJSON(_ deltas: [String], maxSeq: Int) -> String {
        "{\"deltas\":[\(deltas.joined(separator: ","))],\"max_server_seq\":\(maxSeq)}"
    }
    /// Un delta de `tx_items` (el cuerpo de `txWithCategoryPage`, sin la envoltura de página).
    private func txCategoryDeltaJSON(sid: UUID, catUUID: UUID, serverSeq: Int, h: String) -> String {
        #"""
        {"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"date":"\#(epochTS)","amount":"5.0000","currency_code":"USD",
        "amount_in_preferred_currency":"5.0000","preferred_currency_code":"USD","exchange_rate":"1.00000000",
        "is_exchange_rate_provisional":false,"created_at":"\#(epochTS)",
        "category_ref":"\#(catUUID.uuidString.lowercased())"},
        "field_hlcs":{"money":"\#(h)","category_ref":"\#(h)"},
        "hlc":"\#(h)","server_seq":\#(serverSeq),"schema_version":1}
        """#
    }
    private func subcategoryDeltaJSON(shortcut: UUID, catUUID: UUID, seq: Int) -> String {
        #"""
        {"entity_type":"subcategories","sync_id":"\#(shortcut.uuidString.lowercased())","op":"upsert",
        "fields":{"name":"Cafés","color_hex":null,"is_default_seed":false,"is_visible":true,"sort_order":0,
        "nature_raw_value":null,"icon_name":null,"is_system":false,
        "category_ref":"\#(catUUID.uuidString.lowercased())"},
        "field_hlcs":{"name":"\#(hlc(seq))","category_ref":"\#(hlc(seq))"},
        "hlc":"\#(hlc(seq))","server_seq":\#(seq),"schema_version":1}
        """#
    }
    private func subcategory(_ shortcut: UUID, _ context: ModelContext) throws -> Subcategory? {
        try context.fetch(FetchDescriptor<Subcategory>()).first { $0.shortcutID == shortcut }
    }

    @Test func reresolve_rowUnreadable_keepsDangler_thenResolves() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        let catUUID = UUID()
        #expect(engine.applyPage(try decodePage(txWithCategoryPage(sid: sid, catUUID: catUUID, serverSeq: 1, h: hlc(1))),
                                 context: context, now: applyNow))
        #expect(engine.applyPage(try decodePage(pageJSON([catDeltaJSON(catUUID, seq: 2, name: "Food")], maxSeq: 2)),
                                 context: context, now: applyNow))
        let dangler = try #require(danglers(context).first)

        EntityApplyMap._testThrowOnFetchOf = ["TransactionItem"]
        #expect(EntityApplyMap.reresolveDangler(dangler, context: context) == .unreadable)
        engine.reresolveDanglingRefs(context: context)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(danglers(context).count == 1)                   // la nota del destino sobrevive…
        #expect(danglers(context).first?.targetUUID == catUUID)
        #expect(txItems(context).first?.category == nil)        // …y la fila sigue esperando

        engine.reresolveDanglingRefs(context: context)          // control positivo: la lectura vuelve
        #expect(txItems(context).first?.category?.syncID == catUUID)
        #expect(danglers(context).isEmpty)
    }

    /// El destino ilegible ya conservaba el dangler por accidente (el `nil` tolerante caía en `.targetMissing`); ahora
    /// lo dice el desenlace, que es lo que impide que un cambio futuro lo trate como ausencia.
    @Test func reresolve_targetUnreadable_isUnreadable_keepsDangler_thenResolves() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        let catUUID = UUID()
        #expect(engine.applyPage(try decodePage(txWithCategoryPage(sid: sid, catUUID: catUUID, serverSeq: 1, h: hlc(1))),
                                 context: context, now: applyNow))
        #expect(engine.applyPage(try decodePage(pageJSON([catDeltaJSON(catUUID, seq: 2, name: "Food")], maxSeq: 2)),
                                 context: context, now: applyNow))
        let dangler = try #require(danglers(context).first)

        EntityApplyMap._testThrowOnFetchOf = ["Category"]
        #expect(EntityApplyMap.reresolveDangler(dangler, context: context) == .unreadable)
        engine.reresolveDanglingRefs(context: context)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(danglers(context).count == 1)
        #expect(txItems(context).first?.category == nil)

        engine.reresolveDanglingRefs(context: context)          // control positivo
        #expect(txItems(context).first?.category?.syncID == catUUID)
        #expect(danglers(context).isEmpty)
    }

    /// Un dangler ilegible no frena a los demás del mismo pase: son independientes. El ilegible va EN MEDIO de dos
    /// legibles: el fetch de los danglers no lleva orden, así que un corte al primer ilegible deja uno sin resolver
    /// salga en el orden que salga.
    @Test func reresolve_oneUnreadable_theOthersStillResolve() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        let subBefore = UUID()
        let subAfter = UUID()
        let catUUID = UUID()
        // TX y dos Subcategory llegan ANTES que su Category → tres danglers; la Category llega en la misma página.
        let page = pageJSON([subcategoryDeltaJSON(shortcut: subBefore, catUUID: catUUID, seq: 1),
                             txCategoryDeltaJSON(sid: sid, catUUID: catUUID, serverSeq: 2, h: hlc(2)),
                             subcategoryDeltaJSON(shortcut: subAfter, catUUID: catUUID, seq: 3),
                             catDeltaJSON(catUUID, seq: 4, name: "Comida")], maxSeq: 4)
        #expect(engine.applyPage(try decodePage(page), context: context, now: applyNow))
        #expect(danglers(context).count == 3)

        EntityApplyMap._testThrowOnFetchOf = ["TransactionItem"]
        engine.reresolveDanglingRefs(context: context)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(try subcategory(subBefore, context)?.category?.syncID == catUUID)   // los legibles se resolvieron…
        #expect(try subcategory(subAfter, context)?.category?.syncID == catUUID)
        #expect(danglers(context).map(\.rowSyncID) == [sid])                    // …y solo queda el ilegible
        #expect(txItems(context).first?.category == nil)

        engine.reresolveDanglingRefs(context: context)                    // control positivo
        #expect(txItems(context).first?.category?.syncID == catUUID)
        #expect(danglers(context).isEmpty)
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }
    private func entityApplyMapSource() throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent("Yala/Services/CloudSync/EntityApplyMap.swift"),
                   encoding: .utf8)
    }
    private func occurrences(_ pattern: String, in text: Substring) throws -> Int {
        try NSRegularExpression(pattern: pattern).numberOfMatches(in: String(text),
                                                                  range: NSRange(text.startIndex..., in: text))
    }

    /// Las 18 ramas del pase final, UNA A UNA: con la fila ilegible, `.unreadable`; sin seam, la fila no existe y es
    /// `.rowGone` (control). Un `fetch*` tolerante que vuelva a CUALQUIER rama compila limpio —los `fetch*` siguen
    /// vivos para `liveRowExists`— y solo esto lo pone en rojo. El scan fija además que no quede ninguno y que la
    /// lista de aquí tenga tantas ramas como el switch: una rama nueva sin su fila en la lista, también en rojo.
    @Test func reresolve_everyBranch_rowUnreadable_isUnreadable_rowAbsent_isRowGone() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let branches: [(table: String, column: String, rowType: String)] = [
            (EntityApplyMap.transactionItem.table, "category_ref", "TransactionItem"),
            (EntityApplyMap.transactionItem.table, "subcategory_ref", "TransactionItem"),
            (EntityApplyMap.transactionItem.table, "account_ref", "TransactionItem"),
            (EntityApplyMap.inboxDraft.table, "account_ref", "InboxDraft"),
            (EntityApplyMap.inboxDraft.table, "subcategory_ref", "InboxDraft"),
            (EntityApplyMap.inboxDraft.table, "approved_transaction_ref", "InboxDraft"),
            (EntityApplyMap.favoritePayment.table, "account_ref", "FavoritePayment"),
            (EntityApplyMap.favoritePayment.table, "subcategory_ref", "FavoritePayment"),
            (EntityApplyMap.merchantMemory.table, "subcategory_ref", "MerchantMemory"),
            (EntityApplyMap.budget.table, "category_id", "Budget"),
            (EntityApplyMap.scheduledPayment.table, "account_ref", "ScheduledPayment"),
            (EntityApplyMap.scheduledPayment.table, "subcategory_ref", "ScheduledPayment"),
            (EntityApplyMap.subcategory.table, "category_ref", "Subcategory"),
            (EntityApplyMap.cashFlowLine.table, "category_ref", "CashFlowLine"),
            (EntityApplyMap.cashFlowLine.table, "subcategory_ref", "CashFlowLine"),
            (EntityApplyMap.cashFlowLine.table, "scheduled_payment_ref", "CashFlowLine"),
            (EntityApplyMap.cashFlowLine.table, "plan_ref", "CashFlowLine"),
            (EntityApplyMap.cashFlowOverride.table, "line_ref", "CashFlowOverride"),
        ]
        for b in branches {
            let d = SyncDanglingRef(entityTable: b.table, rowSyncID: UUID(), column: b.column, targetUUID: UUID())
            EntityApplyMap._testThrowOnFetchOf = [b.rowType]
            #expect(EntityApplyMap.reresolveDangler(d, context: context) == .unreadable, "\(b.table).\(b.column)")
            EntityApplyMap._testThrowOnFetchOf = []
            #expect(EntityApplyMap.reresolveDangler(d, context: context) == .rowGone, "\(b.table).\(b.column)")
        }

        let src = try entityApplyMapSource()
        let start = try #require(src.range(of: "private static func reresolveDanglerReadingStrictly("))
        let end = try #require(src.range(of: "/// Aplica `tag_refs`", range: start.upperBound..<src.endIndex))
        let body = src[start.upperBound..<end.lowerBound]
        #expect(try occurrences(#"\bcase \("#, in: body) == branches.count)
        #expect(try occurrences(#"guard let row = try find[A-Z]"#, in: body) == branches.count)
        #expect(try occurrences(#"guard let t = try find[A-Z]"#, in: body) == branches.count)
        #expect(try occurrences(#"\bfetch[A-Z]"#, in: body) == 0)
    }

    /// Los 25 appliers que leen algo —18 refs singulares y 7 M2M—, UNO A UNO: con el destino ilegible LANZAN (la
    /// página se tira). Un closure tolerante (`{ fetchSubcategory(…) }`) encaja en `(UUID) throws -> T?` sin un aviso
    /// del compilador; solo esto lo pone en rojo. El scan fija que la zona de los appliers no tenga ninguna lectura
    /// tolerante y que el recuento de `resolveRef` cuadre con la lista.
    @Test func everyReadingApplier_targetUnreadable_throws() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let ref = WireValue.string(UUID().uuidString.lowercased())
        let refs = WireValue.array([ref])
        var singular = 0
        var many = 0
        func expectThrows<M: PersistentModel>(_ entry: EntityApply<M>, _ column: String, reading targetType: String, _ value: WireValue) {
            guard let applier = entry.appliers[column] else {
                Issue.record("sin applier \(entry.table).\(column)")
                return
            }
            let model = entry.make(context)
            EntityApplyMap._testThrowOnFetchOf = [targetType]
            #expect(throws: EntityApplyFetchError.self, "\(entry.table).\(column)") {
                try applier.apply(model, value, context)
            }
            EntityApplyMap._testThrowOnFetchOf = []
            if case .array = value { many += 1 } else { singular += 1 }
        }
        expectThrows(EntityApplyMap.transactionItem, "category_ref", reading: "Category", ref)
        expectThrows(EntityApplyMap.transactionItem, "subcategory_ref", reading: "Subcategory", ref)
        expectThrows(EntityApplyMap.transactionItem, "account_ref", reading: "Account", ref)
        expectThrows(EntityApplyMap.transactionItem, "tag_refs", reading: "Tag", refs)
        expectThrows(EntityApplyMap.inboxDraft, "account_ref", reading: "Account", ref)
        expectThrows(EntityApplyMap.inboxDraft, "subcategory_ref", reading: "Subcategory", ref)
        expectThrows(EntityApplyMap.inboxDraft, "approved_transaction_ref", reading: "TransactionItem", ref)
        expectThrows(EntityApplyMap.inboxDraft, "tag_refs", reading: "Tag", refs)
        expectThrows(EntityApplyMap.favoritePayment, "account_ref", reading: "Account", ref)
        expectThrows(EntityApplyMap.favoritePayment, "subcategory_ref", reading: "Subcategory", ref)
        expectThrows(EntityApplyMap.favoritePayment, "tag_refs", reading: "Tag", refs)
        expectThrows(EntityApplyMap.merchantMemory, "subcategory_ref", reading: "Subcategory", ref)
        expectThrows(EntityApplyMap.budget, "category_id", reading: "Category", ref)
        expectThrows(EntityApplyMap.budget, "subcategory_ids", reading: "Subcategory", refs)
        expectThrows(EntityApplyMap.budget, "account_ids", reading: "Account", refs)
        expectThrows(EntityApplyMap.budget, "tag_refs", reading: "Tag", refs)
        expectThrows(EntityApplyMap.scheduledPayment, "account_ref", reading: "Account", ref)
        expectThrows(EntityApplyMap.scheduledPayment, "subcategory_ref", reading: "Subcategory", ref)
        expectThrows(EntityApplyMap.scheduledPayment, "tag_refs", reading: "Tag", refs)
        expectThrows(EntityApplyMap.subcategory, "category_ref", reading: "Category", ref)
        expectThrows(EntityApplyMap.cashFlowLine, "category_ref", reading: "Category", ref)
        expectThrows(EntityApplyMap.cashFlowLine, "subcategory_ref", reading: "Subcategory", ref)
        expectThrows(EntityApplyMap.cashFlowLine, "scheduled_payment_ref", reading: "ScheduledPayment", ref)
        expectThrows(EntityApplyMap.cashFlowLine, "plan_ref", reading: "CashFlowPlan", ref)
        expectThrows(EntityApplyMap.cashFlowOverride, "line_ref", reading: "CashFlowLine", ref)
        context.rollback()

        let src = try entityApplyMapSource()
        let end = try #require(src.range(of: "// MARK: - Resolución de un `_ref`"))
        let appliersZone = src[src.startIndex..<end.lowerBound]
        #expect(try occurrences(#"= try resolveRef\("#, in: appliersZone) == singular)
        #expect(try occurrences(#"try apply(TagRefs|UUIDArrayRefs)\("#, in: appliersZone) == many)
        #expect(try occurrences(#"\bfetch(?!BySyncID)[A-Z]\w*\("#, in: appliersZone) == 0)
        #expect(singular == 18)
        #expect(many == 7)
    }

    @Test func apply_danglingRef_registryUnreadable_pageNotApplied_thenRegisters() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        let catUUID = UUID()  // no local → la ref cuelga y hay que apuntarla
        let page = try decodePage(txWithCategoryPage(sid: sid, catUUID: catUUID, serverSeq: 1, h: hlc(1)))

        EntityApplyMap._testThrowOnFetchOf = ["SyncDanglingRef"]
        #expect(engine.applyPage(page, context: context, now: applyNow) == false)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(txItems(context).isEmpty)                       // ni fila sin ref…
        #expect(danglers(context).isEmpty)                      // …ni nota a medias
        #expect((cursor(context)?.serverSeqCursor ?? 0) == 0)

        #expect(engine.applyPage(page, context: context, now: applyNow))   // control positivo
        #expect(txItems(context).count == 1)
        #expect(danglers(context).map(\.targetUUID) == [catUUID])
        #expect(cursor(context)?.serverSeqCursor == 1)
    }

    @Test func apply_retargetedDanglingRef_registryUnreadable_noSecondDangler_thenRetargets() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        let catA = UUID()
        let catB = UUID()  // ninguna de las dos es local
        #expect(engine.applyPage(try decodePage(txWithCategoryPage(sid: sid, catUUID: catA, serverSeq: 1, h: hlc(1))),
                                 context: context, now: applyNow))
        let retarget = try decodePage(txWithCategoryPage(sid: sid, catUUID: catB, serverSeq: 2, h: hlc(2)))

        EntityApplyMap._testThrowOnFetchOf = ["SyncDanglingRef"]
        #expect(engine.applyPage(retarget, context: context, now: applyNow) == false)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(danglers(context).map(\.targetUUID) == [catA])  // sin duplicado y sin perder la vieja
        #expect(cursor(context)?.serverSeqCursor == 1)

        #expect(engine.applyPage(retarget, context: context, now: applyNow))   // control positivo
        #expect(danglers(context).map(\.targetUUID) == [catB])  // UNO, reapuntado
        #expect(cursor(context)?.serverSeqCursor == 2)
    }

    @Test func apply_nulledRef_registryUnreadable_pageNotApplied_thenClears() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        let catUUID = UUID()
        #expect(engine.applyPage(try decodePage(txWithCategoryPage(sid: sid, catUUID: catUUID, serverSeq: 1, h: hlc(1))),
                                 context: context, now: applyNow))
        let nulled = try decodePage(#"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"category_ref":null},"field_hlcs":{"category_ref":"\#(hlc(2))"},
        "hlc":"\#(hlc(2))","server_seq":2,"schema_version":1}],"max_server_seq":2}
        """#)

        EntityApplyMap._testThrowOnFetchOf = ["SyncDanglingRef"]
        #expect(engine.applyPage(nulled, context: context, now: applyNow) == false)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(danglers(context).count == 1)                   // el NULL no se da por aplicado…
        #expect(cursor(context)?.serverSeqCursor == 1)          // …con la nota vieja viva

        #expect(engine.applyPage(nulled, context: context, now: applyNow))     // control positivo
        #expect(danglers(context).isEmpty)
        #expect(cursor(context)?.serverSeqCursor == 2)
    }

    /// La ref resuelve en caliente y deja OBSOLETO el dangler viejo: si ese borrado se tragara, el dangler viejo
    /// seguiría vivo y, al llegar su destino, el pase final pisaría la ref buena con la relación que el wire ya cambió.
    @Test func apply_hotResolvedRef_registryUnreadable_pageNotApplied_thenClearsStaleDangler() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        let catA = UUID()  // no local todavía → dangler
        let catB = UUID()  // local
        #expect(engine.applyPage(try decodePage(pageJSON([catDeltaJSON(catB, seq: 1, name: "Viaje"),
                                                          txCategoryDeltaJSON(sid: sid, catUUID: catA, serverSeq: 2, h: hlc(2))],
                                                         maxSeq: 2)),
                                 context: context, now: applyNow))
        #expect(danglers(context).map(\.targetUUID) == [catA])
        let retarget = try decodePage(txWithCategoryPage(sid: sid, catUUID: catB, serverSeq: 3, h: hlc(3)))

        EntityApplyMap._testThrowOnFetchOf = ["SyncDanglingRef"]
        #expect(engine.applyPage(retarget, context: context, now: applyNow) == false)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(txItems(context).first?.category == nil)
        #expect(cursor(context)?.serverSeqCursor == 2)

        #expect(engine.applyPage(retarget, context: context, now: applyNow))  // control positivo
        #expect(txItems(context).first?.category?.syncID == catB)
        #expect(danglers(context).isEmpty)                                    // el viejo ya no puede volver
        // Llega el destino VIEJO: sin dangler, el pase final no tiene nada que re-adjuntar.
        #expect(engine.applyPage(try decodePage(pageJSON([catDeltaJSON(catA, seq: 4, name: "Casa")], maxSeq: 4)),
                                 context: context, now: applyNow))
        engine.reresolveDanglingRefs(context: context)
        #expect(txItems(context).first?.category?.syncID == catB)
    }

    @Test func apply_ref_targetUnreadable_keepsGoodLocalRef_thenApplies() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let sid = UUID()
        let catA = UUID()
        let catB = UUID()
        // Las dos Category llegan ANTES que la TX → la ref resuelve en caliente, sin dangler.
        let first = pageJSON([catDeltaJSON(catA, seq: 1, name: "Casa"), catDeltaJSON(catB, seq: 2, name: "Viaje"),
                              txCategoryDeltaJSON(sid: sid, catUUID: catA, serverSeq: 3, h: hlc(3))], maxSeq: 3)
        #expect(engine.applyPage(try decodePage(first), context: context, now: applyNow))
        #expect(txItems(context).first?.category?.syncID == catA)
        #expect(danglers(context).isEmpty)
        let retarget = try decodePage(txWithCategoryPage(sid: sid, catUUID: catB, serverSeq: 4, h: hlc(4)))

        EntityApplyMap._testThrowOnFetchOf = ["Category"]
        #expect(engine.applyPage(retarget, context: context, now: applyNow) == false)
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(txItems(context).first?.category?.syncID == catA)   // la ref buena no se pisa con nil…
        #expect(danglers(context).isEmpty)                          // …ni se apunta un dangler falso
        #expect(cursor(context)?.serverSeqCursor == 3)

        #expect(engine.applyPage(retarget, context: context, now: applyNow))  // control positivo
        #expect(txItems(context).first?.category?.syncID == catB)
        #expect(danglers(context).isEmpty)
        #expect(cursor(context)?.serverSeqCursor == 4)
    }
}

// MARK: - Stubs

/// Devuelve un cuerpo fijo (200) — para el pull de una sola página.
private final class OneShotSession: SyncHTTPSession, @unchecked Sendable {
    let body: Data
    init(body: Data) { self.body = body }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

/// Simula el interleaving F-1: ejecuta `onRequest` (en MainActor) DENTRO de la ventana del `await pull`
/// — después del drain de entrada, antes de devolver la página.
private final class EditingStubSession: SyncHTTPSession, @unchecked Sendable {
    let body: Data
    let onRequest: @MainActor () -> Void
    private var fired = false
    init(body: Data, onRequest: @escaping @MainActor () -> Void) {
        self.body = body
        self.onRequest = onRequest
    }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if !fired {
            fired = true
            await MainActor.run { onRequest() }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (body, response)
        }
        // Segunda llamada (si el loop pagina): cola vacía.
        let empty = Data(#"{"deltas":[],"max_server_seq":0}"#.utf8)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (empty, response)
    }
}

/// Devuelve cuerpos en secuencia por llamada (200) — para la paginación.
private final class SequencedStubSession: SyncHTTPSession, @unchecked Sendable {
    private let bodies: [Data]
    private var i = 0
    init(_ bodies: [Data]) { self.bodies = bodies }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let body = bodies[min(i, bodies.count - 1)]
        i += 1
        return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
