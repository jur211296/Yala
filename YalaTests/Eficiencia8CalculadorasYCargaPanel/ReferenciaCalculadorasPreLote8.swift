//
//  ReferenciaCalculadorasPreLote8.swift
//  YalaTests / Eficiencia8CalculadorasYCargaPanel
//
//  Copia CONGELADA de las calculadoras compartidas de saldo tal como estaban en `origin/2.3` (`a2b8bc3b2`), antes del
//  lote 8 de eficiencia, que las pasó a acumuladores fila a fila (`LiveBalanceCalculator.SumaSaldoVivo`,
//  `AccountBalanceCalculator.SumaSaldosPorCuenta`) para poder recorrerlas por tramos. Es la referencia de la paridad: la
//  versión de una vez, la de por tramos y la de la foto sobre filas tienen que dar exactamente lo mismo que este código.
//  No se mantiene: si la regla de una cifra cambia a propósito, este fichero se retira junto con sus tests.
//

import Foundation
import SwiftData

@testable import Yala

@MainActor
enum ReferenciaCalculadorasPreLote8 {

    // MARK: - LiveBalanceCalculator.liveBalanceBreakdown (a2b8bc3b2)

    static func liveBalanceBreakdown(
        accounts: [Account],
        transactions: [TransactionItem],
        preferredCurrencyCode: String,
        selectedAccountIDs: Set<PersistentIdentifier> = [],
        excludedAccountIDs: Set<PersistentIdentifier> = [],
        asOf now: Date = .now,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> LiveBalanceCalculator.Breakdown {
        let countableIDs = Set(
            accounts.filter(\.sumsInBalance)
                .map { $0.persistentModelID }
        )
        let accountFilter = EntityFilter(included: selectedAccountIDs, excluded: excludedAccountIDs)
        let eligibleAccountIDs = countableIDs.filter { accountFilter.matches($0) }

        let cutoff = LiveBalanceCalculator.TodayCutoff(asOf: now)
        var nativeBalances: [String: Decimal] = [:]
        for tx in transactions {
            guard tx.account?.sumsInBalance == true, let acc = tx.account,
                eligibleAccountIDs.contains(acc.persistentModelID),
                cutoff.counts(tx.date)
            else { continue }
            nativeBalances[tx.currencyCode, default: 0] += Decimal(tx.amount)
        }

        let (convertedTotal, approximateMagnitude) = LiveBalanceCalculator.convertAtLatestRate(
            nativeBalances, to: preferredCurrencyCode, converter: converter
        )
        let amountsAreApproximate = ApproximateMarkThreshold.marks(
            approximate: (approximateMagnitude as NSDecimalNumber).doubleValue,
            total: (convertedTotal as NSDecimalNumber).doubleValue
        )

        return LiveBalanceCalculator.Breakdown(
            nativeBalances: nativeBalances,
            convertedTotal: convertedTotal,
            preferredCurrencyCode: preferredCurrencyCode,
            amountsAreApproximate: amountsAreApproximate,
            eligibleAccountIDs: eligibleAccountIDs,
            cutoff: cutoff
        )
    }

    // MARK: - AccountBalanceCalculator.batchCalculateBalances (a2b8bc3b2)

    static func batchCalculateBalances(
        accounts: [Account],
        transactions: [TransactionItem],
        asOf now: Date = .now,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [PersistentIdentifier: Decimal] {
        let cutoff = LiveBalanceCalculator.TodayCutoff(asOf: now)
        var balances: [PersistentIdentifier: Decimal] = [:]
        for account in accounts {
            balances[account.persistentModelID] = Decimal(0)
        }
        for transaction in transactions where cutoff.counts(transaction.date) {
            if let account = transaction.account {
                let amount = amountInAccountCurrency(transaction, converter: converter)
                let accountID = account.persistentModelID
                if let current = balances[accountID] {
                    balances[accountID] = current + amount
                }
            }
        }
        return balances
    }

    private static func amountInAccountCurrency(_ item: TransactionItem, converter: CurrencyConverting) -> Decimal {
        let amount = Decimal(item.amount)
        guard let account = item.account,
              let from = recognizedCurrencyCode(item.currencyCode),
              let to = recognizedCurrencyCode(account.currencyCode),
              from != to
        else { return amount }
        return converter.convert(amount, from: from, to: to, on: item.date)
    }
}
