//
//  AccountFormCurrencyGateTests.swift
//  YalaTests
//
//  El formulario de cuenta no deja desemparejar el histórico al cambiar la divisa.
//  Ticket `changing-an-account-currency-orphans-its-whole-history`.
//
//  El gate vive en DOS sitios a propósito —la vista no deja abrir el selector, y el ViewModel no deja
//  guardar— y esta suite prueba el segundo. Es el que aguanta si mañana otra pantalla reusa el
//  ViewModel o si el gate de la vista se cae en un refactor: un guard puesto solo en la capa que se
//  ve es un guard medio puesto.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`. `.serialized` porque cada
//  test pide contexto y el helper vacía el store en cada llamada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("El gate del cambio de divisa en el formulario de cuenta", .serialized)
struct AccountFormCurrencyGateTests {

    // MARK: - Helpers

    private struct Fixture {
        let context: ModelContext
        let account: Account
        let transactions: [TransactionItem]
    }

    /// Una cuenta en PEN con `count` filas. `shape` decide qué forma tiene la PRIMERA de ellas.
    private func makeFixture(
        count: Int = 3,
        firstIsTransfer: Bool = false,
        firstIsGroupExpense: Bool = false
    ) throws -> Fixture {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)

        var rows: [TransactionItem] = []
        for index in 0..<count {
            let tx = makeTestTransaction(
                context: context, amount: -100 - Double(index), date: Date(),
                account: account, category: category, subcategory: sub)
            if index == 0 {
                if firstIsTransfer {
                    tx.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
                }
                if firstIsGroupExpense {
                    tx.splitExpenseID = UUID().uuidString
                }
            }
            rows.append(tx)
        }
        try context.save()
        return Fixture(context: context, account: account, transactions: rows)
    }

    private func makeViewModel(_ fixture: Fixture) -> AccountFormViewModel {
        let vm = AccountFormViewModel(
            accountToEdit: fixture.account,
            existingNames: [],
            allTransactions: fixture.transactions
        )
        vm.name = fixture.account.name
        return vm
    }

    // MARK: - Histórico convertible: pregunta antes de guardar

    /// Cambiar la divisa de una cuenta con movimientos **no guarda nada** hasta que el usuario
    /// confirma. El estado que la vista necesita para redactar la pregunta queda publicado.
    @Test func conHistoricoConvertible_noGuardaYPideConfirmacion() throws {
        let fixture = try makeFixture(count: 3)
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd

        #expect(vm.saveAccount(context: fixture.context) == false)
        #expect(vm.pendingCurrencyConversion != nil)
        #expect(vm.pendingCurrencyConversion?.rowCount == 3)
        #expect(vm.pendingCurrencyConversion?.fromCurrencyCode == "PEN")
        #expect(vm.pendingCurrencyConversion?.toCurrencyCode == "USD")
        // Y la cuenta sigue en su divisa: el gate corre ANTES de aplicar nada.
        #expect(normalizeCurrencyCode(fixture.account.currencyCode) == "PEN")
    }

    /// El conteo que se le enseña al usuario es el de filas que se van a tocar de verdad. Con una
    /// fila ya estampada en la divisa destino, son 2 de 3 y no 3.
    @Test func elConteoExcluyeLoQueYaEstaEnLaDivisaDestino() throws {
        let fixture = try makeFixture(count: 3)
        fixture.transactions[0].currencyCode = "USD"
        try fixture.context.save()

        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd

        #expect(vm.saveAccount(context: fixture.context) == false)
        #expect(vm.pendingCurrencyConversion?.rowCount == 2)
    }

    // MARK: - Histórico que manda otro: no se puede

    @Test func conUnaTransferencia_bloqueaYNoGuarda() throws {
        let fixture = try makeFixture(count: 3, firstIsTransfer: true)
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd

        #expect(vm.saveAccount(context: fixture.context) == false)
        #expect(vm.isShowingCurrencyChangeBlocked)
        #expect(vm.pendingCurrencyConversion == nil)
        #expect(normalizeCurrencyCode(fixture.account.currencyCode) == "PEN")
        #expect(vm.isCurrencyEditable == false)
        #expect(vm.blockedCurrencyReasons == [.transfer])
    }

    @Test func conUnGastoDeGrupo_bloqueaYNoGuarda() throws {
        let fixture = try makeFixture(count: 3, firstIsGroupExpense: true)
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd

        #expect(vm.saveAccount(context: fixture.context) == false)
        #expect(vm.isShowingCurrencyChangeBlocked)
        #expect(vm.blockedCurrencyReasons == [.groupExpense])
    }

    // MARK: - Lo que el gate NO debe estorbar

    /// Sin cambio de divisa, guardar sigue funcionando igual que siempre — incluso con una
    /// transferencia dentro, que bloquea la divisa pero no el resto del formulario.
    @Test func sinCambioDeDivisa_guardaAunqueElHistoricoEsteBloqueado() throws {
        let fixture = try makeFixture(count: 3, firstIsTransfer: true)
        let vm = makeViewModel(fixture)
        vm.name = "Otro nombre"

        #expect(vm.saveAccount(context: fixture.context) == true)
        #expect(fixture.account.name == "Otro nombre")
        #expect(vm.pendingCurrencyConversion == nil)
        #expect(vm.isShowingCurrencyChangeBlocked == false)
    }

    /// Una cuenta sin movimientos no tiene histórico que desemparejar: la divisa se cambia y ya.
    @Test func sinMovimientos_cambiaLaDivisaSinPreguntar() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Nueva", currencyCode: "PEN")
        try context.save()

        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [], allTransactions: [])
        vm.name = "Nueva"
        vm.selectedCurrency = .usd

        #expect(vm.saveAccount(context: context) == true)
        #expect(normalizeCurrencyCode(account.currencyCode) == "USD")
        #expect(vm.pendingCurrencyConversion == nil)
    }

    /// Las filas de OTRA cuenta no cuentan: bloquear por una transferencia ajena dejaría cuentas
    /// perfectamente convertibles congeladas para siempre.
    @Test func lasFilasDeOtraCuentaNoCuentan() throws {
        let context = try makeTestContext()
        let mine = makeTestAccount(context: context, name: "Mía", currencyCode: "PEN")
        let other = makeTestAccount(context: context, name: "Ajena", currencyCode: "PEN")
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)

        let mineRow = makeTestTransaction(
            context: context, amount: -100, account: mine, category: category, subcategory: sub)
        let otherRow = makeTestTransaction(
            context: context, amount: -200, account: other, category: category, subcategory: sub)
        otherRow.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
        try context.save()

        let vm = AccountFormViewModel(
            accountToEdit: mine, existingNames: [], allTransactions: [mineRow, otherRow])
        vm.name = "Mía"
        vm.selectedCurrency = .usd

        #expect(vm.isCurrencyEditable)
        #expect(vm.saveAccount(context: context) == false)
        #expect(vm.pendingCurrencyConversion?.rowCount == 1)
    }

    // MARK: - Cancelar

    /// Cancelar devuelve el selector a la divisa de la cuenta. Sin esto, el formulario se quedaría
    /// enseñando una divisa que la cuenta no tiene y el siguiente Guardar volvería a preguntar.
    @Test func cancelar_devuelveElSelectorALaDivisaDeLaCuenta() throws {
        let fixture = try makeFixture(count: 2)
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd
        _ = vm.saveAccount(context: fixture.context)

        vm.cancelCurrencyConversion()

        #expect(vm.selectedCurrency == .pen)
        #expect(vm.pendingCurrencyConversion == nil)
        #expect(vm.isCurrencyChangeRequested == false)
    }

    // MARK: - El camino completo

    /// Confirmar reexpresa el histórico **y** guarda la cuenta, en ese orden. Al final las dos cosas
    /// dicen lo mismo: no queda ninguna fila estampada en la divisa vieja.
    ///
    /// Las tasas se siembran antes para que la conversión no dependa de la red — `prepareRates` no
    /// encuentra nada que pedir y sale sin tocarla.
    @Test func confirmar_reexpresaElHistoricoYGuardaLaCuenta() async throws {
        let fixture = try makeFixture(count: 3)
        _ = try makeTestExchangeRate(
            context: fixture.context,
            dateKey: {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.timeZone = TimeZone(identifier: "UTC")
                return f.string(from: Date())
            }(),
            rates: ["USD": 1.0, "PEN": 4.0, "EUR": 0.92])
        try fixture.context.save()

        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd
        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)

        let saved = await vm.confirmCurrencyConversion(pending, context: fixture.context)

        #expect(saved)
        #expect(normalizeCurrencyCode(fixture.account.currencyCode) == "USD")
        #expect(vm.pendingCurrencyConversion == nil)
        #expect(vm.isConvertingCurrency == false)
        // Ni una sola fila se queda en la divisa vieja: es la condición que el bug rompía.
        for tx in fixture.transactions {
            #expect(normalizeCurrencyCode(tx.currencyCode) == "USD")
        }
        // Y los importes se reexpresaron de verdad: -100 PEN a 4,00 son -25 USD.
        #expect(abs(fixture.transactions[0].amount - (-25.0)) < 0.01)
    }

    // MARK: - La carrera contra el setter del alert

    /// **El test del hallazgo que dos lentes independientes encontraron.** SwiftUI escribe `false` en
    /// el `isPresented` del alert al pulsar CUALQUIER botón, Convertir incluido; el cuerpo `async` de
    /// la confirmación corre después. Si el flujo leyera `pendingCurrencyConversion` del estado, se lo
    /// encontraría ya en `nil` y no haría nada — la feature entera sería un no-op silencioso.
    ///
    /// Aquí se reproduce el peor orden posible: el estado limpio ANTES de llamar. Debe convertir
    /// igual, porque el dato viaja en el parámetro.
    @Test func confirmar_funcionaAunqueElEstadoYaSeHayaLimpiado() async throws {
        let fixture = try makeFixtureConTasas()
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd
        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)

        // Lo que hace el setter del binding al pulsar el botón.
        vm.pendingCurrencyConversion = nil

        let saved = await vm.confirmCurrencyConversion(pending, context: fixture.context)

        #expect(saved)
        #expect(normalizeCurrencyCode(fixture.account.currencyCode) == "USD")
        for tx in fixture.transactions {
            #expect(normalizeCurrencyCode(tx.currencyCode) == "USD")
        }
    }

    /// El segundo desenlace de esa misma carrera, y el caro: si algo revierte `selectedCurrency`
    /// mientras se esperan las tasas, `saveAccount` escribiría la divisa VIEJA sobre un histórico ya
    /// convertido — el bug de este ticket, creado por su arreglo. La divisa destino manda desde el
    /// `pending`.
    @Test func confirmar_reafirmaLaDivisaDestinoAunqueAlguienLaRevierta() async throws {
        let fixture = try makeFixtureConTasas()
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd
        #expect(vm.saveAccount(context: fixture.context) == false)
        let pending = try #require(vm.pendingCurrencyConversion)

        // Lo que hacía el setter viejo: revertir la divisa elegida.
        vm.selectedCurrency = .pen

        let saved = await vm.confirmCurrencyConversion(pending, context: fixture.context)

        #expect(saved)
        #expect(normalizeCurrencyCode(fixture.account.currencyCode) == "USD")
        for tx in fixture.transactions {
            #expect(normalizeCurrencyCode(tx.currencyCode) == "USD")
        }
    }

    // MARK: - El saldo tecleado no sobrevive a la conversión

    /// Sin esto, el ajuste de saldo compara un número en la divisa VIEJA contra un `currentBalance`
    /// que ya está en la nueva, y mete un ajuste enorme que el usuario nunca vio. Basta con tocar el
    /// selector de modo: `adjustmentModeChanged` prellena el campo solo.
    @Test func pedirConversion_descartaElSaldoTecleadoEnLaDivisaVieja() throws {
        let fixture = try makeFixture(count: 3)
        let vm = makeViewModel(fixture)
        vm.selectedAdjustmentMode = .changeInitialBalance
        vm.balanceText = "1000.00"

        vm.selectedCurrency = .usd
        #expect(vm.saveAccount(context: fixture.context) == false)

        #expect(vm.balanceText.isEmpty)
        #expect(vm.parsedBalanceAmount == nil)
        #expect(vm.needsAdjustment == false)
    }

    /// El importe que se ve en «Saldo actual» sigue siendo el de la cuenta hasta que se convierte:
    /// rotularlo con la divisa recién elegida enseñaba «$ 900,00» sobre novecientos soles.
    @Test func elSaldoSeRotulaConLaDivisaDeLaCuentaHastaConvertir() throws {
        let fixture = try makeFixture(count: 2)
        let vm = makeViewModel(fixture)
        vm.selectedCurrency = .usd

        #expect(vm.balanceDisplayCurrency == .pen)
    }

    // MARK: - El gate falla CERRADO

    /// Un fetch fallido deja `allTransactions` vacío, y una lista vacía se lee igual que «cuenta sin
    /// movimientos» → veredicto `.free` → la divisa cambiaría sin convertir nada. Que es el bug
    /// original entero, entrando por la puerta de atrás.
    @Test func siNoSePudoLeerElHistorico_bloqueaEnVezDeDejarPasar() throws {
        let fixture = try makeFixture(count: 3)
        let vm = makeViewModel(fixture)
        vm._testSimulateTransactionsLoadFailure()
        vm.selectedCurrency = .usd

        #expect(vm.saveAccount(context: fixture.context) == false)
        #expect(vm.isShowingCurrencyChangeBlocked)
        #expect(normalizeCurrencyCode(fixture.account.currencyCode) == "PEN")
    }

    // MARK: - Helper con tasas

    /// Como `makeFixture`, más la fila de tasas de hoy: así `prepareRates` no encuentra nada que
    /// pedir y el camino completo corre sin tocar la red.
    private func makeFixtureConTasas() throws -> Fixture {
        let fixture = try makeFixture(count: 3)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        _ = try makeTestExchangeRate(
            context: fixture.context, dateKey: f.string(from: Date()),
            rates: ["USD": 1.0, "PEN": 4.0, "EUR": 0.92])
        try fixture.context.save()
        return fixture
    }
}
