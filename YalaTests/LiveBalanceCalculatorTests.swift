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
            selectedAccountID: acc1.persistentModelID,
            converter: MockCurrencyConverter()
        )
        #expect(result == 100)
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
            selectedAccountID: excluded.persistentModelID,  // excluida → fallback total
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
}
