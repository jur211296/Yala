//
//  GroupOpeningBalanceDateTests.swift
//  YalaTests
//
//  Card t3fq · el saldo inicial de un miembro aceptado hace tiempo, con fecha.
//
//  Hasta el 2026-10-28 `setOpeningBalance` y `updateOpeningBalance` fechaban SIEMPRE en `group.createdAt`: el registro
//  caía al fondo del grupo y editarlo lo devolvía ahí. Y un segundo saldo de la misma pareja creaba otra fila. Estos
//  casos fijan las tres promesas: la fecha elegida es la del registro (y la del movimiento de la cuenta «Grupos»),
//  editar no la pierde, y uno nuevo de la misma pareja y moneda reemplaza al que había.
//
//  Harness ON-DISK con los 3 stores (molde de `GroupSettlementDeletionTests`): los servicios son singletons
//  compartidos ⇒ suite `.serialized` + `_testResetContext()` en `defer`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Saldo inicial con fecha, en cualquier momento (card t3fq)", .serialized)
@MainActor
struct GroupOpeningBalanceDateTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupOpeningBalanceDate-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GOBD-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "GOBD-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "GOBD-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
    }

    /// Grupo creado hace un año por mí; Ana aceptada hace seis meses (el caso de Jürgen: «la acepté hace rato»).
    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Depa", currencyCode: "PEN", isOwner: true)
        group.createdAt = Date.now.addingTimeInterval(-365 * 86_400)
        context.insert(group)
        let me = SplitMember(
            groupZoneID: group.cloudKitZoneID, displayName: "Yo", role: "admin",
            isGroupOwner: true, isCurrentUser: true
        )
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        ana.joinedAt = Date.now.addingTimeInterval(-180 * 86_400)
        context.insert(ana)
        try context.save()
        return Fixture(group: group, me: me, ana: ana)
    }

    private func withServices(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupExpenseService.shared.setContext(context)
        GroupService.shared.setContext(context)
        GroupTransactionBridge.shared.setContext(context)
        let previousPrivateSession = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = true
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
            SessionState.shared.hasPrivateSession = previousPrivateSession
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    private func openingBalances(_ context: ModelContext, in group: SplitGroup) throws -> [SplitExpense] {
        let zoneID = group.cloudKitZoneID
        return try context.fetch(FetchDescriptor<SplitExpense>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isOpeningBalance == true }
        ))
    }

    private func debtor(_ context: ModelContext, of expense: SplitExpense) throws -> String? {
        let expenseID = expense.id
        return try context.fetch(FetchDescriptor<SplitShare>(
            predicate: #Predicate { $0.expenseID == expenseID }
        )).first?.memberID
    }

    private func bridgedTxs(_ context: ModelContext, expense: SplitExpense) throws -> [TransactionItem] {
        let expenseID = expense.id.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == expenseID }
        ))
    }

    // MARK: - Casos

    @Test("Un miembro aceptado hace meses recibe su saldo con la fecha elegida, no la de creación del grupo")
    func memberAcceptedLongAgo_getsTheChosenDate() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        let chosen = Date.now.addingTimeInterval(-3 * 86_400)

        try withServices(context) {
            try GroupExpenseService.shared.setOpeningBalance(
                in: f.group,
                debtorMemberID: f.ana.id.uuidString,
                creditorMemberID: f.me.id.uuidString,
                amount: 120,
                currencyCode: "PEN",
                date: chosen
            )
        }

        let rows = try openingBalances(context, in: f.group)
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.date == chosen)
        #expect(row.date != f.group.createdAt)
        #expect(try debtor(context, of: row) == f.ana.id.uuidString)
        // El movimiento de la cuenta «Grupos» de quien lo apunta (acreedor) lleva la misma fecha.
        let txs = try bridgedTxs(context, expense: row)
        #expect(txs.count == 1)
        #expect(txs.first?.date == chosen)
    }

    @Test("Una fecha futura se guarda como hoy")
    func futureDate_isStoredAsToday() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        let before = Date.now

        try withServices(context) {
            try GroupExpenseService.shared.setOpeningBalance(
                in: f.group,
                debtorMemberID: f.ana.id.uuidString,
                creditorMemberID: f.me.id.uuidString,
                amount: 50,
                currencyCode: "PEN",
                date: Date.now.addingTimeInterval(10 * 86_400)
            )
        }

        let row = try #require(try openingBalances(context, in: f.group).first)
        #expect(row.date >= before)
        #expect(row.date <= Date.now)
    }

    @Test("Editar un saldo cambia su fecha a la elegida, y no la devuelve a la de creación del grupo")
    func editing_keepsTheChosenDate() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        let first = Date.now.addingTimeInterval(-10 * 86_400)
        let second = Date.now.addingTimeInterval(-40 * 86_400)

        try withServices(context) {
            let expense = try GroupExpenseService.shared.setOpeningBalance(
                in: f.group, debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
                amount: 80, currencyCode: "PEN", date: first
            )
            try GroupExpenseService.shared.updateOpeningBalance(
                expense, in: f.group, debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
                amount: 95, currencyCode: "PEN", date: second
            )
        }

        let rows = try openingBalances(context, in: f.group)
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.amount == 95)
        #expect(row.date == second)
    }

    @Test("Un saldo nuevo entre las mismas dos personas y en la misma moneda reemplaza al que había")
    func newForSamePair_replacesTheExisting() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        let later = Date.now.addingTimeInterval(-1 * 86_400)
        var firstID: UUID?

        try withServices(context) {
            firstID = try GroupExpenseService.shared.setOpeningBalance(
                in: f.group, debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
                amount: 80, currencyCode: "PEN", date: Date.now.addingTimeInterval(-20 * 86_400)
            ).id
            // En el sentido contrario: ahora soy yo quien le debe a Ana.
            try GroupExpenseService.shared.setOpeningBalance(
                in: f.group, debtorMemberID: f.me.id.uuidString, creditorMemberID: f.ana.id.uuidString,
                amount: 30, currencyCode: "PEN", date: later
            )
        }

        let rows = try openingBalances(context, in: f.group)
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.id == firstID)
        #expect(row.amount == 30)
        #expect(row.paidByMemberID == f.ana.id.uuidString)
        #expect(try debtor(context, of: row) == f.me.id.uuidString)
        #expect(row.date == later)
    }

    @Test("Si el saldo que había ya no se puede tocar (un pago confirmado), el nuevo va aparte y el viejo no cambia")
    func replacementLockedBySettlement_addsANewOneAndKeepsTheOld() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        var firstID: UUID?

        try withServices(context) {
            firstID = try GroupExpenseService.shared.setOpeningBalance(
                in: f.group, debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
                amount: 80, currencyCode: "PEN", date: Date.now.addingTimeInterval(-20 * 86_400)
            ).id
            // Ana me pagó y lo confirmé: el guard de liquidaciones bloquea editar el saldo de esta pareja.
            let settlement = SplitSettlement(
                groupZoneID: f.group.cloudKitZoneID, fromMemberID: f.ana.id.uuidString,
                toMemberID: f.me.id.uuidString, amount: 30, currencyCode: "PEN"
            )
            settlement.isConfirmed = true
            context.insert(settlement)
            try context.save()

            try GroupExpenseService.shared.setOpeningBalance(
                in: f.group, debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
                amount: 25, currencyCode: "PEN", date: Date.now
            )
        }

        let rows = try openingBalances(context, in: f.group)
        #expect(rows.count == 2)
        let old = try #require(rows.first { $0.id == firstID })
        #expect(old.amount == 80)
        #expect(rows.contains { $0.id != firstID && $0.amount == 25 })
    }

    @Test("En otra moneda es otro saldo: no reemplaza")
    func newForSamePairOtherCurrency_isAnotherBalance() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            try GroupExpenseService.shared.setOpeningBalance(
                in: f.group, debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
                amount: 80, currencyCode: "PEN", date: Date.now
            )
            try GroupExpenseService.shared.setOpeningBalance(
                in: f.group, debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
                amount: 20, currencyCode: "USD", date: Date.now
            )
        }

        let rows = try openingBalances(context, in: f.group)
        #expect(rows.count == 2)
        #expect(Set(rows.map(\.currencyCode)) == ["PEN", "USD"])
    }
}
