//
//  LiveBalanceCalculator.swift
//  Yala
//
//  Calcula el saldo "vivo" del usuario en moneda preferida, agrupando
//  transacciones por moneda nativa y convirtiendo cada bucket con el TC
//  ACTUAL (no el TC del día de cada transacción). Esto refleja el valor
//  real disponible HOY.
//
//  Para flujos históricos (cashflow, income/gasto del mes, sankey, top
//  categorías) seguir usando `tx.amountInPreferredCurrency` directamente
//  — esa semántica es correcta porque refleja "qué pasó económicamente".
//

import Foundation
import SwiftData

struct LiveBalanceCalculator {

    /// Desglose por moneda nativa del saldo vivo, útil para debug y para
    /// futuras vistas educativas (FX P&L breakdown).
    struct Breakdown {
        let nativeBalances: [String: Decimal]
        let convertedTotal: Decimal
        let preferredCurrencyCode: String
    }

    /// Saldo total "hoy" en moneda preferida. Si `selectedAccountID` apunta a
    /// una cuenta excluida, hace fallback al total agregado (replica behavior
    /// del antiguo `BalanceHelper.displayedBalance`).
    static func liveBalance(
        accounts: [Account],
        transactions: [TransactionItem],
        preferredCurrencyCode: String,
        selectedAccountID: PersistentIdentifier? = nil,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Double {
        let breakdown = liveBalanceBreakdown(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: preferredCurrencyCode,
            selectedAccountID: selectedAccountID,
            converter: converter
        )
        return (breakdown.convertedTotal as NSDecimalNumber).doubleValue
    }

    /// Versión que retorna el desglose completo. La versión `liveBalance` la
    /// llama internamente.
    static func liveBalanceBreakdown(
        accounts: [Account],
        transactions: [TransactionItem],
        preferredCurrencyCode: String,
        selectedAccountID: PersistentIdentifier? = nil,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Breakdown {
        let eligibleAccountIDs: Set<PersistentIdentifier>
        if let selectedID = selectedAccountID,
            let acc = accounts.first(where: { $0.persistentModelID == selectedID }),
            !acc.excludeFromStatistics
        {
            eligibleAccountIDs = [selectedID]
        } else {
            eligibleAccountIDs = Set(
                accounts.filter { !$0.excludeFromStatistics }
                    .map { $0.persistentModelID }
            )
        }

        var nativeBalances: [String: Decimal] = [:]
        for tx in transactions {
            guard let acc = tx.account,
                eligibleAccountIDs.contains(acc.persistentModelID)
            else { continue }
            nativeBalances[tx.currencyCode, default: 0] += Decimal(tx.amount)
        }

        var convertedTotal: Decimal = 0
        for (code, amount) in nativeBalances {
            if code == preferredCurrencyCode {
                convertedTotal += amount
            } else {
                convertedTotal += converter.convertWithLatestRate(
                    amount, from: code, to: preferredCurrencyCode
                )
            }
        }

        return Breakdown(
            nativeBalances: nativeBalances,
            convertedTotal: convertedTotal,
            preferredCurrencyCode: preferredCurrencyCode
        )
    }

    /// Override del último punto del trend chart. Solo retorna no-nil cuando
    /// la métrica es `.balance` y el intervalo cubre "hoy" — en otros casos
    /// el último punto del trend mantiene su valor histórico.
    /// Centraliza el patrón usado por callers de `TrendDataProcessor`.
    static func liveBalanceOverride(
        for metric: TrendType,
        interval: DateInterval,
        accounts: [Account],
        transactions: [TransactionItem],
        preferredCurrencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Double? {
        guard metric == .balance, interval.end >= Date.now else { return nil }
        return liveBalance(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: preferredCurrencyCode,
            converter: converter
        )
    }
}
