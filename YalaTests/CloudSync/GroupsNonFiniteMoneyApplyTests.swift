//
//  GroupsNonFiniteMoneyApplyTests.swift
//  YalaTests / CloudSync
//
//  Un importe NO FINITO que baja por el pull de Grupos no entra (ticket `wire-decoder-accepts-non-finite-money`).
//  Grupos no tiene cuarentena: el delta se salta con rastro, la fila local se queda como estaba y el cursor avanza.
//  En la meta del grupo solo se deja sin tocar `budget_limit_amount`: con `nil` se le quitaría el presupuesto a todos.
//
//  Control rojo con el código viejo: el reparto nacía con `amount = NaN` y el gasto existente se lo quedaba.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupsSyncClient · un importe no finito no entra", .serialized)
@MainActor
struct GroupsNonFiniteMoneyApplyTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsNonFinite-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GNF-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GNF-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GNF-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private let group = "SplitGroup-A"
    private let hlc = "2026-07-15T00:00:00.000Z-0000-00000000000000aa"

    private func delta(_ table: String, id: UUID?, seq: Int64, fields: [String: WireValue]) -> GroupPulledDelta {
        GroupPulledDelta(entityType: table, groupID: group, rawSyncID: id?.uuidString, syncID: id, op: .upsert,
                         fields: fields, fieldHlcs: [:], hlc: hlc, serverSeq: seq, schemaVersion: 1)
    }

    @discardableResult
    private func apply(_ d: GroupPulledDelta, client: GroupsSyncClient, context: ModelContext) throws -> Bool {
        let cursor = try client.loadOrCreateCursor(context)
        let page = GroupPulledPage(deltas: [d], cursors: [group: d.serverSeq], memberships: [group])
        return client.applyPulledPage(page, cursor: cursor, context: context)
    }

    private func cursorFor(_ context: ModelContext, client: GroupsSyncClient) throws -> Int64? {
        let json = try client.loadOrCreateCursor(context).groupCursorsJSON
        return try JSONDecoder().decode([String: Int64].self, from: Data(json.utf8))[group]
    }

    private func shareFields(_ amount: String) -> [String: WireValue] {
        ["expense_id": .string(UUID().uuidString), "member_key": .string("member-1"),
         "amount": .string(amount), "is_paid": .bool(false)]
    }

    static let nonFinite = ["NaN", "nan", "Infinity", "-Infinity", "1e400"]

    // MARK: - Reparto y liquidación que nacen: no nacen, el cursor avanza

    @Test(arguments: nonFinite)
    func bornShare_nonFiniteAmount_isSkipped_cursorAdvances(_ raw: String) throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        let ok = try apply(delta("split_shares", id: UUID(), seq: 7, fields: shareFields(raw)), client: client, context: context)

        #expect(ok)
        #expect(try context.fetch(FetchDescriptor<SplitShare>()).isEmpty, "un reparto \(raw) no puede materializarse")
        #expect(try cursorFor(context, client: client) == 7)
    }

    /// Control: la MISMA página con un importe finito sí materializa el reparto.
    @Test func bornShare_finiteAmount_isApplied() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        try apply(delta("split_shares", id: UUID(), seq: 7, fields: shareFields("10.0000")), client: client, context: context)
        #expect(try context.fetch(FetchDescriptor<SplitShare>()).first?.amount == 10)
    }

    @Test func bornSettlement_nonFiniteAmount_isSkipped_finiteIsApplied() throws {
        func fields(_ amount: String) -> [String: WireValue] {
            ["from_member_key": .string("a"), "to_member_key": .string("b"), "amount": .string(amount),
             "currency_code": .string("USD"), "date": .string("2026-07-15T00:00:00.000Z"), "is_confirmed": .bool(true)]
        }
        do {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let client = GroupsSyncClient()
            try apply(delta("split_settlements", id: UUID(), seq: 3, fields: fields("NaN")), client: client, context: context)
            #expect(try context.fetch(FetchDescriptor<SplitSettlement>()).isEmpty)
            #expect(try cursorFor(context, client: client) == 3)
        }
        // Control: la misma liquidación con un importe finito sí nace.
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()
        try apply(delta("split_settlements", id: UUID(), seq: 3, fields: fields("15.0000")), client: client, context: context)
        #expect(try context.fetch(FetchDescriptor<SplitSettlement>()).first?.amount == 15)
    }

    // MARK: - Gasto existente: se queda ENTERO como estaba

    @Test func existingExpense_nonFiniteUpdate_leavesItAsItWas_andALaterFiniteOneApplies() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()
        let id = UUID()

        func fields(_ amount: String, _ desc: String) -> [String: WireValue] {
            ["expense_description": .string(desc), "amount": .string(amount), "currency_code": .string("USD"),
             "date": .string("2026-07-15T00:00:00.000Z"), "paid_by_member_key": .string("member-1"),
             "split_type": .string("equal"), "is_settled": .bool(false)]
        }

        try apply(delta("split_expenses", id: id, seq: 4, fields: fields("12.5000", "Cena")), client: client, context: context)
        #expect(try context.fetch(FetchDescriptor<SplitExpense>()).first?.amount == 12.5)

        try apply(delta("split_expenses", id: id, seq: 5, fields: fields("NaN", "Otra")), client: client, context: context)
        let kept = try #require(try context.fetch(FetchDescriptor<SplitExpense>()).first)
        #expect(kept.amount == 12.5)
        #expect(kept.expenseDescription == "Cena", "aplicar la descripción sin el importe mezclaría dos versiones")
        #expect(try cursorFor(context, client: client) == 5)

        try apply(delta("split_expenses", id: id, seq: 6, fields: fields("20.0000", "Cena 2")), client: client, context: context)
        let fixed = try #require(try context.fetch(FetchDescriptor<SplitExpense>()).first)
        #expect(fixed.amount == 20)
        #expect(fixed.expenseDescription == "Cena 2")
    }

    // MARK: - Meta del grupo: el límite no finito no quita el presupuesto

    @Test func groupMeta_nonFiniteBudgetLimit_keepsTheBudget_butNullStillRemovesIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        func meta(_ seq: Int64, _ limit: WireValue) -> GroupPulledDelta {
            delta(GroupEntityEmissionMap.splitGroup.table, id: nil, seq: seq,
                  fields: ["name": .string("Viaje \(seq)"), "budget_limit_amount": limit])
        }
        func theGroup() throws -> SplitGroup { try #require(try context.fetch(FetchDescriptor<SplitGroup>()).first) }

        try apply(meta(1, .string("100.0000")), client: client, context: context)
        #expect(try theGroup().budgetLimitAmount == 100)

        try apply(meta(2, .string("NaN")), client: client, context: context)
        #expect(try theGroup().budgetLimitAmount == 100, "con el `nil` del decoder se le quitaría el presupuesto")
        #expect(try theGroup().name == "Viaje 2", "el resto de la meta sí se aplica")

        // Control: `null` sigue significando «el admin quitó el presupuesto» (G14).
        try apply(meta(3, .null), client: client, context: context)
        #expect(try theGroup().budgetLimitAmount == nil)
    }
}
