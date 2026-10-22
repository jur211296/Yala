//
//  GroupsCoalescedRecalculationTests.swift
//  YalaTests
//
//  El freno de los cambios remotos en las dos pantallas de Grupos, con SwiftData de verdad: que
//  una ráfaga de `reloadAndRecalculate()` publique UNA vez y con los datos nuevos, que nada se
//  publique antes de que la espera termine, y que un recálculo cancelado no publique.
//
//  La espera la suelta el test (`ManualDebounceSleeper`, en `RecalculationDebouncerTests.swift`) y
//  «la app está activa» se inyecta: nada depende del `applicationState` del host de test.
//
//  Una sola suite `.serialized` para las dos VMs a propósito: `makeTestContext()` reusa el store
//  por fichero, y dos suites hermanas se borrarían las filas una a otra.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct GroupsCoalescedRecalculationTests {

    // MARK: - Fixture

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
    }

    /// Grupo con dos miembros y un gasto de 100 pagado por Ana a medias ⇒ yo le debo 50.
    private func seedGroup(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "PEN")
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        try context.save()
        let f = Fixture(group: group, me: me, ana: ana)
        try addExpense(context, f, amount: 100)
        return f
    }

    /// Gasto pagado por Ana y repartido a medias: lo que llegaría de otro miembro por el sync.
    private func addExpense(_ context: ModelContext, _ f: Fixture, amount: Double) throws {
        let expense = SplitExpense(
            groupZoneID: f.group.cloudKitZoneID,
            amount: amount,
            currencyCode: "PEN",
            expenseDescription: "Gasto",
            paidByMemberID: f.ana.id.uuidString
        )
        context.insert(expense)
        for m in [f.me, f.ana] {
            context.insert(SplitShare(
                expenseID: expense.id, memberID: m.id.uuidString,
                amount: amount / 2, groupZoneID: f.group.cloudKitZoneID
            ))
        }
        try context.save()
    }

    private func withServices(_ context: ModelContext, _ body: () async throws -> Void) async rethrows {
        GroupService.shared.setContext(context)
        GroupExpenseService.shared.setContext(context)
        defer {
            GroupService.shared._testResetContext()
            GroupExpenseService.shared._testResetContext()
        }
        try await body()
    }

    private func myDebt(_ vm: GroupsViewModel, _ group: SplitGroup) -> Double? {
        vm.currentUserDebts(for: group).first?.amount
    }

    // MARK: - Detalle del grupo (y, a través de él, los Ajustes)

    @Test func detail_burstOfRemoteChanges_publishesOnce_withTheNewData() async throws {
        let context = try makeTestContext()
        try await withServices(context) {
            let f = try seedGroup(context)
            let sleeper = ManualDebounceSleeper()
            let vm = GroupDetailViewModel(group: f.group, debouncer: sleeper.makeDebouncer())
            vm.setContext(context)
            #expect(vm.expenses.count == 1)
            #expect(vm.coalescedReloadRevision == 0)

            // Tres gastos de otro miembro, cinco avisos de cambio.
            for amount in [20.0, 40.0, 60.0] { try addExpense(context, f, amount: amount) }
            for _ in 0..<5 { vm.reloadAndRecalculate() }
            await yieldUntil { sleeper.waitingCount == 5 }
            #expect(sleeper.waitingCount == 5)

            // Mientras la espera no termina, nada se publica.
            #expect(vm.expenses.count == 1)
            #expect(vm.coalescedReloadRevision == 0)

            sleeper.releaseAll()
            await drainMainActor()

            #expect(vm.coalescedReloadRevision == 1)
            #expect(vm.expenses.count == 4)
            let anaBalance = vm.balances.first { $0.memberID == f.ana.id.uuidString }?.netBalance
            #expect(anaBalance == 110)
        }
    }

    @Test func detail_cancelledRecalculation_doesNotPublish() async throws {
        let context = try makeTestContext()
        try await withServices(context) {
            let f = try seedGroup(context)
            let sleeper = ManualDebounceSleeper()
            let vm = GroupDetailViewModel(group: f.group, debouncer: sleeper.makeDebouncer())
            vm.setContext(context)

            try addExpense(context, f, amount: 40)
            vm.reloadAndRecalculate()
            await yieldUntil { sleeper.waitingCount == 1 }
            #expect(sleeper.waitingCount == 1)

            vm.cancelRecalculation()  // el `.onDisappear` del detalle
            sleeper.releaseAll()
            await drainMainActor()

            #expect(vm.coalescedReloadRevision == 0)
            #expect(vm.expenses.count == 1)
        }
    }

    @Test func detail_goingToBackground_dropsThePendingRecalculation() async throws {
        let context = try makeTestContext()
        try await withServices(context) {
            let f = try seedGroup(context)
            let sleeper = ManualDebounceSleeper()
            let vm = GroupDetailViewModel(group: f.group, debouncer: sleeper.makeDebouncer())
            vm.setContext(context)

            try addExpense(context, f, amount: 40)
            vm.reloadAndRecalculate()
            await yieldUntil { sleeper.waitingCount == 1 }
            vm.setBackground(true)
            sleeper.releaseAll()
            await drainMainActor()
            #expect(vm.coalescedReloadRevision == 0)
            #expect(vm.expenses.count == 1)

            // La vuelta a primer plano programa uno nuevo (lo hace el `scenePhase` del detalle).
            vm.setBackground(false)
            vm.reloadAndRecalculate()
            await yieldUntil { sleeper.waitingCount == 1 }
            sleeper.releaseAll()
            await drainMainActor()
            #expect(vm.coalescedReloadRevision == 1)
            #expect(vm.expenses.count == 2)
        }
    }

    /// Los gestos de la propia persona recargan en el acto y NO mueven la señal de los Ajustes: ellos
    /// ya pasan por `GroupService`, que sube `dataVersion`, y llegan por el camino con freno.
    @Test func detail_localLoad_isImmediate_andDoesNotMoveTheRevision() async throws {
        let context = try makeTestContext()
        try await withServices(context) {
            let f = try seedGroup(context)
            let sleeper = ManualDebounceSleeper()
            let vm = GroupDetailViewModel(group: f.group, debouncer: sleeper.makeDebouncer())
            vm.setContext(context)

            try addExpense(context, f, amount: 40)
            vm.loadData()

            #expect(vm.expenses.count == 2)
            #expect(vm.coalescedReloadRevision == 0)
            #expect(sleeper.waitingCount == 0)
        }
    }

    // MARK: - Lista de grupos

    @Test func list_burstOfRemoteChanges_publishesOnlyWhenTheWaitEnds() async throws {
        let context = try makeTestContext()
        try await withServices(context) {
            let f = try seedGroup(context)
            let sleeper = ManualDebounceSleeper()
            let vm = GroupsViewModel(debouncer: sleeper.makeDebouncer())
            vm.setContext(context)
            #expect(myDebt(vm, f.group) == 50)

            for amount in [20.0, 40.0] { try addExpense(context, f, amount: amount) }
            for _ in 0..<4 { vm.reloadAndRecalculate() }
            await yieldUntil { sleeper.waitingCount == 4 }
            #expect(sleeper.waitingCount == 4)
            #expect(myDebt(vm, f.group) == 50)

            sleeper.releaseAll()
            await drainMainActor()

            #expect(myDebt(vm, f.group) == 80)
        }
    }

    @Test func list_cancelledRecalculation_doesNotPublish() async throws {
        let context = try makeTestContext()
        try await withServices(context) {
            let f = try seedGroup(context)
            let sleeper = ManualDebounceSleeper()
            let vm = GroupsViewModel(debouncer: sleeper.makeDebouncer())
            vm.setContext(context)

            try addExpense(context, f, amount: 40)
            vm.reloadAndRecalculate()
            await yieldUntil { sleeper.waitingCount == 1 }
            #expect(sleeper.waitingCount == 1)

            vm.cancelRecalculation()  // el `.onDisappear` de la pestaña
            sleeper.releaseAll()
            await drainMainActor()

            #expect(myDebt(vm, f.group) == 50)
        }
    }
}
