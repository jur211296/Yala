//
//  NonFiniteMoneyApplyTests.swift
//  YalaTests / CloudSync
//
//  Un importe o una tasa NO FINITOS (`NaN`, `±inf`) que llegan por el pull del canal personal no entran al teléfono
//  (ticket `wire-decoder-accepts-non-finite-money`). El delta va ENTERO a `SyncQuarantine`: el cursor avanza (no
//  atasca), el delta se guarda (no se descarta) y se retira solo cuando llega una versión posterior de la fila. El
//  drenaje del arranque no lo vuelve a aplicar. Container ON-DISK temp con los 3 stores (molde `SyncQuarantineTests`).
//
//  Control rojo con el código viejo: el born-remote nacía con `amount = NaN` y la fila existente se lo quedaba.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Pull · dinero no finito va a cuarentena", .serialized)
@MainActor
struct NonFiniteMoneyApplyTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NonFiniteMoney-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContainer(_ dir: URL) throws -> ModelContainer {
        let personalCfg = ModelConfiguration(
            "NFM-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "NFM-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "NFM-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        return try ModelContainer(for: SwiftDataConfiguration.schema,
                                  configurations: personalCfg, groupsCfg, syncMetaCfg)
    }

    private let node = "0123456789abcdef"
    private func hlc(_ c: Int) -> String { "2023-11-14T22:13:20.000Z-\(String(format: "%04x", c))-\(node)" }
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)
    private let epochTS = "2023-11-14T22:13:20.000Z"

    private func decodePage(_ json: String) throws -> PulledPage {
        try SyncPullClient.decodePage(Data(json.utf8))
    }

    /// Página con UN upsert full-row de `tx_items`. Los importes van como STRING JSON, que es como llegan de PostgREST.
    private func txPage(sid: UUID, serverSeq: Int, amount: String = "10.5000", aip: String = "38.0000",
                        rate: String = "3.62000000", note: String = "hola", h: Int = 1) -> String {
        #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
        "fields":{"date":"\#(epochTS)","amount":"\#(amount)","currency_code":"USD","note":"\#(note)",
        "amount_in_preferred_currency":"\#(aip)","preferred_currency_code":"PEN","exchange_rate":"\#(rate)",
        "is_exchange_rate_provisional":false,"created_at":"\#(epochTS)","tag_refs":[]},
        "field_hlcs":{"money":"\#(hlc(h))","date":"\#(hlc(h))","note":"\#(hlc(h))","currency_code":"\#(hlc(h))",
        "tag_refs":"\#(hlc(h))","created_at":"\#(hlc(h))"},
        "hlc":"\#(hlc(h))","server_seq":\#(serverSeq),"schema_version":1}],"max_server_seq":\#(serverSeq)}
        """#
    }

    // Una lectura que falla no puede pasar por «vacío»: las aserciones `isEmpty` saldrían verdes sin mirar nada.
    private func txItems(_ context: ModelContext) -> [TransactionItem] {
        do { return try context.fetch(FetchDescriptor<TransactionItem>()) } catch {
            Issue.record("fetch TransactionItem: \(error)"); return []
        }
    }
    private func quarantine(_ context: ModelContext) -> [SyncQuarantine] {
        do { return try context.fetch(FetchDescriptor<SyncQuarantine>()) } catch {
            Issue.record("fetch SyncQuarantine: \(error)"); return []
        }
    }
    private func cursor(_ context: ModelContext) -> SyncCursor? {
        try? context.fetch(FetchDescriptor<SyncCursor>()).first
    }

    /// Las formas del wire que antes entraban como no finitas (`"NaN"` es la de Postgres).
    static let nonFinite = ["NaN", "nan", "Infinity", "-Infinity", "inf", "-inf", "1e400"]

    // MARK: - 1. Born-remote: no nace, va a cuarentena, el cursor avanza

    @Test(arguments: nonFinite)
    func bornRemote_nonFiniteAmount_isQuarantined_notMaterialized(_ raw: String) throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let ok = engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 9, amount: raw)), context: context, now: applyNow)

        #expect(ok)
        #expect(txItems(context).isEmpty, "un importe \(raw) no puede materializarse")
        let rows = quarantine(context)
        #expect(rows.count == 1)
        #expect(rows.first?.syncID == sid)
        #expect(rows.first?.serverSeq == 9)
        #expect(rows.first?.entityType == "tx_items")
        // No atasca: el cursor avanzó y el testigo lockstep cuenta la fila.
        #expect(cursor(context)?.serverSeqCursor == 9)
        #expect(cursor(context)?.quarantinePendingCount == 1)
    }

    /// Cada columna del grupo `money`, sola, basta para cuarentenar: la tasa también (`exchange_rate`, escala 8).
    @Test(arguments: [("amount_in_preferred_currency", "NaN"), ("exchange_rate", "-Infinity")])
    func bornRemote_anyMoneyColumnNonFinite_isQuarantined(_ column: String, _ raw: String) throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let sid = UUID()
        let json = column == "exchange_rate" ? txPage(sid: sid, serverSeq: 4, rate: raw) : txPage(sid: sid, serverSeq: 4, aip: raw)
        engine.applyPage(try decodePage(json), context: context, now: applyNow)

        #expect(txItems(context).isEmpty)
        #expect(quarantine(context).count == 1)
    }

    // MARK: - 2. Fila existente: se queda ENTERA como estaba

    @Test func existingRow_nonFiniteUpdate_leavesTheWholeRowAsItWas() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        let sid = UUID()

        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 5, h: 1)), context: context, now: applyNow)
        let tx = try #require(txItems(context).first)
        #expect(tx.amount == 10.5)

        // Versión posterior con el importe en NaN y OTRA nota: no se aplica ni la columna buena. Aplicar la nota y
        // dejar el importe viejo mezclaría dos versiones de la fila.
        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 6, amount: "NaN", note: "cambio", h: 2)),
                         context: context, now: applyNow)

        let after = try #require(txItems(context).first)
        #expect(after.amount == 10.5)
        #expect(after.note == "hola")
        #expect(after.amountInPreferredCurrency == 38.0)
        #expect(quarantine(context).count == 1)
        #expect(cursor(context)?.serverSeqCursor == 6)
    }

    // MARK: - 3. Una versión posterior y finita la retira

    @Test func laterFiniteVersion_appliesAndRetiresTheQuarantinedOne() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        let sid = UUID()

        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 6, amount: "NaN", h: 1)), context: context, now: applyNow)
        #expect(quarantine(context).count == 1)
        #expect(cursor(context)?.quarantinePendingCount == 1)

        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 7, amount: "20.0000", h: 2)),
                         context: context, now: applyNow)

        #expect(txItems(context).first?.amount == 20)
        #expect(quarantine(context).isEmpty, "la versión vieja ya no es la fila: se retira")
        #expect(cursor(context)?.quarantinePendingCount == 0)
    }

    /// Un borrado posterior de la fila también la retira: si no, el Merkle de `tx_items` quedaría apagado para siempre.
    @Test func laterTombstone_retiresTheQuarantinedOne() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        let sid = UUID()

        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 6, amount: "NaN", h: 1)), context: context, now: applyNow)
        let tombstone = #"""
        {"deltas":[{"entity_type":"tx_items","sync_id":"\#(sid.uuidString.lowercased())","op":"tombstone",
        "fields":{},"field_hlcs":{},"hlc":"\#(hlc(2))","server_seq":8,"schema_version":1}],"max_server_seq":8}
        """#
        engine.applyPage(try decodePage(tombstone), context: context, now: applyNow)

        #expect(quarantine(context).isEmpty)
        #expect(cursor(context)?.quarantinePendingCount == 0)
    }

    /// La retirada es por FILA: la cuarentena de otra fila no se toca.
    @Test func laterVersionOfAnotherRow_keepsTheQuarantinedOne() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        let bad = UUID()
        engine.applyPage(try decodePage(txPage(sid: bad, serverSeq: 6, amount: "NaN", h: 1)), context: context, now: applyNow)
        engine.applyPage(try decodePage(txPage(sid: UUID(), serverSeq: 7, h: 2)), context: context, now: applyNow)

        #expect(quarantine(context).map(\.syncID) == [bad])
        #expect(cursor(context)?.quarantinePendingCount == 1)
    }

    /// Un `NaN` sobre otro `NaN` también retira el viejo: solo queda la versión vigente de la fila.
    @Test func laterNonFiniteVersion_replacesTheOlderOneInQuarantine() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        let sid = UUID()

        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 6, amount: "NaN", h: 1)), context: context, now: applyNow)
        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 9, amount: "Infinity", h: 2)), context: context, now: applyNow)

        #expect(quarantine(context).map(\.serverSeq) == [9])
        #expect(cursor(context)?.quarantinePendingCount == 1)
    }

    /// Solo cuenta el dinero: un texto que dice `"NaN"` (o `"inf"`) es un texto y la fila entra.
    @Test func textColumnSayingNaN_isApplied_notQuarantined() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()

        engine.applyPage(try decodePage(txPage(sid: UUID(), serverSeq: 2, note: "NaN")), context: context, now: applyNow)

        #expect(txItems(context).first?.note == "NaN")
        #expect(quarantine(context).isEmpty)
        #expect(EntityApplyMap.nonFiniteMoneyColumns(table: "tx_items", fields: ["note": .string("inf")]).isEmpty)
    }

    /// Con una fila pendiente, la cuarentena se lee en CADA página para poder retirarla. Si no se deja leer, la página
    /// no se aplica y el cursor no avanza: «no pude leer» no es «no hay nada», y avanzar dejaría la versión vieja atrás.
    @Test func withAPendingRow_anUnreadableQuarantine_stopsThePage() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        let sid = UUID()

        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 6, amount: "NaN", h: 1)), context: context, now: applyNow)
        let page = try decodePage(txPage(sid: sid, serverSeq: 7, amount: "20.0000", h: 2))

        engine._testThrowOnApplyRead = .quarantineSeqs
        defer { engine._testThrowOnApplyRead = nil }
        #expect(engine.applyPage(page, context: context, now: applyNow) == false)
        #expect(cursor(context)?.serverSeqCursor == 6)
        #expect(txItems(context).isEmpty)

        // Control: la misma página con la lectura sana se aplica y retira.
        engine._testThrowOnApplyRead = nil
        #expect(engine.applyPage(page, context: context, now: applyNow))
        #expect(txItems(context).first?.amount == 20)
        #expect(quarantine(context).isEmpty)
    }

    /// Un save que falla tras retirar deja la cuarentena y el testigo como estaban (rollback, F-3).
    @Test func failedSave_afterRetiring_leavesTheQuarantineAsItWas() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        let sid = UUID()

        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 6, amount: "NaN", h: 1)), context: context, now: applyNow)
        engine._testThrowOnApplySave = true
        #expect(engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 7, h: 2)), context: context, now: applyNow) == false)
        engine._testThrowOnApplySave = false

        // Contra el store, con un contexto fresco (regla de testing: no aserjar memoria tras un rollback).
        let fresh = ModelContext(context.container)
        #expect(quarantine(fresh).map(\.serverSeq) == [6])
        #expect(cursor(fresh)?.quarantinePendingCount == 1)
        #expect(cursor(fresh)?.serverSeqCursor == 6)
        #expect(txItems(fresh).isEmpty)
    }

    // MARK: - 4. Re-pull idempotente

    @Test func rePullOfTheSamePage_doesNotDuplicate() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        let sid = UUID()
        let json = txPage(sid: sid, serverSeq: 3, amount: "NaN")

        engine.applyPage(try decodePage(json), context: context, now: applyNow)
        engine.applyPage(try decodePage(json), context: context, now: applyNow)

        #expect(quarantine(context).count == 1)
        #expect(cursor(context)?.quarantinePendingCount == 1)
        #expect(txItems(context).isEmpty)
    }

    // MARK: - 5. El drenaje del arranque no lo aplica

    @Test func drainQuarantine_keepsTheNonFiniteDelta() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = ModelContext(try makeContainer(dir))
        let engine = CloudSyncEngine()
        let sid = UUID()

        engine.applyPage(try decodePage(txPage(sid: sid, serverSeq: 3, amount: "Infinity")), context: context, now: applyNow)
        engine.drainQuarantineOnce(context: context, now: applyNow)

        #expect(txItems(context).isEmpty, "el drenaje re-aplicaba cualquier fila de una tabla cableada")
        #expect(quarantine(context).count == 1)
        #expect(cursor(context)?.quarantinePendingCount == 1)
    }

    // MARK: - 6. Todas las columnas de dinero del manifest, tabla por tabla

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// `(tabla, columna)` de cada columna `decimal_fixed` del `capability_manifest.json`: la fuente de verdad de qué es
    /// dinero o tasa en el wire. Una columna nueva entra sola en el caso de abajo.
    static func manifestMoneyColumns() throws -> [(String, String)] {
        struct Manifest: Decodable {
            struct Column: Decodable { let format: String }
            struct Entity: Decodable { let columns: [String: Column] }
            let entities: [String: Entity]
        }
        let data = try Data(contentsOf: repoRoot.appendingPathComponent("capability_manifest.json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        var out: [(String, String)] = []
        for (table, entity) in manifest.entities {
            for (column, spec) in entity.columns where spec.format == "decimal_fixed" { out.append((table, column)) }
        }
        return out.sorted { ($0.0, $0.1) < ($1.0, $1.1) }
    }

    @Test func manifest_hasTheMoneyColumnsThisSuiteExpects() throws {
        // Premisa del caso de abajo: sin columnas, el bucle no probaría nada.
        let columns = try Self.manifestMoneyColumns()
        #expect(columns.count == 14)
        #expect(columns.contains { $0 == ("tx_items", "amount") })
        #expect(columns.contains { $0 == ("tx_items", "exchange_rate") })
        #expect(columns.contains { $0 == ("budgets", "limit_amount") })
        #expect(columns.contains { $0 == ("scheduled_payments", "amount") })
    }

    /// Por cada columna de dinero: un `NaN` la marca y el delta no materializa la fila; un valor finito en la MISMA
    /// columna sí la materializa (control: sin él, «no nace» podría ser que el andamio no crea nada).
    @Test func everyManifestMoneyColumn_nonFiniteIsQuarantined_finiteIsApplied() throws {
        let classByTable = Dictionary(uniqueKeysWithValues: CloudSyncEngine.personalEntityNames.compactMap { name in
            EntityEmissionMap.table(forClass: name).map { ($0, name) }
        })
        for (table, column) in try Self.manifestMoneyColumns() {
            #expect(EntityApplyMap.nonFiniteMoneyColumns(table: table, fields: [column: .string("NaN")]) == [column],
                    "\(table).\(column) no está marcada como dinero en EntityApplyMap")
            #expect(EntityApplyMap.nonFiniteMoneyColumns(table: table, fields: [column: .string("12.5000")]).isEmpty)

            let className = try #require(classByTable[table], "\(table) sin clase")
            for (raw, materializes) in [("NaN", false), ("12.5000", true)] {
                let dir = freshDir(); defer { cleanup(dir) }
                let context = ModelContext(try makeContainer(dir))
                let engine = CloudSyncEngine()
                let sid = UUID()
                let json = #"""
                {"deltas":[{"entity_type":"\#(table)","sync_id":"\#(sid.uuidString.lowercased())","op":"upsert",
                "fields":{"\#(column)":"\#(raw)"},"field_hlcs":{},"hlc":"\#(hlc(1))","server_seq":2,"schema_version":1}],
                "max_server_seq":2}
                """#
                #expect(engine.applyPage(try decodePage(json), context: context, now: applyNow))
                #expect(EntityApplyMap.liveRowExists(entityTypeName: className, syncID: sid, context: context) == materializes,
                        "\(table).\(column) = \(raw)")
                #expect(quarantine(context).count == (materializes ? 0 : 1), "\(table).\(column) = \(raw)")
            }
        }
    }
}
