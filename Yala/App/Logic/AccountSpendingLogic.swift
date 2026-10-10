//
//  AccountSpendingLogic.swift
//  Yala
//
//  Lo gastado por una cuenta en un período: la regla única que leen la tarjeta de cuenta del Panel
//  (`PanelViewModel.calculateAccountPeriodExpenses`) y la vista de cuenta (`AccountDetailCalculator`), para que las dos
//  no puedan contradecirse.
//
//  - **Qué cuenta**: un registro normal (sin ajuste ni transferencia) con categoría de gasto. Sin categoría no cuenta.
//  - **Cuánto aporta**: su importe con el signo cambiado. Un gasto de −100 suma 100 y una devolución de +30 en una
//    categoría de gasto resta 30, como acumulan Registros y Tendencias (`TransactionClassificationLogic` + suma con
//    signo). Hasta el 2026-10-10 se sumaba el valor absoluto y la devolución SUBÍA lo gastado.
//  - El neto puede ser negativo si en el período se devolvió más de lo que se gastó: se enseña tal cual.
//

import Foundation

enum AccountSpendingLogic {

    /// `true` si el registro cuenta como gasto de su cuenta.
    nonisolated static func countsAsSpending(adjustmentType: String?, categoryIsIncome: Bool?) -> Bool {
        adjustmentType == nil && categoryIsIncome == false
    }

    /// Lo que el registro aporta a lo gastado, o `nil` si no cuenta. Positivo para un gasto, negativo para una
    /// devolución.
    nonisolated static func spending(amount: Double, adjustmentType: String?, categoryIsIncome: Bool?) -> Double? {
        guard countsAsSpending(adjustmentType: adjustmentType, categoryIsIncome: categoryIsIncome) else { return nil }
        return -amount
    }

    /// Lo gastado por cada cuenta de `accounts` en `interval`, en la moneda de la cuenta. Es lo que enseña la tarjeta de
    /// cuenta del Panel en modo «solo gastos». `key` identifica la cuenta (en producción, su `persistentModelID`).
    static func spentByAccount<Key: Hashable>(
        _ transactions: [TransactionItem],
        accounts: [Key],
        in interval: DateInterval,
        key: (Account) -> Key
    ) -> [Key: Double] {
        var result: [Key: Double] = [:]
        for account in accounts { result[account] = 0 }
        for transaction in transactions {
            guard let account = transaction.account else { continue }
            let accountKey = key(account)
            guard let previous = result[accountKey] else { continue }
            guard interval.contains(transaction.date) else { continue }
            guard let spent = spending(
                amount: transaction.amount,
                adjustmentType: transaction.balanceAdjustmentType,
                categoryIsIncome: transaction.category?.isIncome
            ) else { continue }
            result[accountKey] = previous + spent
        }
        return result
    }
}
