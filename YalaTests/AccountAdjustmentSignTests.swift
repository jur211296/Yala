//
//  AccountAdjustmentSignTests.swift
//  YalaTests
//
//  «Ajustar por registro» arrancaba con el signo en «Positivo» / «A favor» aunque la cuenta estuviera en
//  negativo. Quien debe S/ 1,200 en su tarjeta escribía «1200» y Yala lo guardaba como +1,200, con un
//  ajuste de +2,400 (auditoría UX 2.2, lote 7, B6). El signo arranca ahora en el del saldo de hoy.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("El signo del ajuste arranca en el del saldo de hoy", .serialized)
@MainActor
struct AccountAdjustmentSignTests {

    private func makeViewModel(balance: Double) throws -> AccountFormViewModel {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Tarjeta", currencyCode: "PEN")
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        // Con su saldo inicial: sin él, el formulario abre en «Cambiar saldo inicial» y no en «Ajustar por registro».
        let opening = makeTestTransaction(
            context: context, amount: balance, date: Date(),
            account: account, category: category, subcategory: sub)
        opening.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        try context.save()
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.setContext(context)
        return vm
    }

    @Test func negativeBalance_startsNegative() throws {
        let vm = try makeViewModel(balance: -1_200)
        #expect(vm.selectedAdjustmentMode == .byEntry)
        #expect(vm.currentBalance == -1_200)
        #expect(vm.isPositive == false)

        // Escribir la deuda tal cual da el mismo saldo: no hace falta ajuste.
        vm.balanceText = "1200"
        #expect(vm.needsAdjustment == false)
    }

    @Test func positiveBalance_startsPositive() throws {
        let vm = try makeViewModel(balance: 800)
        #expect(vm.isPositive == true)
    }

    @Test func backToByEntry_keepsTheSignOfTodaysBalance() throws {
        let vm = try makeViewModel(balance: -1_200)
        vm.selectedAdjustmentMode = .changeInitialBalance
        vm.adjustmentModeChanged()
        vm.selectedAdjustmentMode = .byEntry
        vm.adjustmentModeChanged()
        #expect(vm.balanceText.isEmpty)
        #expect(vm.isPositive == false)
    }

    // MARK: - El mensaje de «Eliminar cuenta» (B1)

    @Test func deleteMessage_saysHowManyRecordsAndWhereTheyGo() {
        #expect(AccountDeleteConfirmation.message(recordCount: 0) == L10n.Account.deleteConfirmMessageEmpty)
        let three = AccountDeleteConfirmation.message(recordCount: 3)
        #expect(three == L10n.Account.deleteConfirmMessage(3))
        #expect(three.contains("3"))
    }
}
