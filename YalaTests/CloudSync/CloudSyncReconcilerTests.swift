//
//  CloudSyncReconcilerTests.swift
//  YalaTests / CloudSync
//
//  Reconciliadores cross-fila post-pull (I8f-2, tests #2-#8 del plan): golden SERIO 4 (ganador por
//  money-clock, NO por HLC de fila), rama conservadora sin señal, poda del split (real-gana interina,
//  firma estricta, M5 nunca dispara), y el gate `pagesApplied > 0` + captura por el drain (autor
//  normal). Container ON-DISK temp con los 3 stores. `.serialized`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSyncReconciler · cross-fila I8f-2", .serialized)
@MainActor
struct CloudSyncReconcilerTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CloudSyncReconciler-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CSR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "CSR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "CSR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private let node = "0123456789abcdef"
    private func hlc(_ c: Int) -> String { "2023-11-14T22:13:20.000Z-\(String(format: "%04x", c))-\(node)" }
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)
    private let epochDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeTx(_ amount: Double, account: Account? = nil, pairID: String? = nil,
                        splitExpenseID: String? = nil, context: ModelContext) -> TransactionItem {
        let tx = TransactionItem(date: epochDate, amount: amount, currencyCode: "USD",
                                 account: account)
        tx.createdAt = epochDate
        tx.transferPairID = pairID
        tx.splitExpenseID = splitExpenseID
        tx.syncID = UUID()
        context.insert(tx)
        return tx
    }

    private func makeAccount(system: Bool, name: String, context: ModelContext) -> Account {
        let acc = Account(name: name, currencyCode: "USD", colorHex: "#111111",
                          iconName: "creditcard", type: "checking", isSystemAccount: system)
        context.insert(acc)
        return acc
    }

    /// Sobrescribe DIRECTO el mapa del clock (bypass del merge MAX — los HLCs de test son 2023 y el
    /// drain ya escribió HLCs frescos).
    private func setClock(_ tx: TransactionItem, _ map: [String: String], context: ModelContext) throws {
        let sid = try #require(tx.syncID)
        if let row = SyncUnitClockStore.row(syncID: sid, context: context) {
            row.unitHlcsJSON = SyncUnitClockStore.encodeMap(map)
        } else {
            context.insert(SyncUnitClock(syncID: sid, entityTable: "tx_items",
                                         unitHlcsJSON: SyncUnitClockStore.encodeMap(map)))
        }
    }

    private func outbox(_ context: ModelContext) -> [SyncOutbox] {
        (try? context.fetch(FetchDescriptor<SyncOutbox>())) ?? []
    }

    private func purgeOutbox(_ context: ModelContext) throws {
        for row in outbox(context) { context.delete(row) }
        try context.save()
    }

    private func aliveTxs(_ context: ModelContext) -> [TransactionItem] {
        (try? context.fetch(FetchDescriptor<TransactionItem>())) ?? []
    }

    // MARK: - #2 Golden SERIO 4 (D1/D2/D3): ganador por money-clock, NO por HLC de fila

    @Test func golden_serio4_winnerByMoneyClock_notRowHLC_moneyGroupRepairedAndDrained() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        // Par divergente: A = la verdad del usuario (−120), B = lado stale (+100).
        let pairID = UUID().uuidString
        let a = makeTx(-120, pairID: pairID, context: context)
        a.amountInPreferredCurrency = -456
        a.exchangeRate = 3.8
        a.preferredCurrencyCode = "PEN"
        a.isExchangeRateProvisional = true
        let b = makeTx(100, pairID: pairID, context: context)
        b.amountInPreferredCurrency = 380
        try context.save()

        // Drenar los inserts (simula ya-subido) y fijar los clocks del ESCENARIO: A editó `money` en H5;
        // B tiene su money viejo en H1 pero un HLC DE FILA más nuevo (note@H9 — D2 del golden: el
        // row-HLC de B > el de A). El desempate DEBE ignorar el row-HLC → gana A.
        engine.drainOnce(context: context)
        try purgeOutbox(context)
        try setClock(a, ["money": hlc(5)], context: context)
        try setClock(b, ["money": hlc(1), "note": hlc(9)], context: context)
        try context.save()

        let stats = CloudSyncReconciler.reconcileTransferPairDivergence(context: context)
        try context.save()  // autor NORMAL (espeja runPostPullReconcilers)

        #expect(stats == .init(repaired: 1, noSignal: 0))
        // El monto a-propósito del usuario (A) SOBREVIVE; B recibe el grupo money ENTERO coherente
        // con el signo de B.
        #expect(a.amount == -120)
        #expect(b.amount == 120)
        #expect(b.amountInPreferredCurrency == 456)
        #expect(b.exchangeRate == 3.8)
        #expect(b.preferredCurrencyCode == "PEN")
        #expect(b.isExchangeRateProvisional == true)

        // D3: el drain posterior captura la reparación (autor normal) y el emitter expande el grupo
        // money ENTERO en el delta.
        engine.drainOnce(context: context)
        let rows = outbox(context)
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.syncID == b.syncID)
        #expect(row.opRaw == SyncOutboxOp.upsert.rawValue)
        for column in ["amount", "amount_in_preferred_currency", "exchange_rate",
                       "preferred_currency_code", "is_exchange_rate_provisional"] {
            #expect(row.fieldsJSON.contains("\"\(column)\""), "money group incompleto: falta \(column)")
        }
    }

    // MARK: - #3 Rama conservadora: sin señal → no tocar

    @Test func transferPair_missingMoneyClock_noTouch_noSignal() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let pairID = UUID().uuidString
        let a = makeTx(-120, pairID: pairID, context: context)
        let b = makeTx(100, pairID: pairID, context: context)
        try context.save()
        // Solo A tiene clock de money; B NO (p.ej. SyncUnitClock recreada por migración).
        try setClock(a, ["money": hlc(5)], context: context)
        try context.save()

        let stats = CloudSyncReconciler.reconcileTransferPairDivergence(context: context)
        #expect(stats == .init(repaired: 0, noSignal: 1))
        #expect(a.amount == -120)  // intactos: jamás se adivina con un monto
        #expect(b.amount == 100)
    }

    // MARK: - Cross-currency: |amounts| distintos POR DISEÑO → skip silencioso

    @Test func transferPair_crossCurrency_skipsSilently() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let pairID = UUID().uuidString
        let a = makeTx(-120, pairID: pairID, context: context)
        let b = makeTx(100, pairID: pairID, context: context)
        b.currencyCode = "PEN"  // par cross-currency
        try context.save()
        try setClock(a, ["money": hlc(5)], context: context)
        try setClock(b, ["money": hlc(1)], context: context)
        try context.save()

        let stats = CloudSyncReconciler.reconcileTransferPairDivergence(context: context)
        #expect(stats == .init(repaired: 0, noSignal: 0))  // ni reparación ni "anomalía"
        #expect(a.amount == -120)
        #expect(b.amount == 100)
    }

    // MARK: - #4 Split: real + virtualNeg (+lent) → poda virtualNeg; tombstone drenado

    @Test func split_realAndVirtualNegPresent_prunesVirtualNeg_tombstoneDrained() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        let realAcc = makeAccount(system: false, name: "BCP", context: context)
        let sysAcc = makeAccount(system: true, name: "Grupos PEN", context: context)
        let expenseID = UUID().uuidString
        let real = makeTx(-100, account: realAcc, splitExpenseID: expenseID, context: context)   // forma ON
        let lent = makeTx(30, account: sysAcc, splitExpenseID: expenseID, context: context)      // +lent (ON)
        let virtNeg = makeTx(-30, account: sysAcc, splitExpenseID: expenseID, context: context)  // forma OFF
        try context.save()
        engine.drainOnce(context: context)
        try purgeOutbox(context)
        let prunedSyncID = try #require(virtNeg.syncID)

        let stats = CloudSyncReconciler.reconcileSplitRepresentations(context: context)
        try context.save()  // autor NORMAL

        #expect(stats == .init(pruned: 1))
        let alive = aliveTxs(context)
        #expect(alive.count == 2)
        #expect(alive.contains { $0.syncID == real.syncID })
        #expect(alive.contains { $0.syncID == lent.syncID })  // la virtual POSITIVA +lent sobrevive

        // El drain emite el tombstone de la podada (HLC fresco → terminación server-side §d.4 cat.3).
        engine.drainOnce(context: context)
        let tombstones = outbox(context).filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue }
        #expect(tombstones.count == 1)
        #expect(tombstones.first?.syncID == prunedSyncID)
    }

    // MARK: - #5 (regla interina real-gana): real + virtualNeg SIN +lent → también poda virtualNeg

    @Test func split_interimRule_realAlwaysWins_regardlessOfBridgePreference() throws {
        // Regla INTERINA (review I8f-2): real-gana SIEMPRE que ambas formas están presentes — NO se
        // consulta `effectiveBridgeEnabled` (device-dependent; su divergencia ES la causa de C3 y dos
        // devices con effective opuesto se borrarían el gasto entero mutuamente). REVISAR en I9.
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let realAcc = makeAccount(system: false, name: "BCP", context: context)
        let sysAcc = makeAccount(system: true, name: "Grupos PEN", context: context)
        let expenseID = UUID().uuidString
        let real = makeTx(-100, account: realAcc, splitExpenseID: expenseID, context: context)
        _ = makeTx(-30, account: sysAcc, splitExpenseID: expenseID, context: context)  // virtual −myShare
        try context.save()

        let stats = CloudSyncReconciler.reconcileSplitRepresentations(context: context)
        try context.save()

        #expect(stats == .init(pruned: 1))
        let alive = aliveTxs(context)
        #expect(alive.count == 1)
        #expect(alive.first?.syncID == real.syncID)  // real gana SIEMPRE
    }

    // MARK: - #6 Solo-una-forma: no se toca nada

    @Test func split_onlyOneForm_untouched() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let realAcc = makeAccount(system: false, name: "BCP", context: context)
        let sysAcc = makeAccount(system: true, name: "Grupos PEN", context: context)
        // (a) Solo la forma OFF (virtual −myShare) — sin real → NO se poda (borrarla dejaría el gasto
        //     sin representación).
        _ = makeTx(-30, account: sysAcc, splitExpenseID: "E-off", context: context)
        // (b) Solo la forma ON completa {real, +lent} — sin virtualNeg → no hay violación.
        _ = makeTx(-100, account: realAcc, splitExpenseID: "E-on", context: context)
        _ = makeTx(30, account: sysAcc, splitExpenseID: "E-on", context: context)
        // (c) Solo real.
        _ = makeTx(-50, account: realAcc, splitExpenseID: "E-real", context: context)
        try context.save()

        let stats = CloudSyncReconciler.reconcileSplitRepresentations(context: context)
        #expect(stats == .init(pruned: 0))
        #expect(aliveTxs(context).count == 4)
    }

    // MARK: - #7 `.groupInvite` M5 (2 virtuales, una positiva) → NO dispara

    @Test func split_groupInviteM5_twoVirtuals_neverFires() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let sysAcc = makeAccount(system: true, name: "Grupos PEN", context: context)
        let expenseID = UUID().uuidString
        _ = makeTx(50, account: sysAcc, splitExpenseID: expenseID, context: context)   // virtual positiva
        _ = makeTx(-50, account: sysAcc, splitExpenseID: expenseID, context: context)  // virtual negativa
        try context.save()

        let stats = CloudSyncReconciler.reconcileSplitRepresentations(context: context)
        #expect(stats == .init(pruned: 0))  // sin forma REAL → jamás dispara
        #expect(aliveTxs(context).count == 2)
    }

    // MARK: - Guard: TX con account == nil NO participa (ni forma presente ni podable)

    @Test func split_accountNil_doesNotParticipate() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let sysAcc = makeAccount(system: true, name: "Grupos PEN", context: context)
        let expenseID = UUID().uuidString
        // La TX sin cuenta (dangler I8f-1 sin resolver) NO cuenta como "real presente".
        _ = makeTx(-100, account: nil, splitExpenseID: expenseID, context: context)
        _ = makeTx(-30, account: sysAcc, splitExpenseID: expenseID, context: context)
        try context.save()

        let stats = CloudSyncReconciler.reconcileSplitRepresentations(context: context)
        #expect(stats == .init(pruned: 0))
        #expect(aliveTxs(context).count == 2)
    }

    // MARK: - #8 Gate `pagesApplied > 0` + captura por el drain

    @Test func reconcilers_onlyRunWhenPagesApplied_andWritesDrain() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        // Par divergente listo para reconciliar (clocks fijados tras drenar los inserts).
        let pairID = UUID().uuidString
        let a = makeTx(-120, pairID: pairID, context: context)
        let b = makeTx(100, pairID: pairID, context: context)
        try context.save()
        engine.drainOnce(context: context)
        try purgeOutbox(context)
        try setClock(a, ["money": hlc(5)], context: context)
        try setClock(b, ["money": hlc(1)], context: context)
        try context.save()

        // Ciclo 1: pull VACÍO → pagesApplied == 0 → los reconcilers NO corren.
        let emptyClient = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                         tokenProvider: { "jwt" },
                                         urlSession: FixedBodySession(#"{"deltas":[],"max_server_seq":0}"#))
        _ = await engine.pullAndApplyOnce(using: emptyClient, context: context, now: applyNow)
        #expect(b.amount == 100)  // intacto: ciclo vacío no reconcilia

        // Ciclo 2: 1 delta (Category ajena al par) → pagesApplied == 1 → reconcilers corren.
        let catJSON = #"""
        {"deltas":[{"entity_type":"categories","sync_id":"\#(UUID().uuidString.lowercased())","op":"upsert",
        "fields":{"name":"Ajena","color_hex":"#111111","is_income":false,"is_default_seed":false,
        "is_visible":true,"sort_order":0,"is_system":false},
        "field_hlcs":{"name":"\#(hlc(7))"},"hlc":"\#(hlc(7))","server_seq":1,"schema_version":1}],
        "max_server_seq":1}
        """#
        let pageClient = SyncPullClient(baseURL: URL(string: "https://example.test")!,
                                        tokenProvider: { "jwt" },
                                        urlSession: FixedBodySession(catJSON))
        _ = await engine.pullAndApplyOnce(using: pageClient, context: context, now: applyNow)
        #expect(b.amount == 120)  // reparado (gana A por money-clock)

        // Los writes del reconciler van bajo autor NORMAL → el PRÓXIMO drain los captura y encola.
        engine.drainOnce(context: context)
        let rows = outbox(context)
        #expect(rows.contains { $0.syncID == b.syncID && $0.opRaw == SyncOutboxOp.upsert.rawValue })
    }
}

// MARK: - Stub

/// Devuelve siempre el mismo cuerpo (200).
private final class FixedBodySession: SyncHTTPSession, @unchecked Sendable {
    let body: Data
    init(_ json: String) { self.body = Data(json.utf8) }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
