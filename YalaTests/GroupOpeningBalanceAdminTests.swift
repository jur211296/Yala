//
//  GroupOpeningBalanceAdminTests.swift
//  YalaTests
//
//  Card yd2w · cualquier admin del grupo gestiona los saldos iniciales, no solo quien lo creó.
//
//  Hasta el 2026-10-31 `setOpeningBalance`, `updateOpeningBalance` y `removeOpeningBalance` exigían `group.isOwner`: en el
//  grupo Matri Jürgen es admin y el servicio lo habría rechazado aunque la UI le enseñara el botón. Estos casos fijan las
//  cuatro promesas: un admin que no es el dueño crea, edita y borra; un miembro normal sigue sin poder; el guard de
//  liquidaciones confirmadas vale igual para el admin; y el dueño no pierde nada.
//
//  Harness ON-DISK con los 3 stores (molde de `GroupOpeningBalanceDateTests`): los servicios son singletons compartidos
//  ⇒ suite `.serialized` + `_testResetContext()` en `defer`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Saldos iniciales: cualquier admin, no solo el dueño (card yd2w)", .serialized)
@MainActor
struct GroupOpeningBalanceAdminTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupOpeningBalanceAdmin-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("GroupOpeningBalanceAdminTests: no se pudo crear \(dir.path): \(error)")
        }
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("GroupOpeningBalanceAdminTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GOBA-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "GOBA-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "GOBA-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
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
        let beto: SplitMember
    }

    /// Grupo de Ana (la dueña). Yo entro con `myRole` y `myStatus`, sin ser dueño, salvo que `iAmOwner`.
    private func makeFixture(
        _ context: ModelContext,
        myRole: String,
        myStatus: SplitMemberStatus = .active,
        iAmOwner: Bool = false
    ) throws -> Fixture {
        let group = SplitGroup(name: "Matri", currencyCode: "PEN", isOwner: iAmOwner)
        context.insert(group)
        let ana = SplitMember(
            groupZoneID: group.cloudKitZoneID, displayName: "Ana", role: "admin",
            isGroupOwner: !iAmOwner
        )
        context.insert(ana)
        let me = SplitMember(
            groupZoneID: group.cloudKitZoneID, displayName: "Yo", role: myRole, status: myStatus,
            isGroupOwner: iAmOwner, isCurrentUser: true
        )
        context.insert(me)
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

    /// Un saldo inicial «Beto le debe 50 a Ana» escrito sin pasar por el servicio: lo apuntó la dueña en su teléfono.
    private func seedOpeningBalance(_ context: ModelContext, _ f: Fixture) throws -> SplitExpense {
        let expense = SplitExpense(
            groupZoneID: f.group.cloudKitZoneID, amount: 50, currencyCode: "PEN",
            expenseDescription: L10n.Groups.OpeningBalance.entryDescription,
            paidByMemberID: f.ana.id.uuidString, splitType: "exact"
        )
        expense.isOpeningBalance = true
        context.insert(expense)
        context.insert(SplitShare(
            expenseID: expense.id, memberID: f.beto.id.uuidString, amount: 50, groupZoneID: f.group.cloudKitZoneID
        ))
        try context.save()
        return expense
    }

    private func isNotAdmin(_ error: Error) -> Bool {
        if case GroupExpenseServiceError.notAdmin = error { return true }
        return false
    }

    private func isSettlementLocked(_ error: Error) -> Bool {
        if case GroupExpenseServiceError.expenseHasAssociatedSettlements = error { return true }
        return false
    }

    // MARK: - La decisión

    @Test("La decisión: el dueño siempre; si no, un admin activo; nadie más")
    func permissionTable() {
        typealias L = OpeningBalancePermissionLogic
        #expect(L.canManage(groupIsOwner: true, currentMemberIsActive: false, currentMemberIsAdmin: false))
        #expect(L.canManage(groupIsOwner: false, currentMemberIsActive: true, currentMemberIsAdmin: true))
        #expect(!L.canManage(groupIsOwner: false, currentMemberIsActive: true, currentMemberIsAdmin: false))
        #expect(!L.canManage(groupIsOwner: false, currentMemberIsActive: false, currentMemberIsAdmin: true))
        #expect(!L.canManage(groupIsOwner: false, currentMemberIsActive: false, currentMemberIsAdmin: false))
    }

    // MARK: - Servicio

    @Test("Un admin que no es el dueño crea, edita y borra un saldo inicial")
    func adminNotOwner_createsEditsAndDeletes() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, myRole: "admin")
        #expect(f.group.isOwner == false)

        try withServices(context) {
            let created = try GroupExpenseService.shared.setOpeningBalance(
                in: f.group, debtorMemberID: f.beto.id.uuidString, creditorMemberID: f.ana.id.uuidString,
                amount: 120, currencyCode: "PEN", date: Date.now
            )
            #expect(try openingBalances(context, in: f.group).count == 1)

            try GroupExpenseService.shared.updateOpeningBalance(
                created, in: f.group, debtorMemberID: f.beto.id.uuidString, creditorMemberID: f.ana.id.uuidString,
                amount: 80, currencyCode: "PEN", date: Date.now
            )
            #expect(try openingBalances(context, in: f.group).first?.amount == 80)

            try GroupExpenseService.shared.removeOpeningBalance(created, in: f.group)
            #expect(try openingBalances(context, in: f.group).isEmpty)
        }
    }

    @Test("Un miembro que no es admin no puede crear, editar ni borrar, y no se toca nada")
    func plainMember_isRejectedEverywhere() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, myRole: "member")
        let existing = try seedOpeningBalance(context, f)

        withServices(context) {
            #expect(performing: {
                try GroupExpenseService.shared.setOpeningBalance(
                    in: f.group, debtorMemberID: f.me.id.uuidString, creditorMemberID: f.ana.id.uuidString,
                    amount: 10, currencyCode: "PEN", date: Date.now
                )
            }, throws: isNotAdmin)
            #expect(performing: {
                try GroupExpenseService.shared.updateOpeningBalance(
                    existing, in: f.group, debtorMemberID: f.beto.id.uuidString, creditorMemberID: f.ana.id.uuidString,
                    amount: 1, currencyCode: "PEN", date: Date.now
                )
            }, throws: isNotAdmin)
            #expect(performing: {
                try GroupExpenseService.shared.removeOpeningBalance(existing, in: f.group)
            }, throws: isNotAdmin)
        }

        let rows = try openingBalances(context, in: f.group)
        #expect(rows.count == 1)
        #expect(rows.first?.amount == 50)
    }

    @Test("Un admin que ya salió del grupo no puede")
    func inactiveAdmin_isRejected() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, myRole: "admin", myStatus: .left)

        withServices(context) {
            #expect(performing: {
                try GroupExpenseService.shared.setOpeningBalance(
                    in: f.group, debtorMemberID: f.beto.id.uuidString, creditorMemberID: f.ana.id.uuidString,
                    amount: 10, currencyCode: "PEN", date: Date.now
                )
            }, throws: isNotAdmin)
        }
        #expect(try openingBalances(context, in: f.group).isEmpty)
    }

    @Test("Con una liquidación confirmada de la pareja, el admin tampoco edita ni borra")
    func confirmedSettlement_locksTheAdminToo() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, myRole: "admin")
        let existing = try seedOpeningBalance(context, f)
        let settlement = SplitSettlement(
            groupZoneID: f.group.cloudKitZoneID, fromMemberID: f.beto.id.uuidString,
            toMemberID: f.ana.id.uuidString, amount: 20, currencyCode: "PEN"
        )
        settlement.isConfirmed = true
        context.insert(settlement)
        try context.save()

        withServices(context) {
            #expect(performing: {
                try GroupExpenseService.shared.updateOpeningBalance(
                    existing, in: f.group, debtorMemberID: f.beto.id.uuidString, creditorMemberID: f.ana.id.uuidString,
                    amount: 1, currencyCode: "PEN", date: Date.now
                )
            }, throws: isSettlementLocked)
            #expect(performing: {
                try GroupExpenseService.shared.removeOpeningBalance(existing, in: f.group)
            }, throws: isSettlementLocked)
        }

        let rows = try openingBalances(context, in: f.group)
        #expect(rows.count == 1)
        #expect(rows.first?.amount == 50)
    }

    @Test("El dueño sigue pudiendo aunque su fila no diga admin: nadie pierde lo que tenía")
    func owner_keepsItEvenIfItsRowIsNotAdmin() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, myRole: "member", iAmOwner: true)
        // `isAdmin` es `isGroupOwner || role == "admin"`: con la marca local puesta la fila ya contaría como admin y el
        // caso no probaría el permiso del DUEÑO. Sin ella, solo `group.isOwner` lo deja pasar.
        f.me.isGroupOwner = false
        try context.save()
        #expect(f.me.isAdmin == false)

        try withServices(context) {
            let created = try GroupExpenseService.shared.setOpeningBalance(
                in: f.group, debtorMemberID: f.beto.id.uuidString, creditorMemberID: f.ana.id.uuidString,
                amount: 30, currencyCode: "PEN", date: Date.now
            )
            try GroupExpenseService.shared.removeOpeningBalance(created, in: f.group)
        }
        #expect(try openingBalances(context, in: f.group).isEmpty)
    }
}
