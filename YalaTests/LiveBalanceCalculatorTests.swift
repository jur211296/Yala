//
//  LiveBalanceCalculatorTests.swift
//  YalaTests
//
//  Tests unitarios para LiveBalanceCalculator.
//  Cada test usa MockCurrencyConverter (no requiere ModelContext).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct LiveBalanceCalculatorTests {

    // MARK: - Helpers

    private func makeAccount(
        name: String = "Main",
        currencyCode: String = "USD",
        excludeFromStatistics: Bool = false
    ) -> Account {
        Account(
            name: name,
            currencyCode: currencyCode,
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "bank",
            excludeFromStatistics: excludeFromStatistics
        )
    }

    private func makeTransaction(
        amount: Double,
        currencyCode: String = "USD",
        account: Account? = nil,
        amountInPreferredCurrency: Double? = nil,
        preferredCurrencyCode: String = "USD"
    ) -> TransactionItem {
        let snapshot = amountInPreferredCurrency ?? amount
        let tx = TransactionItem(
            date: Date(),
            amount: amount,
            currencyCode: currencyCode,
            note: "",
            account: account,
            tags: [],
            amountInPreferredCurrency: snapshot,
            preferredCurrencyCode: preferredCurrencyCode
        )
        return tx
    }

    // MARK: - Tests

    @Test func liveBalance_emptyTransactions_returnsZero() {
        let account = makeAccount()
        let result = LiveBalanceCalculator.liveBalance(
            accounts: [account],
            transactions: [],
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter()
        )
        #expect(result == 0)
    }

    @Test func liveBalance_singleCurrencyMatchingPreferred_sumsRaw() {
        // Tx en USD, preferred USD: no debería invocar el converter
        let account = makeAccount(currencyCode: "USD")
        let tx1 = makeTransaction(amount: 1000, currencyCode: "USD", account: account)
        let tx2 = makeTransaction(amount: -250, currencyCode: "USD", account: account)

        // Usamos un converter con fixedRate exagerado: si lo invocara, el
        // resultado sería distinto a 750 y el test fallaría.
        var converter = MockCurrencyConverter()
        converter.fixedRate = 99

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [account],
            transactions: [tx1, tx2],
            preferredCurrencyCode: "USD",
            converter: converter
        )
        #expect(result == 750)
    }

    @Test func liveBalance_excludedAccount_notCounted() {
        let included = makeAccount(name: "In", currencyCode: "USD")
        let excluded = makeAccount(name: "Out", currencyCode: "USD", excludeFromStatistics: true)
        let txIn = makeTransaction(amount: 100, currencyCode: "USD", account: included)
        let txOut = makeTransaction(amount: 999, currencyCode: "USD", account: excluded)

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [included, excluded],
            transactions: [txIn, txOut],
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter()
        )
        #expect(result == 100)
    }

    @Test func liveBalance_twoCurrenciesRateOne_sumsAsIfSame() {
        let usdAcc = makeAccount(name: "USD", currencyCode: "USD")
        let penAcc = makeAccount(name: "PEN", currencyCode: "PEN")
        let txUsd = makeTransaction(amount: 1000, currencyCode: "USD", account: usdAcc)
        let txPen = makeTransaction(amount: 1000, currencyCode: "PEN", account: penAcc)

        var converter = MockCurrencyConverter()
        converter.fixedRate = 1.0

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [usdAcc, penAcc],
            transactions: [txUsd, txPen],
            preferredCurrencyCode: "PEN",
            converter: converter
        )
        // 1000 PEN nativos + (1000 USD * 1.0) = 2000 PEN
        #expect(result == 2000)
    }

    @Test func liveBalance_twoCurrenciesRateAboveOne_appliesConversion() {
        // 1000 USD + 1000 PEN, fixedRate=3.5 (USD→PEN), preferred=PEN → 4500
        let usdAcc = makeAccount(name: "USD", currencyCode: "USD")
        let penAcc = makeAccount(name: "PEN", currencyCode: "PEN")
        let txUsd = makeTransaction(amount: 1000, currencyCode: "USD", account: usdAcc)
        let txPen = makeTransaction(amount: 1000, currencyCode: "PEN", account: penAcc)

        var converter = MockCurrencyConverter()
        converter.fixedRate = 3.5

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [usdAcc, penAcc],
            transactions: [txUsd, txPen],
            preferredCurrencyCode: "PEN",
            converter: converter
        )
        #expect(result == 4500)
    }

    @Test func liveBalance_twoCurrenciesRateBelowOne_appliesConversion() {
        // Mismo escenario invertido: preferred=USD, fixedRate desde PEN→USD = 0.27
        let usdAcc = makeAccount(name: "USD", currencyCode: "USD")
        let penAcc = makeAccount(name: "PEN", currencyCode: "PEN")
        let txUsd = makeTransaction(amount: 1000, currencyCode: "USD", account: usdAcc)
        let txPen = makeTransaction(amount: 1000, currencyCode: "PEN", account: penAcc)

        var converter = MockCurrencyConverter()
        converter.fixedRate = 0.27

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [usdAcc, penAcc],
            transactions: [txUsd, txPen],
            preferredCurrencyCode: "USD",
            converter: converter
        )
        // 1000 USD nativos + (1000 PEN * 0.27) = 1270 USD
        #expect(result == 1270)
    }

    @Test func liveBalance_selectedAccountID_filtersToOne() {
        let acc1 = makeAccount(name: "A1", currencyCode: "USD")
        let acc2 = makeAccount(name: "A2", currencyCode: "USD")
        let tx1 = makeTransaction(amount: 100, currencyCode: "USD", account: acc1)
        let tx2 = makeTransaction(amount: 500, currencyCode: "USD", account: acc2)

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [acc1, acc2],
            transactions: [tx1, tx2],
            preferredCurrencyCode: "USD",
            selectedAccountIDs: [acc1.persistentModelID],
            converter: MockCurrencyConverter()
        )
        #expect(result == 100)
    }

    @Test func liveBalance_twoSelectedAccounts_sumsBoth() {
        // El filtro de cuentas es un conjunto: con A y B seleccionadas el saldo
        // suma las dos. Colapsarlo a `.first` mostraba una sola —y cuál, no era
        // estable—, que es como el Panel y Distribución acababan discrepando.
        let acc1 = makeAccount(name: "A1", currencyCode: "USD")
        let acc2 = makeAccount(name: "A2", currencyCode: "USD")
        let acc3 = makeAccount(name: "A3", currencyCode: "USD")
        let tx1 = makeTransaction(amount: 10_000, currencyCode: "USD", account: acc1)
        let tx2 = makeTransaction(amount: 5_000, currencyCode: "USD", account: acc2)
        let tx3 = makeTransaction(amount: 777, currencyCode: "USD", account: acc3)

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [acc1, acc2, acc3],
            transactions: [tx1, tx2, tx3],
            preferredCurrencyCode: "USD",
            selectedAccountIDs: [acc1.persistentModelID, acc2.persistentModelID],
            converter: MockCurrencyConverter()
        )
        #expect(result == 15_000)  // ni 10_000 ni 5_000: las dos, y sin la tercera
    }

    @Test func liveBalance_twoSelectedAccounts_excludeMode_returnsTheRest() {
        // En modo excluir el saldo es "todas menos las seleccionadas". Sin este
        // camino, excluir A y B enseñaba justamente el saldo de una de ellas.
        let acc1 = makeAccount(name: "A1", currencyCode: "USD")
        let acc2 = makeAccount(name: "A2", currencyCode: "USD")
        let acc3 = makeAccount(name: "A3", currencyCode: "USD")
        let tx1 = makeTransaction(amount: 10_000, currencyCode: "USD", account: acc1)
        let tx2 = makeTransaction(amount: 5_000, currencyCode: "USD", account: acc2)
        let tx3 = makeTransaction(amount: 777, currencyCode: "USD", account: acc3)

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [acc1, acc2, acc3],
            transactions: [tx1, tx2, tx3],
            preferredCurrencyCode: "USD",
            selectedAccountIDs: [acc1.persistentModelID, acc2.persistentModelID],
            isExcludeMode: true,
            converter: MockCurrencyConverter()
        )
        #expect(result == 777)
    }

    @Test func liveBalance_excludeMode_allAccountsExcluded_isZeroNotTotal() {
        // El fallback al total es SOLO del modo incluir. Excluir todas debe dar
        // 0, no el agregado — si no, "excluir" acabaría mostrando el total.
        let acc1 = makeAccount(name: "A1", currencyCode: "USD")
        let acc2 = makeAccount(name: "A2", currencyCode: "USD")
        let tx1 = makeTransaction(amount: 100, currencyCode: "USD", account: acc1)
        let tx2 = makeTransaction(amount: 500, currencyCode: "USD", account: acc2)

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [acc1, acc2],
            transactions: [tx1, tx2],
            preferredCurrencyCode: "USD",
            selectedAccountIDs: [acc1.persistentModelID, acc2.persistentModelID],
            isExcludeMode: true,
            converter: MockCurrencyConverter()
        )
        #expect(result == 0)
    }

    @Test func liveBalance_twoSelected_oneExcludedFromStats_countsOnlyTheCountable() {
        // Con dos seleccionadas y una excluida de estadísticas NO hay fallback al
        // total: la selección sigue resolviendo a una cuenta contable.
        let good = makeAccount(name: "In", currencyCode: "USD")
        let excluded = makeAccount(name: "Out", currencyCode: "USD", excludeFromStatistics: true)
        let other = makeAccount(name: "Other", currencyCode: "USD")
        let txGood = makeTransaction(amount: 200, currencyCode: "USD", account: good)
        let txExcluded = makeTransaction(amount: 999, currencyCode: "USD", account: excluded)
        let txOther = makeTransaction(amount: 333, currencyCode: "USD", account: other)

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [good, excluded, other],
            transactions: [txGood, txExcluded, txOther],
            preferredCurrencyCode: "USD",
            selectedAccountIDs: [good.persistentModelID, excluded.persistentModelID],
            converter: MockCurrencyConverter()
        )
        #expect(result == 200)  // no 1_199 (excluida) ni 533 (fallback al total)
    }

    @Test func liveBalance_breakdownWithTwoAccounts_keepsNativeBuckets() {
        // `liveBalanceBreakdown` bajo selección de cuenta no lo fijaba ningún
        // test: solo se cubría a través del wrapper que devuelve Double.
        let usd = makeAccount(name: "USD", currencyCode: "USD")
        let eur = makeAccount(name: "EUR", currencyCode: "EUR")
        let ignored = makeAccount(name: "Ignored", currencyCode: "USD")
        let txUsd = makeTransaction(amount: 100, currencyCode: "USD", account: usd)
        let txEur = makeTransaction(amount: 50, currencyCode: "EUR", account: eur)
        let txIgnored = makeTransaction(amount: 900, currencyCode: "USD", account: ignored)

        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [usd, eur, ignored],
            transactions: [txUsd, txEur, txIgnored],
            preferredCurrencyCode: "USD",
            selectedAccountIDs: [usd.persistentModelID, eur.persistentModelID],
            converter: MockCurrencyConverter()
        )
        #expect(breakdown.nativeBalances["USD"] == 100)
        #expect(breakdown.nativeBalances["EUR"] == 50)
        #expect(breakdown.nativeBalances.count == 2)
    }

    @Test func liveBalance_selectedAccountIDExcluded_fallsBackToTotal() {
        // Si la cuenta seleccionada está excluida, comportamiento actual de
        // BalanceHelper.displayedBalance es caer al total agregado
        // (sumando todas las no-excluidas).
        let included = makeAccount(name: "In", currencyCode: "USD")
        let excluded = makeAccount(name: "Out", currencyCode: "USD", excludeFromStatistics: true)
        let txIn = makeTransaction(amount: 200, currencyCode: "USD", account: included)
        let txOut = makeTransaction(amount: 999, currencyCode: "USD", account: excluded)

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [included, excluded],
            transactions: [txIn, txOut],
            preferredCurrencyCode: "USD",
            selectedAccountIDs: [excluded.persistentModelID],  // excluida → fallback total
            converter: MockCurrencyConverter()
        )
        #expect(result == 200)  // solo cuenta la incluida
    }

    @Test func liveBalance_transferMultiCurrency_bothSidesCounted() {
        // Par outflow USD -100 + inflow PEN +350 con fixedRate=3.5 (TC del par).
        // Si TC actual coincide, el par es neutro: -100*3.5 + 350 = 0.
        let usdAcc = makeAccount(name: "USD", currencyCode: "USD")
        let penAcc = makeAccount(name: "PEN", currencyCode: "PEN")
        let outflow = makeTransaction(amount: -100, currencyCode: "USD", account: usdAcc)
        let inflow = makeTransaction(amount: 350, currencyCode: "PEN", account: penAcc)
        outflow.transferPairID = "test-pair"
        outflow.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
        inflow.transferPairID = "test-pair"
        inflow.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer

        var converter = MockCurrencyConverter()
        converter.fixedRate = 3.5

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [usdAcc, penAcc],
            transactions: [outflow, inflow],
            preferredCurrencyCode: "PEN",
            converter: converter
        )
        #expect(result == 0)
    }

    @Test func liveBalance_doesNotUseHistoricalSnapshot() {
        // Una tx con amountInPreferredCurrency=999999 pero amount real=100 USD.
        // El cálculo NO debe usar el snapshot histórico — debe usar tx.amount + currencyCode.
        let account = makeAccount(currencyCode: "USD")
        let tx = makeTransaction(
            amount: 100,
            currencyCode: "USD",
            account: account,
            amountInPreferredCurrency: 999_999,  // valor "envenenado" — debe ignorarse
            preferredCurrencyCode: "PEN"
        )

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [account],
            transactions: [tx],
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter()
        )
        #expect(result == 100)  // NO 999999
    }

    @Test func liveBalance_breakdownReturnsNativeBuckets() {
        let usdAcc = makeAccount(name: "USD", currencyCode: "USD")
        let penAcc = makeAccount(name: "PEN", currencyCode: "PEN")
        let txUsd = makeTransaction(amount: 500, currencyCode: "USD", account: usdAcc)
        let txPen = makeTransaction(amount: 1000, currencyCode: "PEN", account: penAcc)

        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [usdAcc, penAcc],
            transactions: [txUsd, txPen],
            preferredCurrencyCode: "PEN",
            converter: MockCurrencyConverter()
        )

        #expect(breakdown.nativeBalances["USD"] == 500)
        #expect(breakdown.nativeBalances["PEN"] == 1000)
        #expect(breakdown.preferredCurrencyCode == "PEN")
    }

    @Test func liveBalance_zeroAmountTransactions_skipped() {
        let account = makeAccount(currencyCode: "USD")
        let tx0 = makeTransaction(amount: 0, currencyCode: "USD", account: account)
        let tx100 = makeTransaction(amount: 100, currencyCode: "USD", account: account)

        let result = LiveBalanceCalculator.liveBalance(
            accounts: [account],
            transactions: [tx0, tx100],
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter()
        )
        #expect(result == 100)  // suma 0 + 100, sin error
    }

    // MARK: - El conjunto de cuentas que viaja al FX P&L

    @Test func breakdown_exposesTheResolvedAccountSet() {
        // El FX P&L recorre las transacciones por su cuenta para poder hacer FIFO por fecha, así
        // que necesita EXACTAMENTE las cuentas que este saldo acabó sumando. Si tuviera que
        // reconstruir la elegibilidad por su lado, el día que cambie una de estas reglas el P&L
        // seguiría pareciendo plausible y estaría hablando de otro dinero.
        let visible = makeAccount(name: "Visible", currencyCode: "USD")
        let excluded = makeAccount(
            name: "Excluida", currencyCode: "USD", excludeFromStatistics: true
        )
        let other = makeAccount(name: "Otra", currencyCode: "USD")

        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [visible, excluded, other],
            transactions: [],
            preferredCurrencyCode: "PEN",
            selectedAccountIDs: [visible.persistentModelID],
            converter: MockCurrencyConverter()
        )

        #expect(breakdown.eligibleAccountIDs == [visible.persistentModelID])
        #expect(!breakdown.eligibleAccountIDs.contains(excluded.persistentModelID))
        #expect(!breakdown.eligibleAccountIDs.contains(other.persistentModelID))
    }

    @Test func breakdown_excludedFromStatistics_neverEnterTheEligibleSet() {
        let a = makeAccount(name: "A", currencyCode: "USD")
        let excluded = makeAccount(name: "X", currencyCode: "USD", excludeFromStatistics: true)

        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: [a, excluded],
            transactions: [],
            preferredCurrencyCode: "PEN",
            converter: MockCurrencyConverter()
        )

        #expect(breakdown.eligibleAccountIDs == [a.persistentModelID])
    }
}
