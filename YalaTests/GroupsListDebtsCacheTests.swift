//
//  GroupsListDebtsCacheTests.swift
//  YalaTests
//
//  Las deudas que pinta cada tarjeta de la lista se precalculan en `recalculate()`
//  (`GroupsViewModel.debtsByGroup`) en vez de calcularse en el body de la tarjeta.
//
//  Lo que protegen estos tests es la parte peligrosa de ese cambio: que el valor cacheado
//  sea EXACTAMENTE el que devolvía el cálculo directo, y que se refresque cuando cambian
//  los datos. Un cache de deudas que se queda viejo enseña dinero que no es.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct GroupsListDebtsCacheTests {

    // MARK: - Fixture

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
    }

    /// Grupo con dos miembros y un gasto de `amount` pagado por Ana, repartido a medias.
    /// ⇒ Yo le debo a Ana `amount / 2`.
    @discardableResult
    private func seedGroup(
        _ context: ModelContext,
        name: String,
        currencyCode: String = "PEN",
        simplifyDebts: Bool = false,
        showDebtsInSingleCurrency: Bool = false,
        expenseAmount: Double = 100,
        expenseCurrency: String = "PEN"
    ) throws -> Fixture {
        let group = SplitGroup(
            name: name,
            currencyCode: currencyCode,
            simplifyDebts: simplifyDebts,
            showDebtsInSingleCurrency: showDebtsInSingleCurrency
        )
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        try context.save()

        try addExpense(context, group: group, payer: ana, splitWith: [me, ana],
                       amount: expenseAmount, currencyCode: expenseCurrency)
        return Fixture(group: group, me: me, ana: ana)
    }

    private func addExpense(
        _ context: ModelContext,
        group: SplitGroup,
        payer: SplitMember,
        splitWith members: [SplitMember],
        amount: Double,
        currencyCode: String = "PEN"
    ) throws {
        let expense = SplitExpense(
            groupZoneID: group.cloudKitZoneID,
            amount: amount,
            currencyCode: currencyCode,
            expenseDescription: "Gasto",
            paidByMemberID: payer.id.uuidString
        )
        context.insert(expense)
        let each = amount / Double(members.count)
        for m in members {
            context.insert(SplitShare(
                expenseID: expense.id, memberID: m.id.uuidString,
                amount: each, groupZoneID: group.cloudKitZoneID
            ))
        }
        try context.save()
    }

    /// Monta los singletons que `GroupsViewModel` usa para leer y los limpia al salir.
    private func withServices(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupService.shared.setContext(context)
        GroupExpenseService.shared.setContext(context)
        defer {
            GroupService.shared._testResetContext()
            GroupExpenseService.shared._testResetContext()
        }
        try body()
    }

    /// El cálculo directo, tal como lo hacía el body de la tarjeta antes del cache.
    private func directDebts(_ vm: GroupsViewModel, _ group: SplitGroup) -> [GroupsViewModel.DebtRow] {
        guard let members = vm.membersByGroup[group.cloudKitZoneID],
              let expenses = vm.expensesByGroup[group.cloudKitZoneID],
              let shares = vm.sharesByGroup[group.cloudKitZoneID],
              let settlements = vm.settlementsByGroup[group.cloudKitZoneID] else {
            return []
        }
        return GroupsViewModel.computeCurrentUserDebts(
            members: members, expenses: expenses, shares: shares, settlements: settlements,
            simplifyDebts: group.simplifyDebts,
            convertTo: group.showDebtsInSingleCurrency ? group.currencyCode : nil
        )
    }

    // MARK: - Paridad con el cálculo directo

    @Test func cachedDebts_matchDirectComputation() throws {
        let context = try makeTestContext()
        try withServices(context) {
            let f = try seedGroup(context, name: "Viaje")
            let vm = GroupsViewModel()
            vm.setContext(context)

            let cached = vm.currentUserDebts(for: f.group)
            #expect(cached == directDebts(vm, f.group))
            // Y el contenido es el esperado, no dos vacíos coincidiendo.
            #expect(cached.count == 1)
            #expect(cached.first?.counterpartyName == "Ana")
            #expect(cached.first?.perspective == .iOwe)
            #expect(cached.first?.amount == 50)
        }
    }

    @Test func cachedDebts_matchDirect_whenSimplifyDebtsIsOn() throws {
        let context = try makeTestContext()
        try withServices(context) {
            let f = try seedGroup(context, name: "Simplificado", simplifyDebts: true)
            let vm = GroupsViewModel()
            vm.setContext(context)

            #expect(f.group.simplifyDebts == true)
            #expect(vm.currentUserDebts(for: f.group) == directDebts(vm, f.group))
            #expect(vm.currentUserDebts(for: f.group).isEmpty == false)
        }
    }

    /// El toggle de moneda única mete `CurrencyConverter` en el camino: si el cache se poblara
    /// ignorando `showDebtsInSingleCurrency`, la tarjeta enseñaría la moneda equivocada.
    @Test func cachedDebts_matchDirect_whenSingleCurrencyIsOn() throws {
        let context = try makeTestContext()
        try withServices(context) {
            let f = try seedGroup(
                context, name: "Multimoneda", currencyCode: "PEN",
                showDebtsInSingleCurrency: true, expenseAmount: 80, expenseCurrency: "USD"
            )
            let vm = GroupsViewModel()
            vm.setContext(context)

            let cached = vm.currentUserDebts(for: f.group)
            #expect(cached == directDebts(vm, f.group))
            #expect(cached.first?.currencyCode == "PEN")
            #expect(cached.first?.wasConverted == true)
        }
    }

    // MARK: - Refresco (lo que evita que el cache mienta)

    @Test func cachedDebts_refreshAfterNewExpense() throws {
        let context = try makeTestContext()
        try withServices(context) {
            let f = try seedGroup(context, name: "Viaje")
            let vm = GroupsViewModel()
            vm.setContext(context)
            #expect(vm.currentUserDebts(for: f.group).first?.amount == 50)

            // Otro gasto de 100 pagado por Ana ⇒ le debo 100, no 50.
            try addExpense(context, group: f.group, payer: f.ana,
                           splitWith: [f.me, f.ana], amount: 100)
            vm.loadData()

            let after = vm.currentUserDebts(for: f.group)
            #expect(after.first?.amount == 100)
            #expect(after == directDebts(vm, f.group))
        }
    }

    /// Editar un gasto en sitio no cambia el NÚMERO de gastos: un cache con clave por conteo
    /// devolvería el importe viejo. Este es el caso que el ticket señalaba como riesgo.
    @Test func cachedDebts_refreshAfterInPlaceEdit() throws {
        let context = try makeTestContext()
        try withServices(context) {
            let f = try seedGroup(context, name: "Viaje")
            let vm = GroupsViewModel()
            vm.setContext(context)
            #expect(vm.currentUserDebts(for: f.group).first?.amount == 50)

            let zoneID = f.group.cloudKitZoneID
            let expenses = try context.fetch(FetchDescriptor<SplitExpense>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            let shares = try context.fetch(FetchDescriptor<SplitShare>(
                predicate: #Predicate { $0.groupZoneID == zoneID }
            ))
            #expect(expenses.count == 1)
            for e in expenses { e.amount = 200 }
            for s in shares { s.amount = 100 }
            try context.save()

            vm.loadData()
            let after = vm.currentUserDebts(for: f.group)
            #expect(after.count == 1)
            #expect(after.first?.amount == 100)
            #expect(after == directDebts(vm, f.group))
        }
    }

    /// Liquidar la deuda tiene que vaciar la tarjeta, no dejarla con el número de ayer.
    @Test func cachedDebts_clearAfterSettlement() throws {
        let context = try makeTestContext()
        try withServices(context) {
            let f = try seedGroup(context, name: "Viaje")
            let vm = GroupsViewModel()
            vm.setContext(context)
            #expect(vm.currentUserDebts(for: f.group).isEmpty == false)

            let settlement = SplitSettlement(
                groupZoneID: f.group.cloudKitZoneID,
                fromMemberID: f.me.id.uuidString,
                toMemberID: f.ana.id.uuidString,
                amount: 50, currencyCode: "PEN"
            )
            settlement.isConfirmed = true
            context.insert(settlement)
            try context.save()

            vm.loadData()
            #expect(vm.currentUserDebts(for: f.group).isEmpty)
            #expect(vm.currentUserDebts(for: f.group) == directDebts(vm, f.group))
        }
    }

    // MARK: - Grupos archivados (el orden respecto al guard de recalculate es load-bearing)

    /// Un grupo archivado ANTES de arrancar no llega a cargar gastos (`fetchData()` corta), así que
    /// su tarjeta no muestra deudas. Igual que antes del cache, donde fallaba el guard del body.
    @Test func cachedDebts_emptyForGroupArchivedBeforeLoad() throws {
        let context = try makeTestContext()
        try withServices(context) {
            let f = try seedGroup(context, name: "Viejo")
            f.group.isArchived = true
            try context.save()

            let vm = GroupsViewModel()
            vm.setContext(context)

            #expect(vm.archivedGroups.count == 1)
            #expect(vm.currentUserDebts(for: f.group).isEmpty)
        }
    }

    /// Y uno archivado DURANTE la sesión conserva sus fuentes en los dicts (nadie las retira), así
    /// que su tarjeta sigue enseñando deudas hasta el próximo arranque.
    ///
    /// Este test pinea una POSICIÓN, no sólo un valor: en `recalculate()` las deudas se calculan
    /// ANTES del `guard !group.isArchived`. Moverlas después vaciaría la tarjeta del archivado y
    /// cambiaría lo que ve el usuario sin que nada más se queje.
    @Test func cachedDebts_survivesArchivingDuringSession() throws {
        let context = try makeTestContext()
        try withServices(context) {
            let f = try seedGroup(context, name: "Recién archivado")
            let vm = GroupsViewModel()
            vm.setContext(context)
            #expect(vm.currentUserDebts(for: f.group).first?.amount == 50)

            f.group.isArchived = true
            try context.save()
            vm.loadData()

            #expect(vm.archivedGroups.count == 1)
            #expect(vm.currentUserDebts(for: f.group).first?.amount == 50)
            #expect(vm.currentUserDebts(for: f.group) == directDebts(vm, f.group))
        }
    }

    // MARK: - Aislamiento entre grupos

    @Test func cachedDebts_areIsolatedPerGroup() throws {
        let context = try makeTestContext()
        try withServices(context) {
            let viaje = try seedGroup(context, name: "Viaje", expenseAmount: 100)
            let cena = try seedGroup(context, name: "Cena", expenseAmount: 40)
            let vm = GroupsViewModel()
            vm.setContext(context)

            #expect(vm.currentUserDebts(for: viaje.group).first?.amount == 50)
            #expect(vm.currentUserDebts(for: cena.group).first?.amount == 20)
        }
    }

    /// Un grupo que el VM nunca cargó no tiene entrada en el cache: el lookup cae en `[]`,
    /// igual que caía el guard del body.
    @Test func cachedDebts_emptyForUnknownGroup() throws {
        let context = try makeTestContext()
        try withServices(context) {
            _ = try seedGroup(context, name: "Viaje")
            let vm = GroupsViewModel()
            vm.setContext(context)

            let foraneo = SplitGroup(name: "No cargado")
            #expect(vm.currentUserDebts(for: foraneo).isEmpty)
        }
    }
}
