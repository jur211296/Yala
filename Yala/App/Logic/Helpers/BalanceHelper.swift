//
//  BalanceHelper.swift
//  Yala
//
//  Helper struct for balance calculations.
//  Extracted from PanelViewModel to reduce God Class complexity.
//

import Foundation
import SwiftData

/// Pure calculation helper for balance-related operations.
/// Contains no state - all methods are static.
struct BalanceHelper {

    /// Calcula el balance total de cuentas elegibles en la moneda preferida.
    /// Delega a `LiveBalanceCalculator.liveBalance` que agrupa por moneda nativa
    /// y aplica el TC actual — refleja el saldo "hoy", no la suma de snapshots
    /// históricos.
    @available(*, deprecated, message: "Use LiveBalanceCalculator.liveBalance directly")
    static func totalBalance(
        accounts: [Account],
        transactions: [TransactionItem],
        preferredCurrencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Double {
        return LiveBalanceCalculator.liveBalance(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: preferredCurrencyCode,
            selectedAccountID: nil,
            converter: converter
        )
    }

    /// Calcula el balance mostrado (total o de cuenta seleccionada).
    /// Si la cuenta seleccionada está excluida, hace fallback al total.
    @available(*, deprecated, message: "Use LiveBalanceCalculator.liveBalance directly")
    static func displayedBalance(
        accounts: [Account],
        transactions: [TransactionItem],
        selectedAccountID: PersistentIdentifier?,
        preferredCurrencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Double {
        return LiveBalanceCalculator.liveBalance(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: preferredCurrencyCode,
            selectedAccountID: selectedAccountID,
            converter: converter
        )
    }

    /// Calculates the initial balance for trend calculation up to a specific date.
    /// Computes all transactions that occurred strictly before the `before` date.
    /// Initial balance is now a transaction, so we start from 0.
    static func initialBalanceForTrend(
        accounts: [Account],
        transactions: [TransactionItem],
        before date: Date,
        preferredCurrency: CurrencyCode,
        categoryFilter: PersistentIdentifier? = nil,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Double {
        var total: Decimal = 0

        // Sum all transactions before the date
        let pastTransactions = transactions.filter { $0.date < date }
        let eligibleAccountIDs = Set(accounts.map { $0.persistentModelID })

        for tx in pastTransactions {
            guard let account = tx.account, eligibleAccountIDs.contains(account.persistentModelID)
            else { continue }

            // Use pre-calculated amount if currency matches
            let amount: Decimal
            if tx.preferredCurrencyCode == preferredCurrency.rawValue {
                amount = Decimal(tx.amountInPreferredCurrency)
            } else {
                // Fallback: convert if preferred currency changed
                let sourceCurrency =
                    CurrencyCode(rawValue: normalizeCurrencyCode(tx.currencyCode))
                    ?? preferredCurrency
                amount = converter.convert(
                    Decimal(tx.amount),
                    from: sourceCurrency.rawValue,
                    to: preferredCurrency.rawValue,
                    on: tx.date
                )
            }

            let isIncome = tx.category?.isIncome ?? (tx.amount >= 0)

            // Apply Category Filter if present
            if let categoryID = categoryFilter {
                if tx.category?.persistentModelID != categoryID {
                    continue
                }
            }

            if isIncome {
                total += abs(amount)
            } else {
                total -= abs(amount)
            }
        }

        return (total as NSDecimalNumber).doubleValue
    }
}
