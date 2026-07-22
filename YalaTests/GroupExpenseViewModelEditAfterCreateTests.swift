//
//  GroupExpenseViewModelEditAfterCreateTests.swift
//  YalaTests
//
//  Regresión: tras REGISTRAR un gasto de grupo, la pantalla de éxito ofrece "Editar",
//  que reabre el mismo form. El siguiente `save()` debe ACTUALIZAR el gasto recién creado,
//  no crear un segundo (espejo de `editingTransaction = tx` en NewTransactionViewModel).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct GroupExpenseViewModelEditAfterCreateTests {

    // MARK: - Fixture

    private struct Fixture {
        let context: ModelContext
        let group: SplitGroup
        let vm: GroupExpenseViewModel
    }

    /// Grupo con 3 miembros activos (uno = current user → queda de pagador por default → Caso A)
    /// + una cuenta PEN compatible. Inyecta el contexto a los singletons que `save()` consulta
    /// (`GroupExpenseService` valida vía `GroupService.fetchMembers`).
    ///
    /// El bridge NO se toca a propósito: el host de tests salta el bootstrap ⇒
    /// `GroupTransactionBridge` sin contexto ⇒ `isReady == false` ⇒ `createExpense`/`updateExpense`
    /// NO bridgean (sus side-effects `WidgetDataCache`/`BudgetAlertService` crashean el runner — R8).
    private func makeFixture() throws -> Fixture {
        let context = try makeTestContext()
        GroupExpenseService.shared.setContext(context)
        GroupService.shared.setContext(context)

        let group = SplitGroup(name: "Viaje", currencyCode: "PEN")
        group.defaultSplitType = "equal"
        context.insert(group)

        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        let beto = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Beto")
        context.insert(me); context.insert(ana); context.insert(beto)

        let account = makeTestAccount(context: context, name: "BCP", currencyCode: "PEN")
        try context.save()

        let members = [me, ana, beto]
        let lookup = Dictionary(members.map { ($0.id.uuidString, $0.displayName) }, uniquingKeysWith: { a, _ in a })
        let vm = GroupExpenseViewModel(group: group, members: members, memberNameLookup: lookup)
        vm.setContext(context)
        // Caso A full-mode determinístico: no groupInvite + cuenta PEN compatible satisface
        // isAccountRequired sin depender de SessionState/BridgeModeResolver globales.
        vm.isGroupInviteOverride = false
        vm.amountString = "100"
        vm.expenseDescription = "Cena"
        vm.currencyCode = "PEN"
        vm.selectedAccount = account

        return Fixture(context: context, group: group, vm: vm)
    }

    private func splitExpenses(_ context: ModelContext) throws -> [SplitExpense] {
        try context.fetch(FetchDescriptor<SplitExpense>())
    }

    // MARK: - Tests

    @Test func save_create_setsEditingExpense() throws {
        let fx = try makeFixture()
        defer {
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
        }
        let vm = fx.vm

        #expect(vm.canSave)
        #expect(vm.editingExpense == nil)

        #expect(vm.save() == true)

        #expect(vm.editingExpense != nil)
        #expect(vm.editingExpense?.id.uuidString == vm.lastCreatedExpenseID)
        #expect(vm.isEditMode == true)
        #expect(try splitExpenses(fx.context).count == 1)
    }

    @Test func save_create_thenSaveAgain_updatesInsteadOfDuplicating() throws {
        let fx = try makeFixture()
        defer {
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
        }
        let vm = fx.vm

        #expect(vm.save() == true)
        #expect(try splitExpenses(fx.context).count == 1)

        // "Editar" en la pantalla de éxito vuelve a este mismo form; cambiar el monto y
        // guardar debe ACTUALIZAR el gasto vinculado, no crear un segundo.
        vm.amountString = "150"
        #expect(vm.canSave)
        #expect(vm.save() == true)

        let expenses = try splitExpenses(fx.context)
        #expect(expenses.count == 1)
        #expect(expenses.first?.amount == 150)
        // El opt-in de "¿También registrar?" no se re-dispara en la rama de update.
        #expect(vm.lastCreatedExpenseID == nil)
    }

    // MARK: - Bridge (garantía INDIRECTA — sin test directo)
    //
    // No hay test directo de "≤1 TransactionItem con splitExpenseID == X". `GroupTransactionBridge`
    // es un singleton SIN `_testResetContext`; inyectarle contexto y ejecutar `bridgeExpense` con
    // `shouldSave` por default dispara `WidgetDataCache.updateCache` + `BudgetAlertService`, la causa
    // documentada de la blacklist R8 que crashea el Swift Testing runner (ver GroupTransactionBridgeTests
    // líneas 135-142 + GroupBridgeCloudSyncIntegrationTests). No se puede resetear limpiamente, así que
    // no se inventa un reset. La garantía es INDIRECTA: el bridge deduplica por expenseID (delete+recreate
    // del único id), luego EXACTAMENTE 1 SplitExpense ⇒ a lo sumo 1 TX bridgeada. Los tests de arriba
    // fijan ese "1 SplitExpense".
}
