//
//  UXAudit22Decidido02BFormTests.swift
//  YalaTests
//
//  El formulario de registro del lote decidido 2.2 · 02, sesión B, sobre SwiftData: la tasa escrita a mano en la cápsula
//  de un gasto en otra divisa es la que se guarda (UX 2.2 · L2-11), y sin tocarla el guardado convierte como siempre.
//
//  Fichero propio con UNA suite: `makeTestContext()` reusa el container por `#fileID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Lote decidido 2.2 · 02 · sesión B · guardar con la tasa", .serialized)
struct UXAudit22Decidido02BFormTests {

    private struct Fixture {
        let context: ModelContext
        let dollars: Account
        let subcategory: Subcategory
    }

    private func makeFixture() throws -> Fixture {
        let context = try makeTestContext()
        let dollars = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
        let category = makeTestCategory(context: context)
        let subcategory = makeTestSubcategory(context: context, category: category)
        try context.save()
        return Fixture(context: context, dollars: dollars, subcategory: subcategory)
    }

    /// Fija la divisa principal mientras dura `block` y deja la que había (patrón de `InitialBalanceServiceTests`).
    private func withPreferredCurrency(_ code: String, _ block: () throws -> Void) rethrows {
        let key = CurrencyDefaults.preferredCurrencyKey
        let original = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.set(code, forKey: key)
        defer {
            if let original {
                UserDefaults.standard.set(original, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        try block()
    }

    private func dollarExpense(_ fixture: Fixture, amount: String) -> NewTransactionViewModel {
        let vm = NewTransactionViewModel()
        vm.setContext(fixture.context)
        vm.amountString = amount
        vm.selectedAccount = fixture.dollars
        vm.sourceAccount = fixture.dollars
        vm.currencyCode = "USD"
        vm.selectedSubcategory = fixture.subcategory
        vm.transactionType = .expense
        return vm
    }

    @Test func gastoEnDolares_enseñaLaEquivalencia() throws {
        // La divisa principal se fija a PEN: por defecto sale de la región del aparato, y en el runner del CI
        // (región de EE. UU.) es USD, que es justo la divisa del gasto y apaga la equivalencia.
        try withPreferredCurrency("PEN") {
            let fixture = try makeFixture()
            let vm = dollarExpense(fixture, amount: "10")
            #expect(vm.showsForeignEquivalence)
            vm.transactionType = .transfer
            #expect(!vm.showsForeignEquivalence, "En una transferencia la tasa va en su propia cápsula.")
        }
    }

    @Test func laTasaEscritaAMano_esLaQueSeGuarda() throws {
        // La divisa principal se fija a PEN: por defecto sale de la región del aparato, y en el runner del CI
        // (región de EE. UU.) es USD, que es justo la divisa del gasto y apaga la equivalencia.
        try withPreferredCurrency("PEN") {
            let fixture = try makeFixture()
            let vm = dollarExpense(fixture, amount: "10")
            vm.setManualForeignRate(3.6)

            let saved = try #require(vm.save(context: fixture.context))
            let tx = try #require(saved.first)
            #expect(tx.amount == -10)
            #expect(normalizeCurrencyCode(tx.currencyCode) == "USD")
            #expect(abs(tx.amountInPreferredCurrency - (-36)) < 0.0001, "10 USD × 3,6 = 36 en la preferida")
            #expect(abs(tx.exchangeRate - 3.6) < 0.0001)
            #expect(tx.isExchangeRateProvisional == false, "La tasa escrita por la persona es exacta.")
        }
    }

    @Test func sinTocarLaTasa_seConvierteComoSiempre() throws {
        // La divisa principal se fija a PEN: por defecto sale de la región del aparato, y en el runner del CI
        // (región de EE. UU.) es USD, que es justo la divisa del gasto y apaga la equivalencia.
        try withPreferredCurrency("PEN") {
            let fixture = try makeFixture()
            let vm = dollarExpense(fixture, amount: "10")
            vm.exchangeRate = 3.6 // la que enseña la cápsula, cargada del servicio: no se escribió a mano
            #expect(!vm.isExchangeRateManual)

            let saved = try #require(vm.save(context: fixture.context))
            let tx = try #require(saved.first)
            let expected = CurrencyConverter.shared.convertChecked(
                Decimal(-10), from: "USD", to: CurrencyDefaults.currentPreferred, on: tx.date, context: fixture.context)
            #expect(abs(tx.amountInPreferredCurrency - (expected.amount as NSDecimalNumber).doubleValue) < 0.0001)
        }
    }

    @Test func cambiarDeCuenta_descartaLaTasaEscrita() throws {
        let fixture = try makeFixture()
        let vm = dollarExpense(fixture, amount: "10")
        vm.setManualForeignRate(3.6)
        #expect(vm.isExchangeRateManual)
        // Lo que hace la vista al cambiar de cuenta (`followSelectedAccount`).
        vm.isExchangeRateManual = false
        #expect(ForeignManualRateLogic.manualRate(
            isManual: vm.isExchangeRateManual, isTransfer: false, rate: vm.exchangeRate,
            amountCurrency: "USD", preferredCurrency: "PEN") == nil)
    }
}
