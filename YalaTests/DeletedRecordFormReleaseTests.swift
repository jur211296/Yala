//
//  DeletedRecordFormReleaseTests.swift
//  YalaTests
//
//  Card 1w89 (ticket `forms-read-their-deleted-model-while-closing`): «Eliminar» del editor de registro borra el registro
//  y el formulario sigue presentado mientras se cierra. Su `body` pinta el importe con `amountCurrencyCode`, que leía el
//  registro en edición: en iOS 27.x leer un modelo borrado aborta. El simulador 27.0 no aborta, así que aquí se fija el
//  mecanismo: tras borrar, el ViewModel ya no apunta al registro y sigue enseñando la divisa de antes.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`. `.serialized` por lo mismo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Editor de registro: suelta lo que borra", .serialized)
struct DeletedRecordFormReleaseTests {

    /// 50 USD dentro de una cuenta en soles: el caso en el que la divisa que se enseña sale del REGISTRO y no de la cuenta.
    /// Con un registro en la divisa de su cuenta, perder la divisa no se notaría y el test no distinguiría nada.
    @Test func trasBorrar_noApuntaAlRegistro_yConservaLaDivisaQueSeVeia() throws {
        let context = try makeTestContext()
        let soles = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        let tx = makeTestTransaction(
            context: context, amount: -50, account: soles, category: category, subcategory: sub, currencyCode: "USD")
        try context.save()

        // Lo que hace `NewTransactionView.prefillFromContext` al editar.
        let vm = NewTransactionViewModel()
        vm.editingTransaction = tx
        vm.selectedAccount = soles
        vm.sourceAccount = soles
        vm.currencyCode = tx.currencyCode
        vm.transactionType = .expense
        #expect(vm.amountCurrencyCode == "USD")

        // Lo que hace `NewTransactionView.deleteTransaction`.
        let shown = vm.amountCurrencyCode
        context.delete(tx)
        try context.save()
        vm.releaseDeletedRecord(keepingAmountCurrency: shown)

        #expect(vm.editingTransaction == nil, "El ViewModel sigue apuntando al registro borrado.")
        #expect(vm.amountCurrencyCode == "USD", "El importe pasó a la divisa de la cuenta mientras el formulario se cierra.")
    }

    /// Una transferencia se edita por su pareja: las dos patas se borran y las dos se sueltan.
    @Test func trasBorrarUnaTransferencia_sueltaLasDosPatas() throws {
        let context = try makeTestContext()
        let soles = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        let ahorro = makeTestAccount(context: context, name: "Ahorro", currencyCode: "PEN")
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        let out = makeTestTransaction(context: context, amount: -20, account: soles, category: category, subcategory: sub)
        let into = makeTestTransaction(context: context, amount: 20, account: ahorro, category: category, subcategory: sub)
        let pairID = UUID().uuidString
        for leg in [out, into] {
            leg.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
            leg.transferPairID = pairID
        }
        try context.save()

        let vm = NewTransactionViewModel()
        vm.transactionType = .transfer
        vm.editingTransaction = out
        vm.editingTransferPair = (out: out, in: into)
        vm.sourceAccount = soles
        vm.destinationAccount = ahorro

        let shown = vm.amountCurrencyCode
        context.delete(out)
        context.delete(into)
        try context.save()
        vm.releaseDeletedRecord(keepingAmountCurrency: shown)

        #expect(vm.editingTransaction == nil)
        #expect(vm.editingTransferPair == nil, "El ViewModel sigue apuntando a la pareja borrada.")
    }
}
