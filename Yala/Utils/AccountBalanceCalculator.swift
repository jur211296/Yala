//
//  AccountBalanceCalculator.swift
//  Yala
//
//  Calcula el saldo actual de una cuenta a partir de todas sus transacciones.
//  El saldo inicial ahora también es una transacción, por lo que empezamos desde 0.
//  Reutilizar en todas las vistas que muestren el saldo de una cuenta.
//

import Foundation
import SwiftData

struct AccountBalanceCalculator {

    // MARK: - API principal (función pura)

    /// Calcula el saldo actual a partir de una colección de transacciones.
    /// El saldo inicial ahora es una transacción con balanceAdjustmentType = "initial_balance",
    /// por lo que empezamos desde 0.
    /// - Parameters:
    ///   - transactions: Lista de TransactionItem asociados a la cuenta.
    /// - Returns: Saldo actual como Decimal (misma moneda de la cuenta).
    static func currentBalance(
        transactions: [TransactionItem]
    ) -> Decimal {
        // Reducimos desde 0 y sumamos cada monto con su signo correcto
        return transactions.reduce(Decimal(0)) { partial, item in
            partial + signedAmount(for: item)
        }
    }

    /// Versión conveniente que recibe la Account y todas las transacciones
    /// y se encarga de filtrar internamente solo las de esa cuenta.
    static func currentBalance(
        for account: Account,
        allTransactions: [TransactionItem]
    ) -> Decimal {
        // Filtramos únicamente las transacciones de la cuenta dada.
        // Usamos `persistentModelID` en lugar de comparar modelos directamente para
        // evitar inconsistencias entre instancias/caches de SwiftData.
        let accountID = account.persistentModelID
        let accountTransactions = allTransactions.filter { $0.account?.persistentModelID == accountID }

        // Partimos de 0 - el saldo inicial es ahora una transacción.
        return currentBalance(transactions: accountTransactions)
    }

    // MARK: - Batch Calculation (Optimized)

    /// Calcula el saldo actual para múltiples cuentas en una sola pasada sobre las transacciones.
    /// - Returns: Diccionario [AccountID: SaldoDecimal]
    static func batchCalculateBalances(
        accounts: [Account],
        transactions: [TransactionItem]
    ) -> [PersistentIdentifier: Decimal] {
        // 1. Inicializar saldos en 0 (el saldo inicial es ahora una transacción)
        var balances: [PersistentIdentifier: Decimal] = [:]
        for account in accounts {
            balances[account.persistentModelID] = Decimal(0)
        }

        // 2. Iterar transacciones una sola vez y acumular en la cuenta correspondiente
        for transaction in transactions {
            if let account = transaction.account {
                let amount = signedAmount(for: transaction)
                let accountID = account.persistentModelID

                // Solo sumamos si la cuenta está en nuestro mapa de interés
                if let current = balances[accountID] {
                    balances[accountID] = current + amount
                }
            }
        }

        return balances
    }

    // MARK: - Normalización de monto

    /// Devuelve el monto de la transacción con el signo correcto.
    private static func signedAmount(for item: TransactionItem) -> Decimal {
        return Decimal(item.amount)
    }
}
