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

    /// Saldo total "hoy" en moneda preferida.
    ///
    /// Algoritmo:
    /// 1. Determinar cuentas elegibles (excluyendo `excludeFromStatistics`).
    /// 2. Agrupar transacciones por `currencyCode` nativo, sumando `tx.amount`.
    /// 3. Convertir cada bucket con `convertWithLatestRate` (TC actual).
    /// 4. Sumar.
    ///
    /// Si `selectedAccountID` apunta a una cuenta excluida, hace fallback al
    /// total agregado (replica behavior de `BalanceHelper.displayedBalance`).
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
        // 1. Determinar cuentas elegibles.
        //    Si la cuenta seleccionada está excluida, fallback a total agregado
        //    (replica el behavior de BalanceHelper.displayedBalance).
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

        // 2. Agrupar transacciones por moneda nativa.
        var nativeBalances: [String: Decimal] = [:]
        for tx in transactions {
            guard let acc = tx.account,
                eligibleAccountIDs.contains(acc.persistentModelID)
            else { continue }
            nativeBalances[tx.currencyCode, default: 0] += Decimal(tx.amount)
        }

        // 3. Convertir cada bucket al TC actual y sumar.
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
}
