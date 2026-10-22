//
//  MismatchedTransactionSaveTests.swift
//  YalaTests
//
//  Guardar una transacción cuya divisa no es la de su cuenta ya no la reetiqueta.
//  Ticket `saving-a-mismatched-transaction-relabels-it-without-converting` (decisión 2A de Jürgen:
//  «el historial no se toca»).
//
//  El formulario se prepara como lo hace `NewTransactionView.prefillFromContext` al editar
//  (importe, cuenta, divisa de la transacción, subcategoría, tipo y fecha): esa función es privada
//  de la vista y es la única forma de llegar aquí desde la UI.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`. `.serialized` por lo mismo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Guardar una fila desemparejada", .serialized)
struct MismatchedTransactionSaveTests {

    private struct Fixture {
        let context: ModelContext
        let soles: Account
        let dollars: Account
        let subcategory: Subcategory
        let tx: TransactionItem
    }

    /// 50 USD dentro de una cuenta en soles: lo que deja un cambio de divisa de cuenta sin convertir,
    /// o el chat antiguo.
    private func makeFixture() throws -> Fixture {
        let context = try makeTestContext()
        _ = try makeTestExchangeRate(context: context, dateKey: "2026-03-10",
                                     rates: ["USD": 1.0, "PEN": 3.75])
        let soles = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        let dollars = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        let tx = makeTestTransaction(
            context: context, amount: -50, date: Date(),
            account: soles, category: category, subcategory: sub, currencyCode: "USD")
        try context.save()
        return Fixture(context: context, soles: soles, dollars: dollars, subcategory: sub, tx: tx)
    }

    /// Lo que hace `prefillFromContext` con `transactionToEdit`.
    private func openForEditing(_ fixture: Fixture) -> NewTransactionViewModel {
        let vm = NewTransactionViewModel()
        vm.editingTransaction = fixture.tx
        vm.amountString = AmountInputHelper.formatWithGrouping(abs(fixture.tx.amount))
        vm.selectedAccount = fixture.tx.account
        vm.sourceAccount = fixture.tx.account
        vm.currencyCode = fixture.tx.currencyCode
        vm.selectedSubcategory = fixture.tx.subcategory
        vm.transactionType = .expense
        vm.transactionDate = fixture.tx.date
        return vm
    }

    /// **El bug del ticket:** abrir y guardar sin tocar nada convertía 50 USD en 50 PEN.
    @Test func guardarSinCambios_conservaImporteYDivisa() throws {
        let fixture = try makeFixture()
        let vm = openForEditing(fixture)
        #expect(vm.amountCurrencyCode == "USD")

        #expect(vm.save(context: fixture.context) != nil)

        #expect(fixture.tx.amount == -50)
        #expect(normalizeCurrencyCode(fixture.tx.currencyCode) == "USD")
        #expect(fixture.tx.account?.persistentModelID == fixture.soles.persistentModelID)
    }

    /// Si la persona cambia el importe, se guarda en la divisa que la pantalla le enseña: la de la
    /// transacción (el símbolo del importe sale de `amountCurrencyCode`).
    @Test func cambiarElImporte_loGuardaEnLaDivisaQueSeVe() throws {
        let fixture = try makeFixture()
        let vm = openForEditing(fixture)
        vm.amountString = "60"

        #expect(vm.save(context: fixture.context) != nil)

        #expect(fixture.tx.amount == -60)
        #expect(normalizeCurrencyCode(fixture.tx.currencyCode) == "USD")
    }

    /// Cambiar de cuenta sigue el criterio de siempre: manda la cuenta elegida (y la pantalla ya
    /// enseña su divisa). Mover una fila de cuenta es otro ticket.
    @Test func cambiarDeCuenta_mandaLaDivisaDeLaCuenta() throws {
        let fixture = try makeFixture()
        let otherSoles = makeTestAccount(context: fixture.context, name: "Otra en soles", currencyCode: "PEN")
        try fixture.context.save()
        let vm = openForEditing(fixture)
        vm.selectedAccount = otherSoles
        #expect(vm.amountCurrencyCode == "PEN")

        #expect(vm.save(context: fixture.context) != nil)

        #expect(normalizeCurrencyCode(fixture.tx.currencyCode) == "PEN")
    }

    /// Crear sigue igual: la divisa es la de la cuenta.
    @Test func crear_usaLaDivisaDeLaCuenta() {
        let vm = NewTransactionViewModel()
        let account = Account(name: "Soles", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        vm.selectedAccount = account
        #expect(vm.amountCurrencyCode == "PEN")
    }
}
