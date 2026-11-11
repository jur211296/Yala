//
//  OpeningBalanceReplacePromptTests.swift
//  YalaTests
//
//  Lote 2.3 de Grupos (10-nov): añadir un saldo inicial entre dos personas que ya tienen uno lo reemplazaba sin avisar.
//  El formulario pregunta ahora con `openingBalanceThatAddingWouldReplace`, que tiene que contestar EXACTAMENTE lo que
//  `setOpeningBalance` va a hacer: el saldo que editaría, o `nil` cuando crea uno aparte (otra moneda, otra pareja, o un
//  pago confirmado que no deja editar el que había).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Saldo inicial: qué reemplazaría añadir otro", .serialized)
@MainActor
struct OpeningBalanceReplacePromptTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpeningBalanceReplace-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("OpeningBalanceReplacePromptTests: no se pudo crear \(dir.path): \(error)")
        }
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "OBR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "OBR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "OBR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
        let beto: SplitMember
    }

    /// Grupo vivo (no congelado) del que soy dueño, con Ana y Beto.
    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "PEN", isOwner: true)
        context.insert(group)
        let me = SplitMember(
            groupZoneID: group.cloudKitZoneID, displayName: "Yo", role: "admin",
            isGroupOwner: true, isCurrentUser: true
        )
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        let beto = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Beto")
        context.insert(beto)
        try context.save()
        return Fixture(group: group, me: me, ana: ana, beto: beto)
    }

    private func withServices(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupExpenseService.shared.setContext(context)
        GroupService.shared.setContext(context)
        GroupTransactionBridge.shared.setContext(context)
        let previousPrivateSession = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = true
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            GroupExpenseService._testFailNextSettlementSave = false
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
            GroupTransactionBridge.shared._testClearContext()
            SessionState.shared.hasPrivateSession = previousPrivateSession
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    private func add(_ f: Fixture, debtor: SplitMember, creditor: SplitMember, amount: Double, currency: String = "PEN") throws -> SplitExpense {
        try GroupExpenseService.shared.setOpeningBalance(
            in: f.group, debtorMemberID: debtor.id.uuidString, creditorMemberID: creditor.id.uuidString,
            amount: amount, currencyCode: currency, date: Date(timeIntervalSince1970: 1_793_000_000)
        )
    }

    private func wouldReplace(_ f: Fixture, debtor: SplitMember, creditor: SplitMember, currency: String = "PEN") throws -> SplitExpense? {
        try GroupExpenseService.shared.openingBalanceThatAddingWouldReplace(
            in: f.group, debtorMemberID: debtor.id.uuidString, creditorMemberID: creditor.id.uuidString,
            currencyCode: currency
        )
    }

    @Test("Entre la misma pareja y moneda, en los dos sentidos: dice cuál, y es el que guardar edita")
    func samePair_namesTheOneThatSavingEdits() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            #expect(try wouldReplace(f, debtor: f.beto, creditor: f.ana) == nil)
            let first = try add(f, debtor: f.beto, creditor: f.ana, amount: 50)

            let same = try #require(try wouldReplace(f, debtor: f.beto, creditor: f.ana))
            let reversed = try #require(try wouldReplace(f, debtor: f.ana, creditor: f.beto))
            #expect(same.id == first.id)
            #expect(reversed.id == first.id)

            // Lo que pasa al confirmar no cambia: setOpeningBalance edita ese mismo, y sigue habiendo uno.
            let saved = try add(f, debtor: f.ana, creditor: f.beto, amount: 30)
            #expect(saved.id == first.id)
            #expect(GroupExpenseService.shared.openingBalanceDebtorMemberID(of: saved) == f.ana.id.uuidString)
        }
    }

    @Test("Otra moneda u otra pareja: no reemplaza nada")
    func otherCurrencyOrPair_replacesNothing() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            _ = try add(f, debtor: f.beto, creditor: f.ana, amount: 50)
            #expect(try wouldReplace(f, debtor: f.beto, creditor: f.ana, currency: "USD") == nil)
            #expect(try wouldReplace(f, debtor: f.beto, creditor: f.me) == nil)
        }
    }

    @Test("En un grupo congelado la pregunta no sale: el aviso de por qué, como al guardar")
    func frozenGroup_throwsBeforeAsking() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            _ = try add(f, debtor: f.beto, creditor: f.ana, amount: 50)
            // Control: sin congelar, pregunta.
            #expect(try wouldReplace(f, debtor: f.beto, creditor: f.ana) != nil)
            f.group.movedToBackendAt = Date(timeIntervalSince1970: 1_790_000_000)
            f.group.isBackendGroup = false
            try context.save()
            #expect(f.group.isMigratedFrozen)
            #expect(performing: { _ = try wouldReplace(f, debtor: f.beto, creditor: f.ana) }, throws: { error in
                if case GroupExpenseServiceError.movedToBackend = error { return true }
                return false
            })
        }
    }

    @Test("Con un pago confirmado entre ellos no se puede editar: el nuevo va aparte y no se pregunta")
    func lockedBySettlement_replacesNothing() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            let first = try add(f, debtor: f.beto, creditor: f.ana, amount: 50)
            let settlement = SplitSettlement(
                groupZoneID: f.group.cloudKitZoneID, fromMemberID: f.beto.id.uuidString,
                toMemberID: f.ana.id.uuidString, amount: 10, currencyCode: "PEN"
            )
            settlement.isConfirmed = true
            context.insert(settlement)
            try context.save()

            #expect(try wouldReplace(f, debtor: f.beto, creditor: f.ana) == nil)
            // Y es verdad: guardar crea otro, no toca el que había.
            let second = try add(f, debtor: f.beto, creditor: f.ana, amount: 20)
            #expect(second.id != first.id)
            #expect(first.amount == 50)
        }
    }
}
