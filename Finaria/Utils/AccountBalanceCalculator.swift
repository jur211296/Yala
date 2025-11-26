//
//  AccountBalanceCalculator.swift
//  Finaria
//
//  Calcula el saldo actual de una cuenta en su propia moneda
//  a partir del saldo inicial y todas sus transacciones.
//  Esta pieza es el "core" de FIN-46 y debe reutilizarse
//  en todas las vistas que muestren el saldo de una cuenta.
//

import Foundation
import SwiftData

struct AccountBalanceCalculator {
    
    // MARK: - API principal (función pura)
    
    /// Calcula el saldo actual a partir de un saldo inicial
    /// y una colección de transacciones ya asociadas a la cuenta.
    /// - Parameters:
    ///   - initialBalance: Saldo inicial de la cuenta en su moneda nativa.
    ///   - transactions: Lista de TransactionItem asociados a la cuenta.
    /// - Returns: Saldo actual como Decimal (misma moneda de la cuenta).
    static func currentBalance(
        initialBalance: Decimal,
        transactions: [TransactionItem]
    ) -> Decimal {
        // Reducimos empezando en el saldo inicial y sumando
        // cada monto ya con su signo correcto (ingresos positivos,
        // gastos negativos según la convención actual de TransactionItem.amount).
        return transactions.reduce(initialBalance) { partial, item in
            partial + signedAmount(for: item)
        }
    }
    
    /// Versión conveniente que recibe la Account y todas las transacciones
    /// y se encarga de filtrar internamente solo las de esa cuenta.
    /// Esto permite reutilizar la misma lista de transacciones cargada
    /// con @Query en las vistas.
    static func currentBalance(
        for account: Account,
        allTransactions: [TransactionItem]
    ) -> Decimal {
        // Filtramos únicamente las transacciones de la cuenta dada.
        let accountTransactions = allTransactions.filter { $0.account == account }
        
        // Partimos del saldo inicial almacenado en el modelo Account.
        let initial = Decimal(account.initialBalance)
        
        // Reutilizamos la función pura principal.
        return currentBalance(initialBalance: initial, transactions: accountTransactions)
    }
    
    // MARK: - Normalización de monto
    
    /// Devuelve el monto de la transacción con el signo correcto.
    /// Supuesto actual:
    /// - TransactionItem.amount ya viene con el signo aplicado:
    ///   ingresos positivos, gastos negativos.
    /// Si en tu modelo guardas todos los montos como positivos y usas
    /// Category.isIncome para determinar el signo, aquí podrías adaptar
    /// la lógica para transformar el monto con base en esa bandera.
    private static func signedAmount(for item: TransactionItem) -> Decimal {
        // Ajusta este acceso si TransactionItem.amount usa otro tipo.
        return Decimal(item.amount)
    }
}
