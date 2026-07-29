//
//  GroupSettlementDeletionTests.swift
//  YalaTests
//
//  Eliminar una liquidación YA CONFIRMADA — el punto de entrada nuevo del menú de la fila en Balances.
//
//  Pinnea las tres promesas de la feature, ninguna de las cuales tenía red:
//   1. `GroupExpenseService.deleteSettlement` NO tiene guard sobre `isConfirmed` y no debe tenerlo:
//      una liquidación confirmada se borra. Si alguien añade ese guard "por prudencia", cae el caso 1.
//   2. El bridge queda LIMPIO: `unbridgeSettlement` se lleva las TX personales (la virtual y la de la
//      cuenta real) y los drafts. Es exactamente lo que promete el copy del diálogo ("si registró un
//      movimiento en tus cuentas, se elimina también") — sin esto quedaría un movimiento huérfano.
//   3. El desbloqueo que motivó la feature: un gasto que `deleteExpense` rechazaba con
//      `expenseHasAssociatedSettlements` se puede borrar en cuanto la liquidación desaparece.
//
//  Harness ON-DISK con los 3 stores (molde de `GroupBridgeCloudSyncIntegrationTests` /
//  `GroupBridgeCaseBPreserveTests`: el History es por CONTAINER). Los tres servicios que toca el camino
//  de borrado son singletons compartidos ⇒ suite `.serialized` + `_testResetContext()` en `defer`.
//  El host de tests salta el bootstrap ⇒ `BridgeModeResolver.appPreferences == nil` ⇒ bridge ON
//  determinístico.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Eliminar una liquidación confirmada", .serialized)
@MainActor
struct GroupSettlementDeletionTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupSettlementDeletion-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GSD-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "GSD-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "GSD-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
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
        let account: Account
    }

    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "USD")
        context.insert(group)
        // `isCurrentUser` + status activo por defecto = lo que pide `validateCurrentUserCanWrite`.
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        let account = Account(
            name: "Efectivo", currencyCode: "USD", colorHex: "#111111",
            iconName: "banknote", type: "cash"
        )
        context.insert(account)
        try context.save()
        return Fixture(group: group, me: me, ana: ana, account: account)
    }

    /// Inyecta el contexto en los 3 singletons del camino de borrado y los limpia al salir.
    /// `GroupTransactionBridge` no expone reset (mismo trato que en `GroupBridgeCaseBPreserveTests`).
    private func withServices(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupExpenseService.shared.setContext(context)
        GroupService.shared.setContext(context)
        GroupTransactionBridge.shared.setContext(context)
        let previousMode = SessionState.shared.onboardingMode
        SessionState.shared.onboardingMode = .full
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
            SessionState.shared.onboardingMode = previousMode
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    // MARK: - Consultas

    private func settlements(_ context: ModelContext, in group: SplitGroup) throws -> [SplitSettlement] {
        let zoneID = group.cloudKitZoneID
        return try context.fetch(FetchDescriptor<SplitSettlement>(
            predicate: #Predicate { $0.groupZoneID == zoneID }
        ))
    }

    private func expenses(_ context: ModelContext, in group: SplitGroup) throws -> [SplitExpense] {
        let zoneID = group.cloudKitZoneID
        return try context.fetch(FetchDescriptor<SplitExpense>(
            predicate: #Predicate { $0.groupZoneID == zoneID }
        ))
    }

    private func bridgedTxs(_ context: ModelContext, settlementID: String) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitSettlementID == settlementID }
        ))
    }

    private func bridgedDrafts(_ context: ModelContext, settlementID: String) throws -> [InboxDraft] {
        try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitSettlementID == settlementID }
        ))
    }

    /// Liquidación yo→Ana (Caso C del bridge: soy el `from`).
    private func makeSettlement(
        _ context: ModelContext, _ f: Fixture,
        amount: Double = 40, confirmed: Bool,
        date: Date = Date(timeIntervalSince1970: 1_000_000)
    ) throws -> SplitSettlement {
        let settlement = SplitSettlement(
            groupZoneID: f.group.cloudKitZoneID,
            fromMemberID: f.me.id.uuidString,
            toMemberID: f.ana.id.uuidString,
            amount: amount,
            currencyCode: "USD",
            date: date
        )
        settlement.isConfirmed = confirmed
        context.insert(settlement)
        try context.save()
        return settlement
    }

    // MARK: - 1. Confirmada se borra, y el bridge se va con ella

    @Test func confirmedSettlement_isDeleted_andBridgedTransactionsGoWithIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            let settlement = try makeSettlement(context, f, confirmed: true)
            // El id se captura ANTES del borrado: tras `context.delete` la fila ya no es consultable.
            let settlementID = settlement.id.uuidString

            // Caso C con cuenta real → TX virtual (+40) + TX en la cuenta del usuario (-40).
            try GroupTransactionBridge.shared.bridgeSettlement(
                settlement, in: f.group, accountForCurrentUser: f.account
            )
            #expect(try bridgedTxs(context, settlementID: settlementID).count == 2)

            try GroupExpenseService.shared.deleteSettlement(settlement, in: f.group)

            // La fila desaparece (el guard `isConfirmed` que nadie debe añadir).
            #expect(try settlements(context, in: f.group).isEmpty)
            // Y con ella el movimiento en las cuentas del usuario — lo que promete el copy del diálogo.
            #expect(try bridgedTxs(context, settlementID: settlementID).isEmpty)
            #expect(try bridgedDrafts(context, settlementID: settlementID).isEmpty)
        }
    }

    /// Caso C sin cuenta elegida: el bridge deja un `InboxDraft` en vez de la TX real. El borrado
    /// también se lo tiene que llevar (si no, el usuario ve en la bandeja un pendiente de algo que
    /// ya no existe).
    @Test func confirmedSettlement_withoutAccount_deletesThePendingDraftToo() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            let settlement = try makeSettlement(context, f, confirmed: true)
            let settlementID = settlement.id.uuidString

            try GroupTransactionBridge.shared.bridgeSettlement(settlement, in: f.group)
            #expect(try bridgedDrafts(context, settlementID: settlementID).count == 1)

            try GroupExpenseService.shared.deleteSettlement(settlement, in: f.group)

            #expect(try settlements(context, in: f.group).isEmpty)
            #expect(try bridgedTxs(context, settlementID: settlementID).isEmpty)
            #expect(try bridgedDrafts(context, settlementID: settlementID).isEmpty)
        }
    }

    // MARK: - 2. El servicio es agnóstico al estado, a propósito

    /// `deleteSettlement` es el MISMO camino que usa "rechazar" sobre una pendiente. Pinnearlo evita
    /// que un futuro guard por `isConfirmed` acabe en el lado equivocado y rompa el rechazo.
    @Test func pendingSettlement_stillDeletable_throughTheSameService() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            let settlement = try makeSettlement(context, f, confirmed: false)
            try GroupExpenseService.shared.deleteSettlement(settlement, in: f.group)
            #expect(try settlements(context, in: f.group).isEmpty)
        }
    }

    // MARK: - 3. El desbloqueo que motivó la feature

    /// El problema real: `deleteExpense` rechaza el borrado si existe cualquier liquidación CONFIRMADA
    /// con `date >= expense.date` (guard F8, conservador a propósito). Sin punto de entrada para borrar
    /// la liquidación, el gasto quedaba inborrable. Este caso pinnea el desbloqueo end-to-end.
    @Test func deletingTheSettlement_unblocksTheExpenseItWasGuarding() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            let expenseDate = Date(timeIntervalSince1970: 1_000_000)
            let expense = SplitExpense(
                groupZoneID: f.group.cloudKitZoneID,
                amount: 90, currencyCode: "USD",
                expenseDescription: "Cena",
                date: expenseDate,
                paidByMemberID: f.me.id.uuidString
            )
            context.insert(expense)
            context.insert(SplitShare(
                expenseID: expense.id, memberID: f.me.id.uuidString,
                amount: 45, groupZoneID: f.group.cloudKitZoneID
            ))
            try context.save()

            // Liquidación confirmada POSTERIOR al gasto → dispara el guard.
            let settlement = try makeSettlement(
                context, f, confirmed: true, date: expenseDate.addingTimeInterval(86_400)
            )

            // `GroupExpenseServiceError` no es Equatable (case con Error asociado) → do/catch tipado.
            var blocked = false
            do {
                try GroupExpenseService.shared.deleteExpense(expense, in: f.group)
            } catch GroupExpenseServiceError.expenseHasAssociatedSettlements {
                blocked = true
            }
            #expect(blocked)
            #expect(try expenses(context, in: f.group).count == 1)

            // Se elimina la liquidación desde el punto de entrada nuevo…
            try GroupExpenseService.shared.deleteSettlement(settlement, in: f.group)
            // …y ahora el gasto sí se puede borrar.
            try GroupExpenseService.shared.deleteExpense(expense, in: f.group)
            #expect(try expenses(context, in: f.group).isEmpty)
        }
    }
}
