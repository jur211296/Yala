//
//  GroupOpeningBalanceFrozenTests.swift
//  YalaTests
//
//  Card jqgy · en un grupo congelado (se movió a la nube de Yala y este teléfono aún no volvió a entrar), los saldos
//  iniciales no se guardan, y el rechazo dice por qué: `movedToBackend`, antes de mirar permisos o liquidaciones.
//
//  Hasta el 2026-11-01 `setOpeningBalance` y `updateOpeningBalance` comprobaban el freeze tarde, dentro de
//  `createExpense`/`updateExpense`: a un miembro no admin le salía «solo un administrador…» y a un saldo con pagos
//  confirmados, el aviso de pagos — los dos falsos para quien mira un grupo de solo lectura. Y la sección de Miembros
//  ofrecía «Añadir» y el editor sin mirar el freeze (`OpeningBalanceSectionLogic`).
//
//  Harness ON-DISK con los 3 stores (molde de `GroupOpeningBalanceAdminTests`): los servicios son singletons
//  compartidos ⇒ suite `.serialized` + `_testResetContext()` en `defer`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Saldos iniciales en un grupo congelado (card jqgy)", .serialized)
@MainActor
struct GroupOpeningBalanceFrozenTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupOpeningBalanceFrozen-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("GroupOpeningBalanceFrozenTests: no se pudo crear \(dir.path): \(error)")
        }
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("GroupOpeningBalanceFrozenTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GOBF-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "GOBF-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "GOBF-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
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
        // Congelado: se movió a la nube de Yala y este teléfono aún no volvió a entrar (`GroupFreezeLogic.isFrozen`).
        group.movedToBackendAt = Date(timeIntervalSince1970: 1_790_000_000)
        group.isBackendGroup = false
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

    private func isMovedToBackend(_ error: Error) -> Bool {
        if case GroupExpenseServiceError.movedToBackend = error { return true }
        return false
    }

    /// Un pago confirmado entre Beto y Ana: bloquea editar su saldo inicial en un grupo vivo.
    private func seedConfirmedSettlement(_ context: ModelContext, _ f: Fixture) throws {
        let settlement = SplitSettlement(
            groupZoneID: f.group.cloudKitZoneID, fromMemberID: f.beto.id.uuidString, toMemberID: f.ana.id.uuidString,
            amount: 10, currencyCode: "PEN"
        )
        settlement.isConfirmed = true
        context.insert(settlement)
        try context.save()
    }

    // MARK: - La sección de Miembros

    @Test("La sección: oculta a quien no gestiona; de solo lectura si el grupo está congelado; editable si no")
    func sectionModeTable() {
        typealias L = OpeningBalanceSectionLogic
        #expect(L.mode(isManager: false, isFrozen: false) == .hidden)
        #expect(L.mode(isManager: false, isFrozen: true) == .hidden)
        #expect(L.mode(isManager: true, isFrozen: false) == .editable)
        #expect(L.mode(isManager: true, isFrozen: true) == .frozenReadOnly)
        #expect(!L.Mode.frozenReadOnly.allowsChanges)
        #expect(L.Mode.editable.allowsChanges)
        #expect(!L.Mode.hidden.allowsChanges)
    }

    // MARK: - Servicio

    @Test("Fixture: el grupo está congelado de verdad")
    func fixtureIsFrozen() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, myRole: "admin")
        #expect(f.group.isMigratedFrozen)
    }

    /// Red de regresión, no discriminante: con el código de antes un admin ya oía `movedToBackend` desde `createExpense`.
    @Test("Un admin no crea un saldo inicial en un grupo congelado: «se movió», y no se escribe nada")
    func admin_cannotCreate() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, myRole: "admin")

        withServices(context) {
            #expect(performing: {
                try GroupExpenseService.shared.setOpeningBalance(
                    in: f.group, debtorMemberID: f.beto.id.uuidString, creditorMemberID: f.ana.id.uuidString,
                    amount: 120, currencyCode: "PEN", date: Date.now
                )
            }, throws: { isMovedToBackend($0) })
        }
        #expect(try openingBalances(context, in: f.group).isEmpty)
    }

    @Test("Un miembro no admin oye «se movió», no «solo un administrador»: el freeze va primero")
    func plainMember_hearsMovedNotNotAdmin() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, myRole: "member")
        let existing = try seedOpeningBalance(context, f)

        withServices(context) {
            #expect(performing: {
                try GroupExpenseService.shared.setOpeningBalance(
                    in: f.group, debtorMemberID: f.beto.id.uuidString, creditorMemberID: f.ana.id.uuidString,
                    amount: 120, currencyCode: "PEN", date: Date.now
                )
            }, throws: { isMovedToBackend($0) })
            #expect(performing: {
                try GroupExpenseService.shared.updateOpeningBalance(
                    existing, in: f.group, debtorMemberID: f.beto.id.uuidString,
                    creditorMemberID: f.ana.id.uuidString, amount: 80, currencyCode: "PEN", date: Date.now
                )
            }, throws: { isMovedToBackend($0) })
        }
        #expect(try openingBalances(context, in: f.group).map(\.amount) == [50])
    }

    @Test("Editar un saldo con pagos confirmados en un grupo congelado: «se movió», no el aviso de pagos")
    func admin_editWithSettlement_hearsMoved() throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, myRole: "admin")
        let existing = try seedOpeningBalance(context, f)
        try seedConfirmedSettlement(context, f)

        withServices(context) {
            #expect(performing: {
                try GroupExpenseService.shared.updateOpeningBalance(
                    existing, in: f.group, debtorMemberID: f.beto.id.uuidString,
                    creditorMemberID: f.ana.id.uuidString, amount: 80, currencyCode: "PEN", date: Date.now
                )
            }, throws: { isMovedToBackend($0) })
            #expect(performing: {
                try GroupExpenseService.shared.removeOpeningBalance(existing, in: f.group)
            }, throws: { isMovedToBackend($0) })
        }
        #expect(try openingBalances(context, in: f.group).map(\.amount) == [50])
    }
}
