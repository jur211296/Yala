//
//  ApplyPageBatchLookupTests.swift
//  YalaTests / SentryHangs2026Nov
//
//  YALA-IOS-J (y con él YALA-IOS-A): tras «Activar la nube», cada página de 500 cambios tardaba ~4 s en el hilo principal
//  del iPhone 14, porque el bucle de `applyPage` buscaba fila a fila, en tablas sin índice, de cinco a diez veces por delta.
//  Ahora la página lee por lote antes del bucle (`EntityApplyMap.prepareLookups`).
//
//  Dos cosas que fijar: (1) una página ya no hace una búsqueda suelta por delta —el testigo
//  `EntityApplyMap._testSingleRowFetches`, que sin el arreglo crece con la página—, y (2) lo que la página escribe lo ven
//  sus deltas siguientes igual que antes: born-remote, borrados, refs a algo que llegó en la misma página, danglers y
//  relojes por unidad.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("YALA-IOS-J · la página del apply busca por lote", .serialized)
@MainActor
struct ApplyPageBatchLookupTests {

    // MARK: - Infra (molde de SyncApplyEngineTests: container on-disk con los tres stores)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ApplyBatch-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration("AB-Personal", schema: SwiftDataConfiguration.personalSchema,
                                          url: dir.appendingPathComponent("p.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration("AB-Groups", schema: SwiftDataConfiguration.groupsSchema,
                                        url: dir.appendingPathComponent("g.sqlite"), cloudKitDatabase: .none)
        let meta = ModelConfiguration("AB-Meta", schema: SwiftDataConfiguration.syncMetaSchema,
                                      url: dir.appendingPathComponent("m.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personal, groups, meta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private let node = "0123456789abcdef"
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }
    private let ts = "2023-11-14T22:13:20.000Z"
    private let now = Date(timeIntervalSince1970: 1_700_000_100)

    private func lower(_ id: UUID) -> String { id.uuidString.lowercased() }

    private func txDelta(_ sid: UUID, seq: Int, h: Int, amount: String = "7.0000",
                         category: UUID? = nil, account: UUID? = nil) -> String {
        let cat = category.map { #""\#(lower($0))""# } ?? "null"
        let acc = account.map { #""\#(lower($0))""# } ?? "null"
        return #"""
        {"entity_type":"tx_items","sync_id":"\#(lower(sid))","op":"upsert",
        "fields":{"date":"\#(ts)","amount":"\#(amount)","currency_code":"PEN","note":"n",
        "amount_in_preferred_currency":"\#(amount)","preferred_currency_code":"PEN","exchange_rate":"1.00000000",
        "is_exchange_rate_provisional":false,"created_at":"\#(ts)","category_ref":\#(cat),"account_ref":\#(acc),
        "subcategory_ref":null,"tag_refs":[]},
        "field_hlcs":{"money":"\#(hlc(h))","date":"\#(hlc(h))","note":"\#(hlc(h))","category_ref":"\#(hlc(h))",
        "account_ref":"\#(hlc(h))","subcategory_ref":"\#(hlc(h))","tag_refs":"\#(hlc(h))","created_at":"\#(hlc(h))"},
        "hlc":"\#(hlc(h))","server_seq":\#(seq),"schema_version":1}
        """#
    }

    private func tombstone(_ sid: UUID, seq: Int, h: Int) -> String {
        #"""
        {"entity_type":"tx_items","sync_id":"\#(lower(sid))","op":"tombstone","fields":{},"field_hlcs":{},
        "hlc":"\#(hlc(h))","server_seq":\#(seq),"schema_version":1}
        """#
    }

    private func accountDelta(_ id: UUID, seq: Int, h: Int) -> String {
        #"""
        {"entity_type":"accounts","sync_id":"\#(lower(id))","op":"upsert",
        "fields":{"name":"Nueva","currency_code":"PEN","color_hex":"#000000","icon_name":"x","type":"cash",
        "adjustment_mode":"Ajustar por registro","exclude_from_statistics":false,"is_archived":false,
        "is_system_account":false},
        "field_hlcs":{"name":"\#(hlc(h))"},"hlc":"\#(hlc(h))","server_seq":\#(seq),"schema_version":1}
        """#
    }

    private func page(_ deltas: [String], maxSeq: Int) throws -> PulledPage {
        try SyncPullClient.decodePage(Data(#"{"deltas":[\#(deltas.joined(separator: ","))],"max_server_seq":\#(maxSeq)}"#.utf8))
    }

    private func all<M: PersistentModel>(_ type: M.Type, _ context: ModelContext) throws -> [M] {
        try context.fetch(FetchDescriptor<M>())
    }

    /// Una cuenta, una categoría y `count` movimientos ya sincronizados, cada uno con su testigo y su reloj.
    private func seed(_ context: ModelContext, count: Int) throws -> (account: Account, category: UUID, sids: [UUID]) {
        let account = Account(name: "A", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        context.insert(account)
        let category = Category(name: "C", colorHex: "#000000", isIncome: false)
        let categoryID = UUID()
        category.syncID = categoryID
        context.insert(category)
        var sids: [UUID] = []
        for i in 0..<count {
            let tx = TransactionItem(date: .now, amount: Double(i), currencyCode: "PEN", category: category, account: account)
            let sid = UUID()
            tx.syncID = sid
            context.insert(tx)
            context.insert(SyncIdentity(syncID: sid, entityType: SyncEntityType.transactionItem, localAnchor: "x"))
            context.insert(SyncUnitClock(syncID: sid, entityTable: "tx_items",
                                         unitHlcsJSON: #"{"money":"\#(hlc(1))"}"#, updatedAt: .now))
            sids.append(sid)
        }
        try context.save()
        return (account, categoryID, sids)
    }

    // MARK: - 1. Testigo: la página no busca una fila por delta

    @Test func aPageOfUpdates_doesNotLookUpOneRowPerDelta() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let seeded = try seed(context, count: 300)
        let engine = CloudSyncEngine()

        let deltas = seeded.sids.enumerated().map {
            txDelta($0.element, seq: 10 + $0.offset, h: 2, amount: "9.0000",
                    category: seeded.category, account: seeded.account.shortcutID)
        }
        EntityApplyMap._testSingleRowFetches = 0
        #expect(engine.applyPage(try page(deltas, maxSeq: 400), context: context, now: now))
        let singleFetches = EntityApplyMap._testSingleRowFetches

        // Sin el arreglo: ~5 búsquedas sueltas por delta (fila, testigo de refs, dos danglers, categoría y cuenta):
        // más de 1.000 para 300 deltas. Con él, ninguna de esas tablas se busca fila a fila.
        #expect(singleFetches < 30, "búsquedas sueltas: \(singleFetches)")

        // Y aplicó de verdad, sin duplicar: los mismos 300, con el importe nuevo.
        let txs = try all(TransactionItem.self, context)
        #expect(txs.count == 300)
        #expect(txs.allSatisfy { $0.amount == 9 })
        #expect(try all(SyncUnitClock.self, context).count == 300)
        #expect(try all(SyncIdentity.self, context).count == 300)
    }

    @Test func aPageOfNewRows_doesNotLookUpOneRowPerDelta() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let seeded = try seed(context, count: 200)
        let engine = CloudSyncEngine()

        let deltas = (0..<300).map {
            txDelta(UUID(), seq: 1000 + $0, h: 2, category: seeded.category, account: seeded.account.shortcutID)
        }
        EntityApplyMap._testSingleRowFetches = 0
        #expect(engine.applyPage(try page(deltas, maxSeq: 1400), context: context, now: now))
        #expect(EntityApplyMap._testSingleRowFetches < 30, "búsquedas sueltas: \(EntityApplyMap._testSingleRowFetches)")

        #expect(try all(TransactionItem.self, context).count == 500)
        #expect(try all(SyncIdentity.self, context).count == 500)    // un testigo por born-remote
        #expect(try all(SyncUnitClock.self, context).count == 500)
    }

    // MARK: - 2. Lo que la página escribe lo ven sus deltas siguientes

    /// La cuenta llega en la MISMA página que el movimiento que la apunta: el movimiento la encuentra (no deja dangler).
    @Test func aRefToARowBornEarlierInThePage_resolves() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let accountID = UUID()
        let sid = UUID()

        #expect(engine.applyPage(try page([accountDelta(accountID, seq: 1, h: 1),
                                           txDelta(sid, seq: 2, h: 1, account: accountID)], maxSeq: 2),
                                 context: context, now: now))
        let tx = try #require(try all(TransactionItem.self, context).first)
        #expect(tx.account?.shortcutID == accountID)
        #expect(try all(SyncDanglingRef.self, context).isEmpty)
    }

    /// Dos versiones de una fila NUEVA en la misma página: una sola fila, un testigo y un reloj.
    @Test func twoVersionsOfANewRowInOnePage_makeOneRow() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let sid = UUID()

        #expect(engine.applyPage(try page([txDelta(sid, seq: 1, h: 1, amount: "1.0000"),
                                           txDelta(sid, seq: 2, h: 2, amount: "2.0000")], maxSeq: 2),
                                 context: context, now: now))
        let txs = try all(TransactionItem.self, context)
        #expect(txs.count == 1)
        #expect(txs.first?.amount == 2)
        #expect(try all(SyncIdentity.self, context).count == 1)
        #expect(try all(SyncUnitClock.self, context).count == 1)
    }

    /// Borrada y vuelta a subir en la misma página: la página no le devuelve al upsert la fila que acaba de borrar.
    @Test func aRowDeletedThenUpsertedInOnePage_comesBackOnce() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let seeded = try seed(context, count: 3)
        let engine = CloudSyncEngine()
        let sid = seeded.sids[0]

        #expect(engine.applyPage(try page([tombstone(sid, seq: 10, h: 5),
                                           txDelta(sid, seq: 11, h: 6, amount: "4.0000")], maxSeq: 11),
                                 context: context, now: now))
        let back = try all(TransactionItem.self, context).filter { $0.syncID == sid }
        #expect(back.count == 1)
        #expect(back.first?.amount == 4)
        #expect(try all(SyncIdentity.self, context).filter { $0.syncID == sid }.count == 1)
        #expect(try all(SyncUnitClock.self, context).filter { $0.syncID == sid }.count == 1)
    }

    /// El dangler que la página apunta lo retira la propia página cuando el destino llega después.
    @Test func aDanglerRegisteredInThePage_isClearedWhenItsTargetArrivesLaterInThePage() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let accountID = UUID()
        let sid = UUID()

        #expect(engine.applyPage(try page([txDelta(sid, seq: 1, h: 1, account: accountID),
                                           accountDelta(accountID, seq: 2, h: 1),
                                           txDelta(sid, seq: 3, h: 2, account: accountID)], maxSeq: 3),
                                 context: context, now: now))
        let tx = try #require(try all(TransactionItem.self, context).first)
        #expect(tx.account?.shortcutID == accountID)
        #expect(try all(SyncDanglingRef.self, context).isEmpty)
    }

    // MARK: - 3. Una lectura por lote que falla no cambia dónde falla la página

    /// El lote de testigos no se deja leer, y esta página no los necesita (actualiza filas que ya existen): se aplica,
    /// igual que antes del arreglo. Si el lote lanzara, una tabla que la página no usa la tumbaría.
    @Test func anUnreadableBatchThePageDoesNotNeed_doesNotStopThePage() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let seeded = try seed(context, count: 5)
        let engine = CloudSyncEngine()
        EntityApplyMap._testThrowOnFetchOf = ["SyncIdentity"]
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        let deltas = seeded.sids.enumerated().map { txDelta($0.element, seq: 10 + $0.offset, h: 2, amount: "3.0000") }
        #expect(engine.applyPage(try page(deltas, maxSeq: 20), context: context, now: now))
        #expect(try all(TransactionItem.self, context).allSatisfy { $0.amount == 3 })
    }

    /// Y la que SÍ necesita (crear filas nuevas exige leer sus testigos) sigue sin aplicarse: «no pude leer» no es «no hay».
    @Test func anUnreadableBatchThePageNeeds_stillRollsBackThePage() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        EntityApplyMap._testThrowOnFetchOf = ["SyncIdentity"]
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        #expect(!engine.applyPage(try page([txDelta(UUID(), seq: 1, h: 1)], maxSeq: 1), context: context, now: now))
        #expect(try all(TransactionItem.self, context).isEmpty)
    }

    /// Fuera de una página no queda nada puesto: la búsqueda de siempre.
    @Test func afterThePage_noLookupsRemain() throws {
        let dir = freshDir(); defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        #expect(engine.applyPage(try page([txDelta(UUID(), seq: 1, h: 1)], maxSeq: 1), context: context, now: now))
        #expect(EntityApplyMap.pageLookups == nil)
    }
}
