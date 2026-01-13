//
//  BalanceHelper.swift
//  Neto
//
//  Helper struct for balance calculations.
//  Extracted from PanelViewModel to reduce God Class complexity.
//

import Foundation
import SwiftData

/// Pure calculation helper for balance-related operations.
/// Contains no state - all methods are static.
struct BalanceHelper {

    /// Calculates the total balance of all eligible accounts in the default currency.
    /// Uses pre-calculated amountInPreferredCurrency for optimal performance.
    /// Initial balance is now a transaction, so we start from 0.
    static func totalBalance(
        accounts: [Account],
        transactions: [TransactionItem],
        preferredCurrencyCode: String,
        context: ModelContext
    ) -> Double {
        let preferredCurrency = CurrencyCode(rawValue: preferredCurrencyCode) ?? .pen

        let eligibleAccounts = accounts.filter { account in
            !account.isArchived && !account.excludeFromStatistics
        }

        let eligibleAccountIDs = Set(eligibleAccounts.map { $0.persistentModelID })

        var totalDecimal: Decimal = 0

        // Initial balance is now a transaction, so we only sum transactions
        for tx in transactions {
            guard let account = tx.account,
                eligibleAccountIDs.contains(account.persistentModelID)
            else { continue }

            // Use pre-calculated amount if currency matches
            if tx.preferredCurrencyCode == preferredCurrency.rawValue {
                totalDecimal += Decimal(tx.amountInPreferredCurrency)
            } else {
                // Fallback: convert if preferred currency changed
                let sourceCurrency =
                    CurrencyCode(rawValue: normalizeCurrencyCode(tx.currencyCode))
                    ?? preferredCurrency

                let converted = CurrencyConverter.shared.convert(
                    Decimal(tx.amount),
                    from: sourceCurrency.rawValue,
                    to: preferredCurrency.rawValue,
                    on: tx.date,
                    context: context
                )
                totalDecimal += converted
            }
        }

        return (totalDecimal as NSDecimalNumber).doubleValue
    }

    /// Calculates the displayed balance (either total or selected account).
    /// Uses date-specific exchange rates for each transaction for accuracy.
    /// Initial balance is now a transaction.
    static func displayedBalance(
        accounts: [Account],
        transactions: [TransactionItem],
        selectedAccountID: PersistentIdentifier?,
        preferredCurrencyCode: String,
        context: ModelContext
    ) -> Double {
        let preferredCurrency = CurrencyCode(rawValue: preferredCurrencyCode) ?? .pen

        if let selectedID = selectedAccountID,
            let account = accounts.first(where: { $0.persistentModelID == selectedID }),
            !account.isArchived,
            !account.excludeFromStatistics
        {
            // Sum transactions for single account
            var totalDecimal: Decimal = 0

            let accountTransactions = transactions.filter {
                $0.account?.persistentModelID == selectedID
            }
            for tx in accountTransactions {
                // Use pre-calculated amount if currency matches
                if tx.preferredCurrencyCode == preferredCurrency.rawValue {
                    totalDecimal += Decimal(tx.amountInPreferredCurrency)
                } else {
                    // Fallback: convert if preferred currency changed
                    let txSourceCurrency =
                        CurrencyCode(rawValue: normalizeCurrencyCode(tx.currencyCode))
                        ?? preferredCurrency

                    let converted = CurrencyConverter.shared.convert(
                        Decimal(tx.amount),
                        from: txSourceCurrency.rawValue,
                        to: preferredCurrency.rawValue,
                        on: tx.date,
                        context: context
                    )
                    totalDecimal += converted
                }
            }

            return (totalDecimal as NSDecimalNumber).doubleValue
        }

        return totalBalance(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: preferredCurrencyCode,
            context: context
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
        context: ModelContext
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
                amount = CurrencyConverter.shared.convert(
                    Decimal(tx.amount),
                    from: sourceCurrency.rawValue,
                    to: preferredCurrency.rawValue,
                    on: tx.date,
                    context: context
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

    /// Converts an amount from one currency to another using the latest available rate.
    private static func convertToPreferredCurrency(
        amount: Decimal,
        from source: CurrencyCode,
        to target: CurrencyCode,
        context: ModelContext
    ) -> Decimal {
        if source == target {
            return amount
        }

        return CurrencyConverter.shared.convertWithLatestRate(
            amount,
            from: source.rawValue,
            to: target.rawValue,
            context: context
        )
    }
}
